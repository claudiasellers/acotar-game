"""Alis, Feyre's attendant at the manor (lore/03-characters/alis.md).

Canon [C], as Feyre first sees her under Tamlin's glamour: a rotund,
brown-haired woman in a simple brass bird mask, a white apron over a brown
dress; brisk, practical, kind under the gruffness; a lesser faerie of the
Summer Court.  (Her true form, bark skin and wild hair, is a later piece.)
[X]: 1.60 m, round and solid (full bust, belly and hips, soft round face and
cheeks, plump forearms); brown hair in a tidy working bun; warm brown eyes.
Dress: plain brown wool, high round neck, long sleeves pushed a little up the
forearm with turned-back cuffs, a full skirt to the ankle.  Apron: white
linen, a bib pinned at the chest, the skirt to below the knee with a deep
pocket, ties in a bow at the back.  Mask: brass, over brow, eyes and nose,
shaped like a small bird's face: swept feather lobes at the temples, engraved
feather lines, a short hooked beak over the nose.  Plain brown shoes.
"""

import math

import numpy as np
from mathutils import Vector as V

import cast_common as cc

HEIGHT = 1.60
SHAPE = dict(
    eye_r=0.0186, eye_open_up=33.0, eye_open_lo=29.0, eye_tilt=2.0, eye_open_w=63.0,
    cheeks=1.40, cheekbones=0.0, jaw=0.0, jaw_w=1.12, chin=1.18, chin_drop=0.004, chin_point=0.0,
    brow=0.2, nose=1.06, nose_bridge=0.0, lips=1.00, lip_w=1.02, face_w=1.10, cranium=1.02, neck=1.16,
    bust=1.30, ribs=1.16, waist=1.36, belly=1.45, pelvis=1.16, seat=1.22,
    thigh=1.20, calf=1.10, arm=1.20, forearm=1.15, deltoid=1.10, hand=1.04,
)
WARP = dict(height=HEIGHT, head=1.02, legs=0.95, arm_len=0.97, arm_thick=1.08,
            wx=((0.0, 1.06), (0.45, 1.10), (0.85, 1.16), (1.00, 1.18), (1.15, 1.14), (1.28, 1.08), (1.47, 1.0)),
            wy=((0.0, 1.04), (0.85, 1.10), (1.00, 1.16), (1.15, 1.12), (1.30, 1.04), (1.47, 1.0)))
GAIT = "female"
SKIN_LINEAR = (0.74, 0.49, 0.37)        # warm, ruddy, outdoorsy
SKIN_SRGB = "E2B79C"
IRIS = ((0.11, 0.065, 0.03), (0.33, 0.20, 0.09), (0.55, 0.38, 0.15))   # warm brown
IRIS_FLECKS = 0.4
LASH = 0.85
LASH_LINEAR = cc.srgb("2E2018")
HAIR_RGB = cc.srgb("6B4A30")            # plain mid brown
BROWS_SRGB = "5A3E28"
LIPS_SRGB = "B07468"

DEFAULT_OUTFIT = ["alis_dress", "alis_apron", "alis_shoes", "alis_mask"]
DEFAULT_HAIR = "alis_bun"

BROWN, BROWN_D, LINEN, LINEN_D, BRASS, BRASS_L = "7A5638", "5E4029", "F6F1E6", "E4DCCB", "C29A48", "E2C277"
PAL = {"fabric": (BROWN, 0.85, 0.0), "lining": (BROWN_D, 0.85, 0.0), "apron": (LINEN, 0.75, 0.0),
       "apron_d": (LINEN_D, 0.8, 0.0), "cord": (LINEN_D, 0.8, 0.0), "chain": (BRASS, 0.35, 0.8)}


def build(ctx):
    rep = []
    rep.append(cc.tris_line(build_dress(ctx)))
    rep.append(cc.tris_line(build_apron(ctx)))
    B = ctx.builder("alis_shoes", {"fabric": ("4E3626", 0.55, 0.0), "lining": ("3C2A1E", 0.6, 0.0)})
    ctx.bw.build_slippers(B, ctx.probe, ctx.sh, ctx.rng)
    rep.append(cc.tris_line(ctx.cloth(B, "alis_shoes")))
    B = ctx.builder("alis_mask", {"fabric": (BRASS, 0.30, 0.85), "chain": (BRASS_L, 0.25, 0.85),
                                  "gem": ("3A2A1A", 0.2, 0.3)})
    build_mask(B, ctx)
    rep.append(cc.tris_line(ctx.head_piece(B, "alis_mask")))
    obj, clear = ctx.hair_style("alis_bun", style_bun, HAIR_RGB)
    rep.append(cc.tris_line(obj) + " crown_clear=%.4f" % clear)
    return rep


# ---------------------------------------------------------------------------
def build_dress(ctx):
    bw, bg, probe, sh = ctx.bw, ctx.bg, ctx.probe, ctx.sh
    B = ctx.builder("alis_dress", PAL)
    # bodice and long sleeves (pushed up a little: they stop above the wrist), high round neck
    hole = bw.neckline(0.030, 0.058, 1.345)
    bm = sh.make(lambda r, c: r in ("torso", "arms") and not hole(c),
                 lambda c: 0.0060, [bw.z_below(0.94)] + bw.x_beyond(0.545), max_tris=2600)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.0060)
    bw.bind(B, bm, 0.0055, "lining", where=lambda p: abs(p[0]) > 0.5, squash=2.2, fit=0.0060)  # turned-back cuffs
    bw.bind(B, bm, 0.0022, "lining", where=lambda p: p[2] > 1.25 and abs(p[0]) < 0.2, fit=0.0060)  # neck binding
    bm.free()
    bw.buttons(B, probe, np.linspace(1.17, 1.30, 4), 0.0085, r=0.0034, mat="lining")
    # full skirt to the ankle
    W = np.array([probe.torso_pt(0.975, a, 0.0080) for a in bg.ANG])
    hx, hy, hc = bw.girth(probe, 0.88)
    ctrl = [(0.93, hx + 0.020, hy + 0.020, hc), (0.75, hx + 0.050, hy + 0.050, hc + 0.004),
            (0.50, hx + 0.085, hy + 0.085, hc + 0.010), (0.25, hx + 0.115, hy + 0.115, hc + 0.016),
            (0.075, hx + 0.135, hy + 0.135, hc + 0.020)]
    bg.skirt(B, ctrl, 8, bg.rows(8, "fabric", "lining"), waist=W, fold=(0.040, 9, 0.0), lmax=0.75)
    ctx._skirt = bg.Profile(ctrl)
    return ctx.cloth(B, "alis_dress")


def build_apron(ctx):
    """White linen bib apron: bib pinned at the chest, skirt to below the knee with a pocket, waist ties
    in a bow at the back, neck strap."""
    bw, bg, probe = ctx.bw, ctx.bg, ctx.probe
    base = ctx._skirt
    B = ctx.builder("alis_apron", PAL, first="apron")
    i0 = len(B.bm.verts)
    # bib: a panel on the chest from the waist to just under the neckline
    A = np.radians(np.linspace(-34, 34, 11))
    rows_ = []
    for z in np.linspace(0.985, 1.255, 7):
        w = 1.0 - 0.18 * (z - 0.985) / 0.27
        rows_.append(np.array([tuple(probe.torso_pt(z, a * w, 0.0150)) for a in A]))
    f = B.grid(rows_, ["apron"], closed=False)
    B.orient(f, lambda c: V((c.x, c.y - 0.01, 0)))
    B.tube(rows_[-1], 0.0016, 4, "apron_d", cap=False)
    for col in (0, -1):
        B.tube(np.array([r[col] for r in rows_]), 0.0016, 4, "apron_d", cap=False)
    for col in (0, -1):                                    # brass pins at the bib's corners
        p = V(rows_[-1][col])
        B.bead(p + V((0, -0.003, -0.004)), 0.0030, "chain", 5, 3)
    B.mark("shell", i0, fit=0.012)
    # neck strap from the bib corners round the back of the neck
    i0 = len(B.bm.verts)
    l, r = V(rows_[-1][0]), V(rows_[-1][-1])
    back = V((0, 0.060, 1.360))
    for p in (l, r):
        s = 1 if p.x > 0 else -1
        mid = V((s * 0.075, 0.020, 1.352))
        B.tube(bg.smooth_curve(np.array([tuple(p), tuple(mid), tuple(back)]), 10), 0.0022, 4, "apron",
               squash=2.5, cap=False)
    B.mark("shell", i0, fit=0.012)
    # apron skirt over the dress, front and sides, to below the knee
    i0 = len(B.bm.verts)
    ncol = 18
    A = np.radians(np.linspace(-78, 78, ncol))
    zs = np.linspace(0.975, 0.44, 8)
    rings = []
    for k, z in enumerate(zs):
        rx, ry, cy = base.at(min(z, 0.93))
        g = 0.020 + 0.006 * k / (len(zs) - 1)
        row = []
        for a in A:
            p = V(((rx + g) * math.sin(a), cy - (ry + g) * math.cos(a), z))
            if z > 0.93:
                p = p.lerp(probe.torso_pt(z, a, 0.020), 0.6)
            row.append(tuple(p))
        rings.append(np.array(row))
    faces = B.grid(rings, ["apron"], closed=False)
    B.orient(faces, lambda c: V((c.x, c.y - 0.01, 0)))
    for col in (0, -1):
        B.tube(np.array([r[col] for r in rings[1:]]), 0.0017, 4, "apron_d", cap=False)
    B.tube(rings[-1], 0.0022, 4, "apron_d", cap=False)
    # a deep patch pocket on her right
    c = V(rings[4][6])
    out = V((c.x, c.y - 0.01, 0)).normalized()
    side = out.cross(V((0, 0, 1))).normalized()
    B.ellipsoid(c + out * 0.004, side * 0.048, out * 0.005, V((0, 0, 0.044)), "apron_d", 8, 4)
    B.tube(np.array([c + out * 0.008 + side * s * 0.044 + V((0, 0, 0.028)) for s in np.linspace(-1, 1, 7)]),
           0.0018, 4, "apron", cap=False)
    B.mark("skirt", i0, lmax=0.6)
    # waistband round the back, bow at the back
    bw.belt(B, probe, 0.982, 0.022, "apron", off=0.019, buckle=None)
    i0 = len(B.bm.verts)
    p, n = probe.on_torso(0.982, 180, 0.028)
    B.bow(p, n, 0.070, "apron")
    B.mark("near", i0, fit=0.020)
    return ctx.cloth(B, "alis_apron")


# ---------------------------------------------------------------------------
FEATHERS = [  # (x, z) base, direction (deg from +x, ccw), length, width: feather lobes swept up and out
    ((0.060, 1.540), 38, 0.040, 0.0115), ((0.070, 1.524), 20, 0.040, 0.0110), ((0.076, 1.506), 2, 0.034, 0.0100),
]


def build_mask(B, ctx):
    bw = ctx.bw

    def lower(X):
        ax = np.abs(X)
        return np.interp(ax, [0.0, 0.012, 0.026, 0.044, 0.064, 0.084, 0.098],
                         [1.478, 1.478, 1.488, 1.482, 1.474, 1.482, 1.502])

    def sdf(X, Z):
        d = bw.sd_ellipse(X, Z, 0.0, 1.530, 0.086, 0.055)
        d = np.maximum(d, lower(X) - Z)
        for s in (1, -1):
            for (x, z), ang, L, w in FEATHERS:
                a = np.array([s * x, z])
                th = math.radians(ang if s > 0 else 180 - ang)
                b = a + L * np.array([math.cos(th), math.sin(th)])
                d = bw.bg_smin(d, bw.sd_leaf(X, Z, tuple(a - 0.3 * (b - a)), tuple(b), w), 0.004)
        return np.maximum(d, -bw.eye_holes(X, Z))
    bw.mask_sheet(B, ctx.probe, sdf, h=0.0040, lift=0.0032)
    i0 = len(B.bm.verts)
    for s in (1, -1):
        for (x, z), ang, L, w in FEATHERS:                   # a raised quill down each feather lobe
            th = math.radians(ang if s > 0 else 180 - ang)
            dv = np.array([math.cos(th), math.sin(th)])
            a = np.array([s * x, z])
            bw.face_tube(B, ctx.probe, [tuple(a + dv * L * 0.05), tuple(a + dv * L * 0.85)], 0.0010, 0.0050,
                         "chain", 8)
        bw.face_tube(B, ctx.probe, [(s * 0.010, 1.540), (s * 0.028, 1.552), (s * 0.048, 1.551), (s * 0.064, 1.540)],
                     0.0013, 0.0046, "chain", 12)          # brow ridge over each eye
        for k in range(3):                                   # little engraved feather rows on the cheek
            x0 = s * (0.030 + 0.014 * k)
            bw.face_tube(B, ctx.probe, [(x0, 1.497), (x0 + s * 0.006, 1.489)], 0.0008, 0.0044, "chain", 4)
    # the beak: a short hooked brass beak from the bridge of the nose, over the nose
    top = V((0.0, -0.082, 1.528))
    path = np.array([tuple(top), (0.0, -0.096, 1.505), (0.0, -0.110, 1.484), (0.0, -0.121, 1.468),
                     (0.0, -0.124, 1.456), (0.0, -0.119, 1.448)])
    B.tube(path, [0.0130, 0.0150, 0.0135, 0.0095, 0.0050, 0.0012], 10, "fabric", up=V((1, 0, 0)), squash=0.75)
    B.tube(path[:4] + np.array([0.0, -0.0105, 0.004]), [0.0012, 0.0016, 0.0014, 0.0008], 4, "chain", cap=False)
    for s in (1, -1):                                        # nostril slits
        B.bead(V((s * 0.006, -0.116, 1.480)), 0.0016, "gem", 4, 2)
    B.mark("acc", i0)


# ---------------------------------------------------------------------------
def style_bun(st):
    """Tidy working hair: parted in the middle, drawn back over the ears into a round bun at the
    back of the crown, two short loose wisps at the temples."""
    st.cap(thick=0.0090, back_extra=0.005)
    st.cap_locks(0.0, n=24, off=0.0095, r=0.0080, front_sweep=False)
    for s in (1, -1):
        for k in range(3):
            st.skull_lock(s * math.radians(26 + 15 * k), math.radians(44 - 14 * k), s * math.radians(158),
                          math.radians(10), 0.0090, 0.0078, n=12, sag=math.radians(4))
    c = st.outer(math.pi, math.radians(18), 0.020)
    st.bun(c, 0.042, wraps=10, axis=(0, 1, 0.45))
    for s in (1, -1):                                        # wisps escaping at the temples
        p = st.head.scalp(s * math.radians(70), math.radians(18), 0.005)
        st.hang(p, 0.050, 0.010, r0=0.0042, wave=0.004, front=True)
