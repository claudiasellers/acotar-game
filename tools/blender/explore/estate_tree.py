"""The estate's trees, from scratch (owner, 2026-11-12: "do you want to just
start from scratch instead" ... "totally fine go ahead"). A tree-builder
written for the estate's look, one species at a time:

  wood    a skeleton shaped on purpose (a stout trunk with a root flare,
          heavy limbs that kink and curve up, each forking once), skinned and
          subdivided (Skin + Subsurf), so it is one smooth organic body
  clouds  every limb ends inside a leaf cloud: a soft flattened ball built
          from leaf-clump cards (tools/court/explore/gen_candy_puff.py) whose
          normals are the cloud's, so the crown keeps the cotton-candy shapes
          and is made of leaves; a darker heart inside each for depth
  builds  the same recipe from another seed is another tree, so neighbours
          differ

What the earlier rounds taught: no twigs, every limb ends in a cloud, no
cloud floats, the outline is leaves.

Run:  <bpy python> tools/blender/explore/estate_tree.py [--only oak] [--seeds 3]
Out:  world/spring_court/manor_estate/flora/explore/tree_<species>_<a..>.glb
      (objects tree_<species>_<x>_bark / _leaves / _core)
Preview only: nothing in the game loads these yet.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import bpy  # noqa: E402,I001
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import prop_kit as K  # noqa: E402
import manor_flora as MF  # noqa: E402

OUT = os.path.join(K.ROOT, "world/spring_court/manor_estate/flora/explore")
UP = Vector((0, 0, 1))

# Lengths are fractions of the tree's height; angles in degrees.
#   trunk: radius at chest height; clear: the stem below the first limbs
#   whorls: rings of limbs up the trunk: (height, limbs, reach, rise0, rise1, forks)
#           reach = limb length, rise0/rise1 = angle above level at root/tip
#   kink: how far a limb's heading wanders per segment (the oak's gnarl)
#   cloud: cloud radius; flat: its height over its width; card: leaf-clump size
RECIPES = {
    "oak": dict(
        trunk=0.046, clear=0.22, lean=0.025,
        whorls=[(0.22, 3, 0.40, 16, 40, 2), (0.37, 3, 0.31, 40, 62, 1)],
        leader=0.60, kink=22, cloud=0.118, flat=0.82, card=0.085, cover=2.3, rim=0.28,
    ),
}


def heading(az, rise):
    return Vector((math.cos(az) * math.cos(rise), math.sin(az) * math.cos(rise), math.sin(rise)))


class Skeleton:
    def __init__(self):
        self.pos, self.rad, self.edges, self.tips = [], [], [], []

    def node(self, p, r, parent=None):
        self.pos.append(Vector(p))
        self.rad.append(r)
        if parent is not None:
            self.edges.append((parent, len(self.pos) - 1))
        return len(self.pos) - 1

    def limb(self, start, az, rise0, rise1, length, r0, r1, kink, rng, segs=3):
        """A limb from node `start`: it sets off at rise0, kinks from side to
        side and turns up to rise1. Returns its node indices."""
        at = self.pos[start].copy()
        out, prev = [], start
        side = rng.choice((-1, 1))
        for k in range(1, segs + 1):
            t = k / segs
            a = az + math.radians(kink) * side * (1 if k % 2 else -1) * rng.uniform(0.5, 1.0)
            at = at + heading(a, math.radians(rise0 + (rise1 - rise0) * t ** 0.8)) * (length / segs)
            prev = self.node(at, r0 + (r1 - r0) * t, prev)
            out.append(prev)
        return out


def grow(sid, rng):
    """The species' skeleton (unit height) and its cloud seats [(centre, radius)]."""
    rc = RECIPES[sid]
    sk = Skeleton()
    r = rc["trunk"]
    lean_az = rng.uniform(0, math.tau)
    lean = heading(lean_az, 0.0) * rc["lean"]
    top_z = rc["leader"]
    # the trunk: buried a little, flared at the root, a slow bend to the lean
    stem = [sk.node((0, 0, -0.02), r * 1.9)]
    for z, k in ((0.035, 1.35), (0.11, 1.06), (rc["clear"] * 0.62, 0.98)):
        stem.append(sk.node(lean * (z / top_z) ** 1.5 + Vector((0, 0, z)), r * k, stem[-1]))
    az0 = rng.uniform(0, math.tau)
    seats = []
    prev_h = None
    for wi, (wh, n, reach, rise0, rise1, forks) in enumerate(rc["whorls"]):
        hub = sk.node(lean * (wh / top_z) ** 1.5 + Vector((rng.uniform(-0.006, 0.006), rng.uniform(-0.006, 0.006), wh)), r * (0.92 - 0.2 * wi), stem[-1])
        stem.append(hub)
        for i in range(n):
            az = az0 + math.tau * (i + 0.5 * wi) / n + rng.uniform(-0.22, 0.22)
            ln = reach * rng.uniform(0.88, 1.12)
            lr = r * (0.62 - 0.12 * wi)
            limb = sk.limb(hub, az, rise0 + rng.uniform(-6, 6), rise1 + rng.uniform(-6, 6), ln, lr, lr * 0.5, rc["kink"], rng)
            seats.append((limb[-1], rc["cloud"] * rng.uniform(0.95, 1.15)))
            # each limb forks: side limbs off its middle, shorter, still rising
            for f in range(forks):
                sgn = 1 if f % 2 == 0 else -1
                at = limb[0 if f == 0 else 1]
                sub = sk.limb(at, az + sgn * math.radians(rng.uniform(42, 62)), rise0 + 14, rise1 + 6, ln * rng.uniform(0.5, 0.62), lr * 0.62, lr * 0.36, rc["kink"] * 0.7, rng, 2)
                seats.append((sub[-1], rc["cloud"] * rng.uniform(0.8, 1.0)))
    # the leader: the trunk's own top, one cloud over the crown
    tip = sk.node(lean + Vector((rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), top_z)), r * 0.5, stem[-1])
    top2 = sk.node(sk.pos[tip] + Vector((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), 0.13)), r * 0.3, tip)
    seats.append((top2, rc["cloud"] * 1.15))
    # every limb ends inside its cloud: the cloud sits just past the tip
    clouds = []
    for idx, cr in seats:
        out = Vector((sk.pos[idx].x, sk.pos[idx].y, 0.0))
        c = sk.pos[idx] + (out.normalized() * cr * 0.25 if out.length > 1e-5 else Vector()) + UP * cr * 0.35 * rc["flat"]
        clouds.append([c, cr])
    return sk, clouds


def settle(clouds):
    """No cloud floats and none swallows another: neighbours overlap a little."""
    for _ in range(6):
        for q in clouds:
            for o in clouds:
                if o is q:
                    continue
                d = q[0] - o[0]
                want = (q[1] + o[1]) * 0.74
                if 1e-6 < d.length < want:
                    q[0] += d.normalized() * (want - d.length) * 0.25


def wood(sk, name):
    """The skeleton skinned and subdivided: one smooth body."""
    bm = bmesh.new()
    layer = bm.verts.layers.skin.verify()
    vs = []
    for i, (p, r) in enumerate(zip(sk.pos, sk.rad)):
        v = bm.verts.new(p)
        v[layer].radius = (r, r)
        v[layer].use_root = i == 0
        vs.append(v)
    for a, b in sk.edges:
        bm.edges.new((vs[a], vs[b]))
    me = bpy.data.meshes.new(name + "_skel")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name + "_skel", me)
    bpy.context.scene.collection.objects.link(ob)
    skin = ob.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    skin.branch_smoothing = 0.6
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    # the subdivided body is rounder than it needs triangles for
    dec = ob.modifiers.new("dec", "DECIMATE")
    dec.ratio = 0.4
    done = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    out = bmesh.new()
    out.from_mesh(done.to_mesh())
    done.to_mesh_clear()
    bpy.data.objects.remove(ob, do_unlink=True)
    return out


def card(bm, uv, col, centre, normal, up, size, tone):
    u = up.cross(normal)
    if u.length < 1e-4:
        u = Vector((1, 0, 0)).cross(normal)
    u.normalize()
    v = normal.cross(u).normalized()
    h = size * 0.5
    f = bm.faces.new([bm.verts.new(centre + u * sx * h + v * sy * h) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    for loop, st in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop[uv].uv = st
        loop[col] = (tone, tone, tone, 1.0)


def foliage(sid, clouds, rng):
    """Leaf-clump cards over every cloud (shingled, a few standing out along
    the rim) with the cloud's own normals, and the hearts inside."""
    rc = RECIPES[sid]
    crown = sum((c * r for c, r in clouds), Vector()) / sum(r for _, r in clouds)
    leaves = bmesh.new()
    uv = leaves.loops.layers.uv.new("UVMap")
    col = leaves.loops.layers.float_color.new("Col")
    normals = []
    core = K.Prop("core")
    flat = Matrix.Diagonal((1.0, 1.0, rc["flat"]))
    for ci, (cc, r) in enumerate(clouds):
        tone = 0.9 + 0.2 * rng.random()
        n = max(10, round(4 * math.pi * r * r * rc["cover"] / (rc["card"] ** 2)))
        for i in range(n):
            z = 1.0 - 2.0 * (i + 0.5) / n
            if z < -0.45:
                continue   # a cloud's flat underside: the heart shows, shaded
            a = i * 2.39996 + rng.uniform(-0.3, 0.3)
            d = Vector((math.sqrt(1 - z * z) * math.cos(a), math.sqrt(1 - z * z) * math.sin(a), z))
            at = cc + flat @ (d * r * 0.92)
            shade = (d * 0.6 + (at - crown).normalized() * 0.4).normalized()
            jit = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
            s = rc["card"] * rng.uniform(0.85, 1.15)
            card(leaves, uv, col, at, (d + jit * 0.45).normalized(), Matrix.Rotation(rng.uniform(0, math.tau), 3, d) @ UP, s, tone)
            normals += [shade] * 4
            if rng.random() < rc["rim"]:
                side = d.cross(jit)
                side = side.normalized() if side.length > 1e-3 else d.orthogonal().normalized()
                card(leaves, uv, col, at + d * s * 0.1, side, side.cross(d), s, tone)
                normals += [shade] * 4
        MF.blob(core, cc.x, cc.y, cc.z, r * 0.7, (1, 1, 1), rng, 1, rc["flat"], fine=1)
    return leaves, normals, core


def build(sid, letter, seed):
    kind, h, col = MF.species()[sid]
    name = f"tree_{sid}_{letter}"
    rng = random.Random(seed)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    sk, clouds = grow(sid, rng)
    settle(clouds)
    bark = wood(sk, name)
    leaves, normals, core = foliage(sid, clouds, rng)
    # to the species height, standing on the ground (the root stays buried)
    top = max(v.co.z for b in (leaves, core.bm) for v in b.verts)
    m = K.S(h / top)
    for b in (bark, leaves, core.bm):
        bmesh.ops.transform(b, matrix=m, verts=b.verts)
    objs = []
    for part, b in (("bark", bark), ("leaves", leaves)):
        me = bpy.data.meshes.new(f"{name}_{part}")
        b.to_mesh(me)
        for poly in me.polygons:
            poly.use_smooth = True
        if part == "leaves":
            me.normals_split_custom_set_from_vertices([tuple(n) for n in normals])
            me.color_attributes.active_color_name = "Col"
            me.attributes.default_color_name = "Col"
        me.materials.append(bpy.data.materials.new(f"tree_{part}"))
        ob = bpy.data.objects.new(f"{name}_{part}", me)
        bpy.context.scene.collection.objects.link(ob)
        objs.append(ob)
    objs.append(core.to_object(f"{name}_core"))
    tris = [K.mesh_tris(o) for o in objs]
    print(f"  {name:18s} {sum(tris):5d} tris (bark {tris[0]}, leaves {tris[1]}, core {tris[2]}; {len(clouds)} clouds)")
    K.export_glb(objs, os.path.join(OUT, f"{name}.glb"))


def main():
    K.reset()
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else list(RECIPES)
    seeds = int(sys.argv[sys.argv.index("--seeds") + 1]) if "--seeds" in sys.argv else 3
    for sid in only:
        for k in range(seeds):
            build(sid, "abcdef"[k], sum(map(ord, sid)) * 7 + 101 * k)


if __name__ == "__main__":
    main()
