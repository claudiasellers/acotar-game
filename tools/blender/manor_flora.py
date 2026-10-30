"""Generates the Manor Estate plant models (headless Blender, deterministic).

Run:  /opt/bpyenv/bin/python tools/blender/manor_flora.py [--preview dir]
Out:  world/spring_court/manor_estate/flora/models/<species>.glb
      Nodes "<species>" and "<species>_lod1". Base at the origin,
      scaled uniformly to the species height in flora_lib.gd. Every surface is
      the "leaf" finish: colour lives in vertex colours so the game can draw
      each species with the shared stylized_foliage shader in one draw call.

Look (experience bar 2.2/2.7): oversized blooms, mint-sage foliage (never
lime), rose-taupe bark, one blossom hue per bed. Budgets: flowers <= 700 tris,
shrubs <= 1,200, trees <= 3,000 (scatter draws thousands of these).
"""

import math
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,I001
import prop_kit as K  # noqa: E402
from prop_kit import (BARK, BUTTER, LEAF, LEAF_DARK, R, S, SAGE_DEEP, SAGE_LIGHT, SAGE_SHADOW, T, WHITE, bloom, ico,  # noqa: E402
                      leaf, lighter, lathe, mix, petal, sphere, star_flower, tube, cyl)

OUT = os.path.join(K.ROOT, "world/spring_court/manor_estate/flora/models")
F = "leaf"
BUDGET = {"flower": 700, "groundcover": 600, "aquatic": 600, "reed": 400, "bush": 1200, "climber": 1600, "tree": 3000}


def species():
    path = os.path.join(K.ROOT, "world/spring_court/manor_estate/flora/flora_lib.gd")
    out = {}
    for m in re.finditer(r'&"(\w+)": \[&"(\w+)", ([\d.]+), Color\(([^)]*)\)\]', open(path).read()):
        out[m.group(1)] = (m.group(2), float(m.group(3)), tuple(float(v) for v in m.group(4).split(",")))
    return out


def stem(p, a, b, r=0.01, col=LEAF_DARK, sides=3):
    p.add(tube([a, b], [r, r * 0.7], sides, caps=False), col, F)


def blob(p, x, y, z, r, col, rng, sub=1, squash=0.85):
    b = ico(r, sub)
    for v in b.verts:
        v.co *= 1.0 + rng.uniform(-0.08, 0.08)
    p.add(b, col, F, T(x, y, z) @ S(1, 1, squash), sharp_deg=89.0)


# ------------------------------------------------------------ shrubs


def rose_bush(p, h, col, rng):
    """Mounded rose shrub smothered in big cupped blooms."""
    r = h * 0.45
    for i in range(6):
        a = 2 * math.pi * i / 6 + rng.uniform(-0.2, 0.2)
        blob(p, r * 0.5 * math.cos(a), r * 0.5 * math.sin(a), h * 0.45, r * 0.55, LEAF if i % 2 else LEAF_DARK, rng)
    blob(p, 0, 0, h * 0.7, r * 0.6, mix(LEAF, SAGE_LIGHT, 0.3), rng)
    for i in range(8):
        a = 2 * math.pi * i / 8 + rng.uniform(-0.3, 0.3)
        e = rng.uniform(0.1, 1.1)
        x, y = r * 0.85 * math.cos(a) * math.cos(e), r * 0.85 * math.sin(a) * math.cos(e)
        z = h * 0.55 + r * 0.75 * math.sin(e)
        c = col if i % 3 else lighter(col, 0.2)
        bloom(p, (x, y, z), h * 0.13 * rng.uniform(0.85, 1.15), c, 2, 5, rng, finish=F,
              tilt=R("Z", math.degrees(a)) @ R("Y", 90 - math.degrees(e) * 0.8))


def hedge(p, h, col, rng):
    """Clipped box hedge block (rounded), 1.6 m long module."""
    w = h * 0.6
    b = K.box(w * 1.6, w, h, bevel=w * 0.3, seg=2)
    for v in b.verts:
        v.co *= 1.0 + rng.uniform(-0.02, 0.02)
    p.add(b, col, F, T(0, 0, h / 2))
    for i in range(10):
        x = rng.uniform(-w * 0.7, w * 0.7)
        z = rng.uniform(h * 0.2, h * 0.95)
        s = rng.choice((-1, 1))
        blob(p, x, s * w * 0.47, z, w * 0.14, lighter(col, 0.12), rng, 0, 1.0)


def blossom_shrub(p, h, col, rng, panicles=True):
    """Elderflower / lilac: leafy mound with upright conical flower panicles."""
    r = h * 0.4
    for i in range(5):
        a = 2 * math.pi * i / 5
        blob(p, r * 0.45 * math.cos(a), r * 0.45 * math.sin(a), h * 0.45, r * 0.6, LEAF if i % 2 else LEAF_DARK, rng)
    blob(p, 0, 0, h * 0.68, r * 0.62, LEAF, rng)
    p.add(tube([(0, 0, 0), (0.02, 0, h * 0.4)], [h * 0.04, h * 0.03], 5), BARK, F)
    for i in range(10):
        a = rng.uniform(0, 2 * math.pi)
        e = rng.uniform(0.2, 1.2)
        x, y = r * 0.85 * math.cos(a) * math.cos(e), r * 0.85 * math.sin(a) * math.cos(e)
        z = h * 0.6 + r * 0.8 * math.sin(e)
        if panicles:
            p.add(lathe([(0, 0), (h * 0.06, h * 0.04), (h * 0.045, h * 0.12), (0, h * 0.2)], 6), col if i % 2 else lighter(col, 0.2), F,
                  T(x, y, z) @ R("Z", math.degrees(a)) @ R("Y", 30 * math.cos(e)))
        else:   # flat umbels (elderflower)
            p.add(lathe([(0, 0), (h * 0.08, h * 0.03), (h * 0.07, h * 0.05), (0, h * 0.055)], 7), col, F, T(x, y, z))


def bramble(p, h, col, rng):
    r = h * 0.5
    for i in range(5):
        a = 2 * math.pi * i / 5
        blob(p, r * 0.5 * math.cos(a), r * 0.5 * math.sin(a), h * 0.4, r * 0.5, LEAF_DARK if i % 2 else SAGE_DEEP, rng)
    for i in range(6):
        a = 2 * math.pi * i / 6
        arc = [(0, 0, h * 0.3), (r * 0.6 * math.cos(a), r * 0.6 * math.sin(a), h * 0.95), (r * 1.1 * math.cos(a), r * 1.1 * math.sin(a), h * 0.3)]
        p.add(tube(arc, 0.012, 3, caps=False), mix(BARK, LEAF_DARK, 0.3), F)
    for i in range(14):
        a = rng.uniform(0, 2 * math.pi)
        e = rng.uniform(0.1, 1.0)
        x, y, z = r * 0.95 * math.cos(a) * math.cos(e), r * 0.95 * math.sin(a) * math.cos(e), h * 0.4 + r * 0.6 * math.sin(e)
        if i % 3 == 0:
            star_flower(p, (x, y, z), h * 0.04, WHITE, 5, finish=F, heart=BUTTER, facing=R("Z", math.degrees(a)) @ R("Y", 70))
        else:
            for k in range(3):
                p.add(ico(h * 0.018, 0), col if i % 2 else (0.85, 0.35, 0.5), F, T(x + 0.015 * k, y, z - 0.012 * k), smooth=False)


# ------------------------------------------------------------ flowers


def clump_leaves(p, h, n, rng, col=LEAF, length=0.5):
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.2, 0.2)
        p.add(leaf(h * length, h * 0.15), col if i % 2 else LEAF_DARK, F, R("Z", math.degrees(a)) @ R("Y", -rng.uniform(25, 50)))


def spike_flower(p, h, col, rng, n=5, bells=False):
    """Lavender / foxglove / hyacinth: spikes of florets above a leaf rosette."""
    clump_leaves(p, h, 6, rng, length=0.45 if not bells else 0.35)
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.3, 0.3)
        lean = rng.uniform(4, 14)
        top = h * rng.uniform(0.85, 1.0)
        m = R("Z", math.degrees(a)) @ R("Y", lean)
        stem(p, (0, 0, 0), tuple(m @ K.Vector((0, 0, top * 0.98))), h * 0.012 + 0.002)
        k = 6 if bells else 5
        for j in range(k):
            t = 0.45 + 0.55 * j / k
            pos = m @ K.Vector((0, 0, top * t))
            c = col if j % 2 else lighter(col, 0.2)
            if bells:
                p.add(lathe([(0, 0), (h * 0.035, -h * 0.02), (h * 0.045, -h * 0.07), (h * 0.02, -h * 0.07)], 6, cap_bottom=False, cap_top=False), c, F,
                      T(*pos) @ R("Z", 90 * j) @ R("Y", 70) @ T(h * 0.02, 0, 0))
            else:
                p.add(ico(h * 0.04 * (1.2 - t * 0.5), 0), c, F, T(*pos) @ S(1, 1, 1.4))


def tulip(p, h, col, rng):
    clump_leaves(p, h, 5, rng, length=0.55)
    for i in range(4):
        a = 2 * math.pi * i / 4 + rng.uniform(-0.3, 0.3)
        top = h * rng.uniform(0.8, 1.0)
        x, y = 0.12 * h * math.cos(a), 0.12 * h * math.sin(a)
        stem(p, (0, 0, 0), (x, y, top), 0.006)
        c = col if i % 2 else lighter(col, 0.25)
        p.add(lathe([(0, 0), (h * 0.09, h * 0.05), (h * 0.1, h * 0.16), (h * 0.07, h * 0.24)], 6, cap_top=False), c, F, T(x, y, top))
        for k in range(3):
            p.add(petal(h * 0.22, h * 0.14, cup=0.25, curl=-0.1), c, F, T(x, y, top) @ R("Z", 120 * k + 60) @ R("Y", -72))


def peony(p, h, col, rng):
    r = h * 0.4
    for i in range(5):
        a = 2 * math.pi * i / 5
        blob(p, r * 0.5 * math.cos(a), r * 0.5 * math.sin(a), h * 0.38, r * 0.45, LEAF if i % 2 else LEAF_DARK, rng, 1, 0.7)
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.4
        x, y = r * 0.6 * math.cos(a), r * 0.6 * math.sin(a)
        z = h * rng.uniform(0.75, 0.9)
        bloom(p, (x, y, z), h * 0.17, col if i % 2 else lighter(col, 0.25), 2, 6, rng, finish=F,
              tilt=R("Z", math.degrees(a)) @ R("Y", 25))


def small_stars(p, h, col, rng, n=7, heart=BUTTER, petals=5):
    """Daisy / forget-me-not / wild strawberry / faelight dandelion clumps."""
    clump_leaves(p, h, 6, rng, length=0.8)
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.3, 0.3)
        d = h * rng.uniform(0.15, 0.55)
        x, y, top = d * math.cos(a), d * math.sin(a), h * rng.uniform(0.7, 1.0)
        stem(p, (0, 0, 0), (x, y, top), 0.004)
        star_flower(p, (x, y, top), h * 0.14, col, petals, finish=F, heart=heart, facing=R("Z", math.degrees(a)) @ R("Y", 20))


def dandelion(p, h, col, rng):
    clump_leaves(p, h, 6, rng, length=0.9)
    for i in range(3):
        a = 2 * math.pi * i / 3
        x, y, top = h * 0.2 * math.cos(a), h * 0.2 * math.sin(a), h * rng.uniform(0.75, 1.0)
        stem(p, (0, 0, 0), (x, y, top), 0.004, SAGE_LIGHT)
        p.add(ico(h * 0.16, 1), col, F, T(x, y, top))       # glowing seed puff
        p.add(ico(h * 0.07, 0), lighter(col, 0.4), F, T(x, y, top + h * 0.14))


def strawberry(p, h, col, rng):
    for i in range(7):
        a = 2 * math.pi * i / 7
        p.add(leaf(h * 1.1, h * 0.75), LEAF if i % 2 else LEAF_DARK, F, R("Z", math.degrees(a)) @ R("Y", -35) @ T(0, 0, h * 0.2))
    for i in range(5):
        a = 2 * math.pi * i / 5 + rng.uniform(-0.3, 0.3)
        x, y = h * 0.55 * math.cos(a), h * 0.55 * math.sin(a)
        top = h * rng.uniform(0.85, 1.0)
        stem(p, (0, 0, 0), (x, y, top), 0.004)
        if i % 2:   # a berry hanging from the stem tip
            p.add(lathe([(0, 0), (h * 0.18, h * 0.08), (h * 0.12, h * 0.25), (0, h * 0.3)], 6), col, F, T(x, y, top) @ R("X", 180))
        else:
            star_flower(p, (x, y, top), h * 0.2, WHITE, 5, finish=F)


def iris(p, h, col, rng):
    """Sword leaves and three tall stems, each with falls and standards."""
    clump_leaves(p, h, 7, rng, length=0.85)
    for i in range(3):
        a = 2 * math.pi * i / 3 + rng.uniform(-0.3, 0.3)
        x, y, top = h * 0.12 * math.cos(a), h * 0.12 * math.sin(a), h * rng.uniform(0.85, 1.0)
        stem(p, (0, 0, 0), (x, y, top - h * 0.08), 0.006)
        for k in range(3):
            p.add(petal(h * 0.18, h * 0.1, cup=0.2, curl=0.25), col, F, T(x, y, top - h * 0.1) @ R("Z", 120 * k) @ R("Y", 55))
            p.add(petal(h * 0.15, h * 0.08, cup=0.35, curl=-0.15), lighter(col, 0.3), F, T(x, y, top - h * 0.1) @ R("Z", 120 * k + 60) @ R("Y", -20))
        p.add(ico(h * 0.025, 0), BUTTER, F, T(x, y, top - h * 0.08))


def madder(p, h, col, rng):
    """Whorled scrambling stems topped with tiny pale-yellow flower clusters."""
    for i in range(6):
        a = 2 * math.pi * i / 6 + rng.uniform(-0.3, 0.3)
        top = h * rng.uniform(0.75, 1.0)
        x, y = h * 0.25 * math.cos(a), h * 0.25 * math.sin(a)
        stem(p, (0, 0, 0), (x, y, top), 0.005, col)
        for t in (0.35, 0.6, 0.85):
            for k in range(4):
                p.add(leaf(h * 0.12, h * 0.03), col if k % 2 else LEAF_DARK, F,
                      T(x * t, y * t, top * t) @ R("Z", 90 * k + 45 * t) @ R("Y", -60))
        for k in range(3):
            p.add(ico(h * 0.025, 0), BUTTER, F, T(x + rng.uniform(-0.02, 0.02), y + rng.uniform(-0.02, 0.02), top + h * 0.03 * k))


def orchid(p, h, col, rng):
    """Broad basal leaves and two arching sprays of moth-orchid blooms."""
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.3
        p.add(leaf(h * 0.45, h * 0.18), LEAF if i % 2 else LEAF_DARK, F, R("Z", math.degrees(a)) @ R("Y", -65))
    for s_i in range(2):
        a = math.pi * s_i + 0.4
        pts = [(0, 0, 0), (h * 0.08 * math.cos(a), h * 0.08 * math.sin(a), h * 0.6), (h * 0.3 * math.cos(a), h * 0.3 * math.sin(a), h * 0.95)]
        p.add(tube(pts, [0.005, 0.004, 0.003], 3, caps=False), LEAF_DARK, F)
        for k in range(4):
            t = 0.45 + k * 0.17
            x, y = h * 0.3 * t * math.cos(a), h * 0.3 * t * math.sin(a)
            z = h * (0.62 + 0.33 * t)
            star_flower(p, (x, y, z), h * 0.12, col if k % 2 else lighter(col, 0.3), 5, finish=F, heart=(0.95, 0.55, 0.7),
                        facing=R("Z", math.degrees(a)) @ R("Y", 70))


def herb_patch(p, h, col, rng):
    for i in range(5):
        a = 2 * math.pi * i / 5
        blob(p, h * 0.35 * math.cos(a), h * 0.35 * math.sin(a), h * 0.45, h * 0.32, col if i % 2 else mix(col, SAGE_LIGHT, 0.4), rng, 1, 1.1)
    for i in range(6):
        a = rng.uniform(0, 2 * math.pi)
        p.add(ico(h * 0.05, 0), (0.82, 0.68, 1.0) if i % 2 else WHITE, F, T(h * 0.45 * math.cos(a), h * 0.45 * math.sin(a), h * 0.85))


def vegetable_row(p, h, col, rng):
    for k in range(4):
        x = -h * 1.2 + k * h * 0.8
        for i in range(5):
            a = 2 * math.pi * i / 5 + k
            p.add(leaf(h * 0.7, h * 0.35), col if i % 2 else LEAF_DARK, F, T(x, 0, h * 0.05) @ R("Z", math.degrees(a)) @ R("Y", -45))
        if k % 2 == 0:
            p.add(ico(h * 0.2, 1), (0.6, 0.85, 0.55), F, T(x, 0, h * 0.2))
        else:
            p.add(ico(h * 0.12, 0), (0.98, 0.55, 0.4), F, T(x, 0, h * 0.08))


def fern(p, h, col, rng):
    for i in range(7):
        a = 2 * math.pi * i / 7 + rng.uniform(-0.2, 0.2)
        L = h * rng.uniform(0.9, 1.15)
        pts = [(0, 0, 0), (L * 0.45 * math.cos(a), L * 0.45 * math.sin(a), h * 0.75), (L * math.cos(a), L * math.sin(a), h * 0.45)]
        p.add(tube(pts, [0.006, 0.005, 0.002], 3, caps=False), LEAF_DARK, F)
        for j in range(5):
            t = 0.2 + j * 0.16
            x, y = L * t * math.cos(a), L * t * math.sin(a)
            z = h * (0.75 * math.sin(math.pi * t * 0.85))
            for s_ in (-1, 1):
                p.add(leaf(h * 0.28 * (1.15 - t), h * 0.08), col if j % 2 else lighter(col, 0.1), F,
                      T(x, y, z) @ R("Z", math.degrees(a) + s_ * 75) @ R("Y", 10))


def starmoss(p, h, col, rng):
    for i in range(7):
        a = 2 * math.pi * i / 7
        d = 0.18 if i else 0.0
        blob(p, d * math.cos(a), d * math.sin(a), 0.0, 0.16, col if i % 2 else lighter(col, 0.15), rng, 1, 0.35)
    for i in range(4):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.0, 0.3)
        star_flower(p, (d * math.cos(a), d * math.sin(a), 0.055), 0.035, (1.0, 0.98, 0.85), 5, finish=F, heart=WHITE)


def glowcap(p, h, col, rng):
    for i in range(5):
        a = 2 * math.pi * i / 5 + rng.uniform(-0.3, 0.3)
        d = rng.uniform(0.03, 0.12)
        s = rng.uniform(0.6, 1.1)
        x, y = d * math.cos(a), d * math.sin(a)
        p.add(cyl(0.012 * s, h * 0.6 * s, 5), (0.95, 0.95, 0.88), F, T(x, y, 0))
        p.add(lathe([(0, 0), (0.05 * s, 0.0), (0.045 * s, 0.03 * s), (0.02 * s, 0.05 * s), (0, 0.055 * s)], 7), col, F, T(x, y, h * 0.55 * s))


def reed(p, h, col, rng):
    for i in range(10):
        a = 2 * math.pi * i / 10 + rng.uniform(-0.3, 0.3)
        lean = rng.uniform(3, 16)
        top = h * rng.uniform(0.7, 1.0)
        m = R("Z", math.degrees(a)) @ R("Y", lean)
        tip = m @ K.Vector((0, 0, top))
        p.add(tube([(0, 0, 0), tuple(m @ K.Vector((0, 0, top * 0.5))), tuple(tip)], [0.012, 0.008, 0.002], 3, caps=False), col if i % 2 else LEAF_DARK, F)
        if i % 3 == 0:
            p.add(cyl(0.018, top * 0.14, 5), (0.78, 0.6, 0.62), F, T(*(m @ K.Vector((0, 0, top * 0.72)))) @ m)


def water_lily(p, h, col, rng):
    for i in range(3):
        a = 2 * math.pi * i / 3
        x, y = 0.28 * math.cos(a), 0.28 * math.sin(a)
        pad = lathe([(0, 0), (0.22, 0.0), (0.22, 0.01), (0, 0.01)], 10)
        for v in pad.verts:   # the notch
            if v.co.x > 0.05 and abs(v.co.y) < 0.03:
                v.co.x *= 0.4
        p.add(pad, LEAF if i % 2 else SAGE_DEEP, F, T(x, y, 0) @ R("Z", rng.uniform(0, 360)))
    bloom(p, (0.0, 0.0, 0.03), 0.13, col, 2, 6, rng, finish=F)
    bloom(p, (0.3, -0.25, 0.02), 0.08, lighter(col, 0.3), 2, 5, rng, finish=F)


# ------------------------------------------------------------ climbers


def climber(p, h, col, rng, kind="rose"):
    """Climbing plant on its own little trellis panel (wall-mounted look)."""
    w = h * 0.45
    for x in (-w / 2, 0, w / 2):
        p.add(K.box(0.03, 0.03, h), (0.98, 0.95, 0.93), F, T(x, -0.05, h / 2), smooth=False)
    for z in (h * 0.3, h * 0.6, h * 0.9):
        p.add(K.box(w + 0.1, 0.03, 0.03), (0.98, 0.95, 0.93), F, T(0, -0.05, z), smooth=False)
    pts = [(rng.uniform(-w / 2, w / 2), 0.03, h * t) for t in [i / 8 for i in range(9)]]
    p.add(tube(pts, [0.02 - 0.0015 * i for i in range(9)], 3, caps=False), BARK, F)
    for i in range(14):
        x = rng.uniform(-w * 0.6, w * 0.6)
        z = rng.uniform(h * 0.15, h)
        blob(p, x, 0.05, z, h * 0.07, LEAF if i % 2 else LEAF_DARK, rng, 0, 0.6)
        if kind == "rose" and i % 2 == 0:
            bloom(p, (x, 0.12, z), h * 0.045, col if i % 4 else lighter(col, 0.25), 2, 5, rng, finish=F, tilt=R("X", -80))
        elif kind == "wisteria" and i % 2 == 0:
            p.add(lathe([(0, 0), (h * 0.04, -h * 0.03), (h * 0.03, -h * 0.12), (0, -h * 0.2)], 6), col if i % 4 else lighter(col, 0.2), F, T(x, 0.1, z))
        elif kind == "honeysuckle" and i % 2 == 0:
            for k in range(4):
                p.add(tube([(x, 0.1, z), (x + 0.06 * math.cos(k * 1.6), 0.14, z + 0.06 * math.sin(k * 1.6))], [0.006, 0.012], 3), col if k % 2 else WHITE, F)


# ------------------------------------------------------------ trees


def tree(p, h, col, rng, kind):
    trunk_h = h * {"willow": 0.4, "oak": 0.35, "birch": 0.5}.get(kind, 0.38)
    bark = (0.95, 0.93, 0.9) if kind == "birch" else BARK
    lean = rng.uniform(-0.04, 0.04) * h
    p.add(tube([(0, 0, 0), (lean * 0.5, 0, trunk_h * 0.6), (lean, 0, trunk_h * 1.1)], [h * 0.035, h * 0.025, h * 0.018], 7), bark, F)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        p.add(tube([(0, 0, 0.0), (h * 0.04 * math.cos(a), h * 0.04 * math.sin(a), -h * 0.01)], [h * 0.025, h * 0.01], 4), bark, F)
    crown_c = (lean, 0, trunk_h + h * 0.28)
    blossom = kind in ("cherry_blossom", "apple_blossom", "crab_apple")
    if kind == "willow":
        for i in range(5):
            a = 2 * math.pi * i / 5
            blob(p, lean + h * 0.15 * math.cos(a), h * 0.15 * math.sin(a), trunk_h + h * 0.25, h * 0.17, col if i % 2 else SAGE_LIGHT, rng, 1, 0.7)
        for i in range(18):   # weeping curtains
            a = 2 * math.pi * i / 18
            r0 = h * 0.22
            pts = [(lean + r0 * math.cos(a), r0 * math.sin(a), trunk_h + h * 0.3), (lean + r0 * 1.35 * math.cos(a), r0 * 1.35 * math.sin(a), trunk_h + h * 0.1),
                   (lean + r0 * 1.5 * math.cos(a), r0 * 1.5 * math.sin(a), h * 0.1)]
            p.add(tube(pts, [h * 0.03, h * 0.025, h * 0.008], 3, caps=False), col if i % 2 else SAGE_LIGHT, F)
        return
    n = 7 if kind == "oak" else 6
    spread = {"oak": 0.32, "birch": 0.17, "pear_tree": 0.2}.get(kind, 0.26)
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.2, 0.2)
        e = rng.uniform(-0.1, 0.5)
        x = lean + h * spread * 0.75 * math.cos(a)
        y = h * spread * 0.75 * math.sin(a)
        z = crown_c[2] + h * spread * 0.4 * math.sin(e) - h * 0.03
        p.add(tube([(lean * 0.9, 0, trunk_h * 0.95), (x * 0.8, y * 0.8, z - h * 0.05)], [h * 0.015, h * 0.008], 4), bark, F)
        c = col if i % 2 else (lighter(col, 0.15) if blossom else mix(col, SAGE_DEEP, 0.35))
        blob(p, x, y, z, h * spread * 0.62, c, rng, 1, 0.8)
    blob(p, crown_c[0], 0, crown_c[2] + h * spread * 0.35, h * spread * 0.75, lighter(col, 0.08), rng, 1, 0.8)
    if blossom or kind == "pear_tree":
        for i in range(16):
            a = rng.uniform(0, 2 * math.pi)
            e = rng.uniform(-0.2, 1.2)
            r = h * spread * 1.05
            x, y = lean + r * math.cos(a) * math.cos(e), r * math.sin(a) * math.cos(e)
            z = crown_c[2] + r * 0.75 * math.sin(e)
            if kind == "pear_tree":
                p.add(lathe([(0, 0), (h * 0.02, h * 0.012), (h * 0.012, h * 0.035), (0, h * 0.045)], 6), (0.85, 0.92, 0.5), F, T(x, y, z - h * 0.05))
            else:
                p.add(ico(h * 0.045, 0), WHITE if i % 3 == 0 else lighter(col, 0.2), F, T(x, y, z))
    if kind == "oak":
        for i in range(5):
            a = 2 * math.pi * i / 5 + 0.3
            blob(p, lean + h * 0.42 * math.cos(a), h * 0.42 * math.sin(a), crown_c[2] - h * 0.04, h * 0.14, mix(col, SAGE_DEEP, 0.3), rng, 1, 0.75)


# ------------------------------------------------------------ table


def build_species(sid, kind, h, col, rng):
    p = K.Prop(sid)
    c = col[:3]
    if sid.startswith("rose_") and kind == "bush":
        rose_bush(p, h, c, rng)
    elif sid == "hedge_box":
        hedge(p, h, mix(c, SAGE_DEEP, 0.25), rng)
    elif sid in ("elderflower",):
        blossom_shrub(p, h, c, rng, panicles=False)
    elif sid == "lilac":
        blossom_shrub(p, h, c, rng, panicles=True)
    elif sid == "blackberry":
        bramble(p, h, c, rng)
    elif sid == "rose_climbing":
        climber(p, h, c, rng, "rose")
    elif sid == "wisteria":
        climber(p, h, c, rng, "wisteria")
    elif sid == "honeysuckle":
        climber(p, h, c, rng, "honeysuckle")
    elif sid == "lavender":
        spike_flower(p, h, c, rng, 5)
    elif sid == "foxglove":
        spike_flower(p, h, c, rng, 3, bells=True)
    elif sid == "wild_hyacinth":
        spike_flower(p, h, c, rng, 3, bells=True)
    elif sid == "tulip_bed":
        tulip(p, h, c, rng)
    elif sid == "peony":
        peony(p, h, c, rng)
    elif sid == "daisy":
        small_stars(p, h, c, rng, 5, BUTTER, 7)
    elif sid == "forget_me_not":
        small_stars(p, h, c, rng, 6, BUTTER, 5)
    elif sid == "faelight_dandelion":
        dandelion(p, h, c, rng)
    elif sid == "crocus":
        tulip(p, h, c, rng)
    elif sid == "buttercup":
        small_stars(p, h, c, rng, 6, (1.0, 0.95, 0.6), 5)
    elif sid == "iris":
        iris(p, h, c, rng)
    elif sid == "madder":
        madder(p, h, c, rng)
    elif sid == "orchid":
        orchid(p, h, c, rng)
    elif sid == "wild_strawberry":
        strawberry(p, h, c, rng)
    elif sid == "herb_patch":
        herb_patch(p, h, c, rng)
    elif sid == "vegetable_row":
        vegetable_row(p, h, c, rng)
    elif sid == "fern":
        fern(p, h, mix(c, SAGE_DEEP, 0.2), rng)
    elif sid == "starmoss":
        starmoss(p, h, c, rng)
    elif sid == "mushroom_glowcap":
        glowcap(p, h, c, rng)
    elif sid == "reed":
        reed(p, h, mix(c, SAGE_DEEP, 0.3), rng)
    elif sid == "water_lily":
        water_lily(p, h, c, rng)
    elif kind == "tree":
        foliage = c if sid in ("cherry_blossom", "apple_blossom", "crab_apple") else mix(c, (0.49, 0.76, 0.6), 0.6)   # pull toward sage
        tree(p, h, foliage, rng, sid)
    else:
        rose_bush(p, h, c, rng)
    # uniform scale to the species height; base stays at the origin
    lo, hi = p.bounds()
    s = h / max(hi.z - lo.z, 1e-3) if hi.z - lo.z > 0.02 else 1.0
    if kind in ("groundcover", "aquatic"):
        s = 1.0
    K.bmesh.ops.transform(p.bm, matrix=S(s) @ T(0, 0, -lo.z), verts=p.bm.verts)
    return p


def main():
    args = sys.argv[1:]
    prev = args[args.index("--preview") + 1] if "--preview" in args else None
    K.reset()
    objs, over = [], []
    for sid, (kind, h, col) in sorted(species().items()):
        rng = random.Random(sum(map(ord, sid)))
        p = build_species(sid, kind, h, col, rng)
        ob = p.to_object(sid)
        n0 = K.mesh_tris(ob)
        lo = K.lod(ob, 0.5)
        lo.name = sid + "_lod1"
        print(f"  {sid:20s} {kind:11s} {n0:5d} tris  lod1 {K.mesh_tris(lo):5d}")
        if n0 > BUDGET[kind]:
            over.append((sid, n0))
        objs += [ob, lo]
        if not prev:
            K.export_glb([ob, lo], os.path.join(OUT, f"{sid}.glb"))
    if prev:
        import manor_props
        for o in objs:
            if o.name.endswith("_lod1"):
                o.hide_render = True
        manor_props.preview([o for o in objs if not o.name.endswith("_lod1")], os.path.join(prev, "flora.png"), 7)
    print(f"{len(objs) // 2} species; over budget: {over}")
    if over:
        sys.exit(1)


if __name__ == "__main__":
    main()
