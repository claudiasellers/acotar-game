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
# a finer face where the character asks for it (the sisters' close-up faces): more of the tri budget
# goes to face, ears and hands; the rest of the body keeps Feyre's count
if getattr(C, "FACE_TRIS", 0):
    bf.BODY_TRIS += C.FACE_TRIS - bf.DETAIL_TRIS
    bf.DETAIL_TRIS = C.FACE_TRIS

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
    """Feyre's lashes scaled by C.LASH (1 = Feyre), with C.LASH_FLICK lengthening the outer
    half into a princess flick (0 = Feyre's taper)."""
    obj = _feyre_lashes(body_P)
    flick = getattr(C, "LASH_FLICK", 0.0)
    if C.LASH != 1.0 or flick:
        me = obj.data
        P = bf.verts_np(me)
        per_side = len(P) // 8   # rows of four verts (under, base, mid, tip), both sides
        for i in range(0, len(P), 4):
            j = (i // 4) % per_side
            tx = -0.96 + 1.92 * j / max(1, per_side - 1)
            k = C.LASH * (1.0 + flick * max(0.0, tx) ** 1.5)
            base = P[i + 1].copy()
            P[i + 2] = base + (P[i + 2] - base) * k
            P[i + 3] = base + (P[i + 3] - base) * k
        me.vertices.foreach_set("co", P.ravel())
        me.update()
    for m in obj.data.materials:
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf is not None:
            bsdf.inputs["Base Color"].default_value = (*C.LASH_LINEAR, 1.0)
    return obj


bf.build_lashes = build_lashes


def build_strand_lashes(body_P):
    """Princess lashes for C.LASH_STYLE == "strands": separate tapered strands that rise from the
    upper-lid rim and curl up and out, longest at the outer corner (C.LASH_FLICK), a few short
    lower lashes at the outer corner (C.LOWER_LASH).  Same object name, material and skinning
    as Feyre's ribbon, so the export and the game see no difference but the shape."""
    bm = bmesh.new()
    n_up = getattr(C, "LASH_COUNT", 26)
    flick = getattr(C, "LASH_FLICK", 0.0)
    lower = getattr(C, "LOWER_LASH", 0.0)
    for s in (1, -1):
        c = np.array([fs.EYE_X * s, fs.EYE_Y, fs.EYE_Z])
        rim = bf.lid_rim_points(body_P, s, n=15)
        # resample the rim evenly
        seg = np.linalg.norm(np.diff(rim, axis=0), axis=1)
        t = np.concatenate([[0], np.cumsum(seg)]) / seg.sum()
        rows = [(n_up, True)] + ([(9, False)] if lower > 0 else [])
        for count, upper in rows:
            for i in range(count):
                if upper:
                    u = (i + 0.5) / count
                    base = np.array([np.interp(0.04 + 0.94 * u, t, rim[:, k]) for k in range(3)])
                    base += (c - base) * 0.04 - np.array([0, 0, 0.0007])   # root on the lid edge, not above it
                    tx = -1.0 + 2.0 * u                     # inner corner -> outer corner
                else:
                    u = 0.55 + 0.42 * (i + 0.5) / count
                    a = (-0.06 + 1.0 * (u - 0.5) * 2) * fs.EYE_OPEN_W
                    az = -fs.EYE_OPEN_LO * math.sqrt(max(0.0, 1.0 - abs(u * 2 - 1) ** 1.6)) - math.radians(4)
                    az += fs.EYE_TILT * (u * 2 - 1)
                    d = np.array([math.sin(a) * math.cos(az) * s, -math.cos(a) * math.cos(az), math.sin(az)])
                    base = c + d * (fs.EYE_R + fs.LID_GAP + 0.0006)
                    tx = u * 2 - 1
                out = base - c
                out /= np.linalg.norm(out)
                side_v = np.cross(out, [0, 0, 1.0])
                side_v /= np.linalg.norm(side_v)
                outer = max(0.0, tx)
                if upper:
                    L = 0.0060 * C.LASH * (0.55 + 0.45 * math.sin(math.pi * (0.5 + 0.5 * tx) * 0.5 + 0.3)) \
                        * (1.0 + flick * outer ** 1.4)
                    L *= 0.88 if i % 3 == 1 else 1.0
                    up = np.array([0, -0.15, 1.0])
                    lat = np.array([s * 1.0, 0, 0]) * (0.25 + 1.1 * outer ** 1.2) - np.array([s, 0, 0]) * 0.25 * max(0.0, -tx)
                    curl = 1.0
                else:
                    L = 0.0022 * C.LASH * lower * (0.6 + 0.8 * (tx - 0.1))
                    up = np.array([0, -0.2, -1.0])
                    lat = np.array([s * 0.9, 0, 0]) * tx
                    curl = -1.0
                d0 = out * 0.75 + up * 0.25 + lat * 0.25
                d0 /= np.linalg.norm(d0)
                pts, w = [], []
                p = base.copy()
                dirn = d0.copy()
                for k in range(4):
                    pts.append(p.copy())
                    w.append(0.0011 * (1.0 - k / 3.0) ** 0.7 + 0.00008)
                    bend = up * 0.55 * curl + lat * 0.2
                    dirn = dirn + bend * 0.45
                    dirn /= np.linalg.norm(dirn)
                    p = p + dirn * L / 3.0
                vs = []
                for k, (q, ww) in enumerate(zip(pts, w)):
                    vs.append((bm.verts.new(q - side_v * ww), bm.verts.new(q + side_v * ww)))
                for k in range(3):
                    a1, b1 = vs[k]
                    a2, b2 = vs[k + 1]
                    f = bm.faces.new((a1, b1, b2, a2) if s > 0 else (a1, a2, b2, b1))
                    f.smooth = True
    bm.normal_update()
    obj = bf.obj_from_bm("Lashes", bm)
    obj.data.materials.append(bf.make_material("lashes", C.LASH_LINEAR, 0.45, cull=False))
    return obj


if getattr(C, "LASH_STYLE", "") == "strands":
    bf.build_lashes = build_strand_lashes


_feyre_masks = bf.bake_makeup_masks


def bake_makeup_masks(P, tris, uv, size=1024):
    """Feyre's masks, then (when the character sets MASK) its own eye shadow, liner, blush and brows:
    the shadow and liner hug the upper lid from the inner corner to a wing at C.MASK["wing"] degrees,
    the blush sits on the apples, the brows take C.MASK's arch and weight.  Lips are Feyre's mask
    widened to the character's mouth (MOUTH_HALF_W)."""
    stats = _feyre_masks(P, tris, uv, size)
    M = getattr(C, "MASK", None)
    if not M:
        return stats
    X, Y, Z, cov = bf.raster_head(P, tris, uv, size)
    F = (cov & (Y < bf.HEAD_C.y - 0.015)).astype(float)
    ax = np.abs(X)
    side = np.where(X >= 0, 1.0, -1.0)
    sm = bf.smoothstep
    deg = math.pi / 180.0

    def ell(cx, cz, rx, rz, soft=0.35):
        d = np.sqrt(((ax - cx) / rx) ** 2 + ((Z - cz) / rz) ** 2)
        return (1.0 - sm(1.0 - soft, 1.0, d)) * F

    MZ, lw = fs.MOUTH_Z, fs.MOUTH_HALF_W / 0.0165
    upper = ell(0.0, MZ + 0.0040, 0.0172 * lw, 0.0049, 0.35)
    bow = 1.0 - 0.6 * np.exp(-(X / 0.0028) ** 2) * sm(MZ + 0.006, MZ + 0.0085, Z)
    lower = ell(0.0, MZ - 0.0045, 0.0140 * lw, 0.0060, 0.4)
    lips = np.maximum(upper * bow, lower) * (Y < fs.MOUTH_Y + 0.004)
    qx, qy, qz = X - fs.EYE_X * side, Y - fs.EYE_Y, Z - fs.EYE_Z
    eax, eaz, up, lo = fs.eye_angles(qx, qy, qz, side)
    edist = np.sqrt(qx * qx + qy * qy + qz * qz)
    near = (edist < fs.EYE_R + 0.020) * F * (ax > 0.008)     # never across the bridge of the nose
    over = eaz - up
    inner_cut = sm(-fs.EYE_OPEN_W * 1.02, -fs.EYE_OPEN_W * 0.80, eax)
    outer_cut = 1.0 - sm(fs.EYE_OPEN_W * 1.05, fs.EYE_OPEN_W * 1.40, eax)
    sh_h = M.get("shadow_h", 20.0) * deg
    shadow = sm(-2 * deg, 2 * deg, over) * (1.0 - sm(sh_h * 0.5, sh_h, over)) * inner_cut * outer_cut * near
    lw_deg = M.get("liner_w", 3.5) * deg
    liner = sm(-5.0 * deg, -3.0 * deg, over) * (1.0 - sm(lw_deg * 0.6, lw_deg, over)) * inner_cut \
        * (1.0 - sm(fs.EYE_OPEN_W * 0.98, fs.EYE_OPEN_W * 1.05, eax)) * near * (edist < fs.EYE_R + 0.0075)
    # thicker towards the outer corner
    liner *= 0.75 + 0.25 * sm(-0.2, 0.8, eax / fs.EYE_OPEN_W)
    wing_deg = M.get("wing", 0.0)
    if wing_deg > 0:
        wt = np.clip((eax - fs.EYE_OPEN_W * 0.92) / (wing_deg * deg), 0, 1)
        wing_az = up * 0 + fs.EYE_TILT * 0.0 + wt * M.get("wing_lift", 14.0) * deg
        wing = np.exp(-((eaz - wing_az) / ((2.8 - 2.2 * wt) * deg)) ** 2) * (eax > fs.EYE_OPEN_W * 0.88) * (wt < 1) * near
        liner = np.maximum(liner, wing)
    low = M.get("lower_liner", 0.0)
    if low > 0:   # a soft smudge under the outer half of the lower lid
        under = -eaz - lo
        ll = sm(-1.0 * deg, 0.5 * deg, under) * (1.0 - sm(2 * deg, 4 * deg, under)) * sm(0.1, 0.6, eax / fs.EYE_OPEN_W) \
            * (1.0 - sm(fs.EYE_OPEN_W * 0.95, fs.EYE_OPEN_W * 1.05, eax)) * near
        liner = np.maximum(liner, ll * low)
    bx, bz, brx, brz = M.get("blush", (0.047, 1.477, 0.017, 0.012))
    blush = ell(bx, bz, brx, brz, 0.9)
    arch, wgt = M.get("brow_arch", 1.0), M.get("brow_weight", 1.0)
    bt = np.clip((ax - 0.013) / 0.047, 0, 1)
    brow_z = fs.BROW_Z + 0.006 * arch * np.sin(np.minimum(bt / M.get("brow_peak", 0.7), 1.0) * math.pi * 0.5) \
        - 0.009 * arch * sm(M.get("brow_peak", 0.7), 1.0, bt) - 0.003 * bt
    brow_th = 0.0031 * wgt * (1.0 - 0.65 * bt)
    brows = np.exp(-((Z - brow_z) / brow_th) ** 4) * (ax > 0.011) * (ax < 0.062) * F
    brows *= 1.0 - sm(0.85, 1.0, bt)
    a = np.stack([lips, shadow, liner, blush], axis=-1)
    paint = np.zeros_like(X)   # festival paint stays Feyre's (Calanmai) alone
    b = np.stack([brows, paint, np.zeros_like(X), np.ones_like(X)], axis=-1)
    bf.write_png(os.path.join(bf.MODEL_DIR, "makeup_mask_a.png"), a)
    bf.write_png(os.path.join(bf.MODEL_DIR, "makeup_mask_b.png"), b)
    return {k: round(float(v.sum()) / 1000.0, 1) for k, v in dict(
        lips=lips, shadow=shadow, liner=liner, blush=blush, brows=brows).items()}


bf.bake_makeup_masks = bake_makeup_masks


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
