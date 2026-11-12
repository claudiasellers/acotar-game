"""The woods' special trees, one at a time (owner, 2026-11-12: "these are
special"): the candy flowering trees of spring_flora.py rebuilt with more
care. Headless bpy, deterministic; the same output and vertex conventions as
spring_flora.py (near and far objects in world/spring_court/shared/models/
<species>.glb; COLOR_0 sRGB albedo, UV0.x wind flex, UV0.y glow), so
FloraLibrary draws them wherever the old ones grew.

Run:  <bpy python> tools/woods/blender/special_trees.py [out_dir] [species ...]

Budgets: near <= 6,000 triangles (the estate trees' budget; these are
planted sparsely), far <= 1,500.

magnolia   A saucer magnolia in full flower on bare pearl wood: a short
           trunk opening into a vase of limbs that sweep out and turn up
           like a candelabra, every twig ending in a flower that stands
           upright. Open stars of nine petals at the top of the crown,
           goblets below them, pointed buds on the spurs along the limbs.
           Each petal is rose at its foot, blush, then pearl at its tip.
candyfloss_tree
           One tall cone of candyfloss on a straight pearl-rose trunk: a
           heap of soft billows, big low down and small toward the tip, with
           a fuzz standing off them, and a few star blossoms resting on top.
           The shader colours it from where it stands: most trees one
           colour (blush, rose, lilac or pearl), some with a different
           colour to each of nine tufts.
wisteria_tree
           An old wisteria grown as a parasol: two stems twined round each
           other, limbs arching out level and dipping at the rim, and a
           curtain of long flower chains hanging from them, each a string of
           small florets, pale where they have opened at the top and deep
           violet in the bud at the tip. Young leaves and a few star
           blossoms lie on top of the limbs.
magnolia_harlequin
           The same tree with every flower its own candy colour (rose,
           coral, lilac, periwinkle, apricot, mint, hot pink) and a heart of
           petals in another standing up out of the cup.
"""

import math
import random
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402,F401
from mathutils import Vector  # noqa: E402

import woods_trees as wt  # noqa: E402
from woods_trees import hexc, mix, taper  # noqa: E402
import spring_flora as sf  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 and "/" in sys.argv[1] else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "world", "spring_court", "shared", "models")

SPECIAL = (6000, 1500)
UP = Vector((0.0, 0.0, 1.0))

PEARL_WOOD = hexc("E8DCE0")
MAUVE_WOOD = hexc("A88E96")
TWIG = hexc("D9C6CF")


def sweep(kit, base, heading, rise0, rise1, length, segs, wander=0.1):
    """A limb's line: it leaves `base` along `heading` (a flat unit vector)
    at rise0 degrees above level and turns up to rise1 by its tip."""
    pts = [Vector(base)]
    h = Vector(heading).normalized()
    for i in range(segs):
        t = (i + 0.5) / segs
        rise = math.radians(rise0 + (rise1 - rise0) * t ** 0.8)
        turn = kit.rng.uniform(-wander, wander)
        h = (h + Vector((-h.y, h.x, 0.0)) * turn).normalized()
        pts.append(pts[-1] + (h * math.cos(rise) + UP * math.sin(rise)) * (length / segs))
    return pts


def at(line, t):
    """The point a share t along a polyline (by segment count)."""
    f = t * (len(line) - 1)
    i = min(int(f), len(line) - 2)
    return line[i] + (line[i + 1] - line[i]) * (f - i)


def flat(v):
    f = Vector((v.x, v.y, 0.0))
    return f.normalized() if f.length > 1e-4 else Vector((1.0, 0.0, 0.0))


def petal(kit, centre, axis, out, length, width, tilt, cup, cols, flex, rows):
    """One petal of a flower on `axis` at `centre`, leaning `tilt` degrees out
    toward `out` at its foot and curling back toward the axis by `cup` of
    that along its length. Narrow foot, broad shoulder, pointed tip; its
    edges lifted so it is spooned. Smooth, with normals that follow the
    flower's roundness so both faces take the light alike."""
    side = axis.cross(out).normalized()
    spine = [centre + out * width * 0.18]
    for r in range(rows):
        t = (r + 0.5) / rows
        a = math.radians(tilt * (1.0 - cup * t))
        spine.append(spine[-1] + (axis * math.cos(a) + out * math.sin(a)) * (length / rows))
    ring = []
    for r in range(rows + 1):
        t = r / rows
        p = spine[r]
        if r == rows:
            ring.append([kit.add_vert(p)])
        else:
            # narrow foot, full shoulder at about 0.55, easing in to the tip
            w = width * (0.2 + 0.8 * math.sin(math.pi * min(t / 0.55, 1.0) * 0.5)) * (1.0 if t < 0.55 else math.cos((t - 0.55) / 0.45 * math.pi * 0.42))
            inward = (centre + axis * (p - centre).dot(axis) - p)
            inward = inward.normalized() if inward.length > 1e-4 else -out
            lift = inward * w * 0.2
            ring.append([kit.add_vert(p - side * w + lift), kit.add_vert(p), kit.add_vert(p + side * w + lift)])
        col = mix(cols[0], cols[1], t / 0.5) if t < 0.5 else mix(cols[1], cols[2], (t - 0.5) / 0.5)
        for v in ring[-1]:
            n = (kit.verts[v] - centre)
            n = n.normalized() if n.length > 1e-4 else axis
            # round the flower: lit on top, soft shade under the cup where the rose shows
            kit.normals[v] = (n * 0.85 + axis * 0.22).normalized()
        ring[-1] = (ring[-1], col, flex + 0.05 * t)
    for r in range(rows):
        (a, ca, fa), (b, cb, fb) = ring[r], ring[r + 1]
        if len(b) == 3:
            for k in range(2):
                kit.face((a[k], a[k + 1], b[k + 1]), (ca, ca, cb), ((fa, 0), (fa, 0), (fb, 0)))
                kit.face((a[k], b[k + 1], b[k]), (ca, cb, cb), ((fa, 0), (fb, 0), (fb, 0)))
        else:
            for k in range(2):
                kit.face((a[k], a[k + 1], b[0]), (ca, ca, cb), ((fa, 0), (fa, 0), (fb, 0)))


def heart(kit, centre, axis, r, h, col, flex):
    """The flower's heart: a small gold cone in a five-pointed gold star."""
    side = axis.orthogonal().normalized()
    fwd = axis.cross(side).normalized()
    tip = kit.add_vert(centre + axis * h)
    kit.normals[tip] = axis.copy()
    base = []
    for k in range(5):
        a = math.tau * k / 5
        d = side * math.cos(a) + fwd * math.sin(a)
        v = kit.add_vert(centre + d * r)
        kit.normals[v] = (d + axis * 0.4).normalized()
        base.append(v)
    for k in range(5):
        kit.face((base[k], base[(k + 1) % 5], tip), (wt.shade(col, 0.85), wt.shade(col, 0.85), col), ((flex, 0),) * 3)
    for k in range(5):
        a = math.tau * (k + 0.5) / 5
        d = side * math.cos(a) + fwd * math.sin(a)
        point = kit.add_vert(centre + d * r * 3.4 + axis * h * 0.55)
        kit.normals[point] = axis.copy()
        kit.face((base[k], base[(k + 1) % 5], point), (col, col, hexc("FFF3C4")), ((flex, 0),) * 3)


# Petal colours, foot to tip. A flower is (its outer ring, its inner ring).
ROSE_PEARL = [
    ((hexc("E8739A"), hexc("F4A6C0"), hexc("FBE3E6")), (hexc("F6BFD0"), hexc("FBE3E6"), hexc("FBF3EC"))),   # rose foot, pearl tip
    ((hexc("DE6494"), hexc("F2A0BE"), hexc("F9D9E0")), (hexc("F6BFD0"), hexc("FBE3E6"), hexc("FBF3EC"))),   # deeper rose
    ((hexc("EE8AAE"), hexc("F8C3D2"), hexc("FCEDE8")), (hexc("F6BFD0"), hexc("FBE3E6"), hexc("FBF3EC"))),   # blush
    ((hexc("B58FDD"), hexc("D8BDF0"), hexc("F1E4F8")), (hexc("F6BFD0"), hexc("FBE3E6"), hexc("FBF3EC"))),   # a lilac one now and then
]
ROSE_PEARL_ODDS = None   # a lilac flower about one time in seven, see bloom()
BUD = (hexc("D2588F"), hexc("E983AE"), hexc("F4B3CB"))
# The harlequin: every flower its own candy colour, with a heart of petals in
# another standing up out of the cup, as the first magnolia had (owner,
# 2026-11-12: "i liked how the original one was multicolored"). The cup is
# the colour: it is what you see from the ground.
CREAM = (hexc("F3D58C"), hexc("FAE9B4"), hexc("FBF4E2"))
ROSE = (hexc("E8739A"), hexc("F4A6C0"), hexc("FBD9E2"))
CORAL = (hexc("EE7C66"), hexc("F7A08C"), hexc("FBD3C2"))
LILAC = (hexc("A77FDB"), hexc("C8A8E9"), hexc("E9DBF6"))
PERI = (hexc("8F9DEB"), hexc("A7B5F2"), hexc("DCE2FB"))
APRICOT = (hexc("F0B45E"), hexc("F8D28A"), hexc("FBEBC4"))
MINT = (hexc("7FCFAA"), hexc("B5E8CD"), hexc("E6F7EC"))
HOT_PINK = (hexc("E25A8A"), hexc("EE7FB0"), hexc("F9C3D8"))
HARLEQUIN = [(ROSE, CREAM), (CORAL, APRICOT), (LILAC, ROSE), (PERI, LILAC), (APRICOT, CORAL), (MINT, ROSE), (HOT_PINK, CREAM)]
HARLEQUIN_ODDS = [0.17, 0.15, 0.16, 0.15, 0.14, 0.09, 0.14]
GOLD = hexc("F6CF6A")


def bloom(kit, base, axis, size, stage, near, flex, palette, odds):
    """A magnolia flower standing on `axis`: stage 2 an open star (six petals
    spread wide round three upright ones and a gold star heart), 1 a goblet,
    0 a pointed bud. Its colours are one pair from `palette`."""
    axis = axis.normalized()
    side = axis.orthogonal().normalized()
    fwd = axis.cross(side).normalized()
    turn = kit.rng.uniform(0.0, math.tau)
    if palette is ROSE_PEARL:
        # (drawn this way so the rose magnolia stays the tree the owner approved)
        outer, inner = kit.rng.choice(ROSE_PEARL[:3] if kit.rng.random() > 0.14 else ROSE_PEARL[3:])
    else:
        outer, inner = kit.rng.choices(palette, weights=odds)[0]

    def ring(count, offset, length, width, tilt, cup, colours, rows):
        rows = rows if near else 1
        for k in range(count):
            a = turn + offset + math.tau * k / count
            out = side * math.cos(a) + fwd * math.sin(a)
            j = kit.rng.uniform(0.9, 1.1)
            petal(kit, base, axis, out, length * size * j, width * size, tilt * kit.rng.uniform(0.9, 1.1), cup, colours, flex, rows)

    if stage == 2:
        ring(6, 0.0, 0.62, 0.22, 64.0, 0.6, outer, 4)
        if palette is ROSE_PEARL:
            ring(3, math.pi / 6, 0.5, 0.19, 24.0, 0.5, inner, 3)
        else:
            # the heart's petals stand up out of the cup, to show their colour
            ring(3, math.pi / 6, 0.66, 0.2, 17.0, 0.45, inner, 3)
        if near:
            heart(kit, base + axis * 0.03 * size, axis, 0.05 * size, 0.2 * size, GOLD, flex)
    elif stage == 1:
        ring(3, 0.0, 0.58, 0.22, 34.0, 1.0, outer, 3)
        ring(3, math.pi / 3, 0.54, 0.21, 24.0, 1.1, (outer[0], outer[1] if palette is ROSE_PEARL else inner[1], inner[2]), 3)
    elif palette is ROSE_PEARL:
        ring(3, 0.0, 0.4, 0.14, 20.0, 2.0, BUD, 2)
    else:
        # a bud shows the colour its flower will open to
        ring(3, 0.0, 0.4, 0.14, 20.0, 2.0, (wt.shade(outer[0], 0.9), outer[0], outer[1]), 2)


def magnolia(kit, near, palette=ROSE_PEARL, odds=ROSE_PEARL_ODDS):
    trunk_top = Vector((kit.rng.uniform(-0.08, 0.08), kit.rng.uniform(-0.08, 0.08), 1.25))
    trunk = [Vector((0, 0, 0)), trunk_top * 0.5 + Vector((0.03, -0.02, 0)), trunk_top]
    kit.tube(trunk, [0.3, 0.25, 0.22], 8 if near else 5, MAUVE_WOOD, PEARL_WOOD, 0.0, 0.04, flare=0.4 if near else 0.0)
    flowers = []   # (point, axis, share of the way up the crown's order)
    limbs = 5
    start = kit.rng.uniform(0.0, math.tau)
    for i in range(limbs):
        a = start + math.tau * i / limbs + kit.rng.uniform(-0.22, 0.22)
        heading = Vector((math.cos(a), math.sin(a), 0.0))
        base = at(trunk, 0.72 + 0.28 * (i % 2)) if i else trunk_top
        length = kit.rng.uniform(3.3, 3.9)
        limb = sweep(kit, base, heading, kit.rng.uniform(24.0, 36.0), 66.0, length, 5 if near else 3)
        kit.tube(limb, taper(len(limb), 0.17, 0.05), 6 if near else 4, hexc("BFA3AD"), PEARL_WOOD, 0.05, 0.42)
        flowers.append((limb[-1], UP, 1.0))
        # two side branches, alternate sides, each turning up into its own flower
        for k, t in enumerate((0.42, 0.68)):
            p = at(limb, t)
            sideways = Vector((-heading.y, heading.x, 0.0)) * (1 if (i + k) % 2 else -1)
            h2 = (heading * 0.55 + sideways * 0.85).normalized()
            arm = sweep(kit, p, h2, kit.rng.uniform(18.0, 30.0), 70.0, kit.rng.uniform(1.5, 2.0) * (1.0 - 0.25 * k), 4 if near else 2, 0.14)
            kit.tube(arm, taper(len(arm), 0.085 - 0.02 * k, 0.03), 5 if near else 3, PEARL_WOOD, TWIG, 0.2 + 0.1 * k, 0.5)
            flowers.append((arm[-1], UP, 0.55 + 0.2 * k))
            if near or k == 0:
                q = at(arm, 0.5)
                tw = sweep(kit, q, (h2 * 0.3 - sideways * 0.2 + heading * 0.6).normalized(), 40.0, 84.0, 0.75, 2, 0.1)
                kit.tube(tw, taper(len(tw), 0.04, 0.02), 4 if near else 3, TWIG, TWIG, 0.35, 0.55)
                flowers.append((tw[-1], UP, 0.35 + 0.2 * k))
        # the limb's tip forks into two more candles
        for s in (-1, 1):
            p = at(limb, 0.86)
            sideways = Vector((-heading.y, heading.x, 0.0)) * s
            tw = sweep(kit, p, (heading * 0.5 + sideways).normalized(), 30.0, 74.0, kit.rng.uniform(0.7, 0.95), 3 if near else 2, 0.1)
            kit.tube(tw, taper(len(tw), 0.045, 0.02), 4 if near else 3, TWIG, TWIG, 0.38, 0.6)
            flowers.append((tw[-1], UP, 0.85))
        # spurs along the limb: short upright twigs with buds and young goblets
        if near:
            for t in (0.24, 0.55, 0.78):
                p = at(limb, t + kit.rng.uniform(-0.04, 0.04))
                tip = p + UP * kit.rng.uniform(0.28, 0.4) + heading * 0.05
                kit.tube([p, tip], [0.03, 0.018], 4, TWIG, TWIG, 0.1 + 0.3 * t, 0.15 + 0.3 * t)
                flowers.append((tip, UP, 0.12 + 0.2 * t))
    # the leader: the tallest candle, in the middle of the vase
    lead = sweep(kit, trunk_top, Vector((math.cos(start + 0.6), math.sin(start + 0.6), 0.0)), 72.0, 86.0, 3.5, 4 if near else 2, 0.12)
    kit.tube(lead, taper(len(lead), 0.14, 0.035), 6 if near else 4, hexc("BFA3AD"), PEARL_WOOD, 0.05, 0.5)
    flowers.append((lead[-1], UP, 1.0))
    for t, s in ((0.5, 1), (0.74, -1)):
        p = at(lead, t)
        tw = sweep(kit, p, Vector((math.cos(start + 0.6 + s * 1.9), math.sin(start + 0.6 + s * 1.9), 0.0)), 34.0, 82.0, 1.0, 3 if near else 2, 0.1)
        kit.tube(tw, taper(len(tw), 0.05, 0.02), 4 if near else 3, TWIG, TWIG, 0.3, 0.55)
        flowers.append((tw[-1], UP, 0.75))

    # Flowers: open stars at the top and outside of the crown, goblets below, buds on the spurs.
    top = max(p.z for p, _, _ in flowers)
    for p, axis, order in flowers:
        lean = flat(Vector((p.x, p.y, 0.0))) * kit.rng.uniform(0.04, 0.2) + Vector((kit.rng.uniform(-0.08, 0.08), kit.rng.uniform(-0.08, 0.08), 0.0))
        ax = (axis + lean).normalized()
        if order < 0.3:
            stage = 0 if kit.rng.random() < 0.75 else 1
        elif order < 0.6:
            stage = 1 if kit.rng.random() < 0.7 else 2
        else:
            stage = 2 if kit.rng.random() < 0.8 else 1
        size = (1.0 if stage == 2 else 0.9 if stage == 1 else 0.8) * kit.rng.uniform(0.92, 1.12)
        flex = 0.3 + 0.3 * (p.z / top)
        bloom(kit, p + ax * 0.02, ax, size, stage, near, flex, palette, odds)

    # A few young mint leaves low on the limbs: the leaves come after the flowers.
    if near:
        low = sorted(flowers, key=lambda f: f[2])[:8]
        for p, _, _ in low[::2]:
            for k in range(2):
                a = kit.rng.uniform(0.0, math.tau)
                d = Vector((math.cos(a), math.sin(a), kit.rng.uniform(0.5, 0.9)))
                sf.leaf(kit, p - UP * kit.rng.uniform(0.2, 0.32), d, kit.rng.uniform(0.42, 0.55), 0.13, hexc("8FDDB0"), hexc("C9F2D6"), 0.3, 0.45)


def magnolia_harlequin(kit, near):
    magnolia(kit, near, HARLEQUIN, HARLEQUIN_ODDS)


# ------------------------------------------------------ candyfloss tree ----
# Third build, from scratch (owner, 2026-11-12, with a picture of candyfloss
# trees: "remake this from scratch just using the same colors ... almost more
# like this texture"). One tall cone of candyfloss on a straight trunk: a heap
# of soft billows, big low down and small toward the tip, with a second skin
# standing a little off them that the shader cuts into fuzz
# (world/spring_court/shared/woods_floss_fuzz.gdshader). The floss and the
# fuzz are meshes of their own ("near_floss" / "far_floss", "near_fuzz";
# FloraLibrary.FLOSSED) and carry a tone, not
# a colour: the shader gives each tree one of the first tree's colours.

FLOSS_HEIGHT = 7.0     # the cone, foot to tip
FLOSS_FOOT = 2.4       # where it starts up the trunk
FLOSS_RADIUS = 2.3     # at its widest, a quarter of the way up
FUZZ = 1.09            # the fuzz skin stands this far off a billow


def cone(t):
    """The cone's radius (of FLOSS_RADIUS) at height t, 0 foot to 1 tip:
    rounded in under the foot, widest at a quarter, tapering to a soft tip."""
    if t < 0.26:
        return 0.62 + 0.38 * math.sin(math.pi * 0.5 * t / 0.26)
    return 1.0 - 0.78 * ((t - 0.26) / 0.74) ** 1.1


def tuft_pick(lumps, i, tufts):
    """The colour (COLOR.g, one of four) of billow i: its nearest tuft's.
    The shader uses it only on a tree of many colours."""
    return (min(tufts, key=lambda tuft: (tuft[0] - lumps[i][0]).length)[1] + 0.5) / 4.0


def billow(fk, lumps, i, scale, subdiv, fuzz, tufts, like=None):
    """One billow of the heap into kit `fk`: a lumpy ball. Its tone is light
    on top and deep where it meets its neighbours; `scale` > 1 with `fuzz`
    makes its fuzz skin. `like` is the near tree's billows [(centre, radius,
    colour)]: the far tree's few big billows take, face by face, the colour
    of the near billow that stands there, so a tree keeps its colours as the
    step swaps."""
    c, r, seed = lumps[i]
    verts, faces = wt.icosphere(subdiv)
    first = len(fk.faces)
    idx, tones = [], []
    pick = tuft_pick(lumps, i, tufts)
    spots = []
    # no two billows the same: each a little squashed its own way, and lumpy
    squash = Vector((0.9 + 0.2 * (seed.x % 1.0), 0.9 + 0.2 * (seed.y % 1.0), 0.86 + 0.2 * (seed.z % 1.0)))
    for v in verts:
        rr = r * scale * (1.0 + 0.2 * wt.noise.noise(v * 1.3 + seed))
        p = c + Vector((v.x * squash.x, v.y * squash.y, v.z * squash.z)) * rr
        idx.append(fk.add_vert(p))
        spots.append(p)
        fk.normals[idx[-1]] = v.copy()
        # deep in the creases: how far this point is from the nearest neighbour's skin
        gap = min(((p - oc).length - orad * scale) / r for j, (oc, orad, _) in enumerate(lumps) if j != i)
        crease = min(max(gap / 0.32, 0.0), 1.0)
        tone = (0.3 + 0.7 * (0.5 + 0.5 * v.z) ** 0.9) * (0.42 + 0.58 * crease)
        tones.append(min(1.0, tone + (0.04 if fuzz else 0.0)))
    flex = 0.16 + 0.3 * min(1.0, max(0.0, (c.z - FLOSS_FOOT) / FLOSS_HEIGHT))
    for f in faces:
        if like:
            mid = (spots[f[0]] + spots[f[1]] + spots[f[2]]) / 3.0
            pick = min(like, key=lambda b: (mid - b[0]).length - b[1])[2]
        fk.face(tuple(idx[k] for k in f), tuple((tones[k], pick, 0.0) for k in f), tuple((flex, 1.0 if fuzz else 0.0) for _ in f))
    fk.blobs.append((c, r * scale * 0.9, 0.95, 0.2, first, len(fk.faces)))


TUFTS = 9
NEAR_BILLOWS = []   # the near tree's outer billows, kept for the far tree's colours


def floss_tufts():
    """[(place on the cone, colour 0..3)]: a spiral up the cone, no tuft the
    colour of the one below it, the same for every build of the tree."""
    rng = random.Random(1907)
    tufts, last = [], -1
    bag = []
    for k in range(TUFTS):
        if not bag:
            bag = [0, 1, 2, 3]
            rng.shuffle(bag)
        colour = next(c for c in bag if c != last)
        bag.remove(colour)
        last = colour
        t = (k + rng.uniform(0.3, 0.7)) / TUFTS
        a = k * 2.39996 + rng.uniform(-0.3, 0.3)
        ring = FLOSS_RADIUS * cone(t)
        tufts.append((Vector((math.cos(a) * ring, math.sin(a) * ring, FLOSS_FOOT + t * FLOSS_HEIGHT)), colour))
    return tufts


def candyfloss_tree(kit, near):
    # A straight pearl-rose trunk, running up inside the floss.
    bark0, bark1 = hexc("A9808C"), hexc("D6A9B3")
    lean = Vector((kit.rng.uniform(-1, 1), kit.rng.uniform(-1, 1), 0.0)).normalized() * 0.06
    trunk = [Vector((0, 0, 0)), Vector((lean.x, lean.y, 1.3)), Vector((-lean.x * 0.5, -lean.y * 0.5, 2.7)), Vector((0, 0, 4.4))]
    if not near:
        trunk = [trunk[0], trunk[2], trunk[3]]
    kit.tube(trunk, taper(len(trunk), 0.36, 0.18), 8 if near else 5, bark0, bark1, 0.0, 0.06, flare=0.4 if near else 0.0)

    # The heap: billows up a spiral round the cone, each bulging out of it.
    count = 30 if near else 13
    lumps = []
    for i in range(count):
        t = (i + kit.rng.uniform(0.2, 0.8)) / count
        a = i * 2.39996 + kit.rng.uniform(-0.35, 0.35)
        ring = FLOSS_RADIUS * cone(t)
        r = min(max(ring * kit.rng.uniform(0.4, 0.62) * (1.0 if near else 1.45), 0.38), 1.25 if near else 1.7)
        out = max(ring - r * kit.rng.uniform(0.4, 0.7), 0.0)
        c = Vector((math.cos(a) * out, math.sin(a) * out, FLOSS_FOOT + t * FLOSS_HEIGHT + kit.rng.uniform(-0.12, 0.12)))
        lumps.append((c, r, Vector((kit.rng.random() * 50, kit.rng.random() * 50, kit.rng.random() * 50))))
    # the tip, and the middle of the foot so the underside is closed
    lumps.append((Vector((0, 0, FLOSS_FOOT + FLOSS_HEIGHT)), 0.55, Vector((7.0, 3.0, 1.0))))
    lumps.append((Vector((0, 0, FLOSS_FOOT + 0.5)), FLOSS_RADIUS * 0.55, Vector((2.0, 9.0, 4.0))))
    for t in (0.3, 0.52, 0.74):   # the heap's middle, so no gap shows the trunk
        lumps.append((Vector((0, 0, FLOSS_FOOT + t * FLOSS_HEIGHT)), FLOSS_RADIUS * cone(t) * 0.62, Vector((t * 9.0, 1.0, 5.0))))

    # Billows on the billows, as candyfloss heaps: two smaller ones on the
    # outward side of each of the bigger ones. (They go in ahead of the
    # hidden middle ones, so the fuzz below takes them too.)
    outer = count + 1
    if near:
        kids = []
        for i in sorted(range(count), key=lambda i: -lumps[i][1])[:10]:
            c, r, _ = lumps[i]
            away = flat(c)
            for k in range(2):
                a = kit.rng.uniform(-1.2, 1.2)
                d = (away * math.cos(a) + Vector((-away.y, away.x, 0.0)) * math.sin(a) + UP * kit.rng.uniform(-0.5, 0.9)).normalized()
                kids.append((c + d * r * 0.78, r * kit.rng.uniform(0.42, 0.56), Vector((kit.rng.random() * 50, kit.rng.random() * 50, kit.rng.random() * 50))))
        lumps[outer:outer] = kids
        outer += len(kids)

    # The tufts: nine places up the cone, each with one of the four colours;
    # a billow belongs to the nearest. (Owner: "the original had a multicolor
    # option where there were a variety of colored tufts in one tree".) They
    # are drawn apart from the tree's own dice, so the near tree and the far
    # one are coloured alike and nothing changes colour as the step swaps.
    tufts = floss_tufts()

    # (the near tree is built first: build_flossed. Its outer billows colour the far one.)
    if near:
        NEAR_BILLOWS[:] = [(lumps[i][0], lumps[i][1], tuft_pick(lumps, i, tufts)) for i in range(outer)]
    base = wt.Kit(1)
    for i in range(len(lumps)):
        billow(base, lumps, i, 1.0, 1, False, tufts, None if near else NEAR_BILLOWS)
    base.cull_buried()
    kit.floss = base
    # The fuzz: a second skin a little off every billow but the hidden middle
    # ones. Its own mesh, for the cut-out shader (the billows are drawn solid).
    kit.fuzz = None
    if near:
        kit.fuzz = wt.Kit(2)
        for i in range(outer):
            billow(kit.fuzz, lumps, i, FUZZ, 1, True, tufts)
        kit.fuzz.cull_buried()

    # Star blossoms resting on the billows (owner: "we also have to add the stars").
    def covered(p, own):
        return any(j != own and (p - oc).length < orad * FUZZ for j, (oc, orad, _) in enumerate(lumps))

    placed = 0
    tries = 0
    while placed < (24 if near else 6) and tries < 400:
        tries += 1
        i = kit.rng.randrange(outer)
        c, r, _ = lumps[i]
        a = kit.rng.uniform(0.0, math.tau)
        z = kit.rng.uniform(-0.1, 0.9)   # on the tops and the sides: seen from the ground
        d = Vector((math.cos(a) * math.sqrt(1 - z * z), math.sin(a) * math.sqrt(1 - z * z), z))
        if d.x * c.x + d.y * c.y < 0.0:
            continue   # facing in toward the trunk
        p = c + d * r * (FUZZ + 0.06)
        if covered(p, i):
            continue
        roll = kit.rng.random()
        petal_c, tip_c, heart_c = STAR_GOLD if roll < 0.25 else STAR_BLUSH if roll < 0.5 else STAR_PEARL
        star(kit, p, d, kit.rng.uniform(0.26, 0.4) * (1.0 if near else 1.5), petal_c, tip_c, heart_c, 0.3)
        placed += 1


STAR_PEARL = (hexc("FBF1DC"), hexc("FFFBF2"), hexc("F2C94C"))   # petal, tip, heart
STAR_GOLD = (hexc("F8DF94"), hexc("FCF0C2"), hexc("E8A93A"))
STAR_BLUSH = (hexc("FBE3E6"), hexc("FFF7F5"), hexc("F2C94C"))


def star(kit, centre, normal, radius, petal, tip, heart_c, flex):
    """A five-pointed star blossom resting on the floss: a raised gold heart,
    pale petals drawn out to points that lift a little. (Pointed on purpose:
    the owner's "stars on them".)"""
    n, side, up = sf.frame(normal)
    c = Vector(centre)
    turn = kit.rng.uniform(0.0, math.tau)
    mid = kit.add_vert(c + n * radius * 0.16)
    kit.normals[mid] = n.copy()
    ring = []
    for i in range(10):
        a = turn + math.tau * i / 10
        d = side * math.cos(a) + up * math.sin(a)
        point = i % 2 == 0
        v = kit.add_vert(c + d * radius * (1.0 if point else 0.4) + n * radius * (0.2 if point else 0.03))
        kit.normals[v] = (n * 0.9 + d * 0.3).normalized()
        ring.append((v, tip if point else petal))
    for i in range(10):
        (a, ca), (b, cb) = ring[i], ring[(i + 1) % 10]
        kit.face((mid, a, b), (heart_c, ca, cb), ((flex, 0.0),) * 3)


# ------------------------------------------------------------- wisteria ----
# The wisteria (owner, 2026-11-12: one special tree at a time). The first one
# hung fat lilac crystals under a few leaf discs. This is an old wisteria
# trained as a parasol: twined stems, limbs arching out and dipping at the
# rim, and a curtain of flower chains you can walk in under.

WIST_BARK = (hexc("6B5464"), hexc("B9A2B4"))    # plum at the foot, silver-lilac in the limbs
WIST_TWIG = hexc("C9B6C8")
# A chain's colours, top (open flowers) to tip (buds), and its florets' lip.
WIST_CHAINS = [
    (hexc("EADDF8"), hexc("B79BEA"), hexc("7A5FD0"), hexc("F6EEFC")),   # wisteria: the first tree's lilacs
    (hexc("E6DCF9"), hexc("A996EC"), hexc("6A58CC"), hexc("F4EEFD")),   # bluer
    (hexc("F1DDF6"), hexc("CFA2E8"), hexc("9466CF"), hexc("FBEFFB")),   # orchid
]
WIST_CHAIN_ODDS = [0.55, 0.25, 0.2]
WIST_LEAF = (hexc("7FCB8E"), hexc("C8EDB4"))    # young leaves: fresh green to pale gold-green
WIST_HEIGHT = 3.3      # where the stems open into limbs
WIST_REACH = 4.3       # how far a limb arches out
WIST_CLEAR = 1.25      # no chain hangs lower than this


def twine(height, turns, phase, hr0, hr1, lean, steps):
    """One stem of the twined trunk: a helix round the trunk's line, which
    leans a little as it rises."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        a = phase + turns * math.tau * t
        hr = hr0 + (hr1 - hr0) * t
        mid = lean * (t ** 1.4)
        pts.append(Vector((mid.x + math.cos(a) * hr, mid.y + math.sin(a) * hr, height * t)))
    return pts


def chain(kit, top, length, width, cols, near, sway):
    """A wisteria flower chain hanging from `top`: whorls of small florets on a
    thread, full at the shoulder and running down to a point of buds. Pale at
    the top where the flowers have opened, deep at the tip. The far one is a
    plain spindle in the same colours."""
    pale, mid_c, deep, lip = cols
    turn = kit.rng.uniform(0.0, math.tau)

    def spot(t):
        # the thread: straight down, drifting a little the way the chain sways
        return Vector(top) + Vector((sway.x * t * t, sway.y * t * t, -length * t))

    def girth(t):
        shoulder = math.sin(math.pi * 0.5 * min(t / 0.22, 1.0))
        return width * (0.3 + 0.7 * shoulder) * (1.0 - t) ** 0.75 + 0.02

    def colour(t):
        return mix(pale, mid_c, t / 0.45) if t < 0.45 else mix(mid_c, deep, (t - 0.45) / 0.55)

    if not near:
        rings = []
        for r, t in enumerate((0.0, 0.2, 0.6)):
            c = spot(t)
            ring = []
            for k in range(4):
                a = turn + math.tau * k / 4 + r * 0.6
                d = Vector((math.cos(a), math.sin(a), 0.0))
                v = kit.add_vert(c + d * (girth(t) if r else width * 0.35))
                kit.normals[v] = (d + UP * (0.5 if r == 0 else 0.0)).normalized()
                ring.append(v)
            rings.append((ring, colour(t), 0.3 + 0.6 * t))
        tip = kit.add_vert(spot(1.0))
        kit.normals[tip] = -UP
        for r in range(2):
            (a, ca, fa), (b, cb, fb) = rings[r], rings[r + 1]
            for k in range(4):
                kit.face((a[k], b[(k + 1) % 4], a[(k + 1) % 4]), (ca, cb, ca), ((fa, 0), (fb, 0), (fa, 0)))
                kit.face((a[k], b[k], b[(k + 1) % 4]), (ca, cb, cb), ((fa, 0), (fb, 0), (fb, 0)))
        last, cl, fl = rings[-1]
        for k in range(4):
            kit.face((last[k], tip, last[(k + 1) % 4]), (cl, deep, cl), ((fl, 0), (0.95, 0.35), (fl, 0)))
        return

    whorls = max(5, round(length / 0.21))
    per = 4
    for w in range(whorls):
        t = (w + 0.5) / whorls
        c = spot(t)
        r = girth(t)
        drop = length / whorls * 1.25
        col = colour(t)
        flex = 0.3 + 0.6 * t
        # the buds at the tip catch a little faelight
        glow = 0.35 * max(0.0, (t - 0.72) / 0.28)
        for k in range(per):
            a = turn + math.tau * (k + 0.5 * (w % 2)) / per + kit.rng.uniform(-0.2, 0.2)
            d = Vector((math.cos(a), math.sin(a), 0.0))
            side = Vector((-d.y, d.x, 0.0))
            size = r * kit.rng.uniform(0.9, 1.15)
            foot = kit.add_vert(c + UP * drop * 0.25)
            # a blunt shield, not a spike: broad low shoulders, a short lip
            left = kit.add_vert(c + d * size * 0.8 + side * size * 0.72 - UP * drop * 0.42)
            right = kit.add_vert(c + d * size * 0.8 - side * size * 0.72 - UP * drop * 0.42)
            point = kit.add_vert(c + d * size * 1.0 - UP * drop * 0.86)
            kit.normals[foot] = (d * 0.5 + UP * 0.8).normalized()
            kit.normals[left] = (d * 0.75 + side * 0.55 + UP * 0.2).normalized()
            kit.normals[right] = (d * 0.75 - side * 0.55 + UP * 0.2).normalized()
            kit.normals[point] = (d * 0.9 - UP * 0.3).normalized()
            inner = wt.shade(col, 0.86)
            edge = mix(col, lip, 0.55 * (1.0 - t))
            # (wound to face out, the way their normals point)
            kit.face((foot, point, left), (inner, edge, col), ((flex, glow),) * 3)
            kit.face((foot, right, point), (inner, col, edge), ((flex, glow),) * 3)


def wisteria_tree(kit, near):
    lean = Vector((kit.rng.uniform(-1, 1), kit.rng.uniform(-1, 1), 0.0)).normalized() * 0.35
    phase = kit.rng.uniform(0.0, math.tau)
    steps = 9 if near else 4
    # Two stems twined round each other, and a young vine round them both.
    stem_a = twine(WIST_HEIGHT, 1.1, phase, 0.2, 0.1, lean, steps)
    stem_b = twine(WIST_HEIGHT * 0.97, 1.1, phase + math.pi, 0.2, 0.12, lean, steps)
    kit.tube(stem_a, taper(len(stem_a), 0.24, 0.17), 7 if near else 5, WIST_BARK[0], WIST_BARK[1], 0.0, 0.05, flare=0.5 if near else 0.0)
    kit.tube(stem_b, taper(len(stem_b), 0.19, 0.14), 7 if near else 5, WIST_BARK[0], WIST_BARK[1], 0.0, 0.05, flare=0.4 if near else 0.0)
    if near:
        vine = twine(WIST_HEIGHT * 0.8, 1.9, phase + 1.4, 0.36, 0.2, lean * 0.8, 12)
        kit.tube(vine, taper(len(vine), 0.07, 0.04), 5, WIST_BARK[1], WIST_TWIG, 0.0, 0.05)
    crown = Vector((lean.x, lean.y, WIST_HEIGHT))

    # The parasol: limbs leave the stems rising, run out level and dip at the rim.
    hangs = []    # (point, share of the way out to the rim)
    tops = []     # points on top of the limbs, for leaves and stars
    limbs = 7
    for i in range(limbs):
        a = phase + math.tau * i / limbs + kit.rng.uniform(-0.2, 0.2)
        heading = Vector((math.cos(a), math.sin(a), 0.0))
        base = (stem_a if i % 2 == 0 else stem_b)[-1 - (i % 3 == 2)]
        reach = WIST_REACH * kit.rng.uniform(0.85, 1.08)
        limb = sweep(kit, base, heading, kit.rng.uniform(34.0, 46.0), -24.0, reach * 1.08, 6 if near else 3, 0.16)
        kit.tube(limb, taper(len(limb), 0.13, 0.035), 6 if near else 4, WIST_BARK[1], WIST_TWIG, 0.05, 0.5)
        lines = [(limb, 0.18, 1.0)]
        # side arms, alternate sides, arching the same way
        for k, t in enumerate((0.36, 0.62) if near else (0.5,)):
            p = at(limb, t)
            sideways = Vector((-heading.y, heading.x, 0.0)) * (1 if (i + k) % 2 else -1)
            arm = sweep(kit, p, (heading * 0.6 + sideways * 0.8).normalized(), kit.rng.uniform(14.0, 26.0), -28.0,
                        reach * kit.rng.uniform(0.4, 0.5), 4 if near else 2, 0.18)
            kit.tube(arm, taper(len(arm), 0.06, 0.025), 5 if near else 3, WIST_TWIG, WIST_TWIG, 0.25 + 0.2 * t, 0.6)
            lines.append((arm, 0.2, 1.0))
        for line, t0, t1 in lines:
            span = sum((line[j + 1] - line[j]).length for j in range(len(line) - 1)) * (t1 - t0)
            count = max(2, round(span / (0.8 if near else 1.25)))
            for j in range(count):
                t = t0 + (t1 - t0) * (j + kit.rng.uniform(0.25, 0.75)) / count
                p = at(line, t)
                hangs.append((p + Vector((kit.rng.uniform(-0.14, 0.14), kit.rng.uniform(-0.14, 0.14), -0.03)),
                              min(1.0, flat(p - crown).dot(p - crown) / WIST_REACH)))
                tops.append((p, flat(line[-1] - line[0])))

    # The curtain: short chains by the stems so the trunk shows, the longest at the rim.
    for p, out in hangs:
        length = (1.05 + 1.5 * out) * kit.rng.uniform(0.8, 1.2)
        if kit.rng.random() < 0.12:
            length *= 1.3
        length = min(length, p.z - WIST_CLEAR)
        if length < 0.6:
            continue
        cols = kit.rng.choices(WIST_CHAINS, weights=WIST_CHAIN_ODDS)[0]
        width = kit.rng.uniform(0.2, 0.26) * (1.0 if near else 1.25)
        sway = Vector((kit.rng.uniform(-0.12, 0.12), kit.rng.uniform(-0.12, 0.12), 0.0))
        chain(kit, p, length, width, cols, near, sway)

    # Young leaves along the tops of the limbs, in pairs, and a few star blossoms among them.
    for n, (p, along) in enumerate(tops if near else tops[::3]):
        sideways = Vector((-along.y, along.x, 0.0))
        # a spray of three: one to each side and one standing up along the limb
        for s in (-1, 1, 0) if near else (-1, 1):
            d = (along * (kit.rng.uniform(0.2, 0.7) if s else 0.9) + sideways * s + UP * kit.rng.uniform(0.25, 0.6) * (1 if s else 1.8)).normalized()
            sf.leaf(kit, p + UP * 0.03, d, kit.rng.uniform(0.5, 0.7) * (1.0 if near else 1.5), 0.16 * (1.0 if near else 1.5),
                    WIST_LEAF[0], WIST_LEAF[1], 0.35, 0.6)
        if near and n % 7 == 3:
            up = (UP + along * 0.25 + sideways * kit.rng.uniform(-0.3, 0.3)).normalized()
            petal_c, tip_c, heart_c = STAR_PEARL if kit.rng.random() < 0.6 else STAR_GOLD
            star(kit, p + up * 0.14, up, kit.rng.uniform(0.2, 0.28), petal_c, tip_c, heart_c, 0.4)


def build_flossed(species, fn, near_cap, far_cap):
    """wt.build for a tree with candyfloss: near and far as usual (the wood,
    the stars), near_floss / far_floss beside them, and near_fuzz (the far
    tree has none). The caps count all of it."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    seed = sum(ord(c) * (i + 1) for i, c in enumerate(species))
    objs, report = [], []
    for name, near, cap in (("near", True, near_cap), ("far", False, far_cap)):
        kit = wt.grow(fn, seed, near, set())
        floss, fuzz = kit.floss, kit.fuzz
        soft = floss.tri_count() + (fuzz.tri_count() if fuzz else 0)
        wood = wt.skin_wood(kit, min(700, cap - kit.tri_count() - soft - 10)) if near else 0
        total = kit.tri_count() + soft
        if total > cap:
            raise SystemExit("%s %s: %d tris over the %d cap" % (species, name, total, cap))
        report.append((total, wood, floss.tri_count(), fuzz.tri_count() if fuzz else 0))
        objs.append(wt.to_object(kit, name))
        objs.append(wt.to_object(floss, name + "_floss"))
        if fuzz:
            objs.append(wt.to_object(fuzz, name + "_fuzz"))
    path = os.path.join(OUT, species + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_normals=True, export_texcoords=True, export_materials="PLACEHOLDER",
                              export_apply=False, export_animations=False)
    print("%-14s near %5d tris (wood %4d, floss %4d, fuzz %4d)  far %4d tris (floss %4d)  %6.0f KB" % (
        species, report[0][0], report[0][1], report[0][2], report[0][3], report[1][0], report[1][2],
        os.path.getsize(path) / 1024))


FLOSSED = ("candyfloss_tree",)
# The most triangles a tree's wood may take of its cap (the rest is flowers).
WOOD = {"wisteria_tree": 900}

SPECIES = {
    "magnolia": (magnolia, SPECIAL),
    "wisteria_tree": (wisteria_tree, SPECIAL),
    # (twice the billows of any other crown, and its fuzz: a cap of its own)
    "candyfloss_tree": (candyfloss_tree, (9000, 1500)),
    "magnolia_harlequin": (magnolia_harlequin, SPECIAL),
}


def main():
    wt.OUT = OUT
    os.makedirs(OUT, exist_ok=True)
    only = [a for a in sys.argv[1:] if a in SPECIES] or list(SPECIES)
    for species in only:
        fn, (near_cap, far_cap) = SPECIES[species]
        if species in FLOSSED:
            build_flossed(species, fn, near_cap, far_cap)
        else:
            wt.build(species, fn, near_cap, far_cap, WOOD.get(species, wt.WOOD_MAX))


if __name__ == "__main__":
    main()
