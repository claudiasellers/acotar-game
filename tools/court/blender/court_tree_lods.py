"""Detail steps for the court's tree set (finish plan T2).

Every model in world/spring_court/wider/assets/trees/{qtz,ez}/ gets a "near"
mesh (<= 4,500 triangles, drawn to 80 m) and a "mid" mesh (<= 1,200, drawn to
260 m), written together as world/spring_court/wider/assets/trees/lod/<model>.glb
(objects "near" and "mid"). The far step past 260 m is a baked card, not a mesh.

A model already under a budget is copied as it is. Over it, the triangles are
shared out: the bark keeps up to BARK_SHARE of the budget and is decimated
(collapse) to fit, and the leaves take the rest. Leaves are thinned by whole
islands (a leaf card or clump at a time, chosen by a fixed seed) and each kept
island is scaled up about its own centre by 1/sqrt(kept share), capped at
LEAF_GROW, so the crown keeps its outline and most of its cover. A model whose
leaves are a few big clumps (under MIN_ISLANDS) is decimated instead.

Materials stay as named slots (Bark_NormalTree, Leaves_Pine, ez_bark,
ez_leaves...): CourtAssets dresses them by name. Vertex colours and UVs are kept.

Run (headless Blender, `pip install bpy`):
  <venv>/bin/python tools/court/blender/court_tree_lods.py [model ...]
"""

import math
import os
import random
import json
import struct
import sys
import zlib

import bpy  # noqa: I001 (bpy first: it registers bmesh)
import bmesh
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "..",
                                     "world", "spring_court", "wider", "assets", "trees"))
OUT = os.path.join(ROOT, "lod")
STEPS = [("near", 4500), ("mid", 1200)]
BARK_SHARE = {"near": 0.45, "mid": 0.35}
LEAF_GROW = 1.8
MIN_ISLANDS = 24
LEAF_WORDS = ("leaves", "flowers", "leaf")


def is_leaf(mat):
    return mat is not None and any(w in mat.name.lower() for w in LEAF_WORDS)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load(path):
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    # Bake every parent transform in, so the copies stand at the origin.
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o != obj:
            bpy.data.objects.remove(o, do_unlink=True)
    return obj


def tri_count(obj, leaf=None):
    n = 0
    for p in obj.data.polygons:
        if leaf is None or is_leaf(obj.material_slots[p.material_index].material if obj.material_slots else None) == leaf:
            n += len(p.vertices) - 2
    return n


def copy(obj, name):
    c = obj.copy()
    c.data = obj.data.copy()
    c.name = name
    c.data.name = name
    bpy.context.scene.collection.objects.link(c)
    return c


def leaf_islands(bm, leaf_slots):
    faces = [f for f in bm.faces if f.material_index in leaf_slots]
    seen = set()
    islands = []
    for f in faces:
        if f.index in seen:
            continue
        stack = [f]
        seen.add(f.index)
        isl = []
        while stack:
            g = stack.pop()
            isl.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen and h.material_index in leaf_slots:
                        seen.add(h.index)
                        stack.append(h)
        islands.append(isl)
    return islands


def thin_leaves(obj, keep, seed):
    """Keeps about `keep` of the leaf triangles by whole islands, grown to cover."""
    leaf_slots = {i for i, s in enumerate(obj.material_slots) if is_leaf(s.material)}
    if not leaf_slots or keep >= 1.0:
        return "kept"
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    islands = leaf_islands(bm, leaf_slots)
    if len(islands) < MIN_ISLANDS:
        bm.free()
        decimate(obj, keep)
        return "decimated (%d clumps)" % len(islands)
    rng = random.Random(seed)
    rng.shuffle(islands)
    total = sum(sum(len(f.verts) - 2 for f in isl) for isl in islands)
    target = total * keep
    kept = 0
    kept_islands = 0
    drop = []
    grow = min(LEAF_GROW, 1.0 / math.sqrt(max(keep, 1e-3)))
    for isl in islands:
        n = sum(len(f.verts) - 2 for f in isl)
        if kept + n <= target or kept == 0:
            kept += n
            kept_islands += 1
            verts = {v for f in isl for v in f.verts}
            c = sum((v.co for v in verts), Vector()) / len(verts)
            for v in verts:
                v.co = c + (v.co - c) * grow
        else:
            drop.extend(isl)
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    return "%d of %d islands, grown x%.2f" % (kept_islands, len(islands), grow)


def decimate(obj, ratio):
    if ratio >= 1.0 or len(obj.data.polygons) == 0:
        return
    mod = obj.modifiers.new("lod", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = max(ratio, 0.02)
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def split(obj):
    """[bark object, leaf object] (either may be None), by material slot."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    leaf_slots = {i for i, sl in enumerate(obj.material_slots) if is_leaf(sl.material)}
    has_leaf = False
    has_bark = False
    for p in obj.data.polygons:
        p.select = p.material_index in leaf_slots
        has_leaf = has_leaf or p.select
        has_bark = has_bark or not p.select
    if not has_leaf:
        return obj, None
    if not has_bark:
        return None, obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [o for o in bpy.context.selected_objects]
    leaf = [o for o in parts if o != obj][0]
    return obj, leaf


def thin_bark(obj, target):
    """Keeps the biggest pieces (trunk and limbs before twigs), then decimates."""
    if obj is None or tri_count(obj) <= target:
        return
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    islands = leaf_islands(bm, set(range(max(1, len(obj.material_slots)))))
    if len(islands) > 1:
        islands.sort(key=lambda isl: -sum(f.calc_area() for f in isl))
        kept = 0
        drop = []
        for isl in islands:
            n = sum(len(f.verts) - 2 for f in isl)
            if kept == 0 or kept + n <= target * 1.8:
                kept += n
            else:
                drop.extend(isl)
        bmesh.ops.delete(bm, geom=drop, context="FACES")
        bm.to_mesh(obj.data)
    bm.free()
    for _ in range(4):
        b = tri_count(obj)
        if b <= target * 1.02:
            break
        decimate(obj, target / b)


def make_step(src, name, budget, seed):
    obj = copy(src, name)
    bark = tri_count(obj, leaf=False)
    leaves = tri_count(obj, leaf=True)
    note = "as delivered"
    if bark + leaves > budget:
        bark_t = min(bark, budget * BARK_SHARE[name]) if leaves > 0 else budget
        leaf_t = budget - bark_t
        if leaves < leaf_t:  # leaves fit: give the bark what's left
            bark_t = budget - leaves
            leaf_t = leaves
        b_obj, l_obj = split(obj)
        thin_bark(b_obj, bark_t)
        note = "leaves kept"
        if l_obj is not None and leaves > leaf_t:
            note = thin_leaves(l_obj, leaf_t / leaves, seed)
            for _ in range(4):
                lv = tri_count(l_obj)
                if lv <= leaf_t * 1.02 or lv == 0:
                    break
                decimate(l_obj, leaf_t / lv)
        parts = [o for o in (b_obj, l_obj) if o is not None]
        bpy.ops.object.select_all(action="DESELECT")
        for o in parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        if len(parts) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = name
        obj.data.name = name
    return obj, note


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)

    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_normals=True, export_texcoords=True, export_materials="PLACEHOLDER",
                              export_apply=False, export_animations=False)
    name_materials(path, objs)


def name_materials(path, objs):
    """Writes the slot names into the .glb. PLACEHOLDER export keeps the vertex
    colours (EXPORT dropped them on most Quaternius models) but leaves the
    primitives without materials; they come out one per used slot, in slot
    order, so each gets its slot's named material back for CourtAssets."""
    with open(path, "rb") as fh:
        data = bytearray(fh.read())
    jlen = struct.unpack_from("<I", data, 12)[0]
    j = json.loads(data[20:20 + jlen])
    names = []
    for o in objs:
        for sl in o.material_slots:
            n = sl.material.name if sl.material else "none"
            n = n.split(".")[0]
            if n not in names:
                names.append(n)
    j["materials"] = [{"name": n} for n in names]
    by_mesh = {o.data.name: o for o in objs}
    for m in j["meshes"]:
        o = by_mesh.get(m.get("name"))
        if o is None:
            continue
        used = sorted({p.material_index for p in o.data.polygons})
        for prim, slot in zip(m["primitives"], used):
            mat = o.material_slots[slot].material
            prim["material"] = names.index(mat.name.split(".")[0] if mat else "none")
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    rest = data[20 + jlen:]
    out = bytearray(data[:12])
    out += struct.pack("<I", len(js)) + b"JSON" + js + rest
    struct.pack_into("<I", out, 8, len(out))
    with open(path, "wb") as fh:
        fh.write(out)


def main():
    want = set(a for a in sys.argv[1:] if not a.startswith("-"))
    os.makedirs(OUT, exist_ok=True)
    for sub in ("qtz", "ez"):
        d = os.path.join(ROOT, sub)
        for f in sorted(os.listdir(d)):
            if not (f.endswith(".gltf") or f.endswith(".glb")):
                continue
            base = os.path.splitext(f)[0]
            if want and base not in want:
                continue
            reset()
            src = load(os.path.join(d, f))
            total = tri_count(src)
            made = []
            line = "LOD %-22s %6d" % (base, total)
            for i, (name, budget) in enumerate(STEPS):
                o, note = make_step(src, name, budget, zlib.crc32(base.encode()) + i)
                made.append(o)
                line += "  %s %5d (bark %5d, %s)" % (name, tri_count(o), tri_count(o, leaf=False), note)
            bpy.data.objects.remove(src, do_unlink=True)
            path = os.path.join(OUT, base + ".glb")
            export(made, path)
            print(line + "  %4.0f KB" % (os.path.getsize(path) / 1024))


if __name__ == "__main__":
    main()
