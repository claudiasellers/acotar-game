"""The estate trees' leaf and blossom clumps (tools/blender/estate_tree.py).
One card is a rounded mass of small leaves or blossoms, sunlit at the rim and
top, shaded at the heart, so a cloud built from these cards keeps its
cotton-candy shape and is made of leaves (owner, 2026-11-11, of smooth
puffs: "not detailed ... just look at the other ones").

  leaf clumps (oak, birch, pear): painted like the court's sprays
      (gen_ez_textures.py): a value the tree shader bands into shadow, mid
      and light colours, and a cut-out
  blossom clumps (cherry, apple, crab apple): painted in their own colours
      (gen_ez_blossoms.py's petals), the estate's cotton-candy pinks and
      whites, over fresh mint leaves
  the willow's frond: hanging strands of narrow leaves, for its curtain

Run:  python3 tools/court/gen_estate_tree_clumps.py [out_dir] [--sheet]
Out:  puff_<species>.png, frond_willow.png  (512 x 512 RGBA, straight alpha)
      in world/spring_court/manor_estate/flora/trees/ by default
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
import gen_ez_textures as G  # noqa: E402
import gen_ez_blossoms as B  # noqa: E402

SIZE = G.SIZE
# kind: (leaf outline, leaves, leaf length px, leaf width / length)
KINDS = {
    "oak": ("oak", 170, 62.0, 0.62),
    "birch": ("aspen", 200, 46.0, 0.82),
    "pear_tree": ("aspen", 170, 58.0, 0.56),
}
# blossom clumps: (petal colours deep/mid/light, blossoms, leaves under them, buds 0..1, bud colour)
BLOSSOMS = {
    "cherry_blossom": ([(0.90, 0.50, 0.68), (0.99, 0.72, 0.85), (1.0, 0.90, 0.95)], 104, 10, 0.05, (0.86, 0.42, 0.60)),
    "apple_blossom": ([(0.93, 0.68, 0.74), (0.99, 0.91, 0.92), (1.0, 0.98, 0.97)], 88, 26, 0.13, (0.90, 0.50, 0.62)),
    "crab_apple": ([(0.95, 0.80, 0.84), (1.0, 0.96, 0.95), (1.0, 0.99, 0.98)], 86, 30, 0.22, (0.84, 0.30, 0.46)),
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


# the leaves under the blossom: the estate's fresh mint (the court's deeper
# greens speckle a white crown dark from a distance)
LEAF_SHADE, LEAF_MID, LEAF_LIGHT = (0.38, 0.64, 0.44), (0.56, 0.8, 0.54), (0.78, 0.94, 0.68)


def soft_leaf(cv, at, ang, length, width, rng):
    tone = rng.uniform(-0.15, 0.15)
    out = B.leaf_outline("aspen", length, width, rng)
    cv.poly(B.place(out, at, ang), B.rgb(B.mix(LEAF_SHADE, LEAF_MID, 0.4 + tone)))
    cv.poly(B.place([(x * 0.92 + length * 0.08, y * 0.78) for x, y in out], at, ang), B.rgb(B.mix(LEAF_MID, LEAF_LIGHT, 0.2 + tone)))
    cv.poly(B.place([(x * 0.55 + length * 0.42, y * 0.5 + width * 0.06) for x, y in out], at, ang), B.rgb(B.mix(LEAF_MID, LEAF_LIGHT, 0.8 + tone)))
    cv.line(B.place([(length * 0.05, 0), (length * 0.85, 0)], at, ang), max(1.0, width * 0.05), B.rgb(LEAF_SHADE))


def blossom5(cv, c, r, cols, rng, heart=(0.98, 0.82, 0.55)):
    """A five-petal fruit blossom: round, slightly notched petals, a pale
    heart and a few stamens."""
    rot = rng.uniform(0, math.tau)
    shade = rng.uniform(0.0, 1.0)
    rim = B.mix(cols[1], cols[2], shade)
    base = B.mix(cols[0], cols[1], shade * 0.5)
    for k in range(5):
        B.petal(cv, c, rot + math.tau * k / 5, r, r * 1.2, rim, base, notch=True)
    cv.disc(c, r * 0.24, B.rgb(B.mix(base, heart, 0.5)))
    for k in range(7):
        a = rot + math.tau * k / 7
        cv.disc((c[0] + math.cos(a) * r * 0.24, c[1] + math.sin(a) * r * 0.24), max(1.0, r * 0.06), B.rgb(B.mix(cols[0], (0.75, 0.45, 0.35), 0.5)))


def blossom_clump(cv, rng, kind):
    """Blossoms over a few leaves: the shaded heart first, the sunlit rim last."""
    cols, n, leaves, buds, bud_col = BLOSSOMS[kind]
    cx, cy, rad = SIZE / 2, SIZE * 0.51, SIZE * 0.4
    for k in range(leaves):
        a = k * 2.39996 + rng.uniform(-0.3, 0.3)
        r = rad * (0.45 + 0.6 * math.sqrt((k + 0.5) / leaves))
        at = (cx + r * 0.72 * math.cos(a), cy + r * 0.72 * math.sin(a))
        soft_leaf(cv, at, a + rng.uniform(-0.5, 0.5), rng.uniform(52, 70), rng.uniform(26, 34), rng)
    spots = []
    for k in range(n):
        r = rad * math.sqrt((k + 0.5) / n) * rng.uniform(0.92, 1.06)
        a = k * 2.39996 + rng.uniform(-0.25, 0.25)
        x, y = cx + r * math.cos(a), cy + r * math.sin(a) * 0.95
        spots.append((0.25 * (r / rad) + 0.5 * (1.0 - y / SIZE) + rng.uniform(-0.08, 0.08), x, y))
    for lit, x, y in sorted(spots):
        t = max(0.0, min(1.0, lit * 1.6 - 0.1))
        if rng.uniform() < buds:
            cv.disc((x, y), rng.uniform(8, 11), B.rgb(bud_col))
            cv.disc((x - 2.5, y - 2.5), rng.uniform(4, 5.5), B.rgb(B.mix(bud_col, cols[1], 0.6)))
            continue
        tones = [B.mix(cols[0], cols[1], 0.35 + 0.65 * t), B.mix(cols[0], cols[1], 0.6 + 0.4 * t), B.mix(cols[1], cols[2], 0.3 + 0.7 * t)]
        blossom5(cv, (x, y), rng.uniform(20, 27), tones, rng)


def frond(cv, rng):
    """The willow's curtain: strands hanging the card's whole height, narrow
    leaves down each, lighter towards the tips."""
    for k in range(5):
        x0 = SIZE * (0.14 + 0.18 * k) + rng.uniform(-12, 12)
        sway = rng.uniform(-26, 26)
        strand = G.bezier((x0, 2.0), (x0 + sway, SIZE * 0.5), (x0 + sway * 0.4 + rng.uniform(-14, 14), SIZE * rng.uniform(0.88, 0.99)))
        cv.line(strand, 2.5, 0.3)
        n = 22
        for i in range(n):
            t = 0.03 + 0.97 * i / (n - 1)
            p, a = G.along(strand, t)
            side = 1 if i % 2 == 0 else -1
            ln = rng.uniform(52, 70)
            G.paint_leaf(cv, "ash", p, a + side * rng.uniform(0.25, 0.6), ln, ln * 0.2, rng, 0.3 + 0.2 * t + rng.uniform(-0.04, 0.05))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out_dir = args[0] if args else os.path.join(os.path.dirname(__file__), "../../world/spring_court/manor_estate/flora/trees")
    sheet = []
    for i, kind in enumerate(KINDS):
        cv = G.Canvas()
        clump(cv, np.random.default_rng(4000 + i), kind)
        img, cover = finish(cv)
        img.save(f"{out_dir}/puff_{kind}.png", optimize=True)
        print(f"puff_{kind}.png  cover {cover:.3f}")
        sheet.append(img)
    for i, kind in enumerate(BLOSSOMS):
        cv = B.Canvas()
        blossom_clump(cv, np.random.default_rng(4100 + i), kind)
        img = cv.finish()
        img.save(f"{out_dir}/puff_{kind}.png", optimize=True)
        print(f"puff_{kind}.png  cover {(np.asarray(img)[..., 3] > 127).mean():.3f}")
        sheet.append(img)
    cv = G.Canvas()
    frond(cv, np.random.default_rng(4200))
    img, cover = finish(cv)
    img.save(f"{out_dir}/frond_willow.png", optimize=True)
    print(f"frond_willow.png  cover {cover:.3f}")
    sheet.append(img)
    if "--sheet" in sys.argv:
        w = Image.new("RGBA", (SIZE * 4, SIZE * 2), (60, 60, 70, 255))
        for i, im in enumerate(sheet):
            w.alpha_composite(im, (SIZE * (i % 4), SIZE * (i // 4)))
        w.save(f"{out_dir}/puff_sheet.png")


if __name__ == "__main__":
    main()
