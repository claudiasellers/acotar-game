"""Feyre's curtain-trimming rope (ch7), headless Blender, deterministic.

Run:  /opt/bpyenv/bin/python tools/blender/bedroom_set.py
Out:  art/bedroom/<id>.glb, nodes "<id>" and "<id>_lod1", fitted to SIZES, base
      centre at the origin (the rope hangs down from its top: the origin is
      the knot at the light fixture, set by the game).

"The length of rope I'd made from the curtain trimmings" [C]: braided blush
and gold cord knotted from the fringe, with tassels. Finishes as the manor
props (prop_kit.py); Godot loads it with PropModels.pair(). <= 3,000 tris.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import prop_kit as K  # noqa: E402
from prop_kit import BLUSH, GOLD, ROSE, T, S, cyl, sphere, tube  # noqa: E402

OUT = os.path.join(K.ROOT, "art/bedroom")
SIZES = {"curtain_rope": (0.16, 1.6, 0.16), "curtain_rope_coil": (0.4, 0.12, 0.3)}


def rope(p):
    # Two strands twisted down 1.5 m, knots every 30 cm, a tassel at the end.
    n = 40
    for k, col in enumerate((BLUSH, GOLD)):
        pts = []
        for i in range(n + 1):
            z = 1.5 - 1.5 * i / n
            a = i * 0.9 + k * math.pi
            pts.append((0.012 * math.cos(a), 0.012 * math.sin(a), z))
        p.add(tube(pts, 0.009, 6), col, "fabric" if k == 0 else "gold")
    for j in range(5):
        p.add(sphere(0.022, 8, 6), ROSE, "fabric", T(0, 0, 1.5 - 0.3 * j - 0.15) @ S(1.0, 1.0, 0.8))
    p.add(cyl(0.02, 0.03, 10), GOLD, "gold", T(0, 0, 0.0))
    for t in range(10):
        a = 2 * math.pi * t / 10
        p.add(cyl(0.004, 0.09, 4), BLUSH, "fabric", T(0.014 * math.cos(a), 0.014 * math.sin(a), -0.09))
    p.add(sphere(0.03, 10, 6), GOLD, "gold", T(0, 0, 1.53))


def coil(p):
    # The rope as she holds it, coiled on the window seat before she rigs it.
    for r in range(3):
        pts = []
        for i in range(25):
            a = 2 * math.pi * i / 24
            pts.append(((0.12 + r * 0.025) * math.cos(a), (0.09 + r * 0.02) * math.sin(a), 0.02 + r * 0.025))
        p.add(tube(pts, 0.012, 6, closed=True), BLUSH if r % 2 == 0 else GOLD, "fabric" if r % 2 == 0 else "gold")
    p.add(sphere(0.03, 8, 6), ROSE, "fabric", T(0.16, 0.0, 0.03))


BUILDERS = {"curtain_rope": rope, "curtain_rope_coil": coil}


def main():
    for pid, fn in BUILDERS.items():
        K.reset()
        p = K.Prop(pid)
        fn(p)
        p.fit(SIZES[pid])
        ob = p.to_object(pid)
        lo = K.lod(ob, 0.5)
        n0, n1 = K.mesh_tris(ob), K.mesh_tris(lo)
        print(f"  {pid:20s} {n0:5d} tris  lod1 {n1:5d}")
        if n0 > 3000:
            sys.exit(1)
        K.export_glb([ob, lo], os.path.join(OUT, pid + ".glb"))


if __name__ == "__main__":
    main()
