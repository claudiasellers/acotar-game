"""Set props for the return to the human realm (P7, ch 28-31) and the pass
(P8, ch 32-33). Lane L73. Headless Blender, deterministic, prop_kit contract
(one mesh, finishes in UV.x, front +Y, fitted to its size).

Run:  /opt/bpyenv/bin/python tools/blender/return_pass_props.py [--only id,id] [--sheet DIR]
Out:  art/return_pass/<id>.glb (+ "<id>_lod1") and return_pass_manifest.json

Canon (Keeper, 2026-11-12, from the book): the trunks of gold and "enormous,
raw jewels", the "uncut ruby the size of a duck's egg" and the "little scale"
in Father's office, Elain's "purple-and-white" tulip bulbs in "rich, dark
soil", her "large, floppy hat" and gloves, "the heavy watering cans", the "new
square of earth", Nesta's iron bracelet, the "satchel of food, and supplies";
the old cottage's garden "a wild tangle" and its cracked "circular
windowpane"; the manor's garden doors "completely shattered", "the giant table
was in pieces, the windows smashed, the curtains in shreds", the blood
"splatters ... small puddles and smears down the gouged walls", Alis's "large
satchel", the "two daggers", the "slender cave mouth" in "the hollow between
two hills". [X]: the estate gate, the ball flower stand, the Beddor shell
(the fire is hearsay only), the worn shrine stone. The wreck is fight damage,
not looting, and stays frightening (R3): no pastels on it.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import bmesh  # noqa: E402,I001
from mathutils import Vector  # noqa: E402
import prop_kit as K  # noqa: E402
import upcoming_kit as U  # noqa: E402
from prop_kit import (BLUSH, BUTTER, CREAM, GOLD, IRON, LILAC, MINT, OAK, OAK_DARK, PEARL, PERI, ROSE, STRAW,  # noqa: E402
                      WARM_STONE, R, S, T, box, cyl, lathe, sphere, torus, tube)

OUT = os.path.join(K.ROOT, "art/return_pass")
FRONT = R("X", -90)           # builds made facing +Z turned to face the front (+Y)
FLAT = R("X", 90)             # XZ-plane slabs laid on the floor

TRUNK = (0.55, 0.30, 0.32)
SOIL = (0.28, 0.19, 0.16)
GREEN = K.SAGE_DEEP
RUBY = (0.75, 0.08, 0.20)
JEWELS = [RUBY, (0.12, 0.55, 0.36), (0.16, 0.30, 0.75), (0.52, 0.24, 0.72), (0.85, 0.62, 0.16)]
BLOOD = (0.40, 0.03, 0.05)
BLOOD_DRY = (0.24, 0.03, 0.04)
CHAR = (0.10, 0.09, 0.11)
ASH = (0.36, 0.34, 0.40)
COLD_STONE = (0.30, 0.31, 0.38)
PALE_STONE = (0.72, 0.72, 0.74)
VELVET = (0.52, 0.16, 0.30)
MAHOGANY = (0.46, 0.24, 0.20)
GLASS = (0.74, 0.85, 0.85, 0.42)
STEEL = (0.66, 0.66, 0.76)


def clamp(v):
    return max(0.0, min(1.0, v))


def splinter(length, r, rng):
    return lathe([(0.0, 0.0), (r, length * rng.uniform(0.2, 0.4)), (r * 0.7, length * 0.7), (0.0, length)], 4)


def raw_gem(r, rng):
    bm = K.ico(r, 1)
    for v in bm.verts:
        v.co *= rng.uniform(0.72, 1.18)
    return bm


# ------------------------------------------------------------------ the estate


def _trunk(p, lid_deg, rng):
    """A brass-bound travelling trunk, 1.0 x 0.6 x 0.45 without its lid."""
    w, d, h = 1.0, 0.6, 0.45
    p.add(box(w, d, h, bevel=0.03), TRUNK, "satin", T(0, 0, h / 2),
          shade=lambda co: K.mix(K.darker(TRUNK, 0.2), TRUNK, clamp(0.6 + co.z * 1.4)))
    p.add(box(w - 0.07, d - 0.07, 0.02), K.darker(TRUNK, 0.55), "fabric", T(0, 0, h - 0.004))
    for x in (-0.3, 0.3):
        p.add(box(0.06, d + 0.012, h + 0.006, bevel=0.006), GOLD, "gold", T(x, 0, h / 2))
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (0.03, h - 0.03):
                p.add(sphere(0.04, 6, 4), GOLD, "gold", T(sx * (w / 2 - 0.02), sy * (d / 2 - 0.02), z) @ S(1, 1, 0.8))
        p.add(torus(0.05, 0.01, 10, 5), GOLD, "gold", T(sx * (w / 2 + 0.012), 0, h * 0.62) @ R("Y", 90) @ S(1, 1.6, 1))
    # the lid: a domed section swung up on its back hinge by lid_deg
    hinge = T(0, -d / 2, h) @ R("X", lid_deg)
    dome = [(d * i / 8, 0.03 + 0.15 * math.sin(math.pi * i / 8)) for i in range(9)]
    p.add(U.slab(dome + [(d, 0.0), (0.0, 0.0)], w), TRUNK, "satin", hinge @ R("Z", 90),
          shade=lambda co: K.mix(K.darker(TRUNK, 0.2), TRUNK, clamp(0.5 + co.z * 4)))
    p.add(U.slab([(0.02, 0.0), (d - 0.02, 0.0), (d - 0.02, -0.012), (0.02, -0.012)], w - 0.04), K.darker(TRUNK, 0.5), "fabric", hinge @ R("Z", 90))
    band = [(d * i / 8, 0.036 + 0.152 * math.sin(math.pi * i / 8)) for i in range(9)]
    for x in (-0.3, 0.3):
        p.add(U.slab(band + [(d + 0.004, -0.004), (-0.004, -0.004)], 0.06), GOLD, "gold", hinge @ T(x, 0, 0) @ R("Z", 90))
    p.add(box(0.1, 0.02, 0.09, bevel=0.01), GOLD, "gold", T(0, d / 2 + 0.008, h - 0.06))
    return w, d, h


def trunk_gold(p):
    """[C] one of her trunks: thrown open on a heap of gold and enormous raw jewels."""
    rng = random.Random(7321)
    w, d, h = _trunk(p, 108, rng)
    p.add(sphere(0.3, 14, 8), GOLD, "gold", T(0, 0, h - 0.03) @ S(1.5, 0.86, 0.42),
          shade=lambda co: K.mix(K.GOLD_DEEP, GOLD, clamp(co.z / 0.3 + 0.3)))
    for k in range(24):
        a, rr = rng.uniform(0, 6.283), rng.uniform(0.0, 0.92)
        x, y = math.cos(a) * rr * 0.42, math.sin(a) * rr * 0.23
        z = h - 0.03 + 0.126 * math.sqrt(max(0.0, 1 - rr * rr)) + 0.004
        p.add(lathe([(0.0, 0.0), (0.019, 0.0), (0.021, 0.002), (0.019, 0.004), (0.0, 0.004)], 8), GOLD if k % 3 else K.GOLD_DEEP, "gold",
              T(x, y, z) @ R("X", rng.uniform(-40, 40)) @ R("Y", rng.uniform(-40, 40)))
    for k in range(9):
        a, rr = rng.uniform(0, 6.283), rng.uniform(0.1, 0.8)
        x, y = math.cos(a) * rr * 0.4, math.sin(a) * rr * 0.2
        z = h + 0.11 * math.sqrt(max(0.0, 1 - rr * rr))
        p.add(raw_gem(rng.uniform(0.035, 0.06), rng), JEWELS[k % 5], "pearl", T(x, y, z) @ R("Z", rng.uniform(0, 360)), sharp_deg=12.0)
    for k in range(5):
        x, y = rng.uniform(-0.2, 0.5), d / 2 + rng.uniform(0.08, 0.3)
        p.add(lathe([(0.0, 0.0), (0.019, 0.0), (0.021, 0.002), (0.019, 0.004), (0.0, 0.004)], 8), GOLD, "gold", T(x, y, 0.0))
    p.add(raw_gem(0.05, rng), JEWELS[1], "pearl", T(0.56, d / 2 + 0.16, 0.04), sharp_deg=12.0)


def trunk_gowns(p):
    """[C] a trunk of clothes: gowns folded and spilling over its edge, a
    tiara and a rope of pearls on top (the dress-up haul)."""
    rng = random.Random(7322)
    w, d, h = _trunk(p, 100, rng)
    cols = [ROSE, LILAC, MINT, BUTTER, PERI, BLUSH]
    for k in range(5):
        p.add(K.cushion(rng.uniform(0.36, 0.44), rng.uniform(0.4, 0.48), 0.06, puff=0.5), cols[k], "fabric",
              T(-0.22 + (k % 2) * 0.44 + rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), h - 0.02 + (k // 2) * 0.05) @ R("Z", rng.uniform(-8, 8)))
    for x, col, wd, ln in ((-0.2, ROSE, 0.34, 0.5), (0.16, LILAC, 0.3, 0.36), (0.36, PEARL, 0.12, 0.44)):
        path = [(-0.2, h + 0.06), (0.1, h + 0.085), (d / 2 + 0.02, h + 0.05), (d / 2 + 0.06, h - 0.1),
                (d / 2 + 0.07 + 0.02 * math.sin(x * 9), h - ln * 0.6), (d / 2 + 0.11, h - ln)]
        p.add(U.ribbon(path, wd, 0.006), col, "fabric" if col != PEARL else "pearl", T(x, 0, 0) @ R("Z", 90),
              shade=(lambda c: (lambda co: K.mix(c, K.darker(c, 0.2), 0.5 + 0.5 * math.sin(co.y * 60.0))))(col))
    # tiara
    m = T(0.02, -0.02, h + 0.2)
    p.add(torus(0.075, 0.005, 16, 5), GOLD, "gold", m)
    for k in range(5):
        a = math.radians(50 + k * 20)
        hgt = 0.05 if k == 2 else 0.035 if k in (1, 3) else 0.024
        p.add(lathe([(0.006, 0.0), (0.003, hgt * 0.7), (0.0, hgt)], 5), GOLD, "gold", m @ T(math.cos(a) * 0.075, math.sin(a) * 0.075, 0))
        p.add(sphere(0.008, 6, 4), PEARL if k != 2 else ROSE, "pearl", m @ T(math.cos(a) * 0.075, math.sin(a) * 0.075, hgt + 0.004))
    for k in range(16):
        a = k / 16 * math.pi * 1.4
        p.add(sphere(0.011, 6, 4), PEARL, "pearl", T(0.3 + math.cos(a) * 0.09, 0.05 + math.sin(a) * 0.12, h + 0.105 + 0.01 * math.sin(a * 2)))


def raw_ruby(p):
    """[C] the "uncut ruby the size of a duck's egg" on Father's desk: a raw
    corundum crystal as it comes out of the ground, a six-sided barrel with
    flat ends and growth lines round its faces. Never a cut stone."""
    prof = [(0.0, 0.0), (0.0135, 0.0)]
    body = [(0.0185, 0.007), (0.0215, 0.016), (0.023, 0.026), (0.0232, 0.036), (0.0218, 0.046), (0.0192, 0.055), (0.015, 0.062)]
    for k, (r, z) in enumerate(body):                 # growth striations: a fine step at every ring
        prof.append((r, z))
        if k < len(body) - 1:
            prof.append((r - 0.0011, z + 0.0012))
    prof += [(0.0105, 0.0645), (0.0, 0.0645)]
    deep, bright = K.darker(RUBY, 0.5), (0.85, 0.22, 0.34)

    def shade(co):
        r = math.hypot(co.x, co.y)
        a = math.atan2(co.y, co.x)
        edge = abs(math.cos(a * 3.0))                 # 1 on the six edges, 0 at a face's middle
        return K.mix(K.mix(deep, RUBY, clamp(r / 0.02)), bright, 0.55 * edge * clamp(co.z / 0.05 + 0.2))

    p.add(lathe(prof, 6), RUBY, "pearl", sharp_deg=12.0, shade=shade)


def gold_scale(p):
    """[C] Father's little scale: a brass balance with two hanging pans."""
    p.add(lathe([(0.0, 0.0), (0.07, 0.0), (0.075, 0.008), (0.05, 0.016), (0.014, 0.024), (0.009, 0.05), (0.013, 0.09), (0.007, 0.13),
                 (0.007, 0.25), (0.012, 0.262), (0.0, 0.275)], 12), GOLD, "gold")
    beam = [(-0.13, 0, 0.243), (-0.07, 0, 0.252), (0, 0, 0.256), (0.07, 0, 0.25), (0.13, 0, 0.238)]
    p.add(tube(beam, [0.003, 0.0045, 0.006, 0.0045, 0.003], 6), GOLD, "gold")
    for sx, drop in ((-1, 0.0), (1, 0.012)):
        top = Vector((sx * 0.13, 0, 0.24 - (0.003 if sx < 0 else 0.0)))
        zc = 0.1 - drop
        for k in range(3):
            a = 2 * math.pi * k / 3
            p.add(tube([top, Vector((sx * 0.13 + math.cos(a) * 0.045, math.sin(a) * 0.045, zc + 0.012))], 0.0012, 3), K.GOLD_DEEP, "gold")
        p.add(lathe([(0.0, 0.0), (0.03, 0.002), (0.046, 0.012), (0.048, 0.014), (0.044, 0.014), (0.028, 0.005), (0.0, 0.004)], 12), GOLD, "gold",
              T(sx * 0.13, 0, zc))
    rng = random.Random(7324)
    p.add(raw_gem(0.014, rng), RUBY, "pearl", T(0.13, 0, 0.106), sharp_deg=12.0)
    for k in range(3):
        p.add(lathe([(0.008, 0.0), (0.008, 0.012 + k * 0.004), (0.004, 0.014 + k * 0.004), (0.0, 0.02 + k * 0.004)], 6), K.GOLD_DEEP, "gold",
              T(-0.14 + k * 0.012, 0.004 * k, 0.106))


def tulip_cup(color, stripe=None):
    def shade(co):
        if stripe is None:
            return K.mix(K.darker(color, 0.12), color, clamp(co.z / 0.05))
        a = math.atan2(co.y, co.x)
        return color if math.sin(a * 3) > 0.1 else stripe
    return shade


def _tulip(p, x, y, z, hgt, color, stripe, rng):
    lean = Vector((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), 0))
    top = Vector((x, y, z + hgt)) + lean
    p.add(tube([(x, y, z), (x + lean.x * 0.3, y + lean.y * 0.3, z + hgt * 0.5), top], 0.006, 4), GREEN, "leaf")
    for k in range(2):
        p.add(K.leaf(hgt * 0.75, 0.05), K.SAGE, "leaf", T(x, y, z + 0.01) @ R("Z", rng.uniform(0, 360) + 180 * k) @ R("Y", -66))
    p.add(lathe([(0.004, 0.0), (0.03, 0.012), (0.036, 0.035), (0.03, 0.062), (0.019, 0.078)], 6, True, False), color, "fabric", T(*top),
          shade=tulip_cup(color, stripe), sharp_deg=80.0)
    p.add(K.disc(0.02, 6, 0.06), K.darker(color, 0.4), "fabric", T(*top))


PURPLE = (0.50, 0.28, 0.70)
TULIP_WHITE = (0.85, 0.84, 0.82)


def tulip_bed(p):
    """[C] Elain's bed beneath the window: purple-and-white tulips in rich, dark soil."""
    rng = random.Random(7325)
    p.add(K.cushion(1.7, 1.7, 0.16, puff=0.5, seg=3), SOIL, "matte", T(0, 0, 0.05),
          shade=lambda co: K.mix(K.darker(SOIL, 0.25), SOIL, 0.5 + 0.5 * math.sin(co.x * 23) * math.cos(co.y * 19)))
    for sx, sy, ln, rot in ((0, -0.88, 1.8, 0), (0, 0.88, 1.8, 0), (-0.88, 0, 1.8, 90), (0.88, 0, 1.8, 90)):
        p.add(box(ln, 0.05, 0.12, bevel=0.012), OAK, "satin", T(sx, sy, 0.06) @ R("Z", rot))
    kinds = [(PURPLE, None), (TULIP_WHITE, None), (TULIP_WHITE, PURPLE), (PURPLE, TULIP_WHITE)]
    for i in range(5):
        for j in range(5):
            col, st = kinds[(i * 2 + j) % 4]
            _tulip(p, -0.62 + i * 0.31 + rng.uniform(-0.04, 0.04), -0.62 + j * 0.31 + rng.uniform(-0.04, 0.04), 0.12,
                   rng.uniform(0.3, 0.42), col, st, rng)


def dug_plot(p):
    """[C] the new square of earth Feyre digs: turned clods, the spade left
    standing in it, bulbs set out along one furrow."""
    rng = random.Random(7326)
    p.add(K.cushion(1.5, 1.5, 0.1, puff=0.4, seg=3), SOIL, "matte", T(0, 0, 0.03))
    for k in range(22):
        p.add(U.rock(rng.uniform(0.04, 0.09), 1, k * 1.7, 0.25), K.mix(SOIL, K.darker(SOIL, 0.3), rng.random()), "matte",
              T(rng.uniform(-0.65, 0.65), rng.uniform(-0.65, 0.65), 0.08) @ S(1, 1, 0.6))
    for k in range(6):
        _bulb(p, T(-0.5 + k * 0.2, -0.3, 0.1), rng, sprout=k % 2 == 0)
    m = T(0.35, 0.3, 0.02) @ R("X", -10) @ R("Y", 6)
    p.add(U.slab([(-0.1, 0.0), (0.1, 0.0), (0.105, 0.2), (0.07, 0.3), (-0.07, 0.3), (-0.105, 0.2)], 0.008), IRON, "mirror", m @ T(0, 0, -0.1))
    p.add(lathe([(0.02, 0.18), (0.017, 0.3), (0.017, 0.86), (0.02, 0.88)], 8), OAK, "satin", m)
    grip = [(-0.07, 0, 0.88), (-0.075, 0, 0.98), (0.0, 0, 1.0), (0.075, 0, 0.98), (0.07, 0, 0.88)]
    p.add(tube(grip, 0.014, 6), OAK, "satin", m)
    p.add(tube([(-0.07, 0, 0.885), (0.07, 0, 0.885)], 0.014, 6), OAK, "satin", m)


def _bulb(p, m, rng, sprout=False):
    onion = (0.70, 0.50, 0.36)
    p.add(lathe([(0.0, 0.0), (0.022, 0.006), (0.03, 0.026), (0.02, 0.05), (0.006, 0.066), (0.0, 0.074)], 7), onion, "satin",
          m @ R("X", rng.uniform(-25, 25)) @ R("Y", rng.uniform(-25, 25)),
          shade=lambda co: K.mix(onion, (0.85, 0.80, 0.68), clamp(co.z / 0.07 - 0.35)))
    if sprout:
        p.add(lathe([(0.005, 0.06), (0.004, 0.09), (0.0, 0.11)], 4), K.SAGE, "leaf", m)


def bulb_crate(p):
    """[C] the tulip bulbs "from the continent": a slatted crate of them in straw."""
    rng = random.Random(7327)
    w, d, h = 0.56, 0.4, 0.26
    for sy in (-1, 1):
        for k in range(3):
            p.add(box(w, 0.016, 0.066, bevel=0.004), OAK, "satin", T(0, sy * d / 2, 0.04 + k * 0.088))
    for sx in (-1, 1):
        for k in range(3):
            p.add(box(0.016, d, 0.066, bevel=0.004), K.lighter(OAK, 0.1), "satin", T(sx * w / 2, 0, 0.04 + k * 0.088))
        for sy in (-1, 1):
            p.add(box(0.035, 0.035, h, bevel=0.004), OAK_DARK, "satin", T(sx * (w / 2 - 0.02), sy * (d / 2 - 0.02), h / 2))
    p.add(box(w, d, 0.014), OAK, "satin", T(0, 0, 0.007))
    p.add(K.cushion(w - 0.05, d - 0.05, 0.14, puff=0.5), STRAW, "fabric", T(0, 0, 0.13),
          shade=lambda co: K.mix(K.darker(STRAW, 0.25), STRAW, 0.5 + 0.5 * math.sin(co.x * 90 + co.y * 70)))
    for k in range(13):
        _bulb(p, T(rng.uniform(-0.2, 0.2), rng.uniform(-0.13, 0.13), 0.19 + rng.uniform(0, 0.02)), rng, sprout=k % 4 == 0)
    _bulb(p, T(0.36, 0.16, 0.012) @ R("X", 80), rng)
    _bulb(p, T(0.42, 0.05, 0.012) @ R("Y", 75), rng, sprout=True)
    p.add(box(0.16, 0.004, 0.09), CREAM, "matte", T(0, d / 2 + 0.01, 0.13) @ R("Y", -4))
    p.add(box(0.1, 0.005, 0.012), PURPLE, "matte", T(0, d / 2 + 0.012, 0.14) @ R("Y", -4))


def watering_can(p):
    """[C] one of "the heavy watering cans": mint enamel, gilt rims, a rose on its side."""
    rng = random.Random(7328)
    enamel = K.lighter(MINT, 0.05)
    p.add(lathe([(0.0, 0.0), (0.125, 0.0), (0.135, 0.012), (0.13, 0.26), (0.118, 0.3), (0.1, 0.31)], 16, True, False), enamel, "pearl")
    p.add(K.disc(0.1, 16, 0.3), (0.45, 0.62, 0.70), "water")
    for z, rr in ((0.012, 0.136), (0.3, 0.119)):
        p.add(torus(rr, 0.006, 16, 5), GOLD, "gold", T(0, 0, z))
    spout = [(0.12, 0, 0.07), (0.2, 0, 0.14), (0.3, 0, 0.25), (0.38, 0, 0.34)]
    p.add(tube(spout, [0.028, 0.022, 0.018, 0.016], 8), enamel, "pearl")
    p.add(lathe([(0.016, 0.0), (0.05, 0.035), (0.052, 0.04), (0.0, 0.047)], 10), GOLD, "gold", T(0.375, 0, 0.335) @ R("Y", 48))
    for k in range(7):
        a = 2 * math.pi * k / 7
        p.add(sphere(0.005, 5, 3), K.GOLD_DEEP, "gold", T(0.375, 0, 0.335) @ R("Y", 48) @ T(math.cos(a) * 0.03, math.sin(a) * 0.03, 0.046))
    p.add(tube([(-0.11, 0, 0.3), (-0.08, 0, 0.4), (0.0, 0, 0.43), (0.08, 0, 0.4), (0.11, 0, 0.3)], 0.011, 6), GOLD, "gold")
    p.add(tube([(-0.125, 0, 0.26), (-0.2, 0, 0.24), (-0.22, 0, 0.14), (-0.13, 0, 0.07)], 0.011, 6), GOLD, "gold")
    K.soft_rose(p, T(0, 0.134, 0.16) @ FRONT, 0.04, ROSE, "pearl", rng)
    for a in (150, 30, 270):
        p.add(K.leaf(0.05, 0.022), K.SAGE, "leaf", T(0, 0.133, 0.16) @ FRONT @ R("Z", a) @ T(0.03, 0, 0.002))


def garden_trug(p):
    """[C] Elain's gardening things: her large, floppy hat, her gloves, and a
    trowel, in a wooden trug."""
    rng = random.Random(7329)
    trug = lathe([(0.0, 0.0), (0.16, 0.006), (0.25, 0.07), (0.27, 0.12), (0.255, 0.12), (0.235, 0.075), (0.15, 0.02), (0.0, 0.018)], 14)
    p.add(trug, OAK, "satin", S(1.25, 0.8, 1), shade=U.grain(OAK, 0.14, 50.0))
    arc = [(0, -0.2 * math.cos(math.pi * i / 10), 0.11 + 0.26 * math.sin(math.pi * i / 10)) for i in range(11)]
    p.add(tube(arc, 0.011, 5), OAK_DARK, "satin", S(2.2, 1, 1))
    hat = lathe([(0.0, 0.11), (0.06, 0.105), (0.085, 0.07), (0.09, 0.02), (0.12, 0.008), (0.2, 0.0), (0.26, -0.004), (0.262, 0.004),
                 (0.2, 0.01), (0.12, 0.018)], 16, False, False)
    for v in hat.verts:
        rr = math.hypot(v.co.x, v.co.y)
        if rr > 0.1:
            v.co.z += (rr - 0.1) * 0.5 * math.sin(math.atan2(v.co.y, v.co.x) * 3 + 0.6) - (rr - 0.1) * 0.18
    hm = T(-0.06, 0.0, 0.13) @ R("X", 12) @ R("Y", -10)
    p.add(hat, STRAW, "fabric", hm, shade=lambda co: K.mix(K.darker(STRAW, 0.18), STRAW, 0.5 + 0.5 * math.sin(math.hypot(co.x, co.y) * 400)))
    p.add(lathe([(0.091, 0.02), (0.093, 0.035), (0.088, 0.05)], 16, False, False), LILAC, "fabric", hm)
    for side in (1, -1):
        p.add(K.round_petal(0.06, 0.04, cup=0.4, curl=0.2), LILAC, "fabric", hm @ T(0, -0.092, 0.035) @ R("Z", 90 - side * 90) @ R("X", -80))
    for k, (x, y, rz) in enumerate(((0.2, 0.06, 20), (0.22, -0.05, -15))):
        gm = T(x, y, 0.1 + k * 0.012) @ R("Z", rz) @ R("Y", -8)
        p.add(K.cushion(0.15, 0.085, 0.03, puff=0.6), BLUSH, "fabric", gm)
        p.add(K.cushion(0.06, 0.03, 0.025, puff=0.6), BLUSH, "fabric", gm @ T(0.0, 0.055, 0) @ R("Z", 40))
        p.add(lathe([(0.046, 0.0), (0.05, 0.02)], 8, False, False), ROSE, "fabric", gm @ T(-0.08, 0, 0) @ R("Y", -90) @ S(1, 0.9, 0.45))
    tm = T(0.02, -0.12, 0.1) @ R("Z", 25) @ R("Y", 90)
    p.add(lathe([(0.014, 0.0), (0.017, 0.05), (0.012, 0.1)], 6), ROSE, "satin", tm)
    p.add(U.slab([(-0.028, 0.0), (0.028, 0.0), (0.03, 0.08), (0.0, 0.13), (-0.03, 0.08)], 0.004), IRON, "mirror", tm @ T(0, 0, 0.1))


def iron_bracelet(p):
    """[C] the iron bracelet on Nesta's wrist (iron does nothing to them)."""
    pts = [(math.cos(2 * math.pi * i / 20) * 0.031, math.sin(2 * math.pi * i / 20) * 0.027, 0.0) for i in range(20)]
    p.add(tube(pts, 0.0042, 6, closed=True), IRON, "mirror", T(0, 0, 0.0065) @ S(1, 1, 1.5))
    for k in range(10):
        a = 2 * math.pi * k / 10
        p.add(sphere(0.0022, 5, 3), K.darker(IRON, 0.25), "satin", T(math.cos(a) * 0.0352, math.sin(a) * 0.031, 0.0065))
    p.add(lathe([(0.006, 0.0), (0.007, 0.004), (0.006, 0.012)], 6), K.darker(IRON, 0.2), "mirror", T(0.031, -0.006, 0.0065) @ R("X", -90))


def ball_flower_stand(p):
    """[X] ballroom dressing for the ball in her honour: a gilt stand under a
    great urn of roses and peonies, ribbons trailing."""
    rng = random.Random(7331)
    p.add(lathe([(0.0, 0.0), (0.22, 0.0), (0.23, 0.03), (0.12, 0.07), (0.05, 0.12), (0.04, 0.5), (0.07, 0.56), (0.04, 0.62), (0.04, 0.95),
                 (0.09, 1.0), (0.18, 1.02), (0.19, 1.05), (0.0, 1.05)], 14), GOLD, "gold")
    p.add(lathe([(0.07, 1.05), (0.16, 1.1), (0.2, 1.22), (0.17, 1.32), (0.2, 1.36), (0.21, 1.37), (0.15, 1.33)], 14, False, False), PEARL, "pearl")
    p.add(sphere(0.24, 10, 6), K.SAGE_DEEP, "leaf", T(0, 0, 1.52) @ S(1, 1, 0.85))
    cols = [ROSE, BLUSH, LILAC, BUTTER, PEARL, ROSE, PERI, BLUSH, ROSE, LILAC, BLUSH, BUTTER, ROSE, PEARL, BLUSH, LILAC]
    for k, col in enumerate(cols):
        a = 2.4 * k
        el = math.radians(86 - (k / len(cols)) * 96)
        d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
        m = T(*(Vector((0, 0, 1.52)) + d * 0.2)) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        if k % 3 == 0:
            K.layered_rose(p, m, 0.14, col, "fabric", rng, cupped=True)
        else:
            K.soft_rose(p, m, 0.13, col, "fabric", rng, petals=4)
    for k in range(10):
        a = 0.63 * k
        p.add(K.leaf(0.2, 0.08), K.SAGE_DEEP, "leaf", T(0, 0, 1.42) @ R("Z", math.degrees(a)) @ T(0.2, 0, 0) @ R("Y", 25))
    for k, col in enumerate((ROSE, BUTTER, LILAC)):
        path = [(0.19, 1.36), (0.27, 1.25), (0.25 + 0.03 * k, 0.95), (0.3, 0.7 - 0.1 * k), (0.27, 0.45 - 0.1 * k)]
        p.add(U.ribbon(path, 0.04), col, "fabric", R("Z", 30 + 120 * k))


def estate_gate(p):
    """[X] the Archeron estate's gate: two capped stone piers and a pair of
    wrought-iron leaves under a scrolled overthrow, tipped in gilt."""
    rng = random.Random(7332)
    stone = K.mix(WARM_STONE, PEARL, 0.3)
    iron = (0.20, 0.20, 0.26)
    for sx in (-1, 1):
        x = sx * 2.1
        p.add(box(0.7, 0.7, 0.3, bevel=0.03), K.darker(stone, 0.1), "matte", T(x, 0, 0.15))
        for k in range(5):
            p.add(box(0.56, 0.56, 0.47, bevel=0.025), K.mix(stone, K.darker(stone, 0.12), rng.random()), "matte", T(x, 0, 0.54 + k * 0.48))
        p.add(box(0.76, 0.76, 0.12, bevel=0.03), stone, "matte", T(x, 0, 2.76))
        p.add(lathe([(0.2, 2.82), (0.12, 2.9), (0.2, 3.02), (0.22, 3.14), (0.14, 3.28), (0.0, 3.32)], 12), stone, "satin", T(x, 0, 0))
        # one leaf, hinged at the pier
        hx = sx * 1.78
        for k in range(8):
            bx = hx - sx * (0.1 + k * 0.23)
            top = 2.05 + 0.4 * (k / 7)
            p.add(tube([(bx, 0, 0.14), (bx, 0, top)], 0.014, 5), iron, "satin")
            p.add(lathe([(0.016, 0.0), (0.03, 0.05), (0.0, 0.17)], 5), GOLD, "gold", T(bx, 0, top))
        for z in (0.2, 1.1, 1.9):
            p.add(tube([(hx, 0, z), (hx - sx * 1.74, 0, z + (0.09 if z > 1.5 else 0))], 0.02, 5), iron, "satin")
        p.add(tube([(hx, 0, 0.1), (hx, 0, 2.2)], 0.032, 6), iron, "satin")
        for k in range(3):
            p.add(K.scroll(0.15, 1.4, 9, 0.014), iron, "satin", T(hx - sx * (0.34 + k * 0.5), 0, 1.5) @ S(sx, 1, 1))
        p.add(K.scroll(0.2, 1.5, 9, 0.018), iron, "satin", T(sx * 0.42, 0, 2.86) @ S(-sx, 1, 1))
    arch = [(-1.78 + 3.56 * i / 14, 0, 2.5 + 0.55 * math.sin(math.pi * i / 14)) for i in range(15)]
    p.add(tube(arch, 0.026, 6), iron, "satin")
    K.layered_rose(p, T(0, 0.03, 3.12) @ FRONT, 0.13, GOLD, "gold", rng, cupped=True)
    for a in (160, 20):
        p.add(K.leaf(0.26, 0.1), GOLD, "gold", T(0, 0.02, 3.12) @ FRONT @ R("Z", a) @ T(0.08, 0, 0))


def supply_satchel(p):
    """[C] what Elain has ready: "a satchel of food, and supplies" (saddle
    pack, bedroll, a waterskin, bread and apples under the flap)."""
    rng = random.Random(7333)
    leather = (0.56, 0.36, 0.28)
    p.add(K.cushion(0.5, 0.2, 0.34, puff=0.5, seg=3), leather, "fabric", T(0, 0, 0.17))
    flap = [(-0.1, 0.34), (0.0, 0.365), (0.1, 0.35), (0.125, 0.25), (0.13, 0.14)]
    p.add(U.ribbon(flap, 0.5, 0.012), K.darker(leather, 0.15), "fabric", R("Z", 90))
    for x in (-0.14, 0.14):
        p.add(U.ribbon([(0.134, 0.3), (0.142, 0.08)], 0.035, 0.006), K.darker(leather, 0.4), "fabric", T(x, 0, 0) @ R("Z", 90))
        p.add(torus(0.02, 0.004, 8, 4), GOLD, "gold", T(x, 0.145, 0.15) @ R("X", 90) @ S(1, 1.3, 1))
    p.add(lathe([(0.0, 0.0), (0.075, 0.004), (0.08, 0.02), (0.08, 0.52), (0.075, 0.536), (0.0, 0.54)], 12), PERI, "fabric",
          T(-0.27, 0, 0.42) @ R("Y", 90), shade=lambda co: K.mix(PERI, K.darker(PERI, 0.2), 0.5 + 0.5 * math.sin(co.z * 70)))
    for x in (-0.15, 0.15):
        p.add(torus(0.083, 0.008, 12, 4), K.darker(leather, 0.3), "fabric", T(x, 0, 0.42) @ R("Y", 90))
    p.add(lathe([(0.0, 0.0), (0.05, 0.03), (0.07, 0.1), (0.055, 0.18), (0.02, 0.22), (0.018, 0.25), (0.0, 0.25)], 10), (0.62, 0.45, 0.33), "fabric",
          T(0.28, 0.02, 0.08) @ R("Y", 12) @ S(1, 0.6, 1))
    p.add(sphere(0.09, 10, 6), (0.80, 0.60, 0.36), "matte", T(-0.08, -0.03, 0.335) @ S(1.3, 0.8, 0.6))
    for k in range(2):
        p.add(sphere(0.04, 8, 6), (0.80, 0.22, 0.2), "pearl", T(0.1 + k * 0.08, -0.04, 0.345))


def garden_tangle(p):
    """[C] Elain's old cottage garden gone to "a wild tangle": briars, dead
    stalks and the few flowers that seeded themselves."""
    rng = random.Random(7334)
    briar = (0.42, 0.30, 0.26)
    for k in range(20):
        a = rng.uniform(0, 6.283)
        r0, r1 = rng.uniform(0.1, 0.6), rng.uniform(0.3, 0.8)
        b = a + rng.uniform(1.2, 2.6)
        hgt = rng.uniform(0.4, 0.95)
        pts = [(math.cos(a) * r0, math.sin(a) * r0, 0.0)]
        for u in (0.25, 0.5, 0.75, 1.0):
            aa = a + (b - a) * u
            rr = r0 + (r1 - r0) * u
            pts.append((math.cos(aa) * rr, math.sin(aa) * rr, hgt * math.sin(math.pi * min(u * 1.1, 1.0)) + 0.03))
        p.add(tube(pts, [0.014, 0.012, 0.01, 0.008, 0.005], 4), briar, "matte")
        for u in range(1, 5):
            q = Vector(pts[u])
            for j in range(3):
                col = K.mix(K.SAGE_DEEP, (0.55, 0.50, 0.28), rng.random() * 0.7)
                p.add(K.leaf(rng.uniform(0.12, 0.2), 0.085), col, "leaf", T(*q) @ R("Z", rng.uniform(0, 360)) @ R("Y", rng.uniform(-30, 20)))
    for k in range(12):
        x, y = rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7)
        h = rng.uniform(0.3, 0.75)
        p.add(tube([(x, y, 0), (x + rng.uniform(-0.08, 0.08), y + rng.uniform(-0.08, 0.08), h)], [0.006, 0.003], 3), STRAW, "matte")
        if k % 2:
            K.star_flower(p, (x, y, h), 0.035, [ROSE, BUTTER, LILAC][k % 3], 5, "fabric")
    p.add(K.cushion(1.5, 1.5, 0.08, puff=0.4), K.mix(SOIL, K.SAGE_DEEP, 0.4), "matte", T(0, 0, 0.02))


def cottage_window_cracked(p):
    """[C] the old cottage window: bullseye panes in lead, one of the
    circular windowpanes cracked."""
    rng = random.Random(7335)
    w, h = 0.62, 0.62
    for (sx, sz, ln, rot) in ((0, 0.0, w + 0.08, 0), (0, h, w + 0.08, 0), (-w / 2, h / 2, h + 0.08, 90), (w / 2, h / 2, h + 0.08, 90)):
        p.add(box(ln, 0.07, 0.08, bevel=0.012), (0.45, 0.33, 0.27), "matte", T(sx, 0, sz) @ R("Y", rot))
    lead = (0.26, 0.26, 0.32)
    for i in range(2):
        for j in range(2):
            c = T(-w / 4 + i * w / 2, 0, h / 4 + j * h / 2)
            pane = lathe([(0.0, 0.012), (0.03, 0.004), (0.08, 0.0), (0.128, 0.004)], 14, False, False)
            p.add(pane, GLASS, "glass", c @ FRONT)
            p.add(torus(0.132, 0.01, 14, 4), lead, "satin", c @ R("X", 90))
            if (i, j) == (1, 1):
                for k in range(5):
                    a = 0.5 + k * 1.3
                    pts = [(0.012 * math.cos(a), -0.012, 0.012 * math.sin(a))]
                    for u in (0.4, 0.7, 1.0):
                        aa = a + rng.uniform(-0.25, 0.25)
                        pts.append((0.125 * u * math.cos(aa), -0.008, 0.125 * u * math.sin(aa)))
                    p.add(tube(pts, 0.0016, 3), (0.80, 0.85, 0.85), "satin", c)
    p.add(box(0.02, 0.03, h, bevel=0.004), lead, "satin", T(0, 0, h / 2))
    p.add(box(w, 0.03, 0.02, bevel=0.004), lead, "satin", T(0, 0, h / 2))


def beddor_ruin(p):
    """[X] the Beddor house after the fire (hearsay in the book; the burnt
    shell on its plot is ours): the chimney stack standing over its hearth,
    charred posts and fallen rafters, a drift of ash. No pastels."""
    rng = random.Random(7336)
    soot = (0.20, 0.18, 0.20)
    brick = (0.42, 0.30, 0.28)
    for k in range(12):
        z = k * 0.42
        wdt = 1.7 if k < 4 else 1.1 if k < 9 else 0.9
        c = K.mix(brick, soot, clamp(0.25 + k / 14 + rng.uniform(-0.15, 0.15)))
        p.add(box(wdt + rng.uniform(-0.04, 0.04), 0.8, 0.43, bevel=0.03), c, "matte", T(rng.uniform(-0.02, 0.02), -1.6, z + 0.21))
    p.add(box(0.9, 0.3, 1.0), CHAR, "matte", T(0, -1.3, 0.55))
    p.add(box(1.9, 0.9, 0.14, bevel=0.03), K.darker(brick, 0.3), "matte", T(0, -1.55, 1.75))
    for (x, y, hgt, lean) in ((-2.4, -1.7, 2.6, 6), (2.4, -1.7, 1.5, -9), (-2.4, 1.6, 1.1, 12), (2.4, 1.6, 2.1, -4), (0.2, 1.7, 0.7, 20)):
        post = box(0.24, 0.24, hgt, bevel=0.04)
        for v in post.verts:
            if v.co.z > 0:
                v.co.x *= 0.55
                v.co.y *= 0.6
                v.co.z += rng.uniform(-0.12, 0.12)
        p.add(post, CHAR, "matte", T(x, y, hgt / 2) @ R("Y", lean),
              shade=lambda co: K.mix(CHAR, (0.22, 0.20, 0.26), 0.5 + 0.5 * math.sin(co.z * 40 + co.x * 90)))
    for k in range(6):
        ln = rng.uniform(1.6, 3.6)
        beam = box(ln, 0.18, 0.2, bevel=0.03)
        p.add(beam, K.mix(CHAR, (0.20, 0.17, 0.2), rng.random()), "matte",
              T(rng.uniform(-1.3, 1.3), rng.uniform(-0.8, 1.2), rng.uniform(0.12, 0.5)) @ R("Z", rng.uniform(0, 180)) @ R("Y", rng.uniform(-16, 16)))
    p.add(sphere(1.0, 10, 5), ASH, "matte", T(0.2, 0.1, -0.05) @ S(2.6, 1.9, 0.28),
          shade=lambda co: K.mix(K.darker(ASH, 0.45), ASH, clamp(co.z * 2 + 0.5 + 0.2 * math.sin(co.x * 9 + co.y * 7))))
    for k in range(8):
        p.add(U.rock(rng.uniform(0.12, 0.26), 1, k * 2.3, 0.2), K.mix(brick, soot, rng.uniform(0.4, 0.9)), "matte",
              T(rng.uniform(-2.5, 2.5), rng.uniform(-1.9, 1.9), 0.08), sharp_deg=30.0)
    p.add(box(1.0, 0.1, 0.9, bevel=0.02), K.darker(brick, 0.5), "matte", T(-1.2, 1.75, 0.4) @ R("X", 8))


# ------------------------------------------------------------------ the wrecked manor


def door_shattered(p):
    """[C] "the doors to the garden were completely shattered": one glazed
    leaf hanging off its top hinge, rails snapped, glass in its corners."""
    rng = random.Random(7341)
    white = (0.82, 0.80, 0.78)
    w, h = 1.05, 2.4
    m = T(-w / 2, 0, 0.04) @ R("Z", -28) @ R("Y", 9) @ T(w / 2, 0, 0)
    for sx in (-1, 1):
        p.add(box(0.12, 0.05, h, bevel=0.01), white, "satin", m @ T(sx * (w / 2 - 0.06), 0, h / 2))
    p.add(box(w, 0.05, 0.14, bevel=0.01), white, "satin", m @ T(0, 0, h - 0.07))
    p.add(box(w * 0.42, 0.05, 0.2, bevel=0.01), white, "satin", m @ T(-w * 0.27, 0, 0.1) @ R("Y", -7))
    p.add(box(w * 0.3, 0.05, 0.2, bevel=0.01), white, "satin", m @ T(w * 0.34, 0, 0.16) @ R("Y", 16))
    for k, z in enumerate((0.75, 1.3, 1.85)):
        ln = (0.36, 0.2, 0.44)[k]
        p.add(tube([(-w / 2 + 0.1, 0, z), (-w / 2 + 0.1 + ln, 0.02 * k, z + rng.uniform(-0.05, 0.05))], 0.014, 4), white, "satin", m)
        p.add(tube([(w / 2 - 0.1, 0, z), (w / 2 - 0.1 - ln * 0.6, -0.03, z + rng.uniform(-0.08, 0.08))], 0.014, 4), white, "satin", m)
    p.add(tube([(0, 0, h - 0.14), (0.03, 0.02, h - 0.7)], 0.014, 4), white, "satin", m)
    for (x, z, s, rz) in ((-0.36, 2.12, 0.2, 10), (0.34, 2.1, 0.24, 80), (-0.38, 0.4, 0.17, 200), (0.37, 1.0, 0.14, 130), (-0.37, 1.55, 0.12, 300)):
        p.add(U.shard(rng, s), GLASS, "glass", m @ T(x, 0, z) @ R("Y", rz))
    for k in range(9):
        p.add(splinter(rng.uniform(0.12, 0.4), 0.012, rng), K.darker(white, 0.12), "matte",
              T(rng.uniform(-0.5, 0.7), rng.uniform(0.1, 0.9), 0.012) @ R("Z", rng.uniform(0, 360)) @ R("Y", 90))
    for k in range(10):
        p.add(U.shard(rng, rng.uniform(0.05, 0.14)), GLASS, "glass",
              T(rng.uniform(-0.5, 0.8), rng.uniform(0.05, 1.0), 0.006) @ R("Z", rng.uniform(0, 360)) @ FLAT)
    p.add(lathe([(0.012, 0.0), (0.012, 0.1)], 6), GOLD, "gold", T(-w / 2 - 0.02, 0, h - 0.3))
    # the claw rake through the top rail
    for k in range(3):
        p.add(tube([(-0.2 + k * 0.09, 0.028, h - 0.02), (-0.12 + k * 0.09, 0.03, h - 0.13)], 0.007, 3), (0.30, 0.22, 0.2), "matte", m)


def table_wrecked(p):
    """[C] "the giant table was in pieces": the top split in three, one slab
    propped on a snapped leg, the rest strewn. No blood here (canon)."""
    rng = random.Random(7342)
    wood = U.grain(MAHOGANY, 0.16, 30.0)

    def slab_piece(ln, m):
        b = box(ln, 1.25, 0.09, bevel=0.02)
        for v in b.verts:
            if abs(v.co.x) > ln / 2 - 0.05:
                v.co.x += rng.uniform(-0.16, 0.1) * (1 if v.co.x > 0 else -1) * (1 if abs(v.co.y) < 0.5 else 0.3)
        p.add(b, MAHOGANY, "satin", m, shade=wood)

    slab_piece(1.9, T(-1.5, 0.1, 0.42) @ R("Z", 8) @ R("Y", -24))
    slab_piece(1.4, T(0.35, -0.2, 0.06) @ R("Z", -14))
    slab_piece(1.5, T(1.75, 0.3, 0.3) @ R("Z", 20) @ R("Y", 14) @ R("X", 20))
    legs = [(T(-2.1, 0.45, 0.0), 0.78), (T(-0.9, -0.3, 0.07) @ R("Y", 90) @ R("Z", 40), 0.78), (T(0.9, 0.85, 0.07) @ R("X", 90), 0.5),
            (T(2.3, -0.5, 0.07) @ R("Y", 90) @ R("X", 70), 0.78), (T(1.5, 0.75, 0.0) @ R("X", 9), 0.42), (T(0.1, 0.9, 0.07) @ R("Y", 90), 0.3)]
    for m, ln in legs:
        p.add(K.turned_leg(ln, 0.085, 10), K.darker(MAHOGANY, 0.12), "satin", m)
        if ln < 0.7:
            for k in range(4):
                p.add(splinter(rng.uniform(0.06, 0.16), 0.014, rng), (0.70, 0.50, 0.38), "matte",
                      m @ T(rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), ln - 0.02) @ R("X", rng.uniform(-25, 25)))
    for k in range(16):
        p.add(splinter(rng.uniform(0.15, 0.5), rng.uniform(0.012, 0.03), rng), K.mix(MAHOGANY, (0.70, 0.50, 0.38), rng.random()), "matte",
              T(rng.uniform(-2.5, 2.6), rng.uniform(-1.0, 1.1), 0.02) @ R("Z", rng.uniform(0, 360)) @ R("Y", 90 + rng.uniform(-10, 10)))
    cm = T(0.5, -0.75, 0.05) @ R("Z", 30) @ R("Y", 90)
    p.add(lathe([(0.0, 0.0), (0.1, 0.0), (0.105, 0.015), (0.03, 0.04), (0.022, 0.2), (0.04, 0.24), (0.02, 0.28), (0.022, 0.42), (0.0, 0.43)], 10), GOLD, "gold", cm)
    for a in (-1, 1):
        arm = [(0, 0, 0.3), (a * 0.09, 0, 0.3), (a * 0.14, 0, 0.36), (a * 0.14, 0, 0.44)]
        p.add(tube(arm, 0.011, 5), GOLD, "gold", cm)
        p.add(lathe([(0.02, 0.0), (0.028, 0.012), (0.014, 0.02), (0.012, 0.1)], 8), CREAM, "satin", cm @ T(a * 0.14, 0, 0.44))
    p.add(lathe([(0.02, 0.0), (0.028, 0.012), (0.014, 0.02), (0.012, 0.06)], 8), CREAM, "satin", cm @ T(0, 0, 0.43))
    for k in range(5):
        p.add(U.shard(rng, rng.uniform(0.06, 0.12)), (0.80, 0.78, 0.74), "pearl",
              T(rng.uniform(-0.6, 1.2), rng.uniform(-0.9, -0.3), 0.008) @ R("Z", rng.uniform(0, 360)) @ FLAT)


def curtain_shredded(p):
    """[C] "the curtains in shreds": velvet hanging in claw-cut strips from a
    rod knocked half off its brackets, the rest heaped on the floor."""
    rng = random.Random(7343)
    w, h = 2.3, 2.9
    tilt = R("Y", -7)
    rod_m = T(0, 0, h) @ tilt
    p.add(tube([(-w / 2 - 0.15, 0, 0), (w / 2 + 0.15, 0, 0)], 0.024, 8), GOLD, "gold", rod_m)
    for sx in (-1, 1):
        p.add(lathe([(0.024, 0.0), (0.05, 0.03), (0.04, 0.07), (0.0, 0.1)], 8), GOLD, "gold", rod_m @ T(sx * (w / 2 + 0.15), 0, 0) @ R("Y", sx * 90))
    n = 11
    for k in range(n):
        x = -w / 2 + (k + 0.5) * w / n
        ln = rng.choice((0.5, 0.9, 1.4, 2.0, 2.6, 2.75)) * rng.uniform(0.85, 1.0)
        zt = h - 0.02 + x * math.sin(math.radians(7))
        wave = rng.uniform(0, 6)
        path = [(0.03 * math.sin(wave + u * 5.0) * u, zt - ln * u) for u in [i / 6 for i in range(7)]]
        wd = w / n * rng.uniform(0.75, 1.25)
        col = K.mix(VELVET, K.darker(VELVET, 0.3), rng.random())
        p.add(U.ribbon(path, wd, 0.008), col, "fabric", T(x, rng.uniform(-0.02, 0.02), 0) @ R("Z", 90 + rng.uniform(-14, 14)))
        p.add(torus(0.03, 0.005, 8, 4), GOLD, "gold", T(x, 0, zt + 0.02) @ R("Y", 90))
        if ln < 2.4:
            for j in range(3):
                p.add(lathe([(0.012, 0.0), (0.0, -rng.uniform(0.05, 0.16))], 3), col, "fabric", T(x + (j - 1) * wd * 0.3, 0, zt - ln))
    for k in range(4):
        p.add(K.cushion(rng.uniform(0.5, 0.9), rng.uniform(0.3, 0.5), 0.12, puff=0.7, seg=3), K.mix(VELVET, K.darker(VELVET, 0.3), rng.random()), "fabric",
              T(rng.uniform(-0.8, 0.8), 0.25 + rng.uniform(-0.1, 0.2), 0.05 + k * 0.03) @ R("Z", rng.uniform(-40, 40)))
    p.add(tube([(0.3, 0.3, 0.14), (0.6, 0.5, 0.05), (1.0, 0.55, 0.03)], 0.012, 5), GOLD, "gold")
    p.add(lathe([(0.012, 0.0), (0.03, 0.02), (0.035, 0.1), (0.02, 0.11)], 8), GOLD, "fabric", T(1.0, 0.55, 0.03) @ R("Y", 90))


def glass_shards(p):
    """[C] "the windows smashed" and the "crushed glass" underfoot: a floor
    scatter of shards with a few still standing where they fell."""
    rng = random.Random(7344)
    for k in range(34):
        s = rng.uniform(0.05, 0.2) if k < 22 else rng.uniform(0.02, 0.05)
        a, rr = rng.uniform(0, 6.283), 0.75 * math.sqrt(rng.random())
        m = T(math.cos(a) * rr, math.sin(a) * rr, 0.004 + (0.03 if k % 9 == 0 else 0.0)) @ R("Z", rng.uniform(0, 360))
        m = m @ (R("X", rng.uniform(40, 75)) if k % 9 == 0 else FLAT @ R("X", rng.uniform(-6, 6)))
        p.add(U.shard(rng, s), (0.74 + rng.uniform(-0.08, 0.08), 0.85, 0.85, rng.uniform(0.3, 0.55)), "glass", m)
    for k in range(40):
        a, rr = rng.uniform(0, 6.283), 0.8 * math.sqrt(rng.random())
        p.add(lathe([(0.0, 0.0), (0.008, 0.003), (0.0, 0.01)], 3), (0.82, 0.85, 0.85), "pearl", T(math.cos(a) * rr, math.sin(a) * rr, 0.0), sharp_deg=10.0)


def claw_gouges(p):
    """[C] "the gouged walls": four raking claw marks, torn wood pale at
    their edges. A wall decal: lies in the wall's plane, facing the room."""
    rng = random.Random(7345)
    for k in range(4):
        x0 = -0.3 + k * 0.2
        ln = 1.5 - abs(k - 1.5) * 0.18
        pts, wx = [], []
        for i in range(9):
            u = i / 8
            pts.append((0.0, (1.9 - ln * u)))
            wx.append(0.004 + 0.03 * math.sin(math.pi * u) ** 0.7)
        m = T(x0, 0, 0) @ R("Y", -16)
        bm = U.sweep(pts, wx, 0.008, 6)
        for v in bm.verts:
            v.co.x += 0.1 * math.sin((1.9 - v.co.z) * 1.6)
        p.add(bm, (0.13, 0.09, 0.10), "matte", m)
        for j in range(6):
            u = rng.uniform(0.1, 0.9)
            z = 1.9 - ln * u
            p.add(splinter(rng.uniform(0.05, 0.13), 0.007, rng), (0.72, 0.56, 0.44), "matte",
                  m @ T(0.1 * math.sin((1.9 - z) * 1.6) + rng.choice((-1, 1)) * 0.03, 0.006, z) @ R("Y", rng.uniform(140, 220)) @ R("X", -20))
    for k in range(5):
        p.add(U.splat(rng.uniform(0.02, 0.05), rng.uniform(0.02, 0.06), 7, rng, 0.4), BLOOD_DRY, "satin",
              T(rng.uniform(-0.4, 0.5), 0.003, rng.uniform(0.5, 1.7)) @ FRONT)


def blood_puddle(p):
    """[C] "small puddles": pooled blood on the hall floor with a dragged
    smear and thrown drops. Horror stays horror (R3)."""
    rng = random.Random(7346)
    p.add(U.splat(0.34, 0.26, 18, rng, 0.35, 0.006), BLOOD, "pearl", T(0, 0, 0.001),
          shade=lambda co: K.mix(BLOOD_DRY, BLOOD, clamp(1.4 - math.hypot(co.x / 0.34, co.y / 0.26))))
    p.add(U.splat(0.16, 0.11, 12, rng, 0.3, 0.005), BLOOD, "pearl", T(0.42, 0.2, 0.001))
    for i in range(7):
        u = i / 6
        p.add(U.splat(0.11 - 0.05 * u, 0.2, 9, rng, 0.3, 0.002), K.mix(BLOOD, BLOOD_DRY, u), "satin",
              T(-0.25 - u * 0.75, 0.3 + u * 0.8 + 0.06 * math.sin(u * 5), 0.0006) @ R("Z", 42))
    for k in range(18):
        a, rr = rng.uniform(0, 6.283), rng.uniform(0.4, 1.0)
        s = rng.uniform(0.008, 0.035)
        p.add(U.splat(s, s * rng.uniform(1.0, 2.6), 6, rng, 0.2, 0.002), BLOOD, "pearl",
              T(math.cos(a) * rr, math.sin(a) * rr * 0.8, 0.0005) @ R("Z", math.degrees(a) + 90))


def blood_smear_wall(p):
    """[C] "smears down the gouged walls": a handspan splatter with runs
    dragging down from it. A wall decal facing the room."""
    rng = random.Random(7347)
    p.add(U.splat(0.26, 0.2, 16, rng, 0.45, 0.004), BLOOD, "pearl", T(0, 0.002, 1.5) @ FRONT)
    for k in range(7):
        x = rng.uniform(-0.22, 0.22)
        ln = rng.uniform(0.25, 1.1)
        pts = [(0.002, 1.48 - ln * i / 5) for i in range(6)]
        wx = [rng.uniform(0.012, 0.03) * (1 - 0.6 * i / 5) for i in range(6)]
        bm = U.sweep(pts, wx, 0.0015, 6)
        p.add(bm, BLOOD, "pearl", T(x, 0, 0), shade=lambda co: K.mix(BLOOD_DRY, BLOOD, clamp((co.z - 0.4) / 1.1)))
        p.add(U.splat(wx[-1] * 1.5, wx[-1] * 1.9, 6, rng, 0.2, 0.003), BLOOD, "pearl", T(x, 0.002, 1.48 - ln) @ FRONT)
    for k in range(14):
        a, rr = rng.uniform(0, 6.283), rng.uniform(0.3, 0.7)
        s = rng.uniform(0.006, 0.03)
        p.add(U.splat(s, s * rng.uniform(1.0, 3.0), 6, rng, 0.2, 0.002), BLOOD, "pearl",
              T(math.cos(a) * rr, 0.002, 1.5 + math.sin(a) * rr * 0.7) @ FRONT @ R("Z", math.degrees(a) + 90))
    # a dragged handprint's four fingers
    for k in range(4):
        p.add(U.sweep([(0.002, 1.2 - 0.3 * i / 4) for i in range(5)], [0.011, 0.012, 0.01, 0.007, 0.003], 0.0012, 5), BLOOD_DRY, "satin",
              T(0.42 + k * 0.032, 0, 0.04 * math.sin(k * 1.1)) @ R("Y", 8))


def alis_satchel(p):
    """[C] Alis's "large satchel ... already half full of what looked like
    clothes and supplies", with the knives and the food that survived (an apple)."""
    rng = random.Random(7348)
    canvas = (0.50, 0.38, 0.28)
    body = K.cushion(0.62, 0.3, 0.44, puff=0.45, seg=3)
    for v in body.verts:
        if v.co.z > 0.12:
            v.co.z -= (v.co.z - 0.12) * 0.55
            v.co.y *= 1.08
    p.add(body, canvas, "fabric", T(0, 0, 0.2), shade=lambda co: K.mix(K.darker(canvas, 0.2), canvas, 0.5 + 0.5 * math.sin(co.x * 40 + co.z * 31)))
    flap = [(-0.16, 0.34), (-0.26, 0.36), (-0.36, 0.26), (-0.4, 0.1), (-0.42, 0.02)]
    p.add(U.ribbon(flap, 0.6, 0.012), K.darker(canvas, 0.14), "fabric", R("Z", 90))
    p.add(K.cushion(0.3, 0.2, 0.08, puff=0.6), (0.80, 0.76, 0.66), "fabric", T(-0.12, 0.0, 0.34) @ R("Z", 12))
    p.add(K.cushion(0.26, 0.18, 0.07, puff=0.6), (0.42, 0.30, 0.24), "fabric", T(0.14, 0.02, 0.33) @ R("Z", -9))
    for k in range(3):
        m = T(0.2 + k * 0.045, -0.07, 0.3) @ R("Y", 14 + k * 5) @ R("X", -8)
        p.add(lathe([(0.012, 0.0), (0.015, 0.05), (0.012, 0.11), (0.016, 0.12), (0.0, 0.125)], 6), OAK_DARK, "satin", m @ T(0, 0, 0.06))
        p.add(box(0.03, 0.006, 0.012), GOLD, "gold", m @ T(0, 0, 0.06))
    p.add(sphere(0.042, 10, 6), (0.80, 0.22, 0.2), "pearl", T(-0.02, 0.05, 0.41) @ S(1, 1, 0.92))
    p.add(tube([(-0.02, 0.05, 0.445), (-0.015, 0.055, 0.468)], 0.003, 3), OAK_DARK, "matte")
    strap = [(-0.3, 0, 0.3), (-0.42, 0.04, 0.2), (-0.5, 0.2, 0.03), (-0.3, 0.42, 0.015), (0.1, 0.5, 0.015), (0.4, 0.34, 0.02), (0.36, 0.12, 0.2), (0.3, 0, 0.3)]
    p.add(tube(strap, 0.012, 5), K.darker(canvas, 0.35), "fabric", S(1, 1, 1))
    for x in (-0.16, 0.16):
        p.add(torus(0.022, 0.004, 8, 4), IRON, "mirror", T(x, 0.16, 0.2) @ R("X", 90))


def dagger(p):
    """[C] one of the "two daggers at my waist" she takes from the wrecked
    manor: a Spring Court blade, leaf-ground, gilt guard, rose-leather grip."""
    p.add(lathe([(0.004, 0.0), (0.019, 0.02), (0.016, 0.1), (0.011, 0.17), (0.0, 0.215)], 8), STEEL, "mirror", T(0, 0, 0.125) @ S(1, 0.2, 1), sharp_deg=60.0)
    p.add(lathe([(0.0016, 0.0), (0.0012, 0.15), (0.0, 0.18)], 4), K.lighter(STEEL, 0.1), "mirror", T(0, 0.0036, 0.13))
    guard = [(-0.045, 0, 0.128), (-0.03, 0, 0.118), (0, 0, 0.116), (0.03, 0, 0.118), (0.045, 0, 0.128)]
    p.add(tube(guard, [0.004, 0.006, 0.008, 0.006, 0.004], 6), GOLD, "gold")
    for sx in (-1, 1):
        p.add(sphere(0.006, 6, 4), GOLD, "gold", T(sx * 0.046, 0, 0.13))
    p.add(lathe([(0.009, 0.02), (0.012, 0.05), (0.011, 0.09), (0.009, 0.112)], 8), (0.70, 0.36, 0.42), "fabric", S(1, 0.8, 1))
    for k in range(5):
        p.add(torus(0.0118, 0.0012, 8, 3), GOLD, "gold", T(0, 0, 0.032 + k * 0.018) @ S(1, 0.8, 1))
    p.add(lathe([(0.0, 0.0), (0.011, 0.006), (0.013, 0.014), (0.009, 0.022)], 8), GOLD, "gold")
    p.add(sphere(0.006, 6, 4), ROSE, "pearl", T(0, 0.008, 0.012))


# ------------------------------------------------------------------ the pass


def cave_mouth_pass(p):
    """[C] "a slender cave mouth" in "the hollow between two hills": two
    leaning shoulders of cold bedded rock and a black slot between them, the
    mountain's "pale stone" just showing inside. Frightening, never pretty."""
    rng = random.Random(7351)

    def shoulder(seed, sx):
        def shape(co):
            z = max(0.0, (co.z + 0.35) * 5.4)                     # flat foot: nothing buried
            return Vector((co.x * 1.65 - sx * max(0.0, z - 1.5) * 0.09, co.y * 2.0, z))
        bm = U.weathered_rock(1.0, 4, seed, 0.22, shape, strata=0.11, beds=0.42, cut_foot=True)

        def pale(co, col):
            inner = clamp(1.0 - abs(co.x * sx + 1.7) * 1.1) * clamp(0.9 - co.y * 0.7)
            return K.mix(col, PALE_STONE, inner * 0.5)
        p.add(bm, COLD_STONE, "matte", T(sx * 2.35, 0, 0), sharp_deg=50.0,
              shade=U.stone_shade(bm, COLD_STONE, 0.55, 0.42, (0.42, 0.14), pale))

    shoulder(1.3, -1)
    shoulder(4.1, 1)
    p.add(box(1.9, 0.4, 5.4), (0.015, 0.015, 0.02), "matte", T(0, 0.55, 2.7))
    lintel = U.weathered_rock(1.0, 3, 7.7, 0.2, lambda co: Vector((co.x * 1.9, co.y * 1.6, co.z * 0.9)), strata=0.1, beds=1.1)
    p.add(lintel, COLD_STONE, "matte", T(0, -0.2, 6.4), sharp_deg=50.0, shade=U.stone_shade(lintel, COLD_STONE, 0.55, 0.42, (1.1, 0.12)))
    for k in range(5):
        r = rng.uniform(0.22, 0.5)
        bm = U.weathered_rock(r, 2, k * 3.1, 0.25)
        base = K.mix(COLD_STONE, PALE_STONE, rng.random() * 0.4)
        p.add(bm, base, "matte", T(rng.choice((-1, 1)) * rng.uniform(0.9, 3.4), rng.uniform(1.2, 2.6), r * 1.25), sharp_deg=50.0,
              shade=U.stone_shade(bm, base, 0.5, 0.35))
    # the worn threshold of the "ancient shortcut"
    p.add(box(1.1, 1.6, 0.16, bevel=0.05), K.mix(COLD_STONE, PALE_STONE, 0.5), "matte", T(0, 0.9, 0.06))


def shrine_stone_worn(p):
    """[X] "once considered sacred, but no more": a leaning marker stone, its
    spiral and three strokes cut into the face and weathered almost flat, the
    edges worn round, lichen grown into it, a cracked offering bowl."""
    rng = random.Random(7352)
    stone = (0.42, 0.42, 0.48)
    H, W, TH, NU = 1.7, 0.36, 0.17, 24
    # rows are packed where the carving is, so the grooves have mesh to sit in
    VS = [0.38 / H * k / 12 for k in range(12)] + [(0.38 + 1.02 * k / 34) / H for k in range(34)] + [(1.4 + 0.3 * k / 8) / H for k in range(9)]
    NV = len(VS) - 1
    patches = [(-0.24, 0.3, 0.11, 0.2), (0.2, 0.22, 0.07, 0.8), (0.24, 0.82, 0.08, 0.5), (-0.17, 1.5, 0.09, 0.9)]     # lichen, clear of the carving
    cx, cz = 0.0, 1.08

    def halfw(v, side):
        top = math.sqrt(max(0.0, 1.0 - max(0.0, (v - 0.78) / 0.22) ** 2))
        chip = 0.13 * math.exp(-((v - (0.56 if side < 0 else 0.3)) / 0.05) ** 2)      # a bite out of each edge
        return W * (1.0 - 0.12 * v + 0.04 * math.sin(v * 7.0 + side)) * (0.3 + 0.7 * top) * (1.0 - chip)

    def carve(x, z):
        dx, dz = x - cx, z - cz
        r = math.hypot(dx, dz)
        g = 0.0
        if 0.03 < r < 0.3:
            q = (r - 0.03) / 0.13 - math.atan2(dz, dx) / (2.0 * math.pi)
            g = clamp(1.3 - abs(q - round(q)) * 0.13 / 0.03)
        if 0.42 < z < 0.68:
            for sx in (-0.16, 0.0, 0.16):
                g = max(g, clamp(1.3 - abs(x - sx) / 0.03) * clamp((z - 0.42) / 0.03) * clamp((0.68 - z) / 0.03))
        worn = clamp(0.62 + 0.5 * math.sin(x * 9.0 + z * 6.0))        # some of it is rubbed nearly away
        return g * g * (3.0 - 2.0 * g) * worn

    bm = bmesh.new()
    cav = bm.verts.layers.float.new("cav")
    grid = []
    for j in range(NV + 1):
        v = VS[j]
        row = []
        for i in range(NU + 1):
            u = -1.0 + 2.0 * i / NU
            x0 = u * (halfw(v, -1) * (1 - u) / 2 + halfw(v, 1) * (1 + u) / 2)
            z = v * H
            t = TH * max(0.0, 1.0 - u * u) ** 0.45 * math.sqrt(max(0.0, 1.0 - max(0.0, (v - 0.8) / 0.2) ** 2))
            g = carve(x0, z)
            bed0 = z * 2.3 + 0.3 * math.sin(x0 * 3.0)
            bed0 -= math.floor(bed0)
            rough = 0.008 * (math.sin(x0 * 13.7 + z * 5.1) + 0.6 * math.sin(z * 9.3 - x0 * 4.7 + 1.0) + 0.4 * math.sin(x0 * 27.1 + z * 21.3))
            edge = 0.0 if (i in (0, NU) or j == NV) else 1.0
            vert = bm.verts.new((x0 + z * 0.16, (t - 0.024 * g + rough + 0.01 * bed0) * edge - z * 0.08, z))
            bed = z * 2.3 + 0.3 * math.sin(x0 * 3.0)
            bed -= math.floor(bed)
            broad = math.sin(x0 * 4.3 + z * 2.9 + 0.7) + 0.6 * math.sin(z * 6.1 - x0 * 2.3)
            vert[cav] = clamp(0.52 + 0.3 * (bed - 0.5) + 0.2 * broad + rough * 9.0 - 0.65 * g)
            row.append(vert)
        grid.append(row)
    for j in range(NV):
        for i in range(NU):
            bm.faces.new((grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]))
    mids = []
    for j in range(NV + 1):
        v = VS[j]
        if j == NV:
            mids.append(grid[j][NU // 2])
            continue
        z = v * H
        t = TH * 0.8 * math.sqrt(max(0.0, 1.0 - max(0.0, (v - 0.8) / 0.2) ** 2))
        m = bm.verts.new((z * 0.16 + 0.02 * math.sin(v * 9.0), -t - z * 0.08, z))
        m[cav] = 0.45 + 0.2 * math.sin(v * 13.0)
        mids.append(m)
    for j in range(NV):
        bm.faces.new((grid[j][0], mids[j], mids[j + 1], grid[j + 1][0]))
        if j == NV - 1:
            bm.faces.new((mids[j], grid[j][NU], grid[j + 1][NU], mids[j + 1]))
        else:
            bm.faces.new((mids[j], grid[j][NU], grid[j + 1][NU], mids[j + 1]))

    def lichen(co, col):
        x, z = co.x - co.z * 0.16, co.z
        if co.y + z * 0.08 < 0.0:
            return col                                   # the sheltered back stays bare
        for px, pz, pr, hue in patches:
            d = math.hypot(x - px, (z - pz) * 0.8) / pr + 0.35 * math.sin(x * 37.0 + z * 29.0 + hue * 6.0)
            if d < 1.0:
                col = K.mix(col, K.mix((0.50, 0.62, 0.52), (0.70, 0.66, 0.42), hue), clamp((1.0 - d) * 2.5) * 0.65)
        return col

    p.add(bm, stone, "matte", sharp_deg=62.0, shade=U.stone_shade(bm, stone, 0.6, 0.3, (2.2, 0.1), lichen))
    bowl = lathe([(0.0, 0.0), (0.09, 0.0), (0.15, 0.05), (0.17, 0.1), (0.15, 0.1), (0.13, 0.06), (0.07, 0.02), (0.0, 0.02)], 12)
    p.add(bowl, K.lighter(stone, 0.15), "matte", T(0.5, 0.35, 0.12) @ R("X", 68) @ R("Z", 30), shade=U.stone_shade(bowl, K.lighter(stone, 0.15), 0.45, 0.2))
    p.add(U.shard(rng, 0.09), K.lighter(stone, 0.15), "matte", T(0.3, 0.52, 0.006) @ FLAT)
    p.add(U.shard(rng, 0.06), K.lighter(stone, 0.15), "matte", T(0.68, 0.5, 0.006) @ FLAT @ R("Y", 40))


BUILDERS = {
    # id: (builder, size (None: as modelled, true scale), meta)
    "trunk_gold": (trunk_gold, None, dict(scene="return", canon="C")),
    "trunk_gowns": (trunk_gowns, None, dict(scene="return", canon="C")),
    "raw_ruby": (raw_ruby, None, dict(scene="return", canon="C")),
    "gold_scale": (gold_scale, None, dict(scene="return", canon="C")),
    "tulip_bed": (tulip_bed, None, dict(scene="return", canon="C")),
    "dug_plot": (dug_plot, None, dict(scene="return", canon="C")),
    "bulb_crate": (bulb_crate, None, dict(scene="return", canon="C")),
    "watering_can": (watering_can, None, dict(scene="return", canon="C")),
    "garden_trug": (garden_trug, None, dict(scene="return", canon="C")),
    "iron_bracelet": (iron_bracelet, None, dict(scene="return", canon="C")),
    "ball_flower_stand": (ball_flower_stand, None, dict(scene="return", canon="X")),
    "estate_gate": (estate_gate, None, dict(scene="return", canon="X")),
    "supply_satchel": (supply_satchel, None, dict(scene="return", canon="C")),
    "garden_tangle": (garden_tangle, None, dict(scene="return", canon="C")),
    "cottage_window_cracked": (cottage_window_cracked, None, dict(scene="return", canon="C")),
    "beddor_ruin": (beddor_ruin, None, dict(scene="return", canon="X", horror=True)),
    "door_shattered": (door_shattered, None, dict(scene="pass", canon="C", horror=True)),
    "table_wrecked": (table_wrecked, None, dict(scene="pass", canon="C", horror=True)),
    "curtain_shredded": (curtain_shredded, None, dict(scene="pass", canon="C", horror=True)),
    "glass_shards": (glass_shards, None, dict(scene="pass", canon="C", horror=True)),
    "claw_gouges": (claw_gouges, None, dict(scene="pass", canon="C", horror=True, decal="wall")),
    "blood_puddle": (blood_puddle, None, dict(scene="pass", canon="C", horror=True, decal="floor")),
    "blood_smear_wall": (blood_smear_wall, None, dict(scene="pass", canon="C", horror=True, decal="wall")),
    "alis_satchel": (alis_satchel, None, dict(scene="pass", canon="C")),
    "dagger": (dagger, None, dict(scene="pass", canon="C")),
    "cave_mouth_pass": (cave_mouth_pass, None, dict(scene="pass", canon="C", horror=True)),
    "shrine_stone_worn": (shrine_stone_worn, None, dict(scene="pass", canon="X", horror=True)),
}

RETURN = [k for k, v in BUILDERS.items() if v[2]["scene"] == "return"]
PASS = [k for k, v in BUILDERS.items() if v[2]["scene"] == "pass"]
SHEETS = [
    ("return_estate.png", RETURN, 4, 32, 24, False),
    ("pass_wreck_and_cave.png", PASS, 4, 28, 20, True),
]

if __name__ == "__main__":
    U.run_family(BUILDERS, OUT, "return_pass_manifest.json", sys.argv[1:], SHEETS)
