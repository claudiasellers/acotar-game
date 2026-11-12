"""Exploration (owner, 2026-11-11, of the smooth puff oak: "this is so ... not
detailed. its fine for some trees but just look at the other ones"): the
half-and-half tree with the court trees' detail. Same EZ-Tree trunk and limbs
and the same puffs as candy_hybrid.py, but each puff is built from leaf-clump
cards (tools/court/explore/gen_candy_puff.py) instead of one smooth ball:

  bark    the EZ bark with its UVs (twigs dropped, trunk rounded), for the
          court's painted bark texture
  leaves  clump cards laid over every puff like shingles, plus cards standing
          out along the rim so the outline is leaves; their normals are the
          puff's, so the crown still shades as soft clouds
  core    a darker ball inside each puff: depth, and no seeing through

Run:  <bpy python> tools/blender/explore/candy_leafy.py [--only oak]
Out:  world/spring_court/manor_estate/flora/explore/candy_<species>.glb
      (objects candy_<species>_bark / _leaves / _core)
Preview only: nothing in the game loads these.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import bpy  # noqa: E402,I001
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import prop_kit as K  # noqa: E402
import manor_flora as MF  # noqa: E402
import candy_hybrid as H  # noqa: E402

OUT = H.OUT
# card: clump card size x height; cover: card area over puff area (shingles);
# rim: standing cards per shingle card; core: core radius x puff radius
LEAFY = {
    "oak": dict(card=0.115, cover=1.5, rim=0.5, core=0.74),
}


def puffs(sid, bm, top, cards, rng):
    """The puffs of candy_hybrid.build(): [centre, radius, main]."""
    hy = H.HYBRIDS[sid]
    tips = H.limbs(bm, top, hy["twig"], hy["fat"])
    wood = [v.co.copy() for v in bm.verts]
    centres, groups = H.kmeans(cards, hy["puffs"], rng)
    placed = []
    for cc, g in zip(centres, groups):
        if g:
            spread = math.sqrt(sum((q - cc).length_squared for q in g) / len(g))
            placed.append([cc.copy(), spread * hy["puff"][0] + top * hy["puff"][1], True])
    for tip in tips:
        if any((tip - q[0]).length < q[1] * 0.95 for q in placed):
            continue
        r = top * hy["tip"]
        out = Vector((tip.x, tip.y, 0.0))
        placed.append([tip + (out.normalized() * r * 0.25 if out.length > 1e-6 else Vector()) + Vector((0, 0, r * 0.2)), r, False])
    for q in placed:
        others = [o for o in placed if o is not q]
        if any((w - q[0]).length < q[1] for w in wood) or any((o[0] - q[0]).length < (o[1] + q[1]) * 0.75 for o in others):
            continue
        o = min(others, key=lambda o: (o[0] - q[0]).length - o[1])
        q[0] = o[0] + (q[0] - o[0]).normalized() * (o[1] + q[1]) * 0.68
    return placed


def card(bm, uv, centre, normal, up, size, shade):
    """One clump card; returns its 4 verts' shading normal."""
    u = up.cross(normal)
    if u.length < 1e-4:
        u = Vector((1, 0, 0)).cross(normal)
    u.normalize()
    v = normal.cross(u).normalized()
    h = size * 0.5
    vs = [bm.verts.new(centre + u * sx * h + v * sy * h) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    f = bm.faces.new(vs)
    for loop, st in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop[uv].uv = st
    return [shade] * 4


def build(sid):
    kind, h, col = MF.species()[sid]
    ly = LEAFY[sid]
    rng = random.Random(sum(map(ord, sid)) + 31)
    bark_ob, cards = H.ez_parts(H.HYBRIDS[sid]["ez"])
    top = max(v.z for v in cards)
    bark = bmesh.new()
    bark.from_mesh(bark_ob.data)
    bark.transform(bark_ob.matrix_world)
    placed = puffs(sid, bark, top, cards, rng)
    crown = sum((q[0] * q[1] for q in placed), Vector()) / sum(q[1] for q in placed)

    leaves = bmesh.new()
    uv = leaves.loops.layers.uv.new("UVMap")
    normals = []
    size = top * ly["card"]
    up = Vector((0, 0, 1))
    for cc, r, main in placed:
        n = max(8, round(4 * math.pi * r * r * ly["cover"] / (size * size)))
        for i in range(n):
            # even over the sphere (golden spiral), each card tipped off the
            # surface a little so it reads as leaves from every side
            z = 1.0 - 2.0 * (i + 0.5) / n
            a = i * 2.39996 + rng.uniform(-0.3, 0.3)
            d = Vector((math.sqrt(1 - z * z) * math.cos(a), math.sqrt(1 - z * z) * math.sin(a), z))
            if d.z < -0.55 and rng.random() < 0.5:
                continue   # thinner underneath
            shade = (d * 0.62 + (cc + d * r - crown).normalized() * 0.38).normalized()
            jit = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
            s = size * rng.uniform(0.85, 1.15) * (1.0 if main else 0.8)
            normals += card(leaves, uv, cc + d * r * 0.9, (d + jit * 0.45).normalized(), Matrix.Rotation(rng.uniform(0, math.tau), 3, d) @ up, s, shade)
            if rng.random() < ly["rim"]:
                # a card standing out from the puff: stem in, leaves out
                side = d.cross(jit).normalized() if d.cross(jit).length > 1e-3 else d.orthogonal().normalized()
                normals += card(leaves, uv, cc + d * (r * 0.9 + s * 0.2), side, side.cross(d), s, shade)

    core = K.Prop("core")
    for cc, r, main in placed:
        MF.blob(core, cc.x, cc.y, cc.z, r * ly["core"], (1, 1, 1), rng, 1, 0.9, fine=1)

    # scale to the species height, standing on the ground
    zs = [v.co.z for b in (bark, leaves, core.bm) for v in b.verts]
    s = h / (max(zs) - min(zs))
    m = K.S(s) @ K.T(0, 0, -min(zs))
    for b in (bark, leaves, core.bm):
        bmesh.ops.transform(b, matrix=m, verts=b.verts)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    objs = []
    for part, b in (("bark", bark), ("leaves", leaves)):
        me = bpy.data.meshes.new(f"candy_{sid}_{part}")
        b.to_mesh(me)
        for poly in me.polygons:
            poly.use_smooth = True
        if part == "leaves":
            me.normals_split_custom_set_from_vertices([tuple(n) for n in normals])
        me.materials.append(bpy.data.materials.new(f"candy_{part}"))
        ob = bpy.data.objects.new(f"candy_{sid}_{part}", me)
        bpy.context.scene.collection.objects.link(ob)
        objs.append(ob)
    ob = core.to_object(f"candy_{sid}_core")
    objs.append(ob)
    tris = [K.mesh_tris(o) for o in objs]
    print(f"  candy_{sid:14s} {sum(tris):5d} tris (bark {tris[0]}, leaves {tris[1]}, core {tris[2]}; {len(placed)} puffs)")
    K.export_glb(objs, os.path.join(OUT, f"candy_{sid}.glb"))


def main():
    K.reset()
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else list(LEAFY)
    for sid in only:
        build(sid)


if __name__ == "__main__":
    main()
