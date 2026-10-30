"""Contact sheets of the everyday wardrobe (preview only, not committed output).

    /opt/bpyenv/bin/python tools/blender/feyre/render_wardrobe.py outfits OUT.png   # six outfits, front
    /opt/bpyenv/bin/python tools/blender/feyre/render_wardrobe.py details OUT.png   # masks, jewellery, wrists

Needs characters/feyre/wardrobe/wardrobe.blend.  Cycles CPU, few samples.  Hairstyles are appended from
hair.blend for the head shots.
"""
import math
import os
import sys

import bpy  # noqa: E402
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_feyre import write_png  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
mode, out = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "characters", "feyre", "wardrobe", "wardrobe.blend"))
with bpy.data.libraries.load(os.path.join(ROOT, "characters", "feyre", "hair", "hair.blend")) as (src, dst):
    dst.objects = [n for n in src.objects if n in ("hair_braid", "hair_half_up", "hair_loose")]
for o in dst.objects:
    bpy.context.scene.collection.objects.link(o)
    o.parent = None
    o.modifiers.clear()
scn = bpy.context.scene
scn.render.engine = "CYCLES"
scn.cycles.device = "CPU"
scn.cycles.samples = 20
scn.cycles.use_denoising = False
world = bpy.data.worlds.new("w")
scn.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.86, 0.88, 0.94, 1)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
scn.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
scn.collection.objects.link(cam)
scn.camera = cam

ward = [o for o in bpy.data.collections["Wardrobe"].objects]
hair = list(dst.objects)
FRONT = ((0, -4, None), (math.radians(90), 0, 0))
SIDE = ((4, 0, None), (math.radians(90), 0, math.radians(90)))
BACK = ((0, 4, None), (math.radians(90), 0, math.radians(180)))
Q3 = ((2.8, -2.8, None), (math.radians(90), 0, math.radians(45)))
WRF = ((0.6, -4, None), FRONT[1])
WRQ = ((0.6 + 2.8, -2.8, None), Q3[1])
FEET = ((0.09 + 2.8, -2.8, None), Q3[1])


def shot(show, view, z, scale, w, h):
    for o in ward + hair:
        o.hide_render = o.name not in show
    scn.render.resolution_x, scn.render.resolution_y = w, h
    (x, y, _), rot = view
    cam.location, cam.rotation_euler = (x, y, z), rot
    if view is BACK:
        cam.location = (0, 4, z)
    cam.data.ortho_scale = scale
    path = os.path.join(os.path.dirname(out), "_tmp.png")
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    px = np.array(img.pixels[:]).reshape(h, w, 4)
    bpy.data.images.remove(img)
    os.remove(path)
    return px


if mode == "outfits":
    looks = [["spring_tunic", "spring_trousers", "slippers", "flower_wristlet", "necklace_pendant", "hair_half_up"],
             ["painter_smock", "spring_trousers", "riding_boots", "hair_braid"],
             ["riding_leathers", "riding_boots", "capelet", "gloves_lace", "hair_braid"],
             ["woods_leathers", "riding_boots", "charm_bracelet", "hair_braid"],
             ["vest", "spring_tunic", "stockings", "slippers", "ribbon_sash", "circlet", "hair_loose"],
             ["velvet_cloak", "riding_leathers", "riding_boots", "hair_braid"]]
    row = [shot(set(lk), FRONT, 0.86, 1.95, 420, 760) for lk in looks]
    img = np.concatenate(row, axis=1)
else:
    face = lambda show, view=FRONT: shot(set(show), view, 1.52, 0.30, 360, 360)  # noqa: E731
    tiles = [face(["mask_butterfly", "hair_half_up"]), face(["mask_fox", "hair_braid"]),
             face(["mask_leaf", "hair_loose"]),
             face(["circlet", "earrings_drop", "necklace_choker", "hair_braid"]),
             face(["butterfly_clips", "earrings_hoop", "hair_half_up"], SIDE),
             face(["pearl_pins", "earrings_rose", "hair_braid"], Q3),
             face(["hair_ribbon", "hair_loose"], BACK),
             face(["earrings_star", "earrings_pearl", "necklace_pearl", "hair_braid"], Q3),
             shot({"necklace_locket", "hair_braid"}, FRONT, 1.33, 0.30, 360, 360),
             shot({"bangle", "charm_bracelet", "gloves_lace"}, WRF, 1.29, 0.22, 360, 360),
             shot({"flower_wristlet", "ribbon_cuff"}, WRQ, 1.29, 0.22, 360, 360),
             shot({"stockings", "slippers"}, FEET, 0.25, 0.60, 360, 360)]
    rows = [np.concatenate(tiles[i:i + 6], axis=1) for i in (0, 6)]
    img = np.concatenate(rows[::-1], axis=0)
img[..., 3] = 1.0
write_png(out, img)
print("wrote", out)
