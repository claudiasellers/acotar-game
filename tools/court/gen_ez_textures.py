#!/usr/bin/env python3
"""Painted leaf sprays and barks for the court's EZ-Tree trees (finish plan T1).

EZ-Tree's code is MIT, but the photo leaf sprays and barks it ships carry no
stated licence. These are our own, painted from scratch. The sprays keep the
same layout (one twig
rising from the bottom centre of a 512 px RGBA card) so the exported leaf cards
map onto them unchanged. The court's leaf shader (painted = 1) recolours a card
from its value alone, so each spray is matched to the photo spray it replaces in
coverage and in value (mean and spread), measured on the opaque pixels:

    oak    cover 0.256, value 0.427 +- 0.107   (lobed leaves, alternate)
    ash    cover 0.157, value 0.404 +- 0.095   (pinnate: paired leaflets)
    aspen  cover 0.153, value 0.601 +- 0.102   (round leaves on long stalks)
    pine   cover 0.229, value 0.381 +- 0.123   (needle tufts)

The barks tile both ways and are matched the same way, because the court's bark
shader keeps only a texture's light and dark (value / mean):

    oak    value 0.338 +- 0.107   (long vertical furrows)
    birch  value 0.582 +- 0.120   (pale, dark lenticel dashes and patches)
    pine   value 0.303 +- 0.094   (plates split by dark cracks)

    python3 tools/court/gen_ez_textures.py <out dir>        # leaf_<species>.png, bark_<species>.png
    python3 tools/court/gen_ez_textures.py <out dir> --sheet # plus a contact sheet

Deterministic (fixed seeds). Needs Pillow and numpy.
"""
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 512
SS = 2  # supersampling
TARGET = {
    "oak": (0.256, 0.427, 0.107),
    "ash": (0.157, 0.404, 0.095),
    "aspen": (0.153, 0.601, 0.102),
    "pine": (0.229, 0.381, 0.123),
}
HUE = {  # RGB direction for the value (only the photo path, painted = 0, sees it)
    "oak": (0.78, 1.0, 0.52),
    "ash": (0.72, 1.0, 0.50),
    "aspen": (0.80, 1.0, 0.48),
    "pine": (0.66, 1.0, 0.56),
}


class Canvas:
    """A value layer and a coverage layer at SS x size."""

    def __init__(self):
        n = SIZE * SS
        self.val = Image.new("L", (n, n), 0)
        self.cov = Image.new("L", (n, n), 0)
        self.dv = ImageDraw.Draw(self.val)
        self.dc = ImageDraw.Draw(self.cov)

    def poly(self, pts, value):
        p = [(x * SS, y * SS) for x, y in pts]
        self.dv.polygon(p, fill=int(value * 255))
        self.dc.polygon(p, fill=255)

    def line(self, pts, width, value):
        p = [(x * SS, y * SS) for x, y in pts]
        self.dv.line(p, fill=int(value * 255), width=max(1, int(width * SS)), joint="curve")
        self.dc.line(p, fill=255, width=max(1, int(width * SS)), joint="curve")

    def stroke(self, pts, width, value):
        """A mark on the value layer only (midribs, veins)."""
        p = [(x * SS, y * SS) for x, y in pts]
        self.dv.line(p, fill=int(value * 255), width=max(1, int(width * SS)))


def bezier(a, b, c, n=24):
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * b[0] + t * t * c[0],
                    (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * b[1] + t * t * c[1]))
    return out


def along(path, t):
    """Point and direction at fraction t of a polyline."""
    seg = [math.dist(path[i], path[i + 1]) for i in range(len(path) - 1)]
    total = sum(seg)
    d = t * total
    for i, s in enumerate(seg):
        if d <= s or i == len(seg) - 1:
            f = d / s if s > 0 else 0
            a, b = path[i], path[i + 1]
            p = (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
            return p, math.atan2(b[1] - a[1], b[0] - a[0])
        d -= s
    return path[-1], 0.0


def leaf_outline(kind, length, width, rng):
    """Leaf outline in leaf space: base at (0, 0), tip at (length, 0)."""
    pts = []
    n = 48
    lobes = rng.integers(4, 7)
    for i in range(n + 1):
        t = i / n  # 0 base -> 1 tip -> back along the other side
        u = t * 2 if t <= 0.5 else (1 - t) * 2
        side = 1 if t <= 0.5 else -1
        if kind == "oak":
            w = math.sin(math.pi * u ** 0.85) * (0.58 + 0.42 * math.sqrt(abs(math.sin(math.pi * lobes * u))))
        elif kind == "ash":
            w = math.sin(math.pi * u) ** 0.9 * (1.0 - 0.35 * u)
        else:  # aspen: round, a little heart at the base, short tip
            w = math.sin(math.pi * u ** 0.75) ** 0.6
        pts.append((u * length, side * w * width * 0.5))
    return pts


def place(pts, at, ang):
    c, s = math.cos(ang), math.sin(ang)
    return [(at[0] + x * c - y * s, at[1] + x * s + y * c) for x, y in pts]


def paint_leaf(cv, kind, at, ang, length, width, rng, value):
    """A leaf in three painted bands (base shade, body, sunlit tip) and a midrib."""
    out = leaf_outline(kind, length, width, rng)
    cv.poly(place(out, at, ang), value * 0.82)
    body = [(x * 0.92 + length * 0.08, y * 0.78) for x, y in out]
    cv.poly(place(body, at, ang), value)
    tip = [(x * 0.55 + length * 0.42, y * 0.55 + width * 0.06) for x, y in out]
    cv.poly(place(tip, at, ang), min(1.0, value * 1.22))
    cv.stroke(place([(length * 0.04, 0), (length * 0.9, 0)], at, ang), max(1.0, width * 0.06), value * 0.7)


def twig(rng, bend=30.0):
    top = (SIZE / 2 + rng.uniform(-bend, bend), 18.0)
    mid = (SIZE / 2 + rng.uniform(-bend, bend) * 1.4, SIZE * 0.5)
    return bezier((SIZE / 2, SIZE - 1.0), mid, top)


def side_twigs(cv, main, rng, count, reach, width, value, t0=0.15, t1=0.8):
    """Short side twigs off the main one, alternating; returns their paths."""
    out = []
    for k in range(count):
        t = t0 + (t1 - t0) * k / max(count - 1, 1)
        p, a = along(main, t)
        side = 1 if k % 2 == 0 else -1
        ba = a + side * rng.uniform(0.55, 0.9)
        bl = reach * (1.0 - 0.45 * t) * rng.uniform(0.85, 1.1)
        end = (p[0] + math.cos(ba) * bl, p[1] + math.sin(ba) * bl)
        br = bezier(p, ((p[0] + end[0]) / 2 + side * 8, (p[1] + end[1]) / 2 - 10), end, 12)
        cv.line(br, width, value)
        out.append(br)
    return out


def spray_oak(cv, rng, sc):
    main = twig(rng)
    cv.line(main, 5.0, 0.30)
    for br in [main] + side_twigs(cv, main, rng, 4, 150, 3.5, 0.3):
        n = 9 if br is main else 5
        for k in range(n):
            t = 0.15 + 0.85 * k / (n - 1)
            p, a = along(br, t)
            side = 1 if k % 2 == 0 else -1
            length = sc * (90 * (1.0 - 0.35 * t) + rng.uniform(-8, 8))
            paint_leaf(cv, "oak", p, a + side * rng.uniform(0.6, 1.1), length, length * 0.62, rng, rng.uniform(0.36, 0.52))
        p, a = along(br, 1.0)
        paint_leaf(cv, "oak", p, a, sc * 70, sc * 44, rng, 0.5)


def spray_ash(cv, rng, sc):
    main = twig(rng, 24)
    cv.line(main, 4.0, 0.28)
    for rach in side_twigs(cv, main, rng, 6, 190, 2.0, 0.3, 0.12, 0.85) + [main[len(main) // 2:]]:
        pairs = 5
        for j in range(pairs):
            q, qa = along(rach, 0.2 + 0.72 * j / pairs)
            for side in (-1, 1):
                ln = sc * (40 + rng.uniform(-5, 5))
                paint_leaf(cv, "ash", q, qa + side * 1.05, ln, ln * 0.42, rng, rng.uniform(0.34, 0.48))
        q, qa = along(rach, 1.0)
        paint_leaf(cv, "ash", q, qa, sc * 42, sc * 17, rng, 0.46)


def spray_aspen(cv, rng, sc):
    main = twig(rng, 20)
    cv.line(main, 3.5, 0.40)
    for br in [main] + side_twigs(cv, main, rng, 4, 120, 2.5, 0.4):
        n = 8 if br is main else 4
        for k in range(n):
            t = 0.18 + 0.8 * k / (n - 1)
            p, a = along(br, t)
            side = 1 if k % 2 == 0 else -1
            sa = a + side * rng.uniform(0.6, 1.1)
            stalk = 22 + rng.uniform(-5, 6)
            q = (p[0] + math.cos(sa) * stalk, p[1] + math.sin(sa) * stalk)
            cv.line([p, q], 1.6, 0.45)
            ln = sc * (48 * (1.0 - 0.25 * t) + rng.uniform(-5, 5))
            paint_leaf(cv, "aspen", q, sa + rng.uniform(-0.5, 0.5), ln, ln * 0.95, rng, rng.uniform(0.52, 0.68))


def spray_pine(cv, rng, sc):
    main = twig(rng, 18)
    cv.line(main, 5.0, 0.26)
    for br in [main] + side_twigs(cv, main, rng, 9, 200, 3.0, 0.26, 0.1, 0.88):
        for i in range(110):
            t = rng.uniform(0.05, 1.0)
            p, a = along(br, t)
            for side in (-1, 1):
                na = a + side * rng.uniform(0.45, 0.85) - 0.25 * side * t
                nl = sc * rng.uniform(18, 28) * (1.15 - 0.3 * t)
                v = rng.uniform(0.28, 0.5) + 0.12 * t
                cv.line([p, (p[0] + math.cos(na) * nl, p[1] + math.sin(na) * nl)], 2.4, v)


def finish(cv, species):
    cover_target, mean_t, std_t = TARGET[species]
    val = cv.val.resize((SIZE, SIZE), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
    cov = cv.cov.resize((SIZE, SIZE), Image.LANCZOS)
    v = np.asarray(val).astype(np.float32) / 255.0
    a = np.asarray(cov).astype(np.float32) / 255.0
    # Coverage is premultiplied into the value at the edges: undo it.
    v = np.where(a > 0.05, v / np.maximum(a, 0.05), 0.0)
    m = a >= 0.5
    cur = v[m]
    v = (v - cur.mean()) / max(cur.std(), 1e-4) * std_t + mean_t
    v = np.clip(v, 0.0, 1.0)
    hue = np.array(HUE[species], np.float32)
    # Luminance of value * hue must equal the value.
    hue = hue / float(hue @ np.array([0.3, 0.59, 0.11], np.float32))
    rgb = np.clip(v[..., None] * hue[None, None, :], 0.0, 1.0)
    img = np.dstack([rgb, a]) * 255.0
    out = Image.fromarray(img.astype(np.uint8), "RGBA")
    stats = (float(m.mean()), float(v[m].mean()), float(v[m].std()))
    return out, stats


BARK_TARGET = {"oak": (0.338, 0.107), "birch": (0.582, 0.120), "pine": (0.303, 0.094)}
BARK_HUE = {"oak": (1.10, 0.98, 0.84), "birch": (1.02, 1.0, 0.97), "pine": (1.22, 0.94, 0.80)}


def periodic_noise(rng, sx, sy, n=SIZE):
    """Tileable noise: white noise shaped in frequency (sx, sy = feature size in px)."""
    f = np.fft.fft2(rng.standard_normal((n, n)))
    ky = np.fft.fftfreq(n)[:, None]
    kx = np.fft.fftfreq(n)[None, :]
    f *= np.exp(-((kx * sx) ** 2 + (ky * sy) ** 2) * 2.0)
    v = np.real(np.fft.ifft2(f))
    return (v - v.mean()) / max(v.std(), 1e-6)


def bark_oak(rng):
    furrow = periodic_noise(rng, 3.5, 70)        # long vertical ridges
    ridges = np.clip(1.0 - np.abs(furrow) * 0.75, 0.0, 1.0)  # dark furrow lines
    cross = periodic_noise(rng, 2.5, 7)          # breaks along the ridges
    detail = periodic_noise(rng, 1.5, 3)
    big = periodic_noise(rng, 50, 140)
    return ridges ** 1.6 * (0.85 + 0.15 * np.tanh(cross)) + 0.08 * detail + 0.10 * big


def bark_pine(rng, cells=110):
    pts = rng.uniform(0, SIZE, (cells, 2))
    pts[:, 1] *= 1.0
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    d1 = np.full((SIZE, SIZE), 1e9, np.float32)
    d2 = np.full((SIZE, SIZE), 1e9, np.float32)
    shade = np.zeros((SIZE, SIZE), np.float32)
    tone = rng.uniform(-0.5, 0.5, cells)
    for i, (px, py) in enumerate(pts):
        for ox in (-SIZE, 0, SIZE):
            for oy in (-SIZE, 0, SIZE):
                # Plates are taller than wide: squash the vertical distance.
                d = np.sqrt((xx - px - ox) ** 2 + ((yy - py - oy) * 0.55) ** 2)
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                shade = np.where(closer, tone[i], shade)
                d1 = np.where(closer, d, d1)
    crack = np.clip((d2 - d1) / 9.0, 0.0, 1.0)
    edge = np.clip(d1 / 22.0, 0.0, 1.0)  # each plate lit at its middle
    return crack ** 0.6 * (0.8 + 0.2 * (1.0 - edge)) + 0.3 * shade + 0.12 * periodic_noise(rng, 1.5, 4)


def bark_birch(rng):
    v = 1.0 + 0.08 * periodic_noise(rng, 20, 60)
    img = Image.fromarray(np.zeros((SIZE, SIZE), np.uint8), "L")
    d = ImageDraw.Draw(img)
    for _ in range(110):  # lenticels: thin horizontal dashes
        x, y = rng.uniform(0, SIZE, 2)
        w, h = rng.uniform(8, 34) * rng.uniform(0.6, 1.4), rng.uniform(1.0, 2.6)
        for ox in (-SIZE, 0, SIZE):
            for oy in (-SIZE, 0, SIZE):
                d.ellipse([x + ox - w, y + oy - h, x + ox + w, y + oy + h], fill=int(rng.uniform(150, 255)))
    for _ in range(5):  # dark patches where branches fell: ragged chevrons
        x, y = rng.uniform(0, SIZE, 2)
        w, h = rng.uniform(16, 30), rng.uniform(5, 10)
        pts = [(x - w, y), (x - w * 0.3, y - h * rng.uniform(0.6, 1.2)), (x + w * rng.uniform(0.1, 0.4), y - h * 0.4),
            (x + w, y + rng.uniform(-2, 2)), (x + w * 0.2, y + h * rng.uniform(0.6, 1.0)), (x - w * 0.5, y + h * 0.5)]
        for ox in (-SIZE, 0, SIZE):
            for oy in (-SIZE, 0, SIZE):
                d.polygon([(px + ox, py + oy) for px, py in pts], fill=255)
    marks = np.asarray(img.filter(ImageFilter.GaussianBlur(1.0))).astype(np.float32) / 255.0
    return v - 1.1 * marks


BARKS = {"oak": bark_oak, "birch": bark_birch, "pine": bark_pine}


def finish_bark(v, species):
    mean_t, std_t = BARK_TARGET[species]
    v = (v - v.mean()) / max(v.std(), 1e-6) * std_t + mean_t
    v = np.clip(v, 0.0, 1.0)
    hue = np.array(BARK_HUE[species], np.float32)
    hue = hue / float(hue @ np.array([0.3, 0.59, 0.11], np.float32))
    rgb = np.clip(v[..., None] * hue[None, None, :], 0.0, 1.0)
    return Image.fromarray((rgb * 255.0).astype(np.uint8), "RGB"), (float(v.mean()), float(v.std()))


PAINTERS = {"oak": spray_oak, "ash": spray_ash, "aspen": spray_aspen, "pine": spray_pine}


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    out_dir = sys.argv[1]
    sheet = []
    for i, species in enumerate(PAINTERS):
        # Leaf size is solved so the spray covers what the photo covered.
        sc = 1.0
        for _ in range(6):
            rng = np.random.default_rng(1000 + i)
            cv = Canvas()
            PAINTERS[species](cv, rng, sc)
            img, (cover, mean, std) = finish(cv, species)
            if abs(cover / TARGET[species][0] - 1.0) < 0.04:
                break
            sc *= (TARGET[species][0] / cover) ** 0.6
        img.save(f"{out_dir}/leaf_{species}.png", optimize=True)
        t = TARGET[species]
        print(f"leaf_{species}.png  cover {cover:.3f} (photo {t[0]:.3f})  value {mean:.3f} +- {std:.3f} (photo {t[1]:.3f} +- {t[2]:.3f})")
        sheet.append(img)
    for i, species in enumerate(BARKS):
        img, (mean, std) = finish_bark(BARKS[species](np.random.default_rng(2000 + i)), species)
        img.save(f"{out_dir}/bark_{species}.png", optimize=True)
        t = BARK_TARGET[species]
        print(f"bark_{species}.png  value {mean:.3f} +- {std:.3f} (photo {t[0]:.3f} +- {t[1]:.3f})")
        sheet.append(img.convert("RGBA"))
    if "--sheet" in sys.argv:
        w = Image.new("RGBA", (SIZE * len(sheet), SIZE), (40, 40, 40, 255))
        for i, im in enumerate(sheet):
            w.alpha_composite(im, (SIZE * i, 0))
        w.save(f"{out_dir}/leaf_sheet.png")


if __name__ == "__main__":
    main()
