"""Lineup sheet for one cast member (milestone preview, not committed output).

    /opt/bpyenv/bin/python tools/blender/cast/render_lineup.py <id> OUT.png [--pose idle] [--hide a,b]

Opens characters/<id>/model/<id>.blend, poses the rig on a frame of a clip,
stands Feyre beside the front view for height, and renders front / 3-4 / side
/ back plus two face close-ups with Cycles.  Brows and lips from the makeup
masks are mixed into the head material so the face reads as it does in game.
"""

import math
import os
import sys
import tempfile

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
args = [a for a in sys.argv[1:] if not a.startswith("--")]
CHAR, OUT = args[0], args[1]
opts = {a.split("=")[0][2:]: (a.split("=", 1)[1] if "=" in a else "1") for a in sys.argv[1:] if a.startswith("--")}
POSE = opts.get("pose", "idle")
FRAME = int(opts.get("frame", "12"))
HIDE = set(filter(None, opts.get("hide", "").split(",")))
BROWS = opts.get("brows", "4A3524")
LIPS = opts.get("lips", "B86A6A")

bpy.ops.wm.open_mainfile(filepath=os.path.join(REPO, "characters", CHAR, "model", CHAR + ".blend"))
scn = bpy.context.scene
arm = bpy.data.objects["Armature"]
for o in bpy.data.objects:
    if o.type == "MESH":
        o.hide_render = o.name == "Body_LOD1" or o.name in HIDE
        o.hide_set(o.hide_render)


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
    ia = nt.nodes.new("ShaderNodeTexImage")
    ia.image = bpy.data.images.load(mask_a)
    ia.image.colorspace_settings.name = "Non-Color"
    ib = nt.nodes.new("ShaderNodeTexImage")
    ib.image = bpy.data.images.load(mask_b)
    ib.image.colorspace_settings.name = "Non-Color"
    sa, sb = nt.nodes.new("ShaderNodeSeparateColor"), nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(ia.outputs["Color"], sa.inputs[0])
    nt.links.new(ib.outputs["Color"], sb.inputs[0])
    lips = nt.nodes.new("ShaderNodeMix")
    lips.data_type = "RGBA"
    lips.inputs[6].default_value = base
    lips.inputs[7].default_value = srgb(LIPS)
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 0.45
    nt.links.new(sa.outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], lips.inputs[0])
    brows = nt.nodes.new("ShaderNodeMix")
    brows.data_type = "RGBA"
    nt.links.new(lips.outputs[2], brows.inputs[6])
    brows.inputs[7].default_value = srgb(BROWS)
    mb = nt.nodes.new("ShaderNodeMath")
    mb.operation = "MULTIPLY"
    mb.inputs[1].default_value = 0.9
    nt.links.new(sb.outputs[0], mb.inputs[0])
    nt.links.new(mb.outputs[0], brows.inputs[0])
    nt.links.new(brows.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Subsurface Weight"].default_value = 0.15


md = os.path.join(REPO, "characters", CHAR, "model")
paint_face("head", os.path.join(md, "makeup_mask_a.png"), os.path.join(md, "makeup_mask_b.png"))

# pose
act = bpy.data.actions.get(POSE)
if act is not None:
    arm.animation_data_create()
    arm.animation_data.action = act
    if hasattr(arm.animation_data, "action_slot") and act.slots:
        arm.animation_data.action_slot = act.slots[0]
scn.frame_set(FRAME)

# Feyre for scale
fey = os.path.join(REPO, "characters", "feyre", "model", "feyre.blend")
ref = []
if CHAR != "feyre" and os.path.exists(fey):
    with bpy.data.libraries.load(fey, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n in ("Body", "Eyes", "Armature", "hunter_tunic", "hunter_trousers",
                                                      "hunter_boots")]
    for o in dst.objects:
        if o is None:
            continue
        o.name = "REF_" + o.name
        scn.collection.objects.link(o)
        ref.append(o)
    rarm = next((o for o in ref if o.type == "ARMATURE"), None)
    for o in ref:
        if o.type == "MESH":
            for md_ in o.modifiers:
                if md_.type == "ARMATURE":
                    md_.object = rarm
            o.hide_render = True
    if rarm is not None:
        rarm.location.x = -0.62
        if act is not None:
            rarm.animation_data_create()
            rarm.animation_data.action = bpy.data.actions.get(POSE + ".001") or act
        rarm.hide_render = True

scn.render.engine = "CYCLES"
scn.cycles.device = "CPU"
scn.cycles.samples = int(opts.get("samples", "32"))
scn.cycles.use_denoising = True
try:
    scn.cycles.denoiser = "OPENIMAGEDENOISE"
except Exception:
    pass
scn.view_settings.view_transform = "AgX"
scn.view_settings.look = "AgX - Medium High Contrast"
world = bpy.data.worlds.new("w")
scn.world = world
world.use_nodes = True
bgn = world.node_tree.nodes["Background"]
bgn.inputs[0].default_value = srgb("F4E6F0")
bgn.inputs[1].default_value = 0.75


def light(name, kind, energy, rot, loc=(0, 0, 0), size=1.0, color="FFFFFF"):
    L = bpy.data.lights.new(name, kind)
    L.energy = energy
    L.color = srgb(color)[:3]
    if kind == "AREA":
        L.size = size
    o = bpy.data.objects.new(name, L)
    o.rotation_euler = [math.radians(a) for a in rot]
    o.location = loc
    scn.collection.objects.link(o)
    return o


light("Key", "SUN", 3.2, (52, 0, -32), color="FFF2E2")
light("Rim", "SUN", 2.4, (60, 0, 160), color="FFD9B0")
light("Fill", "SUN", 0.8, (70, 0, 60), color="DCCBFF")
# floor disc
bpy.ops.mesh.primitive_circle_add(vertices=64, radius=1.6, fill_type="NGON", location=(0, 0, 0))
floor = bpy.context.active_object
fm = bpy.data.materials.new("floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = srgb("EED8E6")
fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
floor.data.materials.append(fm)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
scn.collection.objects.link(cam)
scn.camera = cam
body = bpy.data.objects["Body"]
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
ev = body.evaluated_get(dg).to_mesh()
P = np.array([v.co[:] for v in ev.vertices])
body.evaluated_get(dg).to_mesh_clear()
top = float(P[:, 2].max())
head_z = top - 0.12
H = max(top, 1.7)


def look(cam, target, yaw_deg, dist=5.0, pitch=0.0):
    yaw = math.radians(yaw_deg)
    cam.location = (target[0] + dist * math.sin(yaw), target[1] - dist * math.cos(yaw), target[2] + dist * math.sin(math.radians(pitch)))
    cam.rotation_euler = (math.radians(90 - pitch), 0, yaw)


def shot(path, w, h, target, yaw, ortho, with_ref=False):
    for o in ref:
        o.hide_render = not with_ref or o.type == "ARMATURE"
    scn.render.resolution_x, scn.render.resolution_y = w, h
    cam.data.ortho_scale = ortho
    look(cam, target, yaw)
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    px = np.array(img.pixels[:]).reshape(h, w, 4)
    bpy.data.images.remove(img)
    os.remove(path)
    return px


tmp = tempfile.mkdtemp(prefix="lineup_")
PW, PH = 520, 1000
oz = H * 1.08
full = [
    shot(os.path.join(tmp, "_f.png"), PW + 260, PH, (-0.31, 0, H * 0.52), 0, oz, with_ref=True),
    shot(os.path.join(tmp, "_q.png"), PW, PH, (0, 0, H * 0.52), 35, oz),
    shot(os.path.join(tmp, "_s.png"), PW, PH, (0, 0, H * 0.52), 90, oz),
    shot(os.path.join(tmp, "_b.png"), PW, PH, (0, 0, H * 0.52), 180, oz),
]
face = [
    shot(os.path.join(tmp, "_ff.png"), PW, PH // 2, (0, 0, head_z), 0, 0.40),
    shot(os.path.join(tmp, "_fq.png"), PW, PH // 2, (0, 0, head_z), 40, 0.40),
]
col = np.concatenate([face[1], face[0]], axis=0)   # pixel rows go bottom-up
img = np.concatenate(full + [col], axis=1)
img[..., 3] = 1.0
H2, W2 = img.shape[:2]
out = bpy.data.images.new("lineup", W2, H2)
out.pixels = img.ravel()
out.filepath_raw = OUT
out.file_format = "PNG"
out.save()
print("wrote", OUT, W2, H2)
