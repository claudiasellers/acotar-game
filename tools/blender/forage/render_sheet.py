"""Contact sheet of the forage pickups (preview only, not committed output).

    /opt/bpyenv/bin/python tools/blender/forage/render_sheet.py OUT.png [id ...]

One 3/4 tile per art/forage/<id>.glb, framed on its bounds, with a 0.3 m
grey tick for scale, Cycles CPU at low samples; labels are added with PIL by
the caller when it is available.
"""
import math
import os
import sys
import tempfile

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SRC = os.path.join(ROOT, "art", "forage")
args = sys.argv[1:]
OUT = args[0]
ids = args[1:] or sorted(f[:-4] for f in os.listdir(SRC) if f.endswith(".glb"))
TS = 300


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def tile(item, path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, item + ".glb"))
    obs = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in obs:
        o.hide_render = o.name.endswith("_LOD1")
    main = [o for o in obs if not o.hide_render]
    pts = [o.matrix_world @ v.co for o in main for v in o.data.vertices]
    mn = Vector([min(p[i] for p in pts) for i in range(3)])
    mx = Vector([max(p[i] for p in pts) for i in range(3)])
    c = (mn + mx) * 0.5
    size = max((mx - mn).length, 0.12)
    bpy.ops.mesh.primitive_circle_add(vertices=48, radius=size * 1.5, fill_type="NGON", location=(0, 0, -0.001))
    fl = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = srgb("E9DDE6")
    fl.data.materials.append(fm)
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 24
    scn.cycles.use_denoising = True
    scn.view_settings.view_transform = "AgX"
    w = bpy.data.worlds.new("w")
    scn.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = srgb("F6EEF4")
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    for name, e, rot in (("k", 3.0, (50, 0, -35)), ("r", 1.5, (65, 0, 150))):
        L = bpy.data.lights.new(name, "SUN")
        L.energy = e
        o = bpy.data.objects.new(name, L)
        o.rotation_euler = [math.radians(a) for a in rot]
        scn.collection.objects.link(o)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size * 1.15
    scn.collection.objects.link(cam)
    scn.camera = cam
    yaw, pitch = math.radians(30), math.radians(32)
    d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
    cam.location = c + d * 5
    cam.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    scn.render.resolution_x = scn.render.resolution_y = TS
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return size


tmp = tempfile.mkdtemp(prefix="forage_")
cols = 10
rows = math.ceil(len(ids) / cols)
sheet = np.ones((rows * TS, cols * TS, 4), np.float32)
sizes = []
for n, item in enumerate(ids):
    p = os.path.join(tmp, item + ".png")
    sizes.append(tile(item, p))
    img = bpy.data.images.load(p)
    px = np.array(img.pixels[:], np.float32).reshape(TS, TS, 4)
    r, cidx = divmod(n, cols)
    sheet[(rows - 1 - r) * TS:(rows - r) * TS, cidx * TS:(cidx + 1) * TS] = px
out = bpy.data.images.new("sheet", cols * TS, rows * TS)
out.pixels = sheet.ravel()
out.filepath_raw = OUT
out.file_format = "PNG"
out.save()
with open(OUT + ".txt", "w") as f:
    for item, s in zip(ids, sizes):
        f.write("%s %.2f\n" % (item, s))
print("wrote", OUT)
