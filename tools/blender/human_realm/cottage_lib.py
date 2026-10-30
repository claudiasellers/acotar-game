"""Tiny modelling kit for the human realm cottage/estate generators.

Everything is authored in GODOT axes (x right, +y up, -z forward/north) and
converted to Blender axes on build, so the exported glb lands in Godot the
way the numbers read. Colour is baked into a "Col" vertex colour attribute
(the glTF COLOR_0 the importer multiplies into albedo). One joined mesh per
asset; optional "-colonly" collision objects become StaticBody3D on import.

Run the asset scripts with the bpy venv, e.g.
  bpyenv/bin/python tools/blender/human_realm/cottage_buildings.py
"""
import math
import os
import random

import bpy  # noqa: E402 (bpy must load before bmesh)
import bmesh
from mathutils import Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

# Palette: the human realm is blue-grey, snow-white, wet-black bark, bone,
# smoke-brown. Feyre's paint is the only saturated colour.
STONE = (0.42, 0.43, 0.46)
STONE_DARK = (0.28, 0.29, 0.32)
STONE_LIGHT = (0.62, 0.62, 0.64)
TIMBER = (0.24, 0.18, 0.13)
TIMBER_OLD = (0.36, 0.30, 0.24)
PLASTER = (0.70, 0.67, 0.60)
THATCH = (0.46, 0.38, 0.24)
THATCH_DARK = (0.30, 0.24, 0.16)
SNOW = (0.92, 0.94, 0.98)
SOOT = (0.08, 0.08, 0.09)
CHAR = (0.13, 0.11, 0.10)
IRON = (0.17, 0.17, 0.19)
BONE = (0.83, 0.79, 0.69)
CLOTH_GREY = (0.45, 0.45, 0.48)
CLOTH_BROWN = (0.38, 0.30, 0.23)
WOOL = (0.62, 0.58, 0.52)
EARTH = (0.27, 0.22, 0.18)
FROST = (0.82, 0.89, 0.97)
ICE = (0.66, 0.78, 0.88)
DEAD_GREEN = (0.30, 0.33, 0.25)
BERRY_RED = (0.62, 0.08, 0.10)

_G2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

_parts = []
_cols = []
_rng = random.Random(1)


def seed(n):
    _rng.seed(n)


def rnd(a, b):
    return _rng.uniform(a, b)


def reset():
    global _parts, _cols
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for coll in (bpy.data.meshes, bpy.data.materials):
        for item in list(coll):
            if item.users == 0:
                coll.remove(item)
    _parts = []
    _cols = []


def _xform(at=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Godot-space transform: Euler YXZ like Godot (degrees)."""
    rx, ry, rz = (math.radians(a) for a in rot)
    r = Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(rz, 4, "Z")
    s = Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    return Matrix.Translation(Vector(at)) @ r @ s


def _finish(bm, col, name, collision, jitter, snow, col_fn, smooth):
    if jitter > 0.0:
        for v in bm.verts:
            v.co += Vector((rnd(-jitter, jitter), rnd(-jitter, jitter), rnd(-jitter, jitter)))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    # Godot -> Blender axes.
    me.transform(_G2B)
    attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    me.update()
    for poly in me.polygons:
        n = poly.normal
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            co = me.vertices[vi].co
            c = col_fn((co.x, co.z, -co.y), (n.x, n.z, -n.y)) if col_fn else col
            if snow and n.z > snow:
                c = SNOW
            attr.data[li].color_srgb = (c[0], c[1], c[2], 1.0)
    for poly in me.polygons:
        poly.use_smooth = smooth
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    if collision:
        _cols.append(obj)
    else:
        _parts.append(obj)
    return obj


def box(size, at=(0, 0, 0), rot=(0, 0, 0), col=STONE, bevel=0.0, jitter=0.0, snow=0.0, col_fn=None, collision=False, name="part"):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.transform(bm, matrix=_xform(at, rot, size), verts=bm.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=bevel, segments=1, affect="EDGES")
    return _finish(bm, col, name, collision, jitter, snow, col_fn, False)


def cyl(r, h, at=(0, 0, 0), rot=(0, 0, 0), col=TIMBER, seg=10, r2=None, jitter=0.0, snow=0.0, col_fn=None, cap=True, collision=False, smooth=True, name="part"):
    """Cylinder/cone along +y, base at `at` (before rotation about its base)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
    # bmesh cone is along z centred; make it along y with the base at 0.
    bmesh.ops.transform(bm, matrix=Matrix.Translation((0, h / 2.0, 0)) @ Matrix.Rotation(math.radians(-90), 4, "X"), verts=bm.verts)
    bmesh.ops.transform(bm, matrix=_xform(at, rot), verts=bm.verts)
    return _finish(bm, col, name, collision, jitter, snow, col_fn, smooth)


def ball(r, at=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), col=STONE, sub=1, jitter=0.0, snow=0.0, col_fn=None, smooth=True, name="part"):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    bmesh.ops.transform(bm, matrix=_xform(at, rot, scale), verts=bm.verts)
    return _finish(bm, col, name, False, jitter, snow, col_fn, smooth)


def poly(verts, faces, col=STONE, at=(0, 0, 0), rot=(0, 0, 0), snow=0.0, col_fn=None, collision=False, name="part"):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.transform(bm, matrix=_xform(at, rot), verts=bm.verts)
    return _finish(bm, col, name, collision, 0.0, snow, col_fn, False)


def prism_roof(length, width, rise, at=(0, 0, 0), rot=(0, 0, 0), thick=0.25, col=THATCH, snow=0.45, overhang=0.0, collision=False, jitter=0.0):
    """A gable roof as a solid prism, ridge along x, eaves at y=0."""
    L, W = length / 2.0 + overhang, width / 2.0 + overhang
    t = thick
    v = [(-L, 0, -W), (L, 0, -W), (L, 0, W), (-L, 0, W), (-L, rise, 0), (L, rise, 0),
         (-L, -t, -W), (L, -t, -W), (L, -t, W), (-L, -t, W), (-L, rise - t * 1.2, 0), (L, rise - t * 1.2, 0)]
    f = [(0, 1, 5, 4), (3, 4, 5, 2),  # top slopes
         (6, 10, 11, 7), (9, 8, 11, 10),  # undersides
         (0, 4, 10, 6), (3, 9, 10, 4), (1, 7, 11, 5), (2, 5, 11, 8),  # gable edge strips
         (0, 6, 7, 1), (3, 2, 8, 9)]  # eave edges
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in v]
    for face in f:
        try:
            bm.faces.new([vs[i] for i in face])
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.transform(bm, matrix=_xform(at, rot), verts=bm.verts)
    return _finish(bm, col, "roof", collision, jitter, snow, None, False)


def scatter_parts(n, fn):
    for i in range(n):
        fn(i)


def gradient(c0, c1, y0, y1):
    def f(p, _n):
        t = max(0.0, min(1.0, (p[1] - y0) / max(1e-4, (y1 - y0))))
        return tuple(c0[k] + (c1[k] - c0[k]) * t for k in range(3))
    return f


def mottled(base, amt=0.06, s=7):
    def f(p, _n):
        k = (math.sin(p[0] * 3.1 * s) + math.sin(p[1] * 2.3 * s + 1.3) + math.sin(p[2] * 2.7 * s + 2.1)) / 3.0
        return tuple(max(0.0, min(1.0, c + k * amt)) for c in base)
    return f


def _material(name):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def export(rel_path, name=None):
    """Join the parts into one mesh named after the file, export glb."""
    global _parts, _cols
    path = os.path.join(REPO, rel_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    name = name or os.path.splitext(os.path.basename(path))[0]
    bpy.ops.object.select_all(action="DESELECT")
    mat = _material("M_" + name)
    for o in _parts:
        o.data.materials.append(mat)
        o.select_set(True)
    bpy.context.view_layer.objects.active = _parts[0]
    if len(_parts) > 1:
        bpy.ops.object.join()
    main = bpy.context.view_layer.objects.active
    main.name = name
    main.data.name = name
    main.data.color_attributes.active_color = main.data.color_attributes["Col"]
    if _cols:
        bpy.ops.object.select_all(action="DESELECT")
        for o in _cols:
            o.select_set(True)
        bpy.context.view_layer.objects.active = _cols[0]
        if len(_cols) > 1:
            bpy.ops.object.join()
        col = bpy.context.view_layer.objects.active
        col.name = name + "_shape-colonly"
        col.select_set(True)
    main.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_vertex_color="ACTIVE", export_apply=True,
                              export_materials="EXPORT", export_normals=True,
                              export_texcoords=False, export_yup=True)
    reset()
    print("wrote", rel_path)
