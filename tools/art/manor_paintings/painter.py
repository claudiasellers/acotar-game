"""Core of the manor painting generator: a reference picture, then oil paint.

Each artwork is drawn twice. First a clean *reference* (gradients, shapes,
light) by a genre module (scenes_*.py). Then paint(): Hertzmann's layered
brush-stroke method (coarse to fine curved strokes that follow the image's
contours), so every work reads as an oil painting rather than a vector.
Then age, varnish and the albedo cap (whites <= 0.85, L18-4).

Only PIL and numpy, so it runs on the cloud and on the Mac alike.
Deterministic: all randomness comes from the work's own seeded RNG.
"""

import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ALBEDO_CAP = 0.85


# ------------------------------------------------------------------ colour

def hexc(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(ch * 2 for ch in h)
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def C(c):
    return hexc(c) if isinstance(c, str) else np.asarray(c, np.float32)


def mix(a, b, t):
    return C(a) * (1.0 - t) + C(b) * t


def shade(c, k):
    """k < 0 darkens toward a cool shadow, k > 0 lightens toward warm light."""
    c = C(c)
    if k < 0:
        return c * (1 + k) + np.array([0.10, 0.06, 0.16], np.float32) * (-k) * 0.6
    return c + (np.array([1.0, 0.95, 0.85], np.float32) - c) * k


def jitter(c, rng, amt=0.05):
    return np.clip(C(c) + np.array([rng.uniform(-amt, amt) for _ in range(3)], np.float32), 0, 1)


# ------------------------------------------------------------------ canvas

class Ref:
    """A reference picture being built: float RGB in 0..1, plus a detail mask
    (areas such as faces whose fine features must survive the brush)."""

    def __init__(self, w, h, rng):
        self.w, self.h, self.rng = w, h, rng
        self.rgb = np.zeros((h, w, 3), np.float32)
        self.detail = np.zeros((h, w), np.float32)
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        self.u = xx / max(1, w - 1)
        self.v = yy / max(1, h - 1)

    # --- fills

    def fill(self, c):
        self.rgb[:] = C(c)

    def vgrad(self, stops, y0=0.0, y1=1.0, mask=None):
        """Vertical gradient through [(t, colour), ...] between v=y0 and v=y1."""
        t = np.clip((self.v - y0) / max(1e-5, y1 - y0), 0, 1)
        out = self._ramp(t, stops)
        self.put(out, mask)

    def rgrad(self, cx, cy, r, stops, mask=None, aspect=1.0):
        d = np.sqrt(((self.u - cx) * aspect) ** 2 + (self.v - cy) ** 2) / max(1e-5, r)
        out = self._ramp(np.clip(d, 0, 1), stops)
        self.put(out, mask)

    @staticmethod
    def _ramp(t, stops):
        out = np.zeros(t.shape + (3,), np.float32)
        ts = [s[0] for s in stops]
        cs = [C(s[1]) for s in stops]
        out[:] = cs[0]
        for i in range(len(stops) - 1):
            a, b = ts[i], ts[i + 1]
            k = np.clip((t - a) / max(1e-5, b - a), 0, 1)[..., None]
            sel = (t >= a)[..., None]
            out = np.where(sel, cs[i] * (1 - k) + cs[i + 1] * k, out)
        return out

    def put(self, colour_or_img, mask=None, alpha=1.0):
        """Composite a colour or HxWx3 image through a 0..1 mask."""
        src = colour_or_img if isinstance(colour_or_img, np.ndarray) and colour_or_img.ndim == 3 else C(colour_or_img)
        if mask is None:
            m = np.full((self.h, self.w, 1), alpha, np.float32)
        else:
            m = (mask * alpha)[..., None]
        self.rgb = self.rgb * (1 - m) + src * m

    def shaded(self, mask, base, light=(-0.6, -0.5), k=0.35, rim=0.0):
        """Fill `mask` with `base`, lit from `light` (a direction in uv): the
        mask's own distance field gives a soft rounded look (R3 rounded forms)."""
        if mask.max() <= 0:
            return
        ys, xs = np.nonzero(mask > 0.5)
        if len(xs) == 0:
            return
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        bw, bh = max(1, x1 - x0), max(1, y1 - y0)
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        nx = ((np.arange(self.w, dtype=np.float32) - cx) / (bw / 2))[None, :]
        ny = ((np.arange(self.h, dtype=np.float32) - cy) / (bh / 2))[:, None]
        lx, ly = light
        dot = -(nx * lx + ny * ly)
        dot = np.clip(dot, -1.4, 1.4) / 1.4
        img = np.empty((self.h, self.w, 3), np.float32)
        b = C(base)
        lit = shade(b, k)
        dark = shade(b, -k * 1.1)
        t = (dot * 0.5 + 0.5)[..., None]
        img[:] = dark * (1 - t) + lit * t
        if rim > 0:
            edge = np.clip(np.sqrt(nx ** 2 + ny ** 2) - 0.7, 0, 1)[..., None] * rim
            img = img + (np.array([1.0, 0.92, 0.80]) - img) * edge * np.clip(-dot, 0, 1)[..., None]
        self.put(img, mask)

    def mark_detail(self, mask, k=1.0):
        self.detail = np.maximum(self.detail, mask * k)

    # --- masks (all return HxW float32 0..1; coordinates in uv)

    def _draw(self, fn, bbox, blur=0.0, ss=2):
        """Rasterise only inside bbox (uv x0, y0, x1, y1) and paste the patch into
        a full-size mask: masks are many and small, so this is the hot path."""
        pad = int(blur * 3) + 3
        x0 = max(0, int(bbox[0] * self.w) - pad)
        y0 = max(0, int(bbox[1] * self.h) - pad)
        x1 = min(self.w, int(math.ceil(bbox[2] * self.w)) + pad)
        y1 = min(self.h, int(math.ceil(bbox[3] * self.h)) + pad)
        out = np.zeros((self.h, self.w), np.float32)
        if x1 <= x0 or y1 <= y0:
            return out
        pw, ph = x1 - x0, y1 - y0
        img = Image.new("L", (pw * ss, ph * ss), 0)
        d = ImageDraw.Draw(img)
        fn(d, ss, x0, y0)
        img = img.resize((pw, ph), Image.LANCZOS if pw * ph < 250000 else Image.BILINEAR)
        if blur > 0:
            img = img.filter(ImageFilter.GaussianBlur(blur))
        out[y0:y1, x0:x1] = np.asarray(img, np.float32) / 255.0
        return out

    def poly(self, pts, blur=0.6):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]

        def f(d, ss, ox, oy):
            d.polygon([((x * self.w - ox) * ss, (y * self.h - oy) * ss) for x, y in pts], fill=255)
        return self._draw(f, (min(xs), min(ys), max(xs), max(ys)), blur)

    def ellipse(self, cx, cy, rx, ry, blur=0.6, angle=0.0):
        if angle == 0.0:
            def f(d, ss, ox, oy):
                d.ellipse([((cx - rx) * self.w - ox) * ss, ((cy - ry) * self.h - oy) * ss,
                           ((cx + rx) * self.w - ox) * ss, ((cy + ry) * self.h - oy) * ss], fill=255)
            return self._draw(f, (cx - rx, cy - ry, cx + rx, cy + ry), blur)
        pts = []
        ca, sa = math.cos(angle), math.sin(angle)
        for i in range(36):
            a = 2 * math.pi * i / 36
            x, y = rx * math.cos(a) * self.w, ry * math.sin(a) * self.h
            pts.append(((cx * self.w + x * ca - y * sa) / self.w, (cy * self.h + x * sa + y * ca) / self.h))
        return self.poly(pts, blur)

    def circle(self, cx, cy, r, blur=0.6):
        """A true circle: r is in units of the image height."""
        return self.ellipse(cx, cy, r * self.h / self.w, r, blur)

    def lines(self, segs, width, blur=0.5):
        """segs: list of point lists in uv; width in px of the final image."""
        xs = [p[0] for s in segs for p in s]
        ys = [p[1] for s in segs for p in s]
        mw, mh = width / self.w, width / self.h

        def f(d, ss, ox, oy):
            for pts in segs:
                d.line([((x * self.w - ox) * ss, (y * self.h - oy) * ss) for x, y in pts], fill=255, width=max(1, int(width * ss)), joint="curve")
        return self._draw(f, (min(xs) - mw, min(ys) - mh, max(xs) + mw, max(ys) + mh), blur)

    def blob(self, cx, cy, r, wobble=0.18, seed=0, squash=1.0, n=40, blur=0.8):
        rng = random.Random(seed)
        ph = [rng.uniform(0, 6.28) for _ in range(3)]
        pts = []
        for i in range(n):
            a = 2 * math.pi * i / n
            k = 1 + wobble * (0.6 * math.sin(3 * a + ph[0]) + 0.3 * math.sin(5 * a + ph[1]) + 0.2 * math.sin(8 * a + ph[2]))
            pts.append((cx + r * k * math.cos(a) * self.h / self.w, cy + r * k * math.sin(a) * squash))
        return self.poly(pts, blur)

    def below(self, profile, blur=0.8):
        """Mask of everything below a horizon profile: profile(u) -> v."""
        us = np.linspace(0, 1, self.w, dtype=np.float32)
        vs = np.array([profile(float(x)) for x in us], np.float32)
        m = (self.v >= vs[None, :]).astype(np.float32)
        if blur > 0:
            m = blur_arr(m, blur)
        return m

    def noise(self, scale, seed, octaves=3):
        return fractal(self.w, self.h, scale, seed, octaves)


# ------------------------------------------------------------------ noise & filters

def value_noise(w, h, cells, seed):
    rng = np.random.default_rng(seed)
    gx, gy = max(2, int(cells * w / max(w, h)) + 2), max(2, int(cells * h / max(w, h)) + 2)
    g = (rng.random((gy, gx)) * 255).astype(np.uint8)
    img = Image.fromarray(g, "L").resize((w, h), Image.BICUBIC)
    return np.asarray(img, np.float32) / 255.0


def fractal(w, h, scale, seed, octaves=3):
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        out += value_noise(w, h, scale * (2 ** o), seed * 31 + o) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def blur_arr(a, r):
    if a.ndim == 2:
        img = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8), "L")
        return np.asarray(img.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0
    img = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8), "RGB")
    return np.asarray(img.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0


def bend(rgb, seed, amount):
    """The fae 'bend to the world' (ch19): a slow swirl through the picture."""
    h, w = rgb.shape[:2]
    nx = (fractal(w, h, 2.5, seed, 2) - 0.5) * 2 * amount * w
    ny = (fractal(w, h, 2.5, seed + 7, 2) - 0.5) * 2 * amount * h
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    sx = np.clip(xx + nx, 0, w - 1).astype(np.int32)
    sy = np.clip(yy + ny, 0, h - 1).astype(np.int32)
    return rgb[sy, sx]


# ------------------------------------------------------------------ painting

def paint(ref_rgb, rng, ground=(0.45, 0.32, 0.26), scales=(0.045, 0.022, 0.011, 0.0065), threshold=0.075,
          curvature=0.4, max_len=(5, 5, 4, 3), bristle=0.55, value_jitter=0.03, detail=None, flow_seed=1,
          crisp=0.16, flow_angle=0.0):
    """Hertzmann (1998) layered curved brush strokes over an underpainting.

    The underpainting is the reference blurred to the coarsest brush, warmed
    toward the toned ground, so no bare canvas shows. Strokes follow the
    picture's contours; where the picture is flat they follow a slow flow
    field (flow_angle in radians plus noise), the way a painter lays a sky."""
    h, w = ref_rgb.shape[:2]
    ref8 = Image.fromarray(np.clip(ref_rgb * 255, 0, 255).astype(np.uint8), "RGB")
    size = max(w, h)
    under = np.asarray(ref8.filter(ImageFilter.GaussianBlur(scales[0] * size * 0.6)), np.float32) / 255.0
    under = under * 0.85 + np.asarray(ground, np.float32) * 0.15
    canvas = Image.fromarray(np.clip(under * 255, 0, 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(canvas)
    flow = flow_angle + (fractal(w, h, 2.0, flow_seed, 2) - 0.5) * 2.2
    fcos, fsin = np.cos(flow), np.sin(flow)
    for li, frac in enumerate(scales):
        R = max(2, int(round(frac * size)))
        L = max_len[min(li, len(max_len) - 1)]
        blur = np.asarray(ref8.filter(ImageFilter.GaussianBlur(R * 0.45)), np.float32) / 255.0
        cur = np.asarray(canvas, np.float32) / 255.0
        lum = blur @ np.array([0.3, 0.59, 0.11], np.float32)
        gy, gx = np.gradient(lum)
        diff = np.abs(cur - blur).sum(axis=2)
        g = max(2, int(R * 0.9))
        hh, ww = (h // g) * g, (w // g) * g
        blocks = diff[:hh, :ww].reshape(hh // g, g, ww // g, g).transpose(0, 2, 1, 3).reshape(hh // g, ww // g, g * g)
        err = blocks.mean(axis=2)
        arg = blocks.argmax(axis=2)
        strokes = []
        thr = 0.0 if li == 0 else threshold * (1.0 + 0.4 * li)
        for by in range(err.shape[0]):
            for bx in range(err.shape[1]):
                if err[by, bx] < thr:
                    continue
                k = arg[by, bx]
                strokes.append((bx * g + k % g, by * g + k // g))
        rng.shuffle(strokes)
        for (x, y) in strokes:
            col = blur[y, x]
            col = np.clip(col * (1 + rng.uniform(-value_jitter, value_jitter)) + rng.uniform(-0.01, 0.01), 0, 1)
            pts = [(x, y)]
            dx0, dy0 = 0.0, 0.0
            px, py = float(x), float(y)
            for i in range(L):
                ix, iy = int(px), int(py)
                if ix < 0 or iy < 0 or ix >= w or iy >= h:
                    break
                if i > 1 and np.abs(blur[iy, ix] - col).sum() > np.abs(cur[iy, ix] - col).sum() + 0.015:
                    break
                gxv, gyv = gx[iy, ix], gy[iy, ix]
                mag = math.hypot(gxv, gyv)
                if mag < 0.004:
                    dx, dy = fcos[iy, ix], fsin[iy, ix]
                else:
                    dx, dy = -gyv / mag, gxv / mag
                if i > 0 and dx * dx0 + dy * dy0 < 0:
                    dx, dy = -dx, -dy
                if i > 0:
                    dx, dy = curvature * dx + (1 - curvature) * dx0, curvature * dy + (1 - curvature) * dy0
                    m2 = math.hypot(dx, dy) or 1.0
                    dx, dy = dx / m2, dy / m2
                px, py = px + R * 0.8 * dx, py + R * 0.8 * dy
                dx0, dy0 = dx, dy
                pts.append((px, py))
            c255 = tuple(int(v * 255) for v in col)
            r2 = R / 2
            if len(pts) == 1:
                draw.ellipse([x - r2, y - r2, x + r2, y + r2], fill=c255)
                continue
            draw.line(pts, fill=c255, width=R, joint="curve")
            for (qx, qy) in (pts[0], pts[-1]):
                draw.ellipse([qx - r2, qy - r2, qx + r2, qy + r2], fill=c255)
            if R >= 4 and rng.random() < bristle:
                for off, kk in ((-0.3, 1.06), (0.28, 0.94)):
                    bc = tuple(int(min(255, v * 255 * kk)) for v in col)
                    nx, ny = -dy0 * R * off, dx0 * R * off
                    draw.line([(sx + nx, sy + ny) for sx, sy in pts], fill=bc, width=max(1, R // 6))
    out = np.asarray(canvas, np.float32) / 255.0
    sharp = blur_arr(ref_rgb, 0.8)
    m = np.full((h, w), crisp, np.float32)
    if detail is not None and detail.max() > 0:
        m = np.maximum(m, blur_arr(detail, 1.2) * 0.7)
    out = out * (1 - m[..., None]) + sharp * m[..., None]
    return out


# ------------------------------------------------------------------ finishing

def finish(img, rng, age=0.0, varnish=0.0, vignette=0.0, cool=0.0, contrast=0.0, saturate=0.0):
    """Contrast and saturation (pastels still need darks to read), varnish
    (warm amber), age (darkening + craquelure), vignette, then the albedo cap.
    All amounts 0..1."""
    h, w = img.shape[:2]
    out = img.copy()
    if contrast > 0:
        lum = (out @ np.array([0.3, 0.59, 0.11], np.float32))[..., None]
        mid = float(np.median(lum))
        out = out + (out - mid) * contrast
        out = np.clip(out, 0, 1)
    if saturate > 0:
        lum = (out @ np.array([0.3, 0.59, 0.11], np.float32))[..., None]
        out = np.clip(lum + (out - lum) * (1 + saturate), 0, 1)
    if varnish > 0:
        amber = np.array([1.0, 0.86, 0.62], np.float32)
        out = out * (1 - varnish * 0.35) + out * amber * (varnish * 0.35)
    if cool > 0:
        out = out * (1 - cool * 0.2) + out * np.array([0.86, 0.9, 1.0], np.float32) * (cool * 0.2)
    if vignette > 0:
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        d = np.sqrt(((xx / w - 0.5) * 1.6) ** 2 + ((yy / h - 0.5) * 1.6) ** 2)
        out *= (1 - vignette * np.clip(d - 0.35, 0, 1) ** 1.5)[..., None]
    if age > 0:
        out *= 1 - age * 0.12
        crack = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(crack)
        n = int(age * (w * h) / 900)
        for _ in range(n):
            x, y = rng.uniform(0, w), rng.uniform(0, h)
            pts = [(x, y)]
            a = rng.uniform(0, math.pi * 2)
            for _ in range(rng.randint(2, 5)):
                a += rng.uniform(-1.2, 1.2)
                L = rng.uniform(3, 9) * w / 512
                x, y = x + math.cos(a) * L, y + math.sin(a) * L
                pts.append((x, y))
            d.line(pts, fill=255, width=1)
        cr = np.asarray(crack, np.float32)[..., None] / 255.0
        out = out * (1 - cr * 0.22 * age)
    return np.clip(out, 0, ALBEDO_CAP)


def to_image(arr):
    return Image.fromarray(np.clip(arr * 255 + 0.5, 0, 255).astype(np.uint8), "RGB")
