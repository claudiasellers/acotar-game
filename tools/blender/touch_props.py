"""Loose physics props for the touchable world (T5, L59): bucket, firewood log,
glazed flower pot. Same kit and finish contract as the manor props
(prop_kit.py: vertex colour albedo, finish in UV.x, "opaque"/"clear" surfaces).

Run:  /opt/bpyenv/bin/python tools/blender/touch_props.py [--preview out.png]
Out:  art/props/touch/<id>.glb with nodes "<id>" and "<id>_lod1" (~50%).
Base centre at the origin, front -Z in Godot. Budget (R4): <= 3,000 tris.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,I001
import prop_kit as K  # noqa: E402

OUT = os.path.join(K.ROOT, "art/props/touch")
MAX_TRIS = 3000
# id: (w, h, d) metres, matching data/props/<id>.tres sizes.
SIZES = {
    "bucket": (0.42, 0.44, 0.42),
    "firewood_log": (0.95, 0.30, 0.30),
    "pot_glazed": (0.46, 0.46, 0.46),
}


def bucket(p):
    # Tapered wooden staves, two gilt hoops, a gold bail handle; water inside.
    n = 14
    for i in range(n):
        a = 2 * math.pi * i / n
        tone = K.mix(K.FAWN, K.OAK, 0.35 + 0.3 * ((i * 7) % 5) / 4.0)
        st = K.box(0.032, 0.086, 0.44, bevel=0.008)
        m = K.R("Z", math.degrees(a) + 90) @ K.T(0.185, 0, 0.22) @ K.R("Y", -4)
        p.add(st, tone, "satin", matrix=m)
    p.add(K.cyl(0.17, 0.03, n=16), K.OAK_DARK, "satin")
    for z in (0.09, 0.34):
        p.add(K.torus(0.2 + (0.006 if z > 0.2 else 0.0), 0.013, n=20, sides=5), K.GOLD, "gold", matrix=K.T(0, 0, z))
    p.add(K.cyl(0.185, 0.01, n=16), (0.72, 0.88, 0.98, 0.8), "water", matrix=K.T(0, 0, 0.36))
    bail = [(0.21 * math.cos(t), 0, 0.42 + 0.17 * math.sin(t)) for t in [math.pi * k / 10 for k in range(11)]]
    p.add(K.tube(bail, 0.009, sides=5), K.GOLD, "gold")


def firewood_log(p):
    # Rose-taupe bark round, pale cream end grain with rings, a sprig of moss.
    rng = random.Random(59)
    prof = []
    for k in range(9):
        z = -0.47 + 0.94 * k / 8
        prof.append((0.14 + rng.uniform(-0.006, 0.008), z))
    bark = K.lathe(prof, n=12, cap_bottom=False, cap_top=False)
    p.add(bark, K.BARK, "matte", matrix=K.R("Y", 90), sharp_deg=70)
    for s in (-1, 1):
        for r, c in ((0.135, K.CREAM), (0.09, K.mix(K.CREAM, K.FAWN, 0.4)), (0.045, K.CREAM)):
            d = K.disc(r, n=12)
            p.add(d, c, "satin", matrix=K.T(0.47 * s + 0.002 * s * (0.14 - r) * 10, 0, 0) @ K.R("Y", 90 * s))
    for i in range(3):
        x = -0.2 + 0.18 * i
        p.add(K.sphere(0.035, u=6, v=4), K.LEAF, "leaf", matrix=K.T(x, 0.02, 0.135) @ K.S(1.4, 1.0, 0.5))
    p.add(K.sphere(0.02, u=6, v=4), K.BLUSH, "fabric", matrix=K.T(-0.02, 0.03, 0.15))


def pot_glazed(p):
    # Rounded rose-glazed pot, pearl lip, gold band, painted butter dots; a
    # mound of soil and a blush bloom so it reads as a flower pot.
    prof = [(0.0, 0.0), (0.13, 0.0), (0.17, 0.02), (0.215, 0.12), (0.225, 0.22), (0.2, 0.33),
            (0.175, 0.38), (0.19, 0.4), (0.205, 0.43), (0.19, 0.44)]
    p.add(K.lathe(prof, n=20, cap_bottom=False, cap_top=False), K.ROSE, "pearl",
          shade=lambda v: K.mix(K.ROSE, K.BLUSH, min(1.0, max(0.0, v.z / 0.44))))
    p.add(K.torus(0.2, 0.012, n=20, sides=5), K.GOLD, "gold", matrix=K.T(0, 0, 0.34))
    for i in range(8):
        a = 2 * math.pi * i / 8
        p.add(K.sphere(0.018, u=6, v=4), K.BUTTER, "pearl",
              matrix=K.T(0.222 * math.cos(a), 0.222 * math.sin(a), 0.2) @ K.S(0.6, 0.6, 0.6))
    p.add(K.cyl(0.18, 0.02, n=16), K.OAK_DARK, "matte", matrix=K.T(0, 0, 0.405))
    for i in range(3):
        a = 2 * math.pi * i / 3
        K.bloom(p, (0.06 * math.cos(a), 0.06 * math.sin(a), 0.45), 0.05, K.BLUSH if i else K.LILAC,
                rings=2, per=5, rng=random.Random(i))


BUILDERS = {"bucket": bucket, "firewood_log": firewood_log, "pot_glazed": pot_glazed}


def main():
    K.reset()
    preview = None
    if "--preview" in sys.argv:
        preview = sys.argv[sys.argv.index("--preview") + 1]
    made = []
    for pid, size in SIZES.items():
        p = K.Prop(pid)
        BUILDERS[pid](p)
        p.fit(size)
        ob = p.to_object(pid)
        n = K.mesh_tris(ob)
        if n > MAX_TRIS:
            raise SystemExit("%s: %d tris > %d" % (pid, n, MAX_TRIS))
        lo = K.lod(ob, 0.5)
        lo.name = pid + "_lod1"
        K.export_glb([ob, lo], os.path.join(OUT, pid + ".glb"))
        print("%-14s %5d tris  lod1 %5d" % (pid, n, K.mesh_tris(lo)))
        made.append(ob)
        lo.hide_render = True
    if preview:
        import manor_props as MP
        MP.preview(made, preview, cols=3)


if __name__ == "__main__":
    main()
