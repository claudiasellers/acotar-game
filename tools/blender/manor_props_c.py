"""Manor prop models, part C: nursery toys, crafts and the observatory, the ids
the earlier procedural pass added and the house layouts now place.

Same contract as parts A and B: builder(p, size, color), front faces +Y, fitted afterwards.
"""

import math
import random

from mathutils import Vector

from manor_props_a import gilt_edge, knob
from prop_kit import (BLUSH, BUTTER, CANVAS, CREAM, GOLD, GOLD_DEEP, LILAC, MINT, OAK, OAK_DARK, PEARL, PERI, ROSE,
                      SOFT_BLUE, WHITE, R, S, T, bloom, box, cushion, cyl, darker, disc, hexc, ico, lathe, lighter,
                      sphere, torus, tube, turned_leg)

SLATE = hexc("#9C93B8")          # pastel lilac-grey roof slate (experience bar §2.5)
LIT_WINDOW = hexc("#FFD9A0")
WOOL = [BLUSH, BUTTER, MINT, LILAC, PERI, ROSE]


def _wheel(p, centre, r, spokes, col, hub=GOLD, thick=0.02):
    """A spoked wheel in the XZ plane (faces the front)."""
    m = T(*centre) @ R("X", 90)
    p.add(torus(r, thick, 24, 4), col, "satin", m)
    for k in range(spokes):
        p.add(cyl(thick * 0.5, r, 4), col, "satin", T(*centre) @ R("Y", 360 * k / spokes))
    p.add(cyl(thick * 1.6, thick * 4, 8), hub, "gold", T(centre[0], centre[1] - thick * 2, centre[2]) @ R("X", -90))


def _horse(p, L, H, z0, body, mane, saddle):
    """A storybook horse along X (head at +X), hooves at z0, standing H tall."""
    bz = z0 + H * 0.55
    p.add(sphere(1.0, 14, 8), body, "satin", T(0, 0, bz) @ S(L * 0.36, L * 0.14, H * 0.18))
    neck = [(L * 0.26, 0, bz + H * 0.05), (L * 0.35, 0, bz + H * 0.2), (L * 0.40, 0, bz + H * 0.3)]
    p.add(tube(neck, [L * 0.09, L * 0.075, L * 0.065], 8), body, "satin")
    p.add(sphere(1.0, 10, 7), body, "satin", T(L * 0.46, 0, bz + H * 0.3) @ R("Y", 30) @ S(L * 0.12, L * 0.065, L * 0.06))
    for sy in (-1, 1):
        p.add(lathe([(L * 0.025, 0), (0, L * 0.07)], 5), body, "satin", T(L * 0.40, sy * L * 0.035, bz + H * 0.37))
        p.add(sphere(L * 0.014, 6, 4), OAK_DARK, "satin", T(L * 0.47, sy * L * 0.05, bz + H * 0.34))
    for k in range(6):   # curly mane down the neck
        t = k / 5
        p.add(ico(L * 0.045, 1), mane, "fabric", T(L * (0.27 + 0.11 * t), 0, bz + H * (0.12 + 0.25 * t)) @ S(0.8, 1.2, 1.0))
    p.add(tube([(-L * 0.34, 0, bz + H * 0.05), (-L * 0.44, 0, bz - H * 0.1), (-L * 0.42, 0, bz - H * 0.32)],
               [L * 0.05, L * 0.06, L * 0.03], 6), mane, "fabric")
    p.add(sphere(1.0, 12, 6), saddle, "fabric", T(-L * 0.02, 0, bz + H * 0.165) @ S(L * 0.12, L * 0.155, H * 0.03))
    p.add(torus(1.0, 0.07, 16, 3), GOLD, "gold", T(-L * 0.02, 0, bz + H * 0.16) @ S(L * 0.12, L * 0.155, L * 0.15))
    p.add(torus(L * 0.07, L * 0.008, 12, 3), GOLD, "gold", T(L * 0.47, 0, bz + H * 0.3) @ R("Y", 30) @ R("X", 90) @ S(1, 1, 0.9))
    for sx in (-1, 1):
        for sy in (-1, 1):
            top = (sx * L * 0.22, sy * L * 0.07, bz - H * 0.05)
            foot = (sx * L * 0.30, sy * L * 0.09, z0 + H * 0.04)
            p.add(tube([top, foot], [L * 0.045, L * 0.03], 6), body, "satin")
            p.add(cyl(L * 0.035, H * 0.05, 8), GOLD, "gold", T(foot[0], foot[1], z0))


def rocking_horse(p, size, c):
    for sy in (-1, 1):
        pts = [(1.0 * math.sin(a) * 0.62, sy * 0.18, 0.62 - 0.62 * math.cos(a) + 0.03)
               for a in [math.radians(-55 + 110 * i / 8) for i in range(9)]]
        p.add(tube(pts, 0.035, 6), OAK, "satin")
        p.add(sphere(0.045, 8, 5), GOLD, "gold", T(*pts[0]))
        p.add(sphere(0.045, 8, 5), GOLD, "gold", T(*pts[-1]))
    for x in (-0.3, 0.3):
        p.add(box(0.06, 0.4, 0.04, bevel=0.01), OAK_DARK, "satin", T(x, 0, 0.06))
    _horse(p, 1.0, 0.95, 0.08, c, BLUSH, ROSE)
    rng = random.Random(41)
    bloom(p, (0.3, 0.09, 0.79), 0.045, ROSE, 2, 5, rng, tilt=R("X", -90))


def toy_wooden_horse(p, size, c):
    p.add(box(0.44, 0.22, 0.04, bevel=0.01), OAK_DARK, "satin", T(0, 0, 0.06))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(cyl(0.05, 0.03, 10), ROSE, "satin", T(sx * 0.15, sy * 0.12, 0.05) @ R("X", 90 * sy))
            p.add(cyl(0.015, 0.035, 6), GOLD, "gold", T(sx * 0.15, sy * 0.12, 0.05) @ R("X", 90 * sy))
    _horse(p, 0.42, 0.42, 0.08, CREAM, BUTTER, PERI)
    p.add(tube([(0.22, 0, 0.07), (0.24, 0.08, 0.02), (0.2, 0.14, 0.0)], 0.006, 3), ROSE, "fabric")


def spinning_wheel(p, size, c):
    p.add(box(0.95, 0.24, 0.07, bevel=0.02), c, "satin", T(0, 0, 0.46) @ R("Y", -6))
    for x, y in ((-0.4, 0.0), (0.38, 0.09), (0.38, -0.09)):
        p.add(turned_leg(0.46, 0.025), c, "satin", T(x, y, 0.0) @ R("Y", 8 if x < 0 else -6))
    for sy in (-1, 1):
        p.add(box(0.05, 0.04, 0.42, bevel=0.01), c, "satin", T(0.18, sy * 0.07, 0.68) @ R("Y", 6))
    _wheel(p, (0.2, 0.0, 0.78), 0.3, 10, c)
    p.add(box(0.3, 0.12, 0.02, bevel=0.005), darker(c, 0.1), "satin", T(0.2, 0, 0.06) @ R("Y", 8))
    p.add(tube([(0.2, 0.0, 0.78), (0.24, 0.0, 0.4), (0.15, 0.0, 0.1)], 0.008, 3), OAK_DARK, "satin")
    # mother-of-all and flyer at the left, with blush wool on the bobbin
    for x in (-0.42, -0.26):
        p.add(cyl(0.02, 0.22, 6), c, "satin", T(x, 0.0, 0.5))
    p.add(cyl(0.035, 0.18, 8), BLUSH, "fabric", T(-0.43, 0.0, 0.66) @ R("Y", 90))
    p.add(torus(0.05, 0.008, 10, 3), GOLD, "gold", T(-0.34, 0.0, 0.66) @ R("Y", 90))
    # distaff with a cloud of wool
    p.add(tube([(-0.36, -0.06, 0.5), (-0.3, -0.08, 0.85), (-0.28, -0.08, 1.0)], 0.012, 4), c, "satin")
    p.add(ico(0.09, 1), PEARL, "fabric", T(-0.28, -0.08, 0.98) @ S(0.9, 0.9, 1.3))
    p.add(tube([(-0.28, -0.08, 0.9), (-0.38, -0.03, 0.75), (-0.43, 0.0, 0.67)], 0.005, 3), PEARL, "fabric")
    for k, col in enumerate((ROSE, BUTTER, MINT)):
        p.add(cyl(0.03, 0.05, 8), col, "fabric", T(0.32 + 0.04 * k, 0.02 * k - 0.02, 0.495) @ R("Y", -6))


def embroidery_frame(p, size, c):
    for sx in (-1, 1):
        p.add(box(0.08, 0.56, 0.05, bevel=0.015), c, "satin", T(sx * 0.42, 0, 0.025))
        p.add(turned_leg(0.86, 0.028), c, "satin", T(sx * 0.42, 0, 0.05))
        p.add(sphere(0.035, 8, 5), GOLD, "gold", T(sx * 0.42, 0, 0.93))
    p.add(cyl(0.018, 0.84, 6), c, "satin", T(-0.42, 0, 0.3) @ R("Y", 90))
    m = T(0, 0.02, 0.86) @ R("X", -72)
    p.add(torus(0.34, 0.024, 28, 4), c, "satin", m)
    p.add(torus(0.355, 0.012, 28, 3), GOLD, "gold", m)
    p.add(disc(0.335, 24), CANVAS, "fabric", m)
    for sx in (-1, 1):
        p.add(cyl(0.016, 0.1, 5), GOLD, "gold", T(sx * 0.42, 0.02, 0.86) @ R("Y", -90 * sx))
    rng = random.Random(77)
    for (x, y, col, r) in ((-0.1, 0.06, ROSE, 0.07), (0.12, 0.1, LILAC, 0.055), (0.02, -0.12, BLUSH, 0.06),
                           (-0.17, -0.1, BUTTER, 0.04), (0.18, -0.06, PERI, 0.045)):
        centre = m @ Vector((x, y, 0.012))
        bloom(p, tuple(centre), r, col, 2, 5, rng, tilt=R("X", -72))
    for (x, y) in ((0.0, 0.0), (-0.05, 0.15), (0.08, -0.02)):
        centre = m @ Vector((x, y, 0.01))
        p.add(sphere(1.0, 6, 4), MINT, "fabric", T(*centre) @ R("X", -72) @ S(0.05, 0.02, 0.006))
    # thread basket at the foot
    p.add(lathe([(0.0, 0.0), (0.12, 0.0), (0.15, 0.1), (0.14, 0.11)], 10, cap_top=False), lighter(c, 0.2), "fabric", T(0.18, 0.1, 0.05))
    for k, col in enumerate(WOOL[:4]):
        a = math.radians(90 * k + 20)
        p.add(ico(0.045, 1), col, "fabric", T(0.18 + 0.06 * math.cos(a), 0.1 + 0.06 * math.sin(a), 0.15))


def dollhouse(p, size, c):
    p.add(box(1.4, 0.6, 0.08, bevel=0.02), OAK, "satin", T(0, 0, 0.04))
    p.add(box(1.0, 0.46, 0.72, bevel=0.015), c, "satin", T(0, 0, 0.44))
    p.add(box(1.04, 0.5, 0.04, bevel=0.01), PEARL, "pearl", T(0, 0, 0.45))       # string course
    p.add(box(1.04, 0.5, 0.05, bevel=0.01), PEARL, "pearl", T(0, 0, 0.81))
    # hipped slate roof with a gold ridge and dormers
    p.add(lathe([(0.64, 0), (0, 0.36)], 4, cap_top=False), SLATE, "satin", T(0, 0, 0.83) @ S(1.25, 0.6, 1) @ R("Z", 45))
    p.add(box(0.4, 0.02, 0.02), GOLD, "gold", T(0, 0, 1.18))
    for x in (-0.22, 0.22):
        p.add(box(0.14, 0.1, 0.14, bevel=0.01), PEARL, "pearl", T(x, 0.18, 0.95))
        p.add(lathe([(0.11, 0), (0, 0.09)], 4), SLATE, "satin", T(x, 0.18, 1.02) @ R("Z", 45))
        p.add(box(0.07, 0.02, 0.08), LIT_WINDOW, "glow", T(x, 0.235, 0.95))
    # two round towers with conical caps and finials
    for sx in (-1, 1):
        x = sx * 0.58
        p.add(cyl(0.13, 0.95, 12), PEARL, "pearl", T(x, 0.05, 0.08))
        p.add(lathe([(0.16, 0), (0.05, 0.3), (0, 0.42)], 12), SLATE, "satin", T(x, 0.05, 1.03))
        p.add(sphere(0.025, 8, 5), GOLD, "gold", T(x, 0.05, 1.47))
        p.add(lathe([(0.008, 0), (0, 0.08)], 5), GOLD, "gold", T(x, 0.05, 1.48))
        for z in (0.3, 0.62):
            p.add(box(0.07, 0.02, 0.12), LIT_WINDOW, "glow", T(x, 0.175, z))
    # lit windows in two storeys, white frames, a rose door and a balcony
    for row, z in enumerate((0.27, 0.63)):
        for x in (-0.33, -0.11, 0.11, 0.33):
            if row == 0 and abs(x) < 0.2:
                continue
            p.add(box(0.12, 0.02, 0.18, bevel=0.005), WHITE, "satin", T(x, 0.235, z))
            p.add(box(0.09, 0.03, 0.15), LIT_WINDOW, "glow", T(x, 0.24, z))
    p.add(box(0.18, 0.02, 0.28, bevel=0.01), ROSE, "satin", T(0, 0.235, 0.22))
    p.add(sphere(0.09, 10, 6), ROSE, "satin", T(0, 0.235, 0.36) @ S(1, 0.12, 0.7))
    knob(p, 0.05, 0.25, 0.2, 0.014)
    p.add(box(0.36, 0.08, 0.02), GOLD, "gold", T(0, 0.27, 0.48))
    for k in range(7):
        p.add(cyl(0.005, 0.06, 4), GOLD, "gold", T(-0.15 + k * 0.05, 0.305, 0.48))
    rng = random.Random(9)
    for x in (-0.16, 0.16):
        bloom(p, (x, 0.28, 0.12), 0.04, ROSE if x < 0 else BLUSH, 2, 5, rng)
        p.add(ico(0.045, 1), MINT, "leaf", T(x, 0.27, 0.1))


def loom_upright(p, size, c):
    for sx in (-1, 1):
        x = sx * 0.9
        p.add(box(0.1, 0.1, 1.95, bevel=0.02), c, "satin", T(x, -0.2, 0.975))
        p.add(box(0.1, 0.8, 0.08, bevel=0.02), c, "satin", T(x, 0.05, 0.04))
        p.add(box(0.06, 0.06, 0.5, bevel=0.01), c, "satin", T(x, 0.25, 0.25) @ R("X", -40))
        p.add(sphere(0.05, 8, 5), GOLD, "gold", T(x, -0.2, 1.97))
    for z in (0.35, 1.85):
        p.add(cyl(0.05, 1.9, 10), darker(c, 0.1), "satin", T(-0.95, -0.2, z) @ R("Y", 90))
    p.add(box(1.7, 0.04, 0.06, bevel=0.01), c, "satin", T(0, -0.15, 1.3))            # heddle bar
    for k in range(34):
        x = -0.82 + k * 1.64 / 33
        p.add(box(0.006, 0.006, 1.0), CREAM, "fabric", T(x, -0.2, 0.85))
    bands = [ROSE, BLUSH, BUTTER, MINT, PERI, LILAC, ROSE, BLUSH]
    z = 0.4
    for k, col in enumerate(bands):
        h = 0.07 if k % 2 else 0.05
        p.add(box(1.66, 0.025, h), col, "fabric", T(0, -0.2, z + h / 2))
        z += h
    rng = random.Random(55)
    for x in (-0.5, 0.0, 0.5):
        bloom(p, (x, -0.18, 0.6), 0.05, PEARL, 2, 5, rng, tilt=R("X", -90))
    p.add(box(0.3, 0.05, 0.04, bevel=0.01), OAK_DARK, "satin", T(0.2, -0.17, z + 0.04))  # shuttle
    p.add(cushion(1.0, 0.32, 0.06, 0.3), BLUSH, "fabric", T(0, 0.33, 0.48))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(turned_leg(0.45, 0.022), c, "satin", T(sx * 0.42, 0.33 + sy * 0.11, 0.0))
    for k, col in enumerate(WOOL[:3]):
        p.add(ico(0.06, 1), col, "fabric", T(-0.65 + 0.13 * k, 0.33, 0.06))


def telescope_brass(p, size, c):
    head = (0.0, 0.0, 1.28)
    for k in range(3):
        a = math.radians(90 + 120 * k)
        foot = (0.32 * math.cos(a), 0.26 * math.sin(a), 0.0)
        p.add(tube([head, ((head[0] + foot[0]) / 2, (head[1] + foot[1]) / 2, 0.62), foot], [0.025, 0.022, 0.018], 6), OAK, "satin")
        p.add(sphere(0.026, 6, 4), c, "gold", T(*foot))
    p.add(torus(0.12, 0.01, 12, 3), c, "gold", T(0, 0, 0.55))
    p.add(lathe([(0.05, 0), (0.07, 0.06), (0.04, 0.12)], 10), c, "gold", T(*head))
    p.add(box(0.04, 0.12, 0.14, bevel=0.01), c, "gold", T(0, 0, 1.43))
    tilt = T(0, 0, 1.5) @ R("Y", -24)
    sections = [(-0.5, 0.045), (-0.18, 0.06), (0.12, 0.075), (0.42, 0.085)]
    for i, (x0, r) in enumerate(sections):
        length = (sections[i + 1][0] if i + 1 < len(sections) else 0.62) - x0
        p.add(cyl(r, length, 14), c if i % 2 else GOLD_DEEP, "gold", tilt @ T(x0, 0, 0) @ R("Y", 90))
        p.add(torus(r + 0.004, 0.008, 14, 3), GOLD, "gold", tilt @ T(x0, 0, 0) @ R("Y", 90))
    p.add(disc(0.083, 16), SOFT_BLUE, "glass", tilt @ T(0.621, 0, 0) @ R("Y", 90))
    p.add(cyl(0.02, 0.08, 8), c, "gold", tilt @ T(-0.58, 0, 0) @ R("Y", 90))
    p.add(cyl(0.025, 0.22, 8), GOLD_DEEP, "gold", tilt @ T(0.1, 0, 0.11) @ R("Y", 90))           # finder scope
    for x in (0.12, 0.28):
        p.add(box(0.015, 0.015, 0.05), c, "gold", tilt @ T(x, 0, 0.08))
    for k in range(5):   # little gilt stars engraved round the big ring
        a = 2 * math.pi * k / 5
        p.add(lathe([(0.012, 0), (0, 0.01)], 4), PEARL, "glow", tilt @ T(0.3, 0.08 * math.cos(a), 0.08 * math.sin(a)) @ R("Y", 90))


def dumbwaiter(p, size, c):
    p.add(box(0.9, 0.5, 1.3, bevel=0.02), c, "satin", T(0, -0.1, 0.65))
    p.add(box(0.94, 0.56, 0.06, bevel=0.02), PEARL, "pearl", T(0, -0.08, 1.33))
    p.add(box(0.7, 0.04, 0.55), darker(c, 0.35), "matte", T(0, 0.14, 0.75))           # open shaft
    p.add(box(0.66, 0.36, 0.03), lighter(c, 0.15), "satin", T(0, 0.0, 0.52))           # car floor
    p.add(box(0.7, 0.05, 0.3, bevel=0.01), lighter(c, 0.1), "satin", T(0, 0.17, 1.2))  # raised sash
    for sx in (-1, 1):
        p.add(box(0.05, 0.06, 0.62), PEARL, "pearl", T(sx * 0.37, 0.16, 0.78))
    for z in (0.47, 1.04):
        p.add(box(0.78, 0.02, 0.025), GOLD, "gold", T(0, 0.2, z))
    # a tea tray waiting on the car
    p.add(box(0.44, 0.26, 0.015, bevel=0.005), GOLD, "gold", T(0, 0.02, 0.545))
    p.add(lathe([(0.0, 0), (0.06, 0), (0.07, 0.08), (0.04, 0.12), (0.0, 0.13)], 10), PEARL, "pearl", T(-0.1, 0.02, 0.555))
    for x in (0.06, 0.15):
        p.add(lathe([(0, 0), (0.025, 0), (0.035, 0.04), (0.034, 0.045)], 8, cap_top=False), WHITE, "pearl", T(x, 0.05, 0.555))
    rng = random.Random(13)
    bloom(p, (0.12, -0.04, 0.6), 0.03, ROSE, 2, 5, rng)
    # pulley wheel and rope on top, brass call bell at the side
    _wheel(p, (0.18, 0.0, 1.5), 0.12, 6, OAK_DARK)
    for sx in (-1, 1):
        p.add(box(0.03, 0.08, 0.2), OAK_DARK, "satin", T(0.18 + sx * 0.04, 0.0, 1.4))
    p.add(tube([(0.06, 0.06, 1.5), (0.06, 0.08, 1.0), (0.06, 0.1, 0.62)], 0.008, 4), CREAM, "fabric")
    p.add(lathe([(0, 0), (0.05, 0.0), (0.045, 0.03), (0.02, 0.08), (0, 0.09)], 10, cap_bottom=False), GOLD, "gold",
          T(-0.36, 0.17, 1.12))
    p.add(box(0.03, 0.12, 0.03), GOLD, "gold", T(-0.36, 0.13, 1.22))


BUILDERS = {k: v for k, v in dict(globals()).items() if callable(v) and k in {
    "rocking_horse", "toy_wooden_horse", "spinning_wheel", "embroidery_frame", "dollhouse", "loom_upright",
    "telescope_brass", "dumbwaiter"}}
