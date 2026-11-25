"""The Suriel's body: joints, clay forms, hard parts and surface zones.

Bestiary §3 (FINAL 2026-11-24): "the tall, thin veiled figure in dark tattered
robes", hunched, the knobs of its spine through the thin cloth. A face of
dried, weatherworn bone, a lipless mouth, grey teeth too long for it held by
blackened gums, slits for nostrils, eyes that are pits of milky white. Spindly
scabby grey arms, too-long fingers with yellowed nails, bare gnarled feet.

Imported by suriel.py. Built in the rest pose: standing at its full 2.2 m,
arms held out and down, fingers spread, the jaw a little open. The clips fold
it down into the hunch.

The clay is in three kinds (cloth, bone, skin), so the surface knows which
it is by asking which kind of clay is nearest.
"""

import math

import numpy as np

import kit


def _v(*a):
    return np.array(a, dtype=np.float64)


def _n(v):
    v = np.asarray(v, dtype=np.float64)
    return v / np.linalg.norm(v)


# ------------------------------------------------------------------ joints
# Right side (+x); the left is mirrored. Metres, y forward, z up.

_ARM = _v(0.185, -0.075, 1.82)
_FORE = _ARM + 0.40 * _n((0.62, 0.02, -0.784))
_HAND = _FORE + 0.44 * _n((0.58, 0.12, -0.806))
HAND_DIR = _n((0.58, 0.12, -0.806))
_KNUCKLE = _HAND + 0.105 * HAND_DIR

J = {
    "pelvis": _v(0, -0.02, 1.20),
    "spine": _v(0, -0.05, 1.36),
    "spine2": _v(0, -0.08, 1.52),
    "chest": _v(0, -0.095, 1.67),
    "neck": _v(0, -0.055, 1.87),
    "neck2": _v(0, 0.02, 1.945),
    "head": _v(0, 0.085, 2.00),
    "head_end": _v(0, 0.11, 2.20),
    "jaw": _v(0, 0.115, 2.03),
    "jaw_end": _v(0, 0.232, 1.975),
    "clav": _v(0.04, -0.05, 1.81),
    "arm": _ARM,
    "forearm": _FORE,
    "hand": _HAND,
    "knuckle": _KNUCKLE,
    "upper": _v(0.085, -0.02, 1.18),
    "lower": _v(0.09, 0.0, 0.62),
    "foot": _v(0.09, -0.04, 0.085),
    "paw": _v(0.095, 0.115, 0.022),
    "paw_end": _v(0.10, 0.20, 0.016),
}

LIP_Z = 2.004                 # the gap between the jaws
EYE = _v(0.035, 0.192, 2.086)
EYE_R = 0.0115
HEM_Z = 0.36                  # where the robe's body ends and its rags begin

# Fingers: a thumb and four fingers, two bones each, a third longer than a
# man's. Chain 0 is the thumb (toward +y, the inner side of the hanging hand).
FINGER_LEN = ((0.05, 0.045), (0.072, 0.062), (0.08, 0.068), (0.074, 0.064), (0.058, 0.05))


def fingers():
    """[(root, mid, tip)] for the right hand."""
    out = []
    fwd = _v(0, 1, 0)
    # the thumb leaves the side of the palm
    root = J["hand"] + HAND_DIR * 0.035 + fwd * 0.03
    d = _n(HAND_DIR * 0.55 + fwd * 0.8)
    mid = root + d * FINGER_LEN[0][0]
    out.append((root, mid, mid + _n(d + _v(0, 0, -0.2)) * FINGER_LEN[0][1]))
    for i in range(4):
        spread = (1.5 - i) * 0.2
        d = _n(HAND_DIR * math.cos(spread) + fwd * math.sin(spread))
        root = J["knuckle"] + fwd * ((1.5 - i) * 0.019) - HAND_DIR * (abs(1.5 - i) * 0.005)
        mid = root + d * FINGER_LEN[i + 1][0]
        out.append((root, mid, mid + _n(d + _v(0, 0, -0.15)) * FINGER_LEN[i + 1][1]))
    return out


def toes():
    """[(root, tip, radius)] for the right foot; toe 0 is the big toe (inner)."""
    out = []
    for i, (dx, length, r) in enumerate(((-0.031, 0.062, 0.0125), (-0.013, 0.058, 0.009), (0.003, 0.052, 0.0085),
                                         (0.018, 0.045, 0.008), (0.031, 0.036, 0.0075))):
        root = J["paw"] + _v(dx, 0.012 - abs(i - 1) * 0.006, 0.0)
        d = _n((dx * 2.2, 1.0, 0.0))
        out.append((root, root + d * length, r))
    return out


def mx(p):
    return _v(-p[0], p[1], p[2])


def back_y(z):
    """Where the robe's back is at height z (the line the vertebrae follow)."""
    pts = ((1.24, -0.108), (1.36, -0.12), (1.52, -0.152), (1.68, -0.178), (1.80, -0.198), (1.88, -0.172), (1.95, -0.118))
    return float(np.interp(z, [p[0] for p in pts], [p[1] for p in pts]))


def upper_arc(x):
    """Depth of the upper jaw's tooth line at x."""
    return 0.246 - 26.0 * x * x


def lower_arc(x):
    """Depth of the lower jaw's tooth line at x: behind the upper, so the long
    upper teeth close in front of it."""
    return 0.222 - 21.5 * x * x


# ------------------------------------------------------------------ clay

def forms():
    """{kind: (midline forms, right-side forms)}; the caller mirrors the sided ones."""
    t, e = kit.tube, kit.ellipsoid
    cloth_m, cloth_s, bone_m, bone_s, skin_m, skin_s = [], [], [], [], [], []

    # ---- the robe: a thin bell from the shoulders to the shins
    cloth_m.append(t("robe", [(0, -0.045, 1.84), (0, -0.07, 1.68), (0, -0.06, 1.52), (0, -0.035, 1.36), (0, -0.015, 1.20),
                              (0, 0.0, 0.95), (0, 0.0, 0.65), (0, 0.0, HEM_Z)],
                     [(0.15, 0.085), (0.142, 0.10), (0.122, 0.09), (0.112, 0.082), (0.126, 0.092), (0.165, 0.118),
                      (0.215, 0.155), (0.255, 0.19)], segs=32, k=0.05, cap=0.2))
    cloth_m.append(e("hump", (0, -0.12, 1.80), (0.115, 0.075, 0.11), rot=(-12, 0, 0), k=0.1))
    for i in range(10):
        z = 1.27 + 0.073 * i
        cloth_m.append(e(f"vertebra{i}", (0, back_y(z) - 0.008, z), (0.015, 0.019, 0.021), k=0.012))
    cloth_s.append(e("shoulder", J["arm"] + _v(0.0, 0.0, 0.005), (0.064, 0.06, 0.058), k=0.05))
    cloth_s.append(t("yoke", [(0.03, -0.06, 1.895), (0.10, -0.07, 1.875), (0.17, -0.075, 1.855)], [0.04, 0.04, 0.038], segs=12, k=0.05))
    cloth_s.append(e("blade", (0.085, -0.155, 1.70), (0.05, 0.016, 0.085), rot=(6, 0, 12), k=0.05))
    a, f, h, kn = J["arm"], J["forearm"], J["hand"], J["knuckle"]
    ax, fx = _n(f - a), _n(h - f)
    cloth_s.append(t("sleeve", [a, a + (f - a) * 0.5, f, f + fx * 0.07], [(0.05, 0.048), (0.045, 0.043), (0.049, 0.046), (0.056, 0.052)],
                     side=(0, 1, 0), segs=18, k=0.03, cap=0.25))

    # ---- the veil: a cap over the skull, falling down the sides and the back
    cloth_m.append(e("veil_cap", (0, 0.075, 2.106), (0.099, 0.12, 0.109), k=0.02))
    cloth_m.append(t("veil_back", [(0, -0.02, 2.14), (0, -0.07, 2.04), (0, -0.135, 1.93), (0, -0.2, 1.835)],
                     [(0.08, 0.02), (0.098, 0.02), (0.115, 0.022), (0.12, 0.018)], segs=16, k=0.035))
    cloth_s.append(t("veil_side", [(0.08, 0.10, 2.125), (0.102, 0.09, 2.02), (0.126, 0.035, 1.93), (0.15, -0.03, 1.868)],
                     [(0.058, 0.017), (0.064, 0.016), (0.07, 0.018), (0.06, 0.02)], side=(0, 1, 0), segs=14, k=0.03))

    # ---- the skull: bone, no skin on it
    bone_m.append(e("cranium", (0, 0.11, 2.104), (0.08, 0.105, 0.095), k=0.02))
    bone_m.append(e("maxilla", (0, 0.19, 2.046), (0.04, 0.046, 0.044), k=0.015))
    bone_s.append(e("brow", (0.034, 0.212, 2.115), (0.03, 0.014, 0.011), rot=(0, 8, -14), k=0.028))
    xs = (-0.042, -0.026, 0.0, 0.026, 0.042)
    bone_m.append(t("gum_upper", [(x, upper_arc(x) - 0.005, 2.02) for x in xs], [0.0065] * 5, segs=10, k=0.01, rings_per_m=240))
    bone_s.append(e("cheekbone", (0.046, 0.196, 2.057), (0.0115, 0.022, 0.0135), k=0.024))
    # the lower jaw, its own lobe
    bone_m.append(t("mandible", [(-0.052, 0.128, 2.0), (-0.044, 0.182, 1.987), (-0.024, 0.214, 1.983), (0, 0.222, 1.982),
                                 (0.024, 0.214, 1.983), (0.044, 0.182, 1.987), (0.052, 0.128, 2.0)],
                    [(0.012, 0.0065)] * 7, side=(0, 0, 1), segs=10, k=0.012, rings_per_m=200))
    bone_m.append(e("chin", (0, 0.219, 1.974), (0.016, 0.011, 0.011), k=0.01))
    bone_m.append(e("mouth_floor", (0, 0.17, 1.984), (0.042, 0.058, 0.007), k=0.008))
    bone_s.append(t("ramus", [(0.052, 0.13, 1.998), (0.058, 0.112, 2.04)], [0.011, 0.011], segs=8, k=0.012))

    # ---- skin: what the robe leaves bare
    skin_m.append(t("neck", [(0, -0.05, 1.86), (0, 0.0, 1.93), (0, 0.06, 1.985), (0, 0.09, 2.035)],
                    [(0.03, 0.032), (0.026, 0.027), (0.024, 0.025), (0.026, 0.026)], segs=16, k=0.03))
    skin_m.append(e("larynx", (0, 0.062, 1.94), (0.011, 0.012, 0.016), k=0.012))
    skin_s.append(t("neck_cord", [(0.03, 0.075, 2.02), (0.026, 0.03, 1.93), (0.022, 0.0, 1.87)], [0.007, 0.0075, 0.007], segs=8, k=0.012))
    out_n = _n((0.75, -0.2, 0.62))            # the back of the forearm and hand
    skin_s.append(t("fore_arm", [f - fx * 0.03, f + (h - f) * 0.3, f + (h - f) * 0.7, h],
                    [(0.027, 0.024), (0.024, 0.02), (0.019, 0.015), (0.0175, 0.012)], side=(0, 1, 0), segs=14, k=0.02))
    for j, off in enumerate((0.009, -0.008)):
        o = out_n * 0.0125 + _v(0, off, 0)
        skin_s.append(t(f"tendon{j}", [f + (h - f) * 0.12 + o * 1.3, f + (h - f) * 0.55 + o, h + o * 0.75], [0.0055, 0.005, 0.0045],
                        segs=6, k=0.007, rings_per_m=120))
    skin_s.append(e("wrist_knob", h + _v(0.004, -0.017, 0.006), 0.0115, k=0.01))
    skin_s.append(t("palm", [h - fx * 0.01, h + (kn - h) * 0.5, kn + fx * 0.012], [(0.027, 0.0125), (0.037, 0.0115), (0.041, 0.0105)],
                    side=(0, 1, 0), segs=14, k=0.012))
    for i, (root, midp, tip) in enumerate(fingers()):
        r0 = 0.0105 if i == 0 else 0.0092
        skin_s.append(t(f"finger{i}", [root - _n(midp - root) * 0.02, root, midp, tip], [r0, r0 * 0.95, r0 * 0.84, r0 * 0.7],
                        segs=8, rings_per_m=200, k=0.006))
        skin_s.append(e(f"knuckle{i}", root + out_n * 0.003, r0 * 1.28, k=0.006))
        skin_s.append(e(f"joint{i}", midp + out_n * 0.002, r0 * 1.14, k=0.005))
        if i > 0:
            skin_s.append(t(f"hand_tendon{i}", [h + out_n * 0.009, root + out_n * 0.008], [0.0042, 0.0042], segs=6, k=0.006, rings_per_m=120))

    lo, ft, pw = J["lower"], J["foot"], J["paw"]
    skin_s.append(t("shin", [lo, lo + (ft - lo) * 0.45, lo + (ft - lo) * 0.8, ft],
                    [(0.036, 0.04), (0.029, 0.033), (0.022, 0.026), (0.021, 0.025)], segs=14, k=0.03))
    skin_s.append(e("shin_edge", lo + (ft - lo) * 0.6 + _v(0, 0.022, 0), (0.008, 0.008, 0.12), rot=(4, 0, 0), k=0.012))
    skin_s.append(t("achilles", [lo + (ft - lo) * 0.55 + _v(0, -0.02, 0), ft + _v(0, -0.03, 0.02), (0.09, -0.085, 0.045)],
                    [0.01, 0.008, 0.01], segs=8, k=0.012))
    for s_ in (1, -1):
        skin_s.append(e(f"ankle{s_}", ft + _v(0.022 * s_, -0.004, 0.004), (0.013, 0.015, 0.016), k=0.012))
    skin_s.append(e("heel", (0.09, -0.078, 0.036), (0.026, 0.034, 0.034), k=0.02))
    skin_s.append(t("instep", [ft + _v(0, 0.0, -0.015), (0.092, 0.04, 0.047), pw + _v(0, -0.005, 0.012)],
                    [(0.025, 0.03), (0.03, 0.021), (0.043, 0.016)], segs=14, k=0.02))
    skin_s.append(e("ball", pw + _v(0, -0.005, 0.0), (0.043, 0.03, 0.02), k=0.015))
    for i, (root, tip, r) in enumerate(toes()):
        midp = (root + tip) / 2 + _v(0, 0, 0.011)
        skin_s.append(t(f"toe{i}", [root - _v(0, 0.022, -0.004), midp, tip + _v(0, 0, -0.006)], [r * 1.05, r, r * 0.85],
                        segs=8, rings_per_m=200, k=0.008))
        skin_s.append(e(f"toe_knuckle{i}", midp + _v(0, -0.004, 0.002), r * 1.25, k=0.006))
        skin_s.append(t(f"foot_tendon{i}", [ft + _v(0, 0.02, 0.012), root + _v(0, -0.015, 0.016)], [0.004, 0.004], segs=6, k=0.007, rings_per_m=120))
    return dict(cloth=(cloth_m, cloth_s), bone=(bone_m, bone_s), skin=(skin_m, skin_s))


# ------------------------------------------------------------------ cutters

def cutters():
    """The eye pits and the nostril slits, pressed into the skull (kit.union's
    `cut`). The jaws are two lobes of clay already and need no cut."""
    out = []
    for s in (1, -1):
        out.append(kit.ellipsoid(f"socket{s}", EYE * (s, 1, 1) + _v(0.001 * s, 0.014, 0.0), (0.026, 0.042, 0.0235), rot=(0, 0, -8 * s), k=0.004))
        out.append(kit.ellipsoid(f"nostril{s}", (0.0085 * s, 0.24, 2.05), (0.0042, 0.016, 0.0145), rot=(0, 14 * s, 0), k=0.002))
        out.append(kit.ellipsoid(f"hollow{s}", (0.052 * s, 0.212, 2.034), (0.011, 0.02, 0.012), k=0.004))
    return out


# ------------------------------------------------------------------ zones

def zones(P, N, kinds):
    """Masks the materials and the game mesh's detail weights read. `kinds`
    is {kind: distance field} for the three kinds of clay. 0..1 arrays."""
    x, y, z = np.abs(P[:, 0]), P[:, 1], P[:, 2]
    d = {k: f(P) for k, f in kinds.items()}
    z_ = {}
    z_["bone"] = kit.ss((np.minimum(d["cloth"], d["skin"]) - d["bone"]) / 0.004 + 0.5)
    z_["skin"] = kit.ss((np.minimum(d["cloth"], d["bone"]) - d["skin"]) / 0.004 + 0.5)
    z_["cloth"] = np.clip(1.0 - z_["bone"] - z_["skin"], 0.0, 1.0)
    # blackened gums: the ridges the teeth stand in
    in_mouth = (y > 0.13) & (x < 0.06)
    upper = kit.ss((0.0065 - np.abs(z - 2.016)) / 0.003) * kit.ss((y - (0.246 - 26.0 * x * x) + 0.03) / 0.012)
    lower = kit.ss((0.006 - np.abs(z - 1.994)) / 0.003) * kit.ss((y - 0.14) / 0.02)
    z_["gum"] = np.clip(upper + lower, 0, 1) * in_mouth * z_["bone"]
    # the inside of the mouth and of the pits: black
    slot = (np.abs(z - LIP_Z) < 0.007) & in_mouth & (np.abs(N[:, 2]) > 0.5)
    pit = np.zeros(len(P))
    for s in (1, -1):
        c = EYE * (s, 1, 1)
        q = np.linalg.norm((P - c - (0.001 * s, 0.014, 0.0)) / (0.026, 0.042, 0.0235), axis=1)     # inside the socket's cut
        pit = np.maximum(pit, kit.ss((1.12 - q) / 0.14) * (P[:, 1] < c[1] + 0.05))
        pit = np.maximum(pit, kit.ss((0.007 - np.linalg.norm((P - (0.0085 * s, 0.234, 2.05)) * (1.3, 0.5, 0.55), axis=1)) / 0.003))
    z_["dark"] = np.clip(slot.astype(float) + pit, 0, 1) * z_["bone"]
    # yellowed nails on the toes (the fingernails are hard parts)
    nail = np.zeros(len(P))
    for s in (1, -1):
        for root, tip, r in toes():
            c = (tip + (tip - root) * -0.12 + (0, 0, r * 0.45)) * (s, 1, 1)
            nail = np.maximum(nail, kit.ss((r * 1.15 - np.linalg.norm(P - c, axis=1)) / 0.003) * kit.ss((N[:, 2] - 0.2) / 0.4))
    z_["nail"] = nail * z_["skin"]
    # where game triangles are worth more: the face, the hands, the feet
    z_["keep"] = np.clip(kit.ss((z - 1.95) / 0.04) * kit.ss((y - 0.12) / 0.05) + kit.ss((x - 0.66) / 0.03) * 0.9
                         + kit.ss((0.11 - z) / 0.04) * 0.6, 0, 1)
    return z_


# ------------------------------------------------------------------ surface

def cloth_field(P, N):
    """Relief the voxels can hold: the ribs showing through the thin robe on
    its back, and the long folds the cloth hangs in below the hips."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x)
    d = np.zeros(len(P))
    # ribs: six bars a side, sloping down away from the spine
    on_back = kit.ss((-N[:, 1] + 0.15) / 0.5) * kit.ss((ax - 0.03) / 0.03) * kit.ss((0.17 - ax) / 0.03)
    rib_z = z + 0.35 * ax
    bars = np.cos(rib_z * 2 * np.pi / 0.062) * 0.5 + 0.5
    d += 0.0042 * (bars ** 2 - 0.4) * on_back * kit.ss((z - 1.40) / 0.05) * kit.ss((1.72 - rib_z) / 0.05) * (y < -0.03)
    # folds: deepening toward the hem
    ang = np.arctan2(x, y + 0.0)
    wob = np.sin(z * 9.0 + ang * 2.0) * 0.5
    fold = np.sin(ang * 11.0 + wob) * 0.6 + np.sin(ang * 5.0 + 1.3 - wob) * 0.4
    hang = kit.ss((1.12 - z) / 0.5) * kit.ss((z - HEM_Z + 0.06) / 0.05)
    torso = np.sqrt(x * x + y * y) > 0.085
    d += 0.02 * fold * hang * torso * (z > HEM_Z - 0.06) * (ax < 0.3)
    return d
