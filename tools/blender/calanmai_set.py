"""Generates the Calanmai chapter's story props (headless Blender, deterministic).

Run:  /opt/bpyenv/bin/python tools/blender/calanmai_set.py
Out:  art/calanmai/<id>.glb, nodes "<id>" and "<id>_lod1" (~50% tris), fitted to
      SIZES (w, h, d) in metres, base centre at the origin, front -Z in Godot.
      Same finish contract as the manor props (prop_kit.py): Godot loads them
      with PropModels.pair().

Canon (Keeper, 2026-11-02, ch20-22):
- "the first giant bonfire atop the hill" [C]: calanmai_pyre, a wood stack taller
  than a house, wound with Fire Night ribbons [X]; calanmai_pyre_ash, what is
  left of it after the night (the hill keeps the scar, story lane StateVisibility).
- Tamlin as the Hunter, "crowned with laurel" [C]: laurel_crown (held on his Head bone).
- Her supper in the empty kitchen: bread, an apple, a lemon tart [C].
- "a bouquet of white roses from his parents' garden" [C], put in her painting
  room by Alis [C]: white_roses_vase.
Princess-castle take (R3): glossy, rounded, pearl and gold; the fire wood is
warm honey, not grey. Budgets (R4): <= 3,000 tris, LOD1 ~50%.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import prop_kit as K  # noqa: E402
from prop_kit import BUTTER, CREAM, GOLD, PEARL, R, S, T, cyl, lathe, sphere, torus, tube  # noqa: E402

OUT = os.path.join(K.ROOT, "art/calanmai")
MAX_TRIS = 3000

WOOD = K.hexc("#B98A5E")
WOOD_DK = K.hexc("#8C6346")
WOOD_PALE = K.hexc("#D9B88E")
CHAR = K.hexc("#4A3A44")        # charred, plum-tinted (never flat grey)
ASH = K.hexc("#B7AEB8")
EMBER = K.hexc("#FF9A5A")
RIBBON_RED = K.hexc("#D8344A")
RIBBON_GOLD = K.hexc("#F2C66A")
RIBBON_ROSE = K.hexc("#F4A6C0")
STONE = K.hexc("#D8CFC6")
LAUREL = K.hexc("#5E8C5A")
LAUREL_LT = K.hexc("#86B07A")
APPLE = K.hexc("#E2544E")
APPLE_LT = K.hexc("#F2A07A")
LEMON = K.hexc("#F6DC6E")
PASTRY = K.hexc("#E9BE7A")
WHITE_ROSE = K.hexc("#FBF6EE")
WHITE_ROSE_SH = K.hexc("#EFE3DA")
STEM = K.hexc("#6C9A64")

SIZES = {
    "calanmai_pyre": (4.2, 5.6, 4.2),
    "calanmai_pyre_ash": (4.4, 0.7, 4.4),
    "laurel_crown": (0.21, 0.06, 0.23),
    "kitchen_apple": (0.08, 0.09, 0.08),
    "kitchen_lemon_tart": (0.13, 0.05, 0.13),
    "white_roses_vase": (0.34, 0.62, 0.34),
}


def _ring_stones(p, rng, n, rad, size):
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.08, 0.08)
        s = size * rng.uniform(0.8, 1.2)
        p.add(sphere(s, 8, 5), STONE, "matte",
              T(math.cos(a) * rad, math.sin(a) * rad, s * 0.35) @ R("Z", math.degrees(a)) @ S(1.3, 1.0, 0.7))


def pyre(p):
    """A tall cone of leaning logs over a criss-cross crib, a ring of pale stones, ribbons wound up it."""
    rng = random.Random(2001)
    _ring_stones(p, rng, 18, 2.0, 0.26)
    for layer in range(4):                       # the crib: log pairs, alternating direction
        z = 0.12 + layer * 0.2
        for s in (-1, 1):
            if layer % 2:
                p.add(cyl(0.11, 2.6, 8), WOOD_DK if s > 0 else WOOD, "satin", T(s * 0.75, 0, z) @ R("X", 90) @ T(0, 0, -1.3))
            else:
                p.add(cyl(0.11, 2.6, 8), WOOD if s > 0 else WOOD_DK, "satin", T(0, s * 0.75, z) @ R("Y", 90) @ T(0, 0, -1.3))
    for i in range(22):                          # leaning logs to a point
        a = 2 * math.pi * i / 22 + rng.uniform(-0.05, 0.05)
        r0 = 1.45 + rng.uniform(-0.1, 0.15)
        top = 5.2 + rng.uniform(-0.25, 0.35)
        base = (math.cos(a) * r0, math.sin(a) * r0, 0.0)
        tip = (math.cos(a + 0.25) * 0.12, math.sin(a + 0.25) * 0.12, top)
        col = (WOOD, WOOD_DK, WOOD_PALE)[i % 3]
        p.add(tube([base, tip], 0.085 + rng.uniform(-0.01, 0.015), 6), col, "satin")
    for k, col in enumerate((RIBBON_RED, RIBBON_GOLD, RIBBON_ROSE)):   # ribbons spiralling up [X]
        pts = []
        for j in range(26):
            t = j / 25
            a = t * 2.4 * math.pi + k * 2.1
            r = 1.5 * (1 - t) + 0.18
            pts.append((math.cos(a) * r, math.sin(a) * r, 0.5 + t * 4.4))
        p.add(tube(pts, 0.03, 4), col, "fabric")
    for i in range(6):                           # kindling bundles at the foot
        a = 2 * math.pi * i / 6 + 0.3
        p.add(cyl(0.16, 0.7, 7), WOOD_PALE, "fabric",
              T(math.cos(a) * 1.65, math.sin(a) * 1.65, 0.2) @ R("Z", math.degrees(a)) @ R("Y", 80) @ T(0, 0, -0.35))


def pyre_ash(p):
    """The morning after: a soft mound of ash, charred stubs, the stone ring, a few ribbons left in the dust."""
    rng = random.Random(2002)
    _ring_stones(p, rng, 18, 2.0, 0.26)
    p.add(lathe([(0.0, 0.0), (1.7, 0.0), (1.5, 0.08), (1.0, 0.2), (0.4, 0.3), (0.0, 0.32)], 20), ASH, "matte")
    for i in range(14):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.2, 1.3)
        L = rng.uniform(0.5, 1.4)
        base = (math.cos(a) * r, math.sin(a) * r, 0.18)
        b = a + rng.uniform(-1.2, 1.2)
        tip = (base[0] + math.cos(b) * L, base[1] + math.sin(b) * L, 0.18 + rng.uniform(0.05, 0.35))
        p.add(tube([base, tip], 0.07, 6), CHAR, "satin")
    for i in range(9):                           # embers still glowing in the ash
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.0, 0.9)
        p.add(sphere(0.06, 6, 4), EMBER, "glow", T(math.cos(a) * r, math.sin(a) * r, 0.24))
    for k, col in enumerate((RIBBON_RED, RIBBON_GOLD, RIBBON_ROSE, RIBBON_RED)):
        a = 0.8 + k * 1.6
        x, y = math.cos(a) * 2.2, math.sin(a) * 2.2
        pts = [(x + 0.25 * math.cos(a + 1.5) * j * 0.4, y + 0.25 * math.sin(a + 1.5) * j * 0.4, 0.02 + 0.015 * math.sin(j))
               for j in range(6)]
        p.add(tube(pts, 0.025, 4), col, "fabric")


def laurel_crown(p):
    """A ring of laurel leaves in pairs round the brow, glossy, with a little gold binding."""
    p.add(torus(0.095, 0.006, 32, 5), K.hexc("#6E5A3C"), "satin", S(1.0, 1.1, 1.0))
    for i in range(30):
        a = 2 * math.pi * i / 30
        for s in (-1, 1):
            lf = K.leaf(0.045, 0.016)
            ang = math.degrees(a) + 90
            col = LAUREL if (i + (s > 0)) % 2 else LAUREL_LT
            p.add(lf, col, "leaf",
                  T(math.cos(a) * 0.097, math.sin(a) * 0.107, 0.004) @ R("Z", ang) @ R("X", s * 55) @ R("Y", -20))
    for a in (0.0, math.pi):
        p.add(sphere(0.008, 8, 6), GOLD, "gold", T(math.cos(a + math.pi / 2) * 0.097, math.sin(a + math.pi / 2) * 0.107, 0.004))


def apple(p):
    p.add(sphere(0.04, 16, 12), APPLE, "satin", T(0, 0, 0.04) @ S(1.0, 1.0, 0.92))
    p.add(sphere(0.02, 10, 6), APPLE_LT, "satin", T(0.018, -0.022, 0.05) @ S(1.0, 0.5, 1.0))
    p.add(cyl(0.003, 0.02, 6), WOOD_DK, "satin", T(0, 0, 0.075))
    p.add(K.leaf(0.025, 0.012), STEM, "leaf", T(0.004, 0, 0.088) @ R("Y", 60))


def lemon_tart(p):
    p.add(lathe([(0.0, 0.0), (0.06, 0.0), (0.065, 0.012), (0.064, 0.028), (0.058, 0.03), (0.0, 0.03)], 24), PASTRY, "satin")
    for i in range(16):                          # fluted crust edge
        a = 2 * math.pi * i / 16
        p.add(sphere(0.008, 6, 4), PASTRY, "satin", T(0.06 * math.cos(a), 0.06 * math.sin(a), 0.026))
    p.add(cyl(0.056, 0.004, 24), LEMON, "satin", T(0, 0, 0.026))
    for i in range(5):                           # meringue kisses + a sugared lemon slice
        a = 2 * math.pi * i / 5
        p.add(sphere(0.009, 8, 6), CREAM, "pearl", T(0.03 * math.cos(a), 0.03 * math.sin(a), 0.034) @ S(1, 1, 1.3))
    p.add(cyl(0.016, 0.004, 16), K.lighter(LEMON, 0.3), "satin", T(0, 0, 0.034) @ R("X", 70))


def white_roses_vase(p):
    rng = random.Random(2003)
    p.add(lathe([(0, 0), (0.07, 0), (0.1, 0.06), (0.11, 0.18), (0.06, 0.3), (0.05, 0.34), (0.08, 0.38)], 14),
          PEARL, "pearl")
    for z in (0.02, 0.37):
        p.add(torus(0.075 if z > 0.1 else 0.07, 0.008, 14, 4), GOLD, "gold", T(0, 0, z))
    for i in range(9):                           # nine white roses, each a cupped bloom on a stem
        a = 2 * math.pi * i / 9 + rng.uniform(-0.15, 0.15)
        r = 0.05 + 0.06 * (i % 3) / 2
        top = (math.cos(a) * r * 1.6, math.sin(a) * r * 1.6, 0.5 + rng.uniform(-0.03, 0.07))
        p.add(tube([(math.cos(a) * 0.02, math.sin(a) * 0.02, 0.3), top], 0.004, 5), STEM, "leaf")
        K.bloom(p, top, 0.045, WHITE_ROSE if i % 2 else WHITE_ROSE_SH, rings=3, per=5, rng=rng, finish="fabric",
                heart=BUTTER)
        p.add(K.leaf(0.04, 0.018), STEM, "leaf", T(*[c * 0.9 for c in top[:2]], top[2] - 0.08) @ R("Z", math.degrees(a)) @ R("Y", 60))


BUILDERS = {
    "calanmai_pyre": pyre, "calanmai_pyre_ash": pyre_ash, "laurel_crown": laurel_crown,
    "kitchen_apple": apple, "kitchen_lemon_tart": lemon_tart, "white_roses_vase": white_roses_vase,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    over = []
    only = [a for a in sys.argv[1:] if a in BUILDERS]
    for pid, fn in BUILDERS.items():
        if only and pid not in only:
            continue
        K.reset()
        p = K.Prop(pid)
        fn(p)
        p.fit(SIZES[pid])
        ob = p.to_object(pid)
        lo = K.lod(ob, 0.5)
        n0, n1 = K.mesh_tris(ob), K.mesh_tris(lo)
        print(f"  {pid:20s} {n0:5d} tris  lod1 {n1:5d} ({n1 / max(n0, 1):.0%})")
        if n0 > MAX_TRIS:
            over.append(pid)
        K.export_glb([ob, lo], os.path.join(OUT, pid + ".glb"))
    if over:
        print("OVER BUDGET:", ", ".join(over))
        sys.exit(1)


if __name__ == "__main__":
    main()
