"""Milestone contact sheet of the gowns (not committed output).

    python tools/blender/feyre/render_gowns.py OUT.png

Front + side of Feyre in each gown (Cycles CPU), tinted with sample variant colours.
Tiara goes on the first two gowns, the flower crown on the last two.
"""
import math
import os
import sys

import bpy  # noqa: E402
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_feyre import write_png  # noqa: E402

out = sys.argv[-1] if sys.argv[-1].endswith(".png") else "/tmp/gowns_preview.png"
blend = os.path.join(HERE, "..", "..", "..", "characters", "feyre", "wardrobe", "gowns.blend")
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(blend))
scn = bpy.context.scene
scn.render.engine = "CYCLES"
scn.cycles.device = "CPU"
scn.cycles.samples = 24
scn.cycles.use_denoising = False
W, H = 420, 640
scn.render.resolution_x, scn.render.resolution_y = W, H
world = bpy.data.worlds.new("w")
scn.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.86, 0.84, 0.92, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
scn.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 2.4
scn.collection.objects.link(cam)
scn.camera = cam

for name in ("Body_LOD1",):
    if name in bpy.data.objects:
        bpy.data.objects[name].hide_render = True
gowns = ["gown_dinner", "gown_ball", "gown_garden", "gown_solstice"]
acc = ["tiara", "tiara", "flower_crown", "flower_crown"]
tint = [(0.62, 0.55, 0.92), (0.98, 0.62, 0.78), (0.55, 0.88, 0.72), (1.0, 0.86, 0.45)]
for n in gowns + ["tiara", "flower_crown"]:
    bpy.data.objects[n].hide_render = True


def shot(i, view, path):
    for n in gowns + ["tiara", "flower_crown"]:
        bpy.data.objects[n].hide_render = n not in (gowns[i], acc[i])
    g = bpy.data.objects[gowns[i]]
    m = g.data.materials[0].copy()
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*tint[i], 1)
    g.data.materials[0] = m
    if view == "front":
        cam.location = (0, -5, 0.84)
        cam.rotation_euler = (math.radians(90), 0, 0)
    else:
        cam.location = (5, 0, 0.84)
        cam.rotation_euler = (math.radians(90), 0, math.radians(90))
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    px = np.array(img.pixels[:]).reshape(H, W, 4)
    bpy.data.images.remove(img)
    os.remove(path)
    return px


tmp = os.path.dirname(out)
rows = []
for view in ("side", "front"):  # image rows are bottom-up when written
    rows.append(np.concatenate([shot(i, view, os.path.join(tmp, "_g.png")) for i in range(4)], axis=1))
img = np.concatenate(rows, axis=0)
img[..., 3] = 1.0
write_png(out, img)
print("wrote", out)
