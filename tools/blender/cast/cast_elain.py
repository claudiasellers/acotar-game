"""Elain Archeron, the middle sister (lore/03-characters/archeron-family.md).

Canon [C]: sweet, gentle, dreamy; loves her garden and flowers; brown eyes;
brassy hair; an iron bracelet (human protection from faeries); human, rounded
ears; after the wealth returns she wears big floppy hats in her garden.
[X]: 1.63 m (the shortest sister); a rounder, softer face, big warm eyes,
fuller cheeks and lips.  Hair: soft long curls, half up with two twists that
meet at the back under a cluster of small flowers.  Dress: pale rose, puff
sleeves with little bows, a frilled straight neckline and a laced bodice, a
full bell skirt to mid-calf over a scalloped cream petticoat, and a cream
garden apron with a rose pocket full of seed packets, garden gloves hanging at
her hip.  Separate head accessory: the floppy straw garden hat with a rose
ribbon, a bow and a posy.  Her iron bracelet is two twisted rods.
"""

import math

import numpy as np
from mathutils import Vector as V
from mathutils.bvhtree import BVHTree

import cast_common as cc
from cast_nesta import box, iron_bangle

HEIGHT = 1.63
SHAPE = dict(
    eye_r=0.0195, eye_open_up=37.0, eye_open_lo=32.0, eye_tilt=3.0, eye_open_w=65.0,
    cheeks=1.22, cheekbones=0.0, chin=1.06, chin_drop=-0.002, nose=0.93, nose_bridge=0.0,
    lips=1.16, lip_w=0.97, face_w=1.03, cranium=1.01, neck=0.99,
    bust=1.06, ribs=1.0, waist=1.03, belly=1.02, pelvis=1.03, seat=1.05,
    thigh=1.04, calf=1.02, arm=1.03, forearm=1.02, hand=0.98,
)
WARP = dict(height=HEIGHT, head=1.015, legs=0.985, arm_len=0.99, arm_thick=1.01,
            wx=((0.0, 1.0), (0.85, 1.01), (1.00, 1.01), (1.28, 1.0), (1.47, 1.0)),
            wy=((0.0, 1.0), (1.47, 1.0)))
GAIT = "female"
SKIN_LINEAR = (0.82, 0.55, 0.45)        # warm, rosy
SKIN_SRGB = "EAC4B3"
IRIS = ((0.13, 0.065, 0.025), (0.42, 0.24, 0.09), (0.72, 0.48, 0.17))   # warm brown with honey flecks
IRIS_FLECKS = 0.55
LASH = 1.05
LASH_LINEAR = cc.srgb("3A2618")
HAIR_RGB = cc.srgb("B08552")            # the sisters' shared brassy golden-brown
BROWS_SRGB = "8A6440"
LIPS_SRGB = "C97C7C"

DEFAULT_OUTFIT = ["elain_dress", "elain_slippers", "elain_iron_bangle"]
DEFAULT_HAIR = "elain_curls"

ROSE_P, BLUSH, CREAM, ROSE, GOLD, STRAW = "F5BCC8", "FBE0E5", "FBF3E6", "F4A6C0", "D4A94F", "F1DCA6"
PAL = {"fabric": (ROSE_P, 0.36, 0.0), "lining": (CREAM, 0.40, 0.0), "apron": (CREAM, 0.55, 0.0),
       "ribbon": (ROSE, 0.35, 0.0), "cord": (CREAM, 0.6, 0.0), "trim_gold": (GOLD, 0.30, 0.55),
       "packet_a": ("D8B98C", 0.75, 0.0), "packet_b": ("FCE9A6", 0.6, 0.0), "gloves": ("A8CFA0", 0.7, 0.0),
       "flowers": (ROSE, 0.45, 0.0), "flowers_b": ("FCE9A6", 0.45, 0.0), "flowers_c": ("C8A8E9", 0.45, 0.0),
       "leaves": ("9CCFAA", 0.45, 0.0)}


def build(ctx):
    rep = []
    rep.append(cc.tris_line(build_dress(ctx)))
    B = ctx.builder("elain_slippers", {"fabric": (ROSE, 0.40, 0.0), "lining": (CREAM, 0.40, 0.0)})
    ctx.bw.build_slippers(B, ctx.probe, ctx.sh, ctx.rng)
    rep.append(cc.tris_line(ctx.cloth(B, "elain_slippers")))
    rep.append(cc.tris_line(iron_bangle(ctx, "elain_iron_bangle", side=-1, kind="twist")))
    obj, clear = ctx.hair_style("elain_curls", style_curls, HAIR_RGB)
    rep.append(cc.tris_line(obj) + " crown_clear=%.4f" % clear)
    rep.append(cc.tris_line(build_hat(ctx, obj)))
    return rep


# ---------------------------------------------------------------------------
def build_dress(ctx):
    bw, bg, probe = ctx.bw, ctx.bg, ctx.probe
    B = ctx.builder("elain_dress", PAL)
    W, T = bg.bodice(B, probe, bg.STRAIGHT, bg.rows(9, "fabric", "ribbon", "ribbon"))
    i0 = len(B.bm.verts)                                  # frill round the neckline
    for i in range(16):
        p = V(T[int(round(i * bg.COLS / 16)) % bg.COLS])
        out = V((p.x, p.y - probe.cy(p.z), 0.30)).normalized()
        side = out.cross(V((0, 0, 1))).normalized()
        B.ellipsoid(p + out * 0.006 + V((0, 0, 0.007)), side * 0.017, out.cross(side).normalized() * 0.003,
                    (out + V((0, 0, 1.2))).normalized() * 0.016, "lining", 5, 3)
    zz = np.linspace(0.975, 1.19, 7)                      # cream lacing down the bodice front
    pts = [probe.on_torso(z, 8.0 if k % 2 else -8.0, 0.012)[0] for k, z in enumerate(zz)]
    B.tube(bg.smooth_curve(np.array(pts), 14), 0.0013, 4, "cord", cap=False)
    pt, n = probe.on_torso(1.205, 28, 0.016)              # rosebud on her heart side
    B.rose(pt, n, 0.017, pmat="flowers")
    B.leaf(pt + V((0.014, 0, -0.006)), V((1, 0, -0.4)), n, 0.014, 0.0055)
    B.leaf(pt + V((-0.010, 0, -0.010)), V((-1, 0, -0.8)), n, 0.012, 0.005)
    B.mark("near", i0)
    bg.puff_sleeves(B, probe, ["fabric"] * 6, big=0.080, reach=0.27, trim="ribbon")
    i0 = len(B.bm.verts)
    for s in (1, -1):
        ra = probe.arm_radius(0.27)
        B.bow(V((s * 0.272, -0.004, 1.285 + ra[0] + 0.010)), V((0, -0.3, 1)), 0.024, "ribbon")
    B.mark("near", i0, fit=0.004)
    # bell skirt to mid-calf, scalloped cream petticoat peeking below
    ctrl = [(0.915, 0.19, 0.15, 0.0), (0.80, 0.30, 0.26, 0.0), (0.60, 0.385, 0.345, 0.0),
            (0.42, 0.425, 0.385, 0.0), (0.33, 0.43, 0.39, 0.0)]
    base = bg.Profile(ctrl)
    bg.skirt(B, ctrl, 7, bg.rows(7, "fabric"), waist=W, fold=(0.045, 12, 0.0), hem=("sin", 0.012, 12, 0.0),
             hem_from=0.7, lmax=0.6)
    bg.tier(base, 0.36, 0.285, 0.02, bg.rows(3, "lining"), B, rows=3, gap=0.022, hem=("sin", 0.007, 16, 0.0),
            hem_from=0.3, fold=(0.03, 18, 0.0), lmax=0.6)
    apron(B, ctx, base)
    return ctx.cloth(B, "elain_dress")


def apron(B, ctx, base):
    bw, bg, probe = ctx.bw, ctx.bg, ctx.probe
    i0 = len(B.bm.verts)
    ncol = 16
    A = np.radians(np.linspace(-62, 62, ncol))
    zs = np.linspace(0.975, 0.50, 8)
    rings = []
    for k, z in enumerate(zs):
        row = []
        for a in A:
            if z > 0.92:
                p = probe.torso_pt(z, a, 0.020)
                if z < 0.95:                               # ease into the skirt
                    rx, ry, cy = base.at(0.915)
                    q = V(((rx + 0.024) * math.sin(a), cy - (ry + 0.024) * math.cos(a), z))
                    p = p.lerp(q, 0.5)
            else:
                rx, ry, cy = base.at(z)
                g = 0.028
                p = V(((rx + g) * math.sin(a), cy - (ry + g) * math.cos(a), z))
            if k == len(zs) - 1:                           # scalloped hem
                p.z -= 0.006 * (1 + math.cos(9 * a))
            row.append(tuple(p))
        rings.append(np.array(row))
    faces = B.grid(rings, ["apron"], closed=False)
    B.orient(faces, lambda c: V((c.x, c.y - 0.01, 0)))
    for col in (0, -1):
        B.tube(np.array([r[col] for r in rings[1:]]), 0.0018, 4, "ribbon", cap=False)
    B.tube(rings[-1], 0.0020, 4, "ribbon", cap=False)
    # rose pocket on her right with seed packets standing in it
    r = rings[4]
    c = V(r[5])
    out = V((c.x, c.y - 0.01, 0)).normalized()
    side = out.cross(V((0, 0, 1))).normalized()
    B.ellipsoid(c + out * 0.004, side * 0.040, out * 0.005, V((0, 0, 0.038)), "fabric", 8, 4)
    B.tube(np.array([c + out * 0.007 + side * s * 0.036 + V((0, 0, 0.022)) for s in np.linspace(-1, 1, 7)]),
           0.0018, 4, "ribbon", cap=False)
    for k, (dx, tilt, mat) in enumerate(((-0.014, -0.25, "packet_a"), (0.012, 0.2, "packet_b"))):
        up = (V((0, 0, 1)) + side * tilt).normalized()
        pc = c + out * 0.004 + side * dx + up * 0.030
        box(B, pc, side * 0.011, out * 0.0018, up * 0.016, mat)
        B.flower(pc + out * 0.003 + up * 0.003, out, 0.007, 5, "flowers" if k else "flowers_c", rng=ctx.rng)
    B.mark("skirt", i0, lmax=0.6)
    # waistband tied in a bow at the back, gloves tucked in at her left hip
    bw.belt(B, probe, 0.982, 0.020, "apron", off=0.017, buckle=None)
    i0 = len(B.bm.verts)
    p, n = probe.on_torso(0.982, 180, 0.026)
    B.bow(p, n, 0.060, "apron")
    for k, deg in enumerate((64, 74)):
        p, n = probe.on_torso(0.975, deg, 0.026)
        glove(B, p + V((0, 0, -0.012 * k)), n, 0.9 + 0.1 * k)
    B.mark("near", i0, fit=0.018)


def glove(B, top, out, s=1.0):
    """A cotton garden glove hanging by its cuff, fingers down."""
    top, out = V(top), V(out).normalized()
    side = out.cross(V((0, 0, 1))).normalized()
    B.ellipsoid(top + V((0, 0, -0.012)) * s, side * 0.017 * s, out * 0.004, V((0, 0, 0.014)) * s, "gloves", 6, 3)
    palm = top + V((0, 0, -0.040)) * s + out * 0.002
    B.ellipsoid(palm, side * 0.019 * s, out * 0.006, V((0, 0, 0.022)) * s, "gloves", 6, 3)
    for j in range(4):
        x = (-0.0135 + 0.009 * j) * s
        L = (0.020, 0.024, 0.022, 0.017)[j] * s
        B.ellipsoid(palm + side * x + V((0, 0, -0.020 * s - L * 0.8)), side * 0.0042 * s, out * 0.0040, V((0, 0, L)),
                    "gloves", 5, 3)
    B.ellipsoid(palm + side * 0.020 * s + V((0, 0, -0.010 * s)), side * 0.004 * s, out * 0.004,
                (V((0, 0, -1)) + side * 0.6).normalized() * 0.016 * s, "gloves", 5, 3)


# ---------------------------------------------------------------------------
SKULL_C = V((0.0, 0.012, 1.535))


def build_hat(ctx, hair):
    """Big floppy straw garden hat, fitted over her hair: the crown follows the outermost of hair and
    head along rays from the skull centre, the wide soft brim droops more at the back and waves."""
    bg, probe = ctx.bg, ctx.probe
    B = ctx.builder("elain_garden_hat", {**PAL, "fabric": (STRAW, 0.72, 0.0)})
    me = hair.data
    hv = [tuple(v.co) for v in me.vertices]
    hbvh = BVHTree.FromPolygons(hv, [tuple(p.vertices) for p in me.polygons])

    def reach(d):
        best = 0.08
        for bvh in (hbvh, probe.bvh):
            hit = bvh.ray_cast(SKULL_C + d * 0.35, -d, 0.35)[0]
            if hit is not None:
                best = max(best, (hit - SKULL_C).length)
        return best

    nc = 40
    TH = 2 * math.pi * np.arange(nc) / nc
    def phib(th):
        return math.radians(17 + 9 * math.cos(th))
    rows = 7
    crown = []
    for k in range(rows):
        t = k / (rows - 1)
        row = []
        for th in TH:
            ph = phib(th) + (math.radians(86) - phib(th)) * t
            d = V((math.sin(th) * math.cos(ph), -math.cos(th) * math.cos(ph), math.sin(ph)))
            r = reach(d) + 0.007 + 0.010 * t ** 1.5
            row.append(tuple(SKULL_C + d * r))
        crown.append(np.array(row))
    # smooth each row round the head so stray locks don't dent the crown
    for k in range(rows):
        R = crown[k] - np.array(SKULL_C)
        rad = np.linalg.norm(R, axis=1)
        rs = (np.roll(rad, 1) + 2 * rad + np.roll(rad, -1)) / 4
        rs = np.maximum(rs, rad - 0.002)
        crown[k] = np.array(SKULL_C) + R / rad[:, None] * rs[:, None]
    i0 = len(B.bm.verts)
    faces = B.grid(crown, ["fabric"])
    B.orient(faces, lambda c: c - SKULL_C)
    topc = V(crown[-1].mean(axis=0)) + V((0, 0, 0.004))
    vt = B.bm.verts.new(tuple(topc))
    B.bm.verts.ensure_lookup_table()
    ring = [B.bm.verts[i0 + (rows - 1) * nc + j] for j in range(nc)]
    for j in range(nc):
        f = B.bm.faces.new((ring[j], ring[(j + 1) % nc], vt))
        f.material_index = B.slot("fabric")
    # brim
    base = crown[0]
    brim = [base]
    nb = 5
    for k in range(1, nb + 1):
        t = k / nb
        row = []
        for j, th in enumerate(TH):
            e = np.array([math.sin(th), -math.cos(th), 0.0])
            w = 0.135 + 0.010 * math.cos(th)
            droop = (0.020 + 0.026 * (1 - math.cos(th)) / 2) * t ** 1.7
            wave = 0.011 * t ** 2 * math.sin(6 * th + 0.5)
            row.append(base[j] + e * w * t + np.array([0, 0, -droop + wave]))
        brim.append(np.array(row))
    faces = B.grid(brim, ["fabric"])
    B.orient(faces, lambda c: V((0, 0, 1)))
    rim = np.vstack([brim[-1], brim[-1][:1]])
    B.tube(rim, 0.0035, 4, "fabric", cap=False)
    # rose ribbon round the crown, bow at the back-left with trailing tails
    band = []
    for j, th in enumerate(list(TH) + [TH[0]]):
        j = j % nc
        p = V(crown[0][j]).lerp(V(crown[1][j]), 0.55)
        o = (p - SKULL_C)
        o.z = 0
        band.append(tuple(p + o.normalized() * 0.002))
    B.tube(np.array(band), 0.0022, 4, "ribbon", up=V((0, 0, 1)), squash=4.2, cap=False)
    jb = int(round(nc * 150 / 360))
    pb = V(band[jb])
    ob = V((pb.x, pb.y - SKULL_C.y, 0)).normalized()
    B.bow(pb + ob * 0.006, ob, 0.046, "ribbon")
    for s, L in ((1, 0.15), (-1, 0.12)):
        side = ob.cross(V((0, 0, 1))).normalized()
        pts = [pb + ob * (0.010 + 0.11 * u) + side * s * 0.012 * u + V((0, 0, -0.012 - L * u * u))
               for u in np.linspace(0, 1, 7)]
        B.tube(np.array(pts), 0.0016, 4, "ribbon", up=ob, squash=5.0, cap=True)
    # posy on the front-left of the band
    for k, (deg, dz, kind, size) in enumerate(((42, 0.004, "rose", 0.030), (62, -0.004, "flowers_b", 0.020),
                                               (26, -0.006, "flowers_c", 0.018), (74, 0.008, "rose_s", 0.018))):
        j = int(round(nc * deg / 360))
        p = V(band[j]) + V((0, 0, dz))
        o = V((p.x, p.y - SKULL_C.y, 0.35)).normalized()
        p = p + o * 0.008
        if kind == "rose":
            B.rose(p, o, size, pmat="flowers")
        elif kind == "rose_s":
            B.rose(p, o, size, spin=0.7, pmat="flowers")
        else:
            B.flower(p, o, size, 6, kind, spin=0.3 * k)
    for deg, ang in ((50, -0.6), (34, 0.5), (68, 0.9)):
        j = int(round(nc * deg / 360))
        p = V(band[j])
        o = V((p.x, p.y - SKULL_C.y, 0)).normalized()
        t = o.cross(V((0, 0, 1))).normalized()
        B.leaf(p + o * 0.006 + t * 0.022 * math.copysign(1, ang) + V((0, 0, -0.008)),
               t * math.copysign(1, ang) + V((0, 0, ang * 0.3)), o, 0.020, 0.008)
    B.mark("acc", i0)
    return ctx.head_piece(B, "elain_garden_hat")


# ---------------------------------------------------------------------------
def style_curls(st):
    """Soft, long, loosely curled hair; a near-centre parting; two twists from the temples meet at the
    back under a little cluster of flowers (pink, butter, lilac, pearl)."""
    part = math.radians(-10)
    st.cap(thick=0.012, back_extra=0.010)
    st.cap_locks(part, n=24)
    st.back_mass(1.08, n=15, spread=0.065, r=0.021, wave=0.005, curl=0.016)
    st.front_locks(1.20, n=2, r=0.014, wave=0.004, curl=0.013)
    meet = st.outer(math.pi, math.radians(-6), 0.004)
    for s in (1, -1):
        a = st.head.scalp(s * math.radians(72), math.radians(30), 0.013)
        b = st.head.scalp(s * math.radians(130), math.radians(12), 0.015)
        st.lock([a, b, meet + np.array([s * 0.012, -0.004, 0.0])], 0.010, 0.008, k=0.004)
    for i, (dx, dz, sz, col) in enumerate(((0.0, 0.0, 0.012, 0), (0.017, 0.006, 0.010, 1), (-0.017, 0.005, 0.010, 2),
                                           (0.010, -0.014, 0.008, 3), (-0.011, -0.013, 0.008, 1))):
        st.flower(meet + np.array([dx, 0.006, dz]), sz, normal=(dx * 20, 1.0, 0.15), col=col)
    st.flower(st.outer(math.radians(84), math.radians(4), 0.002), 0.008, normal=(1, 0.1, 0.1), col=0)
