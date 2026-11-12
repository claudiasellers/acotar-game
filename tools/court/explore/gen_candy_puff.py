"""Exploration (owner, 2026-11-11, of the smooth puff oak: "this is so ...
not detailed ... just look at the other ones"): a leaf clump for the estate's
cotton-candy crowns. One card is a rounded mass of small leaves fanning up and
out, sunlit at the rim and top, shaded at the heart, so a puff built from
these cards keeps its cloud shape and gains the court trees' leaf detail.

Painted like the court's sprays (gen_ez_textures.py): a value layer the tree
shader bands into shadow, mid and light colours, and a cut-out.

Run:  python3 tools/court/explore/gen_candy_puff.py <out_dir> [--sheet]
Out:  puff_<kind>.png  (512 x 512 RGBA, straight alpha)
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import gen_ez_textures as G  # noqa: E402

SIZE = G.SIZE
# kind: (leaf outline, leaves, leaf length px, leaf width / length)
KINDS = {
    "oak": ("oak", 170, 62.0, 0.62),
    "birch": ("aspen", 200, 46.0, 0.82),
}


def clump(cv, rng, kind):
    shape, n, length, wide = KINDS[kind]
    cx, cy, rad = SIZE / 2, SIZE * 0.51, SIZE * 0.42
    root = (cx, cy + rad * 0.55)   # the leaves fan up and out from below the heart
    leaves = []
    for k in range(n):
        # even over the disc (sunflower), a little jitter
        r = rad * math.sqrt((k + 0.5) / n) * rng.uniform(0.92, 1.06)
        a = k * 2.39996 + rng.uniform(-0.2, 0.2)
        x, y = cx + r * math.cos(a), cy + r * math.sin(a) * 0.94
        ang = math.atan2(y - root[1], x - root[0]) + rng.uniform(-0.45, 0.45)
        rim = r / rad
        up = 1.0 - y / SIZE
        value = 0.24 + 0.2 * rim + 0.26 * up + rng.uniform(-0.05, 0.05)
        ln = length * rng.uniform(0.82, 1.15) * (0.85 + 0.25 * rim)
        leaves.append((value, (x - math.cos(ang) * ln * 0.45, y - math.sin(ang) * ln * 0.45), ang, ln))
    # the shaded heart first, the sunlit rim last
    for value, at, ang, ln in sorted(leaves, key=lambda q: q[0]):
        G.paint_leaf(cv, shape, at, ang, ln, ln * wide, rng, value)


def finish(cv):
    val = cv.val.resize((SIZE, SIZE), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
    cov = cv.cov.resize((SIZE, SIZE), Image.LANCZOS)
    v = np.asarray(val).astype(np.float32) / 255.0
    a = np.asarray(cov).astype(np.float32) / 255.0
    v = np.where(a > 0.05, v / np.maximum(a, 0.05), 0.0)
    m = a >= 0.5
    # the court sprays' mid value, a wider spread: more of all three bands
    v = np.clip((v - v[m].mean()) / max(v[m].std(), 1e-4) * 0.13 + 0.40, 0.0, 1.0)
    hue = np.array((0.74, 1.0, 0.72), np.float32)
    hue = hue / float(hue @ np.array([0.3, 0.59, 0.11], np.float32))
    img = np.dstack([np.clip(v[..., None] * hue[None, None, :], 0.0, 1.0), a]) * 255.0
    return Image.fromarray(img.astype(np.uint8), "RGBA"), float(m.mean())


def main():
    out_dir = sys.argv[1]
    sheet = []
    for i, kind in enumerate(KINDS):
        cv = G.Canvas()
        clump(cv, np.random.default_rng(4000 + i), kind)
        img, cover = finish(cv)
        img.save(f"{out_dir}/puff_{kind}.png", optimize=True)
        print(f"puff_{kind}.png  cover {cover:.3f}")
        sheet.append(img)
    if "--sheet" in sys.argv:
        w = Image.new("RGBA", (SIZE * len(sheet), SIZE), (60, 60, 70, 255))
        for i, im in enumerate(sheet):
            w.alpha_composite(im, (SIZE * i, 0))
        w.save(f"{out_dir}/puff_sheet.png")


if __name__ == "__main__":
    main()
