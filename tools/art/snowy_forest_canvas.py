#!/usr/bin/env python3
"""Paints Feyre's "snowy forest" canvas: the one Tamlin keeps (ch22 [C]).

Keeper 2026-11-02: if none of the player's own canvases is wintry, she still
has this one, "a hazy landscape of snow and skeletal trees", because his line
("That was your forest. Where you hunted") depends on it. It reads as her
hand: loose, layered strokes, a human winter remembered in Spring.

    python3 tools/art/snowy_forest_canvas.py
Out: art/calanmai/snowy_forest_canvas.webp (1024 x 768, the studio canvas size).
Deterministic (seeded).
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 1024, 768
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "calanmai", "snowy_forest_canvas.webp")
rng = random.Random(1222)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main():
    img = Image.new("RGB", (W, H))
    px = np.zeros((H, W, 3), np.float32)
    sky_top, sky_low = (178, 186, 204), (226, 224, 226)
    for y in range(H):
        t = min(1.0, y / (H * 0.62))
        px[y, :] = lerp(sky_top, sky_low, t)
    img = Image.fromarray(px.astype(np.uint8))
    d = ImageDraw.Draw(img, "RGBA")
    # far hills and the haze of the far trees
    for k, (base, col, a) in enumerate(((0.52, (160, 166, 184), 150), (0.58, (138, 144, 164), 170))):
        pts = [(0, H)]
        for x in range(0, W + 32, 32):
            pts.append((x, H * base + 22 * math.sin(x * 0.006 + k * 2) + rng.uniform(-6, 6)))
        pts.append((W, H))
        d.polygon(pts, fill=col + (a,))
        for i in range(160):
            x = rng.uniform(0, W)
            y = H * base + rng.uniform(-40, 10)
            h = rng.uniform(40, 110)
            d.line([(x, y), (x + rng.uniform(-3, 3), y - h)], fill=col + (90,), width=2)
    img = img.filter(ImageFilter.GaussianBlur(3.5))
    d = ImageDraw.Draw(img, "RGBA")
    # snow ground in broad strokes
    for i in range(900):
        y = rng.uniform(H * 0.6, H)
        x = rng.uniform(-40, W)
        L = rng.uniform(40, 180)
        shade = rng.uniform(222, 250)
        c = (int(shade), int(shade + rng.uniform(-3, 2)), int(min(255, shade + rng.uniform(2, 10))), 120)
        d.line([(x, y), (x + L, y + rng.uniform(-4, 4))], fill=c, width=int(rng.uniform(4, 10)))
    img = img.filter(ImageFilter.GaussianBlur(2.2))
    d = ImageDraw.Draw(img, "RGBA")
    # skeletal trees: dark trunks with forked bare branches, nearer = darker and larger
    def branch(x, y, ang, length, width, col, depth):
        if depth == 0 or length < 6:
            return
        x2 = x + math.cos(ang) * length
        y2 = y - math.sin(ang) * length
        d.line([(x, y), (x2, y2)], fill=col, width=max(1, int(width)))
        for s in (-1, 1):
            if rng.random() < 0.82:
                branch(x2, y2, ang + s * rng.uniform(0.25, 0.7), length * rng.uniform(0.55, 0.75), width * 0.62, col, depth - 1)
    for layer, (n, scale, col) in enumerate(((14, 0.55, (110, 112, 128, 150)), (9, 0.85, (78, 76, 88, 210)),
                                             (5, 1.25, (52, 46, 56, 245)))):
        for i in range(n):
            x = rng.uniform(20, W - 20)
            base = H * (0.6 + 0.09 * layer) + rng.uniform(-10, 18)
            trunk = rng.uniform(190, 320) * scale
            wdt = rng.uniform(4, 14) * scale
            lean = rng.uniform(-10, 10) * scale
            d.polygon([(x - wdt * 0.6, base), (x + wdt * 0.6, base), (x + lean + wdt * 0.12, base - trunk),
                       (x + lean - wdt * 0.12, base - trunk)], fill=col)
            for j in range(5):
                yb = base - trunk * rng.uniform(0.35, 0.95)
                branch(x, yb, math.pi / 2 + rng.choice((-1, 1)) * rng.uniform(0.5, 1.0), trunk * 0.32, wdt * 0.55, col, 4)
            d.ellipse([x - 26 * scale, base - 5, x + 26 * scale, base + 7], fill=(196, 198, 214, 120))
    # falling snow, and a haze over everything
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(700):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(1.0, 3.2)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(250, 250, 255, int(rng.uniform(90, 200))))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r in range(14, 0, -1):                   # a low winter sun behind the haze, upper left
        gd.ellipse([180 - r * 30, 150 - r * 22, 180 + r * 30, 150 + r * 22], fill=(255, 226, 196, 7))
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    haze = Image.new("RGBA", (W, H), (236, 234, 240, 46))
    img = Image.alpha_composite(img.convert("RGBA"), haze).convert("RGB")
    # canvas weave
    a = np.asarray(img).astype(np.float32)
    yy, xx = np.mgrid[0:H, 0:W]
    weave = (np.sin(xx * 1.9) * np.sin(yy * 1.9)) * 4.0
    a = np.clip(a + weave[..., None], 0, 255).astype(np.uint8)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(a).save(OUT, "WEBP", quality=88)
    print("wrote", os.path.relpath(OUT, ROOT), os.path.getsize(OUT), "bytes")


if __name__ == "__main__":
    main()
