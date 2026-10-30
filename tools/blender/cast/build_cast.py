"""Main-cast builder: one rigged, dressed character per run, at Feyre's level of detail.

    /opt/bpyenv/bin/python tools/blender/cast/build_cast.py <id>     (tamlin, lucien, nesta, elain, father)

Each character is a module cast_<id>.py holding its look as data plus its own
garment, hair and accessory builders.  The run:

1. installs a per-character feyre_shape (cast_shape) and runs Feyre's own body
   build on it in a temp folder: sculpt, 60-bone rig, heat weights, region
   surfaces, 17 shape keys, eyes with a painted iris, lid margins, lashes,
   makeup masks, LOD1.  The face and body are the character's own; the
   skeleton, bone names, shape-key names and surfaces are Feyre's, so
   feyre_skin.gdshader, the wardrobe convention and retargeted mocap all apply.
2. reopens that rig and builds the character's clothes, hair and accessories
   with Feyre's wardrobe, gown and hair kits (still in Feyre's space, where the
   kits' landmarks are valid);
3. warps everything (meshes, shape keys, bones) to the character's height and
   build with cast_warp, then bakes the locomotion clips on the warped rig
   (feyre_anims' leg IK re-solves for the new leg lengths);
4. exports characters/<id>/model/<id>.glb, characters/<id>/wardrobe/*.glb,
   characters/<id>/hair/*.glb, the textures and an editable <id>.blend.

Conventions are Feyre's: Blender Z up, facing -Y, feet on the origin, T-pose;
glTF faces +Z and <id>_model.tscn turns the instance 180 degrees.  Deterministic.
"""

import dataclasses
import importlib
import math
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
FEYRE = os.path.abspath(os.path.join(HERE, "..", "feyre"))
sys.path.insert(0, HERE)
sys.path.insert(1, FEYRE)

import bpy  # noqa: E402  (before mathutils/bmesh users)

CHAR = next((a for a in sys.argv[1:] if not a.startswith("-")), "tamlin")
C = importlib.import_module("cast_" + CHAR)

import cast_shape  # noqa: E402

sys.modules["feyre_shape"] = cast_shape.load(C.SHAPE)

import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import build_feyre as bf  # noqa: E402
import cast_warp  # noqa: E402
import feyre_anims  # noqa: E402
import feyre_shape as fs  # noqa: E402

REPO = bf.REPO
OUT = os.path.join(REPO, "characters", CHAR)
TMP = os.path.join(tempfile.gettempdir(), "cast_build", CHAR)
bf.MODEL_DIR = TMP
bf.WARDROBE_DIR = os.path.join(TMP, "_hunter")
bf.SKIN_RGB = C.SKIN_LINEAR

import build_gowns as bg  # noqa: E402
import build_hair as bh  # noqa: E402
import build_wardrobe as bw  # noqa: E402


# --------------------------------------------------------------------------
# Feyre-builder overrides: iris colours, lash length
# --------------------------------------------------------------------------
def bake_iris(path, size=256):
    """Feyre's painted iris with this character's colours (outer, inner, fleck)."""
    outer, inner, fleck = (np.array(c) for c in C.IRIS)
    g = (np.arange(size) + 0.5) / size * 2.0 - 1.0
    U, Vv = np.meshgrid(g * bf.UV_SPAN, g * bf.UV_SPAN)
    r = np.sqrt(U * U + Vv * Vv)
    ang = np.arctan2(Vv, U)
    sm = bf.smoothstep
    col = np.zeros((size, size, 4))
    col[..., :3] = np.array([0.97, 0.955, 0.95]) * (1.0 - 0.10 * sm(0.75, 1.05, r))[..., None]
    col[..., :3] -= np.array([0.03, 0.05, 0.06]) * sm(0.2, 1.0, Vv)[..., None]
    t = np.clip(r / bf.IRIS_R, 0, 1)
    iris = outer[None, None] * t[..., None] + inner[None, None] * (1 - t[..., None])
    fib = 0.5 + 0.5 * np.sin(ang * 31.0 + np.sin(ang * 7.0) * 2.0) * np.sin(ang * 13.0 + 1.3)
    iris *= (0.86 + 0.22 * fib)[..., None]
    ring = np.exp(-((t - 0.42) / 0.10) ** 2)
    spots = np.clip(np.sin(ang * 9.0 + 0.7) * np.sin(ang * 5.0) * 2.0 - 0.6, 0, 1) * np.exp(-((t - 0.5) / 0.18) ** 2)
    k = 0.30 * ring + 0.55 * spots * C.IRIS_FLECKS
    iris = iris * (1 - k[..., None]) + fleck * k[..., None]
    iris *= (1.0 - 0.55 * sm(0.80, 1.0, t))[..., None]
    iris *= (1.0 - 0.30 * sm(0.0, 0.9, Vv / bf.IRIS_R))[..., None]
    m_iris = 1.0 - sm(bf.IRIS_R - 0.015, bf.IRIS_R + 0.015, r)
    col[..., :3] = col[..., :3] * (1 - m_iris[..., None]) + iris * m_iris[..., None]
    m_pup = 1.0 - sm(bf.PUPIL_R - 0.02, bf.PUPIL_R + 0.01, r)
    col[..., :3] = col[..., :3] * (1 - m_pup[..., None]) + np.array([0.04, 0.04, 0.07]) * m_pup[..., None]
    for cu, cv, rad, kk in ((-0.20, 0.24, 0.13, 1.0), (0.22, -0.20, 0.06, 0.85)):
        d = np.sqrt((U - cu) ** 2 + (Vv - cv) ** 2)
        m = (1.0 - sm(rad * 0.75, rad, d)) * kk
        col[..., :3] = col[..., :3] * (1 - m[..., None]) + m[..., None]
    col[..., 3] = 1.0
    bf.write_png(path, col)


bf.bake_iris_texture = bake_iris
_feyre_lashes = bf.build_lashes


def build_lashes(body_P):
    """Feyre's lashes, shortened towards the lid line by C.LASH (1 = Feyre)."""
    obj = _feyre_lashes(body_P)
    if C.LASH != 1.0:
        me = obj.data
        P = bf.verts_np(me)
        # rows of four verts: under, base, mid, tip
        for i in range(0, len(P), 4):
            base = P[i + 1].copy()
            P[i + 2] = base + (P[i + 2] - base) * C.LASH
            P[i + 3] = base + (P[i + 3] - base) * C.LASH
        me.vertices.foreach_set("co", P.ravel())
        me.update()
    for m in obj.data.materials:
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf is not None:
            bsdf.inputs["Base Color"].default_value = (*C.LASH_LINEAR, 1.0)
    return obj


bf.build_lashes = build_lashes


# --------------------------------------------------------------------------
# Context handed to the character module
# --------------------------------------------------------------------------
class Ctx:
    def __init__(self):
        self.body = bpy.data.objects["Body"]
        self.arm = bpy.data.objects["Armature"]
        self.spec = [(bn.name, tuple(bn.head_local), tuple(bn.tail_local), None, bn.use_deform)
                     for bn in self.arm.data.bones]
        self.probe = bg.BodyProbe(self.body)
        self.sh = bw.Shell(self.probe)
        self.rng = np.random.default_rng(1800 + sum(map(ord, CHAR)))
        self.wardrobe = []   # (object, kind) kind: "cloth" | "acc"
        self.hair = []
        self.model_extra = []  # objects exported inside <id>.glb
        self.props = []      # unskinned props: (object, bone, note)
        self.bg, self.bw, self.bh, self.bf, self.fs = bg, bw, bh, bf, fs

    def builder(self, name, palette=None, first="fabric"):
        return bg.Builder(name, first, {**bw.PAL, **(palette or {})})

    def cloth(self, B, name):
        obj = bw.finalize(B, name, self.probe, self.arm, self.spec)
        self.wardrobe.append((obj, "cloth"))
        return obj

    def gown(self, B, name):
        obj = bg.finalize_gown(B, name, self.probe, self.arm, self.spec)
        self.wardrobe.append((obj, "cloth"))
        return obj

    def head_piece(self, B, name):
        obj = bg.finalize_head(B, name, self.arm)
        self.wardrobe.append((obj, "acc"))
        return obj

    def hair_style(self, sid, fn, rgb):
        bh.HAIR_RGB = rgb
        st = bh.Style(self.head, sid)
        fn(st)
        st.carve_body()
        clear = st.crown_check()
        obj = bh.mesh_style(st, bf.skeleton_spec(), self.arm)
        obj.name = obj.data.name = "hair_" + sid
        self.hair.append(obj)
        return obj, clear

    @property
    def head(self):
        if not hasattr(self, "_head"):
            self._head = bh.Head()
        return self._head


# --------------------------------------------------------------------------
# Warp
# --------------------------------------------------------------------------
def warp_object(obj, W):
    me = obj.data
    if me.shape_keys:
        for kb in me.shape_keys.key_blocks:
            a = np.empty(len(kb.data) * 3)
            kb.data.foreach_get("co", a)
            kb.data.foreach_set("co", W(a.reshape(-1, 3)).ravel())
    P = bf.verts_np(me)
    me.vertices.foreach_set("co", W(P).ravel())
    me.update()


def warp_armature(arm, W):
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.selected_objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    names = [b.name for b in eb]
    H = W(np.array([tuple(eb[n].head) for n in names]))
    T = W(np.array([tuple(eb[n].tail) for n in names]))
    rolls = {n: eb[n].roll for n in names}
    for n, h, t in zip(names, H, T):
        b = eb[n]
        b.use_connect = False
    for n, h, t in zip(names, H, T):
        b = eb[n]
        b.head = Vector(h)
        b.tail = Vector(t)
        b.roll = rolls[n]
    bpy.ops.object.mode_set(mode="OBJECT")


# --------------------------------------------------------------------------
def male_gaits():
    out = []
    for g in feyre_anims.GAITS:
        out.append(dataclasses.replace(g, sway=g.sway * 0.45, roll=g.roll * 0.45, yaw=g.yaw * 0.8,
                                       width=g.width + 0.012, arm=g.arm * 0.9, elbow=g.elbow * 0.8,
                                       lean=g.lean * 1.1))
    return tuple(out)


def main():
    os.makedirs(TMP, exist_ok=True)
    print("== stage 1: Feyre's body pipeline on the %s sculpt" % CHAR)
    bf.main()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(TMP, "feyre.blend"))
    for n in [o.name for o in bpy.data.objects if o.name.startswith("hunter_")]:
        bpy.data.objects.remove(bpy.data.objects[n])
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    for coll in list(bpy.data.collections):
        bpy.data.collections.remove(coll)
    for o in bpy.data.objects:
        if o.name not in bpy.context.scene.collection.objects:
            bpy.context.scene.collection.objects.link(o)
    lod = bpy.data.objects["Body_LOD1"]
    lod.hide_set(False)
    lod.hide_render = False

    print("== stage 2: clothes, hair, accessories")
    ctx = Ctx()
    report = C.build(ctx) or []

    print("== stage 3: warp to %.2f m" % C.WARP["height"])
    W = cast_warp.Warp(**C.WARP)
    arm = ctx.arm
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in meshes:
        warp_object(o, W)
    warp_armature(arm, W)
    if hasattr(C, "after_warp"):
        report += C.after_warp(ctx, W) or []
    if getattr(C, "GAIT", "female") == "male":
        feyre_anims.GAITS = male_gaits()
    clips = feyre_anims.add_actions(arm)
    if hasattr(C, "extra_clips"):
        clips += C.extra_clips(ctx)
    arm.animation_data.action = None

    print("== stage 4: export")
    body = ctx.body
    for sub in ("model", "wardrobe", "hair"):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    for f in ("makeup_mask_a.png", "makeup_mask_b.png", "eye_iris.png"):
        shutil.copy(os.path.join(TMP, f), os.path.join(OUT, "model", f))
    model_objs = [body, lod, bpy.data.objects["Eyes"], bpy.data.objects["Lashes"]] + ctx.model_extra
    bf.export_glb(os.path.join(OUT, "model", CHAR + ".glb"), model_objs, arm, animations=True)
    for o, _ in ctx.wardrobe:
        bg.export_named(os.path.join(OUT, "wardrobe", o.name + ".glb"), o, arm)
    for o in ctx.hair:
        bf.export_glb(os.path.join(OUT, "hair", o.name[len("hair_"):] + ".glb"), [o], arm)
    for o, _, _ in ctx.props:
        select = [o]
        bf.select_only(select, o)
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "model", o.name + ".glb"), export_format="GLB",
                                  use_selection=True, export_yup=True, export_animations=False,
                                  export_materials="EXPORT", export_extras=False)

    allP = bf.verts_np(body.data)
    head_top = allP[:, 2].max()
    lines = ["%-20s tris=%5d" % (o.name, bf.tri_count(o)) for o in model_objs + [w for w, _ in ctx.wardrobe] + ctx.hair
             + [p for p, _, _ in ctx.props]]
    lines.append("hero (body+eyes+lashes+extras) = %d tris" % sum(bf.tri_count(o) for o in model_objs if o is not lod))
    lines.append("height = %.4f m (target %.2f), shoulder width = %.3f m" % (
        head_top - allP[:, 2].min(), C.WARP["height"],
        2 * arm.data.bones["LeftUpperArm"].head_local.x))
    lines.append("bones = %d, clips = %s" % (len(arm.data.bones), clips))
    lines.append("shape keys = %d" % len(body.data.shape_keys.key_blocks))
    lines += bf.pose_check(arm, [body] + [w for w, k in ctx.wardrobe if k == "cloth"][:1])
    for pb in arm.pose.bones:          # pose_check leaves Euler modes, which would ignore the clips' quaternions
        pb.rotation_mode = "QUATERNION"
    for img in bpy.data.images:
        img.pack()
    bpy.context.preferences.filepaths.save_version = 0
    blend = os.path.join(OUT, "model", CHAR + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
    with open(blend + ".import", "w") as f:   # Godot must not try to import it (needs desktop Blender)
        f.write('[remap]\n\nimporter="skip"\n')
    print("\n==== %s BUILD REPORT ====" % CHAR.upper())
    print("\n".join(report + lines))


if __name__ == "__main__":
    main()
