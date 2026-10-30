"""Lucien, emissary of the Spring Court, youngest son of the High Lord of Autumn.

Canon [C]: High Fae (pointed ears); lean, rangy and elegant beside Tamlin;
fine-boned, sharp, handsome, sly; long vivid fire-red hair, sometimes tied;
right eye russet; the left eye a carved golden mechanical orb that moves on
its own, whirs and narrows; a slashing scar from brow to jaw over the left
eye; a bronze fox mask fused over all but the lower half of his face; a
silver tunic; a hunting knife at his belt (he gives it to Feyre).
[X]: 1.85 m, long legs, narrower shoulders than Tamlin; the half-up tie in a
bronze cuff; an autumn russet doublet over the silver tunic with bronze
buttons, a scalloped skirt and leaf epaulettes; the orb's engraved rings and
eight-blade gold iris; the scar gouged across the mask; charcoal trousers,
oxblood riding boots.
"""

import math

import numpy as np
from mathutils import Vector as V

import cast_common as cc

HEIGHT = 1.85
SHAPE = dict(
    eye_r=0.0166, eye_open_up=25.0, eye_open_lo=23.0, eye_tilt=7.0, eye_open_w=62.0,
    cheeks=0.0, cheekbones=1.15, gaunt=0.10, jaw=0.85, jaw_w=0.84, chin=1.25, chin_drop=0.02, brow=0.8,
    nose=1.16, nose_bridge=1.0, lips=0.76, lip_w=1.04, fae_ears=1.0, face_w=0.92, neck=1.07,
    adams_apple=0.5,
    bust=0.0, pecs=0.8, ribs=1.05, waist=1.06, belly=0.82, pelvis=0.90, seat=0.60, lats=1.12,
    thigh=0.86, calf=0.98, arm=1.05, forearm=1.04, deltoid=1.08, hand=1.06,
)
WARP = dict(height=HEIGHT, head=1.04, legs=1.06, arm_len=1.02, arm_thick=1.0,
            wx=((0.0, 1.02), (0.45, 1.00), (0.85, 0.95), (1.00, 1.00), (1.15, 1.10), (1.285, 1.17),
                (1.37, 1.06), (1.47, 1.0)),
            wy=((0.0, 1.0), (0.85, 0.95), (1.05, 1.00), (1.25, 1.03), (1.40, 1.02), (1.47, 1.0)))
GAIT = "male"
SKIN_SRGB = "EEC6A8"                # fair, warm
SKIN_LINEAR = cc.srgb(SKIN_SRGB)
IRIS = ((0.42, 0.12, 0.04), (0.80, 0.38, 0.12), (0.98, 0.62, 0.22))   # russet: outer, inner, amber fleck
IRIS_FLECKS = 0.8
LASH = 0.60
LASH_LINEAR = cc.srgb("5A2214")
HAIR_RGB = cc.srgb("C8280E")        # vivid fire red
BROWS_SRGB = "A8361C"
LIPS_SRGB = "B9786A"

RUSSET, RUSSET_D, SILVER, SILVER_D, BRONZE, BRONZE_L = "6A2416", "4E1A10", "B8BCC6", "8A8F9C", "B57A36", "E0AA5C"
PAL = {"fabric": (RUSSET, 0.48, 0.0), "trim": (BRONZE, 0.30, 0.70), "chain": (BRONZE, 0.26, 0.78),
       "leather": ("6B3F2A", 0.50, 0.0), "leather_d": ("3E2519", 0.45, 0.0),
       "leaf_a": ("D98A2B", 0.40, 0.15), "leaf_b": ("B03A1E", 0.40, 0.10), "leaf_c": ("D9A441", 0.30, 0.55)}
LEAF_MATS = ("leaf_a", "leaf_b", "leaf_c")

# The scar, (x, z) on the face in Feyre space (+x = his left): brow -> through the eye -> jaw.
SCAR = [(0.020, 1.556), (0.026, 1.540), (0.032, 1.524), (0.0375, 1.507), (0.043, 1.490), (0.049, 1.472),
        (0.054, 1.455), (0.058, 1.440), (0.061, 1.426)]


def build(ctx):
    bw, bg, probe, sh = ctx.bw, ctx.bg, ctx.probe, ctx.sh
    rep = []

    # -- silver tunic: long sleeves (the cuffs show past the doublet), high round neck
    B = ctx.builder("lucien_tunic", {"fabric": (SILVER, 0.30, 0.20), "trim": (SILVER_D, 0.28, 0.45)})
    hole = bw.neckline(0.030, 0.056, 1.345)
    bm = sh.make(lambda r, c: r in ("torso", "arms") and not hole(c),
                 lambda c: 0.006, [bw.z_below(0.88)] + bw.x_beyond(0.600), max_tris=3200)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.006)
    bw.bind(B, bm, 0.0028, "trim", where=lambda p: p[2] > 1.2 and abs(p[0]) < 0.2, fit=0.006)
    bw.bind(B, bm, 0.0040, "trim", where=lambda p: abs(p[0]) > 0.5, squash=1.5, fit=0.006)
    bm.free()
    rep.append(cc.tris_line(ctx.cloth(B, "lucien_tunic")))

    # -- russet doublet: deep V over the silver, bronze piping, buttons, scalloped skirt, leaf epaulettes
    B = ctx.builder("lucien_doublet", PAL)

    def vhole(c):
        if c.z > 1.338:
            return True
        return c.y < -0.012 and c.z > 1.165 + 2.2 * abs(c.x)
    bm = sh.make(lambda r, c: r in ("torso", "arms") and not vhole(c),
                 lambda c: 0.013, [bw.z_below(0.93)] + bw.x_beyond(0.555), max_tris=2400)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.013)
    bw.bind(B, bm, 0.0032, "trim", fit=0.013)
    bm.free()
    bw.peplum(B, probe, 0.95, 0.66, 0.080, ["fabric"] * 4 + ["trim"], 5, hem=("scallop", 0.022, 14, 0.5),
              fold=(0.018, 7, 0.0), lmax=0.6, gap=0.036)
    bw.belt(B, probe, 0.958, 0.030, "leather_d", off=0.040)
    bw.buttons(B, probe, np.linspace(1.005, 1.135, 5), 0.0175, r=0.0046, mat="chain")
    i0 = len(B.bm.verts)
    k = 0
    for s in (1, -1):                       # leaves down both lapels of the V
        for z in np.linspace(1.185, 1.30, 4):
            x = (z - 1.165) / 2.2
            p, n = probe.on_torso(z, s * math.degrees(math.atan2(x + 0.006, 0.075)), 0.019)
            B.leaf(p, V((s * 0.35, 0, -1.0)), n, 0.012, 0.0055, LEAF_MATS[k % 3])
            k += 1
        for j, (dx, dz, ang) in enumerate(((0.000, 0.000, -10), (0.020, -0.004, -25), (0.040, -0.010, -38),
                                           (0.010, -0.014, -55), (0.032, -0.022, -60))):
            x = 0.150 + dx                  # epaulette: a fan of autumn leaves over each shoulder
            z = probe.shoulder_z(s * x, 0.004) + 0.018 + dz
            a = math.radians(ang)
            along = V((s * math.cos(a), 0.0, math.sin(a)))
            out = V((s * 0.45, 0.0, 1.0)).normalized()
            B.leaf(V((s * x, 0.004, z)), along, out, 0.032 - 0.002 * j, 0.015, LEAF_MATS[(j + (s > 0)) % 3])
    B.mark("near", i0, fit=0.016)
    rep.append(cc.tris_line(ctx.cloth(B, "lucien_doublet")))

    # -- hunting knife in its sheath on his right hip
    B = ctx.builder("lucien_knife", {**PAL, "fabric": ("3E2519", 0.42, 0.0), "steel": ("C9CDD4", 0.20, 0.9)})
    build_knife(B, ctx)
    rep.append(cc.tris_line(ctx.cloth(B, "lucien_knife")))

    # -- trousers + boots
    B = ctx.builder("lucien_trousers", {**PAL, "fabric": ("34302F", 0.62, 0.0)})
    bm = sh.make(lambda r, c: r == "legs" or (r == "torso" and c.z < 1.0),
                 lambda c: 0.0055, [bw.z_above(0.99), bw.z_below(0.28)], max_tris=3200)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.0055)
    bm.free()
    rep.append(cc.tris_line(ctx.cloth(B, "lucien_trousers")))
    B = ctx.builder("lucien_boots", {**PAL, "fabric": ("3A2019", 0.36, 0.0), "chain": (BRONZE, 0.26, 0.78)})
    bw.build_riding_boots(B, probe, sh, ctx.rng)
    rep.append(cc.tris_line(ctx.cloth(B, "lucien_boots")))

    # -- the fox mask
    B = ctx.builder("lucien_mask", {"fabric": (BRONZE, 0.26, 0.85), "chain": (BRONZE_L, 0.22, 0.85),
                                    "gouge": ("4A2A14", 0.55, 0.5), "cord": ("E8C9A0", 0.35, 0.3)})
    build_mask(B, ctx)
    rep.append(cc.tris_line(ctx.head_piece(B, "lucien_mask")))

    # -- the golden eye (replaces the left eyeball) and the scar, both in the body glb
    orb = build_orb(ctx)
    ctx.model_extra.append(orb)
    rep.append(cc.tris_line(orb))
    scar = build_scar(ctx)
    ctx.model_extra.append(scar)
    rep.append(cc.tris_line(scar))

    # -- hair
    obj, clear = ctx.hair_style("lucien_half_up", style_half_up, HAIR_RGB)
    rep.append(cc.tris_line(obj) + " crown_clear=%.4f" % clear)
    return rep


# ---------------------------------------------------------------------------
def build_knife(B, ctx):
    probe = ctx.probe
    i0 = len(B.bm.verts)
    deg = -78
    p, n = probe.on_torso(0.955, deg, 0.010)
    n = V((n.x, n.y, 0)).normalized()
    t = n.cross(V((0, 0, 1))).normalized()               # along the hip, towards the front
    down = (V((0, 0, -1)) * 0.94 - t * 0.34).normalized()  # raked forward
    top = p + n * 0.046
    # sheath: tapered leather, bronze throat and chape
    pts = np.array([top + down * (0.004 + 0.150 * u) for u in np.linspace(0, 1, 9)])
    B.tube(pts, np.linspace(0.0105, 0.0045, 9), 8, "fabric", up=n, squash=0.42, cap=True)
    B.ellipsoid(top + down * 0.006, t * 0.0125, n * 0.0060, down * 0.006, "chain", 8, 3)
    B.ellipsoid(top + down * 0.152, t * 0.0058, n * 0.0034, down * 0.010, "chain", 6, 3)
    for u in (0.05, 0.09):                               # tooled leaf on the sheath face
        B.leaf(top + down * u + n * 0.0045, down, n, 0.010, 0.0042, "leaf_c")
    # hilt: crossguard, wrapped grip, pommel
    up = -down
    B.ellipsoid(top + up * 0.002, t * 0.019, n * 0.0045, up * 0.0035, "chain", 8, 3)
    grip = np.array([top + up * (0.005 + 0.072 * u) for u in np.linspace(0, 1, 6)])
    B.tube(grip, [0.0050, 0.0056, 0.0058, 0.0056, 0.0052, 0.0050], 8, "leather", cap=False)
    for u in (0.02, 0.036, 0.052):
        B.tube(np.array([top + up * (0.004 + u), top + up * (0.007 + u)]), 0.0062, 8, "chain", cap=False)
    B.bead(top + up * 0.082, 0.0072, "chain", 8, 5)
    B.bead(top + up * 0.082 - n * 0.0062, 0.0026, "leaf_b", 5, 3)  # a garnet in the pommel
    # loop to the belt
    B.ellipsoid(p + n * 0.034 + V((0, 0, 0.000)), t * 0.007, n * 0.010, V((0, 0, 0.016)), "fabric", 6, 3)
    B.mark("near", i0, fit=0.026)


# ---------------------------------------------------------------------------
def build_mask(B, ctx):
    bw, fs = ctx.bw, ctx.fs
    probe = ctx.probe

    def lower(X):
        ax = np.abs(X)        # snout down the nose, up under the eyes, then down to the cheek points
        return np.interp(ax, [0.0, 0.008, 0.018, 0.032, 0.048, 0.066, 0.084, 0.096],
                         [1.474, 1.475, 1.488, 1.484, 1.474, 1.462, 1.470, 1.500])

    def sdf(X, Z):
        d = bw.sd_ellipse(X, Z, 0.0, 1.522, 0.090, 0.050)
        d = np.maximum(d, lower(X) - Z)
        for s in (1, -1):
            # fox ears rising from the brow, swept out
            d = bw.bg_smin(d, bw.sd_tri(X, Z, (s * 0.018, 1.550), (s * 0.080, 1.536), (s * 0.070, 1.606)), 0.006)
            # cheek points
            d = bw.bg_smin(d, bw.sd_tri(X, Z, (s * 0.050, 1.490), (s * 0.090, 1.500), (s * 0.084, 1.452)), 0.005)
        return np.maximum(d, -bw.eye_holes(X, Z))
    bw.mask_sheet(B, probe, sdf, h=0.0040, lift=0.0034)
    i0 = len(B.bm.verts)
    for s in (1, -1):
        c, _ = bw.on_face(probe, s * 0.062, 1.568, 0.0046)        # cream inner ears
        B.ellipsoid(c, V((0.008, 0, 0)), V((0, 0.0014, 0)), V((s * 0.002, 0, 0.016)), "cord", 6, 3)
        bw.face_tube(B, probe, [(s * 0.026, 1.552), (s * 0.046, 1.584), (s * 0.068, 1.602)], 0.0010, 0.0046,
                     "chain", 10)                                  # ear rims
        bw.face_tube(B, probe, [(s * 0.016, 1.530), (s * 0.034, 1.537), (s * 0.052, 1.535), (s * 0.066, 1.522)],
                     0.0012, 0.0046, "chain", 12)                  # brow strokes
        bw.face_tube(B, probe, [(s * 0.058, 1.490), (s * 0.072, 1.484), (s * 0.084, 1.462)], 0.0010, 0.0044,
                     "chain", 8)                                   # cheek fur strokes
    bw.face_tube(B, probe, [(0.0, 1.548), (0.0, 1.520), (0.0, 1.490), (0.0, 1.477)], 0.0011, 0.0046, "chain", 12)
    c, n = bw.on_face(probe, 0.0, 1.477, 0.0050)                  # nose tip of the fox
    B.ellipsoid(c, V((0.0042, 0, 0)), n * 0.0025, V((0, 0, 0.0030)), "gouge", 6, 3)
    B.leaf(bw.on_face(probe, 0.0, 1.556, 0.0050)[0], V((0, 0, 1)), V((0, -1, 0.2)), 0.010, 0.0048, "chain")
    # the scar, gouged through the bronze (skipping the eye hole)
    eh = lambda x, z: bw.sd_ellipse(x, z, fs.EYE_X, fs.EYE_Z + 0.001, 0.0225, 0.0150, math.radians(-6))
    pts = [(x, z) for x, z in sample_scar(60) if eh(x, z) > 0.002 and lower(np.array([x]))[0] + 0.003 < z]
    for seg in split_runs(pts, 0.006):
        if len(seg) >= 3:
            path = np.array([bw.on_face(probe, float(x), float(z), 0.0040)[0] for x, z in seg])
            B.tube(path, taper(len(path), 0.0014), 5, "gouge", squash=0.55, cap=True)
    B.mark("acc", i0)


def sample_scar(n):
    return [tuple(p) for p in cc_smooth(SCAR, n)]


def cc_smooth(ctrl, n):
    import build_gowns as bg
    return bg.smooth_curve(np.array(ctrl), n)


def split_runs(pts, gap):
    runs, cur = [], []
    for p in pts:
        if cur and math.dist(cur[-1], p) > gap:
            runs.append(cur)
            cur = []
        cur.append(p)
    if cur:
        runs.append(cur)
    return runs


def taper(n, r):
    t = np.linspace(0, 1, n)
    return r * (0.35 + 0.65 * np.sin(math.pi * t) ** 0.6)


# ---------------------------------------------------------------------------
def build_orb(ctx):
    """The golden eye: a gold sphere with engraved rings and an eight-blade iris, rigid on LeftEye.
    The left half of `Eyes` is deleted; the orb takes its place."""
    import bmesh
    import bpy
    from mathutils import Matrix
    bf, fs = ctx.bf, ctx.fs
    eyes = bpy.data.objects["Eyes"]
    bm = bmesh.new()
    bm.from_mesh(eyes.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x > 0], context="VERTS")
    bm.to_mesh(eyes.data)
    bm.free()
    eyes.data.update()

    c = V((fs.EYE_X, fs.EYE_Y, fs.EYE_Z))
    R = fs.EYE_R
    f = V((0, -1, 0))                       # gaze
    ux, uz = V((1, 0, 0)), V((0, 0, 1))
    B = ctx.builder("EyeOrb", {"fabric": ("E8B44C", 0.18, 1.0), "engrave": ("8A5A1E", 0.35, 1.0),
                               "blade": ("F2CC6A", 0.14, 1.0), "pupil": ("120A06", 0.25, 0.2),
                               "glint": ("FFD27A", 0.20, 0.6)})
    bmesh.ops.create_uvsphere(B.bm, u_segments=22, v_segments=12, radius=R * 0.995,
                              matrix=Matrix.Translation(c) @ Matrix.Rotation(math.radians(90), 4, "X"))
    for fc in B.bm.faces:
        fc.material_index = B.slot("fabric")

    def on(theta, phi, lift=0.0):           # theta from the gaze axis, phi around it
        d = f * math.cos(theta) + (ux * math.cos(phi) + uz * math.sin(phi)) * math.sin(theta)
        return c + d * (R + lift), d
    for th in (0.50, 0.68, 0.86):           # engraved concentric rings
        ring = np.array([tuple(on(th, 2 * math.pi * k / 40, 0.0002)[0]) for k in range(41)])
        B.tube(ring, 0.00045, 4, "engrave", cap=False)
    for k in range(12):                     # tick marks between the outer rings, like a dial
        a = 2 * math.pi * k / 12
        p0, d = on(0.73, a, 0.0003)
        p1, _ = on(0.81, a, 0.0003)
        B.tube(np.array([tuple(p0), tuple(p1)]), 0.00035, 4, "engrave", cap=False)
    # dark aperture well, then eight overlapping gold blades leaving a narrow pupil
    pc, _ = on(0.0, 0.0, 0.0001)
    B.ellipsoid(pc, ux * R * 0.40, f * R * 0.06, uz * R * 0.40, "pupil", 12, 4)
    for k in range(8):
        a = 2 * math.pi * k / 8
        radial = ux * math.cos(a) + uz * math.sin(a)
        tang = ux * -math.sin(a) + uz * math.cos(a)
        mid = c + f * (R + 0.0003 + 0.00008 * k) + radial * R * 0.25 + tang * R * 0.06
        along = (tang * 0.85 + radial * 0.53).normalized()
        B.ellipsoid(mid, along * R * 0.25, f * R * 0.025, along.cross(f).normalized() * R * 0.085, "blade", 6, 3)
    p, _ = on(0.30, math.radians(120), 0.0006)  # a hot glint on the rim of the aperture
    B.bead(p, R * 0.05, "glint", 4, 2)
    B.mark("acc", 0)
    obj = bg_new(ctx, B, "EyeOrb")
    g = obj.vertex_groups.new(name="LeftEye")
    g.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    bf.skin_to_armature(obj, ctx.arm)
    bf.ensure_uvs(obj)
    return obj


def bg_new(ctx, B, name):
    obj = ctx.bg.new_object(B, name)
    obj.name = obj.data.name = name
    return obj


# ---------------------------------------------------------------------------
def build_scar(ctx):
    """A raised pink ridge from brow to jaw over his left eye, broken across the eye opening.
    Weights and shape keys follow the body under it (Head above the mouth line, Jaw below)."""
    import bpy
    bf, bw, fs, probe = ctx.bf, ctx.bw, ctx.fs, ctx.probe
    B = ctx.builder("Scar", {"fabric": ("D98E86", 0.42, 0.0), "pale": ("F0B4A8", 0.50, 0.0)})
    gapz = (fs.EYE_Z - 0.0135, fs.EYE_Z + 0.0150)
    pts = [(x, z) for x, z in sample_scar(70) if not (gapz[0] < z < gapz[1])]
    for seg in split_runs(pts, 0.006):
        if len(seg) < 3:
            continue
        path = np.array([bw.on_face(probe, float(x), float(z), 0.0003)[0] for x, z in seg])
        B.tube(path, taper(len(path), 0.0017), 6, "fabric", squash=0.5, cap=True)
        if len(seg) > 8:                    # a paler healed nick crossing it
            m = len(seg) // 2
            x, z = seg[m]
            nick = np.array([bw.on_face(probe, x + dx, z + dz, 0.0006)[0]
                             for dx, dz in ((-0.004, -0.002), (0.0, 0.0), (0.004, 0.002))])
            B.tube(nick, [0.0005, 0.0008, 0.0005], 4, "pale", cap=True)
    obj = bg_new(ctx, B, "Scar")
    P = bf.verts_np(obj.data)
    w, nn = bf.transfer_weights(probe.body, probe.P, P)
    bf.apply_weights(obj, w)
    bf.skin_to_armature(obj, ctx.arm)
    keys = probe.body.data.shape_keys.key_blocks
    obj.shape_key_add(name="Basis", from_mix=False)
    for kb in keys[1:]:
        a = np.empty(len(kb.data) * 3)
        kb.data.foreach_get("co", a)
        D = a.reshape(-1, 3) - probe.P
        d = np.array([sum(D[j] * fw for j, fw in lst) for lst in nn])
        if np.abs(d).max() < 1e-6:
            continue
        sk = obj.shape_key_add(name=kb.name, from_mix=False)
        sk.data.foreach_set("co", (P + d).ravel())
        sk.value = 0.0
    bf.ensure_uvs(obj)
    del bpy
    return obj


# ---------------------------------------------------------------------------
def lucien_hairline(theta):
    """Feyre's hairline lifted at the front: swept back off the mask's fox ears."""
    a = np.abs(theta) / math.pi
    return np.interp(a, [0.0, 0.14, 0.28, 0.42, 0.55, 0.75, 1.0], [1.612, 1.604, 1.568, 1.522, 1.492, 1.445, 1.425])


def style_half_up(st):
    import sdf
    bh = cc.bh()
    bh.RIBBON_RGB = cc.srgb(BRONZE)          # the tie is a bronze cuff
    st.cap(thick=0.0065, back_extra=0.004, line=lucien_hairline)
    st.cap_locks(math.radians(-14), n=22, off=0.0085, r=0.0075, front_sweep=False)
    tie = np.array([0.0, 0.112, 1.545])
    for s in (1, -1):                        # the top half swept back from the temples to the tie
        for k, (ph0, th0) in enumerate(((52, 32), (38, 52), (24, 70))):
            pts = [st.head.scalp(s * math.radians(th0 + (172 - th0) * t),
                                 math.radians(ph0 + (30 - ph0) * t) + math.radians(6) * math.sin(math.pi * t),
                                 0.011 + 0.003 * t) for t in np.linspace(0, 0.88, 9)]
            pts.append(tie + np.array([s * 0.006, 0.0, 0.0]))
            st.lock(pts, 0.0095 - 0.0008 * k, 0.0065)
    st.back_mass(1.16, n=17, spread=0.020, r=0.0145, wave=0.004, arc=(112, 248))       # loose lengths past the shoulders
    for s in (1, -1):                        # a long lock either side, in front of the shoulder
        start = st.head.scalp(s * math.radians(80), math.radians(4), 0.006)
        st.hang(start, start[2] - 1.22, 0.018, 0.0110, r1=0.0050, wave=0.003, front=True)
    st.tie(tie, (0, 1.0, -0.25), 0.0105)
    tail = [tie + np.array([0, 0.008, 0.0]), tie + np.array([0.0, 0.030, -0.04]),
            tie + np.array([0.004, 0.036, -0.12]), tie + np.array([-0.004, 0.034, -0.20])]
    st.lock(tail, 0.0110, 0.0045, k=0.006)   # the tied tail over the loose hair
    for s in (1, -1):                        # keep the fox ears of the mask out of the hairline
        st.g.subtract(sdf.ellipsoid((s * 0.062, -0.066, 1.598), (0.030, 0.032, 0.030)), 0.004)
    cc.tuck_behind_ears(st)
