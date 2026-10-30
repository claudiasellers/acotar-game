"""Contact sheets of the gowns and head pieces (preview only, not committed output).

    /opt/bpyenv/bin/python tools/blender/feyre/render_gowns.py sheet OUT.png   # 6 gowns, side row + front row
    /opt/bpyenv/bin/python tools/blender/feyre/render_gowns.py heads OUT.png   # tiara / flower / woven crown close-up

Needs characters/feyre/wardrobe/gowns.blend.  Cycles CPU, few samples.  The close-up adds a stand-in
hair cap (render only) that fills CROWN_RING so the crowns sit on something.
"""
import math
import os
import sys

import bpy  # noqa: E402
import bmesh
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import feyre_shape as fs  # noqa: E402
from build_feyre import write_png  # noqa: E402

mode, out = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(os.path.join(HERE, "..", "..", "..", "characters", "feyre",
                                                                 "wardrobe", "gowns.blend")))
scn = bpy.context.scene
scn.render.engine = "CYCLES"
scn.cycles.device = "CPU"
scn.cycles.samples = 20
scn.cycles.use_denoising = False
world = bpy.data.worlds.new("w")
scn.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.88, 0.86, 0.94, 1)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
scn.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
scn.collection.objects.link(cam)
scn.camera = cam

gowns = ["gown_dinner", "gown_ball", "gown_garden", "gown_solstice", "gown_rose_petal", "gown_starlight"]
heads = ["tiara", "flower_crown", "woven_crown"]
for n in gowns + heads:
    bpy.data.objects[n].hide_render = True


def shot(show, loc, rot, scale, w, h):
    for n in gowns + heads:
        bpy.data.objects[n].hide_render = n not in show
    scn.render.resolution_x, scn.render.resolution_y = w, h
    cam.data.ortho_scale = scale
    cam.location, cam.rotation_euler = loc, rot
    path = os.path.join(os.path.dirname(out), "_tmp.png")
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    px = np.array(img.pixels[:]).reshape(h, w, 4)
    bpy.data.images.remove(img)
    os.remove(path)
    return px


R90 = math.radians(90)
if mode == "sheet":
    W, H = 440, 560
    rows = []
    for loc, rot in (((5, 0, 0.84), (R90, 0, R90)), ((0, -5, 0.84), (R90, 0, 0))):   # side, then front
        rows.append(np.concatenate([shot([g], loc, rot, 1.85, W, H) for g in gowns], axis=1))
else:
    cx, cy, cz = fs.CROWN_RING["centre"]
    cap = bpy.data.meshes.new("cap")
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=1.0)
    for v in bm.verts:
        v.co = (v.co.x * (fs.CROWN_RING["rx"] - 0.006), v.co.y * (fs.CROWN_RING["ry"] - 0.006), v.co.z * 0.075)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.003], context="VERTS")
    bm.to_mesh(cap)
    bm.free()
    co = bpy.data.objects.new("cap", cap)
    co.location = (cx, cy, cz - 0.006)
    m = bpy.data.materials.new("hair")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.08, 0.04, 0.025, 1)
    cap.materials.append(m)
    scn.collection.objects.link(co)
    rows = []
    for az in (0.0, math.radians(35), math.radians(180)):        # front, three-quarter, back
        loc = (math.sin(az) * 4, -math.cos(az) * 4, 1.58)
        rot = (R90, 0, az)
        rows.append(np.concatenate([shot([h], loc, rot, 0.42, 420, 420) for h in heads], axis=1))
img = np.concatenate(rows[::-1], axis=0)   # image rows are written bottom-up
img[..., 3] = 1.0
write_png(out, img)
print("wrote", out)
