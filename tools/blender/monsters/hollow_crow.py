"""The hollow-crow (bestiary §6): creatures/models/fae/hollow_crow.gltf with
its textures, skeleton, eye keys and clips, and
data/animation/creatures/hollow_crow_gaits.txt.

A crow, a little too big, until its other eyes open: nine more, small and
wet, hidden in the feathers down its head and neck. `eyes_open` opens them
all; `eyelid_0..8` open them one by one.

It is modelled standing with its wings spread. Each wing is three bones
(`wing_0..2_<side>`), and the flight feathers of each ride a fan bone
(`wing_fan_0..2_<side>`) so they can swing back along the arm as it folds.

    /opt/bpyenv/bin/python tools/blender/monsters/hollow_crow.py [--preview DIR] [--fast] [--nobake]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import bpy  # noqa: E402
import bmesh  # noqa: E402,I001
import numpy as np  # noqa: E402

import kit  # noqa: E402
import rig  # noqa: E402
from biped import Keys  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402
from rig import pulse, rot, seg, smooth, wave  # noqa: E402

NAME = "hollow_crow"
OUT = os.path.join(kit.ROOT, "creatures", "models", "fae")
BODY_TRIS = 1270

BLACK = (0.011, 0.012, 0.016)
SHEEN_A = (0.008, 0.02, 0.026)       # the oil on it: blue-green
SHEEN_B = (0.016, 0.011, 0.028)      # and violet
MOULT = (0.04, 0.036, 0.032)
SCALE = (0.034, 0.034, 0.032)


def _v(*p):
    return np.array(p, dtype=np.float64)


def _ang(deg):
    """A flat direction: 0 = out along +x, -90 = straight back."""
    a = math.radians(deg)
    return _v(math.cos(a), math.sin(a), 0.0)


# ---- joints (right side; x mirrors)
HIP, ANKLE, FOOT = _v(0.03, -0.02, 0.15), _v(0.035, -0.047, 0.076), _v(0.035, -0.008, 0.012)
SHOULDER, ELBOW, WRIST, TIP = _v(0.045, 0.055, 0.215), _v(0.15, 0.03, 0.22), _v(0.29, 0.055, 0.222), _v(0.385, 0.035, 0.22)
TAIL = _v(0.0, -0.105, 0.122)
TAIL_DIR = _v(0.0, -math.cos(math.radians(20)), -math.sin(math.radians(20)))
EYE = _v(0.0215, 0.153, 0.297)
BEAK_TIP = _v(0.0, 0.24, 0.269)
TUCK = _v(0.03, -0.09, 0.118)        # where a foot is carried in flight (as at rest, by the pelvis)

TOES = ((-28.0, 0.042), (2.0, 0.052), (30.0, 0.044), (172.0, 0.028))     # yaw from forward, length


def toe(i, s=1):
    yaw, length = TOES[i]
    a = math.radians(yaw)
    root = FOOT * (s, 1, 1)
    return root, root + _v(s * math.sin(a) * length, math.cos(a) * length, -0.007)


# ---- the flight feathers: (name, bone, root, direction, length, width)
def feathers():
    out = []
    for i in range(8):                                   # primaries, on the hand
        u = i / 7.0
        root = WRIST + (TIP - WRIST) * u + _v(0, -0.004, -0.004 - 0.0005 * (7 - i))
        out.append((f"prim{i}", f"pri_{i}", root, _ang(-62.0 + 42.0 * u), 0.175 - 0.027 * u + 0.008 * math.sin(i * 2.1), 0.037 - 0.011 * u))
    for i in range(7):                                   # secondaries, on the forearm
        u = (i + 0.4) / 7.0
        root = ELBOW + (WRIST - ELBOW) * u + _v(0, -0.006, -0.004 - 0.0005 * (15 - i))
        out.append((f"sec{i}", f"sec_{i}", root, _ang(-88.0 + 13.0 * u), 0.15 + 0.018 * u, 0.042))
    for i in range(3):                                   # tertials, on the upper arm
        u = (0.35, 0.65, 0.95)[i]
        root = SHOULDER + (ELBOW - SHOULDER) * u + _v(0, -0.008, -0.004 - 0.0005 * (18 - i))
        out.append((f"ter{i}", f"ter_{i}", root, _ang(-100.0), (0.11, 0.13, 0.145)[i], 0.04))
    return out


def tail_feathers():
    out = []
    for i, deg in enumerate((-28, -20, -12, -4, 4, 12, 20, 28)):
        a = math.radians(deg)
        d = _v(math.sin(a), TAIL_DIR[1] * math.cos(a), TAIL_DIR[2])
        mid = 1.0 - abs(deg) / 28.0
        out.append((f"tail{i}", TAIL + _v(deg * 0.0006, 0.012, 0.004 - 0.0015 * abs(i - 3.5)), d / np.linalg.norm(d), 0.15 + 0.03 * mid, 0.034))
    return out


# where the hidden eyes sit (a point near the skin; it is snapped onto it), their size and bone
HIDDEN = (((0.027, 0.13, 0.303), 0.0052, "head"), ((0.028, 0.122, 0.283), 0.0064, "head"), ((0.031, 0.108, 0.262), 0.0046, "neck"),
          ((0.034, 0.094, 0.243), 0.006, "neck"), ((-0.024, 0.142, 0.312), 0.0044, "head"), ((-0.029, 0.118, 0.293), 0.0058, "head"),
          ((-0.03, 0.106, 0.272), 0.0066, "neck"), ((-0.034, 0.09, 0.25), 0.0048, "neck"), ((-0.038, 0.072, 0.228), 0.0056, "neck"))


# ------------------------------------------------------------------ clay

def forms():
    """(feathered forms, leg forms): the legs are scaled skin, the rest feathers."""
    t, e = kit.tube, kit.ellipsoid
    body = [t("torso", [(0, -0.118, 0.117), (0, -0.06, 0.15), (0, 0.0, 0.178), (0, 0.055, 0.2), (0, 0.09, 0.228)],
              [(0.022, 0.019), (0.045, 0.041), (0.056, 0.057), (0.05, 0.052), (0.034, 0.036)], k=0.02, segs=24),
            t("neck", [(0, 0.085, 0.225), (0, 0.115, 0.262), (0, 0.132, 0.288)], [0.034, 0.028, 0.027], k=0.018, segs=18),
            e("head", (0, 0.138, 0.293), (0.027, 0.037, 0.029), rot=(-10, 0, 0), k=0.014, segs=20),
            e("brow", (0, 0.152, 0.303), (0.02, 0.022, 0.016), k=0.014, segs=14),
            e("hackles", (0, 0.122, 0.26), (0.025, 0.023, 0.026), k=0.016, segs=16),      # the shaggy throat
            e("rump", (0, -0.085, 0.142), (0.03, 0.04, 0.022), rot=(20, 0, 0), k=0.02, segs=14)]
    legs = []
    for s in (1, -1):
        m = (s, 1, 1)
        body.append(t(f"thigh{s}", [tuple(HIP * m), (0.036 * s, -0.035, 0.11), tuple(ANKLE * m)], [0.026, 0.018, 0.0078], k=0.014, segs=14))
        body.append(t(f"arm{s}", [tuple((p + _v(0, -0.012, 0)) * m) for p in (SHOULDER, ELBOW, WRIST, TIP)],
                      [(0.025, 0.012), (0.025, 0.009), (0.019, 0.008), (0.009, 0.005)], side=(0, 1, 0), k=0.012, segs=14, rings_per_m=120))
        legs.append(t(f"tarsus{s}", [tuple(ANKLE * m), tuple((ANKLE + FOOT) / 2 * m + _v(0, 0.004, 0)), tuple(FOOT * m)], [0.0058, 0.0044, 0.0058],
                      k=0.004, segs=8, rings_per_m=200))
        for i in range(4):
            a, b = toe(i, s)
            legs.append(t(f"toe{s}{i}", [tuple(a), tuple((a + b) / 2 + _v(0, 0, 0.003)), tuple(b)], [0.0045, 0.0037, 0.003], k=0.003, segs=8, rings_per_m=300))
    return body, legs


# ------------------------------------------------------------------ materials

def feather_coat(g, P, moult=None):
    """Glossy black with oil on it. Returns (colour, roughness, height)."""
    oil = g.noise(P, 9.0, 3.0)
    col = g.mix_rgb(g.smooth(oil, 0.42, 0.6), BLACK, SHEEN_A)
    col = g.mix_rgb(g.smooth(g.noise(P, 6.0, 2.0), 0.55, 0.72), col, SHEEN_B)
    barb = g.noise(g.scale_vec(P, (1.0, 0.12, 1.0)), 900.0, 2.0)
    worn = g.smooth(g.noise(P, 26.0, 3.0), 0.6, 0.72)
    if moult is not None:
        worn = g.math("MAXIMUM", worn, moult)
    col = g.mix_rgb(g.math("MULTIPLY", worn, 0.8), col, MOULT)
    return col, g.mix(worn, 0.6, 0.82), barb


def body_material():
    def build(nt, bsdf):
        g = kit.Graph(nt)
        P = g.position()
        leg, _, _ = g.split(g.attr("zone"))
        # feathers lapping back along the body: cells drawn out along its length
        cell, _ = g.voronoi(g.scale_vec(P, (1.0, 0.45, 1.0)), 190.0, feature="F1")
        lap = g.smooth(cell, 0.0, 0.5)                    # dark at each feather's root, bright at its edge
        col, rough, barb = feather_coat(g, P)
        col = g.mix_rgb(g.math("MULTIPLY", g.math("SUBTRACT", 1.0, lap), 0.45), col, (0.004, 0.004, 0.006))
        height = g.math("ADD", g.math("MULTIPLY", lap, 0.5), g.math("MULTIPLY", barb, 0.4))
        plate, _ = g.voronoi(g.scale_vec(P, (1.0, 1.0, 1.6)), 420.0)
        seam = g.math("SUBTRACT", 1.0, g.smooth(plate, 0.0, 0.1))
        s_col = g.mix_rgb(seam, SCALE, (0.012, 0.012, 0.011))
        col = g.mix_rgb(leg, col, s_col)
        rough = g.mix(leg, rough, 0.55)
        height = g.mix(leg, height, g.math("MULTIPLY", g.math("SUBTRACT", 1.0, seam), 0.8))
        g.out(bsdf, color=col, rough=rough, normal=g.bump(height, 0.0008))
    return kit.sculpt_material("crow_body", build)


def quill_material():
    """A flight feather: the same coat, ragged and dull toward a worn tip."""
    def build(nt, bsdf):
        g = kit.Graph(nt)
        grad, _, _ = g.split(g.attr("grad"))
        col, rough, barb = feather_coat(g, g.position(), moult=g.math("MULTIPLY", g.smooth(grad, 0.8, 1.0), 0.7))
        g.out(bsdf, color=col, rough=rough, normal=g.bump(barb, 0.0004))
    return kit.sculpt_material("crow_quill", build)


def horn_material(name, root, tip, rough):
    def build(nt, bsdf):
        g = kit.Graph(nt)
        grad, _, _ = g.split(g.attr("grad"))
        scuff = g.smooth(g.noise(g.position(), 240.0, 3.0), 0.55, 0.75)
        col = g.mix_rgb(g.smooth(grad, 0.0, 0.8), root, tip)
        col = g.mix_rgb(g.math("MULTIPLY", scuff, 0.5), col, (0.07, 0.07, 0.068))
        g.out(bsdf, color=col, rough=g.mix(scuff, rough, 0.6), normal=g.bump(scuff, 0.0004))
    return kit.sculpt_material(name, build)


def eye_material(name, centre, axis, radius, ring=True):
    """Wet and black; the hidden ones carry an amber ring round the pupil."""
    def build(nt, bsdf):
        g = kit.Graph(nt)
        v = g.sub_vec(g.position(), tuple(centre))
        d = g.math("DIVIDE", g.dot(v, tuple(axis)), radius)
        col = (0.004, 0.004, 0.005)
        if ring:
            band = g.math("MULTIPLY", g.smooth(d, 0.5, 0.6), g.math("SUBTRACT", 1.0, g.smooth(d, 0.8, 0.86)))
            fleck = g.noise(g.position(), 900.0, 2.0)
            amber = g.mix_rgb(g.smooth(fleck, 0.3, 0.7), (0.42, 0.2, 0.02), (0.62, 0.36, 0.05))
            col = g.mix_rgb(band, col, amber)
            col = g.mix_rgb(g.math("SUBTRACT", 1.0, g.smooth(d, 0.2, 0.5)), col, (0.03, 0.012, 0.012))     # raw at the rim
        g.out(bsdf, color=col, rough=0.06)
    return kit.sculpt_material(name, build)


# ------------------------------------------------------------------ parts

def dome(name, centre, axis, radius, segs=6):
    """A small eye at game resolution: the cap of a ball, its pole along `axis`."""
    axis = np.asarray(axis, dtype=np.float64)
    axis /= np.linalg.norm(axis)
    x = np.cross(axis, (0.0, 0.0, 1.0))
    if np.linalg.norm(x) < 1e-4:
        x = np.array((1.0, 0.0, 0.0))
    x /= np.linalg.norm(x)
    y = np.cross(axis, x)
    bm = bmesh.new()
    top = bm.verts.new(centre + axis * radius)
    rings = []
    for lat in (42.0, 84.0):
        a = math.radians(lat)
        rings.append([bm.verts.new(centre + axis * (radius * math.cos(a)) + (x * math.cos(2 * math.pi * j / segs) + y * math.sin(2 * math.pi * j / segs))
                                   * (radius * math.sin(a))) for j in range(segs)])
    for j in range(segs):
        bm.faces.new((top, rings[0][j], rings[0][(j + 1) % segs]))
        bm.faces.new((rings[0][j], rings[1][j], rings[1][(j + 1) % segs], rings[0][(j + 1) % segs]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    P = kit.co(o)
    if ((kit.normals(o) * (P - centre)).sum(axis=1)).mean() < 0:
        o.data.flip_normals()
    kit.shade_smooth(o)
    return o


AWAY = np.array((0.0, 0.0, 1.0))        # the hidden eyes are baked this far off, so none of them lands on the feathers


def hard_parts(sculpt):
    """[(source object, low object, part number, bone)]: beak, eyes, talons, the
    hidden eyes (open, as they are baked; their sources stand AWAY) and every
    flight feather."""
    out = []

    def add(src, part, bone, low=None):
        kit.tag(src, part)
        if low is not None:
            kit.tag(low, part)
        out.append((src, low, part, bone))

    horn = horn_material("crow_beak", (0.016, 0.016, 0.018), (0.01, 0.01, 0.012), 0.26)
    up = kit.horn("beak_u", (0, 0.156, 0.2895), tuple(BEAK_TIP), 0.0128, bend=(0, 0, 0.017), segs=8, rings=7, flat=0.82, tip_r=0.05)
    lo = kit.horn("beak_l", (0, 0.156, 0.28), (0, 0.227, 0.2675), 0.0088, bend=(0, 0, -0.004), segs=6, rings=5, flat=1.15, tip_r=0.08)
    for o, part, bone in ((up, 1, "head"), (lo, 2, "jaw")):
        kit.set_material(o, horn)
        add(o, part, bone)
    claw = horn_material("crow_talon", (0.028, 0.028, 0.027), (0.008, 0.008, 0.01), 0.24)
    for s in (1, -1):
        e = kit.ball(f"eye{s}", tuple(EYE * (s, 1, 1)), 0.0047, segs=8, rings=6)
        kit.set_material(e, eye_material(f"crow_eye{s}", EYE * (s, 1, 1), (s, 0, 0), 0.0047, ring=False))
        add(e, 10, "head")
        for i in range(4):
            a, b = toe(i, s)
            d = (b - a) / np.linalg.norm(b - a)
            c = kit.horn(f"talon{s}{i}", b - d * 0.004, b + d * 0.013 + _v(0, 0, -0.005), 0.0033, bend=(0, 0, 0.007), segs=5, rings=4, flat=0.8, tip_r=0.05)
            kit.set_material(c, claw)
            add(c, 20 + i, f"paw_leg_{'r' if s > 0 else 'l'}")
    quill = quill_material()
    for s, side in ((1, "r"), (-1, "l")):
        m = np.array((s, 1, 1))
        for name, bone, root, d, length, width in feathers():
            if side == "l" and name in ("prim5", "sec2"):      # moulting: two gone from the left wing
                continue
            if side == "r" and name == "prim2":
                length *= 0.72                                  # and one growing back on the right
            root, d = root * m, d * m
            pts = [root, root + d * length * 0.55 + _v(0, 0, -0.004), root + d * length * 0.92 + _v(0, 0, -0.007)]
            o = kit.ribbon(f"{name}_{side}", pts, [width * 0.5, width, width * 0.8], (0, 0, 1), thick=0.003, ragged=0.35,
                           seed=len(out) * 0.37, rings=3)
            kit.set_material(o, quill)
            add(o, 60, f"{bone}_{side}")
    for name, root, d, length, width in tail_feathers():
        pts = [root, root + d * length * 0.55, root + d * length * 0.92]
        o = kit.ribbon(name, pts, [width * 0.55, width, width * 0.85], (0, 0.34, 0.94), thick=0.003, ragged=0.3, seed=len(out) * 0.41, rings=3)
        kit.set_material(o, quill)
        add(o, 61, "tail")
    # the hidden eyes: found on the skin, baked open
    P, N = kit.co(sculpt), kit.normals(sculpt)
    for i, (near, radius, bone) in enumerate(HIDDEN):
        j = int(np.argmin(np.linalg.norm(P - np.array(near), axis=1)))
        n = N[j] / np.linalg.norm(N[j])
        c = P[j] - n * radius * 0.35
        src = kit.ball(f"hidden{i}_src", tuple(c + AWAY), radius * 0.985, segs=14, rings=10)
        kit.set_material(src, eye_material(f"crow_hidden{i}", c + AWAY, n, radius))
        low = dome(f"hidden{i}", c, n, radius)
        add(src, 40 + i, bone, low)
    return out


def eye_keys(low, hidden):
    """Basis: every hidden eye shrunk and sunk under the feathers. `eyelid_<i>`
    opens one, `eyes_open` all of them."""
    P = kit.co(low)
    part = kit.parts_of(low)
    shut = P.copy()
    for i, (c, n, radius) in enumerate(hidden):
        m = part == 40 + i
        shut[m] = c + (P[m] - c) * 0.15 - n * (radius * 0.9 + 0.009)
    kit.set_co(low, shut)
    low.shape_key_add(name="Basis")
    every = low.shape_key_add(name="eyes_open")
    every.data.foreach_set("co", P.ravel())
    for i in range(len(hidden)):
        Q = shut.copy()
        m = part == 40 + i
        Q[m] = P[m]
        low.shape_key_add(name=f"eyelid_{i}").data.foreach_set("co", Q.ravel())


# ------------------------------------------------------------------ rig

def bones():
    B = [("root", (0, 0, 0), (0, 0.06, 0), None, False),
         ("body", (0, 0.0, 0.165), (0, 0.06, 0.165), "root", False),
         ("pelvis", (0, -0.015, 0.155), (0, -0.09, 0.128), "body", True),
         ("chest", (0, -0.005, 0.172), (0, 0.075, 0.215), "body", True),
         ("neck", (0, 0.085, 0.228), (0, 0.125, 0.275), "chest", True),
         ("head", (0, 0.125, 0.275), (0, 0.16, 0.3), "neck", True),
         ("jaw", (0, 0.156, 0.281), (0, 0.227, 0.2675), "head", True),
         ("throat", (0, 0.116, 0.256), (0, 0.136, 0.268), "neck", True),
         ("beak", tuple(BEAK_TIP), tuple(BEAK_TIP + _v(0, 0.03, 0)), "head", False),
         ("tail", tuple(TAIL), tuple(TAIL + TAIL_DIR * 0.17), "pelvis", True)]
    for side, s in (("r", 1), ("l", -1)):
        m = np.array((s, 1, 1))
        chain = (SHOULDER, ELBOW, WRIST, TIP)
        par = "chest"
        for n in range(3):
            b = f"wing_{n}_{side}"
            B.append((b, tuple(chain[n] * m), tuple(chain[n + 1] * m), par, True))
            mid = (chain[n] + chain[n + 1]) / 2 * m
            B.append((f"wing_fan_{n}_{side}", tuple(mid), tuple(mid + _v(0, -0.1, 0)), b, True))
            par = b
        for name, bone, root, d, length, width in feathers():          # each quill on its own bone, to stack when the wing shuts
            B.append((f"{bone}_{side}", tuple(root * m), tuple((root + d * 0.06) * m), f"wing_fan_{FAN[bone[:3]]}_{side}", True))
        leg = f"leg_{side}"
        B.append((f"upper_{leg}", tuple(HIP * m), tuple(ANKLE * m), "pelvis", True))
        B.append((f"lower_{leg}", tuple(ANKLE * m), tuple(FOOT * m), f"upper_{leg}", True))
        B.append((f"paw_{leg}", tuple(FOOT * m), tuple(FOOT * m + _v(0, 0.045, -0.006)), f"lower_{leg}", True))
    return B


def skin_bones():
    out = ["pelvis", "chest", "neck", "head", "throat"]
    for side in ("r", "l"):
        out += [f"wing_{n}_{side}" for n in range(3)] + [f"upper_leg_{side}", f"lower_leg_{side}", f"paw_leg_{side}"]
    return out


def spec():
    return dict(legs={s: (f"upper_leg_{s}", f"lower_leg_{s}", None, f"paw_leg_{s}") for s in ("r", "l")},
                core=["pelvis", "chest", "head"], radius=dict(pelvis=0.04, chest=0.05, head=0.027))


# ------------------------------------------------------------------ poses

FOLD = 88.0
# Standing on a branch, wings shut. Angles in degrees; pitch is nose-down.
STAND = dict(x=0.0, y=0.0, z=0.0, pitch=0.0, yaw=0.0, roll=0.0, neck_p=0.0, neck_yaw=0.0, neck_roll=0.0, head_p=0.0, head_yaw=0.0, head_roll=0.0,
             jaw=0.0, throat=0.0, tail_p=0.0, tail_yaw=0.0,
             fold_r=1.0, fold_l=1.0, elev_r=0.0, elev_l=0.0, sweep_r=0.0, sweep_l=0.0, bend1_r=0.0, bend1_l=0.0, bend2_r=0.0, bend2_l=0.0,
             twist_r=0.0, twist_l=0.0, air=0.0, f_r=(0.0, 0.0, 0.0), f_l=(0.0, 0.0, 0.0), toe_r=0.0, toe_l=0.0, ground=0.0, eyes=0.0)
# In the air: the body level, the neck out, the feet tucked, the wings open.
FLY = dict(STAND, pitch=27.0, neck_p=-17.0, head_p=-8.0, tail_p=-14.0, fold_r=0.0, fold_l=0.0, air=1.0)


def _frame(d, n):
    d = Vector(d).normalized()
    n = Vector(n)
    n = (n - d * n.dot(d)).normalized()
    return Matrix((d, n, d.cross(n))).transposed()


def _shut():
    """What turns the wing, folded flat in its own plane, into a shut wing: laid
    along the flank, the wrist forward of the shoulder, every quill turned on its
    root to lie back down the body. {bone: turn}, for the right side."""
    out_up = (0.94, 0.0, 0.34)                   # the way the top of a shut wing faces
    #        bone      at rest            shut                    parent
    want = [("wing_0", ELBOW - SHOULDER, (0.017, -0.102, -0.05), None),
            ("wing_1", WRIST - ELBOW, (-0.02, 0.125, 0.035), "wing_0"),
            ("wing_2", TIP - WRIST, (0.0, -0.90, -0.42), "wing_1")]
    lie = dict(pri=lambda i: (-0.10 - 0.004 * i, -0.93, -0.30 - 0.014 * i), sec=lambda i: (-0.09, -0.95, -0.34 + 0.012 * i),
               ter=lambda i: (-0.12, -0.95, -0.2 - 0.03 * i))
    for name, bone, root, d, length, width in feathers():
        want.append((bone, d, lie[bone[:3]](int(bone[4:])), f"wing_{FAN[bone[:3]]}"))
    flat = dict(wing_0=rot(yaw=-FOLD), wing_1=rot(yaw=2 * FOLD), wing_2=rot(yaw=-2 * FOLD))
    world, out = {}, {}
    for b, rest, shut, par in want:
        world[b] = (_frame(shut, out_up) @ _frame(rest, (0, 0, 1)).transposed()).to_quaternion()
        local = world[par].inverted() @ world[b] if par else world[b]
        out[b] = local @ flat.get(b, Quaternion()).inverted()
    return out


FAN = dict(pri=2, sec=1, ter=0)
SHUT = _shut()


def pose(r, q):
    p = rig.Pose()
    p.body(loc=(q["x"], q["y"], q["z"]), pitch=q["pitch"], yaw=q["yaw"], roll=q["roll"])
    p.turn("neck", pitch=q["neck_p"], yaw=q["neck_yaw"], roll=q["neck_roll"])
    p.turn("head", pitch=q["head_p"], yaw=q["head_yaw"], roll=q["head_roll"])
    p.turn("jaw", pitch=q["jaw"])
    p.turn("tail", pitch=q["tail_p"], yaw=q["tail_yaw"])
    if q["throat"]:
        p.stretch("throat", (0.0, 0.004 * q["throat"], -0.007 * q["throat"]))
    for side, s in (("r", 1.0), ("l", -1.0)):
        f = q[f"fold_{side}"]
        a = FOLD * f
        g = smooth(min(max(f, 0.0), 1.0))
        flat = dict(wing_0=rot(roll=-s * q[f"elev_{side}"] * (1.0 - 0.8 * f), yaw=s * (q[f"sweep_{side}"] - a)),
                    wing_1=rot(yaw=s * 2.0 * a, roll=-s * q[f"bend1_{side}"] * (1.0 - f)),
                    wing_2=rot(yaw=-s * 2.0 * a, roll=-s * q[f"bend2_{side}"] * (1.0 - f)))
        for n, k in enumerate((0.4, 0.7, 1.0)):
            p.turn(f"wing_fan_{n}_{side}", pitch=q[f"twist_{side}"] * k)
        for b, c in SHUT.items():
            if s < 0:
                c = Quaternion((c.w, c.x, -c.y, -c.z))
            p.fk[f"{b}_{side}"] = Quaternion().slerp(c, g) @ flat.get(b, Quaternion())
        rest = r.rest_ball(side)
        off = q[f"f_{side}"]
        p.foot(side, ball=(rest.x + off[0], rest.y + off[1], rest.z + off[2]), toe=q[f"toe_{side}"], yaw=0.0,
               carried=tuple(TUCK * (s, 1, 1)), space="pelvis", mix=q["air"])
    if q["ground"]:
        p.rest_on_ground(q["ground"])
    p.key("eyes_open", q["eyes"])
    return p


def beat(q, ph, depth=1.0):
    """One wingbeat laid over a flying pose: ph 0..1, the downstroke first."""
    for side in ("r", "l"):
        up = math.sin(2 * math.pi * (ph + 0.25))                 # +1 at the top
        q[f"elev_{side}"] += depth * (7.0 + 33.0 * up)
        q[f"bend1_{side}"] += depth * 20.0 * math.sin(2 * math.pi * (ph + 0.13))
        q[f"bend2_{side}"] += depth * 30.0 * math.sin(2 * math.pi * (ph + 0.03))
        q[f"sweep_{side}"] += depth * 9.0 * math.sin(2 * math.pi * ph)
        q[f"twist_{side}"] += depth * 14.0 * math.cos(2 * math.pi * (ph + 0.25))
        q[f"fold_{side}"] += depth * 0.16 * max(0.0, math.sin(2 * math.pi * (ph - 0.25)))     # drawn in on the way up
    q["z"] += depth * 0.014 * math.sin(2 * math.pi * (ph + 0.05))
    q["tail_p"] += depth * 4.0 * math.sin(2 * math.pi * ph)
    return q


def author(r):
    def keyed(name, base, keys, loop=False, more=None, **kw):
        K = Keys(base, keys)

        def fn(t):
            q = K(t)
            if more is not None:
                more(t, q)
            return pose(r, q)
        r.clip(name, K.duration, fn, loop=loop, **kw)

    def additive(name, duration, fn, loop=False):
        def frame(t):
            p = rig.Pose()
            fn(t, p)
            return p
        r.clip(name, duration, frame, loop=loop)

    # ---- perched
    def idle(t, q):
        b = wave(t, 2.0)
        q["z"] += 0.0025 * b
        q["neck_p"] += 1.5 * b
        q["tail_p"] += 3.0 * pulse(t, 2.6, 2.75, 2.95)            # a flick of the tail
        q["fold_r"] -= 0.05 * pulse(t, 1.0, 1.15, 1.4)            # a wing shrugged and resettled
    keyed("perch_idle", STAND, [
        (0.0, {}), (0.5, {}), (0.62, dict(head_yaw=38.0, head_roll=8.0), "snap"), (1.5, dict(head_yaw=38.0, head_roll=8.0)),
        (1.6, dict(head_yaw=-20.0, head_roll=-10.0, head_p=10.0), "snap"), (2.5, dict(head_yaw=-20.0, head_roll=-10.0, head_p=10.0)),
        (2.62, dict(head_yaw=0.0, head_roll=0.0, head_p=-6.0), "snap"), (3.5, dict(head_p=-6.0)), (4.0, dict(head_p=0.0))], loop=True, more=idle)
    additive("head_cock", 0.3, lambda t, p: p.turn("head", roll=24.0 * rig.ease_out(seg(t, 0.0, 0.1), 3.0), yaw=10.0 * smooth(seg(t, 0.0, 0.12))))
    keyed("caw", STAND, [
        (0.0, {}), (0.14, dict(pitch=-6.0, neck_p=-8.0, head_p=-6.0)),
        (0.26, dict(pitch=16.0, neck_p=16.0, head_p=-12.0, jaw=26.0, tail_p=16.0, throat=1.0, fold_r=0.93, fold_l=0.93), "snap"),
        (0.5, dict(pitch=13.0, neck_p=13.0, jaw=22.0, throat=0.6)), (0.8, dict(STAND))])
    keyed("shriek", STAND, [
        (0.0, {}), (0.1, dict(pitch=-10.0, neck_p=-10.0, z=0.006)),
        (0.24, dict(pitch=20.0, neck_p=20.0, head_p=-22.0, jaw=40.0, throat=1.0, tail_p=20.0, fold_r=0.45, fold_l=0.45, elev_r=30.0, elev_l=30.0,
                    eyes=1.0, z=-0.008), "snap"),
        (0.8, dict(pitch=17.0, jaw=36.0, fold_r=0.5, fold_l=0.5, elev_r=22.0, elev_l=22.0)), (0.86, dict(eyes=1.0)), (1.0, dict(STAND))],
          more=lambda t, q: q.update(head_roll=5.0 * rig.ring(t, 0.24, 1.0, 16.0, 2.0) * (0.24 < t < 0.85),
                                     elev_r=q["elev_r"] + 8.0 * wave(t, 0.14) * (0.24 < t < 0.85),
                                     elev_l=q["elev_l"] + 8.0 * wave(t, 0.14, 0.3) * (0.24 < t < 0.85)))
    additive("mimic", 1.5, lambda t, p: (p.turn("jaw", pitch=5.0 + 4.0 * wave(t, 0.25) + 3.0 * wave(t, 0.1875, 0.2)),
                                          p.stretch("throat", (0.0, 0.002, -0.004 * (0.6 + 0.4 * wave(t, 0.3)))),
                                          p.turn("head", pitch=-4.0 + 1.5 * wave(t, 0.75))), loop=True)
    keyed("peck", STAND, [
        (0.0, dict(pitch=34.0, neck_p=30.0, head_p=20.0, z=-0.012, tail_p=-20.0)),
        (0.12, dict(pitch=46.0, neck_p=44.0, head_p=30.0, jaw=10.0, z=-0.018), "whip"), (0.24, dict(pitch=36.0, neck_p=30.0, head_p=16.0, jaw=4.0)),
        (0.36, dict(pitch=46.0, neck_p=44.0, head_p=30.0, jaw=12.0, z=-0.018), "whip"),
        (0.55, dict(pitch=30.0, neck_p=20.0, head_p=4.0, head_roll=14.0, jaw=6.0)),         # a tug and a toss
        (0.75, dict(pitch=26.0, neck_p=6.0, head_p=-20.0, head_roll=-8.0, jaw=16.0), "snap"),
        (1.2, dict(pitch=34.0, neck_p=30.0, head_p=20.0, z=-0.012, tail_p=-20.0, jaw=0.0, head_roll=0.0))], loop=True)

    # ---- on the ground
    def walk_up(t, ph, p):
        q = dict(STAND, pitch=8.0, neck_p=-4.0, z=0.003 * math.cos(4 * math.pi * ph), roll=3.0 * math.sin(2 * math.pi * ph),
                 yaw=4.0 * math.cos(2 * math.pi * ph), y=0.0)
        bob = math.sin(4 * math.pi * ph)                                   # the head holds, then darts on
        q.update(neck_p=-4.0 + 9.0 * bob, head_p=-5.0 * bob, tail_yaw=-5.0 * math.cos(2 * math.pi * ph))
        full = pose(r, q)
        for k in ("body_loc", "body_rot", "fk", "offsets", "keys"):
            setattr(p, k, getattr(full, k))
    r.gait("walk", speed=0.45, stride=0.2, duty=0.62, phases={"r": 0.0, "l": 0.5}, lift=0.02, upper=walk_up, heel_off=0.0, swing_heel=0.0,
           toe_swing=-22.0, yaw=0.0)

    def hop_up(t, ph, p):
        air = math.sin(math.pi * seg(ph, 0.42, 1.0))
        q = dict(STAND, pitch=10.0 - 8.0 * air, z=0.035 * air - 0.012 * pulse(ph, 0.0, 0.14, 0.4), neck_p=-6.0 + 8.0 * air, tail_p=-8.0 * air,
                 fold_r=1.0 - 0.1 * air, fold_l=1.0 - 0.1 * air, elev_r=30.0 * air, elev_l=30.0 * air)
        full = pose(r, q)
        for k in ("body_loc", "body_rot", "fk", "offsets", "keys"):
            setattr(p, k, getattr(full, k))
    r.gait("hop", speed=1.2, stride=0.42, duty=0.42, phases={"r": 0.0, "l": 0.04}, lift=0.03, upper=hop_up, heel_off=0.0, swing_heel=0.0,
           toe_swing=-30.0, yaw=0.0)

    # ---- in the air
    T = 9.0 / 30.0
    r.clip("fly", T, lambda t: pose(r, beat(dict(FLY), t / T)), loop=True, speed=9.0)
    r.clip("glide", 2.0, lambda t: pose(r, dict(FLY, elev_r=9.0 + 2.0 * wave(t, 2.0), elev_l=9.0 + 2.0 * wave(t, 2.0, 0.5), bend2_r=7.0, bend2_l=7.0,
                                                  roll=3.5 * wave(t, 2.0), tail_yaw=-4.0 * wave(t, 2.0), tail_p=-14.0 + 2.0 * wave(t, 1.0),
                                                  head_yaw=6.0 * wave(t, 2.0, 0.2), z=0.004 * wave(t, 1.0))), loop=True)

    def lift_off(t, q):
        if t > 0.2:
            beat(q, (t - 0.2) / 0.2, depth=smooth(seg(t, 0.2, 0.32)) * 1.25)
    keyed("take_off", STAND, [
        (0.0, {}), (0.14, dict(pitch=22.0, z=-0.03, neck_p=-10.0, tail_p=-10.0, fold_r=0.55, fold_l=0.55, elev_r=40.0, elev_l=40.0)),
        (0.24, dict(pitch=-12.0, z=0.05, air=0.3, fold_r=0.0, fold_l=0.0, elev_r=0.0, elev_l=0.0, toe_r=-30.0, toe_l=-30.0), "snap"),
        (0.6, dict(FLY, pitch=10.0, z=0.12))], more=lift_off)

    def set_down(t, q):
        if t < 0.42:
            beat(q, t / 0.2, depth=1.2 * (1.0 - smooth(seg(t, 0.25, 0.42))))
    keyed("land", dict(FLY, z=0.12), [
        (0.0, {}), (0.22, dict(pitch=-28.0, z=0.06, air=0.35, tail_p=-34.0, neck_p=6.0, f_r=(0.0, 0.03, 0.0), f_l=(0.0, 0.03, 0.0), toe_r=-20.0, toe_l=-20.0)),
        (0.4, dict(STAND, pitch=14.0, z=-0.026, fold_r=0.35, fold_l=0.35, elev_r=35.0, elev_l=35.0, tail_p=14.0), "out"),
        (0.6, dict(STAND))], more=set_down)

    # ---- attacks: telegraph_<row id> then attack_<row id>
    keyed("telegraph_crow_peck", STAND, [
        (0.0, {}), (0.24, dict(pitch=-14.0, neck_p=-22.0, head_p=10.0, z=0.006, jaw=8.0, fold_r=0.9, fold_l=0.9, tail_p=10.0), "out"),
        (0.4, dict(pitch=-16.0, neck_p=-24.0))])
    keyed("attack_crow_peck", dict(STAND, pitch=-16.0, neck_p=-24.0, head_p=10.0, z=0.006, jaw=8.0, fold_r=0.9, fold_l=0.9, tail_p=10.0), [
        (0.0, {}), (0.1, dict(pitch=30.0, neck_p=34.0, head_p=4.0, y=0.03, z=-0.012, jaw=2.0, tail_p=-18.0, fold_r=0.8, fold_l=0.8, elev_r=20.0, elev_l=20.0), "whip"),
        (0.18, dict(pitch=24.0, neck_p=20.0, jaw=12.0)), (0.35, dict(STAND))], contact=0.1)
    keyed("telegraph_crow_dive", FLY, [
        (0.0, {}), (0.2, dict(pitch=-24.0, z=0.05, elev_r=42.0, elev_l=42.0, tail_p=-30.0, neck_p=4.0), "out"),
        (0.45, dict(pitch=-8.0, z=0.07, fold_r=0.6, fold_l=0.6, elev_r=30.0, elev_l=30.0, neck_p=14.0, head_p=10.0))])
    keyed("attack_crow_dive", dict(FLY, pitch=-8.0, z=0.07, fold_r=0.6, fold_l=0.6, elev_r=30.0, elev_l=30.0, neck_p=14.0, head_p=10.0, tail_p=-30.0), [
        (0.0, {}), (0.3, dict(pitch=62.0, z=-0.04, fold_r=0.72, fold_l=0.72, elev_r=10.0, elev_l=10.0, neck_p=-26.0, head_p=-14.0, tail_p=-4.0), "whip"),
        (0.4, dict(pitch=-30.0, z=-0.02, air=0.0, f_r=(0.01, 0.1, 0.07), f_l=(-0.01, 0.1, 0.07), toe_r=-35.0, toe_l=-35.0, fold_r=0.05, fold_l=0.05,
                   elev_r=48.0, elev_l=48.0, jaw=24.0, neck_p=20.0, head_p=14.0, tail_p=-36.0), "snap"),          # talons out, wings braking
        (0.6, dict(FLY, pitch=-6.0, z=0.05))], contact=0.4, travel=4.0)

    # ---- hurt
    for side, s in (("l", 1.0), ("r", -1.0)):
        additive(f"hit_{side}", 0.25, lambda t, p, s=s: (p.body(loc=(0.012 * s * pulse(t, 0.0, 0.06, 0.25), 0.0, 0.0), roll=-16.0 * s * pulse(t, 0.0, 0.06, 0.25)),
                                                          p.turn("head", roll=14.0 * s * pulse(t, 0.0, 0.08, 0.25)), p.turn("jaw", pitch=18.0 * pulse(t, 0.0, 0.05, 0.2))))
        keyed(f"death_{side}", STAND, [
            (0.0, {}), (0.1, dict(roll=-20.0 * s, jaw=26.0, fold_r=0.6, fold_l=0.6, elev_r=30.0, elev_l=30.0, z=0.01), "snap"),
            (0.5, dict(roll=-84.0 * s, x=-0.07 * s, z=-0.06, air=1.0, neck_p=-20.0, fold_r=0.5, fold_l=0.75, elev_r=-10.0, elev_l=20.0, tail_p=10.0), "slow"),
            (0.75, dict(roll=-96.0 * s, x=-0.1 * s, ground=1.0, air=1.0, neck_p=14.0, head_roll=-24.0 * s, jaw=14.0, fold_r=0.4, fold_l=0.8), "lin"),
            (1.2, dict(roll=-90.0 * s, neck_p=20.0, head_roll=-30.0 * s, jaw=10.0))])
    keyed("death_air", FLY, [
        (0.0, {}), (0.12, dict(pitch=-30.0, roll=26.0, jaw=30.0, elev_r=50.0, elev_l=-10.0, bend2_l=-30.0, neck_p=20.0), "snap"),
        (0.6, dict(pitch=80.0, roll=150.0, yaw=60.0, fold_r=0.3, fold_l=0.55, elev_r=40.0, elev_l=40.0, bend1_r=30.0, bend2_r=40.0, neck_p=-25.0,
                   air=0.6, tail_p=20.0), "lin"),
        (1.2, dict(pitch=160.0, roll=320.0, yaw=140.0, fold_r=0.45, fold_l=0.35, elev_r=55.0, elev_l=35.0, neck_p=25.0, head_roll=30.0, air=0.3), "lin")])


# ------------------------------------------------------------------ build

def build(fast=False, bake=True):
    kit.reset()
    body, legs = forms()
    leg_field = kit.field(legs)
    s = kit.union(body + legs, NAME + "_sculpt", voxel=0.0034 if fast else 0.0024, project=5)
    kit.drop_hollows(s)
    kit.shade_smooth(s)
    kit.paint(s, "zone", lambda P, N: kit.ss(1.0 - leg_field(P) / 0.004))
    kit.set_material(s, body_material())
    hard = hard_parts(s)
    low = kit.game_mesh(s, NAME, BODY_TRIS, keep=lambda P: kit.ss((P[:, 2] - 0.25) / 0.03) + kit.ss(1.0 - leg_field(P) / 0.006), keep_bias=0.75)
    kit.tag(low, 0)
    arm = rig.build_armature(NAME, bones())
    rig.bind_near(low, arm, skin_bones(), sigma=0.012)
    pieces, hidden = [], []
    for src, lo, part, bone in hard:
        g = lo if lo is not None else kit.duplicate(src, src.name + "_g")
        rig.bind_rigid(g, bone)
        pieces.append(g)
    P, N = kit.co(s), kit.normals(s)
    for near, radius, bone in HIDDEN:
        j = int(np.argmin(np.linalg.norm(P - np.array(near), axis=1)))
        n = N[j] / np.linalg.norm(N[j])
        hidden.append((P[j] - n * radius * 0.35, n, radius))
    low = kit.join([low] + pieces, NAME)
    kit.triangulate(low)
    if bake:
        kit.unwrap(low, boost=lambda Q: 1.0 + 0.8 * kit.ss((Q[:, 2] - 0.24) / 0.03) * kit.ss((Q[:, 1] - 0.08) / 0.03), centre=(0.0, 0.14, 0.29))
    rig.attach(low, arm)
    sources = [s] + [src for src, _, _, _ in hard]
    paths = {}
    if bake:
        P, part = kit.co(low), kit.parts_of(low)
        eyes = (part >= 40) & (part < 40 + len(HIDDEN))
        P[eyes] += AWAY
        kit.set_co(low, P)
        _, paths = kit.bake(sources, low, NAME, OUT, size=512 if fast else 1024, extrusion=0.006)
        P[eyes] -= AWAY
        kit.set_co(low, P)
    else:
        kit.set_material(low, kit.plain("clay", (0.2, 0.22, 0.22), 0.5))
    eye_keys(low, hidden)
    r = rig.Rig(arm, low, spec())
    author(r)
    r.finish()
    return sources, low, arm, r, paths


if __name__ == "__main__":
    args = sys.argv[1:]
    hide, low, arm, r, paths = build("--fast" in args, bake="--nobake" not in args)
    for name, rep in r.report.items():
        print(f"clip {name}: " + " ".join(f"{k}={v:.4f}" for k, v in rep.items()))
    if "--preview" in args:
        import preview
        d = args[args.index("--preview") + 1]
        want = [a for a in args[args.index("--preview") + 2:] if not a.startswith("--")]
        cams = dict(q=((0.75, 0.95, 0.5), (0, 0.0, 0.17), 50), side=((1.4, 0.0, 0.2), (0, 0.0, 0.17), 60), top=((0.0, -0.05, 1.7), (0, 0.0, 0.1), 50),
                    face=((0.2, 0.42, 0.34), (0, 0.15, 0.28), 70), front=((0.0, 1.5, 0.3), (0, 0, 0.18), 60))
        for v in want:
            if v in cams:
                preview.shot(os.path.join(d, f"{NAME}_sculpt_{v}.png"), cams[v], hide=[low], samples=24, res=(900, 700))
                preview.shot(os.path.join(d, f"{NAME}_low_{v}.png"), cams[v], hide=hide, samples=24, res=(900, 700))
            else:
                clip, cam, at = (v.split("@") + ["q", ""])[:3]
                ts = [float(x) for x in at.split(",")] if at else [0.0, 0.33, 0.66, 1.0]
                preview.strip(arm, low, clip, os.path.join(d, f"{NAME}_clip_{clip}_{cam}.png"), extra=hide, view=cams[cam or "q"], at=ts, frames=len(ts),
                              res=(700, 560))
    if "--noexport" not in args:
        for o in hide:
            bpy.data.objects.remove(o, do_unlink=True)
        path = kit.export_gltf(NAME, [low, arm], OUT)
        rig.write_gaits(NAME, r, f"creatures/models/fae/{NAME}.gltf")
        print(f"{NAME}: {kit.tris(low)} tris -> {path}")
