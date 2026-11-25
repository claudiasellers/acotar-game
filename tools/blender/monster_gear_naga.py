"""Naga trophies and their riverside camp (lane L88; monster-gear.md §2.2).

Naga have no clothes, gear or weapons [C], so nothing here is made by them:
the two weapons are their own black polished talons, taken from the body, and
the gaff is a mortal fisherman's. Oily dark scale, wet black talon, river reed
and mud. See monster_gear.py for the contract.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402
import monster_gear_gloamer as GL  # noqa: E402
import monster_gear_kit as G  # noqa: E402
import prop_kit as K  # noqa: E402
import upcoming_kit as U  # noqa: E402
from monster_gear_kit import R, S, T, h1, wob  # noqa: E402

TALON = G.grim(0.045, 0.05, 0.065)
TALON_SHEEN = G.grim(0.16, 0.22, 0.26)
TALON_ROOT = G.grim(0.30, 0.27, 0.22)
MUD = G.grim(0.26, 0.21, 0.16)
ALDER = G.grim(0.36, 0.24, 0.17)


def _talon(p, path, r0, worn, seed=1.0, flat=0.55, m=None):
    """One black talon along path [(y, z)]: thick at the root, a wet point."""
    n = len(path)
    keep = n - (3 if worn else 0)                    # the worn one has lost its point
    pts = [(0.0, y, z) for y, z in path[:keep]]
    rad = [max(r0 * (1.0 - (i / (n - 1)) ** 1.5), r0 * 0.04) for i in range(keep)]
    bm = K.tube(pts, rad, 8)
    for v in bm.verts:
        v.co.x *= flat
    z0, z1 = path[0][1], path[-1][1]
    y0 = path[0][0]

    def shade(co):
        t = math.hypot(co.y - y0, co.z - z0) / max(math.hypot(path[-1][0] - y0, z1 - z0), 1e-4)
        c = K.mix(TALON_ROOT, TALON, U._smooth(0.0, 0.22, t))
        return K.mix(c, TALON_SHEEN, max(0.0, math.sin(co.z * 260 + co.y * 140 + seed)) * 0.5)
    p.add(bm, TALON, "pearl", m, shade=shade)


def _skin_grip(p, r, z0, z1, turns, seed=1.0, worn=False):
    p.add(G.lash(r, z0, z1, turns, 0.0055, 4, 0.9, 0.002 if worn else 0.0005, seed), G.SCALE_PALE, "satin",
          shade=G.mottle(G.SCALE_PALE, G.SCALE, 240.0, seed, K.lighter(G.SCALE_PALE, 0.2)))


# ================================================================== weapons


def talon_knife(p, worn):
    """Naga-talon Knife: one of its black polished talons, curved and
    wet-looking, its root wrapped in a strip of its own shed skin."""
    p.add(K.lathe([(0.0, -0.075), (0.012, -0.068), (0.0135, -0.03), (0.0125, 0.03), (0.016, 0.055), (0.013, 0.07)], 8), TALON_ROOT, "matte",
          S(0.85, 1.1, 1.0), shade=G.mottle(TALON_ROOT, G.BONE_DARK, 130.0, 1.0))
    path = [(0.0, 0.05)] + G.arc(0.20, 0.06, 0.20, 176, 118, 12, 1.0)
    _talon(p, path, 0.017, worn, 1.0)
    _skin_grip(p, 0.0135, -0.06, 0.05, 8, 2.0, worn)
    p.add(G.rag(0.07, 0.016, 3.0, 0.4, 5, 0.0012), G.SCALE_PALE, "satin", T(0.008, -0.012, -0.058) @ R("Z", 30))
    if worn:
        G.crack(p, (0.009, 0.004, 0.08), (0.0075, 0.03, 0.17), 2.0, 0.0011, color=G.BONE_OLD)
    tip = path[-4 if worn else -1]
    return dict(tip=(0, tip[0], tip[1]), imbue=(0, 0.03, 0.17), hands=1, kind="knife")


def talon_hook(p, worn):
    """Talon Hook: a single hooked black talon bound to a reed haft with sinew."""
    reed = lambda co: K.mix(G.REED, G.REED_DARK, 0.5 + 0.5 * math.sin(co.z * 75.0))      # noqa: E731
    prof = []
    for i in range(10):                              # a jointed river reed
        z = -0.14 + 0.05 * i
        prof += [(0.0105, z), (0.0125, z + 0.004), (0.0105, z + 0.008)]
    p.add(K.lathe([(0.0, -0.142)] + prof + [(0.0, 0.325)], 7), G.REED, "satin", shade=reed)
    cy, cz, rr = 0.075, 0.30, 0.085
    path = [(-0.03, 0.335)] + G.arc(cy, cz, rr, 128, -28, 12, 0.8)
    _talon(p, path, 0.016, worn, 3.0)
    p.add(G.lash(0.016, 0.27, 0.34, 9, 0.004, 4, 1.5, 0.001, 2.0), G.SINEW, "matte", T(0, -0.004, 0))
    p.add(G.lash(0.013, -0.05, 0.05, 7, 0.0038, 4), G.SINEW, "matte")
    if worn:
        G.crack(p, (0.011, 0.002, 0.06), (0.0112, -0.003, 0.24), 2.0, 0.0014, color=G.BONE_DARK)
    tip = path[-4 if worn else -1]
    return dict(tip=(0, tip[0], tip[1]), imbue=(0, cy, cz + 0.07), hands=1, kind="sickle")


def fishers_gaff(p, worn):
    """Fisher's Gaff: a mortal fisherman's iron hook on an alder pole, the
    line still knotted round it, the pole scored with claw marks."""
    p.add(G.shaft(1.86, 0.019, 0.015, 23.0, 0.02, 2, 8, -0.80), ALDER, "satin", shade=G.wood(ALDER, 3.0, 0.3))
    top = 1.06
    p.add(K.lathe([(0.018, top - 0.11), (0.0195, top - 0.09), (0.017, top - 0.005), (0.012, top + 0.02)], 8), G.IRON, "satin", shade=GL._iron(2.0))   # socket
    cy, cz, rr = 0.062, top + 0.03, 0.062
    hook = [(0.0, 0.0, top)] + [(0.0, y, z) for y, z in G.arc(cy, cz, rr, 180, -62, 13)]
    rad = [0.0085] + [0.008 * (1.0 - (i / 13) ** 2.2) + 0.0008 for i in range(14)]
    if worn:                                         # bent open and blunted
        hook, rad = hook[:-3], rad[:-3]
    p.add(K.tube(hook, rad, 6), G.IRON, "satin", shade=GL._edge_iron(4.0, lambda co: -(co.z - cz) + (co.y - cy), 0.04, 0.09, worn))
    p.add(G.lash(0.02, top - 0.20, top - 0.12, 7, 0.0026, 3, 1.0, 0.002, 4.0), G.HIDE_PALE, "fabric")          # the fishing line
    line = [(0.02, 0, top - 0.2), (0.035, 0.01, top - 0.32), (0.022, -0.012, top - 0.45), (0.03, 0.0, top - 0.58)]
    p.add(K.tube(line, 0.0018, 3), G.HIDE_PALE, "fabric")
    p.add(K.lathe([(0.0, -0.012), (0.008, -0.006), (0.008, 0.006), (0.0, 0.012)], 6), (0.52, 0.30, 0.20), "satin", T(0.03, 0.0, top - 0.60))         # a cork float
    for k, zc in enumerate((0.42, -0.30) if not worn else (0.42, -0.30, 0.74)):                                 # claw marks: three pale scores
        for i in range(3):
            a = math.radians(-60 + 30 * i + 40 * k)
            x, y = 0.0185 * math.sin(a), -0.0185 * math.cos(a)
            p.add(K.tube([(x, y, zc - 0.07 + 0.012 * i), (x * 1.03, y * 1.03, zc), (x, y, zc + 0.07 + 0.012 * i)], [0.0006, 0.0022, 0.0006], 3),
                  K.lighter(ALDER, 0.5), "matte")
    p.add(G.lash(0.02, -0.07, 0.07, 5, 0.0045, 4), G.HIDE, "fabric")
    if worn:
        G.crack(p, (0.017, 0.006, 0.55), (0.016, -0.004, 0.9), 3.0, 0.0018)
    tip = hook[-1]
    return dict(tip=(0, tip[1], tip[2]), imbue=(0, cy, cz + 0.05), hands=2, kind="spear")


# ================================================================== camp gear


def _weave(freq_z=95.0, spokes=18):
    return lambda co: K.mix(G.REED, G.REED_DARK, 0.5 + 0.5 * math.sin(co.z * freq_z) * math.sin(math.atan2(co.y, co.x) * spokes))


def reed_cache(p):
    """Reed cache: a basket of woven reeds sunk half in the water and weighted
    with stones. The woven lid is the child mesh, hinged at the back."""
    body = K.lathe([(0.0, 0.0), (0.26, 0.01), (0.36, 0.12), (0.39, 0.30), (0.35, 0.44), (0.33, 0.46), (0.31, 0.44), (0.34, 0.30), (0.30, 0.10)], 18,
                   cap_top=False)
    p.add(body, G.REED, "matte", shade=_weave())
    p.add(K.torus(0.345, 0.022, 18, 5), G.REED_DARK, "matte", T(0, 0, 0.45), shade=_weave(300.0, 40))
    p.add(K.lathe([(0.0, 0.10), (0.30, 0.10)], 12, cap_bottom=False), G.CHAR, "matte")                       # the dark inside
    for i in range(18):                              # the stakes the weave runs round
        a = 2 * math.pi * i / 18
        p.add(K.tube([(0.30 * math.cos(a), 0.30 * math.sin(a), 0.02), (0.395 * math.cos(a), 0.395 * math.sin(a), 0.3), (0.35 * math.cos(a), 0.35 * math.sin(a), 0.5)],
                     0.006, 3), G.REED_DARK, "matte")
    G.ground_ring(p, 0.50, 7, 0.13, 6.0, G.GRANITE, 0.6)
    for i in range(3):                               # weights tied to the rim
        a = math.radians(40 + 120 * i)
        q = (0.36 * math.cos(a), 0.36 * math.sin(a))
        p.add(K.tube([(q[0], q[1], 0.45), (q[0] * 1.15, q[1] * 1.15, 0.28)], 0.004, 3), G.SINEW, "matte")
        p.add(G.stone(0.06, 20.0 + i, 0.85, 2), G.FLINT, "satin", T(q[0] * 1.17, q[1] * 1.17, 0.24), shade=G.mottle(G.FLINT, G.CHAR, 50.0, i))
    for i in range(7):                               # water weed caught on it
        a = 2 * math.pi * h1(i, 3.0)
        p.add(G.rag(0.2 + 0.12 * h1(i, 4.0), 0.03, 7.0 + i, 0.3, 5), G.SCALE, "satin", T(0.39 * math.cos(a), 0.39 * math.sin(a), 0.25 + 0.15 * h1(i, 5.0)) @ R("Z", math.degrees(a)))
    lid = G.Prop("lid")
    hinge = Vector((0.0, 0.33, 0.47))
    lift = math.radians(-28)
    dome = K.lathe([(0.0, 0.07), (0.15, 0.06), (0.30, 0.025), (0.36, 0.0), (0.34, -0.012)], 18, cap_bottom=False, cap_top=False)
    lm = R("X", math.degrees(lift)) @ T(0, -0.33, 0.012)
    lid.add(dome, G.REED, "matte", lm, shade=lambda co: K.mix(G.REED, G.REED_DARK, 0.5 + 0.5 * math.sin(math.hypot(co.x, co.y) * 110.0) * math.sin(math.atan2(co.y, co.x) * 18)))
    lid.add(K.torus(0.355, 0.016, 18, 4), G.REED_DARK, "matte", lm)
    lid.add(K.tube(K.arc_pts(0.0, 0.07, 0.05, 0.05, 0, 180, 6), 0.007, 4), G.SINEW, "matte", lm)             # its loop handle
    return dict(kind="hoard", loot=(0, 0, 0.42), parts={"lid": (lid, tuple(hinge))})


def basking_stone(p):
    """Basking stone: a flat sun-warmed slab with claw scratches, a shed skin
    draped over its edge."""
    bm = U.rock(1.0, 3, 4.0, 0.14)
    for v in bm.verts:
        v.co.x *= 1.02
        v.co.y *= 0.72
        v.co.z = v.co.z * 0.30 + 0.27
        if v.co.z > 0.42:
            v.co.z = 0.42 + (v.co.z - 0.42) * 0.3 + 0.012 * wob(v.co.x * 5 + v.co.y * 4, 2.0)
    warm = G.grim(0.33, 0.29, 0.25)
    p.add(bm, warm, "matte", shade=G.mottle(warm, K.darker(warm, 0.4), 7.0, 1.0, G.MOSS))
    for k, (x, y, rot) in enumerate(((-0.35, -0.2, 20), (0.3, 0.12, -35), (0.05, -0.38, 70))):               # claw scratches, four abreast
        for i in range(4):
            m = T(x, y, 0.445) @ R("Z", rot) @ T(0, 0.035 * i, 0)
            p.add(K.tube([(-0.16, 0, -0.003), (0.0, 0.006 * i, 0.002), (0.17 + 0.02 * i, 0, -0.003)], [0.001, 0.005, 0.001], 3),
                  K.lighter(warm, 0.35), "matte", m)
    skin = []
    for i in range(16):                              # the shed skin: over the top and down the front
        t = i / 15
        skin.append((-0.55 + 0.9 * t + 0.08 * math.sin(t * 9), -0.15 - 0.62 * t ** 1.6, 0.46 - 0.38 * U._smooth(0.55, 1.0, t)))
    rad = [0.02] + [0.07 + 0.012 * math.sin(i * 1.3) for i in range(13)] + [0.04, 0.008]
    sk = K.tube(skin, rad, 7)
    for v in sk.verts:
        v.co.z = 0.44 + (v.co.z - 0.44) * 0.35 if v.co.y > -0.5 else v.co.z
    pale = K.lighter(G.SCALE_PALE, 0.25)
    p.add(sk, pale, "pearl", shade=lambda co: K.mix(pale, G.SCALE_PALE, 0.5 + 0.5 * math.sin(co.x * 170) * math.sin(co.y * 170)))
    G.ground_ring(p, 1.02, 5, 0.12, 12.0)
    return dict(kind="dressing", rest=(0, 0, 0.45))


def _fish_bones(p, m, ln, seed):
    p.add(K.tube([(0, 0, 0), (0.004 * wob(seed), 0, ln * 0.5), (0, 0, ln)], [0.004, 0.0035, 0.0015], 4), G.BONE, "matte", m)
    for i in range(7):
        z = ln * (0.16 + 0.1 * i)
        w = ln * 0.15 * math.sin(math.pi * (0.2 + 0.1 * i))
        for sx in (-1, 1):
            p.add(K.tube([(0, 0, z), (sx * w, 0, z - ln * 0.035)], [0.002, 0.0006], 3), G.BONE, "matte", m)
    p.add(U.sphere(ln * 0.07, 6, 5), G.BONE, "matte", m @ T(0, 0, -ln * 0.03) @ S(0.8, 0.5, 1.5))
    p.add(K.leaf(ln * 0.16, ln * 0.14), G.BONE_OLD, "matte", m @ T(0, 0, ln) @ R("Y", -90))


def midden(p):
    """Midden: what they eat, heaped at the waterline. Fish bones, a deer's
    ribs and one torn mortal boot."""
    p.add(K.lathe([(0.0, 0.14), (0.3, 0.11), (0.55, 0.04), (0.72, 0.0)], 14, cap_bottom=False), MUD, "matte", S(1.0, 0.85, 1.0),
          shade=G.mottle(MUD, K.darker(MUD, 0.4), 14.0, 1.0, G.SCALE))
    m = T(-0.05, 0.05, 0.19) @ R("Z", 35) @ R("X", 8)                                                         # the deer: spine and ribs
    p.add(K.tube([(-0.42, 0, 0.19), (-0.1, 0, 0.21), (0.3, 0, 0.17), (0.42, 0, 0.11)], [0.018, 0.02, 0.018, 0.012], 6), G.BONE, "matte", m,
          shade=G.mottle(G.BONE, G.BONE_OLD, 60.0, 1.0, G.BLOOD))
    for i in range(9):
        x = -0.34 + 0.075 * i
        for sx in (-1, 1):
            if (i * 3 + sx) % 7 == 0:                # some are cracked off
                continue
            rib = [(x, 0, 0.20), (x, sx * 0.15, 0.17), (x + 0.02, sx * 0.20, 0.04), (x + 0.03, sx * 0.13, -0.10)]
            p.add(K.tube(rib, [0.009, 0.008, 0.006, 0.003], 4), G.BONE, "matte", m, shade=G.mottle(G.BONE, G.BONE_OLD, 80.0, i))
    G.skull_on(p, T(0.48, 0.34, 0.11) @ R("Z", 60) @ R("Y", 22), 0.085, G.BONE, 2.0, 1.25, 0.0)
    for i in range(7):
        a = 2 * math.pi * h1(i, 2.0)
        d = 0.3 + 0.32 * h1(i, 3.0)
        _fish_bones(p, T(d * math.cos(a), d * math.sin(a) * 0.85, 0.07 + 0.05 * h1(i, 5.0)) @ R("Z", 360 * h1(i, 4.0)) @ R("Y", 84), 0.22 + 0.14 * h1(i, 6.0), i)
    GL._boot(p, T(-0.42, -0.34, 0.07) @ R("Z", 150) @ R("Y", 78) @ S(1.1))
    p.add(G.rag(0.2, 0.09, 4.0, 0.3, 5), K.darker(G.HIDE, 0.3), "satin", T(-0.52, -0.42, 0.14) @ R("Z", 200) @ R("Y", 60))   # its torn upper
    for i in range(10):                              # scales shed in the mud
        a = 2 * math.pi * h1(i, 8.0)
        d = 0.62 * math.sqrt(h1(i, 9.0))
        p.add(K.lathe([(0.0, 0.0), (0.02, 0.002), (0.0, 0.004)], 6), G.SCALE, "pearl", T(d * math.cos(a), d * math.sin(a) * 0.85, 0.045 + 0.08 * (1 - d / 0.62)))
    return dict(kind="dressing")


def reed_nest(p):
    """Reed nest: a coil-shaped hollow pressed into reeds and mud, a shed skin
    over its rim."""
    rings = []
    for i in range(26):
        a = 2 * math.pi * i / 26
        r0 = 0.98 * (1 + 0.07 * wob(i * 0.7, 1.0))
        hh = 0.24 * (1 + 0.3 * wob(i * 0.9, 2.0))
        c = Vector((r0 * math.cos(a), r0 * math.sin(a), 0))
        out = Vector((math.cos(a), math.sin(a), 0))
        rings.append([tuple(c + out * 0.27), tuple(c + out * 0.10 + Vector((0, 0, hh))), tuple(c - out * 0.14 + Vector((0, 0, hh * 0.85))), tuple(c - out * 0.3)])
    rings.append(rings[0])
    p.add(G.loft(rings, False, False), G.REED, "matte",
          shade=lambda co: K.mix(G.REED_DARK, G.REED, 0.5 + 0.5 * math.sin(math.atan2(co.y, co.x) * 60 + co.z * 70)))
    floor = K.lathe([(0.0, 0.03), (0.2, 0.035), (0.45, 0.03), (0.74, 0.06)], 16, cap_bottom=False)
    p.add(floor, MUD, "matte",                       # the coil pressed into the mud
          shade=lambda co: K.mix(MUD, K.darker(MUD, 0.5), 0.5 + 0.5 * math.sin(math.hypot(co.x, co.y) * 26 - math.atan2(co.y, co.x))))
    for i in range(54):                              # broken reeds standing out of the weave
        a = 2 * math.pi * h1(i, 3.0)
        r0 = 0.98 + 0.22 * (h1(i, 4.0) - 0.5)
        ln = 0.3 + 0.6 * h1(i, 5.0)
        m = T(r0 * math.cos(a), r0 * math.sin(a), 0.1) @ R("Z", math.degrees(a)) @ R("Y", 15 + 45 * h1(i, 6.0)) @ R("Z", 360 * h1(i, 7.0))
        p.add(K.cyl(0.007, ln, 3, r2=0.002), K.mix(G.REED, G.REED_DARK, h1(i, 8.0)), "matte", m)
    skin = [(0.95 * math.cos(0.9 + 1.5 * i / 11) * (1 + 0.1 * i / 11), 0.95 * math.sin(0.9 + 1.5 * i / 11) * (1 + 0.1 * i / 11), 0.31 - 0.2 * (i / 11) ** 2)
            for i in range(12)]
    pale = K.lighter(G.SCALE_PALE, 0.25)
    p.add(K.tube(skin, [0.05, 0.06, 0.06, 0.055, 0.05, 0.05, 0.045, 0.04, 0.03, 0.025, 0.015, 0.005], 6), pale, "pearl", S(1, 1, 0.6) @ T(0, 0, 0.14),
          shade=lambda co: K.mix(pale, G.SCALE_PALE, 0.5 + 0.5 * math.sin(co.x * 150) * math.sin(co.y * 150)))
    for i in range(4):
        _fish_bones(p, T(0.45 * wob(i, 5.0), 0.45 * wob(i, 6.0), 0.06) @ R("Z", 73 * i) @ R("Y", 86), 0.26, i)
    return dict(kind="rest", rest=(0, 0, 0.06))


WEAPONS = {
    "wpn_naga_talon_knife": talon_knife,
    "wpn_naga_talon_hook": talon_hook,
    "wpn_fishers_gaff": fishers_gaff,
}
CAMP = {
    "camp_naga_reed_cache": reed_cache,
    "camp_naga_basking_stone": basking_stone,
    "camp_naga_midden": midden,
    "camp_naga_reed_nest": reed_nest,
}
