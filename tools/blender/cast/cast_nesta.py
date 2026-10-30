"""Nesta Archeron, eldest of the three sisters (lore/03-characters/archeron-family.md).

Canon [C]: cold, sharp, proud, iron-willed, often sneering; blue-grey eyes like
Feyre's and their mother's; brassy hair; an iron bracelet (human protection
from faeries); human, rounded ears.
[X]: 1.70 m (the tallest sister); an elegant, haughty, sharp-featured beauty:
narrower face, defined cheekbones, small pointed chin, upswept almond eyes,
firmer thinner lips, a straight nose; eyes a colder, steelier blue-grey.
Hair: a severe sleek chignon with a centre parting, a braid wrapped round the
knot and a few pearl pins.  Gown: pastel blue-grey, a high jewel neckline with
a small stand collar and a steel-blue brooch, long fitted sleeves with gold
cuffs, princess-seam piping, a pointed basque waist, a column skirt with a
slight train, open at the front over a pale silver underskirt (pretty but
austere).  Second piece: the worn grey-blue cottage cloak, patched and frayed.

The shared sister kit (iron bangle, worn cloak, box) lives here too; cast_elain
imports it.
"""

import math
import sys

import numpy as np
from mathutils import Vector as V

import cast_common as cc

HEIGHT = 1.70
SHAPE = dict(
    eye_r=0.0181, eye_open_up=30.0, eye_open_lo=27.0, eye_tilt=10.0, eye_open_w=63.0,
    cheeks=0.70, cheekbones=0.40, jaw=0.0, jaw_w=0.95, chin=0.92, chin_drop=0.005, chin_point=0.55,
    brow=0.0, nose=1.04, nose_bridge=0.45, lips=0.90, lip_w=0.97, face_w=0.95, neck=0.96,
    bust=0.95, ribs=0.98, waist=0.95, belly=0.95, pelvis=0.97, seat=0.95,
    thigh=0.96, calf=0.96, arm=0.96, forearm=0.97, hand=0.98,
)
WARP = dict(height=HEIGHT, head=0.985, legs=1.03, arm_len=1.01, arm_thick=0.99,
            wx=((0.0, 1.0), (0.85, 0.99), (1.00, 0.98), (1.28, 1.0), (1.47, 1.0)),
            wy=((0.0, 1.0), (1.47, 1.0)))
GAIT = "female"
SKIN_LINEAR = (0.83, 0.59, 0.50)        # a cool porcelain, a shade paler than Feyre
SKIN_SRGB = "EBCABC"
IRIS = ((0.20, 0.29, 0.38), (0.50, 0.60, 0.68), (0.62, 0.66, 0.70))   # steel outer, grey-blue inner, cold fleck
IRIS_FLECKS = 0.25
LASH = 0.95
LASH_LINEAR = cc.srgb("2E2118")
HAIR_RGB = cc.srgb("B08552")            # the sisters' shared brassy golden-brown
BROWS_SRGB = "6E4E30"
LIPS_SRGB = "B4646C"

DEFAULT_OUTFIT = ["nesta_gown", "nesta_slippers", "nesta_iron_bangle"]
DEFAULT_HAIR = "nesta_chignon"

BLUEGREY, BLUEGREY_D, SILVER, GOLD, STEEL = "8499BA", "6D82A3", "E2E8F1", "D4A94F", "8FB4D9"
IRON = ("4A4C51", 0.62, 0.85)           # dark grey, slightly rough
PAL = {"fabric": (BLUEGREY, 0.38, 0.0), "lining": (SILVER, 0.36, 0.0), "trim": (GOLD, 0.30, 0.6),
       "gem": (STEEL, 0.08, 0.0)}


def build(ctx):
    rep = []
    rep.append(cc.tris_line(build_gown(ctx)))
    B = ctx.builder("nesta_slippers", {"fabric": (BLUEGREY_D, 0.40, 0.0), "lining": (GOLD, 0.30, 0.6)})
    ctx.bw.build_slippers(B, ctx.probe, ctx.sh, ctx.rng)
    rep.append(cc.tris_line(ctx.cloth(B, "nesta_slippers")))
    rep.append(cc.tris_line(iron_bangle(ctx, "nesta_iron_bangle", side=1, kind="band")))
    rep.append(cc.tris_line(worn_cloak(ctx, "nesta_cloak", {"fabric": ("7F8C9C", 0.85, 0.0),
                                                            "lining": ("6A6F78", 0.9, 0.0),
                                                            "patch": ("97A1AE", 0.9, 0.0),
                                                            "cord": ("8A7A68", 0.8, 0.0),
                                                            "clasp": IRON})))
    ctx.bh.RIBBON_RGB = cc.srgb(BLUEGREY_D)
    obj, clear = ctx.hair_style("nesta_chignon", style_chignon, HAIR_RGB)
    rep.append(cc.tris_line(obj) + " crown_clear=%.4f" % clear)
    return rep


# ---------------------------------------------------------------------------
def basque_z(a, z=0.975, dip=0.040):
    """Waistline height round the body: a pointed basque, lowest at the front (a = 0)."""
    aw = (a + math.pi) % (2 * math.pi) - math.pi
    return z - dip * math.exp(-(aw / 0.55) ** 2)


def build_gown(ctx):
    bw, bg, probe, sh = ctx.bw, ctx.bg, ctx.probe, ctx.sh
    B = ctx.builder("nesta_gown", PAL)
    # fitted bodice + long sleeves, high jewel neckline
    hole = bw.neckline(0.022, 0.050, 1.352)
    bm = sh.make(lambda r, c: r in ("torso", "arms") and not hole(c),
                 lambda c: 0.0055, [bw.z_below(0.925)] + bw.x_beyond(0.575), max_tris=1450)
    bw.add_bm(B, bm, "fabric", "shell", fit=0.0055)
    bw.bind(B, bm, 0.0032, "trim", where=lambda p: abs(p[0]) > 0.5, squash=1.8, fit=0.0055)   # gold cuffs
    bm.free()
    # small stand collar, gold-edged, with a steel-blue brooch
    i0 = len(B.bm.verts)

    def collar_z(h):
        return lambda a: 1.349 - 0.019 * max(0.0, math.cos(a)) ** 2 + h
    rings = [bw.neck_ring(probe, collar_z(h), off, 40)[:-1] for h, off in ((-0.004, 0.0055), (0.014, 0.0060),
                                                                          (0.024, 0.0080))]
    faces = B.grid(rings, ["fabric", "lining"])
    B.orient(faces, lambda c: V((c.x, c.y - 0.010, 0)))
    top = np.vstack([rings[-1], rings[-1][:1]])
    B.tube(top, 0.0017, 4, "trim", cap=False)
    bot = np.vstack([rings[0], rings[0][:1]])
    B.tube(bot, 0.0020, 4, "trim", cap=False)
    B.mark("shell", i0, fit=0.0050)
    i0 = len(B.bm.verts)
    f = V(rings[0][0])
    n = V((0, -1, 0.25)).normalized()
    B.ellipsoid(f + n * 0.004, V((0.0075, 0, 0)), n * 0.0035, V((0, 0, 0.0095)), "gem", 8, 4)
    bw.torus(B, f + n * 0.003, n, 0.0092, 0.0015, "trim", 16, 4)
    B.bead(f + n * 0.004 + V((0, 0, -0.013)), 0.0028, "pearl", 5, 3)
    B.mark("near", i0, fit=0.004)
    # gold buttons down the front and princess-seam piping: structured, austere
    bw.buttons(B, probe, np.linspace(1.035, 1.285, 7), 0.0085, r=0.0031, mat="trim")
    i0 = len(B.bm.verts)
    for deg in (-34, 34):
        pts = [probe.on_torso(z, deg, 0.0072)[0] for z in np.linspace(basque_z(math.radians(deg)) + 0.004, 1.21, 9)]
        B.tube(bg.smooth_curve(np.array(pts), 14), 0.0015, 4, "trim", cap=False)
    path = np.array([probe.torso_pt(basque_z(a), a, 0.0125) for a in np.linspace(0, 2 * math.pi, 49)])
    B.tube(path, 0.0026, 4, "trim", up=V((0, 0, 1)), squash=1.7, cap=False)
    B.mark("shell", i0, fit=0.0060)
    # column skirt with a slight train, pale underskirt showing at the front
    W = np.array([probe.torso_pt(basque_z(a), a, 0.0085) for a in bg.ANG])
    hx, hy, hc = bw.girth(probe, 0.875)
    ctrl = [(0.90, hx + 0.016, hy + 0.016, hc), (0.70, hx + 0.036, hy + 0.034, hc + 0.004),
            (0.45, hx + 0.068, hy + 0.068, hc + 0.014), (0.22, hx + 0.100, hy + 0.104, hc + 0.028),
            (0.035, hx + 0.128, hy + 0.146, hc + 0.048)]
    bg.skirt(B, ctrl, 8, bg.rows(8, "lining"), waist=W, fold=(0.030, 8, 0.0), lmax=0.75)
    ctrl_o = [(z, rx + 0.012, ry + 0.012, cy) for z, rx, ry, cy in ctrl]
    ctrl_o[-1] = (0.025, ctrl_o[-1][1] + 0.006, ctrl_o[-1][2] + 0.016, ctrl_o[-1][3] + 0.006)
    open_skirt(B, probe, ctrl_o, 7, math.radians(9), math.radians(34), "fabric", "trim",
               lambda a: probe.torso_pt(basque_z(a), a, 0.0125), fold=(0.045, 7, 0.4), lmax=0.75)
    return ctx.cloth(B, "nesta_gown")


def open_skirt(B, probe, ctrl, nrows, gap0, gap1, mat, edge_mat, waist_fn, ncol=34, fold=(0.04, 7, 0.0),
               lmax=0.7, hem_trim=True):
    """Lathe overskirt open at the front: the gap widens from gap0 at the waist to gap1 at the hem.
    Gold piping runs down both front edges and round the hem."""
    bg = sys.modules["build_gowns"]
    i0 = len(B.bm.verts)
    prof = bg.smooth_curve(ctrl, nrows)
    rings = []
    for k in range(nrows + 1):
        t = k / nrows
        gap = gap0 + (gap1 - gap0) * t ** 0.8
        A = gap + (2 * math.pi - 2 * gap) * np.arange(ncol) / (ncol - 1)
        if k == 0:
            rings.append(np.array([tuple(waist_fn(a)) for a in A]))
            continue
        z, rx, ry, cy = prof[k - 1]
        f = 1.0 + fold[0] * t ** 1.3 * np.sin(fold[1] * A + fold[2])
        rings.append(np.stack([rx * f * np.sin(A), cy - ry * f * np.cos(A), z + 0.0 * A], axis=1))
    faces = B.grid(rings, [mat], closed=False)
    B.orient(faces, lambda c: V((c.x, c.y - 0.01, 0)))
    for col in (0, -1):
        B.tube(np.array([r[col] for r in rings]), 0.0024, 4, edge_mat, cap=False)
    if hem_trim:
        B.tube(rings[-1], 0.0030, 4, edge_mat, cap=False)
    B.mark("skirt", i0, lmax=lmax)
    return rings


# ---------------------------------------------------------------------------
# Shared sister kit
# ---------------------------------------------------------------------------
def box(B, c, a1, a2, a3, mat):
    """Box with half-axes a1..a3 (vectors) centred at c."""
    import bmesh
    from mathutils import Matrix
    M = Matrix([[a1[0], a2[0], a3[0], c[0]], [a1[1], a2[1], a3[1], c[1]], [a1[2], a2[2], a3[2], c[2]], [0, 0, 0, 1]])
    r = bmesh.ops.create_cube(B.bm, size=2.0, matrix=M)
    idx = B.slot(mat)
    for vt in r["verts"]:
        for f in vt.link_faces:
            f.material_index = idx


def iron_bangle(ctx, name, side=1, kind="band", x=0.597):
    """The iron bracelet every Archeron sister wears against faeries: dark grey, slightly rough
    (hammered: the radius wobbles a little).  kind 'band' = a flat riveted cuff, 'twist' = two
    twisted rods.  Skinned like Feyre's bangle (body weights at the wrist)."""
    bw, probe = ctx.bw, ctx.probe
    rng = np.random.default_rng(77 + side)
    B = ctx.builder(name, {"fabric": IRON})
    c = bw.wrist(side, x)
    R = max(probe.arm_radius(x)) + 0.0055
    ax = V((1, 0, 0))
    e1, e2 = V((0, 1, 0)), V((0, 0, 1))
    if kind == "band":
        n = 40
        wob = rng.uniform(-1, 1, n)
        wob = 0.5 * wob + 0.25 * np.roll(wob, 1) + 0.25 * np.roll(wob, -1)
        pts = []
        for k in range(n + 1):
            t = 2 * math.pi * k / n
            r = R + 0.00045 * wob[k % n]
            pts.append(c + (e1 * math.cos(t) + e2 * math.sin(t)) * r)
        B.tube(np.array(pts), 0.0021, 6, "fabric", up=ax, squash=2.6, cap=False)
        for k in range(8):                                     # rivets round the cuff
            t = 2 * math.pi * (k + 0.5) / 8
            d = e1 * math.cos(t) + e2 * math.sin(t)
            for s in (1, -1):
                B.bead(c + d * (R + 0.0021) + ax * s * 0.0034, 0.0011, "fabric", 4, 2)
    else:
        n = 64
        for strand in (0, 1):
            pts = []
            for k in range(n + 1):
                t = 2 * math.pi * k / n
                d = e1 * math.cos(t) + e2 * math.sin(t)
                ph = 7 * t + strand * math.pi
                pts.append(c + d * (R + 0.0016 * math.cos(ph) + 0.0003 * rng.uniform(-1, 1)) + ax * 0.0017 * math.sin(ph))
            pts[-1] = pts[0]
            B.tube(np.array(pts), 0.0015, 5, "fabric", cap=False)
    B.mark("near", 0, fit=0.0025)
    return ctx.cloth(B, name)


def worn_cloak(ctx, name, pal, hem=0.34, rag=0.040, nr=18, nc=36, hood=True):
    """The sisters' worn cottage cloak: like Feyre's velvet cloak, but shorter, coarse wool with a
    frayed, uneven hem, two patches, a hood lying on the shoulders and a cord-and-toggle fastening."""
    bw, probe, rng = ctx.bw, ctx.probe, np.random.default_rng(311 + len(name))
    B = ctx.builder(name, pal)
    gap = math.radians(40)
    sh_r = bw.girth(probe, 1.24)[0] + 0.075
    rag_c = rng.uniform(0.0, 1.0, nc) * (0.4 + 0.6 * (np.arange(nc) % 2))
    outer, inner = [], []
    for r in range(nr):
        t = r / (nr - 1)
        z = 1.375 - t * (1.375 - hem)
        rx = np.interp(t, [0, 0.05, 0.12, 0.25, 1.0], [0.074, 0.15, sh_r, sh_r + 0.02, 0.33])
        ry = np.interp(t, [0, 0.05, 0.12, 0.25, 1.0], [0.070, 0.105, 0.130, 0.150, 0.26])
        row, row_in = [], []
        for c in range(nc):
            a = gap + (2 * math.pi - 2 * gap) * c / (nc - 1)
            fold = 1.0 + 0.05 * t ** 1.2 * math.sin(a * 8.0 + 0.6)
            dz = rag * rag_c[c] * t ** 10
            p = (rx * fold * math.sin(a), -ry * fold * math.cos(a) + 0.014, z + dz)
            row.append(p)
            k = 1.0 - 0.004 / max(rx, ry)
            row_in.append((p[0] * k, (p[1] - 0.014) * k + 0.014, z + dz))
        outer.append(np.array(row))
        inner.append(np.array(row_in))
    i0 = len(B.bm.verts)
    f1 = B.grid(outer, ["fabric"], closed=False)
    B.orient(f1, lambda c: V((c.x, c.y - 0.014, 0)))
    f2 = B.grid(inner, ["lining"], closed=False)
    B.orient(f2, lambda c: -V((c.x, c.y - 0.014, 0)))
    for (r, c, w, h) in ((9, 25, 0.034, 0.040), (13, 8, 0.028, 0.030)):     # mended patches
        p = V(outer[r][c])
        out = V((p.x, p.y - 0.014, 0)).normalized()
        side = out.cross(V((0, 0, 1))).normalized()
        B.ellipsoid(p + out * 0.0025, side * w, out * 0.0018, V((0, 0, h)), "patch", 6, 3)
    if hood:                                               # hood fallen back over the shoulders
        B.ellipsoid(V((0, 0.168, 1.315)), V((0.095, 0, 0)), V((0, 0.032, 0)), V((0, 0, 0.062)), "fabric", 10, 5)
        B.ellipsoid(V((0, 0.150, 1.345)), V((0.080, 0, 0)), V((0, 0.020, 0)), V((0, 0, 0.030)), "lining", 8, 3)
    B.mark("cape", i0, fit=0.014, bones=list(bw.CLOAK_BONES))
    i0 = len(B.bm.verts)                                   # cord and a plain iron toggle at the throat
    pl, pr = V(outer[1][0]) + V((0, -0.006, 0)), V(outer[1][-1]) + V((0, -0.006, 0))
    mid = V((0, -0.096, 1.338))
    B.tube(np.array([pl, (pl + mid) / 2 + V((0, -0.004, -0.004)), mid, (pr + mid) / 2 + V((0, -0.004, -0.004)), pr]),
           0.0014, 4, "cord", cap=False)
    B.ellipsoid(mid + V((0, -0.003, 0)), V((0.011, 0, 0)), V((0, 0.0028, 0)), V((0, 0, 0.0030)), "clasp", 6, 3)
    B.mark("cape", i0, fit=0.010, bones=["Neck", "UpperChest"])
    return ctx.cloth(B, name)


# ---------------------------------------------------------------------------
def style_chignon(st):
    """Severe and sleek: centre parting, hair drawn tight over the ears into a low knot at the back of
    the head, a thin braid wrapped round it and five pearl pins."""
    st.cap(thick=0.0085, back_extra=0.004)
    st.cap_locks(0.0, n=26, off=0.0090, r=0.0074, front_sweep=False)
    for s in (1, -1):                                     # drawn back from the temples, over the ears
        for k in range(3):
            st.skull_lock(s * math.radians(28 + 14 * k), math.radians(46 - 14 * k), s * math.radians(160),
                          math.radians(4), 0.0085, 0.0072, n=12, sag=math.radians(3))
    c = st.outer(math.pi, math.radians(-2), 0.017)
    st.bun(c, 0.036, wraps=11, axis=(0, 1, 0.05))
    pts = []
    for i in range(22):                                   # braid wrapped round the knot
        a = math.radians(-70 + 330 * i / 21)
        pts.append(c + np.array([math.cos(a) * 0.035, -0.006, math.sin(a) * 0.035]))
    st.braid(pts, width=0.016, lobes=16)
    for k in range(5):
        a = math.radians(30 + 30 * k)
        p = c + np.array([math.cos(a) * 0.032, 0.012, math.sin(a) * 0.032])
        st.flower(p, 0.0050, normal=(math.cos(a) * 0.4, 1.0, math.sin(a) * 0.4), col=3)
