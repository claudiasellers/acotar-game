"""Generates the Spring Court manor's façade kit (headless Blender, deterministic).

Run:  /opt/bpyenv/bin/python tools/blender/manor_facade.py [--preview dir]
Out:  world/spring_court/manor_estate/house/facade/models/<id>.glb
      Nodes "<id>" and "<id>_lod1" (~50% tris).

Kit convention (Blender metres, no fitting): X runs along the wall, the wall
face is the plane y=0 and pieces stand proud toward -Y (Godot +Z after the
glTF Y-up export), Z is up with the piece's foot at z=0 and x centred.
ManorFacade (house/facade/manor_facade.gd) places them with MultiMeshes.

Stone trim stays at or below 0.85 albedo (L18-4 glare rule). Gilt is the
kit's soft gold. Roses, ivy and wisteria are R3 storybook blooms.

Budgets (R4): <= 3,000 tris per piece, LOD1 ~50%. The run fails if one is over.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,I001
import prop_kit as K  # noqa: E402
from prop_kit import R, S, T  # noqa: E402

OUT = os.path.join(K.ROOT, "world/spring_court/manor_estate/house/facade/models")
MAX_TRIS = 3000

# Kit sizes shared with manor_facade.gd (keep in step).
STOREY = 4.8          # ManorSitePlan.HOUSE_STOREY
WIN_W = 1.5           # ManorHouseBuilder.WINDOW_WIDTH
WIN_H = 2.6           # window opening height (SILL 0.9 to 3.5)
TILE = 2.0            # length of one course / cornice tile

# Trim palette (sRGB, max channel <= 0.85).
TRIM = (0.85, 0.81, 0.77)        # dressed cream stone
TRIM_SHADE = (0.78, 0.72, 0.72)  # recessed fields, a touch rosier
TRIM_BLUSH = (0.85, 0.74, 0.76)  # tympanum and panels
GILT = K.GOLD
SHUTTER = (0.74, 0.74, 0.92)     # soft periwinkle-lilac
SHUTTER_SLAT = (0.68, 0.68, 0.88)
IRON = (0.42, 0.38, 0.52)        # lilac-black wrought iron
LEAF = K.SAGE
LEAF_DARK = K.SAGE_DEEP
IVY = (0.30, 0.55, 0.47)
IVY_LIGHT = (0.45, 0.70, 0.55)
ROSES = [(0.98, 0.62, 0.74), (1.0, 0.80, 0.84), (0.96, 0.50, 0.64), (0.99, 0.93, 0.90), (0.98, 0.72, 0.62)]
WISTERIA = [(0.78, 0.66, 0.95), (0.70, 0.58, 0.92), (0.86, 0.76, 0.98)]


def prof_x(outline, length):
    """Extrudes a profile [(out, z)] (out >= 0 = proud of the wall) along X, centred on x=0."""
    bm = K.slab([(-o, z) for o, z in outline], length)
    bmesh_rotate(bm, R("Z", 90))
    return bm


def bmesh_rotate(bm, m):
    import bmesh
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)


def bx(sx, sy_out, sz, x=0.0, z=0.0, out0=0.0, bevel=0.0):
    """Box from the wall outward: x centre, foot at z, back at y=-out0."""
    return K.box(sx, sy_out, sz, bevel=bevel), T(x, -(out0 + sy_out / 2), z + sz / 2)


def add_box(p, color, sx, so, sz, x=0.0, z=0.0, out0=0.0, bevel=0.0, finish="matte"):
    b, m = bx(sx, so, sz, x, z, out0, bevel)
    p.add(b, color, finish, m, smooth=False)


# ------------------------------------------------------------------ architecture


def pilaster(p):
    """Fluted Ionic pilaster, one storey tall, 0.8 m wide, 0.22 m proud."""
    w, d = 0.8, 0.22
    add_box(p, TRIM, w + 0.16, d + 0.08, 0.38, bevel=0.02)                 # plinth
    p.add(prof_x([(0, 0), (d + 0.06, 0), (d + 0.02, 0.07), (d, 0.12), (0, 0.12)], w + 0.06), TRIM, "matte",
          T(0, 0, 0.38), smooth=False)                                         # base moulding
    shaft_h = STOREY - 0.38 - 0.12 - 0.62
    add_box(p, TRIM, w, d, shaft_h, z=0.5)
    for i in range(4):                                                         # flute fillets
        x = -w / 2 + w * (i + 0.5) / 4
        add_box(p, TRIM_SHADE, 0.07, 0.02, shaft_h - 0.3, x=x, z=0.65, out0=d - 0.012)
    top = 0.5 + shaft_h
    add_box(p, GILT, w + 0.04, 0.06, 0.08, z=top, out0=d - 0.02, finish="gold")   # gilt astragal
    p.add(prof_x([(0, 0), (d + 0.04, 0), (d + 0.14, 0.22), (0, 0.22)], w + 0.1), TRIM, "matte",
          T(0, 0, top + 0.08), smooth=False)                                   # echinus
    for s in (-1, 1):                                                          # volutes
        p.add(K.scroll(0.16, turns=1.6, n=16, thick=0.035, y=0.0), GILT, "gold",
              T(s * (w / 2 + 0.02), -d - 0.12, top + 0.2) @ (R("Z", 180) if s < 0 else R("Z", 0)) @ R("X", 0))
    add_box(p, TRIM, w + 0.34, d + 0.2, 0.14, z=top + 0.3, bevel=0.015)        # abacus
    p.add(K.sphere(0.07, 8, 6), (0.98, 0.62, 0.74), "satin", T(0, -d - 0.12, top + 0.2))  # rose boss
    add_box(p, TRIM, w + 0.2, d + 0.06, STOREY - (top + 0.44), z=top + 0.44)


def string_course(p):
    """Storey band: fillet, torus, cyma; 0.5 m tall, 2 m tile."""
    p.add(prof_x([(0, 0), (0.12, 0), (0.12, 0.1), (0.2, 0.16), (0.24, 0.25), (0.2, 0.33), (0.26, 0.4),
                  (0.26, 0.5), (0, 0.5)], TILE), TRIM, "matte", smooth=False)
    add_box(p, GILT, TILE, 0.04, 0.05, z=0.42, out0=0.25, finish="gold")


def eaves_cornice(p):
    """Crowning cornice: architrave, frieze, dentils, corona, cyma; 1.2 m tall."""
    p.add(prof_x([(0, 0), (0.1, 0), (0.1, 0.12), (0.14, 0.16), (0.14, 0.3), (0, 0.3)], TILE), TRIM, "matte",
          smooth=False)                                                        # architrave
    add_box(p, TRIM_BLUSH, TILE, 0.1, 0.36, z=0.3)                             # frieze
    for i in range(10):                                                        # dentils
        add_box(p, TRIM, 0.11, 0.16, 0.16, x=-TILE / 2 + 0.1 + i * 0.2, z=0.66, out0=0.1)
    p.add(prof_x([(0, 0.82), (0.32, 0.82), (0.4, 0.86), (0.56, 0.9), (0.56, 1.02), (0.62, 1.08),
                  (0.62, 1.2), (0, 1.2)], TILE), TRIM, "matte", smooth=False)  # corona + cyma
    add_box(p, TRIM, TILE, 0.14, 0.16, z=0.66)
    for i in range(4):                                                         # gilt rosettes in the frieze
        p.add(K.disc(0.07, 8, 0.0), GILT, "gold", T(-TILE / 2 + 0.25 + i * 0.5, -0.101, 0.48) @ R("X", 90))


def plinth(p):
    """Base course along the foot of the walls: 1.0 m, chamfered top."""
    p.add(prof_x([(0, 0), (0.22, 0), (0.22, 0.8), (0.12, 0.95), (0, 0.95)], TILE), TRIM_SHADE, "matte",
          smooth=False)


def _architrave(p, w=WIN_W, h=WIN_H, band=0.2, d=0.1, ears=False):
    """Moulded frame around the opening (opening from z=0 to h)."""
    add_box(p, TRIM, band, d, h, x=-(w + band) / 2)
    add_box(p, TRIM, band, d, h, x=(w + band) / 2)
    add_box(p, TRIM, w + band * 2, d, band, z=h)
    add_box(p, GILT, w + band * 2 + 0.02, 0.05, 0.05, z=h + band - 0.025, out0=d - 0.01, finish="gold")
    if ears:                                                                   # crossettes
        for s in (-1, 1):
            add_box(p, TRIM, 0.14, d, 0.3, x=s * (w / 2 + band + 0.07), z=h - 0.1)
    # sill on consoles
    add_box(p, TRIM, w + band * 2 + 0.3, 0.26, 0.12, z=-0.12, bevel=0.02)
    for s in (-1, 1):
        p.add(K.scroll(0.1, turns=1.2, n=10, thick=0.04), TRIM, "matte",
              T(s * (w / 2 + 0.1), -0.16, -0.24) @ R("Z", 90))
        add_box(p, TRIM, 0.16, 0.18, 0.3, x=s * (w / 2 + 0.1), z=-0.42)


def surround_arch(p):
    """Ground floor: architrave, blind lunette with a gilt sunburst, keystone."""
    _architrave(p)
    r = WIN_W / 2 + 0.2
    base = WIN_H + 0.2
    ring = K.arc_pts(0, base, r, r, 0, 180, 12)
    p.add(K.tube(ring, 0.1, 6), TRIM, "matte")                                 # arch moulding
    fan = K.slab([(0, base)] + [(x, z) for x, _, z in K.arc_pts(0, base, r - 0.1, r - 0.1, 0, 180, 12)], 0.04)
    p.add(fan, TRIM_BLUSH, "matte", T(0, -0.05, 0), smooth=False)              # tympanum
    for i in range(9):                                                         # sunburst rays
        a = math.radians(10 + i * 20)
        p.add(K.tube([(0, -0.08, base), (0.55 * math.cos(a), -0.08, base + 0.55 * math.sin(a))], 0.022, 4),
              GILT, "gold")
    p.add(K.sphere(0.1, 8, 6), GILT, "gold", T(0, -0.08, base) @ S(1, 0.5, 1))
    p.add(K.slab([(-0.14, 0), (0.14, 0), (0.2, 0.36), (-0.2, 0.36)], 0.2), TRIM, "matte",
          T(0, -0.12, base + r - 0.16), smooth=False)                          # keystone
    p.add(K.sphere(0.06, 6, 4), ROSES[0], "satin", T(0, -0.23, base + r + 0.02))


def surround_pediment(p):
    """Piano nobile: architrave, frieze, triangular pediment on consoles, rose in the tympanum."""
    _architrave(p, ears=True)
    top = WIN_H + 0.2
    add_box(p, TRIM_BLUSH, WIN_W + 0.4, 0.08, 0.26, z=top)                     # frieze
    add_box(p, GILT, 0.6, 0.03, 0.05, z=top + 0.1, out0=0.08, finish="gold")
    hw = WIN_W / 2 + 0.5
    add_box(p, TRIM, hw * 2, 0.24, 0.1, z=top + 0.26)                          # cornice shelf
    for s in (-1, 1):
        p.add(K.scroll(0.13, turns=1.3, n=10, thick=0.045), TRIM, "matte",
              T(s * (WIN_W / 2 + 0.28), -0.14, top + 0.1) @ R("Z", 90))
    tri = K.slab([(-hw, 0), (hw, 0), (0, 0.62)], 0.2)
    p.add(tri, TRIM, "matte", T(0, -0.1, top + 0.36), smooth=False)
    inner = K.slab([(-hw + 0.25, 0.06), (hw - 0.25, 0.06), (0, 0.46)], 0.04)
    p.add(inner, TRIM_BLUSH, "matte", T(0, -0.21, top + 0.36), smooth=False)
    K.bloom(p, (0, -0.24, top + 0.58), 0.13, ROSES[0], rings=2, per=5, rng=random.Random(3),
            finish="satin", tilt=R("X", 90))


def surround_segment(p):
    """Piano nobile alternate: segmental (curved) pediment over a garland."""
    _architrave(p, ears=True)
    top = WIN_H + 0.2
    hw = WIN_W / 2 + 0.45
    rad = hw / math.cos(math.radians(30))
    arc = K.arc_pts(0, -rad * math.sin(math.radians(30)), rad, rad * 0.8, 150, 30, 10)
    seg = [(-hw, 0.0)] + [(x, max(z, 0.0)) for x, _, z in arc[1:-1]] + [(hw, 0.0)]
    p.add(K.slab(seg, 0.2), TRIM, "matte", T(0, -0.1, top + 0.3), smooth=False)
    add_box(p, TRIM, hw * 2, 0.24, 0.1, z=top + 0.2)
    sw = K.arc_pts(0, top + 0.12, WIN_W / 2, 0.18, 180, 360, 8, y=-0.14)       # garland swag
    p.add(K.tube(sw, 0.05, 5), LEAF, "leaf")
    rng = random.Random(7)
    for i, (x, y, z) in enumerate(sw[1:-1:2]):
        K.bloom(p, (x, -0.2, z), 0.07, ROSES[i % 3], rings=2, per=4, rng=rng, finish="satin", tilt=R("X", 90))


def surround_simple(p):
    """Top floor: eared architrave and a small gilt shell."""
    _architrave(p, ears=True)
    top = WIN_H + 0.2
    for i in range(7):
        a = math.radians(15 + i * 25)
        p.add(K.tube([(0, -0.1, top), (0.28 * math.cos(a), -0.1, top + 0.28 * math.sin(a))], 0.03, 4), GILT, "gold")
    p.add(K.sphere(0.06, 6, 4), GILT, "gold", T(0, -0.11, top))


def shutters(p):
    """A pair of open louvred shutters either side of a window, periwinkle with gilt pulls."""
    sw, sh = WIN_W / 2 + 0.05, WIN_H
    for s in (-1, 1):
        cx = s * (WIN_W / 2 + 0.22 + sw / 2)
        add_box(p, SHUTTER, sw, 0.05, sh, x=cx, bevel=0.01, finish="satin")
        for i in range(10):
            add_box(p, SHUTTER_SLAT, sw - 0.12, 0.03, 0.06, x=cx, z=0.25 + i * 0.22, out0=0.05, finish="satin")
        p.add(K.sphere(0.035, 6, 4), GILT, "gold", T(cx - s * (sw / 2 - 0.08), -0.08, sh * 0.5))
        p.add(K.tube([(cx - sw / 2 + 0.08, -0.07, sh * 0.5 - 0.05), (cx + sw / 2 - 0.08, -0.07, sh * 0.5 + 0.05)],
                     0.012, 4), SHUTTER_SLAT, "satin")


def balcony(p):
    """Stone balcony on consoles with a balustrade and spilling rose boxes; floor at z=0."""
    w, d = 2.6, 1.0
    add_box(p, TRIM, w, d, 0.18, bevel=0.03)
    p.add(prof_x([(0, 0), (d + 0.08, 0), (d + 0.08, 0.06), (0, 0.06)], w + 0.16), TRIM, "matte",
          T(0, 0, -0.06), smooth=False)
    for s in (-1, 0, 1):                                                       # consoles
        x = s * (w / 2 - 0.3)
        p.add(K.scroll(0.22, turns=1.1, n=10, thick=0.07), TRIM, "matte", T(x, -0.4, -0.3) @ R("Z", 90))
        add_box(p, TRIM, 0.18, 0.5, 0.36, x=x, z=-0.42)
    n = 9
    for i in range(n):                                                         # front balusters
        x = -w / 2 + 0.2 + i * (w - 0.4) / (n - 1)
        p.add(K.turned_leg(0.62, 0.06, 5), TRIM, "matte", T(x, -d + 0.1, 0.24))
    for s in (-1, 1):                                                          # solid side panels
        add_box(p, TRIM_SHADE, 0.1, d - 0.3, 0.62, x=s * (w / 2 - 0.08), z=0.24, out0=0.1)
    add_box(p, TRIM, w, 0.12, 0.08, z=0.18, out0=d - 0.16)                     # bottom rail
    add_box(p, TRIM, w + 0.06, 0.2, 0.1, z=0.86, out0=d - 0.2, bevel=0.02)     # handrail
    for s in (-1, 1):
        add_box(p, TRIM, 0.12, d - 0.1, 0.1, x=s * (w / 2 - 0.06), z=0.86, bevel=0.02)
        add_box(p, TRIM, 0.18, 0.18, 0.78, x=s * (w / 2 - 0.09), z=0.18, out0=d - 0.2)   # newels
        p.add(K.sphere(0.1, 8, 6), GILT, "gold", T(s * (w / 2 - 0.09), -d + 0.11, 1.05))
    # rose box on the rail, roses spilling over the front
    rng = random.Random(11)
    add_box(p, (0.66, 0.74, 0.62), w - 0.5, 0.22, 0.16, z=0.96, out0=d - 0.24, finish="matte")
    for i in range(7):
        x = -w / 2 + 0.45 + i * (w - 0.9) / 6
        for j in range(3):
            lx = x + rng.uniform(-0.15, 0.15)
            p.add(K.leaf(0.14, 0.08), LEAF if j % 2 else LEAF_DARK, "leaf",
                  T(lx, -d + 0.12, 1.12) @ R("Z", rng.uniform(0, 360)) @ R("Y", -25))
        K.bloom(p, (x, -d + 0.1, 1.16 + rng.uniform(-0.03, 0.04)), 0.11, ROSES[i % 4], rings=2, per=4, rng=rng,
                finish="satin", tilt=R("X", 60))
    for i in range(3):                                                         # trailing strands
        x = -w / 2 + 0.6 + i * (w - 1.2) / 2
        pts = [(x, -d - 0.02, 1.0), (x + 0.05, -d - 0.06, 0.7), (x - 0.04, -d - 0.05, 0.4)]
        p.add(K.tube(pts, 0.012, 4), LEAF_DARK, "leaf")
        for k, (lx, ly, lz) in enumerate(pts[1:]):
            p.add(K.leaf(0.12, 0.07), LEAF, "leaf", T(lx, ly - 0.01, lz) @ R("X", -80) @ R("Z", rng.uniform(-60, 60)))
        K.bloom(p, (pts[-1][0], -d - 0.08, 0.36), 0.06, ROSES[(i + 2) % 5], rings=2, per=4, rng=rng,
                finish="satin", tilt=R("X", 90))


# ------------------------------------------------------------------ climbers


def _climb(p, rng, width, height, blooms, leaves, palette, base_leaf, alt_leaf, stems=3, depth=0.25):
    for s in range(stems):
        x0 = (s - (stems - 1) / 2) * width / max(stems, 1) * 0.7
        pts = []
        for i in range(9):
            z = height * i / 8
            pts.append((x0 + math.sin(i * 1.3 + s) * width * 0.18, -0.05 - rng.uniform(0, 0.04), z))
        p.add(K.tube(pts, [0.035 - i * 0.003 for i in range(9)], 5), (0.48, 0.40, 0.42), "matte")
    for _ in range(leaves):
        # denser at the bottom and middle, feathering out at the top and sides
        z = height * (rng.random() ** 0.8)
        spread = width * 0.5 * (0.6 + 0.4 * math.sin(math.pi * min(z / height, 1.0)))
        x = rng.uniform(-spread, spread)
        c = base_leaf if rng.random() < 0.6 else alt_leaf
        p.add(K.leaf(rng.uniform(0.12, 0.2), rng.uniform(0.07, 0.11)), c, "leaf",
              T(x, -0.06 - rng.uniform(0, depth * 0.6), z) @ R("X", -rng.uniform(60, 100)) @ R("Z", rng.uniform(0, 360)))
    for i in range(blooms):
        z = height * (0.15 + 0.8 * rng.random())
        spread = width * 0.42 * (0.6 + 0.4 * math.sin(math.pi * z / height))
        K.bloom(p, (rng.uniform(-spread, spread), -0.12 - rng.uniform(0, depth * 0.5), z), rng.uniform(0.11, 0.15),
                palette[i % len(palette)], rings=2, per=4, rng=rng, finish="satin",
                tilt=R("X", 90 + rng.uniform(-20, 20)))


def climber_rose(p):
    """Climbing rose fanned flat on the wall: 1.4 m wide, 4.4 m tall."""
    _climb(p, random.Random(21), 1.4, 4.4, 17, 190, ROSES, LEAF, LEAF_DARK)


def ivy_drape(p):
    """Ivy curtain: 2.4 m wide, 3.4 m tall, with a few blush ramblers threaded through."""
    _climb(p, random.Random(33), 2.4, 3.4, 6, 480, ROSES[1:3], IVY, IVY_LIGHT, stems=4, depth=0.2)


def wisteria_swag(p):
    """Wisteria hanging from under a cornice: 3 m long, racemes up to 0.9 m."""
    rng = random.Random(45)
    L = 3.0
    pts = [(-L / 2 + L * i / 10, -0.12, -0.05 - 0.12 * math.sin(math.pi * i / 10)) for i in range(11)]
    p.add(K.tube(pts, 0.04, 5), (0.50, 0.42, 0.44), "matte")
    for _ in range(90):
        x = rng.uniform(-L / 2, L / 2)
        p.add(K.leaf(0.16, 0.06), LEAF if rng.random() < 0.6 else K.SAGE_LIGHT, "leaf",
              T(x, -0.12 - rng.uniform(0, 0.1), -0.05 - rng.uniform(0, 0.15)) @ R("X", -rng.uniform(40, 120))
              @ R("Z", rng.uniform(0, 360)))
    for i in range(16):
        x = -L / 2 + 0.1 + (L - 0.2) * (i + rng.uniform(-0.3, 0.3)) / 15
        top = -0.1 - 0.12 * math.sin(math.pi * (x + L / 2) / L)
        length = rng.uniform(0.45, 0.9)
        col = WISTERIA[i % 3]
        for k in range(7):
            t = k / 6
            r = 0.07 * (1 - 0.7 * t)
            p.add(K.ico(r, 1), K.lighter(col, 0.25 * t) if t > 0.5 else col, "satin",
                  T(x + rng.uniform(-0.02, 0.02), -0.16, top - length * t) @ S(1, 1, 1.3))


def inner_reveal(p):
    """Room side of an outer window (audit D2): lined reveal, deep sill board on
    a panelled apron, gilt-beaded casing and mullions at the glass. Here -Y is
    INTO the room; the wall's inner face is y=0 and the glass sits at y=+0.125.
    Kept within 0.24 m of the opening each side so drapes (L38) hang outside it."""
    w, h = WIN_W, WIN_H
    g = 0.125                                     # glass plane, behind the inner face
    lining = (0.86, 0.83, 0.79)
    for sx in (-1, 1):                            # jamb linings
        b, m = K.box(0.04, g + 0.02, h), T(sx * (w / 2 + 0.02), g / 2 - 0.01, h / 2)
        p.add(b, lining, "satin", m, smooth=False)
    p.add(K.box(w + 0.08, g + 0.02, 0.04), lining, "satin", T(0, g / 2 - 0.01, h + 0.02), smooth=False)   # soffit
    for sx in (-1, 1):                            # casing
        add_box(p, lining, 0.16, 0.04, h + 0.16, x=sx * (w / 2 + 0.1), finish="satin")
        add_box(p, GILT, 0.02, 0.05, h + 0.12, x=sx * (w / 2 + 0.05), finish="gold")
    add_box(p, lining, w + 0.36, 0.04, 0.16, z=h, finish="satin")
    add_box(p, GILT, w + 0.12, 0.05, 0.02, z=h + 0.03, finish="gold")
    # deep sill board (window seat ledge) and apron
    add_box(p, lining, w + 0.4, 0.3 + g, 0.06, z=-0.06, out0=-g, bevel=0.015, finish="satin")
    add_box(p, lining, w + 0.1, 0.03, 0.5, z=-0.58, finish="satin")
    add_box(p, TRIM_BLUSH, w - 0.2, 0.035, 0.34, z=-0.5, finish="satin")
    add_box(p, GILT, w - 0.16, 0.04, 0.02, z=-0.5, finish="gold")
    add_box(p, GILT, w - 0.16, 0.04, 0.02, z=-0.18, finish="gold")
    # mullions and transoms just in front of the glass: 2 lights wide, 4 high
    my = g - 0.03
    p.add(K.box(0.045, 0.04, h), lining, "satin", T(0, my, h / 2), smooth=False)
    for i in (1, 2, 3):
        p.add(K.box(w, 0.04, 0.04), lining, "satin", T(0, my, h * i / 4), smooth=False)
    p.add(K.box(0.012, 0.045, h), GILT, "gold", T(0, my - 0.003, h / 2), smooth=False)


BUILDERS = {
    "facade_pilaster": pilaster,
    "facade_string_course": string_course,
    "facade_cornice": eaves_cornice,
    "facade_plinth": plinth,
    "facade_surround_arch": surround_arch,
    "facade_surround_pediment": surround_pediment,
    "facade_surround_segment": surround_segment,
    "facade_surround_simple": surround_simple,
    "facade_shutters": shutters,
    "facade_balcony": balcony,
    "facade_climber_rose": climber_rose,
    "facade_ivy": ivy_drape,
    "facade_wisteria": wisteria_swag,
    "facade_inner_reveal": inner_reveal,
}


def build(pid):
    p = K.Prop(pid)
    BUILDERS[pid](p)
    ob = p.to_object(pid)
    n = K.mesh_tris(ob)
    lo = K.lod(ob, 0.5 if n > 300 else 0.6)
    lo.name = pid + "_lod1"
    return ob, lo


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    preview_dir = args[args.index("--preview") + 1] if "--preview" in args else None
    K.reset()
    over = []
    built = []
    for pid in BUILDERS:
        ob, lo = build(pid)
        n, n1 = K.mesh_tris(ob), K.mesh_tris(lo)
        print(f"{pid:28s} {n:5d} tris  lod1 {n1:5d}")
        if n > MAX_TRIS:
            over.append(pid)
        K.export_glb([ob, lo], os.path.join(OUT, pid + ".glb"))
        built.append(ob)
        lo.hide_render = True
    if preview_dir:
        preview(built, os.path.join(preview_dir, "facade_kit.png"))
    if over:
        print("OVER BUDGET:", over)
        sys.exit(1)


def preview(objs, path, cols=5):
    """Cycles contact sheet of the LOD0 pieces, seen from the front (review only)."""
    sc = bpy.context.scene
    cell = 5.5
    for i, ob in enumerate(objs):
        ob.location = (-(i % cols) * cell + (cols - 1) * cell / 2, 0, -(i // cols) * cell * 1.1)
    rows = (len(objs) + cols - 1) // cols
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = cols * cell * 1.05
    cam.location = (8, -40, -(rows - 1) * cell * 0.55 + 2.4)
    cam.rotation_euler = (math.radians(90), 0, math.radians(11))
    for rot, energy in (((0.9, 0.2, 0.5), 4.0), ((1.3, -0.3, -2.0), 1.4)):
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = energy
        sun.rotation_euler = rot
        sc.collection.objects.link(sun)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.72, 0.9, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    sc.world = world
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.render.resolution_x = 1600
    sc.render.resolution_y = int(1600 * rows * 1.1 / cols) + 100
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
