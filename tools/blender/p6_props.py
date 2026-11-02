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
CAPS = {"head_severed": 5000}     # the horror close-up gets more for its eyes and hair

SIZES = {
    "head_severed": (0.21, 0.30, 0.21),     # true head proportions (asked ~0.24 x 0.30 x 0.26)
    "paint_tins_spilled": (0.60, 0.09, 0.40),
    "picnic_blanket": (2.0, 0.05, 1.6),
    "picnic_basket": (0.50, 0.40, 0.35),
    "maypole_solstice": (3.0, 6.5, 3.0),
    "wine_table_solstice": (1.8, 1.0, 0.8),
    "fiddle": (0.62, 0.08, 0.22),
    "garden_streamer_post": (0.6, 3.2, 0.5),
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
        if matrix.determinant() < 0:
            bmesh.ops.reverse_faces(part, faces=part.faces)
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


def decimate_bm(bm, ratio, weight=None, factor=1.0):
    """Collapse-decimates bm (consumed); weight(co) in 0..1 keeps detail where it is high."""
    me = bpy.data.meshes.new("tmp_dec")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("tmp_dec", me)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("d", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    if weight is not None:
        vg = ob.vertex_groups.new(name="keep")
        for v in me.vertices:
            vg.add([v.index], weight(v.co), "REPLACE")
        mod.vertex_group = "keep"
        mod.invert_vertex_group = True     # Blender collapses weighted verts first; keep them instead
        mod.vertex_group_factor = factor
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
    """Lean cupped rose: 5 open petals, 4 standing, a furled heart (~56 tris)."""
    base = T(*center) @ (tilt if tilt is not None else Matrix.Identity(4))
    for ring, (n, L, lift, col) in enumerate(((5, r, 22, color), (4, r * 0.62, 58, K.lighter(color, 0.15)))):
        for i in range(n):
            a = 360.0 * i / n + ring * 36 + rng.uniform(-9, 9)
            p.add(K.petal(L, L * 0.95, cup=0.4, curl=0.14), col, "fabric", base @ R("Z", a) @ R("Y", -lift))
    p.add(sphere(r * 0.26, 5, 3), heart or K.darker(color, 0.08), "fabric", base @ T(0, 0, r * 0.16) @ S(1, 1, 1.2))


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
MOUTH_Z, MOUTH_W, MOUTH_H = 0.0915, 0.0172, 0.0185
EYE_X, EYE_Z, EYE_R = 0.032, 0.158, 0.0128
NECK_C = Vector((0.0, -0.016, 0.0))
SKIN_TRIS = 1500


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
    zz = z - MOUTH_Z + 0.16 * x          # the dead jaw hangs open, lower on the left
    return math.sqrt((x / MOUTH_W) ** 2 + (zz / MOUTH_H) ** 2)


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
    d += fm * 0.0105 * g2(ax - 0.029, z - 0.1765, 0.021, 0.0062)
    d += fm * 0.003 * g2(x, z - 0.172, 0.010, 0.008)
    d -= fm * 0.0225 * g2(ax - EYE_X, z - EYE_Z, 0.0175, 0.0125)
    d -= fm * 0.004 * g2(ax - EYE_X, z - 0.143, 0.014, 0.006)            # hollow under the eye
    # high, hard cheekbones over sunken hollows; temples drawn in
    d += sm * 0.0075 * g2(ax - 0.050, z - 0.139, 0.016, 0.009)
    d -= sm * 0.0115 * g2(ax - 0.045, z - 0.110, 0.013, 0.016)
    d -= 0.0055 * g2(ax - 0.066, z - 0.176, 0.012, 0.016) * smooth(-0.2, 0.3, math.cos(th))
    # lips round a slack open mouth
    e = mouth_e(x, z)
    upper = z > MOUTH_Z
    d += fm * (0.0024 if upper else 0.0042) * math.exp(-((e - 1.14) / 0.22) ** 2)
    d += fm * 0.003 * g2(x, z - 0.112, 0.0035, 0.006)                     # philtrum
    d -= fm * 0.030 * (1.0 - smooth(0.66, 1.0, e))
    # chin, jaw angle, larynx
    d += fm * 0.0085 * g2(x + 0.002, z - 0.066, 0.017, 0.009)
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
    # dead skin: waxy grey-yellow, mottled with purple lividity, cold grey at the extremities
    c = K.hexc("#A9A391")
    c = mixc(c, K.hexc("#97938A"), 0.5 + 0.5 * nz(x * 40, y * 40, z * 40))
    c = mixc(c, K.hexc("#C2B898"), max(0.0, nz(x * 16 + 3, y * 16, z * 16)) * 0.7)
    liv = smooth(0.15, 0.6, nz(x * 11 - 2, y * 11, z * 11 + 5))
    c = mixc(c, K.hexc("#857285"), liv * 0.7)
    c = mixc(c, K.hexc("#8E8676"), smooth(0.0, 0.5, nz(x * 70, y * 70, z * 70)) * 0.35)
    c = mixc(c, K.hexc("#9097A0"), smooth(0.2, 0.7, nz(x * 7, y * 7 + 4, z * 7)) * 0.35)
    fm = smooth(0.15, 0.6, math.cos(th))
    # dark, sunken sockets
    c = mixc(c, K.hexc("#5A4A50"), 0.85 * fm * g2(ax - 0.031, z - 0.152, 0.022, 0.017))
    c = mixc(c, K.hexc("#2A1F22"), 0.85 * fm * g2(ax - 0.033, z - 0.150, 0.014, 0.008))
    c = mixc(c, K.hexc("#4A3A40"), 0.6 * fm * g2(ax - 0.032, z - 0.140, 0.014, 0.005))
    # an old beating: right cheekbone/temple, left jaw
    b1 = g2(x - 0.054, z - 0.150, 0.02, 0.024) * smooth(-0.3, 0.3, math.cos(th))
    c = mixc(c, K.hexc("#9A9466"), smooth(0.15, 0.4, b1) * 0.55)
    c = mixc(c, K.hexc("#5E4656"), smooth(0.45, 0.9, b1) * 0.85)
    b2 = g2(x + 0.05, z - 0.083, 0.016, 0.014) * smooth(-0.4, 0.3, math.cos(th))
    c = mixc(c, K.hexc("#5E4A58"), smooth(0.25, 0.8, b2) * 0.8)
    # cold grey nose tip
    c = mixc(c, K.hexc("#8A8A94"), 0.5 * fm * g2(x, z - 0.128, 0.008, 0.008))
    # dry grey-violet lips, black mouth
    e = mouth_e(x, z)
    if fm > 0.2:
        c = mixc(c, K.hexc("#5E4E58"), fm * (1 - smooth(1.0, 1.45, e)))
        c = mixc(c, K.hexc("#3A2226"), fm * (1 - smooth(0.85, 1.0, e)))
        c = mixc(c, K.hexc("#0E0607"), fm * (1 - smooth(0.6, 0.8, e)))
        c = mixc(c, K.hexc("#20141A"), fm * g2(ax - 0.0075, z - 0.1185, 0.0035, 0.0025))
    # lividity in the neck, blood-soaked toward the cut
    c = mixc(c, K.hexc("#76627A"), smooth(0.07, 0.03, z) * 0.6)
    edge = neck_edge(th)
    soak = smooth(edge + 0.026 + 0.01 * nz(th * 3, z * 60, 1.7), edge + 0.004, z)
    c = mixc(c, K.hexc("#4A1C16"), soak)                                    # dried, brown
    c = mixc(c, K.hexc("#62080E"), smooth(edge + 0.01, edge + 0.002, z))   # still wet at the cut
    # matted hair
    if h > 0:
        hc = mixc(K.hexc("#140E0C"), K.hexc("#3A2A22"), 0.5 + 0.5 * nz(x * 140, y * 140, z * 22))
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
    bmesh.ops.reverse_faces(bm, faces=bm.faces)          # outward normals
    return bm


def add_hair(bm):
    bm.normal_update()
    # matted hair: thick, clumped and stringy along its fall
    for v in bm.verts:
        th = head_theta(v.co)
        h = hair_amount(th, v.co.z)
        if h <= 0:
            continue
        x, y, z = v.co
        cl = nz(x * 22, y * 22, z * 7)
        st = nz(x * 60, y * 60, z * 10)
        th_ = 0.003 + 0.007 * max(0.0, cl) + 0.002 * st
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


DRIED, DRIED_EDGE, WET = K.hexc("#5C1E18"), K.hexc("#3A1610"), K.hexc("#6A0810")


def blood_trail(p, tree, path_xz, w0, w1, core, rng, drop=True):
    """Blood run down the skin: dark dried edges, a redder core, a bead at the foot."""
    pts, ns = surface_path(tree, path_xz, 0.0011)
    if len(pts) < 2:
        return
    m = len(pts)
    bm = bmesh.new()
    rows = []
    for i, (q, n) in enumerate(zip(pts, ns)):
        t = pts[min(i + 1, m - 1)] - pts[max(i - 1, 0)]
        w = lerp(w0, w1, i / (m - 1)) * (1.1 + 0.4 * rng.random())
        side = n.cross(t).normalized() * (w / 2)
        rows.append([bm.verts.new(q - side), bm.verts.new(q + n * 0.0003), bm.verts.new(q + side)])
    for a, b in zip(rows, rows[1:]):
        bm.faces.new((a[0], a[1], b[1], b[0]))
        bm.faces.new((a[1], a[2], b[2], b[1]))
    key = lambda co: (round(co.x, 6), round(co.y, 6), round(co.z, 6))  # noqa: E731
    centre = {key(r[1].co) for r in rows}
    emit(p, bm, lambda co: core if key(co) in centre else DRIED_EDGE, "matte", smooth_=False)
    if drop:
        p.add(sphere(w1 * 0.85, 5, 3), DRIED_EDGE, "matte", T(*(pts[-1] + ns[-1] * 0.0005)) @ S(1.0, 1.0, 1.3))


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
    burn = K.hexc("#7A4A50")
    # inflamed halo, flush to the skin
    halo = [(x, z) for x, z in blob_outline(0.022, 0.024, 10, random.Random(5), 0.15)]
    emit(p, conform(tree, K.slab([(x, z + 0.004) for x, z in halo], 0.0004), loc, n, 0.0004),
         lambda c: burn, "matte", smooth_=False)
    mountain = [(-0.0135, -0.006), (-0.0075, 0.0035), (-0.0045, 0.0005), (0.0005, 0.0115), (0.0055, 0.002),
                (0.0085, 0.0052), (0.0135, -0.006)]
    mountain = [(x * 1.2, z * 1.2) for x, z in mountain]
    emit(p, conform(tree, K.slab(mountain, 0.0016), loc, n, 0.0012), lambda c: scar, "satin", smooth_=False)
    for sx in (-0.0075, 0.0, 0.0075):
        sz = 0.0215 if sx == 0.0 else 0.019
        so = [(x + sx * 1.2, z + sz) for x, z in star_outline(0.0033)]
        emit(p, conform(tree, K.slab(so, 0.0013), loc, n, 0.0011), lambda c: scar, "satin", smooth_=False)


def eye(p, tree, side, gaze, droop):
    """Sunken, half-lidded dead eye: a dull clouded ball set back in a shadowed socket
    under a heavy upper lid, the lower lid sagging off it with a red rim."""
    loc, n = ray_front(tree, side * EYE_X, EYE_Z)
    yc = loc.y - EYE_R + 0.0032
    c = Vector((side * EYE_X, yc, EYE_Z))
    prof = []
    for phi in (110, 80, 58, 42, 32, 26, 22, 17, 11, 6, 0):
        a = math.radians(phi)
        prof.append((EYE_R * math.sin(a), EYE_R * math.cos(a)))

    def paint(co):
        r = co.length
        phi = math.degrees(math.acos(max(-1.0, min(1.0, co.z / max(r, 1e-6)))))
        ang = math.atan2(co.y, co.x)
        film = K.hexc("#9C9A90")                               # the dry film of death
        if phi < 8:
            return mixc(K.hexc("#2A2224"), film, 0.5)
        if phi < 20:
            return mixc(mixc(K.hexc("#6A4524"), K.hexc("#4A2E1A"), (phi - 8) / 12), film, 0.45)
        if phi < 24:
            return mixc(K.hexc("#3A2A20"), film, 0.4)
        c_ = mixc(K.hexc("#C9C0A8"), K.hexc("#B29A84"), smooth(28, 70, phi))
        vein = smooth(0.0, 0.7, math.sin(ang * 11 + phi * 0.13)) * smooth(28, 60, phi)
        c_ = mixc(c_, K.hexc("#963038"), 0.7 * vein)
        return mixc(c_, K.hexc("#7A2A30"), smooth(55, 85, phi))

    g = Vector(gaze).normalized()
    rot = Vector((0, 0, 1)).rotation_difference(g).to_matrix().to_4x4()
    emit(p, lathe(prof, 12, cap_bottom=True, cap_top=False), paint, "satin", T(*c) @ rot, sharp_deg=80)
    # heavy upper lid: a shell over the top of the ball, its edge low across the iris
    rl = EYE_R + 0.0011
    edge_up = 76 + droop

    def lid_rows(a0, a1, na, nb=9):
        rows = []
        for i in range(na + 1):
            al = math.radians(lerp(a0, a1, i / na))
            row = []
            for j in range(nb + 1):
                be = math.radians(lerp(18, 162, j / nb))
                sag = 0.1 * math.sin(be) ** 2 * (1 if a1 > 90 else 0)
                row.append(c + Vector((side * rl * math.cos(be), rl * math.sin(be) * math.sin(al + sag),
                                       rl * math.sin(be) * math.cos(al + sag))))
            rows.append(row)
        return rows

    lid_col = lambda co: mixc(K.hexc("#6E6068"), K.hexc("#4A3C44"), smooth(c.z + 0.008, c.z, co.z))  # noqa: E731
    up = lid_rows(-25, edge_up, 4)
    bm = grid(up)
    if side > 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    emit(p, bm, lid_col, "matte", sharp_deg=85)
    emit(p, tube(up[-1], [0.0009] + [0.0014] * (len(up[-1]) - 2) + [0.0009], 4, caps=False),
         lambda co: K.hexc("#4E3A3E"), "matte", sharp_deg=85)
    # sagging lower lid, its wet red inner rim turned out
    lo = lid_rows(200, 128, 2)
    bm = grid(lo)
    if side < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    emit(p, bm, lambda co: K.hexc("#6A5A62"), "matte", sharp_deg=85)
    emit(p, tube(lo[-1], 0.0012, 4, caps=False), lambda co: K.hexc("#7A2E34"), "satin", sharp_deg=85)


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
    """A slack dead mouth: the upper lip hides most of the top teeth, a few
    stained, uneven lower teeth, one gone, one snapped; a dark tongue fallen back."""
    loc, _ = ray_front(tree, 0.0, MOUTH_Z + MOUTH_H * 1.12)
    yf = loc.y - 0.0065
    enamel, stain, blood = K.hexc("#B8A882"), K.hexc("#7A6A4A"), K.hexc("#4A1A14")

    def paint_for(h, bloody):
        return lambda co: mixc(mixc(enamel, stain, smooth(0.3 * h, 0.9 * h, co.z) * 0.5), blood,
                               max(bloody, smooth(0.45 * h, 0.0, co.z)))

    def tilt(x):
        return 0.16 * x                                          # follows the crooked jaw

    upper = [(-0.0118, 0.0042, 0.0085, 0.25, 6, 0.3), (-0.0052, 0.0052, 0.0072, 0.75, -4, 0.2),
             (0.0012, 0.0054, 0.0046, 0.8, 9, 0.7), (0.0075, 0.0048, 0.0078, 0.75, 3, 0.25)]
    for x, w, h, taper, rz, bl in upper:
        y = yf - 0.007 * (x / 0.017) ** 2
        tips = [h, h * 0.55, h * 0.7, h * 0.9] if h < 0.005 else None
        m = T(x, y, MOUTH_Z + MOUTH_H * 0.95 - tilt(x)) @ R("Y", 180) @ R("Z", rz) @ R("X", -8)
        emit(p, tooth(w, 0.0042, h, tips, taper), paint_for(h, bl), "satin", m, smooth_=False)
    lower = [(-0.0105, 0.0042, 0.0052, 18, 0.2), (-0.0045, 0.0046, 0.0060, -6, 0.15),
             (0.0062, 0.0044, 0.0030, 12, 0.6)]
    for x, w, h, rz, bl in lower:
        y = yf - 0.0025 - 0.007 * (x / 0.017) ** 2
        tips = [h * 0.6, h, h * 0.75, h * 0.5] if h < 0.004 else None
        m = T(x, y, MOUTH_Z - MOUTH_H * 0.92 - tilt(x)) @ R("Z", rz) @ R("Y", -rz * 0.8) @ R("X", 10)
        emit(p, tooth(w, 0.004, h, tips, 0.8), paint_for(h, bl), "satin", m, smooth_=False)
    p.add(sphere(0.0024, 5, 3), K.hexc("#30080A"), "satin", T(0.0012, yf - 0.0035, MOUTH_Z - MOUTH_H * 0.9))
    # tongue, swollen and dark, slumped in shadow at the back of the jaw
    p.add(sphere(0.012, 8, 5), K.hexc("#3A2228"), "satin",
          T(-0.002, yf - 0.016, MOUTH_Z - MOUTH_H * 0.55) @ R("Z", 8) @ S(1.25, 1.1, 0.45))


EAR_RIM = [(-0.010, 0.127), (-0.020, 0.131), (-0.029, 0.142), (-0.035, 0.158), (-0.040, 0.176), (-0.045, 0.196),
           (-0.051, 0.215), (-0.060, 0.239), (-0.050, 0.222), (-0.039, 0.206), (-0.027, 0.191), (-0.015, 0.178),
           (-0.006, 0.170)]


def head_ear(p, tree, side):
    """Long pointed fae ear sweeping up and back; built for +X, mirrored for -X."""
    rim = []
    for i in range(len(EAR_RIM) - 1):
        p0, p1 = EAR_RIM[max(i - 1, 0)], EAR_RIM[i]
        p2, p3 = EAR_RIM[i + 1], EAR_RIM[min(i + 2, len(EAR_RIM) - 1)]
        for t in ((0.0, 0.5) if 3 <= i <= 8 and i != 6 else (0.0,)):
            rim.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t * t
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t ** 3) for k in range(2)))
    rim.append(EAR_RIM[-1])
    pts = []
    for i, (y, z) in enumerate(rim):
        loc, n = ray_axis(tree, math.atan2(1.0, y / 0.07), z)
        xs = loc.x if loc is not None else 0.07
        out = 0.003 + 0.03 * smooth(0.0, 0.7, (-y - 0.006) / 0.05) + 0.006 * smooth(0.18, 0.235, z)
        pts.append(Vector((xs + out, y, z)))
    tip = min(range(len(pts)), key=lambda i: -pts[i].z)
    rim_r = [lerp(0.0046, 0.0012, smooth(0, 1, 1 - abs(i - tip) / tip)) if i <= tip else
             lerp(0.0012, 0.0032, smooth(0, 1, (i - tip) / max(len(pts) - 1 - tip, 1))) for i in range(len(pts))]
    centre = Vector((0.067, -0.017, 0.151))
    bm = bmesh.new()
    cv = bm.verts.new(centre)
    inner = [bm.verts.new(centre.lerp(q, 0.97) + Vector((-0.0025, 0, 0))) for q in pts]
    mid = [bm.verts.new(centre.lerp(q, 0.55) + Vector((-0.0065, 0, 0))) for q in pts]
    for i in range(len(pts) - 1):
        bm.faces.new((cv, mid[i], mid[i + 1]))
        bm.faces.new((mid[i], inner[i], inner[i + 1], mid[i + 1]))
    bm.faces.new((cv, mid[-1], mid[0]))
    bm.faces.new((mid[-1], inner[-1], inner[0], mid[0]))
    mir = S(-1, 1, 1) if side < 0 else Matrix.Identity(4)

    def ear_col(co):
        t = smooth(0.17, 0.235, co.z)
        c = mixc(K.hexc("#A39D8C"), K.hexc("#76696E"), t)
        d = (co - centre).length
        return mixc(K.hexc("#4A3A44"), c, smooth(0.006, 0.024, d))

    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    emit(p, bm, ear_col, "matte", mir, sharp_deg=80)
    emit(p, tube(pts, rim_r, 4, caps=False), ear_col, "matte", mir, sharp_deg=80)


def flat_tube(pts, ns, widths, flat=0.38, sides=4):
    """Tube with an elliptical section lying flat on the surface normal: a plastered hank."""
    bm = bmesh.new()
    rings = []
    m = len(pts)
    for i, (q, n) in enumerate(zip(pts, ns)):
        t = (pts[min(i + 1, m - 1)] - pts[max(i - 1, 0)]).normalized()
        nn = (n - t * n.dot(t)).normalized()
        side = nn.cross(t).normalized()
        w = widths[i]
        rings.append([bm.verts.new(q + side * (w * math.cos(2 * math.pi * k / sides + 0.4))
                                   + nn * (w * flat * math.sin(2 * math.pi * k / sides + 0.4)))
                      for k in range(sides)])
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            j = (k + 1) % sides
            bm.faces.new((r0[k], r0[j], r1[j], r1[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    return bm


def hank_path(tree, th0, e0, z_stop, rng, cling=0.0034, drift=0.0, hang_n=0):
    """A wet hank from the crown: follows the skull, clings down the cheek or neck,
    then (hang_n > 0) hangs off the skin in a few heavy steps."""
    C = Vector((0.0, -0.012, 0.165))
    pts, ns = [], []
    th, e = th0, e0
    while e > 0.3:                                               # over the dome
        d = Vector((math.sin(th) * math.cos(e), math.cos(th) * math.cos(e), math.sin(e)))
        hit = tree.ray_cast(C + d * 0.4, -d)
        if hit[0] is not None:
            pts.append(hit[0] + hit[1] * cling)
            ns.append(hit[1])
        e -= 0.27
        th += drift * 0.5 + rng.uniform(-0.03, 0.03)
    z = pts[-1].z if pts else 0.2
    while z > z_stop:
        z -= 0.019
        th += drift + rng.uniform(-0.03, 0.03)
        loc, n = ray_axis(tree, th, z)
        if loc is None or (pts and (loc - pts[-1]).length > 0.035):
            break
        pts.append(loc + n * cling)
        ns.append(n)
    for k in range(hang_n):
        q = pts[-1] + Vector((rng.uniform(-0.003, 0.003), rng.uniform(-0.003, 0.003), -0.017))
        pts.append(q)
        ns.append(ns[-1])
    return pts, ns


def head_hair(p, tree, rng):
    """Long dark hair in matted, wet hanks: plastered to the skull, cheek and neck,
    a few heavy ones hanging below the cut, blood-clotted toward the ends."""
    def hair_col(co, base):
        c = mixc(base, K.hexc("#241812"), 0.5 + 0.5 * nz(co.x * 90, co.y * 90, co.z * 25))
        c = mixc(c, K.hexc("#3A0E0C"), smooth(0.08, 0.03, co.z))      # blood climbing the ends
        return mixc(c, K.hexc("#200606"), smooth(0.03, -0.01, co.z))

    # (theta, start elevation, stop z, drift, half-width, hang steps)
    hanks = [
        (0.6, 1.15, 0.105, 0.03, 0.0085, 0), (1.05, 1.05, 0.06, -0.025, 0.009, 0),
        (-0.7, 1.15, 0.115, -0.03, 0.008, 0), (-1.15, 1.0, 0.07, 0.03, 0.0085, 0),
        (1.85, 1.15, 0.012, 0.0, 0.010, 0), (2.3, 1.2, 0.012, 0.01, 0.013, 3), (2.75, 1.2, 0.012, 0.0, 0.012, 0),
        (3.1, 1.2, 0.012, -0.01, 0.014, 4), (-2.9, 1.2, 0.012, 0.0, 0.011, 0), (-2.55, 1.15, 0.03, 0.0, 0.010, 0),
        (0.2, 1.2, 0.192, 0.06, 0.007, 0), (-0.15, 1.2, 0.195, -0.06, 0.007, 0),
        (1.5, 1.15, 0.19, 0.0, 0.009, 0), (-1.5, 1.15, 0.19, 0.0, 0.009, 0),
    ]
    for th0, e0, zs, drift, w0, hang in hanks:
        pts, ns = hank_path(tree, th0, e0, zs, rng, drift=drift, hang_n=hang)
        if len(pts) < 3:
            continue
        m = len(pts)
        ws = [w0 * (0.8 + 0.4 * math.sin(math.pi * min(1.0, 1.6 * i / (m - 1)))) *
              (1.0 - 0.7 * smooth(0.55, 1.0, i / (m - 1))) * (0.8 + 0.4 * rng.random()) for i in range(m)]
        base = K.hexc("#100A08") if rng.random() < 0.6 else K.hexc("#1C120E")
        emit(p, flat_tube(pts, ns, ws), lambda co, b=base: hair_col(co, b), "matte", sharp_deg=85)


def head_stump(p, rng):
    """Wet torn wound closing the neck, open at the centre for the heron's bill."""
    M = 22
    rings = []
    spec = [(1.012, -0.0004), (0.94, -0.0045), (0.62, 0.003), (0.36, 0.010), (0.17, 0.016), (0.15, 0.042)]
    for k, (rad, dz) in enumerate(spec):
        row = []
        for i in range(M):
            th = 2 * math.pi * (i + 0.5) / M - math.pi
            ze = neck_edge(th)
            q, _ = head_base(th, ze)
            rel = Vector((q.x - NECK_C.x, q.y - NECK_C.y, 0))
            j = 0.0 if k in (0, 5) else 0.002 * nz(math.cos(th) * 4, math.sin(th) * 4, k)
            zz = (ze if k < 2 else 0.0) + dz + j
            row.append(Vector((NECK_C.x + rel.x * rad, NECK_C.y + rel.y * rad, zz)))
        rings.append(row)
    bm = grid(rings, close=True, pole_top=Vector((NECK_C.x, NECK_C.y, 0.046)))

    def wound(co):
        rel = Vector((co.x - NECK_C.x, co.y - NECK_C.y))
        r = rel.length
        c = mixc(K.hexc("#4A070C"), K.hexc("#7A1018"), smooth(0.02, 0.045, r))
        c = mixc(c, K.hexc("#A8384A"), 0.5 * max(0.0, nz(co.x * 160, co.y * 160, 2.0)))
        c = mixc(c, K.hexc("#D9B9A0"), 0.6 * smooth(0.55, 0.8, nz(co.x * 220 + 4, co.y * 220, 1.0)))
        return mixc(c, K.hexc("#120203"), smooth(0.012, 0.007, r) + smooth(0.02, 0.04, co.z))

    emit(p, bm, wound, "satin", sharp_deg=75)
    # severed spine and windpipe
    p.add(torus(0.0105, 0.0042, 9, 3), K.hexc("#D8CDB6"), "satin",
          T(0, NECK_C.y - 0.030, -0.0005) @ S(1.0, 0.8, 1.0))
    p.add(sphere(0.0045, 6, 4), K.hexc("#B89A8C"), "satin", T(0, NECK_C.y - 0.030, -0.0008) @ S(1, 1, 0.5))
    p.add(torus(0.0078, 0.0024, 8, 3), K.hexc("#C79090"), "satin", T(0, NECK_C.y + 0.030, 0.0065))
    # clots hanging off the torn edge
    for th in (2.55, -1.25):
        ze = neck_edge(th)
        q, n = head_base(th, ze)
        q = q - n * 0.002
        p.add(sphere(0.0034, 6, 4), K.hexc("#4E070B"), "satin", T(*(q + Vector((0, 0, -0.0015)))) @ S(1.4, 1.4, 0.8))


def head_severed(p):
    rng = random.Random(613)
    bare = build_skin()                       # decimate the clean surface, then lay the hair on it
    skin = decimate_bm(bare, SKIN_TRIS / bm_tris(bare))
    add_hair(skin)
    tree = BVHTree.FromBMesh(skin)
    eye(p, tree, 1, (0.06, 1.0, -0.1), 4)
    eye(p, tree, -1, (-0.34, 1.0, 0.06), 0)   # the left one has drifted
    head_teeth(p, tree)
    head_ear(p, tree, 1)
    head_ear(p, tree, -1)
    head_sigil(p, tree)
    head_hair(p, tree, rng)
    # dried runs from the eyes and nose, the mouth and down the throat; wet only near the cut
    blood_trail(p, tree, [(0.021, 0.147), (0.022, 0.139), (0.026, 0.13), (0.028, 0.12), (0.027, 0.108),
                          (0.029, 0.097)], 0.003, 0.0018, DRIED, rng)
    blood_trail(p, tree, [(-0.022, 0.147), (-0.023, 0.138), (-0.021, 0.129), (-0.024, 0.118)],
                0.0028, 0.0018, DRIED, rng)
    blood_trail(p, tree, [(0.0072, 0.1175), (0.0068, 0.112), (0.009, 0.1065)], 0.0034, 0.0026, DRIED, rng, False)
    blood_trail(p, tree, [(0.017, 0.080), (0.018, 0.072), (0.016, 0.064), (0.018, 0.057)], 0.0048, 0.0026, DRIED,
                rng)
    blood_trail(p, tree, [(-0.012, 0.075), (-0.013, 0.068), (-0.011, 0.061)], 0.0042, 0.0022, DRIED, rng)
    blood_trail(p, tree, [(0.006, 0.050), (0.007, 0.040), (0.005, 0.030), (0.006, 0.021)], 0.0046, 0.003, WET, rng,
                False)
    blood_trail(p, tree, [(0.052, 0.205), (0.055, 0.192), (0.056, 0.18), (0.058, 0.168)], 0.0042, 0.0022, DRIED,
                rng)
    head_stump(p, rng)
    emit(p, skin, skin_color, "matte", sharp_deg=85)


# =============================================================== paint tins

TIN = K.hexc("#E7E1E6")


def paint_tin(p, paint, m, open_=True, fill=0.75):
    p.add(lathe([(0.0, 0.0), (0.0365, 0.0), (0.0365, 0.064), (0.0385, 0.067),
                 (0.0385, 0.0705), (0.034, 0.0705), (0.0335, 0.064), (0.0335, 0.05)], 12, cap_top=False),
          TIN, "pearl", m)
    p.add(cyl(0.0372, 0.034, 12, caps=False), paint, "satin", m @ T(0, 0, 0.016))
    p.add(torus(0.0373, 0.0016, 12, 3), GOLD, "gold", m @ T(0, 0, 0.050))
    if open_:
        p.add(K.disc(0.0335, 12, 0.07 * fill), paint, "satin", m)
    else:
        p.add(lathe([(0.0, 0.074), (0.03, 0.0735), (0.039, 0.071), (0.0395, 0.0695), (0.0, 0.0695)], 14),
              TIN, "pearl", m)
    # folded wire bail
    bail = [(0.0395 * math.cos(math.radians(a)), 0.0395 * math.sin(math.radians(a)), 0.052 + 0.0005 * k)
            for k, a in enumerate(range(-90, 91, 30))]
    p.add(tube(bail, 0.0013, 3), GOLD, "gold", m)


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
    emit(p, puddle(blob_outline(0.11, 0.06, 14, rng), 0.004), lambda c: peri_p, "satin",
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
    for i in range(6):
        x, y = rng.uniform(-0.29, 0.29), rng.uniform(-0.19, 0.19)
        r = rng.uniform(0.005, 0.011)
        p.add(sphere(r, 6, 4), K.mix(PEBBLE, K.hexc("#C8B2A6"), rng.random()), "matte",
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
        z = 0.004 + 0.012 * (0.5 + 0.5 * nz(x * 1.6, y * 1.6, 0.5))
        d = min(HX - abs(x), HY - abs(y))
        per = (x + 3 * y) if abs(HX - abs(x)) < abs(HY - abs(y)) else (3 * x + y)
        z += smooth(0.26, 0.0, d) * 0.03 * (0.55 + 0.45 * math.sin(per * 9.0 + 1.3 * nz(x, y, 3)))
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
    A, B, H = 0.228, 0.142, 0.205
    n = 36
    base = basket_outline(A, B, n)
    rows = []
    zs = [0.0, 0.01] + [0.01 + (H - 0.01) * k / 10 for k in range(1, 11)]
    for j, z in enumerate(zs):
        sc = 0.9 + 0.1 * (z / H)
        row = []
        for i, (x, y) in enumerate(base):
            o = Vector((x, y, 0)).normalized()
            bump = 0.0025 if (i + j) % 2 else 0.0
            row.append(Vector((x * sc, y * sc, z)) + o * bump)
        rows.append(row)
    body = grid(rows, close=True, pole_bottom=Vector((0, 0, 0.0)))

    def weave(c, f):
        a = math.atan2(c.y, c.x)
        i = int((a + math.pi) / (2 * math.pi) * n)
        j = int((c.z - 0.01) / ((H - 0.01) / 10) + 1)
        k = (i + j) % 2
        return mixc(STRAW, K.hexc("#D9AE6E"), k * 0.45 + 0.25 * (j % 4 == 0))

    emit(p, body, weave, "matte", per_face=True)
    # gingham lining
    lin = []
    for z in (0.015, H - 0.004):
        sc = (0.9 + 0.1 * z / H) * 0.955
        lin.append([Vector((x * sc, y * sc, z)) for x, y in base])
    emit(p, grid(lin, close=True, pole_bottom=Vector((0, 0, 0.015))),
         lambda c, f: BLUSH if int((math.atan2(c.y, c.x) + 3.2) * 6) % 2 else LINEN, "fabric", per_face=True)
    # wrapped cane rim
    rim = [Vector((x, y, H + 0.004)) for x, y in basket_outline(A + 0.002, B + 0.002, 30)]
    rimb = tube(rim, 0.009, 4, closed=True)
    emit(p, rimb, lambda c, f: STRAW_SHADE if int((math.atan2(c.y, c.x) + 3.2) * 9) % 2 else STRAW, "satin",
         per_face=True)
    # lids: the left one closed, the right one thrown open
    lid_out = basket_outline(A + 0.006, B + 0.006, 40)
    half = [q for q in lid_out if q[0] <= 0.0]
    half.sort(key=lambda q: math.atan2(q[1], q[0]) % (2 * math.pi))

    def lid(mirror):
        rows_ = []
        for k in range(5):
            t = k / 4
            rows_.append([Vector((x * t, y, 0.006 * math.sin(math.pi * (1 - t) / 2) + 0.004 * (1 - abs(y) / B)))
                          for x, y in half])
        b2 = grid(rows_)
        if mirror:
            bmesh.ops.scale(b2, vec=(-1, 1, 1), verts=b2.verts)
            bmesh.ops.reverse_faces(b2, faces=b2.faces)
        return b2

    def lid_weave(c, f):
        return STRAW if (int(abs(c.x) / 0.02) + int((c.y + 0.2) / 0.02)) % 2 else K.hexc("#E2BC7E")

    emit(p, lid(False), lid_weave, "matte", T(-0.002, 0, H + 0.008), per_face=True)
    edge = [Vector((x, y, 0.0)) for x, y in half]
    p.add(tube(edge, 0.006, 3), STRAW_SHADE, "satin", T(-0.002, 0, H + 0.008))
    hinge = T(0.002, 0, H + 0.010) @ R("Y", -112)
    emit(p, lid(True), lid_weave, "matte", hinge, per_face=True)
    edge2 = [Vector((-x, y, 0.0)) for x, y in half]
    p.add(tube(edge2, 0.006, 3), STRAW_SHADE, "satin", hinge)
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
    p.add(sphere(0.06, 10, 6), CRUST, "satin", T(0.075, -0.05, H + 0.008) @ R("Z", 25) @ S(1.35, 0.85, 0.62))
    for k in range(3):
        p.add(K.box(0.008, 0.07, 0.004), CRUST_DARK, "matte",
              T(0.06 + k * 0.035, -0.05, H + 0.044) @ R("Z", 40) @ R("X", 8))
    bottle = lathe([(0.0, 0.0), (0.033, 0.0), (0.034, 0.16), (0.03, 0.19), (0.013, 0.215), (0.012, 0.27),
                    (0.0135, 0.275), (0.0, 0.276)], 10)
    bm_ = T(0.15, -0.075, 0.03) @ R("X", 14) @ R("Y", -6)
    p.add(bottle, K.hexc("#C9E6D5"), "glass", bm_)
    p.add(cyl(0.0305, 0.14, 10), K.hexc("#F6C7D4"), "satin", bm_ @ T(0, 0, 0.004))
    p.add(cyl(0.0138, 0.045, 10), GOLD, "gold", bm_ @ T(0, 0, 0.235))
    for i, (x, y, z, yaw) in enumerate(((0.06, 0.07, H + 0.025, 20), (0.1, 0.09, H + 0.03, 110),
                                        (0.15, 0.075, H + 0.022, 200),
                                        (0.262, 0.1, 0.012, 140))):
        m = T(x, y, z) @ R("Z", yaw) @ R("Y", 80 if i >= 4 else 60)
        p.add(lathe([(0.0, 0.0), (0.006, 0.004), (0.0115, 0.014), (0.012, 0.021), (0.007, 0.027), (0.0, 0.028)],
                    7), BERRY, "satin", m @ T(0, 0, -0.014))
        for j in range(4):
            p.add(K.leaf(0.011, 0.006), SAGE_DEEP, "leaf", m @ T(0, 0, 0.013) @ R("Z", 90 * j) @ R("Y", -25),
                  smooth=False)


# =============================================================== maypole


def maypole_solstice(p):
    rng = random.Random(66)
    H = 6.0
    p.add(lathe([(0.0, 0.0), (0.36, 0.0), (0.36, 0.08), (0.30, 0.12), (0.30, 0.2), (0.22, 0.26), (0.12, 0.3),
                 (0.0, 0.3)], 12), PEARL, "pearl")
    p.add(torus(0.33, 0.022, 12, 4), GOLD, "gold", T(0, 0, 0.1))
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
    for i in range(6):
        a = 2 * math.pi * i / 6
        c = Vector((0.15 * math.cos(a), 0.15 * math.sin(a), H - 0.04))
        rose(p, c, 0.12, crown_cols[i], rng, tilt=R("Z", math.degrees(a)) @ R("Y", 35))
        for j in (-1, 1):
            leaf_at(p, (c.x, c.y, c.z - 0.03), 0.17, 0.07, math.degrees(a) + 30 * j, -10)
    # eight ribbons sweeping out and round to their stakes
    rib_cols = [ROSE, BLUSH, LILAC, PERI, MINT, BUTTER, PEARL, CORNFLOWER]
    for i in range(8):
        a0 = 2 * math.pi * i / 8
        a1 = a0 + math.radians(38)
        pts, ns, ws = [], [], []
        nseg = 20
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
            ws.append(0.12)
        emit(p, strip(pts, ns, ws), lambda c, col=rib_cols[i]: col, "satin", smooth_=False)
        sx, sy = 1.4 * math.cos(a1), 1.4 * math.sin(a1)
        p.add(cyl(0.028, 0.36, 6, 0.02), K.OAK, "satin", T(sx, sy, 0.0))
        p.add(sphere(0.035, 6, 4), GOLD, "gold", T(sx, sy, 0.37))
        p.add(sphere(0.045, 5, 3), rib_cols[i], "satin", T(sx, sy, 0.31) @ S(1, 1, 0.6))
        tail = [(sx, sy, 0.31), (sx * 1.04, sy * 1.04, 0.2), (sx * 1.06, sy * 1.06, 0.02)]
        emit(p, strip(tail, [(-math.sin(a1), math.cos(a1), 0)] * 3, [0.1, 0.09, 0.08]),
             lambda c, col=rib_cols[i]: col, "satin", smooth_=False)
    # garland round the foot
    gcols = [ROSE, BUTTER, BLUSH, LILAC, PEARL, MINT, PERI, DEEP_BLUSH, BUTTER]
    for i in range(6):
        a = 2 * math.pi * i / 6 + 0.2
        c = Vector((0.36 * math.cos(a), 0.36 * math.sin(a), 0.17))
        rose(p, c, 0.11, gcols[i], rng, tilt=R("Z", math.degrees(a)) @ R("Y", 50))
        for j in (-1, 1):
            leaf_at(p, (0.36 * math.cos(a + 0.3 * j), 0.36 * math.sin(a + 0.3 * j), 0.13), 0.17, 0.07,
                    math.degrees(a) + 55 * j, 10)


# =============================================================== wine table


def wine_table_solstice(p):
    rng = random.Random(67)
    A, B, H = 0.84, 0.35, 0.74
    n = 36

    def rr(t, s=1.0):
        c, si = math.cos(t), math.sin(t)
        return Vector((A * s * math.copysign(abs(c) ** 0.8, c), B * s * math.copysign(abs(si) ** 0.8, si), 0))

    def outw(t):
        return Vector((math.cos(t) / A, math.sin(t) / B, 0)).normalized()

    # gilt cabriole legs, knees out, showing under the cloth
    for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        yaw = math.degrees(math.atan2(sy, sx)) - 45
        p.add(K.cabriole(0.44, 0.024), GOLD, "gold", T(sx * 0.62, sy * 0.21, 0.0) @ R("Z", yaw))
        p.add(sphere(0.026, 6, 4), GOLD_DEEP, "gold", T(sx * 0.632, sy * 0.222, 0.018) @ S(1, 1, 0.7))
    # pearl cloth: a short skirt with soft folds and a scalloped hem
    ts = [2 * math.pi * (i + 0.5) / n for i in range(n)]
    rows = []
    for z, sc, fold in ((0.40, 1.05, 1.0), (0.52, 1.035, 0.7), (0.64, 1.015, 0.35), (H - 0.012, 1.0, 0.05),
                        (H, 0.982, 0.0)):
        row = []
        for i, t in enumerate(ts):
            hem = 0.035 * abs(math.sin(i * math.pi / 4)) if z < 0.45 else 0.0
            row.append(rr(t, sc) + outw(t) * (0.016 * fold * math.sin(i * 2.5)) + Vector((0, 0, z + hem)))
        rows.append(row)
    rows.append([rr(t, 0.6) + Vector((0, 0, H)) for t in ts])
    emit(p, grid(rows, close=True, pole_top=Vector((0, 0, H))), lambda c: LINEN, "pearl")
    hem = [Vector((q.x, q.y, q.z)) + outw(ts[i]) * 0.003 for i, q in enumerate(rows[0])]
    p.add(tube(hem, 0.0065, 3, closed=True), GOLD, "gold")
    # blush swags caught up with little roses
    for k in range(8):
        t0, t1 = 2 * math.pi * k / 8, 2 * math.pi * (k + 1) / 8
        pts, ns = [], []
        for j in range(7):
            t = lerp(t0, t1, j / 6)
            pts.append(rr(t, 1.013) + Vector((0, 0, H - 0.03 - 0.085 * math.sin(math.pi * j / 6))) + outw(t) * 0.006)
            ns.append(outw(t))
        emit(p, strip(pts, ns, [0.034] * 7), lambda c, k=k: DEEP_BLUSH if k % 2 else BLUSH, "satin", smooth_=False)
        q = rr(t0, 1.02) + outw(t0) * 0.012
        p.add(sphere(0.022, 5, 3), ROSE if k % 2 else BUTTER, "fabric", T(q.x, q.y, H - 0.03) @ S(1, 1, 0.8))
        leaf_at(p, (q.x, q.y, H - 0.04), 0.05, 0.025, math.degrees(t0) + 60, 30)
    # crystal decanter of faerie wine, gold-mounted, the wine glowing
    dec = T(0, 0, H)
    p.add(lathe([(0.0, 0.0), (0.06, 0.0), (0.04, 0.012), (0.075, 0.05), (0.095, 0.1), (0.08, 0.15), (0.03, 0.19),
                 (0.022, 0.27), (0.03, 0.285)], 11, cap_top=False), K.GLASS_TINT, "glass", dec)
    p.add(lathe([(0.0, 0.013), (0.04, 0.014), (0.07, 0.05), (0.088, 0.1), (0.074, 0.14), (0.0, 0.142)], 10),
          FAE_WINE, "glow", dec)
    p.add(lathe([(0.0, 0.0), (0.068, 0.0), (0.07, 0.01), (0.045, 0.016), (0.0, 0.016)], 11), GOLD, "gold", dec)
    p.add(torus(0.027, 0.006, 10, 3), GOLD, "gold", dec @ T(0, 0, 0.2))
    p.add(lathe([(0.0, 0.27), (0.024, 0.275), (0.03, 0.3), (0.018, 0.33), (0.0, 0.345)], 8), GOLD, "gold", dec)
    # six gold goblets, poured
    for i, (x, y) in enumerate(((-0.62, 0.12), (-0.5, -0.17), (-0.33, 0.2), (0.3, -0.21), (0.52, 0.16),
                                (0.66, -0.08))):
        m = T(x, y, H)
        p.add(lathe([(0.0, 0.0), (0.038, 0.0), (0.012, 0.016), (0.008, 0.07), (0.036, 0.105), (0.04, 0.165),
                     (0.0, 0.112)], 7), GOLD, "gold", m)
        p.add(K.disc(0.035, 7, 0.15), FAE_WINE, "glow", m)
    # gilt comport heaped with peaches and grapes
    cm = T(-0.22, -0.04, H)
    p.add(lathe([(0.0, 0.0), (0.06, 0.0), (0.016, 0.03), (0.014, 0.08), (0.11, 0.11), (0.12, 0.125), (0.0, 0.1)],
                10), GOLD, "gold", cm)
    for k in range(2):
        a = math.pi * k + 0.6
        p.add(sphere(0.042, 8, 5), PEACH, "satin", cm @ T(0.04 * math.cos(a), 0.05 * math.sin(a), 0.14))
    for k in range(6):
        a = k * 2.4
        r = 0.012 * math.sqrt(k)
        p.add(sphere(0.017, 6, 4), GRAPE, "satin", cm @ T(0.06 + r * math.cos(a), r * math.sin(a), 0.19 - 0.008 * k))
    leaf_at(p, (cm.translation.x + 0.08, cm.translation.y - 0.06, H + 0.13), 0.08, 0.04, -40)
    # a posy in a pearl bud vase
    vm = T(0.22, 0.04, H)
    p.add(lathe([(0.0, 0.0), (0.03, 0.0), (0.045, 0.05), (0.02, 0.11), (0.026, 0.13), (0.0, 0.12)], 8), PEARL,
          "pearl", vm)
    for c, dx, dy, dz in ((ROSE, 0.0, 0.0, 0.2), (BUTTER, 0.04, 0.02, 0.17), (LILAC, -0.035, 0.025, 0.175)):
        rose(p, (0.22 + dx, 0.04 + dy, H + dz), 0.045, c, rng, tilt=R("X", dy * 600) @ R("Y", dx * 600))
    for j in range(4):
        leaf_at(p, (0.22, 0.04, H + 0.13), 0.08, 0.035, 90 * j + 20, -30)


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
    p.add(sphere(0.026, 10, 6), EBONY, "satin", T(-0.142, -0.042, 0.044) @ S(1.1, 0.85, 0.22))
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


def painterly(kind):
    """A small oil sketch as a colour field (u, v in 0..1), dabbed with noise like brushwork."""
    def f(u, v):
        ju = u + 0.03 * nz(u * 9, v * 9, 1.0)
        jv = v + 0.03 * nz(u * 9, v * 9, 7.0)
        if kind == "meadow":
            c = mixc(K.hexc("#FCE3D3"), K.hexc("#BFCBF7"), smooth(0.45, 1.0, jv))
            c = mixc(c, K.hexc("#FFE9A6"), smooth(0.13, 0.0, math.hypot(ju - 0.7, (jv - 0.7) * 1.2)))
            far = 0.47 + 0.07 * math.sin(ju * 5.0 + 0.5)
            c = mixc(c, K.hexc("#C3C2EC"), smooth(far + 0.02, far - 0.02, jv))
            near = 0.3 + 0.08 * math.sin(ju * 6.5 + 2.0)
            c = mixc(c, K.hexc("#9ED6B0"), smooth(near + 0.02, near - 0.02, jv))
            return mixc(c, K.hexc("#7FBF98"), smooth(0.2, 0.0, jv) * 0.6)
        if kind == "roses":
            c = mixc(K.hexc("#FBEFF2"), K.hexc("#F3D3DE"), jv)
            for cx, cv, col in ((0.35, 0.58, ROSE), (0.64, 0.46, DEEP_BLUSH), (0.5, 0.74, BUTTER)):
                c = mixc(c, col, smooth(0.16, 0.08, math.hypot(ju - cx, jv - cv)))
            return mixc(c, SAGE, smooth(0.05, 0.02, abs(ju - 0.5)) * smooth(0.5, 0.4, jv))
        return mixc(K.hexc("#D9E8F6"), K.hexc("#EAD9F6"), jv)
    return f


def painted_canvas(p, w, h, m, kind, framed=None, rng=None, front=False):
    """Stretched canvas standing in the XZ plane, painted face toward +Y, base at z=0."""
    d = 0.016
    p.add(K.box(w, d, h, bevel=0.0025, seg=1), K.hexc("#F4EBDD"), "matte", m @ T(0, 0, h / 2))
    nu, nv = (26, 22) if front else (5, 4)
    rows = [[Vector((-w / 2 + 0.005 + (w - 0.01) * i / nu, d / 2 + 0.0008, 0.005 + (h - 0.01) * j / nv))
             for i in range(nu + 1)] for j in range(nv + 1)]
    pf = painterly(kind)
    emit(p, grid(rows), lambda c: pf((c.x + w / 2) / w, c.z / h), "satin", m, smooth_=False)
    if front and kind == "meadow":
        # impasto dabs: wildflowers in the near grass
        for k in range(9):
            u, v = 0.08 + 0.84 * rng.random(), 0.04 + 0.2 * rng.random()
            col = [ROSE, BUTTER, PEARL, LILAC][k % 4]
            p.add(sphere(0.008, 5, 3), col, "satin",
                  m @ T(-w / 2 + u * w, d / 2 + 0.0015, v * h) @ S(1.0, 0.35, 0.8))
    if framed:
        fo = [(-w / 2 - 0.01, -0.01), (w / 2 + 0.01, -0.01), (w / 2 + 0.01, h + 0.01), (-w / 2 - 0.01, h + 0.01)]
        p.add(tube([(x, d / 2, z) for x, z in fo], 0.014, 4, closed=True), framed,
              "gold" if framed == GOLD else "pearl", m)


def paintings_bundle(p):
    rng = random.Random(69)
    specs = [  # w, h, x, y, roll, kind, frame
        (0.6, 0.56, 0.02, -0.036, 1.5, "plain", GOLD),
        (0.5, 0.5, -0.06, -0.018, -2.5, "roses", None),
        (0.46, 0.58, 0.07, 0.0, 2.0, "plain", PEARL),
        (0.44, 0.44, -0.03, 0.018, -1.5, "roses", None),
        (0.52, 0.47, 0.01, 0.036, 1.0, "meadow", None),
    ]
    for i, (w, h, x, y, roll, kind, frame) in enumerate(specs):
        painted_canvas(p, w, h, T(x, y, 0.012) @ R("Y", roll), kind, frame, rng, front=(i == len(specs) - 1))
    # blush ribbon round the bundle both ways, bowed at the front
    ry, rx = 0.051, 0.345
    for path in ([(-rx, -ry, 0.27), (rx, -ry, 0.27), (rx, ry, 0.27), (-rx, ry, 0.27), (-rx, -ry, 0.27)],
                 [(0.05, -ry, 0.0), (0.05, -ry, 0.6), (0.05, ry, 0.6), (0.05, ry, 0.0), (0.05, -ry, 0.0)]):
        pts, ns = [], []
        for a, b in zip(path, path[1:]):
            a, b = Vector(a), Vector(b)
            for k in range(3):
                pts.append(a.lerp(b, k / 3))
        pts.append(Vector(path[-1]))
        horiz = path[0][2] == path[1][2]
        for q in pts:
            ns.append(Vector((q.x, q.y * 6, 0)).normalized() if horiz else
                      Vector((0, q.y, (q.z - 0.3) * 0.25)).normalized())
        emit(p, strip(pts, ns, [0.032] * len(pts)), lambda c: DEEP_BLUSH, "satin", smooth_=False)
    bow = T(0.05, ry + 0.006, 0.27)
    for s_ in (1, -1):
        p.add(torus(0.042, 0.011, 10, 4), DEEP_BLUSH, "satin", bow @ T(s_ * 0.042, 0.003, 0.012) @ R("Y", s_ * 20)
              @ R("X", 90) @ S(1, 0.55, 1))
        tail = [(0, 0.004, 0), (s_ * 0.03, 0.008, -0.06), (s_ * 0.05, 0.006, -0.12)]
        emit(p, strip(tail, [(0, 1, 0)] * 3, [0.03, 0.028, 0.024]), lambda c: DEEP_BLUSH, "satin", bow,
             smooth_=False)
    p.add(sphere(0.015, 8, 6), ROSE, "satin", bow @ T(0, 0.005, 0) @ S(1, 0.7, 1))


# =============================================================== lantern string


def solstice_lantern_string(p):
    L = 2.95
    sag = 0.27
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
        r = 0.1 if i % 2 == 0 else 0.086
        hh = r * 1.85
        drop = 0.06 + 0.03 * (i % 3 == 1)
        ztop = zc - drop
        prof = [(0.0, -hh / 2), (r * 0.42, -hh / 2 + 0.003)]
        for k in range(1, 6):
            t = k / 6
            rad = r * math.sin(math.pi * t) ** 0.7 * (1.0 if k % 2 else 0.94)
            prof.append((max(rad, r * 0.42), -hh / 2 + hh * t))
        prof += [(r * 0.42, hh / 2 - 0.003), (0.0, hh / 2)]
        m = T(x, 0, ztop - hh / 2)
        emit(p, lathe(prof, 8), lambda c, col=cols[i]: col, "glow", m)
        p.add(cyl(r * 0.45, 0.02, 8), GOLD, "gold", m @ T(0, 0, hh / 2 - 0.01))
        p.add(cyl(r * 0.45, 0.016, 8), GOLD, "gold", m @ T(0, 0, -hh / 2 - 0.006))
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
    lo.data.validate(clean_customdata=False)     # drop faces the collapse left degenerate
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


def sheet(path, only=None):
    import numpy as np
    K.reset()
    built = {}
    for pid in BUILDERS:
        if only and pid not in only:
            continue
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
    head = built.get("head_severed")
    for name, az, el, res, gr in (("head_a", 28, 8, 1024, True), ("head_b", -128, 12, 512, True),
                                  ("head_c", 20, -60, 512, False)):
        if head is None:
            break
        f = os.path.join(tmp, name + ".png")
        render_tile([head], None, f, res, az, el, gr)
        tiles.append(f)
    for pid in list(BUILDERS)[1:]:
        if pid not in built:
            continue
        f = os.path.join(tmp, pid + ".png")
        render_tile([built[pid]], None, f, 512, 35, 24)
        tiles.append(f)

    def load(f):
        im = bpy.data.images.load(f)
        w, h = im.size
        a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        bpy.data.images.remove(im)
        return np.flipud(a)

    if only:
        print("tiles in", tmp)
        return
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
        sheet(args[args.index("--sheet") + 1], only)
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
        if n0 > CAPS.get(pid, MAX_TRIS) or size > 2 * 1024 * 1024:
            over.append(pid)
    if over:
        print("OVER BUDGET:", ", ".join(over))
        sys.exit(1)


if __name__ == "__main__":
    main()
