"""bpy side of the court-props generator: MB -> mesh objects -> embedded glTF."""
import bpy
from mathutils import Vector

MAT_NAME = "court_props_vc"


def reset_scene() -> None:
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


def shared_material():
    mat = bpy.data.materials.get(MAT_NAME)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(MAT_NAME)
    mat.use_nodes = True
    # Vertex colours are deliberately NOT wired into the node tree: with
    # export_vertex_color="ACTIVE" the exporter then writes RGBA COLOR_0
    # (alpha = glow mask) instead of dropping alpha for an opaque material.
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.6
    return mat


def mb_to_object(name: str, mb, offset: Vector):
    me = bpy.data.meshes.new(name)
    verts = [tuple(p + offset) for p in mb.v]
    me.from_pydata(verts, [], mb.f)
    me.update(calc_edges=True)
    ca = me.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
    cols = []
    for fi, poly in enumerate(me.polygons):
        c = mb.c[fi]
        for _ in range(poly.loop_total):
            cols.extend(c)
    ca.data.foreach_set("color", cols)
    me.color_attributes.active_color = ca
    me.polygons.foreach_set("use_smooth", [bool(s) for s in mb.s])
    me.materials.append(shared_material())
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def tri_count(ob) -> int:
    me = ob.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def make_lod(ob, name: str, ratio: float):
    lod = bpy.data.objects.new(name, ob.data.copy())
    bpy.context.scene.collection.objects.link(lod)
    mod = lod.modifiers.new("dec", "DECIMATE")
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    dg = bpy.context.evaluated_depsgraph_get()
    ev = lod.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    old = lod.data
    lod.modifiers.clear()
    lod.data = me
    me.name = name
    bpy.data.meshes.remove(old)
    return lod


def _allow_embedded() -> None:
    try:
        bpy.context.preferences.addons["io_scene_gltf2"].preferences.allow_embedded_format = True
    except (KeyError, AttributeError):
        pass


def export(path: str, objs) -> None:
    _allow_embedded()
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLTF_EMBEDDED", use_selection=True, export_yup=True,
        export_apply=False, export_texcoords=False, export_normals=True, export_materials="EXPORT",
        export_vertex_color="ACTIVE", export_cameras=False, export_lights=False,
        export_animations=False, export_extras=False, export_skins=False, export_morph=False,
    )
