"""Open-world set props for the wider court (P4 and on): the lesser-fae
village's seamstress and potion-maker interiors, the marked climbables and
sentry dressing of the Western Fells and sea cliffs, more of the Blighted
Reaches, and two cast-routine props. Lane L73. Headless Blender,
deterministic, prop_kit contract (one mesh, finishes in UV.x, front +Y).

Run:  /opt/bpyenv/bin/python tools/blender/wider_world_props.py [--only id,id] [--sheet DIR]
Out:  art/wider_world/<id>.glb (+ "<id>_lod1") and wider_world_manifest.json

All [X] (the plan's regions; the book names none of these objects). The
village is the candy-pastel princess look at full strength (R3); the blight
props are the opposite and stay frightening: drained colour, thorns, bone.
Climbables carry one shared marker so "marked climbing" reads everywhere:
small butter-yellow star flowers (ivy, ledges, holds) or glowcaps (roots).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
from mathutils import Vector  # noqa: E402
import prop_kit as K  # noqa: E402
import upcoming_kit as U  # noqa: E402
from prop_kit import (BLUSH, BUTTER, COPPER, CREAM, GOLD, IRON, LILAC, MINT, OAK, OAK_DARK, PEARL, PERI, ROSE, STRAW,  # noqa: E402
                      WARM_STONE, R, S, T, box, lathe, sphere, torus, tube)

OUT = os.path.join(K.ROOT, "art/wider_world")
FRONT = R("X", -90)
FLAT = R("X", 90)
PASTELS = [ROSE, BLUSH, LILAC, PERI, MINT, BUTTER, PEARL]
GREEN, GREEN_DEEP = K.SAGE, K.SAGE_DEEP
STEEL = (0.66, 0.66, 0.76)
BARK = K.BARK
ROCK = (0.56, 0.52, 0.58)
# the blight: colour drained toward a bruised violet-grey, never a clean grey
DEAD = (0.30, 0.27, 0.31)
DEAD_PALE = (0.50, 0.46, 0.48)
BONE = (0.80, 0.76, 0.66)
ROT = (0.12, 0.10, 0.13)


def clamp(v):
    return max(0.0, min(1.0, v))


def stripes(cols, freq, axis="x"):
    def shade(co):
        v = getattr(co, axis)
        return cols[int(math.floor(v * freq)) % len(cols)]
    return shade


def marker_flower(p, m, r=0.035):
    """The shared climb marker: a butter star flower with a glowing heart."""
    for i in range(5):
        p.add(K.petal(r, r * 0.6, cup=0.15, curl=-0.05), BUTTER, "fabric", m @ R("Z", 72 * i))
    p.add(sphere(r * 0.3, 6, 4), (0.85, 0.80, 0.45), "glow", m @ S(1, 1, 0.6))


# ------------------------------------------------------------------ the seamstress


def seam_dress_form(p):
    """A dress form on a gilt stand with a half-made gown pinned to it."""
    rng = random.Random(7361)
    for k in range(3):
        p.add(K.cabriole(0.22, 0.02, 1.4), GOLD, "gold", R("Z", 120 * k + 30) @ T(0.02, 0.02, 0) @ S(1, 1, -1) @ T(0, 0, -0.22))
    p.add(lathe([(0.03, 0.2), (0.018, 0.26), (0.016, 0.8), (0.03, 0.84), (0.02, 0.88)], 10), GOLD, "gold")
    torso = [(0.0, 0.84), (0.13, 0.86), (0.19, 0.93), (0.185, 1.02), (0.13, 1.14), (0.125, 1.2), (0.165, 1.32), (0.17, 1.4),
             (0.14, 1.47), (0.06, 1.5), (0.05, 1.54), (0.0, 1.54)]
    p.add(lathe(torso, 14), CREAM, "fabric", S(1, 0.72, 1), shade=lambda co: K.mix(K.darker(CREAM, 0.1), CREAM, clamp(0.5 + co.y * 4)))
    p.add(lathe([(0.03, 1.54), (0.035, 1.56), (0.015, 1.58), (0.02, 1.61), (0.0, 1.63)], 8), GOLD, "gold")
    skirt = lathe([(0.135, 1.17), (0.2, 1.05), (0.3, 0.8), (0.4, 0.5), (0.47, 0.28), (0.5, 0.2)], 18, False, False)
    for v in skirt.verts:
        a = math.atan2(v.co.y, v.co.x)
        f = (1.17 - v.co.z)
        v.co.x *= 1.0 + 0.09 * f * math.sin(a * 9)
        v.co.y *= 1.0 + 0.09 * f * math.sin(a * 9)
        if v.co.z < 0.25:
            v.co.z += 0.1 * (0.5 + 0.5 * math.sin(a * 2.0 + 1.0))       # unhemmed, uneven
    p.add(skirt, BLUSH, "pearl", S(1, 0.85, 1), shade=lambda co: K.mix(ROSE, BLUSH, clamp((co.z - 0.2) / 0.9)))
    p.add(lathe([(0.132, 1.14), (0.14, 1.2), (0.172, 1.31), (0.176, 1.39)], 14, False, False), LILAC, "pearl", S(1.02, 0.74, 1))
    p.add(torus(0.135, 0.012, 14, 5), GOLD, "gold", T(0, 0, 1.17) @ S(1, 0.75, 1))
    K.soft_rose(p, T(0.1, 0.085, 1.18) @ FRONT, 0.04, ROSE, "pearl", rng)
    tape = [(-0.06, 1.5), (-0.1, 1.46), (-0.14, 1.3), (-0.13, 1.05), (-0.15, 0.95)]
    p.add(U.ribbon(tape, 0.02, 0.003), BUTTER, "fabric", R("Z", 90) @ T(0, 0.05, 0))
    p.add(U.ribbon([(0.06, 1.5), (0.11, 1.44), (0.14, 1.25)], 0.02, 0.003), BUTTER, "fabric", R("Z", 90) @ T(0, 0.05, 0))
    for k in range(10):
        a = rng.uniform(0.3, 2.8)
        z = rng.uniform(0.5, 1.1)
        rr = 0.14 + (1.17 - z) * 0.42
        p.add(sphere(0.008, 5, 3), GOLD, "gold", T(math.cos(a) * rr, math.sin(a) * rr * 0.86, z))


def seam_loom(p):
    """A floor loom with a candy-striped cloth half woven on it."""
    w, d, h = 1.2, 1.3, 1.25
    wood = U.grain(OAK, 0.12, 40.0)
    for sx in (-1, 1):
        x = sx * w / 2
        p.add(box(0.07, 0.09, h, bevel=0.012), OAK, "satin", T(x, -d / 2 + 0.2, h / 2), shade=wood)
        p.add(box(0.07, 0.09, 0.8, bevel=0.012), OAK, "satin", T(x, d / 2 - 0.1, 0.4), shade=wood)
        p.add(box(0.07, d, 0.08, bevel=0.012), OAK, "satin", T(x, 0, 0.06), shade=wood)
        p.add(box(0.07, d - 0.2, 0.07, bevel=0.012), OAK, "satin", T(x, 0.05, 0.76), shade=wood)
        p.add(lathe([(0.05, 0.0), (0.06, 0.012), (0.0, 0.02)], 8), GOLD, "gold", T(x + sx * 0.035, d / 2 - 0.1, 0.72) @ R("Y", sx * 90))
    p.add(box(w, 0.07, 0.07, bevel=0.012), OAK, "satin", T(0, -d / 2 + 0.2, h - 0.04), shade=wood)
    cols = [ROSE, PEARL, LILAC, PEARL, MINT, PEARL, BUTTER, PEARL, PERI, PEARL]
    p.add(lathe([(0.07, -w / 2 + 0.06), (0.07, w / 2 - 0.06)], 10), CREAM, "fabric", T(0, -d / 2 + 0.2, 0.86) @ R("Y", 90))
    p.add(lathe([(0.075, -w / 2 + 0.07), (0.075, w / 2 - 0.07)], 10), ROSE, "fabric", T(0, d / 2 - 0.1, 0.72) @ R("Y", 90), shade=stripes(cols, 26, "z"))
    # warp (back) and woven cloth (front), one sheet with a fell line at y = 0.1
    sheet_w = w - 0.16
    p.add(box(sheet_w, 0.62, 0.004), CREAM, "fabric", T(0, -0.2, 0.84) @ R("X", -5),
          shade=lambda co: K.mix(K.darker(CREAM, 0.22), CREAM, 0.5 + 0.5 * math.sin(co.x * 220)))
    p.add(box(sheet_w, 0.44, 0.006), ROSE, "fabric", T(0, 0.32, 0.79) @ R("X", 8), shade=stripes(cols, 26, "x"))
    for k, y in enumerate((-0.12, 0.0)):
        p.add(box(w - 0.06, 0.025, 0.42, bevel=0.006), K.lighter(OAK, 0.15), "satin", T(0, y, 0.98 - k * 0.06))
        p.add(box(sheet_w, 0.006, 0.3), CREAM, "fabric", T(0, y, 0.95 - k * 0.06))
    p.add(box(w - 0.06, 0.05, 0.1, bevel=0.01), OAK_DARK, "satin", T(0, 0.1, 0.84))
    for k in range(4):
        p.add(box(0.06, 0.55, 0.025, bevel=0.006), OAK_DARK, "satin", T(-0.24 + k * 0.16, 0.1, 0.14) @ R("X", 8))
    shuttle = lathe([(0.0, -0.12), (0.022, -0.06), (0.026, 0.0), (0.022, 0.06), (0.0, 0.12)], 6)
    p.add(shuttle, OAK_DARK, "satin", T(0.2, 0.3, 0.83) @ R("Y", 90) @ R("X", 20) @ S(1, 0.6, 1))
    p.add(lathe([(0.012, -0.05), (0.014, 0.0), (0.012, 0.05)], 6), LILAC, "fabric", T(0.2, 0.3, 0.84) @ R("Y", 90) @ R("X", 20))


def seam_fabric_bolts(p):
    """A shelf of fabric bolts in every candy colour, a few ends hanging loose."""
    rng = random.Random(7363)
    w, h, d = 1.5, 1.9, 0.42
    paint = K.lighter(MINT, 0.1)
    for sx in (-1, 1):
        p.add(box(0.05, d, h, bevel=0.01), paint, "satin", T(sx * w / 2, 0, h / 2))
    for k in range(5):
        p.add(box(w, d, 0.04, bevel=0.008), paint, "satin", T(0, 0, 0.04 + k * 0.44))
    p.add(box(w, 0.02, h), K.darker(paint, 0.15), "satin", T(0, -d / 2, h / 2))
    crest = [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, 0.05)] + [(w / 2 * math.cos(math.pi * i / 10), 0.05 + 0.16 * math.sin(math.pi * i / 10)) for i in range(1, 10)] \
        + [(-w / 2, 0.05)]
    p.add(U.slab(crest, 0.05), paint, "satin", T(0, d / 2 - 0.03, h - 0.02))
    K.soft_rose(p, T(0, d / 2, h + 0.1) @ FRONT, 0.06, ROSE, "pearl", rng)
    for sx in (-1, 1):
        p.add(K.scroll(0.06, 1.3, 9, 0.008), GOLD, "gold", T(sx * 0.2, d / 2, h + 0.06) @ S(sx, 1, 1))
    k = 0
    for row in range(4):
        z0 = 0.06 + row * 0.44
        for i in range(7):
            col = PASTELS[(row * 3 + i * 2) % 7] if (row + i) % 5 else [(0.72, 0.36, 0.55), (0.45, 0.40, 0.78), (0.36, 0.66, 0.62)][i % 3]
            r = rng.uniform(0.075, 0.095)
            x = -w / 2 + 0.13 + i * 0.207
            ln = rng.uniform(0.34, 0.4)
            m = T(x, d / 2 - ln - 0.01 + rng.uniform(-0.02, 0.0), z0 + r) @ FRONT
            pattern = (row * 7 + i) % 4
            sh = None
            if pattern == 1:
                sh = stripes([col, K.lighter(col, 0.3)], 40, "z")
            elif pattern == 2:
                sh = (lambda c: lambda co: K.lighter(c, 0.35) if (math.sin(co.z * 70) * math.sin(math.atan2(co.y, co.x) * 4)) > 0.55 else c)(col)
            p.add(lathe([(0.02, 0.0), (r, 0.0), (r, ln), (0.02, ln)], 9, False, False), col, "fabric" if pattern else "pearl", m, shade=sh)
            p.add(lathe([(0.0, 0.0), (0.022, 0.0), (0.022, ln + 0.02), (0.0, ln + 0.02)], 5), CREAM, "matte", m @ T(0, 0, -0.01))
            if k % 6 == 2:
                path = [(r, 0.0), (r + 0.01, -0.06), (r - 0.02, -0.2), (r + 0.01, -0.3)]
                p.add(U.ribbon([(a, b) for a, b in path], ln * 0.9, 0.004), col, "fabric", T(x - r + 0.0, d / 2 - ln / 2, z0 + r) @ S(0, 1, 1) @ T(0, 0, 0)
                      if False else T(x, d / 2 + 0.005, z0 + r) @ R("Z", 90) @ T(-r, 0, 0) @ S(1, 0.9 * 0.207 / (ln * 0.9), 1), shade=sh)
            k += 1


def seam_ribbon_rack(p):
    """A wall rack of ribbon spools and thread, tails hanging, scissors on a hook."""
    rng = random.Random(7364)
    w, h = 1.2, 0.8
    p.add(box(w, 0.03, h, bevel=0.01), K.lighter(LILAC, 0.2), "satin", T(0, 0, h / 2 + 0.6))
    p.add(K.frame_ring([(-w / 2, 0.6), (w / 2, 0.6), (w / 2, 0.6 + h), (-w / 2, 0.6 + h)], 0.018, 0.02), GOLD, "gold")
    k = 0
    for row in range(3):
        for i in range(5):
            x, z = -0.46 + i * 0.23, 0.76 + row * 0.25
            col = PASTELS[(row * 2 + i) % 7]
            m = T(x, 0.015, z) @ FRONT
            p.add(lathe([(0.012, 0.0), (0.012, 0.1), (0.018, 0.105), (0.0, 0.11)], 5), OAK, "satin", m)
            p.add(lathe([(0.012, 0.0), (0.07, 0.0), (0.07, 0.008), (0.03, 0.008)], 6, True, False), CREAM, "satin", m @ T(0, 0, 0.012))
            p.add(lathe([(0.03, 0.02), (0.058, 0.02), (0.058, 0.07), (0.03, 0.07)], 6), col, "pearl", m)
            p.add(lathe([(0.03, 0.074), (0.07, 0.074), (0.07, 0.082), (0.012, 0.082)], 6, False, True), CREAM, "satin", m)
            if k % 3 == 0:
                ln = rng.uniform(0.3, 0.75)
                path = [(0.058, 0.0)] + [(0.058 + 0.02 * math.sin(u * 6 + k), -ln * u) for u in (0.2, 0.4, 0.6, 0.8, 1.0)]
                p.add(U.ribbon(path, 0.045, 0.002), col, "pearl", T(x, 0.06, z))
            k += 1
    sm = T(0.5, 0.03, 0.72)
    p.add(tube([(0, 0, 0), (0, 0.03, 0.0)], 0.006, 5), GOLD, "gold", sm)
    for sx in (-1, 1):
        p.add(torus(0.028, 0.005, 8, 4), GOLD, "gold", sm @ T(sx * 0.03, 0.03, -0.03) @ R("X", 90))
        p.add(U.slab([(sx * 0.02, -0.055), (sx * 0.006, -0.06), (-sx * 0.012, -0.24), (-sx * 0.004, -0.245)], 0.003), STEEL, "mirror", sm @ T(0, 0.03, 0))


def seam_worktable(p):
    """The cutting table: a length of cloth half cut, shears, pincushion, tape, a pattern."""
    rng = random.Random(7365)
    w, d, h = 1.7, 0.85, 0.86
    p.add(box(w, d, 0.05, bevel=0.012), K.lighter(OAK, 0.1), "satin", T(0, 0, h - 0.025), shade=U.grain(K.lighter(OAK, 0.1), 0.1, 30.0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(K.turned_leg(h - 0.05, 0.04, 8), PEARL, "satin", T(sx * (w / 2 - 0.09), sy * (d / 2 - 0.09), 0))
    p.add(box(w - 0.16, d - 0.16, 0.09, bevel=0.01), PEARL, "satin", T(0, 0, h - 0.095))
    cloth = [(-0.55, h + 0.004), (0.2, h + 0.008), (0.44, h + 0.004), (0.455, h - 0.1), (0.44, h - 0.36), (0.47, h - 0.52)]
    p.add(U.ribbon(cloth, 0.9, 0.005), BLUSH, "pearl", R("Z", 90) @ T(0, 0.1, 0),
          shade=lambda co: K.lighter(BLUSH, 0.3) if (math.sin(co.x * 38) * math.sin(co.y * 38)) > 0.6 else BLUSH)
    p.add(box(0.5, 0.36, 0.003), CREAM, "matte", T(-0.5, 0.12, h + 0.002) @ R("Z", 12))
    for k in range(6):
        p.add(box(0.03, 0.006, 0.0036), PERI, "matte", T(-0.5, 0.12, h + 0.002) @ R("Z", 12) @ T(-0.2 + k * 0.07, 0.1 * math.sin(k * 1.1), 0.001))
    sm = T(0.1, -0.2, h + 0.012) @ R("Z", 35)
    for sx in (-1, 1):
        p.add(torus(0.03, 0.006, 10, 4), GOLD, "gold", sm @ T(sx * 0.034, -0.05, 0))
        p.add(U.slab([(sx * 0.016, 0.0), (sx * 0.004, -0.005), (-sx * 0.012, 0.22), (-sx * 0.002, 0.23)], 0.004), STEEL, "mirror", sm @ FLAT)
    p.add(sphere(0.008, 6, 4), GOLD, "gold", sm @ T(0, 0.012, 0.002))
    p.add(K.cushion(0.1, 0.1, 0.06, puff=0.8), ROSE, "fabric", T(0.55, -0.25, h + 0.03))
    for k in range(7):
        a = rng.uniform(0, 6.283)
        m = T(0.55 + math.cos(a) * 0.02, -0.25 + math.sin(a) * 0.02, h + 0.05) @ R("X", rng.uniform(-25, 25)) @ R("Y", rng.uniform(-25, 25))
        p.add(tube([(0, 0, 0), (0, 0, 0.045)], 0.0012, 3), STEEL, "mirror", m)
        p.add(sphere(0.005, 5, 3), PASTELS[k % 7], "pearl", m @ T(0, 0, 0.047))
    coil = [(math.cos(i * 0.5) * (0.02 + i * 0.0018), math.sin(i * 0.5) * (0.02 + i * 0.0018), 0.0) for i in range(30)]
    p.add(tube(coil, 0.006, 4), BUTTER, "fabric", T(-0.1, 0.28, h + 0.012) @ S(1, 1, 2.2))
    for k, col in enumerate((LILAC, MINT, BUTTER)):
        p.add(lathe([(0.03, 0.0), (0.03, 0.008), (0.012, 0.008), (0.012, 0.012), (0.026, 0.012), (0.026, 0.05), (0.012, 0.05), (0.012, 0.054),
                     (0.03, 0.054), (0.03, 0.062), (0.0, 0.062)], 8), col, "pearl", T(0.62 + k * 0.035, 0.24 - k * 0.07, h))


def seam_crown_stand(p):
    """The dress-up counter piece: a tiered stand with a tiara, a flower
    crown and a gilt half-mask."""
    rng = random.Random(7366)
    p.add(lathe([(0.0, 0.0), (0.2, 0.0), (0.21, 0.02), (0.1, 0.05), (0.03, 0.08), (0.025, 0.34), (0.05, 0.36), (0.0, 0.37)], 14), GOLD, "gold")
    heads = ((0.0, 0.0, 0.37, 0.085), (-0.28, 0.06, 0.0, 0.09), (0.28, 0.06, 0.0, 0.085))
    for k, (x, y, z, r) in enumerate(heads):
        if k:
            p.add(lathe([(0.0, 0.0), (0.1, 0.0), (0.105, 0.012), (0.03, 0.03), (0.022, 0.16), (0.0, 0.17)], 12), PEARL, "pearl", T(x, y, 0))
            z = 0.16
        p.add(lathe([(0.03, 0.0), (r * 0.8, 0.02), (r, 0.08), (r * 0.9, 0.15), (r * 0.5, 0.2), (0.0, 0.21)], 12), K.lighter(LILAC, 0.25), "fabric", T(x, y, z))
    # tiara on the centre head
    m = T(0, 0, 0.37 + 0.13)
    p.add(torus(0.082, 0.005, 14, 4), GOLD, "gold", m)
    for k in range(7):
        a = math.radians(30 + k * 20)
        hgt = (0.03, 0.045, 0.06, 0.085, 0.06, 0.045, 0.03)[k]
        q = T(math.cos(a) * 0.082, math.sin(a) * 0.082, 0)
        p.add(lathe([(0.006, 0.0), (0.004, hgt * 0.7), (0.0, hgt)], 5), GOLD, "gold", m @ q)
        p.add(sphere(0.008 if k != 3 else 0.012, 6, 4), PEARL if k % 2 else ROSE, "pearl", m @ q @ T(0, 0, hgt))
    # flower crown on the left head
    m = T(-0.28, 0.06, 0.16 + 0.13) @ R("X", -8)
    p.add(torus(0.088, 0.006, 14, 4), GREEN, "leaf", m)
    for k in range(9):
        a = 2 * math.pi * k / 9
        q = m @ T(math.cos(a) * 0.092, math.sin(a) * 0.092, 0.006) @ R("Z", math.degrees(a)) @ R("Y", 70)
        K.soft_rose(p, q, 0.026 if k % 2 else 0.032, PASTELS[k % 5], "fabric", rng)
        p.add(K.leaf(0.04, 0.018), GREEN_DEEP, "leaf", m @ T(math.cos(a + 0.35) * 0.09, math.sin(a + 0.35) * 0.09, 0) @ R("Z", math.degrees(a) + 60))
    # half-mask on the right head
    m = T(0.28, 0.06 + 0.078, 0.16 + 0.12)
    mask = U.slab([(-0.085, 0.0), (-0.07, -0.035), (-0.02, -0.03), (0.0, -0.012), (0.02, -0.03), (0.07, -0.035), (0.085, 0.0), (0.1, 0.05),
                   (0.03, 0.035), (0.0, 0.045), (-0.03, 0.035), (-0.1, 0.05)], 0.006)
    for v in mask.verts:
        v.co.y -= (v.co.x ** 2) * 5.0
    p.add(mask, GOLD, "gold", m)
    for sx in (-1, 1):
        p.add(sphere(0.016, 8, 4), (0.12, 0.10, 0.14), "matte", m @ T(sx * 0.04, 0.0, 0.004) @ S(1.3, 0.4, 0.8))
        p.add(K.leaf(0.07, 0.025), GOLD, "gold", m @ T(sx * 0.085, -0.035, 0.03) @ FRONT @ R("Z", 90 - sx * 50))
    p.add(sphere(0.008, 6, 4), ROSE, "pearl", m @ T(0, 0.006, 0.04))


# ------------------------------------------------------------------ the potion-maker


def _bottle(p, m, kind, liquid, rng):
    glass = (*K.mix(liquid, (0.85, 0.85, 0.85), 0.6), 0.4)
    profs = {
        0: [(0.0, 0.0), (0.045, 0.0), (0.05, 0.02), (0.05, 0.09), (0.02, 0.12), (0.018, 0.17), (0.024, 0.175)],          # square shoulders
        1: [(0.0, 0.0), (0.03, 0.0), (0.06, 0.03), (0.062, 0.06), (0.03, 0.1), (0.016, 0.13), (0.016, 0.19), (0.022, 0.195)],   # round flask
        2: [(0.0, 0.0), (0.028, 0.0), (0.03, 0.02), (0.03, 0.16), (0.016, 0.19), (0.016, 0.22), (0.021, 0.225)],          # tall phial
        3: [(0.0, 0.0), (0.05, 0.0), (0.07, 0.04), (0.04, 0.085), (0.02, 0.1), (0.02, 0.13), (0.026, 0.135)],            # squat jar
    }
    prof = profs[kind]
    p.add(lathe(prof, 7, True, False), glass, "glass", m)
    fill = rng.uniform(0.45, 0.8)
    top = prof[-1][1] * fill
    inner = [(0.0, 0.006)] + [(r * 0.8, z) for r, z in prof[1:] if z < top] + [(0.012, top), (0.0, top)]
    p.add(lathe(inner, 6), liquid, "glow", m)
    zt = prof[-1][1]
    p.add(lathe([(prof[-1][0] * 0.8, zt - 0.01), (prof[-1][0] * 0.9, zt + 0.02), (0.0, zt + 0.024)], 6), (0.70, 0.52, 0.36), "matte", m)


POTIONS = [(0.80, 0.36, 0.60), (0.55, 0.42, 0.85), (0.36, 0.72, 0.80), (0.85, 0.72, 0.30), (0.42, 0.80, 0.55), (0.85, 0.45, 0.35)]


def potion_shelf(p):
    """The potion-maker's shelf: an arched lilac cabinet of glowing bottles."""
    rng = random.Random(7371)
    w, h, d = 1.2, 1.95, 0.34
    paint = K.lighter(LILAC, 0.15)
    for sx in (-1, 1):
        p.add(box(0.05, d, h - 0.3, bevel=0.01), paint, "satin", T(sx * w / 2, 0, (h - 0.3) / 2))
    p.add(box(w, 0.02, h - 0.3), K.lighter(BUTTER, 0.1), "satin", T(0, -d / 2, (h - 0.3) / 2))
    for k in range(5):
        p.add(box(w + 0.04, d + 0.02, 0.04, bevel=0.008), paint, "satin", T(0, 0, 0.04 + k * 0.4))
    arch = [(-w / 2 - 0.02, 0.0)] + [((w / 2 + 0.02) * -math.cos(math.pi * i / 12), 0.3 * math.sin(math.pi * i / 12)) for i in range(13)]
    p.add(U.slab(arch, d), paint, "satin", T(0, 0, h - 0.31))
    p.add(tube([((w / 2 + 0.02) * -math.cos(math.pi * i / 12), d / 2, h - 0.31 + 0.3 * math.sin(math.pi * i / 12)) for i in range(13)], 0.014, 5), GOLD, "gold")
    p.add(sphere(0.07, 10, 6), (0.80, 0.78, 0.50), "glow", T(0, d / 2, h - 0.16) @ S(1, 0.4, 1))
    for k in range(6):
        p.add(K.leaf(0.09, 0.03), GOLD, "gold", T(0, d / 2 + 0.01, h - 0.16) @ FRONT @ R("Z", 60 * k) @ T(0.07, 0, 0))
    k = 0
    for row in range(4):
        z = 0.06 + row * 0.4
        n = 4 if row < 3 else 3
        for i in range(n):
            x = -w / 2 + 0.14 + i * (w - 0.28) / (n - 1) + rng.uniform(-0.015, 0.015)
            _bottle(p, T(x, rng.uniform(-0.03, 0.05), z) @ R("Z", rng.uniform(0, 50)), (k + row) % 4, POTIONS[(k * 5 + row) % 6], rng)
            k += 1
    p.add(box(0.09, 0.004, 0.06), CREAM, "matte", T(-0.3, d / 2 + 0.012, 0.42) @ R("Y", 5))
    p.add(box(0.09, 0.004, 0.06), CREAM, "matte", T(0.25, d / 2 + 0.012, 1.22) @ R("Y", -4))


def potion_alembic(p):
    """An alembic at work: a glowing flask over a burner, its beaked head
    running through a copper coil into a receiver."""
    rng = random.Random(7372)
    p.add(box(0.9, 0.42, 0.04, bevel=0.012), K.mix(WARM_STONE, PEARL, 0.4), "satin", T(0, 0, 0.02))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        p.add(tube([(-0.22 + math.cos(a) * 0.12, math.sin(a) * 0.12, 0.04), (-0.22 + math.cos(a) * 0.07, math.sin(a) * 0.07, 0.24)], 0.008, 5), IRON, "mirror")
    p.add(torus(0.075, 0.008, 12, 5), IRON, "mirror", T(-0.22, 0, 0.24))
    p.add(lathe([(0.0, 0.04), (0.05, 0.04), (0.055, 0.07), (0.03, 0.09), (0.0, 0.09)], 10), COPPER, "gold", T(-0.22, 0, 0))
    for k in range(4):
        p.add(K.round_petal(0.07, 0.03, cup=0.5, curl=0.2), (0.85, 0.60, 0.25), "glow", T(-0.22, 0, 0.09) @ R("Z", 90 * k) @ T(0.008, 0, 0) @ R("Y", -80))
    liquid = (0.80, 0.36, 0.60)
    p.add(lathe([(0.0, 0.25), (0.06, 0.26), (0.105, 0.33), (0.1, 0.4), (0.05, 0.46), (0.04, 0.5)], 12, True, False), (0.85, 0.80, 0.85, 0.4), "glass", T(-0.22, 0, 0))
    p.add(lathe([(0.0, 0.26), (0.055, 0.27), (0.092, 0.33), (0.09, 0.37), (0.0, 0.372)], 10), liquid, "glow", T(-0.22, 0, 0))
    p.add(lathe([(0.042, 0.49), (0.07, 0.52), (0.075, 0.58), (0.05, 0.63), (0.0, 0.645)], 12), (0.85, 0.80, 0.85, 0.45), "glass", T(-0.22, 0, 0))
    beak = [(-0.16, 0, 0.6), (-0.05, 0, 0.6), (0.04, 0, 0.55), (0.1, 0, 0.5)]
    p.add(tube(beak, [0.022, 0.018, 0.014, 0.011], 7), (0.85, 0.80, 0.85, 0.45), "glass")
    coil = [(0.16 + math.cos(i * 0.52) * 0.06, math.sin(i * 0.52) * 0.06, 0.5 - i * 0.0055) for i in range(52)]
    p.add(tube([(0.1, 0, 0.5)] + coil + [(0.22, 0, 0.2), (0.3, 0, 0.19)], 0.009, 5), COPPER, "gold")
    p.add(lathe([(0.0, 0.04), (0.05, 0.04), (0.065, 0.08), (0.06, 0.13), (0.025, 0.17), (0.022, 0.21), (0.03, 0.215)], 10, True, False),
          (0.85, 0.80, 0.85, 0.4), "glass", T(0.32, 0, 0))
    p.add(lathe([(0.0, 0.046), (0.045, 0.048), (0.058, 0.08), (0.055, 0.1), (0.0, 0.102)], 8), K.lighter(liquid, 0.2), "glow", T(0.32, 0, 0))
    for k in range(3):
        p.add(sphere(0.007, 5, 3), K.lighter(liquid, 0.3), "glow", T(-0.22 + rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), 0.39 + k * 0.03))
    p.add(tube([(0.16, 0.0, 0.04), (0.16, 0.0, 0.52)], 0.007, 5), IRON, "mirror")
    p.add(torus(0.064, 0.005, 10, 4), IRON, "mirror", T(0.16, 0, 0.36))


def potion_mortar(p):
    """A pearl mortar and pestle with the day's petals and herbs."""
    rng = random.Random(7373)
    p.add(lathe([(0.0, 0.0), (0.07, 0.0), (0.08, 0.012), (0.06, 0.03), (0.09, 0.07), (0.115, 0.13), (0.118, 0.145), (0.105, 0.145), (0.085, 0.09),
                 (0.04, 0.05), (0.0, 0.045)], 14), PEARL, "pearl")
    p.add(lathe([(0.0, 0.0), (0.022, 0.006), (0.026, 0.03), (0.014, 0.07), (0.011, 0.17), (0.016, 0.19), (0.0, 0.2)], 8), K.lighter(LILAC, 0.2), "pearl",
          T(0.02, 0.01, 0.06) @ R("Y", 32) @ R("X", -12))
    for k in range(9):
        a, rr = rng.uniform(0, 6.283), rng.uniform(0.0, 0.06)
        p.add(K.round_petal(0.035, 0.03, cup=0.3), [ROSE, BLUSH, LILAC][k % 3], "fabric",
              T(math.cos(a) * rr, math.sin(a) * rr, 0.062 + rng.uniform(0, 0.02)) @ R("Z", rng.uniform(0, 360)) @ R("Y", rng.uniform(-20, 20)))
    for k in range(3):
        x0 = 0.16 + k * 0.03
        p.add(tube([(x0, -0.08, 0.006), (x0 + 0.02, 0.02, 0.01), (x0 + 0.01, 0.1, 0.008)], 0.003, 3), GREEN_DEEP, "leaf")
        for j in range(5):
            p.add(K.leaf(0.035, 0.014), GREEN, "leaf", T(x0 + 0.012, -0.05 + j * 0.035, 0.01) @ R("Z", 40 if j % 2 else 140))
        p.add(lathe([(0.0, 0.0), (0.008, 0.01), (0.006, 0.04), (0.0, 0.05)], 5), LILAC, "fabric", T(x0 + 0.01, 0.1, 0.008) @ FRONT)
    p.add(K.petal(0.03, 0.025), ROSE, "fabric", T(-0.15, 0.06, 0.002) @ R("Z", 40))
    p.add(K.petal(0.03, 0.025), BLUSH, "fabric", T(-0.13, -0.05, 0.002) @ R("Z", 200))


def potion_herb_rack(p):
    """A hanging rail of drying bundles: lavender, sage, roses, yarrow."""
    rng = random.Random(7374)
    w = 1.5
    p.add(tube([(-w / 2, 0, 1.0), (w / 2, 0, 1.0)], 0.016, 6), OAK, "satin")
    for sx in (-1, 1):
        p.add(lathe([(0.016, 0.0), (0.03, 0.02), (0.0, 0.05)], 6), GOLD, "gold", T(sx * w / 2, 0, 1.0) @ R("Y", sx * 90))
        p.add(tube([(sx * (w / 2 - 0.1), 0, 1.0), (sx * (w / 2 - 0.1), 0, 1.22)], 0.004, 3), STRAW, "fabric")
    kinds = [(LILAC, 0), (GREEN, 1), (ROSE, 2), (BUTTER, 3), (PERI, 0), (GREEN_DEEP, 1), (BLUSH, 2)]
    for k, (col, kind) in enumerate(kinds):
        x = -w / 2 + 0.16 + k * (w - 0.32) / 6
        ln = rng.uniform(0.42, 0.6)
        p.add(tube([(x, 0, 1.0), (x, 0, 0.93)], 0.004, 3), STRAW, "fabric")
        p.add(lathe([(0.012, 0.0), (0.032, -0.06), (0.062, -ln * 0.78)], 7, True, True), K.mix(GREEN_DEEP, STRAW, 0.4), "leaf", T(x, 0, 0.94))
        p.add(torus(0.018, 0.005, 8, 4), STRAW, "fabric", T(x, 0, 0.91))
        for j in range(9):
            a = 2 * math.pi * j / 9
            rr = rng.uniform(0.02, 0.055)
            q = T(x + math.cos(a) * rr, math.sin(a) * rr, 0.94 - ln * rng.uniform(0.74, 0.9))
            if kind == 0:
                p.add(lathe([(0.0, 0.0), (0.017, -0.03), (0.014, -0.11), (0.0, -0.14)], 5), col, "fabric", q)
            elif kind == 1:
                p.add(K.leaf(0.13, 0.05), col, "leaf", q @ R("Z", math.degrees(a)) @ R("Y", 70))
            elif kind == 2:
                K.rose_bud(p, q @ R("X", 180), 0.036, col, "fabric", rng)
            else:
                p.add(sphere(0.032, 6, 4), col, "fabric", q @ S(1, 1, 0.55))


def potion_counter(p):
    """The potion shop counter: mint panels, a pearl top, sweet-jars of
    ingredients, a brass bell and the ledger."""
    rng = random.Random(7375)
    w, d, h = 1.9, 0.7, 1.0
    p.add(box(w, d, h - 0.06, bevel=0.015), K.lighter(MINT, 0.1), "satin", T(0, 0, (h - 0.06) / 2))
    p.add(box(w + 0.1, d + 0.1, 0.06, bevel=0.02), PEARL, "pearl", T(0, 0, h - 0.03))
    p.add(box(w + 0.04, d + 0.04, 0.08, bevel=0.015), K.lighter(LILAC, 0.1), "satin", T(0, 0, 0.04))
    for i in range(4):
        x = -w / 2 + 0.26 + i * (w - 0.52) / 3
        out = K.arched_outline(0.34, 0.62, 8)
        p.add(U.slab(out, 0.02), K.lighter(MINT, 0.3), "satin", T(x, d / 2 + 0.002, 0.16))
        p.add(tube([(x + a, d / 2 + 0.014, 0.16 + b) for a, b in out], 0.008, 4, closed=True), GOLD, "gold")
        K.soft_rose(p, T(x, d / 2 + 0.014, 0.5) @ FRONT, 0.045, [ROSE, BLUSH, LILAC, BUTTER][i], "pearl", rng)
    for k, (x, col) in enumerate(((-0.7, ROSE), (-0.48, BUTTER), (-0.26, PERI))):
        m = T(x, 0.05, h)
        p.add(lathe([(0.0, 0.0), (0.07, 0.0), (0.08, 0.02), (0.08, 0.17), (0.055, 0.2), (0.055, 0.22)], 10, True, False), (0.85, 0.85, 0.85, 0.35), "glass", m)
        p.add(lathe([(0.0, 0.006), (0.066, 0.01), (0.07, 0.12 - k * 0.02), (0.0, 0.135 - k * 0.02)], 8), col, "pearl", m,
              shade=(lambda c: lambda co: K.lighter(c, 0.3) if math.sin(co.x * 150) * math.sin(co.y * 150) * math.sin(co.z * 150) > 0.2 else c)(col))
        p.add(lathe([(0.06, 0.22), (0.062, 0.24), (0.02, 0.255), (0.018, 0.275), (0.0, 0.28)], 10), GOLD, "gold", m)
    p.add(lathe([(0.0, 0.0), (0.07, 0.0), (0.072, 0.012), (0.055, 0.02), (0.05, 0.05), (0.03, 0.075), (0.008, 0.085), (0.01, 0.1), (0.0, 0.105)], 12), GOLD, "gold",
          T(0.3, 0.1, h))
    bm = T(0.68, 0.0, h) @ R("Z", -12)
    p.add(box(0.34, 0.26, 0.05, bevel=0.008), (0.62, 0.30, 0.45), "fabric", bm @ T(0, 0, 0.025))
    p.add(box(0.32, 0.24, 0.04), CREAM, "matte", bm @ T(0.005, 0, 0.028))
    p.add(U.ribbon([(0.0, 0.05), (0.02, 0.052), (0.2, 0.05), (0.21, 0.0)], 0.02, 0.002), GOLD, "gold", bm @ T(-0.02, 0, 0.002))
    quill = [(0.5, -0.2, h + 0.01), (0.56, -0.1, h + 0.1), (0.6, -0.02, h + 0.24)]
    p.add(tube(quill, [0.003, 0.003, 0.001], 3), CREAM, "matte")
    p.add(K.leaf(0.2, 0.05), BLUSH, "fabric", T(0.555, -0.105, h + 0.1) @ R("Z", 62) @ R("Y", -60))
    p.add(lathe([(0.0, 0.0), (0.03, 0.0), (0.034, 0.03), (0.02, 0.04), (0.0, 0.04)], 8), (0.2, 0.16, 0.3), "pearl", T(0.48, -0.22, h))


# ------------------------------------------------------------------ climbables


def climb_ivy_panel(p):
    """A 2 x 4 m sheet of climbable ivy for manor walls and cliff faces,
    starred with the butter marker flowers. Hangs in the wall's plane."""
    rng = random.Random(7381)
    for k in range(7):
        x = -0.85 + k * 0.28 + rng.uniform(-0.06, 0.06)
        pts = [(x, 0.02, 0.0)]
        for i in range(1, 11):
            x += rng.uniform(-0.16, 0.16)
            x = max(-0.95, min(0.95, x))
            pts.append((x, 0.02 + rng.uniform(0, 0.03), i * 0.4))
        p.add(tube(pts, [0.022 - 0.0014 * i for i in range(11)], 4), BARK, "matte")
        for i in range(10):
            a, b = Vector(pts[i]), Vector(pts[i + 1])
            for j in range(2):
                q = a.lerp(b, rng.random())
                sz = rng.uniform(0.14, 0.24)
                col = K.mix(GREEN, GREEN_DEEP, rng.random())
                m = T(q.x + rng.uniform(-0.14, 0.14), 0.05 + rng.uniform(0, 0.05), q.z) @ FRONT @ R("Z", rng.uniform(200, 340)) @ R("Y", rng.uniform(-25, 5))
                p.add(K.leaf(sz, sz * 0.8), col, "leaf", m)
                p.add(K.leaf(sz * 0.7, sz * 0.5), K.lighter(col, 0.12), "leaf", m @ R("Z", rng.choice((-60, 60))))
    for k in range(11):
        marker_flower(p, T(rng.uniform(-0.8, 0.8), 0.11, 0.4 + k * 0.33 + rng.uniform(-0.08, 0.08)) @ FRONT @ R("Z", rng.uniform(0, 72)), 0.05)


def climb_root_ladder(p):
    """Climbable roots hanging down a bank or cliff: thick risers with
    cross-roots for rungs, moss, and glowcaps marking the way up."""
    rng = random.Random(7382)
    root = K.mix(BARK, (0.62, 0.50, 0.42), 0.5)
    xs = (-0.5, -0.18, 0.16, 0.52)
    for k, x0 in enumerate(xs):
        pts = [(x0 + 0.1 * math.sin(i * 0.9 + k * 2), 0.04 + 0.03 * math.cos(i * 1.3 + k), 4.0 - i * 0.4) for i in range(11)]
        pts[-1] = (pts[-1][0] + rng.uniform(-0.1, 0.1), 0.02, 0.0)
        p.add(tube(pts, [0.06 - 0.0035 * i for i in range(11)], 6), root, "matte", shade=U.grain(root, 0.18, 14.0))
        tail = Vector(pts[6])
        p.add(tube([tail, tail + Vector((rng.uniform(-0.1, 0.1), 0.05, -0.3)), tail + Vector((rng.uniform(-0.15, 0.15), 0.06, -0.62))], [0.012, 0.008, 0.003], 3),
              K.darker(root, 0.15), "matte")
    for i in range(8):
        z = 0.45 + i * 0.45
        a, b = rng.sample(range(4), 2)
        x0, x1 = sorted((xs[a], xs[b]))
        if x1 - x0 < 0.4:
            x0, x1 = xs[0], xs[3] if i % 2 else xs[2]
        pts = [(x0, 0.07, z), ((x0 + x1) / 2, 0.11, z + rng.uniform(-0.08, 0.08)), (x1, 0.07, z + rng.uniform(-0.05, 0.05))]
        p.add(tube(pts, [0.03, 0.036, 0.028], 5), K.lighter(root, 0.08), "matte")
        if i % 2 == 0:
            p.add(sphere(0.06, 7, 4), K.mix(MINT, GREEN, 0.5), "leaf", T((x0 + x1) / 2, 0.12, z + 0.02) @ S(1.6, 0.6, 0.5))
    for k in range(7):
        x, z = rng.choice(xs) + rng.uniform(-0.05, 0.05), 0.5 + k * 0.5
        m = T(x, 0.1, z) @ R("X", -40)
        p.add(lathe([(0.006, 0.0), (0.005, 0.035)], 4, False, False), CREAM, "matte", m)
        p.add(lathe([(0.0, 0.05), (0.02, 0.042), (0.026, 0.03), (0.0, 0.032)], 7), (0.60, 0.85, 0.80), "glow", m)


def climb_ledge(p):
    """A mantle ledge: a jutting shelf of fell rock with a worn pale lip, a
    tuft of grass and the marker flowers."""
    rng = random.Random(7383)
    bm = U.rock(1.0, 2, 3.7, 0.16)
    for v in bm.verts:
        v.co.x *= 1.15
        v.co.y = v.co.y * 0.55 + 0.1
        v.co.z = min(v.co.z * 0.42, 0.14 + 0.02 * math.sin(v.co.x * 5))
    p.add(bm, ROCK, "matte", T(0, 0, 0.36), sharp_deg=38.0,
          shade=lambda co: K.mix(K.mix(K.darker(ROCK, 0.3), ROCK, clamp(0.6 + co.z * 2)), (0.82, 0.78, 0.74), clamp((co.z - 0.1) * 14) * clamp((co.y - 0.3) * 4)))
    for k in range(9):
        x = rng.uniform(-0.8, 0.8)
        for j in range(3):
            p.add(K.leaf(rng.uniform(0.16, 0.28), 0.03), K.mix(GREEN, GREEN_DEEP, rng.random()), "leaf",
                  T(x, rng.uniform(-0.25, 0.1), 0.5) @ R("Z", rng.uniform(0, 360)) @ R("Y", -rng.uniform(55, 80)))
    for x in (-0.6, 0.05, 0.62):
        marker_flower(p, T(x, 0.52, 0.47) @ R("X", -50) @ R("Z", rng.uniform(0, 72)), 0.045)
        p.add(tube([(x, 0.5, 0.44), (x, 0.52, 0.47)], 0.004, 3), GREEN_DEEP, "leaf")


def climb_handholds(p):
    """A run of handholds up a rock face: seven knobs and pockets, each with
    a chalk-pale worn top and a marker flower beside the awkward ones."""
    rng = random.Random(7384)
    spots = [(-0.35, 0.25), (0.3, 0.6), (-0.15, 1.05), (0.4, 1.45), (-0.4, 1.8), (0.1, 2.25), (-0.2, 2.7)]
    for k, (x, z) in enumerate(spots):
        bm = U.rock(0.13, 2, k * 2.9, 0.2)
        for v in bm.verts:
            v.co.y = max(v.co.y * 0.8, -0.01)
            v.co.z *= 0.6
            v.co.x *= rng.uniform(1.0, 1.02) * (1.5 if k % 3 == 0 else 1.0)
        p.add(bm, ROCK, "matte", T(x, 0, z), sharp_deg=38.0,
              shade=lambda co: K.mix(K.darker(ROCK, 0.25), (0.82, 0.80, 0.76), clamp(co.z * 16 + 0.2) * clamp(co.y * 12)))
        if k % 2 == 0:
            marker_flower(p, T(x + 0.17, 0.02, z + 0.02) @ FRONT @ R("Z", rng.uniform(0, 72)), 0.04)


def cliff_rope_anchor(p):
    """A rope-arrow target for the sea cliffs: an old oak mooring post with
    an iron ring and a frayed end of line, wedged in rock."""
    rng = random.Random(7385)
    for k in range(4):
        p.add(U.rock(rng.uniform(0.18, 0.3), 2, k * 1.9, 0.2), K.mix(ROCK, K.darker(ROCK, 0.25), rng.random()), "matte",
              T(math.cos(k * 1.6) * 0.26, math.sin(k * 1.6) * 0.26, 0.08) @ S(1, 1, 0.6), sharp_deg=38.0)
    # a squared mooring bitt with a cross-pin and a pyramid cap, not a round post
    lean = R("Y", 5)
    p.add(box(0.2, 0.2, 1.05, bevel=0.02), OAK, "matte", lean @ T(0, 0, 0.525), shade=U.grain(OAK, 0.25, 20.0))
    p.add(lathe([(0.15, 0.0), (0.15, 0.03), (0.0, 0.12)], 4), K.darker(OAK, 0.15), "matte", lean @ T(0, 0, 1.05) @ R("Z", 45))
    p.add(tube([(-0.3, 0, 0.0), (0.3, 0, 0.0)], 0.035, 6), K.darker(OAK, 0.1), "matte", lean @ T(0, 0, 0.66))
    for sx in (-1, 1):
        p.add(lathe([(0.035, 0.0), (0.045, 0.01), (0.045, 0.04), (0.0, 0.05)], 6), IRON, "mirror", lean @ T(sx * 0.3, 0, 0.66) @ R("Y", sx * 90))
    p.add(box(0.22, 0.22, 0.06, bevel=0.008), IRON, "mirror", lean @ T(0, 0, 0.89))
    p.add(lathe([(0.012, 0.0), (0.02, 0.05)], 6), IRON, "mirror", T(0.07, 0.1, 0.9) @ FRONT)
    p.add(torus(0.07, 0.012, 12, 5), IRON, "mirror", T(0.075, 0.16, 0.83) @ R("Y", 90) @ R("X", 14))
    rope = (0.80, 0.70, 0.52)
    pts = [(0.075, 0.17, 0.77), (0.07, 0.2, 0.6), (0.1, 0.22, 0.42), (0.06, 0.25, 0.25), (0.12, 0.3, 0.12), (0.22, 0.38, 0.08)]
    p.add(tube(pts, 0.016, 5), rope, "fabric")
    p.add(torus(0.03, 0.016, 8, 5), rope, "fabric", T(0.075, 0.17, 0.77) @ R("Y", 90))
    for k in range(5):
        p.add(tube([(0.22, 0.38, 0.08), (0.27 + rng.uniform(-0.03, 0.03), 0.42 + rng.uniform(-0.03, 0.03), 0.03)], [0.006, 0.001], 3), rope, "fabric")
    marker_flower(p, T(-0.02, 0.105, 1.0) @ FRONT, 0.035)


# ------------------------------------------------------------------ the fells


def signal_brazier(p):
    """A sentry beacon for the fells tower: an iron fire-basket on three legs,
    laid with logs and burning, a signal horn slung beside it."""
    rng = random.Random(7391)
    for k in range(3):
        a = 2 * math.pi * k / 3
        p.add(tube([(math.cos(a) * 0.42, math.sin(a) * 0.42, 0.0), (math.cos(a) * 0.16, math.sin(a) * 0.16, 0.9), (math.cos(a) * 0.3, math.sin(a) * 0.3, 1.28)],
                   0.022, 5), IRON, "mirror")
    for z, rr in ((0.9, 0.18), (1.1, 0.3), (1.3, 0.36)):
        p.add(torus(rr, 0.016, 14, 4), IRON, "mirror", T(0, 0, z))
    for k in range(10):
        a = 2 * math.pi * k / 10
        p.add(tube([(math.cos(a) * 0.18, math.sin(a) * 0.18, 0.9), (math.cos(a) * 0.3, math.sin(a) * 0.3, 1.1), (math.cos(a) * 0.36, math.sin(a) * 0.36, 1.3)],
                   0.008, 3), IRON, "mirror")
        p.add(lathe([(0.012, 0.0), (0.0, 0.06)], 4), GOLD, "gold", T(math.cos(a) * 0.36, math.sin(a) * 0.36, 1.31))
    p.add(lathe([(0.0, 0.9), (0.17, 0.91), (0.26, 1.06)], 10, False, False), (0.16, 0.13, 0.16), "matte")
    for k in range(5):
        p.add(lathe([(0.0, 0.0), (0.05, 0.004), (0.05, 0.5), (0.0, 0.504)], 6), K.mix(OAK_DARK, (0.14, 0.11, 0.12), 0.5), "matte",
              T(0, 0, 1.08 + k * 0.03) @ R("Z", 36 * k * 2) @ R("X", 78) @ T(0, 0, -0.25),
              shade=lambda co: K.mix((0.14, 0.11, 0.12), (0.85, 0.42, 0.14), clamp(0.5 + 0.5 * math.sin(co.z * 31 + co.x * 60) - 0.2)))
    for k in range(7):
        a = 2 * math.pi * k / 7
        rr = 0.02 if k == 0 else 0.11
        hgt = 0.5 if k == 0 else rng.uniform(0.22, 0.36)
        fl = lathe([(0.0, 0.0), (0.07, hgt * 0.2), (0.05, hgt * 0.55), (0.0, hgt)], 6)
        for v in fl.verts:
            v.co.x += 0.03 * math.sin(v.co.z * 12 + k)
        p.add(fl, (0.85, 0.5, 0.16), "glow", T(math.cos(a) * rr, math.sin(a) * rr, 1.14),
              shade=(lambda hh: lambda co: K.mix((0.85, 0.36, 0.12), (0.85, 0.80, 0.42), clamp(1.0 - co.z / hh)))(hgt))
    horn = [(0.34, 0.1, 0.92), (0.4, 0.14, 0.8), (0.42, 0.2, 0.66), (0.38, 0.27, 0.54), (0.3, 0.32, 0.47)]
    p.add(tube(horn, [0.012, 0.02, 0.03, 0.042, 0.055], 8), BONE_HORN, "pearl")
    p.add(torus(0.056, 0.006, 10, 4), GOLD, "gold", T(0.3, 0.32, 0.47) @ R("Z", -32) @ R("Y", 60))
    p.add(lathe([(0.008, 0.0), (0.014, 0.02)], 6), GOLD, "gold", T(0.34, 0.1, 0.92) @ R("Y", 160))
    p.add(tube([(0.3, 0.26, 1.1), (0.36, 0.1, 0.93), (0.4, 0.2, 0.68)], 0.004, 3), ROSE, "fabric")


BONE_HORN = (0.82, 0.74, 0.60)


def sentry_weapon_rack(p):
    """The tower's arms rack: three boar-spears, a strung bow, and a Spring
    Court shield with the rose on its boss."""
    rng = random.Random(7392)
    for sx in (-1, 1):
        p.add(box(0.08, 0.5, 0.06, bevel=0.012), OAK_DARK, "satin", T(sx * 0.8, 0, 0.03))
        p.add(box(0.07, 0.07, 1.5, bevel=0.012), OAK, "satin", T(sx * 0.8, -0.1, 0.75) @ R("X", -6))
    for z, y in ((0.5, -0.05), (1.36, -0.14)):
        p.add(box(1.7, 0.06, 0.09, bevel=0.012), OAK, "satin", T(0, y, z))
        for i in range(4):
            p.add(torus(0.035, 0.008, 8, 4), IRON, "mirror", T(-0.55 + i * 0.3, y + 0.05, z) @ S(1, 1.2, 1))
    for i in range(3):
        m = T(-0.55 + i * 0.3, 0.02, 0.0) @ R("X", -7)
        p.add(lathe([(0.016, 0.0), (0.017, 1.0), (0.015, 1.86)], 6), K.lighter(OAK, 0.12), "satin", m)
        p.add(lathe([(0.02, 1.8), (0.022, 1.86), (0.014, 1.9)], 6), IRON, "mirror", m)
        p.add(lathe([(0.012, 0.0), (0.05, 0.08), (0.036, 0.2), (0.0, 0.34)], 8), STEEL, "mirror", m @ T(0, 0, 1.9) @ S(1, 0.25, 1), sharp_deg=70.0)
        p.add(U.ribbon([(0.0, 0.0), (0.03, -0.05), (0.02, -0.16)], 0.03, 0.002), [ROSE, BUTTER, MINT][i], "fabric", m @ T(0.02, 0, 1.84))
    bow_pts = [(-0.02 - 0.14 * math.sin(math.pi * i / 16), 0.2 + 1.4 * i / 16) for i in range(17)]
    p.add(U.sweep(bow_pts, [0.012 + 0.008 * math.sin(math.pi * i / 16) for i in range(17)], [0.009 + 0.006 * math.sin(math.pi * i / 16) for i in range(17)], 6),
          GREEN_DEEP, "satin", T(0.38, 0.0, 0.0) @ R("X", -7) @ R("Z", 180))
    p.add(tube([(0.38, 0.045, 0.2), (0.38, 0.215, 1.6)], 0.0025, 3), CREAM, "matte")
    sm = T(0.7, 0.16, 0.42) @ R("X", -14)
    shield = lathe([(0.0, 0.07), (0.1, 0.06), (0.26, 0.03), (0.34, 0.0), (0.345, -0.012), (0.0, -0.012)], 16)
    p.add(shield, GREEN_DEEP, "satin", sm @ FRONT, shade=lambda co: K.mix(GREEN_DEEP, GREEN, clamp(math.hypot(co.x, co.y) * 2.6)))
    p.add(torus(0.34, 0.016, 16, 4), GOLD, "gold", sm @ R("X", 90))
    p.add(lathe([(0.09, 0.0), (0.07, 0.03), (0.0, 0.045)], 10), GOLD, "gold", sm @ T(0, 0.06, 0) @ FRONT)
    K.layered_rose(p, sm @ T(0, 0.09, 0) @ FRONT, 0.075, ROSE, "pearl", rng, cupped=True)


def sentry_banner(p):
    """The Spring Court's banner for the watchtowers: sage silk bordered in
    gold, the rose in leaf at its heart, swallow-tailed."""
    rng = random.Random(7393)
    p.add(lathe([(0.0, 0.0), (0.14, 0.0), (0.15, 0.04), (0.05, 0.1), (0.035, 0.2), (0.03, 4.0), (0.05, 4.03), (0.0, 4.05)], 8), OAK, "satin")
    p.add(lathe([(0.03, 0.0), (0.06, 0.06), (0.02, 0.14), (0.045, 0.2), (0.0, 0.34)], 8), GOLD, "gold", T(0, 0, 4.04))
    p.add(tube([(-0.02, 0, 3.86), (1.08, 0, 3.86)], 0.02, 6), GOLD, "gold")
    p.add(lathe([(0.02, 0.0), (0.04, 0.03), (0.0, 0.07)], 6), GOLD, "gold", T(1.08, 0, 3.86) @ R("Y", 90))
    w, ln = 0.94, 1.9
    nx, nz = 8, 10
    import bmesh as _bm
    for layer, (col, inset, off) in enumerate(((GOLD, 0.0, 0.0), (GREEN_DEEP, 0.07, 0.004))):
        bm = _bm.new()
        grid = []
        for j in range(nz + 1):
            row = []
            for i in range(nx + 1):
                u, v = i / nx, j / nz
                x = 0.08 + inset + u * (w - 2 * inset)
                tail = 0.3 * abs(u - 0.5) * 2 if layer == 0 else 0.3 * abs(u - 0.5) * 2 - 0.02
                z = 3.84 - inset * 0.6 - v * (ln - inset * 1.2 - 0.3 + tail)
                y = 0.05 * math.sin(u * 5.0 + v * 4.0) * v + off
                row.append((x, y, z))
            grid.append(row)
        for sgn in (1, -1):         # two skins a hair apart, so it reads from both sides
            vs = [[bm.verts.new((x, y + sgn * (0.003 + off), z)) for (x, y, z) in row] for row in grid]
            for j in range(nz):
                for i in range(nx):
                    quad = (vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i])
                    bm.faces.new(quad if sgn > 0 else quad[::-1])
        p.add(bm, col, "gold" if layer == 0 else "pearl",
              shade=None if layer == 0 else (lambda co: K.mix(GREEN_DEEP, GREEN, clamp((3.9 - co.z) / 2.0))))
    for sgn in (1, -1):
        m = T(0.55, sgn * 0.035, 3.05) @ (FRONT if sgn > 0 else R("X", 90))
        K.layered_rose(p, m, 0.16, ROSE, "pearl", rng, cupped=True)
        for a in (30, 150, 210, 330, 270):
            p.add(K.leaf(0.24, 0.1), GOLD, "gold", m @ R("Z", a) @ T(0.1, 0, -0.004))
    for x in (0.1, 1.0):
        p.add(tube([(x, 0, 3.86), (x + 0.01, 0.01, 3.62)], 0.004, 3), GOLD, "gold")
        p.add(lathe([(0.008, 0.0), (0.022, -0.02), (0.026, -0.1), (0.016, -0.11)], 7), ROSE, "fabric", T(x + 0.01, 0.01, 3.62))


def range_marker(p):
    """A distance post for the sentries' range: banded in rose and cream, a
    pennant, two spent arrows left in it."""
    rng = random.Random(7394)
    bands = [ROSE, CREAM, ROSE, CREAM, ROSE, CREAM, GOLD]
    p.add(lathe([(0.07, 0.0), (0.06, 0.1), (0.055, 1.4), (0.07, 1.42), (0.07, 1.46), (0.0, 1.5)], 10), ROSE, "satin",
          shade=lambda co: bands[min(6, int(co.z / 0.215))])
    p.add(sphere(0.06, 10, 6), GOLD, "gold", T(0, 0, 1.54))
    pen = [(0.0, 1.38), (0.2, 1.32 + 0.02), (0.45, 1.25), (0.2, 1.2 - 0.02), (0.0, 1.14)]
    flag = U.slab(pen, 0.004)
    for v in flag.verts:
        v.co.y += 0.04 * math.sin(v.co.x * 12)
    p.add(flag, BUTTER, "fabric", T(0.055, 0, 0))
    for k, (z, yaw, pitch) in enumerate(((0.9, 200, 18), (0.62, 160, -8))):
        m = T(0, 0, z) @ R("Z", yaw) @ R("X", 90 + pitch) @ T(0, 0, -0.6)
        p.add(lathe([(0.0055, 0.0), (0.0055, 0.56)], 6, True, False), (0.549, 0.416, 0.271), "satin", m)
        for j in range(3):
            p.add(U.slab([(0.003, 0.02), (0.003, 0.12), (0.012, 0.11), (0.022, 0.05), (0.02, 0.022)], 0.0013), [ROSE, BLUSH][k], "fabric", m @ R("Z", 120 * j + 90))
    for k in range(6):
        p.add(K.leaf(rng.uniform(0.14, 0.24), 0.03), K.mix(GREEN, GREEN_DEEP, rng.random()), "leaf",
              T(rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 0) @ R("Z", rng.uniform(0, 360)) @ R("Y", -rng.uniform(50, 80)))


# ------------------------------------------------------------------ the blight


def _thorn_cane(p, pts, r0, rng, thorns=7, col=DEAD):
    n = len(pts)
    p.add(tube(pts, [r0 * (1 - 0.6 * i / (n - 1)) for i in range(n)], 4), col, "matte",
          shade=lambda co: K.mix(col, ROT, 0.5 + 0.5 * math.sin(co.z * 17 + co.x * 23)))
    for k in range(thorns):
        i = rng.randrange(n - 1)
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        q = a.lerp(b, rng.random())
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 0.8))).normalized()
        m = T(*q) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        p.add(lathe([(r0 * 0.7, 0.0), (0.0, r0 * rng.uniform(4.0, 7.0))], 4), ROT, "matte", m, sharp_deg=20.0)


def blight_rose_bush(p):
    """A rose bush the blight has taken: bare black-thorned canes, the
    blooms hung grey and shut, petals fallen to ash beneath."""
    rng = random.Random(7401)
    for k in range(9):
        a = 2 * math.pi * k / 9 + rng.uniform(-0.3, 0.3)
        lean = rng.uniform(0.25, 0.6)
        hgt = rng.uniform(0.7, 1.25)
        pts = [(math.cos(a) * 0.06, math.sin(a) * 0.06, 0.0)]
        for i in range(1, 6):
            u = i / 5
            pts.append((math.cos(a) * (0.06 + lean * u * u) + rng.uniform(-0.04, 0.04), math.sin(a) * (0.06 + lean * u * u) + rng.uniform(-0.04, 0.04),
                        hgt * math.sin(u * math.pi * 0.62) / math.sin(math.pi * 0.62)))
        _thorn_cane(p, pts, 0.018, rng, 6)
        if k % 3 != 1:
            tip = Vector(pts[-1])
            p.add(tube([tip, tip + Vector((0, 0, -0.06))], 0.004, 3), DEAD, "matte")
            K.soft_rose(p, T(*(tip + Vector((0, 0, -0.06)))) @ R("X", 180 + rng.uniform(-25, 25)), 0.055, K.mix(DEAD_PALE, (0.42, 0.30, 0.32), rng.random()), "matte", rng, petals=3)
        for j in range(2):
            q = Vector(pts[rng.randrange(2, 5)])
            p.add(K.leaf(0.07, 0.03), K.mix(DEAD_PALE, (0.36, 0.33, 0.24), rng.random()), "matte", T(*q) @ R("Z", rng.uniform(0, 360)) @ R("Y", rng.uniform(20, 70)))
    p.add(U.splat(0.55, 0.5, 14, rng, 0.3, 0.01), ROT, "matte", shade=lambda co: K.mix(ROT, DEAD, clamp(math.hypot(co.x, co.y) * 1.8)))
    for k in range(16):
        a, rr = rng.uniform(0, 6.283), rng.uniform(0.1, 0.6)
        p.add(K.round_petal(0.035, 0.03, cup=0.3), DEAD_PALE, "matte", T(math.cos(a) * rr, math.sin(a) * rr, 0.012) @ R("Z", rng.uniform(0, 360)))


def blight_thorn_arch(p):
    """Where a garden arch stood in the Reaches: black briars thick as a
    wrist grown over it into a gate of thorns, a strip of mask-ribbon caught in it."""
    rng = random.Random(7402)
    for k in range(9):
        off = (k - 4) * 0.045
        ph = rng.uniform(0, 6)
        pts = []
        for i in range(15):
            u = i / 14
            a = math.pi * u
            rx, rz = 1.25 + off + 0.1 * math.sin(u * 9 + ph), 2.75 + off * 1.5 + 0.12 * math.sin(u * 7 + ph)
            pts.append((-math.cos(a) * rx, 0.22 * math.sin(u * 11 + ph * 2) + (k % 3 - 1) * 0.1, math.sin(a) ** 0.75 * rz if 0 < i < 14 else 0.0))
        _thorn_cane(p, pts, rng.uniform(0.03, 0.055), rng, 14)
    for k in range(10):
        x = rng.choice((-1, 1)) * rng.uniform(1.0, 1.5)
        pts = [(x, rng.uniform(-0.3, 0.3), 0.0), (x + rng.uniform(-0.3, 0.3), rng.uniform(-0.5, 0.5), rng.uniform(0.3, 0.7)),
               (x + rng.uniform(-0.5, 0.5), rng.uniform(-0.6, 0.6), rng.uniform(0.1, 0.5))]
        _thorn_cane(p, pts, 0.022, rng, 4)
    for k in range(18):
        a = math.pi * rng.random()
        p.add(K.leaf(0.11, 0.05), K.mix(DEAD_PALE, (0.36, 0.33, 0.24), rng.random()), "matte",
              T(-math.cos(a) * 1.3, rng.uniform(-0.25, 0.25), math.sin(a) * 2.7) @ R("Z", rng.uniform(0, 360)) @ R("Y", rng.uniform(30, 110)))
    p.add(U.ribbon([(0.0, 0.0), (0.03, -0.1), (-0.02, -0.3), (0.04, -0.48), (0.0, -0.62)], 0.05, 0.002), (0.50, 0.20, 0.26), "fabric", T(0.5, 0.2, 2.5))
    p.add(U.splat(1.9, 0.8, 16, rng, 0.25, 0.012), ROT, "matte", shade=lambda co: K.mix(ROT, DEAD, clamp(math.hypot(co.x / 1.9, co.y / 0.8) * 1.4)))


def blight_carcass(p):
    """What the blight leaves of a stag: the hide sunk on the ribs, antlers
    and skull clean, the ground black under it. Horror, not gore."""
    rng = random.Random(7403)
    hide = (0.34, 0.27, 0.25)
    body = U.rock(0.5, 2, 5.1, 0.14)
    for v in body.verts:
        v.co.x *= 1.5
        v.co.y *= 0.62
        v.co.z = max(v.co.z * 0.5, -0.06) * (0.55 if abs(v.co.x) < 0.4 and v.co.z > 0.05 else 1.0)
    p.add(body, hide, "matte", T(0, 0, 0.1), shade=lambda co: K.mix(ROT, hide, clamp(0.3 + co.z * 3 + 0.3 * math.sin(co.x * 9))))
    for k in range(8):
        x = -0.34 + k * 0.095
        arc = [(x, -0.28 + 0.56 * i / 8, 0.1 + 0.25 * math.sin(math.pi * i / 8) * (1 - 0.08 * abs(k - 3.5))) for i in range(9)]
        p.add(tube(arc[:7 if k % 3 == 0 else 9], 0.011, 4), BONE, "satin", shade=lambda co: K.mix(K.darker(BONE, 0.25), BONE, clamp(co.z * 4)))
    p.add(tube([(-0.42, 0, 0.3), (0.0, 0, 0.34), (0.5, 0, 0.27), (0.72, 0.02, 0.2)], [0.02, 0.022, 0.018, 0.012], 5), BONE, "satin")
    sm = T(-0.85, 0.12, 0.09) @ R("Z", 25) @ R("Y", 12)
    skull = lathe([(0.0, -0.2), (0.03, -0.18), (0.045, -0.06), (0.075, 0.02), (0.085, 0.1), (0.05, 0.17), (0.0, 0.18)], 8)
    p.add(skull, BONE, "satin", sm @ R("Y", 90) @ S(1, 0.9, 1))
    for sy in (-1, 1):
        p.add(sphere(0.026, 7, 4), ROT, "matte", sm @ T(-0.03, sy * 0.062, 0.03) @ S(1, 0.5, 1))
        base = Vector((-0.11, sy * 0.05, 0.05))
        beam = [base, base + Vector((-0.1, sy * 0.12, 0.18)), base + Vector((-0.06, sy * 0.26, 0.38)), base + Vector((0.08, sy * 0.32, 0.5))]
        p.add(tube(beam, [0.02, 0.017, 0.013, 0.006], 5), K.darker(BONE, 0.12), "satin", sm)
        for j, (i, dx, dz) in enumerate(((1, 0.12, 0.1), (2, 0.14, 0.08), (2, -0.1, 0.14))):
            p.add(tube([beam[i], beam[i] + Vector((dx, sy * 0.03, dz))], [0.012, 0.003], 4), K.darker(BONE, 0.12), "satin", sm)
    p.add(tube([(-0.55, 0.02, 0.2), (-0.7, 0.08, 0.14), (-0.8, 0.11, 0.1)], [0.03, 0.025, 0.022], 5), BONE, "satin")
    for (x, y, a) in ((-0.45, -0.3, -100), (-0.3, -0.34, -75), (0.5, -0.3, -110), (0.62, -0.28, -80)):
        leg = [(x, y * 0.6, 0.12), (x + math.cos(math.radians(a)) * 0.3, y - 0.3, 0.06), (x + math.cos(math.radians(a)) * 0.5, y - 0.62, 0.03)]
        p.add(tube(leg, [0.03, 0.018, 0.014], 5), K.mix(hide, BONE, 0.3), "matte")
        p.add(lathe([(0.016, 0.0), (0.02, 0.03), (0.0, 0.05)], 5), ROT, "matte", T(*leg[-1]) @ R("X", 100))
    p.add(U.splat(1.25, 0.8, 16, rng, 0.3, 0.008), ROT, "satin", T(0, -0.1, 0.0))
    for k in range(10):
        a, rr = rng.uniform(0, 6.283), rng.uniform(0.9, 1.5)
        p.add(K.leaf(0.12, 0.04), DEAD_PALE, "matte", T(math.cos(a) * rr, math.sin(a) * rr * 0.7, 0.01) @ R("Z", rng.uniform(0, 360)) @ R("Y", -rng.uniform(10, 50)))


def blight_dry_fountain(p):
    """A garden fountain in the Reaches: dry, split, its finial fallen, a
    black scum where the water was, dead creeper over the rim."""
    rng = random.Random(7404)
    stone = (0.50, 0.47, 0.50)
    sh = lambda co: K.mix(K.darker(stone, 0.35), stone, clamp(0.45 + co.z * 0.7 + 0.25 * math.sin(co.x * 6 + co.y * 5)))  # noqa: E731
    p.add(lathe([(0.0, 0.0), (1.05, 0.0), (1.1, 0.06), (1.02, 0.12), (1.05, 0.34), (1.12, 0.4), (1.0, 0.42), (0.92, 0.36), (0.9, 0.14), (0.0, 0.12)], 16),
          stone, "matte", shade=sh)
    p.add(U.splat(0.86, 0.86, 16, rng, 0.12, 0.01), ROT, "pearl", T(0, 0, 0.125))
    p.add(lathe([(0.0, 0.12), (0.22, 0.12), (0.24, 0.2), (0.12, 0.3), (0.1, 0.8), (0.16, 0.86), (0.5, 0.96), (0.52, 1.02), (0.44, 1.02), (0.12, 0.94),
                 (0.0, 0.94)], 12), stone, "matte", R("Y", 4), shade=sh)
    fin = lathe([(0.0, 0.0), (0.1, 0.0), (0.12, 0.08), (0.06, 0.16), (0.1, 0.3), (0.05, 0.42), (0.0, 0.46)], 8)
    p.add(fin, stone, "matte", T(0.55, 0.5, 0.2) @ R("X", 100) @ R("Z", 40), shade=sh)
    for k in range(7):
        a = rng.uniform(0, 6.283)
        pts = [(math.cos(a) * 1.08, math.sin(a) * 1.08, 0.41)]
        for i in range(1, 5):
            aa = a + rng.uniform(-0.25, 0.25)
            pts.append((math.cos(aa) * (1.08 + 0.02), math.sin(aa) * (1.08 + 0.02), 0.41 - i * 0.1))
        p.add(tube(pts, 0.006, 3), ROT, "matte")
    for k in range(5):
        a0 = rng.uniform(0, 6.283)
        pts = [(math.cos(a0 + i * 0.22) * (1.07 + 0.05 * math.sin(i * 1.7)), math.sin(a0 + i * 0.22) * (1.07 + 0.05 * math.sin(i * 1.7)),
                0.43 + 0.04 * math.sin(i * 2.1) - (0.12 * i if k % 2 else 0.0)) for i in range(7)]
        _thorn_cane(p, pts, 0.014, rng, 4)
        for j in range(4):
            q = Vector(pts[rng.randrange(7)])
            p.add(K.leaf(0.09, 0.05), K.mix(DEAD_PALE, (0.36, 0.33, 0.24), rng.random()), "matte", T(*q) @ R("Z", rng.uniform(0, 360)) @ R("Y", rng.uniform(-40, 40)))
    for k in range(6):
        p.add(U.shard(rng, rng.uniform(0.08, 0.2)), stone, "matte", T(rng.uniform(-1.4, 1.4), rng.choice((-1, 1)) * rng.uniform(1.15, 1.4), 0.01) @ FLAT)


def blight_withered_patch(p):
    """Ground dressing for the Reaches' edge: a 2 m patch of flowers gone
    over on their stalks, grey curled leaves, the soil stained dark."""
    rng = random.Random(7405)
    p.add(U.splat(1.0, 0.95, 16, rng, 0.3, 0.012), ROT, "matte", shade=lambda co: K.mix(ROT, DEAD, clamp(math.hypot(co.x, co.y) * 1.3 - 0.2)))
    for k in range(22):
        a, rr = rng.uniform(0, 6.283), 0.9 * math.sqrt(rng.random())
        x, y = math.cos(a) * rr, math.sin(a) * rr
        h = rng.uniform(0.18, 0.42)
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)).normalized() * h * 0.6
        top = Vector((x, y, h))
        end = top + d + Vector((0, 0, -h * rng.uniform(0.3, 0.75)))
        col = K.mix(DEAD, DEAD_PALE, rng.random())
        p.add(tube([(x, y, 0), top, top + d * 0.6 + Vector((0, 0, 0.02)), end], [0.006, 0.005, 0.004, 0.003], 3), col, "matte")
        head = K.mix(DEAD_PALE, [(0.46, 0.30, 0.34), (0.42, 0.36, 0.48), (0.50, 0.46, 0.30)][k % 3], 0.6)
        p.add(lathe([(0.0, 0.0), (0.022, -0.012), (0.03, -0.04), (0.012, -0.06)], 5, True, False), head, "matte", T(*end) @ R("X", rng.uniform(-30, 30)), sharp_deg=80.0)
        p.add(K.leaf(0.08, 0.025), col, "matte", T(x, y, h * 0.4) @ R("Z", rng.uniform(0, 360)) @ R("Y", rng.uniform(20, 80)))
    for k in range(14):
        a, rr = rng.uniform(0, 6.283), rng.uniform(0.2, 1.0)
        p.add(K.leaf(0.1, 0.04), K.mix(DEAD_PALE, (0.36, 0.33, 0.24), rng.random()), "matte",
              T(math.cos(a) * rr, math.sin(a) * rr, 0.015) @ R("Z", rng.uniform(0, 360)) @ R("Y", -rng.uniform(5, 30)))


def blight_dead_birds(p):
    """Songbirds dropped where they flew into the blight: five small bodies
    on the path and their feathers."""
    rng = random.Random(7406)
    for k in range(5):
        a, rr = k * 1.3, rng.uniform(0.1, 0.55)
        col = [(0.34, 0.30, 0.36), (0.42, 0.34, 0.30), (0.30, 0.34, 0.42)][k % 3]
        m = T(math.cos(a) * rr, math.sin(a) * rr, 0.022) @ R("Z", rng.uniform(0, 360))
        p.add(lathe([(0.0, -0.05), (0.022, -0.035), (0.03, 0.0), (0.022, 0.035), (0.014, 0.05), (0.018, 0.062), (0.0, 0.08)], 7), col, "matte",
              m @ R("Y", 90) @ S(1, 1, 1), shade=(lambda c: lambda co: K.mix(c, DEAD_PALE, clamp(-co.x * 30)))(col))
        p.add(lathe([(0.004, 0.0), (0.0, 0.016)], 4), (0.62, 0.52, 0.30), "matte", m @ T(0.078, 0, 0) @ R("Y", 90))
        for sy in (-1, 1):
            p.add(K.leaf(0.075, 0.03), K.darker(col, 0.2), "matte", m @ T(-0.01, sy * 0.02, 0.0) @ R("Z", sy * rng.uniform(60, 130)) @ R("Y", -rng.uniform(0, 20)))
        p.add(K.leaf(0.05, 0.016), K.darker(col, 0.3), "matte", m @ T(-0.05, 0, 0) @ R("Z", 180))
        for sy in (-1, 1):
            p.add(tube([(0.0, sy * 0.008, 0.01), (-0.01, sy * 0.012, 0.04)], 0.0015, 3), (0.42, 0.34, 0.30), "matte", m)
    for k in range(9):
        a, rr = rng.uniform(0, 6.283), rng.uniform(0.2, 0.8)
        p.add(K.leaf(0.05, 0.014), DEAD_PALE, "matte", T(math.cos(a) * rr, math.sin(a) * rr, 0.004) @ R("Z", rng.uniform(0, 360)))


# ------------------------------------------------------------------ cast routines


def laundry_basket(p):
    """Alis's hours: a wicker basket of folded linen with a sprig of lavender."""
    rng = random.Random(7411)
    wick = (0.80, 0.64, 0.42)
    p.add(lathe([(0.0, 0.0), (0.2, 0.0), (0.23, 0.03), (0.28, 0.3), (0.3, 0.32), (0.28, 0.32), (0.25, 0.3), (0.2, 0.04), (0.0, 0.04)], 16), wick, "fabric",
          S(1.25, 1, 1), shade=lambda co: K.mix(K.darker(wick, 0.25), wick, 0.5 + 0.5 * math.sin(co.z * 120) * math.sin(math.atan2(co.y, co.x) * 14)))
    for z in (0.03, 0.17, 0.31):
        rr = 0.23 + (z - 0.03) * 0.25
        p.add(torus(rr, 0.012, 16, 4), K.darker(wick, 0.15), "fabric", T(0, 0, z) @ S(1.25, 1, 1))
    for sx in (-1, 1):
        p.add(tube([(sx * 0.36, -0.07, 0.3), (sx * 0.43, 0, 0.36), (sx * 0.36, 0.07, 0.3)], 0.014, 5), K.darker(wick, 0.2), "fabric")
    cols = [CREAM, BLUSH, PEARL, K.lighter(PERI, 0.2), CREAM]
    for k, col in enumerate(cols):
        p.add(K.cushion(0.4 - k * 0.02, 0.3, 0.06, puff=0.5), col, "fabric", T(rng.uniform(-0.03, 0.03), rng.uniform(-0.02, 0.02), 0.2 + k * 0.05) @ R("Z", rng.uniform(-7, 7)))
    for k in range(3):
        x = -0.06 + k * 0.05
        p.add(tube([(x, -0.1, 0.46), (x + 0.02, 0.08, 0.47)], 0.003, 3), GREEN_DEEP, "leaf")
        p.add(lathe([(0.0, 0.0), (0.012, 0.01), (0.009, 0.06), (0.0, 0.075)], 5), LILAC, "fabric", T(x + 0.02, 0.08, 0.47) @ FRONT)
    p.add(U.ribbon([(0.0, 0.0), (0.02, 0.01), (0.04, 0.0)], 0.02, 0.002), ROSE, "fabric", T(-0.03, -0.04, 0.463))


def whetstone_kit(p):
    """Lucien's hours: a whetstone on its block, an oil flask, a rag and a
    long hunting knife laid across it."""
    p.add(box(0.34, 0.14, 0.04, bevel=0.01), OAK, "satin", T(0, 0, 0.02), shade=U.grain(OAK, 0.14, 60.0))
    p.add(box(0.26, 0.085, 0.035, bevel=0.006), (0.52, 0.54, 0.62), "matte", T(0, 0, 0.057),
          shade=lambda co: K.mix((0.52, 0.54, 0.62), (0.40, 0.42, 0.52), clamp(0.5 + 0.5 * math.sin(co.x * 50)) * clamp(co.z * 60)))
    km = T(0.0, 0.01, 0.079) @ R("Z", 22) @ R("Y", 90)
    p.add(lathe([(0.003, 0.0), (0.02, 0.02), (0.018, 0.14), (0.01, 0.24), (0.0, 0.28)], 8), STEEL, "mirror", km @ T(0, 0, -0.06) @ S(0.16, 1, 1), sharp_deg=60.0)
    p.add(lathe([(0.011, -0.12), (0.014, -0.09), (0.012, -0.02), (0.015, -0.006)], 8), (0.62, 0.30, 0.20), "fabric", km @ T(0, 0, -0.05) @ S(0.8, 1, 1))
    p.add(tube([(-0.03, 0, -0.056), (0.03, 0, -0.056)], 0.005, 5), GOLD, "gold", km @ R("Z", 90))
    p.add(lathe([(0.0, -0.014), (0.014, -0.008), (0.0, 0.0)], 8), GOLD, "gold", km @ T(0, 0, -0.17))
    p.add(lathe([(0.0, 0.0), (0.03, 0.0), (0.038, 0.02), (0.03, 0.06), (0.012, 0.075), (0.012, 0.1), (0.016, 0.104), (0.0, 0.106)], 9), COPPER, "gold", T(0.24, 0.05, 0))
    p.add(K.cushion(0.16, 0.12, 0.025, puff=0.7), (0.80, 0.42, 0.30), "fabric", T(-0.26, 0.03, 0.012) @ R("Z", 25))
    p.add(K.cushion(0.1, 0.08, 0.02, puff=0.7), (0.80, 0.42, 0.30), "fabric", T(-0.24, 0.05, 0.03) @ R("Z", -15))


BUILDERS = {
    # id: (builder, size (None: as modelled, true scale), meta)
    "seam_dress_form": (seam_dress_form, None, dict(place="fae_village", shop="seamstress")),
    "seam_loom": (seam_loom, None, dict(place="fae_village", shop="seamstress")),
    "seam_fabric_bolts": (seam_fabric_bolts, None, dict(place="fae_village", shop="seamstress")),
    "seam_ribbon_rack": (seam_ribbon_rack, None, dict(place="fae_village", shop="seamstress", mount="wall")),
    "seam_worktable": (seam_worktable, None, dict(place="fae_village", shop="seamstress")),
    "seam_crown_stand": (seam_crown_stand, None, dict(place="fae_village", shop="seamstress")),
    "potion_shelf": (potion_shelf, None, dict(place="fae_village", shop="potion_maker")),
    "potion_alembic": (potion_alembic, None, dict(place="fae_village", shop="potion_maker")),
    "potion_mortar": (potion_mortar, None, dict(place="fae_village", shop="potion_maker")),
    "potion_herb_rack": (potion_herb_rack, None, dict(place="fae_village", shop="potion_maker", mount="hanging")),
    "potion_counter": (potion_counter, None, dict(place="fae_village", shop="potion_maker")),
    "climb_ivy_panel": (climb_ivy_panel, None, dict(place="western_fells", climbable=True, mount="wall")),
    "climb_root_ladder": (climb_root_ladder, None, dict(place="western_fells", climbable=True, mount="wall")),
    "climb_ledge": (climb_ledge, None, dict(place="western_fells", climbable=True, mount="wall")),
    "climb_handholds": (climb_handholds, None, dict(place="western_fells", climbable=True, mount="wall")),
    "cliff_rope_anchor": (cliff_rope_anchor, None, dict(place="western_fells", rope_target=True)),
    "signal_brazier": (signal_brazier, None, dict(place="western_fells")),
    "sentry_weapon_rack": (sentry_weapon_rack, None, dict(place="western_fells")),
    "sentry_banner": (sentry_banner, None, dict(place="western_fells")),
    "range_marker": (range_marker, None, dict(place="western_fells")),
    "blight_rose_bush": (blight_rose_bush, None, dict(place="blighted_reaches", horror=True)),
    "blight_thorn_arch": (blight_thorn_arch, None, dict(place="blighted_reaches", horror=True)),
    "blight_carcass": (blight_carcass, None, dict(place="blighted_reaches", horror=True)),
    "blight_dry_fountain": (blight_dry_fountain, None, dict(place="blighted_reaches", horror=True)),
    "blight_withered_patch": (blight_withered_patch, None, dict(place="blighted_reaches", horror=True)),
    "blight_dead_birds": (blight_dead_birds, None, dict(place="blighted_reaches", horror=True)),
    "laundry_basket": (laundry_basket, None, dict(place="manor_estate", routine="alis")),
    "whetstone_kit": (whetstone_kit, None, dict(place="manor_estate", routine="lucien")),
}

VILLAGE = [k for k, v in BUILDERS.items() if v[2]["place"] in ("fae_village", "manor_estate")]
FELLS = [k for k, v in BUILDERS.items() if v[2]["place"] == "western_fells"]
BLIGHT = [k for k, v in BUILDERS.items() if v[2]["place"] == "blighted_reaches"]
SHEETS = [
    ("village_shops_and_routines.png", VILLAGE, 5, 28, 20, False),
    ("fells_climb_and_sentry.png", FELLS, 5, 28, 16, False),
    ("blighted_reaches.png", BLIGHT, 3, 28, 22, False),
]

if __name__ == "__main__":
    U.run_family(BUILDERS, OUT, "wider_world_manifest.json", sys.argv[1:], SHEETS)
