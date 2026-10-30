"""Spring Court woods trees as Blender models (headless bpy, deterministic).

Run:  <venv with `pip install bpy`>/bin/python tools/woods/blender/woods_trees.py [out_dir]
Out:  world/spring_court/shared/models/<species>.glb, one file per species
      with two mesh objects: "near" (full detail) and "far" (impostor-range
      LOD). FloraLibrary loads them in place of its procedural builders.

Vertex conventions match woods_foliage.gdshader: COLOR_0 is albedo in sRGB
(written raw, no conversion), UV0.x is wind flex (0 at the root), UV0.y is
glow. One material slot, so each mesh is one surface (one draw call).

Look (engineering rule R3): soft, rounded storybook trees in candy pastels,
lumpy cloud canopies, oversized blossom. The two horror trees (twisted_dead
for the Bogge's wood, blighted_tree for the blight) stay black and grey and
leafless or ashen; they are never softened.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector, noise

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(__file__), "..", "..", "..", "world", "spring_court", "shared", "models")

# Palette (sRGB): experience-bar.md §2.2. No lime anywhere in the court.
def hexc(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


ROSE = hexc("F4A6C0")
BLUSH = hexc("FAD4DC")
LILAC = hexc("C8A8E9")
PERIWINKLE = hexc("A7B5F2")
BUTTER = hexc("FCE9A6")
CREAM = hexc("FBF7F2")  # pearl
GOLD = hexc("F2D27A")
LEAF_GOLD = hexc("B5E3C0")  # light mint-sage
LEAF = hexc("7CC29A")       # mid
LEAF_DEEP = hexc("4F9A82")  # deep
TEAL = hexc("3E6F78")       # shadow teal: undersides, yew
FAWN = hexc("C9A98A")
BARK = hexc("8E6A6E")       # rose-taupe
BARK_DARK = tuple(x * 0.72 for x in BARK)
BARK_GREY = (0.78, 0.74, 0.76)  # beech: pearl-taupe
MOSS = hexc("8DBF7A")
# Horror (§2.2): never softened.
ROT = hexc("0E1612")
BOG = hexc("1F2B22")
BRUISE = hexc("3B2340")
LICHEN = hexc("9AA36A")
BLIGHT = hexc("5A4F5E")
DEAD = ROT
GREY_LEAF = BLIGHT


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def shade(c, f):
    return tuple(max(0.0, min(1.0, x * f)) for x in c)


class Kit:
    """Accumulates triangles with per-corner colour and (flex, glow) UVs."""

    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.verts = []
        self.faces = []
        self.colors = []  # per face: three colours
        self.uvs = []     # per face: three (flex, glow)

    def tri_count(self):
        return len(self.faces)

    def add_vert(self, p):
        self.verts.append(Vector(p))
        return len(self.verts) - 1

    def face(self, idx, cols, uvs):
        self.faces.append(tuple(idx))
        self.colors.append(tuple(cols))
        self.uvs.append(tuple(uvs))

    def tube(self, points, radii, sides, col0, col1, flex0=0.0, flex1=0.0, flare=0.0):
        """A tapered tube along a polyline. Colours and flex run root to tip."""
        rings = []
        n = len(points)
        for i, p in enumerate(points):
            p = Vector(p)
            d = (Vector(points[min(i + 1, n - 1)]) - Vector(points[max(i - 1, 0)])).normalized()
            side = d.orthogonal().normalized()
            up = d.cross(side).normalized()
            ring = []
            for s in range(sides):
                a = math.tau * s / sides
                r = radii[i]
                if i == 0 and flare > 0.0:
                    r *= 1.0 + flare * (0.6 + 0.4 * math.sin(a * 3.0 + self.rng.random()))
                ring.append(self.add_vert(p + (side * math.cos(a) + up * math.sin(a)) * r))
            rings.append(ring)
        for i in range(n - 1):
            t0, t1 = i / (n - 1), (i + 1) / (n - 1)
            c0, c1 = mix(col0, col1, t0), mix(col0, col1, t1)
            f0, f1 = flex0 + (flex1 - flex0) * t0, flex0 + (flex1 - flex0) * t1
            for s in range(sides):
                a, b = rings[i][s], rings[i][(s + 1) % sides]
                c, d = rings[i + 1][(s + 1) % sides], rings[i + 1][s]
                # Bark streaks: every other column a touch darker.
                k = 0.92 if s % 2 else 1.0
                self.face((a, b, c), (shade(c0, k), shade(c0, k), shade(c1, k)), ((f0, 0), (f0, 0), (f1, 0)))
                self.face((a, c, d), (shade(c0, k), shade(c1, k), shade(c1, k)), ((f0, 0), (f1, 0), (f1, 0)))
        # Cap the tip so branches never show a hole.
        tip = self.add_vert(points[-1])
        for s in range(sides):
            a, b = rings[-1][s], rings[-1][(s + 1) % sides]
            self.face((a, b, tip), (col1, col1, col1), ((flex1, 0), (flex1, 0), (flex1, 0)))
        return points[-1]

    def blob(self, center, radius, squash, top, bottom, subdiv, flex, lump=0.28, glow=0.0):
        """A lumpy cloud of foliage: an icosphere pushed out by noise, lit
        light on top and deeper underneath (baked into the colour)."""
        verts, faces = icosphere(subdiv)
        seed = Vector((self.rng.random() * 50, self.rng.random() * 50, self.rng.random() * 50))
        tint = self.rng.uniform(-0.05, 0.05)
        idx, cols = [], []
        c = Vector(center)
        for v in verts:
            n = noise.noise(v * 1.8 + seed)
            r = radius * (1.0 + lump * n)
            p = c + Vector((v.x * r, v.y * r, v.z * r * squash))
            idx.append(self.add_vert(p))
            h = (v.z + 1.0) * 0.5
            col = mix(bottom, top, h ** 0.8)
            # Little highlights where the lumps bulge: reads as leaf clumps.
            col = shade(col, 1.0 + tint + 0.10 * max(0.0, n))
            cols.append(col)
        for f in faces:
            self.face(tuple(idx[i] for i in f), tuple(cols[i] for i in f),
                      tuple((flex, glow) for _ in f))

    def flower(self, center, normal, petals, radius, petal, heart, flex):
        """An oversized five-petal blossom (R3), a flat fan facing `normal`."""
        n = Vector(normal).normalized()
        side = n.orthogonal().normalized()
        up = n.cross(side)
        c = Vector(center)
        mid = self.add_vert(c + n * radius * 0.15)
        ring = []
        for i in range(petals * 2):
            a = math.tau * i / (petals * 2)
            r = radius if i % 2 == 0 else radius * 0.45
            ring.append(self.add_vert(c + (side * math.cos(a) + up * math.sin(a)) * r))
        for i in range(len(ring)):
            a, b = ring[i], ring[(i + 1) % len(ring)]
            # One-sided: woods_foliage.gdshader draws both faces (cull_disabled).
            self.face((mid, a, b), (heart, petal, petal), ((flex, 0.1), (flex, 0.1), (flex, 0.1)))

    def strand(self, top, length, width, col_top, col_bottom, flex_top):
        """A hanging willow frond: a ribbon that sways most at its tip."""
        t = Vector(top)
        yaw = self.rng.random() * math.tau
        right = Vector((math.cos(yaw), math.sin(yaw), 0.0)) * width
        segs = 3
        rows = []
        for i in range(segs + 1):
            k = i / segs
            p = t + Vector((0, 0, -length * k)) + Vector((math.sin(yaw), -math.cos(yaw), 0)) * 0.25 * k * k
            w = 1.0 - 0.6 * k
            rows.append((self.add_vert(p - right * w), self.add_vert(p + right * w), k))
        for i in range(segs):
            a0, a1, k0 = rows[i]
            b0, b1, k1 = rows[i + 1]
            c0, c1 = mix(col_top, col_bottom, k0), mix(col_top, col_bottom, k1)
            f0, f1 = flex_top + 0.6 * k0, flex_top + 0.6 * k1
            for face in ((a0, a1, b1), (a0, b1, b0)):
                cols = tuple(c0 if v in (a0, a1) else c1 for v in face)
                uvs = tuple((f0 if v in (a0, a1) else f1, 0.0) for v in face)
                self.face(face, cols, uvs)


_ICO = {}


def icosphere(subdiv):
    if subdiv in _ICO:
        return _ICO[subdiv]
    t = (1.0 + 5 ** 0.5) / 2.0
    verts = [Vector(v).normalized() for v in (
        (-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t),
        (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1))]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4),
             (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8),
             (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    for _ in range(subdiv):
        cache = {}

        def mid(a, b):
            key = (min(a, b), max(a, b))
            if key not in cache:
                verts.append(((verts[a] + verts[b]) * 0.5).normalized())
                cache[key] = len(verts) - 1
            return cache[key]

        nf = []
        for a, b, c in faces:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            nf += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        faces = nf
    # Blender winding: outward-facing counter-clockwise.
    _ICO[subdiv] = (verts, [(a, c, b) for a, b, c in faces])
    return _ICO[subdiv]


# ------------------------------------------------------------- shapes ----

def trunk_line(kit, height, segs, lean):
    pts = [Vector((0, 0, 0))]
    d = Vector((kit.rng.uniform(-lean, lean), kit.rng.uniform(-lean, lean), 1.0)).normalized()
    for _ in range(segs):
        pts.append(pts[-1] + d * height / segs)
        d = (d + Vector((kit.rng.uniform(-lean, lean), kit.rng.uniform(-lean, lean), 0.0))).normalized()
    return pts


def branch_line(kit, base, direction, length, segs, droop=0.0):
    pts = [Vector(base)]
    d = Vector(direction).normalized()
    for i in range(segs):
        pts.append(pts[-1] + d * length / segs)
        d = (d + Vector((kit.rng.uniform(-0.25, 0.25), kit.rng.uniform(-0.25, 0.25), -droop))).normalized()
    return pts


def taper(n, r0, r1):
    return [r0 + (r1 - r0) * (i / (n - 1)) ** 0.8 for i in range(n)]


def crowned_tree(kit, near, p):
    """Shared broadleaf: a trunk, a whorl of limbs, cloud clusters on each
    limb and a crown cluster. `p` holds the species' proportions."""
    segs = 5 if near else 2
    trunk = trunk_line(kit, p["height"], segs, p.get("lean", 0.12))
    kit.tube(trunk, taper(len(trunk), p["r0"], p["r1"]), 9 if near else 5,
             p["bark0"], p["bark1"], 0.0, 0.08, flare=p.get("flare", 0.35) if near else 0.0)
    top = trunk[-1]
    tips = []
    twig_tips = []
    limbs = p["limbs"]
    for i in range(limbs):
        a = math.tau * i / limbs + kit.rng.uniform(-0.4, 0.4)
        start = trunk[max(1, len(trunk) - 1 - (i % 2))] if near else top
        d = Vector((math.cos(a), math.sin(a), p["rise"] + kit.rng.uniform(-0.1, 0.2)))
        length = p["limb"] * kit.rng.uniform(0.8, 1.15)
        line = branch_line(kit, start, d, length, 3 if near else 1, p.get("droop", 0.0))
        if near:
            kit.tube(line, taper(len(line), p["r1"] * 0.7, p["r1"] * 0.2), 6, p["bark1"], p["bark1"], 0.08, 0.3)
            # Twigs fork off each limb so the crown edge is not a smooth ball.
            for _ in range(p.get("twigs", 1)):
                k = kit.rng.choice(line[1:])
                td = d + Vector((kit.rng.uniform(-0.8, 0.8), kit.rng.uniform(-0.8, 0.8), 0.3))
                tl = branch_line(kit, k, td, length * 0.45, 2)
                kit.tube(tl, taper(len(tl), p["r1"] * 0.25, p["r1"] * 0.06), 4, p["bark1"], p["bark1"], 0.3, 0.5)
                twig_tips.append(tl[-1])
        tips.append(line[-1])
    # Big smooth clouds on the limbs, small lumpy ones on the twigs.
    for i, t in enumerate(tips if near else tips[::2] + [top]):
        size = p["leaf"] * kit.rng.uniform(0.85, 1.15) * (1.0 if near else 1.45)
        kit.blob(t + Vector((0, 0, size * 0.3)), size, p.get("squash", 0.75), p["leaf_top"], p["leaf_bottom"],
                 2 if near and i < p.get("smooth", 3) else 1, 0.45)
    for t in twig_tips:
        size = p["leaf"] * kit.rng.uniform(0.5, 0.7)
        kit.blob(t, size, p.get("squash", 0.75), p["leaf_top"], p["leaf_bottom"], 1, 0.55, lump=0.35)
    tips = tips + twig_tips
    crown = p["leaf"] * p.get("crown", 1.3)
    kit.blob(top + Vector((0, 0, crown * 0.7)), crown, p.get("squash", 0.75), p["leaf_top"], p["leaf_bottom"],
             2 if near else 1, 0.35)
    return tips


def blossoms(kit, tips, count, radius, colors, heart, spread):
    for t in tips:
        for _ in range(count):
            off = Vector((kit.rng.uniform(-1, 1), kit.rng.uniform(-1, 1), kit.rng.uniform(-0.2, 1.0))).normalized()
            kit.flower(Vector(t) + off * spread, off, 5, radius * kit.rng.uniform(0.8, 1.2),
                       kit.rng.choice(colors), heart, 0.55)


def ancient_oak(kit, near):
    p = dict(height=7.5, r0=1.6, r1=0.95, bark0=BARK_DARK, bark1=BARK, lean=0.08, flare=0.6, limbs=7,
             limb=8.0, rise=0.35, leaf=3.2, crown=1.5, leaf_top=LEAF_GOLD, leaf_bottom=LEAF_DEEP, twigs=1)
    crowned_tree(kit, near, p)
    if near:  # buttress roots wide enough to walk along, mossy at the ends
        for i in range(6):
            a = math.tau * i / 6 + kit.rng.uniform(-0.3, 0.3)
            out = Vector((math.cos(a), math.sin(a), 0))
            line = [out * 0.6 + Vector((0, 0, 1.3)), out * 2.4 + Vector((0, 0, 0.3)),
                    out * kit.rng.uniform(4.0, 5.5) + Vector((0, 0, -0.4))]
            kit.tube(line, [0.8, 0.45, 0.15], 6, BARK_DARK, MOSS, 0.0, 0.0)


def oak(kit, near):
    crowned_tree(kit, near, dict(height=5.0, r0=0.55, r1=0.34, bark0=BARK_DARK, bark1=BARK, limbs=5, limb=4.6,
                                 rise=0.5, leaf=2.1, leaf_top=LEAF_GOLD, leaf_bottom=mix(LEAF_DEEP, TEAL, 0.4)))


def beech(kit, near):
    crowned_tree(kit, near, dict(height=9.0, r0=0.45, r1=0.26, bark0=BARK_GREY, bark1=shade(BARK_GREY, 1.08),
                                 lean=0.05, limbs=5, limb=3.6, rise=0.8, leaf=1.9, crown=1.4, squash=0.9,
                                 leaf_top=mix(LEAF_GOLD, BUTTER, 0.35), leaf_bottom=mix(LEAF_DEEP, TEAL, 0.4)))


def elm(kit, near):
    # Tall and vase-shaped: limbs climb steeply and the crown spreads wide.
    crowned_tree(kit, near, dict(height=7.0, r0=0.45, r1=0.3, bark0=BARK_DARK, bark1=BARK, lean=0.06, limbs=5,
                                 limb=5.2, rise=1.1, leaf=2.0, crown=1.0, squash=0.7,
                                 leaf_top=mix(LEAF, LEAF_GOLD, 0.4), leaf_bottom=mix(LEAF_DEEP, TEAL, 0.5)))


def alder(kit, near):
    tips = crowned_tree(kit, near, dict(height=7.0, r0=0.3, r1=0.16, bark0=BARK_DARK, bark1=BARK_GREY, limbs=4,
                                        limb=1.8, rise=0.5, leaf=1.4, crown=1.5, squash=1.5,
                                        leaf_top=LEAF, leaf_bottom=TEAL))
    del tips


def silver_birch(kit, near):
    white = CREAM
    h, rings = 9.0, (8 if near else 2)
    pts = trunk_line(kit, h, rings, 0.04)
    radii = taper(len(pts), 0.22, 0.07)
    if near:
        # Black lenticel bands on white bark, one ring at a time.
        for i in range(rings):
            band = white if i % 2 == 0 else shade(BARK, 0.55)
            kit.tube(pts[i:i + 2], radii[i:i + 2], 7, band, white, 0.1 * i / rings, 0.1 * (i + 1) / rings)
    else:
        kit.tube(pts, radii, 4, white, white)
    top = pts[-1]
    # A narrow, airy crown of small drooping clusters up the upper trunk.
    for i in range(9 if near else 3):
        k = 0.45 + 0.55 * i / (8 if near else 2)
        c = Vector(pts[int(k * (len(pts) - 1))]) + Vector((kit.rng.uniform(-1.1, 1.1), kit.rng.uniform(-1.1, 1.1), 0))
        kit.blob(c, kit.rng.uniform(0.8, 1.1) * (1.0 if near else 1.6), 1.2, mix(LEAF_GOLD, BUTTER, 0.3), mix(LEAF, LEAF_DEEP, 0.5),
                 1, 0.6)
    kit.blob(top, 1.0, 1.3, mix(LEAF_GOLD, BUTTER, 0.4), LEAF, 1, 0.6)


def willow(kit, near):
    tips = crowned_tree(kit, near, dict(height=4.0, r0=0.55, r1=0.36, bark0=BARK, bark1=BARK, lean=0.25, limbs=6,
                                        limb=3.6, rise=0.55, leaf=1.7, crown=1.3, squash=0.6, droop=0.15,
                                        leaf_top=mix(LEAF_GOLD, BUTTER, 0.25), leaf_bottom=LEAF, twigs=1))
    # Weeping fronds curtain the crown down to knee height.
    count = 7 if near else 3
    for t in tips:
        for _ in range(count):
            start = Vector(t) + Vector((kit.rng.uniform(-1.8, 1.8), kit.rng.uniform(-1.8, 1.8), -0.2))
            length = kit.rng.uniform(3.0, 5.0)
            kit.strand(start, length, 0.09 if near else 0.3, mix(LEAF, LEAF_GOLD, 0.35), mix(LEAF, LEAF_DEEP, 0.3), 0.4)


def hawthorn(kit, near):
    tips = crowned_tree(kit, near, dict(height=2.6, r0=0.22, r1=0.14, bark0=BARK_DARK, bark1=BARK, lean=0.35, limbs=4,
                                        limb=1.9, rise=0.45, leaf=1.1, crown=1.1, leaf_top=LEAF,
                                        leaf_bottom=mix(LEAF_DEEP, TEAL, 0.4)))
    if near:
        blossoms(kit, tips, 7, 0.13, [CREAM, CREAM, BLUSH], GOLD, 1.0)


def wild_cherry(kit, near):
    pink = BLUSH
    tips = crowned_tree(kit, near, dict(height=4.0, r0=0.3, r1=0.2, bark0=BARK_DARK, bark1=BARK,
                                        lean=0.18, limbs=6, limb=3.0, rise=0.45, leaf=1.5, crown=1.2,
                                        leaf_top=pink, leaf_bottom=shade(pink, 0.78)))
    if near:
        blossoms(kit, tips, 4, 0.18, [CREAM, BLUSH, ROSE], GOLD, 1.3)


def elder(kit, near):
    tips = crowned_tree(kit, near, dict(height=2.4, r0=0.15, r1=0.1, bark0=BARK, bark1=BARK, lean=0.35, limbs=5,
                                        limb=1.6, rise=0.4, leaf=0.9, crown=1.0, leaf_top=LEAF, leaf_bottom=LEAF_DEEP))
    if near:  # flat cream umbels of elderflower
        for t in tips:
            for _ in range(3):
                c = Vector(t) + Vector((kit.rng.uniform(-0.7, 0.7), kit.rng.uniform(-0.7, 0.7), 0.55))
                kit.flower(c, (0, 0, 1), 9, 0.2, CREAM, shade(CREAM, 0.9), 0.5)


def twisted_dead(kit, near):
    # Bogge territory: black, leafless, too many joints. Never softened.
    segs = 6 if near else 2
    trunk = trunk_line(kit, 6.5, segs, 0.5)
    kit.tube(trunk, taper(len(trunk), 0.5, 0.18), 7 if near else 4, ROT, BOG, 0.0, 0.05,
             flare=0.5 if near else 0.0)
    for i in range(7 if near else 4):
        a = math.tau * i / 7 + kit.rng.uniform(-0.5, 0.5)
        start = trunk[kit.rng.randint(len(trunk) // 2, len(trunk) - 1)]
        d = Vector((math.cos(a), math.sin(a), kit.rng.uniform(-0.2, 0.5)))
        line = branch_line(kit, start, d, kit.rng.uniform(2.5, 4.0), 4 if near else 1)
        kit.tube(line, taper(len(line), 0.16, 0.02), 5 if near else 3, DEAD, DEAD, 0.05, 0.2)
        if near:  # crooked fingers
            for _ in range(2):
                fl = branch_line(kit, line[-2], d + Vector((kit.rng.uniform(-1, 1), kit.rng.uniform(-1, 1),
                                                              kit.rng.uniform(-0.6, 0.8))), 1.4, 3)
                kit.tube(fl, taper(len(fl), 0.06, 0.01), 4, DEAD, DEAD, 0.2, 0.3)


def blighted_tree(kit, near):
    crowned_tree(kit, near, dict(height=5.5, r0=0.45, r1=0.28, bark0=shade(BLIGHT, 0.6), bark1=BLIGHT,
                                 lean=0.22, limbs=4, limb=3.5, rise=0.4, leaf=1.25, crown=0.9, squash=0.55,
                                 leaf_top=shade(LICHEN, 0.8), leaf_bottom=BRUISE))


def crab_apple(kit, near):
    # Canon: crab apple blossom. A low, wide, rounded crown of blush and rose.
    tips = crowned_tree(kit, near, dict(height=3.2, r0=0.3, r1=0.2, bark0=BARK_DARK, bark1=BARK, lean=0.25, limbs=6,
                                        limb=2.8, rise=0.35, leaf=1.5, crown=1.3, squash=0.7,
                                        leaf_top=BLUSH, leaf_bottom=mix(ROSE, BRUISE, 0.15)))
    if near:
        blossoms(kit, tips, 4, 0.2, [CREAM, BLUSH, ROSE], GOLD, 1.3)


def lilac_tree(kit, near):
    # Canon: lilac. A multi-stemmed small tree heavy with lilac panicles.
    for k in range(3 if near else 1):
        a = math.tau * k / 3
        base = Vector((math.cos(a), math.sin(a), 0)) * 0.25
        line = branch_line(kit, base, Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 1.0)), 3.0, 3 if near else 1)
        kit.tube(line, taper(len(line), 0.14, 0.07), 6 if near else 4, BARK_DARK, BARK, 0.0, 0.2)
        kit.blob(line[-1] + Vector((0, 0, 0.6)), 1.3 * (1.0 if near else 1.6), 0.85, LEAF, mix(LEAF_DEEP, TEAL, 0.4),
                 1, 0.4)
        if near:
            # Panicles: soft cones of lilac and periwinkle poking out of the leaves.
            for _ in range(7):
                d = Vector((kit.rng.uniform(-1, 1), kit.rng.uniform(-1, 1), kit.rng.uniform(0.1, 1.0))).normalized()
                tip = line[-1] + Vector((0, 0, 0.6)) + d * 1.25
                col = kit.rng.choice([LILAC, LILAC, PERIWINKLE, mix(LILAC, CREAM, 0.4)])
                kit.blob(tip + Vector((0, 0, 0.15)), 0.32, 1.9, mix(col, CREAM, 0.25), shade(col, 0.85), 1, 0.6,
                         lump=0.45, glow=0.05)


def yew(kit, near):
    # The dark value anchor behind pastel blossom: a dense round-conical mass
    # of deep teal-green on a fluted red-brown trunk.
    trunk = trunk_line(kit, 2.2, 2, 0.08)
    kit.tube(trunk, [0.55, 0.45, 0.4], 8 if near else 5, BARK_DARK, shade(BARK, 1.1), 0.0, 0.05,
             flare=0.5 if near else 0.0)
    tiers = 4 if near else 2
    for i in range(tiers):
        t = i / max(1, tiers - 1)
        r = (2.6 - 1.4 * t) * (1.0 if near else 1.1)
        c = Vector((kit.rng.uniform(-0.3, 0.3), kit.rng.uniform(-0.3, 0.3), 2.2 + 1.9 * i * (3 / max(1, tiers - 1)) * 0.75))
        kit.blob(c, r, 0.8, mix(LEAF_DEEP, TEAL, 0.35), shade(TEAL, 0.7), 2 if near and i < 2 else 1, 0.3, lump=0.22)


def leaning_trunk(kit, near):
    # Canopy-less trunk, broken off high and leaning: cheap density (§2.4).
    pts = branch_line(kit, (0, 0, 0), (kit.rng.uniform(0.25, 0.4), 0.1, 1.0), 6.5, 4 if near else 1)
    kit.tube(pts, taper(len(pts), 0.42, 0.26), 8 if near else 5, BARK_DARK, mix(BARK, MOSS, 0.5), 0.0, 0.05,
             flare=0.4 if near else 0.0)
    if near:
        kit.blob(pts[-1], 0.36, 0.5, MOSS, shade(MOSS, 0.7), 1, 0.05, lump=0.5)  # moss cap on the break
        for i in range(2):
            d = Vector((kit.rng.uniform(-1, 1), kit.rng.uniform(-1, 1), 0.6))
            sl = branch_line(kit, pts[2 + i], d, 1.2, 2)
            kit.tube(sl, taper(len(sl), 0.12, 0.03), 5, BARK, BARK, 0.05, 0.1)


def stump(kit, near):
    pts = [Vector((0, 0, -0.1)), Vector((0, 0, 0.5)), Vector((0, 0, 0.95))]
    kit.tube(pts, [0.62, 0.52, 0.5], 10 if near else 6, BARK_DARK, BARK, 0.0, 0.0, flare=0.6 if near else 0.0)
    # The cut face: fawn rings (the tube's cap is the face).
    kit.flower(Vector((0, 0, 0.96)), (0, 0, 1), 10, 0.5, FAWN, shade(FAWN, 0.8), 0.0)
    if near:
        kit.blob(Vector((0.35, 0.2, 0.55)), 0.3, 0.6, MOSS, shade(MOSS, 0.7), 1, 0.0, lump=0.4)
        for _ in range(4):  # toadstools at the foot
            a = kit.rng.random() * math.tau
            base = Vector((math.cos(a), math.sin(a), 0)) * 0.75
            kit.tube([base, base + Vector((0, 0, 0.18))], [0.03, 0.025], 5, CREAM, CREAM)
            kit.blob(base + Vector((0, 0, 0.2)), 0.09, 0.5, ROSE, shade(ROSE, 0.8), 1, 0.0, lump=0.0)


def fallen_log(kit, near):
    # Dead wood on the forest floor: a mossy trunk with its root plate.
    length = 7.0
    pts = [Vector((-length / 2 + length * i / 4, kit.rng.uniform(-0.15, 0.15), 0.35)) for i in range(5)]
    kit.tube(pts if near else [pts[0], pts[-1]], taper(5 if near else 2, 0.42, 0.3), 9 if near else 5,
             BARK_DARK, BARK, 0.0, 0.0)
    if near:
        for i in range(1, 4):  # moss along the top
            kit.blob(pts[i] + Vector((0, 0, 0.3)), 0.45, 0.35, MOSS, shade(MOSS, 0.75), 1, 0.0, lump=0.45)
        plate = pts[0] + Vector((-0.2, 0, 0.3))
        for k in range(7):  # the torn root plate, roots splayed in a disc
            a = math.tau * k / 7
            tip = plate + Vector((-0.2, math.cos(a) * 1.3, math.sin(a) * 1.1))
            kit.tube([plate, tip], [0.16, 0.04], 4, BARK_DARK, FAWN, 0.0, 0.0)
        for _ in range(2):  # broken branch stubs
            b = kit.rng.choice(pts[1:4])
            d = Vector((kit.rng.uniform(-0.3, 0.3), kit.rng.choice([-1, 1]), 0.6))
            sl = branch_line(kit, b, d, 1.0, 1)
            kit.tube(sl, [0.12, 0.05], 5, BARK, BARK, 0.0, 0.0)


# species: (builder, near tri cap, far tri cap). Rule R4: props <= 3k tris.
SPECIES = {
    "ancient_oak": (ancient_oak, 4500, 600),  # a handful per region, landmarks
    "oak": (oak, 3000, 550),
    "beech": (beech, 3000, 550),
    "elm": (elm, 3000, 550),
    "alder": (alder, 3000, 550),
    "silver_birch": (silver_birch, 3000, 550),
    "willow": (willow, 3000, 550),
    "hawthorn": (hawthorn, 3000, 550),
    "wild_cherry": (wild_cherry, 3000, 550),
    "elder": (elder, 3000, 550),
    "twisted_dead": (twisted_dead, 3000, 550),
    "blighted_tree": (blighted_tree, 3000, 550),
    "crab_apple": (crab_apple, 3000, 550),
    "lilac_tree": (lilac_tree, 3000, 550),
    "yew": (yew, 3000, 550),
    "leaning_trunk": (leaning_trunk, 3000, 550),
    "stump": (stump, 3000, 550),
    "fallen_log": (fallen_log, 3000, 550),
}


# ------------------------------------------------------------- export ----

def to_object(kit, name):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in kit.verts], [], kit.faces)
    mesh.update()
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for k, li in enumerate(poly.loop_indices):
            c = kit.colors[poly.index][k]
            col.data[li].color = (c[0], c[1], c[2], 1.0)
            u = kit.uvs[poly.index][k]
            # glTF flips V on export (v' = 1 - v); pre-flip so Godot reads glow as written.
            uv.data[li].uv = (u[0], 1.0 - u[1])
    mesh.color_attributes.active_color = col
    for poly in mesh.polygons:
        poly.use_smooth = True
    mat = bpy.data.materials.get("woods_foliage") or bpy.data.materials.new("woods_foliage")
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build(species, fn, near_cap, far_cap):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    seed = sum(ord(c) * (i + 1) for i, c in enumerate(species))
    objs = []
    counts = []
    for name, near, cap in (("near", True, near_cap), ("far", False, far_cap)):
        kit = Kit(seed)
        fn(kit, near)
        counts.append(kit.tri_count())
        if kit.tri_count() > cap and not os.environ.get("WOODS_NO_CAP"):
            raise SystemExit("%s %s: %d tris over the %d cap" % (species, name, kit.tri_count(), cap))
        objs.append(to_object(kit, name))
    path = os.path.join(OUT, species + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_normals=True, export_texcoords=True, export_materials="PLACEHOLDER",
                              export_apply=False, export_animations=False)
    print("%-14s near %5d tris  far %4d tris  %6.0f KB" % (species, counts[0], counts[1], os.path.getsize(path) / 1024))


def main():
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[2:] if len(sys.argv) > 2 else list(SPECIES)
    for species in only:
        fn, near_cap, far_cap = SPECIES[species]
        build(species, fn, near_cap, far_cap)


if __name__ == "__main__":
    main()
