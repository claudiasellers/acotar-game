"""Clay preview of a sculpt or a finished model: a few fixed camera angles in one sheet.
Usage (from a generator): preview.sheet(objs, path, views=[...])"""
import math
import bpy
from mathutils import Vector

VIEWS = {
    "front34": ((2.6, 4.6, 1.5), (0, 0, 1.0), 50),
    "side": ((5.2, 0.15, 1.2), (0, 0.1, 1.0), 50),
    "back34": ((-2.4, -4.6, 1.6), (0, 0, 1.0), 50),
    "face": ((0.55, 1.25, 1.95), (0, 0.3, 1.84), 70),
    "face_side": ((1.0, 0.33, 1.86), (0, 0.3, 1.84), 85),
    "hand": ((1.25, 0.75, 1.15), (0.72, 0.03, 0.95), 85),
    "foot": ((0.9, 0.9, 0.35), (0.14, 0.1, 0.12), 70),
}


def shot(path, view, res=(900, 1100), samples=24, clay=None, hide=()):
    scn = bpy.context.scene
    for o in hide:
        o.hide_render = True
    if bpy.data.objects.get("pfloor") is None:
        bpy.ops.mesh.primitive_plane_add(size=40)
        bpy.context.view_layer.objects.active.name = "pfloor"
    if scn.world is None:
        w = bpy.data.worlds.new("w")
        scn.world = w
        w.use_nodes = True
        bg = w.node_tree.nodes["Background"]
        bg.inputs[0].default_value = (0.30, 0.31, 0.34, 1)
        bg.inputs[1].default_value = 0.7
        for rot, e, col in (((50, 0, 140), 4.0, (1, 0.93, 0.85)), ((70, 0, -80), 1.6, (0.7, 0.8, 1.0)), ((120, 0, -30), 2.5, (0.9, 0.95, 1.0))):
            L = bpy.data.lights.new("l", "SUN")
            L.energy = e
            L.color = col
            L.angle = 0.2
            o = bpy.data.objects.new("l", L)
            scn.collection.objects.link(o)
            o.rotation_euler = [math.radians(a) for a in rot]
    cam = bpy.data.objects.get("pcam")
    if cam is None:
        cam = bpy.data.objects.new("pcam", bpy.data.cameras.new("pcam"))
        scn.collection.objects.link(cam)
    pos, look, lens = VIEWS[view] if isinstance(view, str) else view
    cam.location = pos
    cam.rotation_euler = (Vector(look) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    scn.camera = cam
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = samples
    scn.render.resolution_x, scn.render.resolution_y = res
    scn.render.filepath = path
    scn.render.image_settings.file_format = "PNG"
    scn.view_settings.view_transform = "Standard"
    bpy.ops.render.render(write_still=True)
    for o in hide:
        o.hide_render = False


def strip(arm, mesh, clip, path, frames=8, view=((6.5, 0.0, 1.0), (0, 0.0, 0.95), 60), res=(420, 640), samples=8, extra=(), at=None):
    """One clip as a row of evenly spaced frames (a contact sheet)."""
    import os
    import numpy as np
    scn = bpy.context.scene
    act = bpy.data.actions[clip]
    ad = arm.animation_data
    for t in ad.nla_tracks:
        t.mute = True
    ad.action = act
    if hasattr(ad, "action_slot") and act.slots:
        ad.action_slot = act.slots[0]
    keys = mesh.data.shape_keys
    face = bpy.data.actions.get(clip + "_face")
    if keys is not None and keys.animation_data:
        for t in keys.animation_data.nla_tracks:
            t.mute = True
        keys.animation_data.action = face
        if face is not None and hasattr(keys.animation_data, "action_slot") and face.slots:
            keys.animation_data.action_slot = face.slots[0]
    last = int(act.frame_range[1])
    tiles = []
    for i in range(frames):
        f = round(last * i / max(frames - 1, 1)) if frames > 1 else 0
        if at is not None:
            f = round(last * at[i])
        scn.frame_set(f)
        tmp = path + f".{i}.png"
        shot(tmp, view, res=res, samples=samples, hide=extra)
        img = bpy.data.images.load(tmp)
        a = np.empty(res[0] * res[1] * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        tiles.append(a.reshape(res[1], res[0], 4))
        bpy.data.images.remove(img)
        os.remove(tmp)
    sheet = np.concatenate(tiles, axis=1)
    out = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0], alpha=False)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    ad.action = None
    if keys is not None and keys.animation_data:
        keys.animation_data.action = None
