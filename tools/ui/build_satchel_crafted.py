#!/usr/bin/env python3
"""Paints the satchel page's handmade materials (L50): stitched leather tabs,
a deckled paper tag with a brass eyelet, enamel chips, a stitched leather key
button, a wool twill weave for the cloak, and a watercolour wash.

All are generated (fixed seeds), so to change the look edit PALETTE below and
re-run:  python3 tools/ui/build_satchel_crafted.py
Output: ui/satchel/crafted/*.png. Which texture dresses which control (and the
9-patch margins) lives in ui/satchel/crafted/satchel_crafted.tres.
"""
import math
import os
import random

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


def rng(seed):
    r = random.Random(seed)
    np.random.seed(seed)
    return r


def noise(w, h, scale, seed):
    """Smooth value noise in 0..1."""
    np.random.seed(seed)
    gw, gh = max(2, int(w / scale) + 2), max(2, int(h / scale) + 2)
    g = Image.fromarray((np.random.rand(gh, gw) * 255).astype(np.uint8))
    return np.asarray(g.resize((w, h), Image.BICUBIC), dtype=np.float32) / 255.0


def grain(w, h, seed):
    """Leather pebble grain: several octaves of noise plus fine pores."""
    n = noise(w, h, 18, seed) * 0.5 + noise(w, h, 7, seed + 1) * 0.3 + noise(w, h, 2.5, seed + 2) * 0.2
    return n


def rounded_mask(w, h, r, top_only=False):
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    if top_only:
        d.rounded_rectangle([0, 0, w - 1, h + r], r, fill=255)
    else:
        d.rounded_rectangle([0, 0, w - 1, h - 1], r, fill=255)
    return m


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


def leather_tab(name, base, seed, w=160, h=72, r=16, stitch_inset=7):
    """Stitched leather with burnished edges and a running stitch."""
    g = grain(w, h, seed)
    col = np.array(base, dtype=np.float32)
    shade = 0.82 + 0.3 * g
    # Burnished edges: darker toward the rim, a soft top highlight.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    burn = np.clip(edge / 10.0, 0, 1) ** 0.6
    shade *= 0.72 + 0.28 * burn
    shade *= 1.0 + 0.10 * np.clip(1 - yy / (h * 0.5), 0, 1)
    rgb = np.clip(col[None, None, :] * shade[..., None], 0, 255).astype(np.uint8)
    img = Image.fromarray(rgb, "RGB").convert("RGBA")
    img.putalpha(rounded_mask(w, h, r))
    d = ImageDraw.Draw(img)
    i = stitch_inset
    # Thread with a dark needle-hole under each stitch.
    hole = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    stitches(ImageDraw.Draw(hole), (i, i, w - 1 - i, h - 1 - i), r - i * 0.6, PALETTE["leather_dark"] + (150,), width=4)
    hole = hole.filter(ImageFilter.GaussianBlur(1.0))
    img = Image.alpha_composite(img, hole)
    d = ImageDraw.Draw(img)
    stitches(d, (i, i, w - 1 - i, h - 1 - i), r - i * 0.6, PALETTE["thread"] + (255,), width=2)
    # Re-cut the silhouette after compositing.
    a = np.minimum(np.asarray(img)[..., 3], np.asarray(rounded_mask(w, h, r)))
    img.putalpha(Image.fromarray(a))
    shadowed = drop_shadow(img, 3)
    shadowed.save(os.path.join(OUT, name + ".png"))


def drop_shadow(img, off, blur=3, alpha=90):
    w, h = img.size
    pad = off + blur * 2
    out = Image.new("RGBA", (w + pad, h + pad), (0, 0, 0, 0))
    a = img.split()[3]
    sh = Image.new("RGBA", (w, h), PALETTE["ink"] + (0,))
    sh.putalpha(a.point(lambda v: v * alpha // 255))
    layer = Image.new("RGBA", out.size, (0, 0, 0, 0))
    layer.paste(sh, (off, off + 1), sh)
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    out = Image.alpha_composite(out, layer)
    out.alpha_composite(img, (0, 0))
    return out


def deckle_mask(w, h, seed, rough=5):
    r = rng(seed)
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    pts = []
    step = 6
    for x in range(0, w, step):
        pts.append((x, r.uniform(0, rough)))
    for y in range(0, h, step):
        pts.append((w - 1 - r.uniform(0, rough), y))
    for x in range(w - 1, -1, -step):
        pts.append((x, h - 1 - r.uniform(0, rough)))
    for y in range(h - 1, -1, -step):
        pts.append((r.uniform(0, rough), y))
    d.polygon(pts, fill=255)
    return m.filter(ImageFilter.GaussianBlur(0.8))


def paper_tag(name="tag_paper", w=200, h=200, seed=11):
    """An ivory tag: deckled edge, paper fibre, a faint watercolour bloom,
    a ruled gilt line inset, and a brass eyelet at (24, 18) for the twine."""
    base = np.array(PALETTE["paper"], dtype=np.float32)
    fib = noise(w, h, 3, seed) * 0.6 + noise(w, h, 24, seed + 1) * 0.4
    shade = 0.95 + 0.07 * fib
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    rgb = base[None, None, :] * shade[..., None]
    # Foxed, warmer edges.
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    fox = np.clip(1 - edge / 18.0, 0, 1) ** 2
    rgb = rgb * (1 - fox[..., None] * 0.35) + np.array(PALETTE["paper_edge"])[None, None, :] * fox[..., None] * 0.35
    # Watercolour bloom in the lower right (blush), with a darker tide line.
    cx, cy = w * 0.78, h * 0.80
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (w * 0.42)
    wob = noise(w, h, 14, seed + 5) * 0.35
    bloom = np.clip(1 - (dist + wob), 0, 1)
    tide = np.exp(-((dist + wob - 0.95) ** 2) / 0.004) * 0.6
    wash = np.array(PALETTE["wash"], dtype=np.float32)
    k = np.clip(bloom * 0.16 + tide * 0.10, 0, 1)
    rgb = rgb * (1 - k[..., None]) + wash[None, None, :] * k[..., None]
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)
    # Gilt ruled frame, hand-drawn wobble.
    r = rng(seed + 9)
    ins = 12
    gilt = PALETTE["gilt"] + (200,)
    for (a, b) in [((ins + 24, ins), (w - ins, ins)), ((w - ins, ins), (w - ins, h - ins)),
                   ((w - ins, h - ins), (ins, h - ins)), ((ins, h - ins), (ins, ins + 22))]:
        pts = []
        for i in range(21):
            t = i / 20
            pts.append((a[0] + (b[0] - a[0]) * t + r.uniform(-0.4, 0.4), a[1] + (b[1] - a[1]) * t + r.uniform(-0.4, 0.4)))
        d.line(pts, fill=gilt, width=1)
    # Brass eyelet with a punched hole.
    ex, ey = 24, 18
    d.ellipse([ex - 9, ey - 9, ex + 9, ey + 9], fill=PALETTE["gilt_dark"] + (255,))
    d.ellipse([ex - 8, ey - 8, ex + 7, ey + 7], fill=PALETTE["gilt"] + (255,))
    d.ellipse([ex - 6, ey - 6, ex + 4, ey + 4], fill=(255, 236, 170, 255))
    d.ellipse([ex - 4, ey - 4, ex + 4, ey + 4], fill=(0, 0, 0, 0))
    m = deckle_mask(w, h, seed)
    a = np.minimum(np.asarray(img)[..., 3], np.asarray(m))
    img.putalpha(Image.fromarray(a))
    drop_shadow(img, 5, blur=5, alpha=70).save(os.path.join(OUT, name + ".png"))


def enamel_chip(name="chip_enamel", w=64, h=36, r=18, seed=21):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], r, fill=PALETTE["gilt_dark"] + (255,))
    d.rounded_rectangle([1, 1, w - 2, h - 2], r - 1, fill=PALETTE["gilt"] + (255,))
    d.rounded_rectangle([3, 3, w - 4, h - 4], r - 3, fill=PALETTE["enamel"] + (255,))
    # Glossy highlight along the top.
    hl = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(hl).rounded_rectangle([7, 5, w - 8, h // 2 - 1], r // 2, fill=(255, 255, 255, 90))
    img = Image.alpha_composite(img, hl.filter(ImageFilter.GaussianBlur(1.2)))
    img.save(os.path.join(OUT, name + ".png"))


def key_button(name="key_leather", seed=31):
    """A small stitched leather pill for the key prompts (stretches sideways)."""
    leather_tab(name, PALETTE["leather_dark"], seed, w=72, h=48, r=22, stitch_inset=5)


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
    leather_tab("tab_leather", PALETTE["leather"], 1)
    leather_tab("tab_leather_on", PALETTE["leather_on"], 2)
    paper_tag()
    enamel_chip()
    key_button()
    weave()
    wash()
    linen_patch()
    print("crafted textures ->", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
