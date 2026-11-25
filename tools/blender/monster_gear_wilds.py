"""Blackvein, martax, hollow-crow and lampwing gear (lane L88; monster-gear.md
§2.5 to §2.8).

None of these carry anything, so every weapon here is a trophy cut from the
body: a blackvein's finger and jaw (pearl-white, a black vein through them),
a martax's thigh bone, teeth and fang (yellowed), a hollow-crow's beak. Their
camp gear is what they leave: silk, bones, a tipped cart, a carcass.

Three pieces hang (meta hangs=True): their origin is the point they hang from
and they run down from it. See monster_gear.py for the contract.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402
import monster_gear_gloamer as GL  # noqa: E402
import monster_gear_hob as HB  # noqa: E402
import monster_gear_kit as G  # noqa: E402
import prop_kit as K  # noqa: E402
import upcoming_kit as U  # noqa: E402
from monster_gear_kit import R, S, T, h1, wob  # noqa: E402

PEARL = G.grim(0.70, 0.70, 0.68)
PEARL_SHADE = G.grim(0.44, 0.45, 0.50)
VEIN = G.grim(0.035, 0.03, 0.05)
SILK = G.grim(0.56, 0.56, 0.52)
SILK_SHADE = G.grim(0.36, 0.38, 0.38)
YELLOW_BONE = G.grim(0.62, 0.56, 0.40)
YELLOW_DARK = G.grim(0.36, 0.29, 0.18)
MANE = G.grim(0.20, 0.16, 0.13)
MUD = G.grim(0.24, 0.19, 0.14)
MUD_WET = G.grim(0.13, 0.10, 0.08)
DEER = G.grim(0.40, 0.28, 0.18)
DEER_PALE = G.grim(0.58, 0.50, 0.40)
BEAK = G.grim(0.09, 0.09, 0.10)
BEAK_TIP = G.grim(0.42, 0.38, 0.30)
DUST = G.grim(0.74, 0.70, 0.56)


def _vein(p, pts, r=0.0016, seed=1.0, m=None):
    """The black vein: a thin dark thread lying just proud of the pearl, with
    a short branch off every other span."""
    p.add(K.tube(pts, [r * (1.0 - 0.6 * i / (len(pts) - 1)) for i in range(len(pts))], 4), VEIN, "satin", m)
    for i in range(1, len(pts) - 1, 2):
        a = Vector(pts[i])
        b = a + (Vector(pts[i + 1]) - a).cross(Vector((1, 0, 0))).normalized() * 0.012 * (1 if h1(i, seed) > 0.5 else -1) + (Vector(pts[i + 1]) - a) * 0.6
        p.add(K.tube([tuple(a), tuple(b)], [r * 0.6, r * 0.15], 3), VEIN, "satin", m)


def _pearl(seed=1.0):
    return G.mottle(PEARL, PEARL_SHADE, 70.0, seed, K.lighter(PEARL, 0.1))


def _silk_wrap(p, r, z0, z1, turns, seed=1.0, worn=False):
    p.add(G.lash(r, z0, z1, turns, 0.0042, 4, 1.0, 0.003 if worn else 0.0006, seed), SILK, "fabric",
          shade=G.mottle(SILK, SILK_SHADE, 300.0, seed))
    for i in range(4 if worn else 2):                # loose ends of silk
        a = 2 * math.pi * h1(i, seed + 2.0)
        z = z0 + (z1 - z0) * h1(i, seed + 3.0)
        p.add(K.tube([(r * math.cos(a), r * math.sin(a), z), (r * 1.6 * math.cos(a), r * 1.6 * math.sin(a), z - 0.03), (r * 1.4 * math.cos(a), r * 1.5 * math.sin(a), z - 0.07)],
                     [0.0018, 0.0012, 0.0004], 3), SILK, "fabric")


# ================================================================== blackvein


def veinhook(p, worn):
    """Veinhook: one of a blackvein's long hooked fingers, pearl-white with a
    black vein through it, the knuckle wrapped in its silk as a grip."""
    # the finger: three bones swelling at each joint, then the hooked claw
    joints = (-0.085, 0.075, 0.215, 0.315)
    pts, rad = [], []
    for i in range(25):
        z = -0.085 + 0.40 * i / 24
        y = 0.006 * math.sin(z * 14.0)
        r = 0.0125 - 0.004 * (z + 0.085) / 0.40
        for j in joints:
            r *= 1.0 + 0.42 * math.exp(-((z - j) / 0.014) ** 2)
        pts.append((0.0, y, z))
        rad.append(r)
    bm = K.tube(pts, rad, 8)
    for v in bm.verts:
        v.co.x *= 0.86
    p.add(bm, PEARL, "pearl", shade=_pearl(2.0))
    hook = [(0.0, y, z) for y, z in G.arc(0.062, 0.315, 0.062, 180, 52 if worn else 12, 9, 1.15)]
    n = len(hook)
    hr = [max(0.0085 * (1.0 - (i / (n - 1)) ** 1.6), 0.0014 if worn else 0.0004) for i in range(n)]
    hb = K.tube(hook, hr, 7)
    for v in hb.verts:
        v.co.x *= 0.62
    p.add(hb, PEARL, "pearl", shade=lambda co: K.mix(_pearl(4.0)(co), VEIN, U._smooth(0.07, 0.125, co.y) * 0.85))   # the claw darkens to a black point
    _vein(p, [(0.0098, 0.004 + 0.004 * math.sin(i * 1.3), -0.07 + 0.375 * i / 9) for i in range(10)], 0.0019, 2.0)
    _vein(p, [(-0.0092, -0.003 + 0.004 * math.cos(i * 1.1), 0.09 + 0.2 * i / 5) for i in range(6)], 0.0014, 5.0)
    _silk_wrap(p, 0.0135, -0.06, 0.055, 9, 3.0, worn)
    if worn:
        G.crack(p, (0.009, 0.006, 0.10), (0.008, -0.002, 0.20), 2.0, 0.0013, color=VEIN)
        G.crack(p, (0.005, 0.012, 0.33), (0.004, 0.05, 0.375), 4.0, 0.0012, color=VEIN)
    tip = hook[-1]
    return dict(tip=(0, tip[1], tip[2]), imbue=(0, 0.062, 0.39), hands=1, kind="sickle")


def jaw_shears(p, worn):
    """Jaw-shears: half of a blackvein's sideways jaw, its hooked teeth along
    the inner edge, bound into a curved knife."""
    path = [(0.0, -0.075), (0.0, 0.05)] + G.arc(0.11, 0.05, 0.11, 180, 108, 8, 1.75)
    n = len(path)
    w = [0.014, 0.016] + [0.030 - 0.020 * (i / 8) ** 1.5 for i in range(9)]
    th = [0.016, 0.017] + [0.014 - 0.009 * i / 8 for i in range(9)]
    p.add(G.curved_blade(path, w, th, 5.0, 0.004 if worn else 0.0, False, 0.55), PEARL, "pearl", shade=_pearl(3.0))
    for i in range(2, n - 1):                         # the hooked teeth, raked back toward the grip
        if worn and i in (4, 7, 8):
            continue                                 # sockets where teeth have snapped out
        for half in (0.0, 0.5):
            a, b = Vector((0, *path[i])), Vector((0, *path[min(i + 1, n - 1)]))
            c = a.lerp(b, half)
            t = (b - a).normalized()
            nr = Vector((0, t.z, -t.y))
            k = (i + half) / (n - 1)
            q = c + nr * (w[i] * 0.45 - 0.002)
            L = 0.022 * (1.0 - 0.45 * k) * (0.8 + 0.4 * h1(i + half, 2.0))
            ang = math.degrees(math.atan2(nr.y, nr.z)) + 24
            p.add(G.fang(L, 0.0036, -0.55, 5, 4), PEARL, "pearl", T(*q) @ R("X", -ang),
                  shade=lambda co, q=q, L=L: K.mix(PEARL, VEIN, U._smooth(L * 0.45, L, (co - q).length) * 0.8))
    _vein(p, [(0.0078 - 0.004 * i / 8, path[i + 1][0] - 0.004, path[i + 1][1]) for i in range(9)], 0.0017, 3.0)
    _silk_wrap(p, 0.0135, -0.065, 0.045, 8, 6.0, worn)
    p.add(G.lash(0.016, 0.03, 0.062, 3, 0.004, 4, 1.15), G.SINEW, "fabric")
    if worn:
        G.crack(p, (0.0072, 0.012, 0.09), (0.006, 0.03, 0.17), 2.0, 0.0012, color=VEIN)
    tip = path[-1]
    return dict(tip=(0, tip[0], tip[1]), imbue=(0, 0.05, 0.19), hands=1, kind="knife")


def _silk_sheet(rows):
    """A sheet through a grid of points. One face does for both sides: the
    finish shader draws back faces."""
    bm = bmesh.new()
    vs = [[bm.verts.new(q) for q in row] for row in rows]
    for j in range(len(rows) - 1):
        for i in range(len(rows[0]) - 1):
            bm.faces.new((vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]))
    return bm


def cocoon(p):
    """Silk cocoon: a pale bundle hanging from a vault rib with a shape inside
    it. She cuts it open. Hangs from its origin."""
    L, r0 = 0.82, 0.21
    bm = U.sphere(1.0, 14, 12)
    for v in bm.verts:
        q = v.co
        t = (1.0 - q.z) * 0.5                        # 0 at the top, 1 at the bottom
        rr = r0 * (0.35 + 0.65 * math.sin(math.pi * min(t * 1.15, 1.0)) ** 0.8) * (1.0 + 0.10 * wob(t * 7 + math.atan2(q.y, q.x) * 2, 3.0))
        a = math.atan2(q.y, q.x)
        bulge = 1.0 + 0.30 * math.exp(-((t - 0.55) / 0.16) ** 2) * max(0.0, math.cos(a - 1.3))    # a wing or an elbow pressing out
        bulge += 0.20 * math.exp(-((t - 0.30) / 0.10) ** 2) * max(0.0, math.cos(a + 2.2))         # and a head
        h = math.hypot(q.x, q.y)
        q.x, q.y = q.x / max(h, 1e-5) * rr * bulge * min(h * 2.2, 1.0), q.y / max(h, 1e-5) * rr * bulge * min(h * 2.2, 1.0)
        q.z = -0.16 - L * t

    def shade(co):
        t = (-co.z - 0.16) / L
        a = math.atan2(co.y, co.x)
        c = K.mix(SILK, SILK_SHADE, 0.5 + 0.5 * math.sin(co.z * 85 + a * 3.0))                    # the wrap, turn on turn
        dark = 0.5 * math.exp(-((t - 0.55) / 0.16) ** 2) * max(0.0, math.cos(a - 1.3)) + 0.4 * math.exp(-((t - 0.30) / 0.10) ** 2) * max(0.0, math.cos(a + 2.2))
        return K.mix(c, G.BOGWOOD, min(dark, 0.55))                                               # what's inside shows through as a shadow
    p.add(bm, SILK, "fabric", shade=shade)
    for k in range(3):                               # binding strands wound round it
        pts = []
        for i in range(28):
            t = i / 27
            a = 2 * math.pi * (2.2 + 0.4 * k) * t + k * 2.1
            rr = r0 * (0.35 + 0.65 * math.sin(math.pi * min((0.08 + 0.84 * t) * 1.15, 1.0)) ** 0.8) * 1.12
            pts.append((rr * math.cos(a), rr * math.sin(a), -0.16 - L * (0.08 + 0.84 * t)))
        p.add(K.tube(pts, 0.0045, 4), K.lighter(SILK, 0.08), "fabric")
    p.add(K.tube([(0, 0, 0), (0.004, 0.002, -0.08), (0, 0, -0.19)], [0.011, 0.008, 0.02], 6), SILK, "fabric")       # the rope it hangs by
    for i in range(5):                               # anchor threads fanning to the rib
        a = 2 * math.pi * i / 5 + 0.4
        p.add(K.tube([(0.16 * math.cos(a), 0.16 * math.sin(a), 0.0), (0.05 * math.cos(a), 0.05 * math.sin(a), -0.07), (0.02 * math.cos(a), 0.02 * math.sin(a), -0.2)],
                     [0.003, 0.0022, 0.002], 3), SILK, "fabric")
    for i in range(6):                               # threads trailing off the bottom
        a = 2 * math.pi * h1(i, 4.0)
        d = 0.04 + 0.05 * h1(i, 5.0)
        ln = 0.10 + 0.16 * h1(i, 6.0)
        p.add(K.tube([(d * math.cos(a), d * math.sin(a), -0.93), (d * 1.2 * math.cos(a), d * 1.2 * math.sin(a), -0.98 - ln * 0.5), (d * math.cos(a) + 0.01, d * math.sin(a), -0.98 - ln)],
                     [0.003, 0.0018, 0.0005], 3), SILK, "fabric")
    p.add(G.feather(0.11, 0.03), G.FEATHER, "satin", T(0.13, 0.15, -0.60) @ R("Y", 70) @ R("Z", 40))            # one feather caught in the wrap
    p.add(K.tube([(-0.12, -0.14, -0.45), (-0.2, -0.16, -0.62), (-0.14, -0.15, -0.78)], 0.007, 4), G.HIDE, "fabric")                                                                         # a satchel strap hanging out of it
    return dict(kind="container", hangs=True, loot=(0.0, 0.22, -0.60), cut=(0.0, 0.2, -0.45))


def silk_drape(p):
    """Silk drapes: sheets of pale silk strung between vault ribs, sagging and
    torn to tatters along the hem. Hangs from the two ends of its top line,
    4 m apart; its origin is the middle of that line."""
    for k, (y0, sag, drop, seed) in enumerate(((0.0, 0.55, 1.2, 1.0), (0.3, 0.3, 0.75, 5.0))):
        nu, nv = 40, 6
        rows = []
        for j in range(nv + 1):
            v = j / nv
            row = []
            for i in range(nu + 1):
                u = i / nu
                tatter = 0.3 + 0.7 * abs(wob(u * 7.0, seed)) ** 0.6 * (0.75 + 0.25 * wob(u * 31.0, seed + 1.0))       # the hem: long tongues and bitten gaps
                x = (-2.0 + 4.0 * u) * (1.0 - 0.06 * v * math.sin(math.pi * u))
                z = -sag * 4 * u * (1 - u) - drop * (v ** 1.2) * tatter * math.sin(math.pi * u) ** 0.35
                y = y0 + 0.22 * v * wob(u * 5 + v * 2, seed + 2.0) + 0.08 * math.sin(u * 23 + seed) * v           # hanging folds
                row.append((x, y, z))
            rows.append(row)
        p.add(_silk_sheet(rows), SILK, "fabric",
              shade=lambda co, s=seed: K.mix(K.mix(SILK, SILK_SHADE, 0.5 + 0.5 * math.sin(co.x * 23 + s)), K.lighter(SILK, 0.1), max(0.0, math.sin(co.x * 3.3 + s)) * 0.5))
        for i in range(9):                           # threads hanging from the torn hem
            q = rows[-1][int(h1(i, seed + 4.0) * nu)]
            ln = 0.12 + 0.35 * h1(i, seed + 5.0)
            p.add(K.tube([q, (q[0] + 0.02, q[1], q[2] - ln * 0.5), (q[0] - 0.01, q[1] + 0.01, q[2] - ln)], [0.004, 0.0025, 0.0006], 3), SILK, "fabric")
    for sx in (-1, 1):                               # the anchor ropes and their webs on the ribs
        p.add(K.tube([(sx * 2.0, 0.0, 0.0), (sx * 2.06, 0.1, 0.03), (sx * 2.1, 0.35, 0.0)], 0.012, 5), SILK, "fabric")
        for i in range(5):
            a = math.radians(-70 + 35 * i)
            p.add(K.tube([(sx * 2.0, 0.0, 0.0), (sx * (2.0 + 0.16 * math.cos(a)), 0.05, 0.22 * math.sin(a))], [0.005, 0.002], 3), SILK, "fabric")
    for i in range(3):                               # small things caught and wrapped
        x = -1.2 + 1.1 * i + 0.3 * wob(i, 3.0)
        z = -0.55 * 4 * ((x + 2) / 4) * (1 - (x + 2) / 4) - 0.45 - 0.2 * h1(i, 2.0)
        p.add(G.stone(0.07 + 0.03 * h1(i, 7.0), 3.0 + i, 1.6, 1), SILK, "fabric", T(x, 0.03, z), shade=G.mottle(SILK, SILK_SHADE, 60.0, i))
    return dict(kind="dressing", hangs=True, span_m=4.0)


def _bird_skull(p, m, r=0.012):
    p.add(U.sphere(r, 6, 5), G.BONE, "matte", m @ S(0.85, 1.1, 0.85))
    p.add(K.cyl(r * 0.5, r * 2.4, 4, r2=0.0), G.BONE_OLD, "matte", m @ T(0, r * 0.6, -r * 0.2) @ R("X", -90) @ S(0.7, 1, 1))
    for sx in (-1, 1):
        p.add(U.sphere(r * 0.32, 4, 3), G.CHAR, "matte", m @ T(sx * r * 0.62, r * 0.35, r * 0.1))


def bone_rain(p):
    """Bone rain: small bird bones scattered on the flagstones under the
    roost. Look up."""
    for i in range(30):
        a = 2 * math.pi * h1(i, 1.0)
        d = 0.98 * math.sqrt(h1(i, 2.0))
        L = 0.045 + 0.075 * h1(i, 3.0)
        col = K.mix(G.BONE, G.BONE_OLD, h1(i, 5.0))
        p.add(G.bone(L, 0.0034, 1.9, 4), col, "matte", T(d * math.cos(a), d * math.sin(a), 0.006) @ R("Z", 360 * h1(i, 6.0)) @ R("Y", 90))
    for i in range(4):                               # wishbones and rib sprays
        a = 2 * math.pi * h1(i, 11.0)
        d = 0.75 * math.sqrt(h1(i, 12.0))
        m = T(d * math.cos(a), d * math.sin(a), 0.005) @ R("Z", 360 * h1(i, 13.0))
        for sx in (-1, 1):
            p.add(K.tube([(0, 0, 0), (sx * 0.02, 0.03, 0.004), (sx * 0.026, 0.065, 0)], [0.0028, 0.0022, 0.001], 3), G.BONE, "matte", m)
    for i in range(5):
        a = 2 * math.pi * h1(i, 21.0)
        d = 0.8 * math.sqrt(h1(i, 22.0))
        _bird_skull(p, T(d * math.cos(a), d * math.sin(a), 0.011) @ R("Z", 360 * h1(i, 23.0)) @ R("Y", 30 * wob(i, 2.0)), 0.011 + 0.004 * h1(i, 24.0))
    for i in range(7):                               # dark feathers
        a = 2 * math.pi * h1(i, 31.0)
        d = 0.95 * math.sqrt(h1(i, 32.0))
        p.add(G.feather(0.07 + 0.05 * h1(i, 33.0), 0.022), G.FEATHER, "satin", T(d * math.cos(a), d * math.sin(a), 0.006) @ R("Z", 360 * h1(i, 34.0)))
    for i in range(4):                               # husks fallen from the silk: something small, sucked dry
        a = 2 * math.pi * h1(i, 41.0)
        d = 0.7 * math.sqrt(h1(i, 42.0))
        p.add(G.stone(0.035 + 0.02 * h1(i, 43.0), 9.0 + i, 0.55, 1), SILK, "fabric", T(d * math.cos(a), d * math.sin(a), 0.014) @ S(1.6, 1, 1) @ R("Z", 90 * i),
              shade=G.mottle(SILK, SILK_SHADE, 120.0, i))
    return dict(kind="dressing")


# ================================================================== martax


def _saw_tooth(L, w):
    """A flat triangular serrated tooth from the origin up Z, its edges along Y."""
    return G.blade([(0.0, -w * 0.5, w * 0.5), (L * 0.35, -w * 0.42, w * 0.44), (L * 0.7, -w * 0.2, w * 0.26), (L, -0.0006, 0.0006)], w * 0.42, 1.0, w * 0.10, 0.5)


def tooth_club(p, worn):
    """Three-row Club: a martax thigh bone set along one side with three
    staggered rows of its serrated teeth, bound with rawhide."""
    bm = G.bone(0.90, 0.021, 2.0, 9)
    for v in bm.verts:
        z = v.co.z
        v.co.y += 0.018 * math.sin(math.pi * z / 0.9)          # a thigh bone bows
        k = 1.0 + 0.35 * U._smooth(0.45, 0.8, z)               # heavier toward the far end
        v.co.x *= k
        v.co.y *= k
    stain = G.mottle(YELLOW_BONE, YELLOW_DARK, 46.0, 2.0, K.lighter(YELLOW_BONE, 0.1))
    p.add(bm, YELLOW_BONE, "matte", T(0, -0.012, -0.30), shade=stain)
    gone = {(0, 2), (1, 5), (2, 1), (2, 6), (0, 7), (1, 0)} if worn else set()
    for row, sx in enumerate((-0.014, 0.0, 0.014)):
        for i in range(8):
            if (row, i) in gone:
                continue
            z = 0.165 + 0.044 * i + 0.015 * row                # staggered: each row a third of a tooth on
            y = 0.012 + 0.018 * math.sin(math.pi * (z + 0.30) / 0.9) + 0.020 * (1.0 + 0.35 * U._smooth(0.15, 0.5, z)) - 0.004 * abs(row - 1)
            L = 0.034 + 0.012 * h1(i + row * 9, 3.0)
            p.add(_saw_tooth(L, 0.019), YELLOW_BONE, "pearl", T(sx, y - 0.012, z) @ R("Z", -sx * 900) @ R("X", -90 + 14 * wob(i + row, 2.0)),
                  shade=lambda co: K.mix(YELLOW_DARK, K.lighter(YELLOW_BONE, 0.15), U._smooth(0.0, 0.02, co.z)))
    for z0, z1, turns, seed in ((0.12, 0.165, 3, 1.0), (0.31, 0.35, 2.5, 2.0), (0.485, 0.525, 2.5, 3.0)):          # rawhide holding the rows on
        p.add(G.lash(0.0215 * (1.0 + 0.35 * U._smooth(0.15, 0.5, z0)), z0, z1, turns, 0.006, 4, 1.45, 0.003 if worn else 0.001, seed), G.HIDE_PALE, "fabric",
              T(0, 0.012, 0), shade=G.mottle(G.HIDE_PALE, G.HIDE, 200.0, seed))
    p.add(G.lash(0.0195, -0.19, 0.07, 14, 0.0055, 4, 1.0, 0.0015 if worn else 0.0004, 5.0), G.HIDE, "fabric", T(0, -0.004, 0),
          shade=G.mottle(G.HIDE, K.darker(G.HIDE, 0.4), 160.0, 2.0))
    if worn:
        G.crack(p, (0.027, 0.0, 0.08), (0.03, 0.012, 0.36), 2.0, 0.0022, color=YELLOW_DARK)
        G.crack(p, (-0.026, -0.004, 0.30), (-0.03, 0.008, 0.52), 3.0, 0.002, color=YELLOW_DARK)
    return dict(tip=(0, 0.075, 0.56), imbue=(0, 0.07, 0.42), hands=2, kind="club")


def fang_knife(p, worn):
    """Martax-fang Knife: a single long yellowed fang with a serrated edge, its
    root gripped in matted mane hair."""
    top = 0.19 if worn else 0.235
    st, th = [], []
    for i in range(12):
        t = i / 11
        z = -0.07 + (top + 0.07) * t
        lean = 0.028 * (t ** 2.2)
        wdt = 0.030 * (1.0 - 0.80 * U._smooth(0.25, 1.0, (z + 0.07) / 0.305) ** 1.3) + 0.002
        if worn and i == 11:
            wdt = 0.011                              # the point snapped off square
        st.append((z, lean - wdt * 0.5, lean + wdt * 0.5))
        th.append(max(0.021 * (1.0 - 0.75 * (z + 0.07) / 0.305), 0.004))
    stain = G.mottle(YELLOW_BONE, YELLOW_DARK, 60.0, 1.0, K.lighter(YELLOW_BONE, 0.12))
    p.add(G.blade(st, th, 3.0, 0.004 if worn else 0.0022, 0.55), YELLOW_BONE, "pearl",
          shade=lambda co: K.mix(stain(co), YELLOW_DARK, max(U._smooth(0.10, 0.03, co.z) * 0.7, 0.0)))
    for i in range(9):                               # the serrations, cut like a saw's
        z = 0.075 + (top - 0.095) * i / 8
        k = (z + 0.07) / 0.305
        y = 0.028 * (((z + 0.07) / (top + 0.07)) ** 2.2) + (0.030 * (1.0 - 0.80 * U._smooth(0.25, 1.0, k) ** 1.3) + 0.002) * 0.5 - 0.0025
        if worn and i in (2, 5):
            continue
        p.add(K.cyl(0.0028, 0.007, 3, r2=0.0), K.lighter(YELLOW_BONE, 0.1), "pearl", T(0, y, z) @ R("X", -78))
    for i in range(26):                              # the mane: matted locks bound round the root
        a = 2 * math.pi * i / 13 + 0.3 * h1(i, 2.0)
        z = 0.045 - 0.11 * ((i * 7) % 26) / 25
        ln = 0.035 + 0.035 * h1(i, 3.0) + (0.02 if worn else 0.0) * h1(i, 6.0)
        rr = 0.0135
        p.add(K.tube([(rr * math.cos(a), rr * math.sin(a), z), (rr * 1.25 * math.cos(a + 0.3), rr * 1.25 * math.sin(a + 0.3), z - ln * 0.5),
                      (rr * (1.1 + (0.5 if worn else 0.15) * h1(i, 4.0)) * math.cos(a + 0.6), rr * 1.2 * math.sin(a + 0.6), z - ln)], [0.0042, 0.0046, 0.0012], 4),
              K.mix(MANE, G.HIDE, 0.6 * h1(i, 5.0)), "fabric")
    p.add(G.lash(0.016, -0.055, 0.035, 5, 0.0034, 4, 1.0, 0.001, 7.0), G.SINEW, "fabric")
    if worn:
        G.crack(p, (0.008, 0.004, 0.06), (0.004, 0.02, 0.16), 2.0, 0.0013, color=YELLOW_DARK)
    return dict(tip=(0, 0.028, top), imbue=(0, 0.03, 0.15), hands=1, kind="knife")


def den_hoard(p):
    """Den hoard: a cart tipped on its side in the Steading's ruins, sacks
    spilled, things dragged under it."""
    cm = T(0.0, 0.25, 0.5) @ R("Z", 8) @ R("X", 84)             # the cart bed, on its side: its floor faces +Y
    plank = G.wood(HB.PLANK, 2.0, 0.4)
    for i in range(5):                               # the floor, plank by plank, one stove in
        if i == 3:
            p.add(K.box(0.7, 0.17, 0.03, 0.004), HB.PLANK, "matte", cm @ T(-0.5, -0.36 + 0.18 * i, 0.0) @ R("Z", 6), shade=plank)
            continue
        p.add(K.box(1.7, 0.17, 0.03, 0.004), HB.PLANK, "matte", cm @ T(0, -0.36 + 0.18 * i, 0.0), shade=G.wood(HB.PLANK, 2.0 + i, 0.4))
    for sy in (-1, 1):
        p.add(K.box(1.7, 0.035, 0.34, 0.005), HB.PLANK, "matte", cm @ T(0, sy * 0.46, 0.17), shade=G.wood(HB.PLANK, 8.0 + sy, 0.4))
        p.add(K.box(0.09, 0.07, 0.09), HB.PLANK, "matte", cm @ T(0.1, sy * 0.52, -0.06))                                   # the axle blocks
    for sx in (-1, 1):
        p.add(K.box(0.035, 0.92, 0.34, 0.005), HB.PLANK, "matte", cm @ T(sx * 0.85, 0, 0.17), shade=plank)
    p.add(K.cyl(0.035, 1.25, 7), G.IRON, "satin", cm @ T(0.1, -0.625, -0.07) @ R("X", -90), shade=GL._iron(2.0, 0.8))    # the axle
    HB._wheel(p, cm @ T(0.1, 0.64, -0.07), 0.46)
    HB._wheel(p, T(-1.15, -0.55, 0.06) @ R("X", 82) @ R("Z", 30), 0.46)                                                    # the other, thrown clear and flat
    for sy in (-1, 1):                               # the shafts, one snapped
        ln = 1.3 if sy > 0 else 0.55
        p.add(G.shaft(ln, 0.035, 0.028, 4.0 + sy, 0.02, 1, 6), HB.PLANK, "matte", cm @ T(0.85, sy * 0.36, 0.0) @ R("Y", 90) @ R("X", sy * 4), shade=plank)
    HB._sack(p, T(0.55, -0.55, 0.0) @ R("Y", 80) @ R("Z", 30), 0.27, 2.0)
    HB._sack(p, T(-0.25, -0.75, 0.0) @ R("Y", -6), 0.30, 4.0)
    HB._sack(p, T(0.95, -0.15, 0.0) @ R("Y", 86) @ R("Z", -60), 0.25, 6.0, G.HIDE)
    spill = K.lathe([(0.0, 0.06), (0.22, 0.045), (0.42, 0.0)], 10, cap_bottom=False)                                     # grain run out of a torn sack
    p.add(spill, HB.STRAW, "matte", T(0.72, -0.86, 0.0) @ S(1.25, 0.8, 1.0), shade=G.mottle(HB.STRAW, K.darker(HB.STRAW, 0.3), 30.0, 2.0))
    GL._kettle(p, T(-0.72, 0.05, 0.02) @ R("Y", 80) @ R("Z", 140) @ S(1.2))
    for i in range(6):                               # gnawed bones dragged under it
        a = math.radians(40 + 100 * h1(i, 2.0))
        d = 0.25 + 0.5 * h1(i, 3.0)
        p.add(G.bone(0.3 + 0.16 * h1(i, 4.0), 0.02, 1.9, 5), K.mix(G.BONE, G.BONE_OLD, h1(i, 5.0)), "matte",
              T(-0.2 + d * math.cos(a), -0.1 - d * math.sin(a) * 0.5, 0.025) @ R("Z", 360 * h1(i, 6.0)) @ R("Y", 90))
    hide = K.lathe([(0.0, 0.035), (0.3, 0.03), (0.52, 0.0)], 9, cap_bottom=False)                                         # a torn fae cloak in the mud
    for v in hide.verts:
        v.co.x *= 1.0 + 0.3 * wob(math.atan2(v.co.y, v.co.x) * 2.0, 3.0)
    p.add(hide, GL.FADED_PERI, "fabric", T(-0.75, -1.0, 0.0) @ S(1.0, 0.6, 1.0), shade=G.mottle(GL.FADED_PERI, MUD, 14.0, 2.0))
    for i in range(4):                               # claw rakes in the boards
        G.crack(p, (0.35 + 0.07 * i, 0.275, 0.35), (0.25 + 0.07 * i, 0.285, 0.95), 2.0 + i, 0.006, 5, K.lighter(HB.PLANK, 0.3))
    p.transform(R("Z", 180))                        # the spill faces the front
    return dict(kind="container", loot=(-0.2, 0.45, 0.25))


def bone_heap(p):
    """Bone heap: cracked bones, cattle and other things, gnawed white."""
    mound = K.lathe([(0.0, 0.34), (0.4, 0.28), (0.78, 0.10), (1.02, 0.0)], 14, cap_bottom=False)
    for v in mound.verts:
        k = 1.0 + 0.14 * wob(math.atan2(v.co.y, v.co.x) * 2.2, 2.0)
        v.co.x *= k
        v.co.y *= k * 0.88
    p.add(mound, G.BONE_DARK, "matte", shade=G.mottle(G.BONE_DARK, MUD_WET, 11.0, 1.0, G.BONE_OLD))
    white = K.lighter(G.BONE, 0.08)
    for i in range(22):
        a = 2 * math.pi * h1(i, 1.0)
        d = 0.92 * h1(i, 2.0) ** 0.7
        z = 0.03 + 0.34 * max(0.0, 1.0 - d / 0.95) ** 1.2
        L = 0.30 + 0.30 * h1(i, 4.0)
        b = G.bone(L, 0.024 + 0.012 * h1(i, 7.0), 1.9, 5)
        if i % 3 == 0:                               # cracked for the marrow: one end bitten off
            bmesh.ops.bisect_plane(b, geom=b.verts[:] + b.edges[:] + b.faces[:], plane_co=(0, 0, L * 0.62), plane_no=(0.3, 0.2, 1), clear_outer=True)
            bmesh.ops.holes_fill(b, edges=[e for e in b.edges if e.is_boundary])
        p.add(b, K.mix(white, G.BONE_OLD, 0.5 * h1(i, 5.0)), "satin", T(d * math.cos(a), d * math.sin(a) * 0.88, z) @ R("Z", 360 * h1(i, 6.0)) @ R("Y", 62 + 40 * h1(i, 8.0)),
              shade=G.mottle(white, G.BONE_OLD, 50.0, i))
    G.skull_on(p, T(0.05, -0.2, 0.44) @ R("Z", 200) @ R("X", -14), 0.15, white, 2.0, 1.15, 0.30)            # a cow's skull on top
    G.skull_on(p, T(-0.62, 0.42, 0.10) @ R("Z", 110) @ R("Y", 70), 0.09, G.BONE_OLD, 5.0, 1.0, 0.0, False)
    m = T(0.5, 0.35, 0.16) @ R("Z", -40) @ R("Y", -12)                                                        # a rib cage, stove in
    p.add(K.tube([(-0.32, 0, 0.2), (0.32, 0, 0.17)], 0.022, 5), white, "satin", m)
    for i in range(6):
        for sx in (-1, 1):
            if sx > 0 and i in (1, 4):
                continue
            x = -0.27 + 0.105 * i
            p.add(K.tube([(x, 0, 0.19), (x, sx * 0.17, 0.17), (x, sx * 0.23, 0.03), (x, sx * 0.17, -0.07)], [0.012, 0.011, 0.009, 0.004], 4), white, "satin", m)
    return dict(kind="dressing")


def drag_furrow(p):
    """Drag furrows: long furrows in the mud ending at a half-eaten deer. The
    furrows run 5 m along X to the carcass at the +X end."""
    for k, y in enumerate((-0.22, 0.0, 0.2)):        # each furrow: a wet groove with a ridge thrown up either side
        x0 = -3.0 + 0.5 * h1(k, 2.0)
        n = 14
        mid = [(x0 + (1.75 - x0) * i / n, y + 0.10 * wob(i * 0.6, k + 1.0) + 0.05 * math.sin(i * 0.9 + k), 0.004) for i in range(n + 1)]
        p.add(K.tube(mid, [0.02] + [0.055 + 0.02 * h1(i, k) for i in range(n - 1)] + [0.07], 4), MUD_WET, "satin", S(1, 1, 0.12))
        for sy in (-1, 1):
            ridge = [(q[0], q[1] + sy * (0.095 + 0.02 * wob(i * 1.3, k + sy)), 0.0) for i, q in enumerate(mid)]
            p.add(K.tube(ridge, [0.012] + [0.036 + 0.018 * h1(i, k + sy + 5.0) for i in range(n - 1)] + [0.02], 5), MUD, "matte", S(1, 1, 0.55),
                  shade=G.mottle(MUD, MUD_WET, 30.0, k + sy))
    for i in range(6):                               # blood soaked in along the last of it
        x = 0.4 + 0.26 * i
        p.add(U.sphere(0.12 + 0.06 * h1(i, 3.0), 7, 4), G.BLOOD, "satin", T(x, 0.1 * wob(i, 4.0), 0.0) @ S(1.6, 1.0, 0.035))
    # the deer, on its side, its hind half gone
    dm = T(2.25, 0.02, 0.13)
    body = U.sphere(1.0, 12, 9)
    for v in body.verts:
        q = v.co
        q.x, q.y, q.z = q.x * 0.5, q.y * (0.24 + 0.05 * q.x), q.z * 0.15
        q.y += 0.03 * math.sin(q.x * 5)
    cut = [f for f in body.faces if f.calc_center_median().x < -0.14 + 0.05 * wob(f.calc_center_median().y * 14, 2.0)]
    bmesh.ops.delete(body, geom=cut, context="FACES")
    p.add(body, DEER, "fabric", dm, shade=lambda co: K.mix(K.mix(DEER, DEER_PALE, U._smooth(0.0, -0.2, co.y)), G.BLOOD, U._smooth(0.02, -0.14, co.x) * 0.8))
    p.add(U.sphere(1.0, 9, 6), G.MEAT, "satin", dm @ T(-0.12, 0.0, 0.0) @ S(0.10, 0.215, 0.13), shade=G.mottle(G.MEAT, G.BLOOD, 40.0, 2.0, G.FAT))        # the open cavity
    for i in range(5):                               # ribs standing out of it, stripped
        x = -0.16 - 0.065 * i
        p.add(K.tube([(x, 0.19, 0.0), (x - 0.01, 0.16, 0.12 - 0.012 * i), (x - 0.02, -0.02, 0.16 - 0.015 * i), (x - 0.02, -0.15, 0.10 - 0.01 * i)],
                     [0.011, 0.01, 0.009, 0.004], 4), K.mix(G.BONE, G.BLOOD, 0.25), "satin", dm)
    p.add(K.tube([(-0.1, 0.2, 0.0), (-0.3, 0.21, -0.01), (-0.52, 0.19, -0.04), (-0.66, 0.15, -0.08)], [0.02, 0.018, 0.017, 0.012], 5), K.mix(G.BONE, G.BLOOD, 0.3), "satin", dm)   # the spine
    p.add(G.bone(0.3, 0.02, 1.9, 5), K.mix(G.BONE, G.BLOOD, 0.2), "satin", dm @ T(-0.72, 0.02, -0.1) @ R("Z", 50) @ R("Y", 90))                         # a haunch bone, dragged off
    p.add(K.tube([(0.42, 0.10, 0.0), (0.58, 0.24, 0.0), (0.72, 0.36, -0.04)], [0.10, 0.07, 0.055], 8), DEER, "fabric", dm @ S(1, 1, 0.8))                # the neck, thrown back
    hm = dm @ T(0.76, 0.42, -0.05) @ R("Z", -48) @ R("Y", 84)
    p.add(G.skull(0.062, 3.0, 1.15), DEER, "fabric", hm)
    p.add(U.sphere(0.014, 6, 4), G.CHAR, "mirror", hm @ T(0.036, 0.04, 0.012))                                                                           # one open eye
    p.add(U.sphere(0.018, 6, 4), G.CHAR, "matte", hm @ T(0, 0.125, -0.022) @ S(1, 0.6, 0.7))
    for sx in (-1, 1):
        p.add(K.leaf(0.11, 0.05), DEER_PALE, "fabric", hm @ T(sx * 0.04, -0.03, 0.045) @ R("Z", 90 + sx * 50) @ R("Y", -40))
    for i, (x, bend) in enumerate(((0.30, 0.10), (0.20, -0.06))):                                                                                        # forelegs, stiff
        p.add(K.tube([(x, -0.17, 0.02 - 0.05 * i), (x + bend, -0.45, 0.0 - 0.06 * i), (x + bend * 0.4, -0.74, -0.04 - 0.05 * i), (x + bend * 0.4 + 0.04, -0.80, -0.05 - 0.05 * i)],
                     [0.045, 0.024, 0.016, 0.02], 6), DEER, "fabric", dm, shade=lambda co: K.mix(DEER, G.CHAR, U._smooth(-0.68, -0.74, co.y)))
    return dict(kind="dressing", carcass=(2.25, 0.0, 0.13))


# ================================================================== hollow-crow


def beak_awl(p, worn):
    """Crow-beak Awl: the too-long hooked beak of a hollow-crow on a twig, an
    eye-spot feather tied at the end."""
    p.add(G.shaft(0.125, 0.0075, 0.0085, 6.0, 0.004, 1, 7, -0.07), G.BOGWOOD, "matte", shade=G.wood(G.BOGWOOD, 2.0, 0.3))
    pts, rad = [], []
    n = 11
    keep = n - (2 if worn else 0)
    for i in range(keep + 1):
        t = i / n
        pts.append((0.0, 0.034 * t ** 2.6, 0.045 + 0.088 * t))
        rad.append(max(0.0105 * (1.0 - t ** 1.25), 0.0012 if worn else 0.0003))
    bm = K.tube(pts, rad, 7)
    for v in bm.verts:
        v.co.x *= 0.62
    p.add(bm, BEAK, "pearl", shade=lambda co: K.mix(K.mix(BEAK, G.FLINT_EDGE, max(0.0, math.sin(co.z * 300)) * 0.35), BEAK_TIP, U._smooth(0.10, 0.133, co.z) * 0.7))
    p.add(K.tube([(0.0068, 0.004, 0.05), (0.0046, 0.012, 0.09), (0.002, 0.024, 0.118)], 0.0007, 3), G.CHAR, "matte")           # the line where the beak closes
    p.add(G.lash(0.0092, 0.028, 0.056, 5, 0.0026, 4), G.SINEW, "fabric")
    p.add(G.lash(0.0085, -0.066, -0.05, 3, 0.0022, 4), G.SINEW, "fabric")
    fl = 0.05 if worn else 0.075                        # the feather, hanging from the butt
    fm = T(0, 0, -0.064) @ R("Y", 90) @ R("X", 14)
    p.add(K.tube([(0, 0, 0), (fl * 0.5, 0, 0.002), (fl, 0, 0)], [0.0011, 0.0009, 0.0004], 3), G.BONE_OLD, "matte", fm)
    p.add(K.leaf(fl, 0.036 if not worn else 0.024), G.FEATHER, "satin", fm)
    if not worn:                                     # the eye-spot: a pale ring round a dark pupil
        p.add(K.torus(0.0085, 0.0022, 10, 4), G.BONE, "pearl", fm @ T(fl * 0.6, 0, 0.0) @ S(1.2, 1.0, 0.25))
        p.add(U.sphere(0.0055, 6, 4), G.CHAR, "mirror", fm @ T(fl * 0.6, 0, 0.0) @ S(1.2, 1.0, 0.3))
    else:
        G.crack(p, (0.004, 0.006, 0.06), (0.003, 0.014, 0.10), 2.0, 0.0008, color=BEAK_TIP)
    tip = pts[-1]
    return dict(tip=(0, tip[1], tip[2]), imbue=(0, 0.012, 0.10), hands=1, kind="knife")


# ================================================================== lampwing


def roost_lantern(p):
    """Roost lantern: an old mortal lantern hung in the lampwings' roost tree,
    furred with their pale dust. The game lights it when they're home. Hangs
    from its origin."""
    s = 1.35
    lm = T(0, 0, -0.62) @ S(s)
    GL._lantern(p, lm)
    for k, (y, x) in enumerate(((0.062, 0.0), (0.0, 0.062), (0.0, -0.062))):                                            # the panes it still has, clouded
        p.add(K.box(0.11, 0.003, 0.19), (0.62, 0.64, 0.56, 0.5), "glass", lm @ T(x, y, 0.12) @ R("Z", 0 if x == 0 else 90))
    ring_z = -0.62 + 0.31 * s
    pts = [(0, 0, 0)]
    for i in range(1, 8):                            # a twist of old wire up to the branch
        t = i / 7
        pts.append((0.008 * math.sin(i * 2.4), 0.008 * math.cos(i * 2.4), ring_z * t + 0.03 * (1 - t)))
    p.add(K.tube(pts, 0.004, 4), G.IRON, "satin", shade=GL._iron(2.0, 0.9))
    p.add(K.torus(0.05, 0.006, 10, 4), G.IRON, "satin", T(0, 0, -0.02) @ R("X", 90) @ S(1, 1, 0.8), shade=GL._iron(3.0, 0.9))     # the loop over the branch
    dust = G.mottle(DUST, K.darker(DUST, 0.25), 90.0, 2.0)
    cap = K.lathe([(0.0, 0.022), (0.035, 0.016), (0.07, 0.0)], 8, cap_bottom=False)                                     # dust drifted on the roof and in the bottom
    p.add(cap, DUST, "fabric", lm @ T(0, 0, 0.268) @ S(1.0, 1.0, 0.9) @ R("Z", 22), shade=dust)
    p.add(K.lathe([(0.0, 0.03), (0.04, 0.02), (0.066, 0.0)], 8, cap_bottom=False), DUST, "fabric", lm @ T(0, 0, 0.026), shade=dust)
    for i in range(9):                               # and tufts of it on every ledge
        a = 2 * math.pi * h1(i, 3.0)
        z = (0.03, 0.225, 0.12)[i % 3] + 0.01 * h1(i, 4.0)
        d = 0.066 if i % 3 != 2 else 0.062
        p.add(G.stone(0.012 + 0.008 * h1(i, 5.0), 4.0 + i, 0.7, 1), DUST, "fabric", lm @ T(d * math.cos(a), d * math.sin(a), z), shade=dust)
    for i in range(4):                               # shed wings caught in the frame
        a = 2 * math.pi * h1(i, 7.0)
        p.add(K.leaf(0.045, 0.026), (0.72, 0.68, 0.50), "pearl", lm @ T(0.07 * math.cos(a), 0.07 * math.sin(a), 0.06 + 0.04 * i) @ R("Z", math.degrees(a)) @ R("Y", 50 + 20 * i))
    return dict(kind="dressing", hangs=True, fire=(0.0, 0.0, -0.62 + 0.12 * s))


WEAPONS = {
    "wpn_blackvein_veinhook": veinhook,
    "wpn_blackvein_jaw_shears": jaw_shears,
    "wpn_martax_tooth_club": tooth_club,
    "wpn_martax_fang_knife": fang_knife,
    "wpn_crow_beak_awl": beak_awl,
}
CAMP = {
    "camp_blackvein_cocoon": cocoon,
    "camp_blackvein_silk_drape": silk_drape,
    "camp_blackvein_bone_rain": bone_rain,
    "camp_martax_den_hoard": den_hoard,
    "camp_martax_bone_heap": bone_heap,
    "camp_martax_drag_furrow": drag_furrow,
    "camp_lampwing_roost_lantern": roost_lantern,
}
FAMILY = {k: k.split("_")[1] for k in list(WEAPONS) + list(CAMP)}
