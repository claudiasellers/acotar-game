#!/usr/bin/env python3
"""Softens Kenney's Fantasy UI Borders (CC0, kenney.nl, see
tools/ui/kenney_borders/License.txt) into the menus' frame textures (L65).

The pack is crisp 1-bit line art at 48 px. Each chosen frame is blown up,
blurred and re-thresholded so the square fretwork turns into rounded, piped
lines (R3: rounded whimsical shapes), given a darker rim, and saved white so
the game tints it from AcotarPalette `line` (gold in Spring, smoke grey in
the human realm). Which frame dresses which panel lives in
ui/theme/ui_borders.gd.

Run:  python3 tools/ui/build_ui_borders.py [--sheet out.png]
Source: tools/ui/kenney_borders/panel-border-NNN.png (copied from the pack)
Output: ui/theme/borders/frame_<name>.png
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "kenney_borders")
OUT = os.path.join(HERE, "..", "..", "ui", "theme", "borders")

# name -> Kenney Default/Border index. Keep in step with ui_borders.gd.
FRAMES = {
    "page": "012",     # corner knots: the satchel tag, journal pages, wardrobe, brew card
    "card": "002",     # scrolled double corners: the pause card
}
SUPER = 8      # work resolution per source pixel
SCALE = 4      # saved resolution per source pixel (drawn at 0.5, so 2 px on screen per source px)
SOFT = 0.28    # blur radius in source pixels: how round the corners get
RIM = 0.16     # rim width in source pixels
RIM_SHADE = 0.72  # rim brightness; times the tint gives the darker gilt edge


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def soften(idx: str) -> Image.Image:
    src = Image.open(os.path.join(SRC, f"panel-border-{idx}.png")).convert("RGBA")
    a = src.getchannel("A")
    big = a.resize((src.width * SUPER, src.height * SUPER), Image.NEAREST)
    blur = np.asarray(big.filter(ImageFilter.GaussianBlur(SOFT * SUPER)), dtype=np.float32) / 255.0
    body = smoothstep(0.40, 0.60, blur)
    # The rim: a band just outside the body, from a wider blur of the same lines.
    wide = np.asarray(big.filter(ImageFilter.GaussianBlur((SOFT + RIM) * SUPER)), dtype=np.float32) / 255.0
    outer = smoothstep(0.18, 0.32, wide)
    alpha = np.maximum(body, outer)
    shade = RIM_SHADE + (1.0 - RIM_SHADE) * np.where(alpha > 0, body / np.maximum(alpha, 1e-4), 0)
    rgb = np.repeat((shade * 255)[..., None], 3, axis=2)
    img = Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), "RGBA")
    return img.resize((src.width * SCALE, src.height * SCALE), Image.LANCZOS)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, idx in FRAMES.items():
        path = os.path.join(OUT, f"frame_{name}.png")
        soften(idx).save(path, optimize=True)
        print(path, os.path.getsize(path), "bytes")
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1]
        ids = sys.argv[sys.argv.index("--sheet") + 2:] or list(FRAMES.values())
        tiles = [soften(i) for i in ids]
        w = tiles[0].width
        sheet = Image.new("RGBA", (len(tiles) * (w + 16) + 16, w + 32), (251, 245, 232, 255))
        gold = Image.new("RGBA", (w, w), (212, 169, 79, 255))
        for k, t in enumerate(tiles):
            tinted = Image.fromarray((np.asarray(t, dtype=np.float32) * np.asarray(gold, dtype=np.float32) / 255).astype(np.uint8))
            sheet.alpha_composite(tinted, (16 + k * (w + 16), 16))
        sheet.save(out)


if __name__ == "__main__":
    main()
