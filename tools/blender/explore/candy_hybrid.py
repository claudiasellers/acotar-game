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
# species -> (EZ build, puffs, puff size, blossom puffs)
HYBRIDS = {
    "oak": ("ez_oak_a", 18, 1.0, 0),
    "birch": ("ez_aspen_a", 12, 1.0, 0),
    "cherry_blossom": ("ez_ash_b", 15, 1.0, 22),
    "apple_blossom": ("ez_ash_d", 14, 1.0, 18),
}


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
    ez, n, size, puffs = HYBRIDS[sid]
    rng = random.Random(sum(map(ord, sid)) + 31)
    bark_ob, cards = ez_parts(ez)
    p = K.Prop("hybrid_" + sid)
    # the EZ bark, in the estate's flat rose-taupe (white for the birch)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(bark_ob.data)
    bm.transform(bark_ob.matrix_world)
    p.add(bm, (0.95, 0.93, 0.9) if sid == "birch" else BARK, MF.F, sharp_deg=70.0)
    # the leaf cards clustered into puffs: each puff covers its cluster
    centres, groups = kmeans(cards, n, rng)
    top = max(v.z for v in cards)
    for i, (cc, g) in enumerate(zip(centres, groups)):
        if not g:
            continue
        spread = math.sqrt(sum((q - cc).length_squared for q in g) / len(g))
        r = (spread * 0.85 + top * 0.02) * size
        tone = c if i % 2 else (lighter(c, 0.15) if blossom else mix(c, SAGE_DEEP, 0.35))
        if cc.z > top * 0.85:
            tone = lighter(tone, 0.08)
        MF.blob(p, cc.x, cc.y, cc.z, r, tone, rng, 1, 0.82, fine=2)
    # the blossom trees' little white and pink puffs over the crown
    for i in range(puffs):
        g = groups[i % len(groups)]
        q = g[rng.randrange(len(g))] if g else centres[0]
        p.add(sphere(top * 0.03, 6, 4), WHITE if i % 3 == 0 else lighter(c, 0.2), MF.F, T(q.x, q.y, q.z + top * 0.02))
    lo, hi = p.bounds()
    s = h / max(hi.z - lo.z, 1e-3)
    K.bmesh.ops.transform(p.bm, matrix=K.S(s) @ T(0, 0, -lo.z), verts=p.bm.verts)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    ob = p.to_object("hybrid_" + sid)
    print(f"  hybrid_{sid:16s} {K.mesh_tris(ob):5d} tris ({len(cards)} cards -> {n} puffs)")
    K.export_glb([ob], os.path.join(OUT, f"hybrid_{sid}.glb"))


def main():
    K.reset()
    for sid in HYBRIDS:
        build(sid)


if __name__ == "__main__":
    main()
