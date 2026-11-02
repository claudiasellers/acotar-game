"""Renders the reference layers for the manor's paintings (L39), headless Cycles.

Two job kinds. "sitter": a portrait sitter (below). "tableau": game models
(creatures/models/*.gltf, flora, props) staged on a shadow-catching ground for
animal studies, bestiary plates and figures in landscapes.


The paintings' portraits are painted over real light on real forms: each
sitter is one of the game's own cast bodies (characters/<model>/model/
<model>.blend), arms lowered, re-dressed in new colours, sometimes wearing
another model's hair or mask, lit like a portrait studio and rendered with a
transparent background. tools/art/manor_paintings/build.py composites the
render over a painted backdrop and lays oil strokes over it, so no cast
member is recognisable as themselves; the bodies are only the painter's
lay figures.

Run (build.py does this):
  /opt/bpyenv/bin/python tools/blender/manor_art_refs.py -- jobs.json
jobs.json: a list of dicts, keys documented in render_job().
Deterministic: no randomness here; every choice comes from the job.
"""

import json
import math
import os
import sys

import bpy
from mathutils import Euler, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELS = ("tamlin", "lucien", "elain", "nesta", "alis")
HAIRS = {"tamlin": "hair_tamlin_loose", "lucien": "hair_lucien_half_up", "elain": "hair_elain_curls",
         "nesta": "hair_nesta_chignon", "alis": "hair_alis_bun"}
MASKS = {"tamlin": "tamlin_mask", "lucien": "lucien_mask", "alis": "alis_mask"}
SKIN_MATS = ("torso", "arms", "legs", "feet", "hands")
GARMENTS = ("tunic", "doublet", "dress", "gown", "coat", "apron", "cloak")

LIGHTS = {
    # name: [(offset from target, energy, size, colour)], world strength
    "rembrandt": ([((-1.5, -1.5, 1.1), 260, 1.0, (1.0, 0.88, 0.76)), ((1.6, -1.2, 0.0), 25, 2.5, (0.8, 0.85, 1.0)), ((0.9, 1.4, 0.9), 70, 0.8, (1.0, 0.82, 0.7))], 0.25),
    "soft": ([((-1.2, -1.8, 0.8), 200, 2.0, (1.0, 0.95, 0.9)), ((1.4, -1.6, 0.3), 110, 2.5, (0.95, 0.92, 1.0)), ((0.6, 1.4, 1.0), 60, 1.0, (1.0, 0.9, 0.85))], 0.6),
    "rim": ([((-1.0, -1.8, 0.6), 120, 1.5, (1.0, 0.92, 0.85)), ((1.2, 1.2, 0.6), 320, 0.8, (1.0, 0.8, 0.65)), ((-1.2, 1.2, 0.6), 260, 0.8, (0.85, 0.8, 1.0))], 0.3),
    "candle": ([((-0.9, -1.2, -0.2), 200, 0.5, (1.0, 0.7, 0.45)), ((1.0, 1.2, 0.8), 60, 0.8, (0.7, 0.7, 1.0))], 0.08),
    "moon": ([((1.4, -1.4, 1.2), 180, 1.2, (0.75, 0.82, 1.0)), ((-1.0, 1.2, 0.8), 120, 0.8, (0.85, 0.8, 1.0))], 0.15),
}


def _blend(model):
    return os.path.join(ROOT, "characters", model, "model", model + ".blend")


def _head(arm):
    return arm.matrix_world @ arm.pose.bones["Head"].head


def _append(model, name):
    with bpy.data.libraries.load(_blend(model)) as (src, dst):
        dst.objects = [n for n in src.objects if n == name]
    return dst.objects[0] if dst.objects else None


def _graft(obj, arm, src_head, dst_head, scale):
    """Moves an appended head piece (hair or mask) from its own model's head
    onto this body's head, bound to this armature."""
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = arm
    for m in obj.modifiers:
        if m.type == "ARMATURE":
            m.object = arm
    obj.matrix_parent_inverse.identity()
    # scale about the source head, then move onto the target head
    obj.scale = (scale, scale, scale)
    obj.location = dst_head - src_head * scale


def _tint(mat, col, mode="set"):
    if mat is None or not mat.use_nodes:
        return
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return
    inp = bsdf.inputs["Base Color"]
    rgba = (col[0], col[1], col[2], 1.0)
    if not inp.is_linked:
        if mode == "set":
            inp.default_value = rgba
        else:
            c = inp.default_value
            inp.default_value = (c[0] * col[0], c[1] * col[1], c[2] * col[2], 1.0)
        return
    src = inp.links[0].from_socket
    mixn = nt.nodes.new("ShaderNodeMix")
    mixn.data_type = "RGBA"
    mixn.blend_type = "MULTIPLY" if mode == "multiply" else "MIX"
    mixn.inputs["Factor"].default_value = 1.0 if mode == "multiply" else 0.85
    nt.links.new(src, mixn.inputs[6])
    mixn.inputs[7].default_value = rgba
    nt.links.new(mixn.outputs[2], inp)


def _soften(mat):
    """Plastic gloss reads badly under oil paint: satin everything but gems,
    metal and eyes."""
    if mat is None or not mat.use_nodes:
        return
    n = mat.name.lower()
    if any(k in n for k in ("gem", "chain", "eye", "pearl", "clasp", "lashes")):
        return
    for nd in mat.node_tree.nodes:
        if nd.type == "BSDF_PRINCIPLED":
            r = nd.inputs["Roughness"]
            if not r.is_linked:
                r.default_value = max(r.default_value, 0.55)
            for key in ("Coat Weight", "Specular IOR Level"):
                if key in nd.inputs and not nd.inputs[key].is_linked:
                    nd.inputs[key].default_value = min(nd.inputs[key].default_value, 0.25 if key == "Specular IOR Level" else 0.0)


def _lin(c):
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c[:3])


def render_job(job):
    """job keys: out, model, w, h, frame (bust|half|full), turn, tilt,
    hair (model whose hair to wear, or null), hair_col, skin (multiply tint),
    garment, trim, hide (object names), mask (keep|none|<model>), mask_col,
    light (LIGHTS key), lens."""
    bpy.ops.wm.open_mainfile(filepath=_blend(job["model"]))
    sc = bpy.context.scene
    for o in list(bpy.data.objects):
        if o.name.endswith("_LOD1") or o.name in ("Claws",) or o.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(o, do_unlink=True)
    for name in job.get("hide", []):
        o = bpy.data.objects.get(name)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    head = _head(arm).copy()
    hair_src = job.get("hair")
    if hair_src and hair_src != job["model"]:
        own = bpy.data.objects.get(HAIRS[job["model"]])
        if own:
            bpy.data.objects.remove(own, do_unlink=True)
        h = _append(hair_src, HAIRS[hair_src])
        src_head = Vector((0, 0.006, job.get("_heads", {}).get(hair_src, head.z)))
        _graft(h, arm, src_head, head, job.get("hair_scale", 1.0))
    mask = job.get("mask", "keep")
    own_mask = bpy.data.objects.get(MASKS.get(job["model"], "")) if job["model"] in MASKS else None
    if mask != "keep" and own_mask:
        bpy.data.objects.remove(own_mask, do_unlink=True)
    if mask not in ("keep", "none") and mask != job["model"]:
        mo = _append(mask, MASKS[mask])
        src_head = Vector((0, 0.006, job.get("_heads", {}).get(mask, head.z)))
        _graft(mo, arm, src_head, head, job.get("mask_scale", 0.96))
    for mat in bpy.data.materials:
        n = mat.name.lower().split(".")[0]
        _soften(mat)
        if job.get("hair_col") and (n == "hair" or n.endswith(":hair")):
            _tint(mat, _lin(job["hair_col"]))
        elif job.get("skin") and n in SKIN_MATS:
            _tint(mat, job["skin"], "multiply")
        elif job.get("garment") and any(g in n for g in GARMENTS) and (n.endswith(":fabric") or n.endswith("_linen") or n.endswith("_wool")):
            _tint(mat, _lin(job["garment"]))
        elif job.get("trim") and (n.endswith(":trim") or n.endswith(":ribbon") or n.endswith(":lining")):
            _tint(mat, _lin(job["trim"]))
        elif job.get("mask_col") and "mask" in n and n.endswith(":fabric"):
            _tint(mat, _lin(job["mask_col"]))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for side in ("Left", "Right"):
        pb = arm.pose.bones.get(side + "UpperArm")
        if pb:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = Euler((math.radians(-72), 0, 0))
        lb = arm.pose.bones.get(side + "LowerArm")
        if lb and job.get("frame") != "bust":
            lb.rotation_mode = "XYZ"
            lb.rotation_euler = Euler((math.radians(-12), 0, 0))
    hb = arm.pose.bones.get("Head")
    if hb:
        hb.rotation_mode = "XYZ"
        hb.rotation_euler = Euler((math.radians(job.get("tilt", 0.0)), math.radians(job.get("roll", 0.0)), 0))
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.rotation_euler = Euler((0, 0, math.radians(job.get("turn", 0.0))))
    bpy.context.view_layer.update()
    head = _head(arm)
    frame = job.get("frame", "bust")
    lens = job.get("lens", 135)
    k = head.z / 1.6
    if frame == "bust":
        target, dist = head + Vector((0, 0, 0.0 * k)), 3.3 * k
    elif frame == "half":
        target, dist = head + Vector((0, 0, -0.28 * k)), 4.6 * k
    else:
        target, dist = Vector((0, 0, head.z * 0.55)), 6.6 * k
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = lens
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = target + Vector((dist * 0.08, -dist, dist * 0.03))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    rig, world_k = LIGHTS[job.get("light", "rembrandt")]
    for i, (off, energy, size, col) in enumerate(rig):
        ld = bpy.data.lights.new("l%d" % i, "AREA")
        ld.energy = energy * 0.7 * max(1.0, (dist / 3.0) ** 2 * 0.6)
        ld.size = size * (1 if frame == "bust" else 2)
        ld.color = col
        lo = bpy.data.objects.new("l%d" % i, ld)
        sc.collection.objects.link(lo)
        lo.location = target + Vector(off) * max(1.0, dist / 3.0)
        lo.rotation_euler = (target - lo.location).to_track_quat("-Z", "Y").to_euler()
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.4, 0.34, 0.36, 1)
    bg.inputs[1].default_value = world_k
    sc.render.engine = "CYCLES"
    sc.cycles.samples = job.get("samples", 24)
    sc.cycles.use_denoising = True
    sc.cycles.device = "CPU"
    sc.render.resolution_x, sc.render.resolution_y = job["w"], job["h"]
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = job["out"]
    bpy.ops.render.render(write_still=True)


def _setup_render(sc, job, world_col=(0.4, 0.34, 0.36), world_k=0.3):
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*world_col, 1)
    bg.inputs[1].default_value = world_k
    sc.render.engine = "CYCLES"
    sc.cycles.samples = job.get("samples", 24)
    sc.cycles.use_denoising = True
    sc.cycles.device = "CPU"
    sc.render.resolution_x, sc.render.resolution_y = job["w"], job["h"]
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = job["out"]


def _bounds(objs):
    """World bounding box of meshes, or (None, None)."""
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    if not pts:
        return None, None
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def render_tableau(job):
    """job keys: out, w, h, items [{src (res path under the repo), at [x,y,z],
    yaw, scale, tint [r,g,b] (multiply)}], cam {at, look, lens}, light (LIGHTS
    key), sun [x,y,z] direction (optional), ground (true = shadow catcher)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    for it in job["items"]:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, it["src"]))
        new = [o for o in bpy.data.objects if o not in before]
        roots = [o for o in new if o.parent is None]
        for o in new:
            if o.name.lower().endswith("lod1") or "_lod1" in o.name.lower():
                o.hide_render = True
        for r0 in roots:
            r0.location = Vector(it.get("at", (0, 0, 0)))
            r0.rotation_mode = "XYZ"
            r0.rotation_euler = Euler((0, 0, math.radians(it.get("yaw", 0.0))))
            s = it.get("scale", 1.0)
            r0.scale = (s, s, s)
        if it.get("tint"):
            for o in new:
                for slot in getattr(o, "material_slots", []):
                    if slot.material:
                        m = slot.material.copy()
                        slot.material = m
                        _tint(m, _lin(it["tint"]), "multiply")
        for o in new:
            for slot in getattr(o, "material_slots", []):
                _soften(slot.material)
    lo, hi = _bounds([o for o in bpy.data.objects if o.type == "MESH" and not o.hide_render])
    if job.get("ground", True):
        bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
        bpy.context.active_object.is_shadow_catcher = True
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = job["cam"].get("lens", 50)
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = Vector(job["cam"]["at"])
    look = Vector(job["cam"]["look"])
    if job.get("autoframe", True) and lo is not None:
        # keep the job's viewing direction, move in or out so the subjects fill
        # about `fill` of the frame: small creatures render with real detail
        d = (look - cam.location).normalized()
        c = (lo + hi) * 0.5
        ext = hi - lo
        half = math.atan(18.0 / cam_d.lens)
        aspect = job["w"] / job["h"]
        hf, vf = (half, math.atan(math.tan(half) / aspect)) if aspect >= 1 else (math.atan(math.tan(half) * aspect), half)
        fill = job.get("fill", 0.6)
        across = math.hypot(ext.x * d.y, ext.y * d.x) + 1e-3
        dist = max(ext.z / (2 * math.tan(vf) * fill), across / (2 * math.tan(hf) * fill), 0.6)
        look = c
        cam.location = c - d * dist
    cam.rotation_euler = (look - cam.location).to_track_quat("-Z", "Y").to_euler()
    rig, world_k = LIGHTS[job.get("light", "soft")]
    for i, (off, energy, size, col) in enumerate(rig):
        ld = bpy.data.lights.new("l%d" % i, "AREA")
        dist = (cam.location - look).length
        ld.energy = energy * max(1.0, (dist / 3.0) ** 2) * job.get("exposure", 0.22)
        ld.size = size * max(1.0, dist / 3.0)
        ld.color = col
        lo = bpy.data.objects.new("l%d" % i, ld)
        sc.collection.objects.link(lo)
        lo.location = look + Vector(off) * max(1.0, dist / 3.0)
        lo.rotation_euler = (look - lo.location).to_track_quat("-Z", "Y").to_euler()
    if job.get("sun"):
        sd = bpy.data.lights.new("sun", "SUN")
        sd.energy = job.get("sun_energy", 1.6)
        sd.color = job.get("sun_col", (1.0, 0.9, 0.78))
        so = bpy.data.objects.new("sun", sd)
        sc.collection.objects.link(so)
        so.rotation_euler = Vector(job["sun"]).to_track_quat("-Z", "Y").to_euler()
    _setup_render(sc, job, world_k=world_k)
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    jobs = json.load(open(args[0]))
    heads = {"tamlin": 1.684, "lucien": 1.611, "elain": 1.397, "nesta": 1.473, "alis": 1.365}
    for job in jobs:
        if os.path.exists(job["out"]) and not job.get("force"):
            continue
        job["_heads"] = heads
        if job.get("kind") == "tableau":
            render_tableau(job)
        else:
            render_job(job)
        print("SITTER", job["out"], flush=True)


if __name__ == "__main__":
    main()
