"""Tamlin, High Lord of the Spring Court (lore/03-characters/tamlin.md).

Canon [C]: tall, broad, powerfully built warrior; light golden hair worn loose
to the shoulders; green eyes with amber flecks; high cheekbones, straight
nose, broad brow; a gold mask set with leaf-shaped emeralds fused over brow,
nose and cheeks (jaw and mouth bare: his expression lives there); plain dark
green tunic with a leather baldric across the chest; retractable claws.
[X]: 1.93 m; gold thread at neck and cuffs; tan trousers, riding boots.
"""

import math

import numpy as np
from mathutils import Vector as V

import cast_common as cc

HEIGHT = 1.93
SHAPE = dict(
    eye_r=0.0168, eye_open_up=27.0, eye_open_lo=25.0, eye_tilt=3.0, eye_open_w=62.0,
    cheeks=0.0, cheekbones=1.0, jaw=0.9, jaw_w=0.86, chin=1.3, chin_drop=0.022, brow=1.0,
    nose=1.22, nose_bridge=1.0, lips=0.80, lip_w=1.05, fae_ears=1.0, face_w=0.94, neck=1.12,
    adams_apple=0.6,
    bust=0.0, pecs=1.0, ribs=1.12, waist=1.14, belly=0.85, pelvis=0.92, seat=0.62, lats=1.35,
    thigh=0.90, calf=1.05, arm=1.12, forearm=1.10, deltoid=1.22, hand=1.10,
)
WARP = dict(height=HEIGHT, head=1.07, legs=1.0, arm_len=1.0, arm_thick=1.04,
            wx=((0.0, 1.10), (0.45, 1.08), (0.85, 1.00), (1.00, 1.06), (1.15, 1.20), (1.285, 1.30),
                (1.37, 1.12), (1.47, 1.0)),
            wy=((0.0, 1.0), (0.85, 0.98), (1.05, 1.06), (1.25, 1.10), (1.40, 1.04), (1.47, 1.0)))
GAIT = "male"
SKIN_LINEAR = (0.74, 0.50, 0.36)
SKIN_SRGB = "E6B795"
IRIS = ((0.10, 0.36, 0.16), (0.42, 0.62, 0.22), (0.80, 0.55, 0.16))   # outer, inner, amber fleck
IRIS_FLECKS = 1.0
LASH = 0.55
LASH_LINEAR = cc.srgb("6E5232")
HAIR_RGB = cc.srgb("DCAA45")       # light gold with wheat and honey
BROWS_SRGB = "9C7A3E"

GREEN, GREEN_D, TAN, GOLD, EMERALD = "3E7457", "2C5A42", "A88E70", "D4A94F", "2EB872"
PAL = {"fabric": (GREEN, 0.62, 0.0), "trim": (GOLD, 0.30, 0.6), "leather": ("7A5440", 0.5, 0.0),
       "leather_d": ("5C3E30", 0.45, 0.0), "chain": (GOLD, 0.28, 0.7)}


def build(ctx):
    bw, bg, probe, sh = ctx.bw, ctx.bg, ctx.probe, ctx.sh
    rep = []
    # -- tunic: long sleeves, gold thread at the open neck and cuffs, hem to mid-thigh
    B = ctx.builder("tamlin_tunic", PAL)
    hole = bw.neckline(0.075, 0.055, 1.335)
    bm = sh.make(lambda r, c: r in ("torso", "arms") and not hole(c),
                 lambda c: 0.0065, [bw.z_below(0.90)] + bw.x_beyond(0.585), max_tris=3200)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.0065)
    bw.bind(B, bm, 0.0030, "trim", where=lambda p: p[2] > 1.15 and abs(p[0]) < 0.2, fit=0.0065)
    bw.bind(B, bm, 0.0045, "fabric", where=lambda p: abs(p[0]) > 0.5, squash=1.6, fit=0.0065)
    bm.free()
    bw.peplum(B, probe, 0.95, 0.66, 0.075, ["fabric"] * 4 + ["trim"], 6, fold=(0.025, 6, 0.0), lmax=0.6,
              gap=0.020)
    i0 = len(B.bm.verts)                                    # laced V at the throat
    pts = [probe.on_torso(z, 5.0 if k % 2 else -5.0, 0.010)[0] for k, z in enumerate(np.linspace(1.25, 1.32, 6))]
    B.tube(bg.smooth_curve(np.array(pts), 24), 0.0013, 4, "leather", cap=False)
    B.mark("near", i0, fit=0.008)
    bw.belt(B, probe, 0.965, 0.034, "leather_d", off=0.016)
    rep.append(cc.tris_line(ctx.cloth(B, "tamlin_tunic")))

    # -- baldric: across the chest from his right shoulder to his left hip, gold buckle
    B = ctx.builder("tamlin_baldric", PAL, first="leather_d")
    path = []
    for t in np.linspace(0.0, 1.0, 22):
        # front: right shoulder (deg -60, z 1.31) down to left hip (deg +70, z 0.97); back mirrored
        z = 1.315 + (0.975 - 1.315) * t
        deg = -62 + 132 * t
        path.append(probe.on_torso(z, deg, 0.020)[0])
    for t in np.linspace(0.0, 1.0, 22)[1:]:
        z = 0.975 + (1.315 - 0.975) * t
        deg = 70 + 168 * t
        path.append(probe.on_torso(z, deg, 0.020)[0])
    path.append(path[0])
    i0 = len(B.bm.verts)
    B.tube(bg.smooth_curve(np.array(path), 90), 0.0026, 6, "leather_d", squash=8.0, cap=False)
    p, n = probe.on_torso(1.16, -8, 0.026)
    t = (V((0.62, 0, -0.78))).normalized()
    B.ellipsoid(p, t * 0.020, n * 0.004, n.cross(t).normalized() * 0.024, "chain", 8, 3)
    B.ellipsoid(p + n * 0.003, t * 0.010, n * 0.003, n.cross(t).normalized() * 0.012, "leather", 6, 3)
    B.mark("shell", i0, fit=0.016)
    i0 = len(B.bm.verts)                                    # sword frog on the left hip
    p, n = probe.on_torso(0.93, 82, 0.034)
    B.ellipsoid(p, V((0, 0.018, 0)), n * 0.010, V((0, 0, 0.045)), "leather_d", 8, 4)
    B.mark("shell", i0, fit=0.03)
    rep.append(cc.tris_line(ctx.cloth(B, "tamlin_baldric")))

    # -- trousers + riding boots
    B = ctx.builder("tamlin_trousers", {**PAL, "fabric": (TAN, 0.75, 0.0)})
    bm = sh.make(lambda r, c: r == "legs" or (r == "torso" and c.z < 1.0),
                 lambda c: 0.0055, [bw.z_above(0.84), bw.z_below(0.28)], max_tris=3200)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.0055)
    bm.free()
    rep.append(cc.tris_line(ctx.cloth(B, "tamlin_trousers")))
    B = ctx.builder("tamlin_boots", {**PAL, "fabric": ("6A4A3C", 0.45, 0.0)})
    bw.build_riding_boots(B, probe, sh, ctx.rng)
    rep.append(cc.tris_line(ctx.cloth(B, "tamlin_boots")))

    # -- the mask
    B = ctx.builder("tamlin_mask", {"fabric": (GOLD, 0.24, 0.85), "gem": (EMERALD, 0.06, 0.1),
                                    "chain": ("F2D27A", 0.25, 0.8)})
    build_mask(B, ctx)
    rep.append(cc.tris_line(ctx.head_piece(B, "tamlin_mask")))

    # -- claws (in the body glb; shape key claws_out)
    claws = cc.build_claws(ctx, length=0.034, curve=0.55)
    ctx.model_extra.append(claws)
    rep.append(cc.tris_line(claws))

    # -- hair
    obj, clear = ctx.hair_style("tamlin_loose", style_loose, HAIR_RGB)
    rep.append(cc.tris_line(obj) + " crown_clear=%.4f" % clear)
    return rep


# ---------------------------------------------------------------------------
LEAVES = [  # (x, z) base, direction (deg from +x, ccw), length, width: a wreath of leaves
    ((0.0, 1.575), 90, 0.030, 0.0105), ((0.022, 1.572), 72, 0.028, 0.0095), ((-0.022, 1.572), 108, 0.028, 0.0095),
    ((0.044, 1.563), 52, 0.027, 0.0092), ((-0.044, 1.563), 128, 0.027, 0.0092),
    ((0.064, 1.548), 30, 0.025, 0.0090), ((-0.064, 1.548), 150, 0.025, 0.0090),
    ((0.078, 1.522), 8, 0.022, 0.0085), ((-0.078, 1.522), 172, 0.022, 0.0085),
    ((0.070, 1.488), -22, 0.022, 0.0085), ((-0.070, 1.488), -158, 0.022, 0.0085),
]


def build_mask(B, ctx):
    bw, fs = ctx.bw, ctx.fs
    sdl = bw.sd_leaf

    def lower(X):
        ax = np.abs(X)
        return np.interp(ax, [0.0, 0.010, 0.024, 0.040, 0.060, 0.080, 0.095],
                         [1.462, 1.463, 1.484, 1.478, 1.468, 1.476, 1.500])

    def sdf(X, Z):
        d = bw.sd_ellipse(X, Z, 0.0, 1.528, 0.088, 0.060)
        d = np.maximum(d, lower(X) - Z)
        for (x, z), ang, L, w in LEAVES:
            a = np.array([x, z])
            b = a + L * np.array([math.cos(math.radians(ang)), math.sin(math.radians(ang))])
            d = bw.bg_smin(d, sdl(X, Z, tuple(a - 0.35 * (b - a)), tuple(b), w), 0.004)
        return np.maximum(d, -bw.eye_holes(X, Z))
    bw.mask_sheet(B, ctx.probe, sdf, h=0.0040, lift=0.0032)
    i0 = len(B.bm.verts)
    for (x, z), ang, L, w in LEAVES:                         # emerald leaves on the wreath points
        a = np.array([x, z])
        dirv = np.array([math.cos(math.radians(ang)), math.sin(math.radians(ang))])
        c2 = a + dirv * L * 0.35
        c, n = bw.on_face(ctx.probe, float(c2[0]), float(c2[1]), 0.0052)
        tip, _ = bw.on_face(ctx.probe, float(c2[0] + dirv[0] * 0.01), float(c2[1] + dirv[1] * 0.01), 0.0052)
        B.leaf(c, tip - c, n, L * 0.5, w * 0.68, "gem")
        bw.face_tube(B, ctx.probe, [tuple(a), tuple(a + dirv * L * 0.75)], 0.0008, 0.0047, "chain", 6)
    for s in (1, -1):                                        # gold brow scrolls over each eye
        bw.face_tube(B, ctx.probe, [(s * 0.012, 1.528), (s * 0.030, 1.537), (s * 0.050, 1.535), (s * 0.062, 1.524)],
                     0.0012, 0.0044, "chain", 12)
        c, n = bw.on_face(ctx.probe, s * 0.050, 1.478, 0.0052)      # cheek emeralds
        B.leaf(c, V((s * 0.8, 0, -0.6)), n, 0.011, 0.0045, "gem")
    c, n = bw.on_face(ctx.probe, 0.0, 1.535, 0.0056)                # centre stone between the brows
    B.leaf(c, V((0, 0, 1)), n, 0.012, 0.006, "gem")
    B.mark("acc", i0)


# ---------------------------------------------------------------------------
def style_loose(st):
    bh = cc.bh()
    st.cap(thick=0.009, back_extra=0.006)
    st.cap_locks(math.radians(6), n=24, off=0.011, r=0.0088, front_sweep=True)
    for s in (1, -1):                                        # swept back off the mask at the temples
        st.skull_lock(s * math.radians(10), math.radians(62), s * math.radians(75), math.radians(16), 0.012, 0.0085,
                      n=11, sag=math.radians(4))
    st.back_mass(1.315, n=14, spread=0.040, r=0.016, wave=0.004)
    st.front_locks(1.335, n=1, r=0.011, wave=0.003)
    cc.tuck_behind_ears(st)
    del bh
