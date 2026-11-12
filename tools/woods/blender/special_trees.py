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
            # mostly up the flower's axis: the cup takes the light evenly, inside and out
            kit.normals[v] = (n * 0.45 + axis * 0.8).normalized()
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


# Petal colours, foot to tip.
BLOOMS = [
    (hexc("E86AA0"), hexc("F7BCD3"), hexc("FFF4F2")),   # rose foot, pearl tip
    (hexc("D95C9B"), hexc("F3A9CB"), hexc("FCE4EC")),   # deeper rose
    (hexc("C98BE0"), hexc("E8CBF4"), hexc("FBF2FD")),   # a lilac one now and then
    (hexc("F08DB2"), hexc("FBD3DF"), hexc("FFFAF4")),   # blush
]
INNER = (hexc("F9C9DA"), hexc("FFF1F0"), hexc("FFFDF8"))
BUD = (hexc("C94F8E"), hexc("E77FB0"), hexc("F6B8D2"))
GOLD = hexc("FFD166")


def bloom(kit, base, axis, size, stage, near, flex):
    """A magnolia flower standing on `axis`: stage 2 an open star (six petals
    spread wide round three upright ones and a gold heart), 1 a goblet, 0 a
    pointed bud."""
    axis = axis.normalized()
    side = axis.orthogonal().normalized()
    fwd = axis.cross(side).normalized()
    turn = kit.rng.uniform(0.0, math.tau)
    cols = kit.rng.choice(BLOOMS[:2] + BLOOMS[3:] if kit.rng.random() > 0.14 else BLOOMS[2:3])
    def ring(count, offset, length, width, tilt, cup, colours, rows):
        rows = rows if near else 1
        for k in range(count):
            a = turn + offset + math.tau * k / count
            out = side * math.cos(a) + fwd * math.sin(a)
            j = kit.rng.uniform(0.9, 1.1)
            petal(kit, base, axis, out, length * size * j, width * size, tilt * kit.rng.uniform(0.9, 1.1), cup, colours, flex, rows)

    if stage == 2:
        ring(6, 0.0, 0.62, 0.22, 64.0, 0.6, cols, 4)
        ring(3, math.pi / 6, 0.5, 0.19, 24.0, 0.5, INNER, 3)
        if near:
            heart(kit, base + axis * 0.03 * size, axis, 0.05 * size, 0.2 * size, GOLD, flex)
    elif stage == 1:
        ring(3, 0.0, 0.58, 0.22, 34.0, 1.0, cols, 3)
        ring(3, math.pi / 3, 0.54, 0.21, 24.0, 1.1, (cols[0], cols[1], INNER[2]), 3)
    else:
        ring(3, 0.0, 0.4, 0.14, 20.0, 2.0, BUD, 2)


def magnolia(kit, near):
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
        bloom(kit, p + ax * 0.02, ax, size, stage, near, flex)

    # A few young mint leaves low on the limbs: the leaves come after the flowers.
    if near:
        low = sorted(flowers, key=lambda f: f[2])[:8]
        for p, _, _ in low[::2]:
            for k in range(2):
                a = kit.rng.uniform(0.0, math.tau)
                d = Vector((math.cos(a), math.sin(a), kit.rng.uniform(0.5, 0.9)))
                sf.leaf(kit, p - UP * kit.rng.uniform(0.2, 0.32), d, kit.rng.uniform(0.42, 0.55), 0.13, hexc("8FDDB0"), hexc("C9F2D6"), 0.3, 0.45)


SPECIES = {
    "magnolia": (magnolia, SPECIAL),
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
