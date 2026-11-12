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
           A bouquet of candyfloss on sticks: a curving pearl-rose trunk,
           each limb a stick with a tuft of spun sugar wound on it (blush,
           rose, lilac, pearl, peach): a dense heart in the deep colour
           wrapped in pale wisps of painted threads, with five-pointed star
           blossoms nestled in the floss.
magnolia_harlequin
           The same tree with every flower its own candy colour (rose,
           coral, lilac, periwinkle, apricot, mint, hot pink) and a heart of
           petals in another standing up out of the cup.
"""

import math
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
# Owner, 2026-11-12: the first rebuild "looks really similar ... what should a
# candyfloss tree's texture be?" Spun sugar: no hard outline, threads wound
# round a stick, pale where the light comes through and deep in the dense
# middle. So each limb is a stick with a tuft of floss wound on it: a solid
# heart in the deep colour, wrapped in wisps (cards of painted threads,
# tools/woods/gen_floss_wisp.py, drawn by woods_floss.gdshader) laid along
# the winding, some standing off as a fringe, a few pulled out into tails.

class Tuft:
    """Floss wound on a stick from `foot` to `top`: thin where it grips the
    stick, swelling to `radius` about three fifths of the way up, domed."""

    def __init__(self, kit, foot, top, radius, hand):
        self.foot = Vector(foot)
        self.axis = (Vector(top) - self.foot).normalized()
        self.length = (Vector(top) - self.foot).length
        self.radius = radius
        self.side = self.axis.orthogonal().normalized()
        self.fwd = self.axis.cross(self.side).normalized()
        self.hand = hand
        self.phase = kit.rng.uniform(0.0, math.tau)

    def swell(self, t):
        t = min(max(t, 0.0), 1.0)
        return 0.1 * (1.0 - t) + 0.9 * math.sin(math.pi * t ** 1.45) ** 0.75

    def out(self, a):
        return self.side * math.cos(a) + self.fwd * math.sin(a)

    def at(self, t, a, k=1.0):
        """The point at height t (0..1) and angle a, k times the heart's radius out."""
        ridge = 1.0 + 0.07 * math.sin(3.0 * a - self.hand * 9.0 * t + self.phase)
        return self.foot + self.axis * (t * self.length) + self.out(a) * (self.radius * self.swell(t) * ridge * k)

    def normal(self, t, a):
        e = 0.02
        slope = (self.swell(t + e) - self.swell(t - e)) / (2.0 * e) * self.radius / self.length
        return (self.out(a) - self.axis * slope).normalized()

    def winding(self, t, a, pitch):
        """The way the sugar was wound here: round the stick, climbing a little."""
        round_ = self.axis.cross(self.out(a)).normalized() * self.hand
        return (round_ * math.cos(pitch) + self.axis * math.sin(pitch)).normalized()


def floss_heart(kit, tuft, top, deep, flex, rows, segs):
    """The dense middle of a tuft: the deep colour, a little paler up top."""
    rings = []
    for r in range(rows + 1):
        t = r / rows
        ring = []
        for k in range(segs):
            a = math.tau * k / segs + 0.3 * r
            v = kit.add_vert(tuft.at(t, a, 0.86) if 0 < r < rows else tuft.foot + tuft.axis * (t * tuft.length))
            kit.normals[v] = tuft.normal(t, a) if 0 < r < rows else (tuft.axis if r else -tuft.axis)
            ring.append(v)
        rings.append((ring, mix(deep, top, 0.55 * t ** 1.3), flex + 0.08 * t))
    for r in range(rows):
        (a, ca, fa), (b, cb, fb) = rings[r], rings[r + 1]
        for k in range(segs):
            k2 = (k + 1) % segs
            kit.face((a[k], a[k2], b[k2]), (ca, ca, cb), ((fa, 0), (fa, 0), (fb, 0)))
            kit.face((a[k], b[k2], b[k]), (ca, cb, cb), ((fa, 0), (fb, 0), (fb, 0)))


def wisp(kit, centre, along, normal, length, height, shade_normal, colour, flex, lift=0.0):
    """One card of spun threads: `along` its length, facing `normal`, lit as
    `shade_normal` (the tuft's); `lift` raises its upper edge off the tuft."""
    along = along.normalized()
    up = normal.cross(along).normalized()
    up = (up + normal * lift).normalized()
    cell = kit.rng.randrange(4)
    u0, v0 = (cell % 2) * 0.5, (cell // 2) * 0.5
    us = (u0 + 0.004, u0 + 0.496) if kit.rng.random() < 0.5 else (u0 + 0.496, u0 + 0.004)
    vs = (v0 + 0.004, v0 + 0.496) if kit.rng.random() < 0.5 else (v0 + 0.496, v0 + 0.004)
    corners = []
    for sx, sy, u, v in ((-1, -1, us[0], vs[0]), (1, -1, us[1], vs[0]), (1, 1, us[1], vs[1]), (-1, 1, us[0], vs[1])):
        corners.append((centre + along * (sx * length * 0.5) + up * (sy * height * 0.5), (u, v)))
    kit.wisps.append((corners, tuple(shade_normal), (colour[0], colour[1], colour[2], flex)))


FLOSS = [
    (hexc("FAD4DC"), hexc("EE7FA8")),   # blush over rose
    (hexc("F7B3CB"), hexc("E25A8A")),   # rose over hot pink
    (hexc("E9D6F7"), hexc("A77FDB")),   # pale lilac over lilac
    (hexc("FBEDEA"), hexc("F08DB2")),   # pearl over blush rose
    (hexc("FBD9C8"), hexc("EE8A8A")),   # peach over coral rose
]
STAR_PEARL = (hexc("FBF1DC"), hexc("FFFBF2"), hexc("F2C94C"))   # petal, tip, heart
STAR_GOLD = (hexc("F8DF94"), hexc("FCF0C2"), hexc("E8A93A"))
STAR_BLUSH = (hexc("FBE3E6"), hexc("FFF7F5"), hexc("F2C94C"))


def star(kit, centre, normal, radius, petal, tip, heart_c, flex):
    """A five-pointed star blossom lying in the floss: a raised gold heart,
    pale petals drawn out to points that lift a little off the sugar.
    (Pointed on purpose: the owner's "stars on them".)"""
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


def floss(kit, tuft, top, deep, near):
    """Winds a tuft: its heart, the wisps laid along the winding, the fringe
    standing off it, the pulled tails, and its stars."""
    flex = 0.34
    floss_heart(kit, tuft, top, deep, flex, 9 if near else 5, 10 if near else 6)
    pale = mix(top, hexc("FFFFFF"), 0.4)
    r = tuft.radius

    def colour(t):
        return mix(mix(deep, top, 0.45), pale, min(1.0, 0.25 + 0.9 * t))

    # laid wisps: a spiral of cards over the whole tuft, more where it is fat
    want = 34 if near else 9
    placed = 0
    i = 0
    while placed < want:
        i += 1
        t = kit.rng.uniform(0.04, 0.97)
        if kit.rng.random() > tuft.swell(t) + 0.12:
            continue
        a = i * 2.39996 + kit.rng.uniform(-0.3, 0.3)
        n = tuft.normal(t, a)
        along = tuft.winding(t, a, math.radians(kit.rng.uniform(10.0, 32.0)))
        size = r * kit.rng.uniform(0.95, 1.4) * (1.0 if near else 1.6)
        wisp(kit, tuft.at(t, a, kit.rng.uniform(1.0, 1.12)), along, n, size, size * kit.rng.uniform(0.4, 0.5), n,
             colour(t), flex + 0.1 * t, lift=kit.rng.uniform(0.15, 0.5))
        placed += 1
    # the fringe: wisps standing out from the tuft along the winding, so every outline is threads
    for k in range(9 if near else 3):
        t = kit.rng.uniform(0.2, 0.92)
        a = kit.rng.uniform(0.0, math.tau)
        n = tuft.normal(t, a)
        along = tuft.winding(t, a, math.radians(kit.rng.uniform(8.0, 26.0)))
        size = r * kit.rng.uniform(0.9, 1.3)
        wisp(kit, tuft.at(t, a, 1.12), along, along.cross(n).normalized(), size, size * 0.42, n, mix(colour(t), hexc("FFFFFF"), 0.2), flex + 0.14)
    # tails: sugar pulled out of the foot down the stick, and a wisp or two streaming off the top
    for k in range(4 if near else 1):
        a = kit.rng.uniform(0.0, math.tau)
        n = tuft.out(a)
        down = (-tuft.axis * 0.8 - UP * 0.5 + n * 0.25).normalized()
        size = r * kit.rng.uniform(0.9, 1.3)
        wisp(kit, tuft.at(0.1, a, 1.1) + down * size * 0.3, down, n, size, size * 0.3, n, mix(deep, top, 0.5), flex)
    for k in range(2 if near else 0):
        a = kit.rng.uniform(0.0, math.tau)
        n = (tuft.axis * 0.5 + tuft.out(a)).normalized()
        away = (tuft.out(a + 1.2) * 0.8 + tuft.axis * 0.6).normalized()
        size = r * kit.rng.uniform(0.9, 1.2)
        wisp(kit, tuft.at(0.93, a, 1.0) + away * size * 0.3, away, n, size, size * 0.34, n, pale, flex + 0.2)
    # the stars, nestled in the floss
    for k in range(7 if near else 2):
        t = kit.rng.uniform(0.3, 0.97)
        a = kit.rng.uniform(0.0, math.tau)
        n = tuft.normal(t, a)
        size = kit.rng.uniform(0.2, 0.32) * (1.0 if near else 1.5)
        roll = kit.rng.random()
        petal_c, tip_c, heart_c = STAR_GOLD if roll < 0.22 else STAR_BLUSH if roll < 0.45 else STAR_PEARL
        star(kit, tuft.at(t, a, 1.14), n, size, petal_c, tip_c, heart_c, flex + 0.1)


def candyfloss_tree(kit, near):
    kit.wisps = []
    # The wood: a curving pearl-rose trunk, each limb a stick for its tuft.
    bark0, bark1, stick = hexc("A9808C"), hexc("D6A9B3"), hexc("E6C6CC")
    trunk = [Vector((0, 0, 0))]
    lean = Vector((kit.rng.uniform(-1, 1), kit.rng.uniform(-1, 1), 0.0)).normalized()
    for z, k in ((1.1, 0.26), (2.2, -0.12), (3.1, 0.18), (3.8, 0.28)):
        trunk.append(Vector((lean.x * k, lean.y * k, z)) + Vector((kit.rng.uniform(-0.06, 0.06), kit.rng.uniform(-0.06, 0.06), 0.0)))
    if not near:
        trunk = trunk[::2]
    kit.tube(trunk, taper(len(trunk), 0.5, 0.28), 8 if near else 5, bark0, bark1, 0.0, 0.08, flare=0.45 if near else 0.0)
    top = trunk[-1]
    limbs = 6
    start = kit.rng.uniform(0.0, math.tau)
    for i in range(limbs):
        a = start + math.tau * i / limbs + kit.rng.uniform(-0.2, 0.2)
        heading = Vector((math.cos(a), math.sin(a), 0.0))
        low = i % 2 == 0
        base = at(trunk, 0.82) if low else top
        limb = sweep(kit, base, heading, 16.0 if low else 38.0, 70.0 if low else 62.0, kit.rng.uniform(3.4, 3.9) * (1.0 if low else 0.88), 5 if near else 3, 0.1)
        kit.tube(limb, taper(len(limb), 0.2, 0.06), 6 if near else 4, bark1, stick, 0.1, 0.34)
        foot = at(limb, 0.5)
        axis = (limb[-1] - at(limb, 0.6)).normalized()
        length = kit.rng.uniform(2.7, 3.2)
        ca, cb = FLOSS[i % len(FLOSS)]
        floss(kit, Tuft(kit, foot, foot + axis * length, length * kit.rng.uniform(0.4, 0.45), 1 if i % 2 else -1), ca, cb, near)
    # the crown: the biggest tuft, on the leader
    lead = sweep(kit, top, lean, 80.0, 86.0, 2.6, 3 if near else 2, 0.06)
    kit.tube(lead, taper(len(lead), 0.2, 0.06), 6 if near else 4, bark1, stick, 0.1, 0.3)
    foot = at(lead, 0.3)
    ca, cb = FLOSS[(limbs + 1) % len(FLOSS)]
    floss(kit, Tuft(kit, foot, foot + (lead[-1] - foot).normalized() * 3.7, 1.6, 1), ca, cb, near)


def wisp_object(kit, name):
    """The wisps as their own mesh: quads with the picture's UVs, the tuft's
    normals, the tuft's colour in COLOR.rgb and the wind flex in COLOR.a."""
    verts, faces = [], []
    for corners, _, _ in kit.wisps:
        faces.append(tuple(range(len(verts), len(verts) + 4)))
        verts.extend(tuple(p) for p, _ in corners)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    uv = mesh.uv_layers.new(name="UVMap")
    for poly, (corners, _, colour) in zip(mesh.polygons, kit.wisps):
        for k, li in enumerate(poly.loop_indices):
            col.data[li].color = colour
            u, v = corners[k][1]
            uv.data[li].uv = (u, 1.0 - v)
        poly.use_smooth = True
    mesh.color_attributes.active_color = col
    mesh.normals_split_custom_set_from_vertices([n for _, n, _ in kit.wisps for _ in range(4)])
    mat = bpy.data.materials.get("woods_floss") or bpy.data.materials.new("woods_floss")
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_wisped(species, fn, near_cap, far_cap):
    """wt.build for a tree with wisps: near and far as usual, and
    near_wisps / far_wisps beside them (FloraLibrary.WISPED). The caps count
    both."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    seed = sum(ord(c) * (i + 1) for i, c in enumerate(species))
    objs, report = [], []
    for name, near, cap in (("near", True, near_cap), ("far", False, far_cap)):
        kit = wt.grow(fn, seed, near, set())
        cards = 2 * len(kit.wisps)
        wood = wt.skin_wood(kit, min(wt.WOOD_MAX, cap - kit.tri_count() - cards - 10)) if near else 0
        total = kit.tri_count() + cards
        if total > cap:
            raise SystemExit("%s %s: %d tris over the %d cap" % (species, name, total, cap))
        report.append((total, wood, len(kit.wisps)))
        objs.append(wt.to_object(kit, name))
        objs.append(wisp_object(kit, name + "_wisps"))
    path = os.path.join(OUT, species + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_normals=True, export_texcoords=True, export_materials="PLACEHOLDER",
                              export_apply=False, export_animations=False)
    print("%-14s near %5d tris (wood %4d, %3d wisps)  far %4d tris (%2d wisps)  %6.0f KB" % (
        species, report[0][0], report[0][1], report[0][2], report[1][0], report[1][2], os.path.getsize(path) / 1024))


WISPED = ("candyfloss_tree",)

SPECIES = {
    "magnolia": (magnolia, SPECIAL),
    "candyfloss_tree": (candyfloss_tree, SPECIAL),
    "magnolia_harlequin": (magnolia_harlequin, SPECIAL),
}


def main():
    wt.OUT = OUT
    os.makedirs(OUT, exist_ok=True)
    only = [a for a in sys.argv[1:] if a in SPECIES] or list(SPECIES)
    for species in only:
        fn, (near_cap, far_cap) = SPECIES[species]
        (build_wisped if species in WISPED else wt.build)(species, fn, near_cap, far_cap)


if __name__ == "__main__":
    main()
