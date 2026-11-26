"""The gloamer's body: joints, clay forms, the knobbed spine and surface zones.

Bestiary §16 (DECIDED): a common pack scavenger about Feyre's height. Long
arms that reach past the knees, short bowed legs, a stooped back with a ridge
of knobbed vertebrae. It lopes on its knuckles and stands to strike. Skin
mottled like bark, lichen-green to bark-brown, moss in the creases, dun on the
belly; never grey. A short flat face, a wide lipless mouth of small uneven
teeth, small wet black eyes set close, nostril slits, small flat ears.

Imported by gloamer.py. Built in the rest pose: standing at its full 1.6 m,
arms held out and down, fingers spread, the mouth a little open.
"""

import math

import numpy as np

import kit
from hob_body import _onto


def _v(*a):
    return np.array(a, dtype=np.float64)


# ------------------------------------------------------------------ joints
# Right side (+x); the left is mirrored. Metres, y forward, z up.

J = {
    "pelvis": _v(0, -0.02, 0.74),
    "spine": _v(0, -0.05, 0.90),
    "spine2": _v(0, -0.085, 1.08),
    "chest_end": _v(0, -0.05, 1.34),
    "neck": _v(0, 0.0, 1.385),
    "head": _v(0, 0.07, 1.465),
    "head_end": _v(0, 0.26, 1.49),
    "jaw": _v(0, 0.1, 1.452),
    "jaw_end": _v(0, 0.265, 1.418),
    "clav": _v(0.06, -0.01, 1.35),
    "arm": _v(0.265, -0.03, 1.33),
    "forearm": _v(0.43, -0.05, 0.9),
    "hand": _v(0.585, 0.01, 0.47),
    "knuckle": _v(0.632, 0.03, 0.35),
    "upper": _v(0.125, -0.01, 0.72),
    "lower": _v(0.2, 0.1, 0.41),
    "foot": _v(0.17, -0.035, 0.115),
    "paw": _v(0.18, 0.085, 0.036),
    "paw_end": _v(0.19, 0.2, 0.026),
}

FWD = _v(0, 1, 0)
HAND_DIR = (J["knuckle"] - J["hand"]) / np.linalg.norm(J["knuckle"] - J["hand"])
PALM = _v(-0.93, 0.1, -0.34)                # the way the palm faces at rest (right hand)
PALM /= np.linalg.norm(PALM)
FINGER_LEN = (0.092, 0.07, 0.052)
FINGER_R = (0.019, 0.0175, 0.015, 0.0115)
THUMB_LEN = (0.055, 0.042, 0.032)


def fingers():
    """[(root, mid, mid2, tip)] for the right hand: three long fingers, the
    first on the thumb's side (+y)."""
    out = []
    for i in range(3):
        k = 1.0 - i
        spread = k * 0.24
        d = HAND_DIR * math.cos(spread) + FWD * math.sin(spread)
        d /= np.linalg.norm(d)
        pts = [J["knuckle"] + FWD * (k * 0.04) - HAND_DIR * (abs(k) * 0.008)]
        for n, L in enumerate(FINGER_LEN):
            dd = d + PALM * (0.14 * n)
            pts.append(pts[-1] + dd / np.linalg.norm(dd) * L * (0.9 if i != 1 else 1.0))
        out.append(tuple(pts))
    return out


def thumb():
    """(root, mid, mid2, tip) for the right thumb, off the front edge of the palm."""
    root = J["hand"] + (J["knuckle"] - J["hand"]) * 0.3 + FWD * 0.05 + PALM * 0.01
    d = FWD * 0.8 + HAND_DIR * 0.55 + PALM * 0.2
    pts = [root]
    for n, L in enumerate(THUMB_LEN):
        dd = d / np.linalg.norm(d) + PALM * (0.12 * n) + HAND_DIR * (0.15 * n)
        pts.append(pts[-1] + dd / np.linalg.norm(dd) * L)
    return tuple(pts)


def toes():
    """[(root, tip)] for the right foot: three long gripping toes."""
    out = []
    for dx, ang, L in ((-0.04, -0.22, 0.085), (0.0, 0.0, 0.1), (0.042, 0.24, 0.085)):
        root = J["paw"] + _v(dx, 0.025, -0.006)
        d = _v(math.sin(ang), math.cos(ang), -0.04)
        out.append((root, root + d / np.linalg.norm(d) * L))
    return out


# ------------------------------------------------------------------ the face

EYE = _v(0.035, 0.228, 1.513)
EYE_R = 0.0105
MOUTH_BACK = 0.135
THROAT = _v(0.0, 0.125, 1.375)              # the weak spot: a soft pale patch under the jaw


def mouth_z(y):
    """Height of the lip line at depth y: the corners pull back and up a little."""
    return 1.449 + 0.006 * kit.ss((0.2 - y) / 0.06)


def jaw_half_width(y):
    """Half width of the tooth row at depth y."""
    pts = ((0.14, 0.078), (0.18, 0.084), (0.215, 0.072), (0.24, 0.045), (0.252, 0.018))
    return float(np.interp(y, [p[0] for p in pts], [p[1] for p in pts]))


# ------------------------------------------------------------------ clay

def forms():
    """Every lump of clay in the body, biggest first (midline and right side;
    the caller mirrors the sided ones)."""
    mid, side = [], []
    t, e = kit.tube, kit.ellipsoid
    R = 60              # rings per metre for the limbs

    # torso: narrow hips, a deep ribcage, the back rounded over it
    mid.append(t("torso", [(0, 0.0, 0.655), (0, -0.01, 0.74), (0, -0.04, 0.9), (0, -0.08, 1.08), (0, -0.1, 1.22),
                           (0, -0.06, 1.34), (0, 0.0, 1.41)],
                 [(0.15, 0.115), (0.165, 0.125), (0.14, 0.115), (0.185, 0.15), (0.215, 0.165), (0.185, 0.135), (0.085, 0.08)],
                 segs=32, k=0.04, rings_per_m=R))
    mid.append(e("belly", (0, 0.045, 0.9), (0.11, 0.075, 0.11), rot=(8, 0, 0), k=0.07))
    mid.append(e("hump", (0, -0.2, 1.24), (0.165, 0.1, 0.17), rot=(-18, 0, 0), k=0.1))
    mid.append(e("low_back", (0, -0.13, 0.98), (0.1, 0.06, 0.14), rot=(8, 0, 0), k=0.08))
    mid.append(e("ribs", (0, 0.05, 1.16), (0.15, 0.08, 0.13), rot=(-8, 0, 0), k=0.06))
    # the neck: thin, carried forward out of the hump
    mid.append(t("neck", [(0, -0.05, 1.33), (0, 0.0, 1.39), (0, 0.06, 1.455), (0, 0.1, 1.49)],
                 [(0.075, 0.075), (0.062, 0.062), (0.058, 0.058), (0.06, 0.06)], segs=20, k=0.035, rings_per_m=R))

    # the head: a low wide skull, the face short and flat
    mid.append(e("skull", (0, 0.13, 1.518), (0.102, 0.118, 0.088), rot=(-6, 0, 0), k=0.02))
    mid.append(e("crown", (0, 0.085, 1.565), (0.075, 0.085, 0.045), k=0.03))
    mid.append(e("muzzle", (0, 0.2, 1.478), (0.092, 0.05, 0.03), k=0.012))
    mid.append(t("lower_jaw", [(0, 0.1, 1.43), (0, 0.165, 1.426), (0, 0.225, 1.43), (0, 0.256, 1.437)],
                 [(0.082, 0.027), (0.094, 0.029), (0.084, 0.026), (0.052, 0.02)], segs=20, k=0.012, rings_per_m=140))
    side.append(t("brow", [(0.0, 0.24, 1.537), (0.04, 0.243, 1.542), (0.08, 0.224, 1.538), (0.103, 0.178, 1.529)],
                  [0.01, 0.0135, 0.0135, 0.01], segs=10, k=0.012, rings_per_m=180))
    side.append(e("cheekbone", (0.086, 0.195, 1.492), (0.03, 0.04, 0.017), k=0.012))
    side.append(e("jaw_muscle", (0.092, 0.125, 1.468), (0.02, 0.036, 0.04), k=0.02))
    side.append(e("ear", (0.106, 0.095, 1.522), (0.008, 0.026, 0.032), rot=(0, 0, -18), k=0.01))

    # shoulders: high and narrow, hunched up beside the neck
    side.append(t("trapezius", [(0.04, -0.07, 1.4), (0.13, -0.075, 1.415), (0.21, -0.06, 1.39), (0.27, -0.04, 1.34)],
                  [(0.07, 0.075), (0.072, 0.08), (0.07, 0.075), (0.062, 0.066)], segs=16, k=0.06, rings_per_m=R))
    side.append(e("pec", (0.1, 0.07, 1.23), (0.09, 0.03, 0.06), rot=(0, -8, 0), k=0.06))
    side.append(e("scapula", (0.14, -0.2, 1.24), (0.08, 0.04, 0.115), rot=(8, 0, 14), k=0.05))
    side.append(e("hip", (0.13, -0.03, 0.73), (0.075, 0.09, 0.08), k=0.05))

    # arm: long, sinewy, the forearm the heavier half
    a, f, h, kn = J["arm"], J["forearm"], J["hand"], J["knuckle"]
    side.append(e("deltoid", a + _v(0.008, 0.0, -0.01), (0.078, 0.078, 0.095), rot=(0, -22, 0), k=0.04))
    side.append(t("upper_arm", [a, a + (f - a) * 0.45, f], [(0.058, 0.062), (0.05, 0.054), (0.043, 0.045)],
                  side=(0, 1, 0), segs=18, k=0.035, rings_per_m=R))
    side.append(e("biceps", a + (f - a) * 0.45 + _v(0.004, 0.03, 0.0), (0.034, 0.034, 0.1), rot=(0, -21, 0), k=0.03))
    side.append(t("fore_arm", [f, f + (h - f) * 0.22, f + (h - f) * 0.65, h],
                  [(0.046, 0.046), (0.06, 0.054), (0.046, 0.04), (0.036, 0.03)], side=(0, 1, 0), segs=18, k=0.03, rings_per_m=R))
    side.append(e("elbow", f + _v(-0.01, -0.038, 0.01), (0.027, 0.027, 0.032), k=0.02))
    side.append(e("wrist_bone", h + _v(0.008, -0.028, 0.008), (0.016, 0.016, 0.018), k=0.012))
    side.append(t("palm", [h - HAND_DIR * 0.01, h + (kn - h) * 0.5, kn + HAND_DIR * 0.012],
                  [(0.046, 0.024), (0.06, 0.026), (0.064, 0.022)], side=(0, 1, 0), segs=16, k=0.018, rings_per_m=100))
    for i, pts in enumerate(fingers()):
        side.append(t(f"finger{i}", [pts[0] - HAND_DIR * 0.03] + list(pts), [FINGER_R[0] * 1.02] + list(FINGER_R),
                      segs=10, rings_per_m=110, k=0.008))
        # the callus it walks on
        side.append(e(f"knuckle{i}", pts[0] - PALM * 0.008, 0.0245, k=0.01))
        side.append(e(f"joint{i}", pts[1] - PALM * 0.005, 0.0195, k=0.008))
        side.append(e(f"joint{i}b", pts[2] - PALM * 0.004, 0.0165, k=0.008))
    th = thumb()
    side.append(t("thumb", [th[0] - (th[1] - th[0]) * 0.6] + list(th), [0.024, 0.022, 0.02, 0.0175, 0.014],
                  segs=10, rings_per_m=110, k=0.01))

    # legs: short, bowed, the feet long and gripping
    u, l, ft = J["upper"], J["lower"], J["foot"]
    side.append(e("glute", (0.1, -0.1, 0.72), (0.09, 0.08, 0.095), k=0.05))
    side.append(t("thigh", [u + _v(-0.01, 0, 0.04), u + (l - u) * 0.45, l],
                  [(0.085, 0.092), (0.075, 0.08), (0.052, 0.056)], segs=20, k=0.05, rings_per_m=R))
    side.append(e("kneecap", l + _v(0.004, 0.045, 0.005), (0.034, 0.024, 0.04), k=0.02))
    side.append(t("shin", [l, l + (ft - l) * 0.3, l + (ft - l) * 0.72, ft],
                  [(0.05, 0.054), (0.052, 0.064), (0.038, 0.044), (0.033, 0.037)], segs=18, k=0.03, rings_per_m=R))
    side.append(e("heel", (0.17, -0.068, 0.04), (0.04, 0.042, 0.036), k=0.02))
    side.append(t("foot", [(0.17, -0.045, 0.05), (0.175, 0.03, 0.05), (0.181, 0.105, 0.034)],
                  [(0.04, 0.04), (0.05, 0.034), (0.062, 0.024)], segs=16, k=0.02, rings_per_m=100))
    for i, (root, tip) in enumerate(toes()):
        side.append(t(f"toe{i}", [root - _v(0, 0.04, 0), root + (tip - root) * 0.5 + _v(0, 0, 0.004), tip],
                      [(0.021, 0.018), (0.019, 0.016), (0.015, 0.012)], segs=8, rings_per_m=110, k=0.008))
    return mid, side


# ------------------------------------------------------------------ the knobbed spine

KNOBS = []          # [centre]: filled by ridge()


def ridge(f):
    """A row of knobbed vertebrae standing out of the back, from the tail bone
    to the nape (`f` is the body's distance field)."""
    zs = np.linspace(0.72, 1.4, 11)
    seeds = np.array([(0.0, -0.4, z) for z in zs])
    P, N = _onto(f, seeds)
    P[:, 0] = 0.0
    KNOBS.clear()
    out = []
    for i, (p, n) in enumerate(zip(P, N)):
        big = 0.6 + 0.4 * math.sin(math.pi * i / (len(P) - 1))            # largest over the hump
        r = 0.024 * big + 0.006
        c = p + n * r * 0.25
        out.append(kit.ellipsoid(f"knob{i}", tuple(c), (r * 0.75, r, r * 0.95), k=0.012, segs=12))
        KNOBS.append(c)
    return out


# ------------------------------------------------------------------ cutters

def cutters():
    """The mouth (a wide, lipless slot), a hollow behind the teeth, eye sockets,
    nostril slits and ear holes."""
    out = []
    ys = (0.3, 0.262, 0.22, 0.175, MOUTH_BACK)
    out.append(kit.tube("mouth", [(0, y, mouth_z(y)) for y in ys],
                        [(0.07, 0.005), (0.094, 0.0055), (0.106, 0.0055), (0.108, 0.005), (0.1, 0.003)], segs=16, cap=0.2))
    out.append(kit.tube("gullet", [(0, 0.215, mouth_z(0.215) - 0.002), (0, 0.185, mouth_z(0.185)), (0, 0.145, mouth_z(0.145))],
                        [(0.026, 0.009), (0.05, 0.014), (0.058, 0.013)], segs=14))
    for s in (1, -1):
        out.append(kit.ellipsoid(f"socket{s}", EYE * (s, 1, 1) + _v(0, 0.004, -0.001), (0.0135, 0.016, 0.0095)))
        out.append(kit.ellipsoid(f"nostril{s}", (0.011 * s, 0.252, 1.488), (0.004, 0.012, 0.009), rot=(10, 0, 22 * s)))
        out.append(kit.ellipsoid(f"earhole{s}", (0.11 * s, 0.1, 1.518), (0.008, 0.009, 0.013)))
    return out


# ------------------------------------------------------------------ zones

def nail_points():
    """[(tip, outward direction, radius)] for every finger, thumb and toe nail (both sides)."""
    out = []
    for s in (1, -1):
        flip = _v(s, 1, 1)
        for pts in fingers() + [thumb()]:
            out.append((pts[3] * flip, -PALM * flip, 0.02))
        for root, tip in toes():
            out.append((tip * flip, _v(0, 0.3, 1.0), 0.022))
    return out


def _mirror(P):
    return P * np.where(P[:, :1] < 0, (-1, 1, 1), (1, 1, 1))


def zones(P, N):
    """Masks the surface material and the game mesh's detail weights read."""
    x, y, z = np.abs(P[:, 0]), P[:, 1], P[:, 2]
    z_ = {}
    up = kit.ss((N[:, 2] - 0.15) / 0.5)
    z_["up"] = up
    # moss: on what faces the sky along the back and shoulders (the shader adds the creases)
    z_["moss"] = np.clip(up * kit.ss((z - 0.95) / 0.2) * kit.ss((0.05 - y) / 0.12) * 0.8, 0, 1)
    in_head = (y > 0.13) & (z > 1.41) & (z < 1.49) & (x < 0.12)
    dz = z - np.array([mouth_z(v) for v in y])
    inside = (y < 0.246) & (x < np.interp(y, (0.14, 0.18, 0.215, 0.24, 0.252), (0.078, 0.084, 0.072, 0.045, 0.018)) - 0.003)
    z_["mouth"] = (in_head & inside & (np.abs(dz) < 0.026) & (N[:, 2] * np.sign(dz) < -0.5)).astype(float)
    nail = np.zeros(len(P))
    for tip, out_dir, r in nail_points():
        d = np.linalg.norm(P - tip, axis=1)
        nail = np.maximum(nail, kit.ss((r - d) / 0.005) * kit.ss((N @ (out_dir / np.linalg.norm(out_dir)) - 0.35) / 0.3))
    z_["nail"] = nail
    # dun: the belly, the chest, the insides of the limbs
    z_["soft"] = np.clip(kit.ss((N[:, 1] - 0.15) / 0.5) * kit.ss((z - 0.66) / 0.08) * kit.ss((1.3 - z) / 0.1) * kit.ss((0.15 - x) / 0.07), 0, 1)
    # the weak spot: a soft pale patch under the jaw
    td = np.linalg.norm((P - THROAT) / np.array((0.07, 0.06, 0.07)), axis=1)
    z_["throat"] = kit.ss((1.0 - td) / 0.35) * kit.ss((N[:, 1] + 0.1) / 0.4)
    # sheen: the face and the knuckles, so it reads at dusk
    Pm = _mirror(P)
    kd, _ = kit.seg_dist(Pm, J["knuckle"] + FWD * 0.05, J["knuckle"] - FWD * 0.05)
    face = kit.ss((y - 0.17) / 0.05) * kit.ss((z - 1.4) / 0.03)
    z_["sheen"] = np.clip(np.maximum(face, kit.ss((0.045 - kd) / 0.02)), 0, 1)
    hand_d, _ = kit.seg_dist(Pm, J["hand"], J["knuckle"] + HAND_DIR * 0.2)
    z_["keep"] = np.clip(kit.ss((z - 1.4) / 0.03) * kit.ss((y - 0.05) / 0.05) * 1.0 + kit.ss((0.2 - hand_d) / 0.05) * 0.7
                         + kit.ss((0.1 - z) / 0.04) * 0.35, 0, 1)
    return z_


# ------------------------------------------------------------------ surface

def bark_field(P, N):
    """Relief the voxels can hold: ropes of sinew and bark plates along the limbs."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    plate = np.sin(x * 21.0 + z * 9.0 + 1.0) * np.sin(y * 19.0 - z * 15.0 + 0.4) * np.sin(z * 25.0 + x * 7.0)
    fine = np.sin(x * 63.0 + y * 31.0) * np.sin(y * 57.0 - z * 47.0) * np.sin(z * 71.0 + x * 23.0)
    head = kit.ss((z - 1.4) / 0.04) * kit.ss((y - 0.03) / 0.05)
    return (0.004 * plate + 0.0016 * fine) * (1.0 - 0.75 * head)
