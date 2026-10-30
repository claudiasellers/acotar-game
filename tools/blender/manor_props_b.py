"""Manor prop models, part B: art, decor, structure, library, music, bath,
kitchen, stillroom, armory, chapel, garden, stable and secrets.

Same contract as part A: builder(p, size, color), front faces +Y, fitted afterwards.
"""

import math
import random

from manor_props_a import _candelabra_at, _chest, cab_legs, candle, crest, drawer_row, gilt_edge, heart_crest, \
    knob, mirror_panel, rose_cluster
from prop_kit import (BARK, BLUSH, BUTTER, CANVAS, COPPER, CREAM, FLAME, GOLD, GOLD_DEEP, IRON, LEAF, LEAF_DARK, LILAC,
                      MARBLE, MINT, OAK, OAK_DARK, PEARL, PERI, ROSE, SAGE_LIGHT, SOFT_BLUE, STRAW, WARM_STONE, WHITE,
                      R, S, T, arched_outline, bloom, box, cushion, cyl, darker, disc, frame_ring, ico, lathe, leaf,
                      lighter, mix, oval_outline, petal, scroll, slab, sphere, star_flower, torus, tube, turned_leg)

WATERC = (0.74, 0.92, 0.90)
BOOKS = [ROSE, LILAC, PERI, MINT, BUTTER, BLUSH, (0.85, 0.5, 0.6), (0.55, 0.62, 0.9), (0.6, 0.8, 0.65), (0.95, 0.7, 0.5)]


# ------------------------------------------------------------ helpers


def book_row(p, x0, x1, y, z, depth, hmax, rng, lean_end=True):
    x = x0
    while x < x1 - 0.03:
        t = rng.uniform(0.045, 0.09)
        h = hmax * rng.uniform(0.7, 1.0)
        col = BOOKS[rng.randrange(len(BOOKS))]
        p.add(box(t, depth, h), col, "satin", T(x + t / 2, y, z + h / 2), smooth=False)
        if rng.random() < 0.2:
            p.add(box(t + 0.002, depth * 0.3, 0.01, seg=1), GOLD, "gold", T(x + t / 2, y + depth * 0.36, z + h * 0.8), smooth=False)
        x += t + 0.003


def picture(p, w, h, art, frame=GOLD, depth=0.06, oval=False, rng=None):
    """Framed painting facing +Y with a simple painted scene built from colour patches."""
    rng = rng or random.Random(1)
    ol = oval_outline(w, h, 20) if oval else [(-w / 2, 0), (w / 2, 0), (w / 2, h), (-w / 2, h)]
    p.add(slab(ol, depth * 0.5), art[0], "matte", T(0, 0, 0))
    p.add(frame_ring(ol, min(w, h) * 0.05, depth), frame, "gold", T(0, depth * 0.2, 0))
    if not oval:
        crest(p, 0, depth * 0.3, h + min(w, h) * 0.04, min(w, h) * 0.18, frame)
    # the scene: sky band, hills, a blossom tree / figure
    y = depth * 0.26
    iw, ih = w * 0.86, h * 0.86
    p.add(box(iw, 0.004, ih * 0.45), art[1], "matte", T(0, y, h * 0.07 + ih * 0.55 + ih * 0.225 - ih * 0.05))
    p.add(slab([(-iw / 2, 0), (iw / 2, 0), (iw / 2, ih * 0.3), (iw * 0.1, ih * 0.45), (-iw * 0.3, ih * 0.35), (-iw / 2, ih * 0.42)], 0.004),
          art[2], "matte", T(0, y + 0.002, h * 0.07))
    for k in range(len(art) - 3):
        cx = rng.uniform(-iw * 0.3, iw * 0.3)
        p.add(sphere(min(iw, ih) * 0.12, 8, 5), art[3 + k], "matte", T(cx, y + 0.004, h * 0.07 + ih * rng.uniform(0.35, 0.6)) @ S(1, 0.08, 0.8))


def pot(p, r, h, col, finish="satin", rim=GOLD):
    p.add(lathe([(0, 0), (r * 0.65, 0), (r * 0.7, h * 0.08), (r * 0.95, h * 0.55), (r, h * 0.85), (r * 1.12, h * 0.92), (r * 1.1, h), (r * 0.9, h)], 12, cap_top=True), col, finish)
    p.add(torus(r * 1.08, h * 0.04, 12, 4), rim, "gold", T(0, 0, h * 0.95))
    p.add(disc(r * 0.9, 12, h * 0.97), (0.62, 0.48, 0.42), "matte")


def shelf_unit(p, w, h, d, c, shelves, finish="satin", back=None, top_crest=False):
    for sx in (-1, 1):
        p.add(box(0.05, d, h, bevel=0.012), c, finish, T(sx * (w / 2 - 0.025), 0, h / 2))
    p.add(box(w, 0.02, h, seg=1), back or lighter(c, 0.15), "satin", T(0, -d / 2 + 0.01, h / 2))
    for z in shelves:
        p.add(box(w - 0.06, d, 0.03, bevel=0.008), c, finish, T(0, 0, z))
    p.add(box(w + 0.06, d + 0.06, 0.06, bevel=0.02), c, finish, T(0, 0, h - 0.03))
    p.add(box(w + 0.02, d + 0.02, 0.08, bevel=0.015), darker(c, 0.1), finish, T(0, 0, 0.04))
    if top_crest:
        crest(p, 0, d / 2 - 0.02, h + 0.02, 0.2)


def jars(p, x0, x1, y, z, cols, rng, hmax=0.2, glass=True):
    x = x0
    i = 0
    while x < x1 - 0.05:
        r = rng.uniform(0.045, 0.07)
        h = hmax * rng.uniform(0.6, 1.0)
        col = cols[i % len(cols)]
        p.add(lathe([(0, 0), (r, 0), (r, h * 0.8), (r * 0.6, h * 0.9), (0, h * 0.9)], 6), col, "glass" if glass else "satin", T(x + r, y, z))
        p.add(cyl(r * 0.62, h * 0.12, 6), OAK if glass else GOLD, "satin", T(x + r, y, z + h * 0.88))
        x += 2 * r + 0.03
        i += 1


def flower_spray(p, cx, cy, cz, spread, n, cols, rng, size=0.05, stems=True):
    for i in range(n):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.2, 1.0) * spread
        x, y, z = cx + d * math.cos(a), cy + d * math.sin(a), cz + rng.uniform(-0.3, 0.6) * spread
        col = cols[i % len(cols)]
        if stems:
            p.add(tube([(cx, cy, cz - spread * 0.6), (x, y, z)], 0.006, 4), LEAF_DARK, "leaf")
        bloom(p, (x, y, z), size * rng.uniform(0.8, 1.2), col, 2, 5, rng,
              tilt=R("X", math.degrees(math.atan2(y - cy, 1)) * -1.5) @ R("Y", math.degrees(math.atan2(x - cx, 1)) * 1.5))
        if i % 2 == 0:
            p.add(leaf(size * 1.8, size * 0.9), LEAF, "leaf", T(x, y, z - size * 0.6) @ R("Z", math.degrees(a)) @ R("Y", 25))


def foliage_ball(p, cx, cy, cz, r, col, rng, n=5, sub=1):
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = r * rng.uniform(0.5, 0.7)
        off = r * 0.45
        p.add(ico(rr, sub), col if i % 2 else lighter(col, 0.12), "leaf",
              T(cx + off * math.cos(a), cy + off * math.sin(a), cz + rng.uniform(-0.2, 0.25) * r))
    p.add(ico(r * 0.7, sub), lighter(col, 0.08), "leaf", T(cx, cy, cz + r * 0.25))


# ------------------------------------------------------------ fireplaces & structure


def fireplace(p, w, h, d, c, grand):
    # rocaille marble surround: legs, serpentine lintel, mantel shelf, shell keystone
    leg_w = w * 0.16
    for sx in (-1, 1):
        p.add(box(leg_w, d * 0.8, h * 0.8, bevel=0.03), c, "pearl", T(sx * (w / 2 - leg_w / 2), 0, h * 0.4))
        p.add(scroll(leg_w * 0.45, 1.3, 12, leg_w * 0.08), GOLD, "gold", T(sx * (w / 2 - leg_w / 2), d * 0.41, h * 0.62) @ S(-sx, 1, 1) @ R("Y", 180))
    lint = [(-w / 2, h * 0.62), (w / 2, h * 0.62), (w / 2, h * 0.82), (-w / 2, h * 0.82)]
    p.add(slab(lint, d * 0.8, 0.02), c, "pearl", T(0, 0, 0))
    opening = arched_outline(w - 2 * leg_w, h * 0.62, 12, (w - 2 * leg_w) * 0.25)
    p.add(slab(opening, 0.02), (0.36, 0.26, 0.3), "matte", T(0, -d * 0.3, 0))
    p.add(frame_ring(opening, 0.025, 0.04), GOLD, "gold", T(0, d * 0.4, 0))
    p.add(box(w + 0.15, d + 0.05, 0.08, bevel=0.025), lighter(c, 0.05), "pearl", T(0, 0.02, h * 0.84))
    crest(p, 0, d * 0.42, h * 0.68, w * 0.12)
    # hearth, logs, flames
    p.add(box(w + 0.1, d + 0.25, 0.06, bevel=0.015), mix(c, ROSE, 0.15), "pearl", T(0, 0.1, 0.03))
    for k in range(3):
        p.add(cyl(0.06, w * 0.35, 6), BARK, "matte", T(-w * 0.17 + 0.02 * k, -d * 0.1 + 0.08 * (k - 1), 0.12 + 0.05 * (k == 1)) @ R("Y", 90) @ R("X", 8 * (k - 1)))
    for k in range(5):
        x = -w * 0.15 + w * 0.075 * k
        fh = (0.35 if grand else 0.25) * (1.0 - 0.3 * abs(k - 2) / 2)
        p.add(lathe([(0, 0), (0.07, 0.04), (0.05, fh * 0.5), (0, fh)], 6), FLAME if k % 2 else (1.0, 0.65, 0.5), "glow", T(x, -d * 0.1, 0.12))
    # garniture on the mantel
    for sx in (-1, 1):
        _candelabra_at(p, sx * w * 0.38, 0.02, h * 0.88, 0.3 if grand else 0.22)
    if grand:
        p.add(lathe([(0.05, 0), (0.1, 0.06), (0.06, 0.2), (0.11, 0.28)], 10), BLUSH, "pearl", T(0, 0.02, h * 0.88))
        rose_cluster(p, 0, 0.02, h * 0.88 + 0.33, 0.08, 3, ROSE, random.Random(5), 0.06, False)
        # overmantel mirror (experience bar 2.6: mirrors over fireplaces)
        mirror_panel(p, w * 0.62, h * 0.12, h * 0.88, -d * 0.35, "oval", GOLD, depth=0.03)
    else:
        p.add(sphere(0.07, 8, 6), PERI, "pearl", T(0, 0.02, h * 0.88 + 0.07))


def fireplace_grand(p, size, c):
    fireplace(p, 3.2, 2.6, 0.9, c, True)


def fireplace_small(p, size, c):
    fireplace(p, 1.8, 1.6, 0.6, c, False)


def column_marble(p, size, c):
    h = 4.4
    p.add(box(0.8, 0.8, 0.2, bevel=0.03), c, "pearl", T(0, 0, 0.1))
    p.add(lathe([(0.34, 0.2), (0.36, 0.26), (0.3, 0.34), (0.28, 0.4), (0.24, h * 0.9), (0.28, h * 0.92), (0.3, h * 0.94), (0.36, h - 0.12), (0.0, h - 0.12)], 16), c, "pearl")
    shaft = cyl(0.25, h * 0.85, 16)
    p.add(shaft, c, "pearl", T(0, 0, 0.35))
    for i in range(8):                         # gilt flutes
        a = 2 * math.pi * i / 8
        p.add(cyl(0.012, h * 0.7, 4), GOLD, "gold", T(0.25 * math.cos(a), 0.25 * math.sin(a), 0.5))
    p.add(box(0.8, 0.8, 0.12, bevel=0.03), c, "pearl", T(0, 0, h - 0.06))
    for a in range(4):
        p.add(scroll(0.12, 1.3, 10, 0.02), GOLD, "gold", R("Z", 90 * a) @ T(0, 0.32, h - 0.25))
    tube_pts = [(0.27 * math.cos(t), 0.27 * math.sin(t), 0.6 + (h - 1.2) * t / (6 * math.pi)) for t in [i * 0.4 for i in range(48)]]
    p.add(tube(tube_pts, 0.025, 4), LEAF, "leaf")
    rng = random.Random(3)
    for i in range(0, 48, 6):
        x, y, z = tube_pts[i]
        bloom(p, (x * 1.12, y * 1.12, z), 0.07, ROSE if i % 12 else BLUSH, 2, 5, rng, tilt=R("Z", math.degrees(i * 0.4)) @ R("Y", 80))


def pilaster(p, size, c):
    h = 4.4
    p.add(box(0.6, 0.2, 0.3, bevel=0.02), c, "pearl", T(0, 0, 0.15))
    p.add(box(0.46, 0.14, h - 0.6, bevel=0.02), c, "pearl", T(0, 0, h / 2))
    for x in (-0.12, 0.0, 0.12):
        p.add(cyl(0.012, h - 1.0, 4), GOLD, "gold", T(x, 0.07, 0.5))
    p.add(box(0.6, 0.2, 0.3, bevel=0.02), c, "pearl", T(0, 0, h - 0.15))
    crest(p, 0, 0.1, h - 0.35, 0.2)


def arch_trellis(p, size, c):
    w, h = 2.4, 3.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(cyl(0.03, h - 1.1, 6), c, "satin", T(sx * 1.1, sy * 0.22, 0))
        for k in range(5):
            p.add(box(0.02, 0.48, 0.02, seg=1), c, "satin", T(sx * 1.1, 0, 0.3 + k * 0.4))
    for sy in (-1, 1):
        pts = [(1.1 * math.cos(math.pi * i / 10), sy * 0.22, h - 1.1 + 1.1 * math.sin(math.pi * i / 10)) for i in range(11)]
        p.add(tube(pts, 0.03, 6), c, "satin")
    rng = random.Random(11)
    vine = [(1.1 * math.cos(math.pi * i / 14), 0.25 * math.sin(i * 1.3), h - 1.1 + 1.1 * math.sin(math.pi * i / 14)) for i in range(15)]
    vine = [(1.12, 0.2, 0.0), (1.08, -0.15, 0.8), (1.14, 0.18, 1.5)] + vine + [(-1.14, 0.18, 1.5), (-1.08, -0.15, 0.8), (-1.12, 0.2, 0.0)]
    p.add(tube(vine, 0.025, 4), LEAF_DARK, "leaf")
    for i, (x, y, z) in enumerate(vine[1:-1:2]):
        bloom(p, (x * 1.03, y + 0.05, z + 0.05), 0.11, ROSE if i % 3 else BLUSH, 2, 5, rng)
        p.add(leaf(0.16, 0.09), LEAF, "leaf", T(x, y, z - 0.08) @ R("Z", 40 * i) @ R("Y", 20))


def balustrade(p, size, c):
    w = 3.0
    p.add(box(w, 0.3, 0.12, bevel=0.02), c, "pearl", T(0, 0, 0.06))
    p.add(box(w, 0.34, 0.1, bevel=0.03), c, "pearl", T(0, 0, 0.95))
    p.add(box(w - 0.1, 0.36, 0.03), BLUSH, "satin", T(0, 0, 0.92))      # blush band under the rail
    for i in range(9):
        x = -w / 2 + 0.17 + i * (w - 0.34) / 8
        p.add(lathe([(0.07, 0), (0.06, 0.08), (0.1, 0.3), (0.06, 0.6), (0.05, 0.66), (0.08, 0.78)], 8), c, "pearl", T(x, 0, 0.12))
    for x in (-w / 2 + 0.05, w / 2 - 0.05):
        p.add(box(0.2, 0.3, 0.9, bevel=0.02), c, "pearl", T(x, 0, 0.45))
    p.add(sphere(0.08, 8, 6), GOLD, "gold", T(0, 0, 1.08))


def gate_iron_gilt(p, size, c):
    w, h = 4.0, 3.2
    for sx in (-1, 1):
        p.add(box(0.22, 0.22, h - 0.3, bevel=0.03), PEARL, "pearl", T(sx * (w / 2 - 0.11), 0, (h - 0.3) / 2))
        p.add(sphere(0.12, 10, 6), c, "gold", T(sx * (w / 2 - 0.11), 0, h - 0.15))
    for i in range(14):
        x = -w / 2 + 0.35 + i * (w - 0.7) / 13
        top = h - 0.9 + 0.5 * math.sin(math.pi * (i + 0.5) / 14) - 0.1 * (i % 2)
        p.add(cyl(0.018, top, 5), IRON, "gold", T(x, 0, 0.1))
        p.add(lathe([(0, 0), (0.035, 0.03), (0, 0.12)], 6), c, "gold", T(x, 0, 0.1 + top))
    for z in (0.3, 1.6):
        p.add(box(w - 0.45, 0.04, 0.05, seg=1), IRON, "gold", T(0, 0, z))
    arch = [(-(w / 2 - 0.25) * math.cos(math.pi * i / 16), 0, h - 0.95 + 0.55 * math.sin(math.pi * i / 16)) for i in range(17)]
    p.add(tube(arch, 0.025, 5), c, "gold")
    for sx in (-1, 1):
        for k in range(2):
            p.add(scroll(0.18, 1.4, 12, 0.018), c, "gold", T(sx * (0.4 + k * 0.6), 0, 1.0) @ S(sx, 1, 1))
    p.add(slab(oval_outline(0.5, 0.5, 16), 0.04), c, "gold", T(0, 0, h - 0.95))
    heart_crest(p, 0, 0.03, h - 0.72, 0.3, ROSE)


def stone_steps(p, size, c):
    w = 4.0
    for k in range(6):
        p.add(box(w, 3.0 - k * 0.5, 0.3, bevel=0.03), c if k % 2 == 0 else lighter(c, 0.08), "matte", T(0, -k * 0.25, 0.15 + k * 0.3))
    for sx in (-1, 1):
        p.add(tube([(sx * (w / 2 - 0.1), 1.4, 0.4), (sx * (w / 2 - 0.1), -1.4, 1.9)], 0.06, 6), PEARL, "pearl")
        p.add(sphere(0.12, 8, 6), GOLD, "gold", T(sx * (w / 2 - 0.1), 1.4, 0.45))


# ------------------------------------------------------------ art


ARTS = [
    [CREAM, SOFT_BLUE, (0.66, 0.85, 0.7), (1.0, 0.75, 0.85), ROSE],
    [CREAM, (1.0, 0.82, 0.75), (0.72, 0.88, 0.75), LILAC],
    [CREAM, PERI, (0.6, 0.8, 0.7), BUTTER, (1.0, 0.7, 0.8)],
]


def painting_large(p, size, c):
    picture(p, 2.6, 1.8, ARTS[0], c, 0.1, rng=random.Random(1))


def painting_medium(p, size, c):
    picture(p, 1.4, 1.0, ARTS[1], c, 0.08, rng=random.Random(2))


def painting_small(p, size, c):
    picture(p, 0.7, 0.5, ARTS[2], c, 0.06, oval=True, rng=random.Random(3))


def portrait_masked(p, size, c):
    w, h = 1.2, 1.6
    picture(p, w, h, [mix(LILAC, CREAM, 0.5), SOFT_BLUE, (0.7, 0.62, 0.78)], c, 0.08, rng=random.Random(4))
    y = 0.03
    # a masked fae noble: shoulders, head, gold mask (canon: the court is masked)
    p.add(lathe([(0, 0), (0.42, 0), (0.4, 0.2), (0.2, 0.35), (0, 0.38)], 12), (0.45, 0.65, 0.5), "satin", T(0, y, 0.15) @ S(1, 0.1, 1))
    p.add(sphere(0.17, 10, 8), (0.98, 0.84, 0.76), "satin", T(0, y + 0.02, 0.75) @ S(0.85, 0.15, 1.05))
    p.add(sphere(0.2, 10, 8), (0.86, 0.66, 0.42), "satin", T(0, y + 0.01, 0.84) @ S(1.0, 0.12, 0.9))
    mask = [(-0.2, 0.0), (-0.08, -0.03), (0, 0.0), (0.08, -0.03), (0.2, 0.0), (0.24, 0.07), (0.12, 0.09), (0.0, 0.05), (-0.12, 0.09), (-0.24, 0.07)]
    p.add(slab(mask, 0.03), c, "gold", T(0, y + 0.05, 0.77))
    for sx in (-1, 1):
        p.add(petal(0.14, 0.06, cup=0.1, curl=0.3), c, "gold", T(sx * 0.2, y + 0.05, 0.84) @ R("Y", -90 + sx * 60) @ R("X", 90))


def tapestry_roses(p, size, c):
    w, h = 3.0, 2.4
    p.add(cyl(0.03, w + 0.3, 6), GOLD, "gold", T(-w / 2 - 0.15, 0.04, h - 0.05) @ R("Y", 90))
    for sx in (-1, 1):
        p.add(sphere(0.06, 8, 6), GOLD, "gold", T(sx * (w / 2 + 0.15), 0.04, h - 0.05))
    cloth = box(w, 0.03, h - 0.2, seg=1)
    for v in cloth.verts:
        v.co.y += 0.02 * math.sin(v.co.x * 6)
    p.add(cloth, lighter(c, 0.35), "fabric", T(0, 0, (h - 0.2) / 2 + 0.05))
    p.add(box(w - 0.3, 0.035, h - 0.5, seg=1), mix(SOFT_BLUE, CREAM, 0.3), "fabric", T(0, 0, h / 2))
    rng = random.Random(21)
    for i in range(7):
        x = rng.uniform(-w * 0.35, w * 0.35)
        z = rng.uniform(0.4, h - 0.5)
        bloom(p, (x, 0.03, z), 0.12, c if i % 2 else ROSE, 2, 5, rng, tilt=R("X", -90) @ S(1, 1, 0.3))
        p.add(leaf(0.2, 0.1), LEAF, "leaf", T(x + 0.08, 0.035, z - 0.1) @ R("X", -90) @ R("Z", rng.uniform(0, 360)) @ S(1, 1, 0.3))
    for k in range(int(w / 0.15)):
        p.add(cyl(0.012, 0.12, 4, 0.02), GOLD, "gold", T(-w / 2 + 0.07 + k * 0.15, 0.0, -0.06))


def statue_maiden(p, size, c):
    p.add(box(0.9, 0.9, 0.5, bevel=0.04), c, "pearl", T(0, 0, 0.25))
    p.add(box(1.0, 1.0, 0.08, bevel=0.03), c, "pearl", T(0, 0, 0.5))
    # a dancing maiden in a flowing gown holding a garland aloft
    sk = lathe([(0, 0), (0.32, 0), (0.3, 0.1), (0.2, 0.55), (0.12, 0.85), (0.1, 0.9)], 14)
    for v in sk.verts:
        a = math.atan2(v.co.y, v.co.x)
        v.co.x += 0.04 * math.sin(a * 5) * (1 - v.co.z)
    p.add(sk, c, "pearl", T(0, 0, 0.54))
    p.add(lathe([(0.1, 0), (0.12, 0.15), (0.13, 0.3), (0.06, 0.38), (0, 0.4)], 10), c, "pearl", T(0, 0, 1.44) @ S(1, 0.75, 1))
    p.add(sphere(0.1, 10, 8), c, "pearl", T(0, 0.01, 1.95) @ S(0.9, 0.9, 1.05))
    p.add(sphere(0.11, 8, 6), c, "pearl", T(0, -0.04, 2.0) @ S(1, 0.9, 0.8))
    p.add(tube([(-0.12, 0, 1.78), (-0.25, 0.02, 1.9), (-0.22, 0.02, 2.12)], 0.035, 6), c, "pearl")
    p.add(tube([(0.12, 0, 1.78), (0.24, 0.05, 1.7), (0.3, 0.12, 1.55)], 0.035, 6), c, "pearl")
    rng = random.Random(31)
    garland = [(-0.22 + 0.5 * i / 6, 0.05, 2.12 - 0.5 * math.sin(math.pi * i / 6) * 0.6 - 0.1 * i / 6) for i in range(7)]
    p.add(tube(garland, 0.02, 4), LEAF_DARK, "leaf")
    for i, (x, y, z) in enumerate(garland):
        bloom(p, (x, y + 0.03, z), 0.05, ROSE if i % 2 else BLUSH, 2, 5, rng, tilt=R("X", -60))
    p.add(torus(0.1, 0.012, 10, 4), GOLD, "gold", T(0, -0.02, 2.06))


def statue_stag(p, size, c):
    p.add(box(1.6, 0.8, 0.4, bevel=0.04), c, "pearl", T(0, 0, 0.2))
    body = tube([(-0.45, 0, 1.0), (0.0, 0, 1.05), (0.4, 0, 1.08)], [0.2, 0.24, 0.2], 10)
    p.add(body, c, "pearl")
    for sx, sy in ((-0.38, -0.12), (-0.38, 0.12), (0.35, -0.12), (0.35, 0.12)):
        p.add(tube([(sx, sy, 0.95), (sx, sy, 0.6), (sx + 0.02, sy, 0.4)], [0.07, 0.045, 0.035], 6), c, "pearl")
    p.add(tube([(0.42, 0, 1.12), (0.55, 0, 1.4), (0.6, 0, 1.48)], [0.12, 0.08, 0.07], 8), c, "pearl")
    p.add(tube([(0.58, 0, 1.5), (0.78, 0, 1.42)], [0.08, 0.04], 8), c, "pearl")
    for sy in (-1, 1):
        ant = [(0.6, sy * 0.05, 1.56), (0.55, sy * 0.15, 1.75), (0.45, sy * 0.28, 1.88), (0.5, sy * 0.38, 2.0)]
        p.add(tube(ant, [0.025, 0.02, 0.016, 0.01], 5), GOLD, "gold")
        p.add(tube([ant[1], (0.68, sy * 0.2, 1.88)], 0.012, 4), GOLD, "gold")
        p.add(tube([ant[2], (0.35, sy * 0.4, 1.98)], 0.01, 4), GOLD, "gold")
        p.add(petal(0.1, 0.05, cup=0.2), c, "pearl", T(0.6, sy * 0.06, 1.55) @ R("Z", sy * 70) @ R("Y", -30))
    rng = random.Random(41)
    garland = [(0.5, -0.18 + 0.36 * i / 5, 1.25 - 0.08 * math.sin(math.pi * i / 5)) for i in range(6)]
    for i, (x, y, z) in enumerate(garland):
        bloom(p, (x, y, z), 0.05, ROSE if i % 2 else BUTTER, 2, 5, rng, tilt=R("Y", 70))


def bust_pedestal(p, size, c):
    p.add(lathe([(0.22, 0), (0.25, 0.06), (0.18, 0.15), (0.14, 0.3), (0.12, 0.9), (0.15, 1.0), (0.2, 1.05), (0.2, 1.1), (0, 1.1)], 12), c, "pearl")
    p.add(lathe([(0.0, 0), (0.18, 0), (0.2, 0.12), (0.12, 0.2), (0.06, 0.24), (0, 0.26)], 12), c, "pearl", T(0, 0, 1.1) @ S(1.2, 0.7, 1))
    p.add(cyl(0.05, 0.08, 8), c, "pearl", T(0, 0, 1.34))
    p.add(sphere(0.11, 10, 8), c, "pearl", T(0, 0.01, 1.48) @ S(0.85, 0.95, 1.1))
    p.add(torus(0.1, 0.018, 12, 4), ROSE, "fabric", T(0, 0, 1.55))
    rng = random.Random(51)
    for i in range(5):
        a = 2 * math.pi * i / 5
        bloom(p, (0.1 * math.cos(a), 0.1 * math.sin(a), 1.56), 0.03, ROSE if i % 2 else BLUSH, 2, 5, rng)
    p.add(torus(0.21, 0.012, 14, 4), GOLD, "gold", T(0, 0, 1.06))


# ------------------------------------------------------------ decor


def vase_roses(p, size, c):
    rng = random.Random(61)
    p.add(lathe([(0, 0), (0.08, 0), (0.12, 0.08), (0.13, 0.2), (0.07, 0.36), (0.06, 0.4), (0.09, 0.44)], 12), BLUSH, "pearl")
    p.add(torus(0.085, 0.01, 12, 4), GOLD, "gold", T(0, 0, 0.43))
    flower_spray(p, 0, 0, 0.6, 0.14, 7, [c, lighter(c, 0.3), ROSE], rng, 0.06)


def vase_tall(p, size, c):
    p.add(lathe([(0, 0), (0.12, 0), (0.14, 0.05), (0.08, 0.12), (0.18, 0.5), (0.2, 0.8), (0.1, 1.05), (0.08, 1.15), (0.13, 1.28)], 14), c, "pearl")
    for z in (0.06, 0.8, 1.26):
        p.add(torus(0.12 if z < 0.5 else (0.19 if z < 1 else 0.12), 0.014, 14, 4), GOLD, "gold", T(0, 0, z))
    rng = random.Random(71)
    for i in range(4):
        a = 2 * math.pi * i / 4
        bloom(p, (0.19 * math.cos(a), 0.19 * math.sin(a), 0.6), 0.06, ROSE if i % 2 else WHITE, 2, 5, rng,
              tilt=R("Z", math.degrees(a)) @ R("Y", 85))


def urn_flowers(p, size, c):
    p.add(lathe([(0, 0), (0.3, 0), (0.3, 0.1), (0.12, 0.18), (0.1, 0.35), (0.3, 0.45), (0.38, 0.62), (0.42, 0.68), (0.35, 0.68)], 14), c, "pearl")
    rng = random.Random(81)
    foliage_ball(p, 0, 0, 0.8, 0.28, LEAF, rng, 5)
    flower_spray(p, 0, 0, 0.85, 0.25, 8, [ROSE, BLUSH, LILAC, BUTTER], rng, 0.07, stems=False)


def potted_palm(p, size, c):
    pot(p, 0.3, 0.5, BLUSH, "pearl")
    rng = random.Random(91)
    p.add(tube([(0, 0, 0.45), (0.02, 0.0, 1.3), (0.0, 0.02, 1.6)], [0.06, 0.05, 0.04], 6), BARK, "matte")
    for i in range(9):
        a = 2 * math.pi * i / 9 + rng.uniform(-0.1, 0.1)
        L = rng.uniform(0.6, 0.85)
        frond = [(0, 0, 1.6), (L * 0.45 * math.cos(a), L * 0.45 * math.sin(a), 1.75), (L * math.cos(a), L * math.sin(a), 1.5 - rng.uniform(0, 0.2))]
        p.add(tube(frond, [0.012, 0.01, 0.004], 3), LEAF_DARK, "leaf")
        for k in range(4):
            t = 0.25 + k * 0.2
            x, y = L * t * math.cos(a), L * t * math.sin(a)
            z = 1.6 + 0.15 * math.sin(math.pi * t) - 0.1 * t
            for s_ in (-1, 1):
                p.add(leaf(0.22 * (1.2 - t), 0.06), LEAF, "leaf", T(x, y, z) @ R("Z", math.degrees(a) + s_ * 70) @ R("Y", 35))


def potted_roses(p, size, c):
    pot(p, 0.22, 0.35, MINT, "pearl")
    rng = random.Random(101)
    foliage_ball(p, 0, 0, 0.62, 0.22, LEAF, rng, 5)
    rose_cluster(p, 0, 0, 0.72, 0.2, 7, c, rng, 0.065, False)


def flower_garland(p, size, c):
    rng = random.Random(111)
    pts = [(-1.5 + 3.0 * i / 12, 0.0, 0.4 - 0.32 * math.sin(math.pi * i / 12)) for i in range(13)]
    p.add(tube(pts, 0.05, 6), LEAF, "leaf")
    for i, (x, y, z) in enumerate(pts):
        bloom(p, (x, y + 0.05, z), 0.07, [ROSE, BLUSH, WHITE, LILAC][i % 4], 2, 5, rng, tilt=R("X", -70))
        if i % 2:
            p.add(leaf(0.13, 0.07), LEAF_DARK, "leaf", T(x, y + 0.04, z - 0.05) @ R("Z", 30 * i) @ R("X", -60))
    for x in (-1.5, 1.5):
        p.add(tube([(x, 0.03, 0.4), (x * 0.98, 0.04, 0.15), (x * 0.97, 0.04, 0.0)], [0.02, 0.025, 0.01], 5), ROSE, "fabric")


def mirror_gilt(p, size, c):
    mirror_panel(p, 1.0, 1.55, 0.05, 0, "arch", c, depth=0.04, fw=0.06)
    crest(p, 0, 0.04, 1.62, 0.28, c)
    for sx in (-1, 1):
        p.add(scroll(0.15, 1.3, 12, 0.025), c, "gold", T(sx * 0.48, 0.03, 0.15) @ S(sx, 1, 1))
        candle(p, sx * 0.56, 0.08, 0.5, 0.12, 0.02)


def clock_grandfather(p, size, c):
    p.add(box(0.6, 0.45, 0.35, bevel=0.03), c, "satin", T(0, 0, 0.175))
    p.add(box(0.46, 0.36, 1.15, bevel=0.025), c, "satin", T(0, 0, 0.92))
    p.add(slab(arched_outline(0.3, 0.9, 8, 0.15), 0.01), (0.9, 0.95, 1.0, 0.3), "glass", T(0, 0.185, 0.45))
    p.add(lathe([(0, 0), (0.08, 0.0), (0.08, 0.015), (0, 0.015)], 12), GOLD, "gold", T(0, 0.16, 0.6) @ R("X", 90))
    p.add(cyl(0.008, 0.45, 4), GOLD, "gold", T(0, 0.16, 0.62))
    p.add(box(0.58, 0.44, 0.6, bevel=0.03), c, "satin", T(0, 0, 1.8))
    p.add(lathe([(0, 0), (0.21, 0), (0.21, 0.01), (0, 0.01)], 20), CREAM, "pearl", T(0, 0.225, 1.8) @ R("X", -90))
    p.add(torus(0.21, 0.018, 20, 4), GOLD, "gold", T(0, 0.23, 1.8) @ R("X", 90))
    for k in range(12):
        a = 2 * math.pi * k / 12
        p.add(box(0.012, 0.004, 0.035, seg=1), OAK_DARK, "matte", T(0.17 * math.cos(a), 0.238, 1.8 + 0.17 * math.sin(a)) @ R("Y", -math.degrees(a) + 90))
    p.add(box(0.012, 0.004, 0.12, seg=1), GOLD_DEEP, "gold", T(0.0, 0.24, 1.85))
    p.add(box(0.1, 0.004, 0.012, seg=1), GOLD_DEEP, "gold", T(0.04, 0.24, 1.8))
    p.add(slab(arched_outline(0.6, 0.25, 10, 0.22), 0.4), c, "satin", T(0, 0, 2.1))
    crest(p, 0, 0.21, 2.32, 0.14)
    for sx in (-1, 1):
        p.add(lathe([(0.025, 0), (0.035, 0.05), (0, 0.12)], 8), GOLD, "gold", T(sx * 0.26, 0.1, 2.1))


def globe_stand(p, size, c):
    for i in range(3):
        a = math.radians(90 + 120 * i)
        p.add(tube([(0, 0, 0.55), (0.2 * math.cos(a), 0.2 * math.sin(a), 0.3), (0.3 * math.cos(a), 0.3 * math.sin(a), 0.0)], [0.025, 0.03, 0.025], 6), c, "satin")
    p.add(torus(0.22, 0.015, 16, 4), c, "satin", T(0, 0, 0.3))
    p.add(lathe([(0.04, 0), (0.06, 0.1), (0.04, 0.25)], 8), c, "satin", T(0, 0, 0.45))
    g = sphere(0.28, 16, 10)
    p.add(g, mix(SOFT_BLUE, WATERC, 0.5), "satin", T(0, 0, 0.92) @ R("Y", 23))
    rng = random.Random(121)
    for k in range(6):
        a = rng.uniform(0, 360)
        e = rng.uniform(-50, 50)
        p.add(sphere(0.1, 6, 4), (0.75, 0.88, 0.62) if k % 2 else (1.0, 0.86, 0.7), "satin",
              T(0, 0, 0.92) @ R("Y", 23) @ R("Z", a) @ R("Y", e) @ T(0.24, 0, 0) @ S(0.25, 1, 0.8))
    p.add(torus(0.31, 0.015, 24, 4), GOLD, "gold", T(0, 0, 0.92) @ R("X", 90) @ R("Y", 23))


def birdcage_gilt(p, size, c):
    p.add(lathe([(0, 0), (0.18, 0), (0.18, 0.04), (0.04, 0.1), (0.03, 0.6), (0.06, 0.65)], 10), c, "gold")
    p.add(lathe([(0, 0), (0.22, 0), (0.22, 0.04), (0, 0.04)], 14), c, "gold", T(0, 0, 0.65))
    for i in range(14):
        a = 2 * math.pi * i / 14
        pts = [(0.21 * math.cos(a) * math.cos(t), 0.21 * math.sin(a) * math.cos(t), 0.69 + 0.55 * math.sin(t) + 0.0) for t in [k * math.pi / 2 / 6 for k in range(7)]]
        pts = [(0.21 * math.cos(a), 0.21 * math.sin(a), 0.69)] + [(x, y, z + 0.25) for x, y, z in pts]
        p.add(tube(pts, 0.005, 3), c, "gold")
    p.add(torus(0.21, 0.008, 14, 3), c, "gold", T(0, 0, 0.94))
    p.add(torus(0.035, 0.008, 8, 3), c, "gold", T(0, 0, 1.55) @ R("X", 90))
    # a little pastel songbird on its perch
    p.add(cyl(0.006, 0.36, 4), c, "gold", T(-0.18, 0, 0.9) @ R("Y", 90))
    p.add(sphere(0.06, 10, 6), PERI, "satin", T(0, 0, 0.97) @ S(1.2, 0.9, 1))
    p.add(sphere(0.045, 8, 6), PERI, "satin", T(0.06, 0, 1.04))
    p.add(sphere(0.045, 8, 5), BLUSH, "satin", T(0.02, 0, 0.95) @ S(0.9, 0.8, 0.9))
    p.add(lathe([(0.012, 0), (0, 0.035)], 5), BUTTER, "satin", T(0.1, 0, 1.04) @ R("Y", 90))
    for sy in (-1, 1):
        p.add(sphere(0.008, 5, 3), (0.1, 0.08, 0.15), "pearl", T(0.09, sy * 0.025, 1.055))
    rng = random.Random(131)
    rose_cluster(p, 0, 0, 1.25, 0.15, 4, ROSE, rng, 0.06)


def mask_display(p, size, c):
    w = 1.2
    p.add(box(w, 0.04, 0.7, bevel=0.015), mix(SOFT_BLUE, PEARL, 0.4), "satin", T(0, 0, 0.35))
    p.add(frame_ring([(-w / 2, 0), (w / 2, 0), (w / 2, 0.7), (-w / 2, 0.7)], 0.025, 0.04), c, "gold", T(0, 0.02, 0))
    cols = [(c, ROSE), (WHITE, LILAC), (PERI, c)]
    for i, (mc, fc) in enumerate(cols):
        x = -0.38 + i * 0.38
        mask = [(-0.15, 0.0), (-0.06, -0.025), (0, 0.0), (0.06, -0.025), (0.15, 0.0), (0.18, 0.06), (0.09, 0.08), (0.0, 0.045), (-0.09, 0.08), (-0.18, 0.06)]
        p.add(slab(mask, 0.025), mc, "gold" if mc == c else "pearl", T(x, 0.04, 0.32))
        for sx in (-1, 1):
            p.add(sphere(0.022, 6, 4), (0.32, 0.24, 0.3), "matte", T(x + sx * 0.075, 0.05, 0.35) @ S(1.3, 0.3, 0.8))
        for k in range(3):
            p.add(petal(0.18, 0.05, cup=0.1, curl=0.3), fc, "fabric", T(x + 0.15, 0.04, 0.38) @ R("Y", -60 + k * 25) @ R("X", 90))
    crest(p, 0, 0.03, 0.72, 0.16, c)


def altar_marble(p, size, c):
    p.add(box(2.0, 0.9, 0.12, bevel=0.03), c, "pearl", T(0, 0, 0.06))
    p.add(box(1.8, 0.7, 0.85, bevel=0.03), c, "pearl", T(0, 0, 0.55))
    p.add(box(2.0, 0.9, 0.1, bevel=0.03), lighter(c, 0.05), "pearl", T(0, 0, 1.03))
    for x in (-0.55, 0.0, 0.55):
        p.add(frame_ring(arched_outline(0.4, 0.55, 8, 0.15), 0.015, 0.02), GOLD, "gold", T(x, 0.36, 0.2))
    p.add(box(1.9, 0.6, 0.01, seg=1), CREAM, "fabric", T(0, 0, 1.085))
    p.add(box(0.6, 0.02, 0.4, seg=1), BLUSH, "fabric", T(0, 0.31, 0.9))
    _candelabra_at(p, -0.7, 0, 1.08, 0.4)
    _candelabra_at(p, 0.7, 0, 1.08, 0.4)
    rng = random.Random(141)
    p.add(lathe([(0.04, 0), (0.1, 0.08), (0.06, 0.18), (0.1, 0.22)], 10), GOLD, "gold", T(0, -0.05, 1.08))
    rose_cluster(p, 0, -0.05, 1.38, 0.1, 5, WHITE, rng, 0.06)


def candle_bank(p, size, c):
    p.add(box(1.4, 0.4, 0.7, bevel=0.03), PEARL, "pearl", T(0, 0, 0.35))
    for k in range(3):
        p.add(box(1.4 - k * 0.15, 0.4 - k * 0.1, 0.08, bevel=0.015), c, "gold", T(0, -k * 0.05, 0.74 + k * 0.08))
    rng = random.Random(151)
    for k in range(3):
        n = 8 - k * 2
        for i in range(n):
            x = -0.6 + k * 0.075 + i * (1.2 - k * 0.15) / max(n - 1, 1)
            candle(p, x, -k * 0.05 + rng.uniform(-0.05, 0.05), 0.78 + k * 0.08, rng.uniform(0.06, 0.16), 0.022)


def pew(p, size, c):
    w = 3.0
    p.add(box(w, 0.42, 0.05, bevel=0.012), c, "satin", T(0, 0.06, 0.45))
    p.add(cushion(w - 0.1, 0.38, 0.05, 0.3), BLUSH, "fabric", T(0, 0.06, 0.5))
    p.add(box(w, 0.04, 0.5, bevel=0.012), c, "satin", T(0, -0.2, 0.75) @ R("X", -8))
    for sx in (-1, 1):
        p.add(slab(arched_outline(0.55, 1.0, 8, 0.2), 0.05), c, "satin", T(sx * (w / 2 - 0.03), 0, 0) @ R("Z", 90))
        p.add(scroll(0.1, 1.2, 10, 0.015), GOLD, "gold", T(sx * (w / 2 + 0.01), 0.0, 0.85) @ R("Z", 90))
    p.add(box(w - 0.1, 0.03, 0.04, seg=1), c, "satin", T(0, 0.15, 0.1))


# ------------------------------------------------------------ library


def bookcase_tall(p, size, c):
    w, h, d = 2.0, 3.2, 0.5
    shelves = [0.1 + k * 0.6 for k in range(5)]
    shelf_unit(p, w, h, d, c, shelves, "satin", back=mix(SOFT_BLUE, PEARL, 0.35), top_crest=True)
    rng = random.Random(161)
    for z in shelves:
        book_row(p, -w / 2 + 0.08, w / 2 - 0.08, 0.0, z + 0.015, 0.3, 0.42, rng)
    gilt_edge(p, w + 0.06, d + 0.06, h - 0.06, 0.012)


def bookcase_low(p, size, c):
    w, h, d = 1.6, 1.2, 0.45
    shelves = [0.1, 0.6]
    shelf_unit(p, w, h, d, c, shelves, "satin", back=mix(SOFT_BLUE, PEARL, 0.35))
    rng = random.Random(171)
    for z in shelves:
        book_row(p, -w / 2 + 0.08, w / 2 - 0.08, 0.0, z + 0.015, 0.28, 0.4, rng)
    p.add(lathe([(0.04, 0), (0.08, 0.06), (0.04, 0.18), (0.06, 0.22)], 10), BLUSH, "pearl", T(0.5, 0, h))
    rose_cluster(p, 0.5, 0, h + 0.28, 0.05, 3, ROSE, rng, 0.05, False)
    p.add(sphere(0.07, 8, 6), PERI, "pearl", T(-0.5, 0, h + 0.07))


def library_ladder(p, size, c):
    for sx in (-1, 1):
        p.add(tube([(sx * 0.25, 0.15, 0.0), (sx * 0.22, -0.15, 3.0)], 0.025, 6), c, "satin")
    for k in range(9):
        t = (k + 0.7) / 10
        p.add(cyl(0.018, 0.48, 6), c, "satin", T(-0.24, 0.15 - 0.3 * t, 3.0 * t) @ R("Y", 90))
    p.add(tube([(-0.3, -0.18, 2.95), (0.3, -0.18, 2.95)], 0.02, 6), GOLD, "gold")
    for sx in (-1, 1):
        p.add(torus(0.04, 0.01, 8, 3), GOLD, "gold", T(sx * 0.24, -0.18, 2.95) @ R("Y", 90))
        p.add(lathe([(0.035, 0), (0.035, 0.03), (0, 0.04)], 8), GOLD, "gold", T(sx * 0.25, 0.15, 0.0))


def reading_lectern(p, size, c):
    p.add(lathe([(0, 0), (0.25, 0), (0.25, 0.04), (0.06, 0.1), (0.05, 0.9), (0.08, 0.95)], 10), c, "satin")
    for i in range(3):
        a = math.radians(90 + 120 * i)
        p.add(scroll(0.08, 1.0, 8, 0.012), GOLD, "gold", T(0.12 * math.cos(a), 0.12 * math.sin(a), 0.08) @ R("Z", math.degrees(a) + 90))
    top = T(0, 0, 1.05) @ R("X", 25)
    p.add(box(0.55, 0.42, 0.04, bevel=0.012), c, "satin", top)
    p.add(box(0.55, 0.03, 0.05, seg=1), c, "satin", top @ T(0, 0.2, 0.04))
    # an open book with gilded edge and a ribbon
    for sx in (-1, 1):
        pg = box(0.24, 0.32, 0.03, bevel=0.01)
        for v in pg.verts:
            v.co.z += 0.03 * math.sin(math.pi * (0.5 + sx * v.co.x / 0.24))
        p.add(pg, CANVAS, "matte", top @ T(sx * 0.125, 0, 0.04))
    p.add(box(0.52, 0.34, 0.015, seg=1), ROSE, "satin", top @ T(0, 0, 0.025))
    p.add(tube([(0, 0.1, 0.07), (0, 0.2, 0.02), (0.02, 0.24, -0.12)], 0.008, 3), PERI, "fabric", top)


def book_stack(p, size, c):
    rng = random.Random(181)
    z = 0
    for i in range(5):
        h = rng.uniform(0.045, 0.07)
        col = BOOKS[(i * 3) % len(BOOKS)]
        p.add(box(0.36 - i * 0.02, 0.26 - i * 0.01, h, bevel=0.006, seg=1), col, "satin", T(rng.uniform(-0.02, 0.02), 0, z + h / 2) @ R("Z", rng.uniform(-12, 12)), smooth=False)
        p.add(box(0.34 - i * 0.02, 0.005, h * 0.7, seg=1), CANVAS, "matte", T(0, 0.13 - i * 0.005, z + h / 2))
        z += h
    p.add(sphere(0.04, 8, 5), ROSE, "fabric", T(0.05, 0, z + 0.03) @ S(1, 1, 0.6))


def map_table(p, size, c):
    w, h, d = 2.4, 0.9, 1.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(turned_leg(h - 0.05, 0.06, 8), c, "satin", T(sx * (w / 2 - 0.12), sy * (d / 2 - 0.12), 0))
    p.add(box(w - 0.1, d - 0.1, 0.12, bevel=0.02), c, "satin", T(0, 0, h - 0.11))
    p.add(box(w, d, 0.05, bevel=0.02), lighter(c, 0.1), "satin", T(0, 0, h - 0.025))
    gilt_edge(p, w, d, h - 0.05, 0.012)
    # the map of Prythian, weighted with a candlestick and a compass
    mp = box(1.6, 1.1, 0.008, seg=1)
    for v in mp.verts:
        v.co.z += 0.01 * math.sin(v.co.x * 4)
    p.add(mp, CANVAS, "matte", T(0, 0, h + 0.01))
    rng = random.Random(191)
    for col, (x, y) in ((ROSE, (-0.3, 0.2)), ((0.7, 0.88, 0.7), (0.2, -0.1)), (PERI, (0.45, 0.25)), (BUTTER, (-0.45, -0.25))):
        p.add(sphere(0.18, 8, 4), col, "matte", T(x, y, h + 0.012) @ S(1.2, 0.8, 0.02))
    p.add(box(1.5, 0.02, 0.006, seg=1), (0.55, 0.45, 0.5), "matte", T(0, 0.02, h + 0.016))   # the wall
    candle(p, -0.75, 0.48, h, 0.15, 0.025)
    p.add(lathe([(0, 0), (0.06, 0), (0.06, 0.02), (0, 0.02)], 12), GOLD, "gold", T(0.7, -0.45, h))
    for k, (x, y, col) in enumerate(((0.1, 0.1, ROSE), (-0.2, -0.3, PERI), (0.5, 0.0, MINT))):
        p.add(lathe([(0, 0), (0.025, 0), (0.02, 0.05), (0.03, 0.07), (0, 0.08)], 8), col, "satin", T(x, y, h + 0.01))


def map_wall(p, size, c):
    w, h = 2.6, 1.8
    for z in (0.0, h):
        p.add(cyl(0.035, w + 0.2, 8), GOLD, "gold", T(-w / 2 - 0.1, 0.02, z) @ R("Y", 90))
    cloth = box(w, 0.01, h, seg=1)
    p.add(cloth, c, "matte", T(0, 0, h / 2))
    rng = random.Random(201)
    for col in (ROSE, (0.7, 0.88, 0.7), PERI, BUTTER, LILAC, MINT, (1.0, 0.82, 0.72)):
        x = rng.uniform(-w * 0.35, w * 0.35)
        z = rng.uniform(h * 0.2, h * 0.75)
        p.add(sphere(0.3, 8, 4), col, "matte", T(x, 0.008, z) @ S(rng.uniform(0.8, 1.4), 0.02, rng.uniform(0.6, 1.0)))
    p.add(box(w * 0.9, 0.012, 0.025, seg=1), (0.55, 0.45, 0.5), "matte", T(0, 0.012, h * 0.2))
    p.add(lathe([(0, 0), (0.15, 0), (0.15, 0.01), (0, 0.01)], 16), GOLD, "gold", T(w * 0.38, 0.015, h * 0.2) @ R("X", -90))
    for k in range(4):
        p.add(box(0.012, 0.012, 0.13, seg=1), GOLD_DEEP, "gold", T(w * 0.38, 0.02, h * 0.2) @ R("Y", 45 * k))


def scroll_rack(p, size, c):
    w, h, d = 1.2, 1.6, 0.4
    for sx in (-1, 1):
        p.add(box(0.05, d, h, bevel=0.01), c, "satin", T(sx * (w / 2 - 0.025), 0, h / 2))
    rng = random.Random(211)
    for row in range(5):
        z = 0.15 + row * 0.3
        p.add(box(w - 0.06, d, 0.02, seg=1), c, "satin", T(0, 0, z - 0.02))
        for k in range(5):
            x = -w / 2 + 0.16 + k * 0.22
            p.add(cyl(0.05, d * 0.95, 8), CANVAS, "matte", T(x, -d / 2 + 0.01, z + 0.05) @ R("X", -90))
            p.add(torus(0.05, 0.008, 8, 3), BOOKS[(row + k) % len(BOOKS)], "fabric", T(x, d / 2 - 0.08, z + 0.05) @ R("X", 90))
    p.add(box(w + 0.06, d + 0.04, 0.05, bevel=0.015), c, "satin", T(0, 0, h))


def inkstand(p, size, c):
    p.add(box(0.3, 0.2, 0.02, bevel=0.006), c, "gold", T(0, 0, 0.01))
    for sx in (-1, 1):
        p.add(lathe([(0, 0), (0.035, 0), (0.04, 0.04), (0.02, 0.06), (0, 0.06)], 10), PERI if sx < 0 else ROSE, "glass", T(sx * 0.08, 0, 0.02))
        p.add(sphere(0.012, 6, 4), c, "gold", T(sx * 0.08, 0, 0.085))
    p.add(tube([(0.0, 0.03, 0.02), (0.02, -0.02, 0.08), (0.06, -0.06, 0.12)], [0.003, 0.02, 0.004], 4), WHITE, "fabric")


# ------------------------------------------------------------ music & art room


def harp_gilt(p, size, c):
    # pillar, neck curve, soundboard; strings as thin glow-gold lines
    p.add(lathe([(0, 0), (0.22, 0), (0.24, 0.05), (0.2, 0.12), (0, 0.14)], 12), c, "gold", S(1, 0.8, 1))
    p.add(lathe([(0.04, 0), (0.035, 1.4), (0.05, 1.5), (0.04, 1.6)], 8), c, "gold", T(-0.25, 0, 0.12))
    neck = [(-0.25, 0, 1.72), (-0.05, 0, 1.75), (0.12, 0, 1.6), (0.25, 0, 1.55), (0.35, 0, 1.4)]
    p.add(tube(neck, [0.05, 0.045, 0.04, 0.04, 0.045], 6), c, "gold")
    sb = [(0.32, 0, 1.38), (0.15, 0, 0.8), (0.0, 0, 0.3), (-0.08, 0, 0.14)]
    p.add(tube(sb, [0.06, 0.08, 0.1, 0.08], 8), lighter(c, 0.15) if c != GOLD else BLUSH, "pearl", S(1, 0.7, 1))
    for k in range(10):
        t = (k + 0.5) / 10
        x0 = -0.25 + 0.08 + t * 0.5
        top = 1.72 - 0.25 * t * t + 0.05 * math.sin(t * 3)
        bot = 0.3 + (1.38 - 0.3) * t ** 1.4
        p.add(cyl(0.004, max(top - bot, 0.1), 3), (1.0, 0.96, 0.85), "glow", T(x0, 0, bot))
    crest(p, -0.25, 0.0, 1.78, 0.12, c)
    rng = random.Random(221)
    bloom(p, (-0.2, 0.04, 1.75), 0.06, ROSE, 2, 5, rng, tilt=R("X", -60))


def pianoforte(p, size, c):
    # a small rococo square piano: case, raised lid, keys, cabriole legs
    w, d = 1.6, 1.8
    cab_legs(p, w - 0.1, d * 0.55, 0.55, 0.04, GOLD)
    case = [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d * 0.1), (w * 0.2, d / 2), (-w / 2, d / 2)]
    body = slab([(x, y) for x, y in case], 0.3, 0.02)
    p.add(body, c, "pearl", T(0, 0, 0.72) @ R("X", 90))
    gilt_edge(p, w, d * 0.95, 0.85, 0.01)
    lid = slab([(x, y) for x, y in case], 0.03, 0.01)
    p.add(lid, lighter(c, 0.05), "pearl", T(-w / 2, 0, 0.88) @ R("Y", -35) @ T(w / 2, 0, 0) @ R("X", 90))
    p.add(cyl(0.012, 0.6, 4), GOLD, "gold", T(0.3, 0.0, 0.86) @ R("Y", -22))
    p.add(box(w - 0.1, 0.18, 0.05, seg=1), WHITE, "pearl", T(0, -d / 2 - 0.06, 0.74))
    for k in range(18):
        if k % 7 not in (2, 6):
            p.add(box(0.03, 0.1, 0.03, seg=1), (0.35, 0.28, 0.4), "satin", T(-w / 2 + 0.12 + k * 0.08, -d / 2 - 0.02, 0.77), smooth=False)
    p.add(slab(arched_outline(0.5, 0.3, 6, 0.1), 0.02), c, "pearl", T(0, -d / 2 + 0.05, 0.86) @ R("X", -10))
    rng = random.Random(231)
    for k in range(3):
        bloom(p, (0, 0, 0), 0.07, ROSE if k != 1 else LILAC, 2, 5, rng, tilt=T(-0.4 + 0.4 * k, -d / 2 - 0.0, 0.6) @ R("X", -90))
    p.add(cushion(0.6, 0.35, 0.08, 0.4), ROSE, "fabric", T(0, -d / 2 - 0.45, 0.48))
    cab_legs(p, 0.55, 0.3, 0.44, 0.025, GOLD)


def music_stand(p, size, c):
    for i in range(3):
        a = math.radians(90 + 120 * i)
        p.add(tube([(0, 0, 0.3), (0.2 * math.cos(a), 0.2 * math.sin(a), 0.0)], 0.015, 5), c, "gold")
    p.add(cyl(0.015, 0.85, 6), c, "gold", T(0, 0, 0.1))
    m = T(0, 0, 1.0) @ R("X", 20)
    lyre = [(-0.22, 0), (0.22, 0), (0.25, 0.15), (0.15, 0.3), (0.0, 0.25), (-0.15, 0.3), (-0.25, 0.15)]
    p.add(frame_ring(lyre, 0.012, 0.02), c, "gold", m)
    p.add(box(0.48, 0.02, 0.03, seg=1), c, "gold", m @ T(0, 0.02, 0.0))
    p.add(box(0.42, 0.01, 0.3, seg=1), CANVAS, "matte", m @ T(0, 0.025, 0.15))
    for k in range(5):
        p.add(box(0.36, 0.004, 0.004, seg=1), (0.5, 0.4, 0.55), "matte", m @ T(0, 0.032, 0.06 + k * 0.05))


def lute_on_stand(p, size, c):
    p.add(tube([(-0.15, 0, 0.0), (0.0, -0.08, 0.35)], 0.015, 5), c, "satin")
    p.add(tube([(0.15, 0, 0.0), (0.0, -0.08, 0.35)], 0.015, 5), c, "satin")
    p.add(tube([(0.0, 0.15, 0.0), (0.0, -0.08, 0.35)], 0.015, 5), c, "satin")
    body = sphere(0.18, 12, 8)
    p.add(body, lighter(c, 0.1), "satin", T(0, 0.0, 0.3) @ R("X", -12) @ S(1, 0.6, 1.25))
    p.add(lathe([(0, 0), (0.06, 0), (0.06, 0.005), (0, 0.005)], 12), (0.35, 0.25, 0.3), "matte", T(0, 0.1, 0.33) @ R("X", -102))
    p.add(box(0.06, 0.03, 0.45, bevel=0.01), OAK_DARK, "satin", T(0, 0.04, 0.65) @ R("X", -12))
    p.add(box(0.07, 0.04, 0.12, bevel=0.01), OAK_DARK, "satin", T(0, -0.02, 0.92) @ R("X", 50))
    p.add(tube([(0, 0.12, 0.2), (0, 0.13, 0.4), (0.03, 0.15, 0.5), (0.1, 0.17, 0.4)], 0.01, 4), ROSE, "fabric")


def easel(p, size, c):
    for sx in (-1, 1):
        p.add(tube([(sx * 0.4, 0.2, 0.0), (sx * 0.08, 0.05, 1.85)], 0.025, 6), c, "satin")
    p.add(tube([(0, -0.5, 0.0), (0, 0.05, 1.7)], 0.022, 6), c, "satin")
    p.add(box(0.75, 0.08, 0.04, bevel=0.01), c, "satin", T(0, 0.2, 0.75))
    m = T(0, 0.2, 0.78) @ R("X", -12)
    p.add(box(0.68, 0.03, 0.85, seg=1), CANVAS, "matte", m @ T(0, 0, 0.43))
    rng = random.Random(241)
    p.add(box(0.6, 0.004, 0.35, seg=1), SOFT_BLUE, "matte", m @ T(0, 0.018, 0.65))
    p.add(box(0.6, 0.004, 0.2, seg=1), (0.72, 0.88, 0.72), "matte", m @ T(0, 0.018, 0.25))
    for k in range(4):
        p.add(sphere(0.05, 8, 5), [ROSE, BLUSH, LILAC, BUTTER][k], "matte", m @ T(-0.2 + 0.13 * k, 0.02, 0.35 + 0.05 * (k % 2)) @ S(1, 0.15, 1))
    # palette hooked on the ledge
    p.add(slab(oval_outline(0.3, 0.2, 10), 0.012), OAK, "satin", T(0.3, 0.26, 0.6) @ R("Y", 20))
    for k, col in enumerate([ROSE, PERI, MINT, BUTTER]):
        p.add(sphere(0.018, 6, 4), col, "satin", T(0.24 + k * 0.04, 0.27, 0.68 - 0.01 * k) @ S(1, 0.4, 1))


def canvas_stack(p, size, c):
    rng = random.Random(251)
    for k in range(4):
        w = 0.9 - k * 0.12
        h = 1.15 - k * 0.15
        m = T(-0.02 * k, 0.08 * k - 0.12, 0) @ R("X", -10)
        p.add(box(w, 0.03, h, bevel=0.006, seg=1), OAK if k == 0 else c, "satin", m @ T(0, 0, h / 2))
        if k:
            p.add(box(w * 0.85, 0.004, h * 0.5, seg=1), [SOFT_BLUE, BLUSH, MINT][k - 1], "matte", m @ T(0, 0.017, h * 0.65))
            p.add(sphere(0.08, 8, 5), [ROSE, LILAC, BUTTER][k - 1], "matte", m @ T(rng.uniform(-0.1, 0.1), 0.02, h * 0.4) @ S(1.4, 0.1, 1))


def paint_table(p, size, c):
    w, h, d = 1.2, 0.85, 0.7
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(turned_leg(h - 0.04, 0.03, 6, "taper"), c, "satin", T(sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), 0))
    p.add(box(w, d, 0.04, bevel=0.012), c, "satin", T(0, 0, h - 0.02))
    rng = random.Random(261)
    jars(p, -0.5, 0.1, 0.15, h, [ROSE, PERI, MINT, BUTTER, LILAC], rng, 0.12, glass=True)
    p.add(lathe([(0, 0), (0.05, 0), (0.05, 0.12), (0, 0.12)], 8), PERI, "glass", T(0.3, 0.15, h))
    for k in range(4):
        p.add(tube([(0.3, 0.15, h + 0.05), (0.3 + 0.03 * (k - 1.5), 0.15 + 0.02 * k, h + 0.28)], 0.006, 4), OAK, "satin")
        p.add(sphere(0.01, 5, 3), [ROSE, LILAC, BUTTER, MINT][k], "satin", T(0.3 + 0.03 * (k - 1.5), 0.15 + 0.02 * k, h + 0.29))
    p.add(slab(oval_outline(0.35, 0.25, 10), 0.012), OAK, "satin", T(0.0, -0.15, h + 0.005) @ R("X", 90))
    p.add(box(0.5, 0.35, 0.005, seg=1), CANVAS, "fabric", T(-0.25, -0.15, h + 0.003) @ R("Z", 10))


def pigment_jars(p, size, c):
    rng = random.Random(271)
    jars(p, -0.3, 0.3, 0.0, 0.0, [ROSE, PERI, MINT, BUTTER, LILAC, BLUSH], rng, 0.18, glass=True)
    for k in range(4):
        p.add(sphere(0.04, 8, 5), [ROSE, PERI, BUTTER, LILAC][k], "matte", T(-0.2 + k * 0.13, 0.1, 0.02) @ S(1, 1, 0.4))


# ------------------------------------------------------------ bath


def bathtub_clawfoot(p, size, c):
    tub = lathe([(0, 0.15), (0.3, 0.15), (0.42, 0.25), (0.45, 0.8), (0.48, 0.82), (0.4, 0.82), (0.38, 0.3), (0.0, 0.25)], 16, cap_top=False)
    for v in tub.verts:
        v.co.x *= 2.0
        if v.co.x < -0.3:              # raised slipper back
            v.co.z += (abs(v.co.x) - 0.3) * 0.25 * (v.co.z > 0.5)
    p.add(tub, c, "pearl")
    p.add(disc(0.39, 16, 0.62), WATERC, "water", S(2.0, 1, 1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            foot = lathe([(0.0, 0), (0.06, 0), (0.07, 0.04), (0.04, 0.12), (0.06, 0.2), (0.0, 0.22)], 8)
            p.add(foot, GOLD, "gold", T(sx * 0.6, sy * 0.25, 0))
    p.add(tube([(0.82, 0, 0.85), (0.86, 0, 1.05), (0.75, 0, 1.1), (0.72, 0, 1.02)], 0.02, 6), GOLD, "gold")
    rng = random.Random(281)
    for i in range(12):                 # bubbles and floating petals
        x, y = rng.uniform(-0.6, 0.6), rng.uniform(-0.25, 0.25)
        if i % 2:
            p.add(sphere(rng.uniform(0.04, 0.08), 8, 5), WHITE, "glass", T(x, y, 0.63))
        else:
            p.add(petal(0.06, 0.05, cup=0.2), ROSE, "fabric", T(x, y, 0.625) @ R("Z", rng.uniform(0, 360)))


def bath_sunken(p, size, c):
    w, d = 3.0, 2.4
    p.add(box(w, d, 0.02, seg=1), c, "water", T(0, 0, 0.06))
    rim = [(-w / 2, -d / 2, 0.08), (w / 2, -d / 2, 0.08), (w / 2, d / 2, 0.08), (-w / 2, d / 2, 0.08)]
    p.add(tube(rim, 0.06, 6, closed=True), MARBLE, "pearl")
    p.add(tube(rim, 0.07, 6, closed=True), GOLD, "gold", T(0, 0, -0.05) @ S(1.02, 1.02, 1))
    rng = random.Random(291)
    for i in range(20):
        x, y = rng.uniform(-w * 0.4, w * 0.4), rng.uniform(-d * 0.4, d * 0.4)
        p.add(petal(0.07, 0.06, cup=0.2), [ROSE, BLUSH, WHITE][i % 3], "fabric", T(x, y, 0.07) @ R("Z", rng.uniform(0, 360)))
    for k in range(4):
        p.add(sphere(0.05, 6, 4), (1.0, 0.95, 0.8), "glow", T(-w / 2 + 0.2 + k * 0.9, d / 2 - 0.1, 0.1))


def washstand(p, size, c):
    w, h, d = 0.8, 0.9, 0.5
    cab_legs(p, w - 0.04, d - 0.04, 0.72, 0.025, c, "pearl")
    p.add(box(w, d, 0.06, bevel=0.02), MARBLE, "pearl", T(0, 0, 0.75))
    p.add(box(w - 0.06, d - 0.06, 0.1, bevel=0.015), c, "pearl", T(0, 0, 0.67))
    p.add(lathe([(0, 0), (0.12, 0.0), (0.2, 0.08), (0.22, 0.1)], 14, cap_top=False), BLUSH, "pearl", T(0, 0.02, 0.78))
    p.add(lathe([(0, 0), (0.07, 0), (0.09, 0.08), (0.06, 0.2), (0.05, 0.26), (0.08, 0.3)], 12), BLUSH, "pearl", T(0, 0.02, 0.8))
    p.add(tube([(0.06, 0.02, 1.02), (0.13, 0.02, 0.98), (0.1, 0.02, 0.86)], 0.012, 5), GOLD, "gold")
    p.add(box(w - 0.1, 0.02, 0.06, seg=1), c, "pearl", T(0, d / 2 - 0.05, 0.3))
    p.add(box(0.3, 0.04, 0.3, bevel=0.01), WHITE, "fabric", T(w / 2 + 0.01, 0, 0.62) @ R("Z", 90))


def towel_rack(p, size, c):
    for sx in (-1, 1):
        p.add(lathe([(0.04, 0), (0.05, 0.03), (0.02, 0.1), (0.02, 1.1), (0.03, 1.15), (0, 1.2)], 8), c, "gold", T(sx * 0.37, 0, 0))
        p.add(tube([(sx * 0.37, -0.12, 0.01), (sx * 0.37, 0, 0.05), (sx * 0.37, 0.12, 0.01)], 0.015, 5), c, "gold")
    for z in (0.6, 1.0):
        p.add(cyl(0.012, 0.74, 6), c, "gold", T(-0.37, 0, z) @ R("Y", 90))
    for k, (z, col) in enumerate(((1.0, BLUSH), (0.6, MINT))):
        towel = box(0.5 - k * 0.1, 0.06, 0.55, bevel=0.02)
        for v in towel.verts:
            v.co.y += 0.03 * math.sin(v.co.z * 8)
        p.add(towel, col, "fabric", T(0.0 + k * 0.05, 0.0, z - 0.25))
        p.add(box(0.5 - k * 0.1, 0.065, 0.04, seg=1), lighter(col, 0.4), "fabric", T(0.0 + k * 0.05, 0, z - 0.45))


def soap_shelf(p, size, c):
    p.add(box(0.8, 0.25, 0.03, bevel=0.01), c, "pearl", T(0, 0, 0.3))
    p.add(box(0.8, 0.02, 0.6, bevel=0.01), c, "pearl", T(0, -0.12, 0.3))
    p.add(slab(arched_outline(0.8, 0.15, 8, 0.12), 0.02), c, "pearl", T(0, -0.12, 0.6))
    for sx in (-1, 1):
        p.add(scroll(0.1, 1.2, 10, 0.012), GOLD, "gold", T(sx * 0.35, 0.0, 0.25) @ S(sx, 1, 1) @ R("X", 90) @ R("Z", 90))
    rng = random.Random(301)
    soaps = [(ROSE, -0.28), (MINT, -0.12), (LILAC, 0.04)]
    for col, x in soaps:
        p.add(cushion(0.1, 0.07, 0.04, 0.4, 1), col, "satin", T(x, 0.02, 0.335))
    p.add(lathe([(0, 0), (0.04, 0), (0.05, 0.06), (0.02, 0.12), (0.02, 0.15), (0, 0.15)], 10), PERI, "glass", T(0.22, 0.0, 0.315))
    p.add(sphere(0.02, 6, 4), GOLD, "gold", T(0.22, 0, 0.47))
    p.add(sphere(0.035, 8, 5), BLUSH, "fabric", T(0.33, 0.02, 0.35))


# ------------------------------------------------------------ kitchen & service


def range_iron(p, size, c):
    w, h, d = 2.4, 1.2, 1.0
    p.add(box(w, d, 0.8, bevel=0.04), c, "satin", T(0, 0, 0.45))
    p.add(box(w + 0.05, d + 0.05, 0.05, bevel=0.02), lighter(c, 0.1), "gold", T(0, 0, 0.87))
    for k in range(3):
        x = -0.75 + k * 0.75
        p.add(box(0.55, 0.03, 0.4, bevel=0.015), darker(c, 0.1), "satin", T(x, d / 2 + 0.01, 0.4))
        p.add(cyl(0.012, 0.3, 6), COPPER, "gold", T(x - 0.15, d / 2 + 0.05, 0.65) @ R("Y", 90))
        p.add(slab(arched_outline(0.2, 0.15, 6, 0.08), 0.01), (1.0, 0.6, 0.4), "glow", T(x, d / 2 + 0.03, 0.25))
    for k in range(4):
        p.add(torus(0.16, 0.02, 14, 4), darker(c, 0.15), "satin", T(-0.8 + k * 0.53, 0, 0.9))
    p.add(box(w, 0.15, 0.3, bevel=0.02), c, "satin", T(0, -d / 2 + 0.08, 1.05))
    p.add(lathe([(0, 0), (0.2, 0), (0.2, 0.18), (0.18, 0.2)], 12, cap_top=False), COPPER, "gold", T(-0.8, 0, 0.9))
    p.add(lathe([(0, 0), (0.12, 0.0), (0.16, 0.08), (0.12, 0.14), (0.03, 0.18), (0.04, 0.2)], 12), COPPER, "gold", T(0.3, 0, 0.9))
    p.add(tube([(0.42, 0, 1.0), (0.55, 0, 1.1)], 0.018, 5), COPPER, "gold")
    for k in range(3):
        p.add(sphere(0.08, 6, 4), (0.96, 0.96, 1.0, 0.4), "glass", T(-0.8 + 0.05 * k, 0.02 * k, 1.15 + 0.12 * k))


def bread_oven(p, size, c):
    w, h, d = 1.8, 1.8, 1.4
    p.add(box(w, d, 0.8, bevel=0.04), c, "matte", T(0, 0, 0.4))
    dome = sphere(0.85, 14, 8)
    for v in dome.verts:
        if v.co.z < 0:
            v.co.z = 0
    p.add(dome, lighter(c, 0.05), "matte", T(0, 0, 0.8) @ S(1, 0.8, 1.15))
    mouth = arched_outline(0.6, 0.45, 8, 0.25)
    p.add(slab(mouth, 0.04), (1.0, 0.62, 0.4), "glow", T(0, 0.55, 0.85))
    p.add(frame_ring(mouth, 0.05, 0.06), mix(c, ROSE, 0.2), "matte", T(0, 0.56, 0.85))
    p.add(box(1.0, 0.25, 0.06, bevel=0.015), lighter(c, 0.1), "matte", T(0, 0.7, 0.82))
    rng = random.Random(311)
    for k in range(3):
        p.add(sphere(0.12, 8, 5), (0.98, 0.78, 0.5), "satin", T(-0.25 + 0.25 * k, 0.7, 0.88) @ S(1.3, 0.9, 0.55))
    p.add(cyl(0.12, 0.5, 8), c, "matte", T(0.3, -0.2, 1.6))
    p.add(tube([(-0.5, 0.75, 0.85), (-0.6, 0.9, 0.2), (-0.65, 0.95, 0.0)], 0.02, 5), OAK, "satin")
    p.add(box(0.25, 0.3, 0.02, seg=1), OAK, "satin", T(-0.5, 0.75, 0.85) @ R("X", 70))


def hearth_kitchen(p, size, c):
    w, h, d = 3.4, 2.4, 1.2
    for sx in (-1, 1):
        p.add(box(0.5, d, h - 0.4, bevel=0.04), c, "matte", T(sx * (w / 2 - 0.25), 0, (h - 0.4) / 2))
    p.add(box(w, d, 0.5, bevel=0.04), c, "matte", T(0, 0, h - 0.4 + 0.25 - 0.05))
    p.add(box(w + 0.15, d + 0.1, 0.1, bevel=0.03), OAK, "satin", T(0, 0.05, h - 0.1))
    p.add(box(w - 1.0, 0.1, h - 0.4, seg=1), (0.38, 0.27, 0.3), "matte", T(0, -d / 2 + 0.05, (h - 0.4) / 2))
    p.add(box(w - 0.9, d, 0.2, bevel=0.02), mix(c, ROSE, 0.15), "matte", T(0, 0, 0.1))
    # spit, cauldron, flames
    p.add(cyl(0.02, w - 1.0, 6), IRON, "satin", T(-(w - 1.0) / 2, 0, 1.0) @ R("Y", 90))
    p.add(lathe([(0, 0), (0.25, 0.05), (0.32, 0.25), (0.3, 0.42), (0.28, 0.42)], 12, cap_top=False), IRON, "satin", T(0, 0, 0.25))
    p.add(disc(0.27, 12, 0.6), (0.98, 0.82, 0.6), "satin")
    p.add(tube([(-0.3, 0, 0.62), (0, 0, 1.0), (0.3, 0, 0.62)], 0.012, 4), IRON, "satin")
    for k in range(6):
        x = -0.6 + 0.24 * k
        p.add(lathe([(0, 0), (0.09, 0.05), (0.06, 0.2), (0, 0.38 - 0.08 * abs(k - 2.5))], 6), FLAME if k % 2 else (1.0, 0.62, 0.45), "glow", T(x, -0.1, 0.2))
    for x in (-1.2, -0.8, 0.8, 1.2):
        p.add(lathe([(0, 0), (0.1, 0.0), (0.12, 0.1), (0.1, 0.18)], 10, cap_top=False), COPPER, "gold", T(x, 0.1, h - 0.05))
    rng = random.Random(321)
    for x in (-1.0, 1.0):
        p.add(tube([(x, d / 2 - 0.05, h - 0.4), (x + 0.02, d / 2 - 0.03, h - 0.75)], 0.015, 4), LEAF_DARK, "leaf")
        foliage_ball(p, x, d / 2 - 0.02, h - 0.78, 0.08, (0.62, 0.78, 0.55), rng, 3, 1)


def copper_pots(p, size, c):
    for k, (r, h) in enumerate(((0.15, 0.2), (0.12, 0.16), (0.1, 0.12), (0.08, 0.1))):
        x = -0.42 + sum((0.15, 0.12, 0.1, 0.08)[:k]) * 2 + r + 0.02 * k
        p.add(lathe([(0, 0), (r, 0), (r * 1.05, h * 0.8), (r * 1.1, h)], 12, cap_top=False), c, "gold", T(x, 0, 0))
        p.add(tube([(x + r, 0, h * 0.8), (x + r + 0.12, 0, h * 0.9)], 0.012, 4), c, "gold")


def pot_rack_hanging(p, size, c):
    p.add(box(2.0, 0.6, 0.04, seg=1), OAK_DARK, "satin", T(0, 0, 0.58))
    for sx in (-1, 1):
        p.add(cyl(0.008, 0.3, 4), IRON, "satin", T(sx * 0.9, 0, 0.6))
    for k in range(6):
        x = -0.85 + k * 0.34
        r = 0.12 + 0.03 * (k % 3)
        p.add(tube([(x, 0, 0.56), (x, 0, 0.45)], 0.006, 3), IRON, "satin")
        m = T(x, 0, 0.44) @ R("X", 90)
        p.add(lathe([(0, 0), (r, 0), (r * 1.05, 0.1)], 10, cap_top=False), c, "gold", T(x, 0.0, 0.1) @ R("X", 90) @ T(0, 0.0, -0.05))
        p.add(cyl(0.012, 0.22, 4), c, "gold", T(x, 0, 0.22))


def dresser_crockery(p, size, c):
    w, h, d = 2.0, 2.2, 0.5
    p.add(box(w, d, 0.9, bevel=0.03), c, "satin", T(0, 0, 0.45))
    drawer_row(p, w - 0.1, 0.78, 0.18, d / 2 + 0.005, 3, c)
    for k in range(2):
        panel = arched_outline(w / 2 - 0.2, 0.5, 8, 0.12)
        p.add(frame_ring(panel, 0.015, 0.02), GOLD, "gold", T(-w / 4 + k * w / 2, d / 2 + 0.01, 0.1))
    shelf_unit(p, w - 0.1, h - 0.9, 0.3, c, [0.35, 0.75], "satin", back=lighter(c, 0.2))
    for k in range(3):
        z = 0.9 + 0.05 + k * 0.4
        for i in range(6):
            x = -0.8 + i * 0.32
            if k < 2:
                p.add(lathe([(0, 0), (0.12, 0), (0.13, 0.015), (0, 0.015)], 8), [WHITE, BLUSH][(i + k) % 2], "pearl", T(x, -0.08, z + 0.15) @ R("X", 78))
                p.add(torus(0.1, 0.006, 8, 3), ROSE if (i + k) % 2 == 0 else GOLD, "gold", T(x, -0.075, z + 0.15) @ R("X", 78))
            else:
                p.add(lathe([(0, 0), (0.04, 0), (0.06, 0.08), (0.055, 0.1)], 10, cap_top=False), [WHITE, MINT, BLUSH][i % 3], "pearl", T(x, 0, z))
    p.add(slab(arched_outline(w - 0.1, 0.2, 10, 0.18), 0.04), c, "satin", T(0, 0.12, h - 0.02))


def sink_stone(p, size, c):
    w, h, d = 1.4, 0.9, 0.7
    p.add(box(w, d, 0.5, bevel=0.03), c, "matte", T(0, 0, 0.25))
    basin = lathe([(0, 0.0), (0.4, 0.0), (0.45, 0.35), (0.5, 0.35), (0.5, 0.4)], 12, cap_top=False)
    for v in basin.verts:
        v.co.x *= 1.25
        v.co.y *= 0.7
    p.add(box(w, d, 0.4, bevel=0.04), lighter(c, 0.05), "matte", T(0, 0, 0.7))
    p.add(disc(0.42, 12, 0.91), WATERC, "water", S(1.25, 0.7, 1))
    p.add(tube([(0.55, -0.3, 0.9), (0.55, -0.3, 1.15), (0.45, -0.15, 1.15), (0.42, -0.1, 1.05)], 0.025, 6), COPPER, "gold")
    p.add(lathe([(0, 0), (0.1, 0), (0.12, 0.12), (0.1, 0.16)], 10, cap_top=False), COPPER, "gold", T(-0.55, 0, 0.9))


def barrel(p, size, c):
    p.add(lathe([(0, 0), (0.28, 0), (0.33, 0.25), (0.35, 0.5), (0.33, 0.75), (0.28, 1.0), (0, 1.0)], 14), c, "satin")
    for z in (0.12, 0.35, 0.65, 0.88):
        r = 0.28 + 0.07 * math.sin(math.pi * z)
        p.add(torus(r + 0.01, 0.015, 14, 4), GOLD_DEEP, "gold", T(0, 0, z))
    p.add(disc(0.26, 14, 1.005), lighter(c, 0.1), "satin")


def barrel_rack(p, size, c):
    w, h, d = 2.4, 1.6, 1.0
    for x in (-1.15, 0, 1.15):
        p.add(box(0.08, d, 0.08, bevel=0.01), OAK_DARK, "satin", T(x, 0, 0.04))
        p.add(box(0.08, d, 0.08, bevel=0.01), OAK_DARK, "satin", T(x, 0, 0.84))
    for row in range(2):
        for k in range(3):
            x = -0.75 + k * 0.75
            z = 0.4 + row * 0.8
            m = T(x, -d / 2, z) @ R("X", -90)
            p.add(lathe([(0, 0), (0.3, 0), (0.36, 0.5), (0.3, 1.0), (0, 1.0)], 12), OAK, "satin", m)
            for t in (0.15, 0.85):
                p.add(torus(0.33, 0.014, 12, 3), GOLD_DEEP, "gold", m @ T(0, 0, t))
            p.add(disc(0.29, 12, 1.0), lighter(OAK, 0.15), "satin", m)
            p.add(cyl(0.02, 0.06, 6), COPPER, "gold", T(x, d / 2, z - 0.15) @ R("X", -90))


def crate(p, size, c):
    p.add(box(0.8, 0.6, 0.6, bevel=0.015), c, "satin", T(0, 0, 0.3))
    for sy in (-1, 1):
        for x in (-0.38, 0.38):
            p.add(box(0.06, 0.02, 0.6, seg=1), darker(c, 0.15), "satin", T(x, sy * 0.31, 0.3))
        p.add(box(0.8, 0.02, 0.06, seg=1), darker(c, 0.15), "satin", T(0, sy * 0.31, 0.3) @ R("Y", 35))
    rng = random.Random(331)
    for k in range(6):
        p.add(sphere(0.07, 8, 5), [(0.95, 0.35, 0.4), (1.0, 0.75, 0.35), (0.7, 0.88, 0.45)][k % 3], "satin",
              T(-0.25 + 0.1 * k, rng.uniform(-0.15, 0.15), 0.62))
    foliage_ball(p, 0.25, 0.1, 0.62, 0.08, LEAF, rng, 3)


def sack_flour(p, size, c):
    s = lathe([(0, 0), (0.22, 0), (0.25, 0.15), (0.24, 0.45), (0.12, 0.6), (0.07, 0.62), (0.1, 0.7), (0, 0.7)], 10)
    p.add(s, c, "fabric", S(1, 0.8, 1))
    p.add(torus(0.075, 0.015, 8, 3), ROSE, "fabric", T(0, 0, 0.6))
    p.add(slab(oval_outline(0.16, 0.12, 8), 0.004), BLUSH, "fabric", T(0, 0.2, 0.25))


def basket_produce(p, size, c):
    p.add(lathe([(0, 0), (0.2, 0), (0.26, 0.15), (0.28, 0.2), (0.25, 0.2), (0.22, 0.04), (0, 0.04)], 12), c, "matte", S(1, 0.7, 1))
    p.add(tube([(-0.26, 0, 0.2), (0, 0, 0.42), (0.26, 0, 0.2)], 0.015, 4), c, "matte")
    rng = random.Random(341)
    for k in range(7):
        p.add(sphere(0.055, 8, 5), [(0.95, 0.35, 0.4), (1.0, 0.75, 0.35), (0.7, 0.88, 0.45), (0.8, 0.5, 0.85)][k % 4], "satin",
              T(rng.uniform(-0.15, 0.15), rng.uniform(-0.08, 0.08), 0.2))
    p.add(tube([(0.0, 0.08, 0.16), (0.12, 0.2, 0.2)], 0.01, 3), CREAM, "fabric")


def herb_bundle_hanging(p, size, c):
    p.add(cyl(0.015, 1.0, 6), OAK, "satin", T(-0.5, 0, 0.55) @ R("Y", 90))
    rng = random.Random(351)
    cols = [c, LILAC, (0.62, 0.82, 0.58), BUTTER]
    for k in range(5):
        x = -0.4 + k * 0.2
        p.add(tube([(x, 0, 0.55), (x, 0, 0.42)], 0.005, 3), CREAM, "fabric")
        p.add(lathe([(0.02, 0.42), (0.08, 0.2), (0.06, 0.0)], 8), cols[k % len(cols)], "leaf")
        p.add(torus(0.025, 0.006, 6, 3), ROSE, "fabric", T(x, 0, 0.38))
        for j in range(3):
            p.add(sphere(0.03, 6, 4), lighter(cols[k % len(cols)], 0.2), "leaf", T(x + rng.uniform(-0.04, 0.04), rng.uniform(-0.03, 0.03), 0.04 + 0.04 * j))


def cheese_shelf(p, size, c):
    w, h, d = 1.6, 1.8, 0.5
    shelves = [0.1, 0.55, 1.0, 1.45]
    shelf_unit(p, w, h, d, OAK, shelves, "satin")
    for z in shelves:
        for k in range(3):
            x = -0.5 + k * 0.5
            p.add(lathe([(0, 0), (0.17, 0), (0.18, 0.06), (0.17, 0.12), (0, 0.12)], 12), c, "satin", T(x, 0, z + 0.015))
            p.add(torus(0.17, 0.008, 12, 3), lighter(c, 0.3) if k % 2 else ROSE, "satin", T(x, 0, z + 0.075))


def wine_rack(p, size, c):
    w, h, d = 2.0, 2.2, 0.5
    shelf_unit(p, w, h, d, c, [0.1], "satin")
    for k in range(1, 6):
        p.add(box(0.03, d, h - 0.2, seg=1), c, "satin", T(-w / 2 + k * w / 6, 0, h / 2))
    for col in range(6):
        for row in range(7):
            x = -w / 2 + (col + 0.5) * w / 6
            z = 0.25 + row * 0.27
            m = T(x, d / 2 - 0.02, z) @ R("X", -90)
            p.add(lathe([(0, 0), (0.05, 0), (0.05, 0.06)], 6), [(0.65, 0.3, 0.45), (0.55, 0.75, 0.55), (0.98, 0.85, 0.6)][(col + row) % 3], "glass", m)
            p.add(sphere(0.022, 4, 3), GOLD, "gold", m @ T(0, 0, 0.065))


def cake_stand(p, size, c):
    p.add(lathe([(0, 0), (0.12, 0), (0.06, 0.04), (0.03, 0.18), (0.16, 0.2), (0.17, 0.21), (0, 0.21)], 14), WHITE, "pearl")
    p.add(lathe([(0, 0), (0.13, 0), (0.13, 0.12), (0, 0.12)], 16), c, "satin", T(0, 0, 0.21))
    p.add(lathe([(0, 0), (0.09, 0), (0.09, 0.1), (0, 0.1)], 14), lighter(c, 0.3), "satin", T(0, 0, 0.33))
    for z, r in ((0.21, 0.135), (0.33, 0.135), (0.43, 0.095)):
        p.add(torus(r, 0.012, 14, 4), WHITE, "pearl", T(0, 0, z))
    rng = random.Random(361)
    bloom(p, (0, 0, 0.45), 0.04, ROSE, 2, 5, rng)
    for k in range(5):
        a = 2 * math.pi * k / 5
        p.add(sphere(0.013, 6, 4), (0.95, 0.3, 0.4), "satin", T(0.11 * math.cos(a), 0.11 * math.sin(a), 0.345))


def pantry_shelf(p, size, c):
    w, h, d = 2.0, 2.2, 0.45
    shelves = [0.1, 0.6, 1.1, 1.6]
    shelf_unit(p, w, h, d, c, shelves, "satin", back=lighter(MINT, 0.3))
    rng = random.Random(371)
    for i, z in enumerate(shelves):
        jars(p, -w / 2 + 0.08, w / 2 - 0.08 - (0.5 if i % 2 else 0.0), 0.0, z + 0.015, [(0.95, 0.4, 0.45), BUTTER, (0.7, 0.88, 0.5), (0.85, 0.6, 0.9)][i:] + [PERI], rng, 0.25, glass=i % 2 == 0)
        if i % 2:
            p.add(box(0.4, 0.3, 0.2), (0.98, 0.9, 0.7), "matte", T(w / 2 - 0.3, 0, z + 0.115), smooth=False)
        p.add(box(w - 0.06, 0.005, 0.05, seg=1), [ROSE, MINT, LILAC, BUTTER][i], "fabric", T(0, d / 2, z - 0.03))


def laundry_tub(p, size, c):
    p.add(lathe([(0, 0.0), (0.45, 0.0), (0.55, 0.8), (0.5, 0.8), (0.42, 0.1), (0, 0.1)], 14), c, "satin", S(1.1, 0.75, 1))
    for z in (0.15, 0.65):
        p.add(torus(0.47 + 0.07 * z, 0.015, 14, 4), GOLD_DEEP, "gold", T(0, 0, z) @ S(1.1, 0.75, 1))
    p.add(disc(0.48, 14, 0.62), WATERC, "water", S(1.1, 0.75, 1))
    rng = random.Random(381)
    for k in range(8):
        p.add(sphere(rng.uniform(0.05, 0.09), 6, 4), WHITE, "glass", T(rng.uniform(-0.35, 0.35), rng.uniform(-0.2, 0.2), 0.65))
    p.add(tube([(0.3, 0.1, 0.62), (0.4, 0.3, 0.75), (0.55, 0.35, 0.6)], 0.05, 6), BLUSH, "fabric")


def drying_line(p, size, c):
    w = 4.0
    for sx in (-1, 1):
        p.add(cyl(0.04, 2.0, 6), OAK, "satin", T(sx * (w / 2 - 0.05), 0, 0))
    pts = [(-w / 2 + 0.05 + (w - 0.1) * i / 10, 0, 1.9 - 0.12 * math.sin(math.pi * i / 10)) for i in range(11)]
    p.add(tube(pts, 0.008, 3), CREAM, "fabric")
    cols = [WHITE, BLUSH, MINT, LILAC, BUTTER, PERI]
    for k in range(6):
        x, _, z = pts[k * 2 % 10 + 1 if k < 5 else 9]
        x = -1.5 + k * 0.6
        z = 1.9 - 0.12 * math.sin(math.pi * (x + w / 2) / w) - 0.02
        cloth = box(0.45, 0.02, 0.6 + 0.1 * (k % 2), seg=1)
        for v in cloth.verts:
            v.co.y += 0.03 * math.sin(v.co.x * 10)
        p.add(cloth, cols[k], "fabric", T(x, 0, z - 0.3 - 0.05 * (k % 2)))
        p.add(box(0.02, 0.03, 0.06, seg=1), OAK, "satin", T(x - 0.15, 0, z))


def ironing_table(p, size, c):
    w, h, d = 1.6, 0.9, 0.5
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(turned_leg(h - 0.04, 0.03, 6, "taper"), c, "satin", T(sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), 0))
    p.add(box(w, d, 0.04, bevel=0.012), c, "satin", T(0, 0, h - 0.02))
    p.add(box(w * 0.9, d + 0.06, 0.02, bevel=0.008), CREAM, "fabric", T(0, 0, h + 0.01))
    p.add(box(0.2, 0.1, 0.07, bevel=0.03), IRON, "satin", T(0.4, 0, h + 0.05))
    p.add(tube([(0.33, 0, h + 0.09), (0.4, 0, h + 0.15), (0.47, 0, h + 0.09)], 0.012, 4), OAK, "satin")
    for k in range(3):
        p.add(box(0.4, 0.3, 0.03, bevel=0.01), [WHITE, BLUSH, LILAC][k], "fabric", T(-0.4, 0, h + 0.03 + 0.03 * k) @ R("Z", 5 * k))


def linen_press(p, size, c):
    w, h, d = 1.6, 2.2, 0.6
    p.add(box(w, d, h - 0.15, bevel=0.03), c, "satin", T(0, 0, (h - 0.15) / 2 + 0.05))
    p.add(box(w + 0.08, d + 0.06, 0.1, bevel=0.03), lighter(c, 0.06), "satin", T(0, 0, h - 0.05))
    crest(p, 0, d / 2, h + 0.02, 0.16)
    for k in range(2):
        panel = arched_outline(w / 2 - 0.16, 1.1, 8, 0.2)
        x = -w / 4 + k * w / 2
        p.add(slab(panel, 0.02), mix(SOFT_BLUE, c, 0.5), "satin", T(x, d / 2 + 0.01, 0.75))
        p.add(frame_ring(panel, 0.014, 0.02), GOLD, "gold", T(x, d / 2 + 0.02, 0.75))
    drawer_row(p, w - 0.1, 0.45, 0.22, d / 2 + 0.005, 2, c)
    drawer_row(p, w - 0.1, 0.2, 0.22, d / 2 + 0.005, 2, c)


# ------------------------------------------------------------ stillroom & infirmary


def stillroom_bench(p, size, c):
    w, h, d = 2.6, 0.95, 0.9
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(turned_leg(h - 0.05, 0.05, 8), c, "satin", T(sx * (w / 2 - 0.08), sy * (d / 2 - 0.08), 0))
    p.add(box(w, d, 0.06, bevel=0.015), c, "satin", T(0, 0, h - 0.03))
    p.add(box(w - 0.1, d - 0.1, 0.03, seg=1), c, "satin", T(0, 0, 0.2))
    rng = random.Random(391)
    jars(p, -1.2, -0.2, -0.25, h, [ROSE, PERI, MINT, BUTTER, LILAC], rng, 0.2)
    _alembic_at(p, 0.5, 0.0, h, 0.6)
    p.add(lathe([(0, 0), (0.1, 0), (0.12, 0.1), (0.1, 0.12)], 10, cap_top=False), WARM_STONE, "matte", T(-0.2, 0.25, h))
    p.add(tube([(-0.2, 0.25, h + 0.05), (-0.1, 0.3, h + 0.2)], 0.015, 5), WARM_STONE, "matte")
    for k in range(4):
        x = 0.9 + 0.08 * k
        p.add(sphere(0.04, 6, 4), [LILAC, ROSE, BUTTER, MINT][k], "leaf", T(x, 0.25, h + 0.03))
    p.add(box(0.4, 0.3, 0.01, seg=1), CANVAS, "matte", T(-0.6, 0.2, h + 0.005) @ R("Z", -8))


def _alembic_at(p, x, y, z, s):
    p.add(lathe([(0, 0), (0.12 * s, 0), (0.12 * s, 0.15 * s), (0, 0.15 * s)], 8), WARM_STONE, "matte", T(x, y, z))
    p.add(lathe([(0, 0), (0.16 * s, 0.05 * s), (0.2 * s, 0.25 * s), (0.12 * s, 0.4 * s), (0.04 * s, 0.5 * s), (0.04 * s, 0.6 * s)], 12), COPPER, "gold", T(x, y, z + 0.15 * s))
    p.add(lathe([(0.0, 0), (0.08 * s, 0.05 * s), (0.04 * s, 0.15 * s), (0, 0.16 * s)], 10), COPPER, "gold", T(x, y, z + 0.75 * s))
    p.add(tube([(x, y, z + 0.82 * s), (x + 0.2 * s, y, z + 0.85 * s), (x + 0.4 * s, y, z + 0.55 * s)], 0.015 * s + 0.004, 5), COPPER, "gold")
    p.add(lathe([(0, 0), (0.08 * s, 0.0), (0.1 * s, 0.1 * s), (0.03 * s, 0.2 * s), (0.03 * s, 0.25 * s)], 10), PERI, "glass", T(x + 0.42 * s, y, z))
    p.add(sphere(0.06 * s, 6, 4), (1.0, 0.6, 0.45), "glow", T(x, y, z + 0.07 * s))


def alembic(p, size, c):
    _alembic_at(p, 0, 0, 0, 1.0)


def drying_rack_herbs(p, size, c):
    w, h, d = 1.8, 2.0, 0.5
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(cyl(0.025, h, 6), OAK, "satin", T(sx * (w / 2 - 0.03), sy * (d / 2 - 0.03), 0))
    rng = random.Random(401)
    cols = [c, LILAC, (0.62, 0.82, 0.58), BUTTER, ROSE]
    for row, z in enumerate((0.7, 1.3, 1.9)):
        p.add(box(w, 0.03, 0.03, seg=1), OAK, "satin", T(0, 0, z))
        for k in range(6):
            x = -w / 2 + 0.2 + k * 0.28
            col = cols[(row + k) % len(cols)]
            p.add(lathe([(0.015, 0), (0.07, -0.2), (0.05, -0.38)], 6), col, "leaf", T(x, 0, z))
            p.add(torus(0.02, 0.006, 6, 3), CREAM, "fabric", T(x, 0, z - 0.02))
    for sy in (-1, 1):
        p.add(box(w, 0.03, 0.03, seg=1), OAK, "satin", T(0, sy * (d / 2 - 0.03), 0.1))


def apothecary_cabinet(p, size, c):
    w, h, d = 2.0, 2.2, 0.5
    p.add(box(w, d, 0.95, bevel=0.03), c, "satin", T(0, 0, 0.475))
    for row in range(4):
        for col in range(6):
            x = -w / 2 + 0.17 + col * 0.33
            z = 0.12 + row * 0.22
            p.add(box(0.29, 0.02, 0.18), lighter(c, 0.1), "satin", T(x, d / 2 + 0.005, z), smooth=False)
            p.add(box(0.1, 0.005, 0.05), CANVAS, "matte", T(x, d / 2 + 0.018, z + 0.03), smooth=False)
            p.add(sphere(0.012, 4, 3), GOLD, "gold", T(x, d / 2 + 0.02, z - 0.04))
    shelf_unit(p, w - 0.1, h - 0.95, 0.3, c, [0.3, 0.7], "satin", back=lighter(c, 0.25))
    rng = random.Random(411)
    for k, z in enumerate((0.95 + 0.32, 0.95 + 0.72)):
        jars(p, -w / 2 + 0.1, w / 2 - 0.1, 0.0, z - 0.0, [PERI, ROSE, MINT, BUTTER, LILAC][k:] + [BLUSH], rng, 0.25)


def mortar_pestle(p, size, c):
    p.add(lathe([(0, 0), (0.1, 0), (0.14, 0.08), (0.15, 0.2), (0.12, 0.2), (0.1, 0.06), (0, 0.06)], 12), c, "matte")
    p.add(tube([(0.0, 0, 0.08), (0.08, 0, 0.3)], [0.03, 0.02], 6), lighter(c, 0.1), "matte")
    p.add(sphere(0.03, 6, 4), LILAC, "leaf", T(-0.18, 0.05, 0.02))
    p.add(sphere(0.025, 6, 4), ROSE, "leaf", T(-0.16, -0.06, 0.02))


def vial_rack(p, size, c):
    p.add(box(0.6, 0.25, 0.04, bevel=0.01), OAK, "satin", T(0, 0, 0.02))
    p.add(box(0.6, 0.25, 0.02, bevel=0.006), OAK, "satin", T(0, 0, 0.18))
    for sx in (-1, 1):
        p.add(box(0.03, 0.25, 0.2, seg=1), OAK, "satin", T(sx * 0.29, 0, 0.1))
    cols = [ROSE, PERI, MINT, BUTTER, LILAC, BLUSH, (0.7, 0.95, 0.9)]
    for k in range(7):
        x = -0.24 + k * 0.08
        p.add(lathe([(0, 0), (0.025, 0.01), (0.025, 0.25), (0.03, 0.27)], 8, cap_top=False), WHITE, "glass", T(x, 0, 0.04))
        p.add(cyl(0.022, 0.12, 8), cols[k], "glow" if k % 3 == 0 else "glass", T(x, 0, 0.05))
        p.add(cyl(0.02, 0.03, 6), OAK, "satin", T(x, 0, 0.29))


def infirmary_cot(p, size, c):
    w, d = 1.0, 2.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(cyl(0.025, 0.45, 6), WHITE, "pearl", T(sx * (w / 2 - 0.04), sy * (d / 2 - 0.04), 0))
    p.add(box(w, d, 0.06, bevel=0.015), WHITE, "pearl", T(0, 0, 0.45))
    p.add(cushion(w - 0.06, d - 0.06, 0.12, 0.2), c, "fabric", T(0, 0, 0.54))
    p.add(cushion(w, d * 0.55, 0.05, 0.3), mix(MINT, WHITE, 0.4), "fabric", T(0, 0.35, 0.62))
    p.add(cushion(0.6, 0.35, 0.14, 0.5), WHITE, "fabric", T(0, -d / 2 + 0.25, 0.66))
    pts = [(-w / 2 + 0.04, -d / 2 + 0.04, 0.45), (-w / 2 + 0.04, -d / 2 + 0.04, 0.9)] + \
          [(-(w / 2 - 0.04) * math.cos(math.pi * i / 8), -d / 2 + 0.04, 0.9 + 0.15 * math.sin(math.pi * i / 8)) for i in range(1, 8)] + \
          [(w / 2 - 0.04, -d / 2 + 0.04, 0.9), (w / 2 - 0.04, -d / 2 + 0.04, 0.45)]
    p.add(tube(pts, 0.022, 6), WHITE, "pearl")


def bandage_shelf(p, size, c):
    w, h, d = 1.4, 1.8, 0.4
    shelves = [0.1, 0.55, 1.0, 1.45]
    shelf_unit(p, w, h, d, OAK, shelves, "satin", back=lighter(MINT, 0.3))
    rng = random.Random(421)
    for i, z in enumerate(shelves):
        for k in range(4):
            x = -0.5 + k * 0.33
            if (i + k) % 3 == 0:
                p.add(cyl(0.07, 0.12, 8), c, "fabric", T(x, 0, z + 0.015))
                p.add(cyl(0.07, 0.12, 8), c, "fabric", T(x + 0.1, 0.05, z + 0.015))
            elif (i + k) % 3 == 1:
                for j in range(3):
                    p.add(box(0.25, 0.25, 0.04, bevel=0.012), [WHITE, BLUSH, c][j], "fabric", T(x, 0, z + 0.035 + j * 0.045))
            else:
                p.add(lathe([(0, 0), (0.05, 0), (0.06, 0.12), (0.03, 0.18), (0.035, 0.22)], 8), [PERI, ROSE][k % 2], "glass", T(x, 0, z + 0.015))


# ------------------------------------------------------------ armory


def weapon_rack(p, size, c):
    w, h, d = 2.4, 2.0, 0.5
    p.add(box(w, 0.1, h, bevel=0.02), c, "satin", T(0, -d / 2 + 0.05, h / 2))
    for z in (0.2, 1.2, 1.7):
        p.add(box(w, 0.2, 0.06, bevel=0.015), c, "satin", T(0, -d / 2 + 0.15, z))
    for k in range(5):
        x = -0.9 + k * 0.45
        if k % 2 == 0:   # sword: gilt hilt, pale steel blade
            p.add(box(0.06, 0.015, 1.1, bevel=0.005), mix(SOFT_BLUE, WHITE, 0.5), "mirror", T(x, -d / 2 + 0.2, 0.75))
            p.add(box(0.25, 0.04, 0.04, bevel=0.01), GOLD, "gold", T(x, -d / 2 + 0.2, 1.32))
            p.add(cyl(0.02, 0.18, 6), ROSE, "fabric", T(x, -d / 2 + 0.2, 1.34))
            p.add(sphere(0.035, 8, 5), GOLD, "gold", T(x, -d / 2 + 0.2, 1.54))
        else:            # spear
            p.add(cyl(0.02, 1.7, 6), OAK, "satin", T(x, -d / 2 + 0.2, 0.15))
            p.add(lathe([(0.0, 0), (0.05, 0.05), (0.0, 0.25)], 4), mix(SOFT_BLUE, WHITE, 0.5), "mirror", T(x, -d / 2 + 0.2, 1.85))
            p.add(torus(0.03, 0.01, 6, 3), GOLD, "gold", T(x, -d / 2 + 0.2, 1.84))
    crest(p, 0, -d / 2 + 0.11, h - 0.02, 0.2)


def bow_rack(p, size, c):
    w, h, d = 2.0, 2.0, 0.4
    p.add(box(w, 0.08, h, bevel=0.02), lighter(c, 0.1), "satin", T(0, -d / 2 + 0.04, h / 2))
    for k in range(4):
        z = 0.35 + k * 0.45
        for sx in (-1, 1):
            p.add(cyl(0.02, 0.18, 6), GOLD, "gold", T(sx * 0.7, -d / 2 + 0.08, z) @ R("X", -90))
        bow = [(-0.85 * math.cos(math.pi * i / 10), -d / 2 + 0.22 + 0.12 * math.sin(math.pi * i / 10), z + 0.03) for i in range(11)]
        p.add(tube(bow, [0.015 + 0.01 * math.sin(math.pi * i / 10) for i in range(11)], 5), [OAK, OAK_DARK, (0.9, 0.7, 0.75), GOLD][k], "satin" if k < 3 else "gold")
        p.add(tube([bow[0], bow[-1]], 0.003, 3), CREAM, "fabric")
    # quiver of fletched arrows hanging at the side (canon: Feyre's ash arrows)
    p.add(cyl(0.08, 0.6, 8), (0.8, 0.55, 0.6), "satin", T(0.85, -d / 2 + 0.2, 0.2))
    for k in range(5):
        p.add(cyl(0.006, 0.3, 3), CREAM, "satin", T(0.83 + 0.01 * k, -d / 2 + 0.18 + 0.01 * (k % 2), 0.75))
        p.add(petal(0.06, 0.03, cup=0, curl=0), [ROSE, WHITE, BLUSH][k % 3], "fabric", T(0.83 + 0.01 * k, -d / 2 + 0.18, 1.0) @ R("Y", -90))


def armor_stand(p, size, c):
    p.add(lathe([(0, 0), (0.28, 0), (0.28, 0.04), (0.05, 0.08), (0.04, 0.6)], 10), OAK_DARK, "satin")
    steel = mix(SOFT_BLUE, LILAC, 0.4)
    p.add(lathe([(0.0, 0.0), (0.2, 0.0), (0.22, 0.2), (0.2, 0.5), (0.24, 0.65), (0.15, 0.72), (0.0, 0.74)], 12), steel, "mirror", T(0, 0, 0.75) @ S(1, 0.7, 1))
    p.add(torus(0.2, 0.015, 12, 4), GOLD, "gold", T(0, 0, 1.0) @ S(1, 0.7, 1))
    for sx in (-1, 1):
        p.add(sphere(0.12, 10, 6), steel, "mirror", T(sx * 0.25, 0, 1.38) @ S(1, 0.9, 0.7))
        p.add(tube([(sx * 0.27, 0, 1.3), (sx * 0.3, 0.04, 1.0), (sx * 0.28, 0.08, 0.8)], [0.06, 0.05, 0.045], 6), steel, "mirror")
    p.add(cyl(0.06, 0.08, 8), steel, "mirror", T(0, 0, 1.48))
    p.add(lathe([(0.0, 0), (0.13, 0.0), (0.14, 0.1), (0.12, 0.22), (0.06, 0.29), (0.0, 0.3)], 12), steel, "mirror", T(0, 0, 1.55))
    p.add(box(0.2, 0.02, 0.03, seg=1), (0.25, 0.2, 0.3), "matte", T(0, 0.13, 1.66))
    p.add(tube([(0, -0.02, 1.84), (0, -0.12, 1.86), (0, -0.2, 1.7)], [0.02, 0.04, 0.02], 5), ROSE, "fabric")
    # tabard with the Spring Court rose
    p.add(box(0.3, 0.02, 0.45, bevel=0.01), mix(MINT, WHITE, 0.2), "fabric", T(0, 0.16, 0.95))
    bloom(p, (0, 0.18, 1.05), 0.06, ROSE, 2, 5, random.Random(5), tilt=R("X", -90))


def target_straw(p, size, c):
    for sx in (-1, 1):
        p.add(tube([(sx * 0.45, -0.2, 0.0), (sx * 0.3, 0.05, 1.3)], 0.025, 6), OAK, "satin")
    p.add(tube([(0, 0.4, 0.0), (0, 0.0, 1.0)], 0.025, 6), OAK, "satin")
    m = T(0, 0.05, 0.8) @ R("X", -80)
    p.add(cyl(0.55, 0.2, 18), c, "matte", m)
    rings = [(0.5, WHITE), (0.4, ROSE), (0.3, WHITE), (0.2, PERI), (0.1, GOLD)]
    for k, (r, col) in enumerate(rings):
        p.add(cyl(r, 0.205 + 0.002 * k, 18), col, "fabric" if col != GOLD else "gold", m)
    for k, (x, z) in enumerate(((0.05, 0.85), (-0.12, 0.7), (0.2, 0.78))):
        p.add(cyl(0.008, 0.5, 3), CREAM, "satin", T(x, 0.1, z) @ R("X", -100))
        p.add(petal(0.06, 0.03, cup=0, curl=0), ROSE, "fabric", T(x, 0.55, z + 0.08) @ R("Y", -90))


def quiver_barrel(p, size, c):
    p.add(lathe([(0, 0), (0.2, 0), (0.24, 0.3), (0.24, 0.6), (0.22, 0.65), (0, 0.65)], 12), c, "satin")
    for z in (0.08, 0.55):
        p.add(torus(0.23, 0.012, 12, 3), GOLD, "gold", T(0, 0, z))
    rng = random.Random(431)
    for k in range(9):
        a = 2 * math.pi * k / 9
        r = 0.12 * (k % 3) / 2
        x, y = r * math.cos(a), r * math.sin(a)
        p.add(cyl(0.007, 0.3, 3), CREAM, "satin", T(x, y, 0.6) @ R("X", rng.uniform(-8, 8)))
        p.add(petal(0.07, 0.035, cup=0, curl=0), [ROSE, WHITE, BLUSH, PERI][k % 4], "fabric", T(x, y, 0.82) @ R("Z", math.degrees(a)) @ R("Y", -90))


# ------------------------------------------------------------ garden


def planter_box(p, size, c):
    w, h, d = 2.0, 0.7, 0.8
    p.add(box(w, d, 0.55, bevel=0.04), c, "pearl", T(0, 0, 0.3))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(sphere(0.07, 8, 5), GOLD, "gold", T(sx * (w / 2 - 0.04), sy * (d / 2 - 0.04), 0.6))
    for x in (-0.5, 0.5):
        p.add(frame_ring(arched_outline(0.6, 0.3, 6, 0.1), 0.012, 0.02), GOLD, "gold", T(x, d / 2 + 0.01, 0.1))
    rng = random.Random(441)
    for k in range(4):
        foliage_ball(p, -0.7 + k * 0.47, 0, 0.62, 0.2, LEAF, rng, 4)
    flower_spray(p, 0, 0, 0.8, 0.75, 10, [c if c != WARM_STONE else ROSE, BLUSH, LILAC, BUTTER, PERI], rng, 0.06, stems=False)


def orange_tree_tub(p, size, c):
    p.add(box(0.7, 0.7, 0.6, bevel=0.03), mix(SOFT_BLUE, PEARL, 0.4), "pearl", T(0, 0, 0.3))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(sphere(0.06, 8, 5), GOLD, "gold", T(sx * 0.33, sy * 0.33, 0.62))
    p.add(tube([(0, 0, 0.55), (0.02, 0, 1.2), (0, 0.02, 1.5)], [0.05, 0.04, 0.035], 6), BARK, "matte")
    rng = random.Random(451)
    foliage_ball(p, 0, 0, 1.7, 0.42, c, rng, 6, 1)
    for k in range(10):
        a = rng.uniform(0, 2 * math.pi)
        e = rng.uniform(-0.4, 0.8)
        r = 0.48
        p.add(sphere(0.05, 8, 5), (1.0, 0.68, 0.32), "satin", T(r * math.cos(a) * math.cos(e), r * math.sin(a) * math.cos(e), 1.7 + r * math.sin(e) * 0.8))
    for k in range(5):
        a = rng.uniform(0, 2 * math.pi)
        star_flower(p, (0.45 * math.cos(a), 0.45 * math.sin(a), 1.85), 0.035, WHITE, 5, heart=BUTTER)


def fern_pot(p, size, c):
    pot(p, 0.25, 0.4, BLUSH, "pearl")
    rng = random.Random(461)
    for k in range(9):
        a = 2 * math.pi * k / 9 + rng.uniform(-0.15, 0.15)
        L = rng.uniform(0.45, 0.6)
        pts = [(0, 0, 0.35), (L * 0.5 * math.cos(a), L * 0.5 * math.sin(a), 0.75), (L * math.cos(a), L * math.sin(a), 0.6)]
        p.add(tube(pts, [0.008, 0.007, 0.003], 3), c, "leaf")
        for j in range(5):
            t = 0.15 + j * 0.17
            x, y = L * t * math.cos(a), L * t * math.sin(a)
            z = 0.35 + 0.45 * math.sin(math.pi * t * 0.9) - 0.05 * t
            for s_ in (-1, 1):
                p.add(leaf(0.1 * (1.1 - t), 0.04), c, "leaf", T(x, y, z) @ R("Z", math.degrees(a) + s_ * 75) @ R("Y", 15))


def fountain(p, R_, h, c, grand):
    rng = random.Random(471)
    n = 24 if grand else 16
    basin = lathe([(0, 0), (R_, 0), (R_ * 1.02, h * 0.12), (R_ * 0.98, h * 0.14), (R_ * 0.93, h * 0.06), (0, h * 0.06)], n)
    p.add(basin, c, "pearl")
    p.add(torus(R_, h * 0.025, n, 4), GOLD, "gold", T(0, 0, h * 0.13))
    p.add(disc(R_ * 0.93, n, h * 0.1), WATERC, "water")
    p.add(lathe([(R_ * 0.12, h * 0.06), (R_ * 0.08, h * 0.3), (R_ * 0.12, h * 0.42), (R_ * 0.45, h * 0.5), (R_ * 0.46, h * 0.53), (R_ * 0.42, h * 0.53), (R_ * 0.4, h * 0.5), (0, h * 0.5)], n), c, "pearl")
    p.add(disc(R_ * 0.41, n, h * 0.525), WATERC, "water")
    p.add(torus(R_ * 0.45, h * 0.015, n, 4), GOLD, "gold", T(0, 0, h * 0.53))
    p.add(lathe([(R_ * 0.06, h * 0.5), (R_ * 0.05, h * 0.68), (R_ * 0.2, h * 0.74), (R_ * 0.2, h * 0.76), (0, h * 0.76)], n), c, "pearl")
    if grand:
        # three dolphins & a gilt rose finial; water arcs
        for k in range(3):
            a = 2 * math.pi * k / 3
            pts = [(R_ * 0.1 * math.cos(a), R_ * 0.1 * math.sin(a), h * 0.6), (R_ * 0.25 * math.cos(a), R_ * 0.25 * math.sin(a), h * 0.7),
                   (R_ * 0.3 * math.cos(a), R_ * 0.3 * math.sin(a), h * 0.6)]
            p.add(tube(pts, [h * 0.04, h * 0.05, h * 0.02], 6), MINT, "pearl")
        for k in range(8):
            a = 2 * math.pi * k / 8
            arc = [(R_ * (0.45 + 0.4 * t) * math.cos(a), R_ * (0.45 + 0.4 * t) * math.sin(a), h * (0.55 + 0.25 * math.sin(math.pi * t) - 0.45 * t)) for t in [i / 6 for i in range(7)]]
            p.add(tube(arc, h * 0.012, 4), (0.85, 0.97, 1.0, 0.5), "glass")
        for k in range(6):
            a = 2 * math.pi * k / 6
            bloom(p, (R_ * 0.7 * math.cos(a), R_ * 0.7 * math.sin(a), h * 0.11), R_ * 0.05, [ROSE, WHITE, BLUSH][k % 3], 2, 5, rng)
            p.add(cyl(R_ * 0.08, h * 0.004, 8), LEAF, "leaf", T(R_ * 0.72 * math.cos(a) + R_ * 0.05, R_ * 0.72 * math.sin(a), h * 0.105))
    p.add(lathe([(0, 0), (h * 0.04, h * 0.02), (h * 0.03, h * 0.08), (0, h * 0.14)], 8), (0.85, 0.97, 1.0, 0.6), "glass", T(0, 0, h * 0.76))
    p.add(sphere(h * 0.05, 10, 6), GOLD, "gold", T(0, 0, h * 0.8))
    bloom(p, (0, 0, h * 0.85), h * 0.07, ROSE, 2, 5, rng)


def fountain_small(p, size, c):
    fountain(p, 0.8, 1.4, c, False)


def fountain_grand(p, size, c):
    fountain(p, 4.0, 4.0, c, True)


def garden_bench(p, size, c):
    w = 1.8
    for sx in (-1, 1):
        side = [(0, 0), (0.5, 0), (0.48, 0.42), (0.55, 0.65), (0.45, 0.65), (0.35, 0.45), (0.05, 0.45), (-0.02, 0.9), (-0.1, 0.9), (-0.06, 0.4)]
        p.add(slab([(x - 0.22, z) for x, z in side], 0.05, 0.01), c, "pearl", T(sx * (w / 2 - 0.05), 0, 0) @ R("Z", 90))
    for k in range(4):
        p.add(box(w, 0.1, 0.035, bevel=0.01), c, "pearl", T(0, 0.15 - k * 0.11, 0.45))
    back = slab(arched_outline(w - 0.1, 0.45, 12, 0.12), 0.03)
    p.add(back, c, "pearl", T(0, -0.25, 0.45) @ R("X", -10))
    for k in range(3):
        heart_crest(p, -0.55 + 0.55 * k, -0.22, 0.65, 0.16, ROSE)
    rng = random.Random(481)
    vine = [(-w / 2 + 0.05 + (w - 0.1) * i / 8, -0.24, 0.9 + 0.03 * math.sin(i)) for i in range(9)]
    p.add(tube(vine, 0.012, 4), LEAF_DARK, "leaf")
    for i, (x, y, z) in enumerate(vine[::2]):
        bloom(p, (x, y + 0.03, z), 0.05, ROSE if i % 2 else BLUSH, 2, 5, rng, tilt=R("X", -45))


def garden_urn(p, size, c):
    p.add(box(0.6, 0.6, 0.35, bevel=0.03), c, "pearl", T(0, 0, 0.175))
    p.add(lathe([(0, 0), (0.18, 0), (0.08, 0.1), (0.08, 0.2), (0.3, 0.35), (0.38, 0.55), (0.42, 0.6), (0.36, 0.6)], 14), c, "pearl", T(0, 0, 0.35))
    for sx in (-1, 1):
        p.add(scroll(0.1, 1.1, 8, 0.02), GOLD, "gold", T(sx * 0.36, 0, 0.75) @ S(sx, 1, 1))
    rng = random.Random(491)
    foliage_ball(p, 0, 0, 1.05, 0.3, LEAF, rng, 5)
    flower_spray(p, 0, 0, 1.1, 0.25, 7, [ROSE, LILAC, BLUSH, PERI], rng, 0.07, stems=False)
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        p.add(tube([(0.32 * math.cos(a), 0.32 * math.sin(a), 0.92), (0.42 * math.cos(a), 0.42 * math.sin(a), 0.7), (0.4 * math.cos(a), 0.4 * math.sin(a), 0.45)], 0.012, 3), LEAF_DARK, "leaf")


def rose_arbor(p, size, c):
    w, h, d = 3.0, 3.2, 2.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(lathe([(0.08, 0), (0.06, 0.1), (0.05, 2.0), (0.07, 2.1)], 8), c, "pearl", T(sx * 1.35, sy * 0.85, 0))
    for sy in (-1, 1):
        arch = [(1.35 * math.cos(math.pi * i / 12), sy * 0.85, 2.1 + 1.0 * math.sin(math.pi * i / 12)) for i in range(13)]
        p.add(tube(arch, 0.05, 6), c, "pearl")
    for k in range(5):
        t = k / 4
        a = math.pi * t
        p.add(tube([(1.35 * math.cos(a), -0.85, 2.1 + math.sin(a)), (1.35 * math.cos(a), 0.85, 2.1 + math.sin(a))], 0.025, 5), c, "pearl")
    rng = random.Random(501)
    for sy in (-1, 1):
        for sx in (-1, 1):
            vine = [(sx * 1.38, sy * 0.88, 0.1 + 0.3 * i) for i in range(7)] + \
                   [(sx * 1.35 * math.cos(math.pi * i / 12) * (1 if sx > 0 else 1), sy * 0.88, 2.1 + math.sin(math.pi * i / 12)) for i in (range(1, 6) if sx > 0 else range(11, 6, -1))]
            for i, (x, y, z) in enumerate(vine):
                if i % 3 == 0:
                    p.add(ico(0.16, 1), LEAF if i % 2 else LEAF_DARK, "leaf", T(x, y, z) @ S(1, 1, 0.8))
                if i % 3 == 1:
                    bloom(p, (x * 1.04, y * 1.08, z), 0.1, [ROSE, BLUSH, (0.95, 0.3, 0.45)][(i + sx) % 3], 2, 5, rng,
                          tilt=R("X", -80 * sy))


def gazebo(p, size, c):
    r = 2.4
    n = 8
    p.add(lathe([(0, 0), (r + 0.1, 0), (r + 0.1, 0.25), (0, 0.25)], n), WARM_STONE, "matte")
    for k in range(n):
        a = 2 * math.pi * k / n
        x, y = r * 0.95 * math.cos(a), r * 0.95 * math.sin(a)
        p.add(lathe([(0.1, 0), (0.08, 0.1), (0.07, 2.7), (0.1, 2.8)], 8), c, "pearl", T(x, y, 0.25))
        if k != 2:   # opening toward the front (+Y)
            nx, ny = r * 0.95 * math.cos(a + 2 * math.pi / n), r * 0.95 * math.sin(a + 2 * math.pi / n)
            p.add(tube([(x, y, 1.1), (nx, ny, 1.1)], 0.04, 5), c, "pearl")
            for j in range(4):
                t = (j + 1) / 5
                p.add(cyl(0.02, 0.8, 5), c, "pearl", T(x + (nx - x) * t, y + (ny - y) * t, 0.3))
        nx, ny = r * 0.95 * math.cos(a + 2 * math.pi / n), r * 0.95 * math.sin(a + 2 * math.pi / n)
        mid = ((x + nx) / 2, (y + ny) / 2)
        p.add(tube([(x, y, 2.8), (mid[0] * 0.98, mid[1] * 0.98, 2.6), (nx, ny, 2.8)], 0.035, 5), GOLD, "gold")
    roof = lathe([(r + 0.25, 3.05), (r * 0.8, 3.35), (r * 0.35, 4.1), (0.15, 4.6), (0.0, 4.7)], n)
    p.add(roof, mix(LILAC, PEARL, 0.25), "satin")
    p.add(lathe([(0, 2.95), (r + 0.25, 2.95), (r + 0.25, 3.05)], n), c, "pearl")
    p.add(lathe([(0.0, 0), (0.08, 0.05), (0.05, 0.2), (0.0, 0.35)], 8), GOLD, "gold", T(0, 0, 4.65))
    rng = random.Random(511)
    for k in range(5):
        a = 2 * math.pi * k / n + 0.3
        x, y = r * 1.0 * math.cos(a), r * 1.0 * math.sin(a)
        foliage_ball(p, x, y, 2.4, 0.22, LEAF, rng, 2, 1)
        bloom(p, (x * 1.06, y * 1.06, 2.45), 0.11, [ROSE, LILAC][k % 2], 2, 5, rng, tilt=R("Z", math.degrees(a)) @ R("Y", 80))


def sundial(p, size, c):
    p.add(lathe([(0.35, 0), (0.38, 0.06), (0.2, 0.15), (0.14, 0.3), (0.12, 0.9), (0.18, 1.0), (0.38, 1.08), (0.38, 1.12), (0, 1.12)], 12), c, "pearl")
    p.add(lathe([(0, 0), (0.34, 0), (0.34, 0.01), (0, 0.01)], 16), GOLD, "gold", T(0, 0, 1.12))
    p.add(slab([(-0.2, 0), (0.2, 0), (-0.2, 0.18)], 0.02), GOLD, "gold", T(0, 0, 1.12) @ R("Z", 90))
    for k in range(12):
        a = 2 * math.pi * k / 12
        p.add(box(0.01, 0.04, 0.005, seg=1), (0.55, 0.45, 0.55), "matte", T(0.27 * math.cos(a), 0.27 * math.sin(a), 1.132) @ R("Z", math.degrees(a)))


def birdbath(p, size, c):
    p.add(lathe([(0.3, 0), (0.32, 0.05), (0.15, 0.12), (0.1, 0.3), (0.08, 0.7), (0.15, 0.8), (0.4, 0.92), (0.42, 0.98), (0.36, 0.98), (0.0, 0.9)], 14), c, "pearl")
    p.add(disc(0.37, 14, 0.95), WATERC, "water")
    p.add(torus(0.4, 0.015, 14, 4), GOLD, "gold", T(0, 0, 0.97))
    rng = random.Random(521)
    # a tiny bird on the rim
    p.add(sphere(0.05, 8, 5), BLUSH, "satin", T(0.38, 0, 1.03) @ S(1.2, 0.9, 1))
    p.add(sphere(0.035, 8, 5), PERI, "satin", T(0.42, 0, 1.08))
    p.add(lathe([(0.01, 0), (0, 0.03)], 4), BUTTER, "satin", T(0.45, 0, 1.08) @ R("Y", 90))
    for k in range(4):
        p.add(petal(0.06, 0.05, cup=0.2), ROSE, "fabric", T(rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0.955) @ R("Z", rng.uniform(0, 360)))


def lamp_post(p, size, c):
    p.add(lathe([(0.18, 0), (0.18, 0.1), (0.1, 0.2), (0.07, 0.5), (0.05, 2.6), (0.08, 2.7)], 10), c, "gold")
    for sx in (-1, 1):
        p.add(scroll(0.12, 1.2, 10, 0.015), c, "gold", T(sx * 0.1, 0, 2.55) @ S(sx, 1, 1))
    p.add(lathe([(0.06, 0), (0.15, 0.05), (0.16, 0.35), (0.18, 0.38), (0.06, 0.48), (0.0, 0.52)], 8), (1.0, 0.85, 0.9, 0.4), "glass", T(0, 0, 2.7))
    p.add(lathe([(0.17, 0.36), (0.19, 0.39), (0.07, 0.49), (0.0, 0.53)], 8, cap_bottom=False), c, "gold", T(0, 0, 2.7))
    p.add(sphere(0.1, 8, 6), FLAME, "glow", T(0, 0, 2.9) @ S(1, 1, 1.3))
    p.add(lathe([(0.0, 0), (0.03, 0.03), (0.0, 0.12)], 6), c, "gold", T(0, 0, 3.22))


def obelisk(p, size, c):
    p.add(box(1.2, 1.2, 0.5, bevel=0.04), c, "pearl", T(0, 0, 0.25))
    p.add(box(1.0, 1.0, 0.3, bevel=0.03), lighter(c, 0.05), "pearl", T(0, 0, 0.65))
    shaft = lathe([(0.4, 0), (0.2, 4.6), (0, 5.0)], 4)
    p.add(shaft, c, "pearl", T(0, 0, 0.8) @ R("Z", 45), smooth=False)
    p.add(lathe([(0.0, 0), (0.12, 0.05), (0.0, 0.3)], 4), GOLD, "gold", T(0, 0, 5.75) @ R("Z", 45), smooth=False)
    for k in range(4):
        p.add(frame_ring(oval_outline(0.35, 0.5, 12), 0.02, 0.02), GOLD, "gold", R("Z", 90 * k) @ T(0, 0.34, 1.6))
    rng = random.Random(531)
    garland = [(0.42 * math.cos(t), 0.42 * math.sin(t), 0.82 + 0.05 * math.sin(4 * t)) for t in [i * 2 * math.pi / 16 for i in range(16)]]
    for i, (x, y, z) in enumerate(garland[::2]):
        bloom(p, (x * 1.05, y * 1.05, z + 0.03), 0.09, [ROSE, BLUSH, LILAC][i % 3], 2, 5, rng, tilt=R("Z", math.degrees(math.atan2(y, x))) @ R("Y", 70))


# ------------------------------------------------------------ stable


def stall_divider(p, size, c):
    d, h = 3.4, 1.8
    p.add(box(0.12, d, 1.2, bevel=0.015), c, "satin", T(0, 0, 0.6))
    for k in range(5):
        p.add(box(0.13, 0.02, 1.15, seg=1), darker(c, 0.1), "satin", T(0, -d / 2 + 0.5 + k * 0.6, 0.6))
    p.add(box(0.16, d, 0.08, bevel=0.02), OAK_DARK, "satin", T(0, 0, 1.24))
    for k in range(12):
        p.add(cyl(0.012, 0.5, 5), GOLD_DEEP, "gold", T(0, -d / 2 + 0.2 + k * 0.27, 1.28))
    p.add(box(0.16, d, 0.05, bevel=0.015), OAK_DARK, "satin", T(0, 0, 1.78))
    p.add(lathe([(0.06, 0), (0.08, 0.05), (0.0, 0.2)], 8), GOLD, "gold", T(0, d / 2 - 0.05, 1.8))
    p.add(slab(oval_outline(0.35, 0.18, 10), 0.02), PEARL, "pearl", T(0.07, d / 2 - 0.3, 1.0) @ R("Z", 90))


def hay_bale(p, size, c):
    b = box(1.0, 0.6, 0.6, bevel=0.06, seg=2)
    rng = random.Random(541)
    for v in b.verts:
        v.co += v.co.normalized() * rng.uniform(-0.01, 0.015)
    p.add(b, c, "matte", T(0, 0, 0.3))
    for x in (-0.25, 0.25):
        p.add(torus(1.0, 0.02, 4, 3), ROSE, "fabric", T(x, 0, 0.3) @ R("Y", 90) @ S(0.3, 0.31, 1))
    for k in range(10):
        p.add(cyl(0.006, 0.15, 3), lighter(c, 0.15), "matte", T(rng.uniform(-0.45, 0.45), rng.uniform(-0.28, 0.28), 0.58) @ R("X", rng.uniform(-60, 60)))


def hay_pile(p, size, c):
    rng = random.Random(551)
    pile = ico(1.0, 2)
    for v in pile.verts:
        if v.co.z < 0:
            v.co.z *= 0.05
        v.co += v.co.normalized() * rng.uniform(-0.06, 0.06)
    p.add(pile, c, "matte", S(1.0, 1.0, 0.8))
    for k in range(14):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.6, 1.05)
        p.add(cyl(0.008, 0.25, 3), lighter(c, 0.12), "matte", T(r * math.cos(a), r * math.sin(a), 0.0) @ R("Z", rng.uniform(0, 180)) @ R("Y", 85))
    star_flower(p, (0.3, 0.2, 0.78), 0.05, WHITE, 6)
    star_flower(p, (-0.2, -0.3, 0.7), 0.04, BUTTER, 6, heart=WHITE)


def saddle_rack(p, size, c):
    p.add(box(1.4, 0.08, 1.2, bevel=0.015), c, "satin", T(0, -0.26, 0.6))
    for x in (-0.35, 0.35):
        p.add(box(0.1, 0.5, 0.06, bevel=0.015), c, "satin", T(x, 0.0, 0.9))
        sad = sphere(0.25, 12, 8)
        for v in sad.verts:
            if v.co.z < 0:
                v.co.z *= 0.3
        p.add(sad, (0.88, 0.55, 0.62), "satin", T(x, 0.0, 0.95) @ S(0.9, 1.5, 0.5))
        p.add(box(0.5, 0.6, 0.02, bevel=0.01), [ROSE, PERI][x > 0], "fabric", T(x, 0.0, 0.93) @ R("Y", 0))
        p.add(torus(0.05, 0.01, 8, 3), GOLD, "gold", T(x + 0.22, 0.05, 0.7) @ R("Y", 90))
        p.add(tube([(x + 0.22, 0.05, 0.92), (x + 0.22, 0.05, 0.75)], 0.012, 4), (0.8, 0.5, 0.55), "satin")


def tack_wall(p, size, c):
    w, h = 2.4, 1.8
    p.add(box(w, 0.06, h, bevel=0.01), c, "satin", T(0, 0, h / 2))
    for k in range(5):
        x = -0.95 + k * 0.48
        p.add(cyl(0.02, 0.12, 6), GOLD, "gold", T(x, 0.03, 1.5) @ R("X", -90))
        if k % 2 == 0:   # bridle with rose-pink straps
            loop = [(x + 0.15 * math.sin(2 * math.pi * i / 12), 0.1, 1.2 + 0.3 * math.cos(2 * math.pi * i / 12)) for i in range(12)]
            p.add(tube(loop, 0.012, 3, closed=True), (0.9, 0.5, 0.6), "satin")
            p.add(torus(0.04, 0.01, 8, 3), GOLD, "gold", T(x, 0.1, 0.95) @ R("X", 90))
        else:            # coiled rope / reins
            for j in range(3):
                p.add(torus(0.13 - 0.01 * j, 0.015, 12, 3), CREAM if j % 2 else (0.85, 0.7, 0.55), "fabric", T(x, 0.08 + 0.01 * j, 1.28) @ R("X", 90))
    for k in range(3):
        p.add(lathe([(0.0, 0), (0.1, 0.04), (0.12, 0.08), (0.03, 0.1)], 10), GOLD_DEEP, "gold", T(-0.7 + k * 0.7, 0.06, 0.4) @ R("X", -90))
    crest(p, 0, 0.04, h - 0.05, 0.18)


def water_trough(p, size, c):
    p.add(box(2.0, 0.6, 0.55, bevel=0.04), c, "matte", T(0, 0, 0.28))
    p.add(box(1.85, 0.45, 0.02, seg=1), WATERC, "water", T(0, 0, 0.5))
    for sx in (-1, 1):
        p.add(sphere(0.05, 8, 5), GOLD, "gold", T(sx * 0.95, 0.25, 0.56))
    p.add(slab(oval_outline(0.25, 0.18, 10), 0.02), PEARL, "pearl", T(0, 0.31, 0.15))
    rng = random.Random(561)
    for k in range(3):
        star_flower(p, (rng.uniform(-0.8, 0.8), rng.uniform(-0.15, 0.15), 0.515), 0.05, [WHITE, BLUSH, BUTTER][k], 6)


def feed_bin(p, size, c):
    p.add(box(1.2, 0.7, 0.75, bevel=0.03), c, "satin", T(0, 0, 0.375))
    p.add(box(1.25, 0.75, 0.05, bevel=0.02), lighter(c, 0.1), "satin", T(0, -0.05, 0.86) @ R("X", -20))
    for x in (-0.55, 0.55):
        p.add(box(0.04, 0.72, 0.77, seg=1), GOLD_DEEP, "gold", T(x, 0, 0.385))
    for k in range(5):
        p.add(sphere(0.06, 6, 4), (0.98, 0.78, 0.45), "matte", T(-0.3 + 0.15 * k, 0.1, 0.78))
    p.add(lathe([(0, 0), (0.1, 0), (0.12, 0.12)], 8, cap_top=False), COPPER, "gold", T(0.35, 0.15, 0.75))


def cart_flower(p, size, c):
    w, h, d = 2.6, 1.6, 1.4
    p.add(box(1.9, 1.2, 0.35, bevel=0.03), c, "satin", T(-0.2, 0, 0.7))
    for sy in (-1, 1):
        p.add(torus(0.42, 0.04, 16, 4), lighter(c, 0.1), "satin", T(-0.2, sy * 0.66, 0.45) @ R("X", 90))
        for k in range(6):
            a = math.pi * k / 6
            p.add(cyl(0.015, 0.8, 4), lighter(c, 0.1), "satin", T(-0.2 - 0.4 * math.cos(a), sy * 0.66, 0.45 - 0.4 * math.sin(a)) @ R("Y", 90 - math.degrees(a)) @ T(0, 0, 0))
        p.add(cyl(0.06, 0.06, 8), GOLD, "gold", T(-0.2, sy * 0.66, 0.45) @ R("X", 90) @ T(0, 0, -0.03))
    for sy in (-1, 1):
        p.add(tube([(0.7, sy * 0.4, 0.7), (1.3, sy * 0.4, 0.55)], 0.03, 5), c, "satin")
    rng = random.Random(571)
    for k in range(6):
        x = -0.9 + (k % 3) * 0.55
        y = -0.3 + (k // 3) * 0.6
        p.add(ico(0.24, 1), LEAF, "leaf", T(x, y, 1.0) @ S(1.1, 1.1, 0.7))
        flower_spray(p, x, y, 1.1, 0.2, 3, [[ROSE, BLUSH], [LILAC, PERI], [BUTTER, WHITE]][k % 3], rng, 0.07, stems=False)


def carriage_gilt(p, size, c):
    w, h, d = 4.0, 2.8, 2.0
    # pumpkin-round body, gilt scrolls, big wheels: fairytale state coach
    body = sphere(0.95, 14, 8)
    for v in body.verts:
        a = math.atan2(v.co.y, v.co.x)
        v.co.x *= 1.0 + 0.04 * math.cos(8 * a)
    p.add(body, BLUSH, "pearl", T(0, 0, 1.55) @ S(1.15, 0.9, 1.0))
    for k in range(8):
        a = 2 * math.pi * k / 8
        arc = [(1.1 * math.cos(a) * math.sin(t), 0.86 * math.sin(a) * math.sin(t), 1.55 + 0.95 * math.cos(t)) for t in [i * math.pi / 8 for i in range(1, 8)]]
        p.add(tube(arc, 0.025, 4), c, "gold")
    for sy in (-1, 1):
        door = oval_outline(0.6, 0.9, 12)
        p.add(slab(door, 0.02), (0.9, 0.95, 1.0, 0.35), "glass", T(0, sy * 0.84, 1.15) @ R("Z", 0))
        p.add(frame_ring(door, 0.03, 0.03), c, "gold", T(0, sy * 0.85, 1.15))
    p.add(lathe([(0.0, 0), (0.2, 0.02), (0.15, 0.15), (0.0, 0.4)], 10), c, "gold", T(0, 0, 2.48))
    for sx, r_ in ((-1.3, 0.62), (1.2, 0.48)):
        for sy in (-1, 1):
            p.add(torus(r_, 0.05, 18, 4), c, "gold", T(sx, sy * 0.95, r_) @ R("X", 90))
            p.add(cyl(0.09, 0.1, 8), c, "gold", T(sx, sy * 0.95, r_) @ R("X", 90) @ T(0, 0, -0.05))
            for k in range(8):
                a = math.pi * k / 8
                p.add(cyl(0.018, 2 * r_, 4), c, "gold", T(sx - r_ * math.cos(a), sy * 0.95, r_ - r_ * math.sin(a)) @ R("Y", 90 - math.degrees(a)))
    p.add(tube([(-1.4, 0, 0.62), (0, 0, 0.6), (1.6, 0, 0.75), (1.9, 0, 1.2)], 0.06, 6), c, "gold")
    p.add(box(0.6, 1.2, 0.08, bevel=0.02), lighter(c, 0.2), "gold", T(1.6, 0, 1.25))
    p.add(cushion(0.5, 1.0, 0.12, 0.3), ROSE, "fabric", T(1.6, 0, 1.35))
    rng = random.Random(581)
    for k in range(5):
        a = 2 * math.pi * k / 5
        bloom(p, (0.0, 0.0, 0.0), 0.08, [ROSE, WHITE][k % 2], 2, 5, rng, tilt=T(0.18 * math.cos(a), 0.18 * math.sin(a), 2.5) @ R("Z", math.degrees(a)) @ R("Y", 50))


def horse_statue(p, size, c):
    p.add(box(1.0, 2.4, 0.4, bevel=0.04), c, "pearl", T(0, 0, 0.2))
    p.add(tube([(0, -0.55, 1.2), (0, 0.0, 1.25), (0, 0.55, 1.25)], [0.22, 0.26, 0.22], 10), c, "pearl")
    for sy, x, rear in ((-0.5, -0.12, True), (-0.5, 0.12, True), (0.5, -0.12, False), (0.5, 0.12, False)):
        if rear:
            p.add(tube([(x, sy, 1.1), (x, sy - 0.05, 0.75), (x, sy, 0.4)], [0.09, 0.06, 0.045], 6), c, "pearl")
        else:   # front legs raised in a prance
            p.add(tube([(x, sy, 1.1), (x, sy + 0.3, 1.0), (x, sy + 0.25, 0.72)], [0.08, 0.055, 0.045], 6), c, "pearl")
    p.add(tube([(0, 0.6, 1.35), (0, 0.85, 1.75), (0, 0.95, 1.85)], [0.16, 0.12, 0.1], 8), c, "pearl")
    p.add(tube([(0, 0.92, 1.88), (0, 1.15, 1.72)], [0.1, 0.06], 8), c, "pearl")
    for sx in (-1, 1):
        p.add(lathe([(0.03, 0), (0, 0.1)], 5), c, "pearl", T(sx * 0.05, 0.9, 1.95))
    mane = [(0, 0.55 + 0.4 * t, 1.45 + 0.5 * t + 0.03 * math.sin(t * 12)) for t in [i / 8 for i in range(9)]]
    p.add(tube(mane, 0.05, 5), GOLD, "gold", T(0, -0.08, 0.05))
    p.add(tube([(0, -0.7, 1.25), (0, -0.85, 1.0), (0, -0.8, 0.6)], [0.06, 0.08, 0.04], 6), GOLD, "gold")
    rng = random.Random(591)
    for k in range(4):
        bloom(p, (0, 0, 0), 0.06, ROSE if k % 2 else BLUSH, 2, 5, rng, tilt=T(0.0, 0.7 + 0.08 * k, 1.42 + 0.1 * k) @ R("X", -45))


# ------------------------------------------------------------ secrets


def secret_lever(p, size, c):
    p.add(box(0.12, 0.04, 0.12, bevel=0.01), OAK_DARK, "satin", T(0, -0.05, 0.06))
    p.add(tube([(0, -0.03, 0.06), (0, 0.02, 0.2), (0, 0.03, 0.26)], 0.012, 5), c, "gold")
    p.add(sphere(0.03, 8, 5), ROSE, "glass", T(0, 0.03, 0.27))
    p.add(petal(0.06, 0.04, cup=0.3), c, "gold", T(0, -0.03, 0.06) @ R("Y", -90))


def keepsake_glint(p, size, c):
    p.add(ico(0.06, 1), (1.0, 0.95, 0.75), "glow", S(1, 1, 1.4), smooth=False)
    for k in range(4):
        p.add(lathe([(0.015, 0), (0.0, 0.1)], 4), c, "glow", R("Z", 90 * k) @ R("Y", 90) @ T(0, 0, 0.04), smooth=False)
    p.add(lathe([(0.012, 0), (0.0, 0.12)], 4), c, "glow", T(0, 0, 0.05), smooth=False)
    p.add(lathe([(0.012, 0), (0.0, 0.12)], 4), c, "glow", T(0, 0, -0.05) @ R("X", 180), smooth=False)


def loose_panel(p, size, c):
    p.add(box(0.6, 0.04, 0.6, bevel=0.01), c, "satin", T(0, 0, 0.3))
    p.add(frame_ring([(-0.25, 0.05), (0.25, 0.05), (0.25, 0.55), (-0.25, 0.55)], 0.015, 0.02), GOLD, "gold", T(0, 0.025, 0))
    p.add(slab(oval_outline(0.16, 0.2, 10), 0.01), lighter(c, 0.15), "satin", T(0, 0.025, 0.2))
    p.add(box(0.015, 0.005, 0.5, seg=1), (0.3, 0.22, 0.25), "matte", T(0.29, 0.022, 0.3))


BUILDERS = {k: v for k, v in dict(globals()).items() if callable(v) and not k.startswith("_") and k in {
    "fireplace_grand", "fireplace_small", "column_marble", "pilaster", "arch_trellis", "balustrade", "gate_iron_gilt",
    "stone_steps", "painting_large", "painting_medium", "painting_small", "portrait_masked", "tapestry_roses",
    "statue_maiden", "statue_stag", "bust_pedestal", "vase_roses", "vase_tall", "urn_flowers", "potted_palm",
    "potted_roses", "flower_garland", "mirror_gilt", "clock_grandfather", "globe_stand", "birdcage_gilt",
    "mask_display", "altar_marble", "candle_bank", "pew", "bookcase_tall", "bookcase_low", "library_ladder",
    "reading_lectern", "book_stack", "map_table", "map_wall", "scroll_rack", "inkstand", "harp_gilt", "pianoforte",
    "music_stand", "lute_on_stand", "easel", "canvas_stack", "paint_table", "pigment_jars", "bathtub_clawfoot",
    "bath_sunken", "washstand", "towel_rack", "soap_shelf", "range_iron", "bread_oven", "hearth_kitchen",
    "copper_pots", "pot_rack_hanging", "dresser_crockery", "sink_stone", "barrel", "barrel_rack", "crate",
    "sack_flour", "basket_produce", "herb_bundle_hanging", "cheese_shelf", "wine_rack", "cake_stand",
    "pantry_shelf", "laundry_tub", "drying_line", "ironing_table", "linen_press", "stillroom_bench", "alembic",
    "drying_rack_herbs", "apothecary_cabinet", "mortar_pestle", "vial_rack", "infirmary_cot", "bandage_shelf",
    "weapon_rack", "bow_rack", "armor_stand", "target_straw", "quiver_barrel", "planter_box", "orange_tree_tub",
    "fern_pot", "fountain_small", "fountain_grand", "garden_bench", "garden_urn", "rose_arbor", "gazebo", "sundial",
    "birdbath", "lamp_post", "obelisk", "stall_divider", "hay_bale", "hay_pile", "saddle_rack", "tack_wall",
    "water_trough", "feed_bin", "cart_flower", "carriage_gilt", "horse_statue", "secret_lever", "keepsake_glint",
    "loose_panel"}}
