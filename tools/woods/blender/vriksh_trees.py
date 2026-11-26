"""Border Woods trees from the VRIKSH stylized tree generator (headless bpy).

Run:  /opt/bpyenv/bin/python tools/woods/blender/vriksh_trees.py <VRIKSH.blend> <out_dir> [name ...]
Out:  <out_dir>/<name>.glb  one mesh, two surfaces: "bark" and "leaf__<mask>"
      <out_dir>/masks/<mask>.png  RGBA leaf card: RGB = painted detail
      (luminance, 0.667 = neutral), A = cut-out.

The generator's presets are geometry-node curves. Each one is realised and
its trunk decimated to the R4 budget. A preset whose foliage already fits the
budget (the brush-stroke and dome sets) keeps it. A denser one keeps its
branching and crown layout but gets its foliage rebuilt the same way those
sets are made: the leaf cloud is clustered into poms, each pom a shell of
leaf-spray cards facing outward over a small dark core.

COLOR_0: R = crown gradient (0 deep inside/underside, 1 sunlit tip), G = a
per-card random, B = height above ground / tree height (wind flex), A = 0 on
the solid cores (no cut-out). Normals follow the pom and the crown, so the
toon bands read soft round forms. The palette is applied in Godot, so one
model serves every colourway.
"""
import math, os, random, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector

SRC, OUT = sys.argv[1], sys.argv[2]
ONLY = set(sys.argv[3:])
BARK_TRIS = 1300
LEAF_TRIS = 1700
POM_MASK = "lsa1"
MASK_PX = 512
os.makedirs(os.path.join(OUT, "masks"), exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=SRC)
scene = bpy.context.scene

def realize_group():
    ng = bpy.data.node_groups.new("LaneRealize", "GeometryNodeTree")
    ng.interface.new_socket("Geometry", in_out='INPUT', socket_type='NodeSocketGeometry')
    ng.interface.new_socket("Geometry", in_out='OUTPUT', socket_type='NodeSocketGeometry')
    i = ng.nodes.new("NodeGroupInput"); o = ng.nodes.new("NodeGroupOutput")
    r = ng.nodes.new("GeometryNodeRealizeInstances")
    ng.links.new(i.outputs[0], r.inputs[0]); ng.links.new(r.outputs[0], o.inputs[0])
    return ng
RG = realize_group()

def mask_for(mat):
    """(alpha image, diffuse image) of a leaf material, or (None, None)."""
    if not mat or not mat.node_tree: return None, None
    a = d = None
    for n in mat.node_tree.nodes:
        if n.bl_idname == 'ShaderNodeTexImage' and n.image:
            if 'Alpha' in n.image.name: a = n.image
            elif 'Diffuse' in n.image.name: d = n.image
    return a, d

_written = {}
def write_mask(mat):
    a, d = mask_for(mat)
    if a is None: return None
    key = mat.name.lower().replace('.', '_')
    if key in _written: return key
    def px(img):
        im = img.copy(); im.scale(MASK_PX, MASK_PX)
        arr = np.array(im.pixels[:], dtype=np.float32).reshape(MASK_PX, MASK_PX, 4)
        bpy.data.images.remove(im); return arr
    al = px(a)[..., :3].mean(axis=2)
    if d is not None:
        lum = px(d)[..., :3] @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
        m = float((lum * al).sum() / max(al.sum(), 1e-6))
        lum = np.clip(lum / max(m, 1e-4), 0.45, 1.5) / 1.5
    else:
        lum = np.full_like(al, 1.0 / 1.5)
    out = np.dstack([lum, lum, lum, al])
    img = bpy.data.images.new(key, MASK_PX, MASK_PX, alpha=True)
    img.pixels[:] = out.ravel().tolist()
    img.filepath_raw = os.path.join(OUT, "masks", key + ".png"); img.file_format = 'PNG'; img.save()
    _written[key] = True
    return key

def export_tree(o):
    rnd = random.Random(o.name)
    # Ask the generator itself for a lighter trunk (fewer sides and segments):
    # decimating its dense tubes afterwards leaves spikes.
    gen = o.modifiers[0]
    for it in gen.node_group.interface.items_tree:
        if it.item_type == 'SOCKET' and it.in_out == 'INPUT' and it.socket_type == 'NodeSocketInt' and 'Resolution' in it.name:
            v = gen.get(it.identifier)
            if v is not None:
                gen[it.identifier] = 7 if it.name.startswith('Circ') else max(5, int(v) // 2)
    o.update_tag()
    m = o.modifiers.new("LaneRealize", 'NODES'); m.node_group = RG
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), depsgraph=dg)
    o.modifiers.remove(m)
    names = [mm.name if mm else "" for mm in me.materials]
    bark_idx = {i for i, n in enumerate(names) if n.startswith("Bark") or n == ""}
    leaf_mats = [mm for i, mm in enumerate(me.materials) if i not in bark_idx]
    bm = bmesh.new(); bm.from_mesh(me)
    bm.transform(o.matrix_world.to_3x3().to_4x4())
    uvs = bm.loops.layers.uv.active

    def copy_faces(src_faces):
        dst = bmesh.new(); vmap = {}; uvl = dst.loops.layers.uv.verify()
        for f in src_faces:
            vs = []
            for v in f.verts:
                if v.index not in vmap: vmap[v.index] = dst.verts.new(v.co)
                vs.append(vmap[v.index])
            try: nf = dst.faces.new(vs)
            except ValueError: continue
            nf.smooth = True
            if uvs:
                for l, nl in zip(f.loops, nf.loops): nl[uvl].uv = l[uvs].uv
        return dst
    bm.verts.index_update()
    bark = copy_faces([f for f in bm.faces if f.material_index in bark_idx])
    leaf = copy_faces([f for f in bm.faces if f.material_index not in bark_idx])
    bm.free(); bpy.data.meshes.remove(me)
    height = max([v.co.z for v in bark.verts] + [v.co.z for v in leaf.verts] + [0.01])

    # ---- bark: weld, decimate
    bmesh.ops.remove_doubles(bark, verts=bark.verts, dist=0.002)
    bmesh.ops.triangulate(bark, faces=bark.faces)
    bme = bpy.data.meshes.new(o.name + "_bark"); bark.to_mesh(bme); bark.free()
    bob = bpy.data.objects.new(o.name + "_bark", bme); scene.collection.objects.link(bob)
    for _ in range(2):
        tris = len(bob.data.polygons)
        if tris <= BARK_TRIS * 1.1: break
        d = bob.modifiers.new("d", 'DECIMATE'); d.ratio = BARK_TRIS / tris
        dg = bpy.context.evaluated_depsgraph_get()
        nme = bpy.data.meshes.new_from_object(bob.evaluated_get(dg)); bob.modifiers.clear(); bob.data = nme
    bme = bob.data
    for p in bme.polygons: p.use_smooth = True
    col = bme.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
    for i, v in enumerate(bme.vertices):
        col.data[i].color = (0.0, 0.0, max(0.0, min(1.0, v.co.z / height)), 1.0)
    bmat = bpy.data.materials.new("bark"); bme.materials.clear(); bme.materials.append(bmat)

    # ---- leaves
    bmesh.ops.triangulate(leaf, faces=leaf.faces)
    cl = leaf.loops.layers.color.new("Col")
    nl = leaf.verts.layers.float_vector.new("lane_n")
    uvl = leaf.loops.layers.uv.verify()
    leaf.verts.ensure_lookup_table()
    pts = [v.co.copy() for v in leaf.verts]
    mask = None
    poms = 0
    if pts:
        c = sum(pts, Vector()) / len(pts)
        rad = max((p - c).length for p in pts) or 1.0
        zmin = min(p.z for p in pts); zmax = max(p.z for p in pts)

        def crown_t(p):
            return max(0.0, min(1.0, 0.55 * (p.z - zmin) / max(zmax - zmin, 0.01) + 0.45 * min(1.0, (p - c).length / rad)))

        def crown_n(p):
            n = p - c; n.z += rad * 0.35
            return n.normalized()

        if len(leaf.faces) <= LEAF_TRIS * 1.25:
            # Already light: keep the generator's own foliage.
            for mm in leaf_mats: mask = write_mask(mm) or mask
            for v in leaf.verts:
                v[nl] = (crown_n(v.co) * 0.8 + Vector((0, 0, 0.2))).normalized()
                g = rnd.random()
                for l in v.link_loops: l[cl] = (crown_t(v.co), g, max(0.0, min(1.0, v.co.z / height)), 1.0)
        else:
            # Rebuild as poms of leaf-spray cards over dark cores.
            mask = POM_MASK
            sample = pts if len(pts) <= 2500 else rnd.sample(pts, 2500)
            k = max(4, min(9, int(round(3.0 + (zmax - zmin + 2.0 * rad) / 3.0))))
            seeds = rnd.sample(sample, k)
            for _ in range(10):
                groups = [[] for _ in seeds]
                for p in sample:
                    groups[min(range(len(seeds)), key=lambda i: (p - seeds[i]).length_squared)].append(p)
                seeds = [sum(g, Vector()) / len(g) if g else seeds[i] for i, g in enumerate(groups)]
            balls = []
            for sc, g in zip(seeds, groups):
                if len(g) < 3: continue
                balls.append((sc, sorted((p - sc).length for p in g)[int(len(g) * 0.75)] * 1.05 + 0.2))
            poms = len(balls)
            bmesh.ops.delete(leaf, geom=list(leaf.verts), context='VERTS')
            area = sum(r * r for _, r in balls)
            cards = (LEAF_TRIS - 20 * len(balls)) // 2
            for sc, r in balls:
                core = bmesh.ops.create_icosphere(leaf, subdivisions=1, radius=1.0)
                for v in core['verts']:
                    d = v.co.copy()
                    v.co = sc + d * r * 0.62
                    v[nl] = (d * 0.6 + crown_n(v.co) * 0.4).normalized()
                    for l in v.link_loops:
                        l[cl] = (crown_t(v.co) * 0.35, 0.5, max(0.0, min(1.0, v.co.z / height)), 0.0)
                        l[uvl].uv = (0.5, 0.5); l.face.smooth = True
                n_cards = max(6, int(cards * r * r / area))
                made = 0
                while made < n_cards:
                    d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1))).normalized()
                    if d.z < -0.25 and rnd.random() < 0.7: continue
                    p = sc + Vector((d.x, d.y, d.z * 0.85)) * r * rnd.uniform(0.8, 1.08)
                    n = (d + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * 0.4 + Vector((0, 0, 0.2))).normalized()
                    t1 = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
                    t2 = n.cross(t1)
                    a = rnd.uniform(0, math.tau)
                    u1 = t1 * math.cos(a) + t2 * math.sin(a); u2 = n.cross(u1)
                    s = r * rnd.uniform(0.42, 0.6)
                    quad = [leaf.verts.new(p + u1 * sx * s + u2 * sy * s) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
                    f = leaf.faces.new(quad); f.smooth = True
                    g = rnd.random()
                    shade = (d * 0.55 + crown_n(p) * 0.45).normalized()
                    tt = max(0.0, min(1.0, 0.5 * crown_t(p) + 0.5 * (0.5 + 0.5 * d.z)))
                    for l, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
                        l.vert[nl] = shade
                        l[cl] = (tt, g, max(0.0, min(1.0, p.z / height)), 1.0)
                        l[uvl].uv = uv
                    made += 1
            bmesh.ops.triangulate(leaf, faces=leaf.faces)
    for mid in ("LSA1", "LSA2", "LSA3", "LSA4"): write_mask(bpy.data.materials[mid])
    leaf.verts.index_update()
    order = [Vector(v[nl]) if Vector(v[nl]).length > 0.1 else Vector((0, 0, 1)) for v in leaf.verts]
    lme = bpy.data.meshes.new(o.name + "_leaf"); leaf.to_mesh(lme); leaf.free()
    for p in lme.polygons: p.use_smooth = True
    if order: lme.normals_split_custom_set_from_vertices([tuple(n) for n in order])
    lmat = bpy.data.materials.new("leaf__" + (mask or "solid")); lme.materials.clear(); lme.materials.append(lmat)
    lob = bpy.data.objects.new(o.name + "_leaf", lme); scene.collection.objects.link(lob)

    # ---- join + export (the exporter converts to +Y up)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in (bob, lob): ob.select_set(True)
    bpy.context.view_layer.objects.active = bob
    if len(lme.polygons): bpy.ops.object.join()
    else: bpy.data.objects.remove(lob)
    bob.name = o.name.lower().replace('.', '_'); bob.data.name = bob.name
    bpy.ops.object.select_all(action='DESELECT'); bob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, bob.name + ".glb"), use_selection=True, export_format='GLB',
        export_apply=True, export_vertex_color='ACTIVE', export_all_vertex_colors=True,
        export_active_vertex_color_when_no_material=True, export_materials='EXPORT', export_normals=True, export_yup=True)
    bt = sum(1 for p in bob.data.polygons if p.material_index == 0)
    print("TREE %s height %.1f bark %d leaf %d poms %d mask %s" % (bob.name, height, bt, len(bob.data.polygons) - bt, poms, mask))
    bpy.data.objects.remove(bob)
    for mm in (bmat, lmat): bpy.data.materials.remove(mm)

trees = [o for o in bpy.data.objects if o.type == 'CURVE' and o.modifiers and (not ONLY or o.name in ONLY)]
for o in sorted(trees, key=lambda o: o.name):
    try: export_tree(o)
    except Exception as e:
        import traceback; traceback.print_exc(); print("FAIL", o.name, e)
