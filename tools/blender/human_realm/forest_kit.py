"""Tiny modelling kit for the hunting forest / wall seam props (headless bpy).

Every asset is built from primitives, each part gets a flat vertex colour
(slightly jittered so stylized shading has some life), then all parts are
joined into one mesh with a "Col" colour attribute and exported as a .glb.
Metres, +Z up in Blender (+Y up after glTF export), origin at the base centre.
"""
import math
import os
import random

import bpy
from mathutils import Vector

_rng = random.Random(1)
# Collision boxes for the Godot generator: (centre xyz, size xyz, yaw about +Z),
# Blender coordinates. Written beside the .glb as <name>.collision.json.
COLLIDERS = []


def reset(seed=1):
    global _rng
    _rng = random.Random(seed)
    COLLIDERS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)


def col_box(centre, size, yaw=0.0):
    """An invisible collision box (Blender coords, centre)."""
    COLLIDERS.append((tuple(centre), tuple(size), yaw))


def rng():
    return _rng


def _paint(obj, color, jitter=0.05, grad=0.0, smooth=False):
    """Fill the Col attribute: base colour, per-vertex jitter, optional
    darkening toward the bottom (grad 0..1)."""
    me = obj.data
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    zs = [v.co.z for v in me.vertices]
    zmin, zmax = (min(zs), max(zs)) if zs else (0.0, 1.0)
    span = max(zmax - zmin, 1e-4)
    vcol = {}
    for v in me.vertices:
        h = (v.co.z - zmin) / span
        k = 1.0 - grad * (1.0 - h)
        j = 1.0 + _rng.uniform(-jitter, jitter)
        vcol[v.index] = (min(color[0] * k * j, 1.0), min(color[1] * k * j, 1.0), min(color[2] * k * j, 1.0), 1.0)
    for loop in me.loops:
        attr.data[loop.index].color = vcol[loop.vertex_index]
    for p in me.polygons:
        p.use_smooth = smooth


def _place(obj, loc, rot, scale):
    obj.location = Vector(loc)
    obj.rotation_euler = rot
    obj.scale = scale
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.select_set(False)
    return obj


def box(size, loc=(0, 0, 0), rot=(0, 0, 0), color=(0.5, 0.5, 0.5), jitter=0.05, grad=0.0, bevel=0.0, collide=False):
    """Box of `size` (x, y, z) whose base sits at loc. collide=True also adds
    a collision box (only the yaw, rot[2], carries over)."""
    if collide:
        col_box((loc[0], loc[1], loc[2] + size[2] * 0.5), size, rot[2])
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    for v in o.data.vertices:
        v.co.z += size[2] * 0.5
    if bevel > 0.0:
        m = o.modifiers.new("b", "BEVEL")
        m.width = bevel
        m.segments = 1
        bpy.ops.object.modifier_apply(modifier="b")
    _place(o, loc, rot, (1, 1, 1))
    _paint(o, color, jitter, grad)
    return o


def cyl(r, h, loc=(0, 0, 0), rot=(0, 0, 0), color=(0.4, 0.3, 0.2), verts=8, r2=None, jitter=0.05, grad=0.0, smooth=True):
    """Cylinder / cone, base at loc, axis +Z (before rot)."""
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h)
    o = bpy.context.active_object
    for v in o.data.vertices:
        v.co.z += h * 0.5
    _place(o, loc, rot, (1, 1, 1))
    _paint(o, color, jitter, grad, smooth)
    return o


def blob(r, loc=(0, 0, 0), scale=(1, 1, 1), color=(0.5, 0.5, 0.5), subdiv=1, jitter=0.06, lumpy=0.12, rot=(0, 0, 0), smooth=True):
    """Lumpy ico-sphere centred at loc."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r)
    o = bpy.context.active_object
    for v in o.data.vertices:
        v.co *= 1.0 + _rng.uniform(-lumpy, lumpy)
    _place(o, loc, rot, scale)
    _paint(o, color, jitter, 0.0, smooth)
    return o


def torus(R, r, loc=(0, 0, 0), rot=(0, 0, 0), color=(0.3, 0.3, 0.3), major=12, minor=5):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=major, minor_segments=minor)
    o = bpy.context.active_object
    _place(o, loc, rot, (1, 1, 1))
    _paint(o, color, 0.04, 0.0, True)
    return o


def plane(sx, sy, loc=(0, 0, 0), rot=(0, 0, 0), color=(0.9, 0.9, 0.9)):
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    o = bpy.context.active_object
    o.scale = (sx, sy, 1)
    bpy.ops.object.transform_apply(scale=True)
    _place(o, loc, rot, (1, 1, 1))
    _paint(o, color, 0.03)
    return o


def stick(a, b, r, color=(0.35, 0.25, 0.18), verts=6, r2=None):
    """A cylinder from point a to point b."""
    a = Vector(a)
    b = Vector(b)
    d = b - a
    h = d.length
    rot = d.to_track_quat("Z", "Y").to_euler()
    return cyl(r, h, a, rot, color, verts, r2)


def export(path):
    """Join everything in the scene into one mesh and write a .glb."""
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = os.path.splitext(os.path.basename(path))[0]
    obj.data.color_attributes.active_color = obj.data.color_attributes["Col"]
    mat = bpy.data.materials.new("mat_" + obj.name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_vertex_color="ACTIVE",
                              export_apply=True, use_selection=False, export_materials="EXPORT")
    if COLLIDERS:
        import json
        data = [{"centre": list(c), "size": list(sz), "yaw": y} for c, sz, y in COLLIDERS]
        with open(os.path.splitext(path)[0] + ".collision.json", "w") as f:
            json.dump(data, f, indent=1)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print("wrote %s (%d tris)" % (path, tris))


def ring_points(n, radius, jitter=0.0, z=0.0):
    out = []
    for i in range(n):
        a = i / n * math.tau + _rng.uniform(-jitter, jitter)
        out.append((math.cos(a) * radius, math.sin(a) * radius, z))
    return out


# --- palette (human realm: blue-grey, snow-white, wet-black bark, bone, smoke-brown) ---
STONE = (0.46, 0.47, 0.50)
STONE_DARK = (0.30, 0.31, 0.34)
MOSS_STONE = (0.36, 0.40, 0.36)
SNOW = (0.92, 0.94, 0.98)
ICE = (0.70, 0.84, 0.94)
ICE_DEEP = (0.45, 0.64, 0.80)
BARK = (0.12, 0.11, 0.10)
WOOD = (0.36, 0.27, 0.19)
WOOD_ROT = (0.26, 0.22, 0.18)
WOOD_PALE = (0.62, 0.55, 0.45)
CHAR = (0.06, 0.05, 0.05)
BONE = (0.86, 0.82, 0.72)
IRON = (0.22, 0.19, 0.18)
RUST = (0.45, 0.22, 0.12)
STRAW = (0.78, 0.66, 0.38)
CLOTH_RED = (0.62, 0.10, 0.10)
CLOTH_BLUE = (0.30, 0.38, 0.58)
CLOTH_CREAM = (0.88, 0.84, 0.74)
LEATHER = (0.30, 0.20, 0.13)
PAPER = (0.86, 0.82, 0.70)
TIN = (0.62, 0.64, 0.66)
ROBIN_RED = (0.85, 0.35, 0.12)
