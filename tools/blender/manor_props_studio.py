"""Feyre's studio props, detailed (L30): easel, paint table, pigment jars and
canvas stack. Overrides the plainer part-B builders of the same ids.
Same contract as parts A-C: builder(p, size, color), front faces +Y, fitted
afterwards. Budget <= 3,000 tris each (manor_props.py checks).
Canon (Keeper, ch19/23): a clear-lit room, "a table full of canvases of various
sizes, brushes whose wooden handles gleamed ... and paints, so, so many paints";
paintings leaned against the walls. The princess look (pastel, gold, rounded,
little flourishes) is [X].
"""
import math
import random
from manor_props_a import crest, gilt_edge, knob, rose_cluster
from prop_kit import (BLUSH, BUTTER, CANVAS, GOLD, LILAC, MINT, OAK, OAK_DARK, PEARL, PERI, ROSE,
                      SOFT_BLUE, WHITE, R, S, T, box, cabriole, cyl, lathe, lighter, oval_outline, scroll,
                      slab, sphere, torus, tube)

PAINTS = [ROSE, PERI, MINT, BUTTER, LILAC, BLUSH, (0.95, 0.55, 0.45), (0.45, 0.62, 0.92), (0.55, 0.78, 0.55)]
RAG = (0.98, 0.92, 0.94)


# ------------------------------------------------------------ small pieces


def brush(p, base, tip_dir, length, col, rng, wide=False):
    """A paintbrush from `base` (handle end) along unit `tip_dir`: lacquered
    handle, gold ferrule, a bristle tuft dipped in `col`."""
    bx, by, bz = base
    dx, dy, dz = tip_dir
    hl = length * 0.68
    fx, fy, fz = bx + dx * hl, by + dy * hl, bz + dz * hl
    p.add(tube([(bx, by, bz), (fx, fy, fz)], [0.0045, 0.006], 5), [OAK, ROSE, PERI, LILAC][rng.randrange(4)], "satin")
    tx, ty, tz = fx + dx * length * 0.1, fy + dy * length * 0.1, fz + dz * length * 0.1
    p.add(tube([(fx, fy, fz), (tx, ty, tz)], 0.0065, 5), GOLD, "gold")
    ex, ey, ez = tx + dx * length * 0.18, ty + dy * length * 0.18, tz + dz * length * 0.18
    p.add(tube([(tx, ty, tz), (ex, ey, ez)], [0.0075 if wide else 0.006, 0.0015], 5), col, "satin")


def pot(p, x, y, z, r, h, col, rng, lid=False, drip=True, n=8):
    """A squat glazed paint pot with a rim, a dome of paint and a drip."""
    p.add(lathe([(0, 0), (r * 0.9, 0), (r, h * 0.85), (r * 1.08, h), (0, h)], n),
          PEARL, "pearl", T(x, y, z))
    p.add(lathe([(0, 0), (r * 0.9, 0), (r * 0.5, r * 0.3), (0, r * 0.32)], n, cap_bottom=False), col, "satin", T(x, y, z + h * 0.97))
    if drip:
        a = rng.uniform(0, 2 * math.pi)
        p.add(tube([(x + math.cos(a) * r * 1.02, y + math.sin(a) * r * 1.02, z + h * 0.95),
                    (x + math.cos(a) * r * 1.03, y + math.sin(a) * r * 1.03, z + h * 0.55)], [0.006, 0.004], 4), col, "satin")
        p.add(sphere(0.007, 5, 3), col, "satin", T(x + math.cos(a) * r * 1.03, y + math.sin(a) * r * 1.03, z + h * 0.53))
    if lid:
        p.add(lathe([(0, 0), (r * 1.05, 0), (r * 0.8, 0.012), (0.012, 0.02), (0.012, 0.035), (0, 0.04)], 10), GOLD, "gold",
              T(x + r * 1.6, y, z) @ R("Y", 70))


def palette_board(p, m, scale, rng):
    """A kidney palette with a thumb hole and blobs of paint; local XY plane."""
    pts = []
    for i in range(18):
        t = 2 * math.pi * i / 18
        rr = 1.0 - (0.35 if 0.3 < t < 1.0 else 0.0)
        pts.append((math.cos(t) * 0.2 * rr * scale, math.sin(t) * 0.14 * rr * scale))
    p.add(slab(pts, 0.012 * scale), OAK, "satin", m @ R("X", 90))
    p.add(torus(0.022 * scale, 0.006 * scale, 10, 4), OAK_DARK, "satin", m @ T(0.12 * scale, 0.05 * scale, 0.006))
    for k, col in enumerate(PAINTS[:6]):
        a = -2.4 + k * 0.72
        p.add(sphere(0.022 * scale, 5, 3), col, "satin",
              m @ T(math.cos(a) * 0.15 * scale, math.sin(a) * 0.1 * scale, 0.008 * scale) @ S(1, 1, 0.45))
    # two colours swirled together in the middle
    p.add(sphere(0.035 * scale, 7, 4), lighter(ROSE, 0.2), "satin", m @ T(-0.02 * scale, -0.01 * scale, 0.008) @ S(1.5, 1, 0.3))
    p.add(sphere(0.025 * scale, 7, 4), PERI, "satin", m @ T(0.02 * scale, -0.02 * scale, 0.009) @ S(1.3, 1, 0.3))


def rag(p, m, col=RAG, accent=ROSE):
    """A softly crumpled paint rag with a smear of colour."""
    pts = [(-0.12, -0.05), (0.0, -0.08), (0.13, -0.04), (0.11, 0.06), (-0.02, 0.09), (-0.13, 0.04)]
    p.add(slab(pts, 0.012, bevel=0.004), col, "fabric", m @ R("X", 90))
    p.add(sphere(0.045, 8, 5), col, "fabric", m @ T(0.02, 0.0, 0.02) @ S(1.2, 0.9, 0.5))
    p.add(sphere(0.02, 6, 4), accent, "fabric", m @ T(-0.05, 0.02, 0.012) @ S(1.6, 0.8, 0.2))


def painted_canvas(p, m, w, h, rng, scene=0, frame=None):
    """A stretched canvas (facing +Y in `m`) with a small pastel scene."""
    p.add(box(w, 0.025, h, bevel=0.004, seg=1), CANVAS, "matte", m @ T(0, 0, h / 2))
    if frame:
        p.add(tube([(-w / 2, -0.01, 0), (w / 2, -0.01, 0), (w / 2, -0.01, h), (-w / 2, -0.01, h)], 0.012, 4, closed=True),
              frame, "gold", m, smooth=False)
    skies = [(SOFT_BLUE, BLUSH), (lighter(LILAC, 0.2), BUTTER), (lighter(PERI, 0.3), lighter(ROSE, 0.4))]
    sky, glow = skies[scene % 3]
    iw = w * 0.9
    y = 0.0135
    p.add(box(iw, 0.002, h * 0.42, seg=1), sky, "matte", m @ T(0, y, h * 0.73))
    p.add(box(iw, 0.002, h * 0.12, seg=1), glow, "matte", m @ T(0, y, h * 0.47))
    hill = [(-iw / 2, 0), (iw / 2, 0), (iw / 2, h * 0.3), (iw * 0.15, h * 0.42), (-iw * 0.25, h * 0.33), (-iw / 2, h * 0.38)]
    p.add(slab(hill, 0.002), [(0.62, 0.84, 0.62), MINT, (0.7, 0.86, 0.66)][scene % 3], "matte", m @ T(0, y + 0.001, h * 0.05))
    for k in range(5):
        p.add(sphere(0.014 + 0.006 * (k % 2), 6, 4), [ROSE, BLUSH, LILAC, BUTTER, WHITE][k], "matte",
              m @ T(rng.uniform(-iw * 0.4, iw * 0.4), y + 0.003, h * rng.uniform(0.1, 0.3)) @ S(1, 0.2, 1))


# ------------------------------------------------------------ easel


def easel(p, size, c):
    rng = random.Random(1241)
    wood = lighter(OAK, 0.12)
    # Three legs: two front, one back, with gilt feet and finials.
    for sx in (-1, 1):
        pts = [(sx * 0.42, 0.18, 0.0), (sx * 0.25, 0.12, 0.9), (sx * 0.1, 0.06, 1.8)]
        p.add(tube(pts, [0.026, 0.022, 0.018], 6), wood, "satin")
        p.add(lathe([(0, 0), (0.035, 0), (0.03, 0.03), (0.022, 0.05), (0, 0.05)], 8), GOLD, "gold", T(sx * 0.42, 0.18, 0.0))
        p.add(lathe([(0, 0), (0.02, 0), (0.028, 0.03), (0.01, 0.07), (0.016, 0.09), (0, 0.12)], 8), GOLD, "gold", T(sx * 0.1, 0.06, 1.78))
    p.add(tube([(0, -0.55, 0.0), (0, -0.2, 0.9), (0, 0.04, 1.7)], [0.024, 0.02, 0.018], 6), wood, "satin")
    p.add(lathe([(0, 0), (0.035, 0), (0.03, 0.03), (0, 0.05)], 8), GOLD, "gold", T(0, -0.55, 0.0))
    # Cross bar and the hinge, a gilt heart with a little rose.
    p.add(tube([(-0.36, 0.17, 0.35), (0.36, 0.17, 0.35)], 0.014, 5), wood, "satin")
    p.add(tube([(0, -0.38, 0.42), (0, 0.15, 0.4)], 0.012, 5), wood, "satin")
    crest(p, 0, 0.09, 1.86, 0.16, GOLD)
    rose_cluster(p, 0, 0.12, 1.83, 0.03, 3, ROSE, rng, size=0.035)
    # The ledge: a tray with a gilt lip, brushes and a rag on it.
    p.add(box(0.86, 0.13, 0.03, bevel=0.008), wood, "satin", T(0, 0.22, 0.74))
    p.add(box(0.86, 0.015, 0.045, bevel=0.005), GOLD, "gold", T(0, 0.285, 0.765))
    for sx in (-1, 1):
        p.add(scroll(0.035, 1.3, 10, 0.007), GOLD, "gold", T(sx * 0.45, 0.24, 0.73) @ S(sx, 1, 1))
    for k in range(5):
        brush(p, (-0.38 + 0.07 * k, 0.21, 0.77), (0.98, 0.1, 0.05), 0.24, PAINTS[k], rng, wide=k == 2)
    rag(p, T(0.27, 0.21, 0.77) @ R("Z", 15), RAG, PERI)
    # The canvas on the easel, leaning back with the legs, and its top clamp.
    m = T(0, 0.17, 0.77) @ R("X", -8)
    painted_canvas(p, m, 0.74, 0.9, rng, 0)
    p.add(box(0.12, 0.05, 0.035, bevel=0.008), wood, "satin", m @ T(0, 0, 0.93))
    knob(p, 0, 0.17 + 0.03, 1.72, 0.018)
    # The palette hung on a peg, a drop cloth over the back leg.
    palette_board(p, T(0.46, 0.16, 1.0) @ R("Y", 25) @ R("X", 80), 1.0, rng)
    cloth = [(-0.18, 0.0), (0.18, 0.0), (0.2, 0.25), (0.08, 0.45), (-0.1, 0.42), (-0.2, 0.22)]
    p.add(slab(cloth, 0.01, bevel=0.003), lighter(BLUSH, 0.3), "fabric", T(0, -0.33, 0.3) @ R("X", 23) @ R("Z", 90) @ R("X", 90))
    for k, col in enumerate([ROSE, PERI, BUTTER]):
        p.add(sphere(0.02, 6, 4), col, "fabric", T(0.02 * (k - 1) * 3, -0.36, 0.55 - 0.08 * k) @ S(1.4, 0.3, 1))


# ------------------------------------------------------------ paint table


def paint_table(p, size, c):
    rng = random.Random(1261)
    w, h, d = 1.2, 0.85, 0.7
    top = lighter(PEARL, 0.05)
    # A pearl-painted work table with cabriole legs, gilt edging and a drawer.
    for sx, sy, a in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        p.add(cabriole(h - 0.06, 0.03), top, "satin", T(sx * (w / 2 - 0.07), sy * (d / 2 - 0.07), 0) @ R("Z", a))
        p.add(sphere(0.026, 5, 3), GOLD, "gold", T(sx * (w / 2 - 0.07), sy * (d / 2 - 0.07), 0.02))
    p.add(box(w - 0.1, d - 0.1, 0.1, bevel=0.01), top, "satin", T(0, 0, h - 0.1))
    p.add(box(w, d, 0.035, bevel=0.012), top, "pearl", T(0, 0, h - 0.018))
    gilt_edge(p, w, d, h - 0.003, 0.008)
    p.add(box(0.4, 0.012, 0.06, bevel=0.005), lighter(BLUSH, 0.2), "satin", T(0, d / 2 - 0.045, h - 0.1))
    knob(p, 0, d / 2 - 0.035, h - 0.1, 0.016)
    for sx in (-1, 1):
        p.add(scroll(0.03, 1.2, 6, 0.006), GOLD, "gold", T(sx * 0.27, d / 2 - 0.04, h - 0.1) @ S(sx, 1, 1))
    # A lower shelf with a stack of fresh canvases and a jar of water.
    p.add(box(w - 0.18, d - 0.18, 0.02, bevel=0.005), top, "satin", T(0, 0, 0.2))
    for k in range(3):
        p.add(box(0.42 - 0.06 * k, 0.32 - 0.04 * k, 0.025), CANVAS, "matte", T(-0.22, 0.0, 0.225 + 0.026 * k) @ R("Z", 4 * k))
    p.add(lathe([(0, 0), (0.06, 0), (0.065, 0.13), (0.055, 0.15), (0, 0.15)], 8, cap_top=False), SOFT_BLUE, "glass", T(0.3, 0.05, 0.21))
    z = h
    # Paint pots in a row along the back, a brush jar, oil bottles.
    for k in range(6):
        pot(p, -0.5 + 0.09 * k, -0.22 + 0.03 * (k % 2), z, 0.034, 0.05 + 0.012 * (k % 3), PAINTS[k], rng, lid=k == 5, drip=k % 2 == 0, n=7)
    p.add(lathe([(0, 0), (0.05, 0), (0.055, 0.16), (0.06, 0.17), (0, 0.17)], 10, cap_top=False), PERI, "glass", T(0.36, -0.2, z))
    p.add(torus(0.055, 0.006, 10, 4), GOLD, "gold", T(0.36, -0.2, z + 0.12))
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        brush(p, (0.36 + math.cos(a) * 0.02, -0.2 + math.sin(a) * 0.02, z + 0.03),
              (math.cos(a) * 0.18, math.sin(a) * 0.18, 0.97), 0.34, PAINTS[k], rng, wide=k % 3 == 0)
    for k, col in enumerate([BUTTER, lighter(ROSE, 0.3)]):
        x = 0.5 - 0.07 * k
        p.add(lathe([(0, 0), (0.028, 0), (0.03, 0.1), (0.012, 0.13), (0.01, 0.16), (0, 0.16)], 7), col, "glass", T(x, -0.24, z))
        p.add(sphere(0.013, 5, 3), GOLD, "gold", T(x, -0.24, z + 0.165))
    # The palette, mid-mix, with a palette knife and two loose brushes.
    palette_board(p, T(-0.05, 0.08, z + 0.01), 1.15, rng)
    p.add(box(0.16, 0.012, 0.003), WHITE, "mirror", T(0.18, 0.12, z + 0.005) @ R("Z", -20))
    p.add(tube([(0.25, 0.09, z + 0.006), (0.33, 0.06, z + 0.006)], 0.006, 5), OAK_DARK, "satin")
    brush(p, (0.42, 0.18, z + 0.008), (-0.97, 0.2, 0.0), 0.26, ROSE, rng)
    brush(p, (0.48, 0.1, z + 0.008), (-0.92, 0.38, 0.0), 0.24, MINT, rng, wide=True)
    # A rag, a small sketch pinned under a gilt weight, and a posy in a cup.
    rag(p, T(0.4, 0.22, z + 0.01) @ R("Z", -25), RAG, LILAC)
    p.add(box(0.22, 0.16, 0.003, seg=1), CANVAS, "fabric", T(-0.42, 0.18, z + 0.003) @ R("Z", 12))
    p.add(tube([(-0.49, 0.15, z + 0.006), (-0.4, 0.22, z + 0.006), (-0.36, 0.16, z + 0.006)], 0.0025, 3), (0.35, 0.3, 0.4), "matte")
    p.add(cyl(0.022, 0.018, 8), GOLD, "gold", T(-0.33, 0.12, z))
    p.add(lathe([(0, 0), (0.03, 0), (0.04, 0.07), (0.035, 0.08), (0, 0.08)], 8, cap_top=False), PEARL, "pearl", T(-0.55, 0.2, z))
    rose_cluster(p, -0.55, 0.2, z + 0.11, 0.03, 2, BLUSH, rng, size=0.032)
    # Paint splashes on the table top (her habit, canon: paint-splattered).
    for k in range(3):
        p.add(sphere(0.012 + 0.008 * rng.random(), 5, 3), PAINTS[rng.randrange(len(PAINTS))], "satin",
              T(rng.uniform(-0.55, 0.55), rng.uniform(-0.3, 0.3), z + 0.002) @ S(1.6, 1.1, 0.12))


# ------------------------------------------------------------ jars and canvases


def pigment_jars(p, size, c):
    rng = random.Random(1271)
    # A gilt-edged tray of pigment jars with ribboned lids and powder heaps.
    p.add(box(0.62, 0.32, 0.02, bevel=0.006), PEARL, "pearl", T(0, 0, 0.01))
    gilt_edge(p, 0.62, 0.32, 0.022, 0.006)
    for k in range(6):
        x = -0.24 + 0.096 * k
        y = 0.06 if k % 2 else -0.04
        col = PAINTS[k]
        hj = 0.11 + 0.03 * (k % 3)
        p.add(lathe([(0, 0), (0.032, 0), (0.036, 0.02), (0.036, hj * 0.8), (0.026, hj * 0.9), (0.026, hj), (0, hj)], 10, cap_top=False),
              lighter(col, 0.55), "glass", T(x, y, 0.02))
        p.add(lathe([(0, 0), (0.033, 0), (0.03, hj * 0.6), (0, hj * 0.66)], 10), col, "matte", T(x, y, 0.025))
        p.add(lathe([(0, 0), (0.03, 0), (0.03, 0.015), (0.012, 0.03), (0.008, 0.04), (0, 0.045)], 10), GOLD, "gold", T(x, y, 0.02 + hj))
        p.add(torus(0.028, 0.005, 10, 4), [ROSE, LILAC, MINT][k % 3], "fabric", T(x, y, 0.02 + hj * 0.92))
    for k in range(3):
        col = PAINTS[k + 3]
        p.add(sphere(0.04, 8, 5), col, "matte", T(-0.2 + 0.2 * k, -0.12, 0.02) @ S(1.1, 0.8, 0.45))
    p.add(lathe([(0, 0), (0.05, 0), (0.06, 0.02), (0, 0.02)], 10), PEARL, "pearl", T(0.24, -0.12, 0.02))
    p.add(sphere(0.012, 6, 4), GOLD, "gold", T(0.26, -0.11, 0.045))


def canvas_stack(p, size, c):
    rng = random.Random(1251)
    # Finished canvases leaned against each other, the front ones painted,
    # with a gilt-framed one and a ribbon tied round the back two.
    for k in range(4):
        w = 0.9 - k * 0.12
        h = 1.15 - k * 0.15
        m = T(-0.03 * k, 0.08 * k - 0.12, 0) @ R("X", -10)
        if k == 0:
            p.add(box(w, 0.03, h, bevel=0.006, seg=1), lighter(OAK, 0.15), "satin", m @ T(0, 0, h / 2))
            for sx in (-1, 1):
                p.add(box(0.03, 0.035, h * 0.98, seg=1), OAK, "satin", m @ T(sx * (w / 2 - 0.03), 0.02, h / 2))
            p.add(box(w * 0.94, 0.035, 0.03, seg=1), OAK, "satin", m @ T(0, 0.02, h * 0.5))
        else:
            painted_canvas(p, m, w, h, rng, k, frame=GOLD if k == 3 else None)
    p.add(torus(0.42, 0.006, 16, 4), ROSE, "fabric", T(-0.02, -0.06, 0.55) @ R("Y", 90) @ S(1, 0.25, 1))
    p.add(scroll(0.04, 1.4, 10, 0.008), ROSE, "fabric", T(0.2, -0.02, 0.62))
    p.add(scroll(0.04, 1.4, 10, 0.008), ROSE, "fabric", T(0.23, -0.02, 0.62) @ S(-1, 1, 1))


BUILDERS = {"easel": easel, "paint_table": paint_table, "pigment_jars": pigment_jars, "canvas_stack": canvas_stack}
