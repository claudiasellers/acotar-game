"""Garden-room props for the manor gardens (L35): the heron fountain, the lamb
statue, rose swags and tunnels, the wisteria walk, yew hedges and topiary,
pavilions, the Temple of Love, swings, urns, lanterns.
Same contract as parts A-C: builder(p, size, color), front faces +Y, fitted to
the catalogue size afterwards. Budget <= 3,000 tris each (manor_props.py checks).

Canon (Keeper, book 1): the heron fountain in a small pool near iris beds (ch24),
the weathered statue of two bounding lambs and the foxglove alcove (ch8), the
wisteria trellis under Feyre's window (ch11), hedges and gravel walks (ch7-19).
Everything else (swags, tunnels, topiary, pavilions, the temple) is canon:"X".
Look: R3 pastels + gold against deep clipped yew; garden stone stays <= 0.85
albedo (manor glare fix), never near-white in direct sun.
"""
import math
import random

import bmesh
from mathutils import Vector
from prop_kit import (BLUSH, BUTTER, GOLD, LILAC, PERI, ROSE, SAGE, SAGE_DEEP, SAGE_LIGHT, WHITE, R, S, T,
                      box, cyl, ico, lathe, leaf, lighter, darker, mix, petal, soft_rose, sphere, torus, tube, disc)

# Garden palette (sRGB). Stone is warm and mid-light so it never glares.
STONE = (0.84, 0.78, 0.77)
STONE_SHADE = (0.70, 0.63, 0.66)
DOVE = (0.66, 0.64, 0.73)          # the heron's weathered stone: lilac-tinted, never flat grey
LICHEN = (0.62, 0.70, 0.58)
IRON_WHITE = (0.84, 0.81, 0.88)    # painted garden iron, pearl finish
YEW = (0.16, 0.38, 0.27)
YEW_MID = (0.22, 0.46, 0.31)
YEW_TIP = (0.36, 0.58, 0.38)
BOX_GREEN = (0.26, 0.52, 0.34)
WATERC = (0.55, 0.80, 0.90, 0.6)
ROSE_MIX = [ROSE, BLUSH, (0.95, 0.36, 0.52), (1.0, 0.86, 0.80), (0.98, 0.62, 0.66)]
WISTERIA = [(0.74, 0.62, 0.95), (0.82, 0.74, 1.0), (0.66, 0.66, 0.98), (0.96, 0.94, 1.0)]
SWEETPEA = [(1.0, 0.62, 0.78), (0.80, 0.62, 0.98), (1.0, 0.86, 0.90), (0.98, 0.45, 0.62), (0.70, 0.72, 1.0)]


# ------------------------------------------------------------ small pieces


def rosette(p, center, r, col, tilt=None, rng=None, finish="fabric", n=5):
    """A rounded full rose: a smooth cupped head and a few broad outer petals
    (prop_kit.soft_rose; L35-4 replaced the pointed five-petal shard)."""
    rng = rng or random.Random(3)
    m = T(*center) @ (tilt if tilt is not None else R("Z", 0))
    soft_rose(p, m, r, col, finish, rng, petals=min(n, 3))


def leaves_mass(p, cx, cy, cz, r, col, rng, n=4, sub=1, squash=0.85, finish="leaf"):
    """A lumpy foliage mass of n soft balls around a centre."""
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.3, 0.3)
        rr = r * rng.uniform(0.55, 0.75)
        p.add(ico(rr, sub), col if i % 2 else lighter(col, 0.10), finish,
              T(cx + r * 0.45 * math.cos(a), cy + r * 0.45 * math.sin(a), cz + rng.uniform(-0.15, 0.2) * r) @ S(1, 1, squash))


def clipped_block(p, sx, sy, sz, cx, cy, cz, rng, col=YEW, tip=YEW_TIP, seg=2):
    """A clipped yew block: soft bevels, a lighter fresh-growth top, and tufts
    so it reads as foliage, not a box."""
    b = box(sx, sy, sz, bevel=min(sx, sy, sz) * 0.22, seg=seg)
    for v in b.verts:
        v.co.x *= 1.0 + rng.uniform(-0.015, 0.015)
        v.co.y *= 1.0 + rng.uniform(-0.03, 0.03)
        v.co.z *= 1.0 + rng.uniform(-0.01, 0.01)
    p.add(b, col, "leaf", T(cx, cy, cz), sharp_deg=89.0)
    cap = box(sx * 0.98, sy * 0.96, sz * 0.12, bevel=min(sx, sy) * 0.2, seg=1)
    p.add(cap, mix(col, tip, 0.55), "leaf", T(cx, cy, cz + sz * 0.46), sharp_deg=89.0)
    n = max(3, int(sx * sz * 1.4))
    for _ in range(n):
        side = rng.choice((-1, 1))
        x = cx + rng.uniform(-sx * 0.45, sx * 0.45)
        z = cz + rng.uniform(-sz * 0.35, sz * 0.45)
        p.add(ico(rng.uniform(0.10, 0.17), 0), tip if rng.random() < 0.5 else YEW_MID, "leaf",
              T(x, cy + side * sy * 0.5, z) @ S(1, 0.6, 1))


def climbing_roses(p, pts, rng, cols=ROSE_MIX, every=2, leaf_r=0.16, bloom_r=0.11, petals=4):
    """Foliage and roses strung along a path of points (a vine)."""
    for i, (x, y, z) in enumerate(pts):
        if i % 2 == 0:
            # one soft, lumpy clump every other point (same tris as two
            # hexagonal ico-0 balls per point, but round in silhouette)
            b = ico(leaf_r * 1.35 * rng.uniform(0.85, 1.1), 1)
            for v in b.verts:
                v.co *= 1.0 + rng.uniform(-0.12, 0.12)
            p.add(b, [SAGE, SAGE_DEEP, mix(SAGE, SAGE_LIGHT, 0.5)][(i // 2) % 3], "leaf",
                  T(x, y, z - leaf_r * 0.2) @ S(1, 1, 0.8), sharp_deg=89.0)
        if i % every == 0:
            ox, oy = rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08)
            rosette(p, (x + ox, y + oy, z + 0.05), bloom_r * rng.uniform(0.85, 1.2), cols[(i // every) % len(cols)],
                    R("X", rng.uniform(-50, 50)) @ R("Y", rng.uniform(-50, 50)), rng, n=petals)


def raceme(p, top, length, col, rng):
    """A hanging wisteria raceme: a tapering cone of tiny florets."""
    x, y, z = top
    p.add(lathe([(0, 0), (length * 0.12, length * 0.10), (length * 0.22, length * 0.5), (length * 0.2, length * 0.82),
                 (0.03, length)], 5), col, "fabric", T(x, y, z - length))
    p.add(lathe([(0.0, 0), (length * 0.09, length * 0.25), (0.0, length * 0.4)], 4), lighter(col, 0.3), "fabric",
          T(x, y, z - length * 1.02))


def plinth(p, w, h, col=STONE, d=None):
    d = d or w
    p.add(box(w, d, h * 0.18, bevel=0.03), darker(col, 0.06), "matte", T(0, 0, h * 0.09))
    p.add(box(w * 0.82, d * 0.82, h * 0.66, bevel=0.02), col, "matte", T(0, 0, h * 0.18 + h * 0.33))
    p.add(box(w * 0.96, d * 0.96, h * 0.16, bevel=0.03), lighter(col, 0.04), "matte", T(0, 0, h * 0.92))


def column(p, x, y, z0, h, r, col=STONE, gold_band=True):
    p.add(lathe([(r * 1.35, 0), (r * 1.35, h * 0.05), (r * 1.1, h * 0.07), (r, h * 0.1), (r * 0.9, h * 0.9),
                 (r * 1.1, h * 0.93), (r * 1.4, h * 0.97), (r * 1.4, h)], 10), col, "pearl", T(x, y, z0))
    if gold_band:
        p.add(torus(r * 0.95, r * 0.12, 10, 4), GOLD, "gold", T(x, y, z0 + h * 0.91))


# ------------------------------------------------------------ canon pieces


def heron_fountain(p, size, c):
    """[C] ch24: a fountain statue of a great heron flapping its wings, in a small
    pool. Low quatrefoil-ish round basin, a rock of lily leaves, the heron with
    wings half raised, beak to the sky, a thin jet from the beak."""
    R0 = 4.5
    p.add(lathe([(R0 + 0.35, 0), (R0 + 0.45, 0.10), (R0 + 0.45, 0.48), (R0 + 0.25, 0.62), (R0 - 0.05, 0.62),
                 (R0 - 0.15, 0.52), (R0 - 0.2, 0.15), (0, 0.15)], 32), STONE, "pearl")
    p.add(torus(R0 + 0.12, 0.05, 32, 4), GOLD, "gold", T(0, 0, 0.62))
    p.add(disc(R0 - 0.18, 32, 0.46), WATERC, "water")
    # the rock and lily pads
    rng = random.Random(2401)
    for i in range(5):
        a = 2 * math.pi * i / 5
        p.add(ico(0.75, 1), mix(DOVE, LICHEN, 0.25 if i % 2 else 0.05), "matte",
              T(0.45 * math.cos(a), 0.45 * math.sin(a), 0.55) @ S(1, 1, 0.75))
    p.add(ico(0.7, 1), DOVE, "matte", T(0, 0, 1.1) @ S(1, 1, 0.8))
    for i in range(7):
        a = 2 * math.pi * i / 7 + 0.4
        d = rng.uniform(1.6, 3.6)
        p.add(cyl(0.38, 0.02, 8), (0.42, 0.66, 0.46), "leaf", T(d * math.cos(a), d * math.sin(a), 0.47))
        if i % 2 == 0:
            rosette(p, (d * math.cos(a) + 0.1, d * math.sin(a), 0.5), 0.14, (1.0, 0.78, 0.88), None, rng)
    # heron: body, long S neck, head, beak; legs on the rock; wings raised.
    # Built at life size and scaled 1.45x so it reads across the garden.
    HM = T(0, 0, 1.5) @ S(1.45) @ T(0, 0, -1.5)

    def ha(part, col, fin, m=None):
        p.add(part, col, fin, HM @ m if m is not None else HM)

    z0 = 1.5
    ha(ico(0.42, 2), DOVE, "satin", T(0, 0, z0 + 0.55) @ S(0.75, 1.25, 0.7) @ R("X", -20))
    neck = [(0, 0.35, z0 + 0.75), (0, 0.48, z0 + 1.05), (0, 0.38, z0 + 1.35), (0, 0.46, z0 + 1.62), (0, 0.6, z0 + 1.82)]
    ha(tube(neck, [0.13, 0.10, 0.09, 0.085, 0.08], 6), DOVE, "satin")
    ha(ico(0.12, 1), DOVE, "satin", T(0, 0.64, z0 + 1.88) @ S(0.85, 1.3, 0.9))
    ha(cyl(0.045, 0.5, 6, r2=0.004), GOLD, "gold", T(0, 0.72, z0 + 1.9) @ R("X", -62))
    ha(tube([(0, 0.55, z0 + 1.9), (0, 0.3, z0 + 1.98), (0, 0.08, z0 + 1.93)], [0.02, 0.015, 0.008], 4), DOVE, "satin")   # crest plume
    for sx in (-1, 1):
        ha(tube([(sx * 0.12, 0.05, z0 + 0.2), (sx * 0.13, 0.0, z0 - 0.2), (sx * 0.14, -0.05, z0 - 0.45)], 0.03, 5), DOVE, "satin")
        # wing: three feather tiers fanned up and out
        for k in range(3):
            span = 1.35 - k * 0.22
            base = (sx * 0.28, -0.05 - k * 0.12, z0 + 0.72)
            tip = (sx * (0.28 + span * 0.85), -0.35 - k * 0.15, z0 + 0.72 + span * (0.75 - k * 0.12))
            mid = ((base[0] + tip[0]) / 2, (base[1] + tip[1]) / 2 - 0.08, (base[2] + tip[2]) / 2 + 0.12)
            ha(tube([base, mid, tip], [0.16 - k * 0.03, 0.13 - k * 0.025, 0.03], 5), lighter(DOVE, 0.05 * k), "satin",
                  S(1, 1, 1))
            for f in range(4):
                t = 0.55 + 0.15 * f
                fx = base[0] + (tip[0] - base[0]) * t
                fy = base[1] + (tip[1] - base[1]) * t
                fz = base[2] + (tip[2] - base[2]) * t
                ha(leaf(0.55 - k * 0.08, 0.16), lighter(DOVE, 0.08), "satin",
                      T(fx, fy, fz) @ R("Z", -90 * sx) @ R("Y", 70 + 8 * f))
    # tail plumes
    for k in range(3):
        ha(leaf(0.55, 0.16), DOVE, "satin", T((k - 1) * 0.1, -0.45, z0 + 0.45) @ R("Z", -90 + (k - 1) * 18) @ R("Y", 30))
    # the jet from the beak, falling as a bead string
    jet = [(0, 1.15, z0 + 2.95), (0, 1.6, z0 + 3.25), (0, 2.1, z0 + 3.0), (0, 2.6, z0 + 2.0), (0, 2.9, 0.6)]
    p.add(tube(jet, [0.035, 0.04, 0.045, 0.05, 0.06], 5), (0.85, 0.95, 1.0, 0.55), "water")


def lamb_statue(p, size, c):
    """[C] ch8: a weathered statue of two merry, bounding lambs, on a low plinth."""
    rng = random.Random(808)
    p.add(box(1.8, 0.9, 0.3, bevel=0.05), STONE_SHADE, "matte", T(0, 0, 0.15))
    p.add(box(1.7, 0.82, 0.06, bevel=0.02), mix(STONE, LICHEN, 0.25), "matte", T(0, 0, 0.32))

    def lamb(x, z, pitch, yaw, scale):
        m = T(x, 0, z) @ R("Z", yaw) @ R("X", pitch) @ S(scale)
        # fleece body of soft lumps
        for i in range(7):
            a = 2 * math.pi * i / 7
            p.add(ico(0.16, 1), mix(STONE, (0.92, 0.86, 0.82), 0.4 if i % 2 else 0.2), "matte",
                  m @ T(0.11 * math.cos(a), 0.22 * math.sin(a) * 0.9, 0.06 * math.sin(a * 2)))
        p.add(ico(0.2, 1), mix(STONE, (0.92, 0.86, 0.82), 0.3), "matte", m @ S(0.85, 1.25, 0.85))
        p.add(ico(0.12, 1), STONE, "matte", m @ T(0, 0.34, 0.12) @ S(0.8, 1.15, 0.9))
        for sx in (-1, 1):
            p.add(leaf(0.12, 0.06), STONE_SHADE, "matte", m @ T(sx * 0.09, 0.32, 0.18) @ R("Z", 90 + sx * 60) @ R("X", 20))
            for sy in (-1, 1):
                kick = 25 if sy > 0 else -35
                p.add(tube([(sx * 0.08, sy * 0.15, -0.08), (sx * 0.09, sy * 0.2 + kick * 0.003, -0.24), (sx * 0.09, sy * 0.26, -0.36)],
                           [0.04, 0.035, 0.03], 5), STONE, "matte", m)
        p.add(ico(0.06, 0), STONE, "matte", m @ T(0, -0.3, 0.06))
    lamb(-0.45, 0.78, -14, -96, 1.0)     # mid-leap
    lamb(0.45, 0.62, 10, -80, 0.95)      # landing, head up
    for i in range(9):   # moss and little white flowers at the foot
        x = rng.uniform(-0.8, 0.8)
        p.add(ico(0.06, 0), LICHEN, "leaf", T(x, rng.choice((-0.4, 0.4)), 0.33))


def alcove_niche(p, size, c):
    """[C] ch8: a clipped yew alcove (U-shaped) to hold the foxglove bench; the
    open side faces +Y."""
    rng = random.Random(81)
    w, d, h = 3.6, 2.0, 3.0
    clipped_block(p, w, 0.7, h, 0, -d / 2 + 0.35, h / 2, rng)
    for sx in (-1, 1):
        clipped_block(p, 0.7, d - 0.4, h * 0.92, sx * (w / 2 - 0.35), 0.15, h * 0.46, rng)
    # a scalloped crown over the back
    for i in range(5):
        x = -1.2 + i * 0.6
        p.add(ico(0.32, 1), YEW_MID, "leaf", T(x, -d / 2 + 0.35, h + 0.12) @ S(1, 0.9, 0.7))
    # foxglove spires growing against the green (canon "blooming with foxglove")
    for sx in (-1, 1):
        for k in range(3):
            x = sx * (w / 2 - 0.9 + k * 0.05)
            y = -0.2 + k * 0.45
            col = [(0.92, 0.50, 0.80), (0.98, 0.72, 0.90), (0.80, 0.55, 0.95)][k]
            p.add(cyl(0.02, 1.2, 4), SAGE_DEEP, "leaf", T(x, y, 0))
            for j in range(6):
                p.add(lathe([(0.0, 0), (0.05, 0.02), (0.06, 0.1), (0.045, 0.13)], 5, cap_top=False), col, "fabric",
                      T(x + 0.04 * math.cos(j * 2.4), y + 0.04 * math.sin(j * 2.4), 0.55 + j * 0.11) @ R("X", 180))


def wisteria_trellis(p, size, c):
    """[C] ch11: the wisteria trellis climbing the wall under Feyre's window.
    A diamond lattice with a gnarled vine and hanging racemes."""
    rng = random.Random(1111)
    w, h = 4.0, 6.0
    for k in range(-14, 15):
        for sgn in (-1, 1):
            # a 45-degree slat through (k * 0.5, 0.2), clipped to the frame
            x0 = k * 0.5
            ts = [t for t in (0.0, h - 0.2) if -w / 2 <= x0 + sgn * t <= w / 2]
            lo_t = max(0.0, (-w / 2 - x0) / sgn if sgn > 0 else (x0 - w / 2) / 1.0)
            hi_t = min(h - 0.2, (w / 2 - x0) / sgn if sgn > 0 else (x0 + w / 2))
            if hi_t - lo_t < 0.2:
                continue
            p.add(tube([(x0 + sgn * lo_t, 0, 0.2 + lo_t), (x0 + sgn * hi_t, 0, 0.2 + hi_t)], 0.025, 4), IRON_WHITE, "pearl")
    for sx in (-1, 1):
        p.add(box(0.08, 0.08, h, bevel=0.01), IRON_WHITE, "pearl", T(sx * w / 2, 0, h / 2))
    p.add(box(w + 0.1, 0.1, 0.08, bevel=0.01), IRON_WHITE, "pearl", T(0, 0, h))
    vine = [(-0.3, 0.12, 0), (-0.1, 0.12, 1.2), (-0.6, 0.12, 2.4), (0.4, 0.12, 3.4), (1.4, 0.12, 4.4), (1.6, 0.12, 5.4)]
    p.add(tube(vine, [0.09, 0.07, 0.06, 0.05, 0.04, 0.03], 5), (0.55, 0.42, 0.44), "matte")
    vine2 = [(-0.4, 0.12, 2.0), (-1.4, 0.12, 3.0), (-1.6, 0.12, 4.3), (-0.8, 0.12, 5.5)]
    p.add(tube(vine2, [0.05, 0.04, 0.035, 0.025], 5), (0.55, 0.42, 0.44), "matte")
    for i in range(29):
        x = rng.uniform(-1.9, 1.9)
        z = rng.uniform(1.6, 5.9)
        p.add(ico(rng.uniform(0.18, 0.28), 0), SAGE if i % 2 else SAGE_DEEP, "leaf", T(x, 0.18, z) @ S(1, 0.6, 0.8))
        if i % 3 != 2:
            raceme(p, (x + rng.uniform(-0.1, 0.1), 0.26, z - 0.05), rng.uniform(0.35, 0.6), WISTERIA[i % 4], rng)


# ------------------------------------------------------------ roses


def rose_swag_bay(p, size, c):
    """One bay of the rose-swag ring: a garden column wreathed in a climbing rose
    and a rope swag (catenary) to the next column, heavy with roses."""
    rng = random.Random(2525)
    L = 6.6
    x0 = -L / 2
    column(p, x0, 0, 0, 2.7, 0.13, STONE)
    p.add(lathe([(0.0, 0), (0.12, 0.05), (0.06, 0.22), (0.0, 0.3)], 8), GOLD, "gold", T(x0, 0, 2.72))
    rope = []
    for i in range(15):
        t = i / 14
        x = x0 + L * t
        z = 2.62 - 0.85 * (1 - (2 * t - 1) ** 2)
        rope.append((x, 0, z))
    p.add(tube(rope, 0.04, 5), (0.80, 0.66, 0.60), "satin")
    garland = []
    for i in range(1, 14):
        x, _, z = rope[i]
        garland.append((x, rng.uniform(-0.12, 0.12), z - 0.08))
        if i % 2:
            garland.append(((x + rope[i + 1][0]) / 2, rng.uniform(-0.12, 0.12), (z + rope[i + 1][2]) / 2 - 0.16))
    climbing_roses(p, garland, rng, every=1, leaf_r=0.22, bloom_r=0.3)
    spiral = [(x0 + 0.2 * math.cos(a), 0.2 * math.sin(a), 0.2 + a * 0.2) for a in [k * 0.85 for k in range(15)]]
    climbing_roses(p, spiral, rng, every=3, leaf_r=0.18, bloom_r=0.24)


def rose_tunnel_arch(p, size, c):
    """A hooped iron arch smothered in climbing roses; set in rows for a rose tunnel."""
    rng = random.Random(3131)
    w, h = 5.4, 3.8
    spring = 2.2
    hoop = []
    for i in range(17):
        a = math.pi * i / 16
        hoop.append((-(w / 2) * math.cos(a), 0, spring + (h - spring) * math.sin(a)))
    pts = [(-w / 2, 0, 0)] + hoop + [(w / 2, 0, 0)]
    for dy in (-0.35, 0.35):
        p.add(tube([(x, dy, z) for x, _, z in pts], 0.045, 5), IRON_WHITE, "pearl")
    for k in range(0, 17, 4):
        x, _, z = hoop[k]
        p.add(tube([(x, -0.35, z), (x, 0.35, z)], 0.025, 4), GOLD, "gold")
    vine = [(-w / 2, rng.uniform(-0.3, 0.3), 0.3 + 0.38 * i) for i in range(5)] + [(x, rng.uniform(-0.35, 0.35), z) for x, _, z in hoop] + \
           [(w / 2, rng.uniform(-0.3, 0.3), 0.3 + 0.38 * i) for i in range(4, -1, -1)]
    climbing_roses(p, vine, rng, every=1, leaf_r=0.26, bloom_r=0.28)
    for k in range(0):   # (budget) trailing sprays hanging into the walk
        x, _, z = hoop[rng.randrange(3, 14)]
        rosette(p, (x * 0.96, rng.uniform(-0.4, 0.4), z - 0.3), 0.12, ROSE_MIX[k % 5], R("X", 180), rng)


def rose_standard(p, size, c, col=ROSE):
    """A standard (tree) rose: a clipped lollipop head of roses on a clean stem
    in a fluted pot."""
    rng = random.Random(4141 + int(col[0] * 100))
    p.add(lathe([(0.22, 0), (0.26, 0.05), (0.3, 0.35), (0.34, 0.4), (0.0, 0.4)], 10), STONE, "pearl")
    p.add(torus(0.31, 0.02, 10, 4), GOLD, "gold", T(0, 0, 0.37))
    p.add(cyl(0.035, 1.3, 6), (0.55, 0.42, 0.44), "matte", T(0, 0, 0.4))
    leaves_mass(p, 0, 0, 1.75, 0.42, SAGE_DEEP, rng, 5, 1, 0.9)
    p.add(ico(0.36, 1), SAGE, "leaf", T(0, 0, 1.85))
    for i in range(18):
        a = 2.39996 * i
        e = math.asin(min(0.98, -0.55 + 1.5 * (i + 0.5) / 18))
        r = 0.5
        x, y, z = r * math.cos(a) * math.cos(e), r * math.sin(a) * math.cos(e), 1.8 + r * 0.85 * math.sin(e)
        rosette(p, (x, y, z), 0.2, col if i % 4 else lighter(col, 0.2), R("Z", math.degrees(a)) @ R("Y", 90 - math.degrees(e)), rng)


def rose_standard_pink(p, size, c):
    rose_standard(p, size, c, (0.98, 0.56, 0.70))


def rose_standard_white(p, size, c):
    rose_standard(p, size, c, (1.0, 0.95, 0.93))


def rose_standard_apricot(p, size, c):
    rose_standard(p, size, c, (1.0, 0.74, 0.55))


# ------------------------------------------------------------ wisteria walk


def wisteria_bay(p, size, c):
    """One 3 m bay of the wisteria walk: a pair of stone piers with a timber
    pergola over, dripping with lilac, periwinkle and white racemes. Bays tile
    along +Y; each holds the piers at its -Y end."""
    rng = random.Random(5151)
    w, h, d = 5.0, 3.2, 3.0
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.25)
        p.add(lathe([(0.26, 0), (0.26, 0.2), (0.2, 0.3), (0.18, 2.75), (0.24, 2.85), (0.24, 2.95)], 8), STONE, "pearl", T(x, -d / 2 + 0.25, 0))
        p.add(box(0.22, d + 0.2, 0.24, bevel=0.03), (0.78, 0.62, 0.58), "satin", T(x, 0, h - 0.12))
        # twisting trunks up the piers
        p.add(tube([(x + 0.25, -d / 2 + 0.3, 0), (x + 0.15, -d / 2 + 0.45, 1.0), (x + 0.3, -d / 2 + 0.25, 2.0), (x + 0.1, -d / 2 + 0.6, 3.0)],
                   [0.08, 0.07, 0.06, 0.05], 5), (0.55, 0.42, 0.44), "matte")
    for k in range(4):
        y = -d / 2 + 0.35 + k * 0.8
        p.add(box(w + 0.4, 0.14, 0.18, bevel=0.03), (0.80, 0.64, 0.60), "satin", T(0, y, h + 0.09))
    # canopy of leaves over the beams (L35-3): one continuous, lumpy mattress
    # of foliage rolling down over both sides, its lumps periodic along the
    # walk so the tiled bays join without a seam or a repeating tile shape;
    # a few lighter clumps of new growth break it up. The flowers show from
    # above as lilac sprays lying on top, never as pale near-white leaf.
    OVERLAP = 0.45
    bm = bmesh.new()
    nx, ny = 14, 8
    bmesh.ops.create_grid(bm, x_segments=nx, y_segments=ny, size=1.0)
    half = w / 2 + 0.3
    for v in bm.verts:
        u, t = v.co.x, v.co.y                       # -1..1 each
        # the roof runs OVERLAP past each bay end and tucks just under the
        # neighbour's, so a run of bays on sloping ground reads as one roof
        # with no seams or steps (L35-6)
        x, y = u * half, t * (d / 2 + OVERLAP)
        ph = 2 * math.pi * y / d
        z = (0.13 * math.sin(2 * ph + 1.7 * x) + 0.09 * math.cos(ph - 2.3 * x + 0.6)
             + 0.06 * math.sin(3 * ph + 3.1 * x))
        if abs(y) < d / 2 - 0.05:
            z += rng.uniform(-0.04, 0.04)
        z -= 0.12 * max(0.0, abs(y) - d / 2) / OVERLAP
        z -= 0.6 * max(0.0, abs(u) - 0.86) / 0.14    # roll down over the sides, past the beam ends
        v.co = Vector((x, y, h + 0.46 + z))
    p.add(bm, mix(SAGE, YEW_MID, 0.35), "leaf", sharp_deg=89.0)
    for i in range(7):
        # finer and only gently dented, so from above they read as soft
        # mounds of new growth rather than pale hexagons (L35-7)
        b = lathe([(1.0, -0.2), (0.74, 0.68), (0.0, 1.0)], 8, cap_bottom=False, cap_top=False)
        jr = random.Random(5152 + i)
        for v in b.verts:
            v.co *= 1.0 + jr.uniform(-0.06, 0.06)
        r = rng.uniform(0.38, 0.55)
        p.add(b, [mix(SAGE, SAGE_LIGHT, 0.35), mix(SAGE, LICHEN, 0.5)][i % 2], "leaf",
              T(rng.uniform(-w / 2 + 0.6, w / 2 - 0.6), rng.uniform(-d / 2 + 0.4, d / 2 - 0.4), h + 0.54)
              @ S(r * 1.3, r, r * 0.45), sharp_deg=89.0)
    for i in range(22):
        x = rng.uniform(-w / 2 + 0.4, w / 2 - 0.4)
        y = rng.uniform(-d / 2 + 0.2, d / 2 - 0.2)
        length = rng.uniform(0.35, 0.6)
        p.add(lathe([(0, 0), (length * 0.2, length * 0.3), (length * 0.16, length * 0.75), (0, length)], 4),
              WISTERIA[i % 3], "fabric", T(x, y, h + 0.62) @ R("Z", rng.uniform(0, 360)) @ R("Y", rng.uniform(75, 105)))
    # the racemes: many slim, soft drops, heavier along the sides, a scatter
    # over the walk. Slim and smooth so they read as hanging flower trusses
    # from the path, not as faceted crystals (L35-3); lilac, mauve and a
    # muted white that stays out of glare.
    cols = [WISTERIA[0], WISTERIA[1], mix(WISTERIA[0], (0.80, 0.58, 0.86), 0.5), (0.86, 0.84, 0.93)]
    for i in range(44):
        side = rng.random() < 0.7
        x = (rng.choice((-1, 1)) * rng.uniform(w / 2 - 0.8, w / 2 + 0.15)) if side else rng.uniform(-w / 2 + 0.6, w / 2 - 0.6)
        y = rng.uniform(-d / 2 + 0.1, d / 2 - 0.1)
        length = rng.uniform(0.7, 1.25) if side else rng.uniform(0.4, 0.75)
        rw = length * rng.uniform(0.09, 0.12)
        p.add(lathe([(0.0, 0.0), (rw * 0.5, length * 0.12), (rw, length * 0.55), (rw * 0.75, length * 0.85), (0.0, length)], 5),
              cols[(i + rng.randrange(2)) % 4], "fabric", T(x, y, h + 0.08 - length) @ R("Z", rng.uniform(0, 72)), sharp_deg=89.0)


# ------------------------------------------------------------ hedges and topiary


def yew_hedge(p, size, c):
    """A 4 m module of clipped yew wall (tiles along X); 3 m tall."""
    clipped_block(p, 4.05, 1.2, 3.0, 0, 0, 1.5, random.Random(61))


def yew_hedge_arch(p, size, c):
    """A clipped yew archway (4 m wide module, 2 m opening) with a ball finial."""
    rng = random.Random(62)
    for sx in (-1, 1):
        clipped_block(p, 1.0, 1.25, 3.0, sx * 1.5, 0, 1.5, rng)
    for i in range(7):
        a0 = math.pi * i / 7
        a1 = math.pi * (i + 1) / 7
        am = (a0 + a1) / 2
        rr = 1.5
        x, z = -rr * math.cos(am), 3.0 + 0.95 * math.sin(am)
        seg = box(rr * (a1 - a0) * 1.25, 1.25, 1.0, bevel=0.2, seg=2)
        p.add(seg, YEW, "leaf", T(x, 0, z) @ R("Y", math.degrees(am) - 90), sharp_deg=89.0)
        p.add(ico(0.2, 0), YEW_TIP, "leaf", T(x * 1.2, 0, z + 0.5) @ S(1, 1.2, 0.6))
    p.add(ico(0.42, 1), YEW_MID, "leaf", T(0, 0, 4.35))
    p.add(ico(0.2, 1), YEW_TIP, "leaf", T(0, 0, 4.85))


def box_edging(p, size, c):
    """A 1.6 m length of dwarf box edging, 0.45 m tall (tiles along X)."""
    rng = random.Random(63)
    b = box(1.66, 0.42, 0.42, bevel=0.14, seg=2)
    for v in b.verts:
        v.co.z *= 1.0 + rng.uniform(-0.04, 0.04)
    p.add(b, BOX_GREEN, "leaf", T(0, 0, 0.21), sharp_deg=89.0)
    for i in range(5):
        p.add(ico(0.1, 0), lighter(BOX_GREEN, 0.2), "leaf", T(-0.65 + i * 0.32, rng.uniform(-0.1, 0.1), 0.43) @ S(1, 1, 0.5))


def _topiary_pot(p):
    p.add(lathe([(0.32, 0), (0.36, 0.05), (0.42, 0.45), (0.46, 0.5), (0.0, 0.5)], 12), STONE, "pearl")
    p.add(torus(0.43, 0.025, 12, 4), GOLD, "gold", T(0, 0, 0.47))


def topiary_cone(p, size, c):
    rng = random.Random(71)
    p.add(lathe([(0.6, 0), (0.62, 0.3), (0.42, 1.3), (0.2, 2.1), (0.0, 2.6)], 12), YEW, "leaf")
    for i in range(14):
        t = rng.uniform(0.1, 0.9)
        a = rng.uniform(0, 2 * math.pi)
        r = 0.6 * (1 - t) + 0.02
        p.add(ico(0.1, 0), YEW_TIP, "leaf", T(r * math.cos(a), r * math.sin(a), t * 2.6))


def topiary_spiral(p, size, c):
    """A corkscrew yew spiral on a stone pot."""
    rng = random.Random(72)
    _topiary_pot(p)
    p.add(cyl(0.08, 2.4, 6), (0.55, 0.42, 0.44), "matte", T(0, 0, 0.5))
    pts = []
    for i in range(40):
        t = i / 39
        a = t * 4.2 * 2 * math.pi
        r = 0.42 * (1 - t) + 0.08
        pts.append((r * math.cos(a), r * math.sin(a), 0.6 + t * 2.1))
    radii = [0.32 * (1 - i / 39) + 0.08 for i in range(40)]
    p.add(tube(pts, radii, 7), YEW, "leaf")
    for i in range(0, 40, 3):
        x, y, z = pts[i]
        p.add(ico(radii[i] * 0.5, 0), YEW_TIP, "leaf", T(x, y, z + radii[i] * 0.7) @ S(1, 1, 0.5))
    p.add(ico(0.12, 1), YEW_MID, "leaf", T(0, 0, 2.78))


def topiary_tiered(p, size, c):
    """A three-tier 'wedding cake' of clipped discs on a single stem."""
    rng = random.Random(73)
    p.add(cyl(0.07, 2.4, 6), (0.55, 0.42, 0.44), "matte")
    for k, (r, z) in enumerate(((0.8, 0.55), (0.6, 1.35), (0.42, 2.05))):
        p.add(lathe([(0.0, -0.22), (r * 0.8, -0.22), (r, -0.08), (r, 0.08), (r * 0.8, 0.22), (0.0, 0.22)], 14), YEW if k % 2 == 0 else YEW_MID, "leaf",
              T(0, 0, z))
        for i in range(8):
            a = 2 * math.pi * i / 8 + rng.uniform(-0.2, 0.2)
            p.add(ico(0.09, 0), YEW_TIP, "leaf", T(r * 0.9 * math.cos(a), r * 0.9 * math.sin(a), z + 0.18))
    p.add(ico(0.22, 1), YEW_MID, "leaf", T(0, 0, 2.5))


def topiary_ball(p, size, c):
    """A clipped box ball in a stone pot, with a gold-trimmed rim."""
    _topiary_pot(p)
    p.add(ico(0.55, 2), BOX_GREEN, "leaf", T(0, 0, 1.0))
    rng = random.Random(74)
    for i in range(12):
        a = rng.uniform(0, 2 * math.pi)
        e = rng.uniform(-0.3, 1.2)
        p.add(ico(0.08, 0), lighter(BOX_GREEN, 0.2), "leaf", T(0.55 * math.cos(a) * math.cos(e), 0.55 * math.sin(a) * math.cos(e), 1.0 + 0.55 * math.sin(e)))


def topiary_lollipop(p, size, c):
    """A standard bay: a ball on a clean stem in a pot (lines walks and the canal)."""
    _topiary_pot(p)
    p.add(cyl(0.05, 1.4, 6), (0.55, 0.42, 0.44), "matte", T(0, 0, 0.5))
    p.add(ico(0.58, 2), YEW_MID, "leaf", T(0, 0, 2.15))
    rng = random.Random(75)
    for i in range(10):
        a = rng.uniform(0, 2 * math.pi)
        e = rng.uniform(-0.2, 1.2)
        p.add(ico(0.08, 0), YEW_TIP, "leaf", T(0.58 * math.cos(a) * math.cos(e), 0.58 * math.sin(a) * math.cos(e), 2.15 + 0.58 * math.sin(e)))


def topiary_heart_ribbon(p, size, c):
    """A heart of clipped box on a stem, threaded with a pink ribbon (princess, canon:X)."""
    _topiary_pot(p)
    p.add(cyl(0.04, 0.6, 6), (0.55, 0.42, 0.44), "matte", T(0, 0, 0.5))
    pts = []
    for i in range(24):
        t = 2 * math.pi * i / 24
        x = 16 * math.sin(t) ** 3
        z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x * 0.035, 0, 1.55 + z * 0.035))
    p.add(tube(pts, 0.17, 8, closed=True), BOX_GREEN, "leaf")
    p.add(box(0.9, 0.16, 0.5, bevel=0.06), BOX_GREEN, "leaf", T(0, 0, 1.55))
    p.add(box(0.5, 0.16, 0.4, bevel=0.06), BOX_GREEN, "leaf", T(0, 0, 1.25))
    rib = [(x * 1.06, 0.12, z) for x, _, z in pts[::3]]
    p.add(tube(rib, 0.025, 4, closed=True), ROSE, "satin")
    p.add(ico(0.06, 1), ROSE, "satin", T(0, 0.15, 1.95))


def topiary_peacock(p, size, c):
    """A clipped yew peacock on a drum, fan tail up (canon:X)."""
    rng = random.Random(76)
    p.add(lathe([(0.0, 0), (0.62, 0), (0.66, 0.15), (0.66, 0.85), (0.6, 1.0), (0.0, 1.0)], 12), YEW, "leaf")
    p.add(ico(0.32, 1), YEW_MID, "leaf", T(0, 0.15, 1.25) @ S(0.9, 1.3, 0.9))
    p.add(tube([(0, 0.4, 1.35), (0, 0.55, 1.7), (0, 0.6, 1.95)], [0.14, 0.11, 0.1], 6), YEW_MID, "leaf")
    p.add(ico(0.13, 1), YEW_MID, "leaf", T(0, 0.65, 2.02))
    for k in range(3):
        p.add(cyl(0.012, 0.18, 4), YEW_TIP, "leaf", T((k - 1) * 0.04, 0.63, 2.12))
        p.add(ico(0.03, 0), GOLD, "gold", T((k - 1) * 0.04, 0.63, 2.31))
    fan = []
    for i in range(11):
        a = math.radians(-70 + 14 * i)
        fan.append((0.75 * math.sin(a), -0.25, 1.2 + 1.05 * math.cos(a)))
    p.add(tube([(0, -0.15, 1.15)] + fan + [(0, -0.15, 1.15)], 0.16, 6, closed=True), YEW, "leaf")
    for i in range(9):
        a = math.radians(-60 + 15 * i)
        for rr in (0.45, 0.8):
            p.add(ico(0.1, 0), YEW_TIP if rr > 0.5 else YEW_MID, "leaf", T(rr * 0.75 * math.sin(a), -0.3, 1.2 + rr * 1.0 * math.cos(a)) @ S(1, 0.5, 1))


# ------------------------------------------------------------ structures


def birdcage_pavilion(p, size, c):
    """A white-iron birdcage gazebo: open filigree ribs to an onion dome, a gilt
    bird on the finial, roses climbing two posts. Opening faces +Y."""
    rng = random.Random(9191)
    r = 2.9
    n = 10
    p.add(lathe([(0, 0), (r + 0.25, 0), (r + 0.25, 0.22), (0, 0.22)], n * 2), STONE, "pearl")
    p.add(torus(r + 0.2, 0.03, n * 2, 4), GOLD, "gold", T(0, 0, 0.22))
    for k in range(n):
        a = 2 * math.pi * k / n + math.pi / n
        x, y = r * math.cos(a), r * math.sin(a)
        p.add(cyl(0.06, 2.8, 6), IRON_WHITE, "pearl", T(x, y, 0.22))
        # ogee rib to the crown
        rib = []
        for i in range(7):
            t = i / 6
            rr = r * (1.0 + 0.12 * math.sin(math.pi * t * 0.9) - t * 0.98)
            rib.append((rr * math.cos(a), rr * math.sin(a), 3.0 + 2.6 * t + 0.3 * math.sin(math.pi * t)))
        p.add(tube(rib, 0.045, 4), IRON_WHITE, "pearl")
        front = abs(math.sin(a) - 1.0) < 0.35
        if not front:
            na = a + 2 * math.pi / n
            nx, ny = r * math.cos(na), r * math.sin(na)
            p.add(tube([(x, y, 1.0), (nx, ny, 1.0)], 0.03, 4), IRON_WHITE, "pearl")
        # scalloped valance swags between posts at the top
        na = a + 2 * math.pi / n
        nx, ny = r * math.cos(na), r * math.sin(na)
        sw = [(x + (nx - x) * t, y + (ny - y) * t, 3.0 - 0.28 * math.sin(math.pi * t)) for t in (0, 0.25, 0.5, 0.75, 1.0)]
        p.add(tube(sw, 0.035, 4), GOLD, "gold")
    p.add(torus(r, 0.06, n * 2, 4), IRON_WHITE, "pearl", T(0, 0, 3.0))
    p.add(lathe([(0.0, 5.7), (0.22, 5.75), (0.16, 6.0), (0.05, 6.2), (0.0, 6.25)], 10), GOLD, "gold")
    # the gilt bird on the finial
    p.add(ico(0.12, 1), GOLD, "gold", T(0, 0, 6.38) @ S(0.8, 1.4, 0.8))
    p.add(ico(0.07, 1), GOLD, "gold", T(0, 0.15, 6.5))
    p.add(leaf(0.22, 0.1), GOLD, "gold", T(0, -0.12, 6.4) @ R("Z", -90) @ R("Y", -30))
    # lilac silk canopy inside the dome
    p.add(lathe([(r * 0.98, 3.05), (r * 0.7, 4.3), (r * 0.3, 5.2), (0.0, 5.55)], n, cap_bottom=False, cap_top=False), mix(LILAC, WHITE, 0.4), "fabric")
    for k in (2, 7):
        a = 2 * math.pi * k / n + math.pi / n
        x, y = r * math.cos(a), r * math.sin(a)
        climbing_roses(p, [(x + 0.12 * math.cos(t * 2), y + 0.12 * math.sin(t * 2), 0.3 + t * 0.35) for t in range(8)], rng, every=2)


def temple_of_love(p, size, c):
    """A round Temple of Love (canon:X): stepped podium, eight columns, a blush
    dome with gold ribs and finial, and a cupid on a pedestal inside."""
    r = 4.0
    for k, (rr, z) in enumerate(((r + 1.4, 0.0), (r + 1.0, 0.35), (r + 0.6, 0.7))):
        p.add(lathe([(rr, z), (rr, z + 0.35), (rr - 0.4, z + 0.35)], 24, cap_bottom=False, cap_top=False), STONE if k % 2 else STONE_SHADE, "pearl")
    z0 = 1.05
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        column(p, r * math.cos(a), r * math.sin(a), z0, 5.6, 0.3, STONE, gold_band=False)
    ent = z0 + 5.6
    p.add(lathe([(r - 0.55, ent), (r + 0.55, ent), (r + 0.6, ent + 0.25), (r + 0.4, ent + 0.6), (r + 0.75, ent + 0.85), (r + 0.75, ent + 1.0),
                 (r - 0.55, ent + 1.0)], 24, cap_bottom=False, cap_top=False), STONE, "pearl")
    p.add(torus(r + 0.62, 0.06, 24, 4), GOLD, "gold", T(0, 0, ent + 0.5))
    dome = [(r + 0.5, ent + 1.0), (r + 0.3, ent + 1.9), (r * 0.82, ent + 3.0), (r * 0.55, ent + 3.7), (r * 0.25, ent + 4.05), (0.0, ent + 4.15)]
    p.add(lathe(dome, 16, cap_bottom=True), mix(BLUSH, LILAC, 0.3), "pearl")
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.add(tube([(rr * math.cos(a) * 1.01, rr * math.sin(a) * 1.01, z) for rr, z in dome[:-1]], 0.07, 4), GOLD, "gold")
    p.add(lathe([(0.0, 0), (0.35, 0.1), (0.2, 0.5), (0.3, 0.8), (0.08, 1.2), (0.12, 1.5), (0.0, 1.8)], 10), GOLD, "gold", T(0, 0, ent + 4.1))
    # cupid on a pedestal
    p.add(lathe([(0.45, 0), (0.45, 0.15), (0.3, 0.25), (0.28, 1.0), (0.42, 1.1), (0.42, 1.2), (0, 1.2)], 12), STONE, "pearl", T(0, 0, z0))
    cz = z0 + 1.2
    p.add(ico(0.26, 1), mix(STONE, BLUSH, 0.3), "pearl", T(0, 0, cz + 0.45) @ S(0.9, 0.8, 1.15))
    p.add(ico(0.18, 1), mix(STONE, BLUSH, 0.3), "pearl", T(0, 0.02, cz + 0.88))
    for sx in (-1, 1):
        p.add(tube([(sx * 0.1, 0, cz + 0.2), (sx * 0.13, 0.05, cz), (sx * 0.12, 0.0, cz - 0.0)], 0.07, 5), mix(STONE, BLUSH, 0.3), "pearl")
        p.add(leaf(0.55, 0.3), (0.98, 0.94, 0.96), "pearl", T(sx * 0.12, -0.18, cz + 0.62) @ R("Z", -90 - sx * 45) @ R("Y", -40))
    p.add(tube([(-0.25, 0.25, cz + 0.55), (0, 0.32, cz + 0.85), (0.25, 0.25, cz + 1.15)], 0.025, 4), GOLD, "gold")   # bow


def garden_swing(p, size, c):
    """A rose-wreathed swing: an arched frame, a cushioned seat on flower ropes."""
    rng = random.Random(2626)
    w, h = 2.6, 3.2
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(tube([(sx * w / 2, sy * 0.7, 0), (sx * w / 2 * 0.96, sy * 0.15, h - 0.1)], 0.06, 6), IRON_WHITE, "pearl")
    p.add(tube([(-w / 2 * 0.96, 0, h - 0.1), (-0.6, 0, h + 0.1), (0.6, 0, h + 0.1), (w / 2 * 0.96, 0, h - 0.1)], 0.06, 6), IRON_WHITE, "pearl")
    for sx in (-1, 1):
        p.add(tube([(sx * 0.55, 0, h + 0.05), (sx * 0.55, 0, 0.62)], 0.018, 4), (0.86, 0.72, 0.62), "satin")
        climbing_roses(p, [(sx * 0.55, 0.0, 0.8 + 0.22 * i) for i in range(10)], rng, every=3, leaf_r=0.08, bloom_r=0.08)
    p.add(box(1.3, 0.48, 0.07, bevel=0.03), (0.86, 0.66, 0.58), "satin", T(0, 0, 0.6))
    p.add(box(1.2, 0.42, 0.08, bevel=0.04, seg=2), BLUSH, "fabric", T(0, 0, 0.67))
    climbing_roses(p, [(-1.0 + 0.2 * i, rng.uniform(-0.1, 0.1), h + 0.15 + 0.05 * math.sin(i)) for i in range(11)], rng, every=1, leaf_r=0.18, bloom_r=0.12)


def urn_overflowing(p, size, c):
    """A stone urn on a pedestal, overflowing with roses, lilac and trailing sprays."""
    rng = random.Random(3737)
    p.add(lathe([(0.3, 0), (0.32, 0.08), (0.22, 0.14), (0.16, 0.4), (0.24, 0.48), (0.42, 0.62), (0.5, 0.82), (0.55, 0.9), (0.48, 0.92), (0, 0.85)], 14),
          STONE, "pearl")
    p.add(torus(0.53, 0.025, 14, 4), GOLD, "gold", T(0, 0, 0.9))
    leaves_mass(p, 0, 0, 1.0, 0.5, SAGE, rng, 5, 1, 0.7)
    for i in range(12):
        a = 2 * math.pi * i / 12 + rng.uniform(-0.2, 0.2)
        rosette(p, (0.42 * math.cos(a), 0.42 * math.sin(a), 1.08 + rng.uniform(-0.05, 0.12)), 0.1, ROSE_MIX[i % 5],
                R("Z", math.degrees(a)) @ R("Y", 50), rng)
    for i in range(4):
        rosette(p, (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 1.32), 0.11, [ROSE, BLUSH, LILAC, WHITE][i], None, rng)
    for i in range(7):   # trailing sprays spilling over the lip
        a = 2 * math.pi * i / 7 + 0.2
        pts = [(0.52 * math.cos(a), 0.52 * math.sin(a), 0.92), (0.62 * math.cos(a), 0.62 * math.sin(a), 0.7), (0.6 * math.cos(a), 0.6 * math.sin(a), 0.42)]
        p.add(tube(pts, [0.03, 0.025, 0.015], 4), SAGE_DEEP, "leaf")
        for x, y, z in pts[1:]:
            p.add(ico(0.06, 0), SAGE, "leaf", T(x, y, z))
            p.add(ico(0.045, 0), [LILAC, (0.98, 0.62, 0.78), PERI][i % 3], "fabric", T(x * 1.05, y * 1.05, z - 0.04))


def obelisk_sweetpea(p, size, c):
    """A painted tuteur (garden obelisk) climbed by pastel sweet peas."""
    rng = random.Random(4848)
    h = 2.4
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        p.add(tube([(0.42 * math.cos(a), 0.42 * math.sin(a), 0), (0.05 * math.cos(a), 0.05 * math.sin(a), h - 0.2)], 0.03, 4), IRON_WHITE, "pearl")
    for z, rr in ((0.5, 0.34), (1.1, 0.25), (1.7, 0.15)):
        p.add(torus(rr, 0.02, 8, 3), GOLD, "gold", T(0, 0, z) @ R("Z", 45))
    p.add(ico(0.08, 1), GOLD, "gold", T(0, 0, h - 0.1))
    for i in range(29):
        t = rng.uniform(0.05, 0.9)
        a = rng.uniform(0, 2 * math.pi)
        rr = 0.44 * (1 - t) + 0.08
        x, y, z = rr * math.cos(a), rr * math.sin(a), t * (h - 0.3)
        p.add(ico(0.07, 0), SAGE if i % 2 else SAGE_DEEP, "leaf", T(x, y, z))
        if i % 2 == 0:
            col = SWEETPEA[i % 5]
            p.add(petal(0.09, 0.1, cup=0.5), col, "fabric", T(x * 1.15, y * 1.15, z + 0.03) @ R("Z", math.degrees(a)) @ R("Y", -70))
            p.add(petal(0.07, 0.07, cup=0.4), lighter(col, 0.15), "fabric", T(x * 1.15, y * 1.15, z + 0.01) @ R("Z", math.degrees(a) + 30) @ R("Y", -20))


def dovecote(p, size, c):
    """A pole dovecote: lilac-roofed octagonal house on a stone post, with doves."""
    p.add(lathe([(0.25, 0), (0.25, 0.2), (0.12, 0.3), (0.1, 2.3), (0.3, 2.45)], 8), STONE, "pearl")
    p.add(lathe([(0.0, 2.45), (0.75, 2.45), (0.75, 3.2), (0.0, 3.2)], 8), (0.98, 0.92, 0.90), "satin")
    for k in range(8):
        a = 2 * math.pi * k / 8
        for z in (2.6, 2.95):
            p.add(lathe([(0.0, 0), (0.1, 0.0), (0.1, 0.12), (0.0, 0.18)], 6), (0.42, 0.34, 0.40), "matte",
                  T(0.73 * math.cos(a), 0.73 * math.sin(a), z) @ R("Z", math.degrees(a)) @ R("Y", 90))
    p.add(lathe([(0.95, 3.15), (0.95, 3.25), (0.45, 3.65), (0.1, 3.95), (0.0, 4.0)], 8), mix(LILAC, PERI, 0.3), "satin")
    p.add(ico(0.07, 1), GOLD, "gold", T(0, 0, 4.02))
    for k in (0, 3, 5):
        a = 2 * math.pi * k / 8 + 0.2
        x, y = 0.95 * math.cos(a), 0.95 * math.sin(a)
        p.add(ico(0.08, 1), (0.98, 0.97, 0.98), "pearl", T(x, y, 3.27) @ S(0.8, 1.3, 0.8))
        p.add(ico(0.05, 1), (0.98, 0.97, 0.98), "pearl", T(x * 1.03, y * 1.03, 3.36))


def bench_curved(p, size, c):
    """A curved marble exedra bench with scroll ends (follows a circle)."""
    pts_in, R0 = [], 6.0
    seat = []
    for i in range(9):
        a = math.radians(-18 + 36 * i / 8)
        seat.append((R0 * math.sin(a), R0 - R0 * math.cos(a)))
    for i in range(len(seat) - 1):
        (x0, y0), (x1, y1) = seat[i], seat[i + 1]
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
        seglen = math.hypot(x1 - x0, y1 - y0) + 0.03
        p.add(box(seglen, 0.5, 0.1, bevel=0.03), STONE, "pearl", T(mx, my, 0.46) @ R("Z", ang))
        p.add(box(seglen, 0.1, 0.5, bevel=0.03), STONE, "pearl", T(mx, my + 0.28, 0.8) @ R("Z", ang))
    for i in (0, 4, 8):
        x, y = seat[i]
        p.add(lathe([(0.2, 0), (0.12, 0.1), (0.1, 0.35), (0.18, 0.42)], 8), STONE_SHADE, "pearl", T(x, y, 0))
    for i in (0, 8):
        x, y = seat[i]
        p.add(torus(0.14, 0.05, 10, 5), STONE, "pearl", T(x, y + 0.05, 0.62) @ R("Z", 90) @ R("X", 90))
        p.add(ico(0.05, 1), GOLD, "gold", T(x, y + 0.05, 0.62))


def faelight_lantern(p, size, c):
    """A shepherd's-crook post with a glass lantern holding a faelight (glows at
    dusk; canon:X) and a tie of ribbon."""
    p.add(tube([(0, 0, 0), (0, 0, 1.75), (0.08, 0, 1.92), (0.25, 0, 1.95), (0.36, 0, 1.85)], [0.03, 0.025, 0.022, 0.02, 0.018], 5), GOLD, "gold")
    p.add(lathe([(0.0, 0), (0.1, 0.02), (0.11, 0.2), (0.07, 0.26), (0.0, 0.3)], 8), (0.95, 0.97, 1.0, 0.35), "glass", T(0.36, 0, 1.45))
    p.add(ico(0.075, 1), (1.0, 0.92, 0.7), "glow", T(0.36, 0, 1.57))
    p.add(lathe([(0.0, 0), (0.12, 0.0), (0.06, 0.08), (0.0, 0.1)], 8), GOLD, "gold", T(0.36, 0, 1.73))
    p.add(tube([(0.0, 0.03, 1.6), (-0.05, 0.06, 1.45), (0.02, 0.05, 1.3)], 0.012, 3), ROSE, "satin")


def armillary(p, size, c):
    """A gilt armillary sphere sundial on a stone column."""
    p.add(lathe([(0.32, 0), (0.32, 0.1), (0.2, 0.2), (0.15, 1.0), (0.24, 1.1), (0.24, 1.18)], 12), STONE, "pearl")
    for k in range(3):
        p.add(torus(0.38, 0.018, 20, 4), GOLD, "gold", T(0, 0, 1.6) @ R("X", 60 * k) @ R("Y", 30 * k))
    p.add(torus(0.38, 0.03, 20, 4), GOLD_D(), "gold", T(0, 0, 1.6))
    p.add(cyl(0.012, 1.0, 4), GOLD, "gold", T(0, 0, 1.1) @ R("X", 25))
    p.add(ico(0.06, 1), GOLD, "gold", T(0, 0, 1.6))


def GOLD_D():
    return darker(GOLD, 0.1)


def cupid_statue(p, size, c):
    """A little cupid on a fluted plinth (canon:X)."""
    p.add(lathe([(0.32, 0), (0.32, 0.12), (0.24, 0.2), (0.22, 0.9), (0.32, 1.0), (0.32, 1.06), (0, 1.06)], 12), STONE, "pearl")
    cz = 1.06
    skin = mix(STONE, BLUSH, 0.35)
    p.add(ico(0.2, 2), skin, "pearl", T(0, 0, cz + 0.32) @ S(0.9, 0.8, 1.1))
    p.add(ico(0.14, 2), skin, "pearl", T(0, 0.03, cz + 0.66))
    for sx in (-1, 1):
        p.add(tube([(sx * 0.08, 0, cz + 0.15), (sx * 0.12, 0.08, cz + 0.02)], 0.06, 5), skin, "pearl")
        p.add(leaf(0.4, 0.22), (0.98, 0.94, 0.96), "pearl", T(sx * 0.1, -0.14, cz + 0.45) @ R("Z", -90 - sx * 50) @ R("Y", -45))
        p.add(tube([(sx * 0.16, 0.02, cz + 0.45), (sx * 0.24, 0.12, cz + 0.6)], 0.035, 4), skin, "pearl")
    p.add(tube([(-0.2, 0.2, cz + 0.45), (0, 0.27, cz + 0.68), (0.2, 0.2, cz + 0.9)], 0.018, 4), GOLD, "gold")


BUILDERS = {k: v for k, v in dict(globals()).items() if callable(v) and k in {
    "heron_fountain", "lamb_statue", "alcove_niche", "wisteria_trellis", "rose_swag_bay", "rose_tunnel_arch",
    "rose_standard_pink", "rose_standard_white", "rose_standard_apricot", "wisteria_bay", "yew_hedge", "yew_hedge_arch",
    "box_edging", "topiary_cone", "topiary_spiral", "topiary_tiered", "topiary_ball", "topiary_lollipop", "topiary_heart_ribbon",
    "topiary_peacock", "birdcage_pavilion", "temple_of_love", "garden_swing", "urn_overflowing", "obelisk_sweetpea",
    "dovecote", "bench_curved", "faelight_lantern", "armillary", "cupid_statue"}}
