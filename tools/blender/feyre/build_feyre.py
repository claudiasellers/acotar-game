"""Feyre's rigged base model (storybook-princess pass) and her hunting outfit.

Reproducible build (cloud Blender module):
    /opt/bpyenv/bin/python tools/blender/feyre/build_feyre.py

Writes (relative to the repo root):
    characters/feyre/model/feyre.blend            editable source (sculpt it, re-export)
    characters/feyre/model/feyre.glb              Body (+ Body_LOD1), Eyes, Lashes, Armature
    characters/feyre/model/eye_iris.png           eye texture (blue-grey iris, catchlights)
    characters/feyre/model/makeup_mask_a.png      R lips  G eyeshadow  B liner  A blush
    characters/feyre/model/makeup_mask_b.png      R brows G face_paint
    characters/feyre/wardrobe/hunter_*.glb        tunic / trousers / cloak / boots

The body is a signed-distance sculpt (feyre_shape.py) meshed with surface nets,
smoothed and decimated with extra detail kept in the face and hands.  Hair is a
separate set of glbs (build_hair.py) so hairstyles swap like clothes.

Conventions: Blender Z up, she faces -Y, feet on the origin, T-pose, palms down.
glTF faces +Z; feyre_model.tscn turns the instance 180 degrees so the game sees
her facing -Z.  Bone names follow Godot's humanoid profile.
"""

import math
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402  (must come before bmesh when used as a module)
import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector, kdtree  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

import feyre_anims  # noqa: E402
import feyre_shape as fs  # noqa: E402
import sdf  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MODEL_DIR = os.path.join(REPO, "characters", "feyre", "model")
WARDROBE_DIR = os.path.join(REPO, "characters", "feyre", "wardrobe")

GRID_H = 0.002
BODY_TRIS = 11400
DETAIL_TRIS = 4600   # face, ears and hands share of BODY_TRIS
SKIN_RGB = (0.80, 0.55, 0.45)  # linear; the game skin shader sets its own albedo
HEAD_C = Vector(fs.HEAD_C.tolist())
EYE_X, EYE_Y, EYE_Z, EYE_R = fs.EYE_X, fs.EYE_Y, fs.EYE_Z, fs.EYE_R
MOUTH_Z, MOUTH_HALF_W, CHIN_Z = fs.MOUTH_Z, fs.MOUTH_HALF_W, fs.CHIN_Z
REGIONS = ["torso", "arms", "legs", "feet", "hands", "head"]
FINGER_SEG_NAMES = ["Proximal", "Intermediate", "Distal"]
THUMB_SEG_NAMES = ["Metacarpal", "Proximal", "Distal"]
# Hair chain down the centre of her back (braids, ponytails and long loose hair hang on it).
BRAID_PATH = [(0.0, 0.088, 1.505), (0.0, 0.108, 1.405), (0.0, 0.114, 1.300), (0.0, 0.110, 1.195),
              (0.0, 0.102, 1.090)]


# --------------------------------------------------------------------------
# Skeleton: (name, head, tail, parent, deform).  Left side is +X.
# --------------------------------------------------------------------------
def skeleton_spec():
    t = lambda a: tuple(float(x) for x in a)  # noqa: E731
    b = [
        ("Root", (0, 0, 0), (0, 0, 0.10), None, False),
        ("Hips", (0, 0.004, fs.HIPS_Z), (0, 0.006, fs.SPINE_Z), "Root", True),
        ("Spine", (0, 0.006, fs.SPINE_Z), (0, 0.008, fs.CHEST_Z), "Hips", True),
        ("Chest", (0, 0.008, fs.CHEST_Z), (0, 0.010, fs.UPPER_CHEST_Z), "Spine", True),
        ("UpperChest", (0, 0.010, fs.UPPER_CHEST_Z), t(fs.NECK_BASE), "Chest", True),
        ("Neck", t(fs.NECK_BASE), t(fs.NECK_TOP), "UpperChest", True),
        ("Head", t(fs.NECK_TOP), (0, 0.006, 1.625), "Neck", True),
        ("Jaw", (0, -0.004, 1.478), (0, -0.060, 1.418), "Head", True),
    ]
    for side, s in (("Left", 1), ("Right", -1)):
        m = lambda p: (float(p[0]) * s, float(p[1]), float(p[2]))  # noqa: E731
        b.append((side + "Eye", m((EYE_X, EYE_Y, EYE_Z)), m((EYE_X, EYE_Y - 0.03, EYE_Z)), "Head", True))
        b += [
            (side + "Shoulder", m((0.022, 0.008, 1.292)), m(fs.SHOULDER), "UpperChest", True),
            (side + "UpperArm", m(fs.SHOULDER), m(fs.ELBOW), side + "Shoulder", True),
            (side + "LowerArm", m(fs.ELBOW), m(fs.WRIST), side + "UpperArm", True),
            (side + "Hand", m(fs.WRIST), m((fs.KNUCKLE_X, 0.0, 1.285)), side + "LowerArm", True),
        ]
        parent = side + "Hand"
        for i, seg in enumerate(THUMB_SEG_NAMES):
            nm = side + "Thumb" + seg
            b.append((nm, m(fs.THUMB[i]), m(fs.THUMB[i + 1]), parent, True))
            parent = nm
        for f in fs.FINGERS:
            pts = fs.finger_points(f, 1)
            parent = side + "Hand"
            for i, seg in enumerate(FINGER_SEG_NAMES):
                nm = side + f + seg
                b.append((nm, m(pts[i]), m(pts[i + 1]), parent, True))
                parent = nm
        b += [
            (side + "UpperLeg", m(fs.HIP), m(fs.KNEE), "Hips", True),
            (side + "LowerLeg", m(fs.KNEE), m(fs.ANKLE), side + "UpperLeg", True),
            (side + "Foot", m(fs.ANKLE), m(fs.BALL), side + "LowerLeg", True),
            (side + "Toes", m(fs.BALL), m(fs.TOE_END), side + "Foot", True),
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


def make_material(name, rgb, rough=0.6, metal=0.0, cull=True, image=None, alpha=1.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if image is not None:
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = image
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
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


def select_only(objs, active):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def ensure_uvs(obj):
    if obj.data.uv_layers:
        return
    obj.data.uv_layers.new(name="UVMap")
    select_only([obj], obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")


def box_uvs(obj, scale=1.5):
    """Cheap per-face box projection (skin needs UVs only for tangents)."""
    me = obj.data
    uvl = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        n = p.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uvl.data[li].uv = (co[a] * scale % 1.0, co[b] * scale % 1.0)


def srgb(hexstr):
    """Palette hex (plans/experience-bar.md 2.2) -> linear RGB for Blender materials."""
    c = [int(hexstr[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


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


# --------------------------------------------------------------------------
# Body: sculpt -> surface nets -> smooth -> detail-weighted decimate
# --------------------------------------------------------------------------
def detail_weight(P):
    """1 where we keep extra triangles: the face, ears and fingers."""
    q = P - fs.HEAD_C
    face = smoothstep(1.395, 1.42, P[:, 2]) * smoothstep(-0.01, -0.05, q[:, 1])
    face *= 1.0 - smoothstep(1.56, 1.59, P[:, 2])
    ears = np.exp(-(((np.abs(P[:, 0]) - 0.088) / 0.02) ** 2 + ((P[:, 2] - 1.50) / 0.035) ** 2))
    hands = smoothstep(0.64, 0.70, np.abs(P[:, 0]))
    return np.clip(np.maximum.reduce([face, ears * 0.6, hands * 0.55]), 0, 1)


def build_body():
    grid = fs.build_grid(GRID_H)
    V, Q = sdf.surface_nets(grid)
    me = bpy.data.meshes.new("Body")
    me.from_pydata(V.tolist(), [], Q.tolist())
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    body = link(bpy.data.objects.new("Body", me))
    sm = body.modifiers.new("Smooth", "SMOOTH")
    sm.iterations = 3
    sm.factor = 0.5
    bake_modifiers(body)
    # Two-stage decimation.  A collapse modifier never touches weight-0 vertices, so:
    # first thin out the detail areas (face, ears, hands), then the rest of the body.
    def collapse(weights, ratio):
        g = body.vertex_groups.new(name="collapse")
        for i in np.nonzero(weights > 0.0)[0]:
            g.add([int(i)], float(weights[i]), "REPLACE")
        d = body.modifiers.new("Decimate", "DECIMATE")
        d.ratio = min(1.0, ratio)
        d.vertex_group = "collapse"
        bake_modifiers(body)
        body.vertex_groups.clear()

    w = detail_weight(verts_np(body.data))
    detail = w > 0.35
    n = tri_count(body)
    detail_tris = n * float(detail.mean())
    collapse(detail.astype(float), (n - detail_tris + DETAIL_TRIS) / n)
    w = detail_weight(verts_np(body.data))
    collapse((w <= 0.35).astype(float), BODY_TRIS / tri_count(body))
    # Keep the main shell only (drop any crumbs the sculpt left).
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    seen = set()
    islands = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, isl = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop()
            isl.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        islands.append(isl)
    islands.sort(key=len, reverse=True)
    crumbs = [v for isl in islands[1:] for v in isl]
    bmesh.ops.delete(bm, geom=crumbs, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
    bm.to_mesh(body.data)
    bm.free()
    body.data.validate()
    print("body islands dropped:", len(islands) - 1, "verts", sum(len(i) for i in islands[1:]))
    return body, grid


# --------------------------------------------------------------------------
# Eyes: planar-mapped spheres with a painted iris; lashes from the lid edge
# --------------------------------------------------------------------------
IRIS_R = 0.62    # iris radius as a fraction of the eyeball radius (front view)
PUPIL_R = 0.26
UV_SPAN = 1.1    # UV square covers +/- UV_SPAN * EYE_R


def bake_iris_texture(path, size=256):
    g = (np.arange(size) + 0.5) / size * 2.0 - 1.0
    U, V = np.meshgrid(g * UV_SPAN, g * UV_SPAN)  # V up
    r = np.sqrt(U * U + V * V)
    ang = np.arctan2(V, U)
    col = np.zeros((size, size, 4))
    sclera = np.array([0.97, 0.955, 0.95])
    col[..., :3] = sclera * (1.0 - 0.10 * smoothstep(0.75, 1.05, r))[..., None]
    col[..., :3] -= np.array([0.03, 0.05, 0.06]) * smoothstep(0.2, 1.0, V)[..., None]  # lid shadow
    # iris: blue-grey, lighter round the pupil, radial fibres, dark limbal ring
    t = np.clip(r / IRIS_R, 0, 1)
    outer = np.array([0.30, 0.42, 0.55])
    inner = np.array([0.62, 0.74, 0.82])
    gold = np.array([0.75, 0.70, 0.55])
    iris = outer[None, None] * (t[..., None]) + inner[None, None] * (1 - t[..., None])
    fib = 0.5 + 0.5 * np.sin(ang * 31.0 + np.sin(ang * 7.0) * 2.0) * np.sin(ang * 13.0 + 1.3)
    iris *= (0.86 + 0.22 * fib)[..., None]
    ring = np.exp(-((t - 0.42) / 0.10) ** 2)
    iris = iris * (1 - 0.25 * ring[..., None]) + gold * 0.25 * ring[..., None]
    iris *= (1.0 - 0.55 * smoothstep(0.80, 1.0, t))[..., None]                     # limbal ring
    iris *= (1.0 - 0.30 * smoothstep(0.0, 0.9, V / IRIS_R))[..., None]             # upper lid shade
    m_iris = 1.0 - smoothstep(IRIS_R - 0.015, IRIS_R + 0.015, r)
    col[..., :3] = col[..., :3] * (1 - m_iris[..., None]) + iris * m_iris[..., None]
    m_pup = 1.0 - smoothstep(PUPIL_R - 0.02, PUPIL_R + 0.01, r)
    col[..., :3] = col[..., :3] * (1 - m_pup[..., None]) + np.array([0.04, 0.04, 0.07]) * m_pup[..., None]
    # painted catchlights: a big soft one upper-left, a little one lower-right
    for cu, cv, rad, k in ((-0.20, 0.24, 0.13, 1.0), (0.22, -0.20, 0.06, 0.85)):
        d = np.sqrt((U - cu) ** 2 + (V - cv) ** 2)
        m = (1.0 - smoothstep(rad * 0.75, rad, d)) * k
        col[..., :3] = col[..., :3] * (1 - m[..., None]) + m[..., None]
    col[..., 3] = 1.0
    write_png(path, col)


def build_eyes():
    bm = bmesh.new()
    for s in (1, -1):
        ret = bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=EYE_R,
                                        matrix=Matrix.Translation((EYE_X * s, EYE_Y, EYE_Z))
                                        @ Matrix.Rotation(math.radians(90), 4, "X"))
        del ret
    bm.normal_update()
    uvl = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for lp in f.loops:
            co = lp.vert.co
            cx = EYE_X if co.x > 0 else -EYE_X
            lp[uvl].uv = (0.5 + (co.x - cx) / (2 * UV_SPAN * EYE_R), 0.5 + (co.z - EYE_Z) / (2 * UV_SPAN * EYE_R))
        f.smooth = True
    obj = obj_from_bm("Eyes", bm)
    img_path = os.path.join(MODEL_DIR, "eye_iris.png")
    bake_iris_texture(img_path)
    img = bpy.data.images.load(img_path)
    obj.data.materials.append(make_material("eye", (1, 1, 1), rough=0.06, image=img))
    return obj


def lid_rim_points(P, side, n=15):
    """Upper-lid margin on the final mesh: for each slice across the eye, the skin
    vertex just above the opening that sits closest to the eyeball."""
    c = np.array([EYE_X * side, EYE_Y, EYE_Z])
    q = P - c
    dist = np.linalg.norm(q, axis=1)
    ax, az, up, lo = fs.eye_angles(q[:, 0], q[:, 1], q[:, 2], side)
    deg = math.pi / 180.0
    cand = (q[:, 1] < 0) & (dist > EYE_R - 0.0035) & (dist < EYE_R + 0.012) & (az > up - 4 * deg) & (az < up + 16 * deg)
    pts = []
    for i in range(n):
        tx = -0.94 + 1.88 * i / (n - 1)
        band = cand & (np.abs(ax / fs.EYE_OPEN_W - tx) < 0.09)
        idx = np.nonzero(band)[0]
        if len(idx) == 0:
            idx = np.nonzero(cand)[0][np.argsort(np.abs(ax[cand] / fs.EYE_OPEN_W - tx))[:3]]
        j = idx[np.argmin(dist[idx])]
        pts.append(P[j])
    pts = np.array(pts)
    # smooth along the rim so the lash line is a clean curve
    for _ in range(2):
        pts[1:-1] = 0.25 * pts[:-2] + 0.5 * pts[1:-1] + 0.25 * pts[2:]
    return pts


def build_lashes(body_P):
    bm = bmesh.new()
    for s in (1, -1):
        P, D = fs.lid_curve(s, True, n=15, extra=fs.LID_R[0] * 0.55)
        P = P - np.array([0.0, 0.0, fs.LID_R[0] * 0.2])
        n = len(P)
        rows = []
        for i in range(n):
            tx = -0.96 + 1.92 * i / (n - 1)
            outer = max(0.0, tx)
            length = 0.0018 + 0.0052 * smoothstep(-0.4, 1.0, tx) ** 1.5
            if i % 2 == 1:
                length *= 0.86  # soft clumps
            if i in (0, n - 1):
                length *= 0.4
            dv = Vector(D[i].tolist())
            out_dir = (dv + Vector((s * 1.2 * outer, -0.35, 0.25))).normalized()
            base = Vector(P[i].tolist())
            mid = base + out_dir * length * 0.5 + Vector((0, 0, length * 0.08))
            tip = base + out_dir * length + Vector((0, 0, length * 0.15))
            under = base - dv * 0.0012
            rows.append([bm.verts.new(under), bm.verts.new(base), bm.verts.new(mid), bm.verts.new(tip)])
        for i in range(n - 1):
            for r in range(3):
                a, b2, c2, d2 = rows[i][r], rows[i + 1][r], rows[i + 1][r + 1], rows[i][r + 1]
                f = bm.faces.new((a, d2, c2, b2) if s > 0 else (a, b2, c2, d2))
                f.smooth = True
    bm.normal_update()
    obj = obj_from_bm("Lashes", bm)
    obj.data.materials.append(make_material("lashes", srgb("#3B2A26"), 0.5, cull=False))
    return obj


# --------------------------------------------------------------------------
# Armature + weights
# --------------------------------------------------------------------------
def build_armature():
    arm = bpy.data.armatures.new("Armature")
    obj = link(bpy.data.objects.new("Armature", arm))
    arm.display_type = "STICK"
    select_only([obj], obj)
    bpy.ops.object.mode_set(mode="EDIT")
    spec = skeleton_spec()
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
    regs = np.array([region_of_bone(names[i]) for i in np.argmin(D, axis=1)], dtype=object)
    # the neck belongs to the head surface down to the collarbones
    regs[(P[:, 2] > 1.335) & (np.abs(P[:, 0]) < 0.075)] = "head"
    regs[(P[:, 2] > 1.385)] = "head"
    regs[(regs == "head") & (P[:, 2] < 1.30)] = "torso"
    return list(regs)


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
    m = obj.modifiers.get("Armature") or obj.modifiers.new("Armature", "ARMATURE")
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


def jaw_weight(P):
    w = smoothstep(MOUTH_Z + 0.001, MOUTH_Z - 0.016, P[:, 2])
    w *= smoothstep(HEAD_C.y + 0.04, HEAD_C.y - 0.012, P[:, 1])
    w *= P[:, 2] > CHIN_Z - 0.035
    return w


def weight_body(body, arm, spec, P, vreg):
    no_heat = {"Root", "LeftEye", "RightEye", "Jaw"} | {"Braid_%d" % i for i in range(1, 5)}
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
    # Head: rigid on Head, lower face on Jaw, blending into the neck below the jaw line.
    head = [i for i, r in enumerate(vreg) if r == "head" and P[i, 2] > 1.39]
    hP = P[head]
    jw = jaw_weight(hP)
    neck_w = smoothstep(1.43, 1.395, hP[:, 2]) * (1.0 - smoothstep(-0.03, -0.06, hP[:, 1] - HEAD_C.y))
    for g in list(body.vertex_groups):
        g.remove(head)
    for j, vi in enumerate(head):
        nw = float(neck_w[j])
        jww = float(jw[j]) * (1.0 - nw)
        hw = max(0.0, 1.0 - jww - nw)
        for n, w in (("Head", hw), ("Jaw", jww), ("Neck", nw)):
            if w > 0.001:
                g = body.vertex_groups.get(n) or body.vertex_groups.new(name=n)
                g.add([vi], w, "REPLACE")
    body.modifiers["Armature"].object = arm
    print("heat weighting:", "ok" if heat_ok else "FAILED (distance fallback)", "| zero-weight verts filled:", len(empty))


# --------------------------------------------------------------------------
# Shape keys
# --------------------------------------------------------------------------
def jaw_delta(P, amount):
    w = jaw_weight(P)
    a = math.radians(15.0) * amount
    piv = np.array([0.0, 0.0, EYE_Z - 0.02])
    d = P - piv
    y2 = d[:, 1] * math.cos(a) - d[:, 2] * math.sin(a)
    z2 = d[:, 1] * math.sin(a) + d[:, 2] * math.cos(a)
    out = np.zeros_like(P)
    out[:, 1] = (y2 - d[:, 1]) * w
    out[:, 2] = (z2 - d[:, 2]) * w
    return out


def pucker_delta(P, amount, front):
    w = gauss(P, (0, 0, MOUTH_Z), (0.020, 1, 0.011)) * front
    out = np.zeros_like(P)
    out[:, 1] = -0.007 * w * amount
    out[:, 0] = -0.45 * P[:, 0] * w * amount
    return out


def corners_delta(P, front, dx, dy, dz):
    out = np.zeros_like(P)
    for s in (1, -1):
        w = gauss(P, (MOUTH_HALF_W * s, 0, MOUTH_Z), (0.010, 1, 0.008)) * front
        out[:, 0] += dx * s * w
        out[:, 1] += dy * w
        out[:, 2] += dz * w
    return out


def lid_delta(P, side, upper=1.0, lower=1.0):
    """Rotate lid skin about the eye's horizontal axis so the lids meet over the eye."""
    c = np.array([EYE_X * side, EYE_Y, EYE_Z])
    q = P - c
    dist = np.linalg.norm(q, axis=1)
    ax, az, up, lo = fs.eye_angles(q[:, 0], q[:, 1], q[:, 2], side)
    near = (q[:, 1] < 0.004) & (dist < EYE_R + 0.016) & (np.abs(ax) < fs.EYE_OPEN_W * 1.15)
    near = near * (1.0 - smoothstep(EYE_R + 0.008, EYE_R + 0.016, dist))
    meet = -0.3 * lo
    wu = smoothstep(up + math.radians(40), up + math.radians(4), az) * (az > meet) * near * upper
    wl = smoothstep(-lo - math.radians(28), -lo - math.radians(3), az) * (az <= meet) * near * lower
    phi = -(up - meet) * wu + (meet + lo) * wl     # signed rotation (down is negative)
    rho = np.sqrt(q[:, 1] ** 2 + q[:, 2] ** 2)
    alpha = np.arctan2(q[:, 2], -q[:, 1]) + phi
    out = np.zeros_like(P)
    out[:, 1] = -rho * np.cos(alpha) - q[:, 1]
    out[:, 2] = rho * np.sin(alpha) - q[:, 2]
    return out


def add_body_shape_keys(obj, vreg):
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

    head_mask = np.array([r == "head" for r in vreg]) & (P[:, 2] > 1.38)
    # nourished: starving base -> healthy.  Per-region inflation along normals.
    amt = {"torso": 0.010, "arms": 0.006, "legs": 0.009, "feet": 0.0015, "hands": 0.0015, "head": 0.0}
    a = np.array([amt[r] for r in vreg])
    a += 0.010 * sum(gauss(P, (0.065 * s, 0.05, 0.86), (0.07, 0.08, 0.10)) for s in (1, -1))  # hips / seat
    a += 0.005 * sum(gauss(P, (0.047 * s, -0.08, 1.178), (0.04, 0.04, 0.035)) for s in (1, -1))  # bust
    front = smoothstep(0.0, 0.04, -(P[:, 1] - HEAD_C.y)) * head_mask
    cheeks = sum(gauss(P, (0.045 * s, -0.06, 1.474), (0.025, 0.04, 0.03)) for s in (1, -1)) * head_mask
    a = np.where(head_mask, 0.0035 * cheeks, a)
    key("nourished", N * a[:, None])

    def fkey(name, d):
        key(name, d * head_mask[:, None])

    fkey("blink_L", lid_delta(P, 1))
    fkey("blink_R", lid_delta(P, -1))
    fkey("jaw_open", jaw_delta(P, 1.0))
    sm = corners_delta(P, front, 0.0035, 0.0025, 0.0055)
    for s in (1, -1):
        c = gauss(P, (0.042 * s, 0, 1.478), (0.016, 1, 0.014)) * front
        sm[:, 2] += 0.0028 * c
        sm[:, 1] -= 0.0015 * c
    fkey("smile", sm)
    fkey("frown", corners_delta(P, front, -0.001, 0.001, -0.0045))
    bu, bd, sq, cp = (np.zeros_like(P) for _ in range(4))
    for s in (1, -1):
        b = gauss(P, (0.036 * s, 0, fs.BROW_Z + 0.003), (0.03, 1, 0.013)) * front
        bu[:, 2] += 0.0055 * b
        bd[:, 2] -= 0.0038 * b
        bd[:, 0] -= 0.002 * s * b
        bd[:, 1] -= 0.0015 * b
        sq += 0.35 * lid_delta(P, s, 1.0, 0.0) + 0.6 * lid_delta(P, s, 0.0, 1.0)
        ch = gauss(P, (0.043 * s, 0, 1.48), (0.016, 1, 0.012)) * front
        sq[:, 2] += 0.002 * ch
        puff = gauss(P, (0.043 * s, -0.045, 1.470), (0.017, 0.05, 0.018)) * head_mask
        cp += N * (0.007 * puff)[:, None]
    fkey("brow_up", bu)
    fkey("brow_down", bd)
    fkey("squint", sq)
    fkey("cheek_puff", cp)
    fkey("lips_pucker", pucker_delta(P, 1.0, front))
    fkey("vis_AA", jaw_delta(P, 0.75) + corners_delta(P, front, 0.002, 0.0, 0.0))
    fkey("vis_E", jaw_delta(P, 0.25) + corners_delta(P, front, 0.0045, 0.002, 0.001))
    fkey("vis_O", jaw_delta(P, 0.45) + pucker_delta(P, 0.6, front))
    fkey("vis_U", jaw_delta(P, 0.12) + pucker_delta(P, 1.0, front))
    mbp = np.zeros_like(P)
    lip = gauss(P, (0, 0, MOUTH_Z), (0.018, 1, 0.008)) * front
    mbp[:, 1] += 0.0018 * lip
    mbp[:, 2] += np.where(P[:, 2] > MOUTH_Z, -0.0016, 0.0016) * lip
    fkey("vis_MBP", mbp)
    fv = jaw_delta(P, 0.08)
    ll = gauss(P, (0, 0, MOUTH_Z - 0.0055), (0.015, 1, 0.0045)) * front
    fv[:, 2] += 0.0025 * ll
    fv[:, 1] += 0.003 * ll
    fkey("vis_FV", fv)


# --------------------------------------------------------------------------
# Head UVs + makeup masks
# --------------------------------------------------------------------------
HEAD_V0, HEAD_V1 = 1.28, 1.70


def head_uv(P):
    th = np.arctan2(P[:, 0] - HEAD_C.x, -(P[:, 1] - HEAD_C.y))
    u = 0.5 + th / (2 * math.pi)
    v = (P[:, 2] - HEAD_V0) / (HEAD_V1 - HEAD_V0)
    return u, v


def raster_head(P, tris, uv, size):
    """Rasterise head triangles in UV space; returns per-pixel X, Y, Z and coverage."""
    X = np.zeros((size, size))
    Y = np.ones((size, size))
    Z = np.zeros((size, size))
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
        ins = (l1 >= -0.03) & (l2 >= -0.03) & (l3 >= -0.03)
        if not ins.any():
            continue
        sl = (slice(y0, y1 + 1), slice(x0, x1 + 1))
        for A, k in ((X, 0), (Y, 1), (Z, 2)):
            A[sl] = np.where(ins, l1 * P[a, k] + l2 * P[b, k] + l3 * P[c, k], A[sl])
        cov[sl] |= ins
    return X, Y, Z, cov


def bake_makeup_masks(P, tris, uv, size=1024):
    X, Y, Z, cov = raster_head(P, tris, uv, size)
    F = (cov & (Y < HEAD_C.y - 0.015)).astype(float)
    ax = np.abs(X)
    side = np.where(X >= 0, 1.0, -1.0)

    def ell(cx, cz, rx, rz, soft=0.35):
        d = np.sqrt(((ax - cx) / rx) ** 2 + ((Z - cz) / rz) ** 2)
        return (1.0 - smoothstep(1.0 - soft, 1.0, d)) * F

    # lips: follow the sculpted lobes (upper with a cupid's bow, fuller lower)
    upper = ell(0.0, MOUTH_Z + 0.0040, 0.0172, 0.0047, 0.35)
    bow = 1.0 - 0.6 * np.exp(-(X / 0.0028) ** 2) * smoothstep(MOUTH_Z + 0.006, MOUTH_Z + 0.0085, Z)
    lower = ell(0.0, MOUTH_Z - 0.0045, 0.0135, 0.0056, 0.4)
    lips = np.maximum(upper * bow, lower) * (Y < fs.MOUTH_Y + 0.004)
    # eye-relative angles for shadow / liner
    qx, qy, qz = X - EYE_X * side, Y - EYE_Y, Z - EYE_Z
    eax, eaz, up, lo = fs.eye_angles(qx, qy, qz, side)
    edist = np.sqrt(qx * qx + qy * qy + qz * qz)
    near_eye = (edist < EYE_R + 0.022) * F
    deg = math.pi / 180.0
    over = eaz - up
    across = 1.0 - smoothstep(fs.EYE_OPEN_W * 0.95, fs.EYE_OPEN_W * 1.25, np.abs(eax))
    shadow = smoothstep(-2 * deg, 3 * deg, over) * (1.0 - smoothstep(22 * deg, 46 * deg, over)) * across * near_eye
    liner = smoothstep(-1.5 * deg, 0.5 * deg, over) * (1.0 - smoothstep(4 * deg, 8 * deg, over)) * across * near_eye
    # wing: continues the upper rim past the outer corner, flicking up
    wt = np.clip((eax - fs.EYE_OPEN_W * 0.92) / (24 * deg), 0, 1)
    wing_az = fs.EYE_TILT + wt * 14 * deg
    wing = np.exp(-((eaz - wing_az) / ((3.5 - 2.5 * wt) * deg)) ** 2) * (eax > fs.EYE_OPEN_W * 0.9) * (wt < 1) * near_eye
    liner = np.maximum(liner, wing)
    blush = ell(0.046, 1.476, 0.017, 0.012, 0.9)
    # brows: tapered, gently arched
    bt = np.clip((ax - 0.013) / 0.047, 0, 1)
    brow_z = fs.BROW_Z + 0.006 * np.sin(bt * math.pi * 0.8) - 0.004 * bt
    brow_th = 0.0030 * (1.0 - 0.6 * bt)
    brows = np.exp(-((Z - brow_z) / brow_th) ** 4) * (ax > 0.011) * (ax < 0.062) * F
    brows *= 1.0 - smoothstep(0.85, 1.0, bt)
    # face paint (festival / Calanmai): a sweep along the cheekbone, three dots, a forehead mark
    fp_t = np.clip((ax - 0.024) / 0.04, 0, 1)
    fp_z = EYE_Z - 0.024 + fp_t * 0.028
    paint = np.exp(-((Z - fp_z) / 0.0018) ** 2) * (ax > 0.024) * (ax < 0.064) * F
    for dx in (0.032, 0.040, 0.048):
        cz = EYE_Z - 0.031 + (dx - 0.032) * 0.5
        paint = np.maximum(paint, np.exp(-(((ax - dx) / 0.0022) ** 2 + ((Z - cz) / 0.0022) ** 2)) * F)
    paint = np.maximum(paint, np.exp(-((X / 0.0030) ** 2 + ((Z - (fs.BROW_Z + 0.022)) / 0.006) ** 2)) * F)

    a = np.stack([lips, shadow, liner, blush], axis=-1)
    b = np.stack([brows, paint, np.zeros_like(X), np.ones_like(X)], axis=-1)
    write_png(os.path.join(MODEL_DIR, "makeup_mask_a.png"), a)
    write_png(os.path.join(MODEL_DIR, "makeup_mask_b.png"), b)
    return {k: round(float(v.sum()) / 1000.0, 1) for k, v in dict(
        lips=lips, shadow=shadow, liner=liner, blush=blush, brows=brows, paint=paint).items()}


# --------------------------------------------------------------------------
# Hunting outfit
# --------------------------------------------------------------------------
def ring_fit(grid, z, n, cy=0.0, rmax=0.36):
    """Outermost body radius at height z for n angles (angle 0 = front, -Y)."""
    out = []
    rs = np.linspace(0.005, rmax, 300)
    for i in range(n):
        a = 2 * math.pi * i / n
        d = np.array([math.sin(a), -math.cos(a), 0.0])
        pts = np.array([0.0, cy, z])[None] + rs[:, None] * d[None]
        F = grid.sample(pts)
        ins = np.nonzero(F < 0)[0]
        out.append(rs[ins[-1]] if len(ins) else 0.0)
    return np.array(out)


def shell_from_body(name, body, base_P, face_ok, offset_fn, max_tris, mat, extra=None):
    """Garment shell: copy body faces, subdivide (smooth), then push out along normals."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    for v, p in zip(bm.verts, base_P):
        v.co = p
    bm.faces.ensure_lookup_table()
    kill = [f for f in bm.faces if not face_ok(f)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    for layer in list(bm.verts.layers.shape):
        bm.verts.layers.shape.remove(layer)
    obj = obj_from_bm(name, bm)
    obj.vertex_groups.clear()
    obj.modifiers.clear()
    obj.parent = None
    for p in obj.data.polygons:
        p.material_index = 0
    if tri_count(obj) * 4 <= max_tris:
        sub = obj.modifiers.new("Subsurf", "SUBSURF")
        sub.levels = 1
        sub.boundary_smooth = "PRESERVE_CORNERS"
        bake_modifiers(obj)
    me = obj.data
    me.update()
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


def ring_surface(bm, rings, cols, mat_index=0, closed=True):
    """rings: list of lists of 3D points (each len cols).  Faces outward-wound for -Y front rings."""
    grid = [[bm.verts.new(p) for p in r] for r in rings]
    first = len(bm.faces)
    cmax = cols if closed else cols - 1
    for r in range(len(rings) - 1):
        for c in range(cmax):
            c2 = (c + 1) % cols
            f = bm.faces.new((grid[r][c], grid[r + 1][c], grid[r + 1][c2], grid[r][c2]))
            f.material_index = mat_index
    return first


def tunic_skirt_and_belt(grid):
    def extra(bm):
        cols = 40
        rings = []
        z_top, z_bot = 0.93, 0.68
        for r in range(8):
            t = r / 7
            z = z_top - t * (z_top - z_bot)
            fit = ring_fit(grid, z, cols, cy=0.008)
            fit_top = ring_fit(grid, z_top, cols, cy=0.008)
            base = np.maximum(fit, fit_top * (1.0 + 0.10 * t)) + 0.010 + 0.02 * t
            row = []
            for c in range(cols):
                a = 2 * math.pi * c / cols
                fold = 1.0 + 0.035 * t * math.sin(a * 7)
                rr = base[c] * fold
                row.append((rr * math.sin(a), -rr * math.cos(a) + 0.008, z))
            rings.append(row)
        f0 = ring_surface(bm, rings, cols, 0)
        bfit = ring_fit(grid, 0.955, cols, cy=0.008) + 0.014
        belt = []
        for z in (0.972, 0.938):
            belt.append([(bfit[c] * math.sin(2 * math.pi * c / cols), -bfit[c] * math.cos(2 * math.pi * c / cols) + 0.008, z)
                         for c in range(cols)])
        f1 = ring_surface(bm, belt, cols, 1)
        bm.faces.ensure_lookup_table()
        bm.normal_update()
        for f in bm.faces[f0:]:
            c = f.calc_center_median()
            if f.normal.dot(Vector((c.x, c.y - 0.008, 0))) < 0:
                f.normal_flip()
        del f1
    return extra


def build_cloak(grid):
    bm = bmesh.new()
    rings, cols = 26, 44
    gap = math.radians(50)  # front opening half-angle
    shoulder = ring_fit(grid, 1.24, 72, cy=0.008, rmax=0.30)
    sh_r = float(np.max(shoulder)) + 0.03
    grid_pts = []
    for r in range(rings):
        t = r / (rings - 1)
        z = 1.385 - t * (1.385 - 0.40)
        rx = np.interp(t, [0, 0.05, 0.11, 0.22, 1.0], [0.072, 0.15, sh_r + 0.005, sh_r + 0.02, 0.31])
        ry = np.interp(t, [0, 0.05, 0.11, 0.22, 1.0], [0.068, 0.10, 0.125, 0.145, 0.24])
        row = []
        for c in range(cols):
            a = gap + (2 * math.pi - 2 * gap) * c / (cols - 1)
            fold = 0.008 * t * math.sin(a * 9.0)
            row.append((rx * math.sin(a) * (1 + fold * 3), -ry * math.cos(a) + 0.012 + fold, z))
        grid_pts.append(row)
    first = ring_surface(bm, grid_pts, cols, 0, closed=False)
    cloak_faces = len(bm.faces)
    hr, hc = 10, 22
    hg = []
    for i in range(hr):
        u = i / (hr - 1) * 2 * math.pi
        row = []
        for j in range(hc):
            a = math.radians(60) + math.radians(240) * j / (hc - 1)
            pinch = math.sin(math.pi * j / (hc - 1)) ** 0.6
            R = 0.118 + 0.024 * pinch * math.cos(u)
            row.append((R * math.sin(a) * 0.95, -R * math.cos(a) * 0.8 + 0.03 + 0.01 * pinch * math.cos(u),
                        1.37 + 0.026 * pinch * math.sin(u) - 0.02 * math.cos(a) ** 2))
        hg.append(row)
    vs = [[bm.verts.new(p) for p in r] for r in hg]
    for i in range(hr):
        for j in range(hc - 1):
            i2 = (i + 1) % hr
            bm.faces.new((vs[i][j], vs[i][j + 1], vs[i2][j + 1], vs[i2][j]))
    bm.normal_update()
    del first
    obj = obj_from_bm("hunter_cloak", bm)
    obj.data.materials.append(make_material("cloak_wool", srgb("#7E6A78"), 0.9, cull=False))
    obj.data.materials.append(make_material("cloak_hood", srgb("#6E5C6A"), 0.9, cull=False))
    for p in obj.data.polygons:
        p.use_smooth = True
        p.material_index = 0 if p.index < cloak_faces else 1
    return obj


# --------------------------------------------------------------------------
# Export + checks
# --------------------------------------------------------------------------
def export_glb(path, objs, arm, animations=False):
    select_only([arm] + objs, arm)
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
              export_animations=animations, export_skins=True, export_morph=True, export_yup=True,
              export_materials="EXPORT", export_extras=False)
    if animations:
        kw["export_animation_mode"] = "ACTIONS"
    try:
        bpy.ops.export_scene.gltf(**kw, export_morph_normal=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)


def pose_check(arm, objs):
    """Pose a few bones and measure displacement (sanity: no exploding verts)."""

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
            bound = 2.0 * np.linalg.norm(rest[o.name] - piv, axis=1) * math.sin(ang / 2.0) + 1e-4
            over = int((d > bound * 1.05).sum())
            line.append("%s max=%.3fm over-bound:%d%s" % (o.name, d.max(), over, "" if ok else " NaN!"))
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

    body, grid = build_body()
    eyes = build_eyes()
    lashes = build_lashes(verts_np(body.data))
    arm, spec = build_armature()

    # Material slots by region.
    me = body.data
    mats = {r: make_material(r, SKIN_RGB, 0.55) for r in REGIONS}
    for r in REGIONS:
        me.materials.append(mats[r])
    P = verts_np(me)
    vreg = classify_regions(P, spec)
    for p in me.polygons:
        regs = [vreg[v] for v in p.vertices]
        r = max(set(regs), key=regs.count)
        p.material_index = REGIONS.index(r)
        p.use_smooth = True
    # a vertex's region = the region of its faces (heads win at the neckline)
    for p in me.polygons:
        if REGIONS[p.material_index] == "head":
            for v in p.vertices:
                vreg[v] = "head"

    # UVs: box projection on the body, cylindrical on the head (makeup masks).
    box_uvs(body)
    uvl = me.uv_layers["UVMap"]
    u, v = head_uv(P)
    head_tris = []
    me.calc_loop_triangles()
    for t in me.loop_triangles:
        if REGIONS[me.polygons[t.polygon_index].material_index] == "head":
            head_tris.append(tuple(t.vertices))
    for poly in me.polygons:
        if REGIONS[poly.material_index] != "head":
            continue
        lu = [u[me.loops[li].vertex_index] for li in poly.loop_indices]
        wrap = max(lu) - min(lu) > 0.5
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            uu = u[vi]
            if wrap and uu < 0.5:
                uu = 1.0 + uu  # back seam
            uvl.data[li].uv = (uu, v[vi])
    mask_stats = bake_makeup_masks(P, head_tris, np.stack([u, v], axis=1))

    weight_body(body, arm, spec, P, vreg)

    # Eyes rigid on their eye bones; lashes ride the lids with the head.
    for i, vtx in enumerate(eyes.data.vertices):
        n = "LeftEye" if vtx.co.x > 0 else "RightEye"
        g = eyes.vertex_groups.get(n) or eyes.vertex_groups.new(name=n)
        g.add([i], 1.0, "REPLACE")
    skin_to_armature(eyes, arm)
    g = lashes.vertex_groups.new(name="Head")
    g.add(list(range(len(lashes.data.vertices))), 1.0, "REPLACE")
    skin_to_armature(lashes, arm)

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

    add_body_shape_keys(body, vreg)

    # Hunting outfit.
    kb = body.data.shape_keys.key_blocks
    nour = np.empty(len(P) * 3)
    kb["nourished"].data.foreach_get("co", nour)
    nour = nour.reshape(-1, 3) - P

    def face_region(f):
        return REGIONS[f.material_index]

    def centre(f):
        return f.calc_center_median()

    tunic = shell_from_body(
        "hunter_tunic", body, P,
        lambda f: (face_region(f) == "torso" and centre(f).z > 0.90)
        or (face_region(f) == "arms" and abs(centre(f).x) < 0.60),
        lambda co: 0.0055 + 0.005 * (abs(co.x) < 0.16),
        3990, [make_material("tunic_linen", srgb("#A9B4CF"), 0.85),
               make_material("belt_leather", srgb("#8E6A6E"), 0.5)],
        extra=tunic_skirt_and_belt(grid))
    trousers = shell_from_body(
        "hunter_trousers", body, P,
        lambda f: (face_region(f) == "legs" and centre(f).z > 0.11)
        or (face_region(f) == "torso" and centre(f).z < 0.99),
        lambda co: 0.0042,
        3990, make_material("trousers_wool", srgb("#7A86A8"), 0.9))
    boots = shell_from_body(
        "hunter_boots", body, P,
        lambda f: face_region(f) == "feet" or (face_region(f) == "legs" and centre(f).z < 0.36),
        lambda co: 0.008 + 0.002 * (co.z > 0.2),
        3990, make_material("boots_leather", srgb("#8E6A6E"), 0.5))
    bme = boots.data
    bP = verts_np(bme)
    bP[:, 2] = np.where(bP[:, 2] < 0.012, np.maximum(bP[:, 2], 0.0) * 0.3, bP[:, 2])
    bme.vertices.foreach_set("co", bP.ravel())
    bme.update()
    cloak = build_cloak(grid)
    decimate_to(cloak, 3990)

    for cloth in (tunic, trousers, boots, cloak):
        cP = verts_np(cloth.data)
        if cloth is cloak:
            names = ["Neck", "UpperChest", "LeftShoulder", "RightShoulder", "Chest", "Spine", "Hips",
                     "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"]
            cw = distance_weights(cP, spec, names, k=3, power=3.0)
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

    for o in (tunic, trousers, boots, cloak, lod, lashes):
        ensure_uvs(o)

    report = []
    for o in (body, lod, eyes, lashes, tunic, trousers, boots, cloak):
        report.append("%-16s tris=%5d verts=%5d" % (o.name, tri_count(o), len(o.data.vertices)))
    report.append("hero total (body+eyes+lashes) = %d tris" % (tri_count(body) + tri_count(eyes) + tri_count(lashes)))
    face_tris = sum(1 for p in me.polygons if p.material_index == REGIONS.index("head"))
    report.append("head-surface tris = %d" % face_tris)
    allP = verts_np(body.data)
    report.append("height = %.4f m, min z = %.4f, head height ratio = 1:%.2f"
                  % (allP[:, 2].max() - allP[:, 2].min(), allP[:, 2].min(), allP[:, 2].max() / (allP[:, 2].max() - CHIN_Z)))
    report.append("bones = %d" % len(arm.data.bones))
    report.append("shape keys = %s" % [k.name for k in body.data.shape_keys.key_blocks])
    report.append("mask coverage (k px) = %s" % mask_stats)
    report += pose_check(arm, [body, tunic, cloak])

    coll_body = bpy.data.collections.new("Feyre")
    coll_ward = bpy.data.collections.new("Wardrobe_Hunter")
    bpy.context.scene.collection.children.link(coll_body)
    bpy.context.scene.collection.children.link(coll_ward)
    for o in (arm, body, lod, eyes, lashes):
        coll_body.objects.link(o)
        bpy.context.scene.collection.objects.unlink(o)
    for o in (tunic, trousers, boots, cloak):
        coll_ward.objects.link(o)
        bpy.context.scene.collection.objects.unlink(o)
    bpy.context.view_layer.update()
    clips = feyre_anims.add_actions(arm)
    report.append("clips = %s" % clips)
    export_glb(os.path.join(MODEL_DIR, "feyre.glb"), [body, lod, eyes, lashes], arm, animations=True)
    for o in (tunic, trousers, boots, cloak):
        export_glb(os.path.join(WARDROBE_DIR, o.name + ".glb"), [o], arm)
    lod.hide_set(True)
    lod.hide_render = True
    for img in bpy.data.images:
        img.pack()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(MODEL_DIR, "feyre.blend"), compress=True)
    print("\n==== FEYRE BUILD REPORT ====")
    print("\n".join(report))


if __name__ == "__main__":
    main()
