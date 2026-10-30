"""Generates the human-realm creature models with headless Blender (bpy).

Run:  <venv with `pip install bpy`>/bin/python tools/blender/creatures.py [out_dir]
Out:  creatures/models/<name>.gltf  (embedded buffers, feet at origin, facing -Z in Godot)

Embedded .gltf rather than .glb: these are ~100 KB each, under the 1 MB LFS
threshold (engineering rule R15), and plain text keeps them out of LFS.

Bodies are skin-modifier skeletons, subdivided once, then split into material
regions by position (coat, belly, eyes, teeth/claws, nose). Deterministic: no
randomness, so regenerating gives the same files. Wolves are lean, hunched and
bare their teeth (horror stays horror); deer and hares are grounded, not cute.
Engineering rule R4: <= 15k triangles each.
"""

import base64
import json
import math
import os
import struct
import sys

import bpy  # noqa: I001  (bpy must load before bmesh)
import bmesh
from mathutils import Vector

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "creatures", "models")


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, rough=0.85, emission=None, strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def skin_object(name, points, edges, radii):
    """points: list of (x, y, z); radii: per point (rx, rz) or float."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, edges, [])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    layer = mesh.skin_vertices[0].data
    for i, r in enumerate(radii):
        layer[i].radius = (r, r) if isinstance(r, (int, float)) else r
    layer[0].use_root = True
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    bpy.ops.object.modifier_apply(modifier="Skin")
    bpy.ops.object.modifier_apply(modifier="Sub")
    obj.select_set(False)
    return obj


class Graph:
    """A little skeleton builder: named points joined by edges."""

    def __init__(self):
        self.points, self.radii, self.edges, self.names = [], [], [], {}

    def add(self, name, pos, radius, parent=None):
        self.names[name] = len(self.points)
        self.points.append(tuple(pos))
        self.radii.append(radius)
        if parent is not None:
            self.edges.append((self.names[parent], self.names[name]))
        return name

    def chain(self, prefix, parent, positions, radii):
        prev = parent
        for i, (p, r) in enumerate(zip(positions, radii)):
            prev = self.add(f"{prefix}{i}", p, r, prev)
        return prev

    def build(self, name):
        return skin_object(name, self.points, self.edges, self.radii)


def assign_regions(obj, mats, belly_below, belly_y=(-9, 9), extra=None, belly_x=9.0):
    """Material slot 0 = coat, 1 = belly. `extra(center, normal)` may return a slot."""
    for m in mats:
        obj.data.materials.append(m)
    for poly in obj.data.polygons:
        c, n = poly.center, poly.normal
        slot = 0
        if c.z < belly_below and n.z < -0.2 and belly_y[0] < c.y < belly_y[1] and abs(c.x) < belly_x:
            slot = 1
        if extra:
            slot = extra(c, n, slot)
        poly.material_index = slot


def cone(name, base, tip, radius, mat, verts=6):
    """A tapered spike from base to tip (fangs, claws, horns, hackles)."""
    base, tip = Vector(base), Vector(tip)
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=(tip - base).length)
    obj = bpy.context.active_object
    obj.name = name
    direction = (tip - base).normalized()
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction)
    obj.location = (base + tip) / 2
    obj.data.materials.append(mat)
    return obj


def sphere(name, center, radius, mat, segments=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2 + 1, radius=radius, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def set_origin(obj, point):
    """Moves the pivot so the game can rotate the part about a joint."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.context.scene.cursor.location = point
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    obj.select_set(False)


def tris(objs):
    total = 0
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        total += sum(len(f.verts) - 2 for f in bm.faces)
        bm.free()
    return total


def export(name, objs):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    path = os.path.abspath(os.path.join(OUT, f"{name}.gltf"))
    glb = path[:-5] + ".tmp.glb"
    bpy.ops.export_scene.gltf(filepath=glb, use_selection=True, export_format="GLB", export_yup=True,
                              export_apply=True, export_materials="EXPORT")
    glb_to_embedded_gltf(glb, path)
    os.remove(glb)
    print(f"{name}: {tris(objs)} tris -> {path}")


def glb_to_embedded_gltf(glb_path, gltf_path):
    """Blender 5 dropped the embedded-glTF export, so unpack the GLB here:
    its JSON chunk, with the binary chunk inlined as a base64 data URI."""
    with open(glb_path, "rb") as f:
        data = f.read()
    offset, doc, binary = 12, None, b""
    while offset < len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8: offset + 8 + length]
        if kind == 0x4E4F534A:
            doc = json.loads(chunk.decode("utf-8"))
        elif kind == 0x004E4942:
            binary = chunk
        offset += 8 + length
    doc["buffers"][0]["uri"] = "data:application/octet-stream;base64," + base64.b64encode(binary).decode("ascii")
    with open(gltf_path, "w") as f:
        json.dump(doc, f, separators=(",", ":"))


# ---------------------------------------------------------------- quadrupeds

def quadruped(spec):
    """Builds the body graph from proportions. y is forward, z is up."""
    L, H, W = spec["length"], spec["height"], spec["width"]
    g = Graph()
    hip_z, chest_z = H * spec.get("hip", 0.88), H * spec.get("withers", 0.95)
    r_body = spec["girth"]
    g.add("tail0", (0, -0.36 * L, hip_z * 0.98), r_body * 0.35)
    g.add("hip", (0, -0.28 * L, hip_z), (r_body * 0.85, r_body * 0.9), "tail0")
    g.add("mid", (0, -0.02 * L, (hip_z + chest_z) / 2 - spec.get("waist_drop", 0.0)), (r_body * spec.get("waist", 0.8), r_body * 0.85), "hip")
    g.add("chest", (0, 0.2 * L, chest_z), (r_body, r_body * 1.05), "mid")
    g.add("shoulder", (0, 0.27 * L, chest_z + spec.get("hunch", 0.0)), (r_body * 0.8, r_body * spec.get("ruff", 0.9)), "chest")
    # Neck and head
    neck_len, head_r = spec["neck"], spec["head"]
    neck_top = Vector((0, 0.27 * L + neck_len * math.cos(spec["neck_angle"]), chest_z + neck_len * math.sin(spec["neck_angle"])))
    g.add("neck", tuple(neck_top), head_r * 0.75, "shoulder")
    head = neck_top + Vector((0, head_r * 0.9, head_r * 0.15))
    g.add("head", tuple(head), head_r, "neck")
    snout = head + Vector((0, spec["snout"], -spec["snout"] * spec.get("snout_drop", 0.25)))
    g.add("snout", tuple(snout), head_r * spec.get("snout_r", 0.42), "head")
    if spec.get("jaw_open"):
        jaw = head + Vector((0, spec["snout"] * 0.85, -spec["snout"] * 0.55))
        g.add("jaw", tuple(jaw), head_r * 0.28, "head")
    # Ears
    for side in (-1, 1):
        ear_base = head + Vector((side * head_r * 0.5, -head_r * 0.2, head_r * 0.6))
        ear_tip = ear_base + Vector((side * spec["ear"] * 0.25, -spec["ear"] * spec.get("ear_back", 0.2), spec["ear"]))
        g.add(f"ear{side}", tuple(ear_base), head_r * 0.28, "head")
        g.add(f"eart{side}", tuple(ear_tip), head_r * 0.06, f"ear{side}")
    # Legs: front from the shoulder, hind from the hip, with a real hock.
    leg_r = spec["leg"]
    fy, hy = 0.22 * L, -0.27 * L
    for side in (-1, 1):
        x = side * W * 0.32
        g.chain(f"fl{side}_", "chest", [
            (x * 1.1, fy + 0.02 * L, H * 0.6),
            (x, fy - 0.01 * L, H * 0.32),
            (x, fy + 0.01 * L, H * 0.08),
            (x, fy + 0.05 * L, 0.025),
        ], [leg_r * 1.35, leg_r, leg_r * 0.8, (leg_r * 1.1, leg_r * 0.6)])
        g.chain(f"hl{side}_", "hip", [
            (x * 1.1, hy + spec.get("thigh_fwd", 0.06) * L, H * 0.56),
            (x, hy - 0.08 * L, H * spec.get("hock", 0.3)),
            (x, hy - 0.02 * L, H * 0.07),
            (x, hy + 0.03 * L, 0.025),
        ], [leg_r * spec.get("thigh", 1.9), leg_r * 1.05, leg_r * 0.8, (leg_r * 1.1, leg_r * 0.6)])
    # Tail
    tail = spec.get("tail")
    if tail:
        g.chain("tail_", "tail0", tail["points"](L, H, hip_z), tail["radii"](r_body))
    # Hackles: short ridges standing off the spine (wolves only).
    if spec.get("hackles"):
        for i, (name, frac) in enumerate((("shoulder", 1.0), ("chest", 0.8), ("mid", 0.55))):
            base = Vector(g.points[g.names[name]])
            g.add(f"hackle{i}", tuple(base + Vector((0, -0.04 * L, r_body * (0.75 + 0.25 * frac)))), (r_body * 0.12, r_body * 0.3), name)
    obj = g.build("Body")
    return obj, g, head, snout


def finish_quadruped(name, spec, coat, belly, eye_mat, ivory, nose_mat):
    body, g, head, snout = quadruped(spec)
    belly_below = spec["height"] * spec.get("belly_line", 0.8)
    assign_regions(body, [coat, belly], belly_below, belly_y=(-0.3 * spec["length"], 0.3 * spec["length"]),
                   belly_x=spec["width"] * 0.22)
    parts = [body]
    head_r = spec["head"]
    eye_r = head_r * spec.get("eye", 0.16)
    eye_fwd = spec.get("eye_fwd", 0.5)
    for side in (-1, 1):
        parts.append(sphere(f"Eye{side}", head + Vector((side * head_r * 0.62, head_r * eye_fwd, head_r * 0.28)), eye_r, eye_mat, 8))
    parts.append(sphere("Nose", snout + Vector((0, head_r * spec.get("snout_r", 0.42) * 0.35, head_r * 0.08)), head_r * 0.15, nose_mat, 8))
    if spec.get("jaw_open"):
        jaw = Vector(g.points[g.names["jaw"]])
        for side in (-1, 1):
            # Upper and lower fangs, bared.
            up = snout + Vector((side * head_r * 0.18, -head_r * 0.05, -head_r * 0.25))
            parts.append(cone(f"FangU{side}", up, up + Vector((0, 0.01, -head_r * 0.42)), head_r * 0.06, ivory))
            lo = jaw + Vector((side * head_r * 0.14, -head_r * 0.1, head_r * 0.1))
            parts.append(cone(f"FangL{side}", lo, lo + Vector((0, 0.01, head_r * 0.3)), head_r * 0.05, ivory))
    if spec.get("claws"):
        for key in ("fl", "hl"):
            for side in (-1, 1):
                paw = Vector(g.points[g.names[f"{key}{side}_3"]])
                for c in (-1, 0, 1):
                    base = paw + Vector((c * spec["leg"] * 0.5, spec["leg"] * 0.6, 0.01))
                    parts.append(cone(f"Claw{key}{side}{c}", base, base + Vector((0, spec["leg"] * 0.9, -0.012)), spec["leg"] * 0.16, ivory, 4))
    if spec.get("antlers"):
        pass  # The M1 deer is a doe herd; stags come with the Spring Court lanes.
    model = join(parts, name)
    model.name = name
    export(name, [model])


WOLF = {
    "length": 1.5, "height": 0.8, "width": 0.36, "girth": 0.19, "hip": 0.86, "withers": 0.98,
    "hunch": 0.05, "ruff": 1.15, "waist": 0.74, "waist_drop": 0.03, "neck": 0.26, "neck_angle": math.radians(12),
    "head": 0.155, "snout": 0.21, "snout_drop": 0.3, "snout_r": 0.42, "jaw_open": True, "ear": 0.12,
    "ear_back": 0.1, "leg": 0.042, "thigh": 1.45, "hock": 0.32, "claws": True,
    "eye": 0.17, "eye_fwd": 0.55, "belly_line": 0.75,
    "tail": {
        "points": lambda L, H, z: [(0, -0.48 * L, z * 0.85), (0, -0.58 * L, z * 0.62), (0, -0.62 * L, z * 0.42)],
        "radii": lambda r: [r * 0.42, r * 0.38, r * 0.16],
    },
}


def wolf(name, scale, coat_rgb, belly_rgb, eye_rgb, glow, teeth_rgb=(0.86, 0.80, 0.62), paw=1.0, coat_rough=0.95):
    reset()
    spec = dict(WOLF)
    for k in ("length", "height", "width", "girth", "head", "snout", "ear", "leg", "neck"):
        spec[k] = WOLF[k] * scale
    spec["leg"] *= paw
    coat = material("Coat", coat_rgb, coat_rough)
    belly = material("Belly", belly_rgb, 0.95)
    eyes = material("Eyes", eye_rgb, 0.2, emission=eye_rgb, strength=glow)
    ivory = material("Teeth", teeth_rgb, 0.4)
    nose = material("Nose", (0.03, 0.03, 0.03), 0.3)
    finish_quadruped(name, spec, coat, belly, eyes, ivory, nose)


def deer():
    reset()
    spec = {
        "length": 1.6, "height": 1.0, "width": 0.4, "girth": 0.2, "head_scale": 1.0, "hip": 0.95, "withers": 0.93,
        "waist": 0.85, "neck": 0.46, "neck_angle": math.radians(58), "head": 0.125, "snout": 0.2,
        "snout_drop": 0.35, "snout_r": 0.45, "ear": 0.15, "ear_back": 0.1, "leg": 0.03, "thigh": 1.7,
        "hock": 0.38, "thigh_fwd": 0.05, "eye": 0.22, "eye_fwd": 0.25, "belly_line": 0.85,
        "tail": {
            "points": lambda L, H, z: [(0, -0.4 * L, z * 0.84)],
            "radii": lambda r: [r * 0.3],
        },
    }
    coat = material("Coat", (0.45, 0.32, 0.21), 0.95)
    belly = material("Belly", (0.86, 0.80, 0.70), 0.95)
    eyes = material("Eyes", (0.03, 0.02, 0.02), 0.1)
    ivory = material("Hoof", (0.15, 0.12, 0.1), 0.6)
    nose = material("Nose", (0.06, 0.05, 0.05), 0.3)
    finish_quadruped("deer", spec, coat, belly, eyes, ivory, nose)


def hare():
    reset()
    spec = {
        "length": 0.5, "height": 0.32, "width": 0.18, "girth": 0.09, "hip": 0.95, "withers": 0.7,
        "waist": 1.0, "neck": 0.05, "neck_angle": math.radians(50), "head": 0.055, "snout": 0.05,
        "snout_drop": 0.2, "snout_r": 0.6, "ear": 0.13, "ear_back": 0.35, "leg": 0.014, "thigh": 3.8,
        "hock": 0.2, "thigh_fwd": 0.1, "eye": 0.24, "eye_fwd": 0.25, "belly_line": 0.6,
        "tail": {
            "points": lambda L, H, z: [(0, -0.42 * L, z * 0.95)],
            "radii": lambda r: [r * 0.45],
        },
    }
    coat = material("Coat", (0.70, 0.66, 0.60), 0.95)
    belly = material("Belly", (0.93, 0.92, 0.89), 0.95)
    eyes = material("Eyes", (0.12, 0.07, 0.03), 0.1)
    ivory = material("Claws", (0.3, 0.27, 0.24), 0.6)
    nose = material("Nose", (0.45, 0.33, 0.32), 0.4)
    finish_quadruped("hare", spec, coat, belly, eyes, ivory, nose)


def bird():
    """A winter ground bird. Body, Head and two Wing objects stay separate so
    the game can flap the wings and bob the head."""
    reset()
    coat = material("Coat", (0.33, 0.28, 0.24), 0.9)
    breast = material("Breast", (0.76, 0.43, 0.28), 0.9)
    beak = material("Beak", (0.12, 0.1, 0.08), 0.5)
    eye = material("Eyes", (0.02, 0.02, 0.02), 0.1)
    g = Graph()
    g.add("tail", (0, -0.17, 0.12), 0.012)
    g.add("rump", (0, -0.07, 0.13), 0.05, "tail")
    g.add("body", (0, 0.02, 0.14), 0.065, "rump")
    g.add("breast", (0, 0.07, 0.15), 0.055, "body")
    for side in (-1, 1):
        g.chain(f"leg{side}", "body", [(side * 0.02, 0.02, 0.06), (side * 0.02, 0.03, 0.005)], [0.006, 0.005])
    body = g.build("Body")
    assign_regions(body, [coat, breast], 0.16, belly_y=(-0.02, 0.2),
                   extra=lambda c, n, s: 1 if (c.y > 0.04 and n.y > 0.3 and c.z < 0.19) else s)
    h = Graph()
    h.add("neck", (0, 0.09, 0.19), 0.035)
    h.add("crown", (0, 0.11, 0.22), 0.04, "neck")
    head = h.build("Head")
    head.data.materials.append(coat)
    parts = [head, cone("Beak", (0, 0.145, 0.215), (0, 0.19, 0.208), 0.012, beak, 6)]
    for side in (-1, 1):
        parts.append(sphere(f"BirdEye{side}", (side * 0.027, 0.13, 0.228), 0.007, eye, 6))
    head = join(parts, "Head")
    set_origin(head, (0, 0.09, 0.18))
    wings = []
    for side, label in ((-1, "WingL"), (1, "WingR")):
        w = Graph()
        w.add("root", (side * 0.045, 0.03, 0.17), (0.02, 0.008))
        w.add("mid", (side * 0.11, -0.02, 0.17), (0.03, 0.006), "root")
        w.add("tip", (side * 0.17, -0.07, 0.165), (0.012, 0.004), "mid")
        wing = w.build(label)
        wing.data.materials.append(coat)
        set_origin(wing, (side * 0.045, 0.03, 0.17))
        wings.append(wing)
    export("bird", [body, head, *wings])


if __name__ == "__main__":
    wolf("wolf", 1.0, (0.36, 0.34, 0.32), (0.58, 0.55, 0.50), (0.78, 0.62, 0.22), 0.0)
    # Andras (chapter 1 text via the keeper): pony-sized, paws bigger than a hand;
    # charcoal and obsidian with ivory, reading silver at a distance; golden
    # eyes, yellow fangs.
    wolf("great_wolf", 1.65, (0.11, 0.11, 0.13), (0.78, 0.75, 0.68), (0.95, 0.78, 0.2), 1.2,
         teeth_rgb=(0.82, 0.70, 0.38), paw=1.25, coat_rough=0.55)
    deer()
    hare()
    bird()
