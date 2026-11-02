"""Manor prop models for the L38 refurnish (part detail): the small set
dressing that makes every tabletop, mantel, shelf and wall different.
Same contract as parts A-D: builder(p, size, color), front faces +Y, Z up,
fitted to the catalogue size afterwards (so each is modelled at its real size
to keep proportions). Wall pieces keep their back flat at -Y.
Princess look: candy pastels, soft gilt, pearl and glass; never grey.
"""

import math
import random

import bmesh
from mathutils import Matrix, Vector

from manor_props_a import crest, heart_crest
from prop_kit import (BARK, BLUSH, BUTTER, CANVAS, CREAM, FAWN, FLAME, GOLD, GOLD_DEEP, IRON, LEAF,
                      LEAF_DARK, LILAC, MINT, OAK, OAK_DARK, PEARL, PERI, ROSE, SAGE, SAGE_DEEP, SAGE_LIGHT,
                      SOFT_BLUE, STRAW, WHITE, R, S, T, arched_outline, bloom, box, cushion, cyl, darker, ico, lathe, leaf,
                      lighter, mix, oval_outline, petal, scroll, slab, sphere, star_flower, torus, tube)

I4 = Matrix.Identity(4)
SILVER = (0.93, 0.92, 1.0)
GLASS = (0.9, 0.96, 1.0)
INK = (0.38, 0.30, 0.56)
WAX_RED = (0.86, 0.24, 0.32)
BREAD = (0.95, 0.72, 0.44)
CRUST = (0.84, 0.56, 0.34)
DOUGH = (1.0, 0.92, 0.78)
FLOUR = (1.0, 0.98, 0.95)
CARROT = (1.0, 0.6, 0.32)
APPLE = (0.92, 0.30, 0.38)
HONEY = (1.0, 0.72, 0.28)
CHOC = (0.48, 0.28, 0.26)
PLUM = (0.66, 0.46, 0.80)
FORGET = (0.62, 0.76, 1.0)
HYD_BLUE = [(0.60, 0.70, 0.98), (0.70, 0.78, 1.0), (0.76, 0.70, 0.98), (0.56, 0.64, 0.94), (0.82, 0.86, 1.0)]
HYD_PINK = [(1.0, 0.72, 0.82), (0.98, 0.62, 0.76), (1.0, 0.82, 0.89), (0.94, 0.66, 0.86), (1.0, 0.76, 0.78)]
HYD_WHITE = [WHITE, (0.97, 0.95, 1.0), (0.9, 0.86, 1.0), lighter(LILAC, 0.25), (0.98, 0.98, 0.92)]
PASTELS = [ROSE, PERI, MINT, BUTTER, LILAC, BLUSH, (1.0, 0.62, 0.55), (0.62, 0.84, 0.95)]


# ------------------------------------------------------------ geometry helpers


def aim(v):
    """Rotation taking +Z to direction v."""
    return Vector((0, 0, 1)).rotation_difference(Vector(v).normalized()).to_matrix().to_4x4()


def flat(outline, t, bevel=0.0):
    """Outline [(x, y)] lying in the XY plane, thickness t from z=0 to z=t."""
    bm = slab([(x, -y) for x, y in outline], t, bevel)
    bmesh.ops.transform(bm, matrix=T(0, 0, t / 2) @ R("X", 90), verts=bm.verts)
    return bm


def upright(outline, t, y0=0.0):
    """Outline [(x, z)] standing in the XZ plane, back at y0, front at y0+t."""
    bm = slab(outline, t)
    bmesh.ops.translate(bm, vec=(0, y0 + t / 2, 0), verts=bm.verts)
    return bm


def polys(faces):
    """Loose flat polygons, each a list of 3D points (cheap painted detail)."""
    bm = bmesh.new()
    for pts in faces:
        bm.faces.new([bm.verts.new(c) for c in pts])
    return bm


def rects(rs, z=0.0):
    """Flat rectangles (x0, y0, x1, y1) at height z."""
    return polys([[(a, b, z), (c, b, z), (c, d, z), (a, d, z)] for a, b, c, d in rs])


def rects_xz(rs, y=0.0):
    """Upright rectangles (x0, z0, x1, z1) facing +Y at depth y."""
    return polys([[(a, y, b), (c, y, b), (c, y, d), (a, y, d)] for a, b, c, d in rs])


def rr_outline(w, d, r, n=4):
    """Rounded rectangle outline in XY."""
    pts = []
    for cx, cy, a0 in ((w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180),
                       (w / 2 - r, -d / 2 + r, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def blob_outline(rx, ry, n, rng, wob=0.15):
    return [(rx * math.cos(2 * math.pi * i / n) * (1 + rng.uniform(-wob, wob)),
             ry * math.sin(2 * math.pi * i / n) * (1 + rng.uniform(-wob, wob))) for i in range(n)]


def flute(bm, amp, k):
    """Scallops a lathe radially (fluted tart shells, crimped crusts)."""
    for v in bm.verts:
        r = math.hypot(v.co.x, v.co.y)
        if r > 1e-5:
            f = 1 + amp * math.cos(k * math.atan2(v.co.y, v.co.x))
            v.co.x *= f
            v.co.y *= f
    return bm


def bowl_prof(r, h, t=0.008, foot=0.45):
    """Open bowl profile with an inner wall: [(radius, z)]."""
    out = [(0, 0), (r * foot, 0), (r * (foot + 0.05), h * 0.06), (r * 0.82, h * 0.35), (r * 0.97, h * 0.75), (r, h)]
    inn = [(r - t, h), (r * 0.97 - t, h * 0.75), (r * 0.82 - t, h * 0.35 + t * 0.5), (r * (foot + 0.05) - t, h * 0.06 + t),
           (0, t)]
    return out + inn


def bowl(p, x, y, z, r, h, col, fin="pearl", n=16, t=0.008, rim=GOLD, sy=1.0):
    p.add(lathe(bowl_prof(r, h, t), n), col, fin, T(x, y, z) @ S(1, sy, 1))
    if rim:
        p.add(torus(r - t / 2, t * 0.65, n, 4), rim, "gold", T(x, y, z + h) @ S(1, sy, 1))


def band(p, x, y, z, r, h, col, fin="pearl", n=16, sy=1.0):
    """A painted band: a short open lathe ring just proud of a body."""
    p.add(lathe([(r, 0), (r, h)], n, False, False), col, fin, T(x, y, z) @ S(1, sy, 1))


def ring(p, x, y, z, r, t, col=GOLD, fin="gold", n=14, m=None):
    p.add(torus(r, t, n, 4), col, fin, T(x, y, z) @ (m or I4))


def face_disc(p, x, y, z, r, t, col, fin="pearl", n=16):
    """A disc facing +Y (dials, plates, seals) with its back at y."""
    p.add(cyl(r, t, n), col, fin, T(x, y, z) @ R("X", -90))


def candle(p, x, y, z, h, r, wax=CREAM, drips=1, n=10, rng=None, flame=True):
    """Pillar candle with a melted lip, wax drips, wick and a glowing flame."""
    p.add(lathe([(0, 0), (r, 0), (r, h * 0.97), (r * 0.82, h), (0, h * 0.985)], n), wax, "satin", T(x, y, z))
    rng = rng or random.Random(int(x * 1000) + 7)
    for _ in range(drips):
        a = rng.uniform(0, 2 * math.pi)
        dl = h * rng.uniform(0.15, 0.4)
        px, py = x + math.cos(a) * r * 1.02, y + math.sin(a) * r * 1.02
        p.add(tube([(px, py, z + h * 0.99), (px, py, z + h - dl)], [r * 0.18, r * 0.12], 4), wax, "satin")
    if flame:
        p.add(cyl(r * 0.07, r * 0.5, 4), INK, "matte", T(x, y, z + h * 0.98))
        fr = max(r * 0.45, 0.006)
        p.add(lathe([(0, 0), (fr * 0.6, fr * 0.8), (fr * 0.5, fr * 2.0), (0, fr * 3.4)], 6), FLAME, "glow",
              T(x, y, z + h + r * 0.3))


def jar(p, x, y, z, r, h, fill_col, fill=0.8, n=12, glass=GLASS, sharp=False, label=None, label_h=0.35):
    """Glass jar with its contents showing through; returns the rim height."""
    prof = [(0, 0), (r * 0.92, 0), (r, r * 0.12), (r, h * 0.82), (r * 0.82, h * 0.9), (r * 0.8, h)]
    p.add(lathe(prof, n), glass, "glass", T(x, y, z), smooth=not sharp)
    fh = h * 0.82 * fill
    p.add(lathe([(0, 0.004), (r * 0.9, 0.006), (r * 0.92, fh), (0, fh + r * 0.1)], max(n - 2, 6)), fill_col, "satin",
          T(x, y, z))
    if label:
        p.add(box(r * 1.1, 0.003, h * label_h, seg=1), label, "matte", T(x, y + r * 1.0, z + h * 0.42), smooth=False)
        p.add(box(r * 0.8, 0.002, 0.004, seg=1), INK, "matte", T(x, y + r * 1.0 + 0.002, z + h * 0.44), smooth=False)
    return z + h


def cloth_lid(p, x, y, z, r, col, tie=CREAM):
    """Gingham-style cloth cap tied over a jar mouth at height z."""
    p.add(lathe([(r * 1.35, z - r * 0.55), (r * 1.25, z - r * 0.2), (r * 1.05, z + r * 0.12), (r * 0.6, z + r * 0.3),
                 (0, z + r * 0.34)], 12, False, False), col, "fabric", T(x, y, 0))
    ring(p, x, y, z - r * 0.15, r * 0.98, r * 0.06, tie, "fabric", 12)
    p.add(sphere(r * 0.14, 6, 4), tie, "fabric", T(x, y + r, z - r * 0.15))


def apple(p, m, r, col, rng, leafy=False):
    # shallow dimples top and bottom: a deep closing fan reads as a tip turned
    # against its surface (test_lathe_tips)
    p.add(lathe([(0, r * 0.04), (r * 0.5, 0), (r * 0.95, r * 0.35), (r, r * 0.72), (r * 0.72, r * 1.06), (r * 0.25, r * 1.0),
                 (0, r * 0.97)], 9), col, "satin", m)
    p.add(tube([(0, 0, r * 0.88), (r * 0.06, 0, r * 1.15), (r * 0.14, 0, r * 1.25)], r * 0.05, 3), BARK, "matte", m)
    if leafy:
        p.add(leaf(r * 0.9, r * 0.45), LEAF, "leaf", m @ T(r * 0.08, 0, r * 1.1) @ R("Y", -15))


def pear(p, m, r, col):
    p.add(lathe([(0, 0), (r * 0.6, r * 0.04), (r * 0.95, r * 0.42), (r * 0.82, r * 0.9), (r * 0.48, r * 1.3), (r * 0.36, r * 1.6),
                 (0, r * 1.76)], 9), col, "satin", m)
    p.add(tube([(0, 0, r * 1.7), (r * 0.1, 0, r * 2.0)], r * 0.05, 3), BARK, "matte", m)


def grapes(p, x, y, z, r, col, rng, n=12, hang=(0, 0, -1)):
    """A bunch that tapers along `hang` from (x, y, z)."""
    d = Vector(hang).normalized()
    for i in range(n):
        t = (i / n) ** 0.8
        spread = r * 2.6 * (1 - t * 0.75)
        a = i * 2.4
        c = Vector((x, y, z)) + d * (t * r * 6) + Vector((math.cos(a), math.sin(a), 0)) * spread * 0.5
        p.add(ico(r, 1 if i < 3 else 0), col if i % 3 else lighter(col, 0.15), "satin", T(*c))
    p.add(tube([(x, y, z + r), (x + r, y, z + r * 2.5)], r * 0.2, 3), BARK, "matte")


def egg(r):
    bm = sphere(r, 8, 5)
    for v in bm.verts:
        if v.co.z > 0:
            k = v.co.z / r
            v.co.z *= 1.35
            v.co.x *= 1 - 0.12 * k
            v.co.y *= 1 - 0.12 * k
    return bm


def knife(p, x, y, z, length, rot, handle=OAK):
    """A table knife lying flat along local +X (blade) from (x, y, z)."""
    m = T(x, y, z) @ R("Z", rot)
    hl = length * 0.42
    bl = [(0, -0.008), (length * 0.5, -0.009), (length * 0.56, -0.004), (length * 0.58, 0.004), (0, 0.008)]
    p.add(flat(bl, 0.002), SILVER, "mirror", m @ T(0, 0, 0.004))
    p.add(box(hl, 0.016, 0.012, bevel=0.004, seg=1), handle, "satin", m @ T(-hl / 2, 0, 0.006))
    for k in (0.25, 0.7):
        p.add(cyl(0.0025, 0.0125, 5), GOLD, "gold", m @ T(-hl * k, 0, 0.0005))


def book(p, m, t, d, h, col, bands=2, pages=CANVAS, band=GOLD):
    """Upright book: thickness t on X, depth d on Y (spine at +Y), height h on Z, base at z=0."""
    b = max(0.0025, t * 0.09)
    for sx in (-1, 1):
        p.add(box(b, d - b, h), col, "satin", m @ T(sx * (t / 2 - b / 2), -b / 2, h / 2), smooth=False)
    p.add(box(t, b * 1.6, h, bevel=b * 0.5, seg=1), col, "satin", m @ T(0, d / 2 - b * 0.8, h / 2), smooth=False)
    p.add(box(t - 2 * b, d - b * 2.4, h - 0.006), pages, "matte", m @ T(0, -b * 0.9, h / 2), smooth=False)
    for k in range(bands):
        zz = h * (0.14 + 0.72 * k / max(bands - 1, 1))
        p.add(box(t * 1.02, b * 0.4, h * 0.035, seg=1), band, "gold", m @ T(0, d / 2 + b * 0.05, zz), smooth=False)


def book_flat(p, x, y, z, length, d, t, col, rot=0.0, **kw):
    """A book lying on its back cover, `length` along X, spine at +Y."""
    book(p, T(x, y, z + t / 2) @ R("Z", rot) @ R("Y", 90) @ T(0, 0, -length / 2), t, d, length, col, **kw)


# ------------------------------------------------------------ flowers


def floret(r):
    """Four-petal hydrangea floret facing +Z (8 tris)."""
    bm = bmesh.new()
    c = bm.verts.new((0, 0, r * 0.2))
    for i in range(4):
        a = math.pi / 2 * i
        s1 = bm.verts.new((r * 0.5 * math.cos(a - 0.6), r * 0.5 * math.sin(a - 0.6), r * 0.12))
        tip = bm.verts.new((r * math.cos(a), r * math.sin(a), -r * 0.05))
        s2 = bm.verts.new((r * 0.5 * math.cos(a + 0.6), r * 0.5 * math.sin(a + 0.6), r * 0.12))
        bm.faces.new((c, s1, tip, s2))
    return bm


def hydrangea(p, c, r, cols, rng, n=22, squash=0.8):
    """A fat domed cluster: a shaded core studded with little four-petal florets."""
    cx, cy, cz = c
    p.add(ico(r * 0.82, 1), darker(cols[0], 0.1), "fabric", T(cx, cy, cz) @ S(1, 1, squash))
    ga = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        zf = 1 - 1.6 * (i + 0.5) / n
        rr = math.sqrt(max(0.0, 1 - zf * zf))
        a = i * ga
        nrm = Vector((rr * math.cos(a), rr * math.sin(a), zf))
        pos = (cx + nrm.x * r * 0.86, cy + nrm.y * r * 0.86, cz + nrm.z * r * 0.86 * squash)
        p.add(floret(r * rng.uniform(0.3, 0.38)), cols[rng.randrange(len(cols))], "fabric",
              T(*pos) @ aim(nrm) @ R("Z", rng.uniform(0, 90)))


def peony(p, c, r, col, rng, facing=None):
    """Big ruffled cup: a rose-style heart inside broad open guard petals."""
    m = T(*c) @ (facing or I4)
    for i in range(6):
        a = 60 * i + rng.uniform(-10, 10)
        p.add(petal(r * 1.1, r * 1.15, cup=0.45, curl=-0.08), darker(col, 0.04), "fabric", m @ R("Z", a) @ R("Y", -18))
    bloom(p, c, r * 0.85, lighter(col, 0.08), 3, 6, rng, tilt=facing, heart=lighter(col, 0.4))


def tulip(p, c, r, col, facing=None):
    m = T(*c) @ (facing or I4)
    for i in range(6):
        inner = i % 2
        p.add(petal(r * 1.5, r * 1.1, cup=0.38, curl=0.0 if inner else -0.1), col if inner else lighter(col, 0.15), "fabric",
              m @ R("Z", 60 * i) @ R("Y", -66 if inner else -60))
    p.add(sphere(r * 0.3, 5, 3), LEAF_DARK, "leaf", m @ S(1, 1, 0.8))


def iris(p, c, r, col, facing=None):
    """Three upright standards, three drooping falls with a butter beard."""
    m = T(*c) @ (facing or I4)
    deep = darker(col, 0.18)
    for i in range(3):
        a = 120 * i
        p.add(petal(r * 1.15, r * 0.8, cup=0.5, curl=0.15), lighter(col, 0.12), "fabric", m @ R("Z", a) @ R("Y", -72))
        p.add(petal(r * 1.4, r * 0.85, cup=0.12, curl=-0.7), deep, "fabric", m @ R("Z", a + 60) @ R("Y", -30))
        p.add(sphere(r * 0.12, 4, 3), BUTTER, "fabric", m @ R("Z", a + 60) @ T(r * 0.35, 0, r * 0.22) @ S(2.2, 0.6, 0.5))
    p.add(cyl(r * 0.12, r * 0.4, 5), lighter(col, 0.2), "fabric", m)


def daffodil(p, c, r, col, facing=None, trumpet=None):
    m = T(*c) @ (facing or I4)
    for i in range(6):
        p.add(petal(r, r * 0.6, cup=0.12, curl=-0.06), col if i % 2 else lighter(col, 0.1), "fabric",
              m @ R("Z", 60 * i) @ R("Y", -10))
    tr = trumpet or (1.0, 0.74, 0.32)
    p.add(lathe([(r * 0.18, 0), (r * 0.26, r * 0.4), (r * 0.33, r * 0.72), (r * 0.46, r * 0.86), (r * 0.36, r * 0.8),
                 (r * 0.15, r * 0.15)], 8, True, False), tr, "fabric", m)


def lily(p, c, r, col, facing=None, throat=BLUSH):
    m = T(*c) @ (facing or I4)
    for i in range(6):
        p.add(petal(r * 1.6, r * 0.55, cup=0.18, curl=-0.55), col if i % 2 else lighter(col, 0.1), "fabric",
              m @ R("Z", 60 * i + 15) @ R("Y", -58))
    p.add(lathe([(0, 0), (r * 0.2, r * 0.15), (r * 0.32, r * 0.55), (r * 0.12, r * 0.46), (0, r * 0.46)], 6), throat, "fabric", m)
    for i in range(3):
        a = math.radians(120 * i + 40)
        tip = (r * 0.35 * math.cos(a), r * 0.35 * math.sin(a), r * 1.15)
        p.add(tube([(0, 0, r * 0.3), tip], r * 0.025, 3, caps=False), SAGE_LIGHT, "leaf", m)
        p.add(sphere(r * 0.07, 4, 3), (1.0, 0.6, 0.4), "satin", m @ T(*tip) @ S(1.6, 0.8, 0.8))


def camellia(p, c, r, col, rng, facing=None):
    m = T(*c) @ (facing or I4)
    for ring_, (n, lift, L) in enumerate(((7, 10, 1.0), (6, 32, 0.74), (5, 58, 0.48))):
        cc = col if ring_ == 0 else lighter(col, 0.1 * ring_)
        for i in range(n):
            a = 360 * i / n + ring_ * 25 + rng.uniform(-6, 6)
            p.add(petal(r * L, r * L * 1.1, cup=0.3, curl=-0.05), cc, "fabric", m @ R("Z", a) @ R("Y", -lift))
    p.add(sphere(r * 0.18, 6, 4), BUTTER, "fabric", m @ T(0, 0, r * 0.18))


def head(p, kind, c, r, col, rng, facing):
    if kind == "peony":
        peony(p, c, r, col, rng, facing)
    elif kind == "tulip":
        tulip(p, c, r, col, facing)
    elif kind == "iris":
        iris(p, c, r, col, facing)
    elif kind == "daffodil":
        daffodil(p, c, r, col, facing, trumpet=(1.0, 0.74, 0.32) if col != WHITE else BUTTER)
    elif kind == "lily":
        lily(p, c, r, col, facing)
    elif kind == "camellia":
        camellia(p, c, r, col, rng, facing)
    elif kind == "forget":
        star_flower(p, c, r, col, 5, heart=BUTTER, facing=facing)
    else:  # rose
        bloom(p, c, r, col, 3, 5, rng, tilt=facing)


def bouquet(p, kind, mouth, spread, height, n, cols, rng, size, droop=0.0, base_z=None, lean=1.5, stem_r=0.004,
            extra_lean=0.0):
    """Flowers on stems rising from a vessel mouth in a dome (golden-angle spread).
    droop arches the outer stems over; extra_lean turns heads to face outwards."""
    cx, cy, cz = mouth
    bz = cz - height * 0.15 if base_z is None else base_z
    for i in range(n):
        t = (i + 0.5) / n
        a = i * 2.39996 + rng.uniform(-0.25, 0.25)
        d = spread * math.sqrt(t) * rng.uniform(0.85, 1.05)
        x, y = cx + d * math.cos(a), cy + d * math.sin(a)
        z = cz + height * (1.0 - 0.4 * t * t) * rng.uniform(0.92, 1.04) - droop * height * t
        tilt = math.degrees(math.atan2(d, height)) * lean + droop * 75 * t + extra_lean * t
        facing = R("Z", math.degrees(a)) @ R("Y", min(tilt, 150))
        mid = (cx + (x - cx) * 0.4, cy + (y - cy) * 0.4, cz + (z - cz) * 0.6 + droop * height * 0.45 * t)
        p.add(tube([(cx + (x - cx) * 0.06, cy + (y - cy) * 0.06, bz), mid, (x, y, z)], stem_r, 4, caps=False),
              LEAF_DARK, "leaf")
        head(p, kind, (x, y, z), size * rng.uniform(0.88, 1.12), cols[i % len(cols)], rng, facing)


def leaf_skirt(p, cx, cy, cz, rim, n, length, width, rng, up=-20, col=LEAF, col2=LEAF_DARK):
    """Leaves round a vessel mouth pointing outwards (up < 0 raises them)."""
    for i in range(n):
        a = 360 * i / n + rng.uniform(-12, 12)
        p.add(leaf(length * rng.uniform(0.85, 1.1), width), col if i % 2 else col2, "leaf",
              T(cx + rim * math.cos(math.radians(a)), cy + rim * math.sin(math.radians(a)), cz) @ R("Z", a) @ R("Y", up))


def sword_leaves(p, cx, cy, cz, n, length, width, rng):
    for i in range(n):
        a = 360 * i / n + rng.uniform(-20, 20)
        p.add(leaf(length * rng.uniform(0.75, 1.1), width), LEAF if i % 2 else LEAF_DARK, "leaf",
              T(cx, cy, cz) @ R("Z", a) @ R("Y", -rng.uniform(70, 84)))


# ------------------------------------------------------------ flowers in vessels


def vase_hydrangea_blue(p, size, c):
    rng = random.Random(3101)
    p.add(lathe([(0, 0), (0.08, 0), (0.085, 0.02), (0.06, 0.04), (0.1, 0.08), (0.13, 0.16), (0.12, 0.24), (0.075, 0.29),
                 (0.07, 0.31), (0.095, 0.335)], 16), c, "pearl")
    band(p, 0, 0, 0.12, 0.132, 0.07, WHITE, n=16)
    for i in range(8):
        a = 2 * math.pi * i / 8
        p.add(floret(0.022), darker(c, 0.15), "pearl", T(0.134 * math.cos(a), 0.134 * math.sin(a), 0.155) @ aim((math.cos(a), math.sin(a), 0)))
    for z, r in ((0.02, 0.083), (0.33, 0.093)):
        ring(p, 0, 0, z, r, 0.007, n=16)
    leaf_skirt(p, 0, 0, 0.32, 0.08, 6, 0.16, 0.09, rng, up=-5)
    hydrangea(p, (0, 0, 0.5), 0.125, HYD_BLUE, rng)
    for i in range(4):
        a = 2 * math.pi * (i + 0.5) / 4
        hydrangea(p, (0.16 * math.cos(a), 0.16 * math.sin(a), 0.42), 0.11, HYD_BLUE[i:] + HYD_BLUE[:i], rng)


def vase_hydrangea_pink(p, size, c):
    rng = random.Random(3102)
    p.add(lathe([(0, 0), (0.09, 0), (0.09, 0.02), (0.04, 0.05), (0.04, 0.08), (0.1, 0.1), (0.17, 0.16), (0.2, 0.22),
                 (0.19, 0.25), (0.21, 0.26)], 18), GOLD, "gold")
    band(p, 0, 0, 0.15, 0.188, 0.05, c, n=18)
    for i in range(6):
        a = 2 * math.pi * i / 6
        p.add(scroll(0.025, 1.2, 8, 0.004), GOLD_DEEP, "gold", T(0.19 * math.cos(a), 0.19 * math.sin(a), 0.17) @ R("Z", math.degrees(a) + 90))
    leaf_skirt(p, 0, 0, 0.25, 0.17, 7, 0.13, 0.08, rng, up=10)
    hydrangea(p, (0, 0, 0.47), 0.12, HYD_PINK, rng)
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.3
        hydrangea(p, (0.17 * math.cos(a), 0.17 * math.sin(a), 0.37), 0.1, HYD_PINK[i:] + HYD_PINK[:i], rng, n=18)


def urn_hydrangea_white(p, size, c):
    rng = random.Random(3103)
    p.add(lathe([(0, 0), (0.17, 0), (0.17, 0.04), (0.13, 0.06), (0.07, 0.1), (0.06, 0.16), (0.1, 0.19), (0.18, 0.24),
                 (0.24, 0.32), (0.25, 0.4), (0.22, 0.45), (0.2, 0.47), (0.25, 0.5), (0.24, 0.52)], 16), c, "pearl")
    for i in range(12):
        a = 2 * math.pi * i / 12
        p.add(sphere(0.04, 6, 4), lighter(c, 0.1), "pearl", T(0.17 * math.cos(a), 0.17 * math.sin(a), 0.27) @ R("Z", math.degrees(a)) @ S(0.5, 0.7, 1.6))
    for z, r in ((0.04, 0.17), (0.19, 0.1), (0.45, 0.22), (0.51, 0.245)):
        ring(p, 0, 0, z, r, 0.009, n=16)
    for sx in (-1, 1):
        p.add(scroll(0.07, 1.3, 10, 0.012), GOLD, "gold", T(sx * 0.27, 0, 0.4) @ S(sx, 1, 1))
    leaf_skirt(p, 0, 0, 0.5, 0.2, 8, 0.17, 0.1, rng, up=8)
    hydrangea(p, (0, 0, 0.71), 0.14, HYD_WHITE, rng, n=20)
    for i in range(6):
        a = 2 * math.pi * i / 6
        hydrangea(p, (0.21 * math.cos(a), 0.21 * math.sin(a), 0.62), 0.125, HYD_WHITE[i % 5:] + HYD_WHITE[:i % 5], rng, n=18)


def vase_peonies(p, size, c):
    rng = random.Random(3104)
    p.add(lathe([(0, 0), (0.07, 0), (0.075, 0.01), (0.11, 0.06), (0.135, 0.14), (0.13, 0.2), (0.1, 0.25), (0.06, 0.27),
                 (0.055, 0.29), (0.06, 0.3)], 16), c, "pearl")
    for i in range(10):   # little white prunus blossoms painted on the jar
        a = 2 * math.pi * i / 10 + rng.uniform(-0.2, 0.2)
        z = rng.uniform(0.07, 0.21)
        rr = 0.136 if 0.1 < z < 0.2 else 0.12
        p.add(floret(0.018), WHITE, "pearl", T(rr * math.cos(a), rr * math.sin(a), z) @ aim((math.cos(a), math.sin(a), 0.1)))
    ring(p, 0, 0, 0.27, 0.062, 0.006, n=12)
    # the jar's lid set down at its foot
    p.add(lathe([(0, 0), (0.065, 0), (0.065, 0.015), (0.045, 0.035), (0.012, 0.04), (0.016, 0.055), (0, 0.06)], 12), c, "pearl",
          T(0.12, 0.12, 0))
    ring(p, 0.12, 0.12, 0.015, 0.064, 0.005, n=12)
    leaf_skirt(p, 0, 0, 0.29, 0.06, 7, 0.12, 0.06, rng, up=-15)
    cols = [BLUSH, (0.88, 0.36, 0.56), lighter(ROSE, 0.25), (0.95, 0.52, 0.68), (0.98, 0.78, 0.82)]
    bouquet(p, "peony", (0, 0, 0.3), 0.16, 0.2, 5, cols, rng, 0.072)
    for i in range(3):   # buds
        a = 2 * math.pi * i / 3 + 1
        x, y = 0.12 * math.cos(a), 0.12 * math.sin(a)
        p.add(tube([(0, 0, 0.27), (x * 0.6, y * 0.6, 0.42), (x, y, 0.5)], 0.003, 4, caps=False), LEAF_DARK, "leaf")
        p.add(sphere(0.022, 6, 4), (0.9, 0.42, 0.6), "fabric", T(x, y, 0.515) @ S(1, 1, 1.15))


def vase_tulips(p, size, c):
    rng = random.Random(3105)
    p.add(lathe([(0, 0), (0.068, 0), (0.07, 0.008), (0.07, 0.24), (0.074, 0.245)], 16, True, False), GLASS, "glass")
    p.add(lathe([(0, 0.006), (0.064, 0.006), (0.064, 0.16), (0, 0.16)], 14), (0.8, 0.95, 0.92), "water")
    ring(p, 0, 0, 0.19, 0.072, 0.006, c, "fabric", 16)
    for sx in (-1, 1):
        p.add(sphere(0.018, 6, 4), c, "fabric", T(sx * 0.016, 0.075, 0.19) @ R("Y", sx * 30) @ S(1.4, 0.6, 0.8))
        p.add(tube([(sx * 0.005, 0.076, 0.185), (sx * 0.015, 0.08, 0.13)], 0.005, 3), c, "fabric")
    cols = [c, (1.0, 0.68, 0.75), lighter(c, 0.1), (0.98, 0.56, 0.68), (1.0, 0.86, 0.5)]
    bouquet(p, "tulip", (0, 0, 0.24), 0.11, 0.22, 8, cols, rng, 0.042, droop=0.3, base_z=0.015)
    for i in range(5):
        a = 72 * i + 20
        p.add(leaf(0.16, 0.035), LEAF if i % 2 else SAGE_LIGHT, "leaf",
              T(0.03 * math.cos(math.radians(a)), 0.03 * math.sin(math.radians(a)), 0.22) @ R("Z", a) @ R("Y", -40))


def vase_irises(p, size, c):
    rng = random.Random(3106)
    p.add(lathe([(0, 0), (0.06, 0), (0.062, 0.01), (0.04, 0.03), (0.045, 0.08), (0.06, 0.16), (0.055, 0.24), (0.035, 0.3),
                 (0.032, 0.32), (0.045, 0.34)], 14), c, "pearl")
    for z, r in ((0.01, 0.062), (0.16, 0.061), (0.335, 0.044)):
        ring(p, 0, 0, z, r, 0.005, n=14)
    sword_leaves(p, 0, 0, 0.32, 7, 0.3, 0.03, rng)
    cols = [(0.6, 0.42, 0.86), (0.7, 0.52, 0.94), (0.52, 0.38, 0.8), (0.66, 0.46, 0.9)]
    bouquet(p, "iris", (0, 0, 0.33), 0.11, 0.3, 5, cols, rng, 0.05, lean=0.9)


def jug_daffodils(p, size, c):
    rng = random.Random(3107)
    p.add(lathe([(0, 0), (0.06, 0), (0.065, 0.008), (0.085, 0.06), (0.09, 0.11), (0.07, 0.17), (0.06, 0.2), (0.068, 0.22)], 14),
          CREAM, "pearl")
    band(p, 0, 0, 0.09, 0.0905, 0.025, c, n=14)
    p.add(lathe([(0.012, 0), (0.025, 0.02), (0.03, 0.045)], 6, False, False), CREAM, "pearl",
          T(0.06, 0, 0.19) @ R("Y", 60) @ S(1, 0.8, 1))
    p.add(tube([(-0.065, 0, 0.19), (-0.115, 0, 0.17), (-0.115, 0, 0.09), (-0.085, 0, 0.06)], 0.009, 6), CREAM, "pearl")
    ring(p, 0, 0, 0.22, 0.067, 0.004, n=14)
    sword_leaves(p, 0, 0, 0.2, 6, 0.2, 0.022, rng)
    cols = [c, c, WHITE, lighter(c, 0.1)]
    bouquet(p, "daffodil", (0, 0, 0.21), 0.12, 0.22, 8, cols, rng, 0.038, extra_lean=40)


def vase_white_roses(p, size, c):
    rng = random.Random(3108)
    p.add(lathe([(0, 0), (0.065, 0), (0.065, 0.015), (0.03, 0.04), (0.03, 0.08), (0.08, 0.1), (0.1, 0.2), (0.11, 0.3),
                 (0.12, 0.31)], 8, True, False), GLASS, "glass", smooth=False)
    p.add(lathe([(0, 0.085), (0.07, 0.1), (0.09, 0.2), (0.096, 0.24), (0, 0.24)], 8), (0.82, 0.96, 0.94), "water")
    ring(p, 0, 0, 0.31, 0.118, 0.004, GOLD, "gold", 8)
    cols = [WHITE, (1.0, 0.97, 0.93), (0.99, 0.95, 1.0), PEARL]
    bouquet(p, "rose", (0, 0, 0.3), 0.16, 0.22, 8, cols, rng, 0.055, base_z=0.09)
    leaf_skirt(p, 0, 0, 0.3, 0.09, 6, 0.08, 0.045, rng, up=-10)


def bowl_floating_blossoms(p, size, c):
    rng = random.Random(3109)
    tint = mix(GLASS, c, 0.4)
    p.add(lathe([(0, 0), (0.08, 0), (0.08, 0.02), (0.06, 0.03), (0.15, 0.05), (0.21, 0.1), (0.225, 0.13), (0.215, 0.13),
                 (0.2, 0.1), (0.14, 0.055), (0, 0.04)], 20), tint, "glass")
    ring(p, 0, 0, 0.13, 0.22, 0.005, n=20)
    ring(p, 0, 0, 0.005, 0.08, 0.006, n=14)
    p.add(lathe([(0, 0.042), (0.14, 0.057), (0.198, 0.098), (0, 0.098)], 18), (0.78, 0.94, 0.92), "water")
    spots = [(0.0, 0.0), (0.11, 0.05), (-0.1, 0.07), (-0.05, -0.11), (0.09, -0.09)]
    cols = [BLUSH, ROSE, WHITE, (1.0, 0.8, 0.86), lighter(ROSE, 0.2)]
    for (x, y), col in zip(spots, cols):
        camellia(p, (x, y, 0.1), 0.045, col, rng)
        p.add(leaf(0.06, 0.03), LEAF, "leaf", T(x, y, 0.1) @ R("Z", rng.uniform(0, 360)) @ R("Y", -3))
    candle(p, 0.03, 0.12, 0.096, 0.018, 0.018, WHITE, 0, rng=rng)


def vase_lilies(p, size, c):
    rng = random.Random(3110)
    p.add(lathe([(0, 0), (0.07, 0), (0.072, 0.012), (0.05, 0.03), (0.06, 0.1), (0.08, 0.2), (0.07, 0.29), (0.05, 0.32),
                 (0.065, 0.345)], 14), c, "pearl")
    for z, r in ((0.012, 0.07), (0.2, 0.081), (0.343, 0.064)):
        ring(p, 0, 0, z, r, 0.005, n=14)
    cols = [WHITE, (1.0, 0.97, 0.92), WHITE, (1.0, 0.94, 0.96), WHITE]
    bouquet(p, "lily", (0, 0, 0.34), 0.11, 0.3, 5, cols, rng, 0.062, extra_lean=45)
    for i in range(3):
        a = 2 * math.pi * i / 3 + 0.5
        x, y = 0.07 * math.cos(a), 0.07 * math.sin(a)
        p.add(tube([(0, 0, 0.33), (x, y, 0.6)], 0.003, 4, caps=False), LEAF_DARK, "leaf")
        p.add(sphere(0.012, 6, 4), (0.86, 0.95, 0.8), "fabric", T(x, y, 0.62) @ S(1, 1, 2.4))
    for i in range(7):
        a = 360 * i / 7 + rng.uniform(-15, 15)
        p.add(leaf(0.2, 0.035), LEAF if i % 2 else LEAF_DARK, "leaf",
              T(0.03 * math.cos(math.radians(a)), 0.03 * math.sin(math.radians(a)), 0.38 + 0.03 * (i % 3)) @ R("Z", a) @ R("Y", -45))


def posy_teacup(p, size, c):
    rng = random.Random(3111)
    p.add(lathe([(0, 0), (0.05, 0), (0.075, 0.012), (0.08, 0.016), (0.072, 0.015), (0.03, 0.006), (0, 0.006)], 18), c, "pearl")
    ring(p, 0, 0, 0.015, 0.078, 0.002, n=18)
    p.add(lathe([(0, 0), (0.025, 0), (0.026, 0.006), (0.03, 0.008), (0.05, 0.03), (0.06, 0.06), (0.064, 0.068), (0.058, 0.067),
                 (0.054, 0.06), (0.045, 0.03), (0, 0.016)], 16), WHITE, "pearl", T(0, 0, 0.006))
    band(p, 0, 0, 0.045, 0.0565, 0.012, c, n=16)
    ring(p, 0, 0, 0.074, 0.061, 0.0025, n=16)
    p.add(tube([(0.058, 0, 0.062), (0.082, 0, 0.06), (0.084, 0, 0.04), (0.055, 0, 0.032)], 0.004, 5), GOLD, "gold")
    p.add(ico(0.05, 1), SAGE, "leaf", T(0, 0, 0.068) @ S(1, 1, 0.5))
    for i in range(7):
        t = (i + 0.5) / 7
        zf = 1 - 0.8 * t
        rr = math.sqrt(1 - zf * zf)
        a = i * 2.39996
        nrm = (rr * math.cos(a), rr * math.sin(a), zf)
        star_flower(p, (nrm[0] * 0.048, nrm[1] * 0.048, 0.07 + nrm[2] * 0.028), 0.012, FORGET if i % 3 else lighter(FORGET, 0.3), 5,
                    heart=BUTTER, facing=aim(nrm))
    bouquet(p, "forget", (0, 0, 0.09), 0.03, 0.05, 3, [FORGET, (0.72, 0.7, 1.0), WHITE], rng, 0.013, base_z=0.07, lean=1.0)
    for i in range(6):
        a = 60 * i + 10
        p.add(leaf(0.04, 0.016), LEAF if i % 2 else LEAF_DARK, "leaf",
              T(0.04 * math.cos(math.radians(a)), 0.04 * math.sin(math.radians(a)), 0.08) @ R("Z", a) @ R("Y", -10))
    bloom(p, (0.012, 0.01, 0.13), 0.017, ROSE, 2, 5, rng)


# ------------------------------------------------------------ clocks and candles


def cherub(p, x, y, z, s):
    """A seated porcelain cherub with gilt curls and little white wings."""
    m = T(x, y, z) @ S(s)
    skin = (1.0, 0.9, 0.86)
    p.add(sphere(0.3, 10, 7), skin, "pearl", m @ T(0, 0, 0.3) @ S(1, 0.9, 1.1))
    p.add(sphere(0.24, 10, 7), skin, "pearl", m @ T(0, 0.04, 0.76))
    for i in range(6):
        a = 2 * math.pi * i / 6
        p.add(sphere(0.08, 6, 4), GOLD, "gold", m @ T(0.2 * math.cos(a), 0.2 * math.sin(a) - 0.02, 0.86 + 0.06 * math.sin(a * 2)))
    p.add(sphere(0.1, 6, 4), GOLD, "gold", m @ T(0, -0.02, 0.98))
    for sx in (-1, 1):
        p.add(petal(0.5, 0.36, cup=0.3, curl=0.25), WHITE, "pearl", m @ T(sx * 0.1, -0.2, 0.5) @ R("Z", -90 + sx * 60) @ R("Y", -35))
        p.add(tube([(sx * 0.15, 0.05, 0.12), (sx * 0.2, 0.3, 0.08), (sx * 0.22, 0.42, 0.0)], [0.1, 0.08, 0.07], 6), skin, "pearl", m)
        p.add(tube([(sx * 0.25, 0.0, 0.48), (sx * 0.38, 0.12, 0.62), (sx * 0.3, 0.2, 0.8)], [0.07, 0.06, 0.05], 5), skin, "pearl", m)
    p.add(sphere(0.06, 6, 4), (1.0, 0.7, 0.75), "pearl", m @ T(0, 0.27, 0.72))


def dial(p, x, y, z, r, face=WHITE, hand=INK, bezel=GOLD, ticks=12, roman=True):
    """Clock dial facing +Y with its back at y."""
    face_disc(p, x, y, z, r, 0.008, face, "pearl", 20)
    ring(p, x, y + 0.009, z, r * 1.02, max(r * 0.07, 0.004), bezel, "gold", 20, R("X", 90))
    fy = y + 0.0085
    marks = []
    for i in range(ticks):
        a = 2 * math.pi * i / ticks
        cx, cz = x + math.sin(a) * r * 0.8, z + math.cos(a) * r * 0.8
        w = r * (0.05 if i % 3 else 0.09) if roman else r * 0.04
        hgt = r * 0.16
        ux, uz = math.sin(a), math.cos(a)
        vx, vz = uz, -ux
        marks.append([(cx - vx * w - ux * hgt / 2, fy, cz - vz * w - uz * hgt / 2), (cx + vx * w - ux * hgt / 2, fy, cz + vz * w - uz * hgt / 2),
                      (cx + vx * w + ux * hgt / 2, fy, cz + vz * w + uz * hgt / 2), (cx - vx * w + ux * hgt / 2, fy, cz - vz * w + uz * hgt / 2)])
    p.add(polys(marks), hand, "matte")
    p.add(tube([(x, fy + 0.002, z), (x + r * 0.35, fy + 0.002, z + r * 0.35)], r * 0.035, 4), hand, "satin")
    p.add(tube([(x, fy + 0.003, z), (x - r * 0.12, fy + 0.003, z + r * 0.62)], r * 0.025, 4), hand, "satin")
    p.add(sphere(r * 0.06, 6, 4), bezel, "gold", T(x, fy + 0.004, z))


def _waist_outline(w, h):
    hw = w / 2
    side = [(hw, 0), (hw * 0.95, h * 0.08), (hw * 0.72, h * 0.3), (hw * 0.78, h * 0.55), (hw * 0.92, h * 0.7), (hw * 0.75, h * 0.86),
            (hw * 0.4, h * 0.97)]
    return side + [(0, h)] + [(-x, z) for x, z in reversed(side)]


def mantel_clock_gilt(p, size, c):
    rng = random.Random(3201)
    p.add(box(0.44, 0.16, 0.045, bevel=0.012), c, "gold", T(0, 0, 0.042))
    p.add(box(0.4, 0.14, 0.02, bevel=0.006), lighter(c, 0.2), "gold", T(0, 0, 0.075))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(sphere(0.022, 8, 5), c, "gold", T(sx * 0.19, sy * 0.06, 0.02))
        p.add(scroll(0.07, 1.3, 12, 0.012), c, "gold", T(sx * 0.17, 0.0, 0.16) @ S(sx, 1, 1))
        p.add(scroll(0.04, 1.2, 10, 0.008), c, "gold", T(sx * 0.12, 0.0, 0.33) @ S(-sx, 1, 1) @ R("Y", 160))
    p.add(upright(_waist_outline(0.3, 0.28), 0.11, -0.055), c, "gold", T(0, 0, 0.085))
    p.add(upright(_waist_outline(0.26, 0.24), 0.008, 0.055), lighter(c, 0.25), "gold", T(0, 0, 0.1))
    dial(p, 0, 0.06, 0.24, 0.072)
    p.add(lathe([(0, 0), (0.06, 0), (0.05, 0.02), (0.02, 0.03), (0, 0.032)], 10), c, "gold", T(0, 0, 0.36) @ S(1, 0.7, 1))
    cherub(p, 0, -0.01, 0.38, 0.085)
    for i, x in enumerate((-0.12, 0, 0.12)):
        bloom(p, (x, 0.085, 0.07), 0.018, ROSE if i % 2 else BLUSH, 2, 5, rng, tilt=R("X", -80))
        p.add(leaf(0.03, 0.014), LEAF, "leaf", T(x + 0.02, 0.085, 0.065) @ R("X", -80))


def mantel_clock_porcelain(p, size, c):
    rng = random.Random(3202)
    p.add(box(0.33, 0.17, 0.04, bevel=0.012), WHITE, "pearl", T(0, 0, 0.035))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(sphere(0.018, 8, 5), GOLD, "gold", T(sx * 0.14, sy * 0.06, 0.016))
    p.add(upright(arched_outline(0.26, 0.3, 12), 0.12, -0.06), c, "pearl", T(0, 0, 0.055))
    p.add(tube([(x, 0.062, z + 0.055) for x, z in arched_outline(0.26, 0.3, 12)], 0.006, 4, closed=True), GOLD, "gold")
    p.add(upright(arched_outline(0.2, 0.24, 12), 0.006, 0.06), WHITE, "pearl", T(0, 0, 0.075))
    dial(p, 0, 0.066, 0.24, 0.06, bezel=GOLD)
    for i, (x, z, r) in enumerate(((-0.05, 0.12, 0.02), (0.0, 0.1, 0.024), (0.05, 0.12, 0.02))):
        bloom(p, (x, 0.068, z), r, ROSE if i == 1 else BLUSH, 2, 5, rng, tilt=R("X", -90))
        p.add(leaf(0.03, 0.014), LEAF, "leaf", T(x + 0.012, 0.068, z - 0.012) @ R("X", -90) @ R("Z", -40 + 30 * i))
    p.add(lathe([(0, 0), (0.03, 0), (0.02, 0.015), (0.035, 0.04), (0.03, 0.055), (0.008, 0.06), (0.012, 0.075), (0, 0.085)], 10),
          GOLD, "gold", T(0, 0, 0.355))
    for sx in (-1, 1):
        p.add(scroll(0.035, 1.2, 10, 0.008), GOLD, "gold", T(sx * 0.135, 0.0, 0.1) @ S(sx, 1, 1))
        p.add(lathe([(0, 0), (0.016, 0), (0.012, 0.02), (0, 0.035)], 8), GOLD, "gold", T(sx * 0.12, 0, 0.31))


def candlestick_brass(p, size, c):
    p.add(lathe([(0, 0), (0.055, 0), (0.058, 0.008), (0.05, 0.015), (0.02, 0.03), (0.016, 0.05), (0.022, 0.07), (0.013, 0.09),
                 (0.012, 0.17), (0.02, 0.19), (0.012, 0.2), (0.011, 0.23), (0.016, 0.24), (0.04, 0.245), (0.042, 0.252),
                 (0.02, 0.255), (0, 0.255)], 14), c, "gold")
    ring(p, 0, 0, 0.012, 0.052, 0.004, GOLD_DEEP, "gold", 14)
    candle(p, 0, 0, 0.255, 0.12, 0.013, lighter(CREAM, 0.3), 2)


def candlestick_crystal(p, size, c):
    p.add(lathe([(0, 0), (0.055, 0), (0.055, 0.012), (0.03, 0.025), (0.02, 0.05), (0.035, 0.08), (0.02, 0.11), (0.018, 0.17),
                 (0.03, 0.19), (0.018, 0.21), (0.045, 0.225), (0.045, 0.232), (0, 0.232)], 8), GLASS, "glass", smooth=False)
    ring(p, 0, 0, 0.232, 0.044, 0.003, GOLD, "gold", 8)
    for i in range(6):
        a = 2 * math.pi * i / 6
        x, y = 0.042 * math.cos(a), 0.042 * math.sin(a)
        p.add(tube([(x, y, 0.228), (x, y, 0.212)], 0.0012, 3), GOLD, "gold")
        p.add(ico(0.008, 0), (0.95, 0.9, 1.0), "glass", T(x, y, 0.204) @ S(0.8, 0.8, 1.6))
    candle(p, 0, 0, 0.232, 0.1, 0.012, ROSE, 1)


def candle_cluster(p, size, c):
    rng = random.Random(3205)
    p.add(lathe([(0, 0), (0.19, 0), (0.2, 0.012), (0.205, 0.02), (0.195, 0.02), (0.185, 0.008), (0, 0.008)], 20), GOLD, "gold",
          T(0, 0, 0) @ S(1, 0.72, 1))
    spots = [(-0.1, -0.02, 0.2, 0.045, CREAM), (0.0, 0.04, 0.22, 0.042, lighter(BLUSH, 0.3)), (0.1, -0.01, 0.16, 0.04, lighter(BUTTER, 0.3)),
             (-0.03, -0.07, 0.1, 0.035, WHITE), (0.13, 0.06, 0.08, 0.032, lighter(LILAC, 0.35))]
    for x, y, h, r, col in spots:
        candle(p, x, y, 0.008, h, r, col, 2, rng=rng)
    for i in range(7):
        a = rng.uniform(0, 2 * math.pi)
        p.add(petal(0.02, 0.016, cup=0.2), ROSE if i % 2 else BLUSH, "fabric",
              T(0.16 * math.cos(a), 0.11 * math.sin(a), 0.01) @ R("Z", rng.uniform(0, 360)))


def hurricane_lamp(p, size, c):
    p.add(lathe([(0, 0), (0.08, 0), (0.085, 0.01), (0.06, 0.03), (0.03, 0.05), (0.035, 0.08), (0.075, 0.095), (0.08, 0.105),
                 (0, 0.105)], 14), c, "gold")
    for i in range(4):
        a = 2 * math.pi * i / 4 + math.pi / 4
        p.add(scroll(0.025, 1.2, 8, 0.004), c, "gold", T(0.065 * math.cos(a), 0.065 * math.sin(a), 0.02) @ R("Z", math.degrees(a) + 90))
    candle(p, 0, 0, 0.105, 0.14, 0.024, lighter(CREAM, 0.3), 2)
    p.add(lathe([(0.066, 0.105), (0.09, 0.2), (0.095, 0.27), (0.075, 0.36), (0.06, 0.44), (0.068, 0.48)], 16, False, False), GLASS, "glass")
    ring(p, 0, 0, 0.108, 0.07, 0.006, c, "gold", 16)
    ring(p, 0, 0, 0.48, 0.068, 0.004, c, "gold", 16)
    for i in range(8):   # an etched garland of frosted leaves on the glass
        a = 2 * math.pi * i / 8
        p.add(leaf(0.03, 0.014), (0.97, 0.95, 1.0), "pearl", T(0.095 * math.cos(a), 0.095 * math.sin(a), 0.25) @ R("Z", math.degrees(a)) @ R("X", 90) @ R("Z", 30))


# ------------------------------------------------------------ books and writing


def open_pages(p, w, d, z, cover, rng, lines=11, line_col=INK, cover_t=0.008, page_h=0.034):
    """An open book lying flat: cover boards, two curved page blocks, lines of text.
    Returns the top height of the pages' flat reading area."""
    p.add(box(w, d, cover_t, bevel=0.003, seg=1), cover, "satin", T(0, 0, z + cover_t / 2))
    for sx, col in ((-1, CANVAS), (1, lighter(CANVAS, 0.3))):
        hw = w / 2 - 0.008
        top = page_h
        ol = [(0.004, 0.0), (hw, 0.0), (hw, top * 0.8), (hw * 0.93, top * 0.9), (hw * 0.55, top), (hw * 0.28, top),
              (hw * 0.12, top * 0.85), (hw * 0.05, top * 0.6), (0.004, top * 0.3)]
        bm = slab([(sx * x, zz) for x, zz in ol], d - 0.014)
        p.add(bm, col, "matte", T(0, 0, z + cover_t))
    zt = z + cover_t + page_h + 0.0008
    rs = []
    for sx in (-1, 1):
        for k in range(lines):
            yy = d / 2 - 0.03 - k * (d - 0.06) / lines
            x0 = w / 2 * 0.3
            x1 = w / 2 * (0.88 if k != lines - 1 else 0.6)
            rs.append((min(sx * x0, sx * x1), yy - 0.0025, max(sx * x0, sx * x1), yy + 0.0025))
    p.add(rects(rs, zt), line_col, "matte")
    return zt


def book_open(p, size, c):
    rng = random.Random(3301)
    zt = open_pages(p, 0.45, 0.32, 0.0, ROSE, rng, lines=12)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(flat([(0, 0), (-sx * 0.035, 0), (0, -sy * 0.035)], 0.004), GOLD, "gold", T(sx * 0.225, sy * 0.16, 0.006))
    # an illuminated miniature and a gilt capital on the right page
    p.add(rects([(0.13, 0.02, 0.2, 0.11)], zt + 0.0004), SOFT_BLUE, "matte")
    p.add(rects([(0.13, 0.02, 0.2, 0.05)], zt + 0.0008), SAGE_LIGHT, "matte")
    p.add(rects([(0.165, 0.065, 0.175, 0.085)], zt + 0.0012), ROSE, "matte")
    p.add(tube([(0.13, 0.02, zt + 0.001), (0.2, 0.02, zt + 0.001), (0.2, 0.11, zt + 0.001), (0.13, 0.11, zt + 0.001)], 0.002, 4,
               closed=True), GOLD, "gold", smooth=False)
    p.add(box(0.02, 0.022, 0.002, seg=1), GOLD, "gold", T(-0.18, 0.12, zt + 0.001))
    p.add(tube([(0.0, 0.17, zt - 0.004), (0.01, 0.1, zt + 0.004), (0.02, -0.12, zt + 0.002), (0.03, -0.165, zt - 0.02),
                (0.035, -0.172, 0.003), (0.04, -0.178, 0.002)], 0.0035, 4), PERI, "fabric")


def book_pile_ribbon(p, size, c):
    rng = random.Random(3302)
    specs = [(0.3, 0.22, 0.05, c), (0.28, 0.2, 0.045, lighter(PERI, 0.1)), (0.26, 0.19, 0.05, MINT), (0.22, 0.16, 0.04, BUTTER)]
    z = 0.0
    for L, d, t, col in specs:
        book_flat(p, rng.uniform(-0.008, 0.008), rng.uniform(-0.006, 0.006), z, L, d, t, col, rng.uniform(-5, 5))
        z += t
    rib = BLUSH
    p.add(box(0.03, 0.23, 0.003, seg=1), rib, "fabric", T(0, 0, z + 0.0015))
    for sy in (-1, 1):
        p.add(box(0.03, 0.003, z, seg=1), rib, "fabric", T(0, sy * 0.113, z / 2))
    p.add(box(0.31, 0.03, 0.003, seg=1), rib, "fabric", T(0, 0, z + 0.003))
    for sx in (-1, 1):
        p.add(torus(0.028, 0.008, 10, 4), rib, "fabric", T(sx * 0.03, 0, z + 0.02) @ R("Y", sx * 25) @ S(1.2, 0.45, 0.9) @ R("X", 90))
        p.add(tube([(0, 0, z + 0.01), (sx * 0.03, 0.04, z + 0.006), (sx * 0.05, 0.085, z + 0.004)], [0.007, 0.006, 0.006], 4),
              rib, "fabric")
    p.add(sphere(0.012, 6, 4), rib, "fabric", T(0, 0, z + 0.014))


def books_childrens(p, size, c):
    rng = random.Random(3303)
    # two picture books stood up face-out, leaning back, with bold cover art
    for x, col, art, rot in ((-0.1, (1.0, 0.6, 0.55), BUTTER, 8), (0.1, (0.55, 0.7, 1.0), ROSE, -6)):
        m = T(x, -0.06, 0) @ R("Z", rot) @ R("X", -12)
        p.add(box(0.19, 0.022, 0.275, bevel=0.004, seg=1), col, "satin", m @ T(0, 0, 0.1375))
        p.add(box(0.17, 0.018, 0.267), CANVAS, "matte", m @ T(0.006, -0.004, 0.1375))
        p.add(cyl(0.05, 0.004, 14), art, "satin", m @ T(0, 0.011, 0.14) @ R("X", -90))
        for k in range(8):
            a = 2 * math.pi * k / 8
            p.add(box(0.008, 0.003, 0.025, seg=1), art, "satin", m @ T(0.07 * math.sin(a), 0.012, 0.14 + 0.07 * math.cos(a)) @ R("Y", math.degrees(a)))
        p.add(box(0.15, 0.003, 0.025, seg=1), WHITE, "satin", m @ T(0, 0.012, 0.235))
    p.add(box(0.03, 0.17, 0.2, seg=1), MINT, "satin", T(0.0, -0.05, 0.1) @ R("Z", 2))
    # and one open in front: a painted bunny in a meadow
    m = T(0, 0.07, 0) @ R("Z", -4)
    zt = 0.004 + 0.026
    p.add(box(0.36, 0.13, 0.004, seg=1), c, "satin", m @ T(0, 0, 0.002))
    for sx in (-1, 1):
        p.add(box(0.172, 0.12, 0.024, bevel=0.006, seg=1), WHITE, "matte", m @ T(sx * 0.088, 0, 0.016))
    p.add(rects([(0.012, -0.055, 0.168, 0.055)], zt + 0.0005), SOFT_BLUE, "matte", m)
    p.add(rects([(0.012, -0.055, 0.168, -0.01)], zt + 0.001), (0.72, 0.9, 0.7), "matte", m)
    bun = [(0.09, 0.0, 0.03, 0.02), (0.115, 0.015, 0.016, 0.014), (0.11, 0.04, 0.005, 0.016), (0.122, 0.04, 0.005, 0.016)]
    for bx, by, rx, ry in bun:
        p.add(sphere(1, 8, 4), (1.0, 0.94, 0.9), "matte", m @ T(bx, by, zt + 0.0015) @ S(rx, ry, 0.001))
    p.add(sphere(0.007, 6, 3), WHITE, "matte", m @ T(0.06, -0.003, zt + 0.0025) @ S(1, 1, 0.2))
    p.add(sphere(0.012, 8, 3), BUTTER, "matte", m @ T(0.15, 0.04, zt + 0.0015) @ S(1, 1, 0.1))
    for k in range(5):
        p.add(sphere(0.004, 5, 3), [ROSE, BUTTER, WHITE, LILAC, ROSE][k], "matte",
              m @ T(0.03 + 0.03 * k, -0.04 + 0.006 * (k % 2), zt + 0.0018) @ S(1, 1, 0.3))
    lr = [(-0.15 + 0.0, 0.04 - k * 0.014, -0.03, 0.044 - k * 0.014) for k in range(6)]
    p.add(rects(lr, zt + 0.0005), INK, "matte", m)
    p.add(rects([(-0.16, -0.055, -0.03, -0.0)], zt + 0.0005), lighter(PERI, 0.3), "matte", m)


def hare(p, m, col=GOLD, fin="gold"):
    """A sitting hare facing local +X, about 1 unit tall."""
    p.add(sphere(0.3, 10, 7), col, fin, m @ T(-0.08, 0, 0.3) @ S(1.25, 0.85, 1.0))
    p.add(sphere(0.2, 9, 6), col, fin, m @ T(0.17, 0, 0.45) @ S(1, 0.85, 1.25))
    p.add(sphere(0.14, 9, 6), col, fin, m @ T(0.3, 0, 0.72) @ S(1.35, 0.9, 1))
    for s_ in (-1, 1):
        p.add(sphere(0.06, 6, 4), col, fin, m @ T(0.22, s_ * 0.05, 0.98) @ R("Y", -14) @ R("X", s_ * 10) @ S(0.8, 0.45, 3.0))
        p.add(tube([(0.25, s_ * 0.07, 0.35), (0.3, s_ * 0.07, 0.03)], 0.04, 5), col, fin, m)
        p.add(sphere(0.07, 6, 4), col, fin, m @ T(0.0, s_ * 0.16, 0.05) @ S(2.0, 0.8, 0.6))
    p.add(sphere(0.07, 6, 4), WHITE, "pearl", m @ T(-0.4, 0, 0.3))
    p.add(sphere(0.02, 5, 3), INK, "satin", m @ T(0.4, 0.09, 0.76))


def books_upright_bookends(p, size, c):
    rng = random.Random(3304)
    cols = [c, ROSE, PERI, lighter(LILAC, 0.15), MINT, BLUSH, BUTTER, darker(LILAC, 0.1), (0.62, 0.8, 0.95)]
    x = -0.165
    k = 0
    while x < 0.15:
        t = rng.uniform(0.026, 0.042)
        h = rng.uniform(0.19, 0.26)
        book(p, T(x + t / 2, 0, 0.01), t, 0.15, h, cols[k % len(cols)], bands=rng.choice((2, 3)))
        x += t + 0.002
        k += 1
    for sx in (-1, 1):
        p.add(box(0.07, 0.15, 0.01, bevel=0.003, seg=1), c, "gold", T(sx * 0.2, 0, 0.005))
        p.add(box(0.008, 0.13, 0.17, bevel=0.003, seg=1), GOLD, "gold", T(sx * 0.171, 0, 0.095))
        hare(p, T(sx * 0.212, -0.01, 0.01) @ R("Z", 90) @ S(0.21), GOLD, "gold")


def letter_rack(p, size, c):
    rng = random.Random(3305)
    p.add(box(0.28, 0.12, 0.018, bevel=0.005), c, "satin", T(0, 0, 0.009))
    p.add(tube([(-0.14, -0.06, 0.018), (0.14, -0.06, 0.018), (0.14, 0.06, 0.018), (-0.14, 0.06, 0.018)], 0.003, 4, closed=True),
          GOLD, "gold", smooth=False)
    for y, h, w in ((0.045, 0.07, 0.24), (0.0, 0.11, 0.26), (-0.045, 0.14, 0.27)):
        p.add(upright(arched_outline(w, h, 10, arch=0.04), 0.008, y - 0.004), lighter(c, 0.08), "satin", T(0, 0, 0.018))
        p.add(tube([(xx, y + 0.0045, zz + 0.018) for xx, zz in arched_outline(w, h, 10, arch=0.04)[2:]], 0.002, 4), GOLD, "gold")
    heart_crest(p, 0, -0.04, 0.165, 0.04)
    letters = [(0.0225, -0.06, 0.13, CANVAS, 3), (0.022, 0.05, 0.12, (1.0, 0.9, 0.92), -2), (-0.0225, -0.03, 0.17, (0.92, 0.94, 1.0), 2),
               (-0.022, 0.06, 0.15, CANVAS, -3)]
    for y, x, h, col, rot in letters:
        h *= 0.82
        m = T(x, y, 0.018) @ R("Y", rot)
        p.add(box(0.15, 0.003, h, seg=1), col, "matte", m @ T(0, 0, h / 2), smooth=False)
        p.add(flat([(-0.075, 0), (0.075, 0), (0, -0.05)], 0.001), darker(col, 0.06), "matte",
              m @ T(0, 0.0016, h) @ R("X", -90))
        p.add(cyl(0.009, 0.003, 10), WAX_RED, "satin", m @ T(0, 0.0015, h - 0.048) @ R("X", -90))


def quill(p, m, L, col=WHITE):
    """A feather quill lying flat along local +X (nib at the origin)."""
    p.add(tube([(0, 0, 0.002), (L, 0.01, 0.004)], [0.0015, 0.0025], 4), CREAM, "satin", m)
    p.add(lathe([(0, 0), (0.003, 0.006), (0, 0.02)], 4), GOLD, "gold", m @ R("Y", -90) @ T(-0.002, 0, -0.012))
    vane = [(L * 0.25, 0.0)] + [(L * (0.25 + 0.75 * t), 0.024 * math.sin(math.pi * t) ** 0.6 + 0.01 * t) for t in (0.2, 0.45, 0.7, 0.9)] + \
           [(L * 1.02, 0.01)] + [(L * (0.25 + 0.75 * t), -0.018 * math.sin(math.pi * t) ** 0.6 + 0.01 * t) for t in (0.9, 0.7, 0.45, 0.2)]
    p.add(flat(vane, 0.002), col, "satin", m @ T(0, 0, 0.002))
    p.add(flat([(L * 0.8, 0.012), (L * 1.0, 0.012), (L * 0.95, 0.02)], 0.001), BLUSH, "satin", m @ T(0, 0, 0.004))


def quill_and_parchment(p, size, c):
    rng = random.Random(3306)
    z = 0.0
    for i, (x, y, rot, col) in enumerate(((-0.04, 0.0, -6, darker(c, 0.04)), (-0.02, 0.01, 4, c), (-0.03, -0.005, -1, lighter(c, 0.2)))):
        p.add(box(0.24, 0.29, 0.0025, seg=1), col, "matte", T(x, y, z + 0.00125) @ R("Z", rot), smooth=False)
        z += 0.0025
    m = T(-0.03, -0.005, z) @ R("Z", -1)
    p.add(rects([(-0.1, 0.12 - k * 0.019, 0.1 - (0.05 if k % 4 == 3 else 0), 0.123 - k * 0.019) for k in range(12)], 0.0004), INK, "matte", m)
    p.add(rects([(-0.1, 0.122, -0.08, 0.135)], 0.0008), ROSE, "matte", m)
    # a curled sheet at the back right
    curl = [(0.0, 0.0), (0.06, 0.0)] + [(0.06 + 0.02 * math.sin(a), 0.02 - 0.02 * math.cos(a)) for a in (0.8, 1.6, 2.4, 3.2, 4.0)]
    inner = [(x - 0.002 * math.sin(i), zz + 0.002) for i, (x, zz) in enumerate(reversed(curl))]
    p.add(slab(curl + inner, 0.2), lighter(c, 0.1), "matte", T(0.1, -0.03, 0.0) @ R("Z", 0))
    # inkwell with an open gilt lid, a quill laid across, sealing wax
    p.add(lathe([(0, 0), (0.035, 0), (0.038, 0.01), (0.036, 0.035), (0.02, 0.045), (0.016, 0.055), (0.02, 0.058)], 10), GLASS, "glass",
          T(0.13, 0.1, 0))
    p.add(lathe([(0, 0.004), (0.032, 0.006), (0.032, 0.03), (0, 0.03)], 10), INK, "satin", T(0.13, 0.1, 0))
    ring(p, 0.13, 0.1, 0.058, 0.02, 0.003, n=10)
    p.add(lathe([(0, 0), (0.022, 0), (0.016, 0.01), (0, 0.012)], 10), GOLD, "gold", T(0.13, 0.072, 0.07) @ R("X", -70))
    quill(p, T(0.12, 0.09, z + 0.004) @ R("Z", 200) @ R("Y", -6), 0.27)
    p.add(box(0.07, 0.012, 0.012, bevel=0.003, seg=1), WAX_RED, "satin", T(0.1, -0.13, 0.006) @ R("Z", 20))
    p.add(cyl(0.012, 0.004, 10), WAX_RED, "satin", T(-0.06, -0.06, z))


def hourglass(p, size, c):
    for z in (0.0, 0.25):
        p.add(lathe([(0, 0), (0.065, 0), (0.068, 0.006), (0.06, 0.012), (0.062, 0.018), (0, 0.018)], 14), c, "gold", T(0, 0, z))
    for i in range(3):
        a = 2 * math.pi * i / 3 + 0.5
        p.add(lathe([(0.006, 0), (0.008, 0.02), (0.005, 0.06), (0.009, 0.115), (0.005, 0.17), (0.008, 0.21), (0.006, 0.232)], 6),
              c, "gold", T(0.052 * math.cos(a), 0.052 * math.sin(a), 0.018))
    p.add(lathe([(0.004, 0.018), (0.035, 0.026), (0.046, 0.07), (0.032, 0.11), (0.006, 0.134), (0.032, 0.158), (0.046, 0.2),
                 (0.035, 0.242), (0.004, 0.25)], 14), GLASS, "glass")
    sand = (1.0, 0.72, 0.8)
    p.add(lathe([(0, 0.022), (0.04, 0.03), (0.03, 0.06), (0, 0.075)], 12), sand, "satin")
    p.add(lathe([(0, 0.142), (0.026, 0.165), (0.04, 0.185), (0, 0.185)], 12), sand, "satin")
    p.add(cyl(0.0015, 0.065, 4), sand, "satin", T(0, 0, 0.07))
    ring(p, 0, 0, 0.134, 0.009, 0.003, n=8)


def globe_table(p, size, c):
    p.add(lathe([(0, 0), (0.135, 0), (0.135, 0.015), (0.09, 0.03), (0.03, 0.05), (0.02, 0.09), (0.03, 0.11), (0.015, 0.125), (0, 0.125)], 14),
          GOLD, "gold")
    for i in range(3):
        a = 2 * math.pi * i / 3
        p.add(scroll(0.035, 1.2, 8, 0.006), GOLD, "gold", T(0.07 * math.cos(a), 0.07 * math.sin(a), 0.035) @ R("Z", math.degrees(a) + 90))
    tilt = T(0, 0, 0.29) @ R("Y", 18)
    gr = 0.145
    p.add(sphere(gr, 20, 14), c, "satin", tilt)
    def land(v):
        return math.sin(5.1 * v.x + 1.0) + math.cos(4.2 * v.y - 3.4 * v.z) + math.sin(6.0 * v.z + 2.8 * v.x)
    for k, (th, col) in enumerate(((0.75, (0.72, 0.9, 0.7)), (1.45, BUTTER))):
        bm = sphere(gr * (1.012 + 0.004 * k), 28, 18)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if land(f.calc_center_median().normalized()) < th], context="FACES")
        p.add(bm, col, "satin", tilt)
    p.add(tube([(0.158 * math.sin(math.radians(a)), 0, 0.158 * math.cos(math.radians(a))) for a in range(-200, 21, 20)], 0.006, 5),
          GOLD, "gold", tilt)
    for zz in (-1, 1):
        p.add(sphere(0.01, 6, 4), GOLD, "gold", tilt @ T(0, 0, zz * 0.156))
    p.add(tube([(0, 0, 0.12), (-0.04, 0, 0.14)], 0.01, 5), GOLD, "gold")


# ------------------------------------------------------------ table silver, porcelain and trinkets


def oval_tray(p, r, sy, col=SILVER, fin="mirror", handles=True, n=20):
    p.add(lathe([(0, 0), (r * 0.95, 0), (r, 0.012), (r * 1.03, 0.02), (r * 0.98, 0.02), (r * 0.94, 0.007), (0, 0.007)], n), col, fin,
          S(1, sy, 1))
    ring(p, 0, 0, 0.02, r * 1.015, 0.004, GOLD, "gold", n, S(1, sy, 1))
    if handles:
        for sx in (-1, 1):
            p.add(tube([(sx * r * 0.98, -0.035, 0.018), (sx * (r + 0.03), -0.03, 0.03), (sx * (r + 0.035), 0, 0.032),
                        (sx * (r + 0.03), 0.03, 0.03), (sx * r * 0.98, 0.035, 0.018)], 0.005, 5), GOLD, "gold")


def decanter_set(p, size, c):
    oval_tray(p, 0.19, 0.66, handles=False)
    m = T(-0.07, 0.0, 0.007)
    p.add(lathe([(0, 0), (0.06, 0), (0.07, 0.014), (0.075, 0.08), (0.06, 0.12), (0.025, 0.16), (0.02, 0.2), (0.028, 0.21),
                 (0.02, 0.212)], 10, True, False), GLASS, "glass", m, smooth=False)
    p.add(lathe([(0, 0.004), (0.055, 0.006), (0.066, 0.02), (0.068, 0.08), (0.05, 0.11), (0, 0.11)], 10), (0.84, 0.32, 0.48), "satin", m)
    p.add(cyl(0.012, 0.03, 6), GLASS, "glass", m @ T(0, 0, 0.2))
    p.add(ico(0.03, 1), (0.95, 0.92, 1.0), "glass", m @ T(0, 0, 0.255) @ S(1, 0.5, 1.2), smooth=False)
    ring(p, -0.07, 0, 0.17, 0.024, 0.0018, GOLD, "gold", 8, R("X", 18))
    p.add(box(0.03, 0.002, 0.018, seg=1), SILVER, "mirror", T(-0.07, 0.035, 0.145) @ R("X", -20))
    for x, y in ((0.085, 0.055), (0.12, -0.04)):
        mm = T(x, y, 0.007)
        p.add(lathe([(0, 0), (0.03, 0), (0.03, 0.006), (0.004, 0.012), (0.004, 0.06), (0.025, 0.075), (0.033, 0.1), (0.034, 0.125)],
                    10, True, False), GLASS, "glass", mm)
        p.add(lathe([(0, 0.068), (0.022, 0.078), (0.029, 0.098), (0, 0.098)], 10), (0.84, 0.32, 0.48), "satin", mm)
        ring(p, x, y, 0.132, 0.034, 0.0018, GOLD, "gold", 10)


def teapot(p, m, s, col=SILVER, fin="mirror", trim=GOLD, n=14):
    p.add(lathe([(0, 0), (0.05, 0), (0.055, 0.006), (0.05, 0.012), (0.08, 0.04), (0.09, 0.08), (0.08, 0.12), (0.05, 0.145),
                 (0.046, 0.15), (0, 0.15)], n), col, fin, m @ S(s))
    p.add(lathe([(0, 0), (0.048, 0), (0.04, 0.02), (0.015, 0.03), (0.01, 0.04), (0.016, 0.05), (0, 0.058)], n - 2), col, fin,
          m @ S(s) @ T(0, 0, 0.15))
    p.add(tube([(0.075, 0, 0.05), (0.12, 0, 0.08), (0.14, 0, 0.13), (0.165, 0, 0.16)], [0.02, 0.014, 0.01, 0.009], 6), col, fin, m @ S(s))
    p.add(tube([(-0.075, 0, 0.12), (-0.13, 0, 0.12), (-0.14, 0, 0.07), (-0.08, 0, 0.04)], 0.009, 5), col, fin, m @ S(s))
    for z, r in ((0.012, 0.05), (0.15, 0.047)):
        p.add(torus(r, 0.004, n, 4), trim, "gold", m @ S(s) @ T(0, 0, z))


def tea_service_silver(p, size, c):
    rng = random.Random(3402)
    oval_tray(p, 0.24, 0.7, col=lighter(SILVER, 0.1))
    teapot(p, T(-0.07, 0.0, 0.007), 1.18)
    bloom(p, (-0.07, 0.0, 0.252), 0.014, ROSE, 2, 5, rng)
    m = T(0.14, -0.065, 0.007)
    p.add(lathe([(0, 0), (0.03, 0), (0.035, 0.008), (0.05, 0.03), (0.052, 0.06), (0.047, 0.065), (0, 0.065)], 12), SILVER, "mirror", m)
    p.add(lathe([(0, 0), (0.05, 0), (0.04, 0.015), (0.008, 0.02), (0.012, 0.03), (0, 0.035)], 12), SILVER, "mirror", m @ T(0, 0, 0.065))
    for sx in (-1, 1):
        p.add(tube([(sx * 0.05, 0, 0.055), (sx * 0.07, 0, 0.05), (sx * 0.065, 0, 0.03)], 0.004, 4), GOLD, "gold", m)
    m = T(0.14, 0.075, 0.007)
    p.add(lathe([(0, 0), (0.025, 0), (0.03, 0.008), (0.042, 0.04), (0.036, 0.075), (0.04, 0.085)], 12, True, False), SILVER, "mirror", m)
    p.add(flat([(0, -0.012), (0.03, 0), (0, 0.012)], 0.004), SILVER, "mirror", m @ T(0.036, 0, 0.081) @ R("Y", -15))
    p.add(tube([(-0.038, 0, 0.07), (-0.06, 0, 0.065), (-0.055, 0, 0.03), (-0.04, 0, 0.022)], 0.004, 4), GOLD, "gold", m)
    p.add(tube([(0.08, 0.0, 0.009), (0.2, -0.02, 0.009)], 0.002, 4), GOLD, "gold")


def fruit_bowl(p, size, c):
    rng = random.Random(3403)
    p.add(lathe([(0, 0), (0.08, 0), (0.08, 0.01), (0.05, 0.02), (0.02, 0.035), (0.018, 0.06), (0.025, 0.07)], 14), c, "gold")
    p.add(lathe([(0.02, 0.07), (0.12, 0.08), (0.18, 0.1), (0.19, 0.11), (0.178, 0.108), (0.11, 0.09), (0, 0.085)], 18), c, "gold")
    for i in range(12):
        a = 2 * math.pi * i / 12
        p.add(sphere(0.008, 5, 3), PEARL, "pearl", T(0.19 * math.cos(a), 0.19 * math.sin(a), 0.11))
    spots = [(0.0, 0.0, 0.135, 0.045, APPLE), (0.07, 0.04, 0.1, 0.04, (0.95, 0.5, 0.45)), (-0.07, 0.05, 0.1, 0.042, APPLE),
             (0.02, -0.08, 0.1, 0.04, (1.0, 0.8, 0.55)), (-0.06, -0.05, 0.1, 0.04, ROSE)]
    for x, y, z, r, col in spots:
        apple(p, T(x, y, z) @ R("X", rng.uniform(-20, 20)) @ R("Y", rng.uniform(-20, 20)), r, col, rng, leafy=(col == APPLE))
    for x, y, rot in ((0.1, -0.03, 25), (-0.02, 0.09, -20)):
        pear(p, T(x, y, 0.1) @ R("Y", rot) @ R("X", rot * 0.5), 0.038, (0.84, 0.92, 0.55))
    grapes(p, 0.15, 0.08, 0.13, 0.014, PLUM, rng, 12, (0.6, 0.4, -0.7))
    grapes(p, -0.13, -0.02, 0.15, 0.013, (0.8, 0.9, 0.6), rng, 10, (-0.6, -0.2, -0.7))
    for i in range(3):
        a = 120 * i + 30
        p.add(leaf(0.07, 0.035), LEAF, "leaf", T(0.15 * math.cos(math.radians(a)), 0.15 * math.sin(math.radians(a)), 0.105) @ R("Z", a) @ R("Y", 10))


def bonbon_dish(p, size, c):
    rng = random.Random(3404)
    tint = mix(GLASS, c, 0.45)
    p.add(lathe([(0, 0), (0.06, 0), (0.06, 0.008), (0.02, 0.02), (0.018, 0.035), (0.03, 0.045), (0.09, 0.055), (0.115, 0.075),
                 (0.112, 0.08), (0.085, 0.06), (0, 0.05)], 10), tint, "glass", smooth=False)
    ring(p, 0, 0, 0.08, 0.113, 0.003, n=16)
    p.add(lathe([(0.116, 0.082), (0.105, 0.1), (0.07, 0.118), (0.02, 0.124), (0, 0.124)], 10), tint, "glass", smooth=False)
    ring(p, 0, 0, 0.083, 0.115, 0.003, n=16)
    p.add(ico(0.02, 1), tint, "glass", T(0, 0, 0.136) @ S(1, 1, 1.2), smooth=False)
    p.add(sphere(0.008, 6, 4), GOLD, "gold", T(0, 0, 0.158))
    cols = [ROSE, MINT, BUTTER, LILAC, PERI, BLUSH, WHITE]
    for i in range(14):
        a = i * 2.4
        d = 0.075 * math.sqrt((i + 0.5) / 14)
        x, y, z = d * math.cos(a), d * math.sin(a), 0.064 + 0.012 * (1 - d / 0.075) + rng.uniform(0, 0.006)
        col = cols[i % len(cols)]
        if i % 3 == 0:
            p.add(sphere(0.011, 6, 4), col, "satin", T(x, y, z) @ R("Z", math.degrees(a)) @ S(1.3, 1, 0.9))
            for sx in (-1, 1):
                p.add(cyl(0.008, 0.012, 5, r2=0.001), col, "satin", T(x, y, z) @ R("Z", math.degrees(a)) @ R("Y", sx * 90) @ T(0, 0, 0.012))
        elif i % 3 == 1:
            p.add(box(0.016, 0.016, 0.012, bevel=0.004, seg=1), col, "satin", T(x, y, z) @ R("Z", rng.uniform(0, 90)))
        else:
            p.add(sphere(0.01, 6, 4), col, "pearl", T(x, y, z))


def figurine_deer(p, size, c):
    rng = random.Random(3405)
    p.add(lathe([(0, 0), (0.1, 0), (0.1, 0.012), (0.092, 0.022), (0, 0.022)], 16), GOLD, "gold", S(1, 0.55, 1))
    p.add(sphere(0.085, 10, 5), lighter(MINT, 0.3), "pearl", T(0, 0, 0.018) @ S(1.1, 0.55, 0.15))
    for i, (x, y) in enumerate(((-0.07, 0.025), (0.06, -0.025), (-0.03, -0.03), (0.08, 0.02))):
        star_flower(p, (x, y, 0.03), 0.008, [BLUSH, BUTTER, WHITE, LILAC][i], 5, heart=BUTTER)
    hoof = GOLD
    p.add(sphere(0.05, 10, 7), c, "pearl", T(-0.005, 0, 0.14) @ S(1.45, 0.62, 0.72))
    p.add(sphere(0.035, 8, 5), c, "pearl", T(-0.05, 0, 0.145) @ S(1, 0.8, 1))
    for x, sy, kick in ((0.045, 1, 0), (0.04, -1, 0.01), (-0.055, 1, 0), (-0.06, -1, -0.01)):
        p.add(tube([(x, sy * 0.016, 0.13), (x + kick, sy * 0.016, 0.08), (x + kick * 1.5, sy * 0.016, 0.03)], [0.012, 0.006, 0.005], 5),
              c, "pearl")
        p.add(sphere(0.006, 5, 3), hoof, "gold", T(x + kick * 1.5, sy * 0.016, 0.027))
    p.add(tube([(0.05, 0, 0.15), (0.07, 0.006, 0.2), (0.08, 0.012, 0.225)], [0.022, 0.015, 0.013], 6), c, "pearl")
    hm = T(0.088, 0.016, 0.238) @ R("Z", 20) @ R("Y", 18)
    p.add(sphere(0.022, 8, 6), c, "pearl", hm @ S(1.3, 0.85, 0.85))
    p.add(sphere(0.012, 6, 4), c, "pearl", hm @ T(0.022, 0, -0.006) @ S(1.3, 0.8, 0.8))
    p.add(sphere(0.004, 4, 3), INK, "satin", hm @ T(0.036, 0, -0.006))
    for sy in (-1, 1):
        p.add(petal(0.03, 0.016, cup=0.5), BLUSH, "pearl", hm @ T(-0.008, sy * 0.01, 0.01) @ R("Z", sy * 100 + 180) @ R("Y", -40))
        p.add(sphere(0.003, 4, 3), INK, "satin", hm @ T(0.014, sy * 0.016, 0.004))
    p.add(sphere(0.01, 6, 4), WHITE, "pearl", T(-0.085, 0, 0.16) @ S(0.8, 0.8, 1.2))
    for i in range(5):
        a = 2 * math.pi * i / 5
        p.add(sphere(0.006, 5, 3), ROSE if i % 2 else BLUSH, "pearl", T(0.07 + 0.016 * math.cos(a) * 0.4, 0.016 * math.sin(a), 0.19 + 0.012 * math.cos(a)))


def figurine_swan(p, size, c):
    rng = random.Random(3406)
    p.add(sphere(0.11, 12, 4), lighter(PERI, 0.35), "pearl", T(0, 0, 0.0) @ S(1.1, 0.65, 0.18))
    for i in range(6):
        a = 2 * math.pi * i / 6
        p.add(floret(0.012), lighter(PERI, 0.15), "pearl", T(0.1 * math.cos(a), 0.06 * math.sin(a), 0.015))
    p.add(sphere(0.06, 12, 8), c, "pearl", T(-0.01, 0, 0.065) @ S(1.5, 0.95, 0.75))
    p.add(cyl(0.035, 0.07, 8, r2=0.004), c, "pearl", T(-0.09, 0, 0.07) @ R("Y", -60))
    for sy in (-1, 1):
        for k in range(3):
            p.add(petal(0.09 - k * 0.012, 0.04, cup=0.35, curl=0.3), WHITE if k else lighter(c, 0.1), "pearl",
                  T(0.02 - k * 0.012, sy * 0.035, 0.08 + k * 0.006) @ R("Z", 180 + sy * (15 + k * 8)) @ R("Y", -30 - k * 8) @ R("X", sy * 30))
    p.add(tube([(0.06, 0, 0.08), (0.095, 0, 0.11), (0.085, 0, 0.15), (0.07, 0, 0.18), (0.085, 0, 0.198)], [0.016, 0.012, 0.01, 0.01, 0.01], 6),
          c, "pearl")
    p.add(sphere(0.016, 8, 5), c, "pearl", T(0.092, 0, 0.198) @ S(1.3, 0.85, 0.9))
    p.add(cyl(0.007, 0.03, 6, r2=0.002), (1.0, 0.62, 0.45), "satin", T(0.105, 0, 0.196) @ R("Y", 100))
    p.add(sphere(0.006, 5, 3), INK, "satin", T(0.104, 0, 0.198))
    for sy in (-1, 1):
        p.add(sphere(0.0035, 4, 3), INK, "satin", T(0.098, sy * 0.012, 0.203))
    for i in range(5):   # a tiny gold crown
        a = 2 * math.pi * i / 5
        p.add(cyl(0.002, 0.012, 4, r2=0.0008), GOLD, "gold", T(0.088 + 0.008 * math.cos(a), 0.008 * math.sin(a), 0.21))
    ring(p, 0.088, 0, 0.212, 0.009, 0.002, n=10)


def trinket_box_enamel(p, size, c):
    rng = random.Random(3407)
    sq = S(1, 0.68, 1)
    p.add(lathe([(0, 0.012), (0.09, 0.012), (0.095, 0.02), (0.095, 0.058), (0, 0.058)], 18), c, "pearl", sq)
    p.add(lathe([(0, 0), (0.098, 0), (0.098, 0.012), (0.085, 0.026), (0.05, 0.036), (0, 0.04)], 18), c, "pearl", T(0, 0, 0.058) @ sq)
    for z in (0.012, 0.058, 0.07):
        ring(p, 0, 0, z, 0.096, 0.0035, n=18, m=sq)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(sphere(0.008, 6, 4), GOLD, "gold", T(sx * 0.065, sy * 0.042, 0.008))
    p.add(cyl(0.005, 0.06, 8), GOLD, "gold", T(-0.03, -0.066, 0.06) @ R("Y", 90))
    p.add(lathe([(0, 0), (0.008, 0), (0.006, 0.015), (0, 0.016)], 6), GOLD, "gold", T(0, 0.066, 0.048) @ R("X", -10))
    p.add(flat([(0.05 * math.cos(2 * math.pi * i / 14), 0.032 * math.sin(2 * math.pi * i / 14)) for i in range(14)], 0.002), WHITE, "pearl", T(0, 0, 0.0975))
    bloom(p, (0, 0, 0.098), 0.02, ROSE, 2, 5, rng)
    for i, a in enumerate((20, 160, 260)):
        p.add(leaf(0.03, 0.013), LEAF, "leaf", T(0, 0, 0.098) @ R("Z", a) @ R("Y", 8))
    star_flower(p, (0.034, 0.012, 0.098), 0.008, FORGET, 5, heart=BUTTER)
    star_flower(p, (-0.036, -0.01, 0.098), 0.008, BUTTER, 5, heart=WHITE)


def hand_mirror_brush(p, size, c):
    m = T(-0.1, 0.04, 0) @ R("Z", -18)
    ol = [(0.065 * math.cos(2 * math.pi * i / 20), 0.08 * math.sin(2 * math.pi * i / 20)) for i in range(20)]
    p.add(flat(ol, 0.01), c, "gold", m)
    p.add(flat([(x * 0.86, y * 0.86) for x, y in ol], 0.002), (0.94, 0.92, 1.0), "mirror", m @ T(0, 0, 0.01))
    p.add(tube([(x, y, 0.011) for x, y in ol], 0.005, 4, closed=True), c, "gold", m)
    p.add(lathe([(0.009, 0), (0.012, 0.03), (0.008, 0.06), (0.011, 0.1), (0.014, 0.11), (0, 0.115)], 8), c, "gold",
          m @ T(0, -0.075, 0.012) @ R("X", 90))
    for i in range(10):
        p.add(sphere(0.005, 5, 3), PEARL, "pearl", m @ T(0.072 * math.cos(2 * math.pi * i / 10), 0.088 * math.sin(2 * math.pi * i / 10), 0.012))
    m2 = T(0.115, 0.03, 0) @ R("Z", 12)
    bol = [(0.042 * math.cos(2 * math.pi * i / 16), 0.06 * math.sin(2 * math.pi * i / 16)) for i in range(16)]
    p.add(flat([(x * 0.95, y * 0.95) for x, y in bol], 0.018), lighter(CREAM, 0.2), "fabric", m2)
    p.add(flat(bol, 0.012, bevel=0.003), c, "gold", m2 @ T(0, 0, 0.018))
    p.add(flat([(x * 0.6, y * 0.6) for x, y in bol], 0.002), BLUSH, "pearl", m2 @ T(0, 0, 0.03))
    p.add(lathe([(0.01, 0), (0.013, 0.04), (0.01, 0.08), (0.014, 0.1), (0, 0.105)], 8), c, "gold", m2 @ T(0, -0.055, 0.02) @ R("X", 90))
    p.add(box(0.12, 0.012, 0.004, seg=1), PEARL, "pearl", T(0.01, -0.1, 0.002) @ R("Z", 5))
    p.add(rects([(-0.058 + 0.006 * k, -0.02, -0.055 + 0.006 * k, -0.006) for k in range(19)], 0.0), PEARL, "pearl",
          T(0.01, -0.1, 0.0005) @ R("Z", 5) @ R("X", 180))


def fan_lace(p, size, c):
    rng = random.Random(3409)
    pivot = Vector((0, -0.09, 0))
    n = 22
    bm = bmesh.new()
    inner, outer = [], []
    for k in range(n + 1):
        a = math.radians(12 + 156 * k / n)
        z = 0.008 + 0.004 * (k % 2)
        inner.append(bm.verts.new((0.06 * math.cos(a), -0.09 + 0.06 * math.sin(a), z * 0.6)))
        outer.append(bm.verts.new((0.172 * math.cos(a), -0.09 + 0.172 * math.sin(a), z)))
    for k in range(n):
        bm.faces.new((inner[k], inner[k + 1], outer[k + 1], outer[k]))
    p.add(bm, c, "fabric", smooth=False)
    sc = []
    for k in range(n):
        a0, a1 = math.radians(12 + 156 * k / n), math.radians(12 + 156 * (k + 1) / n)
        am = (a0 + a1) / 2
        z = 0.01
        sc.append([(0.17 * math.cos(a0), -0.09 + 0.17 * math.sin(a0), z), (0.17 * math.cos(a1), -0.09 + 0.17 * math.sin(a1), z),
                   (0.183 * math.cos(a1 - 0.03), -0.09 + 0.183 * math.sin(a1 - 0.03), z), (0.19 * math.cos(am), -0.09 + 0.19 * math.sin(am), z),
                   (0.183 * math.cos(a0 + 0.03), -0.09 + 0.183 * math.sin(a0 + 0.03), z)])
    p.add(polys(sc), WHITE, "fabric")
    for k in range(14):
        a = math.radians(rng.uniform(18, 162))
        r = rng.uniform(0.085, 0.155)
        p.add(floret(0.011), WHITE if k % 2 else lighter(c, 0.4), "fabric", T(r * math.cos(a), -0.09 + r * math.sin(a), 0.0135))
    for k in range(n + 1):
        a = math.radians(12 + 156 * k / n)
        L = 0.075 if 0 < k < n else 0.178
        p.add(box(L, 0.006, 0.003, seg=1), PEARL if 0 < k < n else GOLD, "pearl" if 0 < k < n else "gold",
              T(*pivot) @ R("Z", math.degrees(a)) @ T(L / 2, 0, 0.004 + (0.008 if k in (0, n) else 0)), smooth=False)
    p.add(sphere(0.008, 6, 4), GOLD, "gold", T(0, -0.09, 0.008))
    p.add(tube([(0, -0.095, 0.006), (0.03, -0.1, 0.003), (0.06, -0.095, 0.003)], 0.002, 4), ROSE, "fabric")
    p.add(cyl(0.008, 0.03, 6, r2=0.002), ROSE, "fabric", T(0.075, -0.095, 0.006) @ R("Y", -90))


# ------------------------------------------------------------ pastimes and curiosities


def sewing_basket(p, size, c):
    rng = random.Random(3501)
    sq = S(1, 0.76, 1)
    p.add(lathe([(0, 0), (0.15, 0), (0.17, 0.04), (0.18, 0.12), (0.185, 0.13), (0.175, 0.13), (0.165, 0.12), (0.15, 0.04), (0, 0.012)], 14),
          c, "satin", sq)
    for k, z in enumerate((0.015, 0.035, 0.055, 0.075, 0.095, 0.115)):
        r = 0.152 + 0.028 * min(z / 0.12, 1) ** 0.6
        ring(p, 0, 0, z, r, 0.0065, STRAW if k % 2 else darker(c, 0.08), "satin", 14, sq)
    ring(p, 0, 0, 0.13, 0.181, 0.009, lighter(c, 0.1), "satin", 18, sq)
    p.add(lathe([(0.165, 0.125), (0.155, 0.05), (0, 0.04)], 16, False, False), lighter(BLUSH, 0.2), "fabric", sq)
    # twin lids hinged on a centre bar, both propped open
    p.add(cyl(0.006, 0.36, 8), GOLD, "gold", T(-0.18, 0, 0.13) @ R("Y", 90))
    half = [(0.17 * math.cos(math.radians(a)), 0.13 * math.sin(math.radians(a))) for a in range(0, 181, 20)]
    for sy in (-1, 1):
        lid = flat(half, 0.012)
        p.add(lid, c, "satin", T(0, 0, 0.13) @ R("X", sy * 70) @ S(1, sy, 1))
        for k in range(3):
            p.add(tube([(0.17 * (0.85 - 0.25 * k) * math.cos(math.radians(a)), 0.13 * (0.85 - 0.25 * k) * math.sin(math.radians(a)), 0.013)
                        for a in range(0, 181, 30)], 0.003, 3), STRAW, "satin", T(0, 0, 0.13) @ R("X", sy * 70) @ S(1, sy, 1))
    p.add(sphere(0.012, 6, 4), ROSE, "fabric", T(0, 0.045, 0.255))
    # inside: folded fabric, spools of thread, a strawberry pincushion
    for i, (x, y, col) in enumerate(((-0.06, 0.02, ROSE), (0.05, -0.02, MINT), (0.0, 0.04, PERI))):
        p.add(cushion(0.14, 0.09, 0.04, puff=0.2), col, "fabric", T(x, y, 0.1 + 0.012 * i) @ R("Z", rng.uniform(-20, 20)))
    for i, (x, y, col) in enumerate(((-0.1, -0.02, LILAC), (0.1, 0.03, BUTTER), (0.06, 0.06, ROSE), (-0.03, -0.04, SAGE))):
        m = T(x, y, 0.13) @ R("X", 90 if i % 2 else 0)
        p.add(cyl(0.016, 0.03, 10), col, "fabric", m)
        for z in (0.0, 0.03):
            p.add(cyl(0.02, 0.004, 10), OAK, "satin", m @ T(0, 0, z - 0.002))
    p.add(sphere(0.03, 8, 6), APPLE, "fabric", T(0.12, -0.05, 0.15) @ S(1, 1, 0.85))
    for k in range(5):
        a = 2 * math.pi * k / 5
        p.add(leaf(0.015, 0.008), LEAF, "leaf", T(0.12, -0.05, 0.172) @ R("Z", math.degrees(a)) @ R("Y", 20))
        p.add(tube([(0.12 + 0.012 * math.cos(a), -0.05 + 0.012 * math.sin(a), 0.165), (0.12 + 0.02 * math.cos(a), -0.05 + 0.02 * math.sin(a), 0.19)],
                   0.0008, 3), SILVER, "mirror")
        p.add(sphere(0.003, 4, 3), [ROSE, PERI, BUTTER, MINT, LILAC][k], "pearl",
              T(0.12 + 0.02 * math.cos(a), -0.05 + 0.02 * math.sin(a), 0.19))
    p.add(tube([(-0.05, 0.08, 0.13), (-0.04, 0.14, 0.12), (-0.035, 0.145, 0.06), (-0.02, 0.16, 0.002), (0.04, 0.2, 0.002)],
               0.004, 4), ROSE, "fabric", S(1, 0.9, 1))
    p.add(lathe([(0, 0), (0.008, 0), (0.007, 0.014), (0, 0.016)], 8), GOLD, "gold", T(0.13, 0.13, 0.0))


CHESS = {
    "pawn": [(0.006, 0.016), (0.009, 0.019), (0.004, 0.022), (0.007, 0.027), (0.006, 0.033), (0, 0.035)],
    "rook": [(0.007, 0.028), (0.011, 0.031), (0.011, 0.042), (0.008, 0.042), (0.008, 0.038), (0, 0.038)],
    "bishop": [(0.006, 0.032), (0.009, 0.035), (0.005, 0.038), (0.009, 0.046), (0.006, 0.054), (0.002, 0.058), (0.003, 0.061), (0, 0.064)],
    "queen": [(0.006, 0.042), (0.01, 0.046), (0.006, 0.05), (0.011, 0.062), (0.008, 0.065), (0.003, 0.068), (0.004, 0.072), (0, 0.075)],
    "king": [(0.007, 0.046), (0.011, 0.05), (0.007, 0.054), (0.01, 0.066), (0.006, 0.07), (0, 0.071)],
    "knight": [(0.008, 0.012), (0, 0.013)],
}


def chess_piece(p, kind, x, y, z, col, face=0.0):
    fin = "pearl"
    base = [(0, 0), (0.0135, 0), (0.0135, 0.004), (0.009, 0.008)]
    p.add(lathe(base + CHESS[kind], 6), col, fin, T(x, y, z))
    if kind == "king":
        p.add(box(0.003, 0.003, 0.016, seg=1), GOLD, "gold", T(x, y, z + 0.078))
        p.add(box(0.011, 0.003, 0.003, seg=1), GOLD, "gold", T(x, y, z + 0.08))
    elif kind == "queen":
        p.add(sphere(0.0035, 5, 3), GOLD, "gold", T(x, y, z + 0.077))
    elif kind == "knight":
        head = [(-0.008, 0.01), (0.008, 0.01), (0.009, 0.025), (0.013, 0.036), (0.019, 0.042), (0.018, 0.048), (0.006, 0.054), (0.0, 0.058),
                (-0.004, 0.052), (-0.009, 0.034)]
        p.add(slab(head, 0.011, 0.002), col, fin, T(x, y, z) @ R("Z", face))
        p.add(slab([(-0.009, 0.034), (-0.004, 0.052), (-0.007, 0.05), (-0.011, 0.036)], 0.004), GOLD, "gold", T(x, y, z) @ R("Z", face))


def chess_set(p, size, c):
    p.add(box(0.4, 0.4, 0.024, bevel=0.006), OAK, "satin", T(0, 0, 0.012))
    p.add(tube([(-0.19, -0.19, 0.024), (0.19, -0.19, 0.024), (0.19, 0.19, 0.024), (-0.19, 0.19, 0.024)], 0.004, 4, closed=True), GOLD, "gold",
          smooth=False)
    sq = 0.044
    p.add(rects([(-0.176, -0.176, 0.176, 0.176)], 0.0242), c, "pearl")
    dark = []
    for i in range(8):
        for j in range(8):
            if (i + j) % 2 == 0:
                dark.append((-0.176 + i * sq, -0.176 + j * sq, -0.176 + (i + 1) * sq, -0.176 + (j + 1) * sq))
    p.add(rects(dark, 0.0246), lighter(ROSE, 0.15), "pearl")
    def at(i, j):
        return -0.176 + (i + 0.5) * sq, -0.176 + (j + 0.5) * sq
    W, B = PEARL, PLUM
    pieces = [("rook", 0, 0, W), ("king", 6, 0, W), ("rook", 5, 0, W), ("bishop", 2, 0, W), ("queen", 3, 2, W), ("knight", 5, 2, W),
              ("pawn", 0, 1, W), ("pawn", 2, 2, W), ("pawn", 4, 3, W), ("pawn", 5, 1, W), ("pawn", 7, 2, W),
              ("rook", 0, 7, B), ("king", 4, 7, B), ("rook", 7, 7, B), ("bishop", 5, 7, B), ("knight", 2, 5, B), ("queen", 3, 6, B),
              ("bishop", 1, 4, B), ("pawn", 1, 6, B), ("pawn", 4, 4, B), ("pawn", 5, 6, B), ("pawn", 6, 5, B)]
    for kind, i, j, col in pieces:
        x, y = at(i, j)
        chess_piece(p, kind, x, y, 0.025, col, 90 if col == W else -90)


def playing_cards(p, size, c):
    rng = random.Random(3503)
    pivot = (-0.02, -0.07)
    for k in range(6):
        a = -32 + k * 12
        m = T(pivot[0], pivot[1], 0.004 + k * 0.0016) @ R("Z", a) @ T(0, 0.05, 0)
        p.add(box(0.064, 0.09, 0.0012, seg=1), WHITE, "satin", m, smooth=False)
        p.add(tube([(-0.028, -0.041, 0.0008), (0.028, -0.041, 0.0008), (0.028, 0.041, 0.0008), (-0.028, 0.041, 0.0008)], 0.0012, 3, closed=True),
              c, "satin", m, smooth=False)
        col = WAX_RED if k % 2 == 0 else PLUM
        for px, py in ((-0.02, 0.03), (0.0, 0.0), (0.02, -0.03)):
            if k % 3 == 0:
                for sx in (-1, 1):
                    p.add(cyl(0.0042, 0.0006, 8), col, "satin", m @ T(px + sx * 0.0035, py + 0.002, 0.0006))
                p.add(flat([(-0.0078, 0.0015), (0.0078, 0.0015), (0, -0.008)], 0.0006), col, "satin", m @ T(px, py, 0.0006))
            else:
                p.add(flat([(0, 0.008), (0.006, 0), (0, -0.008), (-0.006, 0)], 0.0006), col, "satin", m @ T(px, py, 0.0006))
    m = T(0.08, 0.03, 0) @ R("Z", 15)
    p.add(box(0.064, 0.09, 0.026, seg=1), WHITE, "satin", m @ T(0, 0, 0.013), smooth=False)
    p.add(rects([(-0.03, -0.043, 0.03, 0.043)], 0.0262), c, "satin", m)
    p.add(rects([(-0.022, -0.035, 0.022, 0.035)], 0.0264), lighter(c, 0.35), "satin", m)
    p.add(rects([(-0.008, -0.012, 0.008, 0.012)], 0.0266), GOLD, "gold", m)
    for x, y, n, col in ((-0.1, 0.06, 9, GOLD), (-0.07, 0.075, 6, MINT), (0.0, 0.075, 10, ROSE), (0.1, -0.06, 4, PERI)):
        for k in range(n):
            p.add(cyl(0.011, 0.0035, 8), col, "gold" if col == GOLD else "pearl", T(x + rng.uniform(-0.001, 0.001), y, k * 0.0037))


def fiddle_and_bow(p, size, c):
    def hw(t):  # half width along the body, t 0 (tail) .. 1 (neck)
        return 0.1 * math.exp(-((t - 0.25) / 0.2) ** 2) + 0.084 * math.exp(-((t - 0.78) / 0.17) ** 2) + 0.004
    n = 14
    xs = [-0.3 + 0.36 * i / n for i in range(n + 1)]
    top = [(x, hw((x + 0.3) / 0.36) + 0.002) for x in xs]
    ol = top + [(x, -y) for x, y in reversed(top)]
    body = lighter(c, 0.1)
    p.add(flat(ol, 0.038, bevel=0.004), body, "satin", T(0, 0, 0.004))
    p.add(flat([(x * 0.985, y * 0.94) for x, y in ol], 0.002), lighter(c, 0.2), "satin", T(-0.002, 0, 0.042))
    dark = (0.42, 0.26, 0.34)
    for sy in (-1, 1):
        p.add(flat([(-0.17, sy * 0.034), (-0.12, sy * 0.028), (-0.115, sy * 0.032), (-0.165, sy * 0.038)], 0.001), dark, "matte",
              T(0, 0, 0.044))
    p.add(box(0.15, 0.026, 0.02, bevel=0.004, seg=1), body, "satin", T(0.13, 0, 0.034))
    p.add(flat([(-0.09, -0.016), (0.2, -0.012), (0.2, 0.012), (-0.09, 0.016)], 0.008, bevel=0.002), dark, "satin", T(0, 0, 0.044))
    p.add(box(0.06, 0.024, 0.026, bevel=0.003, seg=1), body, "satin", T(0.23, 0, 0.034))
    p.add(scroll(0.022, 1.5, 12, 0.007), body, "satin", T(0.27, 0, 0.04))
    for k in range(4):
        sy = 1 if k % 2 else -1
        p.add(lathe([(0.003, 0), (0.004, 0.02), (0.009, 0.024), (0.009, 0.034), (0, 0.036)], 6), dark, "satin",
              T(0.21 + 0.014 * k, sy * 0.012, 0.035) @ R("X", -sy * 90))
    p.add(flat([(-0.29, -0.018), (-0.22, -0.01), (-0.22, 0.01), (-0.29, 0.018)], 0.006, bevel=0.002), dark, "satin", T(0, 0, 0.044))
    p.add(slab([(-0.03, 0.0), (0.03, 0.0), (0.024, 0.02), (-0.024, 0.02)], 0.004), lighter(c, 0.35), "satin", T(-0.15, 0, 0.044) @ R("Z", 90))
    for k in range(4):
        yy = -0.009 + 0.006 * k
        p.add(tube([(-0.235, yy, 0.051), (-0.15, yy, 0.065), (0.2, yy * 0.8, 0.054)], 0.0007, 3, caps=False), lighter(GOLD, 0.3), "gold")
    p.add(sphere(0.026, 8, 4), dark, "satin", T(-0.28, 0.05, 0.042) @ S(1.2, 0.9, 0.3))
    # the bow alongside
    p.add(tube([(-0.33, 0.13, 0.012), (0.0, 0.135, 0.016), (0.31, 0.13, 0.012)], 0.0035, 5), (0.62, 0.36, 0.34), "satin")
    p.add(tube([(-0.3, 0.12, 0.006), (0.3, 0.12, 0.008)], 0.0018, 3), CREAM, "satin")
    p.add(box(0.035, 0.012, 0.022, bevel=0.003, seg=1), dark, "satin", T(-0.29, 0.124, 0.011))
    p.add(sphere(0.004, 5, 3), PEARL, "pearl", T(-0.29, 0.131, 0.014))
    p.add(box(0.015, 0.006, 0.014, seg=1), PEARL, "pearl", T(0.31, 0.126, 0.01))
    p.add(cyl(0.004, 0.012, 6), GOLD, "gold", T(-0.31, 0.13, 0.012) @ R("Y", -90))


def staff_sheet(p, m, w, d, rng, staves=7, note_col=INK):
    p.add(box(w, d, 0.0012, seg=1), WHITE, "matte", m @ T(0, 0, 0.0006), smooth=False)
    lines, notes = [], []
    for s_ in range(staves):
        y0 = d / 2 - 0.035 - s_ * (d - 0.05) / staves
        for k in range(5):
            yy = y0 - k * 0.0032
            lines.append((-w / 2 + 0.015, yy - 0.0006, w / 2 - 0.015, yy + 0.0006))
        for k in range(rng.randint(5, 8)):
            nx = -w / 2 + 0.03 + k * (w - 0.05) / 8 + rng.uniform(-0.003, 0.003)
            ny = y0 - rng.randint(0, 8) * 0.0016
            notes.append([(nx - 0.0026, ny, 0), (nx, ny - 0.0018, 0), (nx + 0.0026, ny, 0), (nx, ny + 0.0018, 0)])
            notes.append([(nx + 0.0022, ny, 0), (nx + 0.0032, ny, 0), (nx + 0.0032, ny + 0.011, 0), (nx + 0.0022, ny + 0.011, 0)])
    p.add(rects(lines, 0.0013), lighter(INK, 0.15), "matte", m)
    p.add(polys(notes), note_col, "matte", m @ T(0, 0, 0.0015))
    p.add(rects([(-w * 0.2, d / 2 - 0.022, w * 0.2, d / 2 - 0.015)], 0.0014), GOLD, "gold", m)


def sheet_music(p, size, c):
    rng = random.Random(3505)
    for k, (x, y, rot) in enumerate(((-0.06, 0.0, -8), (0.05, 0.01, 6), (-0.01, -0.005, -1))):
        staff_sheet(p, T(x, y, k * 0.0015) @ R("Z", rot), 0.21, 0.27, rng, 7 if k == 2 else 4)
    p.add(box(0.06, 0.22, 0.0012, seg=1), lighter(c, 0.25), "matte", T(0.12, 0.0, 0.0036), smooth=False)
    p.add(cyl(0.008, 0.22, 10), lighter(c, 0.25), "matte", T(0.152, 0.11, 0.011) @ R("X", 90))
    # a rolled score tied with a ribbon, lying across the pile
    m = T(-0.13, 0.02, 0.022) @ R("Z", 70) @ R("Y", 90)
    p.add(cyl(0.017, 0.2, 12), WHITE, "matte", m @ T(0, 0, -0.1))
    for e in (-0.1, 0.1):
        p.add(torus(0.009, 0.004, 8, 3), CANVAS, "matte", m @ T(0, 0, e))
    p.add(cyl(0.0185, 0.012, 12), ROSE, "fabric", m @ T(0, 0, -0.006))
    p.add(tube([(0.018, 0, 0.0), (0.03, 0.01, 0.02), (0.022, 0.0, 0.04)], 0.003, 3), ROSE, "fabric", m)


def shell_dish(p, size, c):
    rng = random.Random(3506)
    nu, nv = 22, 5
    R0 = 0.15
    def pt(u, v, off=0.0):
        a = math.radians(-62 + 124 * u / nu)
        r = R0 * v / nv
        rib = 0.007 * abs(math.sin(math.pi * u / 2)) * (v / nv)
        r *= 1 + 0.05 * abs(math.sin(math.pi * u / 2)) * (v / nv)
        z = 0.045 * (v / nv) ** 2.2 + rib + off + 0.008 * (1 - math.cos(a)) * (v / nv)
        return (r * math.sin(a) * 0.76, -0.07 + r * math.cos(a), z)
    for off, col in ((0.0, lighter(c, 0.25)), (-0.004, c)):
        bm = bmesh.new()
        grid = [[bm.verts.new(pt(u, v, off) if v else (0, -0.07, off + 0.002)) for v in range(nv + 1)] for u in range(nu + 1)]
        for u in range(nu):
            for v in range(nv):
                if v == 0:
                    bm.faces.new((grid[u][0], grid[u][1], grid[u + 1][1]))
                else:
                    bm.faces.new((grid[u][v], grid[u][v + 1], grid[u + 1][v + 1], grid[u + 1][v]))
        p.add(bm, col, "pearl")
    p.add(flat([(-0.022, -0.075), (0.022, -0.075), (0.012, -0.06), (-0.012, -0.06)], 0.004), c, "pearl", T(0, 0, -0.002))
    ring(p, -0.02, -0.0, 0.012, 0.011, 0.0022, GOLD, "gold", 12)
    ring(p, 0.025, 0.01, 0.016, 0.01, 0.002, GOLD, "gold", 12, R("Y", 25))
    p.add(ico(0.005, 1), ROSE, "glass", T(0.035, 0.01, 0.022))
    ring(p, 0.0, -0.03, 0.025, 0.009, 0.0022, GOLD, "gold", 12, R("X", 80))
    p.add(ico(0.0045, 1), (0.6, 0.75, 1.0), "glass", T(0.0, -0.03, 0.036))
    for k in range(14):
        t = k / 13
        x = -0.06 + 0.11 * t
        y = 0.02 + 0.025 * math.sin(t * 5)
        p.add(sphere(0.0042, 5, 3), PEARL, "pearl", T(x, y, 0.008 + 0.024 * (1 - abs(x) / 0.1) ** 0.5))


def potpourri_bowl(p, size, c):
    rng = random.Random(3507)
    bowl(p, 0, 0, 0, 0.15, 0.095, c, n=18)
    band(p, 0, 0, 0.055, 0.137, 0.014, WHITE, n=18)
    for i in range(10):
        a = 2 * math.pi * i / 10
        p.add(floret(0.012), ROSE if i % 2 else MINT, "pearl", T(0.1375 * math.cos(a), 0.1375 * math.sin(a), 0.062) @ aim((math.cos(a), math.sin(a), 0.3)))
    p.add(sphere(0.13, 12, 6), (0.86, 0.56, 0.64), "fabric", T(0, 0, 0.075) @ S(1, 1, 0.22))
    cols = [ROSE, BLUSH, (0.8, 0.42, 0.55), CREAM, (0.95, 0.6, 0.7), LILAC]
    for i in range(30):
        a = i * 2.4
        d = 0.12 * math.sqrt((i + 0.5) / 30)
        z = 0.075 + 0.028 * math.sqrt(max(0, 1 - (d / 0.13) ** 2))
        p.add(petal(0.022, 0.018, cup=0.4, curl=0.2), cols[i % len(cols)], "fabric",
              T(d * math.cos(a), d * math.sin(a), z) @ R("Z", rng.uniform(0, 360)) @ R("Y", rng.uniform(-30, 10)))
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.3
        x0, y0 = 0.03 * math.cos(a), 0.03 * math.sin(a)
        x1, y1 = 0.12 * math.cos(a + 0.2), 0.12 * math.sin(a + 0.2)
        p.add(tube([(x0, y0, 0.095), (x1, y1, 0.11)], 0.0015, 3, caps=False), SAGE, "leaf")
        for j in range(6):
            t = 0.55 + 0.08 * j
            p.add(sphere(0.0045, 4, 3), (0.62, 0.5, 0.86), "fabric", T(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 0.095 + 0.015 * t) @ S(1.3, 1, 1))
    for k in range(4):
        x, y = rng.uniform(-0.07, 0.07), rng.uniform(-0.07, 0.07)
        p.add(sphere(0.009, 6, 4), (0.85, 0.35, 0.5), "fabric", T(x, y, 0.103) @ S(1, 1, 1.3))


def mushroom(p, x, y, z, h, r, cap, rng):
    p.add(cyl(r * 0.28, h, 6, r2=r * 0.22), WHITE, "satin", T(x, y, z))
    p.add(lathe([(0, 0), (r, 0), (r * 0.9, r * 0.35), (r * 0.5, r * 0.7), (0, r * 0.8)], 8), cap, "satin", T(x, y, z + h))
    for k in range(3):
        a = 2 * math.pi * k / 3 + rng.uniform(0, 1)
        p.add(sphere(r * 0.14, 4, 3), WHITE, "satin", T(x + r * 0.55 * math.cos(a), y + r * 0.55 * math.sin(a), z + h + r * 0.45))


def fern(p, base, direction, L, rng, col=SAGE):
    bx, by, bz = base
    dx, dy = direction
    pts = [(bx + dx * L * t, by + dy * L * t, bz + L * (0.9 * t - 0.75 * t * t) + L * 0.1 * t) for t in (0, 0.25, 0.5, 0.75, 1.0)]
    p.add(tube(pts, [0.0025, 0.002, 0.0018, 0.0014, 0.001], 3, caps=False), SAGE_DEEP, "leaf")
    ang = math.degrees(math.atan2(dy, dx))
    for k in range(9):
        t = 0.15 + 0.09 * k
        i = min(int(t * 4), 3)
        f = t * 4 - i
        P = [pts[i][j] + (pts[i + 1][j] - pts[i][j]) * f for j in range(3)]
        for s_ in (-1, 1):
            p.add(leaf(L * 0.22 * (1.1 - t), L * 0.06), col if k % 2 else SAGE_LIGHT, "leaf", T(*P) @ R("Z", ang + s_ * 70) @ R("Y", 10))


def terrarium_bell(p, size, c):
    rng = random.Random(3508)
    p.add(lathe([(0, 0), (0.15, 0), (0.15, 0.02), (0.14, 0.03), (0.14, 0.045), (0, 0.045)], 20), PEARL, "pearl")
    ring(p, 0, 0, 0.022, 0.15, 0.005, n=20)
    for i in range(3):
        a = 2 * math.pi * i / 3
        p.add(sphere(0.016, 6, 4), GOLD, "gold", T(0.12 * math.cos(a), 0.12 * math.sin(a), 0.004))
    p.add(ico(0.12, 2), SAGE, "leaf", T(0, 0, 0.045) @ S(1, 1, 0.32))
    for i in range(5):
        a = 2 * math.pi * i / 5
        p.add(ico(0.04, 1), [SAGE_LIGHT, SAGE, LEAF, SAGE_LIGHT, c][i], "leaf", T(0.07 * math.cos(a), 0.07 * math.sin(a), 0.06) @ S(1, 1, 0.55))
    for x, y, h, r, cap in ((-0.04, 0.05, 0.03, 0.018, ROSE), (-0.02, 0.07, 0.02, 0.012, ROSE), (0.06, 0.02, 0.025, 0.015, BUTTER),
                            (0.04, -0.05, 0.035, 0.02, (1.0, 0.7, 0.6))):
        mushroom(p, x, y, 0.065, h, r, cap, rng)
    fern(p, (-0.01, -0.02, 0.07), (-0.6, -0.3), 0.16, rng)
    fern(p, (0.0, -0.01, 0.07), (0.5, 0.2), 0.14, rng)
    fern(p, (0.0, 0.0, 0.07), (0.1, -0.7), 0.12, rng, SAGE_LIGHT)
    for i in range(3):
        star_flower(p, (0.08 * math.cos(i * 2.1 + 1), 0.08 * math.sin(i * 2.1 + 1), 0.085), 0.008, [WHITE, LILAC, BUTTER][i], 5)
    p.add(sphere(0.02, 6, 4), lighter(LILAC, 0.3), "pearl", T(0.09, -0.06, 0.055) @ S(1.2, 1, 0.6))
    p.add(lathe([(0.13, 0.045), (0.13, 0.25), (0.12, 0.3), (0.09, 0.34), (0.04, 0.36), (0, 0.365)], 20, False, False), GLASS, "glass")
    p.add(ico(0.02, 1), GLASS, "glass", T(0, 0, 0.38))
    ring(p, 0, 0, 0.36, 0.035, 0.003, n=12)


def songbird(p, m, col=BUTTER):
    """A little round songbird facing local +X, perched at the origin."""
    p.add(sphere(0.025, 8, 6), col, "satin", m @ T(0, 0, 0.02) @ S(1.25, 0.95, 1))
    p.add(sphere(0.018, 8, 6), col, "satin", m @ T(0.022, 0, 0.042))
    p.add(cyl(0.006, 0.014, 5, r2=0.0), (1.0, 0.62, 0.45), "satin", m @ T(0.036, 0, 0.042) @ R("Y", 95))
    p.add(flat([(0, -0.012), (-0.04, -0.016), (-0.045, 0.0), (-0.04, 0.016), (0, 0.012)], 0.003), darker(col, 0.12), "satin",
          m @ T(-0.02, 0, 0.024) @ R("Y", -25))
    for sy in (-1, 1):
        p.add(sphere(0.0035, 4, 3), INK, "satin", m @ T(0.03, sy * 0.012, 0.048))
        p.add(petal(0.035, 0.02, cup=0.4, curl=0.1), darker(col, 0.08), "satin", m @ T(0.0, sy * 0.022, 0.03) @ R("Z", 180 - sy * 12) @ R("X", sy * 70))
    p.add(sphere(0.006, 5, 3), (1.0, 0.7, 0.6), "satin", m @ T(0.03, 0, 0.025))


def songbird_cage_small(p, size, c):
    rng = random.Random(3509)
    p.add(lathe([(0, 0), (0.12, 0), (0.12, 0.018), (0.11, 0.028), (0.11, 0.04), (0, 0.04)], 18), c, "gold")
    p.add(lathe([(0, 0.04), (0.103, 0.04), (0, 0.042)], 16), lighter(MINT, 0.2), "pearl")
    n = 14
    for i in range(n):
        a = 2 * math.pi * i / n
        ca, sa = math.cos(a), math.sin(a)
        pts = [(0.105 * ca, 0.105 * sa, 0.04), (0.105 * ca, 0.105 * sa, 0.22), (0.095 * ca, 0.095 * sa, 0.27), (0.065 * ca, 0.065 * sa, 0.31),
               (0.025 * ca, 0.025 * sa, 0.335)]
        p.add(tube(pts, 0.0022, 3, caps=False), c, "gold")
    for z, r in ((0.042, 0.106), (0.13, 0.106), (0.22, 0.106)):
        ring(p, 0, 0, z, r, 0.004, c, "gold", 18)
    p.add(lathe([(0, 0.33), (0.03, 0.335), (0.02, 0.35), (0.008, 0.36), (0, 0.365)], 10), c, "gold")
    ring(p, 0, 0, 0.385, 0.018, 0.004, c, "gold", 12, R("X", 90))
    p.add(tube([(-0.1, 0, 0.12), (0.1, 0, 0.12)], 0.004, 5), OAK, "satin")
    songbird(p, T(0.0, 0, 0.12) @ R("Z", -60), BUTTER)
    p.add(lathe([(0, 0), (0.016, 0), (0.02, 0.015), (0, 0.012)], 8), PEARL, "pearl", T(0.06, 0.06, 0.042))
    p.add(tube([(-0.035, 0.106, 0.04), (-0.035, 0.106, 0.15), (0, 0.106, 0.18), (0.035, 0.106, 0.15), (0.035, 0.106, 0.04)], 0.004, 4), c, "gold")
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.4
        bloom(p, (0.115 * math.cos(a), 0.115 * math.sin(a), 0.03), 0.016, [ROSE, BLUSH, LILAC, BUTTER][i], 2, 5, rng,
              tilt=aim((math.cos(a), math.sin(a), 0.6)))


def magnifier_glass(p, size, c):
    p.add(cyl(0.034, 0.006, 20), GLASS, "glass", T(-0.06, 0, 0.008))
    p.add(torus(0.036, 0.006, 20, 6), c, "gold", T(-0.06, 0, 0.011))
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.add(sphere(0.004, 5, 3), PEARL, "pearl", T(-0.06 + 0.036 * math.cos(a), 0.036 * math.sin(a), 0.018))
    m = T(-0.024, 0, 0.012) @ R("Y", 90)
    p.add(lathe([(0.006, 0), (0.008, 0.012), (0.006, 0.02), (0, 0.022)], 8, False, True), c, "gold", m @ R("X", 180) @ T(0, 0, -0.002))
    p.add(lathe([(0.0, 0.0), (0.008, 0.0), (0.01, 0.012), (0.009, 0.02), (0.011, 0.07), (0.012, 0.09), (0.01, 0.1), (0, 0.102)], 8), BLUSH, "pearl", m)
    for z in (0.012, 0.09):
        p.add(torus(0.011, 0.002, 8, 4), c, "gold", m @ T(0, 0, z))
    p.add(sphere(0.007, 6, 4), c, "gold", m @ T(0, 0, 0.104))


def map_rolls(p, size, c):
    rng = random.Random(3511)
    papers = [c, CANVAS, lighter(BUTTER, 0.3), (1.0, 0.92, 0.9), lighter(PERI, 0.45)]
    rolls = [(-0.07, 0.035, 0.44, 0.032), (0.0, 0.035, 0.4, 0.034), (0.07, 0.035, 0.46, 0.032), (-0.035, 0.093, 0.42, 0.03),
             (0.035, 0.093, 0.36, 0.03)]
    for i, (y, z, L, r) in enumerate(rolls):
        x0 = rng.uniform(-0.03, 0.03)
        m = T(x0 - L / 2, y - 0.08, z) @ R("Y", 90)
        p.add(cyl(r, L, 12), papers[i % len(papers)], "matte", m)
        for e in (0, L):
            p.add(torus(r * 0.5, r * 0.18, 8, 3), darker(papers[i % len(papers)], 0.08), "matte", m @ T(0, 0, e))
        if i % 2 == 0:
            p.add(cyl(r * 1.1, 0.01, 12), [ROSE, PERI, GOLD][i // 2], "satin", m @ T(0, 0, L * 0.12))
    for x in (-0.11, 0.11):
        loop = [(x, -0.08 + 0.115 * math.cos(a), 0.06 + 0.075 * math.sin(a)) for a in [2 * math.pi * k / 12 for k in range(12)]]
        p.add(tube(loop, 0.003, 3, closed=True), STRAW, "fabric")
    p.add(tube([(0.11, -0.08 + 0.0, 0.135), (0.13, -0.06, 0.13), (0.15, -0.05, 0.11)], 0.0025, 3), STRAW, "fabric")
    # one map half-unrolled in front
    m = T(0, 0.12, 0)
    p.add(box(0.34, 0.11, 0.002, seg=1), CANVAS, "matte", m @ T(0, 0, 0.001))
    for sx in (-1, 1):
        p.add(cyl(0.012, 0.12, 10), CANVAS, "matte", m @ T(sx * 0.175, -0.06, 0.012) @ R("X", -90))
    for col, (x, y, sx_, sy_) in ((SAGE_LIGHT, (-0.06, 0.01, 0.07, 0.04)), (BUTTER, (0.07, -0.01, 0.05, 0.035)), (BLUSH, (0.02, 0.03, 0.03, 0.015))):
        p.add(flat(blob_outline(sx_, sy_, 10, rng, 0.25), 0.001), col, "matte", m @ T(x, y, 0.002))
    p.add(rects([(-0.165, -0.05, 0.165, -0.046), (-0.165, 0.046, 0.165, 0.05)], 0.0023), GOLD, "gold", m)
    p.add(flat([(0, 0.02), (0.005, 0.005), (0.02, 0), (0.005, -0.005), (0, -0.02), (-0.005, -0.005), (-0.02, 0), (-0.005, 0.005)], 0.001),
          ROSE, "matte", m @ T(0.13, 0.02, 0.0025))
    p.add(rects([(-0.13 + 0.03 * k, -0.035, -0.115 + 0.03 * k, -0.033) for k in range(8)], 0.0024), INK, "matte", m)


def astrolabe(p, size, c):
    rng = random.Random(3512)
    p.add(lathe([(0, 0), (0.09, 0), (0.09, 0.015), (0.06, 0.03), (0.02, 0.04), (0, 0.04)], 16), c, "gold")
    p.add(lathe([(0.012, 0.04), (0.016, 0.06), (0.01, 0.08), (0.012, 0.12), (0.018, 0.13), (0.01, 0.145), (0, 0.15)], 8), c, "gold")
    cz = 0.26
    face_disc(p, 0, -0.006, cz, 0.112, 0.012, c, "gold", 28)
    ring(p, 0, 0.006, cz, 0.108, 0.007, GOLD_DEEP, "gold", 28, R("X", 90))
    face_disc(p, 0, 0.006, cz, 0.098, 0.003, SOFT_BLUE, "pearl", 24)
    for r in (0.035, 0.06, 0.085):
        ring(p, 0, 0.009, cz - 0.01, r, 0.0012, c, "gold", 20, R("X", 90))
    ticks = []
    for k in range(48):
        a = 2 * math.pi * k / 48
        ln = 0.008 if k % 4 else 0.014
        ux, uz = math.sin(a), math.cos(a)
        w = 0.0012
        ticks.append([(ux * 0.1 - uz * w, 0.0105, cz + uz * 0.1 + ux * w), (ux * (0.1 - ln) - uz * w, 0.0105, cz + uz * (0.1 - ln) + ux * w),
                      (ux * (0.1 - ln) + uz * w, 0.0105, cz + uz * (0.1 - ln) - ux * w), (ux * 0.1 + uz * w, 0.0105, cz + uz * 0.1 - ux * w)])
    p.add(polys(ticks), INK, "matte")
    # the rete: an eccentric ecliptic ring and star pointers with tiny gems
    ring(p, 0, 0.012, cz + 0.022, 0.058, 0.0028, c, "gold", 20, R("X", 90))
    for k in range(7):
        a = 2 * math.pi * k / 7 + 0.3
        tip = (0.085 * math.sin(a), 0.013, cz + 0.085 * math.cos(a))
        midp = (0.05 * math.sin(a + 0.25), 0.013, cz + 0.05 * math.cos(a + 0.25))
        p.add(tube([(0, 0.013, cz), midp, tip], [0.003, 0.002, 0.001], 3), c, "gold")
        p.add(ico(0.0045, 0), [ROSE, PEARL, MINT, BUTTER, LILAC, PERI, BLUSH][k], "pearl", T(*tip))
    p.add(box(0.2, 0.004, 0.012, seg=1), c, "gold", T(0, 0.016, cz) @ R("Y", 35))
    p.add(sphere(0.008, 6, 4), c, "gold", T(0, 0.02, cz))
    # the throne and ring it hangs from, on a crescent bracket
    crest(p, 0, 0.0, cz + 0.11, 0.07, c)
    ring(p, 0, 0, cz + 0.155, 0.014, 0.004, c, "gold", 12, R("X", 90))
    for sx in (-1, 1):
        p.add(tube([(0, 0, 0.145), (sx * 0.08, 0, 0.17), (sx * 0.14, 0, 0.26), (sx * 0.1, 0, 0.36), (0, 0, 0.4)], 0.006, 5), c, "gold")
        p.add(sphere(0.01, 6, 4), c, "gold", T(sx * 0.14, 0, 0.26))
    p.add(tube([(0, 0, 0.4), (0, 0, 0.42)], 0.004, 4), c, "gold")


# ------------------------------------------------------------ kitchen and larder


def board(p, w, d, t, col=OAK, handle=True):
    ol = rr_outline(w - (0.08 if handle else 0), d, 0.03)
    if handle:
        hx = (w - 0.08) / 2
        ol = ol + [(hx + 0.002, -0.03), (hx + 0.06, -0.025), (hx + 0.08, 0.0), (hx + 0.06, 0.025), (hx + 0.002, 0.03)]
        ol = [(x - 0.04, y) for x, y in ol]
    p.add(flat(ol, t, bevel=0.004), col, "satin")
    if handle:
        p.add(torus(0.008, 0.003, 8, 3), darker(col, 0.2), "satin", T(w / 2 - 0.035, 0, t + 0.0005))
    return ol


def sector(r, h, a0, a1, n=14):
    """Cylinder sector (a wheel with a wedge cut), angles in degrees."""
    ol = [(0.0, 0.0)] + [(r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
                         for i in range(n + 1)]
    return flat(ol, h)


def cut_faces(p, m, r, h, a0, a1, col, stripes=()):
    """Paints the two cut faces of a sector (and optional layer stripes)."""
    faces = []
    for a, sgn in ((a0, -1), (a1, 1)):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        nx, ny = -sa * sgn * 0.0008, ca * sgn * 0.0008
        faces.append([(nx, ny, 0.0), (r * ca + nx, r * sa + ny, 0.0), (r * ca + nx, r * sa + ny, h), (nx, ny, h)])
    p.add(polys(faces), col, "satin", m)
    for z0, z1, col2 in stripes:
        st = []
        for a, sgn in ((a0, -1), (a1, 1)):
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            nx, ny = -sa * sgn * 0.0016, ca * sgn * 0.0016
            st.append([(nx, ny, z0), (r * ca + nx, r * sa + ny, z0), (r * ca + nx, r * sa + ny, z1), (nx, ny, z1)])
        p.add(polys(st), col2, "satin", m)


def bread_board(p, size, c):
    rng = random.Random(3601)
    board(p, 0.5, 0.28, 0.022, c)
    # plaited loaf: three twisting strands
    for k in range(3):
        pts, radii = [], []
        for i in range(13):
            t = i / 12
            ph = t * 2 * math.pi * 1.6 + k * 2 * math.pi / 3
            x = -0.2 + 0.22 * t
            pts.append((x, 0.05 + 0.03 * math.sin(ph), 0.05 + 0.014 * math.cos(ph)))
            radii.append(0.01 + 0.024 * math.sin(math.pi * t) ** 0.6)
        p.add(tube(pts, radii, 6), BREAD if k != 1 else lighter(BREAD, 0.08), "satin")
    for i in range(10):
        p.add(sphere(0.003, 4, 3), WHITE, "matte", T(-0.18 + 0.018 * i, 0.05 + 0.02 * math.sin(i), 0.085 + 0.004 * math.cos(i * 2)))
    # round loaf, flour-dusted and scored
    p.add(sphere(0.07, 12, 8), CRUST, "satin", T(0.1, -0.035, 0.022) @ S(1, 1, 0.75))
    p.add(sphere(0.055, 10, 5), lighter(BREAD, 0.4), "matte", T(0.1, -0.035, 0.05) @ S(1, 1, 0.5))
    for k in range(3):
        p.add(sphere(0.03, 6, 3), lighter(BREAD, 0.55), "satin", T(0.1 + (k - 1) * 0.025, -0.035, 0.074) @ R("Z", 70) @ S(1.4, 0.15, 0.15))
    # two cut slices, a knife and crumbs
    for k in range(2):
        m = T(0.0 + 0.03 * k, -0.08, 0.022 + 0.012 * k) @ R("Z", 20 + 15 * k)
        sl = [(0.04 * math.cos(2 * math.pi * i / 12), 0.032 * math.sin(2 * math.pi * i / 12) * (1.25 if i < 6 else 1)) for i in range(12)]
        p.add(flat(sl, 0.012), DOUGH, "matte", m)
        p.add(tube([(x, y, 0.006) for x, y in sl], 0.0065, 4, closed=True), CRUST, "satin", m)
    knife(p, -0.14, -0.1, 0.022, 0.24, 8)
    for i in range(8):
        p.add(ico(0.003, 0), BREAD, "satin", T(rng.uniform(-0.05, 0.15), rng.uniform(-0.12, 0.0), 0.024))


def pie_lattice(p, size, c):
    p.add(lathe([(0, 0), (0.11, 0), (0.135, 0.04), (0.15, 0.045), (0.152, 0.05), (0.14, 0.05), (0.125, 0.042), (0, 0.04)], 20), BLUSH, "pearl")
    ring(p, 0, 0, 0.05, 0.151, 0.003, n=20)
    p.add(lathe([(0, 0.04), (0.12, 0.046), (0.1, 0.058), (0, 0.062)], 16), (0.85, 0.28, 0.42), "satin")
    pts = [((0.128 + 0.005 * math.cos(16 * a)) * math.cos(a), (0.128 + 0.005 * math.cos(16 * a)) * math.sin(a), 0.055 + 0.004 * math.sin(16 * a))
           for a in [2 * math.pi * k / 48 for k in range(48)]]
    p.add(tube(pts, 0.012, 5, closed=True), c, "satin")
    for k in range(5):
        off = -0.08 + 0.04 * k
        L = 2 * math.sqrt(max(0.124 ** 2 - off ** 2, 0.001))
        for rot, lift in ((0, 0.0), (90, 0.003)):
            z = 0.062 + lift + (0.002 if (k % 2) else 0)
            p.add(box(L, 0.02, 0.007, bevel=0.003, seg=1), lighter(c, 0.05), "satin", R("Z", rot) @ T(0, off, z))
    for i in range(3):
        p.add(leaf(0.035, 0.018), lighter(c, 0.1), "satin", T(0, 0, 0.075) @ R("Z", 120 * i + 30) @ R("Y", -10))
    p.add(sphere(0.006, 5, 3), (0.85, 0.28, 0.42), "satin", T(0, 0, 0.076))


def cheese_board(p, size, c):
    rng = random.Random(3603)
    board(p, 0.45, 0.34, 0.02, OAK)
    m = T(-0.04, 0.0, 0.02)
    rind, paste = darker(c, 0.12), lighter(c, 0.35)
    p.add(sector(0.12, 0.13, 30, 330, 22), rind, "satin", m)
    p.add(sphere(0.12, 16, 4), rind, "satin", m @ T(0, 0, 0.13) @ S(1, 1, 0.08))
    cut_faces(p, m, 0.12, 0.13, 30, 330, paste)
    for i in range(5):
        p.add(sphere(0.004, 4, 3), darker(paste, 0.08), "satin", m @ T(0.04 + 0.012 * i, 0.012 + 0.003 * (i % 2) * 5 + 0.01 * i, 0.03 + 0.02 * i))
    w = T(0.13, 0.08, 0.02) @ R("Z", 200) @ R("X", 90) @ T(0, 0, -0.03)
    p.add(sector(0.1, 0.06, -20, 20, 4), rind, "satin", w)
    cut_faces(p, w, 0.1, 0.06, -20, 20, paste)
    knife(p, 0.04, -0.12, 0.02, 0.18, -10, PEARL)
    grapes(p, 0.16, -0.06, 0.06, 0.013, PLUM, rng, 10, (0.3, -0.2, -0.5))
    for i in range(4):
        p.add(box(0.035, 0.035, 0.005, seg=1), BREAD, "satin", T(-0.15 + 0.012 * i, -0.1, 0.022 + 0.005 * i) @ R("Z", 8 * i))


def egg_basket(p, size, c):
    rng = random.Random(3604)
    wire = lighter(IRON, 0.25)
    for z, r in ((0.0, 0.085), (0.04, 0.115), (0.08, 0.135), (0.12, 0.142)):
        ring(p, 0, 0, z + 0.005, r, 0.003, wire, "gold", 18)
    for i in range(14):
        a = 2 * math.pi * i / 14
        ca, sa = math.cos(a), math.sin(a)
        p.add(tube([(0.085 * ca, 0.085 * sa, 0.005), (0.115 * ca, 0.115 * sa, 0.045), (0.135 * ca, 0.135 * sa, 0.085), (0.142 * ca, 0.142 * sa, 0.125)],
                   0.002, 3, caps=False), wire, "gold")
    p.add(tube([(-0.142, 0, 0.125), (-0.12, 0, 0.17), (-0.06, 0, 0.2), (0.0, 0, 0.205), (0.06, 0, 0.2), (0.12, 0, 0.17), (0.142, 0, 0.125)],
               0.004, 5), wire, "gold")
    for sx in (-1, 1):
        p.add(scroll(0.02, 1.2, 8, 0.003), wire, "gold", T(sx * 0.13, 0, 0.12) @ S(sx, 1, 1))
    p.add(lathe([(0, 0.005), (0.08, 0.008), (0.13, 0.09), (0.15, 0.13), (0.14, 0.12)], 14, True, False), lighter(MINT, 0.25), "fabric")
    cols = [(0.86, 0.66, 0.52), CREAM, (0.92, 0.74, 0.6), WHITE, (0.82, 0.92, 0.98)]
    spots = [(0, 0, 0.06), (0.06, 0.03, 0.07), (-0.06, 0.03, 0.07), (0.03, -0.06, 0.07), (-0.04, -0.05, 0.07), (0.08, -0.03, 0.09),
             (-0.08, -0.01, 0.09), (0.0, 0.08, 0.09), (0.02, 0.01, 0.11), (-0.03, 0.04, 0.12), (0.05, -0.02, 0.125), (-0.02, -0.03, 0.125)]
    for i, (x, y, z) in enumerate(spots):
        p.add(egg(0.026), cols[i % len(cols)], "satin", T(x, y, z) @ R("X", rng.uniform(-50, 50)) @ R("Y", rng.uniform(-50, 50)))
    p.add(petal(0.05, 0.03, cup=0.1), WHITE, "fabric", T(0.04, 0.05, 0.14) @ R("Z", 60) @ R("Y", 20))


def honey_jars(p, size, c):
    rng = random.Random(3605)
    for x, h, cloth in ((-0.11, 0.12, ROSE), (0.0, 0.14, MINT), (0.11, 0.1, PERI)):
        top = jar(p, x, -0.02, 0.0, 0.045, h, HONEY, 0.9, label=CANVAS)
        cloth_lid(p, x, -0.02, top, 0.045, cloth)
    p.add(ico(0.009, 1), BUTTER, "satin", T(0.0, -0.02, 0.165) @ S(1.4, 1, 1))
    for k in range(2):
        p.add(box(0.004, 0.019, 0.004, seg=1), INK, "matte", T(-0.004 + 0.008 * k, -0.02, 0.166))
    for sy in (-1, 1):
        p.add(petal(0.012, 0.008, cup=0.1), WHITE, "glass", T(-0.002, -0.02 + sy * 0.004, 0.17) @ R("Z", 90 * sy) @ R("Y", -20))
    m = T(0.02, 0.06, 0.012) @ R("Z", -12) @ R("Y", 90)
    p.add(cyl(0.004, 0.12, 6), OAK, "satin", m @ T(0, 0, -0.1))
    p.add(lathe([(0, 0), (0.008, 0.0), (0.012, 0.006), (0.009, 0.01), (0.013, 0.016), (0.009, 0.02), (0.012, 0.026), (0.006, 0.032), (0, 0.034)], 8),
          OAK, "satin", m @ T(0, 0, 0.02))
    p.add(sphere(0.02, 8, 4), HONEY, "glass", T(0.06, 0.055, 0.001) @ S(1.2, 0.8, 0.1))


def jam_jars(p, size, c):
    rng = random.Random(3606)
    specs = [(-0.115, 0.0, 0.09, 0.044, (0.82, 0.18, 0.3), "doily"), (0.0, -0.02, 0.105, 0.042, (0.98, 0.56, 0.66), "stopper"),
             (0.115, 0.0, 0.095, 0.04, (1.0, 0.64, 0.3), "ribbon")]
    for x, y, h, r, col, lid in specs:
        top = jar(p, x, y, 0.0, r, h, col, 0.92, n=10 if lid != "stopper" else 8, sharp=(lid == "stopper"))
        p.add(flat(oval_xy(0.026, 0.018, 12), 0.002), CANVAS, "matte", T(x, y + r * 0.98, h * 0.45) @ R("X", 90))
        if lid == "doily":
            p.add(lathe([(0, 0), (r * 0.9, 0), (r * 0.9, 0.012), (0, 0.014)], 12), GOLD, "gold", T(x, y, top))
            p.add(flute(lathe([(r * 1.5, -0.01), (r * 1.2, 0.012), (0, 0.016)], 20, False, False), 0.06, 10), WHITE, "fabric", T(x, y, top))
        elif lid == "stopper":
            p.add(cyl(r * 0.6, 0.012, 8), GLASS, "glass", T(x, y, top))
            p.add(ico(r * 0.45, 1), GLASS, "glass", T(x, y, top + 0.024) @ S(1, 1, 0.7), smooth=False)
            p.add(tube([(x + 0.01, y, top - 0.02), (x + 0.02, y + 0.01, top + 0.04)], 0.003, 4), SILVER, "mirror")
            p.add(sphere(0.007, 5, 3), SILVER, "mirror", T(x + 0.021, y + 0.011, top + 0.043) @ S(1, 1, 0.6))
        else:
            p.add(lathe([(0, 0), (r * 0.85, 0), (r * 0.85, 0.014), (0, 0.016)], 12), GOLD, "gold", T(x, y, top))
            cloth_lid(p, x, y, top + 0.012, r * 0.95, lighter(BUTTER, 0.2), ROSE)
    for x in (-0.04, 0.05):
        p.add(lathe([(0, 0), (0.01, 0.003), (0.013, 0.012), (0.008, 0.022), (0, 0.026)], 7), APPLE, "satin",
              T(x, 0.06, 0.0) @ R("Y", 80) @ R("X", 20))
        p.add(leaf(0.012, 0.01), LEAF, "leaf", T(x - 0.022, 0.06, 0.013) @ R("Z", 180))


def oval_xy(rx, ry, n=12):
    return [(rx * math.cos(2 * math.pi * i / n), ry * math.sin(2 * math.pi * i / n)) for i in range(n)]


def copper_kettle(p, size, c):
    p.add(lathe([(0, 0), (0.08, 0), (0.1, 0.01), (0.12, 0.04), (0.125, 0.07), (0.11, 0.11), (0.07, 0.14), (0.05, 0.15), (0, 0.15)], 18), c, "gold")
    ring(p, 0, 0, 0.012, 0.098, 0.006, darker(c, 0.12), "gold", 18)
    ring(p, 0, 0, 0.07, 0.126, 0.004, GOLD, "gold", 18)
    p.add(lathe([(0, 0), (0.052, 0), (0.045, 0.018), (0.02, 0.028), (0.012, 0.03), (0.016, 0.04), (0.012, 0.05), (0, 0.052)], 12), c, "gold",
          T(0, 0, 0.148))
    p.add(sphere(0.012, 6, 4), PEARL, "pearl", T(0, 0, 0.196))
    p.add(tube([(0.1, 0, 0.04), (0.14, 0, 0.07), (0.16, 0, 0.12), (0.18, 0, 0.15)], [0.024, 0.016, 0.011, 0.01], 8), c, "gold")
    ring(p, 0.18, 0, 0.15, 0.01, 0.0025, GOLD, "gold", 8, R("Y", 45))
    p.add(tube([(-0.06, 0, 0.15), (-0.07, 0, 0.21), (-0.04, 0, 0.27), (0.0, 0, 0.285), (0.04, 0, 0.27), (0.07, 0, 0.21), (0.06, 0, 0.15)],
               0.007, 6), c, "gold")
    p.add(tube([(-0.04, 0, 0.27), (0.0, 0, 0.285), (0.04, 0, 0.27)], 0.013, 8), CREAM, "pearl")
    for sx in (-1, 1):
        p.add(sphere(0.012, 6, 4), GOLD, "gold", T(sx * 0.062, 0, 0.148))
    for i in range(10):
        a = 2 * math.pi * i / 10
        p.add(sphere(0.004, 4, 3), GOLD, "gold", T(0.123 * math.cos(a), 0.123 * math.sin(a), 0.055))


def mixing_bowls(p, size, c):
    rng = random.Random(3608)
    bowl(p, 0, 0, 0, 0.19, 0.15, c, "satin", n=20, t=0.01, rim=None)
    for z in (0.08, 0.1):
        band(p, 0, 0, z, 0.189 * 0.82 + (z - 0.0525) * 0.6, 0.008, PERI, "satin", 20)
    bowl(p, 0.01, 0.0, 0.035, 0.145, 0.11, lighter(BLUSH, 0.25), "satin", n=18, t=0.008, rim=None)
    bowl(p, 0.015, 0.005, 0.06, 0.1, 0.075, lighter(MINT, 0.2), "satin", n=16, t=0.007, rim=None)
    p.add(sphere(0.075, 12, 5), DOUGH, "satin", T(0.015, 0.005, 0.105) @ S(1, 1, 0.3))
    p.add(sphere(0.02, 6, 4), lighter(DOUGH, 0.3), "satin", T(0.03, 0.02, 0.123) @ S(1, 1, 0.4))
    m = T(0.015, 0.005, 0.12) @ R("Z", 30) @ R("Y", -25)
    p.add(tube([(-0.02, 0, 0), (0.2, 0, 0)], [0.006, 0.008], 6), OAK, "satin", m)
    p.add(sphere(0.022, 8, 5), OAK, "satin", m @ T(-0.03, 0, 0) @ S(1.4, 1, 0.35))


def rolling_pin_flour(p, size, c):
    rng = random.Random(3609)
    p.add(flat(blob_outline(0.23, 0.14, 18, rng, 0.12), 0.002), FLOUR, "matte")
    p.add(flat(blob_outline(0.15, 0.1, 16, rng, 0.07), 0.012, bevel=0.004), DOUGH, "satin", T(-0.03, 0.0, 0.001))
    star = [((0.03 if i % 2 == 0 else 0.014) * math.cos(math.pi * i / 5 + math.pi / 2), (0.03 if i % 2 == 0 else 0.014) * math.sin(math.pi * i / 5 + math.pi / 2))
            for i in range(10)]
    p.add(flat(star, 0.008, bevel=0.002), lighter(DOUGH, 0.1), "satin", T(0.17, 0.08, 0.002) @ R("Z", 10))
    heart = []
    for i in range(16):
        t = 2 * math.pi * i / 16
        heart.append((0.0018 * 16 * math.sin(t) ** 3, 0.0018 * (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))))
    p.add(flat(heart, 0.008, bevel=0.002), lighter(DOUGH, 0.1), "satin", T(0.17, -0.07, 0.002))
    p.add(tube([(x, y, 0.016) for x, y in heart], 0.002, 4, closed=True), GOLD, "gold", T(0.12, -0.11, 0.0) @ R("Z", -20))
    p.add(tube([(x, y, 0.0) for x, y in heart], 0.002, 4, closed=True), GOLD, "gold", T(0.12, -0.11, 0.004) @ R("Z", -20))
    m = T(-0.03, 0.0, 0.043) @ R("Z", 12) @ R("Y", 90)
    p.add(lathe([(0, -0.22), (0.01, -0.22), (0.012, -0.19), (0.008, -0.17), (0.009, -0.16), (0.03, -0.155), (0.03, 0.155), (0.009, 0.16),
                 (0.008, 0.17), (0.012, 0.19), (0.01, 0.22), (0, 0.22)], 12), c, "satin", m)
    for z in (-0.15, 0.15):
        p.add(torus(0.0295, 0.0025, 12, 4), ROSE, "satin", m @ T(0, 0, z))


def knife_block(p, size, c):
    p.add(box(0.2, 0.17, 0.02, bevel=0.006), darker(c, 0.1), "satin", T(0, 0, 0.01))
    lean = 12
    m = T(0, 0.012, 0.02) @ R("X", lean)
    p.add(box(0.15, 0.11, 0.23, bevel=0.012), c, "satin", m @ T(0, 0, 0.115))
    p.add(box(0.11, 0.004, 0.17, seg=1), lighter(c, 0.12), "satin", m @ T(0, 0.056, 0.115), smooth=False)
    p.add(cyl(0.018, 0.004, 12), GOLD, "gold", m @ T(0, 0.058, 0.13) @ R("X", -90))
    p.add(ico(0.008, 1), ROSE, "pearl", m @ T(0, 0.063, 0.13))
    slots = []
    handles = [(-0.045, -0.025, 0.11, 0.016, OAK_DARK), (0.0, -0.028, 0.1, 0.015, PEARL), (0.045, -0.025, 0.105, 0.016, OAK_DARK),
               (-0.03, 0.022, 0.08, 0.012, BLUSH), (0.03, 0.022, 0.085, 0.013, OAK_DARK), (0.0, 0.03, 0.07, 0.011, MINT)]
    for x, y, L, r, col in handles:
        slots.append((x - r * 0.9, y - 0.003, x + r * 0.9, y + 0.003))
        p.add(lathe([(r * 0.8, 0), (r, 0.015), (r * 0.9, L * 0.7), (r * 1.1, L * 0.9), (0, L)], 8), col, "satin", m @ T(x, y, 0.23) @ S(1, 0.7, 1))
        p.add(torus(r * 0.85, 0.002, 8, 3), GOLD, "gold", m @ T(x, y, 0.236) @ S(1, 0.7, 1))
        for k in (0.35, 0.65):
            p.add(sphere(0.0025, 4, 3), GOLD, "gold", m @ T(x, y + r * 0.72, 0.23 + L * k))
    p.add(rects(slots, 0.2305), (0.4, 0.28, 0.36), "matte", m)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.add(sphere(0.008, 5, 3), GOLD, "gold", T(sx * 0.085, sy * 0.07, 0.0))


def veg_chopping_board(p, size, c):
    rng = random.Random(3611)
    board(p, 0.5, 0.3, 0.025, c)
    for k, (x, y, rot) in enumerate(((-0.09, 0.06, 10), (-0.07, 0.0, -5), (-0.1, -0.05, 20))):
        m = T(x, y, 0.025 + 0.018) @ R("Z", rot)
        p.add(tube([(0, 0, 0), (0.06, 0, -0.002), (0.13, 0, -0.008), (0.16, 0, -0.012)], [0.018, 0.015, 0.008, 0.002], 7), CARROT, "satin", m)
        for j in range(4):
            p.add(tube([(0.0, 0, 0.0), (-0.03, (j - 1.5) * 0.012, 0.035 + 0.01 * (j % 2)), (-0.07, (j - 1.5) * 0.025, 0.06)], 0.0025, 3, caps=False),
                  SAGE, "leaf", m)
            p.add(leaf(0.04, 0.02), SAGE_LIGHT, "leaf", m @ T(-0.07, (j - 1.5) * 0.025, 0.06) @ R("Z", 180 + (j - 1.5) * 15) @ R("Y", -20))
    for k, (y, rot) in enumerate(((-0.1, -8), (-0.05, 4))):
        m = T(0.0, y, 0.025 + 0.024) @ R("Z", rot) @ R("Y", 90)
        p.add(cyl(0.022, 0.12, 10), (0.98, 0.98, 0.9), "satin", m @ T(0, 0, -0.06))
        p.add(cyl(0.022, 0.06, 10, r2=0.02), SAGE_LIGHT, "satin", m @ T(0, 0, 0.06))
        p.add(lathe([(0.0, 0), (0.01, 0.003), (0.004, 0.006)], 6, False, True), CREAM, "matte", m @ T(0, 0, -0.064))
        for j, a in enumerate((-20, 0, 20)):
            p.add(leaf(0.16, 0.035), SAGE if j % 2 else SAGE_DEEP, "leaf", m @ T(0, 0, 0.115) @ R("Y", -90) @ R("Z", a) @ R("X", 90))
    for k in range(7):
        p.add(cyl(0.016, 0.005, 10), CARROT, "satin", T(0.12 + 0.016 * k, 0.07 + 0.006 * (k % 2), 0.025 + 0.002 * k) @ R("Y", 30))
        p.add(cyl(0.007, 0.0052, 6), lighter(CARROT, 0.25), "satin", T(0.12 + 0.016 * k, 0.07 + 0.006 * (k % 2), 0.0251 + 0.002 * k) @ R("Y", 30))
    knife(p, 0.09, -0.02, 0.025, 0.24, -15, PEARL)


def garlic(p, m, r, col):
    p.add(lathe([(0, 0), (r * 0.5, r * 0.05), (r * 0.95, r * 0.4), (r, r * 0.8), (r * 0.7, r * 1.2), (r * 0.25, r * 1.45), (r * 0.08, r * 1.9),
                 (0, r * 2.0)], 8), col, "satin", m)
    p.add(cyl(r * 0.25, r * 0.12, 6), BARK, "matte", m @ T(0, 0, -r * 0.1))


def garlic_braid_wall(p, size, c):
    rng = random.Random(3612)
    p.add(cyl(0.008, 0.03, 6), GOLD, "gold", T(0, 0.0, 0.69) @ R("X", -90))
    p.add(torus(0.025, 0.004, 10, 4), STRAW, "fabric", T(0, 0.025, 0.665) @ R("X", 90))
    for k in range(3):
        pts = [(0.012 * math.sin(t * 9 + k * 2.1), 0.035 + 0.008 * math.cos(t * 9 + k * 2.1), 0.64 - 0.56 * t) for t in [i / 12 for i in range(13)]]
        p.add(tube(pts, 0.007, 4), STRAW if k != 1 else darker(STRAW, 0.08), "fabric")
    for i in range(10):
        t = i / 9
        side = 1 if i % 2 else -1
        z = 0.58 - 0.5 * t
        x = side * (0.095 - 0.035 * t)
        col = c if i % 3 else (0.97, 0.92, 1.0)
        garlic(p, T(x, 0.045, z) @ R("Y", -side * 70) @ R("Z", rng.uniform(-30, 30)), 0.034 - 0.006 * t, col)
        p.add(tube([(x * 0.6, 0.042, z + 0.012), (x * 0.1, 0.036, z + 0.024)], 0.003, 3), STRAW, "fabric")
    for i in range(6):
        t = (i + 0.5) / 6
        side = -1 if i % 2 else 1
        z = 0.6 - 0.55 * t
        base = (side * 0.02, 0.06, z)
        tip = (side * (0.07 + 0.04 * t), 0.075, z - 0.09)
        mid = (side * 0.06, 0.075, z - 0.03)
        p.add(tube([base, mid, tip], [0.009, 0.007, 0.002], 6), (0.92, 0.3, 0.33) if i % 2 else (1.0, 0.45, 0.38), "satin")
        p.add(sphere(0.007, 5, 3), SAGE_DEEP, "leaf", T(*base))
    for sx in (-1, 1):
        p.add(torus(0.03, 0.007, 10, 4), ROSE, "fabric", T(sx * 0.03, 0.06, 0.62) @ R("Y", sx * 20) @ S(1.2, 0.5, 0.8) @ R("X", 90))
        p.add(tube([(0, 0.06, 0.615), (sx * 0.03, 0.065, 0.56), (sx * 0.04, 0.065, 0.52)], 0.006, 4), ROSE, "fabric")
    p.add(sphere(0.012, 6, 4), ROSE, "fabric", T(0, 0.065, 0.62))
    p.add(tube([(0, 0.035, 0.08), (0.0, 0.035, 0.03)], 0.006, 4), STRAW, "fabric")
    for k in range(5):
        p.add(tube([(0, 0.035, 0.035), ((k - 2) * 0.008, 0.035 + 0.004 * (k % 2), 0.0)], 0.0025, 3), STRAW, "fabric")


def tart(p, x, y, z, r, top, rng):
    p.add(flute(lathe([(0, 0), (r * 0.8, 0), (r, r * 0.4), (r * 1.04, r * 0.5), (r * 0.9, r * 0.48)], 16, True, False), 0.05, 8), CRUST, "satin",
          T(x, y, z))
    p.add(lathe([(0, r * 0.3), (r * 0.9, r * 0.42), (0, r * 0.48)], 14), (1.0, 0.9, 0.42), "satin", T(x, y, z))
    zt = z + r * 0.47
    if top == "meringue":
        p.add(flute(lathe([(0, 0), (r * 0.5, 0), (r * 0.4, r * 0.3), (r * 0.15, r * 0.55), (0, r * 0.75)], 10), 0.18, 5), WHITE, "satin",
              T(x, y, zt) @ R("Z", rng.uniform(0, 60)))
    elif top == "lemon":
        p.add(cyl(r * 0.45, r * 0.08, 10), BUTTER, "satin", T(x, y, zt) @ R("X", 60))
        p.add(torus(r * 0.44, r * 0.04, 10, 3), (1.0, 0.86, 0.3), "satin", T(x, y, zt) @ R("X", 60) @ T(0, 0, r * 0.04))
    elif top == "violet":
        star_flower(p, (x, y, zt), r * 0.3, PLUM, 5, heart=BUTTER)
        p.add(leaf(r * 0.4, r * 0.2), LEAF, "leaf", T(x, y, zt) @ R("Z", 200))
    elif top == "berry":
        for k in range(3):
            p.add(sphere(r * 0.18, 6, 4), (0.9, 0.3, 0.45), "satin", T(x + r * 0.2 * math.cos(k * 2.1), y + r * 0.2 * math.sin(k * 2.1), zt + r * 0.1))
    else:
        for k in range(2):
            p.add(leaf(r * 0.45, r * 0.22), SAGE_LIGHT, "leaf", T(x, y, zt) @ R("Z", 40 + 140 * k) @ R("Y", -15))


def lemon_tarts_tray(p, size, c):
    rng = random.Random(3613)
    ol = rr_outline(0.4, 0.3, 0.05)
    p.add(flat(ol, 0.008, bevel=0.002), PEARL, "pearl")
    p.add(tube([(x, y, 0.012) for x, y in ol], 0.005, 4, closed=True), GOLD, "gold")
    p.add(flute(lathe([(0.0, 0), (0.17, 0), (0.17, 0.001)], 24, True, False), 0.04, 12), WHITE, "fabric", T(0, 0, 0.0085) @ S(1, 0.72, 1))
    tops = ["meringue", "lemon", "violet", "berry", "mint", "meringue"]
    k = 0
    for j in (-1, 1):
        for i in (-1, 0, 1):
            tart(p, i * 0.115, j * 0.068, 0.0095, 0.045, tops[k], rng)
            k += 1


def chocolate_torte(p, size, c):
    rng = random.Random(3614)
    p.add(lathe([(0, 0), (0.06, 0), (0.06, 0.008), (0.02, 0.02), (0.018, 0.05), (0.04, 0.055), (0.14, 0.06), (0.15, 0.066), (0, 0.064)], 20),
          BLUSH, "pearl")
    ring(p, 0, 0, 0.065, 0.148, 0.003, n=20)
    m = T(0, 0, 0.065)
    a0, a1 = 25, 335
    p.add(sector(0.11, 0.06, a0, a1, 22), c, "satin", m)
    cut_faces(p, m, 0.11, 0.06, a0, a1, lighter(c, 0.08), stripes=[(0.018, 0.024, CREAM), (0.038, 0.044, (0.95, 0.5, 0.6))])
    p.add(sector(0.112, 0.006, a0, a1, 22), darker(c, 0.15), "satin", m @ T(0, 0, 0.058))
    for k in range(14):
        a = math.radians(a0 + 12 + (a1 - a0 - 24) * k / 13)
        L = 0.012 + 0.012 * (k % 3) / 2
        p.add(tube([(0.112 * math.cos(a), 0.112 * math.sin(a), 0.062), (0.113 * math.cos(a), 0.113 * math.sin(a), 0.062 - L)], [0.004, 0.003], 4),
              darker(c, 0.15), "satin", m)
    for k in range(9):
        a = math.radians(a0 + 15 + (a1 - a0 - 30) * k / 8)
        x, y = 0.085 * math.cos(a), 0.085 * math.sin(a)
        p.add(flute(lathe([(0, 0), (0.012, 0), (0.009, 0.008), (0.004, 0.014), (0, 0.018)], 8), 0.2, 4), WHITE if k % 2 else lighter(BLUSH, 0.3),
              "satin", m @ T(x, y, 0.064))
        if k % 2 == 0:
            p.add(sphere(0.006, 6, 4), (0.9, 0.25, 0.42), "satin", m @ T(x * 0.75, y * 0.75, 0.069))
    p.add(rects([(-0.012, -0.01, 0.012, 0.01)], 0.0645), GOLD, "gold", m @ R("Z", 30))


def apples_bowl(p, size, c):
    rng = random.Random(3615)
    bowl(p, 0, 0, 0, 0.165, 0.09, OAK, "satin", n=18, t=0.012, rim=None)
    ring(p, 0, 0, 0.09, 0.159, 0.006, lighter(OAK, 0.15), "satin", 18)
    cols = [APPLE, c, (0.95, 0.42, 0.4), APPLE, (1.0, 0.78, 0.6), c, APPLE]
    spots = [(0.0, 0.0, 0.115), (0.07, 0.04, 0.06), (-0.07, 0.04, 0.06), (0.0, -0.08, 0.06), (0.06, -0.05, 0.06), (-0.06, -0.05, 0.06),
             (0.0, 0.08, 0.06)]
    for i, ((x, y, z), col) in enumerate(zip(spots, cols)):
        apple(p, T(x, y, z) @ R("X", rng.uniform(-25, 25)) @ R("Y", rng.uniform(-25, 25)), 0.045, col, rng, leafy=(i in (0, 3)))


def salt_crock(p, size, c):
    p.add(lathe([(0, 0), (0.07, 0), (0.075, 0.01), (0.085, 0.06), (0.085, 0.12), (0.075, 0.14), (0.07, 0.145), (0, 0.145)], 16), c, "satin")
    for z in (0.03, 0.115):
        band(p, 0, 0, z, 0.0862 if z > 0.05 else 0.081, 0.008, PERI, "satin", 16)
    p.add(flat(oval_xy(0.035, 0.022, 14), 0.002), WHITE, "satin", T(0, 0.085, 0.075) @ R("X", 90))
    p.add(rects([(-0.022, -0.004, 0.022, 0.004)], 0.0025), PERI, "matte", T(0, 0.085, 0.075) @ R("X", 90))
    p.add(lathe([(0, 0), (0.08, 0), (0.08, 0.012), (0.06, 0.018), (0.015, 0.02), (0.015, 0.035), (0.025, 0.045), (0, 0.05)], 16), OAK, "satin",
          T(0, 0, 0.145))
    m = T(0.045, 0.075, 0.0)
    p.add(lathe([(0, 0), (0.016, 0.0), (0.02, 0.014), (0.018, 0.015), (0, 0.004)], 8), OAK, "satin", m @ T(0, 0.012, 0.0))
    p.add(tube([(0.0, 0.0, 0.012), (-0.004, -0.006, 0.1)], 0.004, 4), OAK, "satin", m)


# ------------------------------------------------------------ stillroom and linen


def bandage_rolls(p, size, c):
    rng = random.Random(3701)
    w, d = 0.34, 0.24
    p.add(box(w, d, 0.01, bevel=0.003, seg=1), lighter(OAK, 0.15), "satin", T(0, 0, 0.005))
    for sx in (-1, 1):
        p.add(box(0.012, d, 0.035, bevel=0.003, seg=1), lighter(OAK, 0.15), "satin", T(sx * (w / 2 - 0.006), 0, 0.0175))
        p.add(tube([(sx * (w / 2 + 0.002), -0.03, 0.03), (sx * (w / 2 + 0.018), 0, 0.034), (sx * (w / 2 + 0.002), 0.03, 0.03)], 0.004, 4),
              GOLD, "gold")
    for sy in (-1, 1):
        p.add(box(w, 0.012, 0.035, bevel=0.003, seg=1), lighter(OAK, 0.15), "satin", T(0, sy * (d / 2 - 0.006), 0.0175))
    linen = lighter(c, 0.2)
    def roll(m, r, L):
        p.add(cyl(r, L, 12), linen, "fabric", m)
        for e in (0.0, L):
            p.add(torus(r * 0.6, r * 0.12, 8, 3), darker(linen, 0.06), "fabric", m @ T(0, 0, e))
    for k, (x, y) in enumerate(((-0.11, -0.06), (-0.11, 0.0), (-0.11, 0.06), (0.0, -0.065))):
        roll(T(x - 0.04, y, 0.04) @ R("Y", 90), 0.028, 0.085 - 0.006 * k)
    roll(T(-0.08, 0.03, 0.088) @ R("Y", 90), 0.026, 0.07)
    for x, y, r, h in ((0.06, 0.06, 0.03, 0.08), (0.12, 0.05, 0.026, 0.07), (0.1, -0.04, 0.028, 0.075)):
        roll(T(x, y, 0.01), r, h)
    p.add(tube([(0.0, -0.065, 0.068), (0.02, -0.09, 0.06), (0.03, -0.11, 0.04), (0.035, -0.125, 0.02), (0.045, -0.135, 0.002),
                (0.08, -0.14, 0.001)], 0.0035, 4), linen, "fabric")
    p.add(torus(0.012, 0.002, 10, 3), GOLD, "gold", T(0.13, -0.08, 0.012) @ S(1.6, 1, 1))
    for sx in (-1, 1):
        p.add(tube([(0.13, -0.08, 0.012), (0.13 + 0.05, -0.08 + sx * 0.008, 0.012)], [0.0025, 0.001], 4), SILVER, "mirror")
        p.add(torus(0.008, 0.002, 8, 3), GOLD, "gold", T(0.12, -0.08 + sx * 0.012, 0.012))
    p.add(lathe([(0, 0), (0.018, 0), (0.02, 0.04), (0.008, 0.05), (0.008, 0.06), (0, 0.06)], 10), (1.0, 0.72, 0.45), "glass", T(0.0, 0.07, 0.01))
    p.add(cyl(0.009, 0.014, 8), lighter(OAK, 0.3), "satin", T(0.0, 0.07, 0.068))


def basin_and_jug(p, size, c):
    rng = random.Random(3702)
    sy = 0.85
    bowl(p, 0, 0, 0, 0.21, 0.1, c, n=22, t=0.01, sy=sy)
    p.add(lathe([(0, 0.062), (0.17, 0.065), (0, 0.065)], 20), (0.78, 0.94, 0.95), "water", S(1, sy, 1))
    for i in range(14):
        a = 2 * math.pi * i / 14
        p.add(floret(0.014), [BLUSH, MINT, LILAC][i % 3], "pearl",
              T(0.198 * math.cos(a), 0.198 * sy * math.sin(a), 0.07) @ aim((math.cos(a), math.sin(a), 0.4)))
    m = T(0.05, -0.02, 0.012)
    p.add(lathe([(0, 0), (0.055, 0), (0.06, 0.01), (0.04, 0.03), (0.045, 0.06), (0.085, 0.12), (0.09, 0.18), (0.07, 0.25), (0.058, 0.29),
                 (0.07, 0.33), (0.078, 0.36), (0.07, 0.358), (0.055, 0.33), (0.0, 0.3)], 18), c, "pearl", m)
    ring(p, 0.05, -0.02, 0.372, 0.075, 0.004, n=18)
    ring(p, 0.05, -0.02, 0.022, 0.05, 0.004, n=14)
    p.add(flat([(0, -0.03), (0.06, -0.008), (0.065, 0.0), (0.06, 0.008), (0, 0.03)], 0.006, bevel=0.002), c, "pearl", m @ T(0.06, 0, 0.352) @ R("Y", -14))
    p.add(tube([(-0.06, 0, 0.32), (-0.12, 0, 0.31), (-0.125, 0, 0.22), (-0.09, 0, 0.14), (-0.085, 0, 0.12)], [0.009, 0.009, 0.008, 0.007, 0.006], 6),
          GOLD, "gold", m)
    p.add(scroll(0.015, 1.2, 8, 0.004), GOLD, "gold", m @ T(-0.125, 0, 0.32))
    for k, a in enumerate((-40, 0, 40)):
        x, y = 0.09 * math.sin(math.radians(a)), 0.09 * math.cos(math.radians(a))
        bloom(p, (x, y, 0.17), 0.016, ROSE if k == 1 else BLUSH, 2, 5, rng, tilt=aim((x, y, 0.0)))
        p.add(leaf(0.025, 0.012), LEAF, "leaf", m @ T(x * 1.0, y, 0.15) @ R("Z", math.degrees(math.atan2(y, x))) @ R("X", 70))
    p.add(box(0.1, 0.06, 0.01, bevel=0.004, seg=1), WHITE, "fabric", T(-0.15, 0.1, 0.105) @ R("Y", 30) @ R("Z", 20))


def salve_jars(p, size, c):
    rng = random.Random(3703)
    glazes = [PEARL, c, BLUSH, LILAC, BUTTER, MINT]
    specs = [(-0.1, -0.035, 0.03, 0.08, "dome"), (-0.035, -0.04, 0.026, 0.1, "cork"), (0.03, -0.035, 0.032, 0.07, "cloth"),
             (0.1, -0.035, 0.028, 0.11, "dome"), (-0.07, 0.035, 0.026, 0.055, "open"), (0.0, 0.035, 0.024, 0.06, "dome"),
             (0.07, 0.04, 0.025, 0.05, "cork")]
    for i, (x, y, r, h, lid) in enumerate(specs):
        col = glazes[i % len(glazes)]
        p.add(lathe([(0, 0), (r * 0.85, 0), (r, r * 0.25), (r, h * 0.82), (r * 0.82, h * 0.9), (r * 0.78, h)], 12), col, "pearl", T(x, y, 0))
        p.add(box(r * 1.15, 0.002, h * 0.32, seg=1), CANVAS, "matte", T(x, y + r * 0.98, h * 0.45), smooth=False)
        p.add(box(r * 0.8, 0.002, 0.003, seg=1), INK, "matte", T(x, y + r * 0.98 + 0.0015, h * 0.48), smooth=False)
        if lid == "dome":
            p.add(lathe([(0, 0), (r * 0.9, 0), (r * 0.85, r * 0.3), (r * 0.4, r * 0.55), (r * 0.25, r * 0.6), (r * 0.3, r * 0.8), (0, r * 0.9)], 10),
                  GOLD, "gold", T(x, y, h))
        elif lid == "cork":
            p.add(cyl(r * 0.75, r * 0.6, 8, r2=r * 0.85), lighter(OAK, 0.3), "satin", T(x, y, h - r * 0.2))
        elif lid == "cloth":
            cloth_lid(p, x, y, h, r * 0.85, ROSE)
        else:
            p.add(lathe([(0, h * 0.85), (r * 0.76, h * 0.87), (r * 0.3, h * 0.92), (0, h * 0.95)], 10), (0.72, 0.92, 0.78), "satin", T(x, y, 0))
            p.add(cyl(r * 0.9, 0.006, 10), GOLD, "gold", T(x + r * 1.7, y + 0.01, 0.0))
    p.add(box(0.06, 0.008, 0.002, seg=1), SILVER, "mirror", T(-0.02, 0.07, 0.003) @ R("Z", 15))
    p.add(lathe([(0, 0), (0.012, 0), (0.014, 0.08), (0.006, 0.095), (0.006, 0.11), (0, 0.11)], 8), mix(GLASS, MINT, 0.4), "glass", T(0.13, 0.045, 0))
    p.add(ico(0.008, 1), mix(GLASS, MINT, 0.4), "glass", T(0.13, 0.045, 0.12))


def brass_scales(p, size, c):
    rng = random.Random(3704)
    p.add(box(0.36, 0.16, 0.035, bevel=0.008), OAK, "satin", T(0, 0, 0.0175))
    p.add(box(0.12, 0.004, 0.02, seg=1), lighter(OAK, 0.15), "satin", T(0, 0.081, 0.0175), smooth=False)
    p.add(sphere(0.006, 6, 4), c, "gold", T(0, 0.085, 0.0175))
    p.add(tube([(-0.18, -0.08, 0.035), (0.18, -0.08, 0.035), (0.18, 0.08, 0.035), (-0.18, 0.08, 0.035)], 0.003, 4, closed=True), c, "gold", smooth=False)
    p.add(lathe([(0.04, 0.035), (0.035, 0.045), (0.015, 0.06), (0.01, 0.1), (0.014, 0.12), (0.008, 0.14), (0.008, 0.27), (0.014, 0.28),
                 (0.01, 0.29)], 10), c, "gold")
    p.add(lathe([(0, 0), (0.012, 0), (0.016, 0.02), (0.008, 0.035), (0.01, 0.045), (0, 0.06)], 8), c, "gold", T(0, 0, 0.3))
    p.add(tube([(-0.16, 0, 0.285), (-0.06, 0, 0.29), (0, 0, 0.292), (0.06, 0, 0.29), (0.16, 0, 0.285)], [0.004, 0.006, 0.008, 0.006, 0.004], 6),
          c, "gold")
    p.add(cyl(0.004, 0.09, 4, r2=0.001), c, "gold", T(0, 0.012, 0.29) @ R("X", 180))
    p.add(tube([(0.04 * math.sin(a), 0.01, 0.21 + 0.04 * math.cos(a)) for a in [math.radians(-40 + 10 * k) for k in range(9)]], 0.0025, 4), c, "gold")
    for sx in (-1, 1):
        px = sx * 0.15
        p.add(torus(0.008, 0.002, 8, 3), c, "gold", T(px, 0, 0.278) @ R("X", 90))
        for k in range(3):
            a = 2 * math.pi * k / 3 + 0.5
            p.add(tube([(px, 0, 0.275), (px + 0.052 * math.cos(a), 0.052 * math.sin(a), 0.11)], 0.0012, 3, caps=False), c, "gold")
        p.add(lathe([(0, 0), (0.03, 0.002), (0.05, 0.012), (0.058, 0.022), (0.054, 0.022), (0.045, 0.014), (0, 0.006)], 14), c, "gold", T(px, 0, 0.095))
    for k in range(6):
        p.add(leaf(0.03, 0.014), SAGE if k % 2 else SAGE_LIGHT, "leaf", T(-0.15, 0, 0.105) @ R("Z", 60 * k) @ R("Y", -15))
    p.add(sphere(0.012, 6, 4), (0.62, 0.5, 0.86), "fabric", T(-0.15, 0.0, 0.11))
    for k, r in enumerate((0.012, 0.01)):
        p.add(cyl(r, 0.012, 10), c, "gold", T(0.15, 0.0, 0.103 + 0.012 * k))
    p.add(sphere(0.005, 5, 3), c, "gold", T(0.15, 0.0, 0.13))
    for k, (r, h) in enumerate(((0.016, 0.02), (0.013, 0.016), (0.011, 0.013), (0.009, 0.01))):
        x = -0.12 + k * 0.035
        p.add(cyl(r, h, 10), c, "gold", T(x, 0.05, 0.035))
        p.add(lathe([(0, 0), (r * 0.35, 0), (r * 0.3, r * 0.4), (r * 0.5, r * 0.7), (0, r * 0.9)], 6), c, "gold", T(x, 0.05, 0.035 + h))


def linen_stack(p, size, c):
    rng = random.Random(3705)
    cols = [WHITE, lighter(BLUSH, 0.3), c, lighter(MINT, 0.3), lighter(PERI, 0.35)]
    z = 0.0
    for k, col in enumerate(cols):
        t = 0.042
        m = T(rng.uniform(-0.006, 0.006), rng.uniform(-0.006, 0.006), z + t / 2) @ R("Z", rng.uniform(-3, 3))
        p.add(cushion(0.36, 0.27, t, puff=0.12), col, "fabric", m)
        p.add(cyl(t * 0.5, 0.35, 8), col, "fabric", m @ T(-0.175, 0.12, 0.0) @ R("Y", 90))
        if k % 2 == 0:
            p.add(box(0.352, 0.004, 0.006, seg=1), [ROSE, LILAC, MINT][k // 2], "fabric", m @ T(0, 0.142, -0.006))
        else:
            sc = []
            for i in range(14):
                x0 = -0.17 + 0.025 * i
                sc.append([(x0, 0.142, 0.0), (x0 + 0.025, 0.142, 0.0), (x0 + 0.0125, 0.142, -0.014)])
            p.add(polys(sc), WHITE, "fabric", m)
        z += t
    tape = ROSE
    p.add(box(0.03, 0.29, 0.003, seg=1), tape, "fabric", T(0.05, 0, z + 0.0015))
    for sy in (-1, 1):
        p.add(box(0.03, 0.003, z, seg=1), tape, "fabric", T(0.05, sy * 0.148, z / 2))
    for sx in (-1, 1):
        p.add(torus(0.025, 0.007, 10, 4), tape, "fabric", T(0.05 + sx * 0.026, 0.02, z + 0.016) @ R("Y", sx * 25) @ S(1.2, 0.45, 0.9) @ R("X", 90))
        p.add(tube([(0.05, 0.02, z + 0.008), (0.05 + sx * 0.03, 0.06, z + 0.005), (0.05 + sx * 0.045, 0.1, z + 0.004)], 0.006, 4), tape, "fabric")
    p.add(sphere(0.011, 6, 4), tape, "fabric", T(0.05, 0.02, z + 0.012))
    for j in range(3):
        a = math.radians(-30 + 15 * j)
        x0, y0 = 0.02, 0.0
        x1, y1 = x0 - 0.16 * math.cos(a), y0 + 0.16 * math.sin(a)
        p.add(tube([(x0, y0, z + 0.006), (x1, y1, z + 0.008)], 0.0015, 3, caps=False), SAGE, "leaf")
        for k in range(6):
            t = 0.55 + 0.08 * k
            p.add(sphere(0.0045, 4, 3), (0.62, 0.5, 0.86), "fabric", T(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z + 0.011) @ S(1.4, 1, 1))


def herb_bell_jars(p, size, c):
    rng = random.Random(3706)
    # tall cylinder jar of lavender
    x = -0.15
    top = jar(p, x, 0.0, 0.0, 0.05, 0.22, lighter(SAGE, 0.35), 0.08, label=CANVAS, label_h=0.15)
    for k in range(7):
        a = 2 * math.pi * k / 7
        bx, by = x + 0.022 * math.cos(a), 0.022 * math.sin(a)
        tx, ty = x + 0.04 * math.cos(a), 0.04 * math.sin(a)
        p.add(tube([(bx, by, 0.02), (tx, ty, 0.2)], 0.0018, 3, caps=False), SAGE, "leaf")
        for j in range(3):
            p.add(sphere(0.0065, 4, 3), (0.62, 0.5, 0.86), "fabric", T(bx + (tx - bx) * (0.78 + 0.09 * j), by + (ty - by) * (0.78 + 0.09 * j),
                                                                     0.02 + 0.18 * (0.78 + 0.09 * j)) @ S(1, 1, 1.5))
    p.add(cyl(0.035, 0.015, 10), GLASS, "glass", T(x, 0, top - 0.005))
    p.add(ico(0.03, 1), GLASS, "glass", T(x, 0, top + 0.035) @ S(1, 1, 1.15), smooth=False)
    ring(p, x, 0, top - 0.004, 0.04, 0.003, n=12)
    # round globe jar of rosebuds
    x = 0.01
    p.add(lathe([(0, 0), (0.045, 0), (0.07, 0.04), (0.075, 0.08), (0.06, 0.13), (0.04, 0.15), (0.04, 0.17)], 14, True, False), GLASS, "glass", T(x, 0, 0))
    p.add(lathe([(0, 0.004), (0.045, 0.006), (0.066, 0.04), (0.068, 0.08), (0, 0.095)], 12), (0.86, 0.52, 0.62), "fabric", T(x, 0, 0))
    for k in range(10):
        a = k * 2.4
        d = 0.05 * math.sqrt((k + 0.5) / 10)
        p.add(sphere(0.009, 6, 4), (0.9, 0.42, 0.58) if k % 2 else ROSE, "fabric", T(x + d * math.cos(a), d * math.sin(a), 0.085 + 0.01 * (1 - d / 0.05)) @ S(1, 1, 1.3))
    p.add(lathe([(0, 0), (0.045, 0), (0.045, 0.014), (0.03, 0.03), (0.012, 0.032), (0.016, 0.045), (0, 0.05)], 12), c, "pearl", T(x, 0, 0.17))
    ring(p, x, 0, 0.17, 0.045, 0.003, n=12)
    p.add(box(0.06, 0.002, 0.03, seg=1), CANVAS, "matte", T(x, 0.072, 0.06) @ R("X", -10), smooth=False)
    # squat jar of chamomile with a cork
    x = 0.155
    top = jar(p, x, 0.0, 0.0, 0.06, 0.11, lighter(BUTTER, 0.3), 0.55, label=CANVAS)
    for k in range(7):
        a = k * 2.4
        d = 0.038 * math.sqrt((k + 0.5) / 7)
        star_flower(p, (x + d * math.cos(a), d * math.sin(a), 0.058), 0.013, WHITE, 5, heart=BUTTER)
    p.add(cyl(0.042, 0.03, 10, r2=0.05), lighter(OAK, 0.3), "satin", T(x, 0, top - 0.012))
    # a bundle of dried herbs tied with string in front
    m = T(-0.04, 0.075, 0.012) @ R("Z", -8)
    for k in range(7):
        a = (k - 3) * 6
        p.add(tube([(-0.06, 0.0, 0.0), (0.04 * math.cos(math.radians(a)), 0.04 * math.sin(math.radians(a)), 0.002)], 0.0018, 3, caps=False),
              SAGE_DEEP, "leaf", m)
        for j in range(3):
            p.add(leaf(0.03, 0.012), SAGE if (k + j) % 2 else SAGE_LIGHT, "leaf",
                  m @ T(0.0 + 0.02 * j, 0.004 * (k - 3), 0.004) @ R("Z", a + (30 if j % 2 else -30)))
    p.add(torus(0.008, 0.002, 8, 3), STRAW, "fabric", m @ T(-0.035, 0, 0.002) @ R("Y", 90))


# ------------------------------------------------------------ wall pieces (back flat at -Y)


def wall_clock_sunburst(p, size, c):
    cz = 0.4
    p.add(cyl(0.2, 0.02, 24), c, "gold", T(0, 0.0, cz) @ R("X", -90))
    for k in range(32):
        a = 2 * math.pi * k / 32
        L = 0.21 if k % 2 == 0 else 0.15
        w = 0.028 if k % 2 == 0 else 0.02
        ray = [(0.0, -w / 2), (L * 0.55, -w * 0.35), (L, 0.0), (L * 0.55, w * 0.35), (0.0, w / 2)]
        bm = upright([(x, z) for x, z in ray], 0.012, 0.012 if k % 2 == 0 else 0.004)
        p.add(bm, c if k % 2 == 0 else lighter(c, 0.15), "gold", T(0, 0, cz) @ R("Y", -math.degrees(a)) @ T(0.17, 0, 0))
        if k % 2 == 0:
            p.add(sphere(0.014, 6, 4), c, "gold", T(0, 0, cz) @ R("Y", -math.degrees(a)) @ T(0.17 + L + 0.005, 0.018, 0))
        else:
            p.add(sphere(0.008, 5, 3), PEARL, "pearl", T(0, 0, cz) @ R("Y", -math.degrees(a)) @ T(0.17 + L + 0.004, 0.012, 0))
    ring(p, 0, 0.03, cz, 0.18, 0.012, c, "gold", 28, R("X", 90))
    ring(p, 0, 0.04, cz, 0.155, 0.006, PEARL, "pearl", 28, R("X", 90))
    dial(p, 0, 0.04, cz, 0.14)
    p.add(lathe([(0, 0), (0.02, 0), (0.012, 0.012), (0, 0.018)], 10), c, "gold", T(0, 0.06, cz) @ R("X", -90))


def barometer_wall(p, size, c):
    rng = random.Random(3802)
    wood = c
    face_disc(p, 0, 0.0, 0.2, 0.12, 0.035, wood, "satin", 24)
    p.add(box(0.075, 0.035, 0.5, bevel=0.006), wood, "satin", T(0, 0.0175, 0.54))
    p.add(box(0.11, 0.035, 0.05, bevel=0.008), wood, "satin", T(0, 0.0175, 0.8))
    for sx in (-1, 1):
        p.add(scroll(0.04, 1.3, 10, 0.009), wood, "satin", T(sx * 0.045, 0.02, 0.84) @ S(-sx, 1, 1) @ R("Y", 180))
    p.add(lathe([(0, 0), (0.016, 0), (0.012, 0.012), (0.02, 0.03), (0.016, 0.042), (0.004, 0.048), (0, 0.06)], 10), GOLD, "gold",
          T(0, 0.018, 0.84))
    dial(p, 0, 0.035, 0.2, 0.092)
    ring(p, 0, 0.044, 0.2, 0.1, 0.006, GOLD, "gold", 24, R("X", 90))
    p.add(tube([(0, 0.05, 0.2), (0.05, 0.05, 0.245)], 0.0025, 4), GOLD, "gold")
    ring(p, 0, 0.044, 0.08, 0.02, 0.003, GOLD, "gold", 10, R("X", 90))
    face_disc(p, 0, 0.035, 0.08, 0.017, 0.004, lighter(SOFT_BLUE, 0.2), "pearl", 10)
    # thermometer on the neck and a little hygrometer dial above
    p.add(box(0.032, 0.004, 0.2, bevel=0.002, seg=1), WHITE, "pearl", T(0, 0.037, 0.48))
    p.add(rects_xz([(-0.012, 0.39 + 0.012 * k, -0.004 if k % 2 else 0.0, 0.392 + 0.012 * k) for k in range(15)], 0.0395), INK, "matte")
    p.add(cyl(0.004, 0.17, 6), GLASS, "glass", T(0.006, 0.042, 0.39))
    p.add(cyl(0.0022, 0.11, 4), WAX_RED, "satin", T(0.006, 0.042, 0.39))
    p.add(sphere(0.007, 6, 4), WAX_RED, "satin", T(0.006, 0.042, 0.388))
    face_disc(p, 0, 0.035, 0.66, 0.03, 0.004, WHITE, "pearl", 14)
    ring(p, 0, 0.04, 0.66, 0.032, 0.004, GOLD, "gold", 14, R("X", 90))
    p.add(tube([(0, 0.041, 0.66), (0.014, 0.041, 0.675)], 0.0015, 3), INK, "satin")
    for z, rx in ((0.33, 0.028), (0.74, 0.022)):
        p.add(sphere(1, 10, 4), lighter(wood, 0.25), "satin", T(0, 0.035, z) @ S(rx, 0.002, rx * 0.6))
    for i in range(12):
        a = 2 * math.pi * i / 12
        p.add(sphere(0.005, 5, 3), PEARL, "pearl", T(0.112 * math.cos(a), 0.036, 0.2 + 0.112 * math.sin(a)))


def wall_shelf_curios(p, size, c):
    rng = random.Random(3803)
    w = 1.0
    # scalloped back rail and two shelves on scrolling brackets
    rail = [(-w / 2, 0.0), (w / 2, 0.0)] + [(w / 2 - w * i / 12, 0.08 + 0.03 * abs(math.sin(math.pi * i / 2))) for i in range(13)]
    p.add(upright(rail, 0.015, 0.0), c, "pearl", T(0, 0, 0.42))
    p.add(upright([(-w / 2, 0.0), (w / 2, 0.0), (w / 2, 0.06), (-w / 2, 0.06)], 0.012, 0.0), c, "pearl", T(0, 0, 0.13))
    for z in (0.15, 0.42):
        p.add(box(w, 0.2, 0.022), c, "pearl", T(0, 0.1, z), smooth=False)
        p.add(tube([(-w / 2, 0.2, z), (w / 2, 0.2, z)], 0.006, 5), GOLD, "gold")
    for sx in (-1, 1):
        for zt, h in ((0.139, 0.139), (0.409, 0.25)):
            outline = [(0.0, zt), (0.17, zt), (0.15, zt - h * 0.15), (0.08, zt - h * 0.4), (0.04, zt - h * 0.75), (0.02, zt - h), (0.0, zt - h)]
            bm = slab([(y, z_) for y, z_ in outline], 0.016)
            p.add(bm, c, "pearl", T(sx * (w / 2 - 0.08), 0.0, 0.0) @ R("Z", 90))
    # lower shelf: standing painted plates, a little teapot, a posy vase
    for x, col in ((-0.3, PERI), (0.32, BLUSH)):
        m = T(x, 0.04, 0.161 + 0.09) @ R("X", -78)
        p.add(lathe([(0, 0), (0.07, 0.0), (0.09, 0.01), (0.092, 0.013), (0.0, 0.004)], 16), WHITE, "pearl", m)
        p.add(torus(0.075, 0.006, 16, 3), col, "pearl", m @ T(0, 0, 0.008))
        for k in range(4):
            p.add(floret(0.016), ROSE if (col == PERI) == (k % 2 == 0) else LILAC, "pearl",
                  m @ T(0.02 * math.cos(k * 1.6), 0.02 * math.sin(k * 1.6), 0.006))
        p.add(box(0.03, 0.02, 0.01, seg=1), GOLD, "gold", T(x, 0.13, 0.166))
    teapot(p, T(-0.05, 0.1, 0.161) @ R("Z", -20), 0.55, lighter(MINT, 0.2), "pearl", n=10)
    p.add(lathe([(0, 0), (0.025, 0), (0.035, 0.04), (0.03, 0.07), (0.018, 0.09), (0.024, 0.1)], 12), LILAC, "pearl", T(0.12, 0.1, 0.161))
    bouquet(p, "forget", (0.12, 0.1, 0.26), 0.03, 0.045, 4, [FORGET, WHITE, BUTTER], rng, 0.013, base_z=0.24)
    # upper shelf: a ginger jar, two cups, a porcelain songbird and a little hare
    p.add(lathe([(0, 0), (0.035, 0), (0.055, 0.04), (0.06, 0.08), (0.045, 0.11), (0.03, 0.12), (0.03, 0.13)], 10), PERI, "pearl", T(-0.32, 0.1, 0.431))
    p.add(lathe([(0, 0), (0.035, 0), (0.03, 0.02), (0.008, 0.03), (0.012, 0.04), (0, 0.045)], 10), PERI, "pearl", T(-0.32, 0.1, 0.561))
    for k in range(5):
        a = 2 * math.pi * k / 5
        p.add(floret(0.014), WHITE, "pearl", T(-0.32 + 0.058 * math.cos(a), 0.1 + 0.058 * math.sin(a), 0.5) @ aim((math.cos(a), math.sin(a), 0)))
    for x, col in ((-0.15, ROSE), (-0.08, BUTTER)):
        p.add(lathe([(0, 0), (0.04, 0), (0.042, 0.003), (0.0, 0.004)], 10), col, "pearl", T(x, 0.12, 0.431))
        p.add(lathe([(0, 0), (0.016, 0), (0.026, 0.02), (0.03, 0.04), (0.027, 0.04), (0.022, 0.02), (0, 0.008)], 8), WHITE, "pearl", T(x, 0.12, 0.435))
        p.add(torus(0.01, 0.003, 8, 3), WHITE, "pearl", T(x + 0.032, 0.12, 0.458) @ R("X", 90))
    songbird(p, T(0.08, 0.1, 0.431) @ R("Z", -30) @ S(1.6), PEARL)
    p.add(lathe([(0, 0), (0.04, 0), (0.042, 0.01), (0.0, 0.012)], 12), GOLD, "gold", T(0.29, 0.1, 0.431))
    p.add(lathe([(0.036, 0.01), (0.036, 0.07), (0.03, 0.09), (0.012, 0.105), (0, 0.11)], 10, False, False), GLASS, "glass", T(0.29, 0.1, 0.431))
    bloom(p, (0.29, 0.1, 0.46), 0.022, BLUSH, 2, 5, rng)
    candle(p, 0.42, 0.11, 0.431, 0.06, 0.016, CREAM, 1, rng=rng)
    p.add(lathe([(0, 0), (0.03, 0), (0.03, 0.006), (0.018, 0.008), (0.0, 0.008)], 12), GOLD, "gold", T(0.42, 0.11, 0.431))


def wall_mirror_oval(p, size, c):
    rng = random.Random(3804)
    w, h, z0 = 0.54, 0.76, 0.06
    ol = oval_outline(w, h, 28)
    p.add(upright(ol, 0.01, 0.0), (0.93, 0.9, 1.0), "mirror", T(0, 0, z0))
    p.add(tube([(x, 0.03, z + z0) for x, z in ol], 0.03, 6, closed=True), c, "gold")
    p.add(tube([(x * 0.93, 0.03, z0 + h / 2 + (z - h / 2) * 0.95) for x, z in ol], 0.008, 4, closed=True), PEARL, "pearl")
    for i in range(24):
        a = 2 * math.pi * i / 24
        if math.sin(a) > 0.85:
            continue
        x, z = (w / 2 + 0.035) * math.cos(a), z0 + h / 2 + (h / 2 + 0.035) * math.sin(a)
        p.add(leaf(0.05, 0.026), c if i % 2 else lighter(c, 0.15), "gold", T(x, 0.025, z) @ R("Y", -math.degrees(a)) @ R("X", 90) @ R("Z", 25))
    # the bow crest and its ribbon tails
    bz = z0 + h + 0.04
    for sx in (-1, 1):
        p.add(torus(0.05, 0.012, 12, 5), c, "gold", T(sx * 0.055, 0.03, bz) @ R("Y", sx * 25) @ S(1.1, 1, 0.65) @ R("X", 90))
        p.add(tube([(sx * 0.01, 0.03, bz - 0.01), (sx * 0.05, 0.035, bz - 0.07), (sx * 0.12, 0.035, bz - 0.12), (sx * 0.2, 0.035, bz - 0.2),
                    (sx * 0.24, 0.035, bz - 0.32)], [0.012, 0.011, 0.01, 0.009, 0.006], 5), c, "gold")
    p.add(sphere(0.022, 8, 5), c, "gold", T(0, 0.035, bz) @ S(1, 0.7, 1))
    # a little rose garland at the foot
    for i, x in enumerate((-0.08, -0.03, 0.03, 0.08)):
        bloom(p, (x, 0.045, z0 + 0.02 + 0.012 * (i % 2)), 0.024, ROSE if i % 2 else BLUSH, 2, 5, rng, tilt=R("X", -80))
    for sx in (-1, 1):
        p.add(leaf(0.06, 0.025), LEAF, "leaf", T(sx * 0.11, 0.04, z0 + 0.02) @ R("Z", 90 - sx * 90) @ R("X", -80))


def deer_outline():
    """Side view of a doe facing +X, body length ~1.15, standing on z=0."""
    return [(0.0, 0.66), (0.06, 0.74), (0.3, 0.76), (0.62, 0.74), (0.76, 0.8), (0.86, 1.02), (0.88, 1.14), (0.84, 1.28), (0.93, 1.17),
           (1.0, 1.15), (1.14, 1.04), (1.15, 0.99), (1.04, 0.97), (0.96, 0.88), (0.92, 0.7), (0.88, 0.56), (0.89, 0.0), (0.84, 0.0),
           (0.83, 0.48), (0.79, 0.0), (0.75, 0.0), (0.76, 0.5), (0.3, 0.5), (0.25, 0.0), (0.21, 0.0), (0.2, 0.44), (0.15, 0.0),
           (0.11, 0.0), (0.07, 0.5), (0.02, 0.6)]


def tapestry_deer(p, x, z, s, col, y, flip=False, stag=False, spots=False):
    sx = -1 if flip else 1
    ol = [(x + sx * (px - 0.55) * s, z + pz * s) for px, pz in deer_outline()]
    if flip:
        ol.reverse()
    p.add(upright(ol, 0.006, y), col, "fabric")
    p.add(upright([(x + sx * (px - 0.55) * s, z + pz * s) for px, pz in ([(0.35, 0.52), (0.7, 0.52), (0.7, 0.6), (0.35, 0.6)] if not flip else
                                                                         [(0.35, 0.6), (0.7, 0.6), (0.7, 0.52), (0.35, 0.52)])], 0.004, y + 0.004),
          lighter(col, 0.45), "fabric")
    p.add(sphere(0.012 * s / 0.4, 5, 3), INK, "fabric", T(x + sx * (1.02 - 0.55) * s, y + 0.008, z + 1.08 * s) @ S(1, 0.3, 1))
    if stag:
        for side in (-1, 1):
            bx, bz = x + sx * (0.9 - 0.55) * s, z + 1.2 * s
            pts = [(bx, y + 0.006, bz), (bx + sx * side * 0.05 * s - sx * 0.08 * s, y + 0.006, bz + 0.3 * s),
                   (bx - sx * 0.05 * s + side * 0.1 * s, y + 0.006, bz + 0.55 * s)]
            p.add(tube(pts, 0.012 * s / 0.4, 4), lighter(FAWN, 0.3), "fabric")
            for t in (0.4, 0.75):
                q = (bx + (pts[2][0] - bx) * t, y + 0.006, bz + 0.55 * s * t)
                p.add(tube([q, (q[0] + sx * 0.1 * s, y + 0.006, q[2] + 0.12 * s)], 0.009 * s / 0.4, 4), lighter(FAWN, 0.3), "fabric")
    if spots:
        sp = []
        for k in range(6):
            cx, cz = x + sx * ((0.3 + 0.07 * k) - 0.55) * s, z + (0.68 - 0.04 * (k % 2)) * s
            r = 0.015 * s / 0.3
            sp.append([(cx - r, y + 0.0065, cz - r), (cx + r, y + 0.0065, cz - r), (cx + r, y + 0.0065, cz + r), (cx - r, y + 0.0065, cz + r)])
        p.add(polys(sp), WHITE, "fabric")


def tapestry_tree(p, x, z, h, crown, rng, y):
    p.add(upright([(x - 0.04, z), (x + 0.04, z), (x + 0.025, z + h), (x - 0.025, z + h)], 0.005, y), BARK, "fabric")
    for k, (dx, dz, r) in enumerate(((0.0, 0.0, 1.0), (-0.12, -0.08, 0.7), (0.12, -0.06, 0.75), (0.0, 0.12, 0.7))):
        rr = 0.17 * r
        ol = [(x + dx + rr * math.cos(2 * math.pi * i / 12), z + h + dz + rr * 0.85 * math.sin(2 * math.pi * i / 12)) for i in range(12)]
        p.add(upright(ol, 0.005, y + 0.002 + 0.001 * k), crown[k % len(crown)], "fabric")


def tapestry_hunt(p, size, c):
    rng = random.Random(3805)
    W, H = 2.5, 1.82
    z0 = 0.1
    # rod with finials, hanging tabs, the cloth and its border
    p.add(cyl(0.02, 2.36, 10), GOLD, "gold", T(-1.18, 0.03, z0 + H + 0.06) @ R("Y", 90))
    for sx in (-1, 1):
        p.add(lathe([(0, 0), (0.026, 0.0), (0.03, 0.03), (0.016, 0.05), (0.024, 0.07), (0, 0.11)], 10), GOLD, "gold",
              T(sx * 1.18, 0.03, z0 + H + 0.06) @ R("Y", sx * 90))
    for k in range(9):
        x = -1.15 + 2.3 * k / 8
        p.add(box(0.07, 0.012, 0.11, seg=1), lighter(c, 0.1), "fabric", T(x, 0.03, z0 + H + 0.03))
    cloth = bmesh.new()
    nx = 10
    vs = []
    for i in range(nx + 1):
        xx = -W / 2 + W * i / nx
        yy = 0.012 * math.sin(i * math.pi / 2)
        vs.append((cloth.verts.new((xx, yy, z0)), cloth.verts.new((xx, yy, z0 + H))))
    for i in range(nx):
        cloth.faces.new((vs[i][0], vs[i + 1][0], vs[i + 1][1], vs[i][1]))
    p.add(cloth, c, "fabric", smooth=False)
    y = 0.016
    bw = 0.11
    border = [(-W / 2, z0, W / 2, z0 + bw), (-W / 2, z0 + H - bw, W / 2, z0 + H), (-W / 2, z0 + bw, -W / 2 + bw, z0 + H - bw),
              (W / 2 - bw, z0 + bw, W / 2, z0 + H - bw)]
    p.add(rects_xz(border, y), ROSE, "fabric")
    p.add(polys([[(xa, y + 0.001, za), (xb, y + 0.001, za), (xb, y + 0.001, zb), (xa, y + 0.001, zb)] for xa, za, xb, zb in
                 ((-W / 2 + bw, z0 + bw, W / 2 - bw, z0 + bw + 0.015), (-W / 2 + bw, z0 + H - bw - 0.015, W / 2 - bw, z0 + H - bw),
                  (-W / 2 + bw, z0 + bw, -W / 2 + bw + 0.015, z0 + H - bw), (W / 2 - bw - 0.015, z0 + bw, W / 2 - bw, z0 + H - bw))]), GOLD, "gold")
    fl = []
    for k in range(40):
        t = k / 40
        per = 2 * (W + H - 4 * bw)
        d = t * per
        if d < W - 2 * bw:
            cx, cz = -W / 2 + bw + d, z0 + bw / 2
        elif d < W - 2 * bw + H - 2 * bw:
            cx, cz = W / 2 - bw / 2, z0 + bw + (d - (W - 2 * bw))
        elif d < 2 * (W - 2 * bw) + H - 2 * bw:
            cx, cz = W / 2 - bw - (d - (W - 2 * bw) - (H - 2 * bw)), z0 + H - bw / 2
        else:
            cx, cz = -W / 2 + bw / 2, z0 + H - bw - (d - 2 * (W - 2 * bw) - (H - 2 * bw))
        r = 0.025
        fl.append([(cx, y + 0.002, cz - r), (cx + r, y + 0.002, cz), (cx, y + 0.002, cz + r), (cx - r, y + 0.002, cz)])
    p.add(polys(fl[0::2]), BUTTER, "fabric")
    p.add(polys(fl[1::2]), WHITE, "fabric")
    # the picture: a spring wood with a stream, blossom trees, and deer
    x0, x1 = -W / 2 + bw + 0.015, W / 2 - bw - 0.015
    za, zb = z0 + bw + 0.015, z0 + H - bw - 0.015
    p.add(rects_xz([(x0, za, x1, zb)], y + 0.001), lighter(SOFT_BLUE, 0.1), "fabric")
    p.add(polys([[(0.75 + 0.13 * math.cos(a), y + 0.0015, zb - 0.25 + 0.13 * math.sin(a)) for a in [2 * math.pi * i / 12 for i in range(12)]]]),
          BUTTER, "fabric")
    hills = [(x0, za + 0.55)] + [(x0 + (x1 - x0) * t, za + 0.62 + 0.18 * math.sin(t * 6.3 + 0.5) + 0.06 * math.sin(t * 17)) for t in [i / 14 for i in range(15)]] + [(x1, za + 0.55)]
    p.add(upright([(x1, za + 0.3), (x0, za + 0.3)] + hills, 0.003, y + 0.0015), lighter(LILAC, 0.2), "fabric")
    mid = [(x0 + (x1 - x0) * t, za + 0.48 + 0.1 * math.sin(t * 4.0 + 2.0)) for t in [i / 12 for i in range(13)]]
    p.add(upright([(x1, za), (x0, za)] + mid, 0.003, y + 0.002), (0.72, 0.9, 0.72), "fabric")
    stream = [(x0 + (x1 - x0) * t, za + 0.12 + 0.06 * math.sin(t * 7)) for t in [i / 12 for i in range(13)]]
    p.add(upright(stream + [(x, z_ + 0.07) for x, z_ in reversed(stream)], 0.003, y + 0.0025), lighter(PERI, 0.15), "fabric")
    trees = [(-0.85, 0.75, [SAGE, SAGE_LIGHT]), (-0.45, 0.9, [lighter(ROSE, 0.3), BLUSH, WHITE]), (0.5, 0.85, [SAGE_LIGHT, SAGE]),
             (0.88, 0.7, [BLUSH, lighter(ROSE, 0.3), WHITE]), (0.05, 0.95, [SAGE, MINT])]
    for x, h, crown in trees:
        tapestry_tree(p, x, za + 0.35, h * 0.55, crown, rng, y + 0.0035)
    tapestry_deer(p, -0.2, za + 0.22, 0.42, FAWN, y + 0.007, stag=True)
    tapestry_deer(p, 0.32, za + 0.2, 0.36, lighter(FAWN, 0.12), y + 0.007, flip=True)
    tapestry_deer(p, 0.62, za + 0.18, 0.24, lighter(FAWN, 0.2), y + 0.007, flip=True, spots=True)
    for col in (ROSE, BUTTER, WHITE, LILAC):
        dots = []
        for k in range(12):
            cx, cz = rng.uniform(x0 + 0.05, x1 - 0.05), za + rng.uniform(0.02, 0.4)
            r = rng.uniform(0.012, 0.02)
            dots.append([(cx, y + 0.011, cz - r), (cx + r, y + 0.011, cz), (cx, y + 0.011, cz + r), (cx - r, y + 0.011, cz)])
        p.add(polys(dots), col, "fabric")
    birds = []
    for k, (bx, bz) in enumerate(((-0.3, zb - 0.2), (-0.15, zb - 0.28), (0.2, zb - 0.18))):
        for s_ in (-1, 1):
            birds.append([(bx, y + 0.003, bz), (bx + s_ * 0.06, y + 0.003, bz + 0.03), (bx + s_ * 0.06, y + 0.003, bz + 0.015)])
    p.add(polys(birds), INK, "fabric")
    # fringe
    fr_a, fr_b = [], []
    for k in range(60):
        x = -W / 2 + 0.02 + (W - 0.04) * k / 59
        L = 0.08 + 0.01 * (k % 3)
        q = [(x - 0.008, 0.012, z0 + 0.005), (x + 0.008, 0.012, z0 + 0.005), (x + 0.006, 0.012, z0 - L), (x - 0.006, 0.012, z0 - L)]
        (fr_a if k % 2 else fr_b).append(q)
    p.add(polys(fr_a), GOLD, "gold")
    p.add(polys(fr_b), ROSE, "fabric")


BUILDERS = {
    "vase_hydrangea_blue": vase_hydrangea_blue,
    "vase_hydrangea_pink": vase_hydrangea_pink,
    "urn_hydrangea_white": urn_hydrangea_white,
    "vase_peonies": vase_peonies,
    "vase_tulips": vase_tulips,
    "vase_irises": vase_irises,
    "jug_daffodils": jug_daffodils,
    "vase_white_roses": vase_white_roses,
    "bowl_floating_blossoms": bowl_floating_blossoms,
    "vase_lilies": vase_lilies,
    "posy_teacup": posy_teacup,
    "mantel_clock_gilt": mantel_clock_gilt,
    "mantel_clock_porcelain": mantel_clock_porcelain,
    "candlestick_brass": candlestick_brass,
    "candlestick_crystal": candlestick_crystal,
    "candle_cluster": candle_cluster,
    "hurricane_lamp": hurricane_lamp,
    "book_open": book_open,
    "book_pile_ribbon": book_pile_ribbon,
    "books_childrens": books_childrens,
    "books_upright_bookends": books_upright_bookends,
    "letter_rack": letter_rack,
    "quill_and_parchment": quill_and_parchment,
    "hourglass": hourglass,
    "globe_table": globe_table,
    "decanter_set": decanter_set,
    "tea_service_silver": tea_service_silver,
    "fruit_bowl": fruit_bowl,
    "bonbon_dish": bonbon_dish,
    "figurine_deer": figurine_deer,
    "figurine_swan": figurine_swan,
    "trinket_box_enamel": trinket_box_enamel,
    "hand_mirror_brush": hand_mirror_brush,
    "fan_lace": fan_lace,
    "sewing_basket": sewing_basket,
    "chess_set": chess_set,
    "playing_cards": playing_cards,
    "fiddle_and_bow": fiddle_and_bow,
    "sheet_music": sheet_music,
    "shell_dish": shell_dish,
    "potpourri_bowl": potpourri_bowl,
    "terrarium_bell": terrarium_bell,
    "songbird_cage_small": songbird_cage_small,
    "magnifier_glass": magnifier_glass,
    "map_rolls": map_rolls,
    "astrolabe": astrolabe,
    "bread_board": bread_board,
    "pie_lattice": pie_lattice,
    "cheese_board": cheese_board,
    "egg_basket": egg_basket,
    "honey_jars": honey_jars,
    "jam_jars": jam_jars,
    "copper_kettle": copper_kettle,
    "mixing_bowls": mixing_bowls,
    "rolling_pin_flour": rolling_pin_flour,
    "knife_block": knife_block,
    "veg_chopping_board": veg_chopping_board,
    "garlic_braid_wall": garlic_braid_wall,
    "lemon_tarts_tray": lemon_tarts_tray,
    "chocolate_torte": chocolate_torte,
    "apples_bowl": apples_bowl,
    "salt_crock": salt_crock,
    "bandage_rolls": bandage_rolls,
    "basin_and_jug": basin_and_jug,
    "salve_jars": salve_jars,
    "brass_scales": brass_scales,
    "linen_stack": linen_stack,
    "herb_bell_jars": herb_bell_jars,
    "wall_clock_sunburst": wall_clock_sunburst,
    "barometer_wall": barometer_wall,
    "wall_shelf_curios": wall_shelf_curios,
    "wall_mirror_oval": wall_mirror_oval,
    "tapestry_hunt": tapestry_hunt,
}
