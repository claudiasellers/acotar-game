"""Preview sheet for exported minor fae (milestone preview, not committed output).

    /opt/bpyenv/bin/python tools/blender/cast/render_minor_fae.py OUT.png id [id ...] [--clip=idle] [--frame=20]
        [--yaw=20] [--night] [--face]

Imports creatures/models/people/<id>.gltf for each id, stands them in a row on the clip's frame and
renders them with Cycles under a warm key, a pink rim and a pastel sky (--night: firelight and a
deep blue sky, as at the Calanmai bonfire).  --face frames the heads only.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
args = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT, IDS = args[0], args[1:]
opts = {a.split("=")[0][2:]: (a.split("=", 1)[1] if "=" in a else "1") for a in sys.argv[1:] if a.startswith("--")}
CLIP = opts.get("clip", "idle")
FRAME = int(opts.get("frame", "20"))
YAW = math.radians(float(opts.get("yaw", "18")))
NIGHT = "night" in opts
FACE = "face" in opts

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
SPACING = 0.95
tops = []
for i, fid in enumerate(IDS):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(REPO, "creatures", "models", "people", fid + ".gltf"))
    new = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in new if o.parent is None]
    x = (i - (len(IDS) - 1) / 2) * SPACING
    holder = bpy.data.objects.new(fid + "_holder", None)
    scn.collection.objects.link(holder)
    holder.location.x = x
    holder.rotation_euler.z = math.pi + YAW      # imported facing +Y (glTF -Z, the game front); turn to the camera
    for r in roots:
        r.parent = holder
    for o in new:
        if o.type == "ARMATURE":
            act = bpy.data.actions.get(CLIP) or next((a for a in bpy.data.actions if a.name.startswith(CLIP)), None)
            if act:
                o.animation_data_create()
                o.animation_data.action = act
                if hasattr(o.animation_data, "action_slot") and act.slots:
                    o.animation_data.action_slot = act.slots[0]
    scn.frame_set(FRAME)
    bpy.context.view_layer.update()
    zs = [(o.matrix_world @ Vector(c)).z for o in new if o.type == "MESH" for c in o.bound_box]
    tops.append(max(zs) if zs else 2.0)

# ground
bpy.ops.mesh.primitive_plane_add(size=40)
g = bpy.context.object
gm = bpy.data.materials.new("ground")
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (
    (0.05, 0.06, 0.05, 1) if NIGHT else (0.42, 0.62, 0.36, 1))
g.data.materials.append(gm)

world = bpy.data.worlds.new("w")
scn.world = world
world.use_nodes = True
bgn = world.node_tree.nodes["Background"]
bgn.inputs["Color"].default_value = (0.02, 0.025, 0.06, 1) if NIGHT else (0.85, 0.78, 0.92, 1)
bgn.inputs["Strength"].default_value = 0.6 if NIGHT else 0.9


def light(kind, energy, rot, color, size=1.0, loc=(0, 0, 4)):
    d = bpy.data.lights.new(kind + str(energy), kind)
    d.energy = energy
    d.color = color
    if kind == "AREA":
        d.size = size
    o = bpy.data.objects.new(d.name, d)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    scn.collection.objects.link(o)


if NIGHT:
    light("POINT", 900, (0, 0, 0), (1.0, 0.55, 0.25), loc=(1.6, -2.4, 0.8))      # the bonfire
    light("SUN", 0.4, (50, 0, 160), (0.55, 0.6, 1.0))                            # moon rim
else:
    light("SUN", 3.2, (50, 8, 25), (1.0, 0.93, 0.85))
    light("SUN", 1.6, (65, 0, 200), (1.0, 0.72, 0.85))                           # pink rim from behind
    light("AREA", 250, (70, 0, -30), (1.0, 0.95, 0.95), size=4, loc=(-3, -4, 3))

cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
scn.collection.objects.link(cam)
scn.camera = cam
width = SPACING * len(IDS)
if FACE:
    h = max(tops)
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = max(width, 0.6)
    cam.location = (0, -6, h - 0.16)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scn.render.resolution_x, scn.render.resolution_y = 380 * len(IDS), 420
else:
    h = max(tops) * 1.08
    S = width + 0.3
    cam_d.type = "ORTHO"
    cam.location = (0, -8, h * 0.5)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scn.render.resolution_x = int(520 * len(IDS))
    scn.render.resolution_y = int(scn.render.resolution_x * h / S)
    cam_d.ortho_scale = max(S, h)
scn.render.engine = "CYCLES"
scn.cycles.samples = int(opts.get("samples", "24"))
scn.cycles.use_denoising = True
scn.view_settings.view_transform = "AgX"
scn.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("wrote", OUT)
