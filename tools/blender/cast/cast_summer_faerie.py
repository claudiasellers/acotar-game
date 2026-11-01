"""The wounded Summer Court faerie Tamlin carries into the hall (ch 17; keeper, from the text).

Canon [C]: a lesser faerie, "almost as big as Tamlin"; blue skin, gangly limbs,
long pointed ears, long onyx hair (damp, over his face); a long, unearthly face
with a pointed nose and a mouth of sharp teeth; glossy black eyes; spindly blue
fingers, the skin almost leathery; when he trembles "his skin shimmered with
veins of pure gold, iridescent, like a blue butterfly"; his wings torn off to
black velvety stumps at the shoulder blades, cut jagged "as if she'd sawed off
his wings bit by bit", bleeding down his back.  He is not Spring Court: no mask.
[X]: 1.90 m and thin; clothes are not described, so a plain torn sleeveless
shirt of undyed linen, blood-soaked down the back, and loose trousers torn at
the knee; bare feet.  The gold veins are a separate overlay (summer_faerie_veins)
that summer_faerie.gd shimmers while he trembles.  The bloody linen binding
(summer_faerie_binding) is worn once Feyre has bound the stumps.

Clips beyond the cast set: laid_out (face down on the hall table, head turned to
his right, right arm flung past his head with the hand over the table's edge;
shallow, fast breaths) and laid_out_dead (the same, slack, no breath).
"""

import math

import numpy as np
from mathutils import Vector as V

import cast_common as cc

HEIGHT = 1.90
SHAPE = dict(
    eye_r=0.0200, eye_open_up=34.0, eye_open_lo=30.0, eye_tilt=12.0, eye_open_w=66.0,
    cheeks=0.0, cheekbones=1.25, gaunt=0.55, jaw=0.35, jaw_w=0.80, chin=1.05, chin_drop=0.030, chin_point=0.75,
    brow=0.5, nose=1.32, nose_bridge=1.0, lips=0.70, lip_w=1.10, fae_ears=1.35, face_w=0.86, cranium=0.98,
    neck=0.92, adams_apple=0.4,
    bust=0.0, pecs=0.25, ribs=0.92, waist=0.86, belly=0.72, pelvis=0.86, seat=0.55, lats=0.95,
    thigh=0.74, calf=0.80, arm=0.80, forearm=0.80, deltoid=0.85, hand=1.12,
)
WARP = dict(height=HEIGHT, head=1.04, legs=1.10, arm_len=1.10, arm_thick=0.90,
            wx=((0.0, 0.96), (0.45, 0.92), (0.85, 0.90), (1.00, 0.92), (1.15, 1.00), (1.285, 1.04),
                (1.37, 0.98), (1.47, 1.0)),
            wy=((0.0, 0.96), (0.85, 0.90), (1.05, 0.92), (1.25, 0.95), (1.40, 0.98), (1.47, 1.0)))
GAIT = "male"
SKIN_SRGB = "5D86C2"                 # blue, a little leathery
SKIN_LINEAR = cc.srgb(SKIN_SRGB)
IRIS = ((0.010, 0.010, 0.016), (0.020, 0.020, 0.030), (0.06, 0.06, 0.09))   # all glossy black (sclera too, below)
IRIS_FLECKS = 0.0
LASH = 0.55
LASH_LINEAR = cc.srgb("0C0C12")
HAIR_RGB = cc.srgb("0E0E14")         # onyx
BROWS_SRGB = "1E2238"
LIPS_SRGB = "3E4F86"

DEFAULT_OUTFIT = ["summer_faerie_shirt", "summer_faerie_trousers", "summer_faerie_wounds", "summer_faerie_veins"]
DEFAULT_HAIR = "summer_faerie_long"

LINEN, LINEN_D, BLOOD, BLOOD_D, VELVET, RAW, GOLD = "B9B4A6", "8C8778", "6E0C12", "3A060A", "141218", "7A1A22", "F2C95A"
PAL = {"fabric": (LINEN, 0.9, 0.0), "lining": (LINEN_D, 0.9, 0.0), "blood": (BLOOD, 0.35, 0.0),
       "blood_d": (BLOOD_D, 0.30, 0.0), "velvet": (VELVET, 0.95, 0.0), "raw": (RAW, 0.4, 0.0),
       "binding": ("D8D2C2", 0.85, 0.0)}

SB = ((0.085, 1.285), (-0.085, 1.285))   # shoulder blades: (x, z) in Feyre space (back, +y)


def build(ctx):
    rep = []
    rep.append(cc.tris_line(build_shirt(ctx)))
    rep.append(cc.tris_line(build_trousers(ctx)))
    rep.append(cc.tris_line(build_wounds(ctx)))
    rep.append(cc.tris_line(build_binding(ctx)))
    rep.append(cc.tris_line(build_veins(ctx)))
    obj, clear = ctx.hair_style("summer_faerie_long", style_long, HAIR_RGB)
    rep.append(cc.tris_line(obj) + " crown_clear=%.4f" % clear)
    black_eyes()
    return rep


def black_eyes():
    """Glossy black eyes, no white: repaint the baked eye texture almost black with one soft catch-light."""
    import bpy
    for img in bpy.data.images:
        if "iris" not in img.name.lower():
            continue
        w, h = img.size
        if w == 0:
            continue
        px = np.array(img.pixels[:], np.float32).reshape(h, w, 4)
        yy, xx = np.mgrid[0:h, 0:w]
        u = (xx + 0.5) / w * 2 - 1
        v = (yy + 0.5) / h * 2 - 1
        r = np.sqrt(u * u + v * v)
        base = np.array([0.012, 0.012, 0.020]) + np.array([0.02, 0.02, 0.035]) * np.clip(1 - r, 0, 1)[..., None]
        px[..., :3] = base
        hl = np.exp(-(((u + 0.22) ** 2 + (v - 0.26) ** 2) / 0.006))
        px[..., :3] += hl[..., None] * 0.9
        px[..., 3] = 1.0
        img.pixels = px.ravel()
        img.update()
        if img.filepath_raw:
            img.save()
        img.pack()


def _back(c):
    return c.y > 0.02


def build_shirt(ctx):
    bw, probe, sh = ctx.bw, ctx.probe, ctx.sh
    B = ctx.builder("summer_faerie_shirt", PAL)
    hole = bw.neckline(0.075, 0.060, 1.335)
    rng = np.random.default_rng(1717)

    def torn(c):
        # torn open across the shoulder blades round the stumps, ragged hem, armholes cut wide
        if c.z < 0.86 + 0.035 * math.sin(c.x * 61.0) + 0.02 * math.sin(c.x * 23.0 + 1.0):
            return True
        if abs(c.x) > 0.175:
            return True
        if _back(c):
            for x, z in SB:
                if (c.x - x) ** 2 / 0.050 ** 2 + (c.z - z) ** 2 / 0.075 ** 2 < 1.0:
                    return True
        return hole(c)
    bm = sh.make(lambda r, c: r == "torso" and not torn(c), lambda c: 0.0055, [bw.z_below(0.84)], max_tris=2400)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.0055)
    bm.free()
    # soak the back in blood from the stumps down (and a little on the front of the shoulders)
    blood, dark = B.slot("blood"), B.slot("blood_d")
    for f in B.bm.faces:
        c = f.calc_center_median()
        if c.y > 0.0:
            spread = 0.11 + 0.02 * math.sin(c.z * 40.0) + 0.03 * (1.36 - c.z)
            if abs(c.x) < spread + 0.03 * rng.random() and c.z > 0.88:
                f.material_index = dark if c.z > 1.18 else blood
    return ctx.cloth(B, "summer_faerie_shirt")


def build_trousers(ctx):
    bw, sh = ctx.bw, ctx.sh
    B = ctx.builder("summer_faerie_trousers", {**PAL, "fabric": ("5E5A52", 0.9, 0.0)})

    def keep(r, c):
        if not (r == "legs" or (r == "torso" and c.z < 0.99)):
            return False
        # ragged tear over the left knee, frayed hems at the calf
        if c.y < -0.02 and c.x > 0.0 and abs(c.z - 0.48) < 0.035 + 0.01 * math.sin(c.x * 120.0):
            return False
        return c.z > 0.22 + 0.025 * math.sin(c.x * 90.0 + c.y * 40.0)
    bm = sh.make(keep, lambda c: 0.0060, [bw.z_above(0.99), bw.z_below(0.20)], max_tris=3000)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.0060)
    bm.free()
    bw.belt(B, ctx.probe, 0.965, 0.018, "lining", off=0.012, buckle=None)
    return ctx.cloth(B, "summer_faerie_trousers")


def _stump_frame(probe, x, z):
    deg = math.degrees(math.atan2(x, 0.09)) + 180.0
    p, n = probe.on_torso(z, deg, 0.004)
    side = 1.0 if x > 0 else -1.0
    # the wings grew up and out from the blades: the stumps lean that way
    d = (n * 0.75 + V((side * 0.45, 0, 0.55))).normalized()
    return p, n, d


def build_wounds(ctx):
    """The two black velvety stumps (jagged, sawn), raw cut ends, and blood running down his back."""
    bg, probe = ctx.bg, ctx.probe
    rng = np.random.default_rng(1718)
    B = ctx.builder("summer_faerie_wounds", PAL, first="velvet")
    for x, z in SB:
        i0 = len(B.bm.verts)
        p, n, d = _stump_frame(probe, x, z)
        up = V((0, 0, 1))
        a1 = d.cross(up).normalized()
        a2 = d.cross(a1).normalized()
        L = 0.120
        # root: a thick velvet stub flattened like the base of a wing
        path = np.array([tuple(p - d * 0.010 + d * L * t) for t in np.linspace(0, 1, 6)])
        B.tube(path, [0.040, 0.043, 0.040, 0.036, 0.032, 0.029], 10, "velvet", up=a1, squash=1.7)
        tip = p + d * L
        # ragged, sawn end: uneven velvet shards round the rim, raw tissue in the middle
        for k in range(11):
            t = 2 * math.pi * k / 11 + rng.uniform(-0.15, 0.15)
            rim = tip + (a1 * math.cos(t) * 1.7 + a2 * math.sin(t)) * 0.022
            h = rng.uniform(0.006, 0.030)
            B.tube(np.array([tuple(rim - d * 0.006), tuple(rim + d * h * 0.6 + a2 * rng.uniform(-0.004, 0.004)),
                             tuple(rim + d * h)]), [0.0060, 0.0042, 0.0008], 4, "velvet")
        B.ellipsoid(tip + d * 0.002, a1 * 0.030, d * 0.008, a2 * 0.017, "raw", 8, 4)
        for k in range(4):                                   # torn cartilage nubs
            t = rng.uniform(0, 2 * math.pi)
            q = tip + (a1 * math.cos(t) * 1.4 + a2 * math.sin(t)) * 0.010
            B.bead(q + d * 0.006, 0.0042, "blood_d", 4, 3)
        B.ellipsoid(tip + d * 0.004, a1 * 0.018, d * 0.004, a2 * 0.010, "blood", 6, 3)
        B.mark("near", i0, fit=0.012)
        # blood runs from under the stump down the back
        i0 = len(B.bm.verts)
        deg0 = math.degrees(math.atan2(x, 0.09)) + 180.0
        for j in range(4):
            dz = rng.uniform(0.18, 0.40)
            dd = rng.uniform(-9, 9)
            pts = [probe.on_torso(zz, deg0 + dd + 3.0 * math.sin(zz * 30.0 + j), 0.0060)[0]
                   for zz in np.linspace(z - 0.02, z - dz, 10)]
            r0 = rng.uniform(0.0040, 0.0065)
            B.tube(bg.smooth_curve(np.array(pts), 20), np.linspace(r0, r0 * 0.4, 20), 5, "blood", squash=2.8,
                   up=None, cap=True)
        B.mark("shell", i0, fit=0.004)
    return ctx.cloth(B, "summer_faerie_wounds")


def build_binding(ctx):
    """Linen strips bound round the chest under the arms and pads over both stumps, blood soaking through."""
    bg, probe = ctx.bg, ctx.probe
    B = ctx.builder("summer_faerie_binding", PAL, first="binding")
    i0 = len(B.bm.verts)
    for z, tilt in ((1.085, 0.0), (1.130, 0.015), (1.175, -0.02)):
        path = np.array([probe.torso_pt(z + tilt * math.cos(a), a, 0.016) for a in np.append(bg.ANG, bg.ANG[0])])
        B.tube(path, 0.0028, 4, "binding", up=V((0, 0, 1)), squash=5.0, cap=False)
    B.mark("shell", i0, fit=0.016)
    i0 = len(B.bm.verts)
    for x, z in SB:                                          # pads pressed over the stumps
        p, n, d = _stump_frame(probe, x, z)
        a1 = d.cross(V((0, 0, 1))).normalized()
        a2 = d.cross(a1).normalized()
        B.ellipsoid(p + d * 0.060, a1 * 0.058, d * 0.070, a2 * 0.046, "binding", 8, 5)
        B.ellipsoid(p + d * 0.080, a1 * 0.034, d * 0.058, a2 * 0.036, "blood", 7, 4)
    B.mark("near", i0, fit=0.03)
    return ctx.cloth(B, "summer_faerie_binding")


def build_veins(ctx):
    """Fine branching veins of gold just proud of the skin: neck, shoulders, back, arms, the backs of the hands.
    summer_faerie.gd shimmers their emission while he trembles."""
    bg, probe = ctx.bg, ctx.probe
    rng = np.random.default_rng(1719)
    B = ctx.builder("summer_faerie_veins", {"fabric": (GOLD, 0.2, 0.9)})
    i0 = len(B.bm.verts)

    def branch(pts, r):
        if len(pts) >= 3:
            B.tube(bg.smooth_curve(np.array(pts), max(6, len(pts) * 3)), np.linspace(r, r * 0.35, max(6, len(pts) * 3)),
                   4, "fabric", squash=2.5, cap=False)

    # torso: from the sternum and spine outward and down
    for k in range(26):
        deg = rng.uniform(0, 360)
        z0 = rng.uniform(1.16, 1.36)
        pts = []
        for t in np.linspace(0, 1, 7):
            pts.append(tuple(probe.on_torso(z0 - 0.10 * t + 0.01 * math.sin(t * 9 + k),
                                            deg + 14.0 * t * math.sin(k) + 6.0 * math.sin(t * 7 + k), 0.0016)[0]))
        branch(pts, 0.0013)
    # arms (T-pose, along x) and the backs of the hands
    for s in (1, -1):
        for k in range(9):
            x0 = rng.uniform(0.20, 0.50)
            a0 = rng.uniform(0, 2 * math.pi)
            pts = []
            for t in np.linspace(0, 1, 8):
                x = x0 + 0.12 * t
                ra = max(probe.arm_radius(min(x, 0.60))) + 0.0012
                a = a0 + 0.6 * t + 0.25 * math.sin(t * 8 + k)
                pts.append((s * x, 0.004 + math.cos(a) * ra, 1.285 + math.sin(a) * ra))
            branch(pts, 0.0011)
    B.mark("shell", i0, fit=0.002)
    return ctx.cloth(B, "summer_faerie_veins")


# ---------------------------------------------------------------------------
def style_long(st):
    """Long, damp onyx hair, fallen forward: the heavy lengths hang over both shoulders onto his chest (Tamlin
    carried him over his shoulder; on the table it lies round his head), leaving the bleeding back bare; a short
    fall at the nape; strands over his face; the long ears push through."""
    st.cap(thick=0.0085, back_extra=0.004)
    st.cap_locks(math.radians(4), n=26, off=0.0090, r=0.0078, front_sweep=True)
    st.back_mass(1.42, n=9, spread=0.008, r=0.0120, wave=0.002, arc=(140, 220))
    for s in (1, -1):                                        # the long lengths, forward over each shoulder
        for k in range(5):
            th = s * math.radians(62 + 11 * k)
            start = st.head.scalp(th, math.radians(4 + 3 * k), 0.006)
            st.hang(start, start[2] - 1.08 + 0.03 * (k % 2), 0.040, 0.0125, r1=0.0045, wave=0.002, front=True)
    for k, (deg, L) in enumerate(((-30, 0.17), (-40, 0.21))):   # two damp strands fallen over his right cheek
        start = st.head.scalp(math.radians(deg), math.radians(60), 0.006)
        st.hang(start, L, 0.012, 0.0048, r1=0.0018, wave=0.002, front=True)
    cc.tuck_behind_ears(st, depth=1.3)


# ---------------------------------------------------------------------------
# Clips
# ---------------------------------------------------------------------------
def laid_frame(phase, dead=False):
    """Face down on the table (the actor's root carries the lying-down; this is the body on it).
    In the bone frame he is standing: arms and head do the work."""
    import feyre_anims as fa
    fr = fa.Frame()
    breath = 0.0 if dead else math.sin(2.0 * math.pi * 3.0 * phase)      # three quick, shallow breaths per loop
    shiver = 0.0 if dead else math.sin(2.0 * math.pi * 11.0 * phase)
    slack = 1.0 if dead else 0.0
    fr.hips = V((0.0, 0.0, 0.0))
    fr.add("Hips", fa.qx(-2.0))
    for side, _ in fa.SIDES:
        fr.feet[side] = fa.FootTarget(fa.STANCE[side].copy())
    fr.add("Spine", fa.qx(-2.0))
    fr.add("Chest", fa.qx(-1.0 - 1.4 * breath))
    fr.add("UpperChest", fa.qx(-1.5 - 2.0 * breath))
    # head turned to his right (toward Feyre at the table's side), cheek to the table, chin a little down
    fr.add("Neck", fa.qz(-28.0) @ fa.qx(-4.0 - 3.0 * slack))
    fr.add("Head", fa.qz(-52.0 - 0.6 * shiver) @ fa.qy(-8.0 - 4.0 * slack) @ fa.qx(-6.0))
    # right arm flung up past his head, the hand dropping over the table's edge (where she takes it)
    fr.add("RightShoulder", fa.qy(-12.0), -1.0)
    fr.add("RightUpperArm", fa.qx(9.0 + 3.0 * slack) @ fa.qy(-70.0), -1.0)
    fr.add("RightLowerArm", fa.qx(14.0 + 6.0 * slack), -1.0)
    fr.add("RightHand", fa.qx(70.0 + 10.0 * slack), -1.0)
    # left arm along his side, palm up, fingers loosely open
    fr.add("LeftShoulder", fa.qy(4.0))
    fr.add("LeftUpperArm", fa.qy(82.0) @ fa.qx(-4.0))
    fr.add("LeftLowerArm", fa.qz(-6.0) @ fa.qx(-60.0))
    for side, s in fa.SIDES:
        curl = 0.35 if dead else 0.6 + 0.08 * shiver
        for k, f in enumerate(fa.FINGERS):
            for j, seg in enumerate(fa.SEGS):
                fr.add(side + f + seg, fa.qy(curl * (16.0 + 6.0 * k) * (1.0 - 0.2 * j)), s)
        fr.add(side + "ThumbProximal", fa.qy(10.0 * curl), s)
    return fr


def extra_clips(ctx):
    import feyre_anims as fa
    arm = ctx.arm
    rig = fa.Rig(arm)
    clips = [("laid_out", [laid_frame(f / 60) for f in range(60)], True),
             ("laid_out_dead", [laid_frame(0.0, dead=True) for _ in range(2)], False)]
    for name, frames, loop in clips:
        fa.reset_pose(arm)
        fa.key_action(rig, name, frames, loop)
    return [c[0] for c in clips]
