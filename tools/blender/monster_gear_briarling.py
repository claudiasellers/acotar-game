"""Briarling trophies and camp gear (lane L88; monster-gear.md §2.3).

Thorn-folk carry nothing: what they leave is grown, not made. Dark glossy
thorn with rose-red tips, living briar, and the court's own roses pulled up
and left to wilt. See monster_gear.py for the contract.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import bmesh  # noqa: E402,F401
from mathutils import Vector  # noqa: E402
import monster_gear_kit as G  # noqa: E402
import prop_kit as K  # noqa: E402
import upcoming_kit as U  # noqa: E402
from monster_gear_kit import R, S, T, h1, wob  # noqa: E402

THORN_TIP = (0.62, 0.12, 0.16)
CANE = G.grim(0.24, 0.27, 0.13)
CANE_RED = G.grim(0.34, 0.14, 0.13)
LEAF = G.grim(0.20, 0.32, 0.14)
LEAF_WILT = G.grim(0.36, 0.31, 0.15)
ROOT = G.grim(0.26, 0.19, 0.14)
EARTH = G.grim(0.17, 0.13, 0.10)
POD = G.grim(0.27, 0.25, 0.12)
POD_FLESH = (0.55, 0.16, 0.20)


def _thorn(p, m, ln, r, curve=0.3, red=True, sides=5):
    shade = (lambda co: K.mix(G.THORN, THORN_TIP, U._smooth(ln * 0.45, ln, co.z))) if red else None
    p.add(G.fang(ln, r, curve, sides, 4), G.THORN, "pearl", m, shade=shade)


def _along(pts, i):
    a, b = Vector(pts[max(i - 1, 0)]), Vector(pts[min(i + 1, len(pts) - 1)])
    return (b - a).normalized()


def _thorns_on(p, pts, every, ln, r, seed, skip=0.0, leaves=0.0, leaf_col=LEAF):
    """Thorns (and leaves) round a cane's points, standing off it."""
    for i in range(1, len(pts) - 1, every):
        if h1(i, seed) < skip:
            continue
        tg = _along(pts, i)
        side = tg.cross(Vector((1, 0, 0)))
        if side.length < 0.1:
            side = tg.cross(Vector((0, 1, 0)))
        side.normalize()
        q = side.copy()
        q.rotate(__import__("mathutils").Quaternion(tg, 2.4 * i + 6.28 * h1(i, seed + 1)))
        d = (q + tg * 0.35).normalized()
        m = T(*pts[i]) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        _thorn(p, m, ln * (0.7 + 0.6 * h1(i, seed + 2)), r)
        if h1(i, seed + 3) < leaves:
            d2 = (-q + tg * 0.5).normalized()
            m2 = T(*pts[i]) @ d2.to_track_quat("X", "Z").to_matrix().to_4x4()
            for k in (-1, 0, 1):                     # a rose leaf: three leaflets
                p.add(K.leaf(ln * 2.2, ln * 1.3), leaf_col, "leaf", m2 @ R("Z", 38 * k) @ T(ln * 0.6, 0, 0))


# ================================================================== weapons


def thorn_whip(p, worn):
    """Thorn Whip: a living briar cane, still leafing, its thorns rose-red at
    the tips, a knot of root for a grip."""
    n = 26 if not worn else 21                       # the worn one has lost its lash end
    pts, rad = [], []
    for i in range(27):
        t = i / 26
        pts.append((0.012 * math.sin(t * 9.0), 0.36 * t ** 2.3 + 0.012 * math.sin(t * 13.0), 0.05 + 1.44 * t - 0.14 * t ** 3))
        rad.append(0.0105 * (1.0 - t) ** 0.8 + 0.0016)
    pts, rad = pts[:n + 1], rad[:n + 1]
    p.add(K.tube(pts, rad, 6), CANE, "satin", shade=lambda co: K.mix(CANE_RED, CANE, U._smooth(0.1, 0.9, 0.5 + 0.5 * math.sin(co.z * 21.0))))
    _thorns_on(p, pts, 1, 0.022, 0.0042, 3.0, 0.25 if worn else 0.0, 0.12 if worn else 0.42, LEAF_WILT if worn else LEAF)
    knot = G.stone(0.03, 5.5, 1.5, 2)                # the root knot, long enough for a fist
    p.add(knot, ROOT, "matte", T(0, 0, -0.005) @ S(0.8, 0.9, 1.6), shade=G.mottle(ROOT, G.BOGWOOD, 70.0, 2.0, K.lighter(ROOT, 0.2)))
    for i in range(5):                               # rootlets off its end
        a = 2 * math.pi * i / 5
        tp = [(0.012 * math.cos(a), 0.012 * math.sin(a), -0.06), (0.03 * math.cos(a), 0.03 * math.sin(a), -0.10 - 0.02 * h1(i)),
              (0.035 * math.cos(a + 0.6), 0.035 * math.sin(a + 0.6), -0.15 - 0.03 * h1(i, 2.0))]
        p.add(K.tube(tp, [0.006, 0.0035, 0.001], 4), ROOT, "matte")
    if worn:
        G.crack(p, (0.019, 0.008, -0.05), (0.02, -0.004, 0.04), 2.0, 0.0015)
        p.add(U.sphere(0.004, 5, 4), K.lighter(CANE, 0.45), "matte", T(*pts[-1]))       # the pale snapped end
    tip = pts[-1]
    return dict(tip=tuple(tip), imbue=tuple(pts[len(pts) * 2 // 3]), hands=1, kind="whip")


def rose_shiv(p, worn):
    """Rosebriar Shiv: the single long heart-thorn from its core, dark and
    glossy, its root wrapped in a rose leaf."""
    ln = 0.185 if not worn else 0.15
    shade = lambda co: K.mix(K.mix(G.THORN, (0.07, 0.03, 0.04), U._smooth(0.0, 0.08, co.z)), THORN_TIP, U._smooth(ln * 0.7, ln, co.z))   # noqa: E731
    th = G.fang(ln, 0.0135, 0.10, 8, 9)
    p.add(th, G.THORN, "pearl", T(0, -0.004, 0.045) @ S(0.62, 1.0, 1.0), shade=shade)
    p.add(K.lathe([(0.0, -0.062), (0.011, -0.055), (0.0125, -0.02), (0.0118, 0.03), (0.0145, 0.05), (0.011, 0.06)], 8), ROOT, "matte", S(0.85, 1.05, 1.0),
          shade=G.mottle(ROOT, G.THORN, 150.0, 1.0))
    wrap = K.lathe([(0.0135, -0.045), (0.015, -0.01), (0.0145, 0.03), (0.016, 0.046)], 10, cap_bottom=False, cap_top=False)        # the leaf rolled round it
    leaf = LEAF_WILT if worn else LEAF
    p.add(wrap, leaf, "leaf", S(0.9, 1.08, 1.0), shade=lambda co: K.mix(leaf, K.darker(leaf, 0.35), max(0.0, math.sin(co.z * 420 + math.atan2(co.y, co.x) * 3)) * 0.7))
    p.add(K.leaf(0.045, 0.026), leaf, "leaf", T(0.008, 0.012, 0.045) @ R("Y", -62) @ R("Z", 40))                                   # its tip curling free
    p.add(G.lash(0.016, -0.03, 0.035, 3.2, 0.0022, 3, 1.1), CANE_RED, "satin")                                                     # a tendril tying it
    if worn:
        G.crack(p, (0.0052, 0.002, 0.07), (0.004, 0.008, 0.14), 2.0, 0.001, color=(0.5, 0.3, 0.3))
    return dict(tip=(0, 0.014, 0.045 + ln), imbue=(0, 0.006, 0.12), hands=1, kind="knife")


# ================================================================== camp gear


def _pod(p, m, r, seed, split):
    """A swollen thorny pod, point up, its seam facing -Y; split 0..1 opens it."""
    bm = U.sphere(r, 12, 9)
    for v in bm.verts:
        q = v.co
        k = min(max((q.z + r) / (2 * r), 0.0), 1.0)
        s = 0.72 + 0.5 * math.sin(math.pi * k ** 0.8) - 0.3 * k ** 4
        q.x *= s * (1 + 0.06 * wob(q.z * 22 + seed, seed))
        q.y *= s
        q.z = (q.z + r) * 1.25
        if q.y < -r * 0.25 and abs(q.x) < r * 0.3:  # the seam sinks in
            q.y += r * 0.2 * split * (1 - abs(q.x) / (r * 0.3))
    p.add(bm, POD, "satin", m, shade=lambda co: K.mix(K.mix(POD, G.THORN, 0.5 + 0.5 * math.sin(math.atan2(co.y, co.x) * 7)), POD_FLESH,
                                                      U._smooth(0.18, 0.02, abs(co.x) / r) * (1.0 if co.y < 0 else 0.0) * split))
    if split > 0.3:                                  # the red inside showing through the seam
        p.add(U.sphere(r * 0.5, 7, 6), POD_FLESH, "pearl", m @ T(0, -r * 0.42, r * 1.2) @ S(0.22 * split + 0.05, 0.5, 1.5))
    for i in range(11):
        a = 2 * math.pi * h1(i, seed) + 0.6
        if abs(math.sin(a / 2 - math.pi * 0.75)) < 0.2:
            continue
        zz = r * (0.5 + 1.6 * h1(i, seed + 1))
        k = zz / (2.5 * r)
        rr = r * (0.72 + 0.5 * math.sin(math.pi * k ** 0.8) - 0.3 * k ** 4)
        d = Vector((math.cos(a), math.sin(a), 0.3)).normalized()
        _thorn(p, m @ T(rr * math.cos(a) * 0.95, rr * math.sin(a) * 0.95, zz) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4(), r * 0.34, r * 0.07, 0.3, True, 4)
    p.add(G.fang(r * 0.5, r * 0.09, 0.4, 5, 4), G.THORN, "pearl", m @ T(0, 0, r * 2.42))                 # the dried style at its point


def seedpods(p):
    """Seed-pod cluster: three swollen thorny pods on a root, each the size of
    a melon, splitting along a seam."""
    crown = G.stone(0.17, 7.0, 0.55, 2)
    p.add(crown, ROOT, "matte", T(0, 0.05, 0.07), shade=G.mottle(ROOT, EARTH, 30.0, 1.0, G.MOSS))
    for i in range(7):                               # the root's arms over the ground
        a = 2 * math.pi * i / 7 + 0.3
        ln = 0.3 + 0.16 * h1(i, 2.0)
        tp = [(0.1 * math.cos(a), 0.05 + 0.1 * math.sin(a), 0.09), (0.6 * ln * math.cos(a + 0.2), 0.05 + 0.6 * ln * math.sin(a + 0.2), 0.07),
              (ln * math.cos(a + 0.5), 0.05 + ln * math.sin(a + 0.5), 0.0)]
        p.add(K.tube(tp, [0.035, 0.022, 0.006], 5), ROOT, "matte", shade=G.mottle(ROOT, EARTH, 60.0, i))
    spots = ((0.0, -0.06, 0.07, 0.135, 0, 1.0), (-0.25, 0.10, 0.03, 0.115, -24, 0.45), (0.24, 0.14, 0.04, 0.105, 28, 0.0))
    for i, (x, y, z, r, lean, split) in enumerate(spots):
        m = T(x, y, z) @ R("Y", lean) @ R("X", -8)
        p.add(K.tube([(0, 0.05, 0.08), (x * 0.6, y * 0.6 + 0.02, z + 0.04), (x, y, z + 0.03)], [0.03, 0.026, 0.03], 6), CANE, "satin")
        _pod(p, m, r, 3.0 + i, split)
    for i in range(8):                               # thorn seed spilled from the open one
        a = math.radians(230 + 80 * h1(i, 4.0))
        d = 0.2 + 0.16 * h1(i, 5.0)
        p.add(U.sphere(0.014, 5, 4), G.THORN, "pearl", T(d * math.cos(a), d * math.sin(a), 0.012) @ S(1, 1, 1.5) @ R("X", 80))
    canes = [(0.1, 0.12, 0.1), (0.2, 0.3, 0.35), (0.12, 0.38, 0.55), (-0.02, 0.36, 0.7)]
    p.add(K.tube(canes, [0.012, 0.01, 0.007, 0.003], 5), CANE, "satin")
    _thorns_on(p, canes + [(-0.05, 0.35, 0.74)], 1, 0.03, 0.006, 4.0, 0.0, 1.0)
    return dict(kind="hoard", loot=(0, -0.14, 0.24))


def thorn_cage(p):
    """Thorn cage: a songbird shut in a ball of woven living briar on a stake.
    The bird is the child mesh "<id>_bird", so it can be let go."""
    p.add(G.shaft(1.0, 0.024, 0.016, 4.0, 0.03, 2, 6, -0.08), G.BOGWOOD, "matte", shade=G.wood(G.BOGWOOD, 2.0, 0.4))
    cz, r = 1.13, 0.22
    for i in range(6):                               # ribs
        a = math.pi * i / 6
        arc = [(r * math.cos(t) * math.cos(a) * (1 + 0.05 * wob(k + i, 2.0)), r * math.cos(t) * math.sin(a), cz + r * 1.1 * math.sin(t))
               for k, t in enumerate([math.radians(-90 + 360 * j / 16) for j in range(16)])]
        p.add(K.tube(arc, 0.0085, 4, closed=True), CANE, "satin", shade=lambda co: K.mix(CANE_RED, CANE, 0.5 + 0.5 * math.sin(co.z * 30)))
    hoops = []
    for k, zz in enumerate((-0.55, 0.0, 0.55)):      # hoops binding them
        rr = r * math.cos(math.asin(zz)) * 1.03
        hoop = [(rr * math.cos(2 * math.pi * j / 14), rr * math.sin(2 * math.pi * j / 14), cz + r * 1.1 * zz + 0.012 * math.sin(j * 1.9 + k)) for j in range(14)]
        p.add(K.tube(hoop, 0.0075, 4, closed=True), CANE_RED, "satin")
        hoops.append(hoop)
    for k, hoop in enumerate(hoops):
        _thorns_on(p, hoop + hoop[:2], 2, 0.035, 0.007, 5.0 + k, 0.0, 0.45)
    p.add(G.lash(0.022, 0.86, 0.93, 4, 0.006, 4), CANE_RED, "satin")
    bird = G.Prop("bird")                            # a small rose-breasted songbird, facing -Y
    breast, back = (0.74, 0.42, 0.40), (0.36, 0.30, 0.26)
    bird.add(U.sphere(0.042, 10, 7), back, "fabric", S(0.85, 1.25, 0.95) @ R("X", -20), shade=lambda co: K.mix(back, breast, U._smooth(0.0, -0.025, co.z - co.y * 0.4)))
    bird.add(U.sphere(0.027, 9, 6), back, "fabric", T(0, -0.045, 0.036), shade=lambda co: K.mix(back, breast, U._smooth(0.0, -0.015, co.z)))
    bird.add(K.cyl(0.006, 0.02, 5, r2=0.0), (0.30, 0.24, 0.16), "satin", T(0, -0.068, 0.034) @ R("X", 95))
    for sx in (-1, 1):
        bird.add(U.sphere(0.0045, 5, 4), G.CHAR, "pearl", T(sx * 0.016, -0.06, 0.044))
        bird.add(K.leaf(0.07, 0.035), K.darker(back, 0.2), "fabric", T(sx * 0.03, 0.0, 0.012) @ R("Z", 90 + sx * 8) @ R("Y", 12))
        bird.add(K.cyl(0.0022, 0.04, 3), (0.30, 0.24, 0.16), "matte", T(sx * 0.012, 0.0, -0.07))
    bird.add(K.leaf(0.075, 0.03), K.darker(back, 0.25), "fabric", T(0, 0.04, 0.0) @ R("Z", 90) @ R("Y", -18))
    p.add(K.tube([(-0.2, 0.0, cz - 0.075), (0.2, 0.0, cz - 0.075)], 0.006, 4), CANE_RED, "satin")          # its perch
    return dict(kind="deed", parts={"bird": (bird, (0.0, 0.0, cz))}, cut=(0, -r, cz))


def uprooted_ring(p):
    """Uprooted ring: the court's own rose bushes pulled up to make room and
    left on their sides in a ring, roots in the air, the blooms wilting."""
    rng = random.Random(7)
    n = 8
    for b in range(n):
        a = 2 * math.pi * b / n + 0.15 * wob(b, 1.0)
        rr = 2.6 + 0.25 * wob(b, 2.0)
        m = T(rr * math.cos(a), rr * math.sin(a), 0.0) @ R("Z", math.degrees(a) + 90 + 50 * wob(b, 3.0))
        ball = U.sphere(0.22, 8, 5)                  # the root ball, earth still packed round it
        for v in ball.verts:
            v.co *= 1.0 + 0.16 * wob(v.co.x * 9 + v.co.y * 7 + v.co.z * 5, 10.0 + b)
            v.co.z *= 0.85
        p.add(ball, EARTH, "matte", m @ T(0, 0, 0.19), shade=G.mottle(EARTH, ROOT, 26.0, b))
        for i in range(4):                           # roots in the air
            ra = math.radians(-70 + 47 * i)
            tp = [(-0.12, 0.05 * (i - 1.5), 0.24), (-0.36, 0.12 * (i - 1.5), 0.30 + 0.18 * math.cos(ra)), (-0.52 - 0.1 * h1(i, b), 0.2 * (i - 1.5), 0.26 + 0.30 * math.cos(ra))]
            p.add(K.tube(tp, [0.03, 0.016, 0.004], 4), ROOT, "matte", m)
        for i in range(3):                           # the canes, lying where it fell
            sp = 0.26 * (i - 1)
            tp = [(0.12, sp * 0.3, 0.2), (0.5, sp, 0.22 - 0.05 * i), (0.95, sp * 1.6, 0.10), (1.25 + 0.1 * i, sp * 2.0, 0.03)]
            p.add(K.tube(tp, [0.02, 0.015, 0.011, 0.004], 4), CANE, "satin", m, shade=lambda co: K.mix(CANE_RED, CANE, 0.5 + 0.5 * math.sin(co.x * 9)))
            for k in (1, 2):
                q = Vector(tp[k])
                for j in range(2):
                    p.add(K.leaf(0.11, 0.06), LEAF_WILT if (i + k + j) % 3 else LEAF, "leaf",
                          m @ T(q.x, q.y, q.z) @ R("Z", 70 + 140 * j + 30 * i) @ R("Y", 25))
            q = Vector(tp[3])
            K.rose_bud(p, m @ T(q.x, q.y, q.z + 0.01) @ R("Y", 100) @ R("X", 40 * i), 0.055, G.PETAL_DEAD, "fabric", rng)
        for i in range(3):                           # petals dropped under it
            p.add(K.petal(0.05, 0.045, 0.2, 0.1), G.PETAL_DEAD, "fabric", m @ T(0.8 + 0.2 * i, 0.3 * wob(i + b, 4.0), 0.008) @ R("Z", 120 * i))
    return dict(kind="dressing")


WEAPONS = {
    "wpn_briar_thorn_whip": thorn_whip,
    "wpn_briar_rose_shiv": rose_shiv,
}
CAMP = {
    "camp_briar_seedpods": seedpods,
    "camp_briar_thorn_cage": thorn_cage,
    "camp_briar_uprooted_ring": uprooted_ring,
}
