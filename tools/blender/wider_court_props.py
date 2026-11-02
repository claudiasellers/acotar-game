"""The p4 story props (L44): the picnic in the glen (ch 18), the sentries'
butts and warbow chest on the fells, the potion room's cauldron and the
stable grooming kit. Headless Blender, deterministic; same contract as the
manor props (prop_kit.py: one mesh, finishes in UV.x, front +Y, fitted).

Run:  /opt/bpyenv/bin/python tools/blender/wider_court_props.py [--only id,id]
Out:  story/act4/models/<id>.glb with nodes "<id>" and "<id>_lod1".
Budget (R4): <= 3,000 tris per prop, LOD1 ~50%.

Canon: the purple blanket and the wine are Lucien's picnic [C ch18]
(Keeper); the plaid, tassels, goblets, cauldron, chest and kit are [X].
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import bmesh  # noqa: E402
import prop_kit as K  # noqa: E402
from prop_kit import (BLUSH, BUTTER, COPPER, GOLD, IRON, STRAW, LILAC, MINT, OAK, OAK_DARK, PEARL, PERI, ROSE, WHITE,  # noqa: E402
                      R, S, T, box, cyl, lathe, sphere, torus, tube)

OUT = os.path.join(K.ROOT, "story/act4/models")
MAX_TRIS = 3000

PURPLE = (0.55, 0.36, 0.72)
PURPLE_DEEP = (0.40, 0.24, 0.56)
WINE = (0.55, 0.10, 0.22)


def _cloth(sx, sy, nx, ny, rng, ripple=0.012):
    """A soft rumpled sheet, sx by sy, centred, lying on z=0."""
    bm = bmesh.new()
    vs = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            x = (i / nx - 0.5) * sx
            y = (j / ny - 0.5) * sy
            edge = min(i, nx - i, j, ny - j)
            z = ripple * (math.sin(x * 9.0 + rng.uniform(0, 0.4)) * math.cos(y * 7.0)) + (0.004 if edge > 0 else 0.0)
            row.append(bm.verts.new((x, y, max(z, 0.0) + 0.006)))
        vs.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new([vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]])
    return bm


def picnic_blanket(p, size, _c):
    """Lucien's purple blanket: a lilac-and-gold plaid, a tasselled fringe, two
    plump cushions and a folded corner."""
    rng = random.Random(1801)
    w, d = 2.4, 1.9
    p.add(_cloth(w, d, 14, 12, rng), PURPLE, "fabric")
    # plaid bands, a hair above the cloth
    for k in range(5):
        x = (k / 4 - 0.5) * (w - 0.3)
        p.add(box(0.07, d - 0.06, 0.004), LILAC if k % 2 else BUTTER, "fabric", T(x, 0, 0.022))
    for k in range(4):
        y = (k / 3 - 0.5) * (d - 0.3)
        p.add(box(w - 0.06, 0.07, 0.004), LILAC if k % 2 else GOLD, "fabric", T(0, y, 0.024))
    # tassels along the short ends
    for side in (-1, 1):
        for k in range(11):
            y = (k / 10 - 0.5) * (d - 0.1)
            x = side * (w / 2 + 0.04)
            p.add(tube([(side * w / 2, y, 0.01), (x, y, 0.006)], 0.008, 4), GOLD, "gold")
            p.add(sphere(0.016, 6, 4), BUTTER, "fabric", T(x + side * 0.012, y, 0.012))
    # folded corner
    p.add(box(0.42, 0.42, 0.02, bevel=0.008), PURPLE_DEEP, "fabric", T(w / 2 - 0.26, d / 2 - 0.26, 0.03) @ R("Z", 45))
    # cushions
    for (x, y, col) in ((-0.7, 0.5, ROSE), (-0.35, 0.62, PERI)):
        p.add(K.cushion(0.46, 0.46, 0.14, puff=0.45), col, "fabric", T(x, y, 0.1))
        p.add(sphere(0.03, 6, 4), GOLD, "gold", T(x, y, 0.17))


def picnic_wine(p, size, _c):
    """The wine Lucien kept: a bottle, two gilt goblets and a plate of cakes."""
    p.add(lathe([(0, 0), (0.042, 0), (0.044, 0.02), (0.044, 0.2), (0.03, 0.24), (0.014, 0.27),
                 (0.014, 0.32), (0.017, 0.33), (0, 0.33)], 14), WINE, "glass", T(-0.12, 0.0, 0))
    p.add(lathe([(0, 0), (0.046, 0), (0.046, 0.09), (0, 0.09)], 14), PEARL, "satin", T(-0.12, 0.0, 0.1))
    for (x, y) in ((0.05, -0.08), (0.14, 0.05)):
        p.add(lathe([(0, 0), (0.035, 0), (0.035, 0.008), (0.006, 0.02), (0.006, 0.08), (0.03, 0.095),
                     (0.042, 0.15), (0, 0.15)], 12), GOLD, "gold", T(x, y, 0))
    p.add(cyl(0.11, 0.012, 16), PEARL, "pearl", T(0.0, 0.18, 0))
    for k in range(5):
        a = k / 5 * math.tau
        p.add(cyl(0.025, 0.03, 8), [BLUSH, MINT, BUTTER, LILAC, ROSE][k], "satin",
              T(math.cos(a) * 0.06, 0.18 + math.sin(a) * 0.06, 0.012))
        p.add(sphere(0.008, 5, 3), ROSE, "satin", T(math.cos(a) * 0.06, 0.18 + math.sin(a) * 0.06, 0.045))


def sentry_butt(p, size, _c):
    """A sentry's archery butt on the fells: a thick straw boss bound in rope
    on an oak trestle, painted rings (pearl, periwinkle, rose, gold heart)."""
    p.add(box(0.1, 0.1, 1.5, bevel=0.01), OAK, "satin", T(-0.45, -0.25, 0) @ R("X", -12))
    p.add(box(0.1, 0.1, 1.5, bevel=0.01), OAK, "satin", T(0.45, -0.25, 0) @ R("X", -12))
    p.add(box(0.08, 0.08, 1.4, bevel=0.01), OAK_DARK, "satin", T(0.0, 0.45, 0) @ R("X", 25))
    face = T(0, -0.05, 1.05) @ R("X", 78)
    p.add(cyl(0.62, 0.32, 24), STRAW, "fabric", face)
    for k in range(4):
        p.add(torus(0.62, 0.02, 24, 5), OAK_DARK, "satin", face @ T(0, 0, 0.04 + k * 0.08))
    for r, col in ((0.56, PEARL), (0.42, PERI), (0.27, ROSE), (0.12, GOLD)):
        p.add(cyl(r, 0.01, 24), col, "gold" if col == GOLD else "satin", face @ T(0, 0, 0.32 + (0.6 - r) * 0.01))


def warbow_chest(p, size, _c):
    """The sentries' chest in the tower: iron-bound oak, a gilt thorn-and-rose
    clasp (the Spring Court's mark [X])."""
    p.add(box(1.1, 0.55, 0.5, bevel=0.02), OAK, "satin", T(0, 0, 0.25))
    p.add(K.lathe([(0, 0), (0.28, 0), (0.28, 1.1), (0, 1.1)], 12), OAK_DARK, "satin",
          T(-0.55, 0, 0.5) @ R("Y", 90) @ S(1.0, 0.98, 1.0))
    for x in (-0.42, 0.0, 0.42):
        p.add(box(0.05, 0.57, 0.52, bevel=0.005), IRON, "satin", T(x, 0, 0.25))
        p.add(torus(0.28, 0.02, 14, 4), IRON, "satin", T(x, 0, 0.5) @ R("Y", 90) @ S(1, 1, 1))
    p.add(box(0.16, 0.03, 0.2, bevel=0.01), GOLD, "gold", T(0, -0.29, 0.42))
    p.add(sphere(0.04, 8, 5), ROSE, "pearl", T(0, -0.31, 0.47))
    for k in range(5):
        a = k / 5 * math.tau
        p.add(sphere(0.022, 6, 4), BLUSH, "pearl", T(math.cos(a) * 0.04, -0.31, 0.47 + math.sin(a) * 0.04))


def fae_cauldron(p, size, _c):
    """The potion room's cauldron: a round copper belly on three gilt claw feet,
    a pearly brew that glows mint, bubbles and a ladle."""
    p.add(lathe([(0, 0.12), (0.3, 0.14), (0.42, 0.3), (0.44, 0.48), (0.38, 0.62), (0.4, 0.66),
                 (0.36, 0.66), (0.33, 0.62), (0, 0.6)], 20), COPPER, "gold")
    for k in range(3):
        a = k / 3 * math.tau
        p.add(tube([(math.cos(a) * 0.3, math.sin(a) * 0.3, 0.18), (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.0)],
                   [0.035, 0.025], 6), GOLD, "gold")
        p.add(sphere(0.04, 6, 4), GOLD, "gold", T(math.cos(a) * 0.41, math.sin(a) * 0.41, 0.02))
    p.add(cyl(0.355, 0.02, 20), MINT, "glow", T(0, 0, 0.6))
    rng = random.Random(4401)
    for _k in range(7):
        r, a = rng.uniform(0.05, 0.3), rng.uniform(0, math.tau)
        p.add(sphere(rng.uniform(0.02, 0.045), 7, 5), lighter_mint(), "glow",
              T(math.cos(a) * r, math.sin(a) * r, 0.62))
    for side in (-1, 1):
        p.add(torus(0.07, 0.012, 10, 4), GOLD, "gold", T(side * 0.43, 0, 0.6) @ R("Y", 90))
    p.add(tube([(0.1, 0.05, 0.6), (0.25, 0.2, 0.95)], 0.012, 5), OAK, "satin")
    p.add(sphere(0.05, 8, 5), GOLD, "gold", T(0.08, 0.03, 0.58) @ S(1, 1, 0.5))


def lighter_mint():
    return K.lighter(MINT, 0.4)


def grooming_kit(p, size, _c):
    """A stable grooming box: a painted wooden tote with a curry comb, two
    brushes and a ribbon for the mane."""
    p.add(box(0.5, 0.26, 0.16, bevel=0.01), MINT, "satin", T(0, 0, 0.08))
    p.add(box(0.04, 0.04, 0.24), OAK, "satin", T(-0.22, 0, 0.2))
    p.add(box(0.04, 0.04, 0.24), OAK, "satin", T(0.22, 0, 0.2))
    p.add(tube([(-0.22, 0, 0.32), (0.22, 0, 0.32)], 0.018, 6), OAK, "satin")
    for (x, col) in ((-0.1, ROSE), (0.08, PERI)):
        p.add(box(0.16, 0.07, 0.05, bevel=0.012), col, "satin", T(x, -0.03, 0.19))
        p.add(box(0.15, 0.06, 0.03), BUTTER, "fabric", T(x, -0.03, 0.155))
    p.add(K.torus(0.05, 0.012, 12, 4), GOLD, "gold", T(0.2, 0.09, 0.18))
    p.add(tube([(-0.25, 0.1, 0.16), (-0.33, 0.16, 0.02), (-0.3, 0.2, 0.0)], 0.01, 4), BLUSH, "fabric")


BUILDERS = {
    # id: (builder, (w, h, d) in metres)
    "picnic_blanket": (picnic_blanket, (2.6, 0.2, 2.0)),
    "picnic_wine": (picnic_wine, (0.4, 0.33, 0.42)),
    "sentry_butt": (sentry_butt, (1.35, 1.75, 1.0)),
    "warbow_chest": (warbow_chest, (1.15, 0.8, 0.62)),
    "fae_cauldron": (fae_cauldron, (0.95, 0.95, 0.95)),
    "grooming_kit": (grooming_kit, (0.6, 0.33, 0.3)),
}


def main():
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))
    failed = []
    for pid, (fn, size) in BUILDERS.items():
        if only and pid not in only:
            continue
        K.reset()
        p = K.Prop(pid)
        fn(p, size, None)
        p.fit(size)
        ob = p.to_object(pid)
        n = K.mesh_tris(ob)
        lo = K.lod(ob, 0.5 if n > 300 else 0.6)
        lo.name = pid + "_lod1"
        print(f"{pid}: {n} tris, lod1 {K.mesh_tris(lo)}")
        if n > MAX_TRIS:
            failed.append(pid)
        K.export_glb([ob, lo], os.path.join(OUT, f"{pid}.glb"))
    if failed:
        print("over budget:", failed)
        sys.exit(1)


if __name__ == "__main__":
    main()
