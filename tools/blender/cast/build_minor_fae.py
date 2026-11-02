"""Minor fae on the main cast's body (lane L48): one rigged, dressed, masked figure per run, at the
main cast's level of detail, exported as a single self-contained glTF that drops into the slot the
old fae_people.py figure filled.

    /opt/bpyenv/bin/python tools/blender/cast/build_minor_fae.py <id> [<id> ...]   (ids: cast_minor.DESIGNS)
    /opt/bpyenv/bin/python tools/blender/cast/build_minor_fae.py all

Each <id> runs in its own Blender process (build_cast keeps module state).  The run:

1. build_cast stages 1-3 with cast_minor as the character module: Feyre's body pipeline on this
   figure's sculpt, its clothes, mask and hair from the shared kits, warped to its height;
2. the clips PersonAnimator needs (creatures/anim/person_animator.gd): idle, a strolling walk,
   talk, flinch and bow, keyed on the warped rig;
3. bakes the face (brows, lips, liner, blush from the makeup masks) into the head's albedo, since
   court figures wear plain glTF materials rather than feyre_skin.gdshader;
4. drops the body under the clothes, decimates clothes, hair and mask to the 15k creature budget
   (R4), joins everything into one skinned mesh and exports
   creatures/models/people/<id>.gltf (feet at the origin, facing -Z in Godot, like the old
   figures) and data/animation/people/<id>_gaits.txt.

Godot generates the LODs on import (meshes/generate_lods).  Deterministic up to Blender's own
float noise.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_MODELS = os.path.join(REPO, "creatures", "models", "people")
OUT_GAITS = os.path.join(REPO, "data", "animation", "people")
BUDGET = 15000


def _ids(args):
    sys.path.insert(0, HERE)
    if args == ["all"]:
        src = open(os.path.join(HERE, "cast_minor.py")).read()
        import re
        block = src.split("DESIGNS = {", 1)[1].split("\n}\n", 1)[0]
        return re.findall(r'^    "([a-z_0-9]+)": dict\(', block, re.M)
    return args


if __name__ == "__main__" and os.environ.get("MINOR_FAE") is None:
    ids = _ids([a for a in sys.argv[1:] if not a.startswith("-")])
    bad = 0
    for i in ids:
        env = dict(os.environ, MINOR_FAE=i)
        r = subprocess.run([sys.executable, os.path.abspath(__file__)], env=env)
        print("== %s: %s" % (i, "ok" if r.returncode == 0 else "FAILED (%d)" % r.returncode))
        bad += r.returncode != 0
    sys.exit(1 if bad else 0)

# --------------------------------------------------------------------------
# One figure (MINOR_FAE is set)
# --------------------------------------------------------------------------
ID = os.environ["MINOR_FAE"]
sys.argv = [sys.argv[0], "minor"]
sys.path.insert(0, HERE)

import dataclasses  # noqa: E402
import math  # noqa: E402
import tempfile  # noqa: E402

import build_cast as bc  # noqa: E402  (imports bpy, cast_minor, Feyre's builders)
import bmesh  # noqa: E402
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

bf, bg, fa, C = bc.bf, bc.bg, bc.feyre_anims, bc.C
bc.TMP = os.path.join(tempfile.gettempdir(), "cast_build", "minor_" + ID)
bf.MODEL_DIR = bc.TMP
bf.WARDROBE_DIR = os.path.join(bc.TMP, "_hunter")
qx, qy, qz, SIDES = fa.qx, fa.qy, fa.qz, fa.SIDES


# --------------------------------------------------------------------------
# Clips
# --------------------------------------------------------------------------
def stroll():
    """A court stroll in place of Feyre's brisk 3.2 m/s walk: shorter steps, less lift."""
    g = dataclasses.replace(fa.GAITS[0], speed=1.30, frames=28, lift=0.055, crouch=0.045, bob=0.010,
                            arm=12.0, elbow=14.0, elbow_swing=8.0, lean=2.0, trail=6.0)
    if C.GAIT == "male":
        g = dataclasses.replace(g, sway=g.sway * 0.45, roll=g.roll * 0.45, yaw=g.yaw * 0.8, width=g.width + 0.012,
                                arm=g.arm * 0.9, elbow=g.elbow * 0.8, lean=g.lean * 1.1)
    return g


def talk_frame(t):
    """Easy conversation: weight settles, the right hand opens and turns, a nod or two."""
    fr = fa.idle_frame(t)
    a = math.sin(2 * math.pi * 2 * t)
    b = math.sin(2 * math.pi * 3 * t + 1.0)
    lift = 0.6 + 0.4 * math.sin(2 * math.pi * t)
    fr.add("RightUpperArm", qx(-(16.0 + 8.0 * a) * lift) @ qy(-6.0 * lift), -1.0)
    fr.add("RightLowerArm", qz(-(38.0 + 14.0 * b) * lift) @ qx(-20.0 * lift), -1.0)
    fr.add("RightHand", qx(18.0 * b * lift) @ qy(-14.0 * lift), -1.0)
    fr.add("LeftLowerArm", qz(-10.0 * (0.5 + 0.5 * a)), 1.0)
    fa.head(fr, pitch=4.0 * math.sin(2 * math.pi * 4 * t) * 0.6, yaw=6.0 * math.sin(2 * math.pi * t), tilt=3.0 * b)
    return fr


def flinch_frame(t):
    """A start: shoulders up, a half step back from the lean, hands half raised, head turned aside."""
    e = fa.env(t, 0.0, 0.12, 1.0)
    fr = fa.idle_frame(0.0)
    fa.spine(fr, lean=-10.0 * e, yaw=-12.0 * e, roll=3.0 * e)
    fa.head(fr, pitch=-6.0 * e, yaw=-24.0 * e, tilt=6.0 * e)
    for side, s in SIDES:
        fr.add(side + "Shoulder", qy(-9.0 * e), s)
        fr.add(side + "UpperArm", qx(-28.0 * e) @ qy(-18.0 * e), s)
        fr.add(side + "LowerArm", qz(-60.0 * e), s)
    fr.hips += Vector((0.0, 0.03 * e, -0.02 * e))
    return fr


def bow_frame(t):
    """A courtly bow: right hand to the heart, a bend from the hips, the head low, then up."""
    e = fa.env(t, 0.08, 0.42, 0.92)
    h = fa.env(t, 0.0, 0.25, 0.97)
    fr = fa.idle_frame(0.0)
    fr.add("Hips", qx(10.0 * e))
    fa.spine(fr, lean=26.0 * e, yaw=0.0)
    fa.head(fr, pitch=18.0 * e, yaw=0.0)
    fr.add("RightUpperArm", qx(-38.0 * h) @ qy(-30.0 * h), -1.0)
    fr.add("RightLowerArm", qz(-105.0 * h), -1.0)
    fr.add("RightHand", qy(-12.0 * h), -1.0)
    fr.add("LeftUpperArm", qx(10.0 * e), 1.0)
    fr.hips += Vector((0.0, 0.035 * e, -0.012 * e))
    return fr


def add_clips(arm):
    scene = bpy.context.scene
    scene.render.fps, scene.render.fps_base = fa.FPS, 1.0
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    g = stroll()
    rig = fa.Rig(arm)
    clips = [("idle", [fa.idle_frame(f / fa.IDLE_FRAMES) for f in range(fa.IDLE_FRAMES)], True, 0.0),
             ("walk", [fa.gait_frame(g, f / g.frames) for f in range(g.frames)], True, g.speed),
             ("talk", [talk_frame(f / 120) for f in range(120)], True, None),
             ("flinch", [flinch_frame(f / 36) for f in range(37)], False, None),
             ("bow", [bow_frame(f / 72) for f in range(73)], False, None)]
    gaits = []
    for name, frames, loop, speed in clips:
        fa.reset_pose(arm)
        fa.key_action(rig, name, frames, loop)
        dur = (len(frames) if loop else len(frames) - 1) / fa.FPS
        gaits.append((name, speed, dur, loop))
    arm.animation_data.action = None
    fa.reset_pose(arm)
    scene.frame_set(0)
    return gaits


# --------------------------------------------------------------------------
# Face bake
# --------------------------------------------------------------------------
def _srgb01(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def bake_face(body):
    """Skin plus the makeup masks (lips R, shadow G, liner B, blush A; brows in mask b's R) into
    one sRGB albedo on the head material."""
    def load(name):
        img = bpy.data.images.load(os.path.join(bc.TMP, name), check_existing=False)
        img.colorspace_settings.name = "Non-Color"
        w, h = img.size
        px = np.array(img.pixels[:], np.float32).reshape(h, w, 4)
        bpy.data.images.remove(img)
        return px
    a, b = load("makeup_mask_a.png"), load("makeup_mask_b.png")
    h, w = a.shape[:2]
    col = np.empty((h, w, 3), np.float32)
    col[:] = _srgb01(C.SKIN_SRGB)
    female = C.KIND in ("female", "round")
    layers = [(a[..., 3], "F29A9A" if female else "D99A8E", 0.45 if female else 0.18),     # blush
              (a[..., 1], "C9A8D8" if female else C.SKIN_SRGB, 0.30 if female else 0.0),   # lid wash
              (a[..., 2], "3A2420" if not C.BLACK_EYES else "141018", 0.55 if female else 0.30),   # liner
              (b[..., 0], C.BROWS_SRGB, 0.85),                                                # brows
              (a[..., 0], C.LIPS_SRGB, 0.85 if female else 0.55)]                             # lips
    for m, hexc, amt in layers:
        k = np.clip(m * amt, 0, 1)[..., None]
        col = col * (1 - k) + _srgb01(hexc) * k
    img = bpy.data.images.new(ID + "_face", w, h, alpha=False)
    img.colorspace_settings.name = "sRGB"
    px = np.ones((h, w, 4), np.float32)
    px[..., :3] = col
    img.pixels = px.ravel()
    img.pack()
    mat = body.data.materials["head"] if "head" in body.data.materials else None
    if mat is None:
        return "face bake: no head material"
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return "face bake: %dx%d" % (w, h)


# --------------------------------------------------------------------------
# Merge to budget
# --------------------------------------------------------------------------
def _world_bvh(objs):
    bm = bmesh.new()
    for o in objs:
        m = o.data.copy()
        m.transform(o.matrix_world)
        bm.from_mesh(m)
        bpy.data.meshes.remove(m)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


def hide_covered_body(body, cloth, arm):
    """Delete the body faces every vertex of which looks out through a garment (within 30 cm along
    its normal): legs under a skirt, the torso under a tunic.  Hands, neck and face stay."""
    if not cloth:
        return 0
    tree = _world_bvh(cloth)
    me = body.data
    mw = body.matrix_world
    covered = np.zeros(len(me.vertices), bool)
    neck_z = arm.data.bones["Neck"].head_local.z
    wrist_x = abs(arm.data.bones["LeftHand"].head_local.x) - 0.01
    for v in me.vertices:
        p = mw @ v.co
        n = (mw.to_3x3() @ v.normal).normalized()
        if v.co.z > neck_z or abs(v.co.x) > wrist_x:    # never the head, neck or hands
            continue
        hit = tree.ray_cast(p + n * 0.0015, n, 0.30)
        covered[v.index] = hit[0] is not None
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    gone = [f for f in bm.faces if all(covered[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bm.to_mesh(me)
    bm.free()
    return len(gone)


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def decimate(o, ratio):
    if ratio >= 0.999:
        return
    mod = o.modifiers.new("dec", "DECIMATE")
    mod.ratio = max(ratio, 0.15)
    mod.use_collapse_triangulate = True
    bf.select_only([o], o)
    # the armature modifier must stay; move the decimate to the top of the stack and apply it
    while o.modifiers[0] != mod:
        bpy.ops.object.modifier_move_up(modifier=mod.name)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def merge(ctx, arm):
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.name != "Body_LOD1"
              and (o.parent == arm or any(m.type == "ARMATURE" for m in o.modifiers))]
    bpy.data.objects.remove(bpy.data.objects["Body_LOD1"])
    for o in meshes:
        if o.data.shape_keys:
            o.shape_key_clear()
    body = ctx.body
    cloth = [o for o, k in ctx.wardrobe if k == "cloth"]
    removed = hide_covered_body(body, cloth, arm)
    fixed = [o for o in meshes if o.name in ("Eyes", "Lashes", "Mouth") or o is body]
    soft = [o for o in meshes if o not in fixed]
    hard = sum(tris(o) for o in fixed)
    have = sum(tris(o) for o in soft)
    ratio = min(1.0, (BUDGET - 300 - hard) / max(have, 1))
    for o in soft:
        decimate(o, ratio)
    total = sum(tris(o) for o in meshes)
    bf.select_only(meshes, body)
    bpy.ops.object.join()
    body.name = body.data.name = ID
    return body, ["body faces under clothes removed = %d" % removed,
                  "clothes/hair/mask decimate ratio = %.3f" % ratio, "LOD0 tris = %d (budget %d)" % (total, BUDGET)]


def export(model, arm, gaits):
    root = bpy.data.objects.new(ID + "_root", None)
    bpy.context.scene.collection.objects.link(root)
    root.rotation_euler = (0.0, 0.0, math.pi)      # glTF +Z (Feyre's front) -> -Z, the court figures' front
    arm.parent = root
    for a in bpy.data.actions:
        a.use_fake_user = True
    for img in bpy.data.images:                    # unique texture names: every figure sits in one folder
        if img.users and not img.name.startswith(ID):
            img.name = "%s_%s" % (ID, img.name.split(".")[0])
        if img.users and img.packed_file is None and img.size[0] > 0:
            img.pack()
    # The joints' rest is exported as idle's first frame (arms down), not the T-pose, so a scene that
    # instances the figure without playing a clip (the cave trio, the mural, the wayside sentry)
    # still shows someone standing at ease.  Clips are absolute transforms, so they are unchanged.
    idle = bpy.data.actions["idle"]
    arm.animation_data.action = idle
    if hasattr(arm.animation_data, "action_slot") and idle.slots:
        arm.animation_data.action_slot = idle.slots[0]
    bpy.context.scene.frame_set(0)
    bf.select_only([root, arm, model], root)
    path = os.path.join(OUT_MODELS, ID + ".gltf")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", use_selection=True, export_apply=False,
                              export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_morph=False, export_yup=True, export_rest_position_armature=False, export_materials="EXPORT", export_extras=False)
    _own_uris(path)
    with open(os.path.join(OUT_GAITS, ID + "_gaits.txt"), "w") as f:
        f.write("# %s clips (creatures/models/people/%s.gltf), 30 fps. Written by "
                "tools/blender/cast/build_minor_fae.py.\n" % (ID, ID))
        f.write("# name native_speed_mps duration_s loop(0/1)   ('-' = not a locomotion clip)\n")
        for name, speed, dur, loop in gaits:
            f.write("%s %s %.3f %d\n" % (name, "-" if speed is None else "%.3f" % speed, dur, int(loop)))
    return path


def _own_uris(path):
    """Prefix every image file the export wrote with this figure's id (the Feyre kit's eye_iris.png
    would otherwise be shared, and overwritten, by every figure in the folder)."""
    import json
    with open(path) as f:
        j = json.load(f)
    d = os.path.dirname(path)
    for im in j.get("images", []):
        uri = im.get("uri", "")
        if uri and not uri.startswith(ID + "_"):
            new = "%s_%s" % (ID, uri)
            os.replace(os.path.join(d, uri), os.path.join(d, new))
            im["uri"] = new
    with open(path, "w") as f:
        json.dump(j, f, separators=(",", ":"))


def main():
    os.makedirs(bc.TMP, exist_ok=True)
    print("== stage 1: Feyre's body pipeline on the %s sculpt" % ID)
    bf.main()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(bc.TMP, "feyre.blend"))
    for n in [o.name for o in bpy.data.objects if o.name.startswith("hunter_")]:
        bpy.data.objects.remove(bpy.data.objects[n])
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    for coll in list(bpy.data.collections):
        bpy.data.collections.remove(coll)
    for o in bpy.data.objects:
        if o.name not in bpy.context.scene.collection.objects:
            bpy.context.scene.collection.objects.link(o)

    print("== stage 2: clothes, mask, hair")
    ctx = bc.Ctx()
    report = C.build(ctx) or []

    print("== stage 3: warp to %.2f m, clips" % C.WARP["height"])
    W = bc.cast_warp.Warp(**C.WARP)
    arm = ctx.arm
    for o in [o for o in bpy.data.objects if o.type == "MESH"]:
        bc.warp_object(o, W)
    bc.warp_armature(arm, W)
    gaits = add_clips(arm)

    print("== stage 4: face, merge, export")
    if C.KIND == "trio":                       # dark velvet, not the court's lacquered silk
        for m in bpy.data.materials:
            if m.node_tree and ":fabric" in m.name or m.name.endswith("fabric"):
                b = m.node_tree.nodes.get("Principled BSDF")
                if b and "Coat Weight" in b.inputs:
                    b.inputs["Coat Weight"].default_value = 0.0
    report.append(bake_face(ctx.body))
    model, lines = merge(ctx, arm)
    report += lines
    path = export(model, arm, gaits)
    P = bf.verts_np(model.data)
    report.append("height = %.3f m (target %.2f)" % (P[:, 2].max() - P[:, 2].min(), C.HEIGHT))
    report.append("clips = %s" % [g[0] for g in gaits])
    report.append("materials = %d, file = %s (%d KB)" % (len(model.data.materials), os.path.relpath(path, REPO),
                                                          os.path.getsize(path) // 1024))
    print("\n==== %s BUILD REPORT ====" % ID.upper())
    print("\n".join(report))


main()
