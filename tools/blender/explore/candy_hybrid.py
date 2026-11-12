"""Exploration (owner, 2026-11-11: "show me an option of both 1 and 2"):
option 2, half and half. An EZ-Tree trunk and branches (the court's set,
world/spring_court/wider/assets/trees/ez/) wearing the estate's cotton-candy
crowns: puffs where EZ-Tree hung its leaf sprays, so the candy follows the
real branches. Vertex-coloured like the estate's flora (stylized_foliage).

Run:  <bpy python> tools/blender/explore/candy_hybrid.py
Out:  world/spring_court/manor_estate/flora/explore/hybrid_<species>.glb

Preview only: nothing in the game loads these. Over the tree budget (the EZ
bark alone is ~2,000 tris); a real build would decimate the bark.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import bpy  # noqa: E402,I001
from mathutils import Vector  # noqa: E402
import prop_kit as K  # noqa: E402
import manor_flora as MF  # noqa: E402
from prop_kit import BARK, SAGE_DEEP, WHITE, lighter, mix, sphere, T  # noqa: E402

EZ = os.path.join(K.ROOT, "world/spring_court/wider/assets/trees/ez")
OUT = os.path.join(K.ROOT, "world/spring_court/manor_estate/flora/explore")
# One tree at a time (owner, 2026-11-11: "lets do this one by one with love
# ... some sprinkles sticking out and making it look creepy rather than
# beautiful and enchanted"). The sprinkles were EZ-Tree's twigs: four fifths of
# the oak's bark is twigs under 5 cm, poking through the puffs. A tuned species
# keeps only its trunk and real limbs (islands at least `twig` x height thick),
# thickens them (`fat`: trunk, limb, x height; the trunk flares at the root),
# and gives every limb that would end in the open a puff of its own (`tip`).
#   puffs: leaf clusters -> puffs; puff: (cluster spread x, + height x)
#   blossom: little white and pink puffs nestled on the crown
HYBRIDS = {
    "oak": dict(ez="ez_oak_a", puffs=14, puff=(0.85, 0.02), twig=0.0025, fat=(0.009, 0.004), tip=0.045, blossom=0),
    # not yet tuned (twigs still in): one by one
    "birch": dict(ez="ez_aspen_a", puffs=12, puff=(0.85, 0.02), twig=0.0, fat=(0.0, 0.0), tip=0.0, blossom=0),
    "cherry_blossom": dict(ez="ez_ash_b", puffs=15, puff=(0.85, 0.02), twig=0.0, fat=(0.0, 0.0), tip=0.0, blossom=22),
    "apple_blossom": dict(ez="ez_ash_d", puffs=14, puff=(0.85, 0.02), twig=0.0, fat=(0.0, 0.0), tip=0.0, blossom=18),
}


def islands(bm):
    bm.verts.ensure_lookup_table()
    seen, out = set(), []
    for v0 in bm.verts:
        if v0.index in seen:
            continue
        stack, comp = [v0], []
        seen.add(v0.index)
        while stack:
            u = stack.pop()
            comp.append(u)
            for e in u.link_edges:
                w = e.other_vert(u)
                if w.index not in seen:
                    seen.add(w.index)
                    stack.append(w)
        out.append(comp)
    return out


def limbs(bm, top, twig, fat):
    """Drop the twigs (branches thinner than twig x top), round and thicken
    what stays; returns the kept limbs' outer ends."""
    tips, drop, thick = [], [], []
    for comp in islands(bm):
        faces = {f for v in comp for f in v.link_faces}
        area = sum(f.calc_area() for f in faces)
        e0 = max(comp, key=lambda v: (v.co - comp[0].co).length).co.copy()
        e1 = max(comp, key=lambda v: (v.co - e0).length).co.copy()
        radius = area / (2 * math.pi * max((e1 - e0).length, 1e-6))
        if radius < twig * top:
            drop += comp
            continue
        trunk = min(v.co.z for v in comp) < top * 0.02
        if trunk:
            thick += [e for f in faces for e in f.edges]
        tips.append(max((e0, e1), key=lambda q: q.z) if trunk else max((e0, e1), key=lambda q: q.length))
    # EZ-Tree's trunk is five-sided: one smooth subdivision rounds the trunk
    # and the main limbs (the thin limbs stay as they are, they read round)
    if drop:
        K.bmesh.ops.delete(bm, geom=drop, context="VERTS")
    K.bmesh.ops.subdivide_edges(bm, edges=[e for e in set(thick) if e.is_valid], cuts=1, smooth=1.0, use_grid_fill=True)
    bm.normal_update()
    for comp in islands(bm):
        z0 = min(v.co.z for v in comp)
        z1 = max(v.co.z for v in comp)
        trunk = z0 < top * 0.02
        for v in comp:
            d = top * (fat[0] * (1.0 + 0.9 * (1.0 - (v.co.z - z0) / max(z1 - z0, 1e-6)) ** 2) if trunk else fat[1])
            n = Vector((v.normal.x, v.normal.y, 0.0 if trunk else v.normal.z))
            v.co += n * d
    return tips


def ez_parts(name):
    """Bark triangles (world space, Blender z up) and the leaf cards' centres."""
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(EZ, name + ".glb"))
    bark, cards = None, []
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        mat = o.data.materials[0].name if o.data.materials else ""
        if "leaves" in mat:
            mw = o.matrix_world
            vs = [mw @ v.co for v in o.data.vertices]
            for f in o.data.polygons:
                c = Vector()
                for i in f.vertices:
                    c += vs[i]
                cards.append(c / len(f.vertices))
        else:
            bark = o
    return bark, cards


def kmeans(pts, k, rng, iters=12):
    cs = rng.sample(pts, k)
    groups = []
    for _ in range(iters):
        groups = [[] for _ in cs]
        for p in pts:
            groups[min(range(len(cs)), key=lambda i: (p - cs[i]).length_squared)].append(p)
        cs = [sum(g, Vector()) / len(g) if g else cs[i] for i, g in enumerate(groups)]
    return cs, groups


def build(sid):
    kind, h, col = MF.species()[sid]
    blossom = sid in ("cherry_blossom", "apple_blossom")
    c = col[:3] if blossom else mix(col[:3], (0.49, 0.76, 0.6), 0.6)
    hy = HYBRIDS[sid]
    rng = random.Random(sum(map(ord, sid)) + 31)
    bark_ob, cards = ez_parts(hy["ez"])
    top = max(v.z for v in cards)
    p = K.Prop("hybrid_" + sid)
    # the EZ bark, in the estate's flat rose-taupe (white for the birch)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(bark_ob.data)
    bm.transform(bark_ob.matrix_world)
    tips = limbs(bm, top, hy["twig"], hy["fat"]) if hy["twig"] > 0.0 else []
    wood = [v.co.copy() for v in bm.verts]
    bark_tris = sum(len(f.verts) - 2 for f in bm.faces)
    p.add(bm, (0.95, 0.93, 0.9) if sid == "birch" else BARK, MF.F, sharp_deg=70.0 if not tips else 180.0)
    # the leaf cards clustered into puffs: each puff covers its cluster
    centres, groups = kmeans(cards, hy["puffs"], rng)
    placed = []   # [centre, radius, tone, fine]
    for i, (cc, g) in enumerate(zip(centres, groups)):
        if not g:
            continue
        spread = math.sqrt(sum((q - cc).length_squared for q in g) / len(g))
        r = spread * hy["puff"][0] + top * hy["puff"][1]
        tone = c if i % 2 else (lighter(c, 0.15) if blossom else mix(c, SAGE_DEEP, 0.35))
        if cc.z > top * 0.85:
            tone = lighter(tone, 0.08)
        placed.append([cc.copy(), r, tone, 2])
    # no limb ends in the open: a bare tip gets a small puff of its own
    extra = 0
    for tip in tips:
        if hy["tip"] <= 0.0 or any((tip - q[0]).length < q[1] * 0.95 for q in placed):
            continue
        r = top * hy["tip"]
        out = Vector((tip.x, tip.y, 0.0))
        cc = tip + (out.normalized() * r * 0.25 if out.length > 1e-6 else Vector()) + Vector((0, 0, r * 0.2))
        placed.append([cc, r, c if extra % 2 else lighter(c, 0.1), 1])
        extra += 1
    # no puff floats: one that touches neither wood nor another puff (its
    # twigs are gone) drifts in until it sits against its nearest neighbour
    if tips:
        for q in placed:
            others = [o for o in placed if o is not q]
            if any((w - q[0]).length < q[1] for w in wood) or any((o[0] - q[0]).length < (o[1] + q[1]) * 0.75 for o in others):
                continue
            o = min(others, key=lambda o: (o[0] - q[0]).length - o[1])
            q[0] = o[0] + (q[0] - o[0]).normalized() * (o[1] + q[1]) * 0.68
    for cc, r, tone, fine in placed:
        MF.blob(p, cc.x, cc.y, cc.z, r, tone, rng, 1, 0.82 if fine == 2 else 0.85, fine=fine)
    # the blossom trees' little white and pink puffs over the crown
    for i in range(hy["blossom"]):
        g = groups[i % len(groups)]
        q = g[rng.randrange(len(g))] if g else centres[0]
        p.add(sphere(top * 0.03, 6, 4), WHITE if i % 3 == 0 else lighter(c, 0.2), MF.F, T(q.x, q.y, q.z + top * 0.02))
    lo, hi = p.bounds()
    s = h / max(hi.z - lo.z, 1e-3)
    K.bmesh.ops.transform(p.bm, matrix=K.S(s) @ T(0, 0, -lo.z), verts=p.bm.verts)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    ob = p.to_object("hybrid_" + sid)
    print(f"  hybrid_{sid:16s} {K.mesh_tris(ob):5d} tris (bark {bark_tris}, {len(tips)} limbs, {len(placed) - extra} puffs + {extra} tip puffs)")
    K.export_glb([ob], os.path.join(OUT, f"hybrid_{sid}.glb"))


def main():
    K.reset()
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else list(HYBRIDS)
    for sid in only:
        build(sid)


if __name__ == "__main__":
    main()
