"""The bow ladder, the arrow set and the quivers (lane L73). Headless Blender,
deterministic. Plan 4.3: five bows, ten arrow types. All [X] except the plain
worn hunting bow and the long, heavy mountain-ash arrow with its iron head [C].

Run:  /opt/bpyenv/bin/python tools/blender/arms_props.py [--only id,id] [--sheet DIR]
Out:  art/arms/<id>.glb and art/arms/arms_manifest.json

Bows (docs/contracts/arms_models.md): root node "<id>" with children
  <id>_riser        the grip, rigid, grip centre at the origin
  <id>_limb_top     origin at the limb's root, so a small rotation about X flexes it
  <id>_limb_bottom  the same, mirrored
  <id>_tip_top / _tip_bottom   empties at the string nocks (children of the limbs)
and "<id>_lod1", one merged mesh. Limbs run along +Y/-Y in Godot, the tips sit
back toward the archer (+Z), as BowVisual's limbs do. No string: the game draws it.

Arrows follow ArrowModel's mesh contract (F44): nock at the origin, tip down
-Z in Godot, 0.83 m (the ash arrow 0.90 m [C] "the longest and heaviest").
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
from mathutils import Matrix, Vector  # noqa: E402
import prop_kit as K  # noqa: E402
import upcoming_kit as U  # noqa: E402
from prop_kit import (BLUSH, BUTTER, CREAM, GOLD, IRON, LILAC, MINT, OAK_DARK, PEARL, PERI, ROSE, STRAW,  # noqa: E402
                      R, S, T, cyl, lathe, sphere, torus, tube)

OUT = os.path.join(K.ROOT, "art/arms")

HONEY = (0.80, 0.60, 0.40)
WORN_LEATHER = (0.60, 0.38, 0.33)
YEW_HEART = (0.78, 0.47, 0.36)
YEW_SAP = (0.85, 0.80, 0.64)
SAGE_DEEP = K.SAGE_DEEP
STEEL = (0.66, 0.66, 0.76)          # lilac-tinted, never grey
IRON_DARK = (0.36, 0.33, 0.42)
SHAFT = (0.549, 0.416, 0.271)
ID = Matrix.Identity(4)
# local +X -> along the limb, local +Z -> out of the bow's back
ONBACK = Matrix(((0, -1, 0), (0, 0, -1), (1, 0, 0))).to_4x4()
# builds made tip-up (+Z) are laid tip-forward (+Y in Blender, -Z in Godot)
TIP_FORWARD = R("X", -90)


# ------------------------------------------------------------------ limbs


class Limb:
    """One bow limb from its root (origin) up +Z, bending in the YZ plane.
    yfn(t) is the offset toward the back of the bow (+Y) for t in 0..1."""

    def __init__(self, length, yfn, wx, wy, n=18):
        self.L, self.yfn, self.wxf, self.wyf, self.n = length, yfn, wx, wy, n

    def pos(self, t):
        return Vector((0, self.yfn(t), self.L * t))

    def tan(self, t):
        a, b = self.pos(max(t - 0.01, 0.0)), self.pos(min(t + 0.01, 1.0))
        return (b - a).normalized()

    def nrm(self, t):
        tg = self.tan(t)
        return Vector((0, -tg.z, tg.y))

    def wx(self, t):
        return self.wxf[0] + (self.wxf[1] - self.wxf[0]) * t

    def wy(self, t):
        return self.wyf[0] + (self.wyf[1] - self.wyf[0]) * t

    def frame(self, t):
        """Matrix: X across the limb, Y toward the belly, Z along it."""
        tg, nr, p = self.tan(t), self.nrm(t), self.pos(t)
        m = Matrix.Identity(4)
        m.col[0][:3] = (1, 0, 0)
        m.col[1][:3] = nr
        m.col[2][:3] = tg
        m.col[3][:3] = p
        return m

    def on_back(self, t, lift=1.0):
        return self.frame(t) @ T(0, -self.wy(t) * lift, 0) @ ONBACK

    def body(self, sides=8, t0=0.0, t1=1.0, gx=1.0, gy=1.0, pad=0.0, off=0.0, n=None):
        """The limb, or a sleeve/strip over part of it: widths scaled by gx/gy
        plus pad, the section shifted by off * thickness toward the belly."""
        n = n or max(2, int(round(self.n * (t1 - t0))))
        pts, wxs, wys = [], [], []
        for i in range(n + 1):
            t = t0 + (t1 - t0) * i / n
            p = self.pos(t) + self.nrm(t) * (off * self.wy(t))
            pts.append((p.y, p.z))
            wxs.append(self.wx(t) * gx + pad)
            wys.append(self.wy(t) * gy + pad)
        return U.sweep(pts, wxs, wys, sides)

    def helix(self, t0, t1, turns, gap, n=40, phase=0.0):
        out = []
        for i in range(n + 1):
            t = t0 + (t1 - t0) * i / n
            a = phase + turns * 2 * math.pi * i / n
            out.append(self.pos(t) + Vector((1, 0, 0)) * math.cos(a) * (self.wx(t) + gap)
                       + self.nrm(t) * math.sin(a) * (self.wy(t) + gap))
        return out


def riser_pts(g, n=8):
    return [(0.0, -g + 2 * g * i / n) for i in range(n + 1)]


def riser_body(p, g, wx_end, wy_end, swell, color, finish="satin", shade=None, sides=10):
    """The handle section between the limbs, swelling to fill the hand."""
    pts = riser_pts(g)
    f = [1.0 + swell * math.sin(math.pi * i / (len(pts) - 1)) for i in range(len(pts))]
    p.add(U.sweep(pts, [wx_end * v for v in f], [wy_end * v for v in f], sides), color, finish, shade=shade)


def wrap(p, z0, z1, wx, wy, color, finish="fabric", rings=0, ring_color=None, ring_finish="fabric"):
    """A grip wrap with raised turns."""
    p.add(U.sweep([(0, z0), (0, (z0 + z1) / 2), (0, z1)], wx, wy, 8), color, finish)
    for k in range(rings):
        z = z0 + (z1 - z0) * (k + 0.5) / rings
        p.add(U.sweep([(0, z - 0.0022), (0, z), (0, z + 0.0022)], [wx + 0.0004, wx + 0.0016, wx + 0.0004],
                      [wy + 0.0004, wy + 0.0016, wy + 0.0004], 8), ring_color or K.darker(color, 0.2), ring_finish)


# ------------------------------------------------------------------ bows


def hunting_bow():
    """[C] plain, worn, a poor girl's bow: one stave of honey-coloured wood,
    a sweat-darkened leather grip, a twine repair on the upper limb."""
    g = 0.07
    limb = Limb(0.55, lambda t: -0.13 * t ** 1.6, (0.0165, 0.0085), (0.0130, 0.0065))
    wood = U.grain(HONEY, 0.16)

    def limb_fn(p, top):
        p.add(limb.body(), HONEY, "satin", shade=wood)
        p.add(limb.body(t0=0.93, t1=1.0, gx=1.12, gy=1.12), K.darker(HONEY, 0.28), "satin")
        p.add(limb.body(t0=0.955, t1=0.972, gx=1.3, gy=1.3, n=2), K.darker(HONEY, 0.45), "matte")
        if top:
            for k in range(5):
                t = 0.40 + 0.022 * k
                p.add(limb.body(t0=t, t1=t + 0.018, gx=1.1, gy=1.1, pad=0.001, n=2), STRAW, "fabric")
            p.add(tube([limb.pos(0.51) + Vector((0.012, -0.004, 0)), limb.pos(0.53) + Vector((0.02, -0.012, 0.012)),
                        limb.pos(0.535) + Vector((0.026, -0.01, 0.03))], [0.0016, 0.0014, 0.001], 5), STRAW, "fabric")

    def riser_fn(p):
        riser_body(p, g, 0.0165, 0.013, 0.22, HONEY, shade=wood)
        wrap(p, -0.055, 0.055, 0.0215, 0.0175, WORN_LEATHER, "fabric", rings=7)
        p.add(sphere(0.006, 8, 5), K.darker(WORN_LEATHER, 0.25), "fabric", T(0.021, 0, 0.058) @ S(1, 1.4, 0.7))

    return dict(g=g, limb=limb, limb_fn=limb_fn, riser_fn=riser_fn)


def yew_longbow():
    """[X] the manor armoury's longbow: tall, a D of rose heartwood under a
    cream sapwood back, pearl horn nocks, a mint silk grip bound in gold."""
    g = 0.08
    limb = Limb(0.77, lambda t: -0.16 * t ** 1.8, (0.0170, 0.0075), (0.0155, 0.0075), n=20)
    heart = U.grain(YEW_HEART, 0.14)
    rng = random.Random(7302)

    def limb_fn(p, top):
        p.add(limb.body(), YEW_HEART, "satin", shade=heart)
        p.add(limb.body(t0=0.0, t1=0.93, gx=0.78, gy=0.42, off=-0.72, sides=6, n=10), YEW_SAP, "satin")
        p.add(limb.body(t0=0.915, t1=1.0, gx=1.14, gy=1.14, pad=0.0006), PEARL, "pearl")
        tip = limb.pos(1.0)
        p.add(tube([tip, tip + Vector((0, 0.006, 0.014)), tip + Vector((0, 0.016, 0.02)), tip + Vector((0, 0.022, 0.014))],
                   [0.007, 0.0055, 0.004, 0.002], 8), PEARL, "pearl")
        p.add(limb.body(t0=0.90, t1=0.915, gx=1.2, gy=1.2, pad=0.0008, n=2), GOLD, "gold")
        for k, t in enumerate((0.10, 0.17, 0.24, 0.31)):
            side = 1 if k % 2 else -1
            p.add(K.leaf(0.03, 0.011), GOLD, "gold", limb.on_back(t, 0.86) @ T(0, side * 0.002, 0) @ R("Z", side * 22))

    def riser_fn(p):
        riser_body(p, g, 0.017, 0.0155, 0.2, YEW_HEART, shade=heart)
        wrap(p, -0.058, 0.058, 0.0218, 0.0198, MINT, "fabric", rings=8, ring_color=GOLD, ring_finish="gold")
        for z in (-0.066, 0.066):
            p.add(U.sweep([(0, z - 0.006), (0, z), (0, z + 0.006)], [0.021, 0.0235, 0.021], [0.019, 0.0215, 0.019], 10), GOLD, "gold")
        p.add(lathe([(0.016, 0.0), (0.014, 0.003), (0.0, 0.004)], 12), GOLD, "gold", T(0, 0.0175, 0.0) @ TIP_FORWARD)
        K.soft_rose(p, T(0, 0.0195, 0.0) @ TIP_FORWARD, 0.0125, ROSE, "pearl", rng)

    return dict(g=g, limb=limb, limb_fn=limb_fn, riser_fn=riser_fn)


def fae_recurve():
    """[X] the lesser-fae village's recurve: lilac lacquer limbs that curl
    forward into gold scrolls with a faelight bead, a gold vine in leaf and
    blossom wound up each limb, a grip set in a cup of rose petals."""
    g = 0.09
    limb = Limb(0.53, lambda t: -0.242 * t * t + 0.30 * t ** 6, (0.0210, 0.0110), (0.0085, 0.0050), n=20)

    def limb_fn(p, top):
        p.add(limb.body(), LILAC, "pearl",
              shade=lambda co: K.mix(LILAC, PERI, max(0.0, min(1.0, co.z / 0.53)) * 0.7))
        p.add(limb.body(t0=0.02, t1=0.95, gx=0.42, gy=0.5, off=-0.7, sides=6, n=10), K.lighter(MINT, 0.2), "pearl")
        vine = limb.helix(0.06, 0.93, 3.25, 0.0022, 28, phase=0.0 if top else math.pi)
        p.add(tube(vine, [0.0024 - 0.0008 * i / 28 for i in range(29)], 4), GOLD, "gold")
        for k in range(7):
            i = 2 + k * 4
            v, nxt = vine[i], vine[i + 1]
            t = 0.06 + 0.87 * i / 28
            out = (v - limb.pos(t)).normalized()
            along = (nxt - v).normalized()
            side = out.cross(along).normalized()
            m = Matrix.Identity(4)
            m.col[0][:3] = (along * 0.6 + out * 0.8).normalized()
            m.col[1][:3] = side
            m.col[2][:3] = m.col[0].to_3d().cross(side).normalized()
            m.col[3][:3] = v
            if k % 3 == 2:
                K.star_flower(p, (0, 0, 0), 0.008, BLUSH, 5, "pearl", BUTTER, facing=m @ R("Y", 90))
            else:
                p.add(K.leaf(0.022, 0.009), MINT, "leaf", m)
        # the curl: a scroll continuing the tip forward and down, with a faelight in its eye
        tip, w = limb.pos(1.0), limb.wx(1.0)
        r0 = 0.024
        c = tip + Vector((0, r0 * 0.35, -r0 * 0.94))
        a0 = math.atan2((tip - c).z, -(tip - c).y)
        pts, rad = [], []
        for i in range(13):
            u = i / 12
            a = a0 - u * 2.5 * math.pi
            rr = r0 * (1 - 0.74 * u)
            pts.append(c + Vector((0, -math.cos(a) * rr, math.sin(a) * rr)))
            rad.append(w * (0.62 - 0.36 * u))
        p.add(tube(pts, rad, 5), GOLD, "gold")
        p.add(sphere(0.0075, 8, 4), BUTTER, "glow", T(*c))
        p.add(limb.body(t0=0.95, t1=1.0, gx=1.1, gy=1.5, pad=0.0005, n=3), GOLD, "gold")

    def riser_fn(p):
        riser_body(p, g, 0.021, 0.0105, 0.75, K.lighter(MINT, 0.1), "pearl", sides=12)
        wrap(p, -0.05, 0.05, 0.0225, 0.0195, BLUSH, "fabric", rings=4, ring_color=ROSE)
        for sgn in (1, -1):
            for k in range(5):
                m = T(0, 0, sgn * 0.052) @ R("Z", 72 * k + (0 if sgn > 0 else 36)) @ T(0.012, 0, 0) @ R("Y", -52 * sgn)
                p.add(K.round_petal(0.034, 0.03, cup=0.5, curl=-0.1), ROSE, "pearl", m, sharp_deg=89.0,
                      shade=K._petal_rim(ROSE, 0.034, 0.03, 0.25))
            p.add(U.sweep([(0, sgn * 0.046), (0, sgn * 0.052), (0, sgn * 0.058)], [0.022, 0.0245, 0.022], [0.019, 0.0215, 0.019], 10),
                  GOLD, "gold")
        p.add(sphere(0.0085, 8, 4), (0.80, 0.55, 0.85), "glow", T(0, 0.0185, 0) @ S(1, 0.6, 1))
        p.add(torus(0.0095, 0.002, 12, 5), GOLD, "gold", T(0, 0.0185, 0) @ R("X", 90))

    return dict(g=g, limb=limb, limb_fn=limb_fn, riser_fn=riser_fn)


def sentry_warbow():
    """[X] a Spring sentry's warbow off the fells tower: heavy sage-lacquered
    limbs strapped in lilac iron with gilt rivets, iron-shod spiked tips, a
    cord-bound leather grip, the court's rose on a gilt boss, a rose tassel."""
    g = 0.10
    limb = Limb(0.70, lambda t: -0.17 * t ** 1.5, (0.0220, 0.0115), (0.0185, 0.0095), n=20)
    rng = random.Random(7304)
    lacquer = U.grain(SAGE_DEEP, 0.12, 60.0)

    def limb_fn(p, top):
        p.add(limb.body(), SAGE_DEEP, "satin", shade=lacquer)
        p.add(limb.body(t0=0.0, t1=0.9, gx=0.5, gy=0.4, off=-0.74, sides=6, n=10), K.SAGE, "satin")
        for (a, b) in ((0.05, 0.13), (0.36, 0.42), (0.63, 0.68)):
            p.add(limb.body(t0=a, t1=b, gx=1.1, gy=1.1, pad=0.0012, n=2), IRON, "mirror")
            for t in (a + 0.018, b - 0.018):
                p.add(sphere(0.0034, 6, 4), GOLD, "gold", limb.on_back(t, 1.16))
        p.add(limb.body(t0=0.88, t1=1.0, gx=1.12, gy=1.12, pad=0.0012, n=3), IRON, "mirror")
        p.add(limb.body(t0=0.945, t1=0.962, gx=1.35, gy=1.35, pad=0.001, n=2), IRON_DARK, "satin")
        p.add(lathe([(0.0105, 0.0), (0.0085, 0.012), (0.004, 0.04), (0.0, 0.062)], 8), IRON, "mirror", limb.frame(1.0))
        if not top:
            a = limb.pos(0.09) + Vector((0.024, 0, 0))
            p.add(tube([a, a + Vector((0.012, 0.004, 0.02)), a + Vector((0.016, 0.006, 0.06)), a + Vector((0.014, 0.004, 0.10))],
                       0.0022, 5), ROSE, "fabric")
            # (bottom limb is mirrored, so +Z here hangs down in the finished bow)
            e = a + Vector((0.014, 0.004, 0.10))
            p.add(sphere(0.007, 8, 5), GOLD, "gold", T(*e))
            p.add(lathe([(0.006, 0.0), (0.012, 0.02), (0.014, 0.07), (0.009, 0.075)], 10), ROSE, "fabric", T(*e),
                  shade=lambda co: K.mix(ROSE, BLUSH, max(0.0, min(1.0, co.z / 0.07))))

    def riser_fn(p):
        riser_body(p, g, 0.022, 0.0185, 0.16, SAGE_DEEP, shade=lacquer, sides=10)
        wrap(p, -0.065, 0.065, 0.0262, 0.0225, OAK_DARK, "fabric")
        for ph in (0.0, math.pi):
            pts = [(math.cos(ph + 4 * 2 * math.pi * i / 24 * (1 if ph == 0 else -1)) * 0.0272,
                    math.sin(ph + 4 * 2 * math.pi * i / 24 * (1 if ph == 0 else -1)) * 0.0235,
                    -0.062 + 0.124 * i / 24) for i in range(25)]
            p.add(tube(pts, 0.002, 3), STRAW, "fabric")
        for z in (-0.074, 0.074):
            p.add(U.sweep([(0, z - 0.008), (0, z), (0, z + 0.008)], [0.0245, 0.027, 0.0245], [0.021, 0.0235, 0.021], 12), IRON, "mirror")
        p.add(lathe([(0.020, 0.0), (0.018, 0.004), (0.006, 0.006), (0.0, 0.006)], 14), GOLD, "gold", T(0, 0.0225, 0) @ TIP_FORWARD)
        K.soft_rose(p, T(0, 0.0265, 0) @ TIP_FORWARD, 0.0135, ROSE, "pearl", rng)
        for k in range(5):
            p.add(K.leaf(0.016, 0.007), GOLD, "gold", T(0, 0.0275, 0) @ TIP_FORWARD @ R("Z", 72 * k + 36) @ T(0.011, 0, 0))

    return dict(g=g, limb=limb, limb_fn=limb_fn, riser_fn=riser_fn)


def gilded_bow():
    """[X] the gilded bow (P6, tied to her painting and to Tamlin's gifts):
    gold limbs with a pearl back, her palette in enamel drops up each limb,
    roses and leaves at the grip, rosebud tips with a pearl drop."""
    g = 0.09
    limb = Limb(0.63, lambda t: -0.2458 * t * t + 0.20 * t ** 6, (0.0180, 0.0080), (0.0120, 0.0060), n=20)
    rng = random.Random(7305)
    paints = [ROSE, BUTTER, MINT, PERI, LILAC]

    def limb_fn(p, top):
        p.add(limb.body(), GOLD, "gold")
        p.add(limb.body(t0=0.04, t1=0.9, gx=0.5, gy=0.45, off=-0.72, sides=6, n=10), PEARL, "pearl")
        for k, col in enumerate(paints if top else paints[::-1]):
            t = 0.2 + 0.12 * k
            p.add(sphere(limb.wx(t) * 0.42, 6, 4), col, "pearl", limb.on_back(t, 1.08) @ S(1.5, 1, 0.5))
        for t in (0.13, 0.86):
            p.add(limb.body(t0=t - 0.008, t1=t + 0.008, gx=1.18, gy=1.25, pad=0.0006, n=2), K.GOLD_DEEP, "gold")
        K.rose_bud(p, limb.frame(1.0) @ T(0, 0, -0.002), 0.014, BLUSH, "pearl", rng, fine=True)
        for k in range(4):
            p.add(K.leaf(0.02, 0.008), GOLD, "gold", limb.frame(0.985) @ R("Z", 90 * k) @ T(0.004, 0, 0) @ R("Y", -55))
        d = limb.pos(0.965) + limb.nrm(0.965) * 0.008
        p.add(tube([d, d + Vector((0, -0.004, -0.014 if top else 0.014))], 0.0009, 4), GOLD, "gold")
        p.add(sphere(0.0058, 8, 4), PEARL, "pearl", T(*(d + Vector((0, -0.004, -0.019 if top else 0.019)))))

    def riser_fn(p):
        riser_body(p, g, 0.018, 0.012, 0.6, GOLD, "gold", sides=12)
        wrap(p, -0.05, 0.05, 0.0222, 0.0188, CREAM, "fabric", rings=5, ring_color=GOLD, ring_finish="gold")
        for sgn, col, r in ((1, ROSE, 0.021), (-1, BLUSH, 0.018)):
            z = sgn * 0.078
            K.layered_rose(p, T(0, 0.014, z) @ TIP_FORWARD, r, col, "pearl", rng, cupped=True)
            for a in (35, 145, 215, 325):
                p.add(K.leaf(0.03, 0.013), MINT, "leaf", T(0, 0.013, z) @ TIP_FORWARD @ R("Z", a) @ T(r * 0.6, 0, 0) @ R("Y", 12))
            for side in (1, -1):
                p.add(K.scroll(0.017, 1.3, 8, 0.0028), GOLD, "gold",
                      T(side * 0.026, 0.002, z + sgn * 0.03) @ S(side, 1, sgn))
        p.add(sphere(0.008, 8, 4), (0.85, 0.50, 0.66), "glow", T(0, 0.0195, 0) @ S(1, 0.6, 1.3))
        p.add(torus(0.0105, 0.0022, 14, 5), GOLD, "gold", T(0, 0.0195, 0) @ S(1, 1, 1.3) @ R("X", 90))

    return dict(g=g, limb=limb, limb_fn=limb_fn, riser_fn=riser_fn)


BOWS = {
    "bow_hunting_bow": hunting_bow,
    "bow_yew_longbow": yew_longbow,
    "bow_fae_recurve": fae_recurve,
    "bow_sentry_warbow": sentry_warbow,
    "bow_gilded_bow": gilded_bow,
}


def build_bow(pid):
    spec = BOWS[pid]()
    g, limb = spec["g"], spec["limb"]
    root = bpy.data.objects.new(pid, None)
    bpy.context.scene.collection.objects.link(root)
    parts = []
    pr = U.Prop(pid + "_riser")
    spec["riser_fn"](pr)
    riser = pr.to_object(pid + "_riser")
    parts.append(riser)
    tips = {}
    for name, top in (("top", True), ("bottom", False)):
        pl = U.Prop(f"{pid}_limb_{name}")
        spec["limb_fn"](pl, top)
        if not top:
            pl.mirror_z()
        ob = pl.to_object(f"{pid}_limb_{name}")
        ob.location = (0, 0, g if top else -g)
        tip = bpy.data.objects.new(f"{pid}_tip_{name}", None)
        bpy.context.scene.collection.objects.link(tip)
        tp = limb.pos(0.962)
        tip.location = (0, tp.y, tp.z if top else -tp.z)
        tip.parent = ob
        tips[name] = (0.0, round(tp.y, 4), round((g + tp.z) * (1 if top else -1), 4))
        parts.append(ob)
        parts.append(tip)
    for o in parts:
        if o.parent is None:
            o.parent = root
    meshes = [o for o in parts if o.type == "MESH"]
    lo = U.merged_lod(meshes, pid + "_lod1", 0.5)
    info = dict(kind="bow", half_length=round(g + limb.L, 4), grip_half=g,
                tip_top=tips["top"], tip_bottom=tips["bottom"])
    return [root] + parts + [lo], meshes, lo, info


# ------------------------------------------------------------------ arrows


def fletched_tail(p, M, r, shaft, fletch, vl=0.10, vh=0.018, bind=None):
    """Nock at the local origin, the shaft running up +Z: the nock, three
    curved vanes and the thread bindings at each end of them."""
    p.add(lathe([(r * 0.9, 0.0), (r * 1.25, 0.003), (r * 1.2, 0.011), (r * 1.0, 0.014)], 8), K.darker(shaft, 0.35), "satin", M)
    z0 = 0.022
    out = [(r * 0.5, z0), (r * 0.5, z0 + vl), (r + vh * 0.30, z0 + vl * 0.93), (r + vh * 0.78, z0 + vl * 0.62),
           (r + vh, z0 + vl * 0.30), (r + vh * 0.86, z0 + vl * 0.04)]
    for k in range(3):
        p.add(U.slab(out, 0.0013), fletch, "fabric", M @ R("Z", 120 * k + 90),
              shade=lambda co: K.mix(K.darker(fletch, 0.18), fletch, max(0.0, min(1.0, (co.x - r) / vh * 1.6))))
    bind = bind or K.darker(fletch, 0.3)
    for z in (z0 - 0.004, z0 + vl + 0.004):
        p.add(lathe([(r * 1.0, -0.004), (r * 1.3, -0.002), (r * 1.3, 0.002), (r * 1.0, 0.004)], 8, False, False), bind, "fabric", M @ T(0, 0, z))


def shaft_to(p, M, r, z1, color, z0=0.012):
    p.add(lathe([(r * 0.92, z0), (r, z0 + 0.1), (r, z1 - 0.05), (r * 0.9, z1)], 8), color, "satin", M, shade=U.grain(color, 0.12, 140.0))


def leaf_head(p, M, zb, hl, w, r, color, finish="mirror", ridge=False):
    """A forged leaf-blade head on a socket, base at zb, point at zb + hl."""
    p.add(lathe([(r * 1.25, -0.022), (r * 1.3, -0.004), (r * 1.05, 0.004)], 8), K.darker(color, 0.15), finish, M @ T(0, 0, zb))
    prof = [(r * 1.0, 0.0), (w * 0.34, hl * 0.14), (w * 0.5, hl * 0.34), (w * 0.4, hl * 0.6), (w * 0.16, hl * 0.86), (0.0, hl)]
    p.add(lathe(prof, 10, cap_bottom=True), color, finish, M @ T(0, 0, zb) @ S(0.26, 1, 1), sharp_deg=70.0)
    if ridge:
        p.add(lathe([(0.0022, 0.0), (0.0016, hl * 0.7), (0.0, hl * 0.93)], 5), K.lighter(color, 0.15), finish, M @ T(0, 0, zb))


def arrow_wood(p, M):
    r, L = 0.0055, 0.83
    fletched_tail(p, M, r, SHAFT, (0.85, 0.824, 0.765))
    shaft_to(p, M, r, L - 0.065, SHAFT)
    leaf_head(p, M, L - 0.07, 0.07, 0.019, r, STEEL)
    return L


def arrow_ash(p, M):
    """[C] mountain ash with an iron head: the longest and heaviest arrow."""
    r, L = 0.0066, 0.90
    ash = (0.85, 0.82, 0.72)
    fletched_tail(p, M, r, ash, (0.545, 0.353, 0.169), vl=0.115, vh=0.021)
    shaft_to(p, M, r, L - 0.085, ash)
    for z in (L - 0.135, L - 0.125, L - 0.115):
        p.add(lathe([(r * 1.0, -0.002), (r * 1.14, 0.0), (r * 1.0, 0.002)], 8, False, False), K.darker(ash, 0.3), "satin", M @ T(0, 0, z))
    leaf_head(p, M, L - 0.09, 0.09, 0.028, r, IRON_DARK, "satin", ridge=True)
    return L


def arrow_barbed(p, M):
    r, L = 0.0055, 0.83
    fletched_tail(p, M, r, SHAFT, (0.478, 0.353, 0.227))
    shaft_to(p, M, r, L - 0.07, SHAFT)
    zb = L - 0.075
    leaf_head(p, M, zb, 0.075, 0.016, r, STEEL)
    barb = [(0.0015, 0.045), (0.0165, -0.014), (0.0125, -0.0165), (0.003, 0.012)]
    for a, s, dz in ((90, 1.0, 0.0), (270, 1.0, 0.0), (0, 0.7, -0.028), (180, 0.7, -0.028)):
        p.add(U.slab(barb, 0.0016), STEEL, "mirror", M @ T(0, 0, zb + dz) @ R("Z", a) @ S(s, 1, s))
    return L


def arrow_rope(p, M):
    """A grapnel: three hooked tines, a gilt ring and a coil of line."""
    r, L = 0.0058, 0.83
    fletched_tail(p, M, r, SHAFT, (0.788, 0.702, 0.541), vl=0.085)
    shaft_to(p, M, r, L - 0.04, SHAFT)
    zb = L - 0.065
    p.add(lathe([(r * 1.3, -0.02), (r * 1.45, 0.0), (r * 1.2, 0.03), (0.0025, 0.055), (0.0, 0.065)], 8), STEEL, "mirror", M @ T(0, 0, zb))
    for k in range(3):
        pts = [(0.004, 0, 0.03), (0.014, 0, 0.034), (0.025, 0, 0.022), (0.029, 0, 0.002), (0.025, 0, -0.014), (0.018, 0, -0.02)]
        p.add(tube(pts, [0.0034, 0.0032, 0.003, 0.0026, 0.002, 0.0008], 6), STEEL, "mirror", M @ T(0, 0, zb) @ R("Z", 120 * k + 60))
    p.add(torus(0.0105, 0.0022, 12, 5), GOLD, "gold", M @ T(0.0, 0.012, zb - 0.03) @ R("Y", 90))
    rope = (0.80, 0.70, 0.52)
    coil = [(math.cos(i * 0.6) * (r + 0.0042), math.sin(i * 0.6) * (r + 0.0042), zb - 0.045 - i * 0.0011) for i in range(64)]
    tail = [coil[-1], (0.013, 0.004, zb - 0.135), (0.02, -0.006, zb - 0.2), (0.012, -0.012, zb - 0.27), (0.022, -0.004, zb - 0.33),
            (0.03, 0.006, zb - 0.37)]
    p.add(tube([(0.0, 0.012, zb - 0.04)] + coil + tail[1:], 0.0034, 5), rope, "fabric", M)
    p.add(sphere(0.0052, 8, 5), K.darker(rope, 0.2), "fabric", M @ T(0.03, 0.006, zb - 0.372))
    return L


def arrow_signal(p, M):
    """A whistling head: a pierced gilt bulb that shrieks in flight, trailing
    two coral streamers so the sentries can follow it."""
    r, L = 0.0055, 0.83
    coral = (0.85, 0.365, 0.227)
    fletched_tail(p, M, r, SHAFT, coral)
    shaft_to(p, M, r, L - 0.06, SHAFT)
    zb = L - 0.07
    p.add(lathe([(r * 1.2, -0.012), (r * 1.3, 0.0), (0.0125, 0.012), (0.0150, 0.028), (0.0118, 0.046), (0.0055, 0.058),
                 (0.003, 0.064), (0.0, 0.07)], 12), GOLD, "gold", M @ T(0, 0, zb))
    for k in range(4):
        p.add(sphere(0.0042, 8, 5), IRON_DARK, "matte", M @ T(0, 0, zb + 0.03) @ R("Z", 90 * k + 45) @ T(0.0138, 0, 0) @ S(0.45, 1, 1.5))
    p.add(lathe([(0.0128, 0.0), (0.0142, 0.002), (0.0128, 0.004)], 12, False, False), K.GOLD_DEEP, "gold", M @ T(0, 0, zb + 0.012))
    for k, (ln, ph) in enumerate(((0.26, 0.0), (0.2, 1.7))):
        path = [(r + 0.002 + 0.012 * math.sin(ph + u * 7.0) * u + 0.02 * u, zb - 0.014 - ln * u) for u in [i / 12 for i in range(13)]]
        p.add(U.ribbon(path, 0.012), coral if k == 0 else BUTTER, "fabric", M @ R("Z", 180 * k + 30))
    return L


STEEPS = {
    # kind: (liquid, fletching, wax)
    "sleep": ((0.62, 0.52, 0.85), (0.604, 0.514, 0.788), (0.45, 0.36, 0.62)),
    "lure": ((0.85, 0.62, 0.36), (0.85, 0.71, 0.831), (0.80, 0.42, 0.55)),
    "fire": ((0.85, 0.42, 0.16), (0.85, 0.416, 0.106), (0.70, 0.22, 0.14)),
    "frost": ((0.60, 0.82, 0.85), (0.655, 0.847, 0.85), (0.42, 0.60, 0.78)),
    "light": ((0.85, 0.82, 0.55), (0.85, 0.85, 0.69), (0.80, 0.68, 0.36)),
}


def steeped(kind):
    liquid, fletch, wax = STEEPS[kind]

    def build(p, M):
        """A steeped arrow: a little glass phial of the brew bound to the shaft
        behind a wax-sealed point, with its own token so it reads by silhouette."""
        r, L = 0.0055, 0.83
        fletched_tail(p, M, r, SHAFT, fletch)
        shaft_to(p, M, r, L - 0.07, SHAFT)
        zb = L - 0.085
        Mh = M @ T(0, 0, zb)
        for z in (-0.016, -0.010, -0.004):
            p.add(lathe([(r * 1.0, -0.003), (r * 1.4, 0.0), (r * 1.0, 0.003)], 8, False, False), CREAM, "fabric", Mh @ T(0, 0, z))
        p.add(lathe([(r * 1.1, 0.0), (0.0098, 0.008), (0.0122, 0.024), (0.0098, 0.042), (0.0058, 0.05)], 12, True, False),
              (*liquid, 0.4), "glass", Mh)
        p.add(lathe([(0.0, 0.003), (0.0078, 0.010), (0.0098, 0.024), (0.0078, 0.037), (0.0, 0.04)], 10), liquid, "glow", Mh)
        p.add(lathe([(0.0066, 0.047), (0.0078, 0.052), (0.0062, 0.058), (0.0030, 0.072), (0.0, 0.085)], 10), wax, "satin", Mh)
        if kind == "fire":
            for k in range(3):
                p.add(K.round_petal(0.03, 0.013, cup=0.5, curl=0.3, fine=True), (0.85, 0.55, 0.2), "glow",
                      Mh @ T(0, 0, 0.05) @ R("Z", 120 * k) @ T(0.005, 0, 0) @ R("Y", -74), sharp_deg=89.0)
        elif kind == "frost":
            for k in range(5):
                p.add(lathe([(0.0, 0.0), (0.0028, 0.006), (0.0, 0.026)], 4), (0.72, 0.85, 0.85), "pearl",
                      Mh @ T(0, 0, 0.045) @ R("Z", 72 * k) @ T(0.007, 0, 0) @ R("Y", 48), sharp_deg=20.0)
        elif kind == "light":
            for k in range(6):
                p.add(lathe([(0.0, 0.0), (0.002, 0.004), (0.0, 0.017)], 4), BUTTER, "glow",
                      Mh @ T(0, 0, 0.024) @ R("Z", 60 * k) @ T(0.0118, 0, 0) @ R("Y", 90), sharp_deg=20.0)
        elif kind == "sleep":
            K.star_flower(p, (0, 0, 0), 0.021, LILAC, 6, "fabric", (0.36, 0.28, 0.5), facing=Mh @ T(0, 0, -0.001))
        elif kind == "lure":
            K.star_flower(p, (0, 0, 0), 0.02, ROSE, 5, "fabric", BUTTER, facing=Mh @ T(0, 0, -0.001))
            p.add(sphere(0.0038, 8, 5), (0.85, 0.62, 0.25), "pearl", Mh @ T(0.0128, 0, 0.016) @ S(1, 1, 1.5))
        return L
    return build


ARROWS = {
    "arrow_wood": arrow_wood, "arrow_ash": arrow_ash, "arrow_barbed": arrow_barbed, "arrow_rope": arrow_rope,
    "arrow_signal": arrow_signal, "arrow_sleep": steeped("sleep"), "arrow_lure": steeped("lure"),
    "arrow_fire": steeped("fire"), "arrow_frost": steeped("frost"), "arrow_light": steeped("light"),
}


# ------------------------------------------------------------------ quivers


def _quiver_arrows(p, n, mouth_r, z, shaft, fletch, rng):
    for k in range(n):
        a = 2 * math.pi * k / n + rng.uniform(-0.2, 0.2)
        rr = mouth_r * rng.uniform(0.25, 0.62)
        M = T(math.cos(a) * rr, math.sin(a) * rr, z + rng.uniform(0.09, 0.14)) @ R("Z", rng.uniform(0, 120)) \
            @ R("X", 180 + rng.uniform(-5, 5)) @ R("Y", rng.uniform(-5, 5))
        fletched_tail(p, M, 0.0055, shaft, fletch, vl=0.085)
        p.add(lathe([(0.0055, 0.012), (0.0055, 0.16)], 6, False, False), shaft, "satin", M)


def quiver_hunting(p):
    """[C]-plain: her worn hide quiver, patched, on a strap, half full."""
    rng = random.Random(7311)
    hide = (0.55, 0.36, 0.30)
    body = [(0.034, 0.0), (0.043, 0.012), (0.047, 0.05), (0.052, 0.25), (0.058, 0.455), (0.061, 0.47), (0.057, 0.475), (0.053, 0.455)]
    p.add(lathe(body, 14, True, False), hide, "fabric",
          shade=lambda co: K.mix(K.darker(hide, 0.22), hide, 0.5 + 0.5 * math.sin(co.z * 31.0 + co.x * 60.0)))
    p.add(K.disc(0.053, 14, 0.44), K.darker(hide, 0.6), "matte")
    for z in (0.06, 0.40):
        rz = 0.047 + (0.058 - 0.047) * (z - 0.05) / 0.4
        p.add(torus(rz + 0.002, 0.004, 16, 5), K.darker(hide, 0.3), "fabric", T(0, 0, z))
    # a sewn patch and its stitches
    p.add(K.cushion(0.05, 0.012, 0.06, puff=0.2), (0.66, 0.50, 0.40), "fabric", T(0.0, 0.052, 0.2) @ R("X", 1.5))
    for k in range(6):
        for sx in (-0.022, 0.022):
            p.add(sphere(0.0022, 6, 4), STRAW, "fabric", T(sx, 0.058, 0.176 + 0.0096 * k))
    # the strap, looping out behind
    strap = [(0.0, -0.05, 0.42), (0.0, -0.085, 0.44), (0.0, -0.125, 0.36), (0.0, -0.13, 0.22), (0.0, -0.10, 0.10), (0.0, -0.05, 0.06)]
    p.add(tube(strap, 0.0075, 6), K.darker(hide, 0.25), "fabric", S(1.9, 1, 1))
    p.add(torus(0.011, 0.0022, 10, 5), IRON, "mirror", T(0, -0.13, 0.27) @ R("Y", 90))
    _quiver_arrows(p, 5, 0.05, 0.44, SHAFT, (0.85, 0.824, 0.765), rng)


def quiver_spring(p):
    """[X] a Spring Court quiver: rose leather, gilt mouth and foot, a ring of
    pearls, a rose in leaf on its face, a blush tassel and strap."""
    rng = random.Random(7312)
    leather = (0.80, 0.50, 0.56)
    body = [(0.030, 0.0), (0.040, 0.01), (0.043, 0.05), (0.046, 0.25), (0.055, 0.43), (0.064, 0.485), (0.060, 0.49), (0.054, 0.46)]
    p.add(lathe(body, 14, True, False), leather, "satin",
          shade=lambda co: K.mix(K.darker(leather, 0.14), K.lighter(leather, 0.06), max(0.0, min(1.0, co.z / 0.49))))
    p.add(K.disc(0.054, 16, 0.45), K.darker(leather, 0.6), "matte")
    p.add(lathe([(0.0555, 0.43), (0.0595, 0.44), (0.0665, 0.485), (0.0660, 0.495), (0.0600, 0.495)], 16, False, False), GOLD, "gold")
    p.add(lathe([(0.0, -0.012), (0.022, -0.008), (0.0325, 0.0), (0.0425, 0.012), (0.0455, 0.05), (0.0445, 0.056)], 16, True, False), GOLD, "gold")
    for k in range(12):
        a = 2 * math.pi * k / 12
        p.add(sphere(0.0048, 6, 4), PEARL, "pearl", T(math.cos(a) * 0.0572, math.sin(a) * 0.0572, 0.415))
    for z, rr in ((0.14, 0.0445), (0.33, 0.0505)):
        p.add(torus(rr + 0.0012, 0.0028, 14, 4), GOLD, "gold", T(0, 0, z))
    K.layered_rose(p, T(0, 0.0505, 0.235) @ TIP_FORWARD, 0.03, ROSE, "pearl", rng, fine=True, cupped=True)
    for a in (20, 160, 200, 340, 270):
        p.add(K.leaf(0.042, 0.018), MINT, "leaf", T(0, 0.049, 0.235) @ TIP_FORWARD @ R("Z", a) @ T(0.02, 0, 0) @ R("Y", 14))
    for side in (1, -1):
        p.add(K.scroll(0.02, 1.3, 9, 0.003), GOLD, "gold", T(side * 0.02, 0.05, 0.17) @ S(side, 1, -1))
    strap = [(0.0, -0.055, 0.44), (0.0, -0.09, 0.47), (0.0, -0.135, 0.38), (0.0, -0.14, 0.23), (0.0, -0.105, 0.10), (0.0, -0.045, 0.05)]
    p.add(tube(strap, 0.0075, 6), BLUSH, "fabric", S(1.9, 1, 1))
    p.add(torus(0.012, 0.0024, 12, 5), GOLD, "gold", T(0, -0.14, 0.29) @ R("Y", 90))
    t0 = Vector((0.058, 0.0, 0.43))
    p.add(tube([t0, t0 + Vector((0.016, 0.0, -0.02)), t0 + Vector((0.02, 0.0, -0.07))], 0.002, 5), GOLD, "gold")
    e = t0 + Vector((0.02, 0.0, -0.07))
    p.add(sphere(0.007, 8, 5), GOLD, "gold", T(*e))
    p.add(lathe([(0.009, -0.075), (0.014, -0.07), (0.012, -0.02), (0.006, 0.0)], 10), BLUSH, "fabric", T(*e),
          shade=lambda co: K.mix(ROSE, BLUSH, max(0.0, min(1.0, -co.z / 0.07))))
    _quiver_arrows(p, 4, 0.052, 0.45, (0.72, 0.56, 0.42), (0.85, 0.66, 0.76), rng)


def arrow_bundle(p):
    """A pickup: five wood arrows tied with a blush ribbon, lying on the ground."""
    rng = random.Random(7313)
    for k in range(5):
        x = (k - 2) * 0.014
        z = 0.022 + (0.011 if k % 2 else 0.0)
        M = T(x, -0.4 + rng.uniform(-0.02, 0.02), z) @ R("Z", (k - 2) * 1.6) @ TIP_FORWARD @ R("Z", rng.uniform(0, 120))
        arrow_wood(p, M)
    band = [(math.cos(2 * math.pi * i / 16) * 0.042, 0.0, 0.028 + math.sin(2 * math.pi * i / 16) * 0.024) for i in range(16)]
    p.add(tube(band, 0.003, 6, closed=True), BLUSH, "fabric", S(1, 4.5, 1))
    for side in (1, -1):
        p.add(K.round_petal(0.04, 0.03, cup=0.5, curl=0.2, fine=True), BLUSH, "fabric", T(0, 0, 0.052) @ R("Z", 90 - side * 90) @ R("Y", -8),
              sharp_deg=89.0)
        p.add(U.ribbon([(0.0, 0.0), (0.012, -0.012), (0.02, -0.032), (0.032, -0.046)], 0.014), ROSE, "fabric",
              T(0, 0, 0.05) @ R("Z", 90 - side * 70))
    p.add(sphere(0.008, 8, 5), ROSE, "fabric", T(0, 0, 0.054))


SINGLES = {"quiver_hunting": quiver_hunting, "quiver_spring": quiver_spring, "arrow_bundle": arrow_bundle}


def build_single(pid):
    p = U.Prop(pid)
    info = {}
    if pid in ARROWS:
        length = ARROWS[pid](p, ID)
        p.transform(TIP_FORWARD)
        info = dict(kind="arrow", length=length)
    else:
        SINGLES[pid](p)
        info = dict(kind="quiver" if pid.startswith("quiver") else "pickup")
    ob, lo = U.finish_single(p, pid)
    return [ob, lo], [ob], lo, info


ALL = list(BOWS) + list(ARROWS) + list(SINGLES)


def build(pid):
    return build_bow(pid) if pid in BOWS else build_single(pid)


def sheet(out_dir):
    """Three look tiles: the bow ladder with the quivers, the arrows, the heads."""
    os.makedirs(out_dir, exist_ok=True)
    K.reset()
    bows, others = [], []
    for i, pid in enumerate(BOWS):
        objs, meshes, lo, _ = build_bow(pid)
        lo.hide_render = True
        objs[0].location = (-i * 0.42, 0, 0)
        objs[0].rotation_euler = (0, 0, math.radians(58))
        bows += meshes
    for i, pid in enumerate(SINGLES):
        objs, meshes, lo, _ = build_single(pid)
        lo.hide_render = True
        meshes[0].location = (-2.15 - i * 0.3, 0, -0.86)
        meshes[0].rotation_euler = (0, 0, math.radians(-30 if i < 2 else 80))
        if i == 2:
            meshes[0].location = (-2.3, 0.75, -0.868)
        others += meshes
    U.preview_materials()
    U.studio(ground_z=-0.87)
    U.shot(bows + others, os.path.join(out_dir, "arms_bows_quivers.png"), 2400, 1500, 0, 7)
    for o in bows + others:
        o.hide_render = True
    arrows = []
    for i, pid in enumerate(ARROWS):
        objs, meshes, lo, info = build_single(pid)
        lo.hide_render = True
        meshes[0].location = (0, info["length"], 5.0 - i * 0.062)
        arrows += meshes
    U.preview_materials()
    U.shot(arrows, os.path.join(out_dir, "arms_arrows.png"), 2400, 1500, 90, 0, pad=1.04)
    lo, hi = U.bounds(arrows)
    U.shot(arrows, os.path.join(out_dir, "arms_arrow_heads.png"), 800, 1500, 90, 0, pad=1.0,
           box=(Vector((lo.x, hi.y - 0.3, lo.z)), hi))


def main():
    args = sys.argv[1:]
    if "--sheet" in args:
        sheet(args[args.index("--sheet") + 1])
        return
    only = set(args[args.index("--only") + 1].split(",")) if "--only" in args else None
    rows, over = [], []
    print(f"  {'id':22s} {'lod0':>6s} {'lod1':>6s} {'bytes':>8s} {'albedo':>6s}  size (x, y, z)")
    for pid in ALL:
        if only and pid not in only:
            continue
        K.reset()
        objs, meshes, lo, info = build(pid)
        n0, n1 = sum(K.mesh_tris(m) for m in meshes), K.mesh_tris(lo)
        alb = max(U.max_albedo(m) for m in meshes)
        blo, bhi = U.bounds(meshes)
        path = os.path.join(OUT, pid + ".glb")
        K.export_glb(objs, path)
        size = os.path.getsize(path)
        ext = [round(v, 3) for v in (bhi - blo)]
        print(f"  {pid:22s} {n0:6d} {n1:6d} {size:8d} {alb:6.3f}  {ext}")
        rows.append(dict(id=pid, file=pid + ".glb", tris=n0, tris_lod1=n1, bytes=size, size_m=ext, **info))
        if n0 > U.MAX_PROP_TRIS or alb > U.ALBEDO_CAP + 0.005:
            over.append(pid)
    if not only:
        U.write_manifest(os.path.join(OUT, "arms_manifest.json"), rows)
    if over:
        print("OVER BUDGET:", ", ".join(over))
        sys.exit(1)


if __name__ == "__main__":
    main()
