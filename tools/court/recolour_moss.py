#!/usr/bin/env python3
"""Turns the moss ground slot olive (finish plan C1, owner 2026-11-11, render
wcterrain-37): every pixel's hue set to HUE degrees, saturation and value kept,
exactly as the shot tool's `moss_olive` look previewed it. The Western Woods'
floor is 93% moss, and its old hue (160) read teal under the fells grade.
tools/court/ground_texture_packer.gd's PASTEL moss row is the same olive, so a
repack from the Poly Haven maps lands in the same place.

    python3 tools/court/recolour_moss.py [HUE]   # default 110
"""
import colorsys
import sys

import numpy as np
from PIL import Image

PATH = "world/shared/terrain/textures/moss_albedo.png"
HUE = float(sys.argv[1]) if len(sys.argv) > 1 else 110.0

img = Image.open(PATH)
mode = img.mode
a = np.asarray(img.convert("RGBA")).astype(np.float32) / 255.0
rgb = a[..., :3]
mx = rgb.max(-1)
mn = rgb.min(-1)
s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
v = mx
h = HUE / 360.0
r, g, b = colorsys.hsv_to_rgb(h, 1.0, 1.0)
pure = np.array([r, g, b], np.float32)
# HSV -> RGB with a fixed hue: v * (1 - s * (1 - pure)).
out = v[..., None] * (1.0 - s[..., None] * (1.0 - pure[None, None, :]))
a[..., :3] = out
res = Image.fromarray((np.clip(a, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGBA").convert(mode)
res.save(PATH, optimize=True)
m = np.asarray(res.convert("RGB")).reshape(-1, 3).mean(0) / 255.0
print("moss albedo mean %s hue %.0f" % (m.round(3), colorsys.rgb_to_hsv(*m)[0] * 360))
