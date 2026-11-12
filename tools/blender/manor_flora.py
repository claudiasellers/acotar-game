"""Generates the Manor Estate plant models (headless Blender, deterministic).

Run:  /opt/bpyenv/bin/python tools/blender/manor_flora.py [--preview dir]
Out:  world/spring_court/manor_estate/flora/models/<species>.glb
      Nodes "<species>" and "<species>_lod1". Base at the origin,
      scaled uniformly to the species height in flora_lib.gd. Every surface is
      the "leaf" finish: colour lives in vertex colours so the game can draw
      each species with the shared stylized_foliage shader in one draw call.

Look (experience bar 2.2/2.7): oversized blooms, mint-sage foliage (never
lime), rose-taupe bark, one blossom hue per bed. Budgets: flowers <= 700 tris,
shrubs <= 2,000, trees <= 3,000 (scatter draws thousands of these).
"""

import math
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,I001
from mathutils import Vector, noise  # noqa: E402
import prop_kit as K  # noqa: E402
from prop_kit import (BARK, BUTTER, LEAF, LEAF_DARK, R, S, SAGE_DEEP, SAGE_LIGHT, SAGE_SHADOW, T, WHITE, bloom, ico, layered_rose, rose_bud,  # noqa: E402
                      leaf, lighter, lathe, mix, petal, sphere, star_flower, tube, cyl)

OUT = os.path.join(K.ROOT, "world/spring_court/manor_estate/flora/models")
F = "leaf"
# Triangle budgets per kind (R4 props <= 3k). Lane L61 raised "bush" from
# 1,200 to 2,000 so the rose bushes' petals (18-tri cupped, not 8-tri folded)
# hold up at 1 m; LOD1 stays ~50%.
BUDGET = {"flower": 700, "groundcover": 600, "aquatic": 600, "reed": 400, "bush": 2000, "climber": 1600, "tree": 3000}


def species():
    path = os.path.join(K.ROOT, "world/spring_court/manor_estate/flora/flora_lib.gd")
    out = {}
    for m in re.finditer(r'&"(\w+)": \[&"(\w+)", ([\d.]+), Color\(([^)]*)\)\]', open(path).read()):
        out[m.group(1)] = (m.group(2), float(m.group(3)), tuple(float(v) for v in m.group(4).split(",")))
    return out


def stem(p, a, b, r=0.01, col=LEAF_DARK, sides=3):
    p.add(tube([a, b], [r, r * 0.7], sides, caps=False), col, F)


def blob(p, x, y, z, r, col, rng, sub=1, squash=0.85, fine=0):
    """A foliage blob. fine=n (lane L61) is n icosphere levels finer with
    a smooth noise lump instead of per-vertex jitter (jitter on a fine mesh
    crinkles); it draws from `rng` exactly as the coarse blob did, so every
    later shape in the species stays where it was."""
    if not fine:
        b = ico(r, sub)
        for v in b.verts:
            v.co *= 1.0 + rng.uniform(-0.08, 0.08)
    else:
        coarse = ico(r, sub)
        n = len(coarse.verts)
        coarse.free()
        draws = [rng.uniform(-0.08, 0.08) for _ in range(n)]
        seed = Vector((draws[0], draws[1], draws[2])) * 400.0
        b = ico(r, sub + fine)
        for v in b.verts:
            v.co *= 1.0 + 0.1 * noise.noise(v.co.normalized() * 1.6 + seed)
    p.add(b, col, F, T(x, y, z) @ S(1, 1, squash), sharp_deg=89.0)


# ------------------------------------------------------------ shrubs


# a clipped cushion: (radius, height) fractions, broad shoulders, a soft flat crown
MASS_PROFILE = [(0.7, 0.0), (0.94, 0.18), (1.0, 0.4), (0.95, 0.6), (0.78, 0.8), (0.44, 0.95), (0.0, 1.0)]


def shrub_mass(p, cx, cy, rad, top, col, rng, sides=14, lobes=3, crown=None, bumps=0.0):
    """A rounded, clipped shrub mass (L35-8): a smooth dome of revolution, its
    rim gently lobed, so the bush reads as one soft clipped cushion rather than
    a heap of faceted balls."""
    prof = [(rad * p0, top * p1) for p0, p1 in MASS_PROFILE]
    b = lathe(prof, sides, cap_bottom=False)
    ph = rng.uniform(0, 2 * math.pi)
    for v in b.verts:
        a = math.atan2(v.co.y, v.co.x)
        k = 1.0 + 0.07 * math.cos(lobes * a + ph) + 0.035 * math.cos((lobes + 2) * a - ph) + rng.uniform(-0.015, 0.015)
        v.co.x *= k
        v.co.y *= k
        v.co.z *= 1.0 + 0.05 * math.cos(lobes * a + ph) * (1.0 - v.co.z / top)
    shade = None
    if crown is not None:
        # deeper toward the base, lighter on the sunlit crown, with a little
        # patchy variation so the clipped face is not one flat colour (L35-10)
        nr = random.Random(rng.random())
        ph2 = nr.uniform(0, 6.3)

        def shade(c):
            t = max(0.0, min(1.0, c.z / top))
            w = 0.5 + 0.5 * math.sin(7.0 * math.atan2(c.y, c.x) + 9.0 * t + ph2)
            return mix(mix(col, crown, t ** 1.4), crown if w > 0.5 else col, 0.12 * abs(w - 0.5) * 2)
    if bumps:
        # small clipped-leaf lumps on the face, so the silhouette breaks up
        for v in b.verts:
            a = math.atan2(v.co.y, v.co.x)
            k = 1.0 + bumps * (math.sin(9 * a + 5.0 * v.co.z / top + ph) * 0.6 + rng.uniform(-0.6, 0.6))
            v.co.x *= k
            v.co.y *= k
    p.add(b, col, F, T(cx, cy, 0), sharp_deg=89.0, shade=shade)


def _mass_point(rad, top, a, s):
    """A point on shrub_mass's profile at angle a and height fraction s (0..1),
    and the outward direction there."""
    for (r0, z0), (r1, z1) in zip(MASS_PROFILE, MASS_PROFILE[1:]):
        if z0 <= s <= z1:
            t = (s - z0) / max(z1 - z0, 1e-4)
            rr = rad * (r0 + (r1 - r0) * t)
            dz, dr = (z1 - z0) * top, (r1 - r0) * rad
            n = (dz, -dr)                       # outward normal in (r, z)
            ln = math.hypot(*n)
            return (rr * math.cos(a), rr * math.sin(a), s * top), (n[0] / ln, n[1] / ln)
    return (0.0, 0.0, top), (0.0, 1.0)


# a rose's own leaf: deeper and greener than the estate's mint sage (L35-10)
ROSE_LEAF_BASE = K.hexc("#3D7055")
ROSE_LEAF_TOP = K.hexc("#8CC390")


def rose_bush(p, h, col, rng):
    """Rounded, clipped rose shrub (L35-8, L35-10): one gently lobed cushion of
    deep rose-leaf green, darker at its foot and lighter on the crown, its face
    broken by small clipped lumps, and roses in clusters (an open head, a
    half-open one, buds) sunk into the foliage, a few standing proud of the
    outline. The blooms, not the leaves, carry the colour (rose garden 'dozens
    of hues', canon ch13). Within the 1,200-tri bush budget."""
    rad = h * rng.uniform(0.55, 0.65)
    top = h * 0.86
    shrub_mass(p, 0.0, 0.0, rad, top, ROSE_LEAF_BASE, rng, sides=20, crown=ROSE_LEAF_TOP, bumps=0.035)
    # twelve clusters on a golden spiral over the upper two thirds, half led by
    # an open rose and half by a half-open one, each with a bud (L56-2: smaller,
    # cupped heads and more of them; the old big open heads read as flat discs)
    heads = []
    n_clusters = 12
    for c in range(n_clusters):
        a = 2.39996 * c + rng.uniform(-0.15, 0.15)
        s = 0.3 + 0.62 * (c + 0.5) / n_clusters
        heads.append((a, s, "open" if c % 2 == 0 else "half"))
        heads.append((a + rng.choice((-1, 1)) * rng.uniform(0.12, 0.18), s + rng.uniform(-0.06, 0.04), "bud"))
    for i, (a, s, stage) in enumerate(heads):
        s = max(0.3, min(0.95, s))
        (x, y, z), (nr, nz) = _mass_point(rad, top, a, s)
        e = math.degrees(math.atan2(nz, nr))     # 0 = facing out sideways, 90 = up
        # most heads sit sunk into the leaves; every fourth stands proud of the outline
        proud = i % 4 == 1
        c = col if i % 3 else lighter(col, 0.18)
        rr = h * {"open": 0.135, "half": 0.12, "bud": 0.075}[stage] * rng.uniform(0.9, 1.1)
        sink = -0.1 if proud else 0.08
        nx, ny = math.cos(a) * nr, math.sin(a) * nr
        m = T(x - nx * rr * sink, y - ny * rr * sink, z - nz * rr * sink) @ R("Z", math.degrees(a)) \
            @ R("Y", 90 - e + rng.uniform(-12, 12))
        if stage == "bud":
            rose_bud(p, m, rr, c, F, rng, fine=True)
        else:
            layered_rose(p, m, rr, c, F, rng, inner=3, outer=4 if stage == "open" else 0, cupped=True, fine=True)


def cup_rose(p, center, radius, col, rng, tilt):
    """A rounded full rose (L35-4): smooth cupped head, swirled heart and
    broad outer petals (prop_kit.soft_rose), never a pointed shard."""
    K.soft_rose(p, T(*center) @ tilt, radius * 0.95, col, F, rng, petals=3)


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
    """A clump of peony (L35-8): a low, soft cushion of foliage carrying four
    big, ruffled, many-petalled heads, never faceted balls and flat discs."""
    rad = h * 0.55
    top = h * 0.62
    shrub_mass(p, 0.0, 0.0, rad, top, ROSE_LEAF_BASE, rng, sides=14, lobes=4,
               crown=mix(ROSE_LEAF_TOP, SAGE_LIGHT, 0.15), bumps=0.04)
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.4 + rng.uniform(-0.2, 0.2)
        (x, y, z), (nr, nz) = _mass_point(rad, top, a, rng.uniform(0.72, 0.86))
        e = math.degrees(math.atan2(nz, nr))
        rr = h * 0.21 * rng.uniform(0.9, 1.08)
        layered_rose(p, T(x * 0.9, y * 0.9, z + rr * 0.1) @ R("Z", math.degrees(a)) @ R("Y", (90 - e) * 0.6),
                     rr, col if i % 2 else lighter(col, 0.22), F, rng, inner=4, outer=6)


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


def meadow_grass(p, h, col, rng):
    """L56-3: a long-meadow tussock for the park's outer edges, past the mown
    lawns. Arching blades in warm olive and straw, a few seed heads nodding
    above (no mint: the grade lifts saturation)."""
    olive = (0.34, 0.40, 0.20)
    straw = (0.80, 0.74, 0.50)
    # a dense tussock: flat blades (4 tris each) fanning out from a tight base
    for i in range(44):
        a = 2.39996 * i + rng.uniform(-0.3, 0.3)
        up = rng.uniform(52, 84)            # degrees above the ground
        length = h * rng.uniform(0.6, 1.0) / max(math.sin(math.radians(up)), 0.5)
        r0 = 0.1 * h * math.sqrt(rng.random())
        c = col if i % 3 == 0 else (olive if i % 3 == 1 else mix(col, straw, 0.35))
        p.add(leaf(length, h * rng.uniform(0.05, 0.08)), c, F,
              T(r0 * math.cos(a), r0 * math.sin(a), 0) @ R("Z", math.degrees(a)) @ R("Y", -up) @ R("X", rng.uniform(-40, 40)))
    for i in range(5):
        a = 2 * math.pi * i / 5 + rng.uniform(-0.4, 0.4)
        m = R("Z", math.degrees(a)) @ R("Y", rng.uniform(4, 14))
        top = h * rng.uniform(0.9, 1.0)
        tip = m @ K.Vector((0, 0, top))
        p.add(tube([(0, 0, 0), tuple(m @ K.Vector((0, 0, top * 0.6))), tuple(tip)], [0.006, 0.005, 0.004], 3, caps=False), mix(olive, straw, 0.5), F)
        p.add(cyl(0.016, top * 0.16, 5), straw, F, T(*tip) @ m @ R("Y", 160))


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
    # Lane L61: crown blobs were 20-face icosahedrons (read as crystals). They
    # go two levels finer (320 faces) when the species' blobs fit the tree
    # budget that way, else one (80).
    blobs = {"willow": 5, "oak": 13}.get(kind, (7 if kind == "oak" else 6) + 1)
    fine = 2 if blobs * 320 + 700 <= BUDGET["tree"] else 1
    if kind == "willow":
        for i in range(5):
            a = 2 * math.pi * i / 5
            blob(p, lean + h * 0.15 * math.cos(a), h * 0.15 * math.sin(a), trunk_h + h * 0.25, h * 0.17, col if i % 2 else SAGE_LIGHT, rng, 1, 0.7,
                 fine=fine)
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
        blob(p, x, y, z, h * spread * 0.62, c, rng, 1, 0.8, fine=fine)
    blob(p, crown_c[0], 0, crown_c[2] + h * spread * 0.35, h * spread * 0.75, lighter(col, 0.08), rng, 1, 0.8, fine=fine)
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
                # smooth puffs of blossom (lane L61; a 20-tri icosahedron read as a crystal)
                p.add(sphere(h * 0.045, 6, 4), WHITE if i % 3 == 0 else lighter(col, 0.2), F, T(x, y, z))
    if kind == "oak":
        for i in range(5):
            a = 2 * math.pi * i / 5 + 0.3
            blob(p, lean + h * 0.42 * math.cos(a), h * 0.42 * math.sin(a), crown_c[2] - h * 0.04, h * 0.14, mix(col, SAGE_DEEP, 0.3), rng, 1, 0.75,
                 fine=fine)


# ------------------------------------------------------------ tree builds (wider-court D2)
#
# The estate keeps its cotton-candy trees (owner, 2026-11-12: "i love the
# cotton candy honestly i just want to refine them"). Build 0 is tree() above,
# unchanged; builds 1 and 2 are the same puffed crowns grown to a different
# habit, so neighbours stop being clones: an upright crown and a spreading,
# leaning one, a forked trunk on some, the crown thrown to one side on others.
# Exported as <species>_b<n>.glb; FloraLib.mesh(species, build) loads them and
# the scatter hands neighbours different builds (ManorScatter.tree_builds).
TREE_BUILDS = 3
# family -> build -> habit. spread/tall scale the crown's width and height,
# trunk the clear stem, lean tips the trunk (fraction of height), skew throws
# the crown along the lean, fork splits the trunk into two leaders, skirt is
# the oak's low ring of blobs (count, radius as a fraction of height).
HABITS = {
    "blossom": {1: dict(spread=0.9, tall=1.5, trunk=1.0, lean=0.03, skew=0.0, fork=True, skirt=0, tint=0.12),
                2: dict(spread=1.18, tall=0.6, trunk=0.8, lean=0.08, skew=0.2, fork=False, skirt=0, tint=-0.14)},
    "oak": {1: dict(spread=0.86, tall=1.6, trunk=1.12, lean=0.02, skew=0.0, fork=False, skirt=3, tint=0.1),
            2: dict(spread=1.04, tall=0.75, trunk=0.85, lean=0.06, skew=0.16, fork=True, skirt=6, tint=-0.1)},
    "birch": {1: dict(spread=0.92, tall=2.6, trunk=0.72, lean=0.02, skew=0.0, fork=False, skirt=0, tint=0.1),
              2: dict(spread=1.0, tall=1.9, trunk=0.8, lean=0.11, skew=0.3, fork=False, skirt=0, tint=-0.1)},
    "pear_tree": {1: dict(spread=0.78, tall=2.0, trunk=1.0, lean=0.02, skew=0.0, fork=False, skirt=0, tint=0.1),
                  2: dict(spread=1.15, tall=0.8, trunk=0.9, lean=0.06, skew=0.14, fork=True, skirt=0, tint=-0.1)},
}
# a build's colour drifts a little: tint > 0 deeper (blossom) or cooler (leaf), < 0 paler or warmer
BLOSSOM_DEEP = {"cherry_blossom": (0.97, 0.6, 0.78), "apple_blossom": (1.0, 0.8, 0.86), "crab_apple": (1.0, 0.84, 0.9)}
LEAF_WARM = (0.66, 0.84, 0.48)


def build_tint(col, kind, t, blossom):
    if t > 0:
        return mix(col, BLOSSOM_DEEP.get(kind, col), t * 2.5) if blossom else mix(col, SAGE_DEEP, t)
    return mix(col, WHITE, -t * 1.5) if blossom else mix(col, LEAF_WARM, -t * 1.5)


def tree_build(p, h, col, rng, kind, v):
    """Build v (1, 2) of an estate tree: tree()'s look, another habit."""
    if kind == "willow":
        willow_build(p, h, col, rng, v)
        return
    blossom = kind in ("cherry_blossom", "apple_blossom", "crab_apple")
    hb = HABITS["blossom" if blossom else kind][v]
    col = build_tint(col, kind, hb["tint"], blossom)
    bark = (0.95, 0.93, 0.9) if kind == "birch" else BARK
    trunk_h = h * {"oak": 0.35, "birch": 0.5}.get(kind, 0.38) * hb["trunk"]
    la = rng.uniform(0, 2 * math.pi)
    ld = Vector((math.cos(la), math.sin(la), 0.0))
    side = Vector((-ld.y, ld.x, 0.0))
    lean = ld * (hb["lean"] * h)
    spread = {"oak": 0.32, "birch": 0.17, "pear_tree": 0.2}.get(kind, 0.26) * hb["spread"]
    top = Vector((lean.x, lean.y, trunk_h * 1.1))
    # the trunk bows with the lean (a soft S on the leaning birch)
    mid = Vector((lean.x * 0.35, lean.y * 0.35, trunk_h * 0.55)) - side * (h * 0.012 if kind == "birch" else 0.0)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        p.add(tube([(0, 0, 0.0), (h * 0.04 * math.cos(a), h * 0.04 * math.sin(a), -h * 0.01)], [h * 0.025, h * 0.01], 4), bark, F)
    crown_z = trunk_h + h * 0.28
    centre = Vector((lean.x, lean.y, crown_z)) + ld * (hb["skew"] * h * spread)
    if hb["fork"]:
        fork = Vector((lean.x * 0.6, lean.y * 0.6, trunk_h * 0.62))
        p.add(tube([(0, 0, 0), tuple(mid * 0.9), tuple(fork)], [h * 0.035, h * 0.028, h * 0.022], 7), bark, F)
        heads = [centre + side * (h * spread * 0.42), centre - side * (h * spread * 0.38)]
        for hd in heads:
            tip = Vector((hd.x, hd.y, max(trunk_h * 1.05, hd.z - h * spread * 0.25)))
            p.add(tube([tuple(fork), tuple(fork.lerp(tip, 0.55) + Vector((0, 0, h * 0.02))), tuple(tip)], [h * 0.02, h * 0.016, h * 0.012], 6), bark, F)
    else:
        p.add(tube([(0, 0, 0), tuple(mid), tuple(top)], [h * 0.035, h * 0.025, h * 0.018], 7), bark, F)
        heads = [centre]
    n = 7 if kind == "oak" else 6
    blobs = n + 1 + hb["skirt"] + (5 if kind == "oak" and not hb["skirt"] else 0)
    fine = 2 if blobs * 320 + 700 <= BUDGET["tree"] else 1
    base = Vector((top.x * 0.9, top.y * 0.9, trunk_h * 0.95))
    for i in range(n):
        hd = heads[i % len(heads)]
        a = 2 * math.pi * i / n + rng.uniform(-0.3, 0.3)
        # stacked through the crown's height: low blobs wide, high ones in
        t = (i + rng.uniform(0.1, 0.9)) / n
        rr = h * spread * 0.75 * (1.0 - 0.25 * max(0.0, t - 0.45) * hb["tall"]) * rng.uniform(0.88, 1.08)
        z = hd.z + (t - 0.3) * h * spread * 1.05 * hb["tall"] - h * 0.03
        x, y = hd.x + rr * math.cos(a), hd.y + rr * math.sin(a)
        b0 = base if not hb["fork"] else Vector((hd.x, hd.y, max(trunk_h * 1.05, hd.z - h * spread * 0.25)))
        p.add(tube([tuple(b0), (x * 0.8 + b0.x * 0.2, y * 0.8 + b0.y * 0.2, z - h * 0.05)], [h * 0.015, h * 0.008], 4), bark, F)
        c = col if i % 2 else (lighter(col, 0.15) if blossom else mix(col, SAGE_DEEP, 0.35))
        r = h * spread * 0.62 * rng.uniform(0.85, 1.15) * (1.0 + 0.1 * abs(1.0 - hb["tall"]))
        blob(p, x, y, z, r, c, rng, 1, 0.8 if hb["tall"] >= 1.0 else 0.72, fine=fine)
    # a core puff (one level coarser, mostly hidden) keeps the stretched
    # crowns one soft mass instead of separate balls
    for hd in heads:
        blob(p, hd.x, hd.y, hd.z + h * spread * 0.4 * max(0.0, hb["tall"] - 1.0), h * spread * 0.72 / len(heads) ** 0.3, mix(col, SAGE_DEEP, 0.2) if not blossom else col,
             rng, 1, 0.8 * hb["tall"], fine=1)
    crown_top = centre.z + h * spread * (0.35 + 0.75 * max(0.0, hb["tall"] - 1.0))
    blob(p, centre.x, centre.y, crown_top, h * spread * 0.75, lighter(col, 0.08), rng, 1, 0.8, fine=fine)
    if blossom or kind == "pear_tree":
        for i in range(16 - 3 * len(heads)):
            a = rng.uniform(0, 2 * math.pi)
            e = rng.uniform(-0.2, 1.2)
            r = h * spread * 1.05
            x, y = centre.x + r * math.cos(a) * math.cos(e), centre.y + r * math.sin(a) * math.cos(e)
            z = centre.z + r * 0.75 * math.sin(e) * (0.6 + 0.4 * hb["tall"])
            if kind == "pear_tree":
                p.add(lathe([(0, 0), (h * 0.02, h * 0.012), (h * 0.012, h * 0.035), (0, h * 0.045)], 6), (0.85, 0.92, 0.5), F, T(x, y, z - h * 0.05))
            else:
                p.add(sphere(h * 0.045, 6, 4), WHITE if i % 3 == 0 else lighter(col, 0.2), F, T(x, y, z))
    skirt = hb["skirt"] or (5 if kind == "oak" else 0)
    for i in range(skirt):
        a = 2 * math.pi * i / skirt + 0.3 + rng.uniform(-0.25, 0.25)
        rr = h * (0.42 if skirt <= 5 else 0.46) * hb["spread"]
        blob(p, centre.x + rr * math.cos(a), centre.y + rr * math.sin(a), centre.z - h * 0.04 - h * 0.02 * (i % 2), h * 0.14 * rng.uniform(0.85, 1.15),
             mix(col, SAGE_DEEP, 0.3), rng, 1, 0.75, fine=fine)


def willow_build(p, h, col, rng, v):
    """Willow builds: 1 a broad dome with a fuller curtain, 2 a leaning bank
    willow, lopsided, its curtain reaching further down on the low side."""
    trunk_h = h * (0.42 if v == 1 else 0.34)
    la = rng.uniform(0, 2 * math.pi)
    ld = Vector((math.cos(la), math.sin(la), 0.0))
    lean = ld * (h * (0.03 if v == 1 else 0.12))
    p.add(tube([(0, 0, 0), (lean.x * 0.4, lean.y * 0.4, trunk_h * 0.6), (lean.x, lean.y, trunk_h * 1.1)], [h * 0.038, h * 0.027, h * 0.019], 7), BARK, F)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        p.add(tube([(0, 0, 0.0), (h * 0.04 * math.cos(a), h * 0.04 * math.sin(a), -h * 0.01)], [h * 0.025, h * 0.01], 4), BARK, F)
    nb = 6 if v == 1 else 5
    fine = 2 if nb * 320 + 700 + 22 * 12 <= BUDGET["tree"] else 1
    ring = h * (0.18 if v == 1 else 0.15)
    centre = Vector((lean.x, lean.y, trunk_h + h * 0.25)) + ld * (h * 0.05 * (v - 1))
    for i in range(nb):
        a = 2 * math.pi * i / nb + rng.uniform(-0.2, 0.2)
        rr = ring * (1.25 if v == 2 and math.cos(a - la) > 0.3 else 1.0)
        blob(p, centre.x + rr * math.cos(a), centre.y + rr * math.sin(a), centre.z + rng.uniform(-0.03, 0.03) * h, h * 0.17 * rng.uniform(0.9, 1.1),
             col if i % 2 else SAGE_LIGHT, rng, 1, 0.7 if v == 1 else 0.75, fine=fine)
    nc = 22 if v == 1 else 18
    for i in range(nc):
        a = 2 * math.pi * i / nc + rng.uniform(-0.05, 0.05)
        low = math.cos(a - la)   # 1 on the side the tree leans to
        r0 = h * (0.25 if v == 1 else 0.22) * (1.0 + (0.2 * low if v == 2 else 0.0))
        foot = h * (0.1 if v == 1 else max(0.02, 0.1 - 0.08 * low))
        cx, cy = centre.x, centre.y
        pts = [(cx + r0 * math.cos(a), cy + r0 * math.sin(a), centre.z + h * 0.05),
               (cx + r0 * 1.35 * math.cos(a), cy + r0 * 1.35 * math.sin(a), centre.z - h * 0.15),
               (cx + r0 * 1.5 * math.cos(a), cy + r0 * 1.5 * math.sin(a), foot)]
        p.add(tube(pts, [h * 0.03, h * 0.025, h * 0.008], 3, caps=False), col if i % 2 else SAGE_LIGHT, F)


# ------------------------------------------------------------ garden flowers (L35)


def snowdrop(p, h, col, rng):
    """[C] front garden: pale snowdrops, nodding white bells on arched stems."""
    clump_leaves(p, h, 5, rng, length=0.8)
    for i in range(5):
        a = 2 * math.pi * i / 5 + rng.uniform(-0.3, 0.3)
        top = h * rng.uniform(0.8, 1.0)
        bx, by = 0.02 * math.cos(a), 0.02 * math.sin(a)
        tip = (bx + h * 0.22 * math.cos(a), by + h * 0.22 * math.sin(a), top * 0.88)
        p.add(tube([(bx, by, 0), (bx * 2, by * 2, top * 0.8), (bx + h * 0.12 * math.cos(a), by + h * 0.12 * math.sin(a), top),
                    tip], h * 0.02, 3, caps=False), LEAF_DARK, F)
        m = T(*tip) @ R("Z", math.degrees(a)) @ R("Y", 160)
        for k in range(3):
            p.add(petal(h * 0.2, h * 0.12, cup=0.6, curl=0.2), col, F, m @ R("Z", 120 * k) @ R("Y", -70))
        p.add(ico(h * 0.05, 0), (0.7, 0.9, 0.7), F, m @ T(0, 0, h * 0.03))


def daffodil(p, h, col, rng):
    """[C] front garden: butter-yellow daffodils, a trumpet in a star of petals."""
    clump_leaves(p, h, 6, rng, length=0.8)
    for i in range(4):
        a = 2 * math.pi * i / 4 + rng.uniform(-0.3, 0.3)
        top = h * rng.uniform(0.85, 1.0)
        x, y = h * 0.12 * math.cos(a), h * 0.12 * math.sin(a)
        stem(p, (0, 0, 0), (x, y, top), h * 0.02)
        m = T(x, y, top) @ R("Z", math.degrees(a)) @ R("Y", 70)
        for k in range(6):
            p.add(petal(h * 0.16, h * 0.1, cup=0.1, curl=-0.05), lighter(col, 0.25) if i % 2 else col, F, m @ R("Z", 60 * k))
        p.add(lathe([(h * 0.03, 0), (h * 0.045, h * 0.08), (h * 0.07, h * 0.13), (h * 0.06, h * 0.135)], 7, cap_bottom=True, cap_top=False),
              (1.0, 0.70, 0.30) if i % 2 == 0 else col, F, m)


def meadow_buttercup(p, h, col, rng):
    """[C] ch8: lanky meadow buttercups, glossy yellow cups held high on thin
    branching stems over a low tuft of cut leaves."""
    clump_leaves(p, h * 0.35, 5, rng, length=0.6)
    for i in range(9):
        a = 2.39996 * i + rng.uniform(-0.2, 0.2)
        top = h * rng.uniform(0.7, 1.0)
        rr = h * rng.uniform(0.08, 0.3)
        x, y = rr * math.cos(a), rr * math.sin(a)
        stem(p, (0, 0, 0), (x, y, top), h * 0.012)
        m = T(x, y, top) @ R("Z", math.degrees(a)) @ R("Y", rng.uniform(15, 40))
        for k in range(5):
            p.add(petal(h * 0.1, h * 0.09, cup=0.5, curl=0.1), col if k % 2 else lighter(col, 0.12), F, m @ R("Z", 72 * k) @ R("Y", -40))


def hydrangea(p, h, col, rng):
    """Mophead hydrangea: round heads of tiny florets over broad leaves (canon:X outdoors)."""
    r = h * 0.48
    for i in range(5):
        a = 2 * math.pi * i / 5
        blob(p, r * 0.55 * math.cos(a), r * 0.55 * math.sin(a), h * 0.35, r * 0.5, LEAF if i % 2 else LEAF_DARK, rng, 0, 0.8)
    for i in range(7):
        a = 2.39996 * i
        e = math.asin(min(0.95, 0.05 + 0.9 * (i + 0.5) / 7))
        x, y, z = r * 0.75 * math.cos(a) * math.cos(e), r * 0.75 * math.sin(a) * math.cos(e), h * 0.55 + r * 0.6 * math.sin(e)
        c = col if i % 3 else mix(col, (1.0, 0.85, 0.95), 0.35)
        hr = h * 0.17
        blob(p, x, y, z, hr, c, rng, 1, 0.9)
        for k in range(3):
            b = 2 * math.pi * k / 3 + i
            p.add(ico(hr * 0.3, 0), lighter(c, 0.2), F, T(x + hr * 0.7 * math.cos(b), y + hr * 0.7 * math.sin(b), z + hr * 0.55))


def tall_spire(p, h, col, rng, n=3, florets=9, w=0.06):
    """Delphinium / lupin: a few dense tapering spires of florets."""
    clump_leaves(p, h, 6, rng, length=0.35)
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.3, 0.3)
        lean = rng.uniform(3, 10)
        top = h * rng.uniform(0.85, 1.0)
        m = R("Z", math.degrees(a)) @ R("Y", lean)
        stem(p, (0, 0, 0), tuple(m @ K.Vector((0, 0, top))), h * 0.012)
        for j in range(florets):
            t = 0.42 + 0.56 * j / florets
            pos = m @ K.Vector((0, 0, top * t))
            rr = h * w * (1.25 - t)
            c = col if j % 2 else lighter(col, 0.18)
            p.add(ico(rr, 0), c, F, T(pos.x, pos.y, pos.z) @ R("Z", j * 40) @ S(1, 1, 1.3))


def hollyhock(p, h, col, rng):
    """Cottage-garden hollyhocks: tall stems stacked with open saucer flowers."""
    clump_leaves(p, h, 5, rng, length=0.2)
    for i in range(2):
        a = math.pi * i + rng.uniform(-0.3, 0.3)
        top = h * rng.uniform(0.85, 1.0)
        m = R("Z", math.degrees(a)) @ R("Y", rng.uniform(3, 8))
        stem(p, (0, 0, 0), tuple(m @ K.Vector((0, 0, top))), h * 0.01)
        c = col if i != 1 else mix(col, (1.0, 0.95, 0.85), 0.5)
        for j in range(4):
            t = 0.45 + 0.14 * j
            pos = m @ K.Vector((0, 0, top * t))
            b = j * 2.3 + a
            star_flower(p, (pos.x + 0.05 * math.cos(b), pos.y + 0.05 * math.sin(b), pos.z), h * (0.085 - 0.01 * j), c, 5, F, (1.0, 0.95, 0.7),
                        R("Z", math.degrees(b)) @ R("Y", 80))


def allium(p, h, col, rng):
    """Allium: lollipop globes of star florets on bare stems."""
    clump_leaves(p, h, 4, rng, length=0.25)
    for i in range(3):
        a = 2 * math.pi * i / 3 + rng.uniform(-0.3, 0.3)
        top = h * rng.uniform(0.75, 1.0)
        x, y = h * 0.08 * math.cos(a), h * 0.08 * math.sin(a)
        stem(p, (0, 0, 0), (x, y, top), h * 0.012)
        p.add(ico(h * 0.1, 1), col, F, T(x, y, top))
        for k in range(8):
            b = 2.39996 * k
            e = math.asin(-0.6 + 1.5 * (k + 0.5) / 8)
            q = (x + h * 0.11 * math.cos(b) * math.cos(e), y + h * 0.11 * math.sin(b) * math.cos(e), top + h * 0.11 * math.sin(e))
            p.add(ico(h * 0.025, 0), lighter(col, 0.25), F, T(*q))


# ------------------------------------------------------------ table


def build_species(sid, kind, h, col, rng, v=0):
    p = K.Prop(sid if not v else f"{sid}_b{v}")
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
    elif sid == "snowdrop":
        snowdrop(p, h, c, rng)
    elif sid == "daffodil":
        daffodil(p, h, c, rng)
    elif sid == "meadow_buttercup":
        meadow_buttercup(p, h, c, rng)
    elif sid.startswith("hydrangea"):
        hydrangea(p, h, c, rng)
    elif sid == "delphinium":
        tall_spire(p, h, c, rng, 3, 10, 0.06)
    elif sid == "lupin":
        tall_spire(p, h, c, rng, 3, 9, 0.07)
    elif sid == "hollyhock":
        hollyhock(p, h, c, rng)
    elif sid == "allium":
        allium(p, h, c, rng)
    elif sid == "catmint":
        spike_flower(p, h, c, rng, 5)
    elif sid == "foxglove_white":
        spike_flower(p, h, c, rng, 3, bells=True)
    elif sid == "peony_white":
        peony(p, h, c, rng)
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
    elif sid == "meadow_grass":
        meadow_grass(p, h, c, rng)
    elif sid == "reed":
        reed(p, h, mix(c, SAGE_DEEP, 0.3), rng)
    elif sid == "water_lily":
        water_lily(p, h, c, rng)
    elif kind == "tree":
        foliage = c if sid in ("cherry_blossom", "apple_blossom", "crab_apple") else mix(c, (0.49, 0.76, 0.6), 0.6)   # pull toward sage
        if v:
            tree_build(p, h, foliage, rng, sid, v)
        else:
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
    only = set(args[args.index("--only") + 1].split(",")) if "--only" in args else None
    K.reset()
    objs, over = [], []
    for sid, (kind, h, col) in sorted(species().items()):
        if only is not None and sid not in only:
            continue
        for v in range(TREE_BUILDS if kind == "tree" else 1):
            name = sid if not v else f"{sid}_b{v}"
            rng = random.Random(sum(map(ord, sid)) + 7919 * v)
            p = build_species(sid, kind, h, col, rng, v)
            ob = p.to_object(name)
            n0 = K.mesh_tris(ob)
            lo = K.lod(ob, 0.5)
            lo.name = name + "_lod1"
            print(f"  {name:20s} {kind:11s} {n0:5d} tris  lod1 {K.mesh_tris(lo):5d}")
            if n0 > BUDGET[kind]:
                over.append((name, n0))
            objs += [ob, lo]
            if not prev:
                K.export_glb([ob, lo], os.path.join(OUT, f"{name}.glb"))
    if prev:
        import manor_props
        for o in objs:
            if o.name.endswith("_lod1"):
                o.hide_render = True
        shown = [o for o in objs if not o.name.endswith("_lod1")]
        manor_props.preview(shown, os.path.join(prev, "flora.png"), TREE_BUILDS * 3 if len(shown) % TREE_BUILDS == 0 and only else 7)
    print(f"{len(objs) // 2} species; over budget: {over}")
    if over:
        sys.exit(1)


if __name__ == "__main__":
    main()
