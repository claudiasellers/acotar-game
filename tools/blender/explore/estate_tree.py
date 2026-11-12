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
#   optional: flare (root radius x trunk, 1.9), limb (limb radius x trunk, 0.62),
#   top (the leader's last reach, 0.13), top_cloud (x cloud, 1.15),
#   weep (the willow: fronds instead of leaf clouds, see its recipe), fruit (pears per cloud)
RECIPES = {
    # the parkland oak: stout, four long low limbs, a broad tiered crown (owner: "a bit broader", "those look good")
    "oak": dict(
        trunk=0.046, clear=0.25, lean=0.025,
        whorls=[(0.25, 4, 0.44, 12, 38, 2), (0.39, 3, 0.33, 38, 60, 1)],
        leader=0.62, kink=22, cloud=0.12, flat=0.8, card=0.085, cover=2.1, rim=0.26,
    ),
    # the birch: a slender white stem that keeps going, short upswept limbs
    # ring after ring, small airy clouds in a narrow crown
    "birch": dict(
        trunk=0.021, clear=0.36, lean=0.045, flare=1.5, limb=0.5,
        whorls=[(0.36, 3, 0.2, 30, 58, 1), (0.5, 3, 0.18, 36, 62, 0), (0.63, 3, 0.15, 42, 66, 0), (0.75, 2, 0.12, 48, 70, 0)],
        leader=0.83, top=0.07, top_cloud=1.0, kink=10, cloud=0.072, flat=0.9, card=0.07, cover=1.6, rim=0.3,
    ),
    # the cherry: a short trunk opening into a wide vase, blossom clouds
    "cherry_blossom": dict(
        trunk=0.038, clear=0.27, lean=0.03, flare=1.7,
        whorls=[(0.27, 4, 0.46, 26, 50, 2), (0.39, 3, 0.36, 46, 66, 1)],
        leader=0.56, top=0.15, kink=16, cloud=0.15, flat=0.82, card=0.12, cover=2.1, rim=0.26,
    ),
    # the apple: low, round and gnarled
    "apple_blossom": dict(
        trunk=0.042, clear=0.25, lean=0.04, flare=1.8,
        whorls=[(0.25, 4, 0.4, 18, 44, 2), (0.37, 3, 0.3, 42, 62, 1)],
        leader=0.5, top=0.13, kink=28, cloud=0.16, flat=0.8, card=0.13, cover=2.1, rim=0.26,
    ),
    # the crab apple: smaller in the limb and more upright, a tight round head
    "crab_apple": dict(
        trunk=0.036, clear=0.28, lean=0.03, flare=1.7,
        whorls=[(0.28, 3, 0.34, 34, 58, 2), (0.41, 3, 0.27, 50, 68, 1)],
        leader=0.52, top=0.14, kink=20, cloud=0.155, flat=0.86, card=0.13, cover=2.1, rim=0.26,
    ),
    # the pear: upright, an oval crown, pears hanging under the leaves
    "pear_tree": dict(
        trunk=0.04, clear=0.26, lean=0.02, flare=1.6,
        whorls=[(0.26, 3, 0.27, 38, 66, 1), (0.42, 3, 0.23, 46, 70, 1), (0.57, 3, 0.17, 54, 74, 0)],
        leader=0.7, top=0.12, kink=14, cloud=0.118, flat=0.92, card=0.1, cover=2.1, rim=0.26, fruit=1.4,
    ),
    # the willow: a short leaning trunk, slender limbs that climb, arch over
    # and droop, and nothing on them but fronds: strands that leave the limb,
    # roll over a shoulder and fall towards the ground (owner, 2026-11-12: "i
    # love the cascading leaves ... but i dont like the clumps at the top ...
    # thats not what actual willows look like"). No leaf clouds.
    #   weep: fronds per limb, frond width, the shoulder's reach, how near the ground they hang
    "willow": dict(
        trunk=0.046, clear=0.3, lean=0.07, flare=1.8, limb=0.5,
        whorls=[(0.3, 4, 0.36, 50, -18, 1), (0.4, 4, 0.32, 62, -12, 1), (0.49, 3, 0.25, 74, -4, 1)],
        leader=0.57, top=0.07, kink=14, cloud=0.1, flat=0.7, card=0.1, cover=1.7, rim=0.2,
        weep=(9, 0.15, 0.12, 0.11),
        variants=[("d", dict(trail=0.2)), ("e", dict(trail=1.0))],
    ),
}


def heading(az, rise):
    return Vector((math.cos(az) * math.cos(rise), math.sin(az) * math.cos(rise), math.sin(rise)))


class Skeleton:
    def __init__(self):
        self.pos, self.rad, self.edges, self.tips, self.limbs = [], [], [], [], []

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
        self.limbs.append([start] + out)
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
    stem = [sk.node((0, 0, -0.02), r * rc.get("flare", 1.9))]
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
            lr = r * (rc.get("limb", 0.62) - 0.12 * wi)
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
    top2 = sk.node(sk.pos[tip] + Vector((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), rc.get("top", 0.13))), r * 0.3, tip)
    seats.append((top2, rc["cloud"] * rc.get("top_cloud", 1.15)))
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
    dec.ratio = 0.33
    done = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    out = bmesh.new()
    out.from_mesh(done.to_mesh())
    done.to_mesh_clear()
    bpy.data.objects.remove(ob, do_unlink=True)
    return out


def card(bm, uv, col, centre, normal, up, size, tone, u0=0.0, u1=1.0):
    """A card facing `normal`, its picture's top towards `up`; size is a
    side or (width, height); u0..u1 picks a strip of the picture."""
    u = up.cross(normal)
    if u.length < 1e-4:
        u = Vector((1, 0, 0)).cross(normal)
    u.normalize()
    v = normal.cross(u).normalized()
    w, h = (size[0] * 0.5, size[1] * 0.5) if isinstance(size, tuple) else (size * 0.5, size * 0.5)
    f = bm.faces.new([bm.verts.new(centre + u * sx * w + v * sy * h) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    for loop, st in zip(f.loops, ((u0, 0), (u1, 0), (u1, 1), (u0, 1))):
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
            if z < -0.45 and rng.random() < 0.4:
                continue   # thinner on a cloud's underside
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
        MF.blob(core, cc.x, cc.y, cc.z, r * 0.62, (1, 1, 1), rng, 1, rc["flat"], fine=1)
    return leaves, normals, core


def curtain(sid, sk, rng, trail=0.0):
    """The willow's fronds. Each is a ribbon of hanging strands that leaves a
    limb, rolls outward over a shoulder and falls: thick along the limbs'
    outer reach and at their tips, so the crown's top is the limbs' arch
    draped in strands and the rest is a curtain to near the ground.
    trail: the share of strands that fall all the way to the ground (0 the
    curtain stops short, 0.3 some trail, 1 every strand is that long)."""
    n, width, reach, foot = RECIPES[sid]["weep"]
    fronds = bmesh.new()
    uv = fronds.loops.layers.uv.new("UVMap")
    col = fronds.loops.layers.float_color.new("Col")
    normals = []
    seats = []
    for limb in sk.limbs:
        pts = [sk.pos[i] for i in limb]
        for k in range(n):
            # along the limb's outer two thirds, crowding towards the tip
            t = 0.2 + 0.8 * ((k + rng.random()) / n) ** 0.8
            f = t * (len(pts) - 1)
            i = min(int(f), len(pts) - 2)
            seats.append((pts[i].lerp(pts[i + 1], f - i) + UP * rng.uniform(-0.012, 0.02), pts[i + 1] - pts[i], t))
        for _ in range(3):
            seats.append((pts[-1].copy(), pts[-1] - pts[-2], 1.0))
    tip = sk.pos[-1]
    for _ in range(n):      # the leader's top: a fountain all round
        seats.append((tip.copy(), Vector((0, 0, 1)), 1.0))
    def hang(at, along, t):
            flat = Vector((along.x, along.y, 0.0))
            a = (math.atan2(flat.y, flat.x) if flat.length > 1e-4 else rng.uniform(0, math.tau)) + rng.uniform(-1.0, 1.0) * (1.3 if flat.length > 1e-4 else math.pi)
            d = Vector((math.cos(a), math.sin(a), 0.0))
            side = d.cross(UP).normalized()
            side = (side + d * rng.uniform(-0.35, 0.35)).normalized()
            w = width * rng.uniform(0.85, 1.2) * 0.5
            r = reach * rng.uniform(0.7, 1.3)
            low = foot * rng.uniform(0.7, 3.0) + (0.0 if t > 0.7 else at.z * rng.uniform(0.2, 0.5))
            if trail > 0.0 and rng.random() < trail:
                low = rng.uniform(-0.012, 0.012)    # to the grass
            low = min(low, at.z - r)
            # leave the limb, rise a little, roll over the shoulder, fall
            spine = [at, at + d * r * 0.4 + UP * r * 0.3, at + d * r * 0.9 + UP * r * 0.22, at + d * r * 1.3 - UP * r * 0.35]
            spine.append(Vector((spine[-1].x + d.x * r * 0.1, spine[-1].y + d.y * r * 0.1, low)))
            lens = [0.0]
            for q0, q1 in zip(spine, spine[1:]):
                lens.append(lens[-1] + (q1 - q0).length)
            half = rng.random() < 0.5
            u0, u1 = (0.0, 0.5) if half else (0.5, 1.0)
            tone = 0.92 + 0.16 * rng.random()
            rows = []
            for q, ln in zip(spine, lens):
                v = 1.0 - ln / lens[-1]
                rows.append((fronds.verts.new(q - side * w), fronds.verts.new(q + side * w), v))
                # shade: the shoulder faces the sky, the fall faces out
                normals.extend([(d * (0.35 + 0.5 * (1.0 - v)) + UP * (0.25 + 0.7 * v)).normalized()] * 2)
            for (l0, r0, v0), (l1, r1, v1) in zip(rows, rows[1:]):
                face = fronds.faces.new((l0, r0, r1, l1))
                for loop, st in zip(face.loops, ((u0, v0), (u1, v0), (u1, v1), (u0, v1))):
                    loop[uv].uv = st
                    loop[col] = (tone, tone, tone, 1.0)

    for seat in seats:
        hang(*seat)
    # The wood along the crown's top wears strands too (owner, 2026-11-12: "i
    # want that brown branch covered just a little bit more"): short ones
    # leave from just above it and fall to either side.
    crown_top = max(q.z for q, _, _ in seats)
    flip = 1
    for a, b in sk.edges:
        pa, pb = sk.pos[a], sk.pos[b]
        if (pa.z + pb.z) * 0.5 < crown_top * 0.72:
            continue
        steps = max(1, round((pb - pa).length / 0.045))
        for k in range(steps):
            f = (k + 0.5) / steps
            q = pa.lerp(pb, f) + UP * (sk.rad[a] + (sk.rad[b] - sk.rad[a]) * f + 0.006)
            along = pb - pa
            across = Vector((-along.y, along.x, 0.0)) * flip
            flip = -flip
            hang(q, across if across.length > 1e-4 else Vector((0, 0, 1)), 0.5)
    return fronds, normals


def pears(sid, clouds, rng):
    """Pears hanging under the pear's clouds."""
    fruit = K.Prop("fruit")
    for cc, r in clouds:
        for _ in range(int(RECIPES[sid]["fruit"] + rng.random())):
            a = rng.uniform(0, math.tau)
            at = cc + Vector((math.cos(a), math.sin(a), 0.0)) * r * rng.uniform(0.3, 0.85) - UP * r * RECIPES[sid]["flat"] * rng.uniform(0.7, 0.95)
            s = rng.uniform(0.85, 1.15)
            fruit.add(K.lathe([(0, 0), (0.021 * s, 0.012 * s), (0.012 * s, 0.036 * s), (0, 0.047 * s)], 6), (0.86, 0.9, 0.46) if rng.random() < 0.7 else (0.95, 0.84, 0.5), MF.F,
                      K.T(at.x, at.y, at.z - 0.04 * s))
    return fruit


def build(sid, letter, seed, **opts):
    kind, h, col = MF.species()[sid]
    name = f"tree_{sid}_{letter}"
    rng = random.Random(seed)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    sk, clouds = grow(sid, rng)
    settle(clouds)
    bark = wood(sk, name)
    rc = RECIPES[sid]
    weep = "weep" in rc
    leaves, normals, core = foliage(sid, clouds, rng) if not weep else (None, [], None)
    fronds, frond_normals = curtain(sid, sk, rng, opts.get("trail", 0.0)) if weep else (None, [])
    fruit = pears(sid, clouds, rng) if "fruit" in rc else None
    # to the species height, standing on the ground (the root stays buried)
    crown = [fronds] if weep else [leaves, core.bm]
    top = max(v.co.z for b in crown for v in b.verts)
    m = K.S(h / top)
    meshes = [("bark", bark, None)] + ([("fronds", fronds, frond_normals)] if weep else [("leaves", leaves, normals)])
    for b in [b for _, b, _ in meshes] + ([core.bm] if core else []) + ([fruit.bm] if fruit else []):
        bmesh.ops.transform(b, matrix=m, verts=b.verts)
    objs = []
    for part, b, part_normals in meshes:
        me = bpy.data.meshes.new(f"{name}_{part}")
        b.to_mesh(me)
        for poly in me.polygons:
            poly.use_smooth = True
        if part_normals:
            me.normals_split_custom_set_from_vertices([tuple(n) for n in part_normals])
            me.color_attributes.active_color_name = "Col"
            me.attributes.default_color_name = "Col"
        me.materials.append(bpy.data.materials.new(f"tree_{part}"))
        ob = bpy.data.objects.new(f"{name}_{part}", me)
        bpy.context.scene.collection.objects.link(ob)
        objs.append(ob)
    if core:
        objs.append(core.to_object(f"{name}_core"))
    if fruit:
        objs.append(fruit.to_object(f"{name}_fruit"))
    tris = {o.name.rsplit("_", 1)[-1]: K.mesh_tris(o) for o in objs}
    print(f"  {name:24s} {sum(tris.values()):5d} tris ({', '.join(f'{k} {v}' for k, v in tris.items())}; {len(clouds)} clouds)")
    K.export_glb(objs, os.path.join(OUT, f"{name}.glb"))


def main():
    K.reset()
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else list(RECIPES)
    seeds = int(sys.argv[sys.argv.index("--seeds") + 1]) if "--seeds" in sys.argv else 3
    for sid in only:
        for k in range(seeds):
            build(sid, "abcdef"[k], sum(map(ord, sid)) * 7 + 101 * k)
        # the willow's longer curtains (owner, 2026-11-12: "one being SOME
        # strands going to the ground and then one being all very very long")
        for k, (letter, opts) in enumerate(RECIPES[sid].get("variants", [])):
            build(sid, letter, sum(map(ord, sid)) * 7 + 101 * (seeds + k), **opts)


if __name__ == "__main__":
    main()
