#!/usr/bin/env python3
"""Paints the satchel page's handmade materials (L50): a wool twill weave for
the cloak, a watercolour wash and a stitched linen patch.

All are generated (fixed seeds), so to change the look edit PALETTE below and
re-run:  python3 tools/ui/build_satchel_crafted.py
Output: ui/satchel/crafted/*.png, loaded by ui/satchel/satchel_table.gd.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "ui", "satchel", "crafted")

# R3 manor palette: blush leather, ivory paper, gilt, plum ink.
PALETTE = {
    "leather": (196, 138, 128),       # dusty blush leather
    "leather_on": (214, 120, 140),    # the open pocket: rose leather
    "leather_dark": (120, 70, 72),
    "thread": (250, 236, 210),        # cream linen thread
    "paper": (251, 245, 232),         # ivory
    "paper_edge": (226, 208, 176),
    "gilt": (212, 169, 79),
    "gilt_dark": (150, 108, 40),
    "ink": (90, 46, 68),
    "enamel": (244, 214, 222),        # blush enamel
    "wash": (244, 166, 192),          # rose watercolour
}


def noise(w, h, scale, seed):
    """Smooth value noise in 0..1."""
    np.random.seed(seed)
    gw, gh = max(2, int(w / scale) + 2), max(2, int(h / scale) + 2)
    g = Image.fromarray((np.random.rand(gh, gw) * 255).astype(np.uint8))
    return np.asarray(g.resize((w, h), Image.BICUBIC), dtype=np.float32) / 255.0


def stitches(draw, box, r, color, dash=7, gap=5, width=2):
    """A running stitch along a rounded rectangle's inset path."""
    x0, y0, x1, y1 = box
    pts = []
    # Walk the perimeter (straight runs; corners as arcs).
    def arc(cx, cy, a0, a1):
        steps = 12
        for i in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * i / steps)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    arc(x0 + r, y0 + r, 180, 270)
    arc(x1 - r, y0 + r, 270, 360)
    arc(x1 - r, y1 - r, 0, 90)
    arc(x0 + r, y1 - r, 90, 180)
    pts.append(pts[0])
    # Resample by length into dashes.
    seg = []
    for i in range(len(pts) - 1):
        seg.append((pts[i], pts[i + 1]))
    t = 0.0
    on = True
    run = dash
    for (a, b) in seg:
        L = math.dist(a, b)
        pos = 0.0
        while pos < L:
            step = min(run - t, L - pos)
            p0 = (a[0] + (b[0] - a[0]) * pos / L, a[1] + (b[1] - a[1]) * pos / L)
            p1 = (a[0] + (b[0] - a[0]) * (pos + step) / L, a[1] + (b[1] - a[1]) * (pos + step) / L)
            if on:
                draw.line([p0, p1], fill=color, width=width)
            pos += step
            t += step
            if t >= run - 1e-6:
                t = 0.0
                on = not on
                run = dash if on else gap


def weave(name="cloak_weave", s=256, seed=41):
    """Wool twill, near-white so the theme's paper colour tints it: diagonal
    ribs, a slubby yarn texture and soft fibre fuzz. Tiles seamlessly."""
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    period = 8.0
    rib = 0.5 + 0.5 * np.sin(2 * math.pi * (xx + yy) / period)
    cross = 0.5 + 0.5 * np.sin(2 * math.pi * (xx - yy * 0.0) / (period * 0.5))
    # Seamless slub noise: wrap by tiling a smaller noise.
    small = noise(64, 64, 6, seed)
    slub = np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((s, s), Image.BICUBIC), dtype=np.float32) / 255.0
    np.random.seed(seed + 1)
    fuzz = np.random.rand(s, s).astype(np.float32)
    fuzz = np.asarray(Image.fromarray((fuzz * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float32) / 255.0
    v = 0.86 + 0.07 * rib + 0.025 * cross + 0.04 * (slub - 0.5) + 0.03 * (fuzz - 0.5)
    v = np.clip(v, 0, 1)
    tint = np.array([1.0, 0.985, 0.975], dtype=np.float32)
    rgb = (v[..., None] * tint[None, None, :] * 255).astype(np.uint8)
    Image.fromarray(rgb, "RGB").save(os.path.join(OUT, name + ".png"))


def wash(name="wash_bloom", s=256, seed=51):
    """A watercolour bloom (alpha only; tinted at use) for under the hero."""
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    dist = np.sqrt((xx - s / 2) ** 2 + (yy - s / 2) ** 2) / (s * 0.45)
    wob = noise(s, s, 22, seed) * 0.35 + noise(s, s, 6, seed + 1) * 0.08
    d = dist + wob - 0.15
    body = np.clip(1 - d, 0, 1) ** 0.7 * 0.55
    tide = np.exp(-((d - 1.0) ** 2) / 0.0035) * 0.65
    a = np.clip(body + tide, 0, 1)
    a *= np.clip((1.12 - d) * 8, 0, 1)
    rgb = np.full((s, s, 3), 255, np.uint8)
    img = Image.fromarray(rgb, "RGB").convert("RGBA")
    img.putalpha(Image.fromarray((a * 255).astype(np.uint8)))
    img.save(os.path.join(OUT, name + ".png"))


def linen_patch(name="patch_linen", s=192, seed=61):
    """A quiet stitched linen patch the things rest on: a soft rounded square of
    darker linen pressed into the cloak, with a running stitch round it.
    Near-neutral so it reads as a home, not a box."""
    r = s // 7
    inset = 10
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    weave_v = 0.5 + 0.5 * np.sin(2 * math.pi * xx / 4.0) * 0.5 + 0.25 * np.sin(2 * math.pi * yy / 4.0)
    slub = noise(s, s, 9, seed)
    base = np.array(PALETTE["paper_edge"], dtype=np.float32)
    shade = 0.93 + 0.04 * weave_v + 0.05 * (slub - 0.5)
    # Debossed: a soft inner shadow along the top-left edge, light along the bottom-right.
    m = Image.new("L", (s, s), 0)
    ImageDraw.Draw(m).rounded_rectangle([inset, inset, s - 1 - inset, s - 1 - inset], r, fill=255)
    mask = np.asarray(m.filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255.0
    inner = np.asarray(m.filter(ImageFilter.GaussianBlur(7)), dtype=np.float32) / 255.0
    shifted = np.roll(np.roll(inner, 4, 0), 4, 1)
    shade = shade * (0.86 + 0.14 * shifted)
    rgb = np.clip(base[None, None, :] * shade[..., None], 0, 255).astype(np.uint8)
    img = Image.fromarray(rgb, "RGB").convert("RGBA")
    img.putalpha(Image.fromarray((mask * 150).astype(np.uint8)))
    d = ImageDraw.Draw(img)
    i = inset + 9
    stitches(d, (i, i, s - 1 - i, s - 1 - i), r - 8, PALETTE["thread"] + (230,), dash=9, gap=6, width=2)
    img.save(os.path.join(OUT, name + ".png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    weave()
    wash()
    linen_patch()
    print("crafted textures ->", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
