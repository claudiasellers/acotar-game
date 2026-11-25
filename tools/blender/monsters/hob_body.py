"""The Hollow Hob's body: joints, clay forms, the moss mantle and surface zones.

Bestiary §10 (FINAL): a hill that breathes. A huge, hunched, round-backed
lesser fae, about 4.5 m standing and 2.5 m on its knuckles, with arms that
reach the ground, huge blunt hands, short thick legs, a heavy belly and a
small head sunk between massive shoulders. Skin like weathered granite; moss,
lichen and grass over its back, shoulders and scalp.

Imported by hob.py. Everything is built in the rest pose: standing at full
height, arms held out and down, fingers spread, the mouth a little open.
"""

import math

import numpy as np
from mathutils import Matrix, Vector

import kit


def _v(*a):
    return np.array(a, dtype=np.float64)


# ------------------------------------------------------------------ joints
# Right side (+x); the left is mirrored. Metres, y forward, z up.

J = {
    "pelvis": _v(0, -0.05, 2.0),
    "spine": _v(0, -0.10, 2.35),
    "spine2": _v(0, -0.14, 2.75),
    "chest_end": _v(0, -0.08, 3.38),
    "neck": _v(0, 0.08, 3.48),
    "head": _v(0, 0.25, 3.64),
    "head_end": _v(0, 0.64, 3.68),
    "jaw": _v(0, 0.30, 3.60),
    "jaw_end": _v(0, 0.68, 3.50),
    "clav": _v(0.18, 0.0, 3.42),
    "arm": _v(0.95, -0.05, 3.42),
    "forearm": _v(1.40, -0.10, 2.30),
    "hand": _v(1.76, 0.02, 1.22),
    "knuckle": _v(1.87, 0.06, 0.93),
    "upper": _v(0.42, -0.02, 1.95),
    "lower": _v(0.50, 0.22, 1.08),
    "foot": _v(0.48, -0.06, 0.30),
    "paw": _v(0.50, 0.30, 0.10),
    "paw_end": _v(0.52, 0.62, 0.07),
}

FWD = _v(0, 1, 0)
HAND_DIR = (J["knuckle"] - J["hand"]) / np.linalg.norm(J["knuckle"] - J["hand"])
PALM = _v(-0.93, 0.1, -0.34)                # the way the palm faces at rest (right hand)
PALM /= np.linalg.norm(PALM)
FINGER_LEN = (0.17, 0.13, 0.11)
FINGER_R = (0.066, 0.062, 0.055, 0.046)
THUMB_LEN = (0.14, 0.11, 0.09)


def fingers():
    """[(root, mid, mid2, tip)] for the right hand: four thick fingers, the
    first on the thumb's side (+y)."""
    out = []
    for i in range(4):
        k = 1.5 - i
        spread = k * 0.2
        d = HAND_DIR * math.cos(spread) + FWD * math.sin(spread)
        d /= np.linalg.norm(d)
        pts = [J["knuckle"] + FWD * (k * 0.1) - HAND_DIR * (abs(k) * 0.02)]
        for n, L in enumerate(FINGER_LEN):
            dd = d + PALM * (0.14 * n)
            pts.append(pts[-1] + dd / np.linalg.norm(dd) * L * (0.92 if i in (0, 3) else 1.0))
        out.append(tuple(pts))
    return out


def thumb():
    """(root, mid, mid2, tip) for the right thumb, off the front edge of the palm."""
    root = J["hand"] + (J["knuckle"] - J["hand"]) * 0.3 + FWD * 0.15 + PALM * 0.03
    d = FWD * 0.8 + HAND_DIR * 0.55 + PALM * 0.2
    pts = [root]
    for n, L in enumerate(THUMB_LEN):
        dd = d / np.linalg.norm(d) + PALM * (0.12 * n) + HAND_DIR * (0.15 * n)
        pts.append(pts[-1] + dd / np.linalg.norm(dd) * L)
    return tuple(pts)


def toes():
    """[(root, tip)] for the right foot: four blunt toes."""
    out = []
    for dx, ang, L in ((-0.135, -0.22, 0.2), (-0.045, -0.07, 0.25), (0.05, 0.08, 0.24), (0.14, 0.24, 0.2)):
        root = J["paw"] + _v(dx, 0.07, -0.02)
        d = _v(math.sin(ang), math.cos(ang), -0.04)
        out.append((root, root + d / np.linalg.norm(d) * L))
    return out


# ------------------------------------------------------------------ the face

EYE = _v(0.115, 0.548, 3.74)
EYE_R = 0.03
MOUTH_BACK = 0.43


def mouth_z(y):
    """Height of the lip line at depth y: the corners turn down."""
    return 3.598 - 0.028 * kit.ss((0.58 - y) / 0.14)


def jaw_half_width(y):
    """Half width of the tooth row at depth y."""
    pts = ((0.42, 0.185), (0.5, 0.19), (0.58, 0.165), (0.64, 0.115), (0.675, 0.05))
    return float(np.interp(y, [p[0] for p in pts], [p[1] for p in pts]))


# ------------------------------------------------------------------ clay

def forms():
    """Every lump of clay in the body, biggest first (midline and right side;
    the caller mirrors the sided ones)."""
    mid, side = [], []
    t, e = kit.tube, kit.ellipsoid
    R = 26              # rings per metre for the big limbs

    # torso: a barrel, wider at the shoulders, round-backed
    mid.append(t("torso", [(0, -0.02, 1.74), (0, -0.03, 2.0), (0, -0.06, 2.35), (0, -0.12, 2.75), (0, -0.16, 3.1),
                           (0, -0.10, 3.38), (0, 0.0, 3.55)],
                 [(0.52, 0.42), (0.62, 0.5), (0.66, 0.56), (0.74, 0.6), (0.80, 0.6), (0.70, 0.5), (0.36, 0.32)],
                 segs=36, k=0.1, rings_per_m=R))
    mid.append(e("belly", (0, 0.34, 2.36), (0.54, 0.4, 0.52), rot=(8, 0, 0), k=0.22))
    mid.append(e("gut_fold", (0, 0.42, 2.08), (0.44, 0.26, 0.2), k=0.1))
    mid.append(e("hump", (0, -0.52, 3.22), (0.62, 0.34, 0.52), rot=(-16, 0, 0), k=0.3))
    mid.append(e("low_back", (0, -0.46, 2.55), (0.5, 0.2, 0.4), rot=(6, 0, 0), k=0.25))
    mid.append(e("sternum", (0, 0.42, 3.0), (0.2, 0.08, 0.3), rot=(-10, 0, 0), k=0.15))
    # a short thick neck, carried forward
    mid.append(t("neck", [(0, -0.05, 3.38), (0, 0.09, 3.5), (0, 0.22, 3.62), (0, 0.3, 3.68)],
                 [(0.3, 0.29), (0.27, 0.25), (0.24, 0.22), (0.22, 0.2)], segs=24, k=0.1, rings_per_m=R))
    mid.append(e("dewlap", (0, 0.3, 3.44), (0.16, 0.12, 0.13), k=0.08))

    # the head: small for the body, low-browed, wide-mouthed
    mid.append(e("skull", (0, 0.36, 3.755), (0.225, 0.25, 0.185), rot=(-6, 0, 0), k=0.05))
    mid.append(e("crown", (0, 0.27, 3.86), (0.17, 0.19, 0.09), k=0.06))
    mid.append(e("muzzle", (0, 0.525, 3.662), (0.2, 0.135, 0.068), k=0.035))
    mid.append(t("lower_jaw", [(0, 0.34, 3.535), (0, 0.46, 3.525), (0, 0.6, 3.53), (0, 0.685, 3.547)],
                 [(0.2, 0.062), (0.225, 0.066), (0.2, 0.06), (0.125, 0.046)], segs=24, k=0.03, rings_per_m=60))
    mid.append(e("chin", (0, 0.665, 3.512), (0.11, 0.065, 0.055), k=0.03))
    mid.append(e("nose", (0, 0.655, 3.705), (0.085, 0.05, 0.055), k=0.03))
    mid.append(e("nose_bridge", (0, 0.61, 3.755), (0.05, 0.05, 0.05), k=0.03))
    side.append(e("nostril_wing", (0.06, 0.66, 3.69), (0.04, 0.035, 0.035), k=0.02))
    side.append(t("brow", [(0.0, 0.615, 3.8), (0.1, 0.625, 3.808), (0.19, 0.585, 3.8), (0.245, 0.48, 3.782)],
                  [0.052, 0.066, 0.062, 0.042], segs=12, k=0.03, rings_per_m=80))
    side.append(e("cheekbone", (0.19, 0.5, 3.7), (0.06, 0.09, 0.05), k=0.04))
    side.append(e("jowl", (0.19, 0.4, 3.56), (0.07, 0.12, 0.09), k=0.05))
    side.append(e("jaw_muscle", (0.215, 0.33, 3.64), (0.05, 0.09, 0.1), k=0.05))
    side.append(e("ear", (0.245, 0.27, 3.74), (0.03, 0.07, 0.085), rot=(0, 0, -25), k=0.02))
    side.append(e("ear_lobe", (0.255, 0.275, 3.66), (0.025, 0.04, 0.045), k=0.02))

    # shoulders: the head sits between them, not on them
    side.append(t("trapezius", [(0.12, -0.12, 3.66), (0.42, -0.14, 3.74), (0.72, -0.12, 3.68), (0.96, -0.08, 3.52)],
                  [(0.24, 0.26), (0.27, 0.3), (0.28, 0.3), (0.26, 0.28)], segs=20, k=0.2, rings_per_m=R))
    side.append(e("pec", (0.36, 0.36, 3.02), (0.34, 0.15, 0.27), rot=(0, -8, 0), k=0.2))
    side.append(e("scapula", (0.5, -0.56, 3.1), (0.27, 0.13, 0.36), rot=(8, 0, 14), k=0.2))
    side.append(e("lat", (0.66, -0.2, 2.75), (0.16, 0.34, 0.42), k=0.2))
    side.append(e("love_handle", (0.6, 0.1, 2.2), (0.16, 0.34, 0.24), k=0.15))

    # arm: long, the forearm heavier than the upper arm
    a, f, h, kn = J["arm"], J["forearm"], J["hand"], J["knuckle"]
    side.append(e("deltoid", a + _v(0.05, 0.0, 0.0), (0.36, 0.36, 0.42), rot=(0, -24, 0), k=0.15))
    side.append(t("upper_arm", [a, a + (f - a) * 0.45, f], [(0.27, 0.28), (0.235, 0.25), (0.2, 0.2)],
                  side=(0, 1, 0), segs=24, k=0.12, rings_per_m=R))
    side.append(e("biceps", a + (f - a) * 0.5 + _v(0.02, 0.15, 0.03), (0.15, 0.15, 0.36), rot=(0, -22, 0), k=0.1))
    side.append(e("triceps", a + (f - a) * 0.42 + _v(-0.02, -0.16, -0.03), (0.16, 0.15, 0.4), rot=(0, -22, 0), k=0.1))
    side.append(t("fore_arm", [f, f + (h - f) * 0.25, f + (h - f) * 0.65, h],
                  [(0.22, 0.21), (0.3, 0.265), (0.245, 0.21), (0.185, 0.15)], side=(0, 1, 0), segs=24, k=0.1, rings_per_m=R))
    side.append(e("elbow", f + _v(-0.04, -0.15, 0.03), (0.1, 0.1, 0.12), k=0.06))
    side.append(e("wrist_bone", h + _v(0.03, -0.12, 0.03), (0.06, 0.06, 0.07), k=0.04))
    side.append(t("palm", [h - HAND_DIR * 0.03, h + (kn - h) * 0.5, kn + HAND_DIR * 0.04],
                  [(0.19, 0.1), (0.235, 0.105), (0.245, 0.085)], side=(0, 1, 0), segs=20, k=0.06, rings_per_m=40))
    for i, pts in enumerate(fingers()):
        side.append(t(f"finger{i}", [pts[0] - HAND_DIR * 0.09] + list(pts), [FINGER_R[0] * 1.02] + list(FINGER_R),
                      segs=12, rings_per_m=50, k=0.02))
        side.append(e(f"knuckle{i}", pts[0] - PALM * 0.024, 0.074, k=0.03))
        side.append(e(f"joint{i}", pts[1] - PALM * 0.018, 0.066, k=0.02))
        side.append(e(f"joint{i}b", pts[2] - PALM * 0.014, 0.057, k=0.02))
    th = thumb()
    side.append(t("thumb", [th[0] - (th[1] - th[0]) * 0.6] + list(th), [0.085, 0.078, 0.07, 0.062, 0.052],
                  segs=12, rings_per_m=50, k=0.03))
    side.append(e("thumb_pad", th[0] + PALM * 0.03 - FWD * 0.03, (0.09, 0.1, 0.1), k=0.05))

    # legs: short, thick, flat-footed
    u, l, ft, pw = J["upper"], J["lower"], J["foot"], J["paw"]
    side.append(e("glute", (0.36, -0.36, 1.95), (0.36, 0.3, 0.38), k=0.2))
    side.append(t("thigh", [u + _v(-0.02, 0, 0.12), u + (l - u) * 0.45, l],
                  [(0.42, 0.44), (0.39, 0.41), (0.28, 0.3)], segs=26, k=0.18, rings_per_m=R))
    side.append(e("kneecap", l + _v(0, 0.2, 0.02), (0.16, 0.1, 0.18), k=0.08))
    side.append(t("shin", [l, l + (ft - l) * 0.3, l + (ft - l) * 0.72, ft],
                  [(0.27, 0.29), (0.28, 0.33), (0.22, 0.25), (0.19, 0.21)], segs=22, k=0.1, rings_per_m=R))
    side.append(e("calf", l + (ft - l) * 0.3 + _v(0, -0.14, -0.03), (0.2, 0.18, 0.36), rot=(-18, 0, 0), k=0.1))
    side.append(e("heel", (0.48, -0.19, 0.14), (0.19, 0.17, 0.14), k=0.06))
    side.append(t("foot", [(0.48, -0.1, 0.17), (0.49, 0.12, 0.17), (0.5, 0.34, 0.11)],
                  [(0.19, 0.16), (0.22, 0.14), (0.25, 0.09)], segs=18, k=0.06, rings_per_m=40))
    for i, (root, tip) in enumerate(toes()):
        side.append(t(f"toe{i}", [root - _v(0, 0.12, 0), root + (tip - root) * 0.5 + _v(0, 0, 0.012), tip],
                      [(0.07, 0.062), (0.068, 0.058), (0.06, 0.05)], segs=10, rings_per_m=50, k=0.025))
    return mid, side


# ------------------------------------------------------------------ the moss mantle

LUMPS = []          # [(centre, radius, normal)]: filled by mantle(); the moss's zone, weights and tufts read it


def _onto(f, p, rounds=8):
    """Slides points onto the clay's surface along its gradient; returns them and the normals."""
    p = np.array(p, dtype=np.float64)
    e = 0.01
    offs = np.array(((1, -1, -1), (-1, -1, 1), (-1, 1, -1), (1, 1, 1)), dtype=np.float64)
    g = np.zeros_like(p)
    for _ in range(rounds):
        g = np.zeros_like(p)
        for o in offs:
            g += o[None, :] * f(p + o * e)[:, None]
        g /= np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-9)
        p = p - g * f(p)[:, None]
    return p, g


def mantle(f):
    """Moss in thick cushions over the back, the shoulders and the scalp: clay
    forms laid on the body's surface (`f` is the body's distance field)."""
    rng = np.random.RandomState(11)
    seeds = []
    # the back and the tops of the shoulders: directions from the middle of the chest
    c0 = _v(0, -0.1, 3.05)
    while len(seeds) < 52:
        d = rng.normal(size=3)
        d /= np.linalg.norm(d)
        if d[1] > 0.18 or d[2] < -0.45 or (d[1] > -0.2 and d[2] < 0.55):
            continue
        seeds.append(c0 + d * _v(1.15, 0.95, 0.95))
    # the upper arms' outer faces and the scalp
    for s in (1, -1):
        seeds.append(_v(1.2 * s, -0.25, 3.2))
        seeds.append(_v(1.25 * s, -0.2, 2.9))
        seeds.append(_v(0.7 * s, -0.5, 3.75))
    seeds += [_v(0.03, 0.2, 4.0), _v(-0.1, 0.1, 3.98), _v(0.12, 0.32, 3.99)]
    P, N = _onto(f, np.array(seeds))
    LUMPS.clear()
    out = []
    for i, (p, n) in enumerate(zip(P, N)):
        scalp = i >= len(seeds) - 3
        r = (0.085 + 0.03 * rng.rand()) if scalp else (0.13 + 0.12 * rng.rand())
        z = Vector(n)
        x = z.orthogonal().normalized()
        y = z.cross(x)
        rot = Matrix((x, y, z)).transposed().to_euler("XYZ")
        thick = r * (0.3 + 0.16 * rng.rand())
        c = p + n * thick * 0.15
        out.append(kit.ellipsoid(f"moss{i}", tuple(c), (r, r * (0.75 + 0.3 * rng.rand()), thick),
                                 rot=tuple(math.degrees(a) for a in rot), k=0.11, segs=16))
        LUMPS.append((c, r, n))
    return out


def moss_near(P):
    """0..1: on or beside a cushion of moss."""
    m = np.zeros(len(P))
    for c, r, _ in LUMPS:
        m = np.maximum(m, kit.ss(1.5 - np.linalg.norm(P - c, axis=1) / r))
    return m


# ------------------------------------------------------------------ cutters

def cutters():
    """The mouth slot (wide, turned down at the corners), a hollow behind the
    teeth, deep eye sockets and nostrils."""
    out = []
    ys = (0.76, 0.66, 0.56, 0.48, MOUTH_BACK)
    out.append(kit.tube("mouth", [(0, y, mouth_z(y)) for y in ys],
                        [(0.2, 0.006), (0.24, 0.007), (0.26, 0.008), (0.27, 0.008), (0.26, 0.005)], segs=18, cap=0.2))
    out.append(kit.tube("gullet", [(0, 0.63, mouth_z(0.63) - 0.004), (0, 0.54, mouth_z(0.54)), (0, 0.44, mouth_z(0.44))],
                        [(0.07, 0.03), (0.13, 0.045), (0.15, 0.04)], segs=16))
    for s in (1, -1):
        out.append(kit.ellipsoid(f"socket{s}", EYE * (s, 1, 1) + _v(0, 0.012, -0.004), (0.04, 0.045, 0.03)))
        out.append(kit.ellipsoid(f"nostril{s}", (0.04 * s, 0.7, 3.685), (0.02, 0.03, 0.016), rot=(20, 0, 20 * s)))
        out.append(kit.ellipsoid(f"earhole{s}", (0.27 * s, 0.29, 3.73), (0.02, 0.025, 0.035)))
    return out


# ------------------------------------------------------------------ zones

def nail_points():
    """[(tip, outward direction)] for every finger, thumb and toe nail (both sides)."""
    out = []
    for s in (1, -1):
        flip = _v(s, 1, 1)
        for pts in fingers() + [thumb()]:
            out.append((pts[3] * flip, -PALM * flip, 0.06))
        for root, tip in toes():
            out.append((tip * flip, _v(0, 0.3, 1.0), 0.075))
    return out


def zones(P, N):
    """Masks the surface material and the game mesh's detail weights read."""
    x, y, z = np.abs(P[:, 0]), P[:, 1], P[:, 2]
    z_ = {}
    up = kit.ss((N[:, 2] - 0.15) / 0.5)
    lumps = moss_near(P)
    film = up * kit.ss((z - 2.5) / 0.3) * kit.ss((0.3 - y) / 0.3) * 0.75      # a thin film on every ledge of the back
    scalp = up * kit.ss((z - 3.82) / 0.05) * kit.ss((0.5 - y) / 0.1)
    z_["moss"] = np.clip(np.maximum(lumps, np.maximum(film, scalp)), 0, 1)
    z_["up"] = up
    in_head = (y > 0.4) & (z > 3.45) & (z < 3.7) & (x < 0.3)
    dz = z - np.array([mouth_z(v) for v in y])
    inside = (y < 0.64) & (x < np.interp(y, (0.42, 0.5, 0.58, 0.64, 0.675), (0.185, 0.19, 0.165, 0.115, 0.05)) - 0.005)
    z_["mouth"] = (in_head & inside & (np.abs(dz) < 0.06) & (N[:, 2] * np.sign(dz) < -0.5)).astype(float)
    nail = np.zeros(len(P))
    for tip, out_dir, r in nail_points():
        v = P - tip
        d = np.linalg.norm(v, axis=1)
        nail = np.maximum(nail, kit.ss((r - d) / 0.015) * kit.ss((N @ (out_dir / np.linalg.norm(out_dir)) - 0.35) / 0.3))
    z_["nail"] = nail
    # the belly and the insides of the limbs: paler, smoother, less cracked
    z_["soft"] = np.clip(kit.ss((N[:, 1] - 0.2) / 0.5) * kit.ss((z - 1.8) / 0.2) * kit.ss((3.3 - z) / 0.2) * kit.ss((0.7 - x) / 0.2), 0, 1)
    hand_d, _ = kit.seg_dist(P * np.where(P[:, :1] < 0, (-1, 1, 1), (1, 1, 1)), J["hand"], J["knuckle"] + HAND_DIR * 0.4)
    z_["keep"] = np.clip(kit.ss((z - 3.42) / 0.08) * kit.ss((y - 0.12) / 0.1) * 1.0 + kit.ss((0.5 - hand_d) / 0.1) * 0.75
                         + kit.ss((0.3 - z) / 0.1) * 0.35, 0, 1)
    return z_


# ------------------------------------------------------------------ surface

def rock_field(P, N):
    """Relief the voxels can hold: the skin's big slabs and the moss's cushions."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    slab = (np.sin(x * 5.3 + z * 2.1 + 1.0) * np.sin(y * 4.7 - z * 3.9 + 0.4) * np.sin(z * 6.1 + x * 1.7))
    fine = np.sin(x * 17.0 + y * 9.0) * np.sin(y * 15.0 - z * 13.0) * np.sin(z * 19.0 + x * 7.0)
    moss = moss_near(P)
    tuft = np.sin(x * 41.0 + y * 13.0) * np.sin(y * 37.0 + z * 29.0) * np.sin(z * 43.0 - x * 11.0)
    head = kit.ss((z - 3.4) / 0.1) * kit.ss((y - 0.1) / 0.1)
    return (0.018 * slab + 0.007 * fine) * (1.0 - 0.8 * head) * (1.0 - moss) + 0.014 * tuft * moss
