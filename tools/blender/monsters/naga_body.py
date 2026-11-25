"""The naga's body: joints, clay forms, hard parts and surface.

Bestiary §2 (FINAL 2026-11-24): a hunched, heavy man, 1.95 m, with too-long
arms and a flat viper's wedge of a head on a long thick neck. No tail. Legs
are digitigrade. Scales of a starless night, a lighter leathery throat band
(the weak spot), polished black talons, amber eyes, one row of needle teeth.

Imported by naga.py. Everything is built in the rest pose: standing at full
height, arms held out and down, fingers spread, the mouth a little open so the
jaw is its own lobe.
"""

import math

import numpy as np

import kit

V = np.array


def _v(*a):
    return np.array(a, dtype=np.float64)


# ------------------------------------------------------------------ joints
# Right side (+x); the left is mirrored. Metres, y forward, z up.

J = {
    "pelvis": _v(0, -0.02, 1.04),
    "spine": _v(0, -0.035, 1.19),
    "chest": _v(0, -0.02, 1.36),
    "neck": _v(0, 0.02, 1.60),
    "neck2": _v(0, 0.10, 1.725),
    "head": _v(0, 0.165, 1.835),
    "head_end": _v(0, 0.47, 1.82),
    "jaw": _v(0, 0.15, 1.80),
    "jaw_end": _v(0, 0.445, 1.765),
    "clav": _v(0.05, 0.0, 1.55),
    "arm": _v(0.235, -0.03, 1.555),
    "forearm": _v(0.447, -0.045, 1.302),
    "hand": _v(0.652, 0.005, 1.047),
    "knuckle": _v(0.716, 0.02, 0.972),
    "upper": _v(0.125, -0.01, 1.01),
    "lower": _v(0.15, 0.135, 0.60),
    "foot": _v(0.14, -0.13, 0.275),
    "paw": _v(0.145, 0.07, 0.04),
    "paw_end": _v(0.15, 0.235, 0.02),
}

# Fingers: four per hand, two bones each, fanned from the knuckles. Finger 0
# is the inner (thumb side, toward +y), finger 3 the outer.
HAND_DIR = (J["knuckle"] - J["hand"]) / np.linalg.norm(J["knuckle"] - J["hand"])
FINGER_LEN = (0.052, 0.050)
TALON_LEN = 0.082


def fingers():
    """[(root, mid, tip, talon_tip)] for the right hand."""
    out = []
    fwd = _v(0, 1, 0)
    for i in range(4):
        spread = (1.5 - i) * 0.34          # radians of fan, inner fingers toward +y
        d = HAND_DIR * math.cos(spread) + fwd * math.sin(spread)
        d /= np.linalg.norm(d)
        root = J["knuckle"] + fwd * ((1.5 - i) * 0.021) - HAND_DIR * (abs(1.5 - i) * 0.006)
        mid = root + d * FINGER_LEN[0]
        curl = d + _v(0, 0, -0.25)
        curl /= np.linalg.norm(curl)
        tip = mid + curl * FINGER_LEN[1]
        hook = curl + _v(-0.25, 0, -0.55)
        hook /= np.linalg.norm(hook)
        out.append((root, mid, tip, tip + hook * TALON_LEN))
    return out


def toes():
    """[(root, tip, claw_tip)] for the right foot: three long toes."""
    out = []
    for i, (dx, ang) in enumerate(((-0.035, -0.32), (0.0, 0.0), (0.035, 0.32))):
        root = J["paw"] + _v(dx, 0.02, -0.005)
        d = _v(math.sin(ang), math.cos(ang), -0.06)
        d /= np.linalg.norm(d)
        tip = root + d * (0.135 if i == 1 else 0.115)
        out.append((root, tip, tip + (d + _v(0, 0, -0.35)) * 0.05))
    return out


def mx(p):
    return _v(-p[0], p[1], p[2])


# ------------------------------------------------------------------ clay

def mouth_z(y):
    """Height of the lip line at depth y: it rises toward the hinge (the smile)."""
    return 1.8125 + 0.016 * kit.ss((0.40 - y) / 0.22) ** 1.5


def skull_half_width(y):
    """Half width of the upper jaw's edge at depth y (widest behind the eyes)."""
    pts = ((0.12, 0.068), (0.19, 0.088), (0.27, 0.074), (0.36, 0.052), (0.43, 0.036), (0.462, 0.028))
    return float(np.interp(y, [p[0] for p in pts], [p[1] for p in pts]))


def forms():
    """Every lump of clay in the sculpt, biggest first (right side and midline;
    the caller mirrors the sided ones)."""
    mid, side = [], []
    t, e = kit.tube, kit.ellipsoid

    # torso: narrow hips, a long waist, a chest deeper than it is wide, the
    # upper back rounded into the hunch
    mid.append(t("torso", [(0, -0.02, 0.95), (0, -0.03, 1.05), (0, -0.045, 1.19), (0, -0.05, 1.32),
                           (0, -0.045, 1.44), (0, -0.03, 1.535), (0, 0.0, 1.61)],
                 [(0.116, 0.10), (0.128, 0.11), (0.12, 0.102), (0.142, 0.13), (0.158, 0.148),
                  (0.15, 0.135), (0.092, 0.10)], segs=28))
    mid.append(e("hump", (0, -0.11, 1.5), (0.09, 0.05, 0.12), rot=(-10, 0, 0), k=0.16))
    mid.append(e("gut", (0, 0.03, 1.15), (0.10, 0.07, 0.13), k=0.07))
    mid.append(e("sternum", (0, 0.11, 1.43), (0.04, 0.02, 0.11), rot=(-6, 0, 0), k=0.07))

    # neck: a long thick column carried forward, narrower than the head's back
    mid.append(t("neck", [(0, -0.01, 1.56), (0, 0.03, 1.64), (0, 0.09, 1.725), (0, 0.14, 1.80), (0, 0.17, 1.84)],
                 [(0.094, 0.10), (0.08, 0.086), (0.068, 0.072), (0.062, 0.062), (0.058, 0.048)], segs=24, k=0.07))
    mid.append(e("throat", (0, 0.125, 1.70), (0.046, 0.04, 0.085), rot=(-32, 0, 0), k=0.04))

    # head: a flat wedge, widest behind the eyes; the skull overhangs the jaw
    mid.append(t("skull", [(0, 0.12, 1.862), (0, 0.19, 1.872), (0, 0.27, 1.868), (0, 0.36, 1.852), (0, 0.43, 1.838),
                           (0, 0.462, 1.832)],
                 [(0.068, 0.036), (0.088, 0.04), (0.074, 0.037), (0.052, 0.03), (0.036, 0.022), (0.028, 0.017)],
                 segs=28, k=0.025, rings_per_m=120))
    mid.append(t("jaw", [(0, 0.13, 1.805), (0, 0.20, 1.799), (0, 0.28, 1.795), (0, 0.36, 1.793), (0, 0.42, 1.795),
                         (0, 0.447, 1.798)],
                 [(0.06, 0.026), (0.075, 0.025), (0.062, 0.021), (0.042, 0.017), (0.028, 0.013), (0.021, 0.011)],
                 segs=28, k=0.012, rings_per_m=120))
    mid.append(e("rostral", (0, 0.452, 1.838), (0.024, 0.02, 0.016), k=0.012))
    mid.append(e("chin", (0, 0.425, 1.79), (0.022, 0.03, 0.012), k=0.012))

    # the viper's brow: a hard ridge from behind the eye to the nostril
    side.append(t("brow", [(0.064, 0.225, 1.892), (0.06, 0.30, 1.8935), (0.042, 0.375, 1.876), (0.021, 0.44, 1.853)],
                  [0.012, 0.0135, 0.0105, 0.007], segs=10, k=0.012, rings_per_m=200))
    side.append(e("gland", (0.066, 0.185, 1.862), (0.03, 0.058, 0.03), k=0.03))
    side.append(e("jaw_muscle", (0.064, 0.165, 1.812), (0.022, 0.045, 0.024), k=0.025))
    side.append(e("cheek", (0.058, 0.30, 1.848), (0.014, 0.05, 0.012), rot=(0, 0, -12), k=0.012))

    # the cords of the neck, from behind the jaw down to the collar
    side.append(t("neck_cord", [(0.055, 0.12, 1.80), (0.06, 0.075, 1.70), (0.045, 0.085, 1.60), (0.03, 0.11, 1.56)],
                  [0.018, 0.021, 0.019, 0.016], segs=10, k=0.04))

    # shoulder girdle
    side.append(t("trapezius", [(0.03, -0.05, 1.67), (0.11, -0.055, 1.615), (0.21, -0.045, 1.575)],
                  [(0.045, 0.05), (0.05, 0.062), (0.045, 0.055)], segs=14, k=0.07))
    side.append(e("pec", (0.075, 0.09, 1.46), (0.07, 0.018, 0.055), rot=(0, -8, 0), k=0.12))
    side.append(e("scapula", (0.105, -0.14, 1.46), (0.055, 0.02, 0.075), rot=(8, 0, 14), k=0.1))
    side.append(t("collarbone", [(0.02, 0.098, 1.553), (0.11, 0.055, 1.572), (0.2, -0.005, 1.58)],
                  [0.012, 0.012, 0.012], segs=8, k=0.045))
    side.append(e("oblique", (0.118, 0.01, 1.12), (0.03, 0.075, 0.09), k=0.06))
    side.append(e("hip_crest", (0.115, 0.02, 1.045), (0.04, 0.07, 0.03), rot=(0, 0, -20), k=0.05))

    # arm: long, the forearm heavier than the upper arm
    a, f, h, kn = J["arm"], J["forearm"], J["hand"], J["knuckle"]
    ax = (f - a) / np.linalg.norm(f - a)
    fx = (h - f) / np.linalg.norm(h - f)
    side.append(t("upper_arm", [a - ax * 0.02, a + (f - a) * 0.45, f], [(0.062, 0.064), (0.054, 0.058), (0.044, 0.044)],
                  side=(0, 1, 0), segs=18, k=0.05))
    side.append(e("deltoid", a + _v(0.012, 0.0, 0.0), (0.072, 0.074, 0.088), rot=(0, -38, 0), k=0.05))
    side.append(e("biceps", a + (f - a) * 0.5 + _v(0.012, 0.036, 0.012), (0.036, 0.036, 0.10), rot=(0, -40, 0), k=0.04))
    side.append(e("triceps", a + (f - a) * 0.42 + _v(-0.012, -0.036, -0.012), (0.04, 0.038, 0.115), rot=(0, -40, 0), k=0.04))
    side.append(t("fore_arm", [f, f + (h - f) * 0.25, f + (h - f) * 0.65, h],
                  [(0.05, 0.047), (0.064, 0.056), (0.046, 0.038), (0.034, 0.025)], side=(0, 1, 0), segs=18, k=0.04))
    side.append(e("extensor", f + (h - f) * 0.28 + _v(0.02, -0.01, 0.02), (0.035, 0.035, 0.10), rot=(0, -38, 0), k=0.04))
    side.append(e("elbow", f + _v(-0.012, -0.036, 0.008), (0.022, 0.022, 0.026), k=0.02))
    side.append(e("wrist_bone", h + _v(0.006, -0.026, 0.006), (0.013, 0.013, 0.015), k=0.012))
    side.append(t("palm", [h - fx * 0.01, h + (kn - h) * 0.5, kn + fx * 0.012], [(0.036, 0.02), (0.047, 0.02), (0.05, 0.017)],
                  side=(0, 1, 0), segs=14, k=0.02))
    for i, (root, midp, tip, _) in enumerate(fingers()):
        side.append(t(f"finger{i}", [root - HAND_DIR * 0.025, root, midp, tip],
                      [0.0145, 0.014, 0.012, 0.0105], segs=10, rings_per_m=160, k=0.008))
        side.append(e(f"knuckle{i}", root + _v(0.004, 0, 0.006), 0.0155, k=0.008))
        side.append(e(f"joint{i}", midp + _v(0.002, 0, 0.003), 0.0135, k=0.006))

    # leg: digitigrade, the heel carried high
    u, l, ft, pw = J["upper"], J["lower"], J["foot"], J["paw"]
    side.append(e("glute", (0.092, -0.085, 1.0), (0.085, 0.08, 0.10), k=0.08))
    side.append(t("thigh", [u + _v(-0.01, 0, 0.04), u + (l - u) * 0.4, l],
                  [(0.092, 0.108), (0.086, 0.10), (0.056, 0.062)], segs=20, k=0.07))
    side.append(e("quad", u + (l - u) * 0.48 + _v(0.008, 0.052, 0.0), (0.056, 0.046, 0.16), rot=(19, 0, 0), k=0.05))
    side.append(e("hamstring", u + (l - u) * 0.45 + _v(-0.005, -0.06, 0.0), (0.05, 0.044, 0.15), rot=(19, 0, 0), k=0.05))
    side.append(e("kneecap", l + _v(0, 0.036, 0.004), (0.034, 0.026, 0.04), k=0.025))
    side.append(t("shin", [l, l + (ft - l) * 0.3, l + (ft - l) * 0.72, ft],
                  [(0.052, 0.058), (0.054, 0.066), (0.037, 0.043), (0.03, 0.036)], segs=18, k=0.04))
    side.append(e("calf", l + (ft - l) * 0.28 + _v(0, -0.036, -0.012), (0.044, 0.04, 0.10), rot=(-39, 0, 0), k=0.04))
    side.append(e("hock", ft + _v(0, -0.022, 0.004), (0.022, 0.026, 0.03), k=0.02))
    side.append(t("metatarsal", [ft, ft + (pw - ft) * 0.5, pw], [(0.027, 0.032), (0.027, 0.026), (0.04, 0.026)],
                  segs=14, k=0.025))
    side.append(e("pad", pw + _v(0, 0.012, -0.004), (0.05, 0.045, 0.03), k=0.02))
    for i, (root, tip, _) in enumerate(toes()):
        side.append(t(f"toe{i}", [root - _v(0, 0.03, 0), root + (tip - root) * 0.5 + _v(0, 0, 0.008), tip],
                      [(0.019, 0.018), (0.0165, 0.016), (0.0135, 0.012)], segs=10, rings_per_m=140, k=0.01))
    return mid, side


# ------------------------------------------------------------------ cutters

EYE = _v(0.0585, 0.305, 1.8685)
EYE_R = 0.0155
MOUTH_BACK = 0.205           # the corner of the mouth, well behind the eye


def cutters():
    """The mouth slot (running back past the eyes), a hollow behind the teeth,
    eye sockets, nostril slits and the earless pits."""
    out = []
    ys = (0.50, 0.42, 0.34, 0.27, MOUTH_BACK)
    out.append(kit.tube("mouth", [(0, y, mouth_z(y)) for y in ys],
                        [(0.07, 0.0035), (0.08, 0.004), (0.10, 0.0045), (0.12, 0.0045), (0.12, 0.003)], segs=16, cap=0.2))
    out.append(kit.tube("gullet", [(0, 0.405, mouth_z(0.405) - 0.001), (0, 0.32, mouth_z(0.32)), (0, 0.23, mouth_z(0.23))],
                        [(0.016, 0.009), (0.036, 0.014), (0.05, 0.014)], segs=14))
    for s in (1, -1):
        out.append(kit.ellipsoid(f"socket{s}", EYE * (s, 1, 1) + _v(-0.003 * s, 0, -0.001), (0.0185, 0.0235, 0.0145), rot=(0, 0, -12 * s)))
        out.append(kit.ellipsoid(f"nostril{s}", (0.0125 * s, 0.4585, 1.8455), (0.0035, 0.012, 0.005), rot=(0, 0, 30 * s)))
        out.append(kit.ellipsoid(f"earpit{s}", (0.087 * s, 0.165, 1.858), (0.007, 0.011, 0.008)))
    return out


SCAR_PATH = [(0.035, 0.255, 1.905), (0.062, 0.31, 1.888), (0.074, 0.345, 1.848)]   # across the right eye (the camp leader's)


# ------------------------------------------------------------------ zones

def zones(P, N):
    """Masks the surface material and the low mesh's detail weights read.
    Returns a dict of 0..1 arrays."""
    x, y, z = np.abs(P[:, 0]), P[:, 1], P[:, 2]
    z_ = {}
    front = kit.ss((N[:, 1] - 0.15) / 0.5)
    # belly plates: the front of the torso from the pelvis to the collar
    torso = kit.ss((z - 0.93) / 0.06) * kit.ss((1.56 - z) / 0.06) * kit.ss((0.12 - x) / 0.05)
    z_["belly"] = front * torso * kit.ss((y - 0.0) / 0.05)
    z_["scute"] = z_["belly"].copy()          # the broad transverse plates, torso only
    # the inside of the arms, a step lighter too
    arm_d, _ = kit.seg_dist(P, J["arm"], J["forearm"])
    fore_d, _ = kit.seg_dist(P, J["forearm"], J["hand"])
    arm = (np.minimum(arm_d, fore_d) < 0.085) & (x > 0.2)
    inner = kit.ss((-N[:, 0] * np.sign(P[:, 0]) * 0.8 - N[:, 2] * 0.4 - 0.25) / 0.4)
    z_["belly"] = np.maximum(z_["belly"], inner * arm * 0.85)
    # the leathery throat band: front of the neck under the jaw
    nd = kit.path_dist(P, [J["neck"] + _v(0, 0.06, 0.02), J["neck2"] + _v(0, 0.05, 0), J["head"] + _v(0, 0.03, -0.045)])
    z_["throat"] = kit.ss((0.085 - nd) / 0.03) * kit.ss((N[:, 1] + 0.1) / 0.5) * kit.ss((z - 1.585) / 0.04) * kit.ss((1.80 - z) / 0.03)
    # big plates: shoulders, forearms, the top of the head, the back
    head_top = kit.ss((z - 1.875) / 0.015) * kit.ss((y - 0.1) / 0.04)
    shoulders = kit.ss((0.13 - np.linalg.norm(P - J["arm"] * np.where(P[:, :1] < 0, (-1, 1, 1), (1, 1, 1)), axis=1)) / 0.05)
    back = kit.ss((-N[:, 1] - 0.2) / 0.4) * kit.ss((z - 1.15) / 0.1) * kit.ss((0.2 - x) / 0.05)
    z_["plates"] = np.clip(head_top + shoulders + (fore_d < 0.08) * (x > 0.3) * kit.ss((N[:, 2] + 0.2) / 0.5) + back * 0.8, 0, 1)
    # fine scales on the neck and face
    z_["fine"] = np.clip(kit.ss((0.11 - nd) / 0.03) + kit.ss((z - 1.76) / 0.03) * (1 - head_top), 0, 1) * (1 - z_["throat"])
    # the mouth's inside
    in_head = (y > 0.16) & (z > 1.74) & (x < 0.1)
    dz = z - (1.812 - 0.03 * (y - 0.3))
    slot = np.abs(dz) < 0.02
    # the palate faces down above the lip line, the floor faces up below it
    z_["mouth"] = (in_head & slot & (N[:, 2] * np.sign(dz) < -0.55)).astype(float)
    # where game triangles are worth more
    z_["keep"] = np.clip(kit.ss((z - 1.70) / 0.05) * kit.ss((y - 0.05) / 0.05) * 1.0
                         + kit.ss((x - 0.6) / 0.04) * 0.9 + kit.ss((0.12 - z) / 0.05) * 0.5, 0, 1)
    return z_


# ------------------------------------------------------------------ surface

def scale_field(P, N):
    """Sculpted relief the voxels can hold: the big plates' steps, the belly's
    transverse bars and the low ridge of larger scales down skull and spine."""
    z_ = zones(P, N)
    zc = P[:, 2]
    bars = (np.abs(((zc * 26.0) % 1.0) - 0.5) * 2.0) ** 3            # sharp grooves between belly plates
    d = -0.0022 * bars * z_["belly"] * (np.abs(P[:, 0]) < 0.2)
    ridge = kit.path_dist(P, [(0, -0.215, 1.52), (0, -0.14, 1.64), (0, -0.045, 1.775), (0, 0.06, 1.885), (0, 0.2, 1.925)])
    along = P[:, 1] * 22.0 + P[:, 2] * 22.0
    d += 0.004 * kit.ss((0.03 - ridge) / 0.02) * (0.5 + 0.5 * np.sin(along * 2 * np.pi)) * (P[:, 2] > 1.45)
    return d
