"""Generates the first dinner's table set (headless Blender, deterministic).

Run:  /opt/bpyenv/bin/python tools/blender/dinner_set.py
Out:  art/dinner/<id>.glb, nodes "<id>" and "<id>_lod1" (~50% tris), fitted to
      SIZES (w, h, d) in metres, base centre at the origin, front -Z in Godot.
      Same finish contract as the manor props (prop_kit.py): Godot loads them
      with PropModels.pair(), so the plate is pearl, the rims gold, the wine glass.

Ch 6-7 (Keeper, [C]): chicken, bread, peas, fish, asparagus, lamb, "meat and
sauce and bread" on her plate, pale sparkling wine, real gold goblets, a
chocolate torte. Princess-castle take (R3): pearl and gold, glossy food,
a blush rose on the torte. Budgets (R4): <= 3,000 tris, LOD1 ~50%.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import prop_kit as K  # noqa: E402
from prop_kit import BLUSH, BUTTER, CREAM, GOLD, MINT, PEARL, ROSE, R, S, T, cyl, lathe, sphere, torus  # noqa: E402

OUT = os.path.join(K.ROOT, "art/dinner")
MAX_TRIS = 3000

ROAST = K.hexc("#C98A4B")
ROAST_DARK = K.hexc("#9A5E2E")
CRUST = K.hexc("#E3B46A")
SAUCE = K.hexc("#B5655A")
CHOC = K.hexc("#5B3328")
CHOC_GLOSS = K.hexc("#6E3B2E")
WINE = K.hexc("#F6E7B0")
PEA = K.hexc("#9CD69A")

SIZES = {
    "dinner_plate": (0.28, 0.03, 0.28),
    "dinner_chicken": (0.15, 0.06, 0.10),
    "dinner_bread": (0.10, 0.06, 0.08),
    "dinner_sauce_peas": (0.16, 0.025, 0.12),
    "dinner_wine_glass": (0.075, 0.19, 0.075),
    "dinner_goblet": (0.085, 0.17, 0.085),
    "dinner_torte": (0.24, 0.17, 0.24),
}


def plate(p):
    p.add(lathe([(0.0, 0.0), (0.09, 0.0), (0.1, 0.006), (0.105, 0.012), (0.14, 0.024), (0.142, 0.03),
                 (0.13, 0.026), (0.1, 0.014), (0.0, 0.012)], 32), PEARL, "pearl")
    p.add(torus(0.137, 0.004, 32, 4), GOLD, "gold", T(0, 0, 0.028))
    p.add(torus(0.1, 0.0025, 32, 4), GOLD, "gold", T(0, 0, 0.013))


def chicken(p):
    # A drumstick and two carved slices, glossy and golden.
    p.add(sphere(0.035, 12, 8), ROAST, "satin", T(0.02, 0, 0.03) @ S(1.4, 1.0, 0.8))
    p.add(cyl(0.008, 0.06, 8), CREAM, "satin", T(-0.02, 0, 0.03) @ R("Y", -90))
    p.add(sphere(0.011, 8, 6), CREAM, "satin", T(-0.08, 0, 0.03))
    for k in range(2):
        p.add(sphere(0.03, 10, 6), ROAST_DARK if k else ROAST, "satin",
              T(0.0 + k * 0.03, 0.035, 0.012) @ S(1.3, 0.8, 0.35))


def bread(p):
    p.add(sphere(0.05, 14, 10), CRUST, "satin", T(0, 0, 0.025) @ S(1.0, 0.8, 0.6))
    for k in range(3):
        p.add(cyl(0.004, 0.06, 6), BUTTER, "matte", T(-0.02 + k * 0.02, 0, 0.052) @ R("X", 90) @ T(0, 0, -0.03))


def sauce_peas(p):
    p.add(lathe([(0.0, 0.0), (0.07, 0.0), (0.075, 0.004), (0.0, 0.008)], 20), SAUCE, "satin",
          S(1.0, 0.75, 1.0))
    for i in range(9):
        a = i * 2.4
        r = 0.02 + 0.006 * i
        p.add(sphere(0.008, 8, 6), PEA, "satin", T(r * math.cos(a) + 0.02, r * math.sin(a) * 0.6, 0.012))


def wine_glass(p):
    p.add(lathe([(0.0, 0.0), (0.035, 0.0), (0.036, 0.004), (0.006, 0.008), (0.005, 0.09), (0.02, 0.1),
                 (0.034, 0.13), (0.036, 0.17), (0.035, 0.19)], 16, cap_top=False), PEARL, "glass")
    p.add(lathe([(0.0, 0.1), (0.02, 0.102), (0.031, 0.13), (0.032, 0.155), (0.0, 0.155)], 16), WINE, "water")


def goblet(p):
    p.add(lathe([(0.0, 0.0), (0.04, 0.0), (0.04, 0.008), (0.012, 0.02), (0.008, 0.07), (0.016, 0.085),
                 (0.038, 0.11), (0.042, 0.17), (0.036, 0.17), (0.0, 0.11)], 20), GOLD, "gold")
    p.add(torus(0.012, 0.004, 12, 4), ROSE, "glow", T(0, 0, 0.06))


def torte(p):
    p.add(lathe([(0.0, 0.0), (0.1, 0.0), (0.115, 0.008), (0.03, 0.015), (0.02, 0.05), (0.12, 0.055),
                 (0.12, 0.06), (0.0, 0.06)], 28), PEARL, "pearl")
    p.add(cyl(0.095, 0.07, 28), CHOC, "satin", T(0, 0, 0.06))
    p.add(cyl(0.097, 0.008, 28), CHOC_GLOSS, "satin", T(0, 0, 0.128))
    for i in range(10):
        a = 2 * math.pi * i / 10
        p.add(sphere(0.012, 8, 6), BLUSH, "satin", T(0.08 * math.cos(a), 0.08 * math.sin(a), 0.138))
    for k in range(5):
        a = 2 * math.pi * k / 5
        p.add(sphere(0.016, 10, 6), ROSE, "fabric", T(0.012 * math.cos(a), 0.012 * math.sin(a), 0.148) @ S(1.0, 1.0, 0.7))
    p.add(sphere(0.012, 10, 6), K.lighter(ROSE, 0.3), "fabric", T(0, 0, 0.158))
    p.add(sphere(0.01, 8, 6), MINT, "leaf", T(0.03, 0, 0.142) @ S(1.6, 0.8, 0.4))


BUILDERS = {
    "dinner_plate": plate, "dinner_chicken": chicken, "dinner_bread": bread, "dinner_sauce_peas": sauce_peas,
    "dinner_wine_glass": wine_glass, "dinner_goblet": goblet, "dinner_torte": torte,
}


def main():
    over = []
    for pid, fn in BUILDERS.items():
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
