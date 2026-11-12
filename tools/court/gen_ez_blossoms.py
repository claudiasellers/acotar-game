#!/usr/bin/env python3
"""Painted blossom sprays for EZ-Tree flowering shrubs (finish plan F1 test).

An EZ-Tree leaf is a card showing a spray. With a spray of leaves AND flowers,
EZ-Tree's bushes and small trees become flowering shrubs. Unlike the leaf sprays
(gen_ez_textures.py, recoloured from value by the court shader), these carry
their own colour: the court's leaf greens (the mixed wood's shadow, mid and
light, wcterrain-28) and the flower's colour, drawn with the shader's
painted = 0 path.

    rose       garden rose: compound leaves, cupped blooms spiralling in, buds
    wildrose   dog rose: five flat notched petals, gold stamens (the Rosewild)
    lilac      heart leaves, cone panicles of tiny four-petal florets
    hydrangea  broad leaves, round mophead heads (periwinkle to lilac)
    cherry     the estate's cotton-candy cherry: bare twigs smothered in
               five-petal blossom clusters, a few bronze-green new leaves
    apple      apple blossom: white cups blushed pink, pink buds, fresh leaves

    python3 tools/court/gen_ez_blossoms.py <out dir> [--sheet]

Deterministic (fixed seeds). Needs Pillow and numpy.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from gen_ez_textures import along, bezier, leaf_outline, place  # noqa: E402

SIZE = 512
SS = 2
# The mixed wood's leaf palette (sRGB), wcterrain-28.
SHADOW = (0.17, 0.32, 0.21)
MID = (0.27, 0.48, 0.30)
LIGHT = (0.46, 0.64, 0.38)
STEM = (0.30, 0.26, 0.22)
FLOWERS = {
    "rose": [(0.80, 0.36, 0.50), (0.93, 0.62, 0.70), (0.99, 0.86, 0.88)],
    "wildrose": [(0.90, 0.58, 0.68), (0.97, 0.78, 0.83), (1.0, 0.92, 0.93)],
    "lilac": [(0.56, 0.44, 0.72), (0.72, 0.60, 0.86), (0.88, 0.80, 0.96)],
    "hydrangea": [(0.50, 0.56, 0.84), (0.68, 0.70, 0.94), (0.86, 0.84, 0.98)],
    # the estate's cotton candy (manor flora: cherry (1.0, 0.75, 0.86), apple (1.0, 0.90, 0.92))
    "cherry": [(0.90, 0.52, 0.70), (0.99, 0.74, 0.86), (1.0, 0.90, 0.95)],
    "apple": [(0.90, 0.62, 0.70), (0.99, 0.90, 0.91), (1.0, 0.98, 0.97)],
}


def rgb(c, k=1.0):
    return tuple(int(max(0, min(1, v * k)) * 255) for v in c) + (255,)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def poly(self, pts, col):
        self.d.polygon([(x * SS, y * SS) for x, y in pts], fill=col)

    def line(self, pts, w, col):
        self.d.line([(x * SS, y * SS) for x, y in pts], fill=col, width=max(1, int(w * SS)), joint="curve")

    def disc(self, c, r, col):
        self.d.ellipse([(c[0] - r) * SS, (c[1] - r) * SS, (c[0] + r) * SS, (c[1] + r) * SS], fill=col)

    def finish(self):
        img = self.img.resize((SIZE, SIZE), Image.LANCZOS)
        a = np.asarray(img).astype(np.float32)
        # Edge pixels: undo the dark fringe the transparent black brings.
        alpha = a[..., 3:4] / 255.0
        a[..., :3] = np.where(alpha > 0.02, a[..., :3] / np.maximum(alpha, 0.02), 0)
        a[..., 3] = np.where(alpha[..., 0] > 0.45, 255, 0)
        return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def leaf(cv, kind, at, ang, length, width, rng):
    tone = rng.uniform(-0.15, 0.15)
    out = leaf_outline(kind, length, width, rng)
    cv.poly(place(out, at, ang), rgb(mix(SHADOW, MID, 0.4 + tone)))
    cv.poly(place([(x * 0.92 + length * 0.08, y * 0.78) for x, y in out], at, ang), rgb(mix(MID, LIGHT, 0.2 + tone)))
    cv.poly(place([(x * 0.55 + length * 0.42, y * 0.5 + width * 0.06) for x, y in out], at, ang), rgb(mix(MID, LIGHT, 0.8 + tone)))
    cv.line(place([(length * 0.05, 0), (length * 0.85, 0)], at, ang), max(1.0, width * 0.05), rgb(SHADOW))


def floret(cv, c, r, cols, rng, petals=4):
    rot = rng.uniform(0, math.tau)
    shade = rng.uniform(0, 1)
    base = mix(cols[0], cols[1], shade)
    for k in range(petals):
        a = rot + math.tau * k / petals
        p = (c[0] + math.cos(a) * r * 0.55, c[1] + math.sin(a) * r * 0.55)
        cv.disc(p, r * 0.55, rgb(base))
    cv.disc((c[0] - r * 0.12, c[1] - r * 0.12), r * 0.42, rgb(mix(base, cols[2], 0.5)))
    cv.disc(c, r * 0.16, rgb(mix(cols[0], (0.9, 0.85, 0.5), 0.4)))


def petal(cv, c, ang, length, width, light, dark, notch=False):
    """A rounded petal from the flower's heart outward: dark at the base,
    light at the rim (a cupped petal catches the light on its edge)."""
    pts = []
    for i in range(25):
        t = i / 24.0
        th = math.pi * (t - 0.5)  # -90 .. 90 degrees across the petal's end
        r = length * (0.55 + 0.45 * math.cos(th) ** 0.5)
        if notch:
            r *= 1.0 - 0.18 * math.exp(-(th / 0.25) ** 2)
        pts.append((r * math.cos(th) * 1.0, r * math.sin(th) * width / length))
    pts = [(0.0, -width * 0.18)] + pts + [(0.0, width * 0.18)]
    cv.poly(place(pts, c, ang), rgb(light))
    inner = [(x * 0.72, y * 0.72) for x, y in pts]
    cv.poly(place(inner, c, ang), rgb(mix(dark, light, 0.45)))
    base = [(x * 0.42, y * 0.42) for x, y in pts]
    cv.poly(place(base, c, ang), rgb(dark))
    # The petal's edge, so overlapping petals read apart.
    edge = place(pts[1:-1], c, ang)
    cv.line(edge, max(1.0, length * 0.05), rgb(mix(dark, light, 0.25)))


def rose_bloom(cv, c, r, cols, rng):
    """A garden rose seen from above: a scalloped ring of broad outer petals,
    a second ring between them, then curled cup petals round a deep heart."""
    deep = mix(cols[0], (0.55, 0.18, 0.30), 0.35)
    rot = rng.uniform(0, math.tau)
    for k in range(6):
        petal(cv, c, rot + math.tau * k / 6, r, r * 0.85, mix(cols[1], cols[2], 0.55), cols[0])
    for k in range(5):
        petal(cv, c, rot + math.tau * (k + 0.5) / 5, r * 0.7, r * 0.62, cols[1], deep)
    for k in range(4):  # cup petals: crescents, each lit on its outer lip
        a = rot + 0.6 + k * math.tau / 4
        rr = r * (0.36 - 0.05 * k)
        arc = [(c[0] + math.cos(a + t) * rr, c[1] + math.sin(a + t) * rr) for t in np.linspace(-1.1, 1.1, 10)]
        cv.line(arc, max(1.5, r * 0.16), rgb(mix(cols[0], cols[1], 0.5)))
        cv.line([(c[0] + (x - c[0]) * 1.08, c[1] + (y - c[1]) * 1.08) for x, y in arc], max(1.0, r * 0.06), rgb(cols[2]))
    cv.disc(c, r * 0.12, rgb(deep, 0.75))


def rose_bud(cv, p, ang, r, cols):
    """A half-open bud: a closed teardrop of petal over green sepals."""
    tear = [(0, 0)] + [(r * (1 - math.cos(t)) * 1.1, r * 0.55 * math.sin(t)) for t in np.linspace(0.2, math.pi - 0.2, 12)]
    cv.poly(place([(x * 1.15, y * 1.5) for x, y in tear], p, ang), rgb(MID))
    cv.poly(place(tear, p, ang), rgb(cols[0]))
    cv.poly(place([(x * 0.6 + r * 0.6, y * 0.5) for x, y in tear], p, ang), rgb(cols[1]))


def wild_rose(cv, c, r, cols, rng):
    """A dog rose: five flat notched petals and a ring of gold stamens."""
    rot = rng.uniform(0, math.tau)
    for k in range(5):
        petal(cv, c, rot + math.tau * k / 5, r, r * 1.15, cols[2], cols[1], notch=True)
    cv.disc(c, r * 0.3, rgb((0.92, 0.80, 0.36)))
    for k in range(14):
        a = math.tau * k / 14
        cv.disc((c[0] + math.cos(a) * r * 0.32, c[1] + math.sin(a) * r * 0.32), max(1.0, r * 0.07), rgb((0.80, 0.58, 0.20)))
    cv.disc(c, r * 0.14, rgb((0.70, 0.78, 0.40)))


def twig(rng, bend=26.0, top_y=22.0):
    top = (SIZE / 2 + rng.uniform(-bend, bend), top_y)
    mid = (SIZE / 2 + rng.uniform(-bend, bend) * 1.3, SIZE * 0.5)
    return bezier((SIZE / 2, SIZE - 1.0), mid, top)


def side(cv, main, rng, n, reach, t0=0.18, t1=0.82):
    out = []
    for k in range(n):
        t = t0 + (t1 - t0) * k / max(n - 1, 1)
        p, a = along(main, t)
        s = 1 if k % 2 == 0 else -1
        ba = a + s * rng.uniform(0.55, 0.9)
        bl = reach * (1.0 - 0.4 * t) * rng.uniform(0.85, 1.1)
        end = (p[0] + math.cos(ba) * bl, p[1] + math.sin(ba) * bl)
        br = bezier(p, ((p[0] + end[0]) / 2 + s * 6, (p[1] + end[1]) / 2 - 8), end, 12)
        cv.line(br, 2.5, rgb(STEM))
        out.append(br)
    return out


def rose_leaves(cv, branches, rng, size=1.0):
    for br in branches:
        for k in range(4):  # compound leaves: leaflet pairs and a tip leaflet
            q, qa = along(br, 0.2 + 0.18 * k)
            s = 1 if k % 2 == 0 else -1
            ra = qa + s * 1.0
            for j, f in enumerate((0.0, 0.45, 0.85)):
                p = (q[0] + math.cos(ra) * 30 * f * size, q[1] + math.sin(ra) * 30 * f * size)
                for t in ((-1, 1) if j < 2 else (0,)):
                    leaf(cv, "ash", p, ra + t * 0.9, 34 * size, 19 * size, rng)


def spray_rose(cv, rng):
    cols = FLOWERS["rose"]
    main = twig(rng, 24, 70.0)
    cv.line(main, 4.0, rgb(STEM))
    branches = [main] + side(cv, main, rng, 5, 150)
    rose_leaves(cv, branches, rng, 0.85)
    # A bush in full flower (owner 2026-11-11: it should read as roses, not a
    # green shrub with pink flecks): a cluster of three or four big blooms at
    # every tip and a bloom or a bud at every joint, so pink outweighs green.
    for i, br in enumerate(branches):
        p, a = along(br, 1.0)
        n = 3 + (i % 2)
        for k in range(n):
            ang = a + math.tau * k / n + rng.uniform(-0.3, 0.3)
            off = 0.0 if k == 0 else rng.uniform(22, 30)
            c = (p[0] + math.cos(ang) * off, p[1] + math.sin(ang) * off)
            rose_bloom(cv, c, rng.uniform(26, 34) if k == 0 else rng.uniform(20, 27), cols, rng)
        for t in (0.45, 0.7):
            q, qa = along(br, t)
            q = (q[0] + rng.uniform(-16, 16), q[1] - 6)
            if rng.uniform() < 0.35:
                rose_bud(cv, q, qa + rng.uniform(-0.6, 0.6), rng.uniform(11, 14), cols)
            else:
                rose_bloom(cv, q, rng.uniform(19, 25), cols, rng)


def spray_wildrose(cv, rng):
    cols = FLOWERS["wildrose"]
    main = twig(rng, 30, 60.0)
    cv.line(main, 3.5, rgb(STEM))
    branches = [main] + side(cv, main, rng, 6, 160)
    rose_leaves(cv, branches, rng, 0.9)
    for br in branches:
        for t in (1.0, 0.62):
            p, a = along(br, t)
            wild_rose(cv, (p[0] + rng.uniform(-12, 12), p[1] + rng.uniform(-8, 8)), rng.uniform(17, 24), cols, rng)


def spray_lilac(cv, rng):
    cols = FLOWERS["lilac"]
    main = twig(rng, 18, 150.0)  # room above for the tip's panicle
    cv.line(main, 3.5, rgb(STEM))
    branches = [main] + side(cv, main, rng, 3, 130, 0.3, 0.75)
    for br in branches:
        for k in range(4):
            p, a = along(br, 0.15 + 0.16 * k)
            s = 1 if k % 2 == 0 else -1
            leaf(cv, "aspen", p, a + s * 1.0, 52, 46, rng)
    for br in branches:  # a cone panicle at each tip, pointing on along the twig
        tip, a = along(br, 1.0)
        length = rng.uniform(95, 130)
        for i in range(260):
            t = rng.uniform(0, 1) ** 0.8
            w = (1 - t) * length * 0.32
            off = rng.uniform(-1, 1) * w
            p = (tip[0] + math.cos(a) * t * length - math.sin(a) * off,
                 tip[1] + math.sin(a) * t * length + math.cos(a) * off)
            floret(cv, p, rng.uniform(5.5, 8.0), cols, rng)


def spray_hydrangea(cv, rng):
    cols = FLOWERS["hydrangea"]
    main = twig(rng, 16, 130.0)  # room above for the tip's head
    cv.line(main, 4.5, rgb(STEM))
    branches = [main] + side(cv, main, rng, 2, 120, 0.35, 0.7)
    for br in branches:
        for k in range(3):
            p, a = along(br, 0.2 + 0.22 * k)
            s = 1 if k % 2 == 0 else -1
            leaf(cv, "aspen", p, a + s * 0.95, 74, 52, rng)
    for br in branches:
        c, a = along(br, 1.0)
        R = rng.uniform(62, 78)
        c = (c[0] + math.cos(a) * R * 0.5, c[1] + math.sin(a) * R * 0.5)
        cv.disc(c, R * 0.96, rgb(cols[0], 0.8))
        for i in range(340):
            rr = R * math.sqrt(rng.uniform(0, 1))
            th = rng.uniform(0, math.tau)
            p = (c[0] + math.cos(th) * rr, c[1] + math.sin(th) * rr)
            floret(cv, p, rng.uniform(8, 11), cols, rng)


def blossom5(cv, c, r, cols, rng, heart=(0.98, 0.82, 0.55)):
    """A five-petal fruit blossom: round, slightly notched petals, a pale
    heart and a few stamens."""
    rot = rng.uniform(0, math.tau)
    shade = rng.uniform(0.0, 1.0)
    rim = mix(cols[1], cols[2], shade)
    base = mix(cols[0], cols[1], shade * 0.5)
    for k in range(5):
        petal(cv, c, rot + math.tau * k / 5, r, r * 1.2, rim, base, notch=True)
    cv.disc(c, r * 0.24, rgb(mix(base, heart, 0.5)))
    for k in range(7):
        a = rot + math.tau * k / 7
        cv.disc((c[0] + math.cos(a) * r * 0.24, c[1] + math.sin(a) * r * 0.24), max(1.0, r * 0.06), rgb(mix(cols[0], (0.75, 0.45, 0.35), 0.5)))


def fruit_spray(cv, rng, cols, leaves, buds):
    main = twig(rng, 30, 40.0)
    cv.line(main, 4.0, rgb((0.42, 0.30, 0.30)))
    branches = [main] + side(cv, main, rng, 6, 170)
    for br in branches:
        for k in range(leaves):
            p, a = along(br, 0.25 + 0.5 * k / max(leaves, 1))
            s = 1 if k % 2 == 0 else -1
            leaf(cv, "aspen", p, a + s * 0.9, 34, 22, rng)
    # Blossom all along every twig, densest at the tips, so the spray reads
    # as a puff of colour, not a twig with flecks.
    for br in branches:
        for t in np.linspace(0.3, 1.0, 6):
            p, a = along(br, float(t))
            n = 3 if t < 0.95 else 5
            for k in range(n):
                ang = rng.uniform(0, math.tau)
                off = 0.0 if k == 0 else rng.uniform(12, 24)
                c = (p[0] + math.cos(ang) * off, p[1] + math.sin(ang) * off)
                if buds and rng.uniform() < 0.18:
                    cv.disc(c, rng.uniform(6, 8), rgb(cols[0]))
                    cv.disc((c[0] - 1.5, c[1] - 1.5), rng.uniform(3, 4), rgb(cols[1]))
                else:
                    blossom5(cv, c, rng.uniform(13, 19), cols, rng)


def spray_cherry(cv, rng):
    fruit_spray(cv, rng, FLOWERS["cherry"], 1, False)


def spray_apple(cv, rng):
    fruit_spray(cv, rng, FLOWERS["apple"], 3, True)


PAINTERS = {"rose": spray_rose, "wildrose": spray_wildrose, "lilac": spray_lilac, "hydrangea": spray_hydrangea, "cherry": spray_cherry, "apple": spray_apple}


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    out = sys.argv[1]
    sheet = []
    for i, name in enumerate(PAINTERS):
        cv = Canvas()
        PAINTERS[name](cv, np.random.default_rng(3000 + i))
        img = cv.finish()
        img.save(f"{out}/blossom_{name}.png", optimize=True)
        a = np.asarray(img)[..., 3] > 127
        print(f"blossom_{name}.png  cover {a.mean():.3f}")
        sheet.append(img)
    if "--sheet" in sys.argv:
        w = Image.new("RGBA", (SIZE * len(sheet), SIZE), (40, 40, 40, 255))
        for i, im in enumerate(sheet):
            w.alpha_composite(im, (SIZE * i, 0))
        w.save(f"{out}/blossom_sheet.png")


if __name__ == "__main__":
    main()
