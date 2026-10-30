"""Per-character body sculpts for the main cast, built on Feyre's sculpt.

`load(params)` returns a private copy of feyre_shape with its face constants
patched and `build_grid` replaced by the parametric sculpt below.  The builder
installs it as `sys.modules["feyre_shape"]` before importing build_feyre, so
Feyre's rig, weights, shape keys, eyes, lids, lashes, makeup masks, hair kit
and wardrobe kit all run unchanged on the new head and body.

Everything here is sculpted in Feyre's space (1.66 m, her landmarks); height,
shoulder width and limb length come afterwards from cast_warp, which moves the
skinned meshes and the skeleton together.  Defaults reproduce Feyre exactly.
"""

import importlib.util
import math
import os
import sys

import numpy as np

FEYRE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "feyre")
sys.path.insert(0, os.path.abspath(FEYRE_DIR))
import sdf  # noqa: E402

# Feyre = every value at its default.
DEFAULTS = dict(
    # face
    eye_r=0.0188, eye_open_up=35.0, eye_open_lo=31.0, eye_tilt=7.0, eye_open_w=64.0,
    cheeks=1.0,          # baby-cheek size
    gaunt=0.0,           # hollow under the cheekbones (age, hunger)
    cheekbones=0.0,      # high, sharp cheekbones
    jaw=0.0,             # square jaw angle mass (0 = soft princess jaw)
    jaw_w=1.0,           # jaw width
    chin=1.0,            # chin ball size
    chin_drop=0.0,       # longer lower face (m)
    chin_point=0.0,      # narrower, pointed chin
    brow=0.0,            # brow ridge
    nose=1.0,            # nose length/size
    nose_bridge=0.0,     # straighter, higher bridge
    lips=1.0,            # lip fullness
    lip_w=1.0,           # mouth width
    fae_ears=0.0,        # 1 = High Fae pointed ears
    cranium=1.0,
    face_w=1.0,          # face width
    neck=1.0,            # neck radius
    adams_apple=0.0,
    # body
    bust=1.0, pecs=0.0, ribs=1.0, waist=1.0, belly=1.0, pelvis=1.0, seat=1.0,
    lats=1.0, thigh=1.0, calf=1.0, arm=1.0, forearm=1.0, deltoid=1.0, hand=1.0,
    knee_scar=0.0,       # 1 = the father's smashed right knee (lumpy, twisted)
)


def load(params=None):
    """A fresh feyre_shape module configured for one character."""
    p = dict(DEFAULTS)
    p.update(params or {})
    spec = importlib.util.spec_from_file_location("feyre_shape", os.path.join(FEYRE_DIR, "feyre_shape.py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    m.EYE_R = p["eye_r"]
    m.EYE_OPEN_UP = math.radians(p["eye_open_up"])
    m.EYE_OPEN_LO = math.radians(p["eye_open_lo"])
    m.EYE_OPEN_W = math.radians(p["eye_open_w"])
    m.EYE_TILT = math.radians(p["eye_tilt"])
    m.MOUTH_HALF_W = 0.0165 * p["lip_w"]
    m.CHIN_Z = 1.405 - p["chin_drop"]
    m.NOSE_TIP = np.array([0.0, -0.0925 - 0.006 * (p["nose"] - 1.0), 1.4725 - 0.004 * (p["nose"] - 1.0)])
    m.CAST_PARAMS = p
    m.build_grid = lambda h=0.0025: build_grid(m, p, h)
    return m


def build_grid(m, p, h=0.0025):
    g = sdf.Grid((-0.80, -0.20, -0.01), (0.80, 0.17, 1.70), h)
    U, S = g.union, g.subtract
    rz, rx, ry = m._rot_z, m._rot_x, m._rot_y
    mirror = m.mirror
    fw = p["face_w"]
    cd = p["chin_drop"]

    # Head --------------------------------------------------------------
    cr = p["cranium"]
    U(sdf.ellipsoid((0, 0.012, 1.553), (0.0915 * cr * fw ** 0.5, 0.096 * cr, 0.1035 * cr)))
    U(sdf.ellipsoid((0, -0.010, 1.497 - cd * 0.4), (0.0775 * fw, 0.074, 0.080 + cd * 0.4)), 0.03)
    ck = p["cheeks"]
    if ck > 0.05:
        for s in (1, -1):
            U(sdf.ellipsoid((0.042 * s * fw, -0.053, 1.474), (0.032 * ck, 0.031 * ck, 0.027 * ck)), 0.022 * ck)
    if p["cheekbones"] > 0:
        for s in (1, -1):
            U(sdf.ellipsoid((0.054 * s * fw, -0.047, 1.497), (0.026, 0.020, 0.012 + 0.004 * p["cheekbones"]),
                            rz(math.radians(-18 * s))), 0.014)
    jw = p["jaw_w"]
    U(sdf.round_cone((0, -0.024, 1.462 - cd * 0.5), (0, -0.056, 1.423 - cd), 0.052 * jw, 0.0175 * jw ** 0.5), 0.03)
    if p["jaw"] > 0:
        j = p["jaw"]
        for s in (1, -1):   # mandible angle below the ear, and the jaw line to the chin
            U(sdf.sphere((0.052 * s * jw, -0.004, 1.452 - cd * 0.6), 0.015 + 0.006 * j), 0.018)
            U(sdf.round_cone((0.052 * s * jw, -0.010, 1.450 - cd * 0.6), (0.018 * s, -0.054, 1.420 - cd),
                             0.012 + 0.004 * j, 0.010 + 0.003 * j), 0.012)
    chin_r = 0.0145 * p["chin"]
    if p["chin_point"] > 0:
        U(sdf.ellipsoid((0, -0.062, 1.4205 - cd), (chin_r * (1 - 0.35 * p["chin_point"]), chin_r * 0.9, chin_r * 1.1)),
          0.012)
    elif p["jaw"] > 0:
        U(sdf.ellipsoid((0, -0.063, 1.4205 - cd), (chin_r * 1.35, chin_r, chin_r * 1.05)), 0.012)  # square chin
    else:
        U(sdf.sphere((0, -0.061, 1.4205 - cd), chin_r), 0.012)
    U(sdf.ellipsoid((0, -0.058, 1.556), (0.064 * fw, 0.034, 0.030)), 0.025)
    if p["brow"] > 0:
        b = p["brow"]
        for s in (1, -1):
            U(sdf.ellipsoid((0.034 * s, -0.073 - 0.002 * b, m.EYE_Z + 0.027), (0.026, 0.011, 0.0065 + 0.002 * b),
                            rz(math.radians(-8 * s))), 0.012)
    if p["gaunt"] > 0:
        for s in (1, -1):
            S(sdf.ellipsoid((0.056 * s * fw, -0.060, 1.466), (0.018, 0.012, 0.018)), 0.016 * p["gaunt"])
    # ears
    fe = p["fae_ears"]
    for s in (1, -1):
        rot = rz(math.radians(-12 * s)) @ rx(math.radians(-8))
        U(sdf.ellipsoid((0.088 * s * fw, 0.016, 1.500), (0.010, 0.019, 0.026 + 0.004 * fe), rot), 0.006)
        if fe > 0:  # High Fae: the helix sweeps up and back to a fine point
            U(sdf.round_cone((0.090 * s * fw, 0.020, 1.515), (0.101 * s * fw, 0.040, 1.548 + 0.012 * fe),
                             0.0085, 0.0012), 0.006)
        S(sdf.ellipsoid((0.096 * s * fw, 0.012, 1.497), (0.004, 0.011, 0.016 + 0.003 * fe), rot), 0.003)
    # nose
    n = p["nose"]
    nb = p["nose_bridge"]
    top = (0, -0.0825 - 0.002 * nb, 1.500 + 0.012 * nb)
    U(sdf.round_cone(top, (0, -0.0885 - 0.006 * (n - 1), 1.477 - 0.004 * (n - 1)),
                     0.0038 + 0.0012 * nb, 0.0050 * n ** 0.5), 0.010)
    U(sdf.sphere(m.NOSE_TIP, 0.0057 * n ** 0.6), 0.005)
    for s in (1, -1):
        U(sdf.sphere((0.0068 * s * n ** 0.5, -0.0855 - 0.004 * (n - 1), 1.4700 - 0.004 * (n - 1)), 0.0040 * n ** 0.5),
          0.004)
    # lips
    L, lw = p["lips"], p["lip_w"]
    MY, MZ = m.MOUTH_Y, m.MOUTH_Z
    for s in (1, -1):
        U(sdf.ellipsoid((0.0068 * s * lw, MY + 0.0015, MZ + 0.0036 * L), (0.0098 * lw, 0.0046 * L, 0.0040 * L),
                        ry(math.radians(-12 * s))), 0.005)
    U(sdf.ellipsoid((0, MY + 0.0022, MZ - 0.0043 * L), (0.0118 * lw, 0.0052 * L, 0.0048 * L)), 0.005)
    S(sdf.ellipsoid((0, MY - 0.0055, MZ), (0.016 * lw, 0.005, 0.0010)), 0.0012)
    S(sdf.ellipsoid((0, MY - 0.0035, MZ - 0.0155 - cd * 0.3), (0.011, 0.004, 0.0032)), 0.006)
    S(sdf.ellipsoid((0, MY - 0.0035, MZ + 0.0135), (0.0032, 0.003, 0.0045)), 0.004)
    for s in (1, -1):
        S(m.eye_cut(s), 0.0022)
        U(m.lid_margin(s, True), 0.003)
        U(m.lid_margin(s, False), 0.0025)
        U(sdf.sphere((m.EYE_X * s, m.EYE_Y, m.EYE_Z), m.EYE_R - 0.002))

    # Neck ----------------------------------------------------------------
    nk = p["neck"]
    U(sdf.round_cone(m.NECK_BASE + (0, 0.002, -0.03), m.NECK_TOP + (0, 0.004, 0.03), 0.046 * nk, 0.039 * nk), 0.022)
    if p["adams_apple"] > 0:
        U(sdf.ellipsoid((0, -0.030 * nk, 1.385), (0.008, 0.008, 0.012)), 0.010 * p["adams_apple"])
    if nk > 1.05:   # trapezius slope into the shoulders
        for s in (1, -1):
            U(sdf.round_cone((0.02 * s, 0.020, 1.37), (0.12 * s, 0.018, 1.29), 0.030 * nk, 0.026), 0.04)

    # Torso ---------------------------------------------------------------
    U(sdf.round_cone((-0.118, 0.012, 1.282), (0.118, 0.012, 1.282), 0.040 * p["deltoid"] ** 0.5,
                     0.040 * p["deltoid"] ** 0.5), 0.05)
    rb = p["ribs"]
    U(sdf.ellipsoid((0, 0.004, 1.175), (0.102 * rb, 0.072 * rb, 0.128)), 0.05)
    if p["bust"] > 0.05:
        for s in (1, -1):
            U(sdf.sphere((0.047 * s, -0.045, 1.178), 0.041 * p["bust"]), 0.028)
    if p["pecs"] > 0:
        pc = p["pecs"]
        for s in (1, -1):
            U(sdf.ellipsoid((0.048 * s, -0.044 - 0.003 * pc, 1.215), (0.058, 0.020 + 0.003 * pc, 0.034),
                            ry(math.radians(10 * s))), 0.02)
        for k, z in enumerate((1.075, 1.035, 0.995)):      # a hint of abdominal blocks
            for s in (1, -1):
                U(sdf.ellipsoid((0.020 * s, -0.050 + 0.004 * k, z), (0.017, 0.010, 0.016)), 0.018 * pc)
    U(sdf.ellipsoid((0, 0.008, 1.028), (0.083 * p["waist"], 0.062 * p["waist"] ** 0.5, 0.095)), 0.06)
    U(sdf.ellipsoid((0, -0.012, 0.965), (0.072, 0.045 * p["belly"], 0.060)), 0.04)
    U(sdf.ellipsoid((0, 0.010, 0.900), (0.124 * p["pelvis"], 0.080, 0.098)), 0.06)
    for s in (1, -1):
        U(sdf.sphere((0.058 * s * p["pelvis"], 0.040, 0.872), 0.064 * p["seat"]), 0.04)
        U(sdf.round_cone((0.03 * s, 0.03, 1.12), (0.12 * s, 0.03, 1.27), 0.045 * p["lats"], 0.035 * p["lats"]), 0.04)
        U(sdf.capsule((0.012 * s, -0.022, 1.296), (0.11 * s, -0.012, 1.302), 0.006), 0.012)

    # Legs ----------------------------------------------------------------
    th, ca = p["thigh"], p["calf"]
    for s in (1, -1):
        knee = mirror(m.KNEE, s)
        ankle = mirror(m.ANKLE, s)
        U(sdf.round_cone((0.086 * s, 0.006, 0.87), knee, 0.068 * th ** 0.5, 0.040), 0.05)
        U(sdf.ellipsoid((0.093 * s, -0.002, 0.70), (0.054 * th, 0.056 * th, 0.13)), 0.05)
        U(sdf.sphere((0.088 * s, -0.010, 0.466), 0.036), 0.03)
        U(sdf.round_cone(knee, ankle, 0.041 * ca ** 0.5, 0.024), 0.03)
        U(sdf.ellipsoid((0.091 * s, 0.020, 0.335), (0.044 * ca, 0.046 * ca, 0.095)), 0.04)
        U(sdf.sphere((0.090 * s, 0.032, 0.036), 0.032), 0.02)
        U(sdf.round_cone((0.090 * s, 0.020, 0.050), mirror(m.BALL, s), 0.030, 0.026), 0.025)
        U(sdf.ellipsoid((0.091 * s, -0.122, 0.020), (0.030, 0.034, 0.016)), 0.018)
        U(sdf.sphere(ankle, 0.026), 0.02)
        if p["knee_scar"] > 0 and s < 0:
            # creditors broke this knee again and again: swollen, knotted, twisted
            for c, r in (((-0.072, -0.030, 0.478), 0.016), ((-0.103, -0.024, 0.452), 0.013),
                         ((-0.084, -0.036, 0.440), 0.011), ((-0.096, -0.010, 0.495), 0.012)):
                U(sdf.sphere(c, r), 0.010)
    S(sdf.halfspace((0, 0, 0.0), (0, 0, 1), ((-0.3, -0.25, -0.02), (0.3, 0.15, 0.02))), 0.004)

    # Arms ----------------------------------------------------------------
    ar, fa, hd = p["arm"], p["forearm"], p["hand"]
    for s in (1, -1):
        sh, el, wr = mirror(m.SHOULDER, s), mirror(m.ELBOW, s), mirror(m.WRIST, s)
        U(sdf.sphere((0.150 * s, 0.010, 1.287), 0.046 * p["deltoid"]), 0.035)
        U(sdf.round_cone(sh, el, 0.039 * ar, 0.028 * ar), 0.03)
        if ar > 1.05:   # biceps / triceps
            U(sdf.ellipsoid((0.285 * s, -0.004, 1.283), (0.070, 0.030 * ar, 0.028 * ar)), 0.03)
        U(sdf.round_cone(el, wr, 0.028 * fa, 0.0195 * fa ** 0.5), 0.015)
        U(sdf.ellipsoid((0.465 * s, 0.010, 1.285), (0.075, 0.030 * fa, 0.031 * fa)), 0.03)
        U(sdf.ellipsoid((0.672 * s, -0.001, 1.284), (0.044, 0.034 * hd, 0.0135 * hd)), 0.014)
        for f in m.FINGERS:
            pts = m.finger_points(f, s)
            r = m.FINGERS[f][3] * hd
            U(sdf.tube(pts, [r, r * 0.92, r * 0.84, r * 0.72]), 0.0035)
        tp = [mirror(q, s) for q in m.THUMB]
        U(sdf.tube(tp, [x * hd for x in (0.0115, 0.0098, 0.0088, 0.0076)]), 0.008)
    return g
