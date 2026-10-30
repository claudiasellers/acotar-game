"""Feyre's body as a signed-distance sculpt, plus the landmarks every builder shares.

Art direction (R3): a storybook-princess take on a 19-year-old huntress.  About
1 : 5.9 head-to-body, big round blue-grey eyes with an arched upper lid, a small
button nose, full soft lips, round cheeks and a small chin; slim neck, narrow
waist, long legs, small hands and feet.  Thin-from-hunger is the base; the
`nourished` shape key fills her out.

Blender space: Z up, she faces -Y, her left is +X, feet on the origin, T-pose
with palms down (fingers along +X, spread in Y, thumb forward).
"""

import math

import numpy as np

import sdf

HEIGHT = 1.66

# ---- head -----------------------------------------------------------------
CHIN_Z = 1.405
HEAD_C = np.array([0.0, 0.004, 1.528])  # rough head centre (UV projection / weights)
EYE_R = 0.0188
EYE_X = 0.0365
EYE_Z = 1.507
EYE_Y = -0.0612
NOSE_TIP = np.array([0.0, -0.0925, 1.4725])
MOUTH_Z = 1.4455
MOUTH_Y = -0.0815
MOUTH_HALF_W = 0.0165
BROW_Z = EYE_Z + 0.029
# eye opening, as angles (radians) seen from the eye centre: horizontal half-width,
# upper and lower lid heights, and how far the opening tilts up at the outer corner
EYE_OPEN_W = math.radians(64)
EYE_OPEN_UP = math.radians(35)
EYE_OPEN_LO = math.radians(31)
EYE_TILT = math.radians(7)

# ---- skeleton anchor points ----------------------------------------------
NECK_BASE = np.array([0.0, 0.012, 1.315])
NECK_TOP = np.array([0.0, 0.006, 1.43])
SHOULDER = np.array([0.158, 0.008, 1.285])
ELBOW = np.array([0.405, 0.012, 1.285])
WRIST = np.array([0.625, 0.008, 1.285])
HAND_END = np.array([0.69, 0.0, 1.283])
HIP = np.array([0.083, 0.004, 0.835])
KNEE = np.array([0.088, -0.004, 0.462])
ANKLE = np.array([0.090, 0.016, 0.078])
BALL = np.array([0.091, -0.088, 0.022])
TOE_END = np.array([0.091, -0.150, 0.018])
HIPS_Z = 0.885
SPINE_Z = 0.985
CHEST_Z = 1.085
UPPER_CHEST_Z = 1.19

# Fingers (left hand): name -> (y offset, z offset at knuckle, length, radius)
FINGERS = {
    "Index": (-0.0215, 0.0, 0.074, 0.0083),
    "Middle": (-0.0072, 0.0012, 0.080, 0.0085),
    "Ring": (0.0072, 0.0, 0.075, 0.0080),
    "Little": (0.0205, -0.0018, 0.060, 0.0070),
}
KNUCKLE_X = 0.712
THUMB = [(0.646, -0.018, 1.278), (0.666, -0.037, 1.276), (0.684, -0.052, 1.274), (0.700, -0.064, 1.273)]


def finger_points(name, side=1):
    dy, dz, length, _ = FINGERS[name]
    x0 = KNUCKLE_X - (0.004 if name in ("Middle", "Ring") else 0.0) + (0.006 if name == "Middle" else 0.0)
    segs = [0.0, 0.42, 0.74, 1.0]
    pts = []
    for s in segs:
        # a gentle downward curl and spread
        x = x0 + length * s
        y = dy * (1.0 + 0.25 * s)
        z = 1.285 + dz - 0.006 * s * s
        pts.append((x * side, y, z))
    return pts


def mirror(p, s):
    return (p[0] * s, p[1], p[2])


# --------------------------------------------------------------------------
# Eye lids: a shell around the eyeball with an almond opening cut out.
# --------------------------------------------------------------------------
def eye_angles(qx, qy, qz, outward):
    """Angles of a point seen from an eye centre: (ax towards the outer corner, az up
    relative to the tilted lid line, upper-lid height at ax, lower-lid depth at ax)."""
    fwd = np.maximum(-qy, 1e-6)
    ax = np.arctan2(qx * outward, fwd)
    az = np.arctan2(qz, np.sqrt(fwd * fwd + qx * qx)) - EYE_TILT * np.clip(ax / EYE_OPEN_W, -1, 1)
    tx = ax / EYE_OPEN_W
    # upper lid is a high arch, lower lid a flatter curve; both pinch to the corners
    up = EYE_OPEN_UP * np.sqrt(np.clip(1.0 - np.abs(tx) ** 2.2, 0.0, 1.0))
    lo = EYE_OPEN_LO * np.sqrt(np.clip(1.0 - np.abs(tx) ** 1.6, 0.0, 1.0))
    return ax, az, up, lo


def _eye_opening(qx, qy, qz, outward):
    """>0 outside the opening (lid), <0 inside.  Approximate metres along the eye surface."""
    ax, az, up, lo = eye_angles(qx, qy, qz, outward)
    d = np.maximum(np.maximum(az - up, -lo - az), np.abs(ax) - EYE_OPEN_W)
    back = (qy > -0.004)  # only the front of the eyeball has an opening
    return np.where(back, 1.0, d * EYE_R)


def eye_cut(side):
    """Everything in front of the eyeball inside the almond opening: subtracting it
    leaves the face surface as the lids, with a rounded lid edge."""
    c = np.array([EYE_X * side, EYE_Y, EYE_Z])
    reach = EYE_R + 0.03

    def f(X, Y, Z):
        qx, qy, qz = X - c[0], Y - c[1], Z - c[2]
        dist = np.sqrt(qx * qx + qy * qy + qz * qz)
        return np.maximum(dist - reach, _eye_opening(qx, qy, qz, side))
    return sdf.custom(f, c - reach, c + reach)


LID_R = (0.0027, 0.0017)       # upper / lower lid-margin tube radius
LID_GAP = 0.0016               # eyeball surface to tube surface


def lid_curve(side, upper=True, n=17, extra=0.0):
    """Points along the upper (or lower) lid margin, plus their outward directions."""
    c = np.array([EYE_X * side, EYE_Y, EYE_Z])
    r = LID_R[0] if upper else LID_R[1]
    pts, dirs = [], []
    for i in range(n):
        tx = -1.0 + 2.0 * i / (n - 1)
        ax = tx * EYE_OPEN_W
        if upper:
            az = EYE_OPEN_UP * math.sqrt(max(0.0, 1.0 - abs(tx) ** 2.2)) + math.radians(2)
        else:
            az = -EYE_OPEN_LO * math.sqrt(max(0.0, 1.0 - abs(tx) ** 1.6)) - math.radians(2)
        az += EYE_TILT * tx
        d = np.array([math.sin(ax) * math.cos(az) * side, -math.cos(ax) * math.cos(az), math.sin(az)])
        pts.append(c + d * (EYE_R + LID_GAP + r + extra))
        dirs.append(d)
    return np.array(pts), np.array(dirs)


def lid_margin(side, upper=True):
    pts, _ = lid_curve(side, upper)
    n = len(pts)
    r = LID_R[0] if upper else LID_R[1]
    radii = [r * (0.45 + 0.55 * math.sin(math.pi * i / (n - 1)) ** 0.5) for i in range(n)]
    return sdf.tube([tuple(p) for p in pts], radii)


# --------------------------------------------------------------------------
# The sculpt
# --------------------------------------------------------------------------
def build_grid(h=0.0025):
    g = sdf.Grid((-0.80, -0.20, -0.01), (0.80, 0.17, 1.70), h)
    U, S = g.union, g.subtract

    # Head --------------------------------------------------------------
    U(sdf.ellipsoid((0, 0.012, 1.553), (0.0915, 0.096, 0.1035)))                 # cranium
    U(sdf.ellipsoid((0, -0.010, 1.497), (0.0775, 0.074, 0.080)), 0.03)          # face mass
    for s in (1, -1):
        U(sdf.ellipsoid((0.042 * s, -0.053, 1.474), (0.032, 0.031, 0.027)), 0.022)  # baby cheeks
    U(sdf.round_cone((0, -0.024, 1.462), (0, -0.056, 1.423), 0.052, 0.0175), 0.03)  # jaw to chin
    U(sdf.sphere((0, -0.061, 1.4205), 0.0145), 0.012)                              # chin ball
    # brow ridge softness (very slight) and temple fill
    U(sdf.ellipsoid((0, -0.058, 1.556), (0.064, 0.034, 0.030)), 0.025)
    # ears (small, rounded, mostly under hair)
    for s in (1, -1):
        rot = _rot_z(math.radians(-12 * s)) @ _rot_x(math.radians(-8))
        U(sdf.ellipsoid((0.088 * s, 0.016, 1.500), (0.010, 0.019, 0.026), rot), 0.006)
        S(sdf.ellipsoid((0.096 * s, 0.012, 1.497), (0.004, 0.011, 0.016), rot), 0.003)
    # nose: soft bridge + button tip + nostril wings
    U(sdf.round_cone((0, -0.0825, 1.500), (0, -0.0885, 1.477), 0.0038, 0.0050), 0.010)
    U(sdf.sphere(NOSE_TIP, 0.0057), 0.005)
    for s in (1, -1):
        U(sdf.sphere((0.0068 * s, -0.0855, 1.4700), 0.0040), 0.004)
           # nostril shadow
    # lips: full upper with a soft cupid's bow, rounder lower
    for s in (1, -1):
        U(sdf.ellipsoid((0.0068 * s, MOUTH_Y + 0.0015, MOUTH_Z + 0.0036), (0.0098, 0.0046, 0.0040),
                        _rot_y(math.radians(-12 * s))), 0.005)
    U(sdf.ellipsoid((0, MOUTH_Y + 0.0022, MOUTH_Z - 0.0043), (0.0118, 0.0052, 0.0048)), 0.005)
    S(sdf.ellipsoid((0, MOUTH_Y - 0.0055, MOUTH_Z), (0.016, 0.005, 0.0010)), 0.0012)  # mouth line
    S(sdf.ellipsoid((0, MOUTH_Y - 0.0035, MOUTH_Z - 0.0155), (0.011, 0.004, 0.0032)), 0.006)  # crease above the chin
    S(sdf.ellipsoid((0, MOUTH_Y - 0.0035, MOUTH_Z + 0.0135), (0.0032, 0.003, 0.0045)), 0.004)          # philtrum
    # eye sockets + lids
    for s in (1, -1):
        S(eye_cut(s), 0.0022)
        U(lid_margin(s, True), 0.003)
        U(lid_margin(s, False), 0.0025)
        U(sdf.sphere((EYE_X * s, EYE_Y, EYE_Z), EYE_R - 0.002))   # closes the socket behind the eyeball

    # Neck ----------------------------------------------------------------
    U(sdf.round_cone(NECK_BASE + (0, 0.002, -0.03), NECK_TOP + (0, 0.004, 0.03), 0.046, 0.039), 0.022)

    # Torso ---------------------------------------------------------------
    U(sdf.round_cone((-0.118, 0.012, 1.282), (0.118, 0.012, 1.282), 0.040, 0.040), 0.05)  # shoulder bar
    U(sdf.ellipsoid((0, 0.004, 1.175), (0.102, 0.072, 0.128)), 0.05)            # ribcage
    for s in (1, -1):
        U(sdf.sphere((0.047 * s, -0.045, 1.178), 0.041), 0.028)                  # bust
    U(sdf.ellipsoid((0, 0.008, 1.028), (0.083, 0.062, 0.095)), 0.06)            # waist
    U(sdf.ellipsoid((0, -0.012, 0.965), (0.072, 0.045, 0.060)), 0.04)           # belly
    U(sdf.ellipsoid((0, 0.010, 0.900), (0.124, 0.080, 0.098)), 0.06)            # pelvis
    for s in (1, -1):
        U(sdf.sphere((0.058 * s, 0.040, 0.872), 0.064), 0.04)                    # seat
        U(sdf.round_cone((0.03 * s, 0.03, 1.12), (0.12 * s, 0.03, 1.27), 0.045, 0.035), 0.04)  # back/lats
    # collarbones (subtle)
    for s in (1, -1):
        U(sdf.capsule((0.012 * s, -0.022, 1.296), (0.11 * s, -0.012, 1.302), 0.006), 0.012)

    # Legs ----------------------------------------------------------------
    for s in (1, -1):
        hip = mirror(HIP, s)
        knee = mirror(KNEE, s)
        ankle = mirror(ANKLE, s)
        U(sdf.round_cone((0.086 * s, 0.006, 0.87), knee, 0.068, 0.040), 0.05)    # thigh
        U(sdf.ellipsoid((0.093 * s, -0.002, 0.70), (0.054, 0.056, 0.13)), 0.05)  # thigh fullness
        U(sdf.sphere((0.088 * s, -0.010, 0.466), 0.036), 0.03)                    # knee
        U(sdf.round_cone(knee, ankle, 0.041, 0.024), 0.03)                        # shin
        U(sdf.ellipsoid((0.091 * s, 0.020, 0.335), (0.044, 0.046, 0.095)), 0.04)  # calf
        # foot: heel, arch, ball and toes, flat sole
        U(sdf.sphere((0.090 * s, 0.032, 0.036), 0.032), 0.02)
        U(sdf.round_cone((0.090 * s, 0.020, 0.050), mirror(BALL, s), 0.030, 0.026), 0.025)
        U(sdf.ellipsoid((0.091 * s, -0.122, 0.020), (0.030, 0.034, 0.016)), 0.018)
        U(sdf.sphere(ankle, 0.026), 0.02)
        del hip
    S(sdf.halfspace((0, 0, 0.0), (0, 0, 1), ((-0.3, -0.25, -0.02), (0.3, 0.15, 0.02))), 0.004)  # flat soles

    # Arms ----------------------------------------------------------------
    for s in (1, -1):
        sh, el, wr = mirror(SHOULDER, s), mirror(ELBOW, s), mirror(WRIST, s)
        U(sdf.sphere((0.150 * s, 0.010, 1.287), 0.046), 0.035)                   # deltoid
        U(sdf.round_cone(sh, el, 0.039, 0.028), 0.03)                             # upper arm
        U(sdf.round_cone(el, wr, 0.028, 0.0195), 0.015)                           # forearm
        U(sdf.ellipsoid((0.465 * s, 0.010, 1.285), (0.075, 0.030, 0.031)), 0.03)  # forearm fullness
        # hand (palm down): palm, fingers, thumb
        U(sdf.ellipsoid((0.672 * s, -0.001, 1.284), (0.044, 0.034, 0.0135)), 0.014)
        for f in FINGERS:
            pts = finger_points(f, s)
            r = FINGERS[f][3]
            U(sdf.tube(pts, [r, r * 0.92, r * 0.84, r * 0.72]), 0.0035)
        tp = [mirror(p, s) for p in THUMB]
        U(sdf.tube(tp, [0.0115, 0.0098, 0.0088, 0.0076]), 0.008)
    return g


def _rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def _rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def _rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


# ---- shared fit for head accessories ---------------------------------------
# Every hairstyle keeps its volume inside this ring at crown height, so tiaras and
# crowns built on it sit on all 16 styles.  (centre, x radius, y radius, tilt: front lower)
CROWN_RING = {"centre": (0.0, 0.010, 1.602), "rx": 0.110, "ry": 0.117, "tilt_deg": 12.0}
