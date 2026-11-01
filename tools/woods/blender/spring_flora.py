"""Spring Court flora kit as Blender models (headless bpy, deterministic). Lane L21.

Run:  /opt/bpyenv/bin/python tools/woods/blender/spring_flora.py [out_dir] [species ...]
Out:  world/spring_court/shared/models/<species>.glb, two mesh objects each:
      "near" (full detail) and "far" (LOD1, about half the triangles).
      FloraLibrary loads a <species>.glb in place of its procedural builder.

Same vertex conventions as woods_trees.py (whose Kit and export this reuses):
COLOR_0 is sRGB albedo, UV0.x is wind flex (0 at the root), UV0.y is glow.
Glow stays 0 here: nothing glows by day in Tamlin's court (Storykeeper).

Look (R3, the user's "Barbie-level cute" ask): rounded, oversized blooms in
candy pastels with gold hearts; soft domed bushes; pom-pom florets; hanging
wisteria and golden-chain racemes. Canon flora from lore 05 (wisteria,
peonies, tulips, irises, foxglove, bluebells, crocus, snowdrops, violets,
buttercups, daffodils, goldenrod, maiden's lace, roses) is tagged C in
FloraLibrary; the rest is X.

Budgets (R4): trees <= 3,000 tris, shrubs <= 700, ground flowers <= 180
(they are scattered by the tens of thousands), LOD1 about 50% of near.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

import woods_trees as wt  # noqa: E402
from woods_trees import Kit, hexc, mix, shade, icosphere, taper, trunk_line, branch_line  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 and "/" in sys.argv[1] else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "world", "spring_court", "shared", "models")

# Palette (sRGB): experience-bar §2.2 plus the candy accents R3 asks for.
ROSE = wt.ROSE
BLUSH = wt.BLUSH
LILAC = wt.LILAC
PERI = wt.PERIWINKLE
BUTTER = wt.BUTTER
PEARL = wt.CREAM
GOLD = wt.GOLD
HOT_PINK = hexc("EE7FB0")
RASPBERRY = hexc("E25A7A")   # canon red roses, kept candy
CORAL = hexc("F7A08C")
APRICOT = hexc("F9C27E")
SUNNY = hexc("FFD85A")
AMETHYST = hexc("9B6FD6")
WISTERIA = hexc("B79BEA")
WISTERIA_DEEP = hexc("8E73D6")
PERI_DEEP = hexc("7F90E6")
SKY = hexc("9FD3F5")
MINT = hexc("A8E6C8")
SAGE = hexc("A9C9B4")
LEAF_GOLD = wt.LEAF_GOLD
LEAF = wt.LEAF
LEAF_DEEP = wt.LEAF_DEEP
TEAL = wt.TEAL
BARK = wt.BARK
BARK_DARK = wt.BARK_DARK
BARK_PEARL = hexc("E8DCE0")
BERRY = hexc("7A3F8C")
# Polish (L21-2): richer bush greens and a lush (not lime, not teal) grass.
BUSH = hexc("62B27A")
BUSH_DEEP = hexc("2F7458")
GRASS_DEEP = hexc("3F8F55")
GRASS = hexc("6FC07A")
GRASS_TIP = hexc("A9DE95")


# ------------------------------------------------------------- helpers ----

def frame(n):
    n = Vector(n).normalized()
    side = n.orthogonal().normalized()
    return n, side, n.cross(side).normalized()


def tri(kit, a, b, c, cols, flex, glow=0.0):
    i = [kit.add_vert(a), kit.add_vert(b), kit.add_vert(c)]
    fl = flex if isinstance(flex, tuple) else (flex, flex, flex)
    kit.face(i, cols, tuple((f, glow) for f in fl))


def quad(kit, a, b, c, d, cols, flex):
    """a-b-c-d in order; cols/flex are per corner."""
    tri(kit, a, b, c, (cols[0], cols[1], cols[2]), (flex[0], flex[1], flex[2]))
    tri(kit, a, c, d, (cols[0], cols[2], cols[3]), (flex[0], flex[2], flex[3]))


def yaw_vec(kit):
    a = kit.rng.random() * math.tau
    return Vector((math.cos(a), math.sin(a), 0.0))


def blade(kit, base, height, width, lean, c0, c1, f0=0.0, f1=1.0, side=None):
    """A soft tapered leaf blade, 3 triangles: two quads' worth, pointed tip."""
    b = Vector(base)
    s = (side or yaw_vec(kit)) * width
    lean = Vector(lean)
    m = b + Vector((0, 0, height * 0.55)) + lean * 0.35
    t = b + Vector((0, 0, height)) + lean
    cm = mix(c0, c1, 0.55)
    fm = f0 + (f1 - f0) * 0.55
    quad(kit, b - s, b + s, m + s * 0.8, m - s * 0.8, (c0, c0, cm, cm), (f0, f0, fm, fm))
    tri(kit, m - s * 0.8, m + s * 0.8, t, (cm, cm, c1), (fm, fm, f1))


def leaf(kit, base, direction, length, width, c0, c1, flex0, flex1):
    """A flat almond leaf (2 triangles) lying along `direction`."""
    b = Vector(base)
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side = side.normalized() * width
    mid = b + d * length * 0.45 + Vector((0, 0, length * 0.08))
    tip = b + d * length
    fm = (flex0 + flex1) * 0.5
    quad(kit, b, mid + side, tip, mid - side, (c0, mix(c0, c1, 0.5), c1, mix(c0, c1, 0.5)), (flex0, fm, flex1, fm))


def stem(kit, base, top, width, col, f0=0.0, f1=1.0):
    """A thin flat stem (2 triangles); the shader draws both faces."""
    b, t = Vector(base), Vector(top)
    d = (t - b).normalized()
    s = d.cross(Vector((0.3, 0.7, 0.1)).normalized()).normalized() * width
    quad(kit, b - s, b + s, t + s * 0.6, t - s * 0.6, (col, col, col, col), (f0, f0, f1, f1))


def fan(kit, center, normal, petals, radius, petal, heart, flex, notch=0.45, tip=None):
    """An open blossom: a star fan of 2*petals triangles facing `normal`."""
    n, side, up = frame(normal)
    c = Vector(center)
    tip = tip or petal
    mid = kit.add_vert(c + n * radius * 0.18)
    ring = []
    for i in range(petals * 2):
        a = math.tau * i / (petals * 2)
        r = radius if i % 2 == 0 else radius * notch
        ring.append((kit.add_vert(c + (side * math.cos(a) + up * math.sin(a)) * r - n * radius * 0.05 * (i % 2)),
                     tip if i % 2 == 0 else petal))
    for i in range(len(ring)):
        (a, ca), (b, cb) = ring[i], ring[(i + 1) % len(ring)]
        kit.face((mid, a, b), (heart, ca, cb), ((flex, 0.0), (flex, 0.0), (flex, 0.0)))


def bead(kit, center, r, col, flex, top=None, squash=1.0):
    """A soft round floret, berry or bud: a squashed 20-triangle ball,
    lighter on top, so clusters read as fluffy rather than faceted."""
    verts, faces = icosphere(0)
    c = Vector(center)
    top = top or shade(col, 1.12)
    idx, cols = [], []
    for v in verts:
        idx.append(kit.add_vert(c + Vector((v.x * r, v.y * r, v.z * r * squash))))
        cols.append(mix(shade(col, 0.9), top, (v.z + 1.0) * 0.5))
    for f in faces:
        kit.face(tuple(idx[i] for i in f), tuple(cols[i] for i in f), ((flex, 0.0),) * 3)


def pom(kit, center, radius, ca, cb, flex, subdiv=1, squash=1.0, lump=0.1):
    """A speckled pom-pom ball of florets (hydrangea, allium, candyfloss)."""
    verts, faces = icosphere(subdiv)
    c = Vector(center)
    seed = Vector((kit.rng.random() * 40, kit.rng.random() * 40, kit.rng.random() * 40))
    idx, cols = [], []
    for v in verts:
        r = radius * (1.0 + lump * noise.noise(v * 2.3 + seed))
        idx.append(kit.add_vert(c + Vector((v.x * r, v.y * r, v.z * r * squash))))
        col = mix(ca, cb, kit.rng.random())
        cols.append(shade(col, 0.9 + 0.16 * (v.z + 1.0) * 0.5))
    for f in faces:
        kit.face(tuple(idx[i] for i in f), tuple(cols[i] for i in f), ((flex, 0.0),) * 3)


def cup(kit, center, normal, radius, petals, layers, c_out, c_in, heart, flex, openness=0.6):
    """A layered cupped rosette (rose, peony, magnolia, crocus): rings of
    petals, the inner ones more upright, plus a bead heart."""
    n, side, up = frame(normal)
    c = Vector(center)
    for L in range(layers):
        k = L / max(layers - 1, 1)
        r = radius * (1.0 - 0.42 * k)
        lift = radius * (0.25 + 0.6 * k) * (1.15 - openness)
        col_tip = mix(c_out, c_in, k * 0.7)
        col_base = mix(c_out, c_in, 0.4 + 0.6 * k)
        off = L * math.pi / petals
        for i in range(petals):
            a = math.tau * i / petals + off
            d = side * math.cos(a) + up * math.sin(a)
            perp = n.cross(d).normalized()
            b = c + d * radius * 0.06 + n * radius * 0.04 * L
            m = c + d * r * 0.55 + n * lift * 0.45
            t = c + d * r + n * lift
            w = r * (0.5 if petals <= 5 else 0.4)
            quad(kit, b, m + perp * w, t, m - perp * w,
                 (col_base, mix(col_base, col_tip, 0.5), col_tip, mix(col_base, col_tip, 0.5)), (flex,) * 4)
    if heart is not None:
        bead(kit, c + n * radius * 0.12, radius * 0.16, heart, flex)


def bell(kit, attach, axis, radius, length, col, col_in, flex, sides=5):
    """A hanging bell or trumpet: an open cone, `sides` triangles from apex."""
    a = Vector(attach)
    n, side, up = frame(axis)
    apex = kit.add_vert(a)
    ring = []
    for s in range(sides):
        ang = math.tau * s / sides
        ring.append(kit.add_vert(a + n * length + (side * math.cos(ang) + up * math.sin(ang)) * radius))
    for s in range(sides):
        kit.face((apex, ring[s], ring[(s + 1) % sides]), (col_in, col, col), ((flex, 0.0),) * 3)


def tulip(kit, base, radius, height, col, col_tip, flex, sides=6):
    """A closed tulip cup with pointed petal tips (4*sides triangles)."""
    b = Vector(base)
    r0 = [kit.add_vert(b + Vector((math.cos(math.tau * s / sides) * radius * 0.4,
                                   math.sin(math.tau * s / sides) * radius * 0.4, 0))) for s in range(sides)]
    r1 = [kit.add_vert(b + Vector((math.cos(math.tau * s / sides) * radius,
                                   math.sin(math.tau * s / sides) * radius, height * 0.45))) for s in range(sides)]
    tips = [kit.add_vert(b + Vector((math.cos(math.tau * (s + 0.5) / sides) * radius * 0.78,
                                     math.sin(math.tau * (s + 0.5) / sides) * radius * 0.78, height))) for s in range(sides)]
    bottom = kit.add_vert(b - Vector((0, 0, height * 0.12)))
    deep = shade(col, 0.85)
    f = ((flex, 0.0),) * 3
    for s in range(sides):
        n = (s + 1) % sides
        kit.face((r0[s], r0[n], r1[n]), (deep, deep, col), f)
        kit.face((r0[s], r1[n], r1[s]), (deep, col, col), f)
        kit.face((r1[s], r1[n], tips[s]), (col, col, col_tip), f)
        kit.face((bottom, r0[n], r0[s]), (deep, deep, deep), f)


def raceme(kit, top, length, radius, c_top, c_tip, flex, sides=5, segs=6):
    """A hanging flower chain (wisteria, golden chain): a plump, rounded
    bunch that tapers to a soft tip, with speckled florets in the colour."""
    t = Vector(top)
    drift = Vector((kit.rng.uniform(-0.12, 0.12), kit.rng.uniform(-0.12, 0.12), 0.0))
    prof = [0.15, 0.85, 1.0, 0.9, 0.72, 0.5, 0.28][:segs + 1] if segs >= 4 else [0.15, 1.0, 0.55]
    n = len(prof)
    rings = []
    for i in range(n):
        k = i / (n - 1)
        p = t + Vector((0, 0, -length * k)) + drift * k * k
        ring = []
        for sd in range(sides):
            a = math.tau * (sd + 0.5 * (i % 2)) / sides
            ring.append((kit.add_vert(p + Vector((math.cos(a), math.sin(a), 0)) * radius * prof[i]),
                         shade(mix(c_top, c_tip, k), kit.rng.uniform(0.94, 1.08))))
        rings.append((ring, flex + 0.5 * k))
    tip = kit.add_vert(t + Vector((0, 0, -length * 1.06)) + drift)
    for i in range(n - 1):
        (r0, f0), (r1, f1) = rings[i], rings[i + 1]
        for sd in range(sides):
            a, b = r0[sd], r0[(sd + 1) % sides]
            c, d = r1[(sd + 1) % sides], r1[sd]
            kit.face((a[0], b[0], c[0]), (a[1], b[1], c[1]), ((f0, 0), (f0, 0), (f1, 0)))
            kit.face((a[0], c[0], d[0]), (a[1], c[1], d[1]), ((f0, 0), (f1, 0), (f1, 0)))
    rl, fl = rings[-1]
    for sd in range(sides):
        a, b = rl[sd], rl[(sd + 1) % sides]
        kit.face((a[0], b[0], tip), (a[1], b[1], c_tip), ((fl, 0), (fl, 0), (fl + 0.1, 0)))


def spike(kit, base, height, radius, beads, c_bottom, c_top, flex=0.0):
    """A flower spike (lupin, lavender, goldenrod): a stem with a cone of
    bead florets that shrink and lighten toward the tip."""
    b = Vector(base)
    lean = Vector((kit.rng.uniform(-0.08, 0.08), kit.rng.uniform(-0.08, 0.08), 0.0)) * height
    top = b + Vector((0, 0, height)) + lean
    stem(kit, b, b + (top - b) * 0.5, radius * 0.18, LEAF, flex, flex + 0.5)
    for i in range(beads):
        k = i / max(beads - 1, 1)
        p = b + (top - b) * (0.45 + 0.55 * k)
        bead(kit, p, radius * (1.25 - 0.6 * k), mix(c_bottom, c_top, k), flex + 0.5 + 0.5 * k, squash=1.15)


def dome(kit, center, radius, top, bottom, near, blobs=3, squash=0.7, flex=0.3, lump=0.08, subdiv=1):
    """A soft rounded bush body: one main smooth blob plus low side blobs.
    Flowers go on the main blob's surface via on_dome(center, radius, squash)."""
    c = Vector(center)
    kit.blob(c, radius * (1.0 if near else 1.05), squash, top, bottom, subdiv if near else 1, flex, lump=lump)
    n = blobs - 1 if near else max(0, (blobs - 1) // 2)
    a0 = kit.rng.random() * math.tau
    for i in range(n):
        a = a0 + math.tau * i / max(n, 1)
        off = Vector((math.cos(a), math.sin(a), -0.35 * squash)) * radius * 0.62
        kit.blob(c + off, radius * 0.68, squash, top, bottom, 1, flex, lump=lump)


def on_dome(kit, center, radius, squash, k=None):
    """A point and outward normal on the upper surface of a dome."""
    a = kit.rng.random() * math.tau
    el = kit.rng.uniform(0.3, 1.45) if k is None else k
    n = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
    p = Vector(center) + Vector((n.x * radius, n.y * radius, n.z * radius * squash))
    return p, n


def scatter_disc(kit, r):
    a = kit.rng.random() * math.tau
    d = r * math.sqrt(kit.rng.random())
    return Vector((math.cos(a) * d, math.sin(a) * d, 0.0))


# --------------------------------------------------------------- trees ----

def _trunk(kit, near, height, r0, r1, lean, c0=BARK_DARK, c1=BARK, flare=0.3):
    pts = trunk_line(kit, height, 4 if near else 2, lean)
    kit.tube(pts, taper(len(pts), r0, r1), 8 if near else 5, c0, c1, 0.0, 0.08, flare=flare if near else 0.0)
    return pts


def _limbs(kit, near, start, count, length, rise, r, droop=0.0, col=BARK):
    tips = []
    for i in range(count):
        a = math.tau * i / count + kit.rng.uniform(-0.35, 0.35)
        d = Vector((math.cos(a), math.sin(a), rise + kit.rng.uniform(-0.1, 0.15)))
        line = branch_line(kit, start, d, length * kit.rng.uniform(0.85, 1.15), 3 if near else 1, droop)
        kit.tube(line, taper(len(line), r, r * 0.3), 5 if near else 4, col, col, 0.1, 0.35)
        tips.append(line[-1])
    return tips


def candyfloss_tree(kit, near):
    """Cotton-candy blossom tree: a curvy pearl-rose trunk under a cluster
    of round pom canopies in pink, blush and lilac, dotted with blossoms."""
    trunk = _trunk(kit, near, 4.2, 0.42, 0.26, 0.22, BARK, hexc("B98A92"), 0.45)
    top = trunk[-1]
    tips = _limbs(kit, near, trunk[-2], 5, 2.6, 0.55, 0.2)
    palette = [(BLUSH, ROSE), (ROSE, HOT_PINK), (hexc("E3CCF5"), LILAC), (PEARL, BLUSH)]
    poms = tips + [top + Vector((0, 0, 1.4))]
    for i, t in enumerate(poms):
        ca, cb = palette[i % len(palette)]
        r = kit.rng.uniform(1.6, 2.0) * (1.0 if i < len(tips) else 1.25)
        pom(kit, t + Vector((0, 0, r * 0.35)), r * (1.0 if near else 1.1), ca, cb, 0.4,
            subdiv=2 if near else 1, squash=0.85, lump=0.12)
    if near:
        for t in poms:
            for _ in range(7):
                p, n = on_dome(kit, Vector(t) + Vector((0, 0, 0.6)), 1.9, 0.85)
                fan(kit, p, n, 5, 0.32, PEARL, GOLD, 0.5, tip=BLUSH)


def wisteria_tree(kit, near, chain=(LILAC, WISTERIA, WISTERIA_DEEP), leaves=(BUSH, BUSH_DEEP), count=32):
    """Canon wisteria as a small weeping tree: a twisted trunk, a domed
    canopy of small leaf puffs, and a curtain of fat lilac racemes hanging
    from all over it (the racemes are the tree's silhouette)."""
    trunk = _trunk(kit, near, 3.6, 0.38, 0.22, 0.32, BARK_DARK, BARK, 0.5)
    tips = _limbs(kit, near, trunk[-1], 6, 2.4, 0.5, 0.16, droop=0.1)
    canopy = tips + [trunk[-1] + Vector((0, 0, 1.3))]
    for i, t in enumerate(canopy):
        if i % 2 and i < len(tips):
            continue  # a sparse canopy: the flowers carry the silhouette
        r = kit.rng.uniform(1.0, 1.25)
        kit.blob(Vector(t) + Vector((0, 0, 0.2)), r * (1.0 if near else 1.2), 0.6, leaves[0], leaves[1],
                 1, 0.4, lump=0.16)
    n = count if near else count // 2
    for i in range(n):
        t = Vector(canopy[i % len(canopy)])
        a = kit.rng.random() * math.tau
        d = kit.rng.uniform(0.2, 1.3)
        p = t + Vector((math.cos(a) * d, math.sin(a) * d, -0.2 - 0.25 * d))
        length = kit.rng.uniform(1.6, 2.8)
        col = chain[1] if kit.rng.random() < 0.6 else chain[2]
        raceme(kit, p + Vector((0, 0, 0.3)), length, 0.34, chain[0], col, 0.5, sides=5 if near else 4,
               segs=6 if near else 2)


def golden_chain(kit, near):
    """Laburnum: the wisteria form with butter-gold chains and mint leaves."""
    wisteria_tree(kit, near, chain=(BUTTER, SUNNY, GOLD), leaves=(BUSH, BUSH_DEEP), count=30)


def magnolia(kit, near):
    """Open vase of pearly branches carrying oversized cupped blooms, pearl
    fading to blush and rose at the base, with a few mint leaf puffs."""
    trunk = _trunk(kit, near, 1.6, 0.32, 0.2, 0.1, hexc("A88E96"), BARK_PEARL, 0.35)
    tips = []
    for i in range(7 if near else 5):
        a = math.tau * i / 7 + kit.rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, 1.0))
        line = branch_line(kit, trunk[-1], d, kit.rng.uniform(3.4, 4.4), 3 if near else 2, 0.0)
        kit.tube(line, taper(len(line), 0.2, 0.07), 5 if near else 4, hexc("B99AA4"), BARK_PEARL, 0.1, 0.45)
        tips.append(line[-1])
        tips += [line[1] + (line[2] - line[1]) * 0.5 + Vector((math.cos(a), math.sin(a), 0.3)) * 0.8]
        if near:  # twig fork
            tw = branch_line(kit, line[2], d + Vector((kit.rng.uniform(-1, 1), kit.rng.uniform(-1, 1), 0.2)), 1.3, 2)
            kit.tube(tw, taper(len(tw), 0.06, 0.02), 4, BARK_PEARL, BARK_PEARL, 0.4, 0.6)
            tips.append(tw[-1])
    for i, t in enumerate(tips[:4]):  # a few fresh leaf tufts low in the crown
        kit.blob(Vector(t) - Vector((0, 0, 1.0)), 0.45, 0.6, LEAF, LEAF_DEEP, 1 if near else 0, 0.5, lump=0.15)
    blooms = tips + [Vector(t) + Vector((0.5, 0.3, -0.6)) for t in tips[::2]]
    for t in (blooms if near else blooms[::2]):
        cols = kit.rng.choice([(PEARL, BLUSH), (BLUSH, ROSE), (PEARL, ROSE), (hexc("F3E3F7"), LILAC)])
        cup(kit, Vector(t) + Vector((0, 0, 0.15)), Vector((kit.rng.uniform(-0.3, 0.3), kit.rng.uniform(-0.3, 0.3), 1.0)),
            0.62, 6, 2 if near else 1, cols[0], cols[1], BUTTER if near else None, 0.6, openness=0.15)


# -------------------------------------------------------------- shrubs ----

def peony_bush(kit, near):
    c, R, sq = (0, 0, 0.42), 0.55, 0.78
    dome(kit, c, R, BUSH, BUSH_DEEP, near)
    for _ in range(9 if near else 4):
        p, n = on_dome(kit, c, R * 0.98, sq)
        cols = kit.rng.choice([(BLUSH, ROSE), (PEARL, BLUSH), (ROSE, HOT_PINK), (hexc("FBE3EC"), CORAL)])
        cup(kit, p, n + Vector((0, 0, 0.8)), 0.23, 7 if near else 5, 2, cols[0], cols[1], BUTTER, 0.4, 0.35)


def hydrangea(kit, near):
    c, R, sq = (0, 0, 0.45), 0.55, 0.8
    dome(kit, c, R, BUSH, BUSH_DEEP, near)
    combos = [(PERI, LILAC), (BLUSH, ROSE), (SKY, PERI), (hexc("E3CCF5"), BLUSH)]
    base = kit.rng.randrange(len(combos))
    n = 5 if near else 3
    for i in range(n):
        a = math.tau * i / n + kit.rng.uniform(-0.3, 0.3)
        p, nn = on_dome(kit, c, R * 0.92, sq, 0.75 if i else 1.5)
        if i:
            p = Vector(c) + Vector((math.cos(a) * R * 0.7, math.sin(a) * R * 0.7, R * sq * 0.65))
        ca, cb = combos[(base + i // 3) % len(combos)]
        pom(kit, p, 0.27, ca, cb, 0.4, subdiv=1, squash=0.85, lump=0.18)


def azalea(kit, near):
    c, R, sq = (0, 0, 0.32), 0.6, 0.68
    dome(kit, c, R, BUSH, BUSH_DEEP, near, blobs=1, subdiv=2)
    cols = kit.rng.choice([(HOT_PINK, PEARL), (ROSE, PEARL), (hexc("F58BB8"), BUTTER)])
    for _ in range(36 if near else 16):
        p, n = on_dome(kit, c, R * 1.02, sq, kit.rng.uniform(0.15, 1.5))
        fan(kit, p, n, 5, 0.12, cols[0], cols[1], 0.4, notch=0.62, tip=shade(cols[0], 1.08))


def lavender_mound(kit, near):
    kit.blob(Vector((0, 0, 0.15)), 0.4, 0.5, SAGE, BUSH_DEEP, 1, 0.2, lump=0.2)
    for _ in range(8 if near else 4):
        b = scatter_disc(kit, 0.3) + Vector((0, 0, 0.15))
        spike(kit, b, kit.rng.uniform(0.45, 0.7), 0.05, 3 if near else 2, AMETHYST, LILAC, 0.2)


def iris_clump(kit, near):
    """Canon amethyst irises: sword leaves and frilled flowers with gold beards."""
    for _ in range(10 if near else 5):
        b = scatter_disc(kit, 0.18)
        blade(kit, b, kit.rng.uniform(0.45, 0.75), 0.035, Vector((kit.rng.uniform(-0.15, 0.15), kit.rng.uniform(-0.15, 0.15), 0)),
              LEAF_DEEP, MINT, 0.0, 0.8)
    for _ in range(6 if near else 3):
        b = scatter_disc(kit, 0.15)
        h = kit.rng.uniform(0.6, 0.85)
        top = b + Vector((0, 0, h))
        stem(kit, b, top, 0.01, LEAF, 0.0, 0.8)
        col = kit.rng.choice([AMETHYST, LILAC, PERI, hexc("F3E3F7")])
        for k in range(3):
            a = math.tau * k / 3 + kit.rng.random()
            d = Vector((math.cos(a), math.sin(a), 0))
            # Fall: droops out and down; standard: stands up.
            leaf(kit, top, d + Vector((0, 0, -0.5)), 0.13, 0.05, GOLD, col, 0.9, 1.0)
            leaf(kit, top, d * 0.4 + Vector((0, 0, 1.0)), 0.12, 0.04, col, shade(col, 1.1), 0.9, 1.0)


def goldenrod(kit, near):
    for _ in range(5 if near else 3):
        b = scatter_disc(kit, 0.25)
        spike(kit, b, kit.rng.uniform(0.6, 0.95), 0.06, 3 if near else 2, GOLD, BUTTER, 0.0)
        leaf(kit, b + Vector((0, 0, 0.2)), yaw_vec(kit) + Vector((0, 0, 0.3)), 0.16, 0.03, LEAF_DEEP, LEAF, 0.2, 0.4)


def lupin_clump(kit, near):
    for _ in range(5 if near else 3):
        b = scatter_disc(kit, 0.2) + Vector((0, 0, 0.12))
        for k in range(5):
            a = math.tau * k / 5
            leaf(kit, b, Vector((math.cos(a), math.sin(a), 0.15)), 0.12, 0.025, LEAF_DEEP, LEAF, 0.1, 0.3)
    for _ in range(5 if near else 3):
        b = scatter_disc(kit, 0.2)
        c0, c1 = kit.rng.choice([(HOT_PINK, BLUSH), (AMETHYST, LILAC), (PERI_DEEP, PERI), (ROSE, PEARL), (APRICOT, BUTTER)])
        spike(kit, b, kit.rng.uniform(0.7, 1.0), 0.075, 4 if near else 2, c0, c1, 0.0)


def sugarberry_bush(kit, near):
    c, R, sq = (0, 0, 0.45), 0.6, 0.8
    dome(kit, c, R, BUSH, BUSH_DEEP, near, blobs=1, subdiv=2)
    for _ in range(15 if near else 6):
        p, n = on_dome(kit, c, R * 1.02, sq, kit.rng.uniform(0.0, 1.4))
        bead(kit, p, 0.075, kit.rng.choice([HOT_PINK, ROSE, PEARL, GOLD, RASPBERRY]), 0.4)
    for _ in range(4 if near else 2):
        p, n = on_dome(kit, c, R * 1.02, sq)
        fan(kit, p, n, 5, 0.09, PEARL, GOLD, 0.4)


def _rose_bush(kit, near, roses):
    c, R, sq = (0, 0, 0.45), 0.55, 0.82
    dome(kit, c, R, BUSH, BUSH_DEEP, near)
    for _ in range(12 if near else 5):
        p, n = on_dome(kit, c, R * 0.98, sq)
        col = kit.rng.choice(roses)
        cup(kit, p, n + Vector((0, 0, 0.5)), 0.17, 5, 3 if near else 2, col[0], col[1], None, 0.4, openness=0.45)


def rose_bush_red(kit, near):
    _rose_bush(kit, near, [(RASPBERRY, hexc("C83E64")), (HOT_PINK, RASPBERRY), (ROSE, RASPBERRY)])


def rose_bush_white(kit, near):
    _rose_bush(kit, near, [(PEARL, BLUSH), (PEARL, BUTTER), (hexc("FFF4F7"), ROSE)])


def honeysuckle_bush(kit, near):
    c, R, sq = (0, 0, 0.42), 0.55, 0.78
    dome(kit, c, R, BUSH, BUSH_DEEP, near)
    for _ in range(16 if near else 6):
        p, n = on_dome(kit, c, R * 0.98, sq)
        for k in range(3):
            d = n + Vector((kit.rng.uniform(-0.6, 0.6), kit.rng.uniform(-0.6, 0.6), 0.3))
            bell(kit, p, d, 0.05, 0.16, kit.rng.choice([BUTTER, PEARL, BLUSH]), APRICOT, 0.4, sides=5)


def hazel(kit, near):
    tops = []
    for _ in range(6 if near else 4):
        to = Vector((kit.rng.uniform(-0.7, 0.7), kit.rng.uniform(-0.7, 0.7), kit.rng.uniform(2.0, 2.9)))
        kit.tube([Vector((0, 0, 0)), to * 0.5, to], [0.05, 0.035, 0.02], 4, BARK, BARK, 0.0, 0.35)
        tops.append(to)
    for t in tops[:5] if near else tops[:3]:
        kit.blob(t, 0.6, 0.72, BUSH, BUSH_DEEP, 1, 0.4, lump=0.14)
    for _ in range(8 if near else 3):
        t = Vector(kit.rng.choice(tops)) + Vector((kit.rng.uniform(-0.5, 0.5), kit.rng.uniform(-0.5, 0.5), -0.35))
        raceme(kit, t, 0.2, 0.035, BUTTER, GOLD, 0.6, sides=3, segs=2)


def bramble(kit, near):
    dome(kit, (0, 0, 0.35), 0.55, BUSH, BUSH_DEEP, near, blobs=2, squash=0.6)
    for _ in range(6 if near else 3):
        a = kit.rng.random() * math.tau
        d = Vector((math.cos(a), math.sin(a), 1.2))
        line = branch_line(kit, (0, 0, 0.1), d, 1.0, 3 if near else 2, droop=0.5)
        kit.tube(line, taper(len(line), 0.025, 0.01), 3, hexc("8E5A6E"), hexc("B9798F"), 0.1, 0.6)
    for _ in range(8 if near else 3):
        p, n = on_dome(kit, (0, 0, 0.35), 0.58, 0.6)
        fan(kit, p, n, 5, 0.06, PEARL, GOLD, 0.4, tip=BLUSH)
    for _ in range(7 if near else 3):
        p, n = on_dome(kit, (0, 0, 0.35), 0.58, 0.6)
        bead(kit, p, 0.045, kit.rng.choice([BERRY, RASPBERRY, HOT_PINK]), 0.4)


def _frond(kit, base, direction, length, c0, c1, leaflets, rise=0.9, curl=0.35):
    """An arching frond: a spine that rises then droops, with paired
    rounded leaflets that shrink toward a curled tip."""
    d = Vector(direction).normalized()
    pts = [Vector(base)]
    for i in range(leaflets):
        k = (i + 1) / leaflets
        pts.append(pts[-1] + d * length / leaflets + Vector((0, 0, length / leaflets * (rise - curl * 3.0 * k))))
    side = d.cross(Vector((0, 0, 1))).normalized()
    for i in range(1, len(pts)):
        k = i / len(pts)
        c = mix(c0, c1, k)
        f = 0.2 + 0.8 * k
        ln = length * 0.3 * (1.0 - 0.65 * k)
        for sgn in (1, -1):
            leaf(kit, pts[i - 1] + (pts[i] - pts[i - 1]) * 0.5, side * sgn + d * 0.35 + Vector((0, 0, 0.15)), ln, ln * 0.38,
                 mix(c0, c1, k * 0.7), c, f, f + 0.1)
    stem(kit, pts[0], pts[-1], 0.008, c0, 0.0, 1.0)


def fern(kit, near):
    for i in range(8 if near else 4):
        a = math.tau * i / 8 + kit.rng.uniform(-0.2, 0.2)
        _frond(kit, (0, 0, 0.02), (math.cos(a), math.sin(a), 0.0), kit.rng.uniform(0.6, 0.85), BUSH_DEEP, GRASS_TIP,
               6 if near else 3)
    if near:  # a curled fiddlehead or two: cute
        for _ in range(2):
            bead(kit, scatter_disc(kit, 0.1) + Vector((0, 0, 0.3)), 0.045, MINT, 0.5)


def bracken(kit, near):
    for i in range(6 if near else 3):
        a = math.tau * i / 6 + kit.rng.uniform(-0.3, 0.3)
        _frond(kit, scatter_disc(kit, 0.15), (math.cos(a), math.sin(a), 0.0), kit.rng.uniform(0.75, 0.95), GRASS_DEEP,
               hexc("C9E59A"), 6 if near else 3, rise=1.6, curl=0.4)


def foxglove(kit, near):
    for i in range(7 if near else 3):
        leaf(kit, (0, 0, 0.02), yaw_vec(kit) + Vector((0, 0, 0.25)), 0.32, 0.09, LEAF_DEEP, LEAF, 0.0, 0.2)
    for s in range(4 if near else 2):
        b = scatter_disc(kit, 0.2)
        h = kit.rng.uniform(0.95, 1.3)
        stem(kit, b, b + Vector((0, 0, h)), 0.018, LEAF, 0.0, 1.0)
        col = [HOT_PINK, LILAC, PEARL, BLUSH][s % 4]
        inner = shade(mix(col, BERRY, 0.45), 0.85)
        nb = 11 if near else 5
        for k in range(nb):
            t = 0.38 + 0.6 * k / nb
            a = kit.rng.random() * math.tau
            p = b + Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, h * t))
            bell(kit, p, Vector((math.cos(a), math.sin(a), -0.5)), 0.07 * (1.15 - 0.5 * t), 0.13 * (1.1 - 0.4 * t),
                 col, inner, 0.4 + 0.6 * t, sides=5)


def moss_mound(kit, near):
    c, R, sq = (0, 0, 0.0), 0.55, 0.5
    kit.blob(Vector(c), R, sq, hexc("A6D79A"), LEAF_DEEP, 2 if near else 1, 0.05, lump=0.12)
    for _ in range(14 if near else 5):
        p, n = on_dome(kit, c, R * 1.02, sq, kit.rng.uniform(0.5, 1.5))
        fan(kit, p, n, 5, 0.06, kit.rng.choice([PEARL, PEARL, BLUSH, BUTTER]), GOLD, 0.1, notch=0.55)


# ------------------------------------------------------- ground flowers ----

def _stems_with(kit, count, spread, h, fn, near):
    for _ in range(count if near else max(1, count // 2)):
        b = scatter_disc(kit, spread)
        hh = kit.rng.uniform(*h)
        top = b + Vector((kit.rng.uniform(-0.03, 0.03), kit.rng.uniform(-0.03, 0.03), hh))
        stem(kit, b, top, 0.006, GRASS, 0.0, 0.9)
        fn(top)


def grass_tuft(kit, near):
    """Fine, soft tufts: many thin blades, deep green at the root to a
    sunny tip (R3: lush, never lime, never teal)."""
    for _ in range(11 if near else 5):
        b = scatter_disc(kit, 0.12)
        blade(kit, b, kit.rng.uniform(0.16, 0.3), 0.012, Vector((kit.rng.uniform(-0.08, 0.08), kit.rng.uniform(-0.08, 0.08), 0)),
              GRASS_DEEP, kit.rng.choice([GRASS, GRASS_TIP, hexc("C6EBB5")]))


def tall_grass(kit, near):
    for _ in range(12 if near else 6):
        b = scatter_disc(kit, 0.18)
        blade(kit, b, kit.rng.uniform(0.38, 0.62), 0.012, Vector((kit.rng.uniform(-0.15, 0.15), kit.rng.uniform(-0.15, 0.15), 0)),
              GRASS_DEEP, kit.rng.choice([GRASS_TIP, hexc("E3E7A6"), GRASS]))
    if near:
        for _ in range(2):  # a soft seed head
            bead(kit, scatter_disc(kit, 0.12) + Vector((0, 0, 0.55)), 0.022, BUTTER, 1.0, squash=1.8)


def clover(kit, near):
    for _ in range(6 if near else 3):
        b = scatter_disc(kit, 0.16) + Vector((0, 0, 0.04))
        for k in range(3):
            a = math.tau * k / 3 + kit.rng.random()
            leaf(kit, b, (math.cos(a), math.sin(a), 0.1), 0.05, 0.025, GRASS, MINT, 0.3, 0.4)
    for _ in range(2 if near else 1):
        b = scatter_disc(kit, 0.12)
        stem(kit, b, b + Vector((0, 0, 0.1)), 0.005, GRASS, 0.0, 0.6)
        pom(kit, b + Vector((0, 0, 0.13)), 0.042, BLUSH, ROSE, 0.6, subdiv=0)


def bluebell(kit, near):
    for _ in range(4 if near else 2):
        b = scatter_disc(kit, 0.14)
        blade(kit, b, 0.18, 0.02, (0.08, 0, 0), GRASS_DEEP, GRASS, 0.0, 0.5)
    for _ in range(4 if near else 2):
        b = scatter_disc(kit, 0.12)
        h = kit.rng.uniform(0.24, 0.34)
        d = yaw_vec(kit)
        top = b + Vector((0, 0, h)) + d * 0.06
        stem(kit, b, b + Vector((0, 0, h * 0.7)), 0.005, GRASS, 0.0, 0.6)
        stem(kit, b + Vector((0, 0, h * 0.7)), top, 0.004, GRASS, 0.6, 1.0)
        for k in range(4):
            p = top - d * 0.03 * k + Vector((0, 0, -0.05 * k))
            bell(kit, p, Vector((d.x * 0.2, d.y * 0.2, -1.0)), 0.035, 0.065, kit.rng.choice([PERI, PERI_DEEP, LILAC]),
                 shade(PERI_DEEP, 0.8), 1.0, sides=5)


def crocus(kit, near):
    for _ in range(5 if near else 3):
        b = scatter_disc(kit, 0.12)
        c = kit.rng.choice([(LILAC, PEARL), (AMETHYST, LILAC), (BUTTER, SUNNY), (PEARL, LILAC)])
        stem(kit, b, b + Vector((0, 0, 0.07)), 0.006, GRASS, 0.0, 0.6)
        cup(kit, b + Vector((0, 0, 0.07)), (0, 0, 1), 0.065, 6, 1, c[0], c[1], None, 0.7, openness=0.3)
    for _ in range(3 if near else 1):
        blade(kit, scatter_disc(kit, 0.1), 0.12, 0.008, (0, 0, 0), GRASS_DEEP, GRASS, 0.0, 0.5)


def snowdrop(kit, near):
    for _ in range(5 if near else 3):
        b = scatter_disc(kit, 0.1)
        h = kit.rng.uniform(0.12, 0.18)
        d = yaw_vec(kit)
        stem(kit, b, b + Vector((0, 0, h)) + d * 0.02, 0.004, GRASS, 0.0, 0.9)
        p = b + Vector((0, 0, h)) + d * 0.03
        for k in range(3):
            a = math.tau * k / 3
            leaf(kit, p, (math.cos(a) * 0.5, math.sin(a) * 0.5, -1.0), 0.065, 0.024, MINT, PEARL, 0.9, 1.0)
    blade(kit, (0, 0, 0), 0.14, 0.01, (0.03, 0, 0), GRASS_DEEP, GRASS, 0.0, 0.5)


def primrose(kit, near):
    for k in range(6 if near else 3):
        a = math.tau * k / 6
        leaf(kit, (0, 0, 0.01), (math.cos(a), math.sin(a), 0.2), 0.12, 0.045, GRASS_DEEP, GRASS, 0.0, 0.2)
    for _ in range(5 if near else 3):
        p = scatter_disc(kit, 0.07) + Vector((0, 0, kit.rng.uniform(0.07, 0.1)))
        fan(kit, p, (kit.rng.uniform(-0.3, 0.3), kit.rng.uniform(-0.3, 0.3), 1.0), 5, 0.05,
            kit.rng.choice([BUTTER, BLUSH, PEARL]), APRICOT, 0.5, notch=0.7)


def violet(kit, near):
    for k in range(5 if near else 2):
        a = math.tau * k / 5
        leaf(kit, (0, 0, 0.01), (math.cos(a), math.sin(a), 0.4), 0.07, 0.04, GRASS_DEEP, GRASS, 0.0, 0.2)
    for _ in range(5 if near else 3):
        p = scatter_disc(kit, 0.09) + Vector((0, 0, kit.rng.uniform(0.07, 0.1)))
        fan(kit, p, (kit.rng.uniform(-0.6, 0.6), kit.rng.uniform(-0.6, 0.6), 0.6), 5, 0.045,
            kit.rng.choice([AMETHYST, LILAC, PERI]), BUTTER, 0.6, notch=0.75, tip=PEARL)


def buttercup(kit, near):
    _stems_with(kit, 6, 0.16, (0.14, 0.26),
                lambda t: cup(kit, t, (0, 0, 1), 0.05, 5, 1, SUNNY, BUTTER, None, 0.9, openness=0.6), near)


def daisy(kit, near):
    for _ in range(7 if near else 3):
        p = scatter_disc(kit, 0.16) + Vector((0, 0, kit.rng.uniform(0.04, 0.1)))
        fan(kit, p, (kit.rng.uniform(-0.3, 0.3), kit.rng.uniform(-0.3, 0.3), 1.0), 8, 0.045, PEARL, GOLD, 0.6,
            notch=0.5, tip=kit.rng.choice([PEARL, BLUSH, ROSE]))


def wood_anemone(kit, near):
    for _ in range(3 if near else 1):
        leaf(kit, scatter_disc(kit, 0.08) + Vector((0, 0, 0.08)), yaw_vec(kit), 0.06, 0.03, GRASS_DEEP, GRASS, 0.4, 0.6)
    _stems_with(kit, 5, 0.13, (0.1, 0.17),
                lambda t: fan(kit, t, (0, 0, 1), 6, 0.045, PEARL, BUTTER, 0.9, notch=0.6, tip=BLUSH), near)


def cowslip(kit, near):
    for k in range(4 if near else 2):
        a = math.tau * k / 4
        leaf(kit, (0, 0, 0.01), (math.cos(a), math.sin(a), 0.2), 0.12, 0.04, GRASS_DEEP, GRASS, 0.0, 0.2)

    def umbel(t):
        for k in range(4):
            a = math.tau * k / 4
            bell(kit, t, (math.cos(a) * 0.6, math.sin(a) * 0.6, -0.7), 0.026, 0.055, SUNNY, APRICOT, 0.9, sides=4)
    _stems_with(kit, 3, 0.08, (0.16, 0.24), umbel, near)


def tulip_patch(kit, near):
    for _ in range(5 if near else 3):
        b = scatter_disc(kit, 0.16)
        h = kit.rng.uniform(0.18, 0.28)
        top = b + Vector((kit.rng.uniform(-0.03, 0.03), kit.rng.uniform(-0.03, 0.03), h))
        stem(kit, b, top, 0.007, GRASS, 0.0, 0.8)
        leaf(kit, b, yaw_vec(kit) + Vector((0, 0, 1.6)), 0.16, 0.03, GRASS_DEEP, GRASS, 0.0, 0.4)
        c, tip = kit.rng.choice([(ROSE, BLUSH), (HOT_PINK, ROSE), (BUTTER, PEARL), (PEARL, BLUSH), (LILAC, PEARL), (CORAL, BUTTER)])
        tulip(kit, top, 0.07, 0.12, c, tip, 0.9, sides=6 if near else 4)


def daffodil(kit, near):
    for _ in range(4 if near else 2):
        blade(kit, scatter_disc(kit, 0.1), 0.26, 0.012, (0.04, 0, 0), GRASS_DEEP, GRASS, 0.0, 0.5)

    def head(t):
        d = yaw_vec(kit) * 0.8 + Vector((0, 0, 0.4))
        fan(kit, t, d, 6, 0.08, BUTTER, BUTTER, 0.9, notch=0.55, tip=PEARL)
        bell(kit, t + d.normalized() * 0.06, -d, 0.035, 0.06, APRICOT, GOLD, 0.9, sides=6)
    _stems_with(kit, 3, 0.1, (0.2, 0.3), head, near)


def maidens_lace(kit, near):
    def umbel(t):
        for k in range(6):
            a = math.tau * k / 6
            p = t + Vector((math.cos(a) * 0.07, math.sin(a) * 0.07, -0.015))
            fan(kit, p, (0, 0, 1), 4, 0.036, PEARL, BLUSH, 1.0, notch=0.6)
    _stems_with(kit, 3, 0.15, (0.3, 0.42), umbel, near)
    leaf(kit, (0, 0, 0.02), yaw_vec(kit), 0.12, 0.04, GRASS_DEEP, GRASS, 0.0, 0.3)


def forget_me_not(kit, near):
    for _ in range(3 if near else 1):
        leaf(kit, scatter_disc(kit, 0.08), yaw_vec(kit) + Vector((0, 0, 0.4)), 0.08, 0.025, GRASS_DEEP, GRASS, 0.0, 0.3)
    for _ in range(11 if near else 5):
        p = scatter_disc(kit, 0.15) + Vector((0, 0, kit.rng.uniform(0.07, 0.15)))
        fan(kit, p, (kit.rng.uniform(-0.4, 0.4), kit.rng.uniform(-0.4, 0.4), 1.0), 5, 0.03,
            kit.rng.choice([SKY, PERI, SKY, BLUSH]), BUTTER, 0.7, notch=0.75)


def allium(kit, near):
    for _ in range(2 if near else 1):
        b = scatter_disc(kit, 0.1)
        h = kit.rng.uniform(0.35, 0.5)
        stem(kit, b, b + Vector((0, 0, h)), 0.007, GRASS, 0.0, 0.9)
        ca, cb = kit.rng.choice([(LILAC, AMETHYST), (BLUSH, LILAC), (PEARL, LILAC)])
        pom(kit, b + Vector((0, 0, h + 0.08)), 0.1, ca, cb, 1.0, subdiv=1 if near else 0, lump=0.05)


def pansy_patch(kit, near):
    for k in range(4 if near else 2):
        a = math.tau * k / 4
        leaf(kit, (0, 0, 0.01), (math.cos(a), math.sin(a), 0.3), 0.08, 0.04, GRASS_DEEP, GRASS, 0.0, 0.2)
    for _ in range(5 if near else 2):
        p = scatter_disc(kit, 0.1) + Vector((0, 0, kit.rng.uniform(0.07, 0.11)))
        face_col, eye = kit.rng.choice([(AMETHYST, BUTTER), (BUTTER, AMETHYST), (BLUSH, HOT_PINK), (PERI, PEARL), (PEARL, LILAC)])
        n = Vector((kit.rng.uniform(-0.5, 0.5), kit.rng.uniform(-0.5, 0.5), 0.7))
        fan(kit, p, n, 5, 0.06, face_col, eye, 0.6, notch=0.8, tip=shade(face_col, 1.08))


# ---------------------------------------------------------------- table ----

TREE, SHRUB, FLOWER = (3000, 1500), (700, 400), (180, 100)

SPECIES = {
    # New trees
    "candyfloss_tree": (candyfloss_tree, TREE),
    "wisteria_tree": (wisteria_tree, TREE),
    "golden_chain": (golden_chain, TREE),
    "magnolia": (magnolia, TREE),
    # New shrubs
    "peony_bush": (peony_bush, SHRUB),
    "hydrangea": (hydrangea, SHRUB),
    "azalea": (azalea, SHRUB),
    "lavender_mound": (lavender_mound, SHRUB),
    "iris_clump": (iris_clump, SHRUB),
    "goldenrod": (goldenrod, SHRUB),
    "lupin_clump": (lupin_clump, SHRUB),
    "sugarberry_bush": (sugarberry_bush, SHRUB),
    # Blender versions of procedural shrubs
    "rose_bush_red": (rose_bush_red, SHRUB),
    "rose_bush_white": (rose_bush_white, SHRUB),
    "honeysuckle_bush": (honeysuckle_bush, SHRUB),
    "hazel": (hazel, SHRUB),
    "bramble": (bramble, SHRUB),
    "fern": (fern, SHRUB),
    "bracken": (bracken, SHRUB),
    "foxglove": (foxglove, SHRUB),
    "moss_mound": (moss_mound, SHRUB),
    # New ground flowers
    "tulip_patch": (tulip_patch, FLOWER),
    "daffodil": (daffodil, FLOWER),
    "maidens_lace": (maidens_lace, FLOWER),
    "forget_me_not": (forget_me_not, FLOWER),
    "allium": (allium, FLOWER),
    "pansy_patch": (pansy_patch, FLOWER),
    # Blender versions of procedural ground cover
    "grass_tuft": (grass_tuft, FLOWER),
    "tall_grass": (tall_grass, FLOWER),
    "clover": (clover, FLOWER),
    "bluebell": (bluebell, FLOWER),
    "crocus": (crocus, FLOWER),
    "snowdrop": (snowdrop, FLOWER),
    "primrose": (primrose, FLOWER),
    "violet": (violet, FLOWER),
    "buttercup": (buttercup, FLOWER),
    "daisy": (daisy, FLOWER),
    "wood_anemone": (wood_anemone, FLOWER),
    "cowslip": (cowslip, FLOWER),
}


def main():
    wt.OUT = OUT
    os.makedirs(OUT, exist_ok=True)
    only = [a for a in sys.argv[1:] if a in SPECIES] or list(SPECIES)
    for species in only:
        fn, (near_cap, far_cap) = SPECIES[species]
        wt.build(species, fn, near_cap, far_cap)


if __name__ == "__main__":
    main()
