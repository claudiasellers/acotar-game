"""Tamlin's beast form: the golden horned thing that breaks the Archeron cottage door.

Reproducible build (cloud Blender module, deterministic: seeded, no clock):
    /opt/bpyenv/bin/python tools/blender/cast/build_tamlin_beast.py [--no-render]

Writes (relative to the repo root):
    characters/tamlin/beast/tamlin_beast.glb        Body (+ Body_LOD1), Armature, 6 clips
    characters/tamlin/beast/tamlin_beast.blend      editable source (images packed)
    characters/tamlin/beast/tamlin_beast_eye.png    emissive iris (slit pupil, amber flecks)
    /mnt/project-files/art/cast/tamlin_beast_lineup.png   lineup render (unless --no-render)

Canon (lore/03-characters/tamlin.md): horse-sized, golden fur, somewhat feline body,
wolfish head, curved elk-like horns, black claws, yellow fangs, green eyes.  R3: the
game is candy-pastel but horror stays horror, so the silhouette is built to frighten:
massive shoulders and a high withers hump, head carried low on a forward neck, a jaw
whose gape runs back under the eyes, an overbite of many yellow fangs over black wet
lips, a ragged ruff, gaunt tucked waist with rib grooves and tendons, hooked claws.

Body: signed-distance sculpt (tools/blender/feyre/sdf.py) meshed with surface nets,
smoothed, decimated with extra density on the head.  Horns, teeth, claws and eyes
are swept / primitive meshes joined into the same `Body` mesh (one material each).
Colour is per-vertex (COLOR_0): gold coat, dark brindle and dorsal stripe, cream
belly, darker ruff roots with bright tips; the post-import script
tamlin_beast_import.gd turns vertex colour on in Godot.

Rig: quadruped (Root, Hips, Spine1-3, Neck1-2, Head, Jaw, LipLeft/Right, EarLeft/Right,
Tail1-6, Front/Back Left/Right Upper/Lower/Foot/Toe).  Clips are keyed procedurally
with planar leg IK onto planted paw targets, so gait stance paws slide back at
exactly the authored ground speed (foot-locked, no root motion).

Conventions: Blender Z up, faces -Y, feet on the origin.  glTF faces +Z;
tamlin_beast_model.tscn turns the instance 180 degrees so the game sees it face -Z.
"""

import math
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "feyre"))

import bpy  # noqa: E402  (before bmesh)
import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Quaternion, Vector, kdtree  # noqa: E402

import sdf  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_DIR = os.path.join(REPO, "characters", "tamlin", "beast")
LINEUP = "/mnt/project-files/art/cast/tamlin_beast_lineup.png"
GRID_H = 0.0050
# Final size: the sculpt is authored at a 1.6 m shoulder; the export is scaled up so his back is level
# with Tamlin's head (shoulder ~1.95 m, horns ~2.6 m) and a touch broader.  Authored gait speeds scale too.
BEAST_SCALE = 1.23
BEAST_WIDEN = 1.10
TRI_BUDGET = 15000
DETAIL_TRIS = 4300          # head share of the body triangles
LOD1_RATIO = 0.5
SEED = 1717
FPS = 30
SIDES = (("Left", 1.0), ("Right", -1.0))
LEGS = [(fb, side, s) for fb in ("Front", "Back") for side, s in SIDES]

rng = np.random.default_rng(SEED)


# --------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------
def smooth(e0, e1, x):
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def sm(e0, e1, x):
    return float(smooth(e0, e1, x))


def env(t, a, m, b):
    return sm(a, m, t) * (1.0 - sm(m, b, t))


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return np.array([x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c])


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def select_only(objs, active):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


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


def verts_np(me):
    a = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def rot_x(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def write_png(path, rgba):
    """rgba: (H, W, 4) floats 0..1, top row first."""
    a = (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8)
    h, w = a.shape[:2]
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(h))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def make_material(name, rgb, rough=0.8, metal=0.0, image=None, emit=0.0, use_vcol=True):
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if image is not None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if emit > 0:
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = emit
    elif use_vcol:
        ca = nt.nodes.new("ShaderNodeVertexColor")
        ca.layer_name = "Col"
        nt.links.new(ca.outputs["Color"], bsdf.inputs["Base Color"])
    mat.diffuse_color = (*rgb, 1.0)
    return mat


# --------------------------------------------------------------------------
# Skeleton  (name, head, tail, parent).  Left side is +X, forward is -Y.
# --------------------------------------------------------------------------
TAIL_PTS = [(0, 0.66, 1.31), (0, 0.86, 1.24), (0, 1.05, 1.11), (0, 1.23, 0.98),
            (0, 1.40, 0.89), (0, 1.56, 0.86), (0, 1.71, 0.89)]


def skeleton_spec():
    S = []

    def b(n, h, t, p):
        S.append((n, tuple(map(float, h)), tuple(map(float, t)), p))

    b("Root", (0, 0, 0), (0, -0.30, 0), None)
    b("Hips", (0, 0.45, 1.24), (0, 0.14, 1.28), "Root")
    b("Spine1", (0, 0.14, 1.28), (0, -0.14, 1.33), "Hips")
    b("Spine2", (0, -0.14, 1.33), (0, -0.42, 1.37), "Spine1")
    b("Spine3", (0, -0.42, 1.37), (0, -0.68, 1.38), "Spine2")
    b("Neck1", (0, -0.68, 1.38), (0, -0.86, 1.35), "Spine3")
    b("Neck2", (0, -0.86, 1.35), (0, -1.00, 1.30), "Neck1")
    b("Head", (0, -1.00, 1.32), (0, -1.37, 1.30), "Neck2")
    b("Jaw", (0, -1.06, 1.27), (0, -1.35, 1.19), "Head")
    for side, s in SIDES:
        b("Lip" + side, (s * 0.035, -1.16, 1.37), (s * 0.035, -1.33, 1.33), "Head")
        b("Ear" + side, (s * 0.125, -1.09, 1.47), (s * 0.185, -1.07, 1.73), "Head")
    for i in range(6):
        b("Tail%d" % (i + 1), TAIL_PTS[i], TAIL_PTS[i + 1], "Hips" if i == 0 else "Tail%d" % i)
    for side, s in SIDES:
        x = s * 0.22
        f = "Front" + side
        b(f + "Upper", (x, -0.62, 1.14), (x, -0.47, 0.72), "Spine3")
        b(f + "Lower", (x, -0.47, 0.72), (x, -0.57, 0.21), f + "Upper")
        b(f + "Foot", (x, -0.57, 0.21), (x, -0.66, 0.06), f + "Lower")
        b(f + "Toe", (x, -0.66, 0.06), (x, -0.79, 0.045), f + "Foot")
        k = "Back" + side
        b(k + "Upper", (x, 0.52, 1.12), (x, 0.36, 0.72), "Hips")
        b(k + "Lower", (x, 0.36, 0.72), (x, 0.73, 0.37), k + "Upper")
        b(k + "Foot", (x, 0.73, 0.37), (x, 0.66, 0.06), k + "Lower")
        b(k + "Toe", (x, 0.66, 0.06), (x, 0.53, 0.045), k + "Foot")
    return S


SPEC = skeleton_spec()
BONE = {n: (np.array(h), np.array(t), p) for n, h, t, p in SPEC}


def zm(y):
    """Mouth line height: the gape curls up toward the eye at the back (too-long jaw)."""
    u = np.clip((np.asarray(y, float) + 1.36) / 0.26, 0.0, 1.2)
    return 1.222 + 0.05 * u ** 2


MOUTH_BACK = -1.08
TOE_OX = (-0.074, -0.026, 0.026, 0.074)


# --------------------------------------------------------------------------
# Sculpt (records every op so regions can be re-evaluated at mesh vertices)
# --------------------------------------------------------------------------
class Sculpt:
    def __init__(self, lo, hi, h):
        self.grid = sdf.Grid(lo, hi, h)
        self.ops = []

    def add(self, prim, k=0.0, tag="body"):
        self.grid.union(prim, k)
        self.ops.append(("u", prim[0], k, tag))

    def cut(self, prim, k=0.0, tag="cut"):
        self.grid.subtract(prim, k)
        self.ops.append(("s", prim[0], k, tag))

    def eval(self, P, skip=()):
        X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
        d = np.full(len(P), sdf.Grid.FAR)
        for op, f, k, tag in self.ops:
            if tag in skip:
                continue
            v = f(X, Y, Z)
            d = sdf.smin(d, v, k) if op == "u" else sdf.smax(d, -v, k)
        return d


def rbox(c, b, r, taper=0.0):
    """Rounded box; `taper` narrows its width toward the front (-Y)."""
    c = np.asarray(c, float)
    b = np.asarray(b, float)

    def f(X, Y, Z):
        t = np.clip((c[1] - Y) / b[1], -1.0, 1.0)
        bx = b[0] * (1.0 - taper * 0.5 * (t + 1.0))
        qx = np.abs(X - c[0]) - bx
        qy = np.abs(Y - c[1]) - b[1]
        qz = np.abs(Z - c[2]) - b[2]
        out = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2 + np.maximum(qz, 0) ** 2)
        return out + np.minimum(np.maximum(np.maximum(qx, qy), qz), 0) - r
    e = b + r
    return f, (c - e, c + e)


def ell(c, r, rot=None):
    return sdf.ellipsoid(c, r, rot)


def rc(a, b, ra, rb):
    return sdf.round_cone(a, b, ra, rb)


def clump(S, base, direction, length, r0, curl=(0, 0, -0.25), tag="clump", k=0.014):
    """A tapering clump of heavy fur: two round cones with a slight droop."""
    d = np.asarray(direction, float)
    d = d / np.linalg.norm(d)
    base = np.asarray(base, float)
    mid = base + d * length * 0.55
    tip = base + d * length + np.asarray(curl) * length * 0.35
    S.add(rc(base, mid, r0, r0 * 0.55), k, tag)
    S.add(rc(mid, tip, r0 * 0.55, max(0.0075, r0 * 0.16)), 0.008, tag)   # rounded tips survive decimation unfaceted


def jit(n=3, a=0.25):
    return rng.uniform(-a, a, n)


def sculpt_body():
    S = Sculpt((-0.56, -1.62, -0.03), (0.56, 2.02, 1.86), GRID_H)
    A = S.add
    # ---- torso: deep chest, withers hump, massive shoulders, tucked gaunt waist
    A(ell((0, -0.50, 1.17), (0.31, 0.37, 0.41)))
    A(ell((0, -0.47, 1.45), (0.22, 0.34, 0.17)), 0.10)
    for side, s in SIDES:
        A(ell((s * 0.20, -0.57, 1.30), (0.135, 0.24, 0.32), rot_x(-22)), 0.06)     # scapula mass
        A(ell((s * 0.225, -0.66, 1.06), (0.135, 0.16, 0.18)), 0.05)                 # shoulder joint
    A(ell((0, -0.12, 1.20), (0.265, 0.42, 0.32)), 0.10)                           # ribcage
    A(rc((0, 0.10, 1.26), (0, 0.42, 1.25), 0.205, 0.215), 0.10)                   # waist
    A(ell((0, 0.52, 1.20), (0.235, 0.26, 0.26)), 0.08)                            # croup
    for side, s in SIDES:
        A(ell((s * 0.165, 0.50, 1.00), (0.115, 0.20, 0.27), rot_x(18)), 0.06)    # haunch
    # ---- neck (forward and down: low predatory carriage)
    A(rc((0, -0.62, 1.38), (0, -0.88, 1.33), 0.25, 0.185), 0.08)
    A(rc((0, -0.88, 1.33), (0, -1.02, 1.29), 0.185, 0.15), 0.06)
    A(rc((0, -0.50, 1.40), (0, -0.86, 1.33), 0.30, 0.20), 0.08, "ruff")      # shaggy neck mass
    # ---- head: wolf skull (domed cranium, hard stop, short deep boxy muzzle), made monstrous
    A(ell((0, -1.04, 1.36), (0.17, 0.17, 0.16)), 0.05, "head")                   # domed cranium
    A(ell((0, -1.10, 1.43), (0.12, 0.10, 0.08)), 0.05, "head")                   # forehead dome
    A(rbox((0, -1.265, 1.305), (0.072, 0.095, 0.055), 0.032, taper=0.25), 0.035, "head")  # upper muzzle
    A(ell((0, -1.372, 1.338), (0.056, 0.036, 0.042)), 0.012, "head")             # nose pad
    for side, s in SIDES:
        A(ell((s * 0.078, -1.19, 1.432), (0.068, 0.058, 0.038), rot_x(-10)), 0.025, "head")  # brow ridge
        A(ell((s * 0.112, -1.13, 1.335), (0.062, 0.08, 0.052)), 0.03, "head")              # cheekbone
        A(ell((s * 0.125, -1.04, 1.27), (0.072, 0.09, 0.09)), 0.04, "head")                # jaw muscle
        e0 = np.array([s * 0.125, -1.09, 1.46])
        A(rc(e0, (s * 0.185, -1.07, 1.735), 0.058, 0.007), 0.02, "ear")
        A(ell((s * 0.155, -1.08, 1.575), (0.026, 0.06, 0.12), rot_x(-4)), 0.02, "ear")
    A(rbox((0, -1.25, 1.19), (0.055, 0.10, 0.03), 0.025, taper=0.2), 0.03, "head")   # lower jaw
    A(ell((0, -1.12, 1.215), (0.075, 0.08, 0.06)), 0.04, "head")                  # jaw angle
    # ---- legs (tendons and knobbly joints suggested)
    for side, s in SIDES:
        x = s * 0.22
        A(rc((x, -0.62, 1.12), (x, -0.47, 0.73), 0.155, 0.10), 0.06)
        A(sdf.sphere((x, -0.445, 0.73), 0.075), 0.03)                            # elbow point
        A(rc((x, -0.47, 0.72), (x, -0.565, 0.23), 0.095, 0.06), 0.04)
        A(ell((x, -0.50, 0.55), (0.085, 0.08, 0.16)), 0.04)                      # forearm muscle
        A(rc((x, -0.44, 0.62), (x, -0.545, 0.25), 0.022, 0.016), 0.02)           # flexor tendon
        A(rc((x, -0.57, 0.22), (x, -0.655, 0.07), 0.055, 0.05), 0.03)
        A(ell((x, -0.69, 0.066), (0.125, 0.13, 0.072)), 0.03)                   # front paw
        A(rc((x, 0.52, 1.10), (x, 0.36, 0.73), 0.165, 0.10), 0.06)
        A(rc((x, 0.36, 0.72), (x, 0.725, 0.38), 0.092, 0.052), 0.04)
        A(ell((x, 0.47, 0.62), (0.08, 0.10, 0.12), rot_x(40)), 0.04)             # gaskin
        A(rc((x, 0.55, 0.66), (x, 0.775, 0.39), 0.026, 0.02), 0.025)             # achilles tendon
        A(sdf.sphere((x, 0.765, 0.385), 0.042), 0.02)                            # hock point
        A(rc((x, 0.73, 0.37), (x, 0.665, 0.07), 0.046, 0.048), 0.03)
        A(ell((x, 0.60, 0.064), (0.115, 0.125, 0.068)), 0.03)                     # hind paw
        for fb, yc, dy in (("Front", -0.775, -1), ("Back", 0.515, -1)):
            for j, ox in enumerate(TOE_OX):
                back = 0.024 if j in (0, 3) else 0.0
                A(sdf.sphere((x + ox, yc + back, 0.048), 0.048 if fb == "Front" else 0.044), 0.015)
    # ---- tail
    radii = [0.085, 0.065, 0.052, 0.044, 0.038, 0.034, 0.030]
    A(sdf.tube([np.array(p) for p in TAIL_PTS], radii), 0.05)

    # ---- fur: ragged ruff, cheek ruff, mane, elbow and fetlock tufts, tail tuft
    n0, n1 = np.array([0, -0.54, 1.42]), np.array([0, -0.92, 1.31])
    ax = (n1 - n0) / np.linalg.norm(n1 - n0)
    for ri, t in enumerate(np.linspace(0.0, 1.0, 9)):
        c = n0 + (n1 - n0) * t
        R = 0.25 + (0.16 - 0.25) * t
        cnt = 14
        for j in range(cnt):
            th = 2 * math.pi * (j + 0.5 * (ri % 2)) / cnt + jit(1, 0.12)[0]
            if t > 0.8 and math.cos(th) > 0.35:
                continue
            radial = np.array([math.sin(th), 0.0, math.cos(th)])
            radial = radial - ax * radial.dot(ax)
            radial /= np.linalg.norm(radial)
            top = max(0.0, radial[2])
            under = max(0.0, -radial[2])
            base = c + radial * R * 1.05
            dirn = radial * 0.45 + np.array([0, 1.0, 0]) + np.array([0, 0, 0.1 - 0.5 * under]) + jit(3, 0.22)
            length = (0.16 + 0.15 * top + 0.08 * under) * (0.75 + 0.5 * math.sin(math.pi * t)) * rng.uniform(0.8, 1.2)
            clump(S, base, dirn, length * 0.85, rng.uniform(0.055, 0.075), k=0.03)
    for side, s in SIDES:
        for j in range(11):
            u = j / 10.0
            base = np.array([s * (0.155 - 0.07 * u), -1.03 + 0.03 * u, 1.43 - 0.30 * u]) + jit(3, 0.008)
            clump(S, base, np.array([s * (0.9 - 0.4 * u), 0.8, 0.15 - 0.6 * u]) + jit(3, 0.18),
                  rng.uniform(0.14, 0.22), rng.uniform(0.04, 0.052), k=0.02)
    for j in range(6):
        base = np.array([-0.07 + 0.028 * j, -1.08 + 0.02 * (j % 2), 1.15]) + jit(3, 0.008)
        clump(S, base, np.array([0, 0.5, -1.0]) + jit(3, 0.2), rng.uniform(0.12, 0.18), 0.045, k=0.02)
    for j in range(12):
        y = -0.60 + 0.06 * j
        base = np.array([((j % 2) - 0.5) * 0.06, y, 1.62 - 0.012 * j - 0.25 * max(0.0, y + 0.1) ** 2])
        clump(S, base, np.array([0, 0.9, 0.55]) + jit(3, 0.2), rng.uniform(0.10, 0.18) * (1.0 - j / 18.0),
              rng.uniform(0.032, 0.042))
    for side, s in SIDES:
        x = s * 0.22
        for j in range(3):
            clump(S, (x + s * 0.02 * j - s * 0.02, -0.43, 0.76), np.array([s * 0.2, 1.0, 0.25]) + jit(3, 0.2),
                  rng.uniform(0.08, 0.11), 0.03)
            clump(S, (x - s * 0.03 + s * 0.03 * j, -0.535, 0.26), np.array([s * 0.15, 1.0, -0.55]) + jit(3, 0.2),
                  rng.uniform(0.08, 0.11), 0.028)
            clump(S, (x - s * 0.03 + s * 0.03 * j, 0.735, 0.30), np.array([s * 0.15, 1.0, -0.6]) + jit(3, 0.2),
                  rng.uniform(0.07, 0.10), 0.026)
    tp = [np.array(p, float) for p in TAIL_PTS]
    for j in range(16):
        t = 0.55 + 0.45 * j / 15.0
        seg = min(5, int(t * 6))
        u = t * 6 - seg
        c = tp[seg] + (tp[seg + 1] - tp[seg]) * u
        along = (tp[seg + 1] - tp[seg]) / np.linalg.norm(tp[seg + 1] - tp[seg])
        th = 2.4 * j
        radial = np.array([math.sin(th), 0.0, math.cos(th)])
        radial -= along * radial.dot(along)
        radial /= np.linalg.norm(radial)
        clump(S, c + radial * 0.02, along * 1.2 + radial * 0.7 + jit(3, 0.15), rng.uniform(0.12, 0.2),
              0.036, curl=(0, 0, -0.1))

    # ---- body fur: short heavy tufts lying back along shoulders, back, flanks, haunches
    g = S.grid
    for j in range(150):
        p = np.array([rng.uniform(-0.3, 0.3), rng.uniform(-0.75, 0.72), rng.uniform(1.0, 1.7)])
        for _ in range(6):
            d = g.sample(p[None])[0]
            e = 0.004
            grad = np.array([(g.sample((p + dv)[None])[0] - d) / e for dv in np.eye(3) * e])
            nrm = grad / (np.linalg.norm(grad) + 1e-9)
            p = p - nrm * d
        if abs(g.sample(p[None])[0]) > 0.01 or nrm[2] < -0.3:
            continue
        back = np.array([0, 1.0, -0.25])
        back = back - nrm * back.dot(nrm)
        clump(S, p - nrm * 0.012, back + nrm * 0.35 + jit(3, 0.2), rng.uniform(0.07, 0.12),
              rng.uniform(0.026, 0.034), curl=(0, 0, -0.1), k=0.012)

    # ---- head coat: small tufts lying back over cranium and cheeks (behind the brow)
    for j in range(90):
        p = np.array([rng.uniform(-0.2, 0.2), rng.uniform(-1.16, -0.94), rng.uniform(1.24, 1.56)])
        for _ in range(6):
            d = g.sample(p[None])[0]
            e = 0.003
            grad = np.array([(g.sample((p + dv)[None])[0] - d) / e for dv in np.eye(3) * e])
            nrm = grad / (np.linalg.norm(grad) + 1e-9)
            p = p - nrm * d
        if abs(g.sample(p[None])[0]) > 0.008 or p[1] < -1.17 or (abs(p[0]) > 0.1 and p[2] > 1.45):
            continue
        back = np.array([0, 1.0, -0.1]) + np.array([np.sign(p[0]) * 0.3, 0, 0])
        back = back - nrm * back.dot(nrm)
        clump(S, p - nrm * 0.008, back + nrm * 0.3 + jit(3, 0.2), rng.uniform(0.045, 0.07),
              rng.uniform(0.016, 0.022), curl=(0, 0, -0.1), k=0.008)

    # ---- carving: eye sockets, nostrils, rib grooves, then the mouth slit
    eyes = []
    for side, s in SIDES:
        n = np.array([s * 0.36, -0.93, 0.06])
        n /= np.linalg.norm(n)
        c0 = np.array([s * 0.05, -1.12, 1.385])
        p = c0.copy()
        for _ in range(200):
            if S.grid.sample(p[None])[0] > 0:
                break
            p += n * 0.002
        er = 0.030
        ec = p - n * er * 0.50
        eyes.append((ec, n, er))
        S.cut(sdf.sphere(ec, er * 1.10), 0.012, "socket")
    for side, s in SIDES:
        S.cut(sdf.sphere((s * 0.022, -1.405, 1.335), 0.0125), 0.005, "socket")
        for j in range(5):
            y = -0.30 + 0.105 * j
            S.cut(rc((s * 0.292, y, 1.36), (s * 0.270, y + 0.06, 1.02), 0.026, 0.022), 0.025, "rib")

    def slit(X, Y, Z):
        g = 0.0125
        slope = 0.05 * 2 * np.clip((Y + 1.36) / 0.26, 0, 1.2) / 0.26
        return np.maximum((np.abs(Z - zm(Y)) - g) / np.sqrt(1 + slope ** 2), Y - MOUTH_BACK)

    S.cut(sdf.custom(slit, (-0.2, -1.50, 1.15), (0.2, MOUTH_BACK + 0.01, 1.34)), 0.0, "slit")
    return S, eyes


# --------------------------------------------------------------------------
# Body mesh
# --------------------------------------------------------------------------
def head_detail(P):
    return smooth(-0.90, -1.00, P[:, 1]) * (P[:, 2] > 0.95)


def build_body(S, max_tris):
    V, Q = sdf.surface_nets(S.grid)
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
    smod = body.modifiers.new("Smooth", "SMOOTH")
    smod.iterations = 5
    smod.factor = 0.5
    bake_modifiers(body)
    print("surface nets tris:", tri_count(body))

    def collapse(weights, ratio):
        g = body.vertex_groups.new(name="collapse")
        for i in np.nonzero(weights > 0.0)[0]:
            g.add([int(i)], float(weights[i]), "REPLACE")
        d = body.modifiers.new("Decimate", "DECIMATE")
        d.ratio = min(1.0, ratio)
        d.vertex_group = "collapse"
        bake_modifiers(body)
        body.vertex_groups.clear()

    detail = head_detail(verts_np(body.data)) > 0.5
    n = tri_count(body)
    dt = n * float(detail.mean())
    collapse(detail.astype(float), (n - dt + DETAIL_TRIS) / n)
    detail = head_detail(verts_np(body.data)) > 0.5
    collapse((~detail).astype(float), max_tris / tri_count(body))
    # keep only the largest shell
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    seen, islands = set(), []
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
    bmesh.ops.delete(bm, geom=[v for isl in islands[1:] for v in isl], context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(body.data)
    bm.free()
    body.data.validate()
    print("body tris:", tri_count(body), "islands dropped:", len(islands) - 1)
    return body


def coat_colours(S, P, N):
    gold = srgb("#C8862A")
    gold_hi = srgb("#E4A443")
    brindle = srgb("#3A1F08")
    cream = srgb("#E2C48C")
    ruff_root = srgb("#5E3610")
    tip = srgb("#F4C766")
    lip = srgb("#1A0B09")
    nose = srgb("#0E0B0B")
    paw = srgb("#4A2E12")
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    C = np.tile(gold, (len(P), 1))
    # sun-lit top, cream belly / throat / inner legs
    C = C + (gold_hi - gold) * smooth(0.2, 0.9, N[:, 2])[:, None] * 0.5
    belly = smooth(0.0, -0.7, N[:, 2]) * smooth(0.6, 1.1, z) * (y > -0.95)
    C = C + (cream - C) * (belly * 0.75)[:, None]
    # fur clumps: darker heavy roots, bright ragged tips
    d_base = S.eval(P, skip=("clump", "ruff"))
    fur = smooth(0.004, 0.16, d_base)
    in_ruff = (d_base > 0.004)
    C = np.where(in_ruff[:, None], ruff_root + (tip - ruff_root) * fur[:, None], C)
    # brindle stripes and a dark dorsal stripe over the back, flanks and haunches
    warp = 5.0 * np.sin(3.1 * z + 2.3 * np.abs(x)) + 3.0 * np.sin(7.3 * y + 1.7)
    st = smooth(0.0, 0.6, np.sin(26.0 * y + warp + 9.0 * np.abs(x) * (z - 1.0)))
    flank = smooth(0.95, 1.40, z) * smooth(-0.85, -0.60, y) * smooth(0.95, 0.70, y) + \
        smooth(0.5, 1.1, z) * smooth(0.30, 0.42, y) * smooth(0.80, 0.68, y)
    st = st * np.clip(flank, 0, 1) * (~in_ruff)
    C = C + (brindle - C) * (0.95 * st)[:, None]
    dorsal = smooth(0.16, 0.03, np.abs(x)) * smooth(-0.15, 0.5, N[:, 2]) * smooth(-0.95, -0.5, y) * (y < 1.0)
    C = C + (brindle - C) * (0.8 * dorsal)[:, None]
    # dark lower legs and paws, darker ear backs and tail tip
    C = C + (paw - C) * (0.85 * smooth(0.60, 0.12, z))[:, None]
    d_ear = S.eval(P, skip=("clump", "slit", "socket", "rib", "body", "head", "ruff"))
    ear = smooth(0.02, 0.004, d_ear) * smooth(1.47, 1.55, z)
    C = C + (brindle * 0.6 - C) * (0.9 * ear)[:, None]
    # muzzle: darker towards the nose; black wet lips along the whole gape
    head = (y < -1.0)
    muzzle = smooth(-1.18, -1.36, y) * head
    C = C + (srgb("#5A3B1C") - C) * (0.6 * muzzle)[:, None]
    zl = zm(y)
    rag = 0.012 * (0.5 + 0.5 * np.sin(y * 140.0) * np.sin(y * 57.0 + 1.0))   # ragged black lips
    lipband = smooth(0.030 + rag, 0.012, np.abs(z - zl)) * (y < MOUTH_BACK + 0.04)
    C = C + (lip - C) * lipband[:, None]
    nosem = smooth(0.075, 0.05, np.linalg.norm((P - np.array([0, -1.372, 1.338])) * np.array([1, 1.4, 1]), axis=1))
    C = C + (nose - C) * nosem[:, None]
    # brow shadow around the eyes (menacing glare)
    for s in (1, -1):
        de = np.linalg.norm(P - np.array([s * 0.08, -1.19, 1.39]), axis=1)
        C = C * (1.0 - 0.65 * smooth(0.08, 0.03, de))[:, None]
    return np.clip(C, 0, 1)


# --------------------------------------------------------------------------
# Parts: horns, teeth, claws, eyes (each a small bmesh object, rigid on one bone)
# --------------------------------------------------------------------------
def frame_from(axis):
    a = Vector(axis).normalized()
    ref = Vector((0, 0, 1)) if abs(a.z) < 0.9 else Vector((1, 0, 0))
    u = a.cross(ref).normalized()
    v = a.cross(u).normalized()
    return a, u, v


def sweep(bm, pts, radii, sides, cols, cap_tip=True, ripple=0.0):
    """Tube through pts (list of Vector) with per-point radius and colour."""
    rings = []
    prev_u = None
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        if prev_u is None:
            _, u, _ = frame_from(d)
        else:
            u = (prev_u - d * prev_u.dot(d)).normalized()
        v = d.cross(u)
        prev_u = u
        r = radii[i] * (1.0 + ripple * math.sin(i * 2.1))
        ring = []
        for k in range(sides):
            th = 2 * math.pi * k / sides
            vert = bm.verts.new(p + (u * math.cos(th) + v * math.sin(th)) * r)
            ring.append(vert)
        rings.append((ring, cols[i]))
    out = []
    for i in range(len(rings) - 1):
        a, b = rings[i][0], rings[i + 1][0]
        for k in range(sides):
            out.append(bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k])))
    tipv = None
    if cap_tip:
        last = rings[-1][0]
        d = (pts[-1] - pts[-2]).normalized()
        tipv = bm.verts.new(pts[-1] + d * radii[-1] * 1.5)
        for k in range(sides):
            out.append(bm.faces.new((last[k], last[(k + 1) % sides], tipv)))
    first = rings[0][0]
    out.append(bm.faces.new(list(reversed(first))))
    colmap = {}
    for ring, c in rings:
        for vv in ring:
            colmap[vv] = c
    if tipv is not None:
        colmap[tipv] = rings[-1][1]
    return colmap


def catmull(ctrl, n):
    P = [Vector(c) for c in ctrl]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    segs = len(P) - 3
    for i in range(n):
        t = i / (n - 1) * segs
        k = min(int(t), segs - 1)
        u = t - k
        p0, p1, p2, p3 = P[k], P[k + 1], P[k + 2], P[k + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u
                          + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u))
    return out


class Part:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.cols = {}
        self.bone = {}   # vert -> bone name

    def finish(self, mat, uv_fn=None):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bm.verts.index_update()
        cols = [self.cols.get(v, (1, 1, 1)) for v in bm.verts]
        bones = [self.bone.get(v, "Head") for v in bm.verts]
        if uv_fn is not None:
            uvl = bm.loops.layers.uv.new("UVMap")
            for f in bm.faces:
                for lp in f.loops:
                    lp[uvl].uv = uv_fn(lp.vert.co)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        if not me.uv_layers:
            me.uv_layers.new(name="UVMap")
        obj = link(bpy.data.objects.new(self.name, me))
        set_colours(obj, np.array(cols, float))
        obj.data.materials.append(mat)
        for p in me.polygons:
            p.use_smooth = True
        for vi, b in enumerate(bones):
            g = obj.vertex_groups.get(b) or obj.vertex_groups.new(name=b)
            g.add([vi], 1.0, "REPLACE")
        return obj


def set_colours(obj, C):
    me = obj.data
    if "Col" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["Col"])
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    rgba = np.concatenate([C, np.ones((len(C), 1))], axis=1).astype(np.float32)
    ca.data.foreach_set("color", rgba.ravel())
    me.color_attributes.active_color = ca
    me.color_attributes.render_color_index = me.color_attributes.find("Col")


def build_horns(mat):
    part = Part("Horns")
    black = srgb("#100c0b")
    bone = srgb("#D9CDAE")
    for side, s in SIDES:
        beam = [(s * 0.06, -1.03, 1.49), (s * 0.11, -0.94, 1.57), (s * 0.17, -0.83, 1.65),
                (s * 0.23, -0.77, 1.79), (s * 0.27, -0.81, 1.93), (s * 0.28, -0.90, 2.03)]
        pts = catmull(beam, 15)
        n = len(pts)
        radii = [0.062 * (1 - i / n) ** 0.8 + 0.008 for i in range(n)]
        cols = [tuple(black + (bone - black) * sm(0.55, 1.0, i / (n - 1))) for i in range(n)]
        cm = sweep(part.bm, pts, radii, 8, cols, ripple=0.06)
        part.cols.update(cm)
        tines = [
            (5, [(s * 0.035, -0.08, 0.05), (s * 0.04, -0.15, 0.11), (s * 0.03, -0.18, 0.18)], 0.030),
            (9, [(s * 0.01, -0.07, 0.06), (s * 0.0, -0.12, 0.13), (s * -0.02, -0.14, 0.20)], 0.024),
            (12, [(s * 0.03, -0.05, 0.07), (s * 0.05, -0.06, 0.14)], 0.018),
        ]
        for idx, offs, r0 in tines:
            b0 = pts[idx]
            ctrl = [b0] + [b0 + Vector(o) for o in offs]
            tp = catmull([tuple(c) for c in ctrl], 7)
            m = len(tp)
            tr = [r0 * (1 - i / m) + 0.004 for i in range(m)]
            base_t = idx / (n - 1)
            tc = [tuple(black + (bone - black) * sm(0.45, 1.0, base_t * 0.5 + 0.5 * i / (m - 1)))
                  for i in range(m)]
            part.cols.update(sweep(part.bm, tp, tr, 6, tc))
    return part.finish(mat)


def contour(S, z_of_y, y_back, y_front, steps=24):
    """Outline of the muzzle (left side) in a near-horizontal slice, back -> front."""
    g = S.grid
    out = []
    for y in np.linspace(y_back, y_front, steps):
        z = z_of_y(y)
        xs = np.linspace(0.0, 0.2, 201)
        d = g.sample(np.stack([xs, np.full_like(xs, y), np.full_like(xs, z)], 1))
        inside = np.nonzero(d < 0)[0]
        if len(inside) == 0:
            continue
        out.append(Vector((xs[inside[-1]], y, z)))
    # round the front: march forward along -y for small x
    last = out[-1]
    for x in np.linspace(last.x * 0.8, 0.008, 5):
        ys = np.linspace(-1.25, -1.55, 301)
        z = z_of_y(-1.34)
        d = g.sample(np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1))
        inside = np.nonzero(d < 0)[0]
        if len(inside):
            out.append(Vector((x, ys[inside[-1]], z)))
    return out


def along(poly, t):
    L = [0.0]
    for a, b in zip(poly[:-1], poly[1:]):
        L.append(L[-1] + (b - a).length)
    target = t * L[-1]
    for i in range(len(poly) - 1):
        if L[i + 1] >= target:
            u = (target - L[i]) / max(L[i + 1] - L[i], 1e-9)
            return poly[i].lerp(poly[i + 1], u), (poly[i + 1] - poly[i]).normalized()
    return poly[-1], (poly[-1] - poly[-2]).normalized()


def tooth(part, root, tip, r, hook, cols, bone):
    ax = tip - root
    pts = [root, root + ax * 0.45 + hook * 0.3, tip + hook]
    radii = [r, r * 0.72, 0.0012]
    cm = sweep(part.bm, pts, radii, 6, cols, cap_tip=True)
    part.cols.update(cm)
    for v in cm:
        part.bone[v] = bone


def build_teeth(S, mat, gum_mat):
    part = Part("Teeth")
    ivory = srgb("#E3CB7C")
    stain = srgb("#7A5A22")
    cols = [tuple(stain), tuple(ivory * 0.9 + stain * 0.1), tuple(ivory)]
    # (position along the jaw edge: 1 = front, length); canines dominate
    upper = [(0.985, 0.024), (0.94, 0.026), (0.895, 0.03), (0.80, 0.105),
             (0.62, 0.03), (0.47, 0.042), (0.32, 0.036), (0.17, 0.05)]
    lower = [(0.975, 0.02), (0.93, 0.022), (0.875, 0.026), (0.76, 0.078),
             (0.55, 0.03), (0.37, 0.036), (0.20, 0.03)]
    up_c = contour(S, lambda y: float(zm(y)) + 0.02, -1.10, -1.33)
    lo_c = contour(S, lambda y: float(zm(y)) - 0.02, -1.10, -1.32)
    for side, s in SIDES:
        for poly, lens, sign, bone, inset in ((up_c, upper, -1, "Head", 0.011), (lo_c, lower, 1, "Jaw", 0.010)):
            for t, ln in lens:
                p, tang = along(poly, t)
                p = Vector((s * max(p.x - inset, 0.006), p.y + (0.006 if p.x < 0.03 else 0.0), p.z))
                root = p + Vector((0, 0, -sign * 0.022))
                tip = p + Vector((0, 0, sign * ln))
                big = ln > 0.06
                rake = Vector((s * 0.003, 0.01 * ln / 0.03, 0)) if sign < 0 else Vector((s * 0.002, -0.008, 0))
                hook = Vector((0, 0.22 * ln, 0)) if big and sign < 0 else Vector((0, -0.1 * ln if big else 0.05 * ln, 0))
                r = 0.005 + ln * (0.15 if big else 0.13)
                tooth(part, root, tip + rake, r, hook, cols, bone)
    teeth = part.finish(mat)
    # wet dark-red gums along both tooth rows: hidden by the lips at rest, bared in a snarl
    gum = Part("Gums")
    red = (1.0, 1.0, 1.0)
    for side, s in SIDES:
        for poly, dz, bone, inset in ((up_c, 0.004, "Head", 0.012), (lo_c, -0.004, "Jaw", 0.011)):
            pts = [Vector((s * max(q.x - inset, 0.004), q.y, q.z + dz)) for q in poly[::2]]
            cm = sweep(gum.bm, pts, [0.014] * len(pts), 6, [red] * len(pts))
            gum.cols.update(cm)
            for v in cm:
                gum.bone[v] = bone
    return teeth, gum.finish(gum_mat)


def build_claws(mat):
    part = Part("Claws")
    black = srgb("#060505")
    tipc = srgb("#3a3430")
    for fb, side, s in LEGS:
        x = s * 0.22
        yc = -0.775 if fb == "Front" else 0.515
        for j, ox in enumerate(TOE_OX):
            back = 0.024 if j in (0, 3) else 0.0
            c = Vector((x + ox, yc + back - 0.008, 0.054))
            sc = 1.0 if fb == "Front" else 0.85
            ctrl = [c + Vector((0, 0.01, 0.006)), c + Vector((ox * 0.1, -0.035, 0.018)) * 1,
                    c + Vector((ox * 0.15, -0.065 * sc, 0.004)), c + Vector((ox * 0.15, -0.078 * sc, -0.030))]
            pts = catmull([tuple(p) for p in ctrl], 5)
            radii = [0.015 * sc * (1 - i / 5) + 0.0015 for i in range(5)]
            cm = sweep(part.bm, pts, radii, 5, [tuple(black + (tipc - black) * (i / 4)) for i in range(5)])
            part.cols.update(cm)
            for v in cm:
                part.bone[v] = fb + side + "Toe"
    return part.finish(mat)


def bake_iris(path, size=128):
    yy, xx = np.mgrid[0:size, 0:size]
    u = (xx + 0.5) / size * 2 - 1
    v = 1 - (yy + 0.5) / size * 2
    r = np.sqrt(u * u + v * v)
    green = srgb("#47FF5A")
    deep = srgb("#0B6B1A")
    amber = srgb("#FFB020")
    C = deep[None, None] + (green - deep)[None, None] * smooth(0.95, 0.25, r)[..., None]
    ang = np.arctan2(v, u)
    fl = (np.sin(ang * 23.0) * np.sin(ang * 7.0 + 1.3) > 0.45) * smooth(0.55, 0.2, r) * smooth(0.08, 0.2, np.abs(u))
    C = C + (amber - C) * (0.85 * fl)[..., None]
    C = C * (1 - 0.85 * smooth(0.82, 1.0, r))[..., None]            # dark limbal ring
    slit = (u / 0.085) ** 2 + (v / 0.80) ** 2
    C = C * smooth(0.75, 1.15, slit)[..., None]                      # vertical slit pupil
    glint = np.exp(-(((u + 0.32) ** 2 + (v - 0.38) ** 2) / 0.006))
    C = np.clip(C + glint[..., None] * 0.9, 0, 1)
    # write sRGB
    Cs = np.where(C <= 0.0031308, C * 12.92, 1.055 * C ** (1 / 2.4) - 0.055)
    write_png(path, np.concatenate([Cs, np.ones((size, size, 1))], axis=2))


def build_eyes(eyes, mat):
    part = Part("Eyes")
    frames = []
    for ec, n, er in eyes:
        res = bmesh.ops.create_uvsphere(part.bm, u_segments=12, v_segments=8, radius=er)
        a, _, _ = frame_from(Vector(n))
        up = Vector((0, 0, 1))
        right = a.cross(up).normalized()
        up = right.cross(a).normalized()
        M = Matrix((right, a, up)).transposed()   # local y -> forward
        for v in res["verts"]:
            local = v.co.copy()
            v.co = Vector(ec) + M @ Vector((local.x, local.z, local.y * 0.78))
            part.cols[v] = (1, 1, 1)
        frames.append((Vector(ec), right, up, er))

    def uv(co):
        ec, right, up, er = min(frames, key=lambda f: (co - f[0]).length)
        d = co - ec
        return (0.5 + d.dot(right) / (2.2 * er), 0.5 + d.dot(up) / (2.2 * er))

    return part.finish(mat, uv)


# --------------------------------------------------------------------------
# Armature + weights
# --------------------------------------------------------------------------
def build_armature():
    arm = bpy.data.armatures.new("Armature")
    obj = link(bpy.data.objects.new("Armature", arm))
    select_only([obj], obj)
    bpy.ops.object.mode_set(mode="EDIT")
    for n, h, t, p in SPEC:
        eb = arm.edit_bones.new(n)
        eb.head, eb.tail, eb.roll = h, t, 0.0
        if p:
            eb.parent = arm.edit_bones[p]
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.bones["Root"].use_deform = False
    arm.display_type = "STICK"
    return obj


def seg_dist(P, H, T):
    d = T - H
    L2 = np.maximum((d * d).sum(1), 1e-12)
    t = np.clip(((P[:, None] - H[None]) * d[None]).sum(-1) / L2[None], 0, 1)
    return np.linalg.norm(P[:, None] - (H[None] + t[..., None] * d[None]), axis=-1)


def distance_weights(P, names, k=3, power=4.0):
    H = np.array([BONE[n][0] for n in names])
    T = np.array([BONE[n][1] for n in names])
    D = seg_dist(P, H, T)
    side = np.array([1 if "Left" in n else (-1 if "Right" in n else 0) for n in names])
    bad = (side[None] != 0) & (side[None] != np.sign(P[:, 0])[:, None]) & (np.abs(P[:, 0])[:, None] > 0.02)
    D = np.where(bad, 1e9, D)
    W = 1.0 / (D ** power + 1e-12)
    idx = np.argsort(-W, axis=1)[:, :k]
    out = []
    for i in range(len(P)):
        ws = W[i, idx[i]]
        ws = ws / ws.sum()
        out.append({names[j]: float(w) for j, w in zip(idx[i], ws) if w > 0.01})
    return out


def weights_of(obj):
    gi = {g.index: g.name for g in obj.vertex_groups}
    return [{gi[g.group]: g.weight for g in v.groups if g.weight > 1e-4} for v in obj.data.vertices]


def set_weights(obj, W, limit=4):
    obj.vertex_groups.clear()
    groups = {}
    for vi, d in enumerate(W):
        items = sorted(d.items(), key=lambda kv: -kv[1])[:limit]
        tot = sum(w for _, w in items) or 1.0
        for n, w in items:
            if n not in groups:
                groups[n] = obj.vertex_groups.new(name=n)
            groups[n].add([vi], w / tot, "REPLACE")


def skin(obj, arm):
    obj.parent = arm
    m = obj.modifiers.get("Armature") or obj.modifiers.new("Armature", "ARMATURE")
    m.object = arm


def weight_body(body, arm, S):
    manual = {"Root", "Jaw", "LipLeft", "LipRight", "EarLeft", "EarRight"}
    for b in arm.data.bones:
        b.use_deform = b.name not in manual
    select_only([body, arm], arm)
    heat_ok = True
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except Exception as e:  # pragma: no cover
        print("heat weighting failed:", e)
        heat_ok = False
    for b in arm.data.bones:
        b.use_deform = b.name != "Root"
    P = verts_np(body.data)
    W = weights_of(body) if heat_ok else [{} for _ in P]
    deform = [n for n, *_ in SPEC if n not in manual]
    empty = [i for i, w in enumerate(W) if sum(w.values()) < 1e-3]
    for i, w in zip(empty, distance_weights(P[empty], deform) if empty else []):
        W[i] = w
    # head: rigid on Head, lower jaw on Jaw, lips and ears on their bones, blending into the neck
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    d_ear = S.eval(P, skip=("clump", "slit", "socket", "rib", "body", "head", "ruff"))
    for i in np.nonzero((y < -0.90) & (z > 0.98))[0]:
        neck = 1.0 - (1.0 - sm(-1.06, -0.93, y[i])) * sm(1.04, 1.14, z[i])
        jaw = 1.0 if (z[i] < zm(y[i]) - 0.001 and y[i] < MOUTH_BACK + 0.02) else 0.0
        jaw *= sm(-0.97, -1.07, y[i])
        if jaw == 0.0 and z[i] < 1.24 and y[i] < -1.0 and y[i] >= MOUTH_BACK:
            jaw = sm(1.24, 1.16, z[i]) * sm(-0.97, -1.07, y[i]) * 0.8   # throat under the hinge
        lipw = 0.0
        if jaw == 0.0 and abs(x[i]) > 0.025 and y[i] < MOUTH_BACK:
            h = z[i] - zm(y[i])
            lipw = sm(0.060, 0.008, h) * sm(MOUTH_BACK, MOUTH_BACK - 0.06, y[i]) * sm(0.025, 0.05, abs(x[i]))
            lipw *= 1.0 - 0.4 * sm(-1.30, -1.36, y[i])
        earw = sm(1.45, 1.52, z[i]) * sm(0.035, 0.008, d_ear[i])
        hw = max(0.0, 1.0 - jaw - lipw - earw)
        d = {"Head": hw}
        if jaw:
            d["Jaw"] = jaw
        if lipw:
            d["LipLeft" if x[i] > 0 else "LipRight"] = lipw
        if earw:
            d["EarLeft" if x[i] > 0 else "EarRight"] = earw
        if neck > 0:
            d = {k: v * (1 - neck) for k, v in d.items()}
            for k, v in W[i].items():
                d[k] = d.get(k, 0.0) + v * neck
        W[i] = d
    set_weights(body, W)
    skin(body, arm)
    print("heat weighting:", "ok" if heat_ok else "FAILED", "| zero-weight verts filled:", len(empty))


def transfer_by_material(src, dst):
    """Nearest-vertex weights from src to dst, only between vertices of the same material."""
    def vmat(obj):
        m = np.zeros(len(obj.data.vertices), int)
        for p in obj.data.polygons:
            for v in p.vertices:
                m[v] = p.material_index
        return m

    sP, dP = verts_np(src.data), verts_np(dst.data)
    sm_, dm = vmat(src), vmat(dst)
    sw = weights_of(src)
    out = [dict() for _ in dP]
    for mi in np.unique(dm):
        ids = np.nonzero(sm_ == mi)[0]
        kd = kdtree.KDTree(len(ids))
        for j, i in enumerate(ids):
            kd.insert(sP[i], j)
        kd.balance()
        for vi in np.nonzero(dm == mi)[0]:
            acc, tot = {}, 0.0
            for co, j, d in kd.find_n(dP[vi], 3):
                f = 1.0 / (d + 1e-4)
                tot += f
                for n, w in sw[ids[j]].items():
                    acc[n] = acc.get(n, 0.0) + w * f
            out[vi] = {n: w / tot for n, w in acc.items()}
    return out


# --------------------------------------------------------------------------
# Animation: procedural keys with planar leg IK
# --------------------------------------------------------------------------
def qe(pitch=0.0, yaw=0.0, roll=0.0):
    return (Quaternion((0, 0, 1), math.radians(yaw)) @ Quaternion((1, 0, 0), math.radians(pitch))
            @ Quaternion((0, 1, 0), math.radians(roll)))


class Frame:
    def __init__(self):
        self.rot = {}
        self.off = {}
        self.legs = {}

    def r(self, bone, pitch=0.0, yaw=0.0, roll=0.0):
        self.rot[bone] = self.rot.get(bone, Quaternion()) @ qe(pitch, yaw, roll)

    def o(self, bone, v):
        self.off[bone] = self.off.get(bone, Vector()) + Vector(v)


class Rig:
    def __init__(self, obj):
        self.obj = obj
        bones = obj.data.bones
        self.names = [n for n, *_ in SPEC]
        self.ml = {n: bones[n].matrix_local.copy() for n in self.names}
        self.par = {n: BONE[n][2] for n in self.names}
        self.rrel = {n: (self.ml[self.par[n]].inverted() @ self.ml[n]) if self.par[n] else None for n in self.names}
        self.R0 = {n: self.ml[n].to_3x3() for n in self.names}
        self.len = {n: bones[n].length for n in self.names}
        self.leg = {}
        for fb, side, s in LEGS:
            key = fb + side
            up, lo, ft, toe = (key + k for k in ("Upper", "Lower", "Foot", "Toe"))
            A = Vector(BONE[up][0])
            J = Vector(BONE[lo][0])
            Wr = Vector(BONE[ft][0])
            B = Vector(BONE[toe][0])
            u = (Wr - A).normalized()
            hint = (J - A) - u * (J - A).dot(u)
            self.leg[key] = dict(chain=(up, lo, ft, toe), ball=B, hint=hint.normalized(),
                                 fd=(B - Wr).normalized(), td=(Vector(BONE[toe][1]) - B).normalized())
        self.ik_err = 0.0
        self.ik_names = {n for L in self.leg.values() for n in L["chain"]}

    def solve(self, fr):
        M, T = {}, {}
        leg_of = {L["chain"][0]: k for k, L in self.leg.items()}
        for n in self.names:
            p = self.par[n]
            Tp = T[p] if p else Quaternion()
            if p:
                head = (M[p] @ self.rrel[n]).translation
            else:
                head = self.ml[n].translation.copy()
            head = head + Tp @ fr.off.get(n, Vector())
            if n in self.ik_names:
                if n in leg_of:
                    self._solve_leg(leg_of[n], fr, M, T, head)
                continue
            T[n] = Tp @ fr.rot.get(n, Quaternion())
            M[n] = Matrix.Translation(head) @ (T[n].to_matrix() @ self.R0[n]).to_4x4()
        return M

    def _solve_leg(self, key, fr, M, T, A):
        L = self.leg[key]
        up, lo, ft, toe = L["chain"]
        B, pf, pt = fr.legs.get(key, (L["ball"], 0.0, 0.0))
        fd = (Quaternion((1, 0, 0), math.radians(pf)) @ L["fd"]).normalized()
        td = (Quaternion((1, 0, 0), math.radians(pt)) @ L["td"]).normalized()
        l1, l2, lf = self.len[up], self.len[lo], self.len[ft]
        Wt = B - fd * lf
        Tp = T[self.par[up]]
        hint = Tp @ L["hint"]
        d = Wt - A
        dist = d.length
        dc = min(max(dist, abs(l1 - l2) + 1e-3), (l1 + l2) * 0.9995)
        u = d.normalized()
        v = (hint - u * hint.dot(u)).normalized()
        ca = max(-1.0, min(1.0, (l1 * l1 + dc * dc - l2 * l2) / (2 * l1 * dc)))
        a = math.acos(ca)
        J = A + (u * math.cos(a) + v * math.sin(a)) * l1
        E = A + u * dc
        self.ik_err = max(self.ik_err, dist - dc)
        heads = {up: A, lo: J, ft: E, toe: E + fd * lf}
        dirs = {up: J - A, lo: E - J, ft: fd, toe: td}
        prevT = Tp
        for n in (up, lo, ft, toe):
            base = prevT.to_matrix() @ self.R0[n]
            y0 = base.col[1].normalized()
            q = y0.rotation_difference(dirs[n].normalized())
            rot = q.to_matrix() @ base
            T[n] = (rot @ self.R0[n].inverted()).to_quaternion()
            M[n] = Matrix.Translation(heads[n]) @ rot.to_4x4()
            prevT = T[n]

    def basis(self, M):
        out = {}
        for n in self.names:
            p = self.par[n]
            ref = (M[p] @ self.rrel[n]) if p else self.ml[n]
            out[n] = ref.inverted() @ M[n]
        return out


def key_action(rig, name, frames, loop):
    obj = rig.obj
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    obj.animation_data_create()
    obj.animation_data.action = act
    pbs = obj.pose.bones
    seq = list(frames) + ([frames[0]] if loop else [])
    prev = {}
    for f, fr in enumerate(seq):
        B = rig.basis(rig.solve(fr))
        for n in rig.names:
            loc, q, _ = B[n].decompose()
            if n in prev and prev[n].dot(q) < 0:
                q.negate()
            prev[n] = q
            pb = pbs[n]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = q
            pb.location = loc
            pb.keyframe_insert("rotation_quaternion", frame=f, group=n)
            pb.keyframe_insert("location", frame=f, group=n)
    act.frame_range = (0.0, float(len(seq) - 1))
    act.use_frame_range = True
    act.use_cyclic = loop
    return act


def rest_frame():
    return Frame()


def breathe(fr, br, amt=1.0):
    fr.o("Hips", (0, 0, -0.012 * amt * br))
    fr.r("Spine2", pitch=-1.4 * amt * br)
    fr.r("Spine3", pitch=-1.0 * amt * br)
    fr.r("Neck1", pitch=0.8 * amt * br)


def tail_wave(fr, t, base_pitch, amp, cycles=1, lag=0.09, lift_wave=0.0):
    for i in range(1, 7):
        fr.r("Tail%d" % i, pitch=(base_pitch if i == 1 else base_pitch * 0.15)
             + lift_wave * math.sin(2 * math.pi * (cycles * t - lag * i)),
             yaw=amp * (0.5 + 0.18 * i) * math.sin(2 * math.pi * (cycles * t - lag * i)))


def idle_frame(t):
    fr = Frame()
    br = math.sin(2 * math.pi * 2 * t)
    breathe(fr, br, 1.3)
    fr.o("Hips", (0.012 * math.sin(2 * math.pi * t), 0, -0.02))
    fr.r("Hips", roll=1.2 * math.sin(2 * math.pi * t))
    fr.r("Neck1", pitch=4 + 1.5 * math.sin(2 * math.pi * (2 * t - 0.1)), yaw=5 * math.sin(2 * math.pi * t))
    fr.r("Neck2", yaw=3 * math.sin(2 * math.pi * t - 0.5))
    fr.r("Head", pitch=-3 + 2 * math.sin(2 * math.pi * 2 * t + 0.4), yaw=4 * math.sin(2 * math.pi * t - 0.8),
         roll=3 * math.sin(2 * math.pi * t - 1.0))
    fr.r("Jaw", pitch=3 + 5 * max(0.0, -br))
    fr.o("LipLeft", (0, 0, 0.004 * env(t, 0.3, 0.35, 0.45)))
    fr.r("EarLeft", pitch=-14 * env(t, 0.28, 0.31, 0.38))
    fr.r("EarRight", pitch=-14 * env(t, 0.70, 0.73, 0.80), yaw=-8 * env(t, 0.7, 0.73, 0.8))
    tail_wave(fr, t, -4, 4)
    fl = env(t, 0.52, 0.58, 0.68)
    fr.r("Tail5", yaw=28 * fl)
    fr.r("Tail6", yaw=40 * fl)
    return fr


class Gait:
    def __init__(self, name, frames, speed, duty, phases, lift, fold, body, shift=(-0.08, -0.12)):
        self.shift = shift
        self.name, self.frames, self.speed, self.duty = name, frames, speed, duty
        self.phases, self.lift, self.fold, self.body = phases, lift, fold, body
        self.T = frames / FPS
        self.L = speed * duty * self.T     # stance travel = ground speed x stance time


def leg_cycle(rig, g, key, t):
    u = (t - g.phases[key]) % 1.0
    front = key.startswith("Front")
    B0 = rig.leg[key]["ball"] + Vector((0, g.shift[0 if front else 1], 0))
    if u < g.duty:
        s = u / g.duty
        y = B0.y - g.L / 2 + g.L * s
        z = B0.z
        pf = -25.0 * sm(0.7, 1.0, s)
        pt = 0.0
    else:
        s = (u - g.duty) / (1 - g.duty)
        y = B0.y + g.L / 2 - g.L * sm(0.0, 1.0, s)
        z = B0.z + g.lift[0 if front else 1] * math.sin(math.pi * s) ** 0.8
        fold = g.fold[0 if front else 1]
        pf = -25.0 * (1 - sm(0.0, 0.35, s)) + fold * math.sin(math.pi * sm(0.0, 0.85, s))
        pt = 45.0 * math.sin(math.pi * s)
    return (Vector((B0.x, y, z)), pf, pt)


def gait_frame(rig, g, t):
    fr = Frame()
    for fb, side, s in LEGS:
        fr.legs[fb + side] = leg_cycle(rig, g, fb + side, t)
    g.body(fr, t)
    # lower the hips (and so the chest) just enough that every planted paw is reachable
    for _ in range(6):
        rig.ik_err = 0.0
        rig.solve(fr)
        if rig.ik_err < 0.003:
            break
        fr.o("Hips", (0, 0, -rig.ik_err * 0.9))
    return fr


def prowl_body(fr, t):
    w = 2 * math.pi * t
    fr.o("Hips", (0.012 * math.sin(w), 0, -0.13 + 0.014 * math.cos(2 * w)))
    fr.r("Hips", roll=2.5 * math.sin(w), yaw=2.5 * math.sin(w + 0.4))
    fr.r("Spine1", yaw=-1.5 * math.sin(w))
    fr.r("Spine3", roll=-3.5 * math.sin(w + math.pi * 0.5), yaw=-2.0 * math.sin(w + 0.6), pitch=2)
    fr.r("Neck1", pitch=14 - 1.5 * math.cos(2 * w), yaw=-1.5 * math.sin(w))
    fr.r("Neck2", pitch=4)
    fr.r("Head", pitch=-14 + 1.5 * math.cos(2 * w), yaw=2.0 * math.sin(w))
    fr.r("Jaw", pitch=5)
    for side, s in SIDES:
        fr.r("Ear" + side, pitch=12)
    tail_wave(fr, t, -10, 5, cycles=1, lag=0.1)


def run_body(fr, t):
    flex = math.cos(2 * math.pi * (t - 0.9))
    fr.o("Hips", (0, 0.04 * flex, -0.10 + 0.05 * math.sin(2 * math.pi * (t - 0.2))))
    fr.r("Hips", pitch=6 * flex)
    fr.r("Spine1", pitch=-8 * flex)
    fr.r("Spine2", pitch=-2 * flex)
    fr.r("Spine3", pitch=7 * flex)
    fr.r("Neck1", pitch=-2 - 4 * flex)
    fr.r("Head", pitch=6 + 3 * flex)
    fr.r("Jaw", pitch=16 + 4 * math.sin(2 * math.pi * t))
    for side, s in SIDES:
        fr.r("Ear" + side, pitch=-50, yaw=-s * 10)
        fr.o("Lip" + side, (s * 0.003, 0.006, 0.012))
    for i in range(1, 7):
        fr.r("Tail%d" % i, pitch=(22 if i == 1 else 3) + 4 * math.sin(2 * math.pi * (t - 0.08 * i)),
             yaw=2 * math.sin(2 * math.pi * (t - 0.1 * i)))


GAITS = [
    Gait("prowl", 30, 1.2, 0.65, {"BackLeft": 0.0, "FrontLeft": 0.25, "BackRight": 0.5, "FrontRight": 0.75},
         (0.15, 0.12), (65.0, 30.0), prowl_body),
    Gait("run", 15, 7.0, 0.22, {"BackLeft": 0.0, "BackRight": 0.1, "FrontLeft": 0.45, "FrontRight": 0.55},
         (0.30, 0.26), (95.0, 50.0), run_body),
]


def snarl_pose(fr, e, t, tremor=1.0):
    tr = tremor * math.sin(2 * math.pi * 12 * t) * e
    fr.o("Hips", (0, 0.06 * e, -0.09 * e))
    fr.r("Spine1", pitch=-3 * e)
    fr.r("Spine3", pitch=5 * e)
    fr.r("Neck1", pitch=12 * e)
    fr.r("Neck2", pitch=5 * e)
    fr.r("Head", pitch=-15 * e + 0.8 * tr, yaw=0.6 * tr)
    fr.r("Jaw", pitch=24 * e + 1.2 * tr)
    for side, s in SIDES:
        fr.o("Lip" + side, (s * 0.007 * e, 0.010 * e, 0.030 * e + 0.002 * tr))
        fr.r("Lip" + side, roll=-s * 6 * e)
        fr.r("Ear" + side, pitch=-52 * e, yaw=-s * 18 * e)


def snarl_frame(t):
    fr = Frame()
    e = sm(0.0, 0.4, t)
    breathe(fr, math.sin(2 * math.pi * 1.5 * t), 0.6)
    snarl_pose(fr, e, t)
    tail_wave(fr, t, -12 * e, 4 + 10 * e, cycles=1.5, lag=0.07)
    return fr


def snarl_hold_frame(t):
    fr = Frame()
    breathe(fr, math.sin(2 * math.pi * 2 * t), 0.7)
    snarl_pose(fr, 1.0, t)
    tail_wave(fr, t, -12, 14, cycles=2, lag=0.07)
    return fr


def roar_frame(t):
    fr = Frame()
    wind = env(t, 0.0, 0.2, 0.34)
    roar = sm(0.22, 0.34, t) * (1 - sm(0.74, 0.96, t))
    shake = math.sin(2 * math.pi * 14 * t) * roar
    fr.o("Hips", (0, 0.05 * wind - 0.07 * roar, -0.04 * wind - 0.05 * roar))
    fr.r("Spine2", pitch=-4 * wind + 2 * roar)
    fr.r("Spine3", pitch=-6 * wind + 4 * roar)
    fr.r("Neck1", pitch=-18 * wind + 10 * roar)
    fr.r("Neck2", pitch=-6 * wind + 4 * roar)
    fr.r("Head", pitch=-12 * wind - 14 * roar + 1.2 * shake, yaw=1.0 * shake, roll=1.5 * shake)
    fr.r("Jaw", pitch=10 * wind + 40 * roar + 1.5 * shake)
    for side, s in SIDES:
        k = max(wind * 0.5, roar)
        fr.o("Lip" + side, (s * 0.008 * k, 0.012 * k, 0.032 * k))
        fr.r("Ear" + side, pitch=-55 * k, yaw=-s * 20 * k)
    tail_wave(fr, t, 8 * roar, 6 + 6 * roar, cycles=1.0, lag=0.08)
    return fr


def add_actions(arm):
    scene = bpy.context.scene
    scene.render.fps, scene.render.fps_base = FPS, 1.0
    rig = Rig(arm)
    clips = [("idle", [idle_frame(f / 120) for f in range(120)], True)]
    for g in GAITS:
        clips.append((g.name, [gait_frame(rig, g, f / g.frames) for f in range(g.frames)], True))
    clips.append(("snarl", [snarl_frame(f / 45) for f in range(46)], False))
    clips.append(("snarl_hold", [snarl_hold_frame(f / 60) for f in range(60)], True))
    clips.append(("roar", [roar_frame(f / 75) for f in range(76)], False))
    names = []
    for name, frames, loop in clips:
        rig.ik_err = 0.0
        key_action(rig, name, frames, loop)
        print("clip %-10s %3d frames loop=%s  max paw IK miss %.3f m" % (name, len(frames), loop, rig.ik_err))
        names.append(name)
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    scene.frame_set(0)
    return names


def pose_check(arm, body, names):
    """Play every clip and check the skinned mesh: finite, bounded, no exploding edges."""
    me = body.data
    E = np.empty(len(me.edges) * 2, int)
    me.edges.foreach_get("vertices", E)
    E = E.reshape(-1, 2)
    P0 = verts_np(me)
    L0 = np.linalg.norm(P0[E[:, 0]] - P0[E[:, 1]], axis=1) + 1e-6
    scene = bpy.context.scene
    report = []
    for n in names:
        act = bpy.data.actions[n]
        arm.animation_data.action = act
        worst, maxd, ok, at, el = 0.0, 0.0, True, None, 0.0
        for f in range(0, int(act.frame_range[1]) + 1, 3):
            scene.frame_set(f)
            dg = bpy.context.evaluated_depsgraph_get()
            ev = body.evaluated_get(dg)
            m = ev.to_mesh()
            P = np.empty(len(m.vertices) * 3)
            m.vertices.foreach_get("co", P)
            ev.to_mesh_clear()
            P = P.reshape(-1, 3)
            ok &= bool(np.isfinite(P).all())
            L = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1)
            r = L / L0
            if r.max() > worst:
                worst = float(r.max())
                at = (P0[E[r.argmax(), 0]] + P0[E[r.argmax(), 1]]) / 2
                el = L0[r.argmax()]
            maxd = max(maxd, float(np.linalg.norm(P - P0, axis=1).max()))
        report.append("  %-10s finite=%s max edge stretch x%.2f (rest len %.3f at %s)  max vert move %.2f m"
                      % (n, ok, worst, el, np.round(at, 2), maxd))
    arm.animation_data.action = None
    scene.frame_set(0)
    return report


# --------------------------------------------------------------------------
# Lineup render (moonlit cottage door: cold blue key, warm rim)
# --------------------------------------------------------------------------
def look_at(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def human_silhouette(mat):
    objs = []

    def add(prim, **kw):
        getattr(bpy.ops.mesh, prim)(**kw)
        o = bpy.context.active_object
        o.data.materials.append(mat)
        o["by"] = o.location.y
        objs.append(o)
        return o

    add("primitive_uv_sphere_add", radius=0.10, location=(0, 0, 1.56), segments=24, ring_count=12)
    add("primitive_cylinder_add", radius=0.045, depth=0.12, location=(0, 0, 1.44), vertices=12)
    t = add("primitive_cylinder_add", radius=0.15, depth=0.52, location=(0, 0, 1.13), vertices=20)
    t.scale = (1.0, 0.7, 1.0)
    add("primitive_cone_add", radius1=0.24, radius2=0.14, depth=0.30, location=(0, 0, 0.78), vertices=20)
    for dy in (-0.07, 0.07):
        add("primitive_cylinder_add", radius=0.06, depth=0.82, location=(0, dy, 0.41), vertices=12)
        a = add("primitive_cylinder_add", radius=0.04, depth=0.62, location=(0, dy * 2.6, 1.08), vertices=12)
        a.rotation_euler = (math.radians(-8 if dy < 0 else 8), 0, 0)
    return objs


def render_lineup(arm, body, path):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 40
    try:
        scene.cycles.use_denoising = True
    except Exception:
        pass
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Punchy"
    except Exception:
        pass
    world = bpy.data.worlds.new("Night")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.006, 0.009, 0.02, 1)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    ground = bpy.context.active_object
    gm = make_material("render_ground", (0.025, 0.03, 0.04), rough=0.95, use_vcol=False)
    ground.data.materials.append(gm)
    sil_mat = make_material("render_human", (0.01, 0.01, 0.012), rough=0.7, use_vcol=False)
    human = human_silhouette(sil_mat)
    moon = bpy.data.lights.new("Moon", "SUN")
    moon.energy = 2.6
    moon.color = (0.55, 0.68, 1.0)
    moon.angle = math.radians(1.5)
    moon_o = link(bpy.data.objects.new("Moon", moon))
    rim = bpy.data.lights.new("DoorGlow", "AREA")
    rim.energy = 1400
    rim.color = (1.0, 0.52, 0.2)
    rim.size = 1.6
    rim_o = link(bpy.data.objects.new("DoorGlow", rim))
    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy = 20
    fill.color = (0.4, 0.5, 0.9)
    fill.size = 3
    fill_o = link(bpy.data.objects.new("Fill", fill))
    cam_d = bpy.data.cameras.new("Cam")
    cam = link(bpy.data.objects.new("Cam", cam_d))
    scene.camera = cam
    label_mat = make_material("render_label", (0.6, 0.65, 0.8), use_vcol=False)
    label_mat.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (0.5, 0.55, 0.7, 1)
    label_mat.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 1.0

    def label(text, loc, rot, size):
        cu = bpy.data.curves.new("lbl", "FONT")
        cu.body = text
        cu.size = size
        o = link(bpy.data.objects.new("lbl", cu))
        o.location = loc
        o.rotation_euler = rot
        o.data.materials.append(label_mat)
        return o

    eye_mat = bpy.data.materials["beast_eye"]
    eye_bsdf = eye_mat.node_tree.nodes["Principled BSDF"]
    eye_bsdf.inputs["Emission Strength"].default_value = 9.0
    tmp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "__render_tmp")
    os.makedirs(tmp, exist_ok=True)
    panels = [
        # name, res, action, frame, cam loc, target, lens, human loc, moon dir, rim loc
        ("side", (1920, 540), "prowl", 8, (9.5, -0.55, 1.05), (0, -0.55, 0.98), 52, (0, -2.55, 0),
         (-0.6, 0.35, -0.75), (-3.0, 1.0, 2.8)),
        ("threeq", (960, 540), "snarl_hold", 10, (2.0, -3.3, 0.62), (0, -0.62, 1.18), 30, None,
         (-0.5, 0.6, -0.7), (-1.8, 3.2, 2.6)),
        ("head", (960, 540), "snarl_hold", 10, (0.85, -2.25, 1.45), (0, -1.12, 1.34), 44, None,
         (-0.55, 0.55, -0.62), (-1.5, 0.6, 2.2)),
    ]
    imgs = {}
    for name, res, act, frame, cl, tgt, lens, hl, md, rl in panels:
        arm.animation_data.action = bpy.data.actions[act]
        scene.frame_set(frame)
        for o in human:
            o.hide_render = hl is None
            if hl is not None:
                o.location.x, o.location.y = hl[0], o["by"] + hl[1] * BEAST_SCALE
        scene.render.resolution_x, scene.render.resolution_y = res
        scene.render.resolution_percentage = 100
        K = BEAST_SCALE
        cl, tgt, rl = tuple(c * K for c in cl), tuple(c * K for c in tgt), tuple(c * K for c in rl)
        cam.location = cl
        look_at(cam, tgt)
        cam_d.lens = lens
        moon_o.rotation_euler = Vector(md).to_track_quat("-Z", "Y").to_euler()
        rim_o.location = rl
        look_at(rim_o, tgt)
        fill_o.location = Vector(cl) + Vector((0, 0, 1.5))
        look_at(fill_o, tgt)
        lbls = []
        if name == "side":
            lbls.append(label("1.66 m", (0.0, -2.85, 1.72), (math.radians(90), 0, math.radians(90)), 0.16))
        out = os.path.join(tmp, name + ".png")
        scene.render.image_settings.file_format = "PNG"
        scene.render.filepath = out
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(out)
        a = np.array(img.pixels[:], dtype=np.float32).reshape(res[1], res[0], 4)[::-1]
        imgs[name] = a
        bpy.data.images.remove(img)
        for o in lbls:
            bpy.data.objects.remove(o)
        print("rendered panel", name)
    canvas = np.zeros((1080, 1920, 4), np.float32)
    canvas[..., 3] = 1
    canvas[0:540] = imgs["side"]
    canvas[540:1080, 0:960] = imgs["threeq"]
    canvas[540:1080, 960:1920] = imgs["head"]
    canvas[538:542] = (0.02, 0.02, 0.03, 1)
    canvas[540:, 958:962] = (0.02, 0.02, 0.03, 1)
    os.makedirs(os.path.dirname(path) + "/", exist_ok=True)
    write_png(path, canvas)
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)
    print("lineup:", path, os.path.getsize(path), "bytes")


# --------------------------------------------------------------------------
def scale_up(arm, meshes, k, widen):
    """Scale the finished, animated beast: meshes and bones by (k*widen, k, k), clip translations by k."""
    f = np.array([k * widen, k, k])
    for o in meshes:
        me = o.data
        if me.shape_keys:
            for kb in me.shape_keys.key_blocks:
                a = np.empty(len(kb.data) * 3)
                kb.data.foreach_get("co", a)
                kb.data.foreach_set("co", (a.reshape(-1, 3) * f).ravel())
        P = verts_np(me) * f
        me.vertices.foreach_set("co", P.ravel())
        me.update()
    select_only([arm], arm)
    bpy.ops.object.mode_set(mode="EDIT")
    for b in arm.data.edit_bones:
        b.use_connect = False
    for b in arm.data.edit_bones:
        roll = b.roll
        b.head = Vector(np.array(b.head) * f)
        b.tail = Vector(np.array(b.tail) * f)
        b.roll = roll
    bpy.ops.object.mode_set(mode="OBJECT")
    for act in bpy.data.actions:
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        if fc.data_path.endswith(".location"):
                            for kp in fc.keyframe_points:
                                kp.co.y *= k
                                kp.handle_left.y *= k
                                kp.handle_right.y *= k
    print("scaled x%.2f (width x%.2f): shoulder %.2f m" % (k, widen, arm.data.bones["Spine3"].head_local.z))


def export_glb(path, objs, arm):
    select_only([arm] + objs, arm)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_morph=False, export_yup=True, export_materials="EXPORT",
                              export_vertex_color="ACTIVE", export_extras=False)


def main():
    do_render = "--no-render" not in sys.argv
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    S, eyes = sculpt_body()
    eye_png = os.path.join(OUT_DIR, "tamlin_beast_eye.png")
    bake_iris(eye_png)
    eye_img = bpy.data.images.load(eye_png)
    eye_img.name = "tamlin_beast_eye"
    mats = dict(
        coat=make_material("beast_coat", (0.58, 0.32, 0.05), rough=0.85),
        mouth=make_material("beast_mouth", (0.07, 0.006, 0.008), rough=0.22, use_vcol=False),
        gum=make_material("beast_gum", (0.16, 0.012, 0.016), rough=0.18, use_vcol=False),
        horn=make_material("beast_horn", (0.3, 0.27, 0.2), rough=0.45),
        tooth=make_material("beast_tooth", (0.75, 0.6, 0.2), rough=0.35),
        claw=make_material("beast_claw", (0.01, 0.01, 0.01), rough=0.25),
        eye=make_material("beast_eye", (1, 1, 1), rough=0.1, image=eye_img, emit=4.0),
    )
    parts = [build_horns(mats["horn"]), *build_teeth(S, mats["tooth"], mats["gum"]), build_claws(mats["claw"]),
             build_eyes(eyes, mats["eye"])]
    part_tris = sum(tri_count(p) for p in parts)
    print("parts:", ", ".join("%s %d" % (p.name, tri_count(p)) for p in parts))
    body = build_body(S, TRI_BUDGET - part_tris - 120)
    P = verts_np(body.data)
    N = np.empty(len(P) * 3)
    body.data.vertices.foreach_get("normal", N)
    set_colours(body, coat_colours(S, P, N.reshape(-1, 3)))
    body.data.materials.append(mats["coat"])
    body.data.materials.append(mats["mouth"])
    cen = np.array([p.center for p in body.data.polygons])
    inner = S.eval(cen, skip=("slit", "socket", "rib", "clump")) < -0.0045
    inner &= (cen[:, 1] < MOUTH_BACK + 0.03) & (np.abs(cen[:, 2] - zm(cen[:, 1])) < 0.07)
    mi = inner.astype(int)
    body.data.polygons.foreach_set("material_index", mi)
    for p in body.data.polygons:
        p.use_smooth = True
    body.data.uv_layers.new(name="UVMap")
    print("mouth faces:", int(mi.sum()))

    arm = build_armature()
    weight_body(body, arm, S)
    for p in parts:
        skin(p, arm)
    select_only([body] + parts, body)
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "Body"
    body.data.name = "Body"
    set_weights(body, weights_of(body))
    ca = body.data.color_attributes["Col"]
    body.data.color_attributes.active_color = ca
    body.data.color_attributes.render_color_index = body.data.color_attributes.find("Col")
    print("hero tris:", tri_count(body))

    lod = link(bpy.data.objects.new("Body_LOD1", body.data.copy()))
    lod.data.name = "Body_LOD1"
    dm = lod.modifiers.new("Decimate", "DECIMATE")
    dm.ratio = LOD1_RATIO
    bake_modifiers(lod)
    set_weights(lod, transfer_by_material(body, lod))
    skin(lod, arm)
    print("LOD1 tris:", tri_count(lod))

    names = add_actions(arm)
    for line in pose_check(arm, body, names):
        print(line)
    scale_up(arm, [body, lod], BEAST_SCALE, BEAST_WIDEN)
    export_glb(os.path.join(OUT_DIR, "tamlin_beast.glb"), [body, lod], arm)
    lod.hide_set(True)
    lod.hide_render = True
    for img in bpy.data.images:
        if img.source == "FILE" and not img.packed_file:
            img.pack()
    bpy.context.preferences.filepaths.save_version = 0   # no .blend1 backups in the repo
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "tamlin_beast.blend"), compress=True)
    print("bones:", " ".join(n for n, *_ in SPEC))
    if do_render:
        render_lineup(arm, body, LINEUP)


if __name__ == "__main__":
    main()
