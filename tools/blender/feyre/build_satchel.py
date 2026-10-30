"""Feyre's satchel, worn cross-body: strap over the right shoulder, bag on the left hip.

Keeper (lore/06-items/key-objects.md, "Feyre's bags and kit"): "satchel" is canon (ch 3, the wolf hide
goes to market in it; ch 8, a satchel from her manor armoire).  Material and how it's worn are [X]:
plain patched leather in Act I, a finer armoire one later.

Reproducible build (needs characters/feyre/model/feyre.blend from build_feyre.py):
    /opt/bpyenv/bin/python tools/blender/feyre/build_satchel.py [satchel_patched|satchel_manor]

Writes characters/feyre/satchel/<name>.glb, skinned to the 60-bone armature of feyre.blend.
The strap takes the body's weights (fit 18 mm, clear of the leathers belt at 14-16 mm); the bag rides
85% Hips / 15% LeftUpperLeg so it sways with her stride without tearing.  Seeded; <= 3k tris each.
"""

import math
import os
import sys
from typing import List

import bpy  # noqa: E402  (before bmesh)
import bmesh
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_feyre as bf  # noqa: E402
import build_gowns as bg  # noqa: E402
import build_wardrobe as bw  # noqa: E402
from build_feyre import MODEL_DIR  # noqa: E402
from build_gowns import BodyProbe, Builder  # noqa: E402

SEED = 23
TRI_BUDGET = 3000
OUT_DIR = os.path.join(os.path.dirname(MODEL_DIR), "satchel")
V = Vector

STRAP_LIFT = 0.026           # off the skin, over the hunter tunic
STRAP_W, STRAP_T = 0.036, 0.006
# Bag on the outside of the left hip (+X is her left; -Y is front).
BAG_W, BAG_H, BAG_D = 0.25, 0.19, 0.07   # along Y, Z, X
BAG_Z = 0.80
BAG_Y = -0.015

PAL = {
    "satchel_patched": {
        "fabric": (bw.LEATHER, 0.62, 0.0), "leather_d": (bw.LEATHER_D, 0.58, 0.0),
        "patch": ("C9B79C", 0.75, 0.0), "patch_b": ("A7B59A", 0.75, 0.0), "cord": (bw.CREAM, 0.8, 0.0),
        "brass": ("B89A62", 0.45, 0.5),
    },
    "satchel_manor": {
        "fabric": ("E7B7BE", 0.42, 0.0), "leather_d": ("D59AA6", 0.40, 0.0), "cord": (bw.CREAM, 0.6, 0.0),
        "brass": bw.METAL, "flowers": (bw.ROSE, 0.40, 0.0), "flower_centers": (bw.GOLD_LIT, 0.35, 0.3),
        "leaves": (bw.SAGE, 0.5, 0.0),
    },
}


# --------------------------------------------------------------------------
# Strap: a flat ribbon traced over the body, front and back, over the right shoulder.
# --------------------------------------------------------------------------
def _hit(probe: BodyProbe, origin: Vector, d: Vector):
    loc, nrm, _, _ = probe.bvh.ray_cast(origin, d, 2.0)
    return loc, nrm


def strap_path(probe: BodyProbe) -> List[tuple]:
    """(point, normal) from the bag's front ring, up the chest, over the right shoulder, down the back.

    The strap is a tilted loop round the torso: lowest at the left hip, highest at the right shoulder,
    traced with rays out from the body axis (like a belt), and a cap of downward rays over the shoulder
    where a sideways ray would miss."""
    z_mid, amp, cap = 1.13, 0.20, math.radians(38)

    def ring(angles) -> List[tuple]:
        out = []
        for a in angles:
            z = z_mid - amp * math.sin(a)
            loc, nrm = probe.bvh.ray_cast(V((0, probe.cy(z), z)), V((math.sin(a), -math.cos(a), 0)), 1.0)[:2]
            if loc is not None:
                out.append((V(loc), V(nrm)))
        return out

    # Front: left hip (a = 70 deg) round the front (a = 0) to the shoulder; back: shoulder to the left hip
    # from behind (a = 110 deg, written -250 so the angles run on).
    front = ring(np.linspace(math.radians(80), -math.pi / 2 + cap, 22))
    back = ring(np.linspace(-math.pi / 2 - cap, math.radians(100) - 2 * math.pi, 22))
    xs = min((front[-1][0].x + back[0][0].x) / 2, -0.13)   # on the shoulder, clear of the head
    cap_pts = []
    for y in np.linspace(front[-1][0].y, back[0][0].y, 9)[1:-1]:
        loc, nrm = probe.bvh.ray_cast(V((xs, y, 1.47)), V((0, 0, -1)), 1.0)[:2]
        if loc is not None:
            cap_pts.append((V(loc), V(nrm)))
    pts = front + cap_pts + back
    P = np.array([p for p, _ in pts])
    N = np.array([n for _, n in pts])
    for _ in range(10):
        P[1:-1] = 0.25 * P[:-2] + 0.5 * P[1:-1] + 0.25 * P[2:]
        N[1:-1] = 0.25 * N[:-2] + 0.5 * N[1:-1] + 0.25 * N[2:]
    N /= np.linalg.norm(N, axis=1)[:, None]
    return [(V(p) + V(n) * STRAP_LIFT, V(n)) for p, n in zip(P, N)]


def ribbon(B: Builder, path: List[tuple], width: float, thick: float, mat: str) -> None:
    rings = []
    for i, (p, n) in enumerate(path):
        a = path[max(i - 1, 0)][0]
        b = path[min(i + 1, len(path) - 1)][0]
        t = (b - a).normalized()
        side = n.cross(t).normalized()
        h, w = n * thick * 0.5, side * width * 0.5
        rings.append(np.array([p - w - h, p + w - h, p + w + h, p - w + h]))
    i0 = len(B.bm.verts)
    faces = B.grid(rings, [mat])
    B.orient(faces, lambda c: c - min((q for q, _ in path), key=lambda q: (q - c).length_squared))
    B.mark("shell", i0, fit=STRAP_LIFT - 0.004)


# --------------------------------------------------------------------------
# Bag: bevelled boxes in the bag's own frame (out = +X, across = Y, up = Z).
# --------------------------------------------------------------------------
def rbox(B: Builder, centre: Vector, size: Vector, mat: str, bevel: float, kind: str = "bag",
         segs: int = 2, taper: float = 0.0) -> None:
    bm = bmesh.new()
    M = Matrix.Translation(centre) @ Matrix.Diagonal((*size, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    if taper:                                    # a bag is a little fuller at the bottom
        for v in bm.verts:
            if v.co.z < centre.z:
                v.co.x = centre.x + (v.co.x - centre.x) * (1.0 + taper)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segs, profile=0.6, affect="EDGES")
    bw.add_bm(B, bm, mat, kind)
    bm.free()


def build_bag(B: Builder, probe: BodyProbe, manor: bool, rng, ends) -> None:
    # Outside of the left hip at BAG_Z.
    side, _ = _hit(probe, V((0.5, BAG_Y, BAG_Z)), V((-1, 0, 0)))
    x0 = side.x + 0.012
    c = V((x0 + BAG_D * 0.5, BAG_Y, BAG_Z))
    rbox(B, c, V((BAG_D, BAG_W, BAG_H)), "fabric", 0.02, taper=0.12)
    out = x0 + BAG_D * (1.06)
    top = BAG_Z + BAG_H * 0.5
    # Flap over the top and two thirds of the outer face.
    fh = BAG_H * 0.62
    rbox(B, V((out + 0.004, BAG_Y, top - fh * 0.5 + 0.006)), V((0.012, BAG_W * 1.03, fh)), "leather_d", 0.006)
    rbox(B, V((x0 + BAG_D * 0.55, BAG_Y, top + 0.006)), V((BAG_D * 1.05, BAG_W * 1.03, 0.012)), "leather_d", 0.006)
    # Clasp strap and buckle.
    cz = top - fh + 0.004
    rbox(B, V((out + 0.012, BAG_Y, cz + 0.012)), V((0.006, 0.030, 0.07)), "fabric", 0.002, segs=1)
    bw.torus(B, V((out + 0.016, BAG_Y, cz - 0.004)), V((1, 0, 0)), 0.014, 0.0028, "brass", 12, 4)
    if manor:
        # Gold piping round the flap and a rose on it.
        y0, y1 = BAG_Y - BAG_W * 0.5, BAG_Y + BAG_W * 0.5
        edge = np.array([(out + 0.011, y0, top), (out + 0.011, y0, top - fh), (out + 0.011, y1, top - fh),
                         (out + 0.011, y1, top)])
        B.tube(edge, 0.0024, 4, "brass", cap=False)
        B.rose(V((out + 0.016, BAG_Y - 0.05, top - fh * 0.45)), V((1, 0, 0)), 0.03, pmat="flowers")
        B.leaf(V((out + 0.014, BAG_Y - 0.02, top - fh * 0.5)), V((0, 1, -0.4)), V((1, 0, 0)), 0.03, 0.01, "leaves")
    else:
        # Patches and their running stitch: the family has mended it for years.
        for (py, pz, w, h, mat) in ((BAG_Y + 0.07, BAG_Z - 0.06, 0.07, 0.05, "patch"),
                                    (BAG_Y - 0.08, top - 0.04, 0.05, 0.04, "patch_b")):
            px = out + (0.012 if pz > cz else -0.004)
            rbox(B, V((px, py, pz)), V((0.004, w, h)), mat, 0.0015, segs=1)
            for k in range(10):
                a = 2 * math.pi * k / 10 + rng.uniform(-0.1, 0.1)
                B.ellipsoid(V((px + 0.003, py + math.cos(a) * w * 0.44, pz + math.sin(a) * h * 0.42)),
                            V((0.0012, 0, 0)), V((0, 0.0035, 0)), V((0, 0, 0.0012)), "cord", 4, 2)
    # Strap anchors (rings) at the two top corners; the strap meets them front and back.
    # Strap rings on the bag's top edge under each strap end, and a short tab from ring to strap.
    ring_x = x0 + BAG_D * 0.35
    for end in ends:
        p = V((ring_x, end.y, top + 0.016))
        bw.torus(B, p, V((0, 1, 0)), 0.013, 0.0026, "brass", 12, 4)
        B.tube(np.array([p + V((0, 0, 0.008)), end]), STRAP_T * 0.5, 4, "fabric",
               squash=STRAP_W * 0.8 / STRAP_T, cap=True)


def bag_weights(obj, B: Builder) -> None:
    """Re-weight every bag part: 85% Hips, 15% LeftUpperLeg."""
    idx = [i for kind, i0, i1, _ in B.parts if kind == "bag" for i in range(i0, i1)]
    for g in obj.vertex_groups:
        g.remove(idx)
    for name, w in (("Hips", 0.85), ("LeftUpperLeg", 0.15)):
        g = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
        g.add(idx, w, "REPLACE")


def build(name: str, probe: BodyProbe, arm, spec) -> bpy.types.Object:
    manor = name == "satchel_manor"
    rng = np.random.default_rng(SEED + len(name))
    B = Builder(name, "fabric", {**bw.PAL, **PAL[name]})
    i_bag = len(B.bm.verts)
    path = strap_path(probe)
    build_bag(B, probe, manor, rng, (path[0][0], path[-1][0]))
    bag_parts = [(k, a, b, p) for k, a, b, p in B.parts]
    # Everything built in build_bag that wasn't marked by a helper is bag too.
    B.parts = [("bag", i_bag, len(B.bm.verts), {})]
    del bag_parts
    ribbon(B, path, STRAP_W, STRAP_T, "fabric")
    obj = bw.finalize(B, name, probe, arm, spec)
    bag_weights(obj, B)
    return obj


def main(only=()) -> None:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(MODEL_DIR, "feyre.blend"))
    for n in [o.name for o in bpy.data.objects if o.name.startswith("hunter_") or o.name == "Body_LOD1"]:
        bpy.data.objects.remove(bpy.data.objects[n])
    body, arm = bpy.data.objects["Body"], bpy.data.objects["Armature"]
    spec = [(bn.name, tuple(bn.head_local), tuple(bn.tail_local), None, bn.use_deform) for bn in arm.data.bones]
    probe = BodyProbe(body)
    os.makedirs(OUT_DIR, exist_ok=True)
    lines = []
    for name in PAL:
        if only and name not in only:
            continue
        obj = build(name, probe, arm, spec)
        t = bf.tri_count(obj)
        lines.append("%-16s tris=%4d/%d%s" % (name, t, TRI_BUDGET, " OVER" if t > TRI_BUDGET else ""))
        bpy.context.view_layer.update()
        bg.export_named(os.path.join(OUT_DIR, name + ".glb"), obj, arm)
    print("\n==== SATCHEL BUILD REPORT ====")
    print("\n".join(lines))


if __name__ == "__main__":
    main([a for a in sys.argv[1:] if a in PAL])
