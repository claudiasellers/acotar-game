#!/usr/bin/env python3
"""Painted blossom sprays for EZ-Tree flowering shrubs (finish plan F1 test).

An EZ-Tree leaf is a card showing a spray. With a spray of leaves AND flowers,
EZ-Tree's bushes and small trees become flowering shrubs. Unlike the leaf sprays
(gen_ez_textures.py, recoloured from value by the court shader), these carry
their own colour: the court's leaf greens (the mixed wood's shadow, mid and
light, wcterrain-28) and the flower's colour, drawn with the shader's
painted = 0 path.

    rose       five-leaflet leaves, open blooms and buds (blush pink)
    lilac      heart leaves, cone panicles of tiny four-petal florets
    hydrangea  broad leaves, round mophead heads (periwinkle to lilac)

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
    "rose": [(0.86, 0.52, 0.62), (0.95, 0.72, 0.78), (0.99, 0.88, 0.90)],
    "lilac": [(0.56, 0.44, 0.72), (0.72, 0.60, 0.86), (0.88, 0.80, 0.96)],
    "hydrangea": [(0.50, 0.56, 0.84), (0.68, 0.70, 0.94), (0.86, 0.84, 0.98)],
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


def rose_bloom(cv, c, r, cols, rng):
    for k, (f, t) in enumerate([(1.0, 0.0), (0.78, 0.35), (0.56, 0.6), (0.34, 0.85)]):
        off = (rng.uniform(-1, 1) * r * 0.06, rng.uniform(-1, 1) * r * 0.06 - k * r * 0.04)
        cv.disc((c[0] + off[0], c[1] + off[1]), r * f, rgb(mix(cols[0], cols[2], t)))
    # The swirl at the heart.
    for k in range(3):
        a0 = rng.uniform(0, math.tau)
        pts = [(c[0] + math.cos(a0 + t * 2.4) * r * (0.3 - 0.08 * t), c[1] - r * 0.15 + math.sin(a0 + t * 2.4) * r * (0.3 - 0.08 * t)) for t in np.linspace(0, 1, 8)]
        cv.line(pts, max(1.0, r * 0.07), rgb(cols[0], 0.85))


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


def spray_rose(cv, rng):
    cols = FLOWERS["rose"]
    main = twig(rng)
    cv.line(main, 4.0, rgb(STEM))
    branches = [main] + side(cv, main, rng, 4, 150)
    for br in branches:
        for k in range(4):  # compound leaves: a leaflet pair or two and a tip
            q, qa = along(br, 0.2 + 0.18 * k)
            s = 1 if k % 2 == 0 else -1
            ra = qa + s * 1.0
            for j, f in enumerate((0.0, 0.45, 0.85)):
                p = (q[0] + math.cos(ra) * 30 * f, q[1] + math.sin(ra) * 30 * f)
                for t in ((-1, 1) if j < 2 else (0,)):
                    leaf(cv, "ash", p, ra + t * 0.9, 34, 19, rng)
    for br in branches:
        p, a = along(br, 1.0)
        rose_bloom(cv, p, rng.uniform(26, 34), cols, rng)
        if rng.uniform() < 0.7:
            q, _ = along(br, 0.7)
            q = (q[0] + rng.uniform(-14, 14), q[1] - 8)
            cv.disc(q, 9, rgb(cols[0], 0.92))  # a bud
            cv.disc((q[0], q[1] + 7), 6, rgb(MID))


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


PAINTERS = {"rose": spray_rose, "lilac": spray_lilac, "hydrangea": spray_hydrangea}


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
