"""Screen-edge masks and effect sprites (plan §15 D).

The big full-screen maps are REVEAL MAPS: greyscale, 0 = appears first,
255 = never. The one edge shader shows a pixel when `value < strength`, so a
single texture gives thorns, frost or veins that creep in from the edges as
the stat rises, and thicken as they come (the soft rim of each line is paler).
"""
import math
import random

import numpy as np
from PIL import Image

from va_common import HORROR, SPRING, circ, ell, f, g, line, path, pol, pts_d, star4, star5, svg

H = HORROR
W, HH = 2048, 1152


def add(out, name, w, h, body, defs="", **kw):
    out[name] = dict({"w": w, "h": h, "svg": svg(w, h, body, defs)}, **kw)


def to_l(img):
    return img.convert("RGB").convert("L")


class Growth:
    """Branching lines whose grey value is how far they have crept from their seed."""

    def __init__(self, seed, reach):
        self.rng = random.Random(seed)
        self.reach = reach
        self.buckets = {}
        self.polys = {}

    def seg(self, x0, y0, x1, y1, wd, dist):
        v = min(31, int(32 * min(0.999, dist / self.reach)))
        key = (v, round(wd * 2) / 2)
        self.buckets.setdefault(key, []).append(f"M{f(x0)} {f(y0)}L{f(x1)} {f(y1)}")

    def poly(self, pts, dist):
        v = min(31, int(32 * min(0.999, dist / self.reach)))
        self.polys.setdefault(v, []).append(pts_d(pts, True))

    def walk(self, x, y, ang, ln, wd, depth, o, dist=0.0, curl=0.0):
        rng = self.rng
        steps = max(2, int(ln / o["step"]))
        for i in range(steps):
            t = i / steps
            ang += rng.gauss(0, o["wiggle"]) + curl
            if o.get("kink") and rng.random() < o["kink"]:
                ang += rng.choice((-1, 1)) * rng.uniform(0.3, 0.7)
            nx, ny = x + math.cos(ang) * o["step"], y + math.sin(ang) * o["step"]
            w_here = max(o["min_w"], wd * (1 - t * 0.85))
            self.seg(x, y, nx, ny, w_here, dist)
            dist += o["step"]
            if o.get("thorn") and i % o["thorn"] == o["thorn"] - 1:
                side = 1 if (i // o["thorn"]) % 2 else -1
                px, py = -math.sin(ang) * side, math.cos(ang) * side
                L = w_here * o["thorn_len"] * rng.uniform(0.8, 1.3)
                tip = (nx + px * L + math.cos(ang) * L * 0.5, ny + py * L + math.sin(ang) * L * 0.5)
                self.poly([(nx - math.cos(ang) * w_here, ny - math.sin(ang) * w_here), tip,
                           (nx + math.cos(ang) * w_here, ny + math.sin(ang) * w_here)], dist)
            if o.get("star") and depth <= 1 and rng.random() < o["star"]:
                R = rng.uniform(5, 13)
                k = R * 0.16
                self.poly([(nx, ny - R), (nx + k, ny - k), (nx + R, ny), (nx + k, ny + k), (nx, ny + R), (nx - k, ny + k), (nx - R, ny), (nx - k, ny - k)], dist)
            if depth > 0:
                if o.get("regular"):
                    if i % o["regular"] == o["regular"] - 1:
                        for s in (-1, 1):
                            self.walk(nx, ny, ang + s * o["branch_ang"], ln * (1 - t) * o["branch_len"], w_here * 0.7, depth - 1, o, dist)
                elif rng.random() < o["branch_p"]:
                    s = rng.choice((-1, 1))
                    self.walk(nx, ny, ang + s * rng.uniform(0.6, 1.3) * o["branch_ang"], ln * (1 - t * 0.5) * o["branch_len"], w_here * 0.72, depth - 1, o,
                              dist, -curl)
            x, y = nx, ny

    def body(self, blur=0.0):
        out = f'<rect width="{W}" height="{HH}" fill="#FFFFFF"/>'
        inner = ""
        # Paint late (pale) first so early (dark) growth sits on top.
        for (v, wd), ds in sorted(self.buckets.items(), key=lambda kv: -kv[0][0]):
            c = int(v * 255 / 32)
            inner += f'<path d="{"".join(ds)}" fill="none" stroke="rgb({c},{c},{c})" stroke-width="{f(wd)}" stroke-linecap="round"/>'
        for v, ds in sorted(self.polys.items(), key=lambda kv: -kv[0]):
            c = int(v * 255 / 32)
            inner += f'<path d="{"".join(ds)}" fill="rgb({c},{c},{c})"/>'
        return out + (g(inner, extra='filter="url(#gb)"') if blur else inner)


def edge_seeds(rng, spacing, corner_extra=0):
    seeds = []
    x = spacing * 0.3
    while x < W:
        seeds.append((x + rng.uniform(-30, 30), -6, math.pi / 2))
        seeds.append((x + rng.uniform(-30, 30), HH + 6, -math.pi / 2))
        x += spacing * rng.uniform(0.7, 1.3)
    y = spacing * 0.3
    while y < HH:
        seeds.append((-6, y + rng.uniform(-30, 30), 0.0))
        seeds.append((W + 6, y + rng.uniform(-30, 30), math.pi))
        y += spacing * rng.uniform(0.7, 1.3)
    for cx, cy in ((0, 0), (W, 0), (0, HH), (W, HH)):
        base = math.atan2(HH / 2 - cy, W / 2 - cx)
        for _ in range(corner_extra):
            seeds.append((cx, cy, base + rng.uniform(-0.7, 0.7)))
    return seeds


def big_maps(out):
    defs = '<filter id="gb"><feGaussianBlur stdDeviation="1.1"/></filter>'
    # D5 venom: black veins crawling in from every edge.
    gr = Growth(101, 760)
    o = {"step": 13, "wiggle": 0.3, "min_w": 1.6, "branch_p": 0.17, "branch_ang": 0.75, "branch_len": 0.62}
    for x, y, a in edge_seeds(gr.rng, 135, 3):
        gr.walk(x, y, a + gr.rng.uniform(-0.5, 0.5), gr.rng.uniform(300, 640), gr.rng.uniform(7, 12), 4, o)
    add(out, "edge/venom_veins", W, HH, gr.body(1), defs, post=to_l, webp=True, quality=86)

    # D2 low health: thorn silhouettes creeping in.
    gr = Growth(202, 640)
    o = {"step": 20, "wiggle": 0.1, "min_w": 3.5, "branch_p": 0.07, "branch_ang": 0.8, "branch_len": 0.6, "thorn": 2, "thorn_len": 2.5}
    for x, y, a in edge_seeds(gr.rng, 210, 4):
        gr.walk(x, y, a + gr.rng.uniform(-0.6, 0.6), gr.rng.uniform(260, 560), gr.rng.uniform(11, 18), 2, o, curl=gr.rng.choice((-1, 1)) * gr.rng.uniform(0.03, 0.08))
    add(out, "edge/low_health_thorns", W, HH, gr.body(1), defs, post=to_l, webp=True, quality=86)

    # D3 cold: corner frost. Spring is feathery fern-rime with sparkle; Human is harsh needles.
    for skin, seed in (("spring", 303), ("human", 404)):
        gr = Growth(seed, 620)
        if skin == "spring":
            o = {"step": 12, "wiggle": 0.035, "min_w": 1.2, "regular": 3, "branch_ang": math.pi / 3, "branch_len": 0.36, "star": 0.05}
            arms, wd, depth = 13, (4, 6.5), 3
        else:
            o = {"step": 16, "wiggle": 0.0, "kink": 0.16, "min_w": 1.4, "branch_p": 0.3, "branch_ang": 0.5, "branch_len": 0.5, "thorn": 3, "thorn_len": 5.0}
            arms, wd, depth = 10, (6, 11), 2
        for cx, cy, a0 in ((0, 0, 0.0), (W, 0, math.pi / 2), (W, HH, math.pi), (0, HH, -math.pi / 2)):
            for k in range(arms):
                t = k / (arms - 1)
                ang = a0 + t * math.pi / 2
                edge_bias = abs(t - 0.5) * 2
                ln = (250 + 330 * edge_bias) * gr.rng.uniform(0.75, 1.15)
                off = gr.rng.uniform(0, 60)
                gr.walk(cx + math.cos(ang) * off, cy + math.sin(ang) * off, ang + gr.rng.uniform(-0.05, 0.05), ln, gr.rng.uniform(*wd), depth, o)
        add(out, f"edge/frost_{skin}", W, HH, gr.body(0.6), '<filter id="gb"><feGaussianBlur stdDeviation="0.6"/></filter>', post=to_l, webp=True, quality=86)

    # D11 rose iris: closes from the rim inward along rings of lapped petals.
    body = '<rect width="1024" height="1024" fill="#000"/>'
    layers = 7
    for k in range(layers):
        R = 640 * (1 - k / layers) ** 1.15 + 26
        c = int(255 * (k + 1) / layers)
        n = 9 - k if k < 5 else 5
        for i in range(n):
            x, y = pol(512, 512, R * 0.5, i * 360 / n + k * 23)
            body += circ(x, y, R * 0.58, f"rgb({c},{c},{c})")
    add(out, "edge/iris_rose", 1024, 1024, g(body, extra='filter="url(#ib)"'), '<filter id="ib"><feGaussianBlur stdDeviation="5"/></filter>',
        post=to_l, webp=True, quality=88)
    # D12 dawn iris: opens softly from the centre with faint rays.
    defs = ('<radialGradient id="dg"><stop offset="0" stop-color="#000"/><stop offset="0.55" stop-color="#8A8A8A"/><stop offset="1" stop-color="#FFF"/></radialGradient>'
            '<filter id="rb"><feGaussianBlur stdDeviation="26"/></filter>')
    body = '<rect width="1024" height="1024" fill="url(#dg)"/>'
    rays = ""
    for i in range(14):
        a0 = i * 360 / 14
        rays += path(pts_d([(512, 512), pol(512, 512, 800, a0 - 4), pol(512, 512, 800, a0 + 4)], True), "#000")
    body += g(rays, extra='filter="url(#rb)" opacity="0.2"')
    add(out, "edge/iris_dawn", 1024, 1024, body, defs, post=to_l, webp=True, quality=88)


def dread_noise():
    """D4: tileable creeping-dark noise. FFT-filtered, so it wraps cleanly."""
    rng = np.random.default_rng(55)
    n = 512
    fx = np.fft.fftfreq(n)[:, None]
    fy = np.fft.fftfreq(n)[None, :]
    fr = np.sqrt(fx * fx + fy * fy)
    fr[0, 0] = 1
    layers = []
    for power in (1.9, 1.4):
        spec = np.fft.fft2(rng.standard_normal((n, n))) / fr ** power
        spec[0, 0] = 0
        a = np.real(np.fft.ifft2(spec))
        layers.append((a - a.min()) / (a.max() - a.min()))
    ridge = 1 - np.abs(layers[1] * 2 - 1)  # smoky tendrils
    v = np.clip(layers[0] * 0.62 + ridge ** 2.2 * 0.5 - 0.1, 0, 1)
    v = (v - v.min()) / (v.max() - v.min())
    return Image.fromarray((v * 255).astype(np.uint8), "L")


def sprites(out):
    # D1 hit direction: a crimson-black bruise with thorn hairlines. Lies along the bottom edge; the game rotates it.
    rng = random.Random(66)
    defs = ('<filter id="b1"><feGaussianBlur stdDeviation="13"/></filter><filter id="b2"><feGaussianBlur stdDeviation="5"/></filter>'
            '<radialGradient id="bg" cx="0.5" cy="1" r="0.75" gradientTransform="translate(0 0) scale(1 1)"><stop offset="0" stop-color="#120C10" stop-opacity="0.95"/>'
            '<stop offset="0.45" stop-color="#5A1220" stop-opacity="0.8"/><stop offset="0.8" stop-color="#3A1E2E" stop-opacity="0.35"/>'
            '<stop offset="1" stop-color="#3A1E2E" stop-opacity="0"/></radialGradient>')
    body = ell(256, 150, 236, 122, "url(#bg)")
    blots = ""
    for _ in range(26):
        x = rng.uniform(50, 462)
        y = 128 - rng.uniform(0, 70) * (1 - abs(x - 256) / 240)
        blots += ell(x, y, rng.uniform(10, 34), rng.uniform(6, 16), rng.choice(("#7A1E2A", "#120C10", "#3A1E2E", "#A3202E", "#2A2A1A")),
                     extra=f'opacity="{rng.uniform(.25, .6):.2f}"')
    body += g(blots, extra='filter="url(#b2)"')
    hair = ""
    for _ in range(11):
        x = rng.uniform(70, 442)
        ang = -math.pi / 2 + (x - 256) / 300 + rng.uniform(-0.3, 0.3)
        px, py = x, 128
        pts = [(px, py)]
        for i in range(rng.randint(4, 8)):
            ang += rng.uniform(-0.35, 0.35)
            px, py = px + math.cos(ang) * 11, py + math.sin(ang) * 11
            pts.append((px, py))
            if i % 2:
                hair += line([(px, py), (px + math.cos(ang + 1.1) * 7, py + math.sin(ang + 1.1) * 7)], "#120C10", 1.6)
        hair += line(pts, "#120C10", 2.2)
    body += g(hair, extra='opacity="0.85"')
    add(out, "edge/hit_bruise", 512, 128, body, defs)

    # D6 drowsy: eyelids (soft alpha) and moth dust.
    defs = '<filter id="lb" x="-10%" y="-30%" width="120%" height="160%"><feGaussianBlur stdDeviation="34"/></filter>'
    add(out, "edge/eyelid_top", 1920, 540, path("M-80 -80 H2000 V250 Q960 520 -80 250Z", "#0A0608", extra='filter="url(#lb)"'), defs, webp=True, quality=90)
    add(out, "edge/eyelid_bottom", 1920, 540, path("M-80 620 H2000 V330 Q960 130 -80 330Z", "#0A0608", extra='filter="url(#lb)"'), defs, webp=True, quality=90)
    rng = random.Random(77)
    body = ""
    for v in range(4):
        fr = ""
        for _ in range(7 + v * 2):
            x, y = rng.gauss(32, 9), rng.gauss(32, 9)
            fr += ell(x, y, rng.uniform(1.2, 4.5), rng.uniform(1, 3), rng.choice(("#CFC6D8", "#A9A2B0", "#E6DFEA")), extra=f'opacity="{rng.uniform(.4, .9):.2f}"')
        body += g(fr, f"translate({v * 64} 0)", 'filter="url(#md)"')
    add(out, "fx/moth_dust", 256, 64, body, '<filter id="md"><feGaussianBlur stdDeviation="0.7"/></filter>')

    # D7 sparkle (shared by fae-toll, ease, healing): 8 frames of one twinkle, white so the game tints it.
    defs = '<filter id="sg" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="5"/></filter>'
    body = ""
    for i in range(8):
        s = math.sin(math.pi * (i + 0.5) / 8)
        fr = g(star4(64, 64, 50 * s + 5, "#FFFFFF", rot=i * 6), extra='filter="url(#sg)" opacity="0.7"')
        fr += star4(64, 64, 50 * s + 5, "#FFFFFF", rot=i * 6) + star4(64, 64, 20 * s + 2, "#FFFFFF", rot=45 + i * 6, pinch=0.2)
        body += g(fr, f"translate({i * 128} 0)")
    add(out, "fx/sparkle_sheet", 1024, 128, body, defs)

    # D9 petals: six variants in the candy enamels.
    p = SPRING
    body = ""
    shapes = ["M64 14 Q104 48 86 96 Q64 122 44 96 Q22 50 64 14Z", "M60 12 Q112 40 92 92 Q72 118 50 104 Q18 60 60 12Z",
              "M70 16 Q98 60 80 104 Q58 118 46 92 Q30 44 70 16Z"]
    for i, col in enumerate(("rose", "blush", "lilac", "butter", "pearl", "mint")):
        d = shapes[i % 3]
        base = p[col]
        fr = path(d, base) + path("M62 34 Q78 62 68 98", "none", "#FFFFFF", 7, 'opacity="0.55"')
        fr += path("M54 104 Q64 116 76 104 Q64 96 54 104Z", p["deep"] if col in ("rose", "blush") else p["gold"], extra='opacity="0.45"')
        body += g(fr, f"translate({i * 128} 0) rotate({(-25, 18, 40, -8, 30, -40)[i]} 64 64)")
    add(out, "fx/petals", 768, 128, body)

    # D11 seeing stars: gold and white, 4- and 5-point, 8 frames.
    body = ""
    for i in range(8):
        s = 0.55 + 0.45 * math.sin(math.pi * 2 * i / 8)
        s2 = 0.55 + 0.45 * math.sin(math.pi * 2 * i / 8 + 2.2)
        fr = g(star5(52, 60, 40 * s + 6, p["butter"], rot=i * 9), extra='filter="url(#sg)" opacity="0.6"')
        fr += star5(52, 60, 40 * s + 6, p["butter"], p["gold"], 3, rot=i * 9)
        fr += star4(100, 34, 22 * s2 + 4, "#FFFFFF", p["gold"], 2, rot=-i * 7) + star4(96, 102, 14 * (1 - s) + 4, "#FFFFFF", p["gold_lt"], 1.5)
        body += g(fr, f"translate({i * 128} 0)")
    add(out, "fx/seeing_stars_sheet", 1024, 128, body, defs)


def build(out):
    big_maps(out)
    sprites(out)
    out["edge/dread_noise"] = {"image": dread_noise()}
