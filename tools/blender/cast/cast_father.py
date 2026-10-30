"""Feyre's father, the ruined merchant (lore/03-characters/archeron-family.md).

Canon [C]: once a wealthy merchant, ruined when his fleet sank; creditors came
and smashed his knee again and again, leaving it twisted and aching in the
damp; he walks with a cane, keeps the leg stretched to the fire and whittles
little wooden figures there.  Passive, defeated, gentle.
[X]: 1.75 m, thin and stooped (the stoop lives in his clips; the rest pose is
the T-pose); the RIGHT knee is the broken one (cast_shape knee_scar); greying
brown hair, thinning and receding, with a short greying beard; hazel eyes;
a once-fine merchant's long coat in faded dove grey with mismatched patched
elbows, a faded periwinkle waistcoat with one button missing, cream shirt and
a soft butter cravat, taupe trousers darned at the bad knee, worn buckled
shoes.  Tarnished gold buttons are all that is left of the money.
Props (unskinned, origin = grip): the cane he carved himself (a whittled bird
for a handle, leaves round the collar) held in the LEFT hand, opposite the bad
knee; a small carving knife (RightHand) and a half-carved wooden bird
(LeftHand) for the fireside.
Clips: idle_cane (stooped, weight off the right leg, cane at his left side),
walk_limp (1.0 m/s, short guarded right stance, stiff right knee, hip hike and
a lurch onto the cane), sit_carve (on a low stool, right leg stretched out,
whittling).
"""

import dataclasses
import math

import numpy as np
from mathutils import Matrix, Quaternion
from mathutils import Vector as V

import cast_common as cc

HEIGHT = 1.75
SHAPE = dict(
    eye_r=0.0166, eye_open_up=23.0, eye_open_lo=23.0, eye_tilt=-5.0, eye_open_w=60.0,
    cheeks=0.0, gaunt=1.0, cheekbones=0.55, jaw=0.65, jaw_w=0.86, chin=1.1, chin_drop=0.020, brow=0.8,
    nose=1.38, nose_bridge=0.55, lips=0.68, lip_w=1.02, fae_ears=0.0, face_w=0.93, neck=0.95,
    adams_apple=0.9,
    bust=0.0, pecs=0.25, ribs=1.0, waist=1.04, belly=0.95, pelvis=0.92, seat=0.55, lats=1.0,
    thigh=0.80, calf=0.84, arm=0.95, forearm=0.96, deltoid=0.95, hand=1.08,
    knee_scar=1.0,
)
WARP = dict(height=HEIGHT, head=1.04, legs=1.01, arm_len=1.0, arm_thick=0.96,
            wx=((0.0, 1.0), (0.45, 0.98), (0.85, 0.97), (1.00, 1.00), (1.15, 1.05), (1.285, 1.08),
                (1.37, 1.02), (1.47, 1.0)),
            wy=((0.0, 1.0), (0.85, 0.96), (1.05, 1.00), (1.25, 1.02), (1.40, 1.0), (1.47, 1.0)))
GAIT = "male"
SKIN_LINEAR = cc.srgb("E5BDA6")
SKIN_SRGB = "E5BDA6"
IRIS = ((0.24, 0.30, 0.14), (0.52, 0.40, 0.18), (0.62, 0.52, 0.22))   # hazel: green-brown rim, amber-brown centre
IRIS_FLECKS = 0.7
LASH = 0.5
LASH_LINEAR = cc.srgb("6A5C50")
HAIR_RGB = cc.srgb("968A7E")       # greying brown
BEARD_RGB = cc.srgb("ACA49C")      # greyer in the beard
BROWS_SRGB = "7B6B5D"
LIPS_SRGB = "B48478"

DEFAULT_OUTFIT = ["father_shirt", "father_waistcoat", "father_coat", "father_trousers", "father_shoes"]
DEFAULT_HAIR = "father_greying"
# (prop, bone, glTF bone-local grip transform: tx, ty, tz, qx, qy, qz, qw), read back from an export
HELD_PROPS = [("father_cane", "LeftHand", (0.00513, 0.07954, -0.02723, -0.57495, -0.29195, -0.74888, 0.15289))]
IDLE_CLIP = "idle_cane"
WALK_CLIP = "walk_limp"

DOVE, DOVE_D, LILAC, PERI, BUTTER, CREAM = "A9A4B6", "8F8A9F", "BDAAD2", "9EA9CF", "E9D9A3", "F1EADB"
TAUPE, SHOE, SOLE, TARNISH = "8A8392", "6E6068", "4F4649", "A8915C"
PAL = {"fabric": (DOVE, 0.72, 0.0), "lining": (LILAC, 0.55, 0.0), "trim": (DOVE_D, 0.7, 0.0),
       "chain": (TARNISH, 0.42, 0.55), "patch_a": (LILAC, 0.8, 0.0), "patch_b": (BUTTER, 0.8, 0.0),
       "thread": (CREAM, 0.8, 0.0), "cord": (CREAM, 0.7, 0.0)}


# ---------------------------------------------------------------------------
# Garments (Feyre space)
# ---------------------------------------------------------------------------
def build(ctx):
    bw, bg, probe, sh = ctx.bw, ctx.bg, ctx.probe, ctx.sh
    rep = []

    # -- shirt + soft cravat
    B = ctx.builder("father_shirt", {**PAL, "fabric": (CREAM, 0.7, 0.0), "cravat": (BUTTER, 0.6, 0.0)})
    hole = bw.neckline(0.02, 0.055, 1.345)
    bm = sh.make(lambda r, c: r in ("torso", "arms") and not hole(c),
                 lambda c: 0.005, [bw.z_below(0.90)] + bw.x_beyond(0.603), max_tris=2600)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.005)
    bw.bind(B, bm, 0.0042, "fabric", where=lambda p: abs(p[0]) > 0.5, squash=1.5, fit=0.005)    # cuffs
    bm.free()
    i0 = len(B.bm.verts)                                    # stand collar wrapped by the cravat
    ring = bw.neck_ring(probe, lambda a: 1.352 + 0.006 * math.cos(a), 0.007, n=36)
    B.tube(ring, 0.0042, 5, "cravat", up=V((0, 0, 1)), squash=2.6, cap=False)
    ring = bw.neck_ring(probe, lambda a: 1.335 + 0.004 * math.cos(a), 0.010, n=36)
    B.tube(ring, 0.0040, 5, "cravat", up=V((0, 0, 1)), squash=2.0, cap=False)
    B.mark("near", i0, fit=0.006)
    i0 = len(B.bm.verts)                                    # the soft knot and its falls
    p, n = probe.on_torso(1.315, 0.0, 0.012)
    B.ellipsoid(p, V((0.014, 0, 0)), n * 0.008, V((0, 0, 0.011)), "cravat", 7, 4)
    for k, (dx, dz, rx, rz, sk) in enumerate(((-0.010, -0.030, 0.013, 0.026, -0.25), (0.009, -0.034, 0.012, 0.028, 0.2),
                                              (0.0, -0.052, 0.011, 0.020, 0.0))):
        q, nq = probe.on_torso(1.315 + dz, math.degrees(math.atan2(dx, 0.08)), 0.010 + 0.002 * k)
        up = V((sk, 0, 1)).normalized()
        side = nq.cross(up).normalized()
        B.ellipsoid(q, side * rx, nq * 0.0045, up * rz, "cravat", 7, 4)
    B.mark("near", i0, fit=0.008)
    rep.append(cc.tris_line(ctx.cloth(B, "father_shirt")))

    # -- waistcoat: faded periwinkle, butter piping, one button gone
    B = ctx.builder("father_waistcoat", {**PAL, "fabric": (PERI, 0.62, 0.0), "trim": (BUTTER, 0.6, 0.0)})

    def vhole(c):
        if c.z > 1.335:
            return True
        return c.y < -0.01 and c.z > 1.15 + 2.3 * abs(c.x)
    bm = sh.make(lambda r, c: r == "torso" and not vhole(c) and c.z > 0.89, lambda c: 0.011,
                 [bw.z_below(0.905)], max_tris=2600)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.011)
    bw.bind(B, bm, 0.0030, "trim", fit=0.011)
    bm.free()
    zs = np.linspace(0.955, 1.135, 5)
    bw.buttons(B, probe, [z for k, z in enumerate(zs) if k != 2], 0.014, r=0.0042, mat="chain")
    i0 = len(B.bm.verts)                                    # the missing one: a frayed thread end
    p, n = probe.on_torso(float(zs[2]), 0.0, 0.0135)
    for dx in (-0.0015, 0.0015):
        B.tube(np.array([p + V((dx, 0, 0)), p + n * 0.004 + V((dx * 2, 0, -0.004)), p + n * 0.006 + V((dx * 3, 0, -0.010))]),
               0.0006, 3, "thread", cap=False)
    for s in (1, -1):                                       # welt pockets
        q, nq = probe.on_torso(1.005, s * 38, 0.0135)
        t = nq.cross(V((0, 0, 1))).normalized()
        B.ellipsoid(q, t * 0.022, nq * 0.002, V((0, 0, 0.0035)), "trim", 6, 3)
    B.mark("near", i0, fit=0.012)
    rep.append(cc.tris_line(ctx.cloth(B, "father_waistcoat")))

    # -- the long coat: open front, turned cuffs, skirts to the knee, patched elbows
    B = ctx.builder("father_coat", PAL)

    def coat_hole(c):
        if c.z > 1.338:
            return True
        w = 0.040 + max(0.0, c.z - 1.10) * 0.26
        return c.y < -0.015 and abs(c.x) < w
    bm = sh.make(lambda r, c: r in ("torso", "arms") and not coat_hole(c),
                 lambda c: 0.017, [bw.z_below(0.895)] + bw.x_beyond(0.588), max_tris=1900)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.017)
    bw.bind(B, bm, 0.0085, "trim", where=lambda p: abs(p[0]) > 0.5, squash=1.7, fit=0.017)       # turned cuffs
    bw.bind(B, bm, 0.0036, "lining", where=lambda p: abs(p[0]) < 0.3, squash=2.2, fit=0.017)      # faced fronts
    bm.free()
    i0 = len(B.bm.verts)                                    # fall-down collar at the back of the neck
    ring = bw.neck_ring(probe, lambda a: 1.338 - 0.010 * math.cos(a), 0.024, n=48)
    arc = np.array([p for p, a in zip(ring, np.linspace(0, 2 * math.pi, len(ring))) if 0.75 < a < 2 * math.pi - 0.75])
    B.tube(arc, 0.0055, 5, "fabric", up=V((0, 0, 1)), squash=2.8, cap=True)
    B.mark("near", i0, fit=0.020)
    rings = open_skirt(B, probe, 0.925, 0.43, 0.075, gap_deg=17, rows=6, cols=32, mats=["fabric"] * 5 + ["trim"],
                       off=0.024, fold=0.03)
    i0 = len(B.bm.verts)                                    # pocket flaps
    for s in (1, -1):
        r = rings[1]
        c = V(r[len(r) // 2 + s * 10])
        out = V((c.x, c.y - 0.01, 0)).normalized()
        side = out.cross(V((0, 0, 1))).normalized()
        B.ellipsoid(c + out * 0.004 - V((0, 0, 0.010)), side * 0.040, out * 0.003, V((0, 0, 0.016)), "trim", 6, 3)
    B.mark("skirt", i0, lmax=0.6)
    i0 = len(B.bm.verts)                                    # tarnished buttons down his left front edge
    for z in (1.02, 1.10, 1.18):
        w = 0.040 + max(0.0, z - 1.10) * 0.26 + 0.012
        loc = probe.bvh.ray_cast(V((w, -0.2, z)), V((0, 1, 0)), 0.4)
        if loc[0] is not None:
            B.ellipsoid(loc[0] + loc[1] * 0.021, V((0.0048, 0, 0)), loc[1] * 0.0022, V((0, 0, 0.0048)), "chain", 6, 3)
    for s in (1, -1):                                       # cuff buttons
        B.ellipsoid(V((s * 0.565, 0.033, 1.286)), V((0.0035, 0, 0)), V((0, 0.0018, 0)), V((0, 0, 0.0035)), "chain", 5, 3)
    B.mark("near", i0, fit=0.019)
    i0 = len(B.bm.verts)                                    # elbow patches: lilac on the left, butter on the right
    for s, mat in ((1, "patch_a"), (-1, "patch_b")):
        hit = probe.bvh.ray_cast(V((s * 0.405, 0.25, 1.287)), V((0, -1, 0)), 0.4)
        if hit[0] is None:
            continue
        c = hit[0] + V((0, 0.0205, 0))
        B.ellipsoid(c, V((0.034, 0, 0)), V((0, 0.0020, 0)), V((0, 0, 0.026)), mat, 8, 4)
        stitch = [c + V((0.036 * math.cos(a), 0.0024, 0.028 * math.sin(a))) for a in np.linspace(0, 2 * math.pi, 15)]
        B.tube(np.array(stitch), 0.0008, 3, "thread", cap=False)
    B.mark("near", i0, fit=0.019)
    rep.append(cc.tris_line(ctx.cloth(B, "father_coat")))

    # -- trousers, darned over the bad right knee
    B = ctx.builder("father_trousers", {**PAL, "fabric": (TAUPE, 0.78, 0.0)})
    bm = sh.make(lambda r, c: r == "legs" or (r == "torso" and c.z < 1.0),
                 lambda c: 0.006 + 0.006 * float(np.clip((0.40 - c.z) / 0.25, 0, 1)),
                 [bw.z_above(0.99), bw.z_below(0.075)], max_tris=3400)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.006)
    bw.bind(B, bm, 0.0035, "fabric", where=lambda p: p[2] < 0.3, squash=1.4)
    bm.free()
    i0 = len(B.bm.verts)
    hit = probe.bvh.ray_cast(V((-0.090, -0.25, 0.47)), V((0, 1, 0)), 0.4)
    if hit[0] is not None:
        c = hit[0] + hit[1] * 0.0085
        B.ellipsoid(c, V((0.028, 0, 0)), hit[1] * 0.002, V((0, 0, 0.034)), "patch_b", 8, 4)
        stitch = [c + hit[1] * 0.0006 + V((0.030 * math.cos(a), 0, 0.036 * math.sin(a))) for a in np.linspace(0, 2 * math.pi, 15)]
        B.tube(np.array(stitch), 0.0008, 3, "thread", cap=False)
    B.mark("near", i0, fit=0.008)
    rep.append(cc.tris_line(ctx.cloth(B, "father_trousers")))

    # -- worn buckled shoes
    B = ctx.builder("father_shoes", {**PAL, "fabric": (SHOE, 0.55, 0.0), "sole": (SOLE, 0.8, 0.0)})
    bm = sh.make(lambda r, c: r == "feet" or (r == "legs" and c.z < 0.10),
                 lambda c: 0.007, [bw.z_above(0.092)], max_tris=2200)
    i0 = len(B.bm.verts)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.007)
    bw.flat_sole(B, i0)
    bw.bind(B, bm, 0.003, "sole", where=lambda p: p[2] > 0.05, fit=0.008)
    bm.free()
    i0 = len(B.bm.verts)
    for s in (1, -1):
        B.ellipsoid(V((s * 0.090, 0.040, 0.010)), V((0.024, 0, 0)), V((0, 0.022, 0)), V((0, 0, 0.010)), "sole", 8, 4)
        hit = probe.bvh.ray_cast(V((s * 0.091, -0.075, 0.20)), V((0, 0, -1)), 0.3)
        if hit[0] is not None:
            c = hit[0] + hit[1] * 0.010
            B.ellipsoid(c, V((0.013, 0, 0)), hit[1] * 0.0025, (hit[1].cross(V((1, 0, 0)))).normalized() * 0.010,
                        "chain", 6, 3)
    B.mark("shell", i0, fit=0.008)
    rep.append(cc.tris_line(ctx.cloth(B, "father_shoes")))

    # -- hair and beard (one mesh; all on the Head bone)
    obj, clear = ctx.hair_style("father_greying", style_greying, HAIR_RGB)
    beard_material(ctx, obj)
    for g in list(obj.vertex_groups):
        obj.vertex_groups.remove(g)
    import sys
    mz = float(sys.modules["feyre_shape"].MOUTH_Z)
    P = ctx.bf.verts_np(obj.data)
    jw = np.clip((mz - 0.004 - P[:, 2]) / 0.018, 0, 1) * (P[:, 1] < 0.0) * np.clip(1.0 - np.abs(P[:, 0]) / 0.075, 0, 1)
    gh, gj = obj.vertex_groups.new(name="Head"), obj.vertex_groups.new(name="Jaw")
    for i, w in enumerate(jw):
        gh.add([i], float(1.0 - w), "REPLACE")
        if w > 0.0:
            gj.add([i], float(w), "REPLACE")
    rep.append(cc.tris_line(obj) + " crown_clear=%.4f" % clear)
    return rep


def open_skirt(B, probe, z0, z1, flare, gap_deg, rows, cols, mats, off, fold):
    """Coat skirts: a lathe open at the front (gap_deg each side of centre), outer cloth + lilac lining."""
    import build_wardrobe as bw
    rx0, ry0, cy0 = 0.0, 0.0, 0.0
    for z in np.linspace(0.85, z0, 5):
        rx, ry, cy = bw.girth(probe, float(z))
        rx0, ry0, cy0 = max(rx0, rx), max(ry0, ry), cy
    gap = math.radians(gap_deg)
    ang = np.linspace(gap, 2 * math.pi - gap, cols)
    outer, inner = [], []
    for k in range(rows):
        s = k / (rows - 1)
        z = z0 + (z1 - z0) * s
        g = gap * (1.0 + 0.9 * s)                      # the fronts fall open toward the hem
        a = np.linspace(g, 2 * math.pi - g, cols)
        rx = rx0 + off + flare * s ** 1.3
        ry = ry0 + off + flare * 0.8 * s ** 1.3
        f = 1.0 + fold * s * np.sin(7 * a + 0.4)
        ring = np.stack([rx * f * np.sin(a), cy0 - ry * f * np.cos(a), np.full(cols, z)], 1)
        outer.append(ring)
        k_in = 1.0 - 0.0035 / max(rx, ry)
        inner.append(np.stack([ring[:, 0] * k_in, (ring[:, 1] - cy0) * k_in + cy0, ring[:, 2]], 1))
    del ang
    i0 = len(B.bm.verts)
    f1 = B.grid(outer, mats, closed=False)
    B.orient(f1, lambda c: V((c.x, c.y - cy0, 0)))
    f2 = B.grid(inner, ["lining"], closed=False)
    B.orient(f2, lambda c: -V((c.x, c.y - cy0, 0)))
    B.mark("skirt", i0, lmax=0.6)
    return outer


# ---------------------------------------------------------------------------
# Hair: receding, thinning, combed back; a short greying beard
# ---------------------------------------------------------------------------
def receding(theta):
    a = np.abs(theta) / math.pi
    return np.interp(a, [0.0, 0.07, 0.15, 0.24, 0.34, 0.44, 0.55, 0.75, 1.0],
                     [1.610, 1.612, 1.622, 1.590, 1.548, 1.522, 1.500, 1.450, 1.432])


def style_greying(st):
    import sdf
    bh = cc.bh()
    st.cap(thick=0.0068, back_extra=0.0045, line=receding)
    part = math.radians(-18)                                # side parting on his right
    for th1, ph1 in [(math.radians(a), math.radians(-4)) for a in np.linspace(110, 250, 9)] + \
            [(math.radians(a), math.radians(6)) for a in (72, 88, -72, -88)]:
        th1 = th1 if th1 <= math.pi else th1 - 2 * math.pi
        j = bh.RNG.uniform(-0.04, 0.04)
        st.skull_lock(part + j, math.radians(66) + j, th1, ph1, 0.0075, 0.0062 * bh.RNG.uniform(0.85, 1.1))
    beard(st, sdf)


def beard(st, sdf):
    import sys
    fs = sys.modules["feyre_shape"]
    X, Y, Z = st.g._coords(tuple(slice(None) for _ in range(3)))
    ax = np.abs(X)
    ztop = np.interp(ax, [0.0, 0.010, 0.020, 0.030, 0.042, 0.055, 0.068, 0.080, 0.090],
                     [1.4625, 1.4630, 1.4590, 1.4520, 1.4530, 1.4590, 1.4700, 1.4880, 1.5050])
    chin = np.clip(1.0 - ax / 0.035, 0, 1) * np.clip((1.43 - Z) / 0.03, 0, 1)
    t = 0.0062 + 0.0060 * chin
    d = st.head.Fb - t
    d = sdf.smax(d, Z - ztop, 0.003)
    d = sdf.smax(d, Y - (0.006 - 0.012 * np.clip((Z - 1.47) / 0.04, 0, 1)), 0.003)   # in front of the ears
    zbot = 1.374 + 0.050 * np.clip((Y + 0.068) / 0.068, 0, 1)
    d = sdf.smax(d, zbot - Z, 0.004)
    MY, MZ = float(fs.MOUTH_Y), float(fs.MOUTH_Z)
    mouth = np.sqrt((X / 0.0215) ** 2 + ((Y - MY) / 0.030) ** 2 + ((Z - (MZ - 0.0015)) / 0.0068) ** 2) - 1.0
    d = sdf.smax(d, -mouth * 0.006, 0.002)
    st.g.F = sdf.smin(st.g.F, d.astype(np.float32), 0.005)


def beard_material(ctx, obj):
    bf = ctx.bf
    me = obj.data
    me.materials.append(bf.make_material("beard", BEARD_RGB, 0.5))
    k = len(me.materials) - 1
    for p in me.polygons:
        c = p.center
        if c.z < 1.488 and c.y < 0.004:
            p.material_index = k


# ---------------------------------------------------------------------------
# After the warp: remember where his left fist closes (warped rest space)
# ---------------------------------------------------------------------------
def after_warp(ctx, W):
    ctx.father_grip = {s: V(W(np.array([[s * 0.700, -0.004, 1.258]]))[0]) for s in (1, -1)}
    return []


# ---------------------------------------------------------------------------
# Clips
# ---------------------------------------------------------------------------
def _fist(fr, side, amt=1.0):
    import feyre_anims as fa
    s = 1.0 if side == "Left" else -1.0
    for k, f in enumerate(fa.FINGERS):
        for j, seg in enumerate(fa.SEGS):
            fr.add(side + f + seg, fa.qy(amt * (62.0 - 4.0 * k) * (1.0 - 0.10 * j)), s)
    fr.add(side + "ThumbMetacarpal", fa.qx(-10.0 * amt), s)
    fr.add(side + "ThumbProximal", fa.qy(20.0 * amt), s)
    fr.add(side + "ThumbDistal", fa.qy(26.0 * amt), s)


def _stoop(fr, amt=1.0, breath=0.0):
    """Rounded upper back, head carried forward and tipped down a little: tired, not hunched in pain."""
    import feyre_anims as fa
    fr.add("Spine", fa.qx(1.5 * amt))
    fr.add("Chest", fa.qx(3.5 * amt - breath * 0.6))
    fr.add("UpperChest", fa.qx(5.0 * amt - breath * 0.8))
    fr.add("Neck", fa.qx(5.0 * amt))
    fr.add("Head", fa.qx(-9.0 * amt))
    for side, s in fa.SIDES:
        fr.add(side + "Shoulder", fa.qz(-5.0 * amt) @ fa.qy(2.0 * amt), s)


def idle_cane_frame(phase):
    import feyre_anims as fa
    fr = fa.idle_frame(phase)
    breath = math.sin(2.0 * math.pi * 2.0 * phase)
    shift = math.sin(2.0 * math.pi * phase)
    fr.hips = V((0.030 + 0.004 * shift, 0.008, -0.036 + 0.003 * breath))
    fr.rot["Hips"] = fa.qz(4.0) @ fa.qy(-3.0 - 0.6 * shift) @ fa.qx(1.0)
    fr.feet["Left"] = fa.FootTarget(V((0.010, -0.005, 0.0)))
    fr.feet["Right"] = fa.FootTarget(V((-0.022, -0.075, 0.0)), 4.0, 0.0)  # bad leg out front, weight off it
    fr.add("Spine", fa.qy(2.5 + 0.5 * shift))          # leaning toward the cane
    _stoop(fr, 1.0, breath)
    fr.add("Head", fa.qz(-3.0 * shift) @ fa.qx(3.0))
    # left arm: hand on the cane at his side, elbow soft, fist closed
    fr.add("LeftUpperArm", fa.qx(-6.0) @ fa.qy(-2.0))
    fr.add("LeftLowerArm", fa.qz(-14.0))
    fr.add("LeftHand", fa.qz(8.0) @ fa.qx(-6.0))
    _fist(fr, "Left")
    fr.add("RightUpperArm", fa.qx(-3.0), -1.0)
    return fr


def limp_gaits():
    import feyre_anims as fa
    base = fa.GAITS[0]
    gl = dataclasses.replace(base, name="walk_limp", speed=1.0, frames=36, duty=0.70, centre=0.035, width=0.096,
                             lift=0.065, release=1.0, strike=12.0, push=-20.0, crouch=0.050, bob=0.010,
                             sway=0.018, yaw=4.0, roll=2.0, lean=6.0, arm=7.0, elbow=18.0, elbow_swing=5.0,
                             trail=0.0, curl=1.0)
    gr = dataclasses.replace(gl, duty=0.56, lift=0.026, strike=4.0, push=-7.0, centre=0.050)
    return gl, gr


R_OFF = 0.56   # right heel strike phase (left at 0): a short, guarded step


def walk_limp_frame(phase, flex=0.0):
    import feyre_anims as fa
    gl, gr = limp_gaits()
    fr = fa.gait_frame(gl, phase)
    u = (phase - R_OFF) % 1.0
    ft = fa.gait_foot(gr, u, -(gr.width - 0.090))
    swing_r = 0.0
    if u >= gr.duty:                                    # stiff-kneed swing: low, swung out round the hip
        w = (u - gr.duty) / (1.0 - gr.duty)
        swing_r = math.sin(math.pi * w)
        ft.pos.x -= 0.026 * swing_r
    fr.feet["Right"] = ft
    stance_r = fa.env(u, 0.0, 0.18, gr.duty) if u < gr.duty else 0.0
    land = fa.env(u, 0.0, 0.10, 0.34) if u < gr.duty else 0.0
    fr.hips += V((0.016 * stance_r, 0.010, 0.016 * swing_r - 0.014 * land))   # hike on the swing, sag on landing
    fr.add("Hips", fa.qy(5.5 * swing_r - 3.0 * land))
    fr.add("Spine", fa.qy(5.0 * stance_r))             # lurch onto the cane while the bad leg bears weight
    fr.add("Chest", fa.qy(3.0 * stance_r) @ fa.qx(2.5 * land))
    _stoop(fr, 1.0)
    fr.add("Head", fa.qx(2.0 * land) @ fa.qy(-3.0 * stance_r))
    # the cane goes forward with the bad leg and takes the weight with it
    cane = math.cos(2.0 * math.pi * (phase - R_OFF + 0.03))
    fr.add("LeftUpperArm", fa.qx(-8.0 * cane - 5.0) @ fa.qy(-2.0))
    fr.add("LeftLowerArm", fa.qz(-20.0 - flex))
    fr.add("LeftHand", fa.qz(8.0) @ fa.qx(-6.0))
    _fist(fr, "Left")
    return fr


SIT_SEAT = 0.42   # low fireside stool, m (warped space)


def sit_carve_frame(phase, rig):
    import feyre_anims as fa
    fr = fa.idle_frame(phase, still=0.5)
    breath = math.sin(2.0 * math.pi * 2.0 * phase)
    hip_z = rig.rest["Hips"].translation.z
    fr.hips = V((0.0, 0.14, SIT_SEAT + 0.05 - hip_z + 0.002 * breath))
    fr.rot["Hips"] = fa.qx(-8.0)
    fr.feet["Left"] = fa.FootTarget(V((0.035, -0.20, 0.0)))
    fr.feet["Right"] = fa.FootTarget(V((-0.040, -0.50, 0.0)), 14.0, 0.0)   # bad leg stretched to the fire
    fr.add("Spine", fa.qx(10.0))
    fr.add("Chest", fa.qx(8.0))
    fr.add("UpperChest", fa.qx(6.0))
    fr.add("Neck", fa.qx(12.0))
    fr.add("Head", fa.qx(12.0))
    whittle = math.sin(2.0 * math.pi * 6.0 * phase)    # six small strokes per loop
    # hands together in the lap: left holds the bird, right draws the knife toward himself
    for side, s in fa.SIDES:
        fr.add(side + "UpperArm", fa.qx(-34.0) @ fa.qz(-8.0), s)
        fr.add(side + "LowerArm", fa.qz(-68.0), s)
    fr.add("RightLowerArm", fa.qz(6.0 * whittle))
    fr.add("RightHand", fa.qx(8.0 * whittle))
    _fist(fr, "Left", 0.7)
    _fist(fr, "Right", 0.9)
    return fr


def extra_clips(ctx):
    import bpy
    import feyre_anims as fa
    arm = ctx.arm
    rig = fa.Rig(arm)
    clips = [("idle_cane", [idle_cane_frame(f / 150) for f in range(150)], True),
             ("sit_carve", [sit_carve_frame(f / 120, rig) for f in range(120)], True)]
    acts = {}
    for name, frames, loop in clips:
        fa.reset_pose(arm)
        acts[name] = fa.key_action(rig, name, frames, loop)
    scn = bpy.context.scene

    def hand_at(act, f, bone):
        arm.animation_data.action = act
        if hasattr(arm.animation_data, "action_slot") and act.slots:
            arm.animation_data.action_slot = act.slots[0]
        scn.frame_set(f)
        bpy.context.view_layer.update()
        return arm.matrix_world @ arm.pose.bones[bone].matrix

    # cane: vertical at his left side in idle_cane frame 0, tip on the floor
    bone = arm.data.bones["LeftHand"]
    grip_local = bone.matrix_local.inverted() @ ctx.father_grip[1]
    Mh = hand_at(acts["idle_cane"], 0, "LeftHand")
    G = Mh @ grip_local
    attach = Mh.inverted() @ Matrix.Translation(G)
    L = G.z
    cane = build_cane(ctx, L)
    # carving pair: placed by sit_carve frame 0 hands
    bl = hand_at(acts["sit_carve"], 0, "LeftHand")
    br = hand_at(acts["sit_carve"], 0, "RightHand")
    gl = bl @ (bone.matrix_local.inverted() @ ctx.father_grip[1])
    gr = br @ (arm.data.bones["RightHand"].matrix_local.inverted() @ ctx.father_grip[-1])
    att_bird = bl.inverted() @ Matrix.Translation(gl)
    att_knife = br.inverted() @ Matrix.Translation(gr) @ Matrix.Rotation(math.radians(-70), 4, "X")
    knife = build_knife(ctx)
    bird = build_bird(ctx)
    # walk_limp: the cane is rigid in the fist, so bend the left elbow frame by frame until the tip
    # stands on the floor while the bad leg bears weight and clears it a little in its swing
    _, gr = limp_gaits()
    target = []
    for f in range(36):
        u = (f / 36 - R_OFF) % 1.0
        target.append(0.0 if u < gr.duty else 0.04 * math.sin(math.pi * (u - gr.duty) / (1.0 - gr.duty)))
    flex = np.zeros(36)
    for it in range(5):
        old = bpy.data.actions.get("walk_limp")
        if old is not None:
            bpy.data.actions.remove(old)
        fa.reset_pose(arm)
        acts["walk_limp"] = fa.key_action(rig, "walk_limp", [walk_limp_frame(f / 36, flex[f]) for f in range(36)], True)
        tips = []
        for f in range(36):
            M = hand_at(acts["walk_limp"], f, "LeftHand") @ attach
            tips.append((M @ V((0, -0.035, -L))).z)
        if it < 4:
            flex = np.clip(flex + np.clip((np.array(target) - np.array(tips)) / 0.0045, -12, 12), -15, 45)
    arm.animation_data.action = None
    fa.reset_pose(arm)
    scn.frame_set(0)
    bpy.context.view_layer.update()
    ctx.father_attach = {"father_cane": ("LeftHand", attach), "father_bird": ("LeftHand", att_bird),
                         "father_knife": ("RightHand", att_knife)}
    for obj, (bn, att) in ((cane, ctx.father_attach["father_cane"]),):
        held = obj.copy()
        held.name = obj.name + "_held"
        scn.collection.objects.link(held)
        held.parent = arm
        held.parent_type = "BONE"
        held.parent_bone = bn
        b = arm.data.bones[bn]
        held.matrix_parent_inverse = Matrix.Identity(4)
        held.matrix_basis = Matrix.Translation(V((0, -b.length, 0))) @ att
    ctx.props += [(cane, "LeftHand", "carved cane, origin = grip, shaft down -Z, bird handle faces -Y"),
                  (knife, "RightHand", "whittling knife, origin = grip, blade down -Z"),
                  (bird, "LeftHand", "half-carved bird, origin = grip, head toward -Y")]
    ctx.father_report = ["cane length %.3f m; walk_limp cane tip z min %.3f max %.3f" % (L, min(tips), max(tips))]
    for n, (bn, att) in ctx.father_attach.items():
        t = att.to_translation()
        q = att.to_quaternion()
        ctx.father_report.append("%s @%s (Blender bone-local, head): t=(%.4f, %.4f, %.4f) q(wxyz)=(%.4f, %.4f, %.4f, %.4f)"
                                 % (n, bn, t.x, t.y, t.z, q.w, q.x, q.y, q.z))
    print("\n".join(ctx.father_report))
    return list(acts)


# ---------------------------------------------------------------------------
# Props (built after the warp: real metres, origin = grip)
# ---------------------------------------------------------------------------
WOOD, WOOD_D, WOOD_L, FRESH = "8C6C50", "6B5040", "B39070", "D9BC92"


def _prop(ctx, B, name):
    obj = ctx.bg.new_object(B, name)
    ctx.bf.ensure_uvs(obj)
    return obj


def build_cane(ctx, L):
    B = ctx.builder("father_cane", {"fabric": (WOOD, 0.55, 0.0), "dark": (WOOD_D, 0.6, 0.0), "light": (WOOD_L, 0.5, 0.0),
                                    "chain": (TARNISH, 0.4, 0.6), "eye": ("2A2220", 0.3, 0.0)})
    rng = np.random.default_rng(1751)
    sx = -0.035                                      # shaft rises in front of the fist
    n = 26
    zs = np.linspace(-0.020, -L + 0.022, n)
    path = np.array([(0.0012 * math.sin(k * 0.9), sx + 0.0012 * math.cos(k * 1.3), z) for k, z in enumerate(zs)])
    rad = np.linspace(0.0118, 0.0098, n) * (1.0 + 0.06 * rng.standard_normal(n).clip(-1.5, 1.5))   # whittled facets
    B.tube(path, rad, 8, "fabric", cap=False)
    for z in (-0.33, -0.61):                          # knots left in the ash
        B.ellipsoid(V((0.009, sx, z)), V((0.004, 0, 0)), V((0, 0.006, 0)), V((0, 0, 0.008)), "dark", 5, 3)
    B.tube(np.array([(0, sx, -L + 0.026), (0, sx, -L + 0.004)]), 0.0102, 8, "chain", cap=True)   # brass ferrule
    B.tube(np.array([(0, sx, -0.040), (0, sx, -0.026)]), 0.0128, 8, "dark", cap=False)           # collar
    for k in range(4):                                # carved leaves round the collar
        a = k * math.pi / 2 + 0.4
        c = V((0.013 * math.cos(a), sx + 0.013 * math.sin(a), -0.050))
        B.leaf(c, V((0, 0, -1)), V((math.cos(a), math.sin(a), 0)), 0.014, 0.006, "light")
    # handle: a little bird, head forward over the shaft, body in the fist, tail behind
    hp = np.array([(0, sx, -0.022), (0, sx + 0.004, -0.004), (0, -0.012, 0.004), (0, 0.012, 0.004), (0, 0.034, 0.000),
                   (0, 0.050, -0.006)])
    hp = ctx.bg.smooth_curve(hp, 16)
    B.tube(hp, np.interp(np.linspace(0, 1, 16), [0, 0.3, 0.7, 1.0], [0.0118, 0.0125, 0.0120, 0.0075]), 8, "fabric")
    head = V((0, sx - 0.006, 0.006))
    B.ellipsoid(head, V((0.0115, 0, 0)), V((0, 0.0135, 0)), V((0, 0, 0.0115)), "light", 8, 5)
    B.ellipsoid(head + V((0, -0.016, -0.001)), V((0.0032, 0, 0)), V((0, 0.0075, 0)), V((0, 0, 0.0028)), "dark", 6, 3)  # beak
    for s in (1, -1):
        B.bead(head + V((s * 0.0105, -0.005, 0.003)), 0.0016, "eye", 5, 3)
        B.leaf(V((s * 0.011, 0.004, 0.004)), V((0, 1, -0.15)), V((s, 0, 0.3)), 0.020, 0.008, "light")   # folded wings
    B.leaf(V((0, 0.056, -0.007)), V((0, 1, -0.35)), V((0, 0, 1)), 0.018, 0.010, "light")             # tail
    return _prop(ctx, B, "father_cane")


def build_knife(ctx):
    B = ctx.builder("father_knife", {"fabric": (WOOD_L, 0.55, 0.0), "blade": ("C4C2C8", 0.28, 0.85),
                                     "chain": (TARNISH, 0.4, 0.6)})
    B.tube(np.array([(0, 0, 0.040), (0, 0, 0.0), (0, 0, -0.040)]), [0.0075, 0.0085, 0.0078], 8, "fabric", squash=0.7)
    B.tube(np.array([(0, 0, -0.040), (0, 0, -0.046)]), 0.0082, 8, "chain", squash=0.7)
    zs = np.linspace(-0.046, -0.098, 6)
    w = np.array([0.0075, 0.0078, 0.0072, 0.0060, 0.0038, 0.0008])
    B.tube(np.stack([np.zeros(6), -w * 0.4, zs], 1), w, 6, "blade", squash=0.16)
    return _prop(ctx, B, "father_knife")


def build_bird(ctx):
    B = ctx.builder("father_bird", {"fabric": (FRESH, 0.6, 0.0), "rough": (WOOD_L, 0.75, 0.0), "dark": (WOOD_D, 0.6, 0.0)})
    # carved front half: head and breast
    B.ellipsoid(V((0, -0.012, 0.004)), V((0.016, 0, 0)), V((0, 0.024, 0)), V((0, 0, 0.017)), "fabric", 10, 6)
    B.ellipsoid(V((0, -0.034, 0.018)), V((0.010, 0, 0)), V((0, 0.011, 0)), V((0, 0, 0.010)), "fabric", 8, 5)
    B.ellipsoid(V((0, -0.047, 0.017)), V((0.0024, 0, 0)), V((0, 0.0060, 0)), V((0, 0, 0.0020)), "dark", 5, 3)
    for s in (1, -1):
        B.leaf(V((s * 0.014, -0.004, 0.008)), V((0, 1, -0.1)), V((s, 0, 0.2)), 0.018, 0.008, "fabric")
    # the back half is still the block: rough-hewn facets
    import bmesh
    from mathutils import Matrix as M
    r = bmesh.ops.create_cube(B.bm, size=1.0, matrix=M.Translation(V((0, 0.020, -0.001))) @ M.Diagonal(V((0.030, 0.034, 0.030, 1.0))))
    idx = B.slot("rough")
    for v in r["verts"]:
        v.co.x += 0.002 * math.sin(v.co.y * 300.0)
        for f in v.link_faces:
            f.material_index = idx
    bmesh.ops.bevel(B.bm, geom=[e for e in B.bm.edges if all(v in r["verts"] for v in e.verts)], offset=0.004,
                    segments=1, affect="EDGES")
    for k in range(3):                                # a few chips still clinging
        B.ellipsoid(V((0.012 - 0.01 * k, 0.040, -0.012 + 0.008 * k)), V((0.004, 0, 0)), V((0, 0.0015, 0)),
                    V((0, 0, 0.003)), "fabric", 4, 2)
    return _prop(ctx, B, "father_bird")
