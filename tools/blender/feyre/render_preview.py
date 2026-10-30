"""Milestone preview render of the Feyre build (not committed output).

    python tools/blender/feyre/render_preview.py OUT.png [blend]

Renders base-front, outfit-front and outfit-side with Cycles (CPU) and
plus a face close-up, and stitches them side by side into OUT.png.
"""
import math
import os
import sys

import bpy  # noqa: E402
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_feyre import write_png  # noqa: E402

out = sys.argv[-1] if sys.argv[-1].endswith(".png") else "/tmp/feyre_preview.png"
blend = os.path.join(HERE, "..", "..", "..", "characters", "feyre", "model", "feyre.blend")
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(blend))
scn = bpy.context.scene
scn.render.engine = "CYCLES"
scn.cycles.device = "CPU"
scn.cycles.samples = 24
scn.cycles.use_denoising = False
W, H = 520, 900
scn.render.resolution_x, scn.render.resolution_y = W, H
scn.render.film_transparent = False
world = bpy.data.worlds.new("w")
scn.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.78, 0.84, 0.80, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
scn.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 1.95
scn.collection.objects.link(cam)
scn.camera = cam

wardrobe = [o for o in bpy.data.objects if o.name.startswith("hunter_")]
lod = bpy.data.objects.get("Body_LOD1")
if lod:
    lod.hide_render = True


def shot(view, dressed, path):
    for o in wardrobe:
        o.hide_render = not dressed
    cam.data.ortho_scale = 1.95
    if view == "face":
        cam.data.ortho_scale = 0.36
        cam.location = (0, -4, 1.53)
        cam.rotation_euler = (math.radians(90), 0, 0)
    elif view == "front":
        cam.location = (0, -4, 0.86)
        cam.rotation_euler = (math.radians(90), 0, 0)
    else:
        cam.location = (4, 0, 0.86)
        cam.rotation_euler = (math.radians(90), 0, math.radians(90))
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    px = np.array(img.pixels[:]).reshape(H, W, 4)
    bpy.data.images.remove(img)
    os.remove(path)
    return px


tmp = os.path.dirname(out)
parts = [shot("front", False, os.path.join(tmp, "_a.png")),
         shot("front", True, os.path.join(tmp, "_b.png")),
         shot("side", True, os.path.join(tmp, "_c.png")),
         shot("face", False, os.path.join(tmp, "_d.png"))]
img = np.concatenate(parts, axis=1)
img[..., 3] = 1.0
write_png(out, img)
print("wrote", out)
