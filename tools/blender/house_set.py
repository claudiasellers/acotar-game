"""The p3 house beats' props (ch12-13, L28), headless Blender, deterministic.

Run:  /opt/bpyenv/bin/python tools/blender/house_set.py
Out:  art/house/<id>.glb, nodes "<id>" and "<id>_lod1", fitted to SIZES, base
      centre at the origin, front facing +Y in Blender (-Z in Godot).

Canon (Keeper, ch12): her little map of the halls with "a few Xs and circles
to signify the doors, the windows, the marble stairs"; the small infirmary is
"more of a supply closet with a worktable", cabinets and drawers and "a deep
sink at the back"; she cleans his hand in a bowl of water, then "bound and
wrapped his hand". Bowl, linen and bandage looks are canon:"X" (R3 pastels).
The hand wraps are built along +Z (Godot +Y: along the hand bone from the
wrist). Finishes as the manor props (prop_kit.py), <= 3,000 tris each.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import prop_kit as K  # noqa: E402
from prop_kit import (BLUSH, BUTTER, CANVAS, CREAM, GOLD, LILAC, MINT, OAK, OAK_DARK, PEARL,  # noqa: E402
                      ROSE, WARM_STONE, WHITE, T, R, S, box, cyl, lathe, sphere, torus, tube)

OUT = os.path.join(K.ROOT, "art/house")
INK = (0.36, 0.22, 0.34)
SIZES = {
    "feyre_hall_map": (0.34, 0.012, 0.25),
    "infirmary_worktable": (1.4, 0.92, 0.72),
    "deep_sink": (0.72, 0.96, 0.5),
    "porcelain_bowl": (0.3, 0.1, 0.3),
    "linen_folded": (0.28, 0.07, 0.2),
    "bandage_roll": (0.08, 0.11, 0.08),
    "hand_wrap_1": (0.1, 0.05, 0.075),
    "hand_wrap_2": (0.1, 0.08, 0.075),
    "hand_wrap_3": (0.1, 0.11, 0.075),
    "mural_frame": (3.9, 2.4, 0.08),
}


def hall_map(p):
    # A sheet of drawing paper, softly curled, with her marks in plum ink.
    sheet = box(0.34, 0.25, 0.002, seg=None)
    p.add(sheet, CANVAS, "matte", T(0, 0, 0.004))
    p.add(box(0.34, 0.012, 0.004), CREAM, "matte", T(0, 0.125, 0.006))  # the curled top edge
    for (x, y) in [(-0.1, 0.06), (0.04, -0.05), (0.11, 0.07)]:
        for a in (45, -45):
            p.add(box(0.035, 0.004, 0.001), INK, "satin", T(x, y, 0.0062) @ R("Z", a))
    for (x, y) in [(-0.06, -0.07), (0.1, -0.02)]:
        p.add(torus(0.016, 0.0018, 14, 4), INK, "satin", T(x, y, 0.0062))
    # Wobbly corridor lines.
    for (x0, y0, x1, y1) in [(-0.15, 0.0, 0.15, 0.0), (-0.02, -0.11, -0.02, 0.11), (0.06, 0.03, 0.15, 0.03)]:
        n = 8
        pts = [(x0 + (x1 - x0) * i / n + 0.002 * math.sin(i * 2.1), y0 + (y1 - y0) * i / n + 0.002 * math.cos(i * 1.7), 0.0062)
               for i in range(n + 1)]
        p.add(tube(pts, 0.0012, 4), INK, "satin")
    p.add(cyl(0.006, 0.006, 8), GOLD, "gold", T(0.15, -0.11, 0.006))  # a drop of gilt ink


def worktable(p):
    # Plain oak worktable with two drawers and a pearl tray with a gilt rim.
    p.add(box(1.4, 0.72, 0.06, bevel=0.012), OAK, "satin", T(0, 0, 0.86))
    for x in (-0.64, 0.64):
        for y in (-0.3, 0.3):
            p.add(cyl(0.035, 0.83, 8, r2=0.028), OAK_DARK, "satin", T(x, y, 0.0))
    p.add(box(1.24, 0.6, 0.14), OAK, "satin", T(0, 0, 0.7))
    for x in (-0.33, 0.33):
        p.add(box(0.5, 0.02, 0.1, bevel=0.006), lighter_oak(), "satin", T(x, 0.305, 0.72))
        p.add(sphere(0.018, 8, 6), GOLD, "gold", T(x, 0.33, 0.77))
    p.add(box(1.24, 0.6, 0.03), OAK_DARK, "satin", T(0, 0, 0.12))  # the low shelf
    tray = lathe([(0.0, 0.0), (0.24, 0.0), (0.25, 0.012), (0.255, 0.03)], 20, cap_top=False)
    p.add(tray, PEARL, "pearl", T(-0.25, 0, 0.89) @ S(1.6, 1.0, 1.0))
    p.add(torus(0.255, 0.007, 20, 4), GOLD, "gold", T(-0.25, 0, 0.92) @ S(1.6, 1.0, 1.0))


def lighter_oak():
    return K.lighter(OAK, 0.18)


def deep_sink(p):
    # A deep warm-stone basin on a mint cupboard, with a brass pump spout.
    p.add(box(0.72, 0.5, 0.62, bevel=0.01), MINT, "satin", T(0, 0, 0.0))
    p.add(box(0.3, 0.02, 0.48), K.lighter(MINT, 0.25), "satin", T(-0.17, 0.25, 0.07))
    p.add(box(0.3, 0.02, 0.48), K.lighter(MINT, 0.25), "satin", T(0.17, 0.25, 0.07))
    basin = lathe([(0.0, 0.0), (0.2, 0.0), (0.24, 0.1), (0.27, 0.26), (0.29, 0.3), (0.26, 0.31), (0.22, 0.12), (0.16, 0.06), (0.0, 0.06)], 16,
                  cap_top=False)
    p.add(basin, WARM_STONE, "satin", T(0, 0, 0.62) @ S(1.2, 0.8, 1.0))
    p.add(cyl(0.02, 0.32, 8), GOLD, "gold", T(0, -0.21, 0.62))
    pts = [(0, -0.21, 0.94), (0, -0.18, 0.99), (0, -0.1, 0.99), (0, -0.06, 0.95)]
    p.add(tube(pts, 0.016, 8), GOLD, "gold")
    p.add(sphere(0.03, 10, 8), GOLD, "gold", T(0, -0.21, 0.95))


def bowl(p):
    body = lathe([(0.0, 0.0), (0.06, 0.0), (0.065, 0.01), (0.11, 0.05), (0.145, 0.095), (0.15, 0.1),
                  (0.14, 0.1), (0.1, 0.05), (0.06, 0.02), (0.0, 0.02)], 20, cap_top=False)
    p.add(body, PEARL, "pearl")
    p.add(torus(0.147, 0.004, 24, 4), GOLD, "gold", T(0, 0, 0.099))
    p.add(torus(0.128, 0.003, 24, 4), BLUSH, "satin", T(0, 0, 0.078))
    for i in range(8):
        a = 2 * math.pi * i / 8
        p.add(sphere(0.008, 6, 4), ROSE, "satin", T(0.122 * math.cos(a), 0.122 * math.sin(a), 0.072))


def linen(p):
    for i, col in enumerate((WHITE, CREAM, WHITE)):
        p.add(K.cushion(0.28, 0.2, 0.02, puff=0.2), col, "fabric", T(0, 0, 0.022 * i))
    p.add(box(0.03, 0.205, 0.068), LILAC, "fabric", T(0.06, 0, 0.0))
    p.add(sphere(0.014, 8, 6), LILAC, "fabric", T(0.06, -0.1, 0.06))


def bandage_roll(p):
    p.add(cyl(0.04, 0.1, 16), WHITE, "fabric", T(0, 0, 0.0))
    p.add(cyl(0.012, 0.102, 8), BUTTER, "matte", T(0, 0, -0.001))
    pts = [(0.04, 0.0, 0.05), (0.05, 0.03, 0.03), (0.045, 0.06, 0.0)]
    p.add(tube(pts, 0.006, 4), WHITE, "fabric")


def hand_wrap(turns):
    def build(p):
        # Linen wound round an oval palm, wrist to knuckles along +Z.
        n = 12 * turns
        length = 0.035 * turns
        for k, col in enumerate((WHITE, CREAM)):
            pts = []
            for i in range(n + 1):
                a = 2 * math.pi * i / 12 + k * 0.4
                z = length * i / n
                pts.append((0.05 * math.cos(a), 0.036 * math.sin(a), z))
            p.add(tube(pts, 0.012 if k == 0 else 0.008, 6), col, "fabric")
        p.add(sphere(0.012, 6, 4), BLUSH, "fabric", T(0.05, 0.0, length * 0.5))  # the tucked end
    return build


def mural_frame(p):
    # Gilt moulding round the study mural (the painting itself is a texture).
    w, h, t = 3.9, 2.4, 0.08
    for (sx, sz, x, z) in [(w, 0.08, 0, 0.04), (w, 0.08, 0, h - 0.04), (0.08, h, -w / 2 + 0.04, h / 2), (0.08, h, w / 2 - 0.04, h / 2)]:
        p.add(box(sx, t, sz, bevel=0.012), GOLD, "gold", T(x, 0, z - sz / 2))
    for x in (-w / 2 + 0.04, w / 2 - 0.04):
        for z in (0.04, h - 0.04):
            p.add(sphere(0.06, 10, 8), GOLD, "gold", T(x, 0.02, z))
    p.add(sphere(0.09, 10, 8), BLUSH, "satin", T(0, 0.03, h - 0.04))  # a rose cartouche on top


BUILDERS = {
    "feyre_hall_map": hall_map, "infirmary_worktable": worktable, "deep_sink": deep_sink,
    "porcelain_bowl": bowl, "linen_folded": linen, "bandage_roll": bandage_roll,
    "hand_wrap_1": hand_wrap(1), "hand_wrap_2": hand_wrap(2), "hand_wrap_3": hand_wrap(3),
    "mural_frame": mural_frame,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    bad = 0
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
            bad += 1
        K.export_glb([ob, lo], os.path.join(OUT, pid + ".glb"))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
