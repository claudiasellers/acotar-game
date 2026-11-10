"""Paints the court trees' leaf atlas: four sprays of leaves on a 2x2 atlas,
for the leaf cards of tools/court/blender/court_trees.py.

  cell 0 broad    oak, ancient oak, crab apple
  cell 1 small    silver birch, hawthorn, elder
  cell 2 long     willow, yew
  cell 3 blossom  wild cherry, lilac (five-petal flowers among a few leaves)

RGB is a multiplier on the card's vertex colour (neutral grey for leaves, so
the species palette shows through; the blossom hearts are warm), A is the
leaf coverage. Each spray is painted like the storybook ground: a lit half
and a shade half on every blade, a darker midrib, the leaves behind darker
than the leaves in front. Painted 4x oversize and filtered down, colour bled
into the empty texels so mipmaps never fringe dark.

Run:  python3 tools/court/gen_leaf_atlas.py
Out:  world/spring_court/shared/models/cards/leaf_atlas.png (512 px)
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "world", "spring_court", "shared", "models", "cards",
                   "leaf_atlas.png")
SIZE = 512
SS = 4  # supersampling
CELL = SIZE * SS // 2
LIGHT = np.array([-0.55, -0.83])  # light from the upper left, in cell space (y down)


def leaf(rgb, a, cx, cy, ang, length, width, value, rng, cell_xy):
    """One pointed blade painted into `rgb`/`a` (cell pixel space)."""
    ox, oy = cell_xy
    r = int(length * 1.1) + 2
    x0, x1 = max(0, int(cx - r)), min(CELL, int(cx + r))
    y0, y1 = max(0, int(cy - r)), min(CELL, int(cy + r))
    if x1 <= x0 or y1 <= y0:
        return
    ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    dx, dy = xs - cx, ys - cy
    c, s = math.cos(ang), math.sin(ang)
    u = (dx * c + dy * s) / length          # along the blade, -1..1 (tip at +1)
    v = (-dx * s + dy * c)                  # across, pixels
    half = width * np.sqrt(np.clip(1.0 - u * u, 0.0, 1.0)) * (1.0 - 0.3 * u)
    inside = (np.abs(u) <= 1.0) & (np.abs(v) <= half)
    if not inside.any():
        return
    across = np.where(half > 0, v / np.maximum(half, 1e-3), 0.0)
    # Which half faces the light: the blade's normal across, dotted with it.
    n = np.array([-s, c])
    lit_side = 1.0 if float(n @ LIGHT) > 0 else -1.0
    shade = value * (0.9 + 0.13 * lit_side * np.sign(across) * np.minimum(1.0, np.abs(across) * 3.0))
    shade -= 0.13 * np.exp(-(across * 7.0) ** 2) * (np.abs(u) < 0.92)   # midrib
    shade -= 0.10 * np.clip((np.abs(across) - 0.75) / 0.25, 0.0, 1.0)    # edge
    shade *= 1.0 + 0.06 * (u * 0.5)                                        # tip a touch lighter
    sub = (slice(oy + y0, oy + y1), slice(ox + x0, ox + x1))
    for k in range(3):
        rgb[k][sub] = np.where(inside, shade, rgb[k][sub])
    a[sub] = np.where(inside, 1.0, a[sub])


def flower(rgb, a, cx, cy, radius, rng, cell_xy):
    """A five-petal blossom: pale petals (the vertex colour tints them), a
    warm heart."""
    ox, oy = cell_xy
    r = int(radius) + 2
    x0, x1 = max(0, int(cx - r)), min(CELL, int(cx + r))
    y0, y1 = max(0, int(cy - r)), min(CELL, int(cy + r))
    ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    dx, dy = xs - cx, ys - cy
    rr = np.sqrt(dx * dx + dy * dy) / radius
    th = np.arctan2(dy, dx) + rng.uniform(0, math.tau)
    petal = 0.62 + 0.38 * np.abs(np.cos(th * 2.5))
    inside = rr <= petal
    light = 0.92 + 0.08 * np.clip(-(dx * LIGHT[0] + dy * LIGHT[1]) / radius, -1, 1)
    heart = rr < 0.22
    sub = (slice(oy + y0, oy + y1), slice(ox + x0, ox + x1))
    val = np.where(heart, 1.0, light * (0.85 + 0.15 * rr))
    for k, warm in enumerate((1.25, 0.95, 0.55)):
        rgb[k][sub] = np.where(inside, np.where(heart, warm, val), rgb[k][sub])
    a[sub] = np.where(inside, 1.0, a[sub])


def spray(rgb, a, cell, kind, seed):
    rng = random.Random(seed)
    ox, oy = (cell % 2) * CELL, (cell // 2) * CELL
    cxy = (ox, oy)
    mid = CELL / 2.0
    reach = CELL * 0.44
    spec = {
        "broad": (30, 0.22, 0.10),
        "small": (60, 0.13, 0.065),
        "long": (34, 0.32, 0.05),
        "blossom": (16, 0.17, 0.08),
    }[kind]
    count, length, width = spec
    items = []
    for i in range(count):
        # Leaves fill a rounded clump, centres anywhere inside it, each blade
        # pointing roughly outward from the clump's middle (a random way near
        # the middle), so a card reads as a tuft of foliage, not a rosette.
        pa = rng.uniform(0, math.tau)
        pr = reach * 0.72 * math.sqrt(rng.random())
        items.append((rng.random(), pa, pr))
    items.sort()  # back to front: the first painted sit behind, darker
    for depth, (z, pa, pr) in enumerate(items):
        cx = mid + math.cos(pa) * pr
        cy = mid + math.sin(pa) * pr
        outward = pr / (reach * 0.72)
        point = pa + rng.uniform(-1.0, 1.0) * (1.6 - outward)
        L = length * CELL * rng.uniform(0.8, 1.15)
        W = width * CELL * rng.uniform(0.85, 1.15)
        tipx, tipy = cx + math.cos(point) * L * 0.5, cy + math.sin(point) * L * 0.5
        if not (6 < tipx < CELL - 6 and 6 < tipy < CELL - 6):
            point += math.pi  # turn it back into the cell
        value = 0.70 + 0.30 * depth / max(1, count - 1) + rng.uniform(-0.05, 0.05)
        leaf(rgb, a, cx, cy, point, L * 0.5, W * 0.5, value, rng, cxy)
    if kind == "blossom":
        for i in range(15):
            ang = i * 2.399 + rng.uniform(-0.4, 0.4)
            r = reach * (0.1 + 0.7 * math.sqrt(rng.random()))
            flower(rgb, a, mid + math.cos(ang) * r, mid + math.sin(ang) * r, CELL * rng.uniform(0.07, 0.1), rng, cxy)


def main():
    full = SIZE * SS
    rgb = [np.zeros((full, full), np.float32) for _ in range(3)]
    a = np.zeros((full, full), np.float32)
    for cell, kind in enumerate(("broad", "small", "long", "blossom")):
        spray(rgb, a, cell, kind, 1000 + cell)
    img = np.stack([np.clip(c, 0, 1) for c in rgb] + [a], axis=-1)
    im = Image.fromarray((img * 255).astype(np.uint8), "RGBA").resize((SIZE, SIZE), Image.LANCZOS)
    # Bleed the leaf colour into the empty texels (mipmaps average them in).
    arr = np.asarray(im).astype(np.float32)
    col = Image.fromarray(arr[..., :3].astype(np.uint8))
    filled = arr[..., :3].copy()
    mask = arr[..., 3] > 8
    for radius in (2, 4, 8, 16, 32):
        blurred = np.asarray(col.filter(ImageFilter.GaussianBlur(radius))).astype(np.float32)
        wmask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius))).astype(np.float32) / 255.0
        est = blurred / np.maximum(wmask[..., None], 1e-3)
        hole = (~mask) & (wmask > 0.02)
        filled[hole] = np.minimum(est[hole], 255)
        mask = mask | hole
        col = Image.fromarray(np.where(mask[..., None], filled, 0).astype(np.uint8))
    filled[~mask] = 200
    out = np.concatenate([filled, arr[..., 3:4]], axis=-1)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(out.astype(np.uint8), "RGBA").save(OUT)
    print("leaf atlas -> %s (coverage %.0f%%)" % (os.path.normpath(OUT), 100.0 * (arr[..., 3] > 127).mean()))


if __name__ == "__main__":
    main()
