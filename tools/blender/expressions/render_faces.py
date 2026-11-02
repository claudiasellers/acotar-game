"""Close-up expression frames for one cast member (milestone preview; not committed output).

    /opt/bpyenv/bin/python tools/blender/expressions/render_faces.py <id> OUT_DIR [--samples=24] [--size=360]

Opens characters/<id>/model/<id>.blend (after apply_face_keys.py), dresses the
face as in game (lips and brows from the makeup masks), and renders one
3/4 close-up per preset of face_profiles.PROFILES[<id>] to OUT_DIR/<nn>_<preset>.png.
tools/blender/expressions/face_sheet.py tiles them into a labelled sheet.
"""

import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
import face_profiles  # noqa: E402
import numpy as np  # noqa: E402

args = [a for a in sys.argv[1:] if not a.startswith("--")]
CHAR, OUT = args[0], args[1]
opts = {a.split("=")[0][2:]: (a.split("=", 1)[1] if "=" in a else "1") for a in sys.argv[1:] if a.startswith("--")}
SIZE = int(opts.get("size", "360"))
LOOK = {"tamlin": ("9C7A3E", "B07A68"), "lucien": ("8A3A1E", "B0786A"), "alis": ("5A4030", "A06A60"),
        "father": ("6A5A48", "A07468")}.get(CHAR, ("4A3524", "B86A6A"))

bpy.ops.wm.open_mainfile(filepath=os.path.join(REPO, "characters", CHAR, "model", CHAR + ".blend"))
scn = bpy.context.scene
HIDE = set(filter(None, opts.get("hide", "").split(",")))
for o in bpy.data.objects:
    if o.type == "MESH":
        o.hide_render = o.name == "Body_LOD1" or o.name in HIDE


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def paint_face(mat_name, mask_a, mask_b):
    m = bpy.data.materials.get(mat_name)
    if m is None or not m.use_nodes:
        return
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    base = list(bsdf.inputs["Base Color"].default_value)
    imgs = []
    for p in (mask_a, mask_b):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(p)
        t.image.colorspace_settings.name = "Non-Color"
        s = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(t.outputs["Color"], s.inputs[0])
        imgs.append(s)
    lips = nt.nodes.new("ShaderNodeMix")
    lips.data_type = "RGBA"
    lips.inputs[6].default_value = base
    lips.inputs[7].default_value = srgb(LOOK[1])
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 0.5
    nt.links.new(imgs[0].outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], lips.inputs[0])
    brows = nt.nodes.new("ShaderNodeMix")
    brows.data_type = "RGBA"
    nt.links.new(lips.outputs[2], brows.inputs[6])
    brows.inputs[7].default_value = srgb(LOOK[0])
    mb = nt.nodes.new("ShaderNodeMath")
    mb.operation = "MULTIPLY"
    mb.inputs[1].default_value = 0.9
    nt.links.new(imgs[1].outputs[0], mb.inputs[0])
    nt.links.new(mb.outputs[0], brows.inputs[0])
    nt.links.new(brows.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Subsurface Weight"].default_value = 0.15


md = os.path.join(REPO, "characters", CHAR, "model")
paint_face("head", os.path.join(md, "makeup_mask_a.png"), os.path.join(md, "makeup_mask_b.png"))

scn.render.engine = "CYCLES"
scn.cycles.device = "CPU"
scn.cycles.samples = int(opts.get("samples", "24"))
scn.cycles.use_denoising = True
scn.view_settings.view_transform = "AgX"
scn.view_settings.look = "AgX - Medium High Contrast"
world = bpy.data.worlds.new("w")
scn.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = srgb("F4E6F0")
world.node_tree.nodes["Background"].inputs[1].default_value = 0.8


def light(name, energy, rot, color):
    L = bpy.data.lights.new(name, "SUN")
    L.energy = energy
    L.color = srgb(color)[:3]
    L.angle = math.radians(8)
    o = bpy.data.objects.new(name, L)
    o.rotation_euler = [math.radians(a) for a in rot]
    scn.collection.objects.link(o)


light("Key", 3.0, (55, 0, -35), "FFF2E2")
light("Rim", 2.6, (60, 0, 150), "FFD9B0")
light("Fill", 0.9, (75, 0, 50), "DCCBFF")

body = bpy.data.objects["Body"]
kb = body.data.shape_keys.key_blocks
riders = [o for o in bpy.data.objects if o.type == "MESH" and o.data.shape_keys and o is not body]
P = np.array([v.co[:] for v in body.data.vertices])
blink = np.array([v.co[:] for v in kb["blink_L"].data]) - P
eye = P[np.linalg.norm(blink, axis=1) > 0.001].mean(0)
target = (0.0, float(eye[1]) + 0.02, float(eye[2]) - float(opts.get("drop", "0.05")))

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 85
scn.collection.objects.link(cam)
scn.camera = cam
yaw, pitch, dist = math.radians(float(opts.get("yaw", "22"))), math.radians(3), float(opts.get("dist", "0.56"))
cam.location = (target[0] + dist * math.sin(yaw) * math.cos(pitch), target[1] - dist * math.cos(yaw) * math.cos(pitch),
                target[2] + dist * math.sin(pitch))
cam.rotation_euler = (math.radians(90) - pitch, 0, yaw)
scn.render.resolution_x = scn.render.resolution_y = SIZE

prof = face_profiles.PROFILES[CHAR]
order = [prof["rest"]] + [k for k in prof["presets"] if k != prof["rest"]]
if "mix" in opts:   # --mix=name/key:v,key:v;name2/... : ad-hoc frames for tuning
    prof = {"presets": {}}
    order = []
    for part in opts["mix"].split(";"):
        nm, kv = part.split("/")
        prof["presets"][nm] = face_profiles.expand({k: float(v) for k, v in (x.split(":") for x in kv.split(","))})
        order.append(nm)
os.makedirs(OUT, exist_ok=True)


def apply(mix):
    for o in [body] + riders:
        for k in o.data.shape_keys.key_blocks[1:]:
            k.value = 0.0
        for name, w in mix.items():
            k = o.data.shape_keys.key_blocks.get(name)
            if k is not None:
                k.value = w


for i, name in enumerate(order):
    apply(prof["presets"][name])
    scn.render.filepath = os.path.join(OUT, "%02d_%s.png" % (i, name))
    bpy.ops.render.render(write_still=True)
    print("rendered", name)
