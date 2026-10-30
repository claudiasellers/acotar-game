"""Procedural first-pass Feyre base model.

Reproducible build:
    blender -b -P tools/blender/feyre/build_feyre.py
or, with the PyPI `bpy` module:
    python tools/blender/feyre/build_feyre.py

Writes (relative to the repo root):
    characters/feyre/model/feyre.blend            editable source
    characters/feyre/model/feyre.glb              body + head + eyes + braid (+ Body_LOD1)
    characters/feyre/model/makeup_mask_a.png      R lips  G eyeshadow  B liner  A blush
    characters/feyre/model/makeup_mask_b.png      R brows G face_paint
    characters/feyre/wardrobe/hunter_*.glb        tunic / trousers / cloak / boots

Conventions: Blender Z up, character faces -Y (Blender "front" view), feet on
the origin, T-pose.  glTF therefore faces +Z; feyre_model.tscn turns the
instance 180 degrees so the game sees her facing -Z.

Art direction: stylised (about 1 : 6.5 head-to-body), big expressive eyes, soft
rounded forms, thin-from-hunger base with a `nourished` shape key.
Everything is generated from the numbers below, so tweak them and rebuild, or
open feyre.blend and sculpt by hand.
"""

import math
import os
import struct
import sys
import zlib

import bpy  # noqa: E402  (must come before bmesh when used as a module)
import bmesh
import numpy as np
from mathutils import Matrix, Vector, kdtree
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MODEL_DIR = os.path.join(REPO, "characters", "feyre", "model")
WARDROBE_DIR = os.path.join(REPO, "characters", "feyre", "wardrobe")

HEIGHT = 1.66
SKIN_RGB = (0.86, 0.69, 0.57)

# Head landmarks (metres, Blender space).
HEAD_TOP = HEIGHT
CHIN_Z = 1.405
HEAD_C = Vector((0.0, -0.005, (HEAD_TOP + CHIN_Z) / 2.0))
HEAD_HALF = Vector((0.075, 0.095, (HEAD_TOP - CHIN_Z) / 2.0))
EYE_X, EYE_Z = 0.034, 1.525
EYE_HOLE_RX, EYE_HOLE_RZ = 0.020, 0.0115
EYE_RADIUS = 0.0165
NOSE_Z = 1.487
MOUTH_Z = 1.452
MOUTH_HALF_W = 0.021

REGIONS = ["torso", "arms", "legs", "feet", "hands", "head"]

# --------------------------------------------------------------------------
# Skeleton: (name, head, tail, parent, deform).  Left side is +X.
# --------------------------------------------------------------------------
FINGERS = {
    # name: (knuckle x, y, z, [segment lengths])
    "Index": (0.748, -0.022, 1.343, [0.033, 0.020, 0.017]),
    "Middle": (0.752, -0.007, 1.343, [0.036, 0.023, 0.019]),
    "Ring": (0.749, 0.008, 1.343, [0.033, 0.021, 0.018]),
    "Little": (0.742, 0.022, 1.342, [0.026, 0.017, 0.016]),
}
THUMB = [(0.668, -0.016, 1.339), (0.695, -0.042, 1.334), (0.718, -0.058, 1.331),
         (0.738, -0.067, 1.329), (0.752, -0.072, 1.328)]
FINGER_SEG_NAMES = ["Proximal", "Intermediate", "Distal"]
THUMB_SEG_NAMES = ["Metacarpal", "Proximal", "Distal"]

BRAID_PATH = [(0.050, 0.040, 1.478), (0.088, 0.000, 1.405), (0.098, -0.095, 1.315),
              (0.096, -0.142, 1.190), (0.090, -0.147, 1.040)]


def finger_points(name):
    x, y, z, lens = FINGERS[name]
    pts = [(x, y, z)]
    for i, ln in enumerate(lens):
        x += ln
        y += -0.001 if name == "Index" else 0.0
        z -= 0.001
        pts.append((x, y, z))
    return pts


def skeleton_spec(eye_y):
    b = [
        ("Root", (0, 0, 0), (0, 0, 0.10), None, False),
        ("Hips", (0, 0, 0.88), (0, 0, 0.97), "Root", True),
        ("Spine", (0, 0, 0.97), (0, 0, 1.07), "Hips", True),
        ("Chest", (0, 0, 1.07), (0, 0, 1.18), "Spine", True),
        ("UpperChest", (0, 0, 1.18), (0, 0, 1.36), "Chest", True),
        ("Neck", (0, 0.0, 1.36), (0, 0.0, 1.44), "UpperChest", True),
        ("Head", (0, 0.0, 1.44), (0, 0.0, 1.62), "Neck", True),
        ("Jaw", (0, -0.005, 1.49), (0, -0.07, 1.425), "Head", True),
    ]
    for side, s in (("Left", 1), ("Right", -1)):
        def m(p):
            return (p[0] * s, p[1], p[2])
        b.append((side + "Eye", m((EYE_X, eye_y, EYE_Z)), m((EYE_X, eye_y - 0.03, EYE_Z)), "Head", True))
        b += [
            (side + "Shoulder", m((0.02, -0.01, 1.33)), m((0.15, 0, 1.345)), "UpperChest", True),
            (side + "UpperArm", m((0.15, 0, 1.345)), m((0.415, 0, 1.345)), side + "Shoulder", True),
            (side + "LowerArm", m((0.415, 0, 1.345)), m((0.655, 0, 1.345)), side + "UpperArm", True),
            (side + "Hand", m((0.655, 0, 1.345)), m((0.745, 0, 1.343)), side + "LowerArm", True),
        ]
        parent = side + "Hand"
        for i, seg in enumerate(THUMB_SEG_NAMES):
            nm = side + "Thumb" + seg
            b.append((nm, m(THUMB[i]), m(THUMB[i + 1]), parent, True))
            parent = nm
        for f in FINGERS:
            pts = finger_points(f)
            parent = side + "Hand"
            for i, seg in enumerate(FINGER_SEG_NAMES):
                nm = side + f + seg
                b.append((nm, m(pts[i]), m(pts[i + 1]), parent, True))
                parent = nm
        b += [
            (side + "UpperLeg", m((0.088, 0, 0.83)), m((0.09, 0, 0.48)), "Hips", True),
            (side + "LowerLeg", m((0.09, 0, 0.48)), m((0.09, 0.01, 0.085)), side + "UpperLeg", True),
            (side + "Foot", m((0.09, 0.01, 0.085)), m((0.09, -0.085, 0.03)), side + "LowerLeg", True),
            (side + "Toes", m((0.09, -0.085, 0.03)), m((0.09, -0.155, 0.025)), side + "Foot", True),
        ]
    parent = "Head"
    for i in range(4):
        nm = "Braid_%d" % (i + 1)
        b.append((nm, BRAID_PATH[i], BRAID_PATH[i + 1], parent, True))
        parent = nm
    return b


def region_of_bone(name):
    n = name.replace("Left", "").replace("Right", "")
    if n in ("Hips", "Spine", "Chest", "UpperChest", "Shoulder", "Root"):
        return "torso"
    if n in ("Neck", "Head", "Jaw", "Eye") or n.startswith("Braid"):
        return "head"
    if n in ("UpperArm", "LowerArm"):
        return "arms"
    if n in ("UpperLeg", "LowerLeg"):
        return "legs"
    if n in ("Foot", "Toes"):
        return "feet"
    return "hands"


# --------------------------------------------------------------------------
# Small helpers
# --------------------------------------------------------------------------
def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def gauss(P, c, s):
    d = (P - np.asarray(c)) / np.asarray(s)
    return np.exp(-np.sum(d * d, axis=1))


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def obj_from_bm(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return link(bpy.data.objects.new(name, me))


def make_material(name, rgb, rough=0.6, metal=0.0, cull=True):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
    mat.diffuse_color = (*rgb, 1.0)
    mat.use_backface_culling = cull
    return mat


def bake_modifiers(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    me.name = obj.name
    bpy.data.meshes.remove(old)


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def decimate_to(obj, max_tris):
    t = tri_count(obj)
    if t <= max_tris:
        return
    m = obj.modifiers.new("Decimate", "DECIMATE")
    m.ratio = max_tris / t * 0.98
    bake_modifiers(obj)


def verts_np(me):
    a = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def normals_np(me):
    a = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("normal", a)
    return a.reshape(-1, 3)


def ensure_uvs(obj):
    if obj.data.uv_layers:
        return
    obj.data.uv_layers.new(name="UVMap")
    select_only([obj], obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")


def select_only(objs, active):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


# --------------------------------------------------------------------------
# Body (neck down) from a skin-modifier skeleton graph
# --------------------------------------------------------------------------
def build_body():
    bm = bmesh.new()
    skin = bm.verts.layers.skin.verify()
    verts = []

    def V(p, r, root=False):
        v = bm.verts.new(p)
        v[skin].radius = (r, r)
        v[skin].use_root = root
        verts.append(v)
        return v

    def E(a, b):
        bm.edges.new((a, b))

    T1 = V((0, 0, 0.875), 0.128, root=True)
    T2 = V((0, 0, 1.00), 0.098)
    T3 = V((0, 0, 1.12), 0.112)
    T4 = V((0, 0, 1.235), 0.118)
    T5 = V((0, 0, 1.325), 0.098)
    N1 = V((0, 0.005, 1.385), 0.043)
    N2 = V((0, 0.008, 1.455), 0.040)
    for a, b in ((T1, T2), (T2, T3), (T3, T4), (T4, T5), (T5, N1), (N1, N2)):
        E(a, b)
    for s in (1, -1):
        def m(p):
            return (p[0] * s, p[1], p[2])
        L0 = V(m((0.088, 0, 0.80)), 0.078)
        L1 = V(m((0.09, 0, 0.67)), 0.064)
        L2 = V(m((0.09, 0, 0.48)), 0.044)
        L3 = V(m((0.09, 0.008, 0.33)), 0.046)
        L4 = V(m((0.09, 0.01, 0.15)), 0.030)
        L5 = V(m((0.09, 0.01, 0.075)), 0.030)
        L6 = V(m((0.09, -0.085, 0.032)), 0.033)
        L7 = V(m((0.09, -0.150, 0.028)), 0.028)
        LH = V(m((0.09, 0.034, 0.035)), 0.030)
        for a, b in ((T1, L0), (L0, L1), (L1, L2), (L2, L3), (L3, L4), (L4, L5), (L5, L6), (L6, L7), (L5, LH)):
            E(a, b)
        A0 = V(m((0.15, 0, 1.335)), 0.043)
        A1 = V(m((0.28, 0, 1.345)), 0.033)
        A2 = V(m((0.415, 0, 1.345)), 0.028)
        A3 = V(m((0.53, 0, 1.345)), 0.029)
        A4 = V(m((0.655, 0, 1.345)), 0.021)
        H0 = V(m((0.703, 0, 1.343)), 0.030)
        for a, b in ((T5, A0), (A0, A1), (A1, A2), (A2, A3), (A3, A4), (A4, H0)):
            E(a, b)
        prev = H0
        for i, p in enumerate(THUMB):
            r = 0.012 if i < 2 else (0.0105 if i < 4 else 0.0085)
            v = V(m(p), r)
            E(prev, v)
            prev = v
        for f in FINGERS:
            prev = H0
            for i, p in enumerate(finger_points(f)):
                r = [0.0105, 0.0095, 0.0088, 0.0078][i] * (0.88 if f == "Little" else 1.0)
                v = V(m(p), r)
                E(prev, v)
                prev = v

    obj = obj_from_bm("Body", bm)
    sk = obj.modifiers.new("Skin", "SKIN")
    sk.use_smooth_shade = True
    sk.branch_smoothing = 0.6
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    bake_modifiers(obj)

    me = obj.data
    P = verts_np(me)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x)
    # Torso: elliptical cross-section (flatter front-to-back).
    torso = (ax < 0.17) & (z > 0.72) & (z < 1.40)
    w = smoothstep(0.72, 0.82, z) * (1.0 - smoothstep(1.34, 1.40, z)) * torso
    y *= 1.0 - 0.30 * w
    # Thighs slightly oval, calves rounder: leave. Hands: flatten palm / fingers.
    hand = (ax > 0.64) & (z > 1.25)
    zc = 1.343
    palm = smoothstep(0.645, 0.67, ax) * (1.0 - smoothstep(0.735, 0.76, ax))
    k = 1.0 - hand * (0.55 * palm + 0.18 * (ax >= 0.735))
    z[:] = np.where(hand, zc + (z - zc) * k, z)
    # Feet: flat soles.
    foot = z < 0.06
    z[:] = np.where(foot, np.maximum(z, 0.0) * (1.0 - 0.0) , z)
    z[:] = np.where(z < 0.012, z * 0.25, z)
    # Soft feminine curves (kept subtle: she is starving at the start).
    for s in (1, -1):
        bust = gauss(P, (0.055 * s, -0.09, 1.215), (0.04, 0.05, 0.035))
        y -= 0.018 * bust
        seat = gauss(P, (0.06 * s, 0.07, 0.83), (0.05, 0.05, 0.05))
        y += 0.012 * seat
        hip = gauss(P, (0.13 * s, 0.0, 0.85), (0.04, 0.08, 0.06))
        x += 0.008 * hip * s
    # Collarbones / shoulder slope.
    shoulder = gauss(P, (0.0, 0.0, 1.36), (0.12, 0.2, 0.03)) * (ax > 0.05)
    z -= 0.01 * shoulder * smoothstep(0.05, 0.14, ax)
    P[:, 0], P[:, 1], P[:, 2] = x, y, z
    me.vertices.foreach_set("co", P.ravel())
    me.update()
    return obj


# --------------------------------------------------------------------------
# Head (stylised; separate shell overlapping the neck)
# --------------------------------------------------------------------------
def build_head():
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=44, radius=1.0)
    P = np.array([v.co[:] for v in bm.verts])
    ux, uy, uz = P[:, 0].copy(), P[:, 1].copy(), P[:, 2].copy()
    X = HEAD_HALF.x * ux
    Y = HEAD_HALF.y * uy
    Z = HEAD_HALF.z * uz
    t = np.clip((0.15 - uz) / 1.15, 0.0, 1.0)
    X *= 1.0 - 0.52 * t ** 1.4
    back = uy > 0
    Y = np.where(back, Y * (1.0 - 0.55 * t), Y * (1.0 - 0.22 * t ** 2))
    Y = np.where(back & (uz > -0.1), Y * 1.06, Y)
    Y = np.where(~back, Y * (1.0 - 0.13 * np.exp(-(uz / 0.55) ** 2)), Y)
    P = np.stack([X + HEAD_C.x, Y + HEAD_C.y, Z + HEAD_C.z], axis=1)
    front = smoothstep(0.0, 0.04, -(P[:, 1] - HEAD_C.y))
    for s in (1, -1):
        sock = gauss(P, (EYE_X * s, 0, EYE_Z), (0.024, 1, 0.017)) * front
        P[:, 1] += 0.006 * sock
        cheek = gauss(P, (0.045 * s, 0, 1.497), (0.018, 1, 0.016)) * front
        P[:, 1] -= 0.0045 * cheek
        P[:, 0] += 0.002 * cheek * s
        side = smoothstep(0.03, 0.06, P[:, 0] * s)
        ear = gauss(P, (0.0, 0.006, 1.513), (1, 0.012, 0.021)) * side
        P[:, 0] += 0.011 * ear * s
    nose = gauss(P, (0, 0, NOSE_Z), (0.0085, 1, 0.022)) * front
    nose += 0.5 * gauss(P, (0, 0, NOSE_Z + 0.025), (0.006, 1, 0.02)) * front
    P[:, 1] -= 0.011 * nose
    brow = gauss(P, (0, 0, 1.549), (0.05, 1, 0.008)) * front
    P[:, 1] -= 0.0025 * brow
    ulip = gauss(P, (0, 0, MOUTH_Z + 0.0045), (0.015, 1, 0.004)) * front
    llip = gauss(P, (0, 0, MOUTH_Z - 0.005), (0.013, 1, 0.0045)) * front
    P[:, 1] -= 0.0032 * ulip + 0.0038 * llip
    chin = gauss(P, (0, 0, CHIN_Z + 0.015), (0.014, 1, 0.012)) * front
    P[:, 1] -= 0.003 * chin
    for v, p in zip(bm.verts, P):
        v.co = p
    bm.normal_update()

    # Eye openings + eyeball centres.
    eye_centres = []
    fv = [v for v in bm.verts if v.co.y < HEAD_C.y]
    for s in (1, -1):
        target = Vector((EYE_X * s, 0, EYE_Z))
        nearest = min(fv, key=lambda v: (v.co.x - target.x) ** 2 + (v.co.z - target.z) ** 2)
        y_front = nearest.co.y
        eye_centres.append(Vector((EYE_X * s, y_front + EYE_RADIUS - 0.0035, EYE_Z)))
    kill = []
    for f in bm.faces:
        c = f.calc_center_median()
        if c.y > HEAD_C.y - 0.03:
            continue
        for s in (1, -1):
            dx = (c.x - EYE_X * s) / EYE_HOLE_RX
            dz = (c.z - EYE_Z) / EYE_HOLE_RZ
            # almond: slightly lifted outer corner
            dz -= 0.15 * dx * s * 0
            if dx * dx + dz * dz < 1.0:
                kill.append(f)
                break
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    # Tuck the rim back towards the eyeball so the lids wrap it.
    for e in bm.edges:
        if e.is_boundary:
            for v in e.verts:
                v.tag = True
    for v in bm.verts:
        if v.tag:
            # snap the jagged grid rim onto a clean almond/ellipse
            s = 1 if v.co.x > 0 else -1
            ex = EYE_X * s
            a = math.atan2((v.co.z - EYE_Z) / EYE_HOLE_RZ, (v.co.x - ex) / EYE_HOLE_RX)
            v.co.x = ex + EYE_HOLE_RX * math.cos(a)
            v.co.z = EYE_Z + EYE_HOLE_RZ * math.sin(a) + 0.002 * math.cos(a) * s * (math.sin(a) > 0)
            v.co.y += 0.002
            v.tag = False
    obj = obj_from_bm("Head", bm)
    return obj, eye_centres


def head_uv(P):
    """Spherical head projection used for the makeup masks (face centred, u=0.5)."""
    theta = np.arctan2(P[:, 0] - HEAD_C.x, -(P[:, 1] - HEAD_C.y))
    u = 0.5 + 0.5 * np.sin(theta / 2.0)
    v = (P[:, 2] - (CHIN_Z - 0.06)) / (HEAD_TOP - CHIN_Z + 0.07)
    return u, np.clip(v, 0.0, 1.0)


# --------------------------------------------------------------------------
# Eyes
# --------------------------------------------------------------------------
def build_eyes(centres):
    bm = bmesh.new()
    for c in centres:
        M = Matrix.Translation(c) @ Matrix.Rotation(math.radians(90), 4, "X")
        bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=14, radius=EYE_RADIUS, matrix=M)
    bm.normal_update()
    obj = obj_from_bm("Eyes", bm)
    mats = [make_material("eye_sclera", (0.93, 0.91, 0.88), 0.3),
            make_material("eye_iris", (0.42, 0.52, 0.60), 0.15),
            make_material("eye_pupil", (0.02, 0.02, 0.03), 0.1)]
    for m in mats:
        obj.data.materials.append(m)
    for p in obj.data.polygons:
        c = Vector(p.center)
        eye = centres[0] if c.x > 0 else centres[1]
        d = (c - eye).normalized()
        a = math.degrees(math.acos(max(-1, min(1, -d.y))))
        p.material_index = 2 if a < 13 else (1 if a < 36 else 0)
        p.use_smooth = True
    return obj


# --------------------------------------------------------------------------
# Armature + weights
# --------------------------------------------------------------------------
def build_armature(eye_y):
    arm = bpy.data.armatures.new("Armature")
    obj = link(bpy.data.objects.new("Armature", arm))
    arm.display_type = "STICK"
    select_only([obj], obj)
    bpy.ops.object.mode_set(mode="EDIT")
    spec = skeleton_spec(eye_y)
    for name, h, t, parent, deform in spec:
        eb = arm.edit_bones.new(name)
        eb.head = h
        eb.tail = t
        eb.roll = 0.0
        eb.use_deform = deform
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = (Vector(arm.edit_bones[parent].tail) - Vector(h)).length < 1e-5 \
                and not name.endswith("Shoulder") and "Thumb" not in name
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj, spec


def bone_segments(spec, names=None):
    sel = [b for b in spec if b[4] and (names is None or b[0] in names)]
    H = np.array([b[1] for b in sel], float)
    T = np.array([b[2] for b in sel], float)
    return [b[0] for b in sel], H, T


def seg_dist(P, H, T):
    d = T - H
    L2 = np.maximum(np.sum(d * d, axis=1), 1e-12)
    t = np.clip(((P[:, None, :] - H[None]) * d[None]).sum(-1) / L2[None], 0, 1)
    proj = H[None] + t[..., None] * d[None]
    return np.linalg.norm(P[:, None, :] - proj, axis=-1)


def classify_regions(P, spec):
    names, H, T = bone_segments(spec, [b[0] for b in spec if not b[0].startswith("Braid")
                                       and not b[0].endswith("Eye") and b[0] != "Jaw"])
    D = seg_dist(P, H, T)
    side = np.array([1 if n.startswith("Left") else (-1 if n.startswith("Right") else 0) for n in names])
    sx = np.sign(P[:, 0])
    bad = (side[None, :] != 0) & (side[None, :] != sx[:, None]) & (np.abs(P[:, 0])[:, None] > 0.01)
    D = np.where(bad, 1e9, D)
    return [region_of_bone(names[i]) for i in np.argmin(D, axis=1)]


def distance_weights(P, spec, names, k=3, power=4.0, side_lock=True):
    names, H, T = bone_segments(spec, names)
    D = seg_dist(P, H, T)
    if side_lock:
        side = np.array([1 if n.startswith("Left") else (-1 if n.startswith("Right") else 0) for n in names])
        sx = np.sign(P[:, 0])
        bad = (side[None, :] != 0) & (side[None, :] != sx[:, None]) & (np.abs(P[:, 0])[:, None] > 0.015)
        D = np.where(bad, 1e9, D)
    W = 1.0 / (D ** power + 1e-12)
    idx = np.argsort(-W, axis=1)[:, :k]
    out = []
    for i in range(len(P)):
        ws = W[i, idx[i]]
        ws = ws / ws.sum()
        out.append([(names[j], float(w)) for j, w in zip(idx[i], ws) if w > 0.01])
    return out


def apply_weights(obj, weights):
    for vi, lst in enumerate(weights):
        for name, w in lst:
            g = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
            g.add([vi], w, "REPLACE")


def skin_to_armature(obj, arm_obj):
    obj.parent = arm_obj
    m = obj.modifiers.new("Armature", "ARMATURE")
    m.object = arm_obj


def weights_of(obj):
    gi = {g.index: g.name for g in obj.vertex_groups}
    return [[(gi[g.group], g.weight) for g in v.groups if g.weight > 0.0] for v in obj.data.vertices]


def transfer_weights(src_obj, src_P, dst_P, k=4):
    kd = kdtree.KDTree(len(src_P))
    for i, p in enumerate(src_P):
        kd.insert(p, i)
    kd.balance()
    sw = weights_of(src_obj)
    out, nn = [], []
    for p in dst_P:
        hits = kd.find_n(p, k)
        acc = {}
        tot = 0.0
        for co, i, d in hits:
            f = 1.0 / (d + 1e-4)
            tot += f
            for n, w in sw[i]:
                acc[n] = acc.get(n, 0.0) + w * f
        s = sum(acc.values()) or 1.0
        out.append([(n, w / s) for n, w in acc.items() if w / s > 0.01])
        nn.append([(i, 1.0 / (d + 1e-4) / tot) for co, i, d in hits])
    return out, nn


# --------------------------------------------------------------------------
# Shape keys
# --------------------------------------------------------------------------
def jaw_delta(P, amount):
    w = smoothstep(MOUTH_Z + 0.001, MOUTH_Z - 0.018, P[:, 2])
    w *= smoothstep(HEAD_C.y + 0.045, HEAD_C.y - 0.01, P[:, 1])
    w *= P[:, 2] > CHIN_Z - 0.04
    a = math.radians(15.0) * amount
    piv = np.array([0.0, -0.002, 1.488])
    d = P - piv
    y2 = d[:, 1] * math.cos(a) - d[:, 2] * math.sin(a)
    z2 = d[:, 1] * math.sin(a) + d[:, 2] * math.cos(a)
    out = np.zeros_like(P)
    out[:, 1] = (y2 - d[:, 1]) * w
    out[:, 2] = (z2 - d[:, 2]) * w
    return out


def pucker_delta(P, amount, front):
    w = gauss(P, (0, 0, MOUTH_Z), (0.022, 1, 0.012)) * front
    out = np.zeros_like(P)
    out[:, 1] = -0.008 * w * amount
    out[:, 0] = -0.45 * P[:, 0] * w * amount
    return out


def corners_delta(P, front, dx, dy, dz):
    out = np.zeros_like(P)
    for s in (1, -1):
        w = gauss(P, (MOUTH_HALF_W * s, 0, MOUTH_Z), (0.011, 1, 0.009)) * front
        out[:, 0] += dx * s * w
        out[:, 1] += dy * w
        out[:, 2] += dz * w
    return out


def lid_delta(P, front, side, upper=1.0, lower=0.0):
    out = np.zeros_like(P)
    ex = EYE_X * side
    across = np.exp(-((P[:, 0] - ex) / 0.021) ** 4) * front
    up = (P[:, 2] >= EYE_Z - 0.002) * np.exp(-np.maximum(0, P[:, 2] - (EYE_Z + EYE_HOLE_RZ + 0.002)) ** 2 / 0.009 ** 2)
    up *= np.exp(-np.maximum(0, np.abs(P[:, 0] - ex) - 0.0) * 0)
    lo = (P[:, 2] < EYE_Z - 0.002) * np.exp(-np.maximum(0, (EYE_Z - EYE_HOLE_RZ - 0.002) - P[:, 2]) ** 2 / 0.006 ** 2)
    close_z = EYE_Z - 0.0065
    wu = across * up * upper
    wl = across * lo * lower
    # Upper lid slides down over the eyeball and bulges forward to clear it.
    out[:, 2] += (close_z - P[:, 2]) * wu * smoothstep(EYE_Z + 0.03, EYE_Z + 0.008, P[:, 2])
    out[:, 1] += -0.0045 * wu * smoothstep(EYE_Z + 0.03, EYE_Z + 0.008, P[:, 2])
    out[:, 2] += (close_z - P[:, 2]) * wl * 0.5
    out[:, 1] += -0.002 * wl
    return out


def add_body_shape_keys(obj, head_slice, region_of_vert):
    me = obj.data
    P = verts_np(me)
    N = normals_np(me)
    obj.shape_key_add(name="Basis", from_mix=False)

    def key(name, delta):
        sk = obj.shape_key_add(name=name, from_mix=False)
        sk.data.foreach_set("co", (P + delta).ravel())
        sk.value = 0.0  # Blender 5 defaults new keys to 1.0
        sk.slider_min, sk.slider_max = 0.0, 1.0
        return sk

    # nourished: starving base -> healthy.  Per-region inflation along normals.
    amt = {"torso": 0.011, "arms": 0.006, "legs": 0.010, "feet": 0.0015, "hands": 0.0015, "head": 0.0}
    a = np.array([amt[r] for r in region_of_vert])
    a += 0.010 * sum(gauss(P, (0.07 * s, 0.05, 0.80), (0.07, 0.08, 0.10)) for s in (1, -1))  # hips / seat
    a += 0.006 * sum(gauss(P, (0.055 * s, -0.09, 1.215), (0.04, 0.04, 0.035)) for s in (1, -1))  # bust
    a -= 0.006 * gauss(P, (0, -0.06, 1.25), (0.03, 0.05, 0.08)) * 0  # keep sternum
    hs, he = head_slice
    head_mask = np.zeros(len(P), bool)
    head_mask[hs:he] = True
    front = smoothstep(0.0, 0.04, -(P[:, 1] - HEAD_C.y)) * head_mask
    cheeks = sum(gauss(P, (0.045 * s, -0.06, 1.475), (0.025, 0.04, 0.03)) for s in (1, -1)) * head_mask
    a = np.where(head_mask, 0.004 * cheeks, a)
    neck = head_mask & (np.arange(len(P)) < 0)
    key("nourished", N * a[:, None])

    def fkey(name, d):
        d = d * head_mask[:, None]
        key(name, d)

    fkey("blink_L", lid_delta(P, front, 1, 1.0, 1.0))
    fkey("blink_R", lid_delta(P, front, -1, 1.0, 1.0))
    fkey("jaw_open", jaw_delta(P, 1.0))
    sm = corners_delta(P, front, 0.004, 0.003, 0.0065)
    for s in (1, -1):
        c = gauss(P, (0.04 * s, 0, 1.495), (0.016, 1, 0.014)) * front
        sm[:, 2] += 0.003 * c
        sm[:, 1] -= 0.0015 * c
    fkey("smile", sm)
    fkey("frown", corners_delta(P, front, -0.001, 0.001, -0.005))
    bu, bd, sq, cp = (np.zeros_like(P) for _ in range(4))
    for s in (1, -1):
        b = gauss(P, (0.035 * s, 0, 1.552), (0.03, 1, 0.013)) * front
        bu[:, 2] += 0.006 * b
        bd[:, 2] -= 0.004 * b
        bd[:, 0] -= 0.002 * s * b
        bd[:, 1] -= 0.0015 * b
        lo = gauss(P, (EYE_X * s, 0, EYE_Z - EYE_HOLE_RZ - 0.003), (0.02, 1, 0.007)) * front
        sq[:, 2] += 0.0035 * lo
        sq += 0.35 * lid_delta(P, front, s, 1.0, 0.0)
        ch = gauss(P, (0.042 * s, 0, 1.495), (0.016, 1, 0.012)) * front
        sq[:, 2] += 0.002 * ch
        puff = gauss(P, (0.042 * s, -0.04, 1.468), (0.017, 0.05, 0.018)) * head_mask
        cp += N * (0.008 * puff)[:, None]
    fkey("brow_up", bu)
    fkey("brow_down", bd)
    fkey("squint", sq)
    fkey("cheek_puff", cp)
    fkey("lips_pucker", pucker_delta(P, 1.0, front))
    fkey("vis_AA", jaw_delta(P, 0.75) + corners_delta(P, front, 0.002, 0.0, 0.0))
    fkey("vis_E", jaw_delta(P, 0.25) + corners_delta(P, front, 0.005, 0.002, 0.001))
    fkey("vis_O", jaw_delta(P, 0.45) + pucker_delta(P, 0.6, front))
    fkey("vis_U", jaw_delta(P, 0.12) + pucker_delta(P, 1.0, front))
    mbp = np.zeros_like(P)
    lip = gauss(P, (0, 0, MOUTH_Z), (0.02, 1, 0.009)) * front
    mbp[:, 1] += 0.002 * lip
    mbp[:, 2] += np.where(P[:, 2] > MOUTH_Z, -0.0018, 0.0018) * lip
    fkey("vis_MBP", mbp)
    fv = jaw_delta(P, 0.08)
    ll = gauss(P, (0, 0, MOUTH_Z - 0.006), (0.016, 1, 0.005)) * front
    fv[:, 2] += 0.0028 * ll
    fv[:, 1] += 0.0035 * ll
    fkey("vis_FV", fv)


# --------------------------------------------------------------------------
# Hair: cap + braid
# --------------------------------------------------------------------------
def hairline(theta):
    a = np.abs(theta) / math.pi  # 0 front .. 1 back
    return np.interp(a, [0.0, 0.18, 0.40, 0.55, 1.0], [1.578, 1.570, 1.540, 1.505, 1.462])


def catmull(points, n):
    pts = [Vector(p) for p in points]
    pts = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    dense = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1:i + 3]
        for j in range(40):
            t = j / 40.0
            dense.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                                + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    dense.append(pts[-2])
    L = [0.0]
    for a, b in zip(dense, dense[1:]):
        L.append(L[-1] + (b - a).length)
    out = []
    for k in range(n):
        s = L[-1] * k / (n - 1)
        i = min(range(len(L)), key=lambda q: abs(L[q] - s))
        out.append((dense[i], (dense[min(i + 1, len(dense) - 1)] - dense[max(i - 1, 0)]).normalized(), s / L[-1]))
    return out


def build_hair(head_obj):
    # Cap: head faces above the hairline, pushed out for volume.
    bm = bmesh.new()
    bm.from_mesh(head_obj.data)
    bm.normal_update()
    kill = []
    for f in bm.faces:
        ok = True
        for v in f.verts:
            th = math.atan2(v.co.x - HEAD_C.x, -(v.co.y - HEAD_C.y))
            if v.co.z < hairline(np.array([th]))[0]:
                ok = False
                break
        if not ok:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.normal_update()
    # Smooth the stair-stepped hairline: snap border verts onto the hairline curve.
    border = {v for e in bm.edges if e.is_boundary for v in e.verts}
    for v in border:
        th = math.atan2(v.co.x - HEAD_C.x, -(v.co.y - HEAD_C.y))
        v.co.z = min(v.co.z, hairline(np.array([th]))[0] + 0.002)
    for v in bm.verts:
        th = math.atan2(v.co.x - HEAD_C.x, -(v.co.y - HEAD_C.y))
        h = hairline(np.array([th]))[0]
        off = 0.0015 + 0.010 * min(1.0, max(0.0, (v.co.z - h) / 0.05))
        v.co += v.normal * off
    cap_count = len(bm.faces)
    # Braid: interlocking lobes along the path.
    n = 22
    samples = catmull(BRAID_PATH, n)
    for i, (p, t, s) in enumerate(samples[:-1]):
        out = Vector((p.x, p.y, 0)).normalized() if s < 0.25 else Vector((0.25, -1, 0)).normalized()
        nrm = (out - t * out.dot(t)).normalized()
        bi = t.cross(nrm).normalized()
        side = 1 if i % 2 == 0 else -1
        ang = math.radians(28) * side
        axis = (t * math.cos(ang) + bi * math.sin(ang)).normalized()
        sb = axis.cross(nrm).normalized()
        scale = 1.0 - 0.45 * s
        R = Matrix((sb, nrm, axis)).transposed().to_4x4()
        S = Matrix.Diagonal((0.0105 * scale, 0.0085 * scale, 0.017 * scale, 1.0))
        c = p + bi * (0.0045 * side * scale)
        bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=7, radius=1.0,
                                  matrix=Matrix.Translation(c) @ R @ S)
    # Tie + tail tuft.
    p, t, s = samples[-2]
    for e in bm.edges:
        e.tag = False
    tie_start = len(bm.faces)
    zaxis = Vector((0, 0, 1))
    rot = zaxis.rotation_difference(t).to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.0075, radius2=0.0075, depth=0.010,
                          matrix=Matrix.Translation(p + t * 0.006) @ rot)
    tie_end = len(bm.faces)
    pe = Vector(BRAID_PATH[-1])
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.008, radius2=0.0015, depth=0.05,
                          matrix=Matrix.Translation(pe + t * 0.022) @ rot)
    bm.faces.ensure_lookup_table()
    tie_faces = set(range(tie_start, tie_end))
    obj = obj_from_bm("Hair_Braid", bm)
    obj.data.materials.append(make_material("hair", (0.36, 0.24, 0.12), 0.32))
    obj.data.materials.append(make_material("hair_tie", (0.22, 0.15, 0.10), 0.7))
    for poly in obj.data.polygons:
        poly.use_smooth = True
        poly.material_index = 1 if poly.index in tie_faces else 0
    return obj, cap_count


def braid_weights(obj, spec):
    P = verts_np(obj.data)
    names = ["Head", "Braid_1", "Braid_2", "Braid_3", "Braid_4"]
    pts = [Vector(p) for p in BRAID_PATH]
    out = []
    kd_dense = catmull(BRAID_PATH, 200)
    seg_len = [(pts[i + 1] - pts[i]).length for i in range(4)]
    cum = np.cumsum([0] + seg_len) / sum(seg_len)
    for p in P:
        pv = Vector(p)
        th = math.atan2(pv.x - HEAD_C.x, -(pv.y - HEAD_C.y))
        d_head = (pv - HEAD_C).length
        best = min(kd_dense, key=lambda q: (q[0] - pv).length)
        if (best[0] - pv).length > 0.03 or best[2] < 0.02:
            out.append([("Head", 1.0)])
            continue
        s = best[2]
        f = np.interp(s, cum, [0, 1, 2, 3, 4])  # 0 at Braid_1 head .. 4 at end
        i = int(min(3, math.floor(f)))
        frac = f - i
        ws = {}
        # blend smoothly across joints
        ws[names[i + 1]] = 1.0 - max(0.0, frac - 0.6) / 0.4 * 0.5
        if frac > 0.6 and i < 3:
            ws[names[i + 2]] = max(0.0, frac - 0.6) / 0.4 * 0.5
        if f < 0.35:
            ws["Head"] = (0.35 - f) / 0.35 * 0.8
        tot = sum(ws.values())
        out.append([(n, w / tot) for n, w in ws.items()])
    return out


# --------------------------------------------------------------------------
# Wardrobe
# --------------------------------------------------------------------------
def shell_from_body(name, body, base_P, face_ok, offset_fn, max_tris, mat, extra=None):
    """Garment shell: copy body faces, subdivide (smooth), then push out along normals."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    # body has shape keys: make sure we use the basis coordinates
    for v, p in zip(bm.verts, base_P):
        v.co = p
    bm.faces.ensure_lookup_table()
    kill = [f for f in bm.faces if not face_ok(f)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    for layer in list(bm.verts.layers.shape):
        bm.verts.layers.shape.remove(layer)
    obj = obj_from_bm(name, bm)
    obj.vertex_groups.clear()
    for p in obj.data.polygons:
        p.material_index = 0
    if tri_count(obj) * 4 <= max_tris:
        sub = obj.modifiers.new("Subsurf", "SUBSURF")
        sub.levels = 1
        sub.boundary_smooth = "PRESERVE_CORNERS"
        bake_modifiers(obj)
    me = obj.data
    me.update()
    # Snap onto the body surface + offset (subdividing the shell shrinks it into the body).
    bvh = BVHTree.FromPolygons([tuple(p) for p in base_P], [tuple(p.vertices) for p in body.data.polygons])
    P = verts_np(me)
    out = []
    for p in P:
        loc, nrm, _, _ = bvh.find_nearest(Vector(p))
        out.append(loc + nrm * offset_fn(Vector(p)))
    me.vertices.foreach_set("co", np.array(out).ravel())
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(me)
    bm.free()
    if extra is not None:
        bm = bmesh.new()
        bm.from_mesh(me)
        extra(bm)
        bm.to_mesh(me)
        bm.free()
    me.materials.clear()
    for m in mat if isinstance(mat, list) else [mat]:
        me.materials.append(m)
    decimate_to(obj, max_tris)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def tunic_skirt_and_belt(bm):
    """Tunic hem down to mid-thigh (one tube around both legs) and a leather belt."""
    first = len(bm.faces)
    rings, cols = 8, 40
    grid = []
    for r in range(rings):
        t = r / (rings - 1)
        z = 0.90 - t * 0.24
        rx = 0.150 + 0.045 * t
        ry = 0.112 + 0.022 * t
        row = []
        for c in range(cols):
            a = 2 * math.pi * c / cols
            fold = 1.0 + 0.03 * t * math.sin(a * 7)
            row.append(bm.verts.new((rx * fold * math.sin(a), -ry * fold * math.cos(a) + 0.008, z)))
        grid.append(row)
    for r in range(rings - 1):
        for c in range(cols):
            c2 = (c + 1) % cols
            bm.faces.new((grid[r][c], grid[r + 1][c], grid[r + 1][c2], grid[r][c2]))
    belt_first = len(bm.faces)
    bmesh.ops.create_cone(bm, cap_ends=False, segments=40, radius1=1.0, radius2=1.0, depth=0.035,
                          matrix=Matrix.Translation((0, 0.006, 0.935)) @ Matrix.Diagonal((0.128, 0.097, 1.0, 1.0)))
    bm.faces.ensure_lookup_table()
    for f in bm.faces[belt_first:]:
        f.material_index = 1
    for f in bm.faces[first:belt_first]:
        f.material_index = 0
    bm.normal_update()
    # cone normals may point inwards depending on winding: make all outward from the body axis
    for f in bm.faces[first:]:
        c = f.calc_center_median()
        if f.normal.dot(Vector((c.x, c.y - 0.008, 0))) < 0:
            f.normal_flip()


def build_cloak():
    bm = bmesh.new()
    rings, cols = 26, 44
    gap = math.radians(52)  # front opening half-angle
    grid = []
    for r in range(rings):
        t = r / (rings - 1)
        z = 1.415 - t * (1.415 - 0.42)
        # radius profile: neck -> over shoulders -> drape
        rx = np.interp(t, [0, 0.05, 0.10, 0.2, 1.0], [0.085, 0.16, 0.215, 0.235, 0.30])
        ry = np.interp(t, [0, 0.05, 0.10, 0.2, 1.0], [0.075, 0.11, 0.135, 0.15, 0.24])
        row = []
        for c in range(cols):
            a = gap + (2 * math.pi - 2 * gap) * c / (cols - 1)  # angle from front (-Y)
            x = rx * math.sin(a)
            y = -ry * math.cos(a) + 0.01
            # gentle folds
            fold = 0.008 * t * math.sin(a * 9.0)
            row.append(bm.verts.new((x * (1 + fold * 3), y + fold, z)))
        grid.append(row)
    for r in range(rings - 1):
        for c in range(cols - 1):
            bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
    cloak_faces = len(bm.faces)
    # Hood, down: a soft folded roll behind the neck.
    hr, hc = 10, 22
    hg = []
    for i in range(hr):
        u = i / (hr - 1) * 2 * math.pi
        row = []
        for j in range(hc):
            a = math.radians(60) + math.radians(240) * j / (hc - 1)
            pinch = math.sin(math.pi * j / (hc - 1)) ** 0.6
            R = 0.13 + 0.025 * pinch * math.cos(u)
            x = R * math.sin(a) * 0.95
            y = -R * math.cos(a) * 0.8 + 0.02
            z = 1.425 + 0.028 * pinch * math.sin(u) - 0.02 * math.cos(a) ** 2
            row.append(bm.verts.new((x, y + 0.01 * pinch * math.cos(u), z)))
        hg.append(row)
    for i in range(hr):
        for j in range(hc - 1):
            i2 = (i + 1) % hr
            bm.faces.new((hg[i][j], hg[i][j + 1], hg[i2][j + 1], hg[i2][j]))
    bm.normal_update()
    obj = obj_from_bm("hunter_cloak", bm)
    obj.data.materials.append(make_material("cloak_wool", (0.24, 0.22, 0.20), 0.9, cull=False))
    obj.data.materials.append(make_material("cloak_hood", (0.21, 0.19, 0.17), 0.9, cull=False))
    for p in obj.data.polygons:
        p.use_smooth = True
        p.material_index = 0 if p.index < cloak_faces else 1
    return obj


# --------------------------------------------------------------------------
# Makeup masks
# --------------------------------------------------------------------------
def write_png(path, rgba_float):
    h, w, _ = rgba_float.shape
    data = (np.clip(rgba_float, 0, 1) * 255 + 0.5).astype(np.uint8)
    data = data[::-1]  # Blender v=0 is the bottom row; PNG row 0 is the top
    raw = b"".join(b"\x00" + data[r].tobytes() for r in range(h))

    def chunk(tag, payload):
        c = struct.pack(">I", len(payload)) + tag + payload
        return c + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def raster_head_attributes(P, tris, uv, size):
    """Rasterise head triangles in UV space; returns per-pixel X, Z and frontness."""
    X = np.zeros((size, size))
    Z = np.zeros((size, size))
    F = np.zeros((size, size))
    cov = np.zeros((size, size), bool)
    U = uv[:, 0] * (size - 1)
    Vv = uv[:, 1] * (size - 1)
    for a, b, c in tris:
        xs = np.array([U[a], U[b], U[c]])
        ys = np.array([Vv[a], Vv[b], Vv[c]])
        if xs.max() - xs.min() > size * 0.5:
            continue  # seam triangle at the back of the head: irrelevant for makeup
        x0, x1 = int(max(0, math.floor(xs.min()))), int(min(size - 1, math.ceil(xs.max())))
        y0, y1 = int(max(0, math.floor(ys.min()))), int(min(size - 1, math.ceil(ys.max())))
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        den = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(den) < 1e-9:
            continue
        l1 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / den
        l2 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / den
        l3 = 1 - l1 - l2
        ins = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
        if not ins.any():
            continue
        px = l1 * P[a, 0] + l2 * P[b, 0] + l3 * P[c, 0]
        pz = l1 * P[a, 2] + l2 * P[b, 2] + l3 * P[c, 2]
        py = l1 * P[a, 1] + l2 * P[b, 1] + l3 * P[c, 1]
        sl = (slice(y0, y1 + 1), slice(x0, x1 + 1))
        X[sl] = np.where(ins, px, X[sl])
        Z[sl] = np.where(ins, pz, Z[sl])
        F[sl] = np.where(ins, (py < HEAD_C.y - 0.02).astype(float), F[sl])
        cov[sl] |= ins
    return X, Z, F, cov


def bake_makeup_masks(P, tris, uv, size=1024):
    X, Z, F, cov = raster_head_attributes(P, tris, uv, size)
    F = F * cov
    ax = np.abs(X)

    def ell(cx, cz, rx, rz, soft=0.35):
        d = np.sqrt(((ax - cx) / rx) ** 2 + ((Z - cz) / rz) ** 2)
        return (1.0 - smoothstep(1.0 - soft, 1.0, d)) * F

    # lips: two lobes (upper / lower lip) shaped like a cupid's bow
    upper = ell(0.0, MOUTH_Z + 0.0035, MOUTH_HALF_W * 0.95, 0.0048, 0.4)
    lower = ell(0.0, MOUTH_Z - 0.0042, MOUTH_HALF_W * 0.85, 0.0058, 0.45)
    bow = 1.0 - 0.5 * np.exp(-(X / 0.003) ** 2) * (Z > MOUTH_Z + 0.006)
    lips = np.maximum(upper * bow, lower)
    # eyeshadow: lid area above each eye, fading towards the brow
    shadow = ell(EYE_X + 0.002, EYE_Z + 0.007, 0.026, 0.017, 0.6) * smoothstep(EYE_Z - 0.004, EYE_Z + 0.002, Z)
    # liner: thin band hugging the upper rim, with a small wing at the outer corner
    rim = np.sqrt(((ax - EYE_X) / (EYE_HOLE_RX + 0.0015)) ** 2 + ((Z - EYE_Z) / (EYE_HOLE_RZ + 0.0015)) ** 2)
    liner = np.exp(-((rim - 1.04) / 0.07) ** 2) * (Z > EYE_Z - 0.002) * F
    wing_t = np.clip((ax - (EYE_X + EYE_HOLE_RX * 0.8)) / 0.009, 0, 1)
    wing_z = EYE_Z + 0.002 + wing_t * 0.004
    wing = np.exp(-((Z - wing_z) / (0.0016 * (1.2 - wing_t))) ** 2) * (wing_t > 0) * (wing_t < 1) * F
    liner = np.maximum(liner, wing)
    blush = ell(0.044, 1.493, 0.017, 0.012, 0.9)
    # brows: tapered arc
    bt = np.clip((ax - 0.014) / 0.044, 0, 1)
    brow_z = EYE_Z + 0.021 + 0.006 * np.sin(bt * math.pi * 0.85) - 0.002 * bt
    brow_th = 0.0034 * (1.0 - 0.6 * bt)
    brows = np.exp(-((Z - brow_z) / brow_th) ** 4) * (ax > 0.012) * (ax < 0.06) * F
    brows *= 1.0 - smoothstep(0.85, 1.0, bt)
    # face paint (festival / Calanmai): sweeping line along the cheekbone + dots + forehead mark
    fp_t = np.clip((ax - 0.022) / 0.04, 0, 1)
    fp_z = EYE_Z - 0.02 + fp_t * 0.03
    paint = np.exp(-((Z - fp_z) / 0.0018) ** 2) * (ax > 0.022) * (ax < 0.062) * F
    for dx in (0.03, 0.038, 0.046):
        paint = np.maximum(paint, np.exp(-(((ax - dx) / 0.0022) ** 2 + ((Z - (EYE_Z - 0.028 + (dx - 0.03) * 0.5)) / 0.0022) ** 2)) * F)
    paint = np.maximum(paint, np.exp(-((X / 0.003) ** 2 + ((Z - 1.578) / 0.006) ** 2)) * F)

    a = np.stack([lips, shadow, liner, blush], axis=-1)
    b = np.stack([brows, paint, np.zeros_like(X), np.ones_like(X)], axis=-1)
    write_png(os.path.join(MODEL_DIR, "makeup_mask_a.png"), a)
    write_png(os.path.join(MODEL_DIR, "makeup_mask_b.png"), b)
    return {k: float(v.max()) for k, v in dict(lips=lips, shadow=shadow, liner=liner, blush=blush,
                                                 brows=brows, paint=paint).items()}


# --------------------------------------------------------------------------
# Export
# --------------------------------------------------------------------------
def export_glb(path, objs, arm):
    select_only([arm] + objs, arm)
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
              export_animations=False, export_skins=True, export_morph=True, export_yup=True,
              export_materials="EXPORT", export_extras=False)
    try:
        bpy.ops.export_scene.gltf(**kw, export_morph_normal=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)


def pose_check(arm, objs):
    """Pose a few bones and measure displacement (sanity: no exploding verts)."""
    dg = bpy.context.evaluated_depsgraph_get()

    def snapshot():
        bpy.context.view_layer.update()
        dg2 = bpy.context.evaluated_depsgraph_get()
        res = {}
        for o in objs:
            ev = o.evaluated_get(dg2)
            m = ev.to_mesh()
            a = np.empty(len(m.vertices) * 3)
            m.vertices.foreach_get("co", a)
            res[o.name] = a.reshape(-1, 3).copy()
            ev.to_mesh_clear()
        return res

    rest = snapshot()
    tests = [("LeftUpperArm", (0, 0, -60)), ("RightLowerArm", (0, 0, 70)), ("LeftUpperLeg", (-60, 0, 0)),
             ("RightLowerLeg", (80, 0, 0)), ("Spine", (20, 0, 0)), ("Head", (0, 0, 35)), ("Jaw", (15, 0, 0)),
             ("LeftIndexProximal", (0, 0, -60)), ("Braid_2", (30, 0, 0))]
    report = []
    for bone, rot in tests:
        pb = arm.pose.bones[bone]
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = [math.radians(a) for a in rot]
        posed = snapshot()
        line = ["%s %s" % (bone, rot)]
        piv = np.array(pb.bone.head_local)
        ang = math.radians(max(abs(a) for a in rot))
        for o in objs:
            d = np.linalg.norm(posed[o.name] - rest[o.name], axis=1)
            ok = np.isfinite(d).all()
            # a rigid rotation about the bone head can move a vertex at most 2 r sin(a/2)
            bound = 2.0 * np.linalg.norm(rest[o.name] - piv, axis=1) * math.sin(ang / 2.0) + 1e-4
            over = int((d > bound * 1.05).sum())
            line.append("%s max=%.3fm over-bound:%d%s" % (o.name, d.max(), over, "" if ok else " NaN!"))
        # verts on the opposite side should not move for one-sided bones
        if bone.startswith(("Left", "Right")):
            s = 1 if bone.startswith("Left") else -1
            P0 = rest["Body"]
            opp = (P0[:, 0] * s < -0.08)
            d = np.linalg.norm(posed["Body"] - P0, axis=1)
            line.append("opposite-side max=%.4fm" % d[opp].max())
        report.append("  " + " | ".join(line))
        pb.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    return report


# --------------------------------------------------------------------------
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(MODEL_DIR, exist_ok=True)
    os.makedirs(WARDROBE_DIR, exist_ok=True)

    body = build_body()
    nb = len(body.data.vertices)
    head, eye_centres = build_head()
    nh = len(head.data.vertices)
    head_tris_src = head.data.copy()
    # Join head into body (one mesh, two shells).
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.from_mesh(head.data)
    bm.to_mesh(body.data)
    bm.free()
    head_mesh_for_hair = head
    head_slice = (nb, nb + nh)

    eyes = build_eyes(eye_centres)
    arm, spec = build_armature(eye_centres[0].y)

    # Material slots by region.
    me = body.data
    mats = {r: make_material(r, SKIN_RGB, 0.55) for r in REGIONS}
    for r in REGIONS:
        me.materials.append(mats[r])
    P = verts_np(me)
    vreg = classify_regions(P, spec)
    for i in range(nb, nb + nh):
        vreg[i] = "head"
    for i in range(nb):
        if P[i, 2] > 1.37 and abs(P[i, 0]) < 0.07:
            vreg[i] = "head"  # neck
    for p in me.polygons:
        regs = [vreg[v] for v in p.vertices]
        r = max(set(regs), key=regs.count)
        p.material_index = REGIONS.index(r)
        p.use_smooth = True

    # UVs: smart project the body, spherical projection on the head shell (makeup masks).
    select_only([body], body)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")
    uvl = me.uv_layers.active
    u, v = head_uv(P)
    for poly in me.polygons:
        if poly.vertices[0] < nb:
            continue
        lu = [u[me.loops[li].vertex_index] for li in poly.loop_indices]
        wrap = max(lu) - min(lu) > 0.5
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            uu = u[vi]
            if wrap and uu < 0.5:
                uu = 1.0 + uu  # back seam
            uvl.data[li].uv = (uu, v[vi])
    # Head-only UVs for mask rasterisation.
    hP = P[nb:nb + nh]
    hm = head_tris_src
    hm.calc_loop_triangles()
    tris = [tuple(t.vertices) for t in hm.loop_triangles]
    hu, hv = head_uv(hP)
    mask_stats = bake_makeup_masks(hP, tris, np.stack([hu, hv], axis=1))

    # Weights: bone heat on the body (eyes / braid / root excluded), then fill gaps.
    no_heat = {"Root", "LeftEye", "RightEye"} | {"Braid_%d" % i for i in range(1, 5)}
    for b in arm.data.bones:
        if b.name in no_heat:
            b.use_deform = False
    select_only([body, arm], arm)
    heat_ok = True
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except Exception as e:  # pragma: no cover
        print("ARMATURE_AUTO failed:", e)
        heat_ok = False
    for b in arm.data.bones:
        if b.name != "Root":
            b.use_deform = True
    deform_names = [b[0] for b in spec if b[4] and b[0] not in no_heat]
    W = weights_of(body)
    empty = [i for i, w in enumerate(W) if sum(x[1] for x in w) < 1e-4]
    if empty or not heat_ok:
        fill = distance_weights(P[empty] if heat_ok else P, spec, deform_names)
        if heat_ok:
            for i, w in zip(empty, fill):
                for n, ww in w:
                    g = body.vertex_groups.get(n) or body.vertex_groups.new(name=n)
                    g.add([i], ww, "REPLACE")
        else:
            apply_weights(body, fill)
            skin_to_armature(body, arm)
    # Head shell: keep it rigid on Head/Neck/Jaw (heat can leak shoulders into the jaw line).
    hw = distance_weights(hP, spec, ["Head", "Neck", "Jaw"], k=2, power=6.0, side_lock=False)
    for g in list(body.vertex_groups):
        g.remove(list(range(nb, nb + nh)))
    for j, lst in enumerate(hw):
        vi = nb + j
        z = hP[j, 2]
        jaw_w = float(jaw_delta(hP[j:j + 1], 1.0)[0, 2] != 0) * float(smoothstep(MOUTH_Z, MOUTH_Z - 0.02, z))
        neck_w = float(smoothstep(1.46, 1.415, z)) * float(hP[j, 1] > HEAD_C.y - 0.02)
        head_w = max(0.0, 1.0 - jaw_w - neck_w)
        for n, w in (("Head", head_w), ("Jaw", jaw_w), ("Neck", neck_w)):
            if w > 0.001:
                g = body.vertex_groups.get(n) or body.vertex_groups.new(name=n)
                g.add([vi], w, "REPLACE")
    print("heat weighting:", "ok" if heat_ok else "FAILED (distance fallback)", "| zero-weight verts filled:", len(empty))

    # Eyes rigid on their eye bones.
    for i, vtx in enumerate(eyes.data.vertices):
        n = "LeftEye" if vtx.co.x > 0 else "RightEye"
        g = eyes.vertex_groups.get(n) or eyes.vertex_groups.new(name=n)
        g.add([i], 1.0, "REPLACE")
    skin_to_armature(eyes, arm)

    # LOD1: decimated copy of the base mesh, weights copied from the body.
    lod = link(bpy.data.objects.new("Body_LOD1", body.data.copy()))
    lod.data.name = "Body_LOD1"
    lod.vertex_groups.clear()
    dm = lod.modifiers.new("Decimate", "DECIMATE")
    dm.ratio = 0.5
    bake_modifiers(lod)
    lP = verts_np(lod.data)
    lw, _ = transfer_weights(body, P, lP)
    apply_weights(lod, lw)
    skin_to_armature(lod, arm)

    # Shape keys on the full-res body.
    add_body_shape_keys(body, head_slice, vreg)

    # Hair.
    hair, cap_faces = build_hair(head_mesh_for_hair)
    decimate_to(hair, 3990)
    apply_weights(hair, braid_weights(hair, spec))
    skin_to_armature(hair, arm)
    bpy.data.objects.remove(head_mesh_for_hair)

    # Wardrobe.
    nourished = np.array([0.0])
    kb = body.data.shape_keys.key_blocks
    nour = np.empty(nb * 3 + nh * 3)
    kb["nourished"].data.foreach_get("co", nour)
    nour = nour.reshape(-1, 3) - P

    def face_region(f):
        return REGIONS[f.material_index]

    def centre(f):
        return f.calc_center_median()

    tunic = shell_from_body(
        "hunter_tunic", body, P,
        lambda f: f.verts[0].index < nb and (
            (face_region(f) == "torso" and centre(f).z > 0.86)
            or (face_region(f) == "arms" and abs(centre(f).x) < 0.625)
            or (face_region(f) == "head" and centre(f).z < 1.385)),
        lambda co: 0.006 + 0.006 * (abs(co.x) < 0.17),
        3990, [make_material("tunic_linen", (0.36, 0.40, 0.44), 0.85),
               make_material("belt_leather", (0.20, 0.13, 0.08), 0.6)],
        extra=tunic_skirt_and_belt)
    trousers = shell_from_body(
        "hunter_trousers", body, P,
        lambda f: f.verts[0].index < nb and (
            (face_region(f) == "legs" and centre(f).z > 0.11)
            or (face_region(f) == "torso" and centre(f).z < 0.975)),
        lambda co: 0.0045,
        3990, make_material("trousers_wool", (0.30, 0.26, 0.21), 0.9))
    boots = shell_from_body(
        "hunter_boots", body, P,
        lambda f: f.verts[0].index < nb and (
            face_region(f) == "feet" or (face_region(f) == "legs" and centre(f).z < 0.36)),
        lambda co: 0.009 + 0.002 * (co.z > 0.2),
        3990, make_material("boots_leather", (0.25, 0.17, 0.11), 0.65))
    # Boots: flat sole slightly under the foot, no sinking below the floor.
    bme = boots.data
    bP = verts_np(bme)
    bP[:, 2] = np.where(bP[:, 2] < 0.012, np.maximum(bP[:, 2], 0.0) * 0.3, bP[:, 2])
    bme.vertices.foreach_set("co", bP.ravel())
    bme.update()
    cloak = build_cloak()
    decimate_to(cloak, 3990)

    for cloth in (tunic, trousers, boots, cloak):
        cP = verts_np(cloth.data)
        if cloth is cloak:
            names = ["Neck", "UpperChest", "LeftShoulder", "RightShoulder", "Chest", "Spine", "Hips",
                     "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"]
            cw = distance_weights(cP, spec, names, k=3, power=3.0)
            # cloth below the hips follows hips mostly; legs a little
            _, nn = transfer_weights(body, P, cP)
        else:
            cw, nn = transfer_weights(body, P, cP)
        apply_weights(cloth, cw)
        skin_to_armature(cloth, arm)
        cloth.shape_key_add(name="Basis", from_mix=False)
        sk = cloth.shape_key_add(name="nourished", from_mix=False)
        d = np.array([sum(nour[i] * f for i, f in lst) for lst in nn])
        if cloth is cloak:
            d *= 0.6
        sk.data.foreach_set("co", (cP + d).ravel())
        sk.value = 0.0

    for o in (eyes, hair, tunic, trousers, boots, cloak, lod):
        ensure_uvs(o)

    # Numbers.
    report = []
    for o in (body, lod, eyes, hair, tunic, trousers, boots, cloak):
        report.append("%-16s tris=%5d verts=%5d" % (o.name, tri_count(o), len(o.data.vertices)))
    allP = verts_np(body.data)
    report.append("height (body+head) = %.4f m, min z = %.4f" % (allP[:, 2].max() - allP[:, 2].min(), allP[:, 2].min()))
    report.append("bones = %d" % len(arm.data.bones))
    report.append("shape keys = %s" % [k.name for k in body.data.shape_keys.key_blocks])
    report.append("mask maxima = %s" % mask_stats)
    report += pose_check(arm, [body, hair, tunic, cloak])

    # Collections for a tidy .blend.
    coll_body = bpy.data.collections.new("Feyre")
    coll_ward = bpy.data.collections.new("Wardrobe_Hunter")
    bpy.context.scene.collection.children.link(coll_body)
    bpy.context.scene.collection.children.link(coll_ward)
    for o in (arm, body, lod, eyes, hair):
        coll_body.objects.link(o)
        bpy.context.scene.collection.objects.unlink(o)
    for o in (tunic, trousers, boots, cloak):
        coll_ward.objects.link(o)
        bpy.context.scene.collection.objects.unlink(o)
    bpy.context.view_layer.update()
    export_glb(os.path.join(MODEL_DIR, "feyre.glb"), [body, lod, eyes, hair], arm)
    for o in (tunic, trousers, boots, cloak):
        export_glb(os.path.join(WARDROBE_DIR, o.name + ".glb"), [o], arm)
    lod.hide_set(True)
    lod.hide_render = True
    bpy.context.preferences.filepaths.save_version = 0  # no feyre.blend1 next to the asset
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(MODEL_DIR, "feyre.blend"), compress=True)
    print("\n==== FEYRE BUILD REPORT ====")
    print("\n".join(report))


if __name__ == "__main__":
    main()
