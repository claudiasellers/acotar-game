"""Generates the Part 6 props: Calanmai/Solstice garden dressing and the
severed-head horror beat (headless Blender, deterministic).

Run:  /opt/bpyenv/bin/python tools/blender/p6_props.py [--only id,id] [--sheet out.png]
Out:  art/p6/<id>.glb, nodes "<id>" and "<id>_lod1" (~50% tris), fitted to
      SIZES (w, h, d) in metres, base centre at the origin, front -Z in Godot.
      Same finish contract as the manor props (prop_kit.py): one bmesh per prop,
      vertex colour = albedo, finish index in UV.x, materials "opaque"/"clear",
      so Godot's PropModels.pair() gives the pearl, gold, glass and glow finishes.
--sheet renders a review contact sheet (Cycles) instead of exporting.

Budgets (R4): <= 3,000 tris per prop, LOD1 ~50%. The run fails if one is over.

Look: the princess-castle pastels and soft gold of the court for the Solstice
props; the head is the opposite on purpose: dead grey-blue skin, bruising,
wide clouded eyes, broken teeth and a wet torn stump, so the beat lands.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,I001
import bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402
import prop_kit as K  # noqa: E402
from prop_kit import (BLUSH, BUTTER, CREAM, GOLD, GOLD_DEEP, LILAC, MINT, PEARL, PERI, ROSE,  # noqa: E402
                      R, S, T, cyl, lathe, sphere, torus, tube)

OUT = os.path.join(K.ROOT, "art/p6")
MAX_TRIS = 3000

SIZES = {
    "head_severed": (0.24, 0.30, 0.26),
    "paint_tins_spilled": (0.60, 0.08, 0.40),
    "picnic_blanket": (2.0, 0.05, 1.6),
    "picnic_basket": (0.50, 0.40, 0.35),
    "maypole_solstice": (3.0, 6.5, 3.0),
    "wine_table_solstice": (1.8, 1.0, 0.8),
    "fiddle": (0.62, 0.08, 0.22),
    "garden_streamer_post": (0.6, 3.2, 0.6),
    "paintings_bundle": (0.7, 0.6, 0.12),
    "solstice_lantern_string": (6.0, 0.6, 0.2),
}

# Solstice ribbon pastels (sRGB)
CORNFLOWER = K.hexc("#9DB4F2")
DEEP_BLUSH = K.hexc("#F4A6B8")
LINEN = K.hexc("#FBF4EA")
SAGE = K.SAGE
SAGE_DEEP = K.SAGE_DEEP
STRAW = K.hexc("#E9C98C")
STRAW_DARK = K.hexc("#C9A066")
STRAW_SHADE = K.hexc("#B88B55")
HONEY = K.hexc("#E9A84C")
HONEY_DEEP = K.hexc("#B66A2A")
EBONY = K.hexc("#3A2622")
BERRY = K.hexc("#E2465E")
CRUST = K.hexc("#E3B46A")
CRUST_DARK = K.hexc("#B97A3C")
FAE_WINE = K.hexc("#FFE7A0")
PEACH = K.hexc("#FFC09A")
GRAPE = K.hexc("#B79BE8")
PEBBLE = K.hexc("#D8C4B6")


# --------------------------------------------------------------- helpers


def clamp01(v):
    return 0.0 if v < 0.0 else 1.0 if v > 1.0 else v


def smooth(e0, e1, x):
    t = clamp01((x - e0) / (e1 - e0))
    return t * t * (3.0 - 2.0 * t)


def g2(dx, dz, sx, sz):
    return math.exp(-(dx / sx) ** 2 - (dz / sz) ** 2)


def lerp(a, b, t):
    return a + (b - a) * t


def mixc(a, b, t):
    t = clamp01(t)
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def table(zs, vs, z):
    if z <= zs[0]:
        return vs[0]
    for i in range(1, len(zs)):
        if z <= zs[i]:
            t = (z - zs[i - 1]) / (zs[i] - zs[i - 1])
            t = t * t * (3 - 2 * t)
            return vs[i - 1] + (vs[i] - vs[i - 1]) * t
    return vs[-1]


def nz(x, y, z):
    return noise.noise(Vector((x, y, z)))


def emit(p, part, paint, finish="satin", matrix=None, smooth_=True, sharp_deg=60.0, per_face=False):
    """Prop.add with a colour per vertex (paint(local_co) -> rgb) or per face
    (per_face=True: paint(face_centre, face) -> rgb), evaluated in the part's
    local space before `matrix`. finish: name or fn(face_centre) -> name."""
    fin = finish if callable(finish) else (lambda c: finish)
    data = {}
    vcol = {}
    if not per_face:
        for v in part.verts:
            vcol[v] = K.srgb(paint(v.co.copy()))
    for f in part.faces:
        c = f.calc_center_median()
        fc = K.srgb(paint(c, f)) if per_face else None
        data[f] = (K.FINISHES.index(fin(c)), fc)
    if matrix is not None:
        part.transform(matrix)
    if smooth_:
        for f in part.faces:
            f.smooth = True
        for e in part.edges:
            if e.is_manifold and e.calc_face_angle(0.0) > math.radians(sharp_deg):
                e.smooth = False
    vmap = {v: p.bm.verts.new(v.co) for v in part.verts}
    for f in part.faces:
        try:
            nf = p.bm.faces.new([vmap[v] for v in f.verts])
        except ValueError:
            continue
        mi, fc = data[f]
        nf.material_index = mi
        nf.smooth = f.smooth
        for lp, ol in zip(nf.loops, f.loops):
            lp[p.col] = fc if per_face else vcol[ol.vert]
    if smooth_:
        for e in part.edges:
            if not e.smooth:
                ne = p.bm.edges.get((vmap[e.verts[0]], vmap[e.verts[1]]))
                if ne:
                    ne.smooth = False
    part.free()
    return p


def grid(rows, close=False, pole_top=None, pole_bottom=None):
    """Quad surface from rows of points (list of lists of Vector)."""
    bm = bmesh.new()
    vr = [[bm.verts.new(pt) for pt in row] for row in rows]
    n = len(rows[0])
    span = n if close else n - 1
    for a, b in zip(vr, vr[1:]):
        for i in range(span):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if pole_top is not None:
        pv = bm.verts.new(pole_top)
        for i in range(span):
            bm.faces.new((vr[-1][i], vr[-1][(i + 1) % n], pv))
    if pole_bottom is not None:
        pv = bm.verts.new(pole_bottom)
        for i in range(span):
            bm.faces.new((vr[0][(i + 1) % n], vr[0][i], pv))
    return bm


def strip(points, normals, widths, off=0.0):
    """Flat ribbon along points; width lies across n x t."""
    pts = [Vector(q) for q in points]
    ns = [Vector(q).normalized() for q in normals]
    rows = []
    for i, q in enumerate(pts):
        t = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
        side = ns[i].cross(t).normalized() * (widths[i] / 2)
        base = q + ns[i] * off
        rows.append([base - side, base + side])
    bm = bmesh.new()
    vr = [[bm.verts.new(a), bm.verts.new(b)] for a, b in rows]
    for a, b in zip(vr, vr[1:]):
        bm.faces.new((a[0], a[1], b[1], b[0]))
    return bm


def decimate_bm(bm, ratio):
    me = bpy.data.meshes.new("tmp_dec")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("tmp_dec", me)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("d", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    dg = bpy.context.evaluated_depsgraph_get()
    new = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    out = bmesh.new()
    out.from_mesh(new)
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    bpy.data.meshes.remove(new)
    return out


def bm_tris(bm):
    return sum(len(f.verts) - 2 for f in bm.faces)


def rose(p, center, r, color, rng, tilt=None, heart=None):
    """Light two-ring rose (~80 tris)."""
    K.bloom(p, center, r, color, rings=2, per=5, rng=rng, tilt=tilt, heart=heart)


def leaf_at(p, pos, length, width, yaw, pitch=-15.0, color=None, roll=0.0):
    p.add(K.leaf(length, width), color or SAGE, "leaf",
          T(*pos) @ R("Z", yaw) @ R("Y", pitch) @ R("X", roll), smooth=False)


def blob_outline(rx, ry, n, rng, wob=0.22):
    a1, a2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1 + wob * math.sin(3 * a + a1) * 0.6 + wob * 0.5 * math.sin(5 * a + a2) + rng.uniform(-0.05, 0.05)
        out.append((rx * k * math.cos(a), ry * k * math.sin(a)))
    return out


def puddle(outline, h):
    """Glossy flat spill: domed blob (centre, mid ring, edge) on z=0."""
    rows = [[Vector((x * 0.55, y * 0.55, h)) for x, y in outline],
            [Vector((x, y, h * 0.55)) for x, y in outline]]
    rows.reverse()
    rows.insert(0, [Vector((x * 1.04, y * 1.04, 0.0)) for x, y in outline])
    return grid(rows, close=True, pole_top=Vector((0, 0, h * 1.05)))


# =============================================================== the head
# Blender axes: face toward +Y, character's left is -X. Built at real size.

HZ = [0.000, 0.030, 0.052, 0.062, 0.073, 0.088, 0.104, 0.120, 0.140, 0.160, 0.178, 0.195]
HA = [0.047, 0.049, 0.052, 0.056, 0.060, 0.063, 0.065, 0.067, 0.070, 0.072, 0.074, 0.075]
HF = [0.038, 0.040, 0.047, 0.060, 0.072, 0.078, 0.080, 0.081, 0.082, 0.083, 0.085, 0.083]
HB = [0.050, 0.051, 0.054, 0.058, 0.064, 0.074, 0.086, 0.094, 0.098, 0.100, 0.100, 0.099]
HYC = [-0.016, -0.016, -0.013, -0.009, -0.005, -0.002, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
Z_DOME, Z_TOP = 0.195, 0.284
MOUTH_Z, MOUTH_W, MOUTH_H = 0.096, 0.0185, 0.0135
EYE_X, EYE_Z, EYE_R = 0.032, 0.158, 0.0128
NECK_C = Vector((0.0, -0.016, 0.0))


def neck_edge(th):
    """Torn bottom edge of the neck: ragged, with a few hanging tongues of skin."""
    z = 0.011 + 0.005 * nz(math.cos(th) * 2.1, math.sin(th) * 2.1, 0.3)
    z += 0.0026 * math.sin(th * 41.0) * math.sin(th * 13.0 + 1.0) + 0.0018 * math.sin(th * 67.0)
    for c, depth in ((2.55, 0.013), (0.35, 0.009), (-1.25, 0.011), (-2.8, 0.007)):
        d = math.atan2(math.sin(th - c), math.cos(th - c))
        z -= depth * math.exp(-(d / 0.09) ** 2)
    return z


def head_base(th, z):
    """Base cross-section point and outward horizontal normal at (theta, z)."""
    if z <= Z_DOME:
        a, f, b, yc = table(HZ, HA, z), table(HZ, HF, z), table(HZ, HB, z), table(HZ, HYC, z)
    else:
        s = math.asin(clamp01((z - Z_DOME) / (Z_TOP - Z_DOME)))
        k = math.cos(s) ** 0.85
        a, f, b = HA[-1] * k, HF[-1] * math.cos(s) ** 1.05, HB[-1] * k
        yc = -0.014 * math.sin(s)
    fb = f if math.cos(th) >= 0 else b
    x = a * math.sin(th)
    y = yc + fb * math.cos(th)
    n = Vector((math.sin(th) / max(a, 1e-4), math.cos(th) / max(fb, 1e-4), 0.0))
    if n.length < 1e-6:
        n = Vector((0, 0, 1))
    return Vector((x, y, z)), n.normalized()


def mouth_e(x, z):
    return math.sqrt((x / MOUTH_W) ** 2 + ((z - MOUTH_Z) / MOUTH_H) ** 2)


def face_offset(x, z, th):
    """Sculpted features as offsets along the horizontal normal (metres)."""
    fm = smooth(0.18, 0.62, math.cos(th))
    sm = smooth(-0.35, 0.25, math.cos(th))      # front + sides
    ax = abs(x)
    d = 0.0
    # nose: bridge, body, tip (sharp underside), wings
    below = z < 0.127
    d += fm * 0.025 * g2(x, z - 0.129, 0.0088, 0.0045 if below else 0.016)
    d += fm * 0.013 * g2(x, z - 0.150, 0.0068, 0.014)
    d += fm * 0.009 * g2(ax - 0.0115, z - 0.1235, 0.0058, 0.0055)
    d -= fm * 0.003 * g2(x, z - 0.162, 0.008, 0.004)                      # nasion dip
    # brow ridge and glabella, eye sockets, lid fold
    d += fm * 0.0085 * g2(ax - 0.029, z - 0.1775, 0.021, 0.0062)
    d += fm * 0.003 * g2(x, z - 0.172, 0.010, 0.008)
    d -= fm * 0.0175 * g2(ax - EYE_X, z - EYE_Z, 0.0165, 0.0105)
    d += fm * 0.0025 * g2(ax - EYE_X, z - 0.1695, 0.013, 0.0022)
    # high, hard cheekbones over sunken hollows; temples drawn in
    d += sm * 0.0075 * g2(ax - 0.050, z - 0.139, 0.016, 0.009)
    d -= sm * 0.0115 * g2(ax - 0.045, z - 0.110, 0.013, 0.016)
    d -= 0.0055 * g2(ax - 0.066, z - 0.176, 0.012, 0.016) * smooth(-0.2, 0.3, math.cos(th))
    # lips round a slack open mouth
    e = mouth_e(x, z)
    upper = z > MOUTH_Z
    d += fm * (0.0042 if upper else 0.0058) * math.exp(-((e - 1.16) / 0.2) ** 2)
    d += fm * 0.003 * g2(x, z - 0.112, 0.0035, 0.006)                     # philtrum
    d -= fm * 0.030 * (1.0 - smooth(0.66, 1.0, e))
    # chin, jaw angle, larynx
    d += fm * 0.0085 * g2(x, z - 0.071, 0.017, 0.009)
    d += 0.0055 * g2(ax - 0.054, z - 0.080, 0.012, 0.011) * smooth(-0.5, 0.2, math.cos(th))
    d += fm * 0.0065 * g2(x, z - 0.038, 0.008, 0.011)
    return d


def hairline(th):
    a = abs(th)
    if a < 0.5:
        z = 0.211 + 0.012 * smooth(0.12, 0.45, a)
    elif a < 1.25:
        z = lerp(0.223, 0.188, smooth(0.5, 1.25, a))
    elif a < 1.85:
        z = 0.190
    elif a < 2.15:
        z = lerp(0.190, 0.160, smooth(1.85, 2.15, a))
    else:
        z = lerp(0.160, 0.098, smooth(2.15, 3.0, a))
    # the brand behind the left ear: hair singed back off it
    if th < 0:
        d = th + 2.13
        z += 0.035 * math.exp(-(d / 0.22) ** 2)
    return z


def hair_amount(th, z):
    return smooth(hairline(th) - 0.003, hairline(th) + 0.006, z)


def head_theta(co):
    return math.atan2(co.x, co.y)


def skin_color(co):
    x, y, z = co
    th = head_theta(co)
    ax = abs(x)
    h = hair_amount(th, z)
    # dead skin: blue-grey, mottled, a greenish cast in places
    c = K.hexc("#9AA3AE")
    m = nz(x * 38, y * 38, z * 38)
    c = mixc(c, K.hexc("#8792A0"), 0.5 + 0.5 * m)
    c = mixc(c, K.hexc("#9EA68F"), max(0.0, nz(x * 14 + 3, y * 14, z * 14)) * 0.7)
    fm = smooth(0.15, 0.6, math.cos(th))
    # bruised, sunken sockets
    c = mixc(c, K.hexc("#4A3A55"), 0.9 * fm * g2(ax - 0.031, z - 0.153, 0.02, 0.014))
    c = mixc(c, K.hexc("#2E2235"), 0.8 * fm * g2(ax - 0.033, z - 0.149, 0.012, 0.006))
    # a beating: right cheekbone/temple, left jaw
    b1 = g2(x - 0.054, z - 0.150, 0.02, 0.024) * smooth(-0.3, 0.3, math.cos(th))
    c = mixc(c, K.hexc("#A3A56A"), smooth(0.15, 0.4, b1) * 0.7)
    c = mixc(c, K.hexc("#5B3F6E"), smooth(0.4, 0.85, b1))
    b2 = g2(x + 0.05, z - 0.083, 0.016, 0.014) * smooth(-0.4, 0.3, math.cos(th))
    c = mixc(c, K.hexc("#55405F"), smooth(0.25, 0.8, b2))
    # cold nose tip and ear-ward blue
    c = mixc(c, K.hexc("#7E86A6"), 0.6 * fm * g2(x, z - 0.128, 0.008, 0.008))
    # lips, mouth, gums
    e = mouth_e(x, z)
    if fm > 0.2:
        c = mixc(c, K.hexc("#5E5470"), fm * (1 - smooth(1.05, 1.5, e)))
        c = mixc(c, K.hexc("#6B1820"), fm * (1 - smooth(0.82, 0.98, e)))
        c = mixc(c, K.hexc("#1A0608"), fm * (1 - smooth(0.62, 0.8, e)))
        # nostrils
        c = mixc(c, K.hexc("#20141A"), fm * g2(ax - 0.0075, z - 0.1185, 0.0035, 0.0025))
    # lividity in the neck, blood-soaked toward the cut
    c = mixc(c, K.hexc("#6E5A7A"), smooth(0.07, 0.03, z) * 0.6)
    edge = neck_edge(th)
    soak = smooth(edge + 0.018 + 0.008 * nz(th * 3, z * 60, 1.7), edge + 0.002, z)
    c = mixc(c, K.hexc("#5A0A10"), soak)
    # matted hair
    if h > 0:
        hc = mixc(K.hexc("#1B1311"), K.hexc("#33241D"), 0.5 + 0.5 * nz(x * 120, y * 120, z * 30))
        clot = smooth(0.25, 0.55, nz(x * 26 + 7, y * 26, z * 26))
        hc = mixc(hc, K.hexc("#3A0A0B"), clot)
        c = mixc(c, hc, h)
    return c


def build_skin():
    N = 104
    thetas = []
    for k in range(N):
        s = -1 + 2 * (k + 0.5) / N
        thetas.append(math.pi * s * (0.42 + 0.58 * s * s))
    zs = [0.003 * i for i in range(66)]                      # 0 .. 0.195
    zs += [Z_DOME + (Z_TOP - Z_DOME) * math.sin(math.pi / 2 * j / 24) for j in range(1, 24)]
    rows = []
    for z0 in zs:
        row = []
        for th in thetas:
            z = z0
            if z0 < 0.04:
                e = neck_edge(th)
                z = e + (z0 / 0.04) * (0.04 - e)
            q, n = head_base(th, z)
            q = q + n * face_offset(q.x, z, th)
            row.append(q)
        rows.append(row)
    bm = grid(rows, close=True, pole_top=Vector((0.0, -0.014, Z_TOP)))
    bm.normal_update()
    # matted hair: thick, clumped and stringy along its fall
    for v in bm.verts:
        th = head_theta(v.co)
        h = hair_amount(th, v.co.z)
        if h <= 0:
            continue
        x, y, z = v.co
        cl = nz(x * 30, y * 30, z * 9)
        st = nz(x * 95, y * 95, z * 14)
        th_ = 0.0055 + 0.0065 * max(0.0, cl) + 0.0022 * st
        v.co += v.normal * h * th_
    bm.normal_update()
    return bm


def ray_front(tree, x, z, start=0.4):
    hit = tree.ray_cast(Vector((x, start, z)), Vector((0, -1, 0)))
    return (hit[0], hit[1]) if hit[0] is not None else (None, None)


def ray_axis(tree, th, z):
    d = Vector((math.sin(th), math.cos(th), 0.0))
    hit = tree.ray_cast(Vector((0, 0, z)) + d * 0.4, -d)
    return (hit[0], hit[1]) if hit[0] is not None else (None, None)


def surface_path(tree, pts_xz, off):
    pts, ns = [], []
    for x, z in pts_xz:
        loc, n = ray_front(tree, x, z)
        if loc is None:
            continue
        pts.append(loc + n * off)
        ns.append(n)
    return pts, ns


def blood_trail(p, tree, path_xz, w0, w1, color, rng, drop=True):
    pts, ns = surface_path(tree, path_xz, 0.0011)
    if len(pts) < 2:
        return
    m = len(pts)
    widths = [lerp(w0, w1, i / (m - 1)) * (0.85 + 0.3 * rng.random()) for i in range(m)]
    emit(p, strip(pts, ns, widths), lambda c: color, "satin", smooth_=False)
    if drop:
        n = ns[-1]
        p.add(sphere(w1 * 0.9, 6, 4), K.darker(color, 0.15), "satin",
              T(*(pts[-1] + n * 0.0006)) @ S(1.0, 1.0, 1.25))


def conform(tree, bm, C, N, lift):
    """Moves a flat decal built in local (u, h, w) = (x, y, z) onto the surface around C."""
    W = (Vector((0, 0, 1)) - N * N.z).normalized()
    U = (-N).cross(W).normalized()
    for v in bm.verts:
        u, hgt, w = v.co
        q = C + U * u + W * w
        hit = tree.ray_cast(q + N * 0.03, -N)
        base = hit[0] if hit[0] is not None else q
        v.co = base + N * (lift + hgt)
    return bm


def star_outline(r, n=5, inner=0.45, rot=90.0):
    out = []
    for i in range(n * 2):
        a = math.radians(rot + 180.0 * i / n)
        rr = r if i % 2 == 0 else r * inner
        out.append((rr * math.cos(a), rr * math.sin(a)))
    return out


def head_sigil(p, tree):
    """Raised branded scar behind the left ear: a mountain under three stars."""
    loc, n = ray_axis(tree, -2.13, 0.137)
    if loc is None:
        return
    scar = K.hexc("#4A2630")
    burn = K.hexc("#8C4A52")
    # inflamed halo, flush to the skin
    halo = [(x, z) for x, z in blob_outline(0.019, 0.021, 14, random.Random(5), 0.15)]
    emit(p, conform(tree, K.slab([(x, z + 0.004) for x, z in halo], 0.0004), loc, n, 0.0004),
         lambda c: burn, "matte", smooth_=False)
    mountain = [(-0.0135, -0.006), (-0.0075, 0.0035), (-0.0045, 0.0005), (0.0005, 0.0115), (0.0055, 0.002),
                (0.0085, 0.0052), (0.0135, -0.006)]
    emit(p, conform(tree, K.slab(mountain, 0.0016), loc, n, 0.0012), lambda c: scar, "satin", smooth_=False)
    for sx in (-0.0075, 0.0, 0.0075):
        sz = 0.0185 if sx == 0.0 else 0.0165
        so = [(x + sx, z + sz) for x, z in star_outline(0.0028)]
        emit(p, conform(tree, K.slab(so, 0.0013), loc, n, 0.0011), lambda c: scar, "satin", smooth_=False)


def eye(p, tree, side, gaze):
    loc, n = ray_front(tree, side * EYE_X, EYE_Z)
    yc = loc.y - EYE_R + 0.0062
    prof = []
    for phi in (128, 100, 78, 60, 46, 35, 29, 25, 20, 13, 8, 0):
        a = math.radians(phi)
        prof.append((EYE_R * math.sin(a), EYE_R * math.cos(a)))

    def paint(co):
        r = co.length
        phi = math.degrees(math.acos(max(-1.0, min(1.0, co.z / max(r, 1e-6)))))
        ang = math.atan2(co.y, co.x)
        if phi < 9:
            return K.hexc("#0B0809")
        if phi < 21:
            c = mixc(K.hexc("#8A5A2A"), K.hexc("#5A3518"), (phi - 9) / 12)
            return mixc(c, K.hexc("#8F949C"), 0.22)          # clouding
        if phi < 26:
            return K.hexc("#2A1A12")
        c = mixc(K.hexc("#E2D9C6"), K.hexc("#D7C1A8"), smooth(30, 70, phi))
        vein = smooth(0.1, 0.5, math.sin(ang * 7 + phi * 0.08)) * smooth(36, 80, phi)
        return mixc(c, K.hexc("#B54A44"), 0.75 * vein)

    g = Vector(gaze).normalized()
    rot = Vector((0, 0, 1)).rotation_difference(g).to_matrix().to_4x4()
    emit(p, lathe(prof, 12, cap_bottom=True, cap_top=False), paint, "satin",
         T(side * EYE_X, yc, EYE_Z) @ rot, sharp_deg=80)


def tooth(w, d, h, tip_h=None, taper=0.6):
    """Tooth along +Z from root (z=0) to biting edge; tip_h breaks the edge."""
    tip_h = tip_h or [h] * 4
    bm = bmesh.new()
    lo = [bm.verts.new((sx * w / 2, sy * d / 2, 0.0)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    hi = [bm.verts.new((sx * w * taper / 2, sy * d * 0.55 / 2, tip_h[i]))
          for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1)))]
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    return bm


def head_teeth(p, tree):
    loc, _ = ray_front(tree, 0.0, MOUTH_Z + MOUTH_H * 1.15)
    yf = loc.y - 0.0055
    enamel, blood = K.hexc("#D9CDAE"), K.hexc("#5E0E12")

    def paint_for(h, bloody):
        return lambda co: mixc(enamel, blood, max(bloody, smooth(0.45 * h, 0.0, co.z)))

    upper = [(-0.0145, 0.0044, 0.0108, "canine"), (-0.0094, 0.0050, 0.0090, "chip"),
             (-0.0034, 0.0058, 0.0094, "broken"), (0.0026, 0.0058, 0.0094, "ok"),
             (0.0086, 0.0050, 0.0090, "gone"), (0.0142, 0.0044, 0.0108, "canine")]
    for x, w, h, kind in upper:
        if kind == "gone":
            p.add(sphere(0.0026, 6, 4), K.hexc("#3C0609"), "satin", T(x, yf - 0.001, MOUTH_Z + 0.0105))
            continue
        tips = {"broken": [h * 0.42, h * 0.3, h * 0.48, h * 0.55], "chip": [h, h * 0.6, h * 0.65, h]}.get(kind)
        taper = 0.25 if kind == "canine" else 0.75
        y = yf - 0.006 * (x / 0.017) ** 2
        m = T(x, y, MOUTH_Z + 0.0125) @ R("Y", 180) @ R("Z", 4 * x / 0.015)
        emit(p, tooth(w, 0.0045, h, tips, taper), paint_for(h, 0.55 if kind != "ok" else 0.15), "satin", m,
             smooth_=False)
    lower = [(-0.0118, 0.0042, 0.0064, "askew"), (-0.0068, 0.0046, 0.0068, "ok"), (-0.0022, 0.0046, 0.0066, "ok"),
             (0.0024, 0.0046, 0.0066, "broken"), (0.0070, 0.0046, 0.0068, "ok"), (0.0118, 0.0042, 0.0064, "ok")]
    for x, w, h, kind in lower:
        tips = [h * 0.35, h * 0.5, h * 0.3, h * 0.42] if kind == "broken" else None
        y = yf - 0.0012 - 0.006 * (x / 0.017) ** 2
        m = T(x, y, MOUTH_Z - 0.0128) @ R("Z", -4 * x / 0.015)
        if kind == "askew":
            m = m @ R("Y", -24) @ R("X", 12)
        emit(p, tooth(w, 0.0042, h, tips, 0.8), paint_for(h, 0.35), "satin", m, smooth_=False)


EAR_RIM = [(-0.010, 0.127), (-0.020, 0.131), (-0.029, 0.142), (-0.035, 0.158), (-0.040, 0.176), (-0.045, 0.196),
           (-0.051, 0.215), (-0.060, 0.239), (-0.050, 0.222), (-0.039, 0.206), (-0.027, 0.191), (-0.015, 0.178),
           (-0.006, 0.170)]


def head_ear(p, tree, side):
    """Long pointed fae ear sweeping up and back; built for +X, mirrored for -X."""
    pts = []
    for i, (y, z) in enumerate(EAR_RIM):
        loc, n = ray_axis(tree, math.atan2(1.0, y / 0.07), z)
        xs = loc.x if loc is not None else 0.07
        out = 0.004 + 0.022 * smooth(0.0, 0.6, (-y - 0.006) / 0.05)
        pts.append(Vector((xs + out, y, z)))
    rim_r = [0.0034, 0.0032, 0.003, 0.0028, 0.0027, 0.0025, 0.0022, 0.0012, 0.002, 0.0024, 0.0026, 0.0026, 0.0024]
    centre = Vector((0.067, -0.017, 0.151))
    bm = bmesh.new()
    cv = bm.verts.new(centre)
    inner = [bm.verts.new(centre.lerp(q, 0.86) + Vector((-0.002, 0, 0))) for q in pts]
    mid = [bm.verts.new(centre.lerp(q, 0.5) + Vector((-0.0045, 0, 0))) for q in pts]
    for i in range(len(pts) - 1):
        bm.faces.new((cv, mid[i], mid[i + 1]))
        bm.faces.new((mid[i], inner[i], inner[i + 1], mid[i + 1]))
    bm.faces.new((cv, mid[-1], mid[0]))
    bm.faces.new((mid[-1], inner[-1], inner[0], mid[0]))
    mir = S(-1, 1, 1) if side < 0 else Matrix.Identity(4)

    def ear_col(co):
        t = smooth(0.17, 0.235, co.z)
        c = mixc(K.hexc("#959DAA"), K.hexc("#6E6488"), t)
        d = (co - centre).length
        return mixc(K.hexc("#5C4C60"), c, smooth(0.006, 0.02, d))

    if side < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    emit(p, bm, ear_col, "matte", mir, sharp_deg=80)
    emit(p, tube(pts, rim_r, 4), ear_col, "matte", mir, sharp_deg=80)


def head_locks(p, tree, rng):
    hair, clot = K.hexc("#211613"), K.hexc("#3A0C0C")
    for th, z0, ln in ((2.35, 0.128, 0.07), (2.62, 0.118, 0.085), (2.92, 0.112, 0.075), (-3.08, 0.110, 0.09),
                       (-2.72, 0.114, 0.07), (1.92, 0.15, 0.06)):
        loc, n = ray_axis(tree, th, z0)
        if loc is None:
            continue
        pts = []
        for i in range(5):
            t = i / 4
            sway = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * 0.004 * t
            pts.append(loc - n * 0.003 + n * 0.006 * t + Vector((0, 0, -ln * t)) + sway)
        rad = [0.0062, 0.0055, 0.0045, 0.003, 0.0012]
        col = clot if rng.random() < 0.4 else hair
        emit(p, tube(pts, rad, 4), lambda c, col=col: col, "satin", S(1, 1, 1), sharp_deg=80)
    # wet locks plastered to the brow
    for path in (((-0.006, 0.217), (-0.016, 0.205), (-0.024, 0.192), (-0.029, 0.181)),
                 ((0.014, 0.216), (0.021, 0.204), (0.024, 0.194))):
        pts, ns = surface_path(tree, path, 0.0016)
        if len(pts) > 1:
            m = len(pts)
            emit(p, tube(pts, [lerp(0.0032, 0.0012, i / (m - 1)) for i in range(m)], 4),
                 lambda c: hair, "satin", sharp_deg=80)


def head_stump(p, rng):
    """Wet torn wound closing the neck, open at the centre for the heron's bill."""
    M = 26
    rings = []
    spec = [(1.012, -0.0004), (0.955, -0.0045), (0.80, -0.0025), (0.60, 0.004), (0.36, 0.010), (0.17, 0.016),
            (0.15, 0.042)]
    for k, (rad, dz) in enumerate(spec):
        row = []
        for i in range(M):
            th = 2 * math.pi * (i + 0.5) / M - math.pi
            ze = neck_edge(th)
            q, _ = head_base(th, ze)
            rel = Vector((q.x - NECK_C.x, q.y - NECK_C.y, 0))
            j = 0.0 if k in (0, 6) else 0.002 * nz(math.cos(th) * 4, math.sin(th) * 4, k)
            zz = (ze if k < 3 else 0.0) + dz + j
            row.append(Vector((NECK_C.x + rel.x * rad, NECK_C.y + rel.y * rad, zz)))
        rings.append(row)
    bm = grid(rings, close=True, pole_top=Vector((NECK_C.x, NECK_C.y, 0.046)))
    bmesh.ops.reverse_faces(bm, faces=bm.faces)

    def wound(co):
        rel = Vector((co.x - NECK_C.x, co.y - NECK_C.y))
        r = rel.length
        c = mixc(K.hexc("#4A070C"), K.hexc("#7A1018"), smooth(0.02, 0.045, r))
        c = mixc(c, K.hexc("#A8384A"), 0.5 * max(0.0, nz(co.x * 160, co.y * 160, 2.0)))
        c = mixc(c, K.hexc("#D9B9A0"), 0.6 * smooth(0.55, 0.8, nz(co.x * 220 + 4, co.y * 220, 1.0)))
        return mixc(c, K.hexc("#120203"), smooth(0.012, 0.007, r) + smooth(0.02, 0.04, co.z))

    emit(p, bm, wound, "satin", sharp_deg=75)
    # severed spine and windpipe
    p.add(torus(0.0105, 0.0042, 10, 4), K.hexc("#D8CDB6"), "satin",
          T(0, NECK_C.y - 0.030, -0.0005) @ S(1.0, 0.8, 1.0))
    p.add(sphere(0.0045, 6, 4), K.hexc("#B89A8C"), "satin", T(0, NECK_C.y - 0.030, -0.0008) @ S(1, 1, 0.5))
    p.add(torus(0.0078, 0.0024, 10, 4), K.hexc("#C79090"), "satin", T(0, NECK_C.y + 0.034, 0.0015))
    # clots hanging off the torn edge
    for th in (2.55, -1.25, 0.9):
        ze = neck_edge(th)
        q, n = head_base(th, ze)
        q = q - n * 0.002
        ln = rng.uniform(0.012, 0.024)
        pts = [q + Vector((0, 0, -0.002)), q + Vector((0, 0, -ln * 0.6)) - n * 0.001, q + Vector((0, 0, -ln))]
        p.add(tube(pts, [0.0026, 0.0016, 0.0012], 4, caps=False), K.hexc("#4E070B"), "satin", smooth=True)
        p.add(sphere(0.0028, 6, 4), K.hexc("#4E070B"), "satin", T(*pts[-1]) @ S(1, 1, 1.3))


def head_severed(p):
    rng = random.Random(613)
    skin = build_skin()
    tree = BVHTree.FromBMesh(skin)
    eye(p, tree, 1, (0.16, 1.0, 0.03))
    eye(p, tree, -1, (-0.05, 1.0, 0.11))
    head_teeth(p, tree)
    head_ear(p, tree, 1)
    head_ear(p, tree, -1)
    head_sigil(p, tree)
    head_locks(p, tree, rng)
    red, dark = K.hexc("#6A0B12"), K.hexc("#480609")
    # tears of blood from the inner corners, from the nose, from the slack mouth
    blood_trail(p, tree, [(0.021, 0.149), (0.022, 0.141), (0.026, 0.131), (0.028, 0.121), (0.027, 0.108),
                          (0.029, 0.097)], 0.0034, 0.0018, red, rng)
    blood_trail(p, tree, [(-0.022, 0.149), (-0.023, 0.140), (-0.021, 0.130), (-0.024, 0.118)],
                0.0032, 0.0019, dark, rng)
    blood_trail(p, tree, [(-0.037, 0.147), (-0.040, 0.136), (-0.041, 0.124), (-0.043, 0.112), (-0.042, 0.101),
                          (-0.044, 0.092)], 0.0026, 0.0014, red, rng)
    blood_trail(p, tree, [(0.0072, 0.1175), (0.0068, 0.112), (0.009, 0.1075)], 0.0034, 0.0026, red, rng, False)
    blood_trail(p, tree, [(0.016, 0.0865), (0.017, 0.080), (0.016, 0.073), (0.018, 0.066)], 0.0048, 0.0026, red, rng)
    blood_trail(p, tree, [(-0.010, 0.0835), (-0.011, 0.076), (-0.009, 0.069), (-0.010, 0.064)],
                0.0042, 0.0022, dark, rng)
    blood_trail(p, tree, [(0.006, 0.050), (0.007, 0.040), (0.005, 0.030), (0.006, 0.021)], 0.0046, 0.003, dark, rng,
                False)
    # a split above the right brow
    blood_trail(p, tree, [(0.018, 0.192), (0.028, 0.190), (0.038, 0.186)], 0.0022, 0.0018, K.hexc("#3A0508"), rng,
                False)
    blood_trail(p, tree, [(0.030, 0.189), (0.031, 0.182), (0.0325, 0.176)], 0.0024, 0.0014, red, rng)
    head_stump(p, rng)
    budget = MAX_TRIS - 30 - p.tris()
    lo = decimate_bm(skin, budget / bm_tris(skin))
    emit(p, lo, skin_color, lambda c: "satin" if hair_amount(head_theta(c), c.z) > 0.5 else "matte",
         sharp_deg=70)


# =============================================================== paint tins

TIN = K.hexc("#E7E1E6")


def paint_tin(p, paint, m, open_=True, fill=0.75):
    p.add(lathe([(0.0, 0.0), (0.034, 0.0), (0.0375, 0.002), (0.0365, 0.005), (0.0365, 0.064), (0.0385, 0.067),
                 (0.0385, 0.0705), (0.034, 0.0705), (0.0335, 0.064), (0.0335, 0.05)], 14, cap_top=False),
          TIN, "pearl", m)
    p.add(cyl(0.0372, 0.034, 14, caps=False), paint, "satin", m @ T(0, 0, 0.016))
    p.add(torus(0.0373, 0.0016, 14, 3), GOLD, "gold", m @ T(0, 0, 0.050))
    p.add(torus(0.0373, 0.0016, 14, 3), GOLD, "gold", m @ T(0, 0, 0.016))
    if open_:
        p.add(K.disc(0.0335, 14, 0.07 * fill), paint, "satin", m)
    else:
        p.add(lathe([(0.0, 0.074), (0.03, 0.0735), (0.039, 0.071), (0.0395, 0.0695), (0.0, 0.0695)], 14),
              TIN, "pearl", m)
    # folded wire bail
    bail = [(0.0395 * math.cos(math.radians(a)), 0.0395 * math.sin(math.radians(a)), 0.052 + 0.0005 * k)
            for k, a in enumerate(range(-90, 91, 30))]
    p.add(tube(bail, 0.0013, 4), GOLD, "gold", m)


def brush(p, tip, m, rng):
    p.add(lathe([(0.0, 0.0), (0.0045, 0.002), (0.0058, 0.05), (0.0052, 0.13), (0.0036, 0.165), (0.0, 0.17)], 7),
          K.hexc("#F3C3CF") if rng.random() < 0.5 else K.hexc("#C9D8F5"), "satin", m @ R("Y", -90) @ T(0, 0, -0.17))
    p.add(cyl(0.0062, 0.024, 8, 0.0055), GOLD, "gold", m @ R("Y", 90))
    p.add(lathe([(0.0058, 0.0), (0.0068, 0.012), (0.0055, 0.024), (0.0015, 0.034), (0.0, 0.034)], 8),
          K.hexc("#EADFC8"), "matte", m @ T(0.024, 0, 0) @ R("Y", 90) @ S(1.0, 0.55, 1.0))
    p.add(lathe([(0.0051, 0.0), (0.0058, 0.006), (0.0015, 0.014), (0.0, 0.014)], 8), tip, "satin",
          m @ T(0.044, 0, 0) @ R("Y", 90) @ S(1.0, 0.6, 1.0))


def paint_tins_spilled(p):
    rng = random.Random(62)
    rose_p, peri_p, butter_p, mint_p = K.hexc("#F4A3BD"), K.hexc("#A8B6F6"), K.hexc("#FBE29A"), K.hexc("#A9E6C8")
    # upright rose tin, lid off and leaning, drips down its side
    paint_tin(p, rose_p, T(-0.21, 0.07, 0), True, 0.82)
    p.add(lathe([(0.0, 0.004), (0.03, 0.0035), (0.039, 0.0015), (0.0395, 0.0), (0.0, 0.0)], 14), TIN, "pearl",
          T(-0.135, 0.135, 0.017) @ R("X", 62) @ R("Z", 20))
    p.add(K.disc(0.026, 10, 0.0042), rose_p, "satin", T(-0.135, 0.135, 0.017) @ R("X", 62) @ R("Z", 20))
    for a, ln in ((25, 0.03), (60, 0.045), (100, 0.022)):
        r = 0.0389
        x, y = math.cos(math.radians(a)), math.sin(math.radians(a))
        pts = [(-0.21 + x * r, 0.07 + y * r, 0.07 - d) for d in (0.0, ln * 0.5, ln)]
        p.add(tube(pts, [0.0022, 0.0019, 0.0024], 4), rose_p, "satin", smooth=True)
    emit(p, puddle(blob_outline(0.045, 0.035, 14, rng), 0.0035), lambda c: rose_p, "satin",
         T(-0.205, 0.07, 0.0))
    # periwinkle tin tipped over, a long glossy spill
    hp = 25
    m = T(0.02, -0.04, 0.0385) @ R("Z", hp) @ R("Y", 90)
    paint_tin(p, peri_p, m, True, 0.5)
    emit(p, puddle(blob_outline(0.11, 0.06, 18, rng), 0.004), lambda c: peri_p, "satin",
         T(0.02, -0.04, 0) @ R("Z", hp) @ T(0.13, 0.0, 0) @ S(1.0, 1.0, 1.0))
    for dx, dy, r in ((0.27, 0.05, 0.012), (0.25, -0.06, 0.008), (0.30, -0.01, 0.006)):
        emit(p, puddle(blob_outline(r, r * 0.8, 10, rng), 0.0025), lambda c: peri_p, "satin",
             T(0.02, -0.04, 0) @ R("Z", hp) @ T(dx, dy, 0))
    # butter tin rolled the other way
    hb = 215
    m = T(-0.07, -0.11, 0.0385) @ R("Z", hb) @ R("Y", 90)
    paint_tin(p, butter_p, m, True, 0.5)
    emit(p, puddle(blob_outline(0.075, 0.05, 16, rng), 0.0035), lambda c: butter_p, "satin",
         T(-0.07, -0.11, 0) @ R("Z", hb) @ T(0.1, 0.0, 0))
    # mint tin still lidded, a thumbprint smear on the lid
    paint_tin(p, mint_p, T(0.22, 0.11, 0) @ R("Z", 40), False)
    emit(p, puddle(blob_outline(0.012, 0.008, 9, rng), 0.0012), lambda c: mint_p, "satin", T(0.225, 0.105, 0.0742))
    # brushes
    brush(p, peri_p, T(0.13, -0.075, 0.0095) @ R("Z", -15), rng)
    brush(p, rose_p, T(-0.10, 0.14, 0.006) @ R("Z", 165), rng)
    brush(p, mint_p, T(0.05, 0.12, 0.006) @ R("Z", 8) @ R("X", 30), rng)
    # folded linen rag with paint wiped on it
    rag = K.cushion(0.12, 0.085, 0.012, puff=0.4)
    p.add(rag, LINEN, "fabric", T(0.21, -0.13, 0.006) @ R("Z", -12))
    rag2 = K.cushion(0.12, 0.05, 0.010, puff=0.4)
    p.add(rag2, K.hexc("#F4EADC"), "fabric", T(0.205, -0.112, 0.016) @ R("Z", -8) @ R("X", -6))
    for (dx, dy, c) in ((-0.03, -0.01, rose_p), (0.02, 0.01, peri_p), (0.0, -0.025, butter_p)):
        emit(p, puddle(blob_outline(0.014, 0.008, 9, rng), 0.001), lambda co, c=c: c, "satin",
             T(0.21 + dx, -0.115 + dy, 0.0215) @ R("Z", rng.uniform(0, 180)))
    # a few gravel stones kicked into the mess
    for i in range(12):
        x, y = rng.uniform(-0.29, 0.29), rng.uniform(-0.19, 0.19)
        r = rng.uniform(0.005, 0.011)
        p.add(K.ico(r, 1), K.mix(PEBBLE, K.hexc("#C8B2A6"), rng.random()), "matte",
              T(x, y, r * 0.35) @ R("Z", rng.uniform(0, 180)) @ S(1.2, 0.9, 0.6), sharp_deg=70)


# =============================================================== picnic blanket


def picnic_blanket(p):
    rng = random.Random(64)
    HX, HY = 0.93, 0.73
    CX, CY = 16, 13
    sub = 2
    nx, ny = CX * sub, CY * sub
    deep = K.hexc("#F2A9BC")

    def height(x, y):
        z = 0.004 + 0.006 * (0.5 + 0.5 * nz(x * 1.3, y * 1.3, 0.5))
        d = min(HX - abs(x), HY - abs(y))
        per = (x + 3 * y) if abs(HX - abs(x)) < abs(HY - abs(y)) else (3 * x + y)
        z += smooth(0.22, 0.0, d) * 0.026 * (0.55 + 0.45 * math.sin(per * 9.0 + 1.3 * nz(x, y, 3)))
        return z

    rows = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            x = -HX + 2 * HX * i / nx
            y = -HY + 2 * HY * j / ny
            fu, fv = (i % sub) / sub, (j % sub) / sub
            puff = 0.0045 * math.sin(math.pi * fu) * math.sin(math.pi * fv)
            row.append(Vector((x, y, height(x, y) + puff)))
        rows.append(row)
    bm = grid(rows)

    def gingham(c, f):
        ci = int((c.x + HX) / (2 * HX) * CX)
        cj = int((c.y + HY) / (2 * HY) * CY)
        a, b = ci % 2 == 1, cj % 2 == 1
        return deep if (a and b) else BLUSH if (a or b) else LINEN

    emit(p, bm, gingham, "fabric", per_face=True)
    # gathered ruffle all round, falling to the grass
    per = []
    for i in range(nx + 1):
        per.append((-HX + 2 * HX * i / nx, -HY))
    for j in range(1, ny + 1):
        per.append((HX, -HY + 2 * HY * j / ny))
    for i in range(nx - 1, -1, -1):
        per.append((-HX + 2 * HX * i / nx, HY))
    for j in range(ny - 1, 0, -1):
        per.append((-HX, -HY + 2 * HY * j / ny))
    inner, outer = [], []
    for k, (x, y) in enumerate(per):
        o = Vector((x / HX if abs(abs(x) - HX) < 1e-6 else 0, y / HY if abs(abs(y) - HY) < 1e-6 else 0, 0))
        o.normalize()
        z = height(x, y)
        inner.append(Vector((x, y, z)))
        gather = 0.055 + 0.012 * math.sin(k * 2.1)
        outer.append(Vector((x, y, 0)) + o * gather + Vector((0, 0, 0.002 + 0.006 * (0.5 + 0.5 * math.sin(k * 2.1)))))
    emit(p, grid([inner, outer], close=True), lambda c: deep, "fabric")
    # gold tassels on the corners
    for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        o = Vector((sx, sy, 0)).normalized()
        c = Vector((sx * HX, sy * HY, 0)) + o * 0.07
        yaw = math.degrees(math.atan2(o.y, o.x))
        p.add(sphere(0.016, 8, 6), GOLD, "gold", T(c.x, c.y, 0.016))
        p.add(lathe([(0.0, 0.0), (0.009, 0.004), (0.014, 0.03), (0.022, 0.072), (0.0, 0.074)], 10), GOLD_DEEP,
              "gold", T(c.x, c.y, 0.013) @ R("Z", yaw) @ R("Y", 84) @ S(1.0, 0.6, 1.0))
        p.add(torus(0.011, 0.0035, 10, 4), BLUSH, "satin", T(c.x, c.y, 0.013) @ R("Z", yaw) @ R("Y", 84) @ T(0, 0, 0.012))


# =============================================================== picnic basket


def basket_outline(A, B, n, ex=4.0):
    out = []
    for i in range(n):
        t = 2 * math.pi * (i + 0.5) / n
        c, s = math.cos(t), math.sin(t)
        out.append((A * math.copysign(abs(c) ** (2 / ex), c), B * math.copysign(abs(s) ** (2 / ex), s)))
    return out


def picnic_basket(p):
    rng = random.Random(65)
    A, B, H = 0.215, 0.145, 0.205
    n = 40
    base = basket_outline(A, B, n)
    rows = []
    zs = [0.0, 0.012, 0.035, 0.06, 0.085, 0.11, 0.135, 0.16, 0.185, H]
    for j, z in enumerate(zs):
        sc = 0.9 + 0.1 * (z / H)
        row = []
        for i, (x, y) in enumerate(base):
            o = Vector((x, y, 0)).normalized()
            bump = 0.003 if (i + j) % 2 else 0.0
            row.append(Vector((x * sc, y * sc, z)) + o * bump)
        rows.append(row)
    body = grid(rows, close=True, pole_bottom=Vector((0, 0, 0.0)))

    def weave(c, f):
        a = math.atan2(c.y, c.x)
        i = int((a + math.pi) / (2 * math.pi) * n)
        j = int(c.z / 0.025)
        return STRAW if (i + j) % 2 else STRAW_DARK

    emit(p, body, weave, "matte", per_face=True)
    # gingham lining
    lin = []
    for z in (0.015, 0.1, H - 0.004):
        sc = (0.9 + 0.1 * z / H) * 0.955
        lin.append([Vector((x * sc, y * sc, z)) for x, y in base])
    emit(p, grid(lin, close=True, pole_bottom=Vector((0, 0, 0.015))),
         lambda c, f: BLUSH if int((math.atan2(c.y, c.x) + 3.2) * 6) % 2 else LINEN, "fabric", per_face=True)
    # wrapped cane rim
    rim = [Vector((x, y, H + 0.004)) for x, y in basket_outline(A + 0.002, B + 0.002, 36)]
    rimb = tube(rim, 0.009, 5, closed=True)
    emit(p, rimb, lambda c, f: STRAW_SHADE if int((math.atan2(c.y, c.x) + 3.2) * 9) % 2 else STRAW, "satin",
         per_face=True)
    # lids: the left one closed, the right one thrown open
    lid_out = basket_outline(A + 0.006, B + 0.006, 40)
    half = [q for q in lid_out if q[0] <= 0.0]
    half.sort(key=lambda q: math.atan2(q[1], q[0]) % (2 * math.pi))

    def lid(mirror):
        rows_ = []
        for k in range(6):
            t = k / 5
            rows_.append([Vector((x * t, y, 0.006 * math.sin(math.pi * (1 - t) / 2) + 0.004 * (1 - abs(y) / B)))
                          for x, y in half])
        b2 = grid(rows_)
        if mirror:
            bmesh.ops.scale(b2, vec=(-1, 1, 1), verts=b2.verts)
            bmesh.ops.reverse_faces(b2, faces=b2.faces)
        return b2

    def lid_weave(c, f):
        return STRAW if (int(abs(c.x) / 0.03) + int((c.y + 0.2) / 0.03)) % 2 else STRAW_DARK

    emit(p, lid(False), lid_weave, "matte", T(-0.002, 0, H + 0.008), per_face=True)
    edge = [Vector((x, y, 0.0)) for x, y in half]
    p.add(tube(edge, 0.006, 4), STRAW_SHADE, "satin", T(-0.002, 0, H + 0.008))
    hinge = T(0.002, 0, H + 0.010) @ R("Y", -112)
    emit(p, lid(True), lid_weave, "matte", hinge, per_face=True)
    edge2 = [Vector((-x, y, 0.0)) for x, y in half]
    p.add(tube(edge2, 0.006, 4), STRAW_SHADE, "satin", hinge)
    # bentwood handle over the hinge, gold-capped, a blush bow on top
    hp = [(0.0, -B * 0.98 + 0.012 * (1 - abs(math.cos(a))), H + 0.17 * math.sin(a) ** 0.8)
          for a in [math.pi * k / 12 for k in range(13)]]
    hp = [(x, -B * 0.96 * math.cos(math.pi * k / 12), H + 0.165 * math.sin(math.pi * k / 12) ** 0.85)
          for k, (x, _, _) in enumerate(hp)]
    p.add(tube(hp, 0.0085, 6), STRAW_SHADE, "satin")
    for y in (-B * 0.96, B * 0.96):
        p.add(cyl(0.012, 0.03, 8), GOLD, "gold", T(0, y, H - 0.012))
    top = H + 0.165
    for s_ in (1, -1):
        p.add(torus(0.028, 0.008, 10, 4), BLUSH, "satin", T(0, s_ * 0.026, top + 0.012) @ R("X", 90) @ S(1, 1, 0.7))
        p.add(tube([(0, 0, top), (0.008, s_ * 0.02, top - 0.04), (0.012, s_ * 0.028, top - 0.075)],
                   [0.007, 0.006, 0.005], 4), BLUSH, "satin")
    p.add(sphere(0.011, 8, 6), DEEP_BLUSH, "satin", T(0, 0, top + 0.004))
    # contents under the open lid: napkin, loaf, bottle, strawberries
    nap = []
    for k in range(7):
        t = k / 6
        y = lerp(-0.06, B + 0.04, t)
        z = H - 0.015 + 0.035 * math.sin(math.pi * min(t / 0.75, 1.0)) - (0.07 * smooth(0.75, 1.0, t))
        row = []
        for i in range(8):
            x = lerp(0.015, 0.2, i / 7)
            row.append(Vector((x, y + 0.012 * math.sin(i * 1.7), z + 0.008 * math.sin(i * 1.3 + k))))
        nap.append(row)
    emit(p, grid(nap), lambda c: LINEN, "pearl")
    p.add(sphere(0.06, 12, 8), CRUST, "satin", T(0.075, -0.05, H + 0.008) @ R("Z", 25) @ S(1.35, 0.85, 0.62))
    for k in range(3):
        p.add(K.box(0.008, 0.07, 0.004), CRUST_DARK, "matte",
              T(0.06 + k * 0.035, -0.05, H + 0.044) @ R("Z", 40) @ R("X", 8))
    bottle = lathe([(0.0, 0.0), (0.033, 0.0), (0.034, 0.16), (0.03, 0.19), (0.013, 0.215), (0.012, 0.27),
                    (0.0135, 0.275), (0.0, 0.276)], 12)
    bm_ = T(0.15, -0.075, 0.03) @ R("X", 14) @ R("Y", -6)
    p.add(bottle, K.hexc("#C9E6D5"), "glass", bm_)
    p.add(cyl(0.0305, 0.14, 12), K.hexc("#F6C7D4"), "satin", bm_ @ T(0, 0, 0.004))
    p.add(cyl(0.0138, 0.045, 10), GOLD, "gold", bm_ @ T(0, 0, 0.235))
    for i, (x, y, z, yaw) in enumerate(((0.06, 0.07, H + 0.025, 20), (0.1, 0.09, H + 0.03, 110),
                                        (0.15, 0.075, H + 0.022, 200), (0.12, 0.17, H - 0.04, 60),
                                        (0.20, 0.22, 0.012, 140), (0.15, 0.24, 0.012, 300))):
        m = T(x, y, z) @ R("Z", yaw) @ R("Y", 80 if i >= 4 else 60)
        p.add(lathe([(0.0, 0.0), (0.006, 0.004), (0.0115, 0.014), (0.012, 0.021), (0.007, 0.027), (0.0, 0.028)],
                    8), BERRY, "satin", m @ T(0, 0, -0.014))
        for j in range(5):
            p.add(K.leaf(0.011, 0.006), SAGE_DEEP, "leaf", m @ T(0, 0, 0.013) @ R("Z", 72 * j) @ R("Y", -25),
                  smooth=False)


# =============================================================== maypole


def maypole_solstice(p):
    rng = random.Random(66)
    H = 6.0
    p.add(lathe([(0.0, 0.0), (0.36, 0.0), (0.36, 0.08), (0.30, 0.12), (0.30, 0.2), (0.22, 0.26), (0.12, 0.3),
                 (0.0, 0.3)], 16), PEARL, "pearl")
    p.add(torus(0.33, 0.022, 16, 4), GOLD, "gold", T(0, 0, 0.1))
    p.add(lathe([(0.075, 0.28), (0.07, 1.0), (0.062, H - 0.4), (0.058, H)], 12, cap_bottom=False), K.hexc("#FFFBF6"),
          "pearl")
    # gilt spiral wrap
    pts, ns, ws = [], [], []
    m = 90
    for k in range(m + 1):
        t = k / m
        z = 0.35 + (H - 0.65) * t
        r = lerp(0.075, 0.059, (z - 0.28) / (H - 0.28)) + 0.003
        a = 2 * math.pi * 5.0 * t
        pts.append((r * math.cos(a), r * math.sin(a), z))
        ns.append((math.cos(a), math.sin(a), 0))
        ws.append(0.045)
    emit(p, strip(pts, ns, ws), lambda c: GOLD, "gold", smooth_=False)
    p.add(cyl(0.085, 0.06, 12), GOLD, "gold", T(0, 0, H - 0.25))
    # crown: gold hoop, finial, ring of roses and leaves
    hoop_z = H - 0.18
    p.add(torus(0.2, 0.018, 18, 4), GOLD, "gold", T(0, 0, hoop_z))
    p.add(lathe([(0.0, H - 0.05), (0.07, H), (0.085, H + 0.06), (0.06, H + 0.13), (0.02, H + 0.2), (0.0, H + 0.42)],
                10), GOLD, "gold")
    crown_cols = [ROSE, BLUSH, BUTTER, LILAC, PEARL, DEEP_BLUSH, PERI]
    for i in range(7):
        a = 2 * math.pi * i / 7
        c = Vector((0.13 * math.cos(a), 0.13 * math.sin(a), H - 0.03))
        rose(p, c, 0.075, crown_cols[i], rng, tilt=R("Z", math.degrees(a)) @ R("Y", 35))
        for j in (-1, 1):
            leaf_at(p, (c.x, c.y, c.z - 0.02), 0.11, 0.05, math.degrees(a) + 26 * j, -10)
    # eight ribbons sweeping out and round to their stakes
    rib_cols = [ROSE, BLUSH, LILAC, PERI, MINT, BUTTER, PEARL, CORNFLOWER]
    for i in range(8):
        a0 = 2 * math.pi * i / 8
        a1 = a0 + math.radians(38)
        pts, ns, ws = [], [], []
        nseg = 26
        for k in range(nseg + 1):
            t = k / nseg
            a = lerp(a0, a1, t ** 0.8)
            r = lerp(0.2, 1.4, t ** 0.9)
            z = lerp(hoop_z, 0.34, t) - 0.55 * math.sin(math.pi * t) * (1 - t * 0.5)
            pts.append((r * math.cos(a), r * math.sin(a), z))
            tw = 0.6 * math.sin(t * math.pi * 3 + i)
            side = Vector((-math.sin(a), math.cos(a), 0))
            up = Vector((0, 0, 1))
            ns.append(up * math.cos(tw) + side * math.sin(tw))
            ws.append(0.085)
        emit(p, strip(pts, ns, ws), lambda c, col=rib_cols[i]: col, "satin", smooth_=False)
        sx, sy = 1.4 * math.cos(a1), 1.4 * math.sin(a1)
        p.add(cyl(0.028, 0.36, 6, 0.02), K.OAK, "satin", T(sx, sy, 0.0))
        p.add(sphere(0.035, 8, 6), GOLD, "gold", T(sx, sy, 0.37))
        p.add(sphere(0.04, 6, 4), rib_cols[i], "satin", T(sx, sy, 0.31) @ S(1, 1, 0.6))
        tail = [(sx, sy, 0.31), (sx * 1.04, sy * 1.04, 0.2), (sx * 1.06, sy * 1.06, 0.02)]
        emit(p, strip(tail, [(-math.sin(a1), math.cos(a1), 0)] * 3, [0.07, 0.065, 0.06]),
             lambda c, col=rib_cols[i]: col, "satin", smooth_=False)
    # garland round the foot
    gcols = [ROSE, BUTTER, BLUSH, LILAC, PEARL, MINT, PERI, DEEP_BLUSH, BUTTER]
    for i in range(9):
        a = 2 * math.pi * i / 9 + 0.2
        c = Vector((0.36 * math.cos(a), 0.36 * math.sin(a), 0.16))
        rose(p, c, 0.07, gcols[i], rng, tilt=R("Z", math.degrees(a)) @ R("Y", 50))
        for j in (-1, 1):
            leaf_at(p, (0.34 * math.cos(a + 0.17 * j), 0.34 * math.sin(a + 0.17 * j), 0.13), 0.12, 0.05,
                    math.degrees(a) + 55 * j, 10)


# =============================================================== wine table


def wine_table_solstice(p):
    rng = random.Random(67)
    A, B, H = 0.86, 0.36, 0.74
    n = 40

    def rr(t, s=1.0):
        c, si = math.cos(t), math.sin(t)
        return Vector((A * s * math.copysign(abs(c) ** 0.8, c), B * s * math.copysign(abs(si) ** 0.8, si), 0))

    ts = [2 * math.pi * (i + 0.5) / n for i in range(n)]
    rows = []
    for z, sc, fold in ((0.012, 1.045, 1.0), (0.10, 1.035, 0.9), (0.3, 1.02, 0.6), (0.52, 1.008, 0.3),
                        (H - 0.015, 1.0, 0.05), (H, 0.985, 0.0)):
        row = []
        for i, t in enumerate(ts):
            q = rr(t, sc)
            o = Vector((math.cos(t) / A, math.sin(t) / B, 0)).normalized()
            hem = 0.018 * (0.5 + 0.5 * math.cos(i * math.pi / 2.5)) if z < 0.05 else 0.0
            row.append(q + o * (0.016 * fold * math.sin(i * 2.5)) + Vector((0, 0, z + hem)))
        rows.append(row)
    for sc in (0.75, 0.4):
        rows.append([rr(t, sc) + Vector((0, 0, H)) for t in ts])
    emit(p, grid(rows, close=True, pole_top=Vector((0, 0, H))), lambda c: LINEN, "pearl")
    # gold hem cord and blush swags with rosettes
    hem = [Vector((q.x, q.y, q.z + 0.004)) for q in rows[0]]
    p.add(tube(hem, 0.007, 3, closed=True), GOLD, "gold")
    for k in range(10):
        t0, t1 = 2 * math.pi * k / 10, 2 * math.pi * (k + 1) / 10
        pts, ns, ws = [], [], []
        for j in range(7):
            t = lerp(t0, t1, j / 6)
            q = rr(t, 1.012)
            o = Vector((math.cos(t) / A, math.sin(t) / B, 0)).normalized()
            pts.append(q + Vector((0, 0, H - 0.03 - 0.09 * math.sin(math.pi * j / 6))) + o * 0.006)
            ns.append(o)
            ws.append(0.035)
        emit(p, strip(pts, ns, ws), lambda c: DEEP_BLUSH if k % 2 else BLUSH, "satin", smooth_=False)
        q = rr(t0, 1.02)
        o = Vector((math.cos(t0) / A, math.sin(t0) / B, 0)).normalized()
        K.star_flower(p, (q.x + o.x * 0.01, q.y + o.y * 0.01, H - 0.03), 0.028, ROSE if k % 2 else BUTTER,
                      facing=R("Z", math.degrees(math.atan2(o.y, o.x))) @ R("Y", 90))
    # crystal decanter of faerie wine, gold-mounted, glowing
    dec = T(0, 0, H)
    p.add(lathe([(0.0, 0.0), (0.06, 0.0), (0.065, 0.006), (0.04, 0.012), (0.075, 0.05), (0.095, 0.1),
                 (0.08, 0.15), (0.03, 0.19), (0.022, 0.27), (0.03, 0.285)], 14, cap_top=False),
          K.GLASS_TINT, "glass", dec)
    p.add(lathe([(0.0, 0.013), (0.04, 0.014), (0.07, 0.05), (0.088, 0.1), (0.074, 0.14), (0.0, 0.142)], 12),
          FAE_WINE, "glow", dec)
    p.add(lathe([(0.0, 0.0), (0.068, 0.0), (0.07, 0.01), (0.045, 0.016), (0.0, 0.016)], 14), GOLD, "gold", dec)
    p.add(torus(0.027, 0.006, 12, 4), GOLD, "gold", dec @ T(0, 0, 0.2))
    p.add(lathe([(0.0, 0.27), (0.024, 0.275), (0.03, 0.3), (0.018, 0.33), (0.0, 0.345)], 10), GOLD, "gold", dec)
    # six gold goblets with glowing wine
    for i, (x, y) in enumerate(((-0.62, 0.12), (-0.5, -0.17), (-0.32, 0.2), (0.3, -0.21), (0.52, 0.16),
                                (0.66, -0.08))):
        m = T(x, y, H)
        p.add(lathe([(0.0, 0.0), (0.038, 0.0), (0.038, 0.007), (0.011, 0.018), (0.008, 0.07), (0.018, 0.088),
                     (0.036, 0.11), (0.04, 0.165), (0.0345, 0.163), (0.0, 0.112)], 9), GOLD, "gold", m)
        p.add(K.disc(0.034, 9, 0.148), FAE_WINE, "glow", m)
        p.add(torus(0.0105, 0.0035, 8, 3), [ROSE, MINT, PERI][i % 3], "glow", m @ T(0, 0, 0.06))
    # gilt comport heaped with fruit
    cm = T(-0.24, -0.04, H)
    p.add(lathe([(0.0, 0.0), (0.06, 0.0), (0.06, 0.01), (0.016, 0.03), (0.014, 0.08), (0.11, 0.11), (0.12, 0.125),
                 (0.0, 0.1)], 12), GOLD, "gold", cm)
    for k in range(3):
        a = 2 * math.pi * k / 3
        p.add(sphere(0.042, 9, 6), PEACH, "satin", cm @ T(0.05 * math.cos(a), 0.05 * math.sin(a), 0.14))
    for k in range(9):
        a = k * 2.4
        r = 0.012 * math.sqrt(k)
        p.add(sphere(0.016, 6, 4), GRAPE, "satin", cm @ T(0.07 + r * math.cos(a), r * math.sin(a), 0.2 - 0.008 * k))
    leaf_at(p, (cm.translation.x + 0.08, cm.translation.y - 0.06, H + 0.13), 0.08, 0.04, -40)
    # a posy in a pearl bud vase and scattered blooms
    vm = T(0.22, 0.04, H)
    p.add(lathe([(0.0, 0.0), (0.03, 0.0), (0.045, 0.05), (0.02, 0.11), (0.026, 0.13), (0.0, 0.12)], 10), PEARL,
          "pearl", vm)
    for j, (c, dx, dy, dz) in enumerate(((ROSE, 0.0, 0.0, 0.2), (BUTTER, 0.04, 0.02, 0.17),
                                         (LILAC, -0.035, 0.025, 0.175), (BLUSH, 0.01, -0.04, 0.165))):
        rose(p, (0.22 + dx, 0.04 + dy, H + dz), 0.04, c, rng, tilt=R("X", dy * 600) @ R("Y", dx * 600))
    for j in range(4):
        leaf_at(p, (0.22, 0.04, H + 0.13), 0.08, 0.035, 90 * j + 20, -30)
    for (x, y, c) in ((0.06, -0.2, BLUSH), (-0.1, 0.2, BUTTER), (0.42, -0.02, ROSE)):
        rose(p, (x, y, H + 0.012), 0.03, c, rng)


# =============================================================== fiddle

FID_HW = [(-0.178, 0.0), (-0.172, 0.052), (-0.155, 0.085), (-0.125, 0.100), (-0.09, 0.103), (-0.055, 0.096),
          (-0.03, 0.08), (-0.012, 0.062), (0.005, 0.056), (0.022, 0.06), (0.04, 0.071), (0.065, 0.08),
          (0.1, 0.083), (0.13, 0.076), (0.152, 0.058), (0.167, 0.03), (0.172, 0.0)]


def fid_hw(x):
    return table([a for a, _ in FID_HW], [b for _, b in FID_HW], x)


def fiddle(p):
    M = 22
    xs = [-0.178 + 0.35 * (1 - math.cos(math.pi * i / M)) / 2 for i in range(M + 1)]
    outline = [(x, fid_hw(x)) for x in xs] + [(x, -fid_hw(x)) for x in reversed(xs[1:-1])]
    cx = -0.01
    rings = [(0.25, 0.0005), (0.5, 0.002), (0.75, 0.0042), (0.92, 0.0068), (1.0, 0.0092), (0.985, 0.0112),
             (0.985, 0.0300), (1.0, 0.0322), (0.965, 0.0342), (0.9, 0.0372), (0.75, 0.0428), (0.5, 0.0478),
             (0.25, 0.0502)]
    rows = [[Vector((cx + (x - cx) * s, y * s, z)) for x, y in outline] for s, z in rings]
    body = grid(rows, close=True, pole_top=Vector((cx, 0, 0.051)), pole_bottom=Vector((cx, 0, 0.0)))

    def varnish(co):
        hw = max(fid_hw(co.x), 1e-3)
        s = min(1.0, math.hypot((co.x - cx) / 0.18, co.y / hw) * 0.8)
        if 0.0105 < co.z < 0.031:
            return HONEY_DEEP
        c = mixc(HONEY, HONEY_DEEP, smooth(0.45, 1.0, s))
        if abs(co.z - 0.0342) < 0.0006:
            return K.hexc("#4A2A1A")
        return c

    emit(p, body, varnish, "satin", sharp_deg=55)
    # f-holes, carved where the plate rises
    for side in (1, -1):
        pts = []
        for k in range(8):
            t = k / 7
            x = lerp(-0.098, -0.022, t)
            y = side * (0.041 - 0.007 * math.sin(math.pi * (t - 0.5)) + 0.004 * t)
            s = abs(y) / fid_hw(x)
            z = table([0.25, 0.5, 0.75, 0.9, 0.965, 1.0], [0.0502, 0.0478, 0.0428, 0.0372, 0.0342, 0.0322], s) + 0.0006
            pts.append((x, y, z))
        p.add(tube(pts, 0.0017, 4), K.hexc("#1E120C"), "matte")
        for q in (pts[0], pts[-1]):
            p.add(sphere(0.0032, 6, 4), K.hexc("#1E120C"), "matte", T(*q) @ S(1, 1, 0.3))
    # neck, fingerboard, pegbox, scroll, pegs
    p.add(K.box(0.14, 0.026, 0.026, bevel=0.008, seg=1), HONEY, "satin", T(0.235, 0, 0.04))
    fb = bmesh.new()
    v = [fb.verts.new(q) for q in ((0.03, -0.021, 0.053), (0.03, 0.021, 0.053), (0.305, 0.012, 0.053),
                                   (0.305, -0.012, 0.053), (0.03, -0.021, 0.062), (0.03, 0.021, 0.062),
                                   (0.305, 0.012, 0.059), (0.305, -0.012, 0.059))]
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        fb.faces.new([v[i] for i in f])
    p.add(fb, EBONY, "satin", smooth=False)
    p.add(K.box(0.075, 0.024, 0.03, bevel=0.006, seg=1), HONEY, "satin", T(0.343, 0, 0.044) @ R("Y", 8))
    p.add(K.box(0.055, 0.012, 0.004), K.hexc("#3B2012"), "matte", T(0.343, 0, 0.059) @ R("Y", 8))
    for sd in (1, -1):
        p.add(K.scroll(0.021, 1.55, 14, 0.0075, 0.0), HONEY, "satin",
              T(0.392, sd * 0.0045, 0.05) @ R("Y", 180) @ R("Z", 0) @ S(1, 1, 1))
    for k, (x, sd) in enumerate(((0.322, 1), (0.338, -1), (0.354, 1), (0.369, -1))):
        m = T(x, 0, 0.048 + 0.002 * k) @ R("X", -90 * sd)
        p.add(cyl(0.0032, 0.034, 6, 0.0026), EBONY, "satin", m)
        p.add(K.box(0.014, 0.004, 0.012, bevel=0.002, seg=1), EBONY, "satin", m @ T(0, 0, 0.036))
        p.add(torus(0.0035, 0.0012, 6, 3), GOLD, "gold", m @ T(0, 0, 0.026))
    # bridge, tailpiece, chinrest, end button
    br = K.slab([(-0.021, 0.0478), (-0.015, 0.0478), (-0.013, 0.056), (0.013, 0.056), (0.015, 0.0478),
                 (0.021, 0.0478), (0.019, 0.074), (0.0, 0.0805), (-0.019, 0.074)], 0.0035)
    p.add(br, K.hexc("#F2DDB3"), "satin", T(-0.06, 0, 0) @ R("Z", 90), smooth=False)
    tp = K.slab([(-0.012, -0.002), (0.012, -0.002), (0.02, 0.04), (0.017, 0.058), (-0.017, 0.058), (-0.02, 0.04)],
                0.004)
    p.add(tp, EBONY, "satin", T(-0.168, 0, 0.0535) @ R("Z", -90) @ R("X", 90), smooth=False)
    p.add(cyl(0.003, 0.006, 6), GOLD, "gold", T(-0.122, 0.006, 0.055))
    p.add(sphere(0.03, 10, 6), EBONY, "satin", T(-0.15, -0.055, 0.046) @ S(1.1, 0.9, 0.28))
    p.add(sphere(0.006, 6, 4), EBONY, "satin", T(-0.181, 0, 0.02))
    # strings: nut -> bridge -> tailpiece
    for k, (yb, yn) in enumerate(((-0.0165, -0.0075), (-0.0055, -0.0025), (0.0055, 0.0025), (0.0165, 0.0075))):
        zb = 0.0805 - 0.004 * abs(yb) / 0.0165 + 0.0008
        pts = [(0.305, yn, 0.0605), (-0.06, yb, zb), (-0.112, yb * 0.8, 0.0575)]
        p.add(tube(pts, 0.00075 + 0.0002 * k, 3), K.hexc("#F5E6C0"), "gold", smooth=False)
    # bow lying alongside on the treble side, hair down
    yb = 0.06
    stick = [(-0.2 + 0.6 * t, yb, 0.064 - 0.006 * math.sin(math.pi * t)) for t in [k / 12 for k in range(13)]]
    p.add(tube(stick, [0.0045] * 3 + [0.0042] * 4 + [0.0036] * 4 + [0.003] * 2, 6), K.hexc("#8C4A28"), "satin")
    p.add(K.box(0.04, 0.012, 0.018, bevel=0.003, seg=1), EBONY, "satin", T(-0.17, yb, 0.0565))
    p.add(sphere(0.003, 6, 4), PEARL, "pearl", T(-0.17, yb + 0.0062, 0.057))
    p.add(cyl(0.0058, 0.01, 8), GOLD, "gold", T(-0.2, yb, 0.064) @ R("Y", -90))
    p.add(K.box(0.012, 0.009, 0.016, bevel=0.003, seg=1), K.hexc("#F6EEDC"), "pearl", T(0.393, yb, 0.0575))
    hair = [(-0.15, yb, 0.0505), (0.39, yb, 0.0505)]
    emit(p, strip(hair, [(0, 0, 1)] * 2, [0.009, 0.009]), lambda c: K.hexc("#FBF6EA"), "satin", smooth_=False)


# =============================================================== streamer post


def garden_streamer_post(p):
    rng = random.Random(68)
    H = 3.0
    p.add(lathe([(0.0, 0.0), (0.09, 0.0), (0.09, 0.05), (0.065, 0.09), (0.05, 0.12), (0.042, 0.2), (0.036, H - 0.2),
                 (0.044, H - 0.15), (0.044, H - 0.1), (0.0, H - 0.1)], 10), K.hexc("#FFFBF6"), "pearl")
    p.add(torus(0.07, 0.012, 12, 4), GOLD, "gold", T(0, 0, 0.06))
    p.add(lathe([(0.0, H - 0.1), (0.03, H - 0.09), (0.04, H - 0.04), (0.025, H + 0.02), (0.006, H + 0.1),
                 (0.0, H + 0.18)], 10), GOLD, "gold")
    for z in (H - 0.6, 1.2):
        p.add(torus(0.041, 0.007, 10, 4), GOLD, "gold", T(0, 0, z))
    knot_z = H - 0.32
    cols = [ROSE, BLUSH, LILAC, PERI, MINT, BUTTER, PEARL, CORNFLOWER]
    # streamers lifting in a light breeze, all to one side
    for i, col in enumerate(cols):
        a0 = 2 * math.pi * i / len(cols)
        ln = 1.35 + 0.35 * ((i * 5) % 3) / 2
        pts, ns, ws = [], [], []
        for k in range(17):
            t = k / 16
            r = 0.04 + lerp(0.0, 0.26, t ** 0.7)
            a = a0 * (1 - 0.6 * t) + 0.5 * t + 0.25 * math.sin(t * 7 + i)
            z = knot_z - ln * t
            pts.append((r * math.cos(a) + 0.04 * math.sin(t * 9 + i) * t, r * math.sin(a), z))
            tw = 1.1 * math.sin(t * 8 + i * 1.3)
            out = Vector((math.cos(a), math.sin(a), 0))
            side = Vector((-math.sin(a), math.cos(a), 0))
            ns.append(out * math.cos(tw) + side * math.sin(tw))
            ws.append(lerp(0.05, 0.04, t))
        emit(p, strip(pts, ns, ws), lambda c, col=col: col, "satin", smooth_=False)
        # notched tail
        q = Vector(pts[-1])
        p.add(sphere(0.012, 6, 4), col, "satin", T(*q) @ S(1, 1, 0.5))
    # flower knot and bow
    for s_ in (1, -1):
        p.add(torus(0.08, 0.016, 12, 4), DEEP_BLUSH, "satin",
              T(s_ * 0.085, 0.06, knot_z + 0.03) @ R("Y", s_ * 25) @ R("X", 90) @ S(1, 1, 0.55))
    p.add(sphere(0.03, 8, 6), DEEP_BLUSH, "satin", T(0, 0.06, knot_z))
    for j, (col, a, z) in enumerate(((ROSE, 90, knot_z + 0.06), (BUTTER, 30, knot_z - 0.02),
                                     (BLUSH, 150, knot_z - 0.03), (LILAC, 220, knot_z + 0.02),
                                     (PEARL, 310, knot_z + 0.04))):
        d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
        rose(p, (d.x * 0.07, d.y * 0.07, z), 0.055, col, rng, tilt=R("Z", a) @ R("Y", 70))
        leaf_at(p, (d.x * 0.06, d.y * 0.06, z - 0.04), 0.1, 0.045, a + 30, 20)
        leaf_at(p, (d.x * 0.06, d.y * 0.06, z + 0.03), 0.09, 0.04, a - 35, -30)


# =============================================================== paintings bundle


def painted_canvas(p, w, h, m, kind, framed=None, rng=None):
    """Canvas standing in the XZ plane, face toward +Y, base at z=0."""
    d = 0.022
    p.add(K.box(w, d, h, bevel=0.003, seg=1), K.hexc("#F4EBDD"), "matte", m @ T(0, 0, h / 2))
    nu, nv = 14, 12
    rows = []
    for j in range(nv + 1):
        rows.append([Vector((-w / 2 + 0.006 + (w - 0.012) * i / nu, d / 2 + 0.0008, 0.006 + (h - 0.012) * j / nv))
                     for i in range(nu + 1)])

    def paint(c, face):
        u = (c.x + w / 2) / w
        v = c.z / h
        if kind == "meadow":
            sky = mixc(K.hexc("#FCE6D6"), K.hexc("#C9D3FA"), smooth(0.4, 1.0, v))
            if (u - 0.7) ** 2 + ((v - 0.68) * 1.2) ** 2 < 0.012:
                return K.hexc("#FFE59A")
            hill1 = 0.42 + 0.08 * math.sin(u * 5.0 + 0.5)
            hill2 = 0.28 + 0.07 * math.sin(u * 7.0 + 2.0)
            if v < hill2:
                c2 = K.hexc("#9FD9AE")
                if (int(u * 14) + int(v * 12)) % 5 == 0:
                    return [ROSE, BUTTER, PEARL][int(u * 14) % 3]
                return c2
            if v < hill1:
                return K.hexc("#B9C8EA")
            return sky
        if kind == "roses":
            bg = mixc(K.hexc("#FBEFF2"), K.hexc("#F6D7E0"), v)
            for cx, cv, col in ((0.35, 0.55, ROSE), (0.62, 0.45, DEEP_BLUSH), (0.5, 0.72, BUTTER)):
                if (u - cx) ** 2 + (v - cv) ** 2 < 0.018:
                    return col
            if abs(u - 0.5) < 0.04 and v < 0.45:
                return SAGE
            return bg
        return mixc(K.hexc("#D9E8F6"), K.hexc("#EAD9F6"), v)

    emit(p, grid(rows), paint, "satin", m, per_face=True, smooth_=False)
    if framed:
        fo = [(-w / 2 - 0.012, -0.012), (w / 2 + 0.012, -0.012), (w / 2 + 0.012, h + 0.012), (-w / 2 - 0.012, h + 0.012)]
        fp = [(x, d / 2 + 0.004, z) for x, z in fo]
        p.add(tube(fp, 0.016, 4, closed=True), framed, "gold" if framed == GOLD else "pearl",
              m @ T(0, 0, 0) @ R("Y", 45) @ R("Y", -45))


def paintings_bundle(p):
    rng = random.Random(69)
    specs = [  # w, h, x, y, roll, kind, frame
        (0.6, 0.56, 0.02, -0.044, 1.5, "plain", GOLD),
        (0.5, 0.5, -0.06, -0.022, -2.5, "roses", None),
        (0.46, 0.58, 0.07, 0.0, 2.0, "plain", PEARL),
        (0.44, 0.44, -0.03, 0.022, -1.5, "roses", None),
        (0.52, 0.47, 0.01, 0.044, 1.0, "meadow", None),
    ]
    for w, h, x, y, roll, kind, frame in specs:
        m = T(x, y, 0.014) @ R("Y", roll)
        painted_canvas(p, w, h, m, kind, frame, rng)
    # blush ribbon round the bundle, both ways, with a bow at the front
    ry = 0.075
    for path, nrm in (([(-0.355, -ry, 0.27), (0.355, -ry, 0.27), (0.355, ry, 0.27), (-0.355, ry, 0.27),
                        (-0.355, -ry, 0.27)], None),
                      ([(0.05, -ry, 0.0), (0.05, -ry, 0.6), (0.05, ry, 0.6), (0.05, ry, 0.0), (0.05, -ry, 0.0)],
                       None)):
        pts, ns = [], []
        for a, b in zip(path, path[1:]):
            a, b = Vector(a), Vector(b)
            for k in range(4):
                q = a.lerp(b, k / 4)
                pts.append(q)
        pts.append(Vector(path[-1]))
        horiz = path[0][2] == path[1][2]
        for q in pts:
            if horiz:
                ns.append(Vector((q.x, q.y * 4, 0)).normalized())
            else:
                ns.append(Vector((0, q.y, (q.z - 0.3) * 0.4)).normalized())
        emit(p, strip(pts, ns, [0.035] * len(pts)), lambda c: DEEP_BLUSH, "satin", smooth_=False)
    bow = T(0.05, ry + 0.008, 0.27)
    for s_ in (1, -1):
        p.add(torus(0.045, 0.012, 12, 4), DEEP_BLUSH, "satin", bow @ T(s_ * 0.045, 0.004, 0.012) @ R("Y", s_ * 20)
              @ R("X", 90) @ S(1, 0.55, 1))
        tail = [(0, 0.004, 0), (s_ * 0.03, 0.008, -0.06), (s_ * 0.05, 0.006, -0.12)]
        emit(p, strip(tail, [(0, 1, 0)] * 3, [0.032, 0.03, 0.026]), lambda c: DEEP_BLUSH, "satin", bow,
             smooth_=False)
    p.add(sphere(0.016, 8, 6), ROSE, "satin", bow @ T(0, 0.006, 0) @ S(1, 0.7, 1))


# =============================================================== lantern string


def solstice_lantern_string(p):
    L = 2.95
    sag = 0.25
    top = 0.6

    def cord(x):
        return top - sag * (1 - (x / L) ** 2)

    pts = [(-L + 2 * L * k / 40, 0, cord(-L + 2 * L * k / 40)) for k in range(41)]
    p.add(tube(pts, 0.008, 5), GOLD, "gold")
    for sx in (-1, 1):
        p.add(torus(0.03, 0.008, 10, 4), GOLD, "gold", T(sx * (L + 0.025), 0, top) @ R("X", 90))
    cols = [ROSE, BUTTER, MINT, LILAC, BLUSH, PERI, K.hexc("#FFE2C2"), CORNFLOWER, ROSE, MINT, BUTTER]
    nl = 11
    for i in range(nl):
        x = -L + 2 * L * (i + 0.5) / nl
        zc = cord(x)
        r = 0.088 if i % 2 == 0 else 0.075
        hh = r * 2.1
        drop = 0.06 + 0.03 * (i % 3 == 1)
        ztop = zc - drop
        prof = [(0.0, -hh / 2), (r * 0.42, -hh / 2 + 0.003)]
        for k in range(1, 6):
            t = k / 6
            rad = r * math.sin(math.pi * t) ** 0.7 * (1.0 if k % 2 else 0.94)
            prof.append((max(rad, r * 0.42), -hh / 2 + hh * t))
        prof += [(r * 0.42, hh / 2 - 0.003), (0.0, hh / 2)]
        m = T(x, 0, ztop - hh / 2)
        emit(p, lathe(prof, 9), lambda c, col=cols[i]: col, "glow", m)
        p.add(cyl(r * 0.45, 0.02, 9), GOLD, "gold", m @ T(0, 0, hh / 2 - 0.01))
        p.add(cyl(r * 0.45, 0.016, 9), GOLD, "gold", m @ T(0, 0, -hh / 2 - 0.006))
        p.add(tube([(x, 0, zc), (x, 0, ztop + 0.01)], 0.003, 3), GOLD, "gold", smooth=False)
        p.add(lathe([(0.0, 0.0), (0.012, 0.004), (0.006, 0.035), (0.0, 0.04)], 6), cols[(i + 3) % nl], "satin",
              m @ T(0, 0, -hh / 2 - 0.046))


BUILDERS = {
    "head_severed": head_severed,
    "paint_tins_spilled": paint_tins_spilled,
    "picnic_blanket": picnic_blanket,
    "picnic_basket": picnic_basket,
    "maypole_solstice": maypole_solstice,
    "wine_table_solstice": wine_table_solstice,
    "fiddle": fiddle,
    "garden_streamer_post": garden_streamer_post,
    "paintings_bundle": paintings_bundle,
    "solstice_lantern_string": solstice_lantern_string,
}


# =============================================================== build / export / review


def build(pid):
    p = K.Prop(pid)
    BUILDERS[pid](p)
    lo_, hi_ = p.bounds()
    ext = hi_ - lo_
    w, h, d = SIZES[pid]
    sc = (w / ext.x, h / ext.z, d / ext.y)
    p.fit(SIZES[pid])
    ob = p.to_object(pid)
    n = K.mesh_tris(ob)
    lo = K.lod(ob, 0.5 if n > 300 else 0.6)
    lo.name = pid + "_lod1"
    return ob, lo, sc


ROUGH = [0.78, 0.42, 0.92, 0.3, 0.18, 0.05, 0.06, 0.5, 0.04, 0.7]
METAL = [0.0, 0.0, 0.0, 1.0, 0.12, 0.1, 0.9, 0.0, 0.2, 0.0]
COAT = [0.0, 0.3, 0.0, 0.0, 0.7, 1.0, 0.0, 0.0, 0.0, 0.0]
GLOW = [0.0] * 7 + [1.6, 0.0, 0.0]


def preview_materials():
    for name in ("opaque", "clear"):
        m = bpy.data.materials.get(name)
        if m is None:
            continue
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = [n for n in nt.nodes if n.bl_idname == "ShaderNodeVertexColor"][0]
        uv = nt.nodes.new("ShaderNodeUVMap")
        uv.uv_map = "finish"
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(uv.outputs["UV"], sep.inputs[0])

        def ramp(vals):
            r = nt.nodes.new("ShaderNodeValToRGB")
            cr = r.color_ramp
            cr.interpolation = "CONSTANT"
            cr.elements[0].position = 0.0
            cr.elements[1].position = 9 / 16
            for i in range(1, 9):
                cr.elements.new(i / 16)
            for i, e in enumerate(sorted(cr.elements, key=lambda e: e.position)):
                e.color = (vals[i], vals[i], vals[i], 1.0)
            nt.links.new(sep.outputs["X"], r.inputs["Fac"])
            return r.outputs["Color"]

        nt.links.new(ramp(ROUGH), bsdf.inputs["Roughness"])
        nt.links.new(ramp(METAL), bsdf.inputs["Metallic"])
        nt.links.new(ramp(COAT), bsdf.inputs["Coat Weight"])
        nt.links.new(ramp(GLOW), bsdf.inputs["Emission Strength"])
        nt.links.new(vc.outputs["Color"], bsdf.inputs["Emission Color"])
        if name == "clear":
            nt.links.new(vc.outputs["Alpha"], bsdf.inputs["Alpha"])


def render_tile(objs, target, path, res, az, el, ground=True, pad=1.12):
    sc = bpy.context.scene
    for o in sc.objects:
        if o.type == "MESH":
            o.hide_render = o not in objs and not (ground and o.name == "ground")
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(q.x for q in pts), min(q.y for q in pts), min(q.z for q in pts)))
    hi = Vector((max(q.x for q in pts), max(q.y for q in pts), max(q.z for q in pts)))
    c = (lo + hi) / 2
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e)))
    cam = sc.camera
    cam.location = c + d * 30
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    right = (-d).cross(Vector((0, 0, 1))).normalized()
    up = right.cross(-d).normalized()
    ex = max(abs((q - c).dot(right)) for q in pts) * 2
    ey = max(abs((q - c).dot(up)) for q in pts) * 2
    cam.data.ortho_scale = max(ex, ey) * pad
    cam.data.clip_end = 100
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def sheet(path):
    import numpy as np
    K.reset()
    built = {}
    for pid in BUILDERS:
        ob, lo, _ = build(pid)
        lo.hide_render = True
        built[pid] = ob
    preview_materials()
    sc = bpy.context.scene
    gm = bpy.data.materials.new("groundmat")
    gm.diffuse_color = (0.8, 0.78, 0.82, 1)
    gb = gm.node_tree.nodes["Principled BSDF"]
    gb.inputs["Base Color"].default_value = (0.70, 0.66, 0.72, 1)
    gb.inputs["Roughness"].default_value = 0.9
    gme = bpy.data.meshes.new("ground")
    gme.from_pydata([(-60, -60, 0), (60, -60, 0), (60, 60, 0), (-60, 60, 0)], [], [(0, 1, 2, 3)])
    gme.materials.append(gm)
    gro = bpy.data.objects.new("ground", gme)
    sc.collection.objects.link(gro)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    for rot, energy, ang in (((0.75, 0.15, 0.7), 3.2, 0.35), ((1.1, -0.3, -2.4), 1.1, 0.6)):
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = energy
        sun.data.angle = ang
        sc.collection.objects.link(sun)
        sun.rotation_euler = rot
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.78, 0.76, 0.86, 1)
    bg.inputs[1].default_value = 0.75
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 40
    sc.cycles.device = "CPU"
    try:
        sc.cycles.use_denoising = True
    except Exception:
        pass
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = False
    tmp = os.path.join(os.path.dirname(path), "p6_tiles")
    os.makedirs(tmp, exist_ok=True)
    tiles = []
    head = built["head_severed"]
    for name, az, el, res, gr in (("head_a", 28, 8, 1024, True), ("head_b", -128, 12, 512, True),
                                  ("head_c", 20, -60, 512, False)):
        f = os.path.join(tmp, name + ".png")
        render_tile([head], None, f, res, az, el, gr)
        tiles.append(f)
    for pid in list(BUILDERS)[1:]:
        f = os.path.join(tmp, pid + ".png")
        render_tile([built[pid]], None, f, 512, 35, 24)
        tiles.append(f)

    def load(f):
        im = bpy.data.images.load(f)
        w, h = im.size
        a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        bpy.data.images.remove(im)
        return np.flipud(a)

    W, H = 2560, 1536
    canvas = np.ones((H, W, 4), dtype=np.float32)
    canvas[:1024, :1024] = load(tiles[0])
    canvas[1024:, :512] = load(tiles[1])
    canvas[1024:, 512:1024] = load(tiles[2])
    for k, f in enumerate(tiles[3:]):
        r, c = divmod(k, 3)
        canvas[r * 512:(r + 1) * 512, 1024 + c * 512:1024 + (c + 1) * 512] = load(f)
    canvas[:, 1022:1026] = (0.2, 0.2, 0.2, 1)
    img = bpy.data.images.new("sheet", W, H, alpha=False)
    img.pixels = np.flipud(canvas).ravel().tolist()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print("sheet:", path)


def main():
    args = sys.argv[1:]
    only = set(args[args.index("--only") + 1].split(",")) if "--only" in args else None
    if "--sheet" in args:
        sheet(args[args.index("--sheet") + 1])
        return
    over = []
    print(f"  {'id':26s} {'lod0':>6s} {'lod1':>6s} {'bytes':>9s}  scale(w,h,d)")
    for pid in BUILDERS:
        if only and pid not in only:
            continue
        K.reset()
        ob, lo, sc = build(pid)
        n0, n1 = K.mesh_tris(ob), K.mesh_tris(lo)
        path = os.path.join(OUT, pid + ".glb")
        K.export_glb([ob, lo], path)
        size = os.path.getsize(path)
        warn = "  <- check proportions" if max(sc) / min(sc) > 1.2 else ""
        print(f"  {pid:26s} {n0:6d} {n1:6d} {size:9d}  ({sc[0]:.2f}, {sc[1]:.2f}, {sc[2]:.2f}){warn}")
        if n0 > MAX_TRIS or size > 2 * 1024 * 1024:
            over.append(pid)
    if over:
        print("OVER BUDGET:", ", ".join(over))
        sys.exit(1)


if __name__ == "__main__":
    main()
