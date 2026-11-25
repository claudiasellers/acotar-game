"""The brackenhound's body: joints, clay forms and surface zones.

Bestiary §17 (DECIDED): a fae hound grown of moss, bark and bone, like
something the woods built badly. About 1 m at the shoulder, long-bodied and
low, with a long neck and a narrow, eyeless-looking skull-snout whose jaw is
too long. A frame of pale bone shows through bark and moss; its legs are long
and knotted like roots, with splayed root-claws. Not a wolf: no pricked ears
(fern fronds grow there instead), no ruff, no golden eyes.

Imported by brackenhound.py. Built in the rest pose: standing square, head
carried forward, the jaw a little open.
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
    "hips": _v(0, -0.62, 0.9),
    "spine": _v(0, -0.36, 0.91),
    "ribs": _v(0, -0.08, 0.9),
    "chest": _v(0, 0.2, 0.89),
    "chest_end": _v(0, 0.44, 0.9),
    "neck2": _v(0, 0.6, 1.05),
    "neck3": _v(0, 0.76, 1.19),
    "head": _v(0, 0.9, 1.31),
    "head_end": _v(0, 1.33, 1.25),
    "jaw": _v(0, 0.98, 1.283),
    "jaw_end": _v(0, 1.31, 1.215),
    "tail": [_v(0, -0.72, 0.88), _v(0, -0.87, 0.82), _v(0, -1.01, 0.73), _v(0, -1.13, 0.62), _v(0, -1.23, 0.5)],
    # front leg: shoulder, elbow, wrist, ball, toe end
    "f_upper": _v(0.17, 0.4, 0.8), "f_lower": _v(0.185, 0.29, 0.52), "f_foot": _v(0.185, 0.35, 0.235),
    "f_paw": _v(0.185, 0.395, 0.04), "f_paw_end": _v(0.19, 0.5, 0.025),
    # hind leg: hip, stifle, hock, ball, toe end
    "h_upper": _v(0.15, -0.6, 0.82), "h_lower": _v(0.175, -0.45, 0.52), "h_foot": _v(0.175, -0.72, 0.3),
    "h_paw": _v(0.175, -0.62, 0.04), "h_paw_end": _v(0.18, -0.515, 0.025),
}

# the torso's section along its length: (y, half width, centre z, half height)
TORSO = ((-0.76, 0.08, 0.87, 0.08), (-0.62, 0.15, 0.85, 0.14), (-0.36, 0.105, 0.885, 0.1), (-0.08, 0.15, 0.84, 0.155),
         (0.2, 0.185, 0.77, 0.235), (0.4, 0.165, 0.81, 0.21), (0.54, 0.11, 0.93, 0.13))
RIB_Y = (0.36, 0.25, 0.14, 0.03, -0.08, -0.18)

EYE = _v(0.038, 1.012, 1.343)
EYE_R = 0.0085
KNOT = _v(0.0, 1.085, 1.342)                 # the weak spot: a pale burl of bone between its eyes


def _section(y):
    ys = [s[0] for s in TORSO]
    return tuple(float(np.interp(y, ys, [s[i] for s in TORSO])) for i in (1, 2, 3))


def rib_path(y, s=1):
    """A rib standing out of the flank at depth y, from the spine round to the breastbone."""
    a, zc, b = _section(y)
    pts = [(0.05, y, zc + b * 0.98), (a * 0.78, y - 0.02, zc + b * 0.6), (a * 1.03, y - 0.05, zc + b * 0.05),
           (a * 0.86, y - 0.085, zc - b * 0.55), (a * 0.4, y - 0.11, zc - b * 0.93)]
    return [(p[0] * s, p[1], p[2]) for p in pts]


def mouth_z(y):
    """Height of the lip line at depth y."""
    return float(np.interp(y, (1.0, 1.14, 1.27, 1.34), (1.283, 1.2515, 1.229, 1.226)))


def jaw_half_width(y):
    return float(np.interp(y, (1.0, 1.14, 1.27, 1.325), (0.042, 0.033, 0.024, 0.011)))


def claws(leg):
    """[(root, tip)]: four short splayed root-claws, a paw more than a talon (right side)."""
    ball = J[f"{leg}_paw"]
    out = []
    for ang, L in ((-0.75, 0.085), (-0.25, 0.11), (0.25, 0.11), (0.75, 0.085)):
        d = _v(math.sin(ang), math.cos(ang), 0.0)
        root = ball + d * 0.015 + _v(0, 0, 0.0)
        out.append((root, _v(*(root + d * L)[:2], 0.012)))
    return out


def knots():
    """[(centre, radius)]: the burls at every joint of the legs (right side)."""
    return [(J["f_lower"] + _v(0, -0.02, 0), 0.062), (J["f_foot"], 0.048), (J["h_lower"] + _v(0, 0.02, 0), 0.066),
            (J["h_foot"] + _v(0, -0.015, 0), 0.05), (J["f_upper"] + _v(0.02, 0, 0.02), 0.085)]


# ------------------------------------------------------------------ clay

def forms():
    """Every lump of clay in the body, biggest first (midline and right side;
    the caller mirrors the sided ones)."""
    mid, side = [], []
    t, e = kit.tube, kit.ellipsoid
    R = 50

    mid.append(t("torso", [(0, s[0], s[2]) for s in TORSO], [(s[1], s[3]) for s in TORSO], segs=30, k=0.05, rings_per_m=R))
    mid.append(e("keel", (0, 0.3, 0.6), (0.08, 0.17, 0.08), k=0.06))                      # the breastbone
    mid.append(e("withers", (0, 0.36, 0.99), (0.08, 0.13, 0.06), k=0.06))
    # the neck: long, thin, carried forward and up
    mid.append(t("neck", [(0, 0.42, 0.9), (0, 0.6, 1.05), (0, 0.76, 1.19), (0, 0.9, 1.3), (0, 0.97, 1.33)],
                 [(0.12, 0.15), (0.085, 0.105), (0.068, 0.082), (0.06, 0.07), (0.058, 0.06)], segs=20, k=0.04, rings_per_m=R))
    # the skull: a long narrow snout of bare bone, the jaw too long under it
    mid.append(e("cranium", (0, 0.985, 1.33), (0.068, 0.095, 0.062), k=0.02))
    mid.append(t("snout", [(0, 1.0, 1.326), (0, 1.14, 1.298), (0, 1.27, 1.269), (0, 1.335, 1.257)],
                 [(0.06, 0.05), (0.047, 0.047), (0.036, 0.04), (0.027, 0.03)], segs=18, k=0.015, rings_per_m=120))
    mid.append(t("lower_jaw", [(0, 0.97, 1.264), (0, 1.12, 1.228), (0, 1.26, 1.208), (0, 1.32, 1.209)],
                 [(0.052, 0.026), (0.04, 0.022), (0.03, 0.018), (0.021, 0.015)], segs=16, k=0.01, rings_per_m=120))
    mid.append(e("knot", tuple(KNOT), (0.03, 0.036, 0.02), k=0.01))
    mid.append(e("crest", (0, 0.93, 1.385), (0.02, 0.07, 0.022), k=0.015))
    side.append(e("brow", (0.05, 1.02, 1.375), (0.026, 0.045, 0.016), rot=(0, 0, 12), k=0.012))
    side.append(e("cheek", (0.058, 1.0, 1.305), (0.02, 0.05, 0.02), k=0.012))
    side.append(e("jaw_hinge", (0.05, 0.975, 1.275), (0.018, 0.03, 0.03), k=0.012))
    # the tail: a stiff knotted root
    tl = J["tail"]
    mid.append(t("tail", [(0, -0.66, 0.88)] + [tuple(p) for p in tl], [0.06, 0.048, 0.04, 0.03, 0.02, 0.01], segs=12, k=0.03, rings_per_m=R))
    for i, p in enumerate(tl[1:4]):
        mid.append(e(f"tail_knot{i}", tuple(p), 0.046 - 0.008 * i, k=0.015))

    # ribs standing out of the flank
    for i, y in enumerate(RIB_Y):
        side.append(t(f"rib{i}", rib_path(y), [0.014, 0.019, 0.02, 0.018, 0.012], segs=8, k=0.012, rings_per_m=90))
    side.append(e("hip_bone", (0.11, -0.6, 0.95), (0.05, 0.08, 0.04), rot=(0, 0, 20), k=0.03))

    # front leg: long, knotted like a root
    su, sl, sf, sp = J["f_upper"], J["f_lower"], J["f_foot"], J["f_paw"]
    side.append(e("shoulder_blade", (0.15, 0.4, 0.88), (0.06, 0.12, 0.17), rot=(14, 0, 0), k=0.05))
    side.append(t("f_upper", [su + _v(-0.01, 0.01, 0.04), su + (sl - su) * 0.5, sl], [(0.075, 0.1), (0.06, 0.075), (0.046, 0.052)],
                  segs=14, k=0.035, rings_per_m=R))
    side.append(t("f_lower", [sl, sl + (sf - sl) * 0.35, sf], [0.046, 0.04, 0.034], segs=12, k=0.025, rings_per_m=R))
    side.append(t("f_foot", [sf, sf + (sp - sf) * 0.6, sp + _v(0, 0, 0.012)], [0.034, 0.031, 0.044], segs=12, k=0.02, rings_per_m=R))
    # hind leg
    hu, hl, hf, hp = J["h_upper"], J["h_lower"], J["h_foot"], J["h_paw"]
    side.append(e("haunch", (0.13, -0.56, 0.76), (0.08, 0.16, 0.2), rot=(-24, 0, 0), k=0.05))
    side.append(t("h_upper", [hu + _v(-0.01, 0, 0.03), hu + (hl - hu) * 0.5, hl], [(0.08, 0.115), (0.065, 0.085), (0.048, 0.055)],
                  segs=14, k=0.035, rings_per_m=R))
    side.append(t("h_lower", [hl, hl + (hf - hl) * 0.4, hf], [0.047, 0.04, 0.034], segs=12, k=0.025, rings_per_m=R))
    side.append(t("h_foot", [hf, hf + (hp - hf) * 0.6, hp + _v(0, 0, 0.012)], [0.034, 0.03, 0.044], segs=12, k=0.02, rings_per_m=R))
    for i, (c, r) in enumerate(knots()):
        side.append(e(f"burl{i}", tuple(c), r, k=0.02))
    for leg in ("f", "h"):
        for i, (root, tip) in enumerate(claws(leg)):
            mid_pt = root + (tip - root) * 0.5 + _v(0, 0, 0.03)
            side.append(t(f"{leg}_claw{i}", [root + _v(0, 0, 0.02), mid_pt, tip], [0.03, 0.024, 0.011], segs=8, rings_per_m=110, k=0.012))
    return mid, side


# ------------------------------------------------------------------ the spine

KNOBS = []


def ridge(f):
    """Vertebrae standing out of the back and the top of the neck (`f` is the body's distance field)."""
    pts = [(0.0, y, 1.25) for y in np.linspace(-0.68, 0.38, 12)]
    for u in np.linspace(0.12, 0.92, 7):
        p = _v(0, 0.44, 0.9) + (_v(0, 0.9, 1.31) - _v(0, 0.44, 0.9)) * u
        pts.append((0.0, p[1] - 0.14, p[2] + 0.2))
    P, N = _onto(f, np.array(pts))
    P[:, 0] = 0.0
    KNOBS.clear()
    out = []
    for i, (p, n) in enumerate(zip(P, N)):
        r = 0.026 if i < 12 else 0.02
        c = p + n * r * 0.3
        out.append(kit.ellipsoid(f"vert{i}", tuple(c), (r * 0.7, r * 0.95, r), k=0.01, segs=10))
        KNOBS.append(c)
    return out


# ------------------------------------------------------------------ cutters

def cutters():
    """The mouth, a hollow behind the teeth, sockets deep enough to look empty and the nose holes."""
    out = []
    ys = (1.37, 1.27, 1.14, 1.05, 0.995)
    out.append(kit.tube("mouth", [(0, y, mouth_z(y)) for y in ys],
                        [(0.03, 0.0045), (0.04, 0.0055), (0.05, 0.006), (0.056, 0.005), (0.05, 0.003)], segs=14, cap=0.2))
    out.append(kit.tube("gullet", [(0, 1.24, mouth_z(1.24)), (0, 1.13, mouth_z(1.13)), (0, 1.02, mouth_z(1.02))],
                        [(0.014, 0.008), (0.022, 0.012), (0.03, 0.012)], segs=12))
    for s in (1, -1):
        out.append(kit.ellipsoid(f"socket{s}", (0.05 * s, 1.03, 1.345), (0.02, 0.034, 0.022), rot=(0, 0, 10 * s)))
        out.append(kit.ellipsoid(f"nose{s}", (0.012 * s, 1.335, 1.262), (0.008, 0.02, 0.008), rot=(-10, 0, 0)))
        out.append(kit.ellipsoid(f"temple{s}", (0.07 * s, 0.95, 1.325), (0.012, 0.03, 0.02)))
    return out


# ------------------------------------------------------------------ zones

def _mirror(P):
    return P * np.where(P[:, :1] < 0, (-1, 1, 1), (1, 1, 1))


def zones(P, N):
    """Masks the surface material and the game mesh's detail weights read."""
    x, y, z = np.abs(P[:, 0]), P[:, 1], P[:, 2]
    Pm = _mirror(P)
    z_ = {}
    up = kit.ss((N[:, 2] - 0.15) / 0.5)
    z_["up"] = up
    z_["moss"] = np.clip(kit.ss((N[:, 2] + 0.25) / 0.6) * kit.ss((z - 0.7) / 0.2) * kit.ss((0.95 - y) / 0.08), 0, 1)
    # bone: the skull and jaw, the ribs, the vertebrae, the joints' burls, the tail's tip
    bone = kit.ss((y - 0.94) / 0.05) * kit.ss((z - 1.15) / 0.04)
    for ry in RIB_Y:
        d = kit.path_dist(Pm, rib_path(ry))
        bone = np.maximum(bone, kit.ss((0.024 - d) / 0.012))
    for c in KNOBS:
        bone = np.maximum(bone, kit.ss((0.03 - np.linalg.norm(P - c, axis=1)) / 0.012))
    for c, r in knots()[:4]:
        bone = np.maximum(bone, 0.8 * kit.ss((r * 0.95 - np.linalg.norm(Pm - c, axis=1)) / 0.02))
    bone = np.maximum(bone, kit.ss((0.72 - z) / 0.1) * kit.ss((-0.98 - y) / 0.08))
    z_["bone"] = np.clip(bone, 0, 1)
    in_head = (y > 0.99) & (z > 1.19) & (z < 1.3) & (x < 0.06)
    dz = z - np.array([mouth_z(v) for v in y])
    inside = (y < 1.31) & (x < np.interp(y, (1.0, 1.14, 1.27, 1.325), (0.042, 0.033, 0.024, 0.011)) - 0.003)
    z_["mouth"] = (in_head & inside & (np.abs(dz) < 0.02) & (N[:, 2] * np.sign(dz) < -0.5)).astype(float)
    nail = np.zeros(len(P))
    for leg in ("f", "h"):
        for root, tip in claws(leg):
            d, u = kit.seg_dist(Pm, root, tip)
            nail = np.maximum(nail, kit.ss((0.03 - d) / 0.01) * kit.ss((u - 0.35) / 0.3))
    z_["nail"] = nail
    kd = np.linalg.norm((P - KNOT) / np.array((0.032, 0.038, 0.024)), axis=1)
    z_["knot"] = kit.ss((1.1 - kd) / 0.3)
    z_["keep"] = np.clip(kit.ss((y - 0.9) / 0.05) * 1.0 + kit.ss((0.12 - z) / 0.05) * 0.5, 0, 1)
    return z_


# ------------------------------------------------------------------ surface

def bark_field(P, N):
    """Relief the voxels can hold: bark plates along the body and the legs."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    plate = np.sin(x * 23.0 + y * 8.0 + 1.0) * np.sin(y * 13.0 - z * 17.0 + 0.4) * np.sin(z * 27.0 + x * 7.0)
    fine = np.sin(x * 63.0 + y * 31.0) * np.sin(y * 57.0 - z * 47.0) * np.sin(z * 71.0 + x * 23.0)
    head = kit.ss((y - 0.94) / 0.05) * kit.ss((z - 1.15) / 0.04)
    return (0.006 * plate + 0.002 * fine) * (1.0 - 0.9 * head)
