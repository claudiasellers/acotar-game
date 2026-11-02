"""Manor prop models for the L38 refurnish (part furnish). Same contract as parts A-D:
builder(p, size, color), front faces +Y, fitted to the catalogue size afterwards.

Princess-chateau furniture and architecture for the rooms that read as empty:
Rococo console and commode, settee, camelback sofa, bergere, the head-of-table
chair, secretary, armoire, library stacks and the two-tier mezzanine with its
spiral stair, kitchen and stillroom pieces. Modelled near real size in metres
(fit() only nudges the proportions). Budget <= 3,000 tris each.
"""

import math
import random

import bmesh
from mathutils import Matrix, Vector

from manor_props_a import cab_legs, candle, crest, gilt_edge
from manor_props_b import BOOKS
from prop_kit import lathe as _lathe
from prop_kit import (BARK, BLUSH, BUTTER, CANVAS, COPPER, CREAM, FAWN, GOLD, IRON, LEAF, LEAF_DARK, LILAC, MARBLE,
                      MINT, OAK, OAK_DARK, PEARL, PERI, ROSE, SAGE, SAGE_DEEP, SAGE_LIGHT, SOFT_BLUE, STRAW, WHITE,
                      R, S, T, arc_pts, arched_outline, bloom, box, cabriole, cushion, cyl, darker, disc, frame_ring,
                      ico, leaf, lighter, mix, oval_outline, scroll, slab, sphere, star_flower, torus, tube,
                      turned_leg)

MARBLE_PINK = mix(BLUSH, WHITE, 0.45)
MARBLE_WHITE = mix(MARBLE, WHITE, 0.55)
IVORY = mix(CREAM, WHITE, 0.45)
EMERALD = (0.27, 0.64, 0.50)
LEATHER_SAGE = mix(SAGE, CREAM, 0.4)
BIRCH = (0.93, 0.88, 0.84)
WICKER = mix(STRAW, OAK, 0.35)
SCRUBBED = mix(OAK, WHITE, 0.4)
PORCELAIN = (0.99, 0.98, 1.0)
DELFT = (0.45, 0.58, 0.95)
DOUGH = mix(BUTTER, WHITE, 0.62)
GOLD_PALE = mix(GOLD, WHITE, 0.15)
BOOKS2 = BOOKS + [mix(ROSE, PERI, 0.5), mix(MINT, PERI, 0.5), (0.96, 0.62, 0.58), (0.72, 0.58, 0.88),
                  (0.98, 0.84, 0.62), (0.55, 0.78, 0.82), (0.88, 0.45, 0.55), mix(SAGE_DEEP, MINT, 0.3)]


# ------------------------------------------------------------ geometry helpers


def lathe(profile, n=12, cap_bottom=True, cap_top=True):
    """prop_kit.lathe with consistent outward normals (its centre fans are wound against the quads)."""
    bm = _lathe(profile, n, cap_bottom, cap_top)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def _face(bm, cos, want):
    f = bm.faces.new([bm.verts.new(c) for c in cos])
    f.normal_update()
    if f.normal.dot(Vector(want)) < 0:
        f.normal_flip()
    return f


def put(p, part, color, finish="satin", matrix=None, **kw):
    """Prop.add that keeps faces outward when the matrix mirrors (S(-1, 1, 1) scrolls and brackets)."""
    if matrix is not None and matrix.determinant() < 0:
        part.transform(matrix)
        bmesh.ops.reverse_faces(part, faces=part.faces[:])
        matrix = None
    return p.add(part, color, finish, matrix, **kw)


def scroll_lite(r, turns=1.4, n=9, thick=0.01, sides=4):
    """Cheaper flat volute (XZ plane) than prop_kit.scroll, for the many small gilt curls."""
    pts = []
    for i in range(n + 1):
        t = i / n
        a = t * turns * 2 * math.pi
        rr = r * (1 - 0.75 * t)
        pts.append((rr * math.cos(a), 0.0, rr * math.sin(a)))
    return tube(pts, [thick * (1.0 - 0.5 * i / n) for i in range(n + 1)], sides)


def crest_lite(p, x, y, z, s=0.15, col=GOLD, m=None):
    """Gilt shell between two curls, facing +Y (about 180 tris against crest()'s 280); m: optional frame."""
    m = m if m is not None else Matrix.Identity(4)
    for sx in (-1, 1):
        put(p, scroll_lite(s * 0.5, 1.2, 8, s * 0.07), col, "gold", m @ T(x + sx * s * 0.45, y, z) @ S(sx, 1, 1) @ R("Y", 180))
    put(p, lathe([(0, 0), (s * 0.35, s * 0.1), (s * 0.3, s * 0.3), (0, s * 0.45)], 8), col, "gold", m @ T(x, y, z) @ S(1, 0.35, 1))
    for a in (-35, 35):
        put(p, leaf(s * 0.4, s * 0.2), col, "gold", m @ T(x, y + s * 0.03, z + s * 0.3) @ R("Y", -(90 + a)) @ R("X", -90))


def flat_flower(p, m, r, col, heart=BUTTER, n=5, finish="satin"):
    """A painted/embroidered flat flower in the local XY plane of m, facing local +Z (about 15 tris)."""
    bm = bmesh.new()
    k = n * 3
    vs = []
    for i in range(k):
        a = 2 * math.pi * i / k
        rr = r * (0.45 + 0.55 * abs(math.cos(n * a / 2)))
        vs.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), 0.0)))
    f = bm.faces.new(vs)
    f.normal_update()
    if f.normal.z < 0:
        f.normal_flip()
    put(p, bm, col, finish, m, smooth=False)
    put(p, disc(r * 0.3, 5, r * 0.06), heart, finish, m, smooth=False)


def rose(p, center, radius, color, rng, tilt=None, finish="fabric", rings=2, per=4):
    """bloom() with fewer petals and a cheap heart (about 55 tris)."""
    c = Vector(center)
    base = T(*c) @ (tilt if tilt is not None else Matrix.Identity(4))
    from prop_kit import petal
    for ring in range(rings):
        t = ring / max(rings - 1, 1)
        L = radius * (0.5 + 0.5 * t)
        col = lighter(color, 0.18 * (1 - t)) if ring < rings - 1 else color
        for i in range(per + ring):
            a = 360.0 * i / (per + ring) + ring * 31 + rng.uniform(-8, 8)
            put(p, petal(L, L * 0.95, cup=0.35, curl=0.1 + 0.1 * t), col, finish, base @ R("Z", a) @ R("Y", -(60 - 45 * t)))
    put(p, ico(radius * 0.25, 0), lighter(color, 0.3), finish, base @ T(0, 0, radius * 0.12), smooth=False)


def knob_lite(p, x, y, z, r=0.02, col=GOLD):
    put(p, ico(r, 0), col, "gold", T(x, y, z), smooth=False)


def plan_slab(pts, z0, h, bevel=0.0):
    """Extrudes a plan outline [(x, y)] from z0 up by h (a table top, a shelf, a tread)."""
    bm = bmesh.new()
    f = bm.faces.new([bm.verts.new((x, y, z0)) for x, y in pts])
    f.normal_update()
    if f.normal.z > 0:
        f.normal_flip()
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    nv = [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, 0, h), verts=nv)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES", profile=0.5,
                        clamp_overlap=True)
    return bm


def band(pts, z0, z1, t):
    """A vertical strip of thickness t following a plan polyline [(x, y)]; z0/z1 may be per-point lists
    (scalloped aprons, serpentine drawer fronts). Its outer face is to the left of the walking direction."""
    n = len(pts)
    z0 = z0 if isinstance(z0, (list, tuple)) else [z0] * n
    z1 = z1 if isinstance(z1, (list, tuple)) else [z1] * n
    bm = bmesh.new()
    rows = []
    nrm = []
    for i in range(n):
        a = Vector(pts[max(i - 1, 0)])
        b = Vector(pts[min(i + 1, n - 1)])
        tg = (b - a).normalized()
        nv = Vector((-tg.y, tg.x))
        nrm.append(nv)
        o = Vector(pts[i]) + nv * t / 2
        q = Vector(pts[i]) - nv * t / 2
        rows.append([bm.verts.new((o.x, o.y, z0[i])), bm.verts.new((o.x, o.y, z1[i])),
                     bm.verts.new((q.x, q.y, z1[i])), bm.verts.new((q.x, q.y, z0[i]))])
    for i in range(n - 1):
        a, b = rows[i], rows[i + 1]
        nn = (nrm[i] + nrm[i + 1]).normalized()
        for (k, l), want in (((0, 1), (nn.x, nn.y, 0)), ((1, 2), (0, 0, 1)), ((2, 3), (-nn.x, -nn.y, 0)),
                             ((3, 0), (0, 0, -1))):
            f = bm.faces.new((a[k], b[k], b[l], a[l]))
            f.normal_update()
            if f.normal.dot(Vector(want)) < 0:
                f.normal_flip()
    for r_, sgn in ((rows[0], -1), (rows[-1], 1)):
        f = bm.faces.new(r_)
        f.normal_update()
        i = 0 if sgn < 0 else n - 1
        tg = Vector(pts[min(i + 1, n - 1)]) - Vector(pts[max(i - 1, 0)])
        if f.normal.dot(Vector((tg.x, tg.y, 0)) * sgn) < 0:
            f.normal_flip()
    return bm


def bend(bm, k):
    """Curves a part in plan: y += k x^2 (positive k swings the ends forward, a tub back)."""
    for v in bm.verts:
        v.co.y += k * v.co.x * v.co.x
    return bm


def orient(xdir, zhint=(0, 0, 1)):
    """Rotation whose local X points along xdir with local Z as close to zhint as possible."""
    x = Vector(xdir).normalized()
    y = Vector(zhint).cross(x)
    if y.length < 1e-6:
        y = Vector((0, 1, 0)).cross(x)
    y.normalize()
    z = x.cross(y)
    return Matrix(((x.x, y.x, z.x, 0), (x.y, y.y, z.y, 0), (x.z, y.z, z.z, 0), (0, 0, 0, 1)))


def serp_y(x, w, d, amp):
    """Serpentine front line: proud at the centre, hollow either side, half-proud at the corners."""
    return d / 2 + amp * (math.cos(3 * math.pi * x / w) - 1) / 2


def serp_plan(w, d, amp, n=20):
    pts = [(-w / 2 + w * i / n, serp_y(-w / 2 + w * i / n, w, d, amp)) for i in range(n + 1)]
    return pts + [(w / 2, -d / 2), (-w / 2, -d / 2)]


def shaped_back(w, z_end, z_mid, n=14, peak=1.8):
    """Louis XV / camel back outline in XZ (base z=0): low shoulders rising to a rounded crest."""
    pts = [(-w / 2, 0.0), (w / 2, 0.0)]
    for i in range(n + 1):
        x = w / 2 - w * i / n
        t = abs(2 * x / w)
        z = z_end + (z_mid - z_end) * (1 - t ** peak)
        if t > 0.99:
            z = z_end * 0.9
        pts.append((x, z))
    return pts


def pull(p, x, y, z, r=0.016, col=GOLD):
    """A small turned knob facing +Y (cheap)."""
    put(p, lathe([(r * 0.5, 0), (r * 0.6, r * 0.5), (r, r * 1.2), (r * 0.6, r * 1.9), (0, r * 2.0)], 6),
          col, "gold", T(x, y, z) @ R("X", -90))


def bail(p, x, y, z, s=0.04, col=GOLD):
    """Gilt bail handle with a rosette backplate, facing +Y."""
    put(p, lathe([(0, 0), (s * 0.45, 0), (s * 0.3, s * 0.2), (0, s * 0.25)], 6), col, "gold", T(x, y, z + s * 0.2) @ R("X", -90))
    put(p, tube(arc_pts(x, z + s * 0.2, s * 0.9, s * 0.8, 200, 340, 5, y + s * 0.18), s * 0.09, 4), col, "gold")


def drawer(p, x, y, z, w, h, col, knobs=1, trim=GOLD, finish="satin"):
    """One drawer front centred at (x, z), face at y, with 1 or 2 knobs."""
    put(p, box(w, 0.022, h, bevel=0.008, seg=1), col, finish, T(x, y + 0.011, z))
    if knobs == 1:
        pull(p, x, y + 0.02, z, 0.015, trim)
    else:
        for sx in (-1, 1):
            pull(p, x + sx * w * 0.28, y + 0.02, z, 0.015, trim)


def bun(p, x, y, r=0.05, col=GOLD, finish="gold"):
    put(p, sphere(r, 6, 4), col, finish, T(x, y, r * 0.7) @ S(1, 1, 0.75))


def book_run(p, x0, x1, yf, z, depth, hmin, hmax, rng, wmin=0.035, wmax=0.075, m=None, cols=BOOKS2, gild=0.3,
             lean=True, set_p=0.35, label=0.2):
    """A row of book spines facing +Y at y=yf on a shelf at z (front, top and step faces only, so a
    whole library of them stays cheap). m: optional matrix for the whole row."""
    mm = m if m is not None else Matrix.Identity(4)
    books = []
    x = x0
    last = None
    xend = x1 - (0.02 + wmax + 0.36 * hmax if lean else 0.0)
    while x < xend - wmin * 0.8:
        if books and rng.random() < set_p:
            # the next volume of a matching set: same height, cloth and binding
            t, hh, col = min(books[-1][1], xend - x), books[-1][2], books[-1][3]
        else:
            t = min(rng.uniform(wmin, wmax), xend - x)
            hh = min(rng.uniform(hmin, hmax) * (1.12 if t > (wmin + wmax) * 0.62 else 1.0), hmax * 1.05)
            col = rng.choice(cols)
            while col == last:
                col = rng.choice(cols)
        last = col
        books.append((x, t, hh, col))
        x += t + 0.002
    if lean and books:
        # the end book leans on its neighbour, showing a wedge of shelf
        t = rng.uniform(wmin, wmax)
        hh = rng.uniform(hmin, hmax) * 0.95
        put(p, box(t, depth * 0.95, hh), rng.choice(cols), "satin",
            mm @ T(x1 - 0.01, yf - depth * 0.5, z) @ R("Y", -22) @ T(-t / 2, 0, hh / 2), smooth=False)
    tone, gilt_prev = 0.0, False
    for i, (bx, t, hh, col) in enumerate(books):
        bm = bmesh.new()
        yb = yf - depth
        X0, X1 = bx, bx + t
        Z1 = z + hh
        _face(bm, [(X0, yf, z), (X1, yf, z), (X1, yf, Z1), (X0, yf, Z1)], (0, 1, 0))
        _face(bm, [(X0, yf, Z1), (X1, yf, Z1), (X1, yb, Z1), (X0, yb, Z1)], (0, 0, 1))
        ph = books[i - 1][2] if i > 0 else 0.0
        nh = books[i + 1][2] if i < len(books) - 1 else 0.0
        if hh > ph + 0.008:
            _face(bm, [(X0, yf, z + ph), (X0, yb, z + ph), (X0, yb, Z1), (X0, yf, Z1)], (-1, 0, 0))
        if hh > nh + 0.008:
            _face(bm, [(X1, yf, z + nh), (X1, yb, z + nh), (X1, yb, Z1), (X1, yf, Z1)], (1, 0, 0))
        same = i > 0 and books[i - 1][3] == col and books[i - 1][2] == hh
        tone = (tone + (0.04 if i % 2 else -0.04)) if same else rng.uniform(-0.12, 0.12)
        cc = lighter(col, tone) if tone > 0 else darker(col, -tone)
        put(p, bm, cc, "satin", mm, smooth=False)
        if (same and gilt_prev) or (not same and rng.random() < gild):
            gilt_prev = True
            b2 = bmesh.new()
            for zz in ((0.8, 0.85), (0.14, 0.18)) if (int(hh * 1000) % 2) else ((0.78, 0.86),):
                _face(b2, [(X0 + 0.003, yf + 0.003, z + hh * zz[0]), (X1 - 0.003, yf + 0.003, z + hh * zz[0]),
                           (X1 - 0.003, yf + 0.003, z + hh * zz[1]), (X0 + 0.003, yf + 0.003, z + hh * zz[1])], (0, 1, 0))
            put(p, b2, GOLD, "gold", mm, smooth=False)
            continue
        gilt_prev = False
        if rng.random() < label:
            b2 = bmesh.new()
            _face(b2, [(X0 + 0.006, yf + 0.003, z + hh * 0.55), (X1 - 0.006, yf + 0.003, z + hh * 0.55),
                       (X1 - 0.006, yf + 0.003, z + hh * 0.7), (X0 + 0.006, yf + 0.003, z + hh * 0.7)], (0, 1, 0))
            put(p, b2, CANVAS, "matte", mm, smooth=False)


def acanthus(p, x, y, z, s, yaw=0.0, col=GOLD):
    """A small gilt acanthus leaf hanging down a knee or corner, facing outward along yaw."""
    put(p, leaf(s, s * 0.55), col, "gold", T(x, y, z) @ R("Z", yaw) @ R("Y", 70))


def leaf_fan(p, cx, y, cz, n, length, a0, a1, col=GOLD, finish="gold"):
    """Leaves radiating in the XZ plane (facing +Y) between angles a0..a1 (deg, 0 = +X, 90 = up)."""
    for i in range(n):
        a = a0 + (a1 - a0) * i / max(n - 1, 1)
        put(p, leaf(length, length * 0.5), col, finish, T(cx, y, cz) @ R("Y", -a) @ R("X", -90))


def fringe(p, r, z0, z1, col=GOLD, n=40, sy=1.0):
    """Bullion fringe skirt: a ring band whose lower edge zigzags."""
    bm = bmesh.new()
    top = [bm.verts.new((r * math.cos(2 * math.pi * i / n), sy * r * math.sin(2 * math.pi * i / n), z1)) for i in range(n)]
    bot = []
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = r * 1.015
        bot.append(bm.verts.new((rr * math.cos(a), sy * rr * math.sin(a), z0 if i % 2 == 0 else z0 + (z1 - z0) * 0.35)))
    for i in range(n):
        j = (i + 1) % n
        f = bm.faces.new((top[i], top[j], bot[j], bot[i]))
        f.normal_update()
        mid = (top[i].co + top[j].co) / 2
        if f.normal.dot(Vector((mid.x, mid.y, 0))) < 0:
            f.normal_flip()
    put(p, bm, col, "gold", smooth=False)
    put(p, torus(r * 1.01, (z1 - z0) * 0.18, n // 2, 4), col, "gold", T(0, 0, z1) @ S(1, sy, 1))


def nailheads(p, pts, r=0.008, col=GOLD):
    for x, y, z in pts:
        put(p, ico(r, 0), col, "gold", T(x, y, z), smooth=False)


# ------------------------------------------------------------ tables & consoles


def console_gilt(p, size, c):
    w, h, d = 1.5, 0.86, 0.45
    top = serp_plan(w, d, 0.05, 24)
    put(p, plan_slab(top, h - 0.04, 0.04, 0.01), MARBLE_PINK, "pearl")
    put(p, tube([(x, y + 0.004, h - 0.042) for x, y in top], 0.011, 5, closed=True), GOLD, "gold", smooth=False)
    # serpentine carved apron with a scalloped lower edge and a shell cartouche
    aw = w - 0.12
    xs = [-aw / 2 + aw * i / 22 for i in range(23)]
    front = [(x, serp_y(x, aw, d - 0.07, 0.045)) for x in xs]
    zlo = [h - 0.15 - 0.075 * math.exp(-(x / 0.16) ** 2) + 0.025 * abs(math.sin(3 * math.pi * x / aw)) for x in xs]
    put(p, band(front, zlo, h - 0.045, 0.03), c, "gold")
    put(p, tube([(x, y + 0.016, z + 0.012) for (x, y), z in zip(front, zlo)], 0.008, 4), lighter(c, 0.2), "gold")
    for sx in (-1, 1):
        side = [(sx * aw / 2, -d / 2 + 0.05 + (d - 0.13) * i / 4) for i in range(5)]
        if sx < 0:
            side = side[::-1]
        put(p, band(side, h - 0.14, h - 0.045, 0.03), c, "gold")
    put(p, box(aw, 0.03, 0.08), darker(c, 0.1), "gold", T(0, -d / 2 + 0.05, h - 0.085))
    crest(p, 0, d / 2 - 0.02, h - 0.225, 0.2, c)
    for sx in (-1, 1):
        put(p, scroll(0.045, 1.3, 10, 0.008), lighter(c, 0.1), "gold", T(sx * 0.32, d / 2 - 0.035, h - 0.11) @ S(sx, 1, 1))
    # cabriole legs with acanthus knees and scrolled toes
    cab_legs(p, w - 0.06, d - 0.05, h - 0.05, 0.03, c, "gold", inset=0.06)
    for sx, sy, a in ((1, 1, 45), (-1, 1, 135)):
        x, y = sx * (w / 2 - 0.06), sy * (d / 2 - 0.06)
        acanthus(p, x + sx * 0.03, y + 0.04, h - 0.1, 0.11, a + 20 * sx)
        put(p, scroll(0.03, 1.2, 8, 0.008), c, "gold", T(x + sx * 0.012, y + 0.02, 0.035) @ R("Z", a - 90))
    # X-stretcher with a gilt urn where the arms meet
    for sx, sy in ((1, 1), (-1, 1), (-1, -1), (1, -1)):
        x, y = sx * (w / 2 - 0.08), sy * (d / 2 - 0.08)
        put(p, tube([(x, y, 0.12), (x * 0.55, y * 0.6, 0.15), (x * 0.15, y * 0.2, 0.2), (0, 0, 0.21)], [0.014, 0.012, 0.012, 0.016], 5), c, "gold")
    put(p, lathe([(0, 0.19), (0.05, 0.2), (0.06, 0.25), (0.03, 0.29), (0.045, 0.32), (0, 0.36)], 10), c, "gold")
    put(p, sphere(0.03, 8, 5), ROSE, "pearl", T(0, 0, 0.38))


def hall_table_round(p, size, c):
    r, h = 0.55, 0.8
    put(p, lathe([(0, h - 0.045), (r - 0.012, h - 0.045), (r, h - 0.032), (r, h - 0.012), (r - 0.012, h), (0, h)], 28),
          MARBLE_WHITE, "pearl")
    put(p, torus(r - 0.005, 0.011, 28, 4), GOLD, "gold", T(0, 0, h - 0.046))
    # pearl apron with gilt bead and four pendant shells
    put(p, lathe([(0.47, h - 0.13), (0.49, h - 0.12), (0.49, h - 0.055), (0.47, h - 0.047)], 24, False, False), c, "pearl")
    put(p, torus(0.488, 0.009, 24, 4), GOLD, "gold", T(0, 0, h - 0.125))
    for i in range(4):
        a = 90 * i + 45
        m = R("Z", a - 90) @ T(0, 0.49, h - 0.15)
        put(p, lathe([(0, 0), (0.05, 0.015), (0.045, 0.045), (0, 0.065)], 8), GOLD, "gold", m @ S(1, 0.35, 1))
    # turned urn pedestal
    put(p, lathe([(0.09, 0.16), (0.11, 0.2), (0.07, 0.26), (0.06, 0.32), (0.1, 0.42), (0.12, 0.48), (0.08, 0.56),
                 (0.06, 0.6), (0.07, h - 0.16), (0.12, h - 0.13)], 14), c, "pearl")
    for z, rr in ((0.205, 0.105), (0.48, 0.118), (h - 0.17, 0.075)):
        put(p, torus(rr, 0.012, 14, 4), GOLD, "gold", T(0, 0, z))
    leaf_ring = 6
    for i in range(leaf_ring):
        a = 360 * i / leaf_ring
        put(p, leaf(0.1, 0.05), GOLD, "gold", R("Z", a) @ T(0.1, 0, 0.44) @ R("Y", 75))
    # tripod base: concave triangular plinth and three scrolled feet
    tri = []
    for i in range(3):
        a0 = math.radians(90 + 120 * i)
        for k in range(5):
            a = a0 + math.radians(120) * k / 5
            rr = 0.2 - 0.07 * math.sin(math.pi * k / 5)
            tri.append((rr * math.cos(a), rr * math.sin(a)))
    put(p, plan_slab(tri, 0.1, 0.07, 0.01), c, "pearl")
    for i in range(3):
        a = 90 + 120 * i + 60
        m = R("Z", a)
        put(p, tube([(0.12, 0, 0.16), (0.24, 0, 0.13), (0.35, 0, 0.06), (0.43, 0, 0.035)], [0.05, 0.045, 0.035, 0.03], 6), c, "pearl", m)
        put(p, scroll(0.045, 1.3, 10, 0.012), GOLD, "gold", m @ T(0.45, 0, 0.055) @ R("Z", 0))
        put(p, leaf(0.16, 0.06), GOLD, "gold", m @ T(0.14, 0, 0.17) @ R("Y", 18))


def library_table(p, size, c):
    w, h, d = 2.6, 0.8, 1.2
    put(p, box(w, d, 0.06, bevel=0.025), c, "satin", T(0, 0, h - 0.03))
    put(p, box(w - 0.04, d - 0.04, 0.025, bevel=0.01), darker(c, 0.08), "satin", T(0, 0, h - 0.07))
    put(p, box(w - 0.26, d - 0.26, 0.006, seg=1), LEATHER_SAGE, "matte", T(0, 0, h + 0.001), smooth=False)
    gilt_edge(p, w - 0.27, d - 0.27, h + 0.004, 0.004)
    gilt_edge(p, w - 0.33, d - 0.33, h + 0.004, 0.003)
    # frieze with drawers both sides
    put(p, box(w - 0.18, d - 0.18, 0.12, bevel=0.015), c, "satin", T(0, 0, h - 0.14))
    for sy in (-1, 1):
        for x in (-0.75, 0.0, 0.75):
            yy = sy * (d - 0.18) / 2
            put(p, box(0.6, 0.02, 0.085, bevel=0.006, seg=1), lighter(c, 0.06), "satin", T(x, yy + sy * 0.008, h - 0.14))
            put(p, sphere(0.016, 6, 4), GOLD, "gold", T(x, yy + sy * 0.025, h - 0.14))
    # six stout turned legs with gilt collars, H-stretcher and ball feet
    for x in (-(w / 2 - 0.16), 0.0, w / 2 - 0.16):
        for sy in (-1, 1):
            y = sy * (d / 2 - 0.16)
            put(p, turned_leg(h - 0.2, 0.06, 10), c, "satin", T(x, y, 0.06))
            put(p, torus(0.058, 0.01, 10, 4), GOLD, "gold", T(x, y, 0.06 + (h - 0.2) * 0.55))
            put(p, sphere(0.045, 8, 5), darker(c, 0.1), "satin", T(x, y, 0.04))
    for x in (-(w / 2 - 0.16), 0.0, w / 2 - 0.16):
        put(p, box(0.05, d - 0.32, 0.05, bevel=0.012), c, "satin", T(x, 0, 0.14))
    put(p, box(w - 0.32, 0.05, 0.05, bevel=0.012), c, "satin", T(0, 0, 0.14))


def writing_desk_small(p, size, c):
    w, h, d = 1.05, 0.78, 0.55
    tz = 0.735
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.07), sy * (d / 2 - 0.06)
            put(p, turned_leg(0.6, 0.026, 8, "taper"), c, "pearl", T(x, y, 0.0))
            put(p, cyl(0.017, 0.035, 8), GOLD, "gold", T(x, y, 0.0))
            put(p, torus(0.028, 0.006, 8, 4), GOLD, "gold", T(x, y, 0.53))
    put(p, box(w - 0.06, d - 0.06, 0.11, bevel=0.012), c, "pearl", T(0, 0, 0.665))
    put(p, box(w, d, 0.03, bevel=0.012), lighter(c, 0.05), "pearl", T(0, 0, tz + 0.015))
    put(p, box(w - 0.14, d - 0.16, 0.004, seg=1), BLUSH, "matte", T(0, 0.02, tz + 0.031), smooth=False)
    gilt_edge(p, w - 0.15, d - 0.17, tz + 0.033, 0.003)
    gilt_edge(p, w, d, tz, 0.007)
    drawer(p, 0, (d - 0.06) / 2, 0.665, 0.46, 0.075, lighter(c, 0.08), 1, finish="pearl")
    for sx in (-1, 1):
        put(p, scroll(0.04, 1.3, 10, 0.006), GOLD, "gold", T(sx * 0.36, d / 2 - 0.02, 0.665) @ S(sx, 1, 1))
    # low pierced gallery rail round the back and sides
    gz = tz + 0.03
    rail = [(-w / 2 + 0.02, d / 2 - 0.14, gz + 0.045), (-w / 2 + 0.02, -d / 2 + 0.02, gz + 0.045),
            (w / 2 - 0.02, -d / 2 + 0.02, gz + 0.045), (w / 2 - 0.02, d / 2 - 0.14, gz + 0.045)]
    put(p, tube(rail, 0.006, 5), GOLD, "gold", smooth=False)
    for i in range(12):
        x = -w / 2 + 0.02 + (w - 0.04) * i / 11
        put(p, cyl(0.004, 0.045, 4, caps=False), GOLD, "gold", T(x, -d / 2 + 0.02, gz))
    for sx in (-1, 1):
        for k in range(1, 5):
            y = -d / 2 + 0.02 + (d - 0.16) * k / 4
            put(p, cyl(0.004, 0.045, 4, caps=False), GOLD, "gold", T(sx * (w / 2 - 0.02), y, gz))
        put(p, sphere(0.011, 6, 4), GOLD, "gold", T(sx * (w / 2 - 0.02), -d / 2 + 0.02, gz + 0.055))


def kitchen_island(p, size, c):
    w, h, d = 3.0, 0.92, 1.4
    put(p, box(w, d, 0.1, bevel=0.03), SCRUBBED, "matte", T(0, 0, h - 0.05))
    for y in (-0.35, 0.0, 0.35):
        put(p, box(w - 0.04, 0.008, 0.004, seg=1), mix(SCRUBBED, OAK, 0.5), "matte", T(0, y, h + 0.001), smooth=False)
    put(p, box(w - 0.2, d - 0.2, 0.14, bevel=0.015), c, "satin", T(0, 0, h - 0.17))
    for sy in (-1, 1):
        for x in (-0.9, 0.0, 0.9):
            yy = sy * (d - 0.2) / 2
            put(p, box(0.75, 0.02, 0.1, seg=1), lighter(c, 0.08), "satin", T(x, yy + sy * 0.008, h - 0.17), smooth=False)
            knob_lite(p, x, yy + sy * 0.03, h - 0.17, 0.024, COPPER)
    legs = [(x, sy * (d / 2 - 0.16)) for x in (-(w / 2 - 0.16), 0.0, w / 2 - 0.16) for sy in (-1, 1)]
    for x, y in legs:
        put(p, lathe([(0.05, 0), (0.07, 0.04), (0.055, 0.1), (0.065, 0.3), (0.085, 0.42), (0.06, 0.52), (0.08, 0.6),
                      (0.075, h - 0.24)], 6), c, "satin", T(x, y, 0.0))
    # slatted pot shelf
    for k in range(6):
        y = -(d - 0.36) / 2 + (d - 0.36) * k / 5
        put(p, box(w - 0.3, 0.16, 0.03, seg=1), lighter(c, 0.05), "satin", T(0, y, 0.2), smooth=False)
    for x, _ in legs[::2]:
        put(p, box(0.06, d - 0.3, 0.06, seg=1), c, "satin", T(x, 0, 0.17), smooth=False)
    rng = random.Random(901)
    # stoneware crocks
    for x, y, r, hh, col, band_ in ((-1.15, 0.2, 0.13, 0.3, CREAM, DELFT), (-0.85, -0.2, 0.1, 0.24, BUTTER, ROSE),
                                    (0.5, 0.25, 0.12, 0.28, PORCELAIN, ROSE),
                                    (1.15, 0.22, 0.11, 0.26, mix(PERI, WHITE, 0.4), WHITE)):
        put(p, lathe([(0, 0), (r * 0.8, 0), (r, hh * 0.3), (r * 0.95, hh * 0.8), (r * 0.75, hh * 0.92), (r * 0.8, hh),
                     (r * 0.6, hh)], 9), col, "pearl", T(x, y, 0.215))
        put(p, lathe([(r * 1.0, hh * 0.45), (r * 1.01, hh * 0.6)], 10, False, False), band_, "pearl", T(x, y, 0.215))
        put(p, disc(r * 0.62, 10, hh - 0.01), darker(col, 0.2), "matte", T(x, y, 0.215))
    # wicker baskets of apples and onions, and a copper stockpot
    for x, y, fruit in ((-0.25, 0.15, ROSE), (0.15, -0.25, mix(LILAC, BLUSH, 0.4))):
        put(p, lathe([(0, 0), (0.17, 0), (0.2, 0.14), (0.21, 0.16)], 12, True, False), WICKER, "matte", T(x, y, 0.215))
        put(p, torus(0.195, 0.012, 12, 3), darker(WICKER, 0.12), "matte", T(x, y, 0.29))
        put(p, torus(0.21, 0.016, 12, 4), darker(WICKER, 0.18), "matte", T(x, y, 0.375))
        put(p, tube(arc_pts(x, 0.375, 0.2, 0.18, 0, 180, 6, y), 0.012, 4), darker(WICKER, 0.18), "matte")
        for k in range(5):
            a = 2 * math.pi * k / 5 + rng.uniform(-0.2, 0.2)
            put(p, sphere(0.06, 6, 4), fruit if k % 3 else lighter(fruit, 0.25), "satin",
                T(x + 0.1 * math.cos(a), y + 0.1 * math.sin(a), 0.38 + rng.uniform(-0.01, 0.02)))
        put(p, sphere(0.06, 6, 4), fruit, "satin", T(x, y, 0.43))
    put(p, lathe([(0, 0), (0.15, 0), (0.16, 0.22), (0.17, 0.23), (0.15, 0.23)], 12), COPPER, "gold", T(-0.45, -0.25, 0.215))
    put(p, lathe([(0, 0), (0.16, 0), (0.1, 0.03), (0.02, 0.04), (0.03, 0.07), (0, 0.08)], 12), COPPER, "gold", T(-0.45, -0.25, 0.445))


def dough_trough(p, size, c):
    w, h, d = 1.6, 0.85, 0.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.16), sy * (d / 2 - 0.12)
            put(p, turned_leg(0.45, 0.04, 8), c, "satin", T(x, y, 0) @ R("Y", -sx * 4) @ R("X", sy * 4))
    for sy in (-1, 1):
        put(p, box(w - 0.36, 0.04, 0.05, bevel=0.01), c, "satin", T(0, sy * (d / 2 - 0.12), 0.14))
    zb, zt = 0.45, 0.78
    # flared trough: tapering ends and tilted long boards
    end = [(-0.2, zb), (0.2, zb), (d / 2, zt), (-d / 2, zt)]
    for sx in (-1, 1):
        put(p, slab(end, 0.04, 0.008), lighter(c, 0.05), "satin", T(sx * (w / 2 - 0.04), 0, 0) @ R("Z", 90))
        put(p, box(0.03, 0.14, 0.04, bevel=0.01), darker(c, 0.1), "satin", T(sx * (w / 2 + 0.0), 0, zt - 0.06))
    for sy in (-1, 1):
        put(p, box(w - 0.1, 0.035, 0.36, bevel=0.01), c, "satin", T(0, sy * 0.25, (zb + zt) / 2) @ R("X", sy * -14))
    put(p, box(w - 0.12, 0.42, 0.04, bevel=0.01), darker(c, 0.05), "satin", T(0, 0, zb + 0.02))
    put(p, cushion(w - 0.3, 0.46, 0.14, 0.6), DOUGH, "satin", T(-0.06, 0, zt - 0.08))
    put(p, sphere(0.1, 10, 6), lighter(DOUGH, 0.2), "satin", T(-0.45, 0.05, zt - 0.02) @ S(1.3, 1, 0.55))
    # lid slid half off and resting askew, dusted with flour
    lid = T(0.3, 0.03, zt + 0.02) @ R("Z", 5) @ R("Y", -2)
    put(p, box(w * 0.9, d + 0.02, 0.035, bevel=0.01), lighter(c, 0.1), "satin", lid)
    for x in (-0.45, 0.45):
        put(p, box(0.05, d - 0.05, 0.035, bevel=0.01), c, "satin", lid @ T(x, 0, 0.03))
    put(p, tube([(-0.1, 0, 0.06), (-0.1, 0, 0.09), (0.1, 0, 0.09), (0.1, 0, 0.06)], 0.012, 5), c, "satin", lid)
    for x, y in ((0.15, 0.12), (-0.2, -0.08)):
        put(p, sphere(0.05, 8, 4), mix(WHITE, DOUGH, 0.4), "matte", lid @ T(x, y, 0.016) @ S(1.6, 1.1, 0.08))
    put(p, box(0.12, 0.09, 0.008, seg=1), SCRUBBED, "satin", T(-0.55, 0.12, zt) @ R("Z", 25) @ R("Y", 8))


# ------------------------------------------------------------ seating


def settee_rose(p, size, c):
    w, d = 1.7, 0.78
    frame = CREAM
    cab_legs(p, w - 0.06, d - 0.08, 0.27, 0.028, frame, "pearl", inset=0.03)
    for sy, a in ((1, 45), (-1, 225)):
        put(p, cabriole(0.27, 0.028), frame, "pearl", T(0, sy * (d / 2 - 0.07), 0) @ R("Z", a))
    for x, y in ((w / 2 - 0.03, d / 2 - 0.04), (-w / 2 + 0.03, d / 2 - 0.04), (0, d / 2 - 0.05)):
        put(p, sphere(0.022, 6, 4), GOLD, "gold", T(x, y, 0.02))
    # serpentine seat rail, gilt bead, carved centre flower
    xs = [-(w - 0.06) / 2 + (w - 0.06) * i / 20 for i in range(21)]
    front = [(x, serp_y(x, w - 0.06, d - 0.06, 0.035)) for x in xs]
    zlo = [0.27 - 0.03 * math.exp(-(x / 0.15) ** 2) for x in xs]
    put(p, band(front, zlo, 0.38, 0.05), frame, "pearl")
    put(p, tube([(x, y + 0.028, z + 0.01) for (x, y), z in zip(front, zlo)], 0.007, 4), GOLD, "gold")
    put(p, box(w - 0.1, d - 0.12, 0.1, bevel=0.03), frame, "pearl", T(0, -0.03, 0.33))
    bloom(p, (0, d / 2 + 0.01, 0.31), 0.05, lighter(frame, 0.1), 2, 5, random.Random(3), "pearl", tilt=R("X", -90))
    put(p, cushion(w - 0.14, d - 0.14, 0.12, 0.35), c, "fabric", T(0, 0.0, 0.44))
    # shaped Louis XV back with padded panel and moulded frame
    ol = shaped_back(w - 0.1, 0.44, 0.6, 16, 1.6)
    mb = T(0, -d / 2 + 0.07, 0.4) @ R("X", -9)
    put(p, bend(slab(ol, 0.08, 0.02), 0.07), c, "fabric", mb)
    put(p, bend(frame_ring(ol, 0.026, 0.06), 0.07), frame, "pearl", mb @ T(0, 0.02, 0))
    inner = [(x * 0.93, 0.03 + z * 0.9) for x, z in ol]
    put(p, bend(frame_ring(inner, 0.007, 0.02), 0.07), GOLD, "gold", mb @ T(0, 0.045, 0))
    crest(p, 0, -d / 2 + 0.07 + 0.05, 0.98, 0.16)
    bloom(p, (0, -d / 2 + 0.08, 1.0), 0.05, ROSE, 2, 5, random.Random(5), "pearl", tilt=R("X", -80))
    # open arms with padded manchettes
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.05)
        arm = [(x, d / 2 - 0.05, 0.36), (x + sx * 0.02, d / 2 - 0.1, 0.55), (x, d / 2 - 0.2, 0.64), (x, 0.0, 0.66),
               (x * 0.98, -d / 2 + 0.12, 0.7)]
        put(p, tube(arm, [0.03, 0.026, 0.026, 0.025, 0.025], 6), frame, "pearl")
        put(p, cushion(0.08, 0.36, 0.05, 0.5), c, "fabric", T(x, -0.07, 0.685))
        put(p, scroll(0.03, 1.2, 8, 0.008), GOLD, "gold", T(x + sx * 0.02, d / 2 - 0.13, 0.62) @ R("Z", 90))
    for x in (-0.48, 0.48):
        put(p, cushion(0.34, 0.12, 0.3, 0.5), lighter(c, 0.35), "fabric", T(x, -d / 2 + 0.2, 0.66) @ R("X", -14) @ R("Z", 8 if x < 0 else -8))


def sofa_camelback(p, size, c):
    w, d = 2.3, 0.95
    for x in (-(w / 2 - 0.1), 0.0, w / 2 - 0.1):
        for sy in (-1, 1):
            put(p, lathe([(0.02, 0), (0.03, 0.03), (0.042, 0.07), (0.028, 0.12), (0.045, 0.16)], 6), GOLD, "gold",
                T(x, sy * (d / 2 - 0.09), 0))
    put(p, box(w - 0.04, d - 0.08, 0.2, bevel=0.06), c, "fabric", T(0, 0, 0.26))
    put(p, tube([(-(w / 2 - 0.03), d / 2 - 0.035, 0.175), ((w / 2 - 0.03), d / 2 - 0.035, 0.175)], 0.012, 5), GOLD, "gold")
    nailheads(p, [(-(w / 2 - 0.25) + (w - 0.5) * i / 11, d / 2 - 0.035, 0.215) for i in range(12)], 0.01)
    cw = (w - 0.44) / 3
    for k in range(3):
        put(p, cushion(cw - 0.01, d - 0.3, 0.15, 0.35), lighter(c, 0.04 * k), "fabric", T(-cw + k * cw, 0.08, 0.43))
    # camel back: a hump rising from the arms
    ol = shaped_back(w - 0.16, 0.42, 0.72, 18, 2.2)
    mb = T(0, -d / 2 + 0.13, 0.32) @ R("X", -7)
    put(p, slab(ol, 0.22, 0.06), c, "fabric", mb)
    top = [(x, 0.0, z) for x, z in ol[3:-1]]
    put(p, tube(top, 0.014, 5), GOLD, "gold", mb @ T(0, 0.11, -0.01))
    # rolled arms with scrolled fronts and gilt rosettes
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.11)
        L = d - 0.12
        put(p, box(0.18, L - 0.05, 0.34, bevel=0.05), c, "fabric", T(x, 0.02, 0.48))
        put(p, cyl(0.11, L, 14), c, "fabric", T(x + sx * 0.02, -d / 2 + 0.1, 0.66) @ R("X", -90))
        put(p, disc(0.1, 14, 0.0), lighter(c, 0.08), "fabric", T(x + sx * 0.02, d / 2 - 0.018, 0.66) @ R("X", -90), smooth=False)
        put(p, torus(0.105, 0.01, 12, 3), GOLD, "gold", T(x + sx * 0.02, d / 2 - 0.005, 0.66) @ R("X", 90))
        rose(p, (x + sx * 0.02, d / 2 + 0.01, 0.66), 0.045, GOLD, random.Random(11), R("X", -90), "gold")
    # two bolsters with gathered gilt-tasselled ends
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.3)
        m = T(x, -0.18, 0.6) @ R("X", -90) @ R("Z", 0)
        put(p, lathe([(0.02, 0), (0.08, 0.02), (0.1, 0.06), (0.1, 0.4), (0.08, 0.44), (0.02, 0.46)], 10), BLUSH, "fabric", m)
        put(p, torus(0.1, 0.008, 10, 3), GOLD, "gold", m @ T(0, 0, 0.23))
        put(p, cyl(0.012, 0.06, 5, 0.025), GOLD, "gold", m @ T(0, 0, 0.46))
        put(p, cushion(0.42, 0.13, 0.36, 0.5), lighter(c, 0.3), "fabric", T(sx * 0.55, -d / 2 + 0.28, 0.66) @ R("X", -14))


def ottoman_tufted(p, size, c):
    prof = [(0, 0.1), (0.43, 0.1), (0.465, 0.13), (0.475, 0.22), (0.47, 0.32), (0.45, 0.36), (0.42, 0.39),
            (0.39, 0.405), (0.35, 0.416), (0.3, 0.426), (0.25, 0.433), (0.19, 0.439), (0.13, 0.443), (0.065, 0.446),
            (0, 0.447)]
    body = lathe(prof, 24)
    buttons = []
    for k in range(6):
        a = math.radians(60 * k)
        buttons.append((0.13 * math.cos(a), 0.13 * math.sin(a)))
    for k in range(12):
        a = math.radians(30 * k + 15)
        buttons.append((0.25 * math.cos(a), 0.25 * math.sin(a)))
    for k in range(12):
        a = math.radians(30 * k)
        buttons.append((0.35 * math.cos(a), 0.35 * math.sin(a)))
    deep = {}
    for v in body.verts:
        if v.co.z < 0.39:
            continue
        dz = 0.0
        for bx, by in buttons:
            dd = math.hypot(v.co.x - bx, v.co.y - by)
            dz = max(dz, 0.026 * math.exp(-(dd / 0.03) ** 2))
        v.co.z -= dz
    for bx, by in buttons:
        best = min(body.verts, key=lambda v: (v.co.x - bx) ** 2 + (v.co.y - by) ** 2)
        deep[(bx, by)] = best.co.z
    put(p, body, c, "fabric")
    for bx, by in buttons:
        put(p, ico(0.014, 1), GOLD, "gold", T(bx, by, deep[(bx, by)] + 0.006) @ S(1, 1, 0.6))
    put(p, lathe([(0, 0), (0.035, 0.0), (0.03, 0.012), (0, 0.02)], 10), GOLD, "gold", T(0, 0, 0.444))
    rose(p, (0, 0, 0.462), 0.03, ROSE, random.Random(5), None, "pearl", 1, 6)
    put(p, torus(0.455, 0.012, 24, 4), lighter(c, 0.3), "fabric", T(0, 0, 0.355))
    fringe(p, 0.476, 0.045, 0.16, GOLD, 48)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        bun(p, 0.33 * math.cos(a), 0.33 * math.sin(a), 0.055, PEARL, "pearl")


def footstool_velvet(p, size, c):
    w, d = 0.55, 0.42
    cab_legs(p, w - 0.04, d - 0.04, 0.2, 0.02, GOLD, "gold", inset=0.04)
    put(p, box(w - 0.02, d - 0.02, 0.07, bevel=0.02), CREAM, "pearl", T(0, 0, 0.225))
    gilt_edge(p, w - 0.01, d - 0.01, 0.192, 0.007)
    crest(p, 0, d / 2 - 0.005, 0.19, 0.09)
    put(p, cushion(w - 0.04, d - 0.04, 0.12, 0.55), c, "fabric", T(0, 0, 0.31))
    put(p, tube([(-w / 2 + 0.02, -d / 2 + 0.02, 0.262), (w / 2 - 0.02, -d / 2 + 0.02, 0.262), (w / 2 - 0.02, d / 2 - 0.02, 0.262),
                (-w / 2 + 0.02, d / 2 - 0.02, 0.262)], 0.009, 5, closed=True), lighter(c, 0.3), "fabric", smooth=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            put(p, cyl(0.012, 0.07, 5, 0.022), GOLD, "gold", T(sx * (w / 2 - 0.01), sy * (d / 2 - 0.01), 0.18))
            put(p, sphere(0.014, 6, 4), GOLD, "gold", T(sx * (w / 2 - 0.01), sy * (d / 2 - 0.01), 0.255))


def chair_low_back(p, size, c):
    w, d = 0.78, 0.78
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.08), sy * (d / 2 - 0.08)
            put(p, turned_leg(0.14, 0.03, 8), PEARL, "pearl", T(x, y, 0))
            put(p, cyl(0.018, 0.025, 8), GOLD, "gold", T(x, y, 0))
    put(p, box(w - 0.04, d - 0.04, 0.22, bevel=0.06), c, "fabric", T(0, 0, 0.25))
    put(p, cushion(w - 0.12, d - 0.2, 0.15, 0.4), lighter(c, 0.08), "fabric", T(0, 0.06, 0.43))
    # tub-shaped low back
    ol = shaped_back(w - 0.04, 0.34, 0.47, 14, 2.0)
    mb = T(0, -d / 2 + 0.1, 0.34) @ R("X", -12)
    put(p, bend(slab(ol, 0.16, 0.05), 0.35), c, "fabric", mb)
    put(p, bend(tube([(x, 0, z) for x, z in ol[3:-1]], 0.012, 5), 0.35), GOLD, "gold", mb @ T(0, 0.075, -0.012))
    # ivory damask: raised lozenge and fleuron motifs
    dam = mix(CREAM, GOLD, 0.3)
    for x, z in ((-0.2, 0.18), (0.0, 0.26), (0.2, 0.18), (-0.1, 0.06), (0.1, 0.06)):
        put(p, box(0.045, 0.008, 0.06, seg=1), dam, "satin", mb @ T(x, 0.08 + 0.35 * x * x, z) @ R("Y", 45), smooth=False)
    for x, z in ((-0.26, 0.0), (-0.13, 0.0), (0.0, 0.0), (0.13, 0.0), (0.26, 0.0)):
        put(p, box(0.04, 0.008, 0.055, seg=1), dam, "satin", T(x, d / 2 - 0.015, 0.25) @ R("Y", 45), smooth=False)
    put(p, cushion(0.4, 0.12, 0.24, 0.5), ROSE, "fabric", T(0, -d / 2 + 0.26, 0.6) @ R("X", -18))
    put(p, tube([(-(w / 2 - 0.03), d / 2 - 0.02, 0.15), ((w / 2 - 0.03), d / 2 - 0.02, 0.15)], 0.01, 5), GOLD, "gold")


def chair_bergere(p, size, c):
    w, d = 0.8, 0.82
    frame = CREAM
    cab_legs(p, w - 0.06, d - 0.08, 0.24, 0.026, frame, "pearl", inset=0.03)
    for sx in (-1, 1):
        for sy in (-1, 1):
            put(p, sphere(0.02, 6, 4), GOLD, "gold", T(sx * (w / 2 - 0.01), sy * (d / 2 - 0.02), 0.02))
    xs = [-(w - 0.06) / 2 + (w - 0.06) * i / 12 for i in range(13)]
    front = [(x, serp_y(x, w - 0.06, d - 0.06, 0.03)) for x in xs]
    put(p, band(front, 0.24, 0.36, 0.05), frame, "pearl")
    put(p, box(w - 0.08, d - 0.12, 0.1, bevel=0.03), frame, "pearl", T(0, -0.03, 0.31))
    bloom(p, (0, d / 2 + 0.005, 0.29), 0.04, lighter(frame, 0.1), 2, 5, random.Random(21), "pearl", tilt=R("X", -90))
    put(p, cushion(w - 0.22, d - 0.2, 0.13, 0.4), c, "fabric", T(0, 0.04, 0.43))
    # rounded tub back with moulded cream frame and carved crest
    ol = arched_outline(w - 0.12, 0.62, 12, 0.26)
    mb = T(0, -d / 2 + 0.08, 0.4) @ R("X", -10)
    put(p, bend(slab(ol, 0.1, 0.03), 0.4), c, "fabric", mb)
    put(p, bend(frame_ring(ol, 0.026, 0.05), 0.4), frame, "pearl", mb @ T(0, 0.02, 0))
    crest(p, 0, -d / 2 + 0.03, 1.0, 0.14, GOLD)
    bloom(p, (0, -d / 2 + 0.06, 1.02), 0.045, lighter(frame, 0.12), 2, 5, random.Random(22), "pearl", tilt=R("X", -80))
    # closed upholstered arms: side panels with a cream arm rail
    side = [(-d / 2 + 0.1, 0.34), (d / 2 - 0.06, 0.34), (d / 2 - 0.06, 0.58), (d / 2 - 0.12, 0.64), (0.0, 0.64),
            (-d / 2 + 0.2, 0.7), (-d / 2 + 0.1, 0.8)]
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.06)
        put(p, slab(side, 0.08, 0.025), c, "fabric", T(x, 0, 0) @ R("Z", 90))
        rail = [(x, d / 2 - 0.03, 0.34), (x, d / 2 - 0.03, 0.6), (x, d / 2 - 0.12, 0.665), (x, 0.0, 0.665),
                (x, -d / 2 + 0.2, 0.725), (x, -d / 2 + 0.1, 0.82)]
        put(p, tube(rail, [0.024, 0.024, 0.026, 0.026, 0.024, 0.022], 6), frame, "pearl")
        put(p, scroll(0.028, 1.2, 8, 0.007), GOLD, "gold", T(x + sx * 0.03, d / 2 - 0.06, 0.6) @ R("Z", 90))
        put(p, cushion(0.08, 0.32, 0.045, 0.5), lighter(c, 0.1), "fabric", T(x, 0.06, 0.69))


def chair_head_dining(p, size, c):
    w, d = 0.85, 0.75
    cab_legs(p, w - 0.06, d - 0.06, 0.4, 0.034, GOLD, "gold", inset=0.05)
    for sx in (-1, 1):
        acanthus(p, sx * (w / 2 - 0.02), d / 2 - 0.02, 0.36, 0.12, 90 - sx * 45)
    xs = [-(w - 0.06) / 2 + (w - 0.06) * i / 14 for i in range(15)]
    front = [(x, serp_y(x, w - 0.06, d - 0.06, 0.03)) for x in xs]
    zlo = [0.36 - 0.05 * math.exp(-(x / 0.12) ** 2) for x in xs]
    put(p, band(front, zlo, 0.48, 0.045), GOLD, "gold")
    put(p, box(w - 0.08, d - 0.1, 0.11, bevel=0.03), GOLD_PALE, "gold", T(0, -0.03, 0.43))
    crest(p, 0, d / 2 - 0.01, 0.3, 0.12)
    put(p, cushion(w - 0.12, d - 0.12, 0.12, 0.38), c if c != GOLD else EMERALD, "fabric", T(0, 0.01, 0.54))
    vel = EMERALD
    # tall back: emerald panel in a heavy gilt frame between turned stiles
    ol = arched_outline(0.66, 0.98, 14, 0.2)
    mb = T(0, -d / 2 + 0.07, 0.56) @ R("X", -6)
    put(p, slab(ol, 0.07, 0.02), vel, "fabric", mb)
    put(p, frame_ring(ol, 0.036, 0.07), GOLD, "gold", mb @ T(0, 0.02, 0))
    put(p, frame_ring([(x * 0.84, 0.08 + z * 0.84) for x, z in ol], 0.009, 0.02), lighter(GOLD, 0.2), "gold", mb @ T(0, 0.04, 0))
    for sx in (-1, 1):
        put(p, lathe([(0.03, 0), (0.035, 0.1), (0.025, 0.25), (0.032, 0.5), (0.025, 0.8), (0.035, 0.92), (0.022, 0.97)], 8),
              GOLD, "gold", mb @ T(sx * 0.37, 0, -0.04))
        put(p, lathe([(0, 0), (0.03, 0.01), (0.04, 0.05), (0.02, 0.09), (0, 0.16)], 8), GOLD, "gold", mb @ T(sx * 0.37, 0, 0.93))
    # leaf-whorl crest: acanthus leaves wheeling round a gilt rose, flanked by volutes
    cm = mb @ T(0, 0.03, 1.08)
    for i in range(10):
        a = 360 * i / 10
        put(p, leaf(0.13, 0.06), GOLD if i % 2 else lighter(GOLD, 0.15), "gold", cm @ R("Y", -a) @ R("Z", 14) @ R("X", -90))
    bloom(p, (0, 0, 0), 0.06, GOLD, 2, 6, random.Random(31), "gold", tilt=cm @ R("X", -90))
    for sx in (-1, 1):
        put(p, scroll(0.07, 1.4, 12, 0.012), GOLD, "gold", mb @ T(sx * 0.2, 0.03, 0.99) @ S(sx, 1, 1))
    # gilt arms with emerald manchettes
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.05)
        arm = [(x, d / 2 - 0.05, 0.48), (x + sx * 0.02, d / 2 - 0.08, 0.66), (x, d / 2 - 0.16, 0.76), (x, 0.0, 0.78),
               (x * 0.95, -d / 2 + 0.1, 0.84)]
        put(p, tube(arm, [0.03, 0.026, 0.028, 0.026, 0.026], 6), GOLD, "gold")
        put(p, cushion(0.08, 0.34, 0.05, 0.5), vel, "fabric", T(x, -0.06, 0.805))
        put(p, scroll(0.035, 1.3, 9, 0.009), GOLD, "gold", T(x + sx * 0.025, d / 2 - 0.13, 0.72) @ R("Z", 90))



def bed_bench(p, size, c):
    w, d = 1.7, 0.48
    cab_legs(p, w - 0.06, d - 0.06, 0.24, 0.024, GOLD, "gold", inset=0.04)
    for sy, a in ((1, 45), (-1, 225)):
        put(p, cabriole(0.24, 0.024), GOLD, "gold", T(0, sy * (d / 2 - 0.06), 0) @ R("Z", a))
    put(p, box(w - 0.04, d - 0.04, 0.09, bevel=0.025), PEARL, "pearl", T(0, 0, 0.285))
    gilt_edge(p, w - 0.03, d - 0.03, 0.245, 0.008)
    crest(p, 0, d / 2 - 0.01, 0.24, 0.1)
    for sx in (-1, 1):
        put(p, scroll(0.035, 1.3, 9, 0.007), GOLD, "gold", T(sx * 0.4, d / 2 - 0.012, 0.285) @ S(sx, 1, 1))
    put(p, cushion(w - 0.06, d - 0.06, 0.16, 0.3), c, "fabric", T(0, 0, 0.41))
    put(p, tube([(-w / 2 + 0.03, -d / 2 + 0.03, 0.335), (w / 2 - 0.03, -d / 2 + 0.03, 0.335), (w / 2 - 0.03, d / 2 - 0.03, 0.335),
                (-w / 2 + 0.03, d / 2 - 0.03, 0.335)], 0.01, 5, closed=True), BLUSH, "fabric", smooth=False)
    for row, (y, n) in enumerate(((-0.08, 8), (0.08, 7))):
        for i in range(n):
            x = -(w - 0.3) / 2 + (w - 0.3) * (i + (0.5 if row else 0.0)) / 7
            put(p, sphere(0.012, 6, 4), GOLD, "gold", T(x, y, 0.49))
            put(p, disc(0.03, 6, 0.0), darker(c, 0.08), "fabric", T(x, y, 0.488))


def hall_bench_cushioned(p, size, c):
    w, d = 1.6, 0.5
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.1), sy * (d / 2 - 0.07)
            put(p, turned_leg(0.3, 0.028, 8), GOLD, "gold", T(x, y, 0))
    for sy in (-1, 1):
        put(p, tube([(-(w / 2 - 0.1), sy * (d / 2 - 0.07), 0.08), (0, sy * (d / 2 - 0.07), 0.11), (w / 2 - 0.1, sy * (d / 2 - 0.07), 0.08)],
                   0.012, 5), GOLD, "gold")
    put(p, tube([(0, -(d / 2 - 0.07), 0.11), (0, d / 2 - 0.07, 0.11)], 0.012, 5), GOLD, "gold")
    put(p, sphere(0.025, 6, 4), GOLD, "gold", T(0, 0, 0.11))
    put(p, box(w - 0.1, d - 0.04, 0.08, bevel=0.025), CREAM, "pearl", T(0, 0, 0.34))
    put(p, tube([(-(w / 2 - 0.06), d / 2 - 0.02, 0.305), (w / 2 - 0.06, d / 2 - 0.02, 0.305)], 0.008, 4), GOLD, "gold")
    put(p, cushion(w - 0.26, d - 0.06, 0.12, 0.35), c, "fabric", T(0, 0, 0.44))
    put(p, tube([(-(w / 2 - 0.14), d / 2 - 0.035, 0.385), (w / 2 - 0.14, d / 2 - 0.035, 0.385)], 0.009, 5), lighter(c, 0.3), "fabric")
    # low rolled ends, like a recamier, with gilt rosettes
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.08)
        put(p, cyl(0.075, d - 0.06, 12), c, "fabric", T(x, -(d - 0.06) / 2, 0.47) @ R("X", -90))
        put(p, box(0.12, d - 0.08, 0.1, bevel=0.03), c, "fabric", T(x, 0, 0.42))
        for sy in (-1, 1):
            put(p, torus(0.065, 0.009, 12, 4), GOLD, "gold", T(x, sy * (d / 2 - 0.028), 0.47) @ R("X", 90))
            put(p, sphere(0.022, 6, 4), GOLD, "gold", T(x, sy * (d / 2 - 0.025), 0.47))


# ------------------------------------------------------------ case furniture


def bureau_secretary(p, size, c):
    w, d = 1.02, 0.56
    for sx in (-1, 1):
        for sy in (-1, 1):
            bun(p, sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), 0.05, darker(c, 0.1), "satin")
    put(p, box(w + 0.03, d + 0.03, 0.06, bevel=0.015), darker(c, 0.08), "satin", T(0, 0, 0.08))
    put(p, box(w, d, 0.76, bevel=0.02), c, "satin", T(0, 0, 0.11 + 0.38))
    yf = d / 2
    drawer(p, -0.24, yf, 0.79, 0.44, 0.13, lighter(c, 0.07))
    drawer(p, 0.24, yf, 0.79, 0.44, 0.13, lighter(c, 0.07))
    drawer(p, 0, yf, 0.58, 0.92, 0.19, lighter(c, 0.07), 2)
    drawer(p, 0, yf, 0.31, 0.92, 0.25, lighter(c, 0.07), 2)
    for z in (0.69, 0.465, 0.17):
        put(p, box(w - 0.04, 0.008, 0.008, seg=1), GOLD, "gold", T(0, yf + 0.004, z), smooth=False)
    # slant-front writing fall with gilt escutcheon
    prof = [(-d / 2, 0.87), (d / 2, 0.87), (d / 2, 0.92), (-d / 2 + 0.26, 1.18), (-d / 2, 1.18)]
    put(p, slab(prof, w, 0.01), c, "satin", T(0, 0, 0) @ R("Z", 90) @ S(-1, 1, 1))
    ang = math.degrees(math.atan2(1.18 - 0.92, d - 0.26))
    mid = ((d / 2 + (-d / 2 + 0.26)) / 2, (0.92 + 1.18) / 2)
    L = math.hypot(d - 0.26, 0.26)
    lid = T(0, mid[0] + 0.012, mid[1] + 0.012) @ R("X", ang)
    put(p, box(w - 0.06, L - 0.03, 0.02, bevel=0.006), lighter(c, 0.1), "satin", lid)
    put(p, box(w - 0.2, L - 0.14, 0.004, seg=1), lighter(c, 0.2), "satin", lid @ T(0, 0, 0.012), smooth=False)
    put(p, lathe([(0, 0), (0.035, 0.0), (0.02, 0.015), (0, 0.02)], 8), GOLD, "gold", lid @ T(0, 0.04, 0.01))
    put(p, box(0.006, 0.004, 0.02, seg=1), OAK_DARK, "matte", lid @ T(0, 0.04, 0.032) @ R("X", 90), smooth=False)
    for sx in (-1, 1):
        pull(p, sx * 0.43, yf, 0.895, 0.012)
    # glazed bookcase top with books behind the glass
    bd = 0.32
    yb = -d / 2 + bd / 2
    z0, z1 = 1.18, 2.06
    put(p, box(w - 0.04, bd, 0.03, bevel=0.01), darker(c, 0.05), "satin", T(0, yb, z0 + 0.015))
    for sx in (-1, 1):
        put(p, box(0.04, bd, z1 - z0, bevel=0.01), c, "satin", T(sx * (w / 2 - 0.04), yb, (z0 + z1) / 2))
    put(p, box(w - 0.08, 0.02, z1 - z0, seg=1), mix(SOFT_BLUE, PEARL, 0.4), "satin", T(0, -d / 2 + 0.01, (z0 + z1) / 2))
    rng = random.Random(1201)
    for z in (z0 + 0.03, z0 + 0.32, z0 + 0.61):
        if z > z0 + 0.04:
            put(p, box(w - 0.1, bd - 0.04, 0.02, seg=1), c, "satin", T(0, yb - 0.01, z - 0.01))
        book_run(p, -w / 2 + 0.07, w / 2 - 0.07, yb + bd / 2 - 0.06, z, 0.2, 0.18, 0.25, rng, 0.03, 0.06, gild=0.35)
    yd = -d / 2 + bd + 0.005
    dw = (w - 0.1) / 2
    for sx in (-1, 1):
        x = sx * dw / 2
        put(p, box(dw - 0.04, 0.006, z1 - z0 - 0.08, seg=1), (0.9, 0.96, 1.0), "glass", T(x, yd - 0.004, (z0 + z1) / 2))
        for ox in (-1, 1):
            put(p, box(0.035, 0.03, z1 - z0 - 0.04), c, "satin", T(x + ox * (dw / 2 - 0.02), yd, (z0 + z1) / 2), smooth=False)
        for zz in (z0 + 0.04, z1 - 0.04):
            put(p, box(dw - 0.02, 0.03, 0.035), c, "satin", T(x, yd, zz), smooth=False)
        for k in (1, 2):
            put(p, box(0.008, 0.012, z1 - z0 - 0.1, seg=1), GOLD, "gold", T(x - dw / 2 + dw * k / 3, yd + 0.004, (z0 + z1) / 2), smooth=False)
        for zz in ((z0 + z1) / 2 - 0.15, (z0 + z1) / 2 + 0.15):
            put(p, box(dw - 0.06, 0.012, 0.008, seg=1), GOLD, "gold", T(x, yd + 0.004, zz), smooth=False)
        pull(p, x - sx * (dw / 2 - 0.045), yd + 0.012, (z0 + z1) / 2, 0.012)
    # arched pediment with gilt moulding and finials
    seg = [(-w / 2 - 0.02, 0.0), (w / 2 + 0.02, 0.0)]
    for i in range(13):
        x = w / 2 + 0.02 - (w + 0.04) * i / 12
        t = 2 * x / (w + 0.04)
        seg.append((x, 0.06 + 0.14 * math.sqrt(max(0.0, 1 - t * t))))
    put(p, box(w + 0.04, bd + 0.04, 0.05, bevel=0.015), darker(c, 0.05), "satin", T(0, yb + 0.01, z1 + 0.025))
    yp = yb + bd / 2 - 0.01
    put(p, slab(seg, 0.05), c, "satin", T(0, yp, z1 + 0.05))
    put(p, tube([(x, 0, z) for x, z in seg[2:]], 0.022, 6), darker(c, 0.06), "satin", T(0, yp + 0.012, z1 + 0.05))
    put(p, tube([(x, 0, z) for x, z in seg[2:]], 0.008, 4), GOLD, "gold", T(0, yp + 0.035, z1 + 0.04))
    crest_lite(p, 0, yp + 0.03, z1 + 0.07, 0.12)
    put(p, lathe([(0, 0), (0.035, 0.01), (0.04, 0.04), (0.02, 0.06), (0.03, 0.08), (0, 0.13)], 8), GOLD, "gold", T(0, yp, z1 + 0.25))
    for sx in (-1, 1):
        put(p, lathe([(0, 0), (0.03, 0.01), (0.032, 0.035), (0.015, 0.05), (0, 0.08)], 8), GOLD, "gold", T(sx * (w / 2 - 0.02), yp, z1 + 0.06))


def commode_serpentine(p, size, c):
    w, h, d = 1.3, 0.92, 0.56
    body_c = mix(c, WHITE, 0.25)
    for sx, sy, a in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        put(p, cabriole(0.16, 0.03, 1.2), body_c, "pearl", T(sx * (w / 2 - 0.07), sy * (d / 2 - 0.07), 0) @ R("Z", a))
        knob_lite(p, sx * (w / 2 - 0.05), sy * (d / 2 - 0.05), 0.015, 0.022)
    put(p, plan_slab(serp_plan(w - 0.04, d - 0.04, 0.05, 20), 0.15, 0.72), body_c, "pearl")
    # scalloped gilt apron
    xs = [-(w - 0.1) / 2 + (w - 0.1) * i / 18 for i in range(19)]
    ap = [(x, serp_y(x, w - 0.04, d - 0.04, 0.05) + 0.005) for x in xs]
    zl = [0.15 - 0.04 * math.exp(-(x / 0.12) ** 2) + 0.012 * abs(math.sin(4 * math.pi * x / w)) for x in xs]
    put(p, band(ap, zl, 0.16, 0.012), GOLD, "gold")
    # three serpentine drawers with painted floral reserves and gilt bail handles
    rng = random.Random(1301)
    xs = [-(w - 0.14) / 2 + (w - 0.14) * i / 12 for i in range(13)]
    fl = [(x, serp_y(x, w - 0.04, d - 0.04, 0.05) + 0.008) for x in xs]
    for k, (z0, z1) in enumerate(((0.18, 0.39), (0.41, 0.62), (0.64, 0.85))):
        put(p, band(fl, z0, z1, 0.016), lighter(body_c, 0.08), "pearl")
        zc = (z0 + z1) / 2
        yc = serp_y(0, w - 0.04, d - 0.04, 0.05) + 0.017
        ov = [(x * 1.0, z) for x, z in oval_outline(0.34, 0.15, 12)]
        put(p, slab(ov, 0.004), [BLUSH, mix(SOFT_BLUE, WHITE, 0.3), mix(MINT, WHITE, 0.3)][k], "matte", T(0, yc, zc - 0.075))
        put(p, tube([(x, 0, z) for x, z in ov], 0.006, 4, closed=True), GOLD, "gold", T(0, yc + 0.002, zc - 0.075))
        rose(p, (0.0, yc + 0.006, zc + 0.01), 0.03, [ROSE, LILAC, PERI][k], rng, R("X", -90), "pearl", 1, 6)
        for dx, col in ((-0.075, [BLUSH, ROSE, BUTTER][k]), (0.075, [BUTTER, BLUSH, ROSE][k]), (-0.04, WHITE), (0.045, LILAC)):
            flat_flower(p, T(dx, yc + 0.004, zc - 0.012 + 0.02 * (dx > 0)) @ R("X", -90), 0.018 if abs(dx) > 0.05 else 0.012, col, BUTTER, 5, "pearl")
        for dx in (-0.11, 0.11):
            put(p, leaf(0.05, 0.025), LEAF, "leaf", T(dx, yc + 0.005, zc) @ R("Z", 0) @ R("Y", 0 if dx > 0 else 180) @ R("X", -90))
        for sx in (-1, 1):
            x = sx * 0.4
            bail(p, x, serp_y(x, w - 0.04, d - 0.04, 0.05) + 0.017, zc - 0.01, 0.045)
    for z in (0.40, 0.63):
        put(p, tube([(x, y + 0.012, z) for x, y in fl], 0.006, 4), GOLD, "gold")
    # gilt corner chutes and the marble top
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.03)
        y = serp_y(x, w - 0.04, d - 0.04, 0.05)
        put(p, tube([(x, y, 0.84), (x + sx * 0.01, y + 0.01, 0.7), (x, y, 0.5), (x - sx * 0.005, y, 0.3)], [0.018, 0.014, 0.01, 0.006], 5), GOLD, "gold")
        put(p, scroll_lite(0.035, 1.2, 8, 0.008), GOLD, "gold", T(x, y + 0.01, 0.83) @ R("Z", sx * 45))
        acanthus(p, x, y + 0.01, 0.8, 0.09, 90 + sx * 45)
    top = serp_plan(w + 0.02, d + 0.02, 0.05, 24)
    put(p, plan_slab(top, h - 0.035, 0.035), MARBLE_PINK, "pearl")
    put(p, tube([(x, y, h - 0.037) for x, y in top], 0.009, 4, closed=True), GOLD, "gold", smooth=False)


def etagere_gilt(p, size, c):
    w, h, d = 0.88, 1.7, 0.4
    posts = [(sx * (w / 2 - 0.03), sy * (d / 2 - 0.03)) for sx in (-1, 1) for sy in (-1, 1)]
    shelves = (0.12, 0.5, 0.88, 1.26)
    for x, y in posts:
        put(p, lathe([(0.016, 0.03), (0.02, 0.2), (0.014, 0.4), (0.02, 0.69), (0.014, 0.88), (0.02, 1.07), (0.014, 1.26),
                     (0.018, 1.48)], 6), c, "gold", T(x, y, 0))
        put(p, lathe([(0, 0), (0.025, 0.01), (0.022, 0.04), (0.008, 0.08), (0.014, 0.1), (0, 0.18)], 8), c, "gold", T(x, y, 1.48))
        bun(p, x, y, 0.028, c)
        for z in shelves[::3]:
            knob_lite(p, x, y, z + 0.012, 0.024, c)
    for z in shelves:
        put(p, box(w - 0.04, d - 0.04, 0.014, seg=1), (0.9, 0.96, 1.0), "glass", T(0, 0, z))
        gilt_edge(p, w - 0.04, d - 0.04, z, 0.008)
    # scroll gallery along the back of the top shelf and a crest
    for sx in (-1, 1):
        put(p, scroll_lite(0.07, 1.4, 10, 0.01), c, "gold", T(sx * 0.18, -d / 2 + 0.03, 1.36) @ S(sx, 1, 1))
    put(p, tube([(-w / 2 + 0.03, -d / 2 + 0.03, 1.33), (w / 2 - 0.03, -d / 2 + 0.03, 1.33)], 0.008, 5), c, "gold")
    crest_lite(p, 0, -d / 2 + 0.03, 1.4, 0.16, c)
    rng = random.Random(1401)
    # bottom: covered porcelain urn and a conch shell
    put(p, lathe([(0, 0), (0.06, 0), (0.05, 0.03), (0.09, 0.12), (0.08, 0.22), (0.05, 0.25), (0.06, 0.27),
                 (0.03, 0.31), (0, 0.33)], 12), PORCELAIN, "pearl", T(-0.2, 0, 0.127))
    put(p, lathe([(0.088, 0.1), (0.092, 0.15)], 12, False, False), DELFT, "pearl", T(-0.2, 0, 0.127))
    put(p, lathe([(0, 0), (0.06, 0.02), (0.07, 0.06), (0.04, 0.12), (0, 0.16)], 10), BLUSH, "pearl",
          T(0.18, 0, 0.17) @ R("Y", 70) @ S(1, 0.8, 1))
    # second: roses in a vase and a little teapot
    put(p, lathe([(0, 0), (0.035, 0), (0.055, 0.06), (0.03, 0.14), (0.045, 0.18)], 10), MINT, "pearl", T(-0.22, 0.02, 0.507))
    for k, col in enumerate((ROSE, BLUSH, ROSE, LILAC)):
        a = 2 * math.pi * k / 4
        rose(p, (-0.22 + 0.04 * math.cos(a), 0.02 + 0.04 * math.sin(a), 0.72 + 0.02 * (k % 2)), 0.04, col, rng,
             R("X", 25 * math.sin(a)) @ R("Y", -25 * math.cos(a)), "fabric", 1, 6)
    put(p, lathe([(0, 0), (0.06, 0), (0.08, 0.05), (0.06, 0.1), (0.02, 0.11), (0.02, 0.13), (0, 0.14)], 12), PORCELAIN, "pearl", T(0.18, 0, 0.507))
    put(p, tube([(0.25, 0, 0.56), (0.3, 0, 0.6), (0.32, 0, 0.63)], [0.014, 0.01, 0.008], 5), PORCELAIN, "pearl")
    put(p, torus(0.035, 0.008, 8, 4), PORCELAIN, "pearl", T(0.1, 0, 0.57) @ R("X", 90))
    put(p, lathe([(0.0805, 0.04), (0.08, 0.055)], 12, False, False), ROSE, "pearl", T(0.18, 0, 0.507))
    # third: books lying flat with a gilt casket on them
    z = 0.887
    for k, col in enumerate((PERI, ROSE, BUTTER)):
        put(p, box(0.26 - 0.02 * k, 0.18 - 0.01 * k, 0.035, bevel=0.005, seg=1), col, "satin", T(-0.15, 0, z + 0.018) @ R("Z", 6 * k - 6), smooth=False)
        z += 0.036
    put(p, box(0.12, 0.08, 0.06, bevel=0.01), GOLD, "gold", T(-0.15, 0, z + 0.03))
    put(p, ico(0.02, 1), PERI, "glass", T(-0.15, 0, z + 0.07), smooth=False)
    put(p, lathe([(0, 0), (0.04, 0), (0.045, 0.01), (0.012, 0.03), (0.012, 0.1), (0.05, 0.12), (0.06, 0.18), (0, 0.17)], 10),
          (0.9, 0.96, 1.0), "glass", T(0.2, 0, 0.887))
    # top: a gilt clock garniture and two pearl spheres
    put(p, lathe([(0, 0), (0.09, 0), (0.09, 0.03), (0.06, 0.05), (0.07, 0.18), (0.04, 0.22), (0, 0.24)], 12), GOLD, "gold", T(0.05, 0, 1.267))
    put(p, disc(0.045, 12, 0.0), WHITE, "matte", T(0.05, 0.068, 1.39) @ R("X", -88))
    for x in (-0.25, 0.28):
        put(p, ico(0.04, 1), [PERI, ROSE][x > 0], "pearl", T(x, 0.02, 1.307))


def armoire_ivory(p, size, c):
    w, h, d = 1.56, 2.5, 0.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            bun(p, sx * (w / 2 - 0.08), sy * (d / 2 - 0.08), 0.06)
    put(p, box(w + 0.04, d + 0.04, 0.1, bevel=0.025), c, "pearl", T(0, 0, 0.12))
    gilt_edge(p, w + 0.04, d + 0.04, 0.17, 0.008)
    put(p, box(w, d, 2.06, bevel=0.03), c, "pearl", T(0, 0, 0.17 + 1.03))
    yf = d / 2
    dw = w / 2 - 0.07
    rng = random.Random(1501)
    for sx in (-1, 1):
        x = sx * (dw / 2 + 0.04)
        put(p, box(dw, 0.025, 1.92, bevel=0.012), lighter(c, 0.05), "pearl", T(x, yf + 0.012, 0.26 + 0.96))
        up = arched_outline(dw - 0.16, 1.06, 12, 0.22)
        put(p, slab(up, 0.02), lighter(c, 0.1), "pearl", T(x, yf + 0.03, 0.95))
        put(p, frame_ring(up, 0.014, 0.02), GOLD, "gold", T(x, yf + 0.035, 0.95))
        lo = [(-(dw - 0.16) / 2, 0), ((dw - 0.16) / 2, 0), ((dw - 0.16) / 2, 0.5), (-(dw - 0.16) / 2, 0.5)]
        put(p, slab(lo, 0.02), lighter(c, 0.1), "pearl", T(x, yf + 0.03, 0.34))
        put(p, frame_ring(lo, 0.014, 0.02), GOLD, "gold", T(x, yf + 0.035, 0.34))
        # carved gilt garland swagged across the arch, hanging tails and a rose knot
        sw = [(x - 0.22 + 0.44 * i / 8, yf + 0.05, 1.83 - 0.12 * math.sin(math.pi * i / 8)) for i in range(9)]
        put(p, tube(sw, [0.012, 0.018, 0.024, 0.026, 0.028, 0.026, 0.024, 0.018, 0.012], 5), GOLD, "gold")
        for i in (1, 3, 5, 7):
            px, py, pz = sw[i]
            put(p, leaf(0.06, 0.03), GOLD, "gold", T(px, py + 0.01, pz) @ R("Y", 60 if i < 4 else 120) @ R("X", -90))
        for i in (2, 4, 6):
            px, py, pz = sw[i]
            rose(p, (px, py + 0.015, pz), 0.035, GOLD, rng, R("X", -90), "gold", 1, 6)
        for ex in (-0.22, 0.22):
            put(p, tube([(x + ex, yf + 0.05, 1.84), (x + ex * 1.05, yf + 0.05, 1.7), (x + ex, yf + 0.05, 1.56)], [0.014, 0.012, 0.006], 4), GOLD, "gold")
        rose(p, (x, yf + 0.05, 0.6), 0.055, GOLD, rng, R("X", -90), "gold", 2, 5)
        leaf_fan(p, x, yf + 0.04, 0.6, 4, 0.09, -30, 210, GOLD, "gold")
        pull(p, x - sx * (dw / 2 - 0.05), yf + 0.025, 1.15, 0.018)
    put(p, box(0.06, 0.03, 1.92, bevel=0.01), GOLD, "gold", T(0, yf + 0.02, 0.26 + 0.96))
    put(p, lathe([(0, 0), (0.04, 0.0), (0.03, 0.04), (0.0, 0.05)], 8), GOLD, "gold", T(0, yf + 0.03, 1.2) @ R("X", -90) @ S(1, 1.6, 1))
    # side panel mouldings
    for sx in (-1, 1):
        sp = [(-(d - 0.2) / 2, 0), ((d - 0.2) / 2, 0), ((d - 0.2) / 2, 1.6), (-(d - 0.2) / 2, 1.6)]
        put(p, frame_ring(sp, 0.012, 0.02), GOLD, "gold", T(sx * (w / 2 + 0.005), 0, 0.4) @ R("Z", 90))
    # crown cornice and pierced bonnet with crest
    put(p, box(w + 0.08, d + 0.06, 0.08, bevel=0.02), c, "pearl", T(0, 0, 2.27))
    put(p, box(w + 0.16, d + 0.1, 0.06, bevel=0.02), lighter(c, 0.05), "pearl", T(0, 0, 2.34))
    gilt_edge(p, w + 0.08, d + 0.06, 2.23, 0.01)
    gilt_edge(p, w + 0.16, d + 0.1, 2.31, 0.01)
    bon = arched_outline(0.8, 0.13, 12, 0.13)
    put(p, slab(bon, 0.06), c, "pearl", T(0, yf - 0.02, 2.37))
    put(p, tube([(x_, 0, z_) for x_, z_ in bon[2:]], 0.01, 4), GOLD, "gold", T(0, yf + 0.012, 2.37))
    crest_lite(p, 0, yf + 0.0, 2.38, 0.18)
    for sx in (-1, 1):
        put(p, lathe([(0, 0), (0.04, 0.01), (0.045, 0.05), (0.02, 0.08), (0, 0.13)], 8), GOLD, "gold", T(sx * (w / 2), yf - 0.02, 2.37))


def vanity_marble(p, size, c):
    w, h, d = 1.35, 0.86, 0.56
    body = IVORY
    pw = 0.42
    for sx in (-1, 1):
        cx = sx * (w / 2 - pw / 2 - 0.01)
        for ox in (-1, 1):
            for oy in (-1, 1):
                bun(p, cx + ox * (pw / 2 - 0.05), oy * (d / 2 - 0.06), 0.04)
        put(p, box(pw, d - 0.02, 0.72, bevel=0.02), body, "pearl", T(cx, 0, 0.06 + 0.36))
        for k, (z, hh) in enumerate(((0.66, 0.16), (0.46, 0.2), (0.22, 0.24))):
            drawer(p, cx, (d - 0.02) / 2, z, pw - 0.05, hh - 0.02, lighter(body, 0.05), 1, finish="pearl")
            put(p, frame_ring([(-(pw - 0.12) / 2, 0), ((pw - 0.12) / 2, 0), ((pw - 0.12) / 2, hh - 0.08), (-(pw - 0.12) / 2, hh - 0.08)],
                             0.004, 0.004), GOLD, "gold", T(cx, (d - 0.02) / 2 + 0.024, z - (hh - 0.08) / 2))
        for ox in (-1, 1):
            put(p, tube([(cx + ox * pw / 2, d / 2 - 0.01, 0.1), (cx + ox * pw / 2, d / 2 - 0.01, 0.78)], 0.009, 4), GOLD, "gold")
    # kneehole: recessed back, central frieze drawer and a scalloped arch apron
    kw = w - 2 * pw - 0.02
    put(p, box(kw, 0.03, 0.62, seg=1), darker(body, 0.06), "pearl", T(0, -d / 2 + 0.06, 0.37))
    put(p, box(kw, d - 0.04, 0.12, bevel=0.012), body, "pearl", T(0, 0, 0.73))
    drawer(p, 0, (d - 0.04) / 2, 0.735, kw - 0.06, 0.08, lighter(body, 0.05), 1, finish="pearl")
    arch = [(-kw / 2, 0.0), (kw / 2, 0.0)]
    for i in range(11):
        x = kw / 2 - kw * i / 10
        arch.append((x, -0.06 * math.cos(math.pi * x / kw) - 0.02 * abs(math.sin(3 * math.pi * x / kw))))
    put(p, slab(arch, 0.025, 0.004), body, "pearl", T(0, d / 2 - 0.04, 0.672))
    put(p, tube([(x, 0, z) for x, z in arch[2:]], 0.006, 4), GOLD, "gold", T(0, d / 2 - 0.025, 0.672))
    crest(p, 0, d / 2 - 0.02, 0.6, 0.08)
    put(p, box(w + 0.03, d + 0.03, 0.04, bevel=0.012), MARBLE_PINK, "pearl", T(0, 0, h - 0.02))
    gilt_edge(p, w + 0.03, d + 0.03, h - 0.042, 0.009)


def library_stack(p, size, c):
    w, h, d = 2.86, 2.5, 0.84
    put(p, box(w, d, 0.12, bevel=0.02), darker(c, 0.1), "satin", T(0, 0, 0.06))
    shelves = (0.12, 0.64, 1.16, 1.68, 2.2)
    for z in shelves:
        put(p, box(w - 0.16, d - 0.02, 0.03, seg=1), c, "satin", T(0, 0, z + 0.015), smooth=False)
    put(p, box(w - 0.16, 0.03, 2.1, seg=1), mix(SOFT_BLUE, PEARL, 0.35), "satin", T(0, 0, 1.17), smooth=False)
    for sy in (-1, 1):
        put(p, box(0.06, 0.04, 2.1, seg=1), c, "satin", T(0, sy * (d / 2 - 0.03), 1.17), smooth=False)
        put(p, box(0.012, 0.01, 1.9, seg=1), GOLD, "gold", T(0, sy * (d / 2 - 0.008), 1.17), smooth=False)
        for z in shelves[1:-1]:
            put(p, box(w - 0.16, 0.01, 0.012, seg=1), GOLD, "gold", T(0, sy * (d / 2 - 0.01), z + 0.024), smooth=False)
    # carved end panels: raised arched panel, gilt moulding and a rose cartouche
    rng = random.Random(1601)
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.05)
        put(p, box(0.1, d, 2.12, bevel=0.02), c, "satin", T(x, 0, 1.18))
        ap = arched_outline(d - 0.28, 1.6, 10, 0.24)
        put(p, slab(ap, 0.02), lighter(c, 0.06), "satin", T(x + sx * 0.055, 0, 0.32) @ R("Z", 90))
        put(p, tube([(u, 0, v) for u, v in ap], 0.012, 4, closed=True), GOLD, "gold", T(x + sx * 0.062, 0, 0.32) @ R("Z", 90))
        rose(p, (x + sx * 0.07, 0, 2.06), 0.06, GOLD, rng, R("Y", sx * 90), "gold", 1, 6)
        for a in (-40, 40, 140, 220):
            put(p, leaf(0.09, 0.045), GOLD, "gold", T(x + sx * 0.066, 0, 2.06) @ R("Z", 90 * sx) @ R("Y", -a) @ R("X", -90))
    for side, m in ((1, None), (-1, R("Z", 180))):
        for z in shelves[:-1]:
            for x0, x1 in ((-w / 2 + 0.1, -0.03), (0.03, w / 2 - 0.1)):
                if (z, x0 < 0, side) in ((0.64, True, 1), (1.68, False, 1), (1.16, False, -1), (0.12, True, -1)):
                    # a display gap: books lying flat under a little curio
                    xs_ = x1 - 0.4 if x0 < 0 else x0 + 0.4
                    book_run(p, x0 if x0 < 0 else xs_, xs_ if x0 < 0 else x1, d / 2 - 0.03, z + 0.03, 0.28, 0.32, 0.43, rng,
                             0.06, 0.12, m=m, gild=0.2, label=0.0, lean=False)
                    cx = (xs_ + (x1 if x0 < 0 else x0)) / 2
                    mm = m if m is not None else Matrix.Identity(4)
                    for k, col in enumerate((rng.choice(BOOKS2), rng.choice(BOOKS2), rng.choice(BOOKS2))):
                        put(p, box(0.3 - 0.03 * k, 0.22, 0.045, seg=1), col, "satin",
                            mm @ T(cx, d / 2 - 0.16, z + 0.055 + 0.046 * k) @ R("Z", 5 * k - 4), smooth=False)
                    curio = (z * 10 + side) % 3
                    top = z + 0.17
                    if curio < 1:
                        put(p, ico(0.07, 1), [PERI, MINT][side > 0], "pearl", mm @ T(cx, d / 2 - 0.16, top + 0.07))
                        put(p, torus(0.08, 0.006, 10, 3), GOLD, "gold", mm @ T(cx, d / 2 - 0.16, top + 0.07) @ R("X", 70))
                    elif curio < 2:
                        put(p, lathe([(0, 0), (0.04, 0), (0.06, 0.08), (0.03, 0.15), (0.045, 0.18)], 8), ROSE, "pearl",
                            mm @ T(cx, d / 2 - 0.16, top))
                    else:
                        put(p, lathe([(0, 0), (0.05, 0), (0.05, 0.02), (0.015, 0.04), (0.02, 0.1), (0.04, 0.16), (0, 0.2)], 8),
                            GOLD, "gold", mm @ T(cx, d / 2 - 0.16, top))
                else:
                    book_run(p, x0, x1, d / 2 - 0.03, z + 0.03, 0.28, 0.32, 0.43, rng, 0.06, 0.12, m=m, gild=0.2, label=0.0,
                             lean=(z == 1.16))
    # crown cornice with a cresting on both faces
    put(p, box(w + 0.06, d + 0.06, 0.08, bevel=0.02), c, "satin", T(0, 0, 2.27))
    put(p, box(w + 0.12, d + 0.12, 0.06, bevel=0.02), lighter(c, 0.05), "satin", T(0, 0, 2.34))
    gilt_edge(p, w + 0.06, d + 0.06, 2.235, 0.01)
    for m in (Matrix.Identity(4), R("Z", 180)):
        ped = arched_outline(0.7, 0.13, 10, 0.13)
        put(p, slab(ped, 0.05), c, "satin", m @ T(0, d / 2 + 0.02, 2.37))
        rose(p, (0, d / 2 + 0.06, 2.43), 0.05, GOLD, rng, m @ R("X", -90), "gold", 1, 6)
        for a in (-20, 20, 160, 200):
            put(p, leaf(0.1, 0.045), GOLD, "gold", m @ T(0, d / 2 + 0.05, 2.43) @ R("Y", -a) @ R("X", -90))


def library_mezzanine(p, size, c):
    W, H, D = 4.0, 4.3, 1.1
    yb = -D / 2
    rng = random.Random(1701)
    back = mix(SOFT_BLUE, PEARL, 0.35)
    # lower bookcase: 0.5 deep, to 2.5 m, four bays
    ld = 0.5
    lf = yb + ld
    put(p, box(W, ld, 0.1, seg=1), darker(c, 0.1), "satin", T(0, yb + ld / 2, 0.05))
    put(p, box(W, 0.02, 2.4, seg=1), back, "satin", T(0, yb + 0.01, 1.3))
    bays = [(-W / 2 + W * k / 4, -W / 2 + W * (k + 1) / 4) for k in range(4)]
    for k in range(5):
        x = -W / 2 + 0.04 + (W - 0.08) * k / 4
        put(p, box(0.08, ld, 2.4, seg=1), c, "satin", T(x, yb + ld / 2, 1.3))
        put(p, box(0.1, 0.03, 2.3, seg=1), lighter(c, 0.06), "satin", T(x, lf + 0.01, 1.25))
        put(p, box(0.02, 0.012, 1.9, seg=1), GOLD, "gold", T(x, lf + 0.03, 1.25), smooth=False)
    lower = (0.1, 0.68, 1.26, 1.84)
    for z in lower[1:] + (2.42,):
        put(p, box(W - 0.08, ld - 0.02, 0.03, seg=1), c, "satin", T(0, yb + ld / 2, z - 0.015))
    for z in lower:
        for x0, x1 in bays:
            book_run(p, x0 + 0.09, x1 - 0.05, lf - 0.04, z, 0.3, 0.38, 0.52, rng, 0.065, 0.13, gild=0.2, label=0.0,
                     lean=(z == 1.26))
    # gallery walkway floor at 2.6 m on curved brackets
    put(p, box(W, D, 0.12, seg=1), c, "satin", T(0, 0, 2.54))
    put(p, box(W, 0.012, 0.05, seg=1), GOLD, "gold", T(0, D / 2 + 0.006, 2.54), smooth=False)
    prof = [(lf, 2.48), (lf, 2.1), (lf + 0.06, 2.12), (lf + 0.12, 2.24), (lf + 0.22, 2.36), (lf + 0.36, 2.43), (D / 2 - 0.02, 2.46),
            (D / 2 - 0.02, 2.48)]
    for k in range(5):
        x = -W / 2 + 0.04 + (W - 0.08) * k / 4
        x = max(-W / 2 + 0.06, min(W / 2 - 0.06, x))
        put(p, slab([(y, z) for y, z in prof], 0.08), c, "satin", T(x, 0, 0) @ R("Z", 90) @ S(-1, 1, 1))
        rose(p, (x, lf + 0.07, 2.2), 0.035, GOLD, rng, R("X", -60), "gold", 1, 5)
    # gilt balustrade along the front edge
    ry = D / 2 - 0.05
    put(p, tube([(-W / 2 + 0.02, ry, 3.55), (W / 2 - 0.02, ry, 3.55)], 0.03, 6), GOLD, "gold")
    put(p, tube([(-W / 2 + 0.02, ry, 2.64), (W / 2 - 0.02, ry, 2.64)], 0.02, 4), GOLD, "gold")
    for k in range(5):
        x = -W / 2 + 0.04 + (W - 0.08) * k / 4
        put(p, box(0.07, 0.07, 0.95, seg=1), GOLD, "gold", T(x, ry, 3.08), smooth=False)
        knob_lite(p, x, ry, 3.6, 0.045)
    for k in range(4):
        x0 = -W / 2 + 0.04 + (W - 0.08) * k / 4
        for j in range(1, 4):
            x = x0 + (W - 0.08) / 4 * j / 4
            put(p, lathe([(0.016, 0), (0.03, 0.2), (0.014, 0.55), (0.022, 0.89)], 5, False, False), GOLD, "gold", T(x, ry, 2.65))
    # upper bookcase behind the walkway, to 4.3 m
    ud = 0.4
    uf = yb + ud
    put(p, box(W, 0.02, 1.6, seg=1), back, "satin", T(0, yb + 0.01, 3.4))
    for k in range(5):
        x = -W / 2 + 0.04 + (W - 0.08) * k / 4
        put(p, box(0.08, ud, 1.62, seg=1), c, "satin", T(x, yb + ud / 2, 3.41))
    upper = (2.62, 3.17, 3.72)
    for z in upper[1:] + (4.24,):
        put(p, box(W - 0.08, ud - 0.02, 0.03, seg=1), c, "satin", T(0, yb + ud / 2, z - 0.015))
    for z in upper:
        for x0, x1 in bays:
            book_run(p, x0 + 0.09, x1 - 0.05, uf - 0.03, z, 0.26, 0.36, 0.5, rng, 0.065, 0.13, gild=0.2, label=0.0,
                     lean=False)
    put(p, box(W, ud + 0.06, 0.07, seg=1), c, "satin", T(0, yb + ud / 2 + 0.03, 4.23))
    put(p, box(W, 0.012, 0.03, seg=1), GOLD, "gold", T(0, uf + 0.066, 4.23), smooth=False)
    for x in (-1.0, 1.0):
        rose(p, (x, uf + 0.08, 4.23), 0.045, GOLD, rng, R("X", -90), "gold", 1, 6)
        for a in (-15, 15, 165, 195):
            put(p, leaf(0.12, 0.05), GOLD, "gold", T(x, uf + 0.07, 4.23) @ R("Y", -a) @ R("X", -90))


def spiral_stair(p, size, c):
    rise, n_t = 0.2, 12
    step = 27.0
    r_out = 0.9
    a0 = 90.0 - step / 2
    tread = mix(OAK, CREAM, 0.25)
    # newel with gilt collars
    prof = [(0.11, 0), (0.12, 0.05), (0.075, 0.1)]
    for z in (0.9, 1.8, 2.7):
        prof += [(0.07, z - 0.04), (0.09, z), (0.07, z + 0.04)]
    prof += [(0.07, 3.5), (0.09, 3.55)]
    put(p, lathe(prof, 8), c, "gold")
    put(p, cyl(0.2, 0.03, 14), c, "gold")
    for k in range(n_t):
        a = a0 + k * step
        z = (k + 1) * rise
        pts = [(0.06 * math.cos(math.radians(a)), 0.06 * math.sin(math.radians(a)))]
        for j in range(5):
            aa = math.radians(a + (step + 3) * j / 4)
            pts.append((r_out * math.cos(aa), r_out * math.sin(aa)))
        pts.append((0.06 * math.cos(math.radians(a + step + 3)), 0.06 * math.sin(math.radians(a + step + 3))))
        put(p, plan_slab(pts, z - 0.05, 0.05), tread, "satin")
        ra = math.radians(a)
        put(p, tube([(0.08 * math.cos(ra), 0.08 * math.sin(ra), z - 0.01), ((r_out - 0.01) * math.cos(ra), (r_out - 0.01) * math.sin(ra), z - 0.01)],
                   0.012, 4), c, "gold")
        # bracket under the tread and two balusters
        put(p, tube([(0.1 * math.cos(ra + 0.2), 0.1 * math.sin(ra + 0.2), z - 0.2),
                    (0.5 * math.cos(ra + 0.25), 0.5 * math.sin(ra + 0.25), z - 0.12),
                    (0.8 * math.cos(ra + 0.25), 0.8 * math.sin(ra + 0.25), z - 0.06)], [0.02, 0.014, 0.01], 4), c, "gold")
        for f in (0.25, 0.75):
            aa = math.radians(a + step * f)
            zb = z
            zt = rise * (1 + (a + step * f - a0) / step) + 0.9
            put(p, cyl(0.01, zt - zb, 4, caps=False), c, "gold", T((r_out - 0.06) * math.cos(aa), (r_out - 0.06) * math.sin(aa), zb))
    # helical gilt handrail, from a volute at the foot round the landing
    rail = []
    a_end = a0 + n_t * step + 100
    n_r = 34
    for i in range(n_r + 1):
        a = a0 + (a_end - a0) * i / n_r
        if a <= a0 + n_t * step:
            z = rise * (1 + (a - a0) / step) + 0.9
        else:
            z = rise * (n_t + 1) + 0.95
        rail.append(((r_out - 0.06) * math.cos(math.radians(a)), (r_out - 0.06) * math.sin(math.radians(a)), z))
    put(p, tube(rail, 0.03, 5), c, "gold")
    sa = math.radians(a0)
    put(p, scroll_lite(0.09, 1.3, 10, 0.022, 5), c, "gold",
          T((r_out - 0.06) * math.cos(sa), (r_out - 0.06) * math.sin(sa), rise + 0.9) @ R("Z", a0 + 90) @ R("Y", 90) @ R("Z", 0))
    put(p, cyl(0.025, 0.95, 6), c, "gold", T((r_out - 0.06) * math.cos(sa), (r_out - 0.06) * math.sin(sa), 0.0))
    # landing at 2.6 m with balusters along its outer arc
    la = a0 + n_t * step
    zl = rise * (n_t + 1)
    pts = [(0, 0)]
    for j in range(9):
        aa = math.radians(la + 100 * j / 8)
        pts.append((r_out * math.cos(aa), r_out * math.sin(aa)))
    put(p, plan_slab(pts, zl - 0.06, 0.06), tread, "satin")
    put(p, tube([(r_out * math.cos(math.radians(la + 100 * j / 8)), r_out * math.sin(math.radians(la + 100 * j / 8)), zl - 0.03)
                for j in range(9)], 0.02, 4), c, "gold")
    for j in range(1, 8):
        aa = math.radians(la + 100 * j / 8)
        put(p, cyl(0.01, 0.95, 4, caps=False), c, "gold", T((r_out - 0.06) * math.cos(aa), (r_out - 0.06) * math.sin(aa), zl))
    # newel cap: gilt urn, a glowing fae-light orb and a spire
    put(p, lathe([(0.09, 3.55), (0.13, 3.62), (0.1, 3.72), (0.06, 3.78), (0.08, 3.84)], 12), c, "gold")
    for i in range(6):
        put(p, leaf(0.12, 0.05), c, "gold", R("Z", 60 * i) @ T(0.05, 0, 3.8) @ R("Y", -55))
    put(p, sphere(0.09, 12, 8), (1.0, 0.92, 0.75), "glow", T(0, 0, 3.98))
    put(p, lathe([(0.03, 4.06), (0.05, 4.09), (0.012, 4.15), (0.0, 4.3)], 8), c, "gold")


def colonnade_screen(p, size, c):
    W, H = 4.2, 4.4
    for sx in (-1, 1):
        x = sx * (W / 2 - 0.35)
        put(p, box(0.7, 0.7, 0.32, bevel=0.03, seg=1), c, "pearl", T(x, 0, 0.16))
        put(p, box(0.66, 0.66, 0.05, bevel=0.015), lighter(c, 0.06), "pearl", T(x, 0, 0.345))
        put(p, lathe([(0.31, 0.37), (0.32, 0.41), (0.27, 0.46), (0.28, 0.49), (0.26, 0.52)], 12, False, False), c, "pearl", T(x, 0, 0))
        put(p, torus(0.265, 0.012, 14, 3), GOLD, "gold", T(x, 0, 0.5))
        put(p, lathe([(0.255, 0.52), (0.26, 1.3), (0.25, 2.3), (0.235, 3.1), (0.22, 3.55)], 14, False, False), c, "pearl", T(x, 0, 0))
        for i in range(8):
            a = 2 * math.pi * (i + 0.5) / 8
            put(p, tube([(0.256 * math.cos(a), 0.256 * math.sin(a), 0.7), (0.248 * math.cos(a), 0.248 * math.sin(a), 2.3),
                        (0.226 * math.cos(a), 0.226 * math.sin(a), 3.4)], 0.008, 3), lighter(c, 0.12), "pearl", T(x, 0, 0))
        put(p, torus(0.225, 0.014, 14, 3), GOLD, "gold", T(x, 0, 3.56))
        # Ionic capital: echinus, gilt egg band, rolled volutes and abacus
        put(p, lathe([(0.22, 3.57), (0.27, 3.62), (0.29, 3.68), (0.0, 3.68)], 16, False, True), c, "pearl", T(x, 0, 0))
        for sx2 in (-1, 1):
            put(p, cyl(0.085, 0.56, 12), lighter(c, 0.04), "pearl", T(x + sx2 * 0.24, -0.28, 3.62) @ R("X", -90))
            for sy in (-1, 1):
                put(p, scroll_lite(0.075, 1.6, 9, 0.013, 3), GOLD, "gold",
                      T(x + sx2 * 0.24, sy * 0.285, 3.62) @ (R("Z", 180) if sy < 0 else T()) @ S(sx2, 1, 1))
        put(p, box(0.66, 0.62, 0.06, bevel=0.012), c, "pearl", T(x, 0, 3.74))
    # entablature: two-fascia architrave, gilt fillet, frieze with cartouches, cornice
    put(p, box(W - 0.1, 0.5, 0.12, bevel=0.01), c, "pearl", T(0, 0, 3.83))
    put(p, box(W - 0.06, 0.54, 0.1, bevel=0.01), lighter(c, 0.04), "pearl", T(0, 0, 3.94))
    put(p, box(W - 0.04, 0.57, 0.035, seg=1), GOLD, "gold", T(0, 0, 4.005))
    put(p, box(W - 0.08, 0.5, 0.2, bevel=0.01), c, "pearl", T(0, 0, 4.12))
    for sy in (-1, 1):
        mm = R("Z", 0 if sy > 0 else 180)
        put(p, lathe([(0, 0), (0.12, 0.0), (0.1, 0.012), (0, 0.016)], 12), GOLD, "gold", mm @ T(0, 0.25, 4.12) @ R("X", -90) @ S(1.8, 1, 1))
        for sx in (-1, 1):
            put(p, scroll_lite(0.07, 1.3, 8, 0.011, 3), GOLD, "gold", mm @ T(sx * 0.36, 0.255, 4.12) @ S(sx, 1, 1))
            for k in range(3):
                put(p, leaf(0.12, 0.05), GOLD, "gold", mm @ T(sx * (0.7 + 0.35 * k), 0.255, 4.12) @ R("Y", 0 if sx > 0 else 180) @ R("X", -90))
    put(p, box(W, 0.66, 0.08, bevel=0.015), lighter(c, 0.05), "pearl", T(0, 0, 4.26))
    put(p, box(W, 0.7, 0.06, bevel=0.015), c, "pearl", T(0, 0, 4.33))
    put(p, box(W - 0.02, 0.68, 0.012, seg=1), GOLD, "gold", T(0, 0, 4.364), smooth=False)
    for sy in (-1, 1):
        for k in range(13):
            x = -W / 2 + 0.1 + (W - 0.2) * k / 12
            put(p, box(0.06, 0.04, 0.05, seg=1), lighter(c, 0.1), "pearl", T(x, sy * 0.315, 4.2), smooth=False)
    put(p, box(W, 0.7, 0.03, seg=1), c, "pearl", T(0, 0, 4.385))


def drawer_chest_apothecary(p, size, c):
    w, h, d = 1.5, 1.05, 0.5
    for sx in (-1, 1):
        for sy in (-1, 1):
            bun(p, sx * (w / 2 - 0.08), sy * (d / 2 - 0.08), 0.045)
    put(p, box(w, d, 0.08, bevel=0.02), darker(c, 0.12), "satin", T(0, 0, 0.09))
    put(p, box(w - 0.04, d - 0.04, 0.86, bevel=0.02), c, "satin", T(0, 0, 0.13 + 0.43))
    put(p, box(w + 0.02, d + 0.02, 0.05, bevel=0.015), lighter(c, 0.1), "satin", T(0, 0, h - 0.025))
    gilt_edge(p, w + 0.02, d + 0.02, h - 0.052, 0.008)
    gilt_edge(p, w, d, 0.13, 0.008)
    yf = (d - 0.04) / 2
    dw, dh = (w - 0.14) / 6, (0.8) / 4
    tones = [lighter(c, 0.12), lighter(c, 0.05)]
    for row in range(4):
        for col in range(6):
            x = -w / 2 + 0.07 + dw / 2 + col * dw
            z = 0.16 + dh / 2 + row * dh
            put(p, box(dw - 0.02, 0.02, dh - 0.02, bevel=0.005, seg=1), tones[(row + col) % 2], "satin", T(x, yf + 0.01, z))
            put(p, box(0.09, 0.006, 0.04, seg=1), CANVAS, "matte", T(x, yf + 0.022, z + 0.04), smooth=False)
            put(p, box(0.1, 0.004, 0.006, seg=1), GOLD, "gold", T(x, yf + 0.022, z + 0.063), smooth=False)
            put(p, lathe([(0.012, 0), (0.022, 0.01), (0.02, 0.018), (0, 0.02)], 6), GOLD, "gold", T(x, yf + 0.02, z - 0.03) @ R("X", -90))
    for sx in (-1, 1):
        put(p, tube([(sx * (w / 2 - 0.02), yf + 0.005, 0.15), (sx * (w / 2 - 0.02), yf + 0.005, 0.98)], 0.01, 4), GOLD, "gold")


def medicine_cabinet_wall(p, size, c):
    w, h, d = 0.92, 1.2, 0.26
    yf = d / 2
    put(p, box(w + 0.04, d + 0.03, 0.05, bevel=0.012), c, "pearl", T(0, 0, 0.025))
    put(p, box(w, d, 1.0, bevel=0.015), c, "pearl", T(0, 0, 0.55))
    put(p, box(w - 0.06, 0.01, 0.8, seg=1), mix(SOFT_BLUE, WHITE, 0.4), "satin", T(0, yf - 0.03, 0.62))
    for z in (0.44, 0.7, 0.96):
        put(p, box(w - 0.06, d - 0.06, 0.015, seg=1), lighter(c, 0.05), "pearl", T(0, 0, z - 0.008))
    rng = random.Random(1801)
    cols = [PERI, ROSE, MINT, BUTTER, LILAC, mix(SAGE_LIGHT, WHITE, 0.2), BLUSH]
    for z in (0.22, 0.44, 0.7):
        x = -w / 2 + 0.08
        while x < w / 2 - 0.08:
            r = rng.uniform(0.028, 0.045)
            hh = rng.uniform(0.1, 0.19)
            col = rng.choice(cols)
            shape = rng.randrange(3)
            if shape == 0:
                prof = [(0, 0), (r, 0), (r, hh * 0.7), (r * 0.4, hh * 0.85), (r * 0.4, hh)]
            elif shape == 1:
                prof = [(0, 0), (r * 0.8, 0), (r * 1.1, hh * 0.35), (r * 0.9, hh * 0.6), (r * 0.35, hh * 0.8), (r * 0.35, hh)]
            else:
                prof = [(0, 0), (r, 0), (r * 1.05, hh * 0.9), (r * 0.8, hh)]
            put(p, lathe(prof, 6, True, False), col, "glass", T(x + r, 0.0, z))
            put(p, lathe([(r * 0.45, 0), (r * 0.45, 0.025), (0, 0.03)], 5), [OAK, GOLD][shape == 1], "satin" if shape != 1 else "gold",
                T(x + r, 0.0, z + hh))
            if rng.random() < 0.35:
                put(p, box(r * 1.2, 0.002, hh * 0.25, seg=1), CANVAS, "matte", T(x + r, r + 0.002, z + hh * 0.4), smooth=False)
            x += 2 * r + 0.025
    # lower drawer
    drawer(p, 0, yf, 0.12, w - 0.08, 0.12, lighter(c, 0.06), 2, finish="pearl")
    # two glazed doors
    zc, dh = 0.62, 0.8
    dw = (w - 0.04) / 2
    for sx in (-1, 1):
        x = sx * dw / 2
        put(p, box(dw - 0.06, 0.005, dh - 0.06, seg=1), (0.9, 0.96, 1.0), "glass", T(x, yf + 0.008, zc))
        for ox in (-1, 1):
            put(p, box(0.035, 0.025, dh), lighter(c, 0.06), "pearl", T(x + ox * (dw / 2 - 0.018), yf + 0.012, zc), smooth=False)
        for oz in (-1, 1):
            put(p, box(dw, 0.025, 0.035), lighter(c, 0.06), "pearl", T(x, yf + 0.012, zc + oz * (dh / 2 - 0.018)), smooth=False)
        put(p, box(0.008, 0.01, dh - 0.06, seg=1), GOLD, "gold", T(x, yf + 0.014, zc), smooth=False)
        pull(p, x - sx * (dw / 2 - 0.04), yf + 0.024, zc, 0.012)
    # arched pediment with a painted rose cartouche
    ped = arched_outline(w + 0.04, 0.15, 12, 0.15)
    put(p, box(w + 0.06, d + 0.04, 0.04, bevel=0.012), c, "pearl", T(0, 0, 1.07))
    put(p, slab(ped, d - 0.02), c, "pearl", T(0, 0, 1.09))
    put(p, tube([(x, 0, z) for x, z in ped[2:]], 0.008, 4), GOLD, "gold", T(0, d / 2 - 0.0, 1.09))
    put(p, slab(oval_outline(0.16, 0.09, 14), 0.006), BLUSH, "matte", T(0, d / 2 - 0.004, 1.1))
    bloom(p, (0, d / 2 + 0.004, 1.145), 0.03, ROSE, 2, 5, rng, "pearl", tilt=R("X", -90))
    for sx in (-1, 1):
        put(p, leaf(0.04, 0.02), LEAF, "leaf", T(sx * 0.035, d / 2 + 0.002, 1.14) @ R("Y", 0 if sx > 0 else 180) @ R("X", -90))


def servants_bell_board(p, size, c):
    w, h = 1.2, 0.8
    put(p, box(w - 0.04, 0.03, h - 0.04, bevel=0.012), mix(SOFT_BLUE, WHITE, 0.25), "satin", T(0, -0.04, h / 2))
    put(p, frame_ring([(-w / 2 + 0.02, 0.02), (w / 2 - 0.02, 0.02), (w / 2 - 0.02, h - 0.02), (-w / 2 + 0.02, h - 0.02)], 0.02, 0.03),
          c, "gold", T(0, -0.025, 0), smooth=False)
    # title cartouche
    put(p, slab(oval_outline(0.36, 0.09, 16), 0.008), IVORY, "matte", T(0, -0.02, h - 0.14))
    put(p, frame_ring(oval_outline(0.36, 0.09, 16), 0.006, 0.008), c, "gold", T(0, -0.016, h - 0.14))
    for k in range(5):
        put(p, box(0.04, 0.004, 0.006, seg=1), OAK_DARK, "matte", T(-0.1 + 0.05 * k, -0.014, h - 0.095), smooth=False)
    rng = random.Random(1901)
    for row, z in enumerate((0.52, 0.2)):
        for k in range(5):
            x = -0.44 + 0.22 * k + (0.0 if row == 0 else 0.0)
            # bracket, curled spring and the bell on its end
            put(p, box(0.02, 0.05, 0.02, seg=1), c, "gold", T(x, -0.005, z + 0.1))
            put(p, scroll_lite(0.04, 1.8, 10, 0.0045, 3), c, "gold", T(x, 0.035, z + 0.08) @ R("Z", 90))
            put(p, lathe([(0.0, 0), (0.046, 0), (0.04, 0.02), (0.024, 0.06), (0.012, 0.085), (0, 0.09)], 8, False, True), c, "gold",
                T(x, 0.06, z - 0.03) @ R("X", rng.uniform(-8, 8)))
            put(p, ico(0.01, 0), lighter(c, 0.2), "gold", T(x, 0.06, z - 0.035), smooth=False)
            put(p, box(0.13, 0.006, 0.035, seg=1), IVORY, "matte", T(x, -0.023, z - 0.08), smooth=False)
            put(p, box(0.07, 0.003, 0.005, seg=1), OAK_DARK, "matte", T(x, -0.019, z - 0.08), smooth=False)


def plate_rack_wall(p, size, c):
    w, h, d = 1.6, 1.0, 0.25
    yb = -d / 2
    put(p, box(w - 0.06, 0.015, h - 0.06, seg=1), mix(SOFT_BLUE, WHITE, 0.3), "satin", T(0, yb + 0.0075, h / 2))
    side = [(yb, 0.0), (d / 2, 0.0), (d / 2, 0.08), (yb + 0.16, 0.18), (yb + 0.14, 0.5), (yb + 0.12, 0.56), (yb + 0.12, 0.9),
            (yb + 0.16, 0.96), (yb + 0.08, 1.0), (yb, 1.0)]
    for sx in (-1, 1):
        put(p, slab(side, 0.035), c, "satin", T(sx * (w / 2 - 0.0175), 0, 0) @ R("Z", 90) @ S(-1, 1, 1))
    put(p, box(w - 0.04, d - 0.01, 0.03, bevel=0.008), c, "satin", T(0, 0.0, 0.065))
    put(p, box(w - 0.04, 0.14, 0.025, bevel=0.008), c, "satin", T(0, yb + 0.07, 0.5))
    put(p, box(w + 0.04, 0.17, 0.05, bevel=0.012), c, "satin", T(0, yb + 0.085, h - 0.025))
    scal = [(-w / 2, 0.0), (w / 2, 0.0)]
    for i in range(17):
        x = w / 2 - w * i / 16
        scal.append((x, -0.05 + 0.03 * abs(math.cos(math.pi * x * 8 / w))))
    put(p, slab(scal, 0.015, 0.0), c, "satin", T(0, yb + 0.165, h - 0.05))
    for z, y in ((0.13, d / 2 - 0.02), (0.56, yb + 0.13)):
        put(p, tube([(-w / 2 + 0.03, y, z), (w / 2 - 0.03, y, z)], 0.012, 5), c, "satin")
    rng = random.Random(2001)
    patterns = [(DELFT, ROSE), (ROSE, DELFT), (mix(MINT, SAGE, 0.4), ROSE), (PERI, BUTTER), (ROSE, MINT), (DELFT, BLUSH)]

    def plate(cx, cz, r, ybase, k):
        lean = 12.0
        m = T(cx, ybase, cz) @ R("X", -90 + lean)
        put(p, lathe([(0, 0), (r * 0.6, 0), (r, 0.016), (r * 0.96, 0.02), (r * 0.6, 0.011), (0, 0.011)], 12),
            PORCELAIN, "pearl", m)
        rim, mid = patterns[k % len(patterns)]
        put(p, lathe([(r * 0.94, 0.0195), (r * 0.8, 0.0175)], 12, False, False), rim, "pearl", m)
        if k % 2 == 0:
            flat_flower(p, m @ T(0, 0, 0.0125), r * 0.32, mid, BUTTER, 5, "pearl")
        else:
            put(p, lathe([(r * 0.4, 0.0125), (r * 0.3, 0.0125)], 10, False, False), mid, "pearl", m)
            flat_flower(p, m @ T(0, 0, 0.0127), r * 0.18, mid, WHITE, 6, "pearl")
        for j in range(3):
            a = 2 * math.pi * j / 3 + 0.4 + k
            put(p, leaf(r * 0.22, r * 0.1), mix(SAGE, rim, 0.3), "pearl",
                m @ T(r * 0.5 * math.cos(a), r * 0.5 * math.sin(a), 0.0128) @ R("Z", math.degrees(a)))

    for k in range(5):
        r = 0.135
        plate(-0.6 + 0.3 * k, 0.08 + r, r, 0.01, k)
    for k in range(6):
        r = 0.11
        plate(-0.625 + 0.25 * k, 0.515 + r, r, yb + 0.09, k + 3)
    for k in range(5):
        x = -0.5 + 0.25 * k
        put(p, tube([(x, yb + 0.12, 0.488), (x, yb + 0.13, 0.465), (x + 0.012, yb + 0.13, 0.455)], 0.004, 3), c, "gold")
        cup = [(0, 0), (0.025, 0), (0.035, 0.045), (0.038, 0.055)]
        mcup = T(x + 0.03, yb + 0.13, 0.385)
        put(p, lathe(cup, 8, True, False), PORCELAIN, "pearl", mcup)
        put(p, lathe([(0.0365, 0.035), (0.0375, 0.048)], 8, False, False), patterns[k][0], "pearl", mcup)
        put(p, torus(0.016, 0.004, 6, 3), PORCELAIN, "pearl", mcup @ T(-0.035, 0, 0.03) @ R("X", 90))


def wall_shelf_books(p, size, c):
    w, h, d = 1.2, 0.5, 0.25
    yb = -d / 2
    zt = 0.17
    put(p, box(w, d, 0.035, bevel=0.01), c, "satin", T(0, 0, zt - 0.0175))
    put(p, tube([(-w / 2 + 0.01, d / 2 - 0.004, zt - 0.03), (w / 2 - 0.01, d / 2 - 0.004, zt - 0.03)], 0.007, 4), GOLD, "gold")
    br = [(yb, 0.0), (yb + 0.03, 0.0), (yb + 0.05, 0.05), (yb + 0.1, 0.1), (yb + 0.17, 0.125), (yb + 0.22, 0.135), (yb + 0.22, 0.152),
          (yb, 0.152)]
    for sx in (-1, 1):
        x = sx * 0.4
        put(p, slab(br, 0.03, 0.006), c, "satin", T(x, 0, 0) @ R("Z", 90) @ S(-1, 1, 1))
        put(p, scroll(0.035, 1.3, 9, 0.006), GOLD, "gold", T(x + 0.017, yb + 0.07, 0.08) @ R("Z", 90))
        put(p, sphere(0.012, 6, 4), GOLD, "gold", T(x, yb + 0.03, 0.005))
    rng = random.Random(2101)
    book_run(p, -w / 2 + 0.06, 0.2, d / 2 - 0.04, zt, 0.17, 0.2, 0.28, rng, 0.03, 0.06, gild=0.4)
    put(p, lathe([(0, 0), (0.05, 0), (0.05, 0.02), (0.012, 0.03), (0.012, 0.13), (0.03, 0.16), (0, 0.17)], 8), GOLD, "gold",
          T(0.23, 0.0, zt) @ S(1, 0.6, 1))
    # two lying books, a pearl shell and a small trailing ivy pot
    for k, col in enumerate((PERI, BLUSH)):
        put(p, box(0.2 - 0.02 * k, 0.15, 0.035, bevel=0.004, seg=1), col, "satin", T(0.34, 0.0, zt + 0.018 + 0.036 * k) @ R("Z", 4 - 8 * k), smooth=False)
    put(p, lathe([(0, 0), (0.03, 0.01), (0.035, 0.03), (0.02, 0.05), (0, 0.06)], 8), BLUSH, "pearl", T(0.34, 0.0, zt + 0.075) @ R("Y", 70))
    px = 0.5
    put(p, lathe([(0, 0), (0.04, 0), (0.05, 0.08), (0.056, 0.095), (0.05, 0.1)], 10), ROSE, "pearl", T(px, 0.0, zt))
    put(p, disc(0.045, 10, 0.095), (0.62, 0.48, 0.42), "matte", T(px, 0.0, zt))
    for k in range(7):
        a = 2 * math.pi * k / 7
        put(p, leaf(0.09, 0.05), [LEAF, SAGE_LIGHT][k % 2], "leaf", T(px, 0, zt + 0.1) @ R("Z", math.degrees(a)) @ R("Y", -35 - 10 * (k % 3)))
    for sx in (-1, 1):
        pts = [(px + sx * 0.04, 0.03, zt + 0.1), (px + sx * 0.07, 0.07, zt + 0.02), (px + sx * 0.06, 0.1, zt - 0.08)]
        put(p, tube(pts, 0.003, 3), LEAF_DARK, "leaf")
        for i, (x, y, z) in enumerate(pts[1:]):
            put(p, leaf(0.04, 0.025), LEAF, "leaf", T(x, y, z) @ R("Z", 90 + sx * 40) @ R("Y", 30))


# ------------------------------------------------------------ hearth, screens, decor


def fire_screen(p, size, c):
    pw = 0.7
    ol = arched_outline(pw, 0.66, 14, 0.2)
    z0 = 0.2
    put(p, slab(ol, 0.02), mix(CREAM, BLUSH, 0.35), "fabric", T(0, 0, z0))
    put(p, frame_ring(ol, 0.03, 0.04), c, "gold", T(0, 0, z0))
    crest(p, 0, 0.01, z0 + 0.66, 0.16, c)
    for sx in (-1, 1):
        x = sx * (pw / 2 + 0.005)
        put(p, lathe([(0, 0), (0.025, 0.01), (0.028, 0.04), (0.012, 0.07), (0, 0.12)], 8), c, "gold", T(x, 0, z0 + 0.46))
        put(p, tube([(x, 0, z0 + 0.02), (x, 0, 0.08)], 0.02, 6), c, "gold")
        put(p, tube([(x, -0.12, 0.015), (x, -0.07, 0.06), (x, 0, 0.09), (x, 0.07, 0.06), (x, 0.12, 0.015)], [0.014, 0.018, 0.022, 0.018, 0.014], 6), c, "gold")
        for sy in (-1, 1):
            put(p, scroll(0.025, 1.1, 8, 0.007), c, "gold", T(x, sy * 0.12, 0.03) @ R("Z", 90) @ S(sy, 1, 1))
    # embroidered bouquet with ribbon and a border of small flowers
    rng = random.Random(2201)
    yf = 0.012
    stems = [((0, 0.2), (-0.1, 0.42)), ((0, 0.2), (0.08, 0.45)), ((0, 0.2), (0.0, 0.5)), ((0, 0.2), (-0.17, 0.3)), ((0, 0.2), (0.17, 0.32))]
    for (x0, zz0), (x1, zz1) in stems:
        put(p, tube([(x0, yf, z0 + zz0), ((x0 + x1) / 2, yf, z0 + (zz0 + zz1) / 2 + 0.02), (x1, yf, z0 + zz1)], 0.005, 3), LEAF_DARK, "leaf")
    for (_, _), (x1, zz1) in stems:
        col = [ROSE, LILAC, BLUSH, PERI, BUTTER][int((x1 + 0.2) * 20) % 5]
        bloom(p, (x1, yf + 0.006, z0 + zz1), 0.04, col, 2, 5, rng, "fabric", tilt=R("X", -90))
    for x, zz, a in ((-0.06, 0.32, 140), (0.06, 0.3, 40), (-0.12, 0.38, 160), (0.13, 0.4, 20), (0.0, 0.36, 90)):
        put(p, leaf(0.06, 0.03), LEAF, "leaf", T(x, yf + 0.004, z0 + zz) @ R("Y", -a) @ R("X", -90))
    put(p, tube([(-0.07, yf + 0.006, z0 + 0.13), (0, yf + 0.006, z0 + 0.19), (0.07, yf + 0.006, z0 + 0.13)], 0.008, 4), PERI, "fabric")
    put(p, tube([(-0.02, yf + 0.006, z0 + 0.19), (-0.06, yf + 0.006, z0 + 0.06)], 0.006, 4), PERI, "fabric")
    put(p, tube([(0.02, yf + 0.006, z0 + 0.19), (0.07, yf + 0.006, z0 + 0.07)], 0.006, 4), PERI, "fabric")
    for i in range(8):
        a = math.pi * (0.1 + 0.8 * i / 7)
        star_flower(p, (0.29 * math.cos(a) * 0.95, yf + 0.004, z0 + 0.33 + 0.27 * math.sin(a) - 0.05), 0.016,
                    [ROSE, BUTTER, PERI][i % 3], 5, "fabric", WHITE, facing=R("X", -90))


def fire_tools(p, size, c):
    put(p, lathe([(0, 0.02), (0.13, 0.02), (0.14, 0.035), (0.1, 0.05), (0.04, 0.07), (0.025, 0.1), (0, 0.1)], 14), c, "gold")
    for i in range(3):
        a = math.radians(90 + 120 * i)
        put(p, sphere(0.022, 6, 4), c, "gold", T(0.11 * math.cos(a), 0.11 * math.sin(a), 0.018))
    put(p, lathe([(0.016, 0.1), (0.013, 0.4), (0.022, 0.43), (0.013, 0.46), (0.012, 0.72), (0.02, 0.74)], 8), c, "gold")
    put(p, torus(0.045, 0.009, 12, 4), c, "gold", T(0, 0, 0.8) @ R("X", 90))
    put(p, sphere(0.018, 6, 4), c, "gold", T(0, 0, 0.85))
    for a in (0, 90):
        put(p, tube([(-0.1, 0, 0.0), (0.1, 0, 0.0)], 0.008, 4), c, "gold", T(0, 0, 0.72) @ R("Z", a))
    for i in range(4):
        a = math.radians(90 * i)
        put(p, sphere(0.014, 6, 4), c, "gold", T(0.1 * math.cos(a), 0.1 * math.sin(a), 0.72))
    shaft = IRON
    # poker (+X), tongs (-X), brush (+Y), shovel (-Y)
    tools = []
    for i in range(4):
        a = math.radians(90 * i)
        tools.append((0.1 * math.cos(a), 0.1 * math.sin(a)))
    (px, py), (bx, by), (tx, ty), (sx_, sy_) = tools
    for x, y in tools:
        put(p, torus(0.014, 0.004, 8, 3), c, "gold", T(x, y, 0.695) @ R("X", 90))
        put(p, lathe([(0.0, 0), (0.014, 0.01), (0.018, 0.04), (0.012, 0.07), (0.006, 0.08)], 8), c, "gold", T(x, y, 0.6))
    put(p, tube([(px, py, 0.6), (px, py, 0.12), (px + 0.03, py, 0.09)], 0.007, 5), shaft, "satin")
    put(p, tube([(px, py, 0.16), (px + 0.025, py, 0.14)], 0.005, 4), shaft, "satin")
    for o in (-0.012, 0.012):
        put(p, tube([(tx + o * 0.4, ty, 0.6), (tx + o, ty, 0.3), (tx + o * 1.5, ty, 0.12), (tx + o * 0.6, ty + 0.02, 0.1)], 0.005, 4), shaft, "satin")
    put(p, tube([(bx, by, 0.6), (bx, by, 0.2)], 0.007, 5), shaft, "satin")
    put(p, cyl(0.022, 0.03, 8), c, "gold", T(bx, by, 0.18))
    put(p, lathe([(0.022, 0), (0.04, -0.06), (0.032, -0.1), (0, -0.105)], 8, True, False), STRAW, "fabric", T(bx, by, 0.18))
    put(p, tube([(sx_, sy_, 0.6), (sx_, sy_, 0.16)], 0.007, 5), shaft, "satin")
    put(p, box(0.1, 0.012, 0.12, bevel=0.004), shaft, "satin", T(sx_, sy_ - 0.01, 0.11) @ R("X", -8))
    put(p, box(0.1, 0.03, 0.012, bevel=0.003), shaft, "satin", T(sx_, sy_ + 0.002, 0.052))


def log_basket(p, size, c):
    sy = 0.68
    sq = S(1, sy, 1)
    put(p, lathe([(0, 0.02), (0.26, 0.02), (0.285, 0.05), (0.3, 0.18), (0.31, 0.3)], 18, True, False), WICKER, "matte", sq)
    for k, z in enumerate((0.07, 0.11, 0.15, 0.19, 0.23, 0.27)):
        rr = 0.287 + (z - 0.05) * 0.1
        put(p, torus(rr, 0.013, 18, 3), lighter(WICKER, 0.12) if k % 2 else darker(WICKER, 0.08), "matte", T(0, 0, z) @ sq)
    put(p, torus(0.31, 0.022, 18, 5), darker(WICKER, 0.15), "matte", T(0, 0, 0.3) @ sq)
    for i in range(16):
        a = 2 * math.pi * i / 16
        put(p, tube([(0.27 * math.cos(a), 0.27 * sy * math.sin(a), 0.03), (0.312 * math.cos(a), 0.312 * sy * math.sin(a), 0.29)], 0.007, 3),
              darker(WICKER, 0.2), "matte")
    for sx in (-1, 1):
        put(p, tube([(sx * 0.31, 0.09 * math.cos(math.radians(t)), 0.27 + 0.07 * math.sin(math.radians(t))) for t in range(0, 181, 30)],
                   0.014, 4), darker(WICKER, 0.15), "matte")
    put(p, disc(0.29, 14, 0.26), darker(WICKER, 0.3), "matte", sq)
    rng = random.Random(2301)
    logs = [(-0.1, 0.3, 0.055), (0.0, 0.3, 0.06), (0.1, 0.3, 0.05), (-0.05, 0.38, 0.055), (0.06, 0.38, 0.05), (0.0, 0.445, 0.045),
            (-0.13, 0.36, 0.04)]
    for i, (y, z, r) in enumerate(logs):
        L = rng.uniform(0.44, 0.52)
        x0 = -L / 2 + rng.uniform(-0.03, 0.03)
        m = T(x0, y, z) @ R("Z", rng.uniform(-6, 6)) @ R("Y", 90)
        put(p, cyl(r, L, 8, caps=False), BIRCH, "satin", m)
        for e in (0.0, L):
            put(p, disc(r * 0.98, 8, e), FAWN, "matte", m)
            put(p, torus(r * 0.55, 0.003, 8, 3), darker(FAWN, 0.15), "matte", m @ T(0, 0, e + (0.001 if e else -0.001)))
        # birch lenticels: dark dashes wrapping round the bark, and a peeled patch
        for k in range(13):
            a = rng.uniform(0, 2 * math.pi)
            zz = rng.uniform(0.03, L - 0.03)
            span = rng.uniform(0.4, 1.3)
            hh = rng.uniform(0.009, 0.02)
            col = mix(BARK, OAK_DARK, 0.5) if k % 3 else OAK_DARK
            bm = bmesh.new()
            rr = r * 1.03
            _face(bm, [(rr * math.cos(a), rr * math.sin(a), zz), (rr * math.cos(a + span), rr * math.sin(a + span), zz),
                       (rr * math.cos(a + span), rr * math.sin(a + span), zz + hh), (rr * math.cos(a), rr * math.sin(a), zz + hh)],
                  (math.cos(a + span / 2), math.sin(a + span / 2), 0))
            put(p, bm, col, "matte", m, smooth=False)
        a = rng.uniform(0, 2 * math.pi)
        zz = rng.uniform(0.08, L - 0.15)
        bm = bmesh.new()
        rr = r * 1.02
        _face(bm, [(rr * math.cos(a), rr * math.sin(a), zz), (rr * math.cos(a + 0.9), rr * math.sin(a + 0.9), zz + 0.01),
                   (rr * math.cos(a + 0.8), rr * math.sin(a + 0.8), zz + 0.07), (rr * math.cos(a + 0.1), rr * math.sin(a + 0.1), zz + 0.06)],
              (math.cos(a + 0.45), math.sin(a + 0.45), 0))
        put(p, bm, mix(FAWN, BLUSH, 0.3), "matte", m, smooth=False)
    put(p, disc(0.06, 8, 0.0), FAWN, "matte", T(0, 0, 0))


def folding_screen_painted(p, size, c):
    lw, lh = 0.52, 1.78
    ang = 12.0
    rng = random.Random(2401)
    pts = []
    x = -2 * lw * math.cos(math.radians(ang))
    for i in range(5):
        pts.append((x, 0.0 if i % 2 == 0 else -lw * math.sin(math.radians(ang))))
        x += lw * math.cos(math.radians(ang))
    ol = arched_outline(lw - 0.02, lh, 10, 0.1)
    blossoms = [ROSE, BLUSH, WHITE, mix(ROSE, WHITE, 0.4)]
    for i in range(4):
        (ax, ay), (bx, by) = pts[i], pts[i + 1]
        cx, cy = (ax + bx) / 2, (ay + by) / 2
        yaw = math.degrees(math.atan2(by - ay, bx - ax))
        m = T(cx, cy, 0) @ R("Z", yaw)
        put(p, slab(ol, 0.025), c, "satin", m @ T(0, 0, 0.06))
        put(p, frame_ring(ol, 0.018, 0.03), GOLD, "gold", m @ T(0, 0, 0.06))
        for sx in (-1, 1):
            put(p, ico(0.028, 0), GOLD, "gold", m @ T(sx * (lw / 2 - 0.05), 0, 0.03), smooth=False)
        # a flowering branch rising across the leaf
        side = -1 if i % 2 == 0 else 1
        br = [(side * 0.2, 0.02, 0.15), (side * 0.05, 0.02, 0.6), (-side * 0.08, 0.02, 1.05), (side * 0.04, 0.02, 1.45), (-side * 0.1, 0.02, 1.62)]
        put(p, tube(br, [0.018, 0.014, 0.011, 0.008, 0.005], 4), BARK, "satin", m)
        for t_ in (1, 2, 3):
            bx_, _, bz_ = br[t_]
            twig = [(bx_, 0.02, bz_), (bx_ + side * 0.12 * (1 if t_ % 2 else -1), 0.02, bz_ + 0.12)]
            put(p, tube(twig, [0.007, 0.003], 3), BARK, "satin", m)
            ex, _, ez = twig[1]
            flat_flower(p, m @ T(ex, 0.03, ez) @ R("X", -90), 0.034, blossoms[(i + t_) % 4], BUTTER)
        for k in range(6):
            j = rng.randrange(1, 4)
            t = rng.random()
            ax_, _, az_ = br[j]
            bx2, _, bz2 = br[j + 1]
            px, pz = ax_ + (bx2 - ax_) * t + rng.uniform(-0.06, 0.06), az_ + (bz2 - az_) * t + rng.uniform(-0.05, 0.05)
            if k % 3 == 2:
                put(p, leaf(0.06, 0.03), mix(SAGE, MINT, 0.3), "leaf", m @ T(px, 0.025, pz) @ R("Y", -rng.uniform(0, 360)) @ R("X", -90))
            else:
                flat_flower(p, m @ T(px, 0.03, pz) @ R("X", -90), rng.uniform(0.024, 0.038), blossoms[k % 4], BUTTER)
        # birds on the second and third leaves; a butterfly on the others
        if i in (1, 2):
            bx_, _, bz_ = br[2]
            bcol = [PERI, BUTTER][i - 1]
            bm_ = m @ T(bx_ + 0.03, 0.045, bz_ + 0.06) @ S(1.7 if i == 1 else -1.7, 1.7, 1.7)
            put(p, sphere(0.045, 8, 6), bcol, "satin", bm_ @ S(1.4, 0.5, 0.9))
            put(p, sphere(0.028, 8, 5), bcol, "satin", bm_ @ T(0.06, 0, 0.035) @ S(1, 0.5, 1))
            put(p, lathe([(0.008, 0), (0, 0.025)], 4), GOLD, "gold", bm_ @ T(0.085, 0, 0.04) @ R("Y", 90))
            put(p, slab([(-0.05, 0.0), (-0.13, 0.04), (-0.12, -0.02)], 0.01), darker(bcol, 0.15), "satin", bm_)
            put(p, slab([(-0.03, 0.01), (0.03, 0.025), (-0.06, 0.05)], 0.008), lighter(bcol, 0.3), "satin", bm_ @ T(0, 0.012, 0))
            put(p, sphere(0.006, 4, 3), OAK_DARK, "matte", bm_ @ T(0.072, 0.012, 0.045))
        else:
            fx, _, fz = br[3]
            for sx in (-1, 1):
                put(p, slab([(0, 0), (sx * 0.04, 0.03), (sx * 0.035, -0.02)], 0.004), [LILAC, BUTTER][i // 3], "satin", m @ T(fx + 0.1, 0.03, fz - 0.15))
    for i in range(1, 4):
        hx, hy = pts[i]
        for z in (0.35, 1.0, 1.55):
            put(p, cyl(0.01, 0.07, 6), GOLD, "gold", T(hx, hy, z))


def umbrella_stand(p, size, c):
    prof = [(0, 0.0), (0.13, 0.0), (0.145, 0.025), (0.13, 0.05), (0.115, 0.25), (0.125, 0.42), (0.15, 0.48), (0.14, 0.5), (0.125, 0.49)]
    put(p, lathe(prof, 16, True, False), PORCELAIN, "pearl")
    put(p, disc(0.12, 12, 0.45), darker(PERI, 0.2), "matte")
    for z, rr in ((0.03, 0.143), (0.485, 0.148)):
        put(p, torus(rr, 0.008, 16, 4), c, "gold", T(0, 0, z))
    for z0, z1 in ((0.08, 0.1), (0.4, 0.42)):
        r0 = 0.122 if z0 < 0.2 else 0.125
        put(p, lathe([(r0 + 0.003, z0), (r0 + 0.003, z1)], 16, False, False), DELFT, "pearl")
    rng = random.Random(2501)
    for i in range(6):
        a = 2 * math.pi * i / 6
        rr = 0.12
        m = T(rr * math.cos(a), rr * math.sin(a), 0.25 + 0.04 * (i % 2)) @ R("Z", math.degrees(a) - 90) @ R("X", -90)
        star_flower(p, (0, 0, 0), 0.03, [ROSE, DELFT][i % 2], 5, "pearl", BUTTER, facing=m)
        put(p, leaf(0.045, 0.022), SAGE, "pearl", m @ T(0.0, -0.03, 0.002) @ R("Z", -60))
    # a crook-handled cane, a gilt-knobbed walking stick and a furled parasol
    cane = [(0.04, 0.02, 0.1), (0.05, 0.03, 0.58), (0.055, 0.03, 0.63), (0.04, 0.03, 0.665), (0.015, 0.03, 0.665), (0.0, 0.03, 0.645)]
    put(p, tube(cane, 0.012, 6), OAK, "satin")
    put(p, torus(0.013, 0.004, 8, 3), c, "gold", T(0.05, 0.03, 0.56))
    put(p, tube([(-0.03, 0.05, 0.1), (-0.06, 0.07, 0.6)], 0.01, 6), FAWN, "satin")
    put(p, sphere(0.02, 8, 5), c, "gold", T(-0.06, 0.07, 0.61))
    pm = T(-0.01, -0.04, 0.05) @ R("X", -3) @ R("Y", -6)
    put(p, cyl(0.006, 0.6, 5), c, "gold", pm)
    put(p, lathe([(0.004, 0.07), (0.03, 0.2), (0.04, 0.34), (0.03, 0.43), (0.014, 0.47)], 10, False, False), ROSE, "fabric", pm)
    for z, rr in ((0.2, 0.031), (0.3, 0.039), (0.42, 0.033)):
        put(p, torus(rr, 0.006, 10, 3), lighter(ROSE, 0.45), "fabric", pm @ T(0, 0, z))
    put(p, torus(0.03, 0.004, 10, 3), c, "gold", pm @ T(0, 0, 0.38))
    put(p, tube([(0, 0, 0.58), (0, 0, 0.64), (0.02, 0, 0.66), (0.04, 0, 0.64)], 0.008, 5), PEARL, "pearl", pm)
    bloom(p, (0, 0, 0.47), 0.022, BLUSH, 2, 5, rng, "fabric", tilt=pm)


def plant_stand_fern(p, size, c):
    # tripod stand: mint pearl column with gilt rings on scrolled feet
    for i in range(3):
        a = 90 + 120 * i
        m = R("Z", a)
        put(p, tube([(0.04, 0, 0.2), (0.12, 0, 0.15), (0.2, 0, 0.06), (0.24, 0, 0.02)], [0.025, 0.022, 0.018, 0.015], 5), c, "pearl", m)
        put(p, scroll(0.03, 1.2, 8, 0.008), GOLD, "gold", m @ T(0.25, 0, 0.035))
        put(p, leaf(0.09, 0.04), GOLD, "gold", m @ T(0.05, 0, 0.22) @ R("Y", 30))
    put(p, lathe([(0.05, 0.16), (0.06, 0.22), (0.035, 0.3), (0.03, 0.6), (0.045, 0.66), (0.03, 0.72), (0.05, 0.76), (0.13, 0.78),
                 (0.13, 0.8), (0, 0.8)], 10), c, "pearl")
    for z, rr in ((0.24, 0.05), (0.66, 0.046)):
        put(p, torus(rr, 0.008, 10, 3), GOLD, "gold", T(0, 0, z))
    # porcelain jardiniere
    put(p, lathe([(0, 0.8), (0.09, 0.8), (0.1, 0.82), (0.15, 0.88), (0.17, 0.96), (0.18, 1.0), (0.165, 1.0)], 14, True, False), PORCELAIN, "pearl")
    put(p, lathe([(0.152, 0.89), (0.168, 0.94)], 14, False, False), MINT, "pearl")
    put(p, torus(0.177, 0.008, 14, 4), GOLD, "gold", T(0, 0, 0.998))
    put(p, disc(0.165, 12, 0.975), (0.62, 0.48, 0.42), "matte")
    # cascading Boston fern: serrated frond ribbons arching out of the crown and spilling over the rim
    rng = random.Random(2601)
    n_f = 18
    for k in range(n_f):
        a = 2 * math.pi * k / n_f + rng.uniform(-0.12, 0.12)
        ca, sa = math.cos(a), math.sin(a)
        kind = k % 3
        if kind == 0:
            prof = [(0.0, 0.97), (0.05, 1.12), (0.11, 1.22), (0.18, 1.22), (0.23, 1.14)]
        elif kind == 1:
            prof = [(0.02, 0.97), (0.1, 1.1), (0.19, 1.12), (0.25, 1.02), (0.27, 0.9)]
        else:
            prof = [(0.03, 0.97), (0.13, 1.06), (0.22, 1.04), (0.27, 0.92), (0.28, 0.74 + rng.uniform(-0.04, 0.04))]
        reach = rng.uniform(0.85, 1.0)
        ctrl = [Vector((r_ * reach * ca, r_ * reach * sa, z)) for r_, z in prof]
        n_s = 14
        path = []
        for i in range(n_s + 1):
            u = i / n_s * (len(ctrl) - 1)
            j = min(int(u), len(ctrl) - 2)
            f = u - j
            p0, p1, p2, p3 = ctrl[max(j - 1, 0)], ctrl[j], ctrl[j + 1], ctrl[min(j + 2, len(ctrl) - 1)]
            path.append(0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f +
                               (-p0 + 3 * p1 - 3 * p2 + p3) * f * f * f))
        side = Vector((-sa, ca, 0.0))
        bm = bmesh.new()
        rows = []
        for i, P in enumerate(path):
            t = i / n_s
            tg = (path[min(i + 1, n_s)] - path[max(i - 1, 0)]).normalized()
            up = side.cross(tg)
            if up.z < 0:
                up = -up
            wdt = (0.045 * (1 - 0.7 * t) + 0.006) * (1.0 if i % 2 else 0.5)
            back = tg * (0.012 if i % 2 else 0.0)
            rows.append((bm.verts.new(P - side * wdt - back - up * 0.006), bm.verts.new(P + up * 0.006),
                         bm.verts.new(P + side * wdt - back - up * 0.006)))
        for r0, r1 in zip(rows, rows[1:]):
            bm.faces.new((r0[0], r1[0], r1[1], r0[1]))
            bm.faces.new((r0[1], r1[1], r1[2], r0[2]))
        col = [SAGE, LEAF, mix(SAGE, SAGE_LIGHT, 0.5), SAGE_DEEP][k % 4]
        put(p, bm, col, "leaf", sharp_deg=80)
    for k in range(5):
        a = 2 * math.pi * k / 5
        put(p, leaf(0.08, 0.035), SAGE_LIGHT, "leaf", T(0.02 * math.cos(a), 0.02 * math.sin(a), 0.98) @ R("Z", math.degrees(a)) @ R("Y", -70))


def candle_tree(p, size, c):
    for i in range(3):
        a = 90 + 120 * i
        m = R("Z", a)
        put(p, tube([(0.04, 0, 0.18), (0.15, 0, 0.14), (0.25, 0, 0.06), (0.3, 0, 0.02)], [0.03, 0.026, 0.02, 0.016], 5), c, "gold", m)
        put(p, scroll(0.04, 1.3, 9, 0.01), c, "gold", m @ T(0.31, 0, 0.04))
        put(p, leaf(0.12, 0.05), c, "gold", m @ T(0.06, 0, 0.2) @ R("Y", 25))
    put(p, lathe([(0.06, 0.12), (0.08, 0.18), (0.05, 0.24), (0.03, 0.3), (0.025, 0.85), (0.05, 0.9), (0.025, 0.95), (0.022, 1.22),
                 (0.045, 1.26), (0.022, 1.3), (0.02, 1.52), (0.04, 1.56), (0.018, 1.6), (0.02, 1.72)], 8), c, "gold")
    put(p, lathe([(0.06, 0.5), (0.08, 0.56), (0.05, 0.62)], 8, False, False), c, "gold")
    tiers = ((0.92, 0.32, 7, 0), (1.27, 0.22, 5, 25), (1.57, 0.12, 2, 90))
    for z, rr, n, off in tiers:
        for i in range(n):
            a = math.radians(360 * i / n + off)
            ca, sa = math.cos(a), math.sin(a)
            arm = [(0.03 * ca, 0.03 * sa, z), (rr * 0.4 * ca, rr * 0.4 * sa, z - 0.06), (rr * 0.8 * ca, rr * 0.8 * sa, z - 0.02),
                   (rr * ca, rr * sa, z + 0.04)]
            put(p, tube(arm, [0.012, 0.01, 0.009, 0.009], 4), c, "gold")
            x, y = rr * ca, rr * sa
            put(p, lathe([(0, 0), (0.04, 0.0), (0.045, 0.012), (0.012, 0.02)], 7), c, "gold", T(x, y, z + 0.04))
            candle(p, x, y, z + 0.055, 0.17 - 0.02 * (i % 2), 0.016)
    put(p, lathe([(0, 0), (0.045, 0.0), (0.05, 0.014), (0.012, 0.02)], 8), c, "gold", T(0, 0, 1.72))
    candle(p, 0, 0, 1.735, 0.12, 0.018)


def butter_churn(p, size, c):
    prof = [(0, 0), (0.2, 0), (0.21, 0.03), (0.2, 0.2), (0.18, 0.5), (0.165, 0.7), (0.16, 0.72), (0, 0.72)]
    put(p, lathe(prof, 12), c, "satin", smooth=False)
    for z, rr in ((0.07, 0.212), (0.36, 0.193), (0.66, 0.17)):
        put(p, torus(rr, 0.012, 12, 4), COPPER, "gold", T(0, 0, z))
    for sx in (-1, 1):
        put(p, box(0.05, 0.05, 0.12, bevel=0.012), c, "satin", T(sx * 0.18, 0, 0.62) @ R("Y", sx * 6))
        put(p, torus(0.022, 0.006, 8, 3), COPPER, "gold", T(sx * 0.2, 0, 0.66) @ R("Y", 90))
    put(p, lathe([(0, 0.0), (0.17, 0.0), (0.17, 0.02), (0.11, 0.05), (0.04, 0.07), (0.035, 0.09), (0, 0.09)], 12), lighter(c, 0.12), "satin",
          T(0, 0, 0.72))
    put(p, cyl(0.017, 0.38, 6), SCRUBBED, "satin", T(0, 0, 0.78))
    put(p, sphere(0.035, 8, 5), SCRUBBED, "satin", T(0, 0, 1.17) @ S(1, 1, 1.2))
    put(p, cyl(0.012, 0.16, 6), SCRUBBED, "satin", T(-0.08, 0, 1.1) @ R("Y", 90))
    put(p, sphere(0.04, 8, 4), DOUGH, "satin", T(0.05, 0.03, 0.8) @ S(1.3, 1, 0.35))
    m = T(0, 0.19, 0.38) @ R("X", -90 + 5)
    star_flower(p, (0, 0, 0), 0.05, ROSE, 5, "satin", BUTTER, facing=m)
    for a in (-30, 210):
        put(p, leaf(0.06, 0.03), LEAF, "satin", m @ R("Z", a) @ T(0.04, 0, 0.0))


def flour_bin(p, size, c):
    w, h, d = 0.9, 0.9, 0.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            put(p, box(0.07, 0.07, 0.08, bevel=0.015), darker(c, 0.1), "satin", T(sx * (w / 2 - 0.05), sy * (d / 2 - 0.05), 0.04))
    put(p, box(w - 0.02, d - 0.02, 0.62, bevel=0.02), c, "satin", T(0, 0, 0.08 + 0.31))
    yf = (d - 0.02) / 2
    for sx in (-1, 1):
        put(p, box(0.32, 0.02, 0.44, bevel=0.012), lighter(c, 0.08), "satin", T(sx * 0.2, yf + 0.008, 0.39))
    put(p, box(0.04, 0.025, 0.56, seg=1), darker(c, 0.06), "satin", T(0, yf + 0.008, 0.39))
    # painted label with a gilt wheat sheaf
    put(p, slab(oval_outline(0.22, 0.14, 16), 0.006), CANVAS, "matte", T(0.2, yf + 0.02, 0.34))
    for k in range(5):
        a = math.radians(-24 + 12 * k)
        put(p, tube([(0.2, yf + 0.025, 0.36), (0.2 + 0.07 * math.sin(a), yf + 0.025, 0.36 + 0.07 * math.cos(a))], 0.0025, 3), GOLD, "gold")
        put(p, sphere(0.008, 5, 3), BUTTER, "satin", T(0.2 + 0.075 * math.sin(a), yf + 0.026, 0.36 + 0.075 * math.cos(a)) @ S(0.6, 0.5, 1.4))
    put(p, torus(0.012, 0.003, 8, 3), ROSE, "satin", T(0.2, yf + 0.026, 0.37) @ R("X", 90))
    star_flower(p, (-0.2, yf + 0.022, 0.39), 0.045, ROSE, 5, "satin", BUTTER, facing=R("X", -90))
    # lid with breadboard ends, brass strap hinges, scoop and a dusting of flour
    put(p, box(w, d, 0.045, bevel=0.012), lighter(c, 0.05), "satin", T(0, 0, 0.7 + 0.0225))
    for sx in (-1, 1):
        put(p, box(0.05, d + 0.01, 0.055, bevel=0.012), c, "satin", T(sx * (w / 2 - 0.02), 0, 0.7235))
        put(p, box(0.03, 0.14, 0.006, seg=1), COPPER, "gold", T(sx * 0.25, -d / 2 + 0.07, 0.747), smooth=False)
    pull(p, 0, d / 2 + 0.0, 0.715, 0.018, COPPER)
    sm = T(-0.08, 0.04, 0.81) @ R("Z", 20) @ R("Y", 90)
    put(p, lathe([(0, 0), (0.06, 0), (0.065, 0.18)], 10, True, False), COPPER, "gold", sm @ T(0, 0, -0.09))
    put(p, sphere(0.05, 8, 4), WHITE, "matte", sm @ T(0, 0, 0.0) @ S(0.9, 0.9, 1.6))
    put(p, tube([(0, 0, -0.09), (0, 0, -0.2)], 0.014, 6), OAK, "satin", sm)
    put(p, sphere(0.06, 8, 4), WHITE, "matte", T(0.18, -0.05, 0.745) @ S(1.6, 1.2, 0.12))


BUILDERS = {
    "console_gilt": console_gilt, "hall_table_round": hall_table_round, "settee_rose": settee_rose,
    "sofa_camelback": sofa_camelback, "ottoman_tufted": ottoman_tufted, "footstool_velvet": footstool_velvet,
    "chair_low_back": chair_low_back, "chair_bergere": chair_bergere, "chair_head_dining": chair_head_dining,
    "bureau_secretary": bureau_secretary, "commode_serpentine": commode_serpentine, "etagere_gilt": etagere_gilt,
    "fire_screen": fire_screen, "fire_tools": fire_tools, "log_basket": log_basket, "armoire_ivory": armoire_ivory,
    "vanity_marble": vanity_marble, "bed_bench": bed_bench, "library_stack": library_stack,
    "library_mezzanine": library_mezzanine, "spiral_stair": spiral_stair, "library_table": library_table,
    "writing_desk_small": writing_desk_small, "colonnade_screen": colonnade_screen,
    "folding_screen_painted": folding_screen_painted, "umbrella_stand": umbrella_stand,
    "hall_bench_cushioned": hall_bench_cushioned, "plant_stand_fern": plant_stand_fern, "kitchen_island": kitchen_island,
    "butter_churn": butter_churn, "flour_bin": flour_bin, "plate_rack_wall": plate_rack_wall, "dough_trough": dough_trough,
    "drawer_chest_apothecary": drawer_chest_apothecary, "medicine_cabinet_wall": medicine_cabinet_wall,
    "servants_bell_board": servants_bell_board, "candle_tree": candle_tree, "wall_shelf_books": wall_shelf_books,
}
