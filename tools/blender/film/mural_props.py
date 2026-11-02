"""The opening film's history mural props (lane L33), headless Blender, deterministic.

Run:  /opt/bpyenv/bin/python tools/blender/film/mural_props.py [id ...]
Out:  art/film/mural/<id>.glb, one mesh "<id>", base centre at the origin, front facing +Y
      in Blender (-Z in Godot), in metres at the mural's own scale.

Each prop is one mesh in vertex colours (prop_kit), with two materials: "opaque" and
"glow" (lit windows, lanterns, candle flames, a god's eyes). The mural paints every
surface with mural_lit and gives "glow" surfaces a gilt glow (MuralStage._lit).

Canon (Keeper, 2026-11-02, book 1):
- fae_palace, court_terrace: "glorious, sprawling civilizations" (ch 3), "palaces and temples
  around the world" (ch 6), the ch 13 mural's "ornate" rulers in starry gold [C]; spires,
  bridges, gilt crowns of leaves and stars are [X], beautiful and inhuman.
- feral_temple, stone_block, chain_span: humans "built them temples to their feral gods"
  (ch 3) [C]: wild and pagan, not churchly; the antlered beast-god, scaffolding, stone and
  chains are [X].
- war_banner, sword, longbow, ground_mud: "bloodied mud", humans with "arrows and swords"
  shoulder to shoulder (ch 13) [C]; no sigils in the book, so the banners stay plain.
- treaty_table, treaty_parchment, treaty_seal, treaty_wax: six mortal queens crafting the
  Treaty (ch 3) [C]; table, parchment and seal are [X].
- archeron_manor, carried_*: "our manor home", the peerage's parties, servants' quarters,
  ransacked by the creditors (ch 2, 6) [C]; a grand merchant's country manor is [X].
- merchant_ship: "three ships to sail to Bharat for invaluable spices and cloth" (ch 19)
  [C]; a merchant sailing ship is [X]. Lost in a storm, kept ambiguous (ch 28).
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import bpy  # noqa: E402,I001
import bmesh  # noqa: E402
import prop_kit as K  # noqa: E402
from prop_kit import T, R, S, box, cyl, lathe, sphere, ico, tube, torus, slab, arched_outline  # noqa: E402
from mathutils import Vector  # noqa: E402

OUT = os.path.join(K.ROOT, "art/film/mural")

MARBLE = (0.93, 0.91, 0.87)
PEARL_W = (0.97, 0.95, 0.93)
GILT = (0.95, 0.76, 0.38)
LILAC = (0.72, 0.66, 0.86)
DOME = (0.62, 0.7, 0.86)
WARM = (1.0, 0.84, 0.52)
SHADOW = (0.18, 0.15, 0.24)
BONE = (0.86, 0.8, 0.68)
GOD = (0.58, 0.52, 0.47)
STONE = (0.62, 0.56, 0.5)
STONE_D = (0.42, 0.39, 0.36)
WOOD = (0.46, 0.32, 0.2)
WOOD_D = (0.3, 0.2, 0.13)
ROPE = (0.72, 0.62, 0.44)
IRON = (0.26, 0.25, 0.27)
STEEL = (0.74, 0.76, 0.8)
LEATHER = (0.32, 0.21, 0.14)
OAK_T = (0.4, 0.26, 0.15)
VELVET = (0.16, 0.2, 0.42)
PARCH = (0.9, 0.84, 0.7)
INKC = (0.12, 0.1, 0.12)
WAX = (0.62, 0.06, 0.08)
BRASS = (0.85, 0.66, 0.32)
CREAM_S = (0.88, 0.82, 0.72)
SLATE = (0.3, 0.32, 0.38)
WHITE = (0.95, 0.94, 0.9)
SAIL = (0.9, 0.86, 0.76)
HULL = (0.34, 0.21, 0.12)


class FilmProp(K.Prop):
    """A prop_kit Prop whose "glow" finish goes on its own material."""

    def to_object(self, name=None):
        me = bpy.data.meshes.new(name or self.name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        glow = K.FINISHES.index("glow")
        for poly in me.polygons:
            poly.material_index = 1 if poly.material_index == glow else 0
        me.materials.append(K.finish_material("opaque"))
        me.materials.append(K.finish_material("glow"))
        ob = bpy.data.objects.new(name or self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def rough(bm, amt, rng):
    """Hand-cut stone: every vertex nudged a little."""
    for v in bm.verts:
        v.co += Vector((rng.uniform(-amt, amt), rng.uniform(-amt, amt), rng.uniform(-amt, amt)))
    return bm


def tint(c, rng, amt=0.06):
    k = 1.0 + rng.uniform(-amt, amt)
    return (min(c[0] * k, 1.0), min(c[1] * k, 1.0), min(c[2] * k, 1.0))


def grid(nx, ny, sx, sy, height):
    """A plane of nx*ny quads, sx by sy, centred, z = height(x, y)."""
    bm = bmesh.new()
    vs = [[bm.verts.new((-sx / 2 + sx * i / nx, -sy / 2 + sy * j / ny, 0.0)) for j in range(ny + 1)]
          for i in range(nx + 1)]
    for row in vs:
        for v in row:
            v.co.z = height(v.co.x, v.co.y)
    for i in range(nx):
        for j in range(ny):
            bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
    return bm


def facing(deg):
    return R("Z", deg)


# --------------------------------------------------------------- the High Fae's world

def spire(p, x, y, h, r, rng, windows=True):
    """A slender tower: a fluted shaft that narrows, a balcony ring, an onion dome, a
    needle spire and a gilt crown of leaves and a star at the tip."""
    z_ring = h * 0.55
    z_dome = h * 0.72
    prof = [(r * 1.25, 0.0), (r * 1.1, 0.25), (r, 0.4), (r * 0.82, z_ring - 0.1), (r * 1.35, z_ring),
            (r * 1.35, z_ring + 0.12), (r * 0.7, z_ring + 0.22), (r * 0.62, z_dome)]
    p.add(lathe(prof, 14), MARBLE, "pearl", T(x, y, 0))
    p.add(torus(r * 1.36, 0.035, 18, 4), GILT, "gold", T(x, y, z_ring + 0.12))
    dr = r * 1.05
    dome = [(r * 0.62, z_dome), (dr, z_dome + dr * 0.5), (dr * 0.95, z_dome + dr * 0.95),
            (dr * 0.6, z_dome + dr * 1.45), (dr * 0.18, z_dome + dr * 1.85), (0.04, h * 0.93), (0.0, h)]
    p.add(lathe(dome, 14), rng.choice([DOME, LILAC, GILT]), "gold", T(x, y, 0))
    tip = h
    for k in range(7):
        a = 360.0 * k / 7
        p.add(cyl(0.035, 0.32, 4, r2=0.0), GILT, "gold",
              T(x, y, tip - 0.12) @ R("Z", a) @ R("X", 32) @ T(0, 0, 0))
    p.add(ico(0.07, 1), WARM, "glow", T(x, y, tip + 0.08))
    if windows:
        for zf in (0.3, 0.42, 0.64):
            z = h * zf
            rr = r * (0.95 if zf < 0.55 else 0.68)
            for k in range(6):
                a = 360.0 * k / 6 + 30.0
                p.add(slab(arched_outline(0.12, 0.34, 5), 0.04), WARM, "glow",
                      T(x, y, z) @ R("Z", a) @ T(0, rr, 0))


def fae_palace(p, rng, w=9.0, n=7):
    """A palace of the High Fae: three marble terraces with a gilt colonnade and a great
    arched gate, a cluster of spires of every height joined by thin bridges, a dome."""
    d = w * 0.5
    z = 0.0
    tiers = [(w, d, 0.55), (w * 0.8, d * 0.8, 0.5), (w * 0.6, d * 0.62, 0.45)]
    for tw, td, th in tiers:
        p.add(box(tw, td, th, bevel=0.03), MARBLE, "pearl", T(0, 0, z + th / 2))
        p.add(box(tw + 0.06, td + 0.06, 0.06, bevel=0.01), GILT, "gold", T(0, 0, z + th))
        z += th
    # The colonnade along the first terrace's front.
    cy = tiers[0][1] / 2 - 0.25
    ncol = int(w / 0.62)
    for i in range(ncol):
        x = -w / 2 + 0.35 + i * (w - 0.7) / (ncol - 1)
        if abs(x) < 0.9:
            continue
        p.add(cyl(0.09, 1.3, 10), PEARL_W, "pearl", T(x, cy, 0.55))
        p.add(cyl(0.14, 0.08, 10, r2=0.09), GILT, "gold", T(x, cy, 1.77))
    p.add(box(w - 0.4, 0.3, 0.14), MARBLE, "pearl", T(0, cy, 1.92))
    # The gate: a tall pointed arch in shadow under a gilt frame.
    gate = arched_outline(1.2, 2.4, 10, arch=0.9)
    p.add(slab(gate, 0.1), SHADOW, "matte", T(0, d / 2 + 0.01, 0.0))
    p.add(K.frame_ring(gate, 0.05, 0.05), GILT, "gold", T(0, d / 2 + 0.07, 0.0))
    p.add(ico(0.12, 1), WARM, "glow", T(0, d / 2 + 0.1, 2.45))
    # Spires: the tallest at the back centre, the rest falling away to the sides.
    towers = []
    for i in range(n):
        f = (i / (n - 1)) * 2.0 - 1.0
        x = f * w * 0.36 + rng.uniform(-0.2, 0.2)
        y = -abs(f) * 0.3 + rng.uniform(-0.6, 0.2)
        h = (2.0 - abs(f) * 1.1) * w * 0.55 * rng.uniform(0.8, 1.1)
        r = 0.22 + 0.16 * (1.0 - abs(f)) + rng.uniform(-0.03, 0.03)
        spire(p, x, y, h + z, r, rng)
        towers.append((x, y, h + z, r))
    # Bridges between neighbours, arched, with a gilt rail.
    for (x0, y0, h0, r0), (x1, y1, h1, r1) in zip(towers, towers[1:]):
        hb = min(h0, h1) * 0.5
        pts = [(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, hb + math.sin(math.pi * t) * 0.35) for t in
               [k / 8 for k in range(9)]]
        p.add(tube(pts, 0.06, 6), MARBLE, "pearl")
        p.add(tube([(a, b, c + 0.12) for a, b, c in pts], 0.015, 4), GILT, "gold")
    # A dome on the top terrace.
    dr = w * 0.12
    p.add(lathe([(dr, 0.0), (dr, 0.3), (dr * 0.9, dr * 0.6), (dr * 0.55, dr * 1.0), (0.05, dr * 1.25), (0.0, dr * 1.3)], 18),
          DOME, "gold", T(0, -0.2, z))
    p.add(torus(dr, 0.04, 20, 4), GILT, "gold", T(0, -0.2, z + 0.3))


def court_terrace(p, rng):
    """The marble terrace the court stands on: a long slab with blind arches under it, a
    balustrade along the front and gilt finials on the posts."""
    L, D, H = 30.0, 4.0, 1.2
    p.add(box(L, D, H, bevel=0.04), MARBLE, "pearl", T(0, 0, H / 2))
    p.add(box(L + 0.1, D + 0.1, 0.1, bevel=0.02), PEARL_W, "pearl", T(0, 0, H - 0.05))
    p.add(box(L, 0.08, 0.05), GILT, "gold", T(0, D / 2 + 0.05, H - 0.14))
    for i in range(20):
        x = -L / 2 + 0.75 + i * 1.5
        p.add(slab(arched_outline(0.8, 0.85, 8), 0.06), SHADOW, "matte", T(x, D / 2 + 0.005, 0.08))
        p.add(box(0.12, 0.1, 0.16), GILT, "gold", T(x, D / 2 + 0.03, 0.97))
    yb = D / 2 - 0.12
    bal = [(0.04, 0.0), (0.07, 0.03), (0.05, 0.1), (0.075, 0.22), (0.035, 0.36), (0.05, 0.4), (0.05, 0.42)]
    n = int(L / 0.32)
    for i in range(n):
        x = -L / 2 + 0.16 + i * 0.32
        if i % 10 == 0:
            p.add(box(0.16, 0.16, 0.5), PEARL_W, "pearl", T(x, yb, H + 0.25))
            p.add(sphere(0.07, 8, 6), GILT, "gold", T(x, yb, H + 0.6))
        else:
            p.add(lathe(bal, 8), PEARL_W, "pearl", T(x, yb, H))
    p.add(box(L, 0.18, 0.06, bevel=0.01), PEARL_W, "pearl", T(0, yb, H + 0.45))


# --------------------------------------------------------------- the humans' labour

def stone_block(p, rng, sling=True):
    p.add(rough(box(0.5, 0.42, 0.4, bevel=0.03), 0.012, rng), tint(STONE, rng), "matte", T(0, 0, 0.2))
    if sling:
        for x in (-0.14, 0.14):
            pts = [(x, -0.22, 0.4), (x, -0.22, 0.0), (x, 0.22, 0.0), (x, 0.22, 0.4)]
            p.add(tube(pts, 0.012, 4, caps=False), ROPE, "fabric")


def feral_temple(p, rng):
    """A temple to the feral gods, half built: a stepped platform of rough blocks, a ring
    of carved standing stones (lintels on the finished side only), the antlered beast-god
    on its plinth at the back, scaffolding and a timber crane on the unfinished side."""
    z = 0.0
    for tw, td in ((10.0, 6.0), (8.2, 4.8), (6.4, 3.6)):
        th = 0.5
        nx, ny = int(tw / 1.0), int(td / 0.8)
        for i in range(nx):
            for j in range(ny):
                if 0 < j < ny - 1 and 0 < i < nx - 1:
                    continue  # the core is out of sight
                x = -tw / 2 + (i + 0.5) * tw / nx
                y = -td / 2 + (j + 0.5) * td / ny
                b = rough(box(tw / nx - 0.04, td / ny - 0.04, th - 0.03, bevel=0.03), 0.02, rng)
                p.add(b, tint(STONE, rng, 0.1), "matte", T(x, y, z + th / 2))
        p.add(box(tw - 0.4, td - 0.4, th), STONE_D, "matte", T(0, 0, z + th / 2))
        z += th
    top = z
    # The standing stones, carved with bands of spirals, in an arc open to the front.
    stones = []
    for k in range(7):
        a = math.radians(200 + k * 140 / 6)
        x, y = math.cos(a) * 2.6, math.sin(a) * 1.4 + 0.2
        h = 3.2 if k < 5 else (1.6 if k == 5 else 2.4)
        b = rough(box(0.55, 0.5, h, bevel=0.05), 0.03, rng)
        p.add(b, tint(STONE, rng, 0.08), "matte", T(x, y, top + h / 2))
        for zz in (0.6, 1.4, 2.2):
            if zz < h - 0.3:
                p.add(torus(0.33, 0.035, 10, 4), STONE_D, "matte", T(x, y, top + zz) @ S(1.0, 0.95, 1.0))
        stones.append((x, y, h))
    for (x0, y0, h0), (x1, y1, h1) in zip(stones[:4], stones[1:5]):
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
        ln = math.hypot(x1 - x0, y1 - y0) + 0.6
        p.add(rough(box(ln, 0.55, 0.45, bevel=0.04), 0.03, rng), tint(STONE, rng), "matte",
              T(mx, my, top + 3.2 + 0.22) @ R("Z", ang))
    # The feral god: a great horned beast's head on a plinth, eyes lit, antlers like trees.
    gy = -1.0
    p.add(rough(box(1.4, 1.2, 1.2, bevel=0.06), 0.03, rng), GOD, "matte", T(0, gy, top + 0.6))
    head = sphere(0.7, 14, 10)
    p.add(rough(head, 0.03, rng), GOD, "matte", T(0, gy, top + 1.9) @ S(0.85, 1.0, 1.05))
    p.add(rough(cyl(0.38, 0.9, 10, r2=0.24), 0.02, rng), GOD, "matte",
          T(0, gy + 0.35, top + 1.65) @ R("X", -70))
    for sx in (-1, 1):
        p.add(ico(0.13, 1), (1.0, 0.72, 0.2), "glow", T(sx * 0.26, gy + 0.55, 2.05 + top))
        p.add(cyl(0.12, 0.35, 6, r2=0.02), GOD, "matte", T(sx * 0.5, gy, top + 2.4) @ R("Y", sx * 50))
        base = Vector((sx * 0.35, gy - 0.1, top + 2.45))
        trunk = [base + Vector((sx * 0.25 * t, -0.15 * t, 1.6 * t - 0.25 * t * t)) for t in [k / 6 for k in range(7)]]
        p.add(tube([tuple(v) for v in trunk], [0.09 - 0.012 * k for k in range(7)], 6), BONE, "matte")
        for k, t in enumerate((0.35, 0.6, 0.85)):
            o = trunk[int(t * 6)]
            tip = o + Vector((sx * (0.55 - 0.1 * k), 0.15 * (1 if k % 2 else -1), 0.5))
            mid = o.lerp(tip, 0.5) + Vector((0, 0, 0.12))
            p.add(tube([tuple(o), tuple(mid), tuple(tip)], [0.05, 0.035, 0.012], 5), BONE, "matte")
    # Scaffolding on the right, round the unfinished stones.
    xs = (2.0, 3.0, 4.0)
    ys = (-0.6, 0.9)
    for x in xs:
        for y in ys:
            p.add(cyl(0.05, 4.6, 6), tint(WOOD, rng), "satin", T(x, y, top - 0.05))
    for zz in (top + 1.5, top + 3.0):
        for y in ys:
            p.add(cyl(0.04, 2.2, 6), WOOD, "satin", T(xs[0] - 0.1, y, zz) @ R("Y", 90))
        for x in xs:
            p.add(cyl(0.04, 1.7, 6), WOOD, "satin", T(x, ys[0] - 0.1, zz) @ R("X", -90))
            for y in ys:
                p.add(torus(0.06, 0.018, 6, 3), ROPE, "fabric", T(x, y, zz))
        for i in range(9):
            p.add(box(0.22, 1.6, 0.04), tint(WOOD, rng, 0.12), "satin", T(2.1 + i * 0.23, 0.15, zz + 0.06))
    for y in ys:
        a, b = Vector((xs[0], y, top + 0.1)), Vector((xs[2], y, top + 2.9))
        p.add(tube([tuple(a), tuple(b)], 0.035, 5), WOOD_D, "satin")
    # A ladder up the side.
    for sx in (-0.18, 0.18):
        p.add(cyl(0.03, 3.2, 5), WOOD_D, "satin", T(4.5 + sx, 1.2, 0.0) @ R("Y", 8))
    for i in range(10):
        p.add(cyl(0.02, 0.36, 4), WOOD_D, "satin", T(4.5 + i * 0.044, 1.2, 0.3 + i * 0.3) @ R("Y", 90) @ T(0, 0, -0.18))
    # The crane: an A-frame and boom lifting a block on a rope.
    for sy in (-0.5, 0.5):
        p.add(cyl(0.06, 5.4, 6), WOOD_D, "satin", T(-4.2, sy, 0.0) @ R("X", sy * 9) @ R("Y", 10))
    boom = [(-3.75, 0.0, 5.2), (-1.5, 0.3, 6.0)]
    p.add(tube(boom, 0.05, 6), WOOD_D, "satin")
    p.add(tube([(-1.5, 0.3, 6.0), (-1.5, 0.3, 3.6)], 0.012, 4), ROPE, "fabric")
    p.add(rough(box(0.8, 0.6, 0.55, bevel=0.03), 0.02, rng), tint(STONE, rng), "matte", T(-1.5, 0.3, 3.3))
    p.add(tube([(-3.9, 0.0, 5.2), (-4.6, 1.8, 0.0)], 0.012, 4), ROPE, "fabric")
    # A ramp of packed earth and planks up the left side, and blocks waiting on the ground.
    for i in range(12):
        t = i / 11
        p.add(box(0.9, 0.24, 0.05), tint(WOOD, rng, 0.15), "satin",
              T(-5.6 + t * 2.4, 2.4 - t * 0.2, 0.05 + t * 1.5) @ R("Y", -32))
    for i in range(8):
        x = -4.6 + (i % 4) * 0.62 + rng.uniform(-0.05, 0.05)
        zz = 0.2 + (i // 4) * 0.4
        p.add(rough(box(0.56, 0.44, 0.38, bevel=0.03), 0.015, rng), tint(STONE, rng, 0.1), "matte",
              T(x, 3.4 - (i // 4) * 0.1, zz) @ R("Z", rng.uniform(-8, 8)))


def chain_span(p, rng):
    """A metre of iron chain with a shackle at each end, sagging a little; along +X."""
    n = 13
    for k in range(n):
        t = (k + 0.5) / n
        x = -0.5 + t
        z = -0.06 * math.sin(math.pi * t)
        p.add(torus(0.032, 0.0085, 10, 4), IRON, "satin",
              T(x, 0, z) @ R("X", 90 * (k % 2)) @ S(1.6, 1.0, 1.0))
    for x in (-0.53, 0.53):
        p.add(torus(0.07, 0.016, 12, 5), IRON, "satin", T(x, 0, 0) @ R("Y", 90))


# --------------------------------------------------------------- the war

def war_banner(p, rng):
    """A plain war banner: an ash pole with a crossbar and a long cloth, torn at the hem."""
    p.add(cyl(0.035, 3.6, 8), WOOD, "satin", T(0, 0, 0))
    p.add(cyl(0.05, 0.25, 6, r2=0.0), IRON, "satin", T(0, 0, 3.6))
    p.add(cyl(0.022, 1.1, 6), WOOD_D, "satin", T(-0.55, 0, 3.3) @ R("Y", 90))
    W, Hc = 1.0, 1.6
    cut = [rng.uniform(0.0, 0.25) for _ in range(11)]

    def h(x, y):
        return 0.0
    cl = bmesh.new()
    cols, rows = 10, 14
    vs = []
    for i in range(cols + 1):
        col = []
        for j in range(rows + 1):
            u, v = i / cols, j / rows
            drop = Hc * v
            if j == rows:
                drop -= cut[i] * Hc * 0.4
            y = 0.06 * math.sin(u * 7.0 + v * 2.0) * (0.3 + v)
            col.append(cl.verts.new((-W / 2 + W * u, y, 3.28 - drop)))
        vs.append(col)
    for i in range(cols):
        for j in range(rows):
            cl.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]))
    p.add(cl, (0.5, 0.16, 0.12), "fabric", shade=lambda c: (0.52, 0.17, 0.12) if c.z > 2.0 else (0.38, 0.12, 0.1))


def sword(p, rng):
    """An arming sword, grip at the origin, blade along +Z."""
    blade = [(-0.024, 0.0), (0.024, 0.0), (0.02, 0.62), (0.0, 0.72), (-0.02, 0.62)]
    p.add(slab(blade, 0.008), STEEL, "mirror", T(0, 0, 0.1))
    p.add(box(0.2, 0.025, 0.025, bevel=0.006), IRON, "satin", T(0, 0, 0.09))
    p.add(cyl(0.016, 0.16, 8), LEATHER, "satin", T(0, 0, -0.07))
    p.add(sphere(0.026, 8, 6), IRON, "satin", T(0, 0, -0.09))


def longbow(p, rng):
    """A yew longbow, grip at the origin, limbs along Z, bent toward +Y; and its string."""
    pts = [(0.0, 0.18 * (1 - (z / 0.85) ** 2) - 0.18, z) for z in [k * 0.85 / 8 for k in range(-8, 9)]]
    radii = [0.009 + 0.012 * (1 - abs(k) / 8) for k in range(-8, 9)]
    p.add(tube(pts, radii, 6), (0.62, 0.42, 0.24), "satin")
    p.add(tube([pts[0], pts[-1]], 0.002, 3), WHITE, "fabric")
    p.add(cyl(0.024, 0.12, 8), LEATHER, "satin", T(0, -0.0, -0.06))


def ground(p, rng, palette, sx=44.0, sy=24.0):
    """Rolling ground, z ~ 0: dusty earth, or the war's bloodied mud."""
    seeds = [(rng.uniform(0, 6.28), rng.uniform(0.15, 0.5), rng.uniform(0.15, 0.5)) for _ in range(5)]

    def h(x, y):
        return sum(0.05 * math.sin(x * a + ph) * math.cos(y * b + ph) for ph, a, b in seeds)

    def shade(c):
        n = sum(math.sin(c.x * a * 3 + ph) * math.cos(c.y * b * 3 - ph) for ph, a, b in seeds) / 5.0
        lo, hi, blood = palette
        col = K.mix(lo, hi, 0.5 + 0.5 * n)
        if blood and n > 0.45:
            col = K.mix(col, blood, min((n - 0.45) * 3.0, 0.8))
        return col
    p.add(grid(66, 36, sx, sy, h), palette[0], "matte", shade=shade)


# --------------------------------------------------------------- the Treaty

def treaty_table(p, rng):
    """A long carved oak table, a velvet runner, two gilt candelabra, an inkwell and quills."""
    L, D, H = 3.4, 1.5, 0.9
    p.add(box(L, D, 0.07, bevel=0.025), OAK_T, "satin", T(0, 0, H - 0.035))
    p.add(box(L - 0.12, D - 0.12, 0.12, bevel=0.01), K.darker(OAK_T, 0.2), "satin", T(0, 0, H - 0.13))
    for sx in (-1, 1):
        for x in (-1.45, 0.0, 1.45):
            p.add(K.turned_leg(H - 0.19, 0.06), OAK_T, "satin", T(x, sx * 0.62, 0.0))
    for sy in (-1, 1):
        for i in range(8):
            x = -1.5 + i * 3.0 / 7
            p.add(K.scroll(0.05, 1.3, 12, 0.008), GILT, "gold", T(x, sy * (D / 2 - 0.05), H - 0.13) @ R("Z", 90 - sy * 90))
    p.add(box(0.5, D + 0.3, 0.008), VELVET, "fabric", T(0, 0, H + 0.004))
    for sy in (-1, 1):
        p.add(box(0.5, 0.008, 0.3), VELVET, "fabric", T(0, sy * (D / 2 + 0.15), H - 0.15))
        p.add(box(0.52, 0.012, 0.02), GILT, "gold", T(0, sy * (D / 2 + 0.15), H - 0.3))
    for x in (-1.25, 1.25):
        stem = [(0.09, 0.0), (0.05, 0.02), (0.02, 0.06), (0.025, 0.2), (0.015, 0.34), (0.02, 0.36)]
        p.add(K.lathe(stem, 10), GILT, "gold", T(x, 0.0, H))
        for k in range(5):
            a = 2 * math.pi * k / 5
            ox, oy = math.cos(a) * 0.13, math.sin(a) * 0.13
            p.add(tube([(x, 0, H + 0.3), (x + ox * 0.6, oy * 0.6, H + 0.28), (x + ox, oy, H + 0.34)], 0.008, 4), GILT, "gold")
            p.add(cyl(0.012, 0.12, 6), WHITE, "satin", T(x + ox, oy, H + 0.34))
            p.add(sphere(0.012, 6, 4), WARM, "glow", T(x + ox, oy, H + 0.48) @ S(0.8, 0.8, 1.6))
        p.add(cyl(0.014, 0.16, 6), WHITE, "satin", T(x, 0, H + 0.36))
        p.add(sphere(0.014, 6, 4), WARM, "glow", T(x, 0, H + 0.54) @ S(0.8, 0.8, 1.6))
    # Inkwell and two quills by the parchment.
    p.add(K.lathe([(0.04, 0.0), (0.045, 0.02), (0.035, 0.05), (0.018, 0.06), (0.02, 0.07)], 10), INKC, "glass",
          T(0.8, -0.3, H))
    for k, ang in enumerate((18, -10)):
        sh = [(0.8, -0.3, H + 0.06), (0.8 + 0.06 * (k * 2 - 1), -0.26, H + 0.2), (0.8 + 0.1 * (k * 2 - 1), -0.2, H + 0.34)]
        p.add(tube(sh, [0.003, 0.004, 0.002], 4), WHITE, "satin")
        for t in range(6):
            v = Vector(sh[1]).lerp(Vector(sh[2]), t / 5)
            p.add(box(0.05, 0.002, 0.012), WHITE, "fabric", T(v.x, v.y, v.z) @ R("Y", ang + 60))


def treaty_parchment(p, rng):
    """The Treaty: a wide sheet with curled ends, ruled with lines of text and six
    signatures under it."""
    W, D = 1.3, 0.9

    def h(x, y):
        e = max(abs(x) - (W / 2 - 0.12), 0.0)
        return e * e * 4.0
    p.add(grid(26, 18, W, D, h), PARCH, "fabric",
          shade=lambda c: K.mix(PARCH, (0.76, 0.66, 0.5), min(abs(c.x) / (W / 2), 1.0) ** 3))
    for j in range(13):
        y = D / 2 - 0.1 - j * 0.045
        x = -W / 2 + 0.16
        while x < W / 2 - 0.2:
            ln = rng.uniform(0.04, 0.12)
            p.add(box(ln, 0.006, 0.0015), INKC, "matte", T(x + ln / 2, y, 0.002))
            x += ln + 0.02
    for k in range(6):
        x = -0.45 + k * 0.18
        pts = [(x + 0.012 * i, -D / 2 + 0.13 + 0.012 * math.sin(i * 1.7 + k), 0.003) for i in range(9)]
        p.add(tube(pts, 0.002, 3), INKC, "matte")


def treaty_seal(p, rng):
    """The seal: a turned ebony handle on a brass matrix; base at the origin."""
    p.add(K.lathe([(0.09, 0.0), (0.09, 0.03), (0.06, 0.05), (0.035, 0.08), (0.03, 0.22), (0.05, 0.3),
                   (0.06, 0.38), (0.045, 0.45), (0.0, 0.47)], 14), (0.12, 0.09, 0.08), "satin")
    p.add(K.lathe([(0.11, 0.0), (0.11, 0.03), (0.09, 0.045), (0.0, 0.05)], 16), BRASS, "gold")
    p.add(torus(0.05, 0.008, 12, 4), GILT, "gold", T(0, 0, 0.33))


def treaty_wax(p, rng):
    """The pressed wax: a red disc with a raised rim and the seal's mark, the Wall's line
    between a star (the North) and a sun (the South)."""
    p.add(K.lathe([(0.16, 0.0), (0.165, 0.008), (0.14, 0.016), (0.12, 0.012), (0.0, 0.012)], 18), WAX, "satin")
    p.add(box(0.2, 0.012, 0.006), K.darker(WAX, 0.3), "satin", T(0, 0, 0.014))
    p.add(ico(0.025, 1), K.darker(WAX, 0.2), "satin", T(0, 0.055, 0.014) @ S(1, 1, 0.3))
    p.add(cyl(0.028, 0.006, 8), K.darker(WAX, 0.2), "satin", T(0, -0.055, 0.012))


# --------------------------------------------------------------- the Archerons' fall

def window(p, x, y, z, w, h, lit, arched=False):
    out = arched_outline(w, h, 6) if arched else [(-w / 2, 0), (w / 2, 0), (w / 2, h), (-w / 2, h)]
    p.add(slab(out, 0.04), WARM if lit else (0.2, 0.22, 0.3), "glow" if lit else "glass", T(x, y + 0.01, z))
    p.add(K.frame_ring(out, 0.025, 0.04), WHITE, "satin", T(x, y + 0.04, z))
    p.add(box(0.02, 0.03, h - 0.05), WHITE, "satin", T(x, y + 0.04, z + h / 2 - 0.02))
    p.add(box(w, 0.03, 0.02), WHITE, "satin", T(x, y + 0.04, z + h * 0.55))
    p.add(box(w + 0.12, 0.08, 0.05), CREAM_S, "matte", T(x, y + 0.04, z - 0.03))


def hip_roof(p, w, d, h, x, y, z, col):
    bm = bmesh.new()
    r = min(w, d) / 2
    a = [bm.verts.new(v) for v in ((-w / 2, -d / 2, 0), (w / 2, -d / 2, 0), (w / 2, d / 2, 0), (-w / 2, d / 2, 0))]
    t0 = bm.verts.new((-w / 2 + r, 0, h))
    t1 = bm.verts.new((w / 2 - r, 0, h))
    bm.faces.new((a[0], a[1], t1, t0))
    bm.faces.new((a[2], a[3], t0, t1))
    bm.faces.new((a[1], a[2], t1))
    bm.faces.new((a[3], a[0], t0))
    bm.faces.new(list(reversed(a)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    p.add(bm, col, "satin", T(x, y, z), smooth=False)


def archeron_manor(p, rng):
    """A rich merchant's country manor: a three-storey centre with a columned portico and
    pediment, two-storey wings, hipped slate roofs, tall chimneys, quoins and a roof
    balustrade; every window lit for a party, a fanlight over the door."""
    cw, cd, ch = 6.0, 4.0, 6.6
    ww, wd, wh = 3.4, 3.4, 4.6
    p.add(box(cw, cd, ch), CREAM_S, "matte", T(0, 0, ch / 2))
    for sx in (-1, 1):
        p.add(box(ww, wd, wh), CREAM_S, "matte", T(sx * (cw / 2 + ww / 2), -0.2, wh / 2))
        hip_roof(p, ww + 0.3, wd + 0.3, 1.3, sx * (cw / 2 + ww / 2), -0.2, wh, SLATE)
        p.add(box(ww + 0.2, wd + 0.2, 0.16), WHITE, "satin", T(sx * (cw / 2 + ww / 2), -0.2, wh - 0.08))
        for i in range(3):
            x = sx * (cw / 2 + 0.6 + i * 1.1)
            window(p, x, wd / 2 - 0.2, 0.7, 0.6, 1.5, True, arched=True)
            window(p, x, wd / 2 - 0.2, 2.8, 0.6, 1.3, rng.random() < 0.85)
        p.add(box(0.5, 0.5, 1.6), K.darker(CREAM_S, 0.1), "matte", T(sx * (cw / 2 + ww - 0.5), -0.6, wh + 0.9))
        for k in (-0.12, 0.12):
            p.add(cyl(0.07, 0.25, 8), (0.62, 0.36, 0.26), "matte", T(sx * (cw / 2 + ww - 0.5) + k, -0.6, wh + 1.7))
    hip_roof(p, cw + 0.3, cd + 0.3, 1.8, 0, 0, ch, SLATE)
    p.add(box(cw + 0.25, cd + 0.25, 0.2), WHITE, "satin", T(0, 0, ch - 0.1))
    for zz in (2.2, 4.4):
        p.add(box(cw + 0.06, cd + 0.06, 0.12), WHITE, "satin", T(0, 0, zz))
    # Quoins at the centre's corners.
    for sx in (-1, 1):
        for k in range(11):
            wq = 0.42 if k % 2 else 0.3
            p.add(box(wq, 0.06, 0.28), WHITE, "matte", T(sx * (cw / 2 - wq / 2 + 0.02), cd / 2 + 0.02, 0.3 + k * 0.58))
    for i in range(5):
        x = -2.4 + i * 1.2
        if i != 2:
            window(p, x, cd / 2, 0.6, 0.7, 1.4, True, arched=True)
        window(p, x, cd / 2, 2.6, 0.7, 1.4, rng.random() < 0.9)
        window(p, x, cd / 2, 4.8, 0.6, 1.0, rng.random() < 0.7)
    # Roof balustrade on the centre.
    for i in range(24):
        x = -cw / 2 + 0.2 + i * (cw - 0.4) / 23
        p.add(K.lathe([(0.04, 0.0), (0.06, 0.06), (0.03, 0.2), (0.045, 0.26)], 6), WHITE, "satin", T(x, cd / 2 + 0.05, ch))
    p.add(box(cw, 0.14, 0.06), WHITE, "satin", T(0, cd / 2 + 0.05, ch + 0.29))
    # The portico: four columns, an entablature, a pediment, the door and fanlight, steps.
    py = cd / 2 + 1.2
    for x in (-1.3, -0.45, 0.45, 1.3):
        p.add(cyl(0.16, 0.12, 12, r2=0.13), WHITE, "satin", T(x, py, 0.55))
        p.add(cyl(0.13, 2.9, 12, r2=0.11), WHITE, "satin", T(x, py, 0.67))
        p.add(box(0.34, 0.34, 0.12), WHITE, "satin", T(x, py, 3.62))
    p.add(box(3.2, 1.5, 0.3), WHITE, "satin", T(0, cd / 2 + 0.75, 3.83))
    ped = [(-1.7, 0.0), (1.7, 0.0), (0.0, 0.9)]
    p.add(slab(ped, 1.5), WHITE, "satin", T(0, cd / 2 + 0.75, 3.98))
    p.add(slab(arched_outline(1.0, 2.2, 8), 0.06), (0.24, 0.15, 0.1), "satin", T(0, cd / 2 + 0.01, 0.55))
    p.add(slab([(0.5 * math.cos(math.pi * k / 8), 0.5 * math.sin(math.pi * k / 8)) for k in range(9)], 0.04),
          WARM, "glow", T(0, cd / 2 + 0.04, 2.25))
    for k in range(4):
        p.add(box(3.6 - k * 0.2, 0.45, 0.14), CREAM_S, "matte", T(0, py + 0.9 - k * 0.42, 0.07 + k * 0.14))
    p.add(box(3.4, 2.2, 0.55), CREAM_S, "matte", T(0, cd / 2 + 1.0, 0.27))
    # A gravel sweep with two clipped yews and gate piers.
    for sx in (-1, 1):
        p.add(K.lathe([(0.5, 0.0), (0.55, 0.3), (0.4, 1.2), (0.12, 1.9), (0.0, 2.0)], 10), (0.2, 0.32, 0.2), "leaf",
              T(sx * 3.4, cd / 2 + 2.4, 0))
        p.add(box(0.5, 0.5, 1.6), CREAM_S, "matte", T(sx * 5.4, cd / 2 + 3.6, 0.8))
        p.add(sphere(0.25, 10, 8), WHITE, "satin", T(sx * 5.4, cd / 2 + 3.6, 1.85))


def carried_chest(p, rng):
    p.add(box(0.62, 0.42, 0.34, bevel=0.02), OAK_T, "satin", T(0, 0, 0.17))
    p.add(K.lathe([(0.0, -0.31), (0.21, -0.31), (0.21, 0.31), (0.0, 0.31)], 10, cap_bottom=False, cap_top=False),
          OAK_T, "satin", T(0, 0, 0.34) @ R("Y", 90) @ S(1.0, 1.0, 1.0))
    for x in (-0.22, 0.0, 0.22):
        p.add(box(0.04, 0.44, 0.36), IRON, "satin", T(x, 0, 0.18))
    p.add(box(0.08, 0.02, 0.1), BRASS, "gold", T(0, 0.22, 0.3))


def carried_frame(p, rng):
    w, h = 0.9, 0.7
    p.add(box(w - 0.1, 0.03, h - 0.1), (0.24, 0.3, 0.3), "satin", T(0, 0, h / 2))
    for (sx, sz, x, z) in [(w, 0.07, 0, 0.035), (w, 0.07, 0, h - 0.035), (0.07, h, -w / 2 + 0.035, h / 2),
                           (0.07, h, w / 2 - 0.035, h / 2)]:
        p.add(box(sx, 0.06, sz, bevel=0.01), GILT, "gold", T(x, 0, z))


def carried_chair(p, rng):
    p.add(box(0.48, 0.46, 0.06, bevel=0.01), (0.55, 0.2, 0.25), "fabric", T(0, 0, 0.46))
    for x in (-0.2, 0.2):
        for y in (-0.19, 0.19):
            p.add(K.cabriole(0.43, 0.025), OAK_T, "satin", T(x, y, 0.0))
    p.add(box(0.44, 0.04, 0.5, bevel=0.01), OAK_T, "satin", T(0, -0.21, 0.74))
    p.add(box(0.34, 0.03, 0.36), (0.55, 0.2, 0.25), "fabric", T(0, -0.19, 0.74))


# --------------------------------------------------------------- the ships

def merchant_ship(p, rng):
    """A three-masted merchant ship, broadside along X (bow at +X): a lofted hull with a
    sheer, a gilt wale, a raised stern with lit windows, a forecastle, three masts with
    billowing square sails, a lateen mizzen, a bowsprit and jib, standing rigging."""
    L, B, Dp = 3.0, 0.8, 0.62
    ns, nr = 22, 9
    rings = []
    hull = bmesh.new()
    for i in range(ns + 1):
        s = i / ns
        x = -L / 2 + L * s
        beam = B / 2 * (math.sin(math.pi * min(s * 1.25, 1.0) * 0.5 + 0.35) if s < 0.8 else
                        (1.0 - (s - 0.8) / 0.2) ** 0.7 * 0.98)
        if s < 0.08:
            beam *= 0.85 + s * 1.8
        sheer = 0.08 * ((2 * s - 1) ** 2) + (0.12 if s < 0.18 else 0.0)
        keel = -Dp * (0.75 + 0.25 * math.sin(math.pi * s)) * (0.4 if s > 0.97 else 1.0)
        ring = []
        for j in range(nr + 1):
            a = math.pi * j / nr  # 0 = port deck edge, pi = starboard
            yy = math.cos(a) * beam
            zz = sheer + (keel - sheer) * math.sin(a) ** 0.8
            ring.append(hull.verts.new((x, yy, zz)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for j in range(nr):
            hull.faces.new((a[j], b[j], b[j + 1], a[j + 1]))
    hull.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(hull, faces=hull.faces)

    def hull_shade(c):
        if c.z > -0.05 and c.z < 0.02:
            return GILT
        if c.z < -0.3:
            return (0.22, 0.24, 0.2)
        return HULL
    p.add(hull, HULL, "satin", shade=hull_shade)
    # Deck, bulwark rail, the raised stern and forecastle.
    p.add(box(L * 0.95, B * 0.82, 0.03), (0.6, 0.48, 0.32), "satin", T(0.0, 0, 0.04))
    for sy in (-1, 1):
        p.add(box(L * 0.9, 0.03, 0.08), WOOD_D, "satin", T(0.0, sy * B * 0.43, 0.14))
    p.add(box(0.7, B * 0.88, 0.42, bevel=0.02), HULL, "satin", T(-L / 2 + 0.38, 0, 0.28))
    p.add(box(0.74, B * 0.92, 0.04), GILT, "gold", T(-L / 2 + 0.38, 0, 0.5))
    for k in range(4):
        p.add(box(0.03, 0.08, 0.1), WARM, "glow", T(-L / 2 + 0.02, -0.24 + k * 0.16, 0.3))
    p.add(sphere(0.04, 8, 6), WARM, "glow", T(-L / 2 - 0.02, 0, 0.6))
    p.add(box(0.5, B * 0.7, 0.24, bevel=0.02), HULL, "satin", T(L / 2 - 0.42, 0, 0.2))
    # Masts and sails.
    masts = [(0.75, 2.5), (0.0, 2.9), (-0.8, 2.1)]
    tops = []
    for k, (mx, mh) in enumerate(masts):
        p.add(cyl(0.03, mh, 8, r2=0.015), WOOD_D, "satin", T(mx, 0, 0.04))
        tops.append((mx, 0.0, mh))
        if k < 2:
            for (z0, z1, wd) in ((0.45, 1.35, 1.0), (1.45, 2.15 if k else 1.95, 0.8)):
                wd *= 0.9 if k == 0 else 1.0
                p.add(cyl(0.012, wd + 0.1, 6), WOOD_D, "satin", T(mx, -wd / 2 - 0.05, z1) @ R("X", -90))
                sail = grid(8, 8, wd, z1 - z0, lambda x, y: 0.0)
                for v in sail.verts:
                    u = (v.co.x + wd / 2) / wd
                    t = (v.co.y + (z1 - z0) / 2) / (z1 - z0)
                    bulge = 0.16 * math.sin(math.pi * u) * math.sin(math.pi * (0.15 + 0.85 * t))
                    v.co = Vector((mx + bulge, v.co.x, z0 + t * (z1 - z0)))
                p.add(sail, SAIL, "fabric")
        else:
            sail = bmesh.new()
            a, b, c = sail.verts.new((mx + 0.5, 0, 1.9)), sail.verts.new((mx - 0.6, 0, 0.5)), sail.verts.new((mx + 0.1, 0, 0.45))
            sail.faces.new((a, b, c))
            p.add(sail, SAIL, "fabric")
            p.add(tube([(mx + 0.55, 0, 1.95), (mx - 0.65, 0, 0.45)], 0.01, 5), WOOD_D, "satin")
    # Bowsprit and jib.
    p.add(tube([(L / 2 - 0.2, 0, 0.2), (L / 2 + 0.75, 0, 0.6)], 0.022, 6), WOOD_D, "satin")
    jib = bmesh.new()
    j0, j1, j2 = jib.verts.new((L / 2 + 0.7, 0, 0.6)), jib.verts.new((masts[0][0] + 0.04, 0, 2.2)), jib.verts.new((masts[0][0] + 0.15, 0, 0.5))
    jib.faces.new((j0, j1, j2))
    p.add(jib, SAIL, "fabric")
    # Standing rigging: stays fore and aft, shrouds to the sides.
    lines = [((L / 2 + 0.74, 0, 0.6), tops[0]), (tops[0], tops[1]), (tops[1], tops[2]), (tops[2], (-L / 2 + 0.05, 0, 0.5))]
    for mx, _, mh in tops:
        for sy in (-1, 1):
            for dx in (-0.12, 0.0, 0.12):
                lines.append(((mx, 0, mh * 0.9), (mx + dx, sy * B * 0.46, 0.14)))
    for a, b in lines:
        p.add(tube([a, b], 0.004, 3, caps=False), (0.25, 0.2, 0.15), "matte")
    p.add(box(0.3, 0.004, 0.08), (0.75, 0.62, 0.3), "fabric", T(tops[1][0] - 0.15, 0, tops[1][2] - 0.02))


def storm_sea(p, rng):
    """A storm-swollen sea: long swells, crests paler; z ~ 0."""
    waves = [(rng.uniform(0, 6.28), rng.uniform(0.4, 0.9), rng.uniform(-0.5, 0.5), rng.uniform(0.08, 0.2)) for _ in range(6)]

    def h(x, y):
        return sum(a * math.sin(x * k + y * dk + ph) for ph, k, dk, a in waves) * 0.6

    def shade(c):
        hh = h(c.x, c.y)
        return K.mix((0.03, 0.06, 0.1), (0.22, 0.3, 0.36), min(max(hh * 1.6 + 0.3, 0.0), 1.0))
    p.add(grid(80, 40, 40.0, 20.0, h), (0.05, 0.1, 0.16), "water", shade=shade)


BUILDERS = {
    "fae_palace_a": lambda p, r: fae_palace(p, r, 9.0, 7),
    "fae_palace_b": lambda p, r: fae_palace(p, r, 6.5, 5),
    "fae_palace_c": lambda p, r: fae_palace(p, r, 11.0, 9),
    "court_terrace": court_terrace,
    "feral_temple": feral_temple,
    "stone_block": stone_block,
    "chain_span": chain_span,
    "war_banner": war_banner,
    "sword": sword,
    "longbow": longbow,
    "ground_dust": lambda p, r: ground(p, r, ((0.36, 0.28, 0.22), (0.5, 0.4, 0.3), None)),
    "ground_mud": lambda p, r: ground(p, r, ((0.2, 0.15, 0.12), (0.34, 0.26, 0.2), (0.36, 0.06, 0.05))),
    "treaty_table": treaty_table,
    "treaty_parchment": treaty_parchment,
    "treaty_seal": treaty_seal,
    "treaty_wax": treaty_wax,
    "archeron_manor": archeron_manor,
    "carried_chest": carried_chest,
    "carried_frame": carried_frame,
    "carried_chair": carried_chair,
    "merchant_ship": merchant_ship,
    "storm_sea": storm_sea,
}


def main():
    want = [a for a in sys.argv[1:] if a in BUILDERS] or list(BUILDERS)
    os.makedirs(OUT, exist_ok=True)
    for pid in want:
        K.reset()
        p = FilmProp(pid)
        BUILDERS[pid](p, random.Random(pid))
        ob = p.to_object(pid)
        print(f"  {pid:18s} {K.mesh_tris(ob):6d} tris")
        K.export_glb([ob], os.path.join(OUT, pid + ".glb"))


if __name__ == "__main__":
    main()
