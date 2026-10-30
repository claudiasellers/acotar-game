"""Manor prop models, part A: bedroom, dressing room, furniture, lighting.

Each builder takes (p, size, color): p is a prop_kit.Prop, size the catalogue
(w, h, d) in metres, color the catalogue colour. Model roughly to size; the
generator fits every prop to its catalogue box afterwards. Front faces +Y.
"""

import math
import random

from prop_kit import (BLUSH, BUTTER, CANVAS, COPPER, CREAM, FLAME, GOLD, LILAC, MINT, OAK, OAK_DARK, PEARL, PERI,
                      ROSE, WHITE, R, S, T, arc_pts, arched_outline, bloom, box, cabriole, cushion, cyl, darker, disc,
                      frame_ring, ico, lathe, lighter, mix, oval_outline, petal, scroll, slab, sphere, torus, tube,
                      turned_leg)

# ------------------------------------------------------------ shared bits


def cab_legs(p, w, d, h, r, color, finish="gold", inset=0.06):
    """Cabriole legs with knees pointing outward at each corner."""
    for sx, sy, a in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        p.add(cabriole(h, r), color, finish, T(sx * (w / 2 - inset), sy * (d / 2 - inset), 0) @ R("Z", a))


def knob(p, x, y, z, r=0.022, color=GOLD):
    p.add(sphere(r, 8, 5), color, "gold", T(x, y, z))


def drawer_row(p, w, z, h, y, n, color, trim=GOLD):
    gap = 0.02
    dw = (w - gap * (n + 1)) / n
    for i in range(n):
        x = -w / 2 + gap + dw / 2 + i * (dw + gap)
        p.add(box(dw, 0.02, h - gap, bevel=0.008), lighter(color, 0.08), "satin", T(x, y, z))
        knob(p, x, y + 0.02, z, 0.018, trim)


def gilt_edge(p, w, d, z, r=0.012, color=GOLD):
    pts = [(-w / 2, -d / 2, z), (w / 2, -d / 2, z), (w / 2, d / 2, z), (-w / 2, d / 2, z)]
    p.add(tube(pts, r, 5, closed=True), color, "gold", smooth=False)


def crest(p, x, y, z, s=0.15, color=GOLD):
    """Gilt shell-and-scroll crest, facing +Y."""
    p.add(scroll(s * 0.5, 1.2, 12, s * 0.07), color, "gold", T(x - s * 0.45, y, z) @ R("Y", 180))
    p.add(scroll(s * 0.5, 1.2, 12, s * 0.07), color, "gold", T(x + s * 0.45, y, z) @ S(-1, 1, 1) @ R("Y", 180))
    p.add(lathe([(0, 0), (s * 0.35, s * 0.1), (s * 0.3, s * 0.3), (0, s * 0.45)], 8), color, "gold", T(x, y, z) @ S(1, 0.35, 1))


def heart_crest(p, x, y, z, s, color=GOLD):
    pts = []
    for i in range(17):
        t = math.pi * 2 * i / 16
        pts.append((x + s * 0.06 * 16 * math.sin(t) ** 3 / 16 * 1.0, y,
                    z + s * (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 16 / 16 * 1.0))
    p.add(tube(pts, s * 0.05, 5, closed=True), color, "gold")


def mirror_panel(p, w, h, z0, y, outline="arch", frame=GOLD, glass=(0.92, 0.88, 1.0), fw=0.05, depth=0.03):
    if outline == "oval":
        ol = oval_outline(w, h, 20)
    else:
        ol = arched_outline(w, h, 10)
    p.add(slab(ol, depth), glass, "mirror", T(0, y, z0))
    p.add(frame_ring(ol, fw, depth), frame, "gold", T(0, y + depth * 0.3, z0))


def candle(p, x, y, z, h=0.18, r=0.022, wax=CREAM):
    p.add(cyl(r, h, 6), wax, "satin", T(x, y, z))
    p.add(lathe([(0, 0), (r * 0.6, r * 0.8), (r * 0.45, r * 2.2), (0, r * 3.2)], 5), FLAME, "glow", T(x, y, z + h))


def rose_cluster(p, cx, cy, cz, spread, n, color, rng, size=0.06, leaves=True):
    from prop_kit import LEAF, leaf
    for i in range(n):
        a = rng.uniform(0, 360)
        d = rng.uniform(0, spread)
        x, y = cx + d * math.cos(math.radians(a)), cy + d * math.sin(math.radians(a))
        z = cz + rng.uniform(-0.3, 0.3) * size
        tilt = R("X", rng.uniform(-25, 25)) @ R("Y", rng.uniform(-25, 25))
        c = color if i % 3 else lighter(color, 0.2)
        bloom(p, (x, y, z), size * rng.uniform(0.85, 1.15), c, 2, 5, rng, tilt=tilt)
        if leaves and i % 2 == 0:
            p.add(leaf(size * 1.6, size * 0.8), LEAF, "leaf", T(x, y, z - size * 0.3) @ R("Z", a + 140) @ R("Y", 20))


# ------------------------------------------------------------ bedroom


def bed_canopy(p, size, c):
    w, h, d = 2.4, 3.2, 2.6
    # four gilt posts with finials
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.08), sy * (d / 2 - 0.08)
            p.add(lathe([(0.06, 0), (0.07, 0.1), (0.045, 0.2), (0.04, 2.7), (0.06, 2.8), (0.04, 2.9)], 6), PEARL, "pearl", T(x, y, 0))
            p.add(lathe([(0.03, 0), (0.06, 0.06), (0.05, 0.14), (0, 0.3)], 8), GOLD, "gold", T(x, y, 2.9))
    # frame and mattress
    p.add(box(w - 0.1, d - 0.1, 0.3, bevel=0.04), PEARL, "pearl", T(0, 0, 0.35))
    p.add(cushion(w - 0.2, d - 0.25, 0.3, 0.2), WHITE, "fabric", T(0, 0.02, 0.65))
    # quilted coverlet draping over the foot
    p.add(cushion(w - 0.1, d * 0.62, 0.12, 0.3), c, "fabric", T(0, 0.38, 0.78))
    p.add(box(w - 0.1, 0.06, 0.35, bevel=0.02), c, "fabric", T(0, d / 2 - 0.08, 0.6))
    # pillows
    for x in (-0.5, 0.5):
        p.add(cushion(0.7, 0.4, 0.2, 0.5), lighter(c, 0.4), "fabric", T(x, -d / 2 + 0.45, 0.9) @ R("X", -20))
    p.add(cushion(0.45, 0.25, 0.25, 0.5, 1), ROSE, "fabric", T(0, -d / 2 + 0.7, 0.9) @ R("X", -15))
    # headboard: arched padded panel with gilt frame + heart
    hb = arched_outline(w - 0.2, 1.5, 12, 0.5)
    p.add(slab(hb, 0.08), lighter(c, 0.15), "fabric", T(0, -d / 2 + 0.06, 0.5))
    p.add(frame_ring(hb, 0.035, 0.08), GOLD, "gold", T(0, -d / 2 + 0.1, 0.5))
    crest(p, 0, -d / 2 + 0.12, 1.95, 0.25)
    # canopy: rails, swagged valance and curtains tied back
    p.add(box(w, d, 0.08, bevel=0.03), PEARL, "pearl", T(0, 0, 3.0))
    gilt_edge(p, w, d, 2.96, 0.02)
    for sy in (-1, 1):
        pts = [(-w / 2 + 0.05 + (w - 0.1) * i / 8, sy * (d / 2 + 0.02), 2.9 - 0.18 * math.sin(math.pi * ((i % 4) / 4))) for i in range(9)]
        p.add(tube(pts, 0.06, 6), lighter(c, 0.25), "fabric")
    for sx in (-1, 1):
        pts = [(sx * (w / 2 + 0.02), -d / 2 + 0.05 + (d - 0.1) * i / 8, 2.9 - 0.18 * math.sin(math.pi * ((i % 4) / 4))) for i in range(9)]
        p.add(tube(pts, 0.06, 6), lighter(c, 0.25), "fabric")
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.05), sy * (d / 2 - 0.05)
            # gathered curtain: tapered tube cinched at the tie
            pts = [(x, y, 2.95), (x - sx * 0.12, y, 2.2), (x - sx * 0.02, y, 1.4), (x - sx * 0.15, y, 0.35)]
            p.add(tube(pts, [0.12, 0.13, 0.05, 0.16], 6), lighter(c, 0.3), "fabric")
            p.add(torus(0.07, 0.015, 10, 4), GOLD, "gold", T(x - sx * 0.02, y, 1.4))
    rng = random.Random(7)
    rose_cluster(p, 0, -d / 2 + 0.1, 3.05, 0.15, 2, ROSE, rng, 0.09, False)


def bed_single(p, size, c):
    w, d = 1.2, 2.1
    p.add(box(w, d, 0.25, bevel=0.03), OAK, "satin", T(0, 0, 0.3))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(turned_leg(0.3 if sy > 0 else 0.3, 0.05, 8), OAK, "satin", T(sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), 0))
    p.add(cushion(w - 0.1, d - 0.15, 0.22, 0.2), WHITE, "fabric", T(0, 0.04, 0.53))
    p.add(cushion(w - 0.05, d * 0.6, 0.1, 0.3), c, "fabric", T(0, 0.35, 0.66))
    p.add(cushion(0.7, 0.38, 0.18, 0.5), lighter(c, 0.4), "fabric", T(0, -d / 2 + 0.3, 0.72) @ R("X", -15))
    hb = arched_outline(w, 0.6, 8, 0.25)
    p.add(slab(hb, 0.06), OAK, "satin", T(0, -d / 2 + 0.03, 0.45))
    heart_crest(p, 0, -d / 2 + 0.07, 0.7, 0.18, ROSE)


def bed_servant(p, size, c):
    w, d = 1.0, 2.0
    p.add(box(w, d, 0.18, bevel=0.02), OAK, "matte", T(0, 0, 0.28))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(box(0.07, 0.07, 0.28, bevel=0.01), OAK, "matte", T(sx * (w / 2 - 0.05), sy * (d / 2 - 0.05), 0.14))
    p.add(cushion(w - 0.08, d - 0.1, 0.16, 0.2), CREAM, "fabric", T(0, 0, 0.44))
    p.add(cushion(w - 0.02, d * 0.55, 0.08, 0.3), mix(MINT, CREAM, 0.4), "fabric", T(0, 0.4, 0.54))
    p.add(cushion(0.6, 0.35, 0.14, 0.5), WHITE, "fabric", T(0, -d / 2 + 0.28, 0.58))
    p.add(box(w, 0.06, 0.55, bevel=0.015), OAK, "matte", T(0, -d / 2 + 0.03, 0.5))


def cradle_chest(p, size, c):
    _chest(p, 1.2, 0.6, 0.7, c, painted=True)


def _chest(p, w, d, h, c, painted=False):
    p.add(box(w, d, h * 0.7, bevel=0.03), c, "satin", T(0, 0, h * 0.35 + 0.04))
    # domed lid: half cylinder along X
    p.add(box(w + 0.02, d + 0.02, 0.06, bevel=0.02), darker(c, 0.1), "satin", T(0, 0, h * 0.7 + 0.04))
    dome = cyl(d / 2, w, 12)
    p.add(dome, lighter(c, 0.05), "satin", T(-w / 2, 0, h * 0.72) @ R("Y", 90) @ S(0.45, 1, 1) @ T(0, 0, 0))
    for x in (-w / 2 + 0.06, w / 2 - 0.06, -w * 0.15, w * 0.15):
        p.add(box(0.04, d + 0.04, h * 0.72, bevel=0.01), GOLD, "gold", T(x, 0, h * 0.36 + 0.04))
    p.add(box(0.12, 0.03, 0.14, bevel=0.01), GOLD, "gold", T(0, d / 2 + 0.01, h * 0.62))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(sphere(0.045, 8, 5), GOLD, "gold", T(sx * (w / 2 - 0.08), sy * (d / 2 - 0.08), 0.04))
    if painted:
        rng = random.Random(3)
        for x in (-w * 0.33, w * 0.33):
            bloom(p, (x, d / 2 + 0.01, h * 0.38), 0.08, ROSE, 2, 5, rng, tilt=R("X", -90))


def nightstand(p, size, c):
    w, d, h = 0.6, 0.5, 0.7
    cab_legs(p, w, d, 0.22, 0.025, GOLD, inset=0.05)
    p.add(box(w, d, 0.42, bevel=0.03), c, "satin", T(0, 0, 0.43))
    p.add(box(w + 0.05, d + 0.05, 0.04, bevel=0.015), lighter(c, 0.1), "pearl", T(0, 0, 0.66))
    drawer_row(p, w - 0.06, 0.5, 0.16, d / 2 + 0.005, 1, c)
    drawer_row(p, w - 0.06, 0.32, 0.16, d / 2 + 0.005, 1, c)
    gilt_edge(p, w + 0.05, d + 0.05, 0.64, 0.008)
    candle(p, 0.15, 0, 0.68, 0.12)
    p.add(lathe([(0.0, 0), (0.06, 0.0), (0.07, 0.01), (0.03, 0.02), (0, 0.02)], 10), GOLD, "gold", T(0.15, 0, 0.68))
    rng = random.Random(4)
    p.add(lathe([(0.03, 0), (0.05, 0.05), (0.025, 0.14), (0.035, 0.18)], 10), PERI, "glass", T(-0.15, 0.05, 0.68))
    bloom(p, (-0.15, 0.05, 0.9), 0.05, ROSE, 2, 5, rng)


def wardrobe_tall(p, size, c):
    w, h, d = 1.8, 2.4, 0.7
    p.add(box(w, d, h - 0.3, bevel=0.03), c, "satin", T(0, 0, (h - 0.3) / 2 + 0.12))
    p.add(box(w + 0.1, d + 0.08, 0.1, bevel=0.03), lighter(c, 0.08), "pearl", T(0, 0, h - 0.17))
    # bonnet top with crest
    bon = arched_outline(w * 0.7, 0.3, 10, 0.25)
    p.add(slab(bon, 0.06), c, "satin", T(0, d / 2 - 0.05, h - 0.13))
    crest(p, 0, d / 2 - 0.0, h - 0.05, 0.18)
    for sx in (-1, 1):
        # door panel: raised arched inset with mirror on the left
        panel = arched_outline(w / 2 - 0.2, h - 0.75, 10, 0.25)
        x = sx * w / 4
        p.add(slab(panel, 0.03), lighter(c, 0.12) if sx > 0 else (0.92, 0.88, 1.0), "satin" if sx > 0 else "mirror", T(x, d / 2 + 0.01, 0.35))
        p.add(frame_ring(panel, 0.018, 0.03), GOLD, "gold", T(x, d / 2 + 0.02, 0.35))
        p.add(lathe([(0.012, 0), (0.016, 0.06), (0.01, 0.12)], 6), GOLD, "gold", T(sx * 0.06, d / 2 + 0.03, 1.1))
    p.add(box(0.02, d * 0.1, h - 0.4), darker(c, 0.15), "matte", T(0, d / 2, (h - 0.3) / 2 + 0.12))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(lathe([(0.05, 0), (0.07, 0.06), (0.06, 0.12)], 8), GOLD, "gold", T(sx * (w / 2 - 0.08), sy * (d / 2 - 0.08), 0))


def dresser(p, size, c):
    w, h, d = 1.4, 1.0, 0.6
    cab_legs(p, w, d, 0.15, 0.03, GOLD)
    body = box(w, d, 0.8, bevel=0.04)
    for v in body.verts:          # bombé belly: front bulges
        if v.co.y > 0:
            v.co.y += 0.06 * (1 - (2 * v.co.z / 0.8) ** 2) * (1 - (2 * v.co.x / w) ** 2)
    p.add(body, c, "satin", T(0, 0, 0.55))
    p.add(box(w + 0.06, d + 0.06, 0.05, bevel=0.02), MINT if c == PEARL else lighter(c, 0.1), "pearl", T(0, 0, 0.97))
    for i, z in enumerate((0.3, 0.55, 0.8)):
        drawer_row(p, w - 0.1, z, 0.22, d / 2 + 0.045, 2, c)
    gilt_edge(p, w + 0.06, d + 0.06, 0.95, 0.01)
    rng = random.Random(9)
    p.add(lathe([(0.04, 0), (0.08, 0.06), (0.04, 0.2), (0.06, 0.25)], 10), BLUSH, "pearl", T(-0.45, 0, 1.0))
    rose_cluster(p, -0.45, 0, 1.3, 0.06, 4, ROSE, rng, 0.05, False)


# ------------------------------------------------------------ dressing room


def vanity_table(p, size, c):
    w, h, d = 1.4, 0.8, 0.6
    cab_legs(p, w, d, 0.62, 0.035, GOLD, inset=0.07)
    # kidney-shaped top
    ol = [(w / 2 * math.cos(2 * math.pi * i / 24), d / 2 * math.sin(2 * math.pi * i / 24) * (1 - 0.25 * max(0, math.sin(2 * math.pi * i / 24)))) for i in range(24)]
    p.add(slab([(x, y) for x, y in ol], 0.05, 0.012), c, "pearl", T(0, 0, 0.74) @ R("X", 90))
    p.add(box(w - 0.15, d - 0.18, 0.12, bevel=0.03), lighter(c, 0.05), "satin", T(0, -0.04, 0.66))
    # ruffled skirt (blush tulle) hung from the apron
    n = 28
    pts = []
    for i in range(n + 1):
        t = i / n
        a = math.pi * (1.0 - t)
        pts.append((w / 2 * 1.02 * math.cos(a), d * 0.42 * math.sin(a) + 0.02, 0.6))
    for i in range(0, n + 1, 2):
        x, y, z = pts[i]
        p.add(tube([(x, y, 0.66), (x * 1.04, y * 1.05 + 0.02, 0.3), (x * 1.08, y * 1.1 + 0.03, 0.02)], [0.02, 0.05, 0.075], 6),
              BLUSH, "fabric")
    p.add(tube([(x, y, 0.66) for x, y, _ in pts], 0.03, 6), ROSE, "fabric")
    drawer_row(p, 0.5, 0.66, 0.1, d / 2 - 0.08, 1, c)
    # treasures on top: perfume bottles, powder puff, hand mirror
    rng = random.Random(12)
    for i, (x, col) in enumerate(((-0.5, PERI), (-0.42, ROSE), (-0.34, MINT))):
        p.add(lathe([(0.0, 0), (0.035, 0.0), (0.04, 0.04), (0.012, 0.09), (0.015, 0.1), (0.0, 0.1)], 10), col, "glass", T(x, 0.05, 0.77))
        p.add(sphere(0.016, 8, 5), GOLD, "gold", T(x, 0.05, 0.885))
    p.add(lathe([(0, 0), (0.07, 0.0), (0.075, 0.02), (0.06, 0.03), (0, 0.03)], 12), PEARL, "pearl", T(0.42, 0.06, 0.77))
    p.add(sphere(0.055, 10, 6), BLUSH, "fabric", T(0.42, 0.06, 0.82) @ S(1, 1, 0.55))
    p.add(slab(oval_outline(0.12, 0.16, 12), 0.012), (0.92, 0.88, 1.0), "mirror", T(0.15, 0.08, 0.775) @ R("X", -88))
    p.add(cyl(0.012, 0.12, 6), GOLD, "gold", T(0.15, -0.0, 0.79) @ R("X", 90))


def vanity_mirror(p, size, c):
    w, h = 1.2, 1.6
    ol = arched_outline(w * 0.85, h * 0.85, 14, w * 0.42)
    p.add(slab(ol, 0.03), (0.93, 0.9, 1.0), "mirror", T(0, 0, h * 0.06))
    p.add(frame_ring(ol, 0.05, 0.05), GOLD, "gold", T(0, 0.02, h * 0.06))
    p.add(slab(ol, 0.02), lighter(c, 0.2), "gold", T(0, -0.04, h * 0.06) @ S(1.08, 1, 1.04))
    crest(p, 0, 0.04, h * 0.91, 0.3)
    heart_crest(p, 0, 0.06, h * 0.95, 0.12, ROSE)
    rng = random.Random(21)
    # roses climbing the frame
    for i, t in enumerate((0.15, 0.3, 0.45)):
        for sx in (-1, 1):
            a = math.pi * (0.5 + sx * 0.5) if t < 0.4 else math.pi * (0.5 - sx * 0.3)
            x = sx * w * 0.43
            z = h * 0.06 + h * 0.85 * (0.1 + t)
            bloom(p, (x, 0.06, z), 0.05, ROSE if (i + sx) % 2 else BLUSH, 2, 5, rng, tilt=R("X", -80))
    # little bulb lights around the arch (Hollywood-vanity sparkle)
    for i in range(9):
        a = math.pi * i / 8
        x = w * 0.48 * math.cos(a)
        z = h * 0.06 + h * 0.85 - w * 0.42 + w * 0.48 * math.sin(a)
        p.add(sphere(0.025, 8, 5), (1.0, 0.95, 0.8), "glow", T(x, 0.05, z))
    for sx in (-1, 1):
        for z in (0.35, 0.65):
            p.add(sphere(0.025, 8, 5), (1.0, 0.95, 0.8), "glow", T(sx * w * 0.48, 0.05, h * z))


def cheval_mirror(p, size, c):
    w, h, d = 0.8, 1.9, 0.4
    ol = oval_outline(0.6, 1.45, 20)
    m = T(0, 0, 0.32) @ R("X", -6)
    p.add(slab(ol, 0.025), (0.93, 0.9, 1.0), "mirror", m)
    p.add(frame_ring(ol, 0.04, 0.03), GOLD, "gold", m)
    for sx in (-1, 1):
        p.add(lathe([(0.03, 0), (0.035, 0.1), (0.022, 1.0), (0.03, 1.08), (0.0, 1.15)], 8), GOLD, "gold", T(sx * 0.37, 0, 0.12))
        p.add(sphere(0.04, 8, 5), GOLD, "gold", T(sx * 0.37, 0, 1.3))
        p.add(tube([(sx * 0.37, -0.18, 0.02), (sx * 0.37, 0, 0.14), (sx * 0.37, 0.18, 0.02)], [0.03, 0.035, 0.03], 6), GOLD, "gold")
    p.add(tube([(-0.37, 0, 0.12), (0.37, 0, 0.12)], 0.02, 6), GOLD, "gold")
    p.add(cyl(0.025, 0.06, 6), GOLD, "gold", T(-0.32, 0, 1.0) @ R("Y", 90))
    p.add(cyl(0.025, 0.06, 6), GOLD, "gold", T(0.26, 0, 1.0) @ R("Y", 90))
    crest(p, 0, 0.01, 1.78, 0.14)
    rng = random.Random(5)
    bloom(p, (-0.18, 0.04, 1.72), 0.06, ROSE, 2, 5, rng, tilt=R("X", -70))
    bloom(p, (0.2, 0.04, 0.4), 0.05, BLUSH, 2, 5, rng, tilt=R("X", -70))


def gown(p, x, y, z, height, color, rng, flare=1.0, trim=GOLD, sleeves=True, seg=18, rose=True):
    """A ball gown on an invisible form: bodice, sash, full skirt with ruffles."""
    sk = height * 0.6
    bod = height * 0.27
    prof = [(0.0, 0), (0.33 * flare, 0.0), (0.34 * flare, 0.04), (0.28 * flare, sk * 0.3),
            (0.18 * flare, sk * 0.7), (0.11, sk * 0.95), (0.1, sk)]
    sk_m = lathe(prof, seg)
    for v in sk_m.verts:              # soft folds around the hem
        a = math.atan2(v.co.y, v.co.x)
        f = 1 + 0.08 * math.sin(a * 9) * (1 - v.co.z / sk)
        v.co.x *= f
        v.co.y *= f * 0.85
    p.add(sk_m, color, "fabric", T(x, y, z))
    p.add(torus(0.33 * flare, 0.03, seg, 4), lighter(color, 0.3), "fabric", T(x, y, z + 0.03) @ S(1, 0.85, 1))
    p.add(lathe([(0.1, 0), (0.115, bod * 0.4), (0.13, bod * 0.85), (0.09, bod), (0.0, bod)], 12), lighter(color, 0.12), "satin", T(x, y, z + sk) @ S(1, 0.75, 1))
    p.add(torus(0.105, 0.018, 12, 4), trim, "gold", T(x, y, z + sk + 0.01) @ S(1, 0.75, 1))
    if sleeves:
        for sx in (-1, 1):
            p.add(sphere(0.055, 8, 5), lighter(color, 0.3), "fabric", T(x + sx * 0.12, y, z + sk + bod * 0.85))
    if rose:
        bloom(p, (x + 0.03, y + 0.085, z + sk + bod * 0.55), 0.035, lighter(color, 0.4), 2, 5, rng, tilt=R("X", -80))


def gown_rack(p, size, c):
    w, h, d = 2.0, 1.9, 0.6
    for sx in (-1, 1):
        p.add(lathe([(0.025, 0), (0.03, 0.05), (0.02, 1.7), (0.035, 1.8), (0, 1.85)], 8), GOLD, "gold", T(sx * 0.95, 0, 0))
        p.add(tube([(sx * 0.95, -0.28, 0.02), (sx * 0.95, 0, 0.08), (sx * 0.95, 0.28, 0.02)], 0.022, 6), GOLD, "gold")
    p.add(tube([(-0.95, 0, 1.78), (0.95, 0, 1.78)], 0.018, 6), GOLD, "gold")
    rng = random.Random(31)
    cols = [ROSE, LILAC, PERI, BUTTER, MINT, BLUSH]
    for i, col in enumerate(cols):
        x = -0.8 + i * 0.32
        p.add(torus(0.02, 0.006, 6, 3), GOLD, "gold", T(x, 0, 1.76) @ R("X", 90))
        p.add(tube([(x - 0.12, 0, 1.66), (x, 0, 1.73), (x + 0.12, 0, 1.66)], 0.01, 4), GOLD, "gold")
        # a gown seen side-on on a hanger: flattened
        gown(p, x, 0, 0.12, 1.55, col, rng, flare=0.75, sleeves=False, seg=10, rose=False)


def mannequin_gown(p, size, c):
    rng = random.Random(41)
    p.add(lathe([(0.0, 0), (0.18, 0), (0.18, 0.03), (0.05, 0.05), (0.03, 0.5)], 12), GOLD, "gold")
    gown(p, 0, 0, 0.05, 1.55, c, rng, flare=1.05)
    p.add(lathe([(0.0, 0), (0.04, 0.0), (0.03, 0.08), (0.06, 0.12), (0.075, 0.2), (0.05, 0.27), (0, 0.29)], 10), CREAM, "pearl", T(0, 0, 1.47))
    # tiara on the form
    for i in range(7):
        a = math.radians(-60 + i * 20)
        p.add(lathe([(0.006, 0), (0.0, 0.03 + (0.025 if i == 3 else 0))], 4), GOLD, "gold", T(0.065 * math.sin(a), -0.065 * math.cos(a) * 0.8, 1.73))
    p.add(torus(0.065, 0.006, 12, 3), GOLD, "gold", T(0, 0, 1.73) @ S(1, 0.8, 1))
    p.add(sphere(0.012, 6, 4), ROSE, "glass", T(0, -0.055, 1.77))


def shoe(p, x, y, z, col, rng):
    p.add(sphere(0.05, 6, 4), col, "satin", T(x, y + 0.04, z + 0.025) @ S(0.7, 1.4, 0.55))
    p.add(cyl(0.012, 0.06, 4, 0.008), GOLD, "gold", T(x, y - 0.06, z))
    p.add(sphere(0.02, 4, 3), lighter(col, 0.4), "glass", T(x, y + 0.08, z + 0.05), smooth=False)


def shoe_shelf(p, size, c):
    w, h, d = 1.6, 1.4, 0.4
    for sx in (-1, 1):
        p.add(slab(arched_outline(d, h, 6, 0.15), 0.04), c, "satin", T(sx * (w / 2 - 0.02), 0, 0) @ R("Z", 90))
    p.add(box(w, 0.02, h - 0.1), lighter(c, 0.2), "satin", T(0, -d / 2 + 0.01, h / 2))
    rng = random.Random(51)
    cols = [ROSE, LILAC, PERI, BUTTER, MINT, GOLD, BLUSH, WHITE]
    for row, z in enumerate((0.05, 0.42, 0.79, 1.16)):
        p.add(box(w - 0.04, d, 0.03, bevel=0.01), lighter(c, 0.1), "satin", T(0, 0, z))
        p.add(tube([(-w / 2, d / 2, z + 0.02), (w / 2, d / 2, z + 0.02)], 0.008, 4), GOLD, "gold")
        for i in range(4):
            col = cols[(row * 3 + i) % len(cols)]
            x = -w / 2 + 0.22 + i * 0.38
            shoe(p, x - 0.04, 0, z + 0.015, col, rng)
            shoe(p, x + 0.04, 0, z + 0.015, col, rng)


def hat_stand(p, size, c):
    p.add(lathe([(0, 0), (0.2, 0), (0.2, 0.03), (0.05, 0.06), (0.03, 0.12), (0.025, 1.6), (0.04, 1.65), (0, 1.7)], 10), c, "gold")
    rng = random.Random(61)
    hats = [(ROSE, 0.0, 1.58, 0.0), (LILAC, 0.0, 1.25, 120), (BUTTER, 0.0, 1.05, 240)]
    for i, (col, _, z, a) in enumerate(hats):
        m = R("Z", a) @ T(0.17, 0, z) @ R("Y", 20)
        p.add(lathe([(0.0, 0.0), (0.2, 0.0), (0.21, 0.01), (0.1, 0.02), (0.1, 0.1), (0.0, 0.11)], 14), col, "fabric", m)
        p.add(torus(0.1, 0.015, 12, 4), lighter(col, 0.4), "satin", m @ T(0, 0, 0.03))
        bloom(p, (0, 0, 0), 0.04, ROSE if col != ROSE else WHITE, 2, 5, rng, tilt=m @ T(0.08, 0.06, 0.06) @ R("Y", 60))
        p.add(tube([(0, 0, 0), (0.0, 0.1, -0.15), (0.03, 0.12, -0.32)], 0.01, 4), lighter(col, 0.5), "fabric", m @ T(-0.08, 0.05, 0.03))


def jewelry_box(p, size, c):
    w, h, d = 0.4, 0.25, 0.3
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(sphere(0.022, 8, 5), GOLD, "gold", T(sx * 0.17, sy * 0.12, 0.02))
    p.add(box(w, d, 0.13, bevel=0.015), BLUSH, "pearl", T(0, 0, 0.1))
    p.add(box(w + 0.01, d + 0.01, 0.02, bevel=0.006), GOLD, "gold", T(0, 0, 0.165))
    lid = cyl(d / 2, w, 14)
    p.add(lid, BLUSH, "pearl", T(-w / 2, 0, 0.175) @ R("Y", 90) @ S(0.45, 1, 1))
    for x in (-w / 2 + 0.03, w / 2 - 0.03):
        p.add(box(0.02, d + 0.02, 0.09, bevel=0.006), GOLD, "gold", T(x, 0, 0.2))
    heart_crest(p, 0, d / 2 - 0.02, 0.2, 0.16, GOLD)
    p.add(ico(0.03, 1), ROSE, "glass", T(0, 0.0, 0.245), smooth=False)
    # half-open drawer with pearls and gems spilling over the lip
    p.add(box(w * 0.8, 0.1, 0.05, bevel=0.008), lighter(BLUSH, 0.1), "pearl", T(0, d / 2 + 0.03, 0.07))
    knob(p, 0, d / 2 + 0.085, 0.07, 0.012)
    for i in range(11):
        t = i / 10
        p.add(sphere(0.012, 6, 4), WHITE, "pearl", T(-0.1 + 0.2 * t, d / 2 + 0.04 + 0.05 * math.sin(math.pi * t), 0.1 - 0.09 * math.sin(math.pi * t) ** 2))
    for col, x in ((PERI, -0.07), (MINT, 0.07)):
        p.add(ico(0.02, 1), col, "glass", T(x, d / 2 + 0.03, 0.105), smooth=False)
    p.add(torus(0.035, 0.006, 12, 4), GOLD, "gold", T(0.13, d / 2 + 0.06, 0.008))
    p.add(ico(0.012, 1), ROSE, "glass", T(0.13, d / 2 + 0.095, 0.015), smooth=False)


def perfume_tray(p, size, c):
    p.add(lathe([(0, 0), (0.26, 0), (0.27, 0.015), (0.25, 0.02), (0, 0.02)], 16), GOLD, "gold", S(1, 0.6, 1))
    bottles = [(-0.16, 0.0, PERI, 0.11), (-0.05, 0.03, ROSE, 0.14), (0.06, -0.02, MINT, 0.1), (0.16, 0.02, LILAC, 0.12)]
    for x, y, col, hh in bottles:
        p.add(lathe([(0.0, 0), (0.03, 0.0), (0.04, hh * 0.3), (0.035, hh * 0.65), (0.01, hh * 0.8), (0.01, hh * 0.9), (0.0, hh * 0.9)], 10), col, "glass", T(x, y, 0.02))
        p.add(sphere(0.015, 8, 5), GOLD, "gold", T(x, y, 0.02 + hh * 0.95))
    p.add(sphere(0.025, 8, 5), ROSE, "fabric", T(-0.05, -0.08, 0.04))
    p.add(tube([(-0.05, -0.08, 0.04), (-0.08, -0.1, 0.06), (-0.05, 0.03, 0.15)], 0.004, 4), GOLD, "gold")


def makeup_palette(p, size, c):
    w, d = 0.4, 0.3
    p.add(box(w, d, 0.02, bevel=0.006), GOLD, "gold", T(0, 0, 0.01))
    p.add(box(w - 0.02, d - 0.02, 0.012, bevel=0.004), PEARL, "pearl", T(0, 0, 0.022))
    cols = [ROSE, BLUSH, LILAC, PERI, MINT, BUTTER, (0.95, 0.45, 0.55), (0.85, 0.65, 0.9)]
    for i, col in enumerate(cols):
        x = -0.135 + (i % 4) * 0.09
        y = -0.06 + (i // 4) * 0.1
        p.add(cyl(0.035, 0.012, 12), col, "satin", T(x, y, 0.024))
    # lid open behind, mirrored
    p.add(box(w, 0.012, d * 0.8, bevel=0.004), GOLD, "gold", T(0, -d / 2, 0.02 + d * 0.38) @ R("X", -12))
    p.add(box(w - 0.04, 0.004, d * 0.7), (0.93, 0.9, 1.0), "mirror", T(0, -d / 2 + 0.01, 0.02 + d * 0.38) @ R("X", -12))
    p.add(cyl(0.006, 0.17, 6), GOLD, "gold", T(0.0, 0.12, 0.03) @ R("Y", 90) @ T(0, 0, -0.08))
    p.add(sphere(0.018, 8, 5), BLUSH, "fabric", T(0.1, 0.12, 0.03) @ S(1.4, 1, 1))


def dressing_screen(p, size, c):
    w, h = 1.8, 1.8
    pw = w / 3
    rng = random.Random(81)
    for i in range(3):
        x = -w / 2 + pw * (i + 0.5)
        yaw = (-12, 0, 12)[i]
        y = (0.08, 0.0, 0.08)[i]
        m = T(x, y, 0.05) @ R("Z", yaw)
        ol = arched_outline(pw - 0.04, h - 0.05, 10, pw * 0.4)
        p.add(slab(ol, 0.03), lighter(c, 0.15), "fabric", m)
        p.add(frame_ring(ol, 0.022, 0.03), GOLD, "gold", m)
        for sx in (-1, 1):
            p.add(sphere(0.025, 6, 4), GOLD, "gold", m @ T(sx * (pw / 2 - 0.04), 0, -0.02))
        # painted roses on the panel
        for k in range(3):
            bloom(p, (0, 0, 0), 0.05, ROSE if k % 2 == 0 else LILAC, 2, 5, rng,
                  tilt=m @ T(rng.uniform(-0.15, 0.15), 0.02, 0.4 + k * 0.4) @ R("X", -90))
    # a gown thrown over the top
    p.add(tube([(-0.35, 0.12, 1.0), (-0.3, 0.06, 1.65), (-0.2, 0.0, 1.82), (-0.1, -0.06, 1.6)], [0.05, 0.08, 0.06, 0.05], 7), LILAC, "fabric")


def pouf_stool(p, size, c):
    p.add(cushion(0.6, 0.6, 0.3, 0.45, 3), c, "fabric", T(0, 0, 0.32))
    p.add(torus(0.28, 0.035, 18, 5), lighter(c, 0.35), "fabric", T(0, 0, 0.2))
    for i in range(4):
        a = math.radians(45 + 90 * i)
        p.add(cabriole(0.2, 0.022), GOLD, "gold", T(0.2 * math.cos(a), 0.2 * math.sin(a), 0) @ R("Z", math.degrees(a) - 45))
    p.add(sphere(0.03, 8, 5), GOLD, "gold", T(0, 0, 0.5))
    # tassels
    for i in range(8):
        a = 2 * math.pi * i / 8
        p.add(cyl(0.012, 0.07, 5, 0.02), GOLD, "gold", T(0.31 * math.cos(a), 0.31 * math.sin(a), 0.13))


# ------------------------------------------------------------ furniture


def chaise_longue(p, size, c):
    w, h, d = 1.9, 0.9, 0.8
    cab_legs(p, w - 0.1, d - 0.1, 0.2, 0.03, GOLD)
    p.add(box(w - 0.1, d - 0.1, 0.12, bevel=0.04), PEARL, "pearl", T(0, 0, 0.26))
    p.add(cushion(w - 0.2, d - 0.15, 0.16, 0.25), c, "fabric", T(0.05, 0, 0.38))
    # rolled, scrolled head end rising from the seat (side profile in XZ)
    head = [(-w / 2 + 0.02, 0.3), (-w / 2 + 0.45, 0.3), (-w / 2 + 0.3, 0.55), (-w / 2 + 0.2, 0.8),
            (-w / 2 + 0.05, 0.9), (-w / 2 - 0.04, 0.82), (-w / 2 - 0.02, 0.6)]
    p.add(slab(head, d - 0.1, 0.03), c, "fabric", R("Z", 0))
    p.add(tube([(-w / 2 + 0.1, -(d - 0.1) / 2 - 0.01, 0.32), (-w / 2 - 0.03, -(d - 0.1) / 2 - 0.01, 0.7),
                (-w / 2 + 0.06, -(d - 0.1) / 2 - 0.01, 0.9), (-w / 2 + 0.22, -(d - 0.1) / 2 - 0.01, 0.8)], 0.016, 5), GOLD, "gold")
    p.add(tube([(-w / 2 + 0.1, (d - 0.1) / 2 + 0.01, 0.32), (-w / 2 - 0.03, (d - 0.1) / 2 + 0.01, 0.7),
                (-w / 2 + 0.06, (d - 0.1) / 2 + 0.01, 0.9), (-w / 2 + 0.22, (d - 0.1) / 2 + 0.01, 0.8)], 0.016, 5), GOLD, "gold")
    # low half back along the rear
    p.add(tube([(-w / 2 + 0.2, -d / 2 + 0.08, 0.62), (0.0, -d / 2 + 0.08, 0.58), (0.5, -d / 2 + 0.08, 0.42)], [0.08, 0.07, 0.05], 8), c, "fabric")
    p.add(cushion(0.4, 0.16, 0.3, 0.5), lighter(c, 0.4), "fabric", T(-w / 2 + 0.38, 0.0, 0.58) @ R("Y", -25))
    p.add(tube([(0.4, -0.05, 0.47), (0.7, 0.1, 0.47), (0.9, 0.3, 0.3)], [0.03, 0.05, 0.03], 6), LILAC, "fabric")


def sofa(p, size, c):
    w, h, d = 2.2, 0.95, 0.9
    cab_legs(p, w - 0.1, d - 0.1, 0.18, 0.03, GOLD)
    p.add(box(w, d - 0.05, 0.16, bevel=0.04), PEARL, "pearl", T(0, 0, 0.26))
    for x in (-0.5, 0.5):
        p.add(cushion(0.95, d - 0.25, 0.16, 0.3), c, "fabric", T(x, 0.06, 0.42))
    back = slab(arched_outline(w - 0.1, 0.65, 14, 0.25), 0.16, 0.03)
    p.add(back, c, "fabric", T(0, -d / 2 + 0.12, 0.3))
    p.add(frame_ring(arched_outline(w - 0.1, 0.65, 14, 0.25), 0.02, 0.04), GOLD, "gold", T(0, -d / 2 + 0.03, 0.3))
    crest(p, 0, -d / 2 + 0.04, 0.95, 0.14)
    for sx in (-1, 1):
        p.add(tube([(sx * (w / 2 - 0.08), -d / 2 + 0.1, 0.4), (sx * (w / 2 - 0.08), 0.0, 0.62), (sx * (w / 2 - 0.08), d / 2 - 0.1, 0.58), (sx * (w / 2 - 0.06), d / 2, 0.45)], [0.09, 0.1, 0.1, 0.08], 8), c, "fabric")
        p.add(cushion(0.4, 0.15, 0.36, 0.5), lighter(c, 0.35), "fabric", T(sx * 0.7, -d / 2 + 0.3, 0.6) @ R("X", -15) @ R("Z", sx * 10))


def armchair(p, size, c, wing=False):
    w, h, d = 0.9, 1.3 if wing else 1.1, 0.9
    cab_legs(p, w - 0.1, d - 0.1, 0.2, 0.03, GOLD)
    p.add(box(w - 0.05, d - 0.05, 0.15, bevel=0.04), PEARL, "pearl", T(0, 0, 0.28))
    p.add(cushion(w - 0.25, d - 0.25, 0.14, 0.35), c, "fabric", T(0, 0.06, 0.42))
    bh = h - 0.35
    back = slab(arched_outline(w - 0.12, bh, 12, 0.3 if not wing else 0.22), 0.14, 0.03)
    p.add(back, c, "fabric", T(0, -d / 2 + 0.1, 0.32) @ R("X", -8))
    p.add(frame_ring(arched_outline(w - 0.12, bh, 12, 0.3 if not wing else 0.22), 0.018, 0.03), GOLD, "gold", T(0, -d / 2 + 0.02, 0.32) @ R("X", -8))
    for sx in (-1, 1):
        if wing:
            p.add(tube([(sx * (w / 2 - 0.07), -d / 2 + 0.12, 0.45), (sx * (w / 2 - 0.02), -d / 2 + 0.15, 1.15), (sx * (w / 2 - 0.08), -d / 2 + 0.3, 1.1)], [0.06, 0.12, 0.06], 8), c, "fabric")
        p.add(tube([(sx * (w / 2 - 0.08), -d / 2 + 0.12, 0.42), (sx * (w / 2 - 0.08), 0, 0.64), (sx * (w / 2 - 0.08), d / 2 - 0.08, 0.6), (sx * (w / 2 - 0.05), d / 2, 0.48)], [0.07, 0.08, 0.08, 0.07], 8), c, "fabric")
        p.add(sphere(0.03, 8, 5), GOLD, "gold", T(sx * (w / 2 - 0.05), d / 2 + 0.02, 0.5))
    p.add(cushion(0.35, 0.14, 0.3, 0.5), lighter(c, 0.35), "fabric", T(0, -d / 2 + 0.25, 0.62) @ R("X", -15))


def wingback_chair(p, size, c):
    armchair(p, size, c, True)


def chair_dining(p, size, c):
    w, d = 0.5, 0.5
    cab_legs(p, w - 0.04, d - 0.04, 0.42, 0.022, c, "pearl", 0.04)
    p.add(box(w, d, 0.06, bevel=0.02), c, "pearl", T(0, 0, 0.45))
    p.add(cushion(w - 0.06, d - 0.06, 0.07, 0.4), ROSE, "fabric", T(0, 0.01, 0.51))
    ol = [(x * 0.85, z) for x, z in oval_outline(0.38, 0.6, 16)]
    for sx in (-1, 1):
        p.add(lathe([(0.02, 0), (0.025, 0.6)], 6), c, "pearl", T(sx * 0.2, -d / 2 + 0.04, 0.48) @ R("X", -6))
    m = T(0, -d / 2 + 0.04, 0.55) @ R("X", -6)
    p.add(slab(ol, 0.04), BLUSH, "fabric", m)
    p.add(frame_ring(ol, 0.018, 0.04), GOLD, "gold", m)
    crest(p, 0, -d / 2 + 0.08, 1.12, 0.1)


def chair_simple(p, size, c):
    w, d = 0.45, 0.45
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(turned_leg(0.45, 0.022, 6, "taper"), c, "satin", T(sx * 0.18, sy * 0.18, 0))
    p.add(box(w, d, 0.04, bevel=0.012), c, "satin", T(0, 0, 0.46))
    p.add(cushion(0.38, 0.38, 0.05, 0.4), MINT, "fabric", T(0, 0.01, 0.5))
    for sx in (-1, 1):
        p.add(cyl(0.02, 0.5, 6), c, "satin", T(sx * 0.18, -0.19, 0.46))
    for z in (0.65, 0.8, 0.94):
        p.add(box(0.38, 0.03, 0.05, bevel=0.01), c, "satin", T(0, -0.19, z))
    heart_crest(p, 0, -0.17, 0.7, 0.1, ROSE)


def bench_settle(p, size, c):
    w, d = 1.6, 0.5
    p.add(box(w, d, 0.06, bevel=0.015), c, "satin", T(0, 0.02, 0.45))
    for sx in (-1, 1):
        p.add(slab(arched_outline(d, 0.7, 6, 0.15), 0.05), c, "satin", T(sx * (w / 2 - 0.03), 0, 0) @ R("Z", 90))
    p.add(slab(arched_outline(w - 0.05, 0.55, 10, 0.12), 0.04), c, "satin", T(0, -d / 2 + 0.03, 0.47))
    for i in range(3):
        heart_crest(p, -0.5 + i * 0.5, -d / 2 + 0.07, 0.65, 0.12, ROSE)
    p.add(cushion(w - 0.15, d - 0.1, 0.08, 0.4), BLUSH, "fabric", T(0, 0.04, 0.52))


def stool(p, size, c):
    p.add(cushion(0.4, 0.4, 0.08, 0.3), c, "satin", T(0, 0, 0.46))
    for i in range(3):
        a = math.radians(90 + 120 * i)
        p.add(tube([(0.07 * math.cos(a), 0.07 * math.sin(a), 0.44), (0.17 * math.cos(a), 0.17 * math.sin(a), 0.0)], [0.025, 0.018], 6), c, "satin")
    p.add(torus(0.1, 0.012, 10, 4), c, "satin", T(0, 0, 0.18))


def _table(p, w, d, h, c, top=PEARL, leg="cabriole", round_=False, cloth=None, rng=None):
    if round_:
        p.add(lathe([(0, 0), (w / 2, 0), (w / 2 + 0.01, 0.02), (w / 2, 0.05), (0, 0.05)], 24), top, "pearl", T(0, 0, h - 0.05))
        p.add(torus(w / 2, 0.012, 24, 4), GOLD, "gold", T(0, 0, h - 0.025))
        p.add(lathe([(0, 0), (0.3 * w, 0), (0.3 * w, 0.04), (0.06, 0.1), (0.05, h * 0.4), (0.08, h * 0.55), (0.05, h * 0.75), (0.1, h - 0.05)], 12), c, "satin")
        for i in range(3):
            a = math.radians(120 * i)
            p.add(cabriole(h * 0.25, 0.025), GOLD, "gold", T(0.12 * math.cos(a), 0.12 * math.sin(a), 0) @ R("Z", math.degrees(a) - 45))
    else:
        if leg == "cabriole":
            cab_legs(p, w - 0.08, d - 0.08, h - 0.08, 0.035 * max(1, h), GOLD if top == PEARL else c, "gold" if top == PEARL else "satin")
        else:
            for sx in (-1, 1):
                for sy in (-1, 1):
                    p.add(turned_leg(h - 0.06, 0.04, 8), c, "satin", T(sx * (w / 2 - 0.08), sy * (d / 2 - 0.08), 0))
        p.add(box(w - 0.06, d - 0.06, 0.1, bevel=0.02), c, "satin", T(0, 0, h - 0.1))
        p.add(box(w, d, 0.05, bevel=0.02), top, "pearl" if top in (PEARL, MINT) else "satin", T(0, 0, h - 0.025))
    if cloth:
        p.add(box(w * 0.35, d + 0.04, 0.012, bevel=0.004), cloth, "fabric", T(0, 0, h + 0.005))


def table_dining_long(p, size, c):
    w, h, d = 8.0, 0.8, 1.6
    p.add(box(w, d, 0.06, bevel=0.03), c, "pearl", T(0, 0, h - 0.03))
    p.add(box(w - 0.15, d - 0.15, 0.1, bevel=0.02), c, "satin", T(0, 0, h - 0.11))
    gilt_edge(p, w, d, h - 0.06, 0.015)
    for x in (-w / 2 + 0.15, 0.0, w / 2 - 0.15):
        for sy in (-1, 1):
            p.add(turned_leg(h - 0.06, 0.06, 7), c, "pearl", T(x, sy * (d / 2 - 0.12), 0))
    # blush damask cloth falling over the sides, gilt-fringed; rose runner on top
    p.add(box(w - 0.2, d + 0.06, 0.012), lighter(BLUSH, 0.3), "fabric", T(0, 0, h + 0.006))
    for sy in (-1, 1):
        p.add(box(w - 0.2, 0.012, 0.3), lighter(BLUSH, 0.3), "fabric", T(0, sy * (d / 2 + 0.03), h - 0.14))
        p.add(box(w - 0.2, 0.02, 0.02), GOLD, "gold", T(0, sy * (d / 2 + 0.035), h - 0.29))
    p.add(box(w - 0.6, 0.45, 0.01), ROSE, "fabric", T(0, 0, h + 0.014))
    rng = random.Random(91)
    for x in (-2.6, 2.6):
        _candelabra_at(p, x, 0, h, 0.55)
    for x in (-1.0, 1.0):
        p.add(lathe([(0.05, 0), (0.12, 0.05), (0.08, 0.15), (0.13, 0.2)], 10), GOLD, "gold", T(x, 0, h))
        rose_cluster(p, x, 0, h + 0.27, 0.1, 3, ROSE, rng, 0.08)
    for x in (-3.3, -1.9, -0.5, 0.5, 1.9, 3.3):
        for sy in (-1, 1):
            p.add(lathe([(0, 0), (0.13, 0), (0.14, 0.012), (0, 0.012)], 8), WHITE, "pearl", T(x, sy * 0.5, h))


def _candelabra_at(p, x, y, z, h):
    p.add(lathe([(0, 0), (0.09, 0), (0.08, 0.03), (0.025, 0.06), (0.03, h * 0.5), (0.02, h * 0.7)], 10), GOLD, "gold", T(x, y, z))
    for sx in (-1, 1):
        p.add(tube([(x, y, z + h * 0.62), (x + sx * 0.1, y, z + h * 0.62), (x + sx * 0.14, y, z + h * 0.8)], 0.012, 5), GOLD, "gold")
        p.add(lathe([(0, 0), (0.03, 0.0), (0.03, 0.02)], 8), GOLD, "gold", T(x + sx * 0.14, y, z + h * 0.8))
        candle(p, x + sx * 0.14, y, z + h * 0.8 + 0.02, h * 0.25, 0.014)
    candle(p, x, y, z + h * 0.7, h * 0.3, 0.016)


def table_round(p, size, c):
    _table(p, 1.4, 1.4, 0.75, c, round_=True)
    rng = random.Random(101)
    p.add(lathe([(0.04, 0), (0.1, 0.08), (0.05, 0.22), (0.08, 0.28)], 10), BLUSH, "pearl", T(0, 0, 0.75))
    rose_cluster(p, 0, 0, 1.08, 0.1, 6, ROSE, rng, 0.06)


def table_side(p, size, c):
    _table(p, 0.6, 0.6, 0.7, c, round_=True)
    rng = random.Random(111)
    p.add(lathe([(0.03, 0), (0.06, 0.05), (0.03, 0.14), (0.05, 0.18)], 10), PERI, "glass", T(0.08, 0, 0.7))
    rose_cluster(p, 0.08, 0, 0.92, 0.04, 3, BLUSH, rng, 0.045)


def table_tea(p, size, c):
    w, d, h = 0.9, 0.6, 0.5
    _table(p, w, d, h, c)
    # tea set: pot, cups, cake plate
    p.add(lathe([(0, 0), (0.06, 0.0), (0.09, 0.05), (0.08, 0.1), (0.04, 0.13), (0.045, 0.15), (0, 0.17)], 12), WHITE, "pearl", T(-0.2, 0, h))
    p.add(tube([(-0.12, 0, h + 0.06), (-0.06, 0, h + 0.12), (-0.04, 0, h + 0.13)], [0.015, 0.01, 0.008], 5), WHITE, "pearl")
    p.add(torus(0.035, 0.008, 8, 4), GOLD, "gold", T(-0.29, 0, h + 0.08) @ R("X", 90))
    p.add(sphere(0.015, 6, 4), ROSE, "pearl", T(-0.2, 0, h + 0.175))
    for x, y in ((0.1, 0.15), (0.25, -0.1)):
        p.add(lathe([(0, 0), (0.06, 0), (0.065, 0.008), (0, 0.008)], 12), WHITE, "pearl", T(x, y, h))
        p.add(lathe([(0, 0), (0.025, 0.0), (0.04, 0.05), (0.035, 0.05), (0, 0.01)], 10), BLUSH, "pearl", T(x, y, h + 0.008))
    p.add(lathe([(0.03, 0), (0.01, 0.1), (0.1, 0.1), (0.1, 0.11), (0, 0.11)], 12), GOLD, "gold", T(0.1, -0.12, h))
    for i in range(5):
        a = 2 * math.pi * i / 5
        col = (ROSE, MINT, BUTTER, LILAC, BLUSH)[i]
        p.add(box(0.05, 0.05, 0.03, bevel=0.01), col, "satin", T(0.1 + 0.06 * math.cos(a), -0.12 + 0.06 * math.sin(a), h + 0.125))


def table_work(p, size, c):
    _table(p, 2.4, 1.0, 0.9, c, top=c, leg="turned")
    p.add(box(2.1, 0.7, 0.03), c, "satin", T(0, 0, 0.2))


def table_kitchen(p, size, c):
    _table(p, 3.2, 1.2, 0.9, c, top=lighter(c, 0.15), leg="turned")
    p.add(box(2.9, 0.9, 0.03), c, "satin", T(0, 0, 0.2))
    rng = random.Random(121)
    for x in (-1.0, 0.4):
        p.add(lathe([(0, 0), (0.12, 0), (0.18, 0.06), (0.18, 0.1), (0, 0.1)], 12), (0.98, 0.88, 0.65), "matte", T(x, 0.1, 0.9))
    for i, col in enumerate(((0.95, 0.3, 0.35), (1.0, 0.75, 0.3), (0.6, 0.85, 0.35))):
        p.add(sphere(0.045, 8, 5), col, "satin", T(-1.0 + (i - 1) * 0.07, 0.1, 1.0))
    p.add(box(0.5, 0.3, 0.03, bevel=0.01), OAK, "satin", T(1.0, -0.1, 0.915))
    p.add(lathe([(0, 0), (0.1, 0.0), (0.12, 0.06), (0.08, 0.09), (0, 0.1)], 12), (1.0, 0.85, 0.55), "satin", T(1.0, -0.1, 0.93) @ S(1.3, 0.9, 1))


def desk_writing(p, size, c, large=False):
    w, h, d = (2.2, 0.8, 1.1) if large else (1.6, 0.8, 0.8)
    cab_legs(p, w - 0.06, d - 0.06, 0.62, 0.035, c, "satin")
    p.add(box(w - 0.04, d - 0.04, 0.14, bevel=0.025), c, "satin", T(0, 0, 0.69))
    p.add(box(w, d, 0.04, bevel=0.015), lighter(c, 0.1), "satin", T(0, 0, 0.78))
    p.add(box(w - 0.3, d - 0.3, 0.005), MINT if not large else ROSE, "fabric", T(0, 0, 0.8))
    gilt_edge(p, w, d, 0.76, 0.01)
    drawer_row(p, w - 0.1, 0.69, 0.12, d / 2 - 0.01, 3, c)
    # quill, ink, papers, a candle
    p.add(box(0.3, 0.22, 0.01), CANVAS, "matte", T(-0.2, 0.05, 0.805) @ R("Z", 8))
    p.add(box(0.28, 0.2, 0.01), CANVAS, "matte", T(-0.18, 0.08, 0.815) @ R("Z", -5))
    p.add(lathe([(0, 0), (0.04, 0), (0.04, 0.05), (0.015, 0.06), (0, 0.06)], 8), PERI, "glass", T(0.3, -0.15, 0.8))
    p.add(tube([(0.3, -0.15, 0.85), (0.28, -0.1, 1.0), (0.24, -0.06, 1.12)], [0.004, 0.02, 0.006], 4), WHITE, "fabric")
    _candelabra_at(p, w / 2 - 0.25, -d / 2 + 0.2, 0.8, 0.35) if large else candle(p, w / 2 - 0.2, -d / 2 + 0.2, 0.8, 0.15)


def desk_large(p, size, c):
    desk_writing(p, size, c, True)


def cabinet_curio(p, size, c):
    w, h, d = 1.2, 2.0, 0.5
    cab_legs(p, w - 0.05, d - 0.05, 0.25, 0.03, GOLD)
    p.add(box(w, d, h - 0.45, bevel=0.03), c, "satin", T(0, 0, 0.22 + (h - 0.45) / 2))
    bon = arched_outline(w, 0.28, 12, 0.24)
    p.add(slab(bon, d), c, "satin", T(0, 0, h - 0.24))
    crest(p, 0, d / 2, h - 0.04, 0.16)
    glass = arched_outline(w - 0.16, h - 0.6, 12, 0.3)
    p.add(slab(glass, 0.01), (0.9, 0.95, 1.0, 0.3), "glass", T(0, d / 2 + 0.005, 0.3))
    p.add(frame_ring(glass, 0.02, 0.02), GOLD, "gold", T(0, d / 2 + 0.01, 0.3))
    p.add(box(w - 0.1, 0.02, h - 0.55), lighter(c, 0.1) if c != PEARL else BLUSH, "satin", T(0, -d / 2 + 0.03, 0.25 + (h - 0.55) / 2))
    rng = random.Random(131)
    for row, z in enumerate((0.55, 0.95, 1.35)):
        p.add(box(w - 0.12, d - 0.1, 0.02), lighter(c, 0.15), "glass", T(0, 0, z))
        for i in range(3):
            x = -0.35 + i * 0.35
            kind = (row + i) % 3
            col = (ROSE, PERI, MINT, LILAC, BUTTER)[(row * 3 + i) % 5]
            if kind == 0:
                p.add(lathe([(0.03, 0), (0.07, 0.06), (0.03, 0.18), (0.05, 0.22)], 10), col, "pearl", T(x, 0, z + 0.01))
            elif kind == 1:
                p.add(lathe([(0, 0), (0.1, 0), (0.1, 0.01), (0, 0.01)], 14), col, "pearl", T(x, -0.08, z + 0.13) @ R("X", 75))
            else:
                p.add(ico(0.05, 1), col, "glass", T(x, 0, z + 0.06), smooth=False)


def sideboard(p, size, c):
    w, h, d = 2.2, 1.0, 0.6
    cab_legs(p, w - 0.06, d - 0.06, 0.18, 0.03, GOLD)
    body = box(w, d, 0.75, bevel=0.03)
    p.add(body, c, "satin", T(0, 0, 0.55))
    p.add(box(w + 0.06, d + 0.06, 0.05, bevel=0.02), MINT if c == PEARL else lighter(c, 0.1), "pearl", T(0, 0, 0.95))
    gilt_edge(p, w + 0.06, d + 0.06, 0.93, 0.01)
    drawer_row(p, w - 0.1, 0.83, 0.13, d / 2 + 0.005, 3, c)
    for i in range(3):
        x = -w / 3 + i * w / 3
        panel = arched_outline(w / 3 - 0.12, 0.5, 8, 0.12)
        p.add(slab(panel, 0.02), lighter(c, 0.1), "satin", T(x, d / 2 + 0.01, 0.22))
        p.add(frame_ring(panel, 0.012, 0.02), GOLD, "gold", T(x, d / 2 + 0.02, 0.22))
    rng = random.Random(141)
    _candelabra_at(p, -0.75, 0, 0.98, 0.45)
    _candelabra_at(p, 0.75, 0, 0.98, 0.45)
    p.add(lathe([(0.06, 0), (0.18, 0.06), (0.22, 0.12)], 14), GOLD, "gold", T(0, 0, 0.98))
    for i, col in enumerate(((0.95, 0.3, 0.35), (1.0, 0.75, 0.3), (0.7, 0.88, 0.4), (0.95, 0.4, 0.5), (0.98, 0.8, 0.4))):
        a = 2 * math.pi * i / 5
        p.add(sphere(0.05, 8, 5), col, "satin", T(0.09 * math.cos(a), 0.09 * math.sin(a), 1.13))


def chest_trunk(p, size, c):
    _chest(p, 1.1, 0.6, 0.7, c)


def coat_rack(p, size, c):
    p.add(lathe([(0, 0), (0.22, 0), (0.22, 0.03), (0.05, 0.08), (0.03, 0.15), (0.03, 1.75), (0.05, 1.8), (0, 1.9)], 10), c, "satin")
    for i in range(6):
        a = math.radians(60 * i)
        p.add(tube([(0, 0, 1.65), (0.15 * math.cos(a), 0.15 * math.sin(a), 1.72), (0.2 * math.cos(a), 0.2 * math.sin(a), 1.8)], [0.012, 0.01, 0.016], 5), GOLD, "gold")
    p.add(tube([(0.18, 0, 1.75), (0.22, 0.08, 1.2), (0.2, 0.0, 0.7)], [0.08, 0.12, 0.14], 8), ROSE, "fabric")
    p.add(tube([(-0.15, -0.1, 1.75), (-0.2, -0.12, 1.4)], [0.05, 0.03], 6), LILAC, "fabric")


def rug(p, w, d, c, shape="rect", rng=None):
    rng = rng or random.Random(1)
    if shape == "round":
        p.add(lathe([(0, 0), (w / 2, 0), (w / 2, 0.015), (0, 0.015)], 32), c, "fabric")
        p.add(torus(w / 2 - 0.12, 0.03, 32, 4), lighter(c, 0.4), "fabric", T(0, 0, 0.015) @ S(1, 1, 0.3))
        p.add(lathe([(0, 0), (w * 0.2, 0), (w * 0.2, 0.017), (0, 0.017)], 20), lighter(c, 0.3), "fabric")
        for i in range(8):
            a = 2 * math.pi * i / 8
            p.add(petal(w * 0.15, w * 0.08, cup=0.0, curl=0.0), ROSE if c != ROSE else BLUSH, "fabric", T(w * 0.2 * math.cos(a), w * 0.2 * math.sin(a), 0.018) @ R("Z", math.degrees(a)) @ S(1, 1, 0.05))
    else:
        p.add(box(w, d, 0.015, bevel=0.005, seg=1), c, "fabric", T(0, 0, 0.0075))
        p.add(box(w - 0.2, d - 0.2, 0.004), lighter(c, 0.35), "fabric", T(0, 0, 0.017))
        p.add(box(w - 0.4, d - 0.4, 0.004), c, "fabric", T(0, 0, 0.019))
        # medallion
        r = min(w, d) * 0.22
        p.add(lathe([(0, 0), (r, 0), (r, 0.004), (0, 0.004)], 20), lighter(c, 0.4), "fabric", T(0, 0, 0.02) @ S(1, d / max(w, d) * 1.4 if d < w else 1, 1))
        for i in range(6):
            a = 2 * math.pi * i / 6
            p.add(petal(r * 0.7, r * 0.4, cup=0, curl=0), ROSE if c != ROSE else BLUSH, "fabric", T(0, 0, 0.025) @ R("Z", math.degrees(a)) @ S(1, 1, 0.05))
        for sy in (-1, 1):
            for i in range(int(w / 0.12)):
                x = -w / 2 + 0.06 + i * 0.12
                if abs(x) < w / 2 - 0.05:
                    p.add(box(0.02, 0.08, 0.006), GOLD, "fabric", T(x, sy * (d / 2 + 0.04), 0.003))


def rug_large(p, size, c):
    rug(p, 5.0, 3.5, c)


def rug_round(p, size, c):
    rug(p, 3.0, 3.0, c, "round")


def rug_runner(p, size, c):
    p.add(box(1.4, 8.0, 0.015, bevel=0.005, seg=1), c, "fabric", T(0, 0, 0.0075))
    p.add(box(1.1, 7.7, 0.004), lighter(c, 0.35), "fabric", T(0, 0, 0.017))
    p.add(box(0.9, 7.5, 0.004), c, "fabric", T(0, 0, 0.019))
    for i in range(5):
        y = -3.0 + i * 1.5
        for k in range(6):
            a = 2 * math.pi * k / 6
            p.add(petal(0.25, 0.15, cup=0, curl=0), BLUSH if c == ROSE else ROSE, "fabric", T(0, y, 0.023) @ R("Z", math.degrees(a)) @ S(1, 1, 0.05))
        p.add(lathe([(0, 0), (0.07, 0), (0.07, 0.005), (0, 0.005)], 10), GOLD, "fabric", T(0, y, 0.024))


def cushion_pile(p, size, c):
    rng = random.Random(151)
    cols = [c, ROSE, LILAC, MINT, BUTTER, PERI]
    spots = [(-0.2, -0.15, 0.1, 0, 0), (0.2, -0.1, 0.1, 10, 1), (0.0, 0.2, 0.1, -5, 2), (-0.05, -0.05, 0.27, 20, 3), (0.15, 0.15, 0.25, -25, 4)]
    for x, y, z, a, i in spots:
        p.add(cushion(0.5, 0.5, 0.18, 0.6), cols[i], "fabric", T(x, y, z) @ R("Z", a) @ R("X", rng.uniform(-10, 10)))
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.add(sphere(0.02, 6, 4), GOLD, "gold", T(x, y, z) @ R("Z", a) @ T(sx * 0.24, sy * 0.24, 0))


def window_seat(p, size, c):
    w, h, d = 2.0, 0.6, 0.7
    p.add(box(w, d, 0.42, bevel=0.03), PEARL, "pearl", T(0, 0, 0.21))
    for i in range(3):
        x = -w / 3 + i * w / 3
        panel = arched_outline(w / 3 - 0.15, 0.28, 8, 0.08)
        p.add(frame_ring(panel, 0.01, 0.02), GOLD, "gold", T(x, d / 2 + 0.01, 0.06))
    p.add(cushion(w - 0.05, d - 0.05, 0.14, 0.3), c, "fabric", T(0, 0, 0.49))
    cols = [ROSE, LILAC, MINT, BUTTER]
    for i, x in enumerate((-0.75, -0.35, 0.35, 0.75)):
        p.add(cushion(0.38, 0.14, 0.36, 0.5), cols[i], "fabric", T(x, -d / 2 + 0.12, 0.7) @ R("X", -12) @ R("Z", (i - 1.5) * 8))


# ------------------------------------------------------------ lighting


def chandelier(p, rad, h, tiers=2, c=GOLD, crystal=True):
    rng = random.Random(161)
    p.add(cyl(0.012, h * 0.35, 6), c, "gold", T(0, 0, h * 0.65))
    p.add(lathe([(0, 0), (0.08 * rad, 0.03), (0.06 * rad, 0.15 * h), (0.1 * rad, 0.3 * h), (0.04 * rad, 0.45 * h), (0.06 * rad, 0.6 * h), (0, 0.66 * h)], 10), c, "gold", T(0, 0, 0.0))
    for t in range(tiers):
        r = rad * (0.9 - 0.4 * t)
        z = h * (0.2 + 0.25 * t)
        n = 8 - 3 * t
        p.add(torus(r * 0.85, 0.012 * rad + 0.004, 24, 4), c, "gold", T(0, 0, z - 0.05))
        for i in range(n):
            a = 2 * math.pi * (i + 0.5 * t) / n
            ca, sa = math.cos(a), math.sin(a)
            p.add(tube([(0.05 * ca, 0.05 * sa, z + 0.12), (r * 0.5 * ca, r * 0.5 * sa, z - 0.08), (r * ca, r * sa, z)], 0.012, 5), c, "gold")
            p.add(lathe([(0, 0), (0.04, 0.0), (0.045, 0.025)], 8), c, "gold", T(r * ca, r * sa, z))
            candle(p, r * ca, r * sa, z + 0.02, 0.1 * rad + 0.04, 0.014)
            if crystal:
                for k in range(1):
                    zz = z - 0.12 - k * 0.08
                    p.add(sphere(0.022 if k else 0.016, 4, 3), (0.95, 0.92, 1.0), "glass", T(r * 0.75 * ca, r * 0.75 * sa, zz) @ S(1, 1, 1.6), smooth=False)
    if crystal:
        for i in range(12):
            a = 2 * math.pi * i / 12
            pts = [(rad * 0.85 * math.cos(a + 0.26 * k), rad * 0.85 * math.sin(a + 0.26 * k), h * 0.15 - 0.06 * math.sin(math.pi * k / 2)) for k in range(3)]
            for x, y, z in pts[1:2]:
                p.add(sphere(0.02, 4, 3), (0.95, 0.92, 1.0), "glass", T(x, y, z), smooth=False)
        p.add(ico(0.06, 1), (0.98, 0.9, 1.0), "glass", T(0, 0, -0.02) @ S(1, 1, 1.8), smooth=False)


def chandelier_crystal(p, size, c):
    chandelier(p, 1.1, 1.8, 3, c)


def chandelier_small(p, size, c):
    chandelier(p, 0.6, 1.0, 1, c)


def candelabra(p, size, c):
    _candelabra_at(p, 0, 0, 0, 0.7)


def candle_sconce(p, size, c):
    p.add(slab(oval_outline(0.16, 0.3, 12), 0.03), c, "gold", T(0, -0.085, 0.1))
    p.add(slab(oval_outline(0.1, 0.2, 12), 0.01), (0.93, 0.9, 1.0), "mirror", T(0, -0.065, 0.15))
    p.add(tube([(0, -0.08, 0.16), (0, 0.0, 0.1), (0, 0.06, 0.18)], 0.012, 5), c, "gold")
    p.add(lathe([(0, 0), (0.035, 0), (0.04, 0.02)], 8), c, "gold", T(0, 0.06, 0.18))
    candle(p, 0, 0.06, 0.2, 0.14, 0.015)
    p.add(lathe([(0, 0), (0.03, 0.03), (0, 0.06)], 6), c, "gold", T(0, -0.08, 0.02) @ R("X", 180) @ T(0, 0, -0.06))


def lantern_hanging(p, size, c):
    p.add(torus(0.04, 0.008, 8, 4), c, "gold", T(0, 0, 0.66) @ R("X", 90))
    p.add(lathe([(0, 0.62), (0.12, 0.52), (0.16, 0.48), (0.14, 0.46)], 8), c, "gold")
    for i in range(6):
        a = 2 * math.pi * i / 6
        p.add(cyl(0.008, 0.36, 4), c, "gold", T(0.14 * math.cos(a), 0.14 * math.sin(a), 0.1))
    p.add(lathe([(0, 0), (0.08, 0.0), (0.15, 0.08), (0.15, 0.1), (0, 0.1)], 8), c, "gold")
    p.add(cyl(0.13, 0.36, 6), (1.0, 0.85, 0.9, 0.35), "glass", T(0, 0, 0.1), smooth=False)
    p.add(sphere(0.06, 8, 6), FLAME, "glow", T(0, 0, 0.28) @ S(1, 1, 1.4))


def floor_candlestand(p, size, c):
    p.add(lathe([(0, 0), (0.18, 0), (0.17, 0.03), (0.05, 0.08), (0.03, 0.2), (0.05, 0.3), (0.025, 0.4), (0.025, 1.2), (0.05, 1.3), (0.035, 1.38), (0.09, 1.42), (0.09, 1.44)], 10), c, "gold")
    for i in range(3):
        a = math.radians(120 * i)
        p.add(scroll(0.07, 1.0, 8, 0.012), c, "gold", T(0.1 * math.cos(a), 0.1 * math.sin(a), 0.05) @ R("Z", math.degrees(a) + 90))
    candle(p, 0, 0, 1.44, 0.12, 0.035)


def faelight_orb(p, size, c):
    p.add(ico(0.1, 2), c, "glow")
    p.add(sphere(0.15, 12, 8), (1.0, 0.95, 0.85, 0.25), "glass")
    for i in range(4):
        a = math.radians(90 * i + 45)
        p.add(petal(0.08, 0.05, cup=0.1, curl=0.2), (0.85, 1.0, 0.95), "glass", T(0.06 * math.cos(a), 0.06 * math.sin(a), 0.05) @ R("Z", math.degrees(a)) @ R("Y", -40))


BUILDERS = {
    "bed_canopy": bed_canopy, "bed_single": bed_single, "bed_servant": bed_servant, "cradle_chest": cradle_chest,
    "nightstand": nightstand, "wardrobe_tall": wardrobe_tall, "dresser": dresser,
    "vanity_table": vanity_table, "vanity_mirror": vanity_mirror, "cheval_mirror": cheval_mirror,
    "gown_rack": gown_rack, "mannequin_gown": mannequin_gown, "shoe_shelf": shoe_shelf, "hat_stand": hat_stand,
    "jewelry_box": jewelry_box, "perfume_tray": perfume_tray, "makeup_palette": makeup_palette,
    "dressing_screen": dressing_screen, "pouf_stool": pouf_stool,
    "chaise_longue": chaise_longue, "sofa": sofa, "armchair": armchair, "wingback_chair": wingback_chair,
    "chair_dining": chair_dining, "chair_simple": chair_simple, "bench_settle": bench_settle, "stool": stool,
    "table_dining_long": table_dining_long, "table_round": table_round, "table_side": table_side,
    "table_tea": table_tea, "table_work": table_work, "table_kitchen": table_kitchen,
    "desk_writing": desk_writing, "desk_large": desk_large, "cabinet_curio": cabinet_curio, "sideboard": sideboard,
    "chest_trunk": chest_trunk, "coat_rack": coat_rack, "rug_large": rug_large, "rug_round": rug_round,
    "rug_runner": rug_runner, "cushion_pile": cushion_pile, "window_seat": window_seat,
    "chandelier_crystal": chandelier_crystal, "chandelier_small": chandelier_small, "candelabra": candelabra,
    "candle_sconce": candle_sconce, "lantern_hanging": lantern_hanging, "floor_candlestand": floor_candlestand,
    "faelight_orb": faelight_orb,
}
