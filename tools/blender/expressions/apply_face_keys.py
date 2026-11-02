"""Add the expression shape keys to a built cast member and re-export its model (lane L36).

    /opt/bpyenv/bin/python tools/blender/expressions/apply_face_keys.py <id> [<id> ...]

Opens characters/<id>/model/<id>.blend (written by tools/blender/cast/build_cast.py
or, for Feyre, build_feyre.py), appends face_keys.EXPRESSION_KEYS to "Body",
copies them onto meshes that ride the face (Lucien's "Scar"), then re-exports
characters/<id>/model/<id>.glb with the same objects, rig and clips it held
before, and saves the .blend.  Re-running is safe: keys are refreshed in place.
Run it after any rebuild of a face.
"""

import json
import os
import struct
import sys

import bpy  # noqa: F401  (first: bpy before numpy users)

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))

import face_keys  # noqa: E402
import mouth  # noqa: E402

# Teeth per face: fangs = extra canine length (m) [C: Tamlin's fangs when furious, ch11];
# Lucien's grin is "too-white" [C ch8-9]; the father's are a poor man's.
TEETH = {
    "tamlin": dict(fangs=0.0045, teeth_rgb=(0.97, 0.95, 0.90)),
    "lucien": dict(teeth_rgb=(1.0, 1.0, 0.99)),
    "father": dict(teeth_rgb=(0.86, 0.80, 0.68)),
}


# Meshes outside <id>.glb that sit on the face and must move with it: id -> {object: glb path}.
FACE_RIDERS = {
    "father": {"hair_father_greying": "characters/father/hair/father_greying.glb"},   # the beard
}


def export_rider(path, obj, arm):
    """Same settings as build_cast's hair export (build_feyre.export_glb, no clips)."""
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in (arm, obj):
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
              export_animations=False, export_skins=True, export_morph=True, export_yup=True,
              export_materials="EXPORT", export_extras=False)
    try:
        bpy.ops.export_scene.gltf(**kw, export_morph_normal=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)


def glb_json(path):
    with open(path, "rb") as fh:
        b = fh.read()
    n = struct.unpack("<I", b[12:16])[0]
    return json.loads(b[20:20 + n])


def export_glb(path, objs, arm):
    """Same settings as build_feyre.export_glb(animations=True)."""
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in [arm] + objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
              export_animations=True, export_skins=True, export_morph=True, export_yup=True,
              export_materials="EXPORT", export_extras=False, export_animation_mode="ACTIONS")
    try:
        bpy.ops.export_scene.gltf(**kw, export_morph_normal=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)


def run(char):
    md = os.path.join(REPO, "characters", char, "model")
    blend, glb = os.path.join(md, char + ".blend"), os.path.join(md, char + ".glb")
    before = glb_json(glb)
    mesh_nodes = [n["name"] for n in before["nodes"] if "mesh" in n]
    clips = sorted(a["name"] for a in before.get("animations", []))
    bpy.ops.wm.open_mainfile(filepath=blend)
    body = bpy.data.objects["Body"]
    arm = bpy.data.objects["Armature"]
    lod_hidden = {}
    seam, mouth_obj, _ = mouth.open_mouth(body, face_keys.Face(body), arm, **TEETH.get(char, {}))
    f, rep = face_keys.add_expression_keys(body)
    riders = []
    for o in bpy.data.objects:
        if o.type == "MESH" and o not in (body, mouth_obj) and face_keys.transfer_keys(body, f, o):
            riders.append(o.name)
    for name, rel in FACE_RIDERS.get(char, {}).items():
        o = bpy.data.objects[name]
        face_keys.transfer_keys(body, f, o, force=True)
        was = o.hide_get()
        export_rider(os.path.join(REPO, rel), o, arm)
        o.hide_set(was)
        riders.append(name + " -> " + rel)
    if "Mouth" not in mesh_nodes:
        mesh_nodes.append("Mouth")
    objs = [bpy.data.objects[n] for n in mesh_nodes if n in bpy.data.objects]
    lost = [n for n in mesh_nodes if n not in bpy.data.objects]
    if lost:
        raise RuntimeError("objects in %s.glb missing from the .blend: %s" % (char, lost))
    for o in objs:
        lod_hidden[o.name] = o.hide_get()
    if arm.animation_data:
        arm.animation_data.action = None
    export_glb(glb, objs, arm)
    for o in objs:
        o.hide_set(lod_hidden[o.name])
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
    after = glb_json(glb)
    clips_after = sorted(a["name"] for a in after.get("animations", []))
    targets = [m.get("extras", {}).get("targetNames", []) for m in after["meshes"]]
    nkeys = max(len(t) for t in targets)
    print("== %s: landmarks eye_x=%.4f mouth_z=%.4f corner_x=%.4f scale h=%.2f v=%.2f" % (
        char, f.eye[1][0], f.mouth[2], f.corner_x, f.sh, f.sv))
    print("   keys on Body: %d (max shift %s mm)" % (nkeys, ", ".join(
        "%s %.1f" % (k, v * 1000) for k, v in rep.items())))
    print("   mouth: %d seam edges opened, Mouth %d tris" % (seam, sum(len(p.vertices) - 2 for p in mouth_obj.data.polygons)))
    print("   riders: %s | meshes: %s" % (riders, [o.name for o in objs]))
    if clips_after != clips:
        raise RuntimeError("clips changed: %s -> %s" % (clips, clips_after))
    print("   clips unchanged: %d" % len(clips))


if __name__ == "__main__":
    for c in [a for a in sys.argv[1:] if not a.startswith("-")]:
        run(c)
