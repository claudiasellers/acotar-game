"""Picture frames for the manor's paintings (L39), headless Blender.

Run:  /opt/bpyenv/bin/python tools/blender/manor_frames.py [--preview dir]
Out:  world/spring_court/manor_estate/art/frames/<style>_<shape>.glb, nodes
      "<style>_<shape>" and "<style>_<shape>_lod1" (~55% tris).

Each frame surrounds a canvas whose long side is 1.0 m, centred on the
origin in the canvas plane (Blender XZ), front facing +Y (Godot -Z). The
game scales a frame uniformly to its painting, so mouldings grow with the
picture the way real ones do. A small plaque hangs under every frame; its
engraving is illegible (Feyre can't read, ch13).

Shapes (canvas width x height, matched by ManorArtCanvas in Godot):
  land 1.0 x 0.703, port 0.75 x 1.0, full 0.667 x 1.0, square 1 x 1,
  oval_p 0.8 x 1.0 / oval_l 1.0 x 0.8 (ellipses), round 1 x 1 (circle),
  arch_p 0.75 x 1.0 (a rectangle with a half-round top).

Frames use the prop_kit finishes only (gold, pearl, satin...), so in a room
they merge into the props' existing draw calls. Budget: <= 3,000 tris.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,I001
import bmesh  # noqa: E402
import prop_kit as K  # noqa: E402
from prop_kit import T, R, S  # noqa: E402

OUT = os.path.join(K.ROOT, "world/spring_court/manor_estate/art/frames")
MAX_TRIS = 3000
N_CURVE = 32  # segments of an oval/round/arch outline (the Godot canvas uses the same)

SHAPES = {
    "land": ("rect", 1.0, 0.703), "port": ("rect", 0.75, 1.0), "full": ("rect", 0.667, 1.0),
    "square": ("rect", 1.0, 1.0), "oval_p": ("oval", 0.8, 1.0), "oval_l": ("oval", 1.0, 0.8),
    "round": ("oval", 1.0, 1.0), "arch_p": ("arch", 0.75, 1.0),
}

GILT = K.GOLD
GILT_DEEP = K.GOLD_DEEP
WALNUT = (0.42, 0.27, 0.22)
EBONY = (0.16, 0.11, 0.15)
SILVER = (0.80, 0.80, 0.86)
PEARLC = (0.85, 0.82, 0.84)
CREAM = (0.85, 0.80, 0.70)
LILAC = (0.72, 0.62, 0.86)
ROSE = (0.90, 0.52, 0.62)
BLUSH = (0.92, 0.70, 0.74)
SAGE = K.SAGE
BUTTER = (0.95, 0.85, 0.50)
INK = (0.30, 0.22, 0.20)


# --------------------------------------------------------------- outlines

def outline(kind, w, h):
    """Closed outline of the canvas opening, counter-clockwise in (x, z)."""
    if kind == "rect":
        return [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
    if kind == "oval":
        return [(w / 2 * math.cos(2 * math.pi * i / N_CURVE - math.pi / 2), h / 2 * math.sin(2 * math.pi * i / N_CURVE - math.pi / 2))
                for i in range(N_CURVE)]
    # arch: straight sides up to h/2 - w/2, then a half circle of radius w/2
    top = h / 2 - w / 2
    pts = [(-w / 2, -h / 2), (w / 2, -h / 2)]
    n = N_CURVE // 2
    for i in range(n + 1):
        a = math.pi * i / n
        pts.append((w / 2 * math.cos(a), top + w / 2 * math.sin(a)))
    return pts


def _normals(pts):
    """Outward mitre vectors at each vertex of a CCW outline."""
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        e0 = (p1[0] - p0[0], p1[1] - p0[1])
        e1 = (p2[0] - p1[0], p2[1] - p1[1])
        l0 = math.hypot(*e0) or 1.0
        l1 = math.hypot(*e1) or 1.0
        n0 = (e0[1] / l0, -e0[0] / l0)
        n1 = (e1[1] / l1, -e1[0] / l1)
        m = (n0[0] + n1[0], n0[1] + n1[1])
        ml = math.hypot(*m) or 1.0
        m = (m[0] / ml, m[1] / ml)
        cos = max(0.35, m[0] * n0[0] + m[1] * n0[1])
        out.append((m[0] / cos, m[1] / cos))
    return out


def sweep(pts, profile):
    """A moulding: profile [(o, y)] (o outward from the opening, y toward the
    viewer) swept around the closed outline with mitred corners."""
    bm = bmesh.new()
    nm = _normals(pts)
    rows = []
    for (x, z), (mx, mz) in zip(pts, nm):
        rows.append([bm.verts.new((x + mx * o, y, z + mz * o)) for o, y in profile])
    n = len(pts)
    for i in range(n):
        a, b = rows[i], rows[(i + 1) % n]
        for j in range(len(profile) - 1):
            bm.faces.new((a[j], b[j], b[j + 1], a[j + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def flat_ring(pts, o0, o1, y):
    return sweep(pts, [(o0, y), (o1, y)])


def point_on(pts, nm, t, o):
    """A point o outward from the outline at parameter t (0..1 along it)."""
    n = len(pts)
    seg = [math.hypot(pts[(i + 1) % n][0] - pts[i][0], pts[(i + 1) % n][1] - pts[i][1]) for i in range(n)]
    total = sum(seg)
    d = t * total
    for i in range(n):
        if d <= seg[i] or i == n - 1:
            k = d / seg[i] if seg[i] else 0
            p = (pts[i][0] + (pts[(i + 1) % n][0] - pts[i][0]) * k, pts[i][1] + (pts[(i + 1) % n][1] - pts[i][1]) * k)
            e = (pts[(i + 1) % n][0] - pts[i][0], pts[(i + 1) % n][1] - pts[i][1])
            el = math.hypot(*e) or 1.0
            nn = (e[1] / el, -e[0] / el)
            return (p[0] + nn[0] * o, p[1] + nn[1] * o)
        d -= seg[i]
    return pts[0]


# --------------------------------------------------------------- profiles (o outward, y forward), long side = 1 m

P_OGEE = [(-0.012, 0.004), (0.0, 0.010), (0.010, 0.018), (0.018, 0.016), (0.028, 0.024), (0.040, 0.040),
          (0.055, 0.050), (0.068, 0.048), (0.080, 0.036), (0.088, 0.020), (0.090, -0.020)]
P_BAROQUE = [(-0.012, 0.004), (0.0, 0.012), (0.008, 0.022), (0.016, 0.018), (0.024, 0.020), (0.040, 0.034),
             (0.058, 0.056), (0.074, 0.068), (0.092, 0.064), (0.106, 0.050), (0.116, 0.030), (0.122, 0.012), (0.124, -0.024)]
P_FLAT = [(-0.012, 0.004), (0.0, 0.008), (0.006, 0.014), (0.012, 0.014), (0.016, 0.010)]
P_WIDE = [(0.016, 0.010), (0.020, 0.022), (0.090, 0.028), (0.100, 0.026), (0.106, 0.016), (0.108, -0.022)]
P_ROUND = [(-0.012, 0.004), (0.0, 0.010), (0.012, 0.020), (0.028, 0.032), (0.046, 0.036), (0.062, 0.030),
           (0.072, 0.016), (0.074, -0.020)]
P_THIN = [(-0.010, 0.004), (0.0, 0.010), (0.010, 0.016), (0.024, 0.022), (0.036, 0.018), (0.044, 0.006), (0.045, -0.018)]


def back_panel(p, pts, o, depth=0.022):
    """A dark board behind the canvas and frame (nothing shows through)."""
    nm = _normals(pts)
    outer = [(x + mx * o, z + mz * o) for (x, z), (mx, mz) in zip(pts, nm)]
    p.add(K.slab(outer, 0.004), (0.18, 0.13, 0.12), "matte", T(0, -depth, 0))


def plaque(p, w, h, color=GILT, drop=0.03):
    """A small plate under the frame; its lines are illegible on purpose."""
    pw, ph = 0.14, 0.038
    z = -h / 2 - drop - ph / 2
    p.add(K.box(pw, 0.008, ph, bevel=0.003), color, "gold", T(0, -0.004, z))
    rng = random.Random(int(w * 1000 + h * 7))
    for i in range(2):
        lw = pw * rng.uniform(0.5, 0.75)
        p.add(K.box(lw, 0.002, 0.003), INK, "matte", T(rng.uniform(-0.01, 0.01), 0.0015, z + (0.006 if i == 0 else -0.006)))
    for sx in (-1, 1):
        p.add(K.sphere(0.0035, 6, 4), color, "gold", T(sx * (pw / 2 - 0.008), 0.002, z))


# --------------------------------------------------------------- ornaments

def shell_crest(p, x, z, s, y=0.05, color=GILT):
    """A gilt shell flanked by scrolls, facing +Y."""
    for k in range(7):
        a = math.radians(-60 + 20 * k)
        p.add(K.cyl(s * 0.07, s * 0.55, 5, r2=s * 0.03), color, "gold", T(x, y, z) @ R("Y", math.degrees(a)) @ R("X", -90) @ R("X", 90))
    p.add(K.lathe([(0, 0), (s * 0.32, s * 0.08), (s * 0.28, s * 0.22), (0, s * 0.3)], 8), color, "gold", T(x, y, z - s * 0.05) @ S(1.2, 0.35, 1))
    for sx in (-1, 1):
        p.add(K.scroll(s * 0.35, 1.3, 10, s * 0.05), color, "gold", T(x + sx * s * 0.45, y, z - s * 0.1) @ S(sx, 1, 1) @ R("Y", 180))


def corner_scrolls(p, cx, cz, s, ang, y=0.05, color=GILT):
    m = T(cx, y, cz) @ R("Y", ang)
    p.add(K.scroll(s * 0.5, 1.4, 10, s * 0.06), color, "gold", m @ T(s * 0.3, 0, 0))
    p.add(K.scroll(s * 0.5, 1.4, 10, s * 0.06), color, "gold", m @ R("Y", -90) @ S(-1, 1, 1) @ T(s * 0.3, 0, 0))
    p.add(K.lathe([(0, 0), (s * 0.25, s * 0.06), (s * 0.18, s * 0.2), (0, s * 0.26)], 6), color, "gold", m @ R("X", -90) @ S(1, 1, 0.5))


def acanthus(p, x, z, s, ang, y, color=GILT, n=3):
    for k in range(n):
        a = ang + (k - (n - 1) / 2) * 35
        p.add(K.leaf(s, s * 0.45), color, "gold", T(x, y, z) @ R("Y", -a) @ R("X", 90))


def rose_cluster(p, x, z, s, y, cols, rng, n=3):
    for k in range(n):
        dx = (k - (n - 1) / 2) * s * 1.3
        K.bloom(p, (x + dx, y, z + rng.uniform(-0.2, 0.2) * s), s * 0.55, cols[k % len(cols)], rings=2, per=4, rng=rng,
                tilt=R("X", -90), finish="satin")
        for sgn in (-1, 1):
            p.add(K.leaf(s * 0.9, s * 0.4), SAGE, "leaf", T(x + dx + sgn * s * 0.5, y - s * 0.1, z - s * 0.3) @ R("Y", 90 + sgn * 50) @ R("X", 90))


def crocus(p, x, z, s, y, col, ang=0.0):
    """A crocus, Spring's flower (ch13), facing the viewer, with two blades."""
    for sgn in (-1, 1):
        p.add(K.leaf(s * 1.7, s * 0.3), SAGE, "leaf", T(x, y - 0.004, z) @ R("Y", -ang - 90 + sgn * 28) @ R("X", 90))
    K.star_flower(p, (x, y + 0.004, z), s, col, n=6, finish="satin", heart=BUTTER, facing=R("X", -90))


def ribbon_bow(p, x, z, s, y, col):
    for sx in (-1, 1):
        loop = [(x + sx * s * (0.1 + 0.9 * math.sin(t * math.pi) * (0.5 + 0.5 * t)), y, z + s * 0.45 * math.sin(t * 2 * math.pi) * 0.6)
                for t in [i / 10 for i in range(11)]]
        p.add(K.tube(loop, s * 0.09, 5), col, "satin")
        tail = [(x + sx * s * 0.1, y, z), (x + sx * s * 0.45, y + 0.004, z - s * 0.7), (x + sx * s * 0.35, y + 0.006, z - s * 1.3)]
        p.add(K.tube(tail, [s * 0.08, s * 0.07, s * 0.05], 5), col, "satin")
    p.add(K.sphere(s * 0.16, 8, 5), col, "satin", T(x, y + 0.004, z))


def leaf_mask(p, x, z, s, y, col=GILT):
    """A Spring Court leaf mask as a crest (post-curse emblem): a solid gilt
    half-mask with dark eye holes, leaves fanning from its outer corners."""
    pts = []
    for i in range(25):
        t = i / 24
        a = math.pi * 2 * t
        # a wide almond, its outer corners swept up like leaf tips
        px = math.cos(a) * s * 0.5
        pz = math.sin(a) * s * 0.17 + abs(math.cos(a)) ** 6 * s * 0.12
        if math.sin(a) < 0:
            pz -= (1 - abs(math.cos(a))) * s * 0.05  # the nose notch
        pts.append((x + px, z + pz))
    p.add(K.slab(pts[:-1], s * 0.06), col, "gold", T(0, y, 0))
    for sx in (-1, 1):
        p.add(K.sphere(1.0, 10, 6), (0.12, 0.08, 0.10), "matte", T(x + sx * s * 0.2, y + s * 0.032, z + s * 0.01) @ S(s * 0.1, s * 0.01, s * 0.06))
        for k, (ang, ln) in enumerate(((35, 0.42), (60, 0.5), (85, 0.36))):
            p.add(K.leaf(s * ln, s * 0.17), col, "gold", T(x + sx * s * 0.45, y, z + s * 0.12) @ R("Y", -(90 - ang) if sx > 0 else -(90 + ang)) @ R("X", 90))
    p.add(K.leaf(s * 0.3, s * 0.14), col, "gold", T(x, y, z + s * 0.12) @ R("Y", -90) @ R("X", 90))


# --------------------------------------------------------------- styles

def _frame(p, pts, prof, col, finish="gold"):
    p.add(sweep(pts, prof), col, finish, smooth=True, sharp_deg=55.0)
    return prof[-1][0]


def st_gilt_baroque(p, kind, w, h, pts):
    o = _frame(p, pts, P_BAROQUE, GILT)
    rng = random.Random(3)
    s = 0.15
    if kind == "rect":
        for sx in (-1, 1):
            for sz in (-1, 1):
                corner_scrolls(p, sx * (w / 2 + o * 0.45), sz * (h / 2 + o * 0.45), s, 45 if sx * sz > 0 else -45, 0.06)
        shell_crest(p, 0, h / 2 + o * 0.7, 0.26, 0.07)
        acanthus(p, 0, -h / 2 - o * 0.45, 0.11, 90, 0.065, n=3)
    else:
        shell_crest(p, 0, h / 2 + o * 0.7, 0.24, 0.07)
    return o


def st_gilt_simple(p, kind, w, h, pts):
    return _frame(p, pts, P_OGEE, GILT_DEEP)


def st_walnut_gold(p, kind, w, h, pts):
    _frame(p, pts, P_FLAT, GILT)
    o = _frame(p, pts, P_WIDE, WALNUT, "satin")
    p.add(flat_ring(pts, o - 0.012, o - 0.006, 0.029), GILT, "gold")
    return o


def st_silver_leaf(p, kind, w, h, pts):
    o = _frame(p, pts, P_OGEE, SILVER, "pearl")
    if kind == "rect":
        for sx in (-1, 1):
            for sz in (-1, 1):
                acanthus(p, sx * (w / 2 + o * 0.5), sz * (h / 2 + o * 0.5), 0.09, math.degrees(math.atan2(sz, sx)), 0.05, SILVER, n=3)
    return o


def st_ebony_dark(p, kind, w, h, pts):
    _frame(p, pts, P_FLAT, GILT_DEEP)
    return _frame(p, pts, P_WIDE, EBONY, "satin")


def st_crocus_spring(p, kind, w, h, pts):
    o = _frame(p, pts, P_ROUND, CREAM, "satin")
    p.add(flat_ring(pts, -0.004, 0.004, 0.012), GILT, "gold")
    cols = [LILAC, (0.98, 0.95, 0.9), BUTTER, LILAC]
    k = 0
    if kind == "rect":
        for sx in (-1, 1):
            for sz in (-1, 1):
                crocus(p, sx * (w / 2 + o * 0.5), sz * (h / 2 + o * 0.5), 0.06, 0.045, cols[k], 45 * sx * sz)
                k += 1
    else:
        for t in (0.25, 0.75):
            x, z = point_on(pts, _normals(pts), t, o * 0.5)
            crocus(p, x, z, 0.06, 0.045, cols[k])
            k += 1
    return o


def st_pearl_roses(p, kind, w, h, pts):
    o = _frame(p, pts, P_ROUND, PEARLC, "pearl")
    rng = random.Random(9)
    if kind == "rect":
        for sx in (-1, 1):
            rose_cluster(p, sx * (w / 2 + o * 0.4), h / 2 + o * 0.4, 0.075, 0.05, [ROSE, BLUSH], rng, 2)
        rose_cluster(p, 0, -h / 2 - o * 0.5, 0.065, 0.05, [BLUSH, ROSE, BLUSH], rng, 3)
    else:
        rose_cluster(p, 0, h / 2 + o * 0.5, 0.075, 0.05, [ROSE, BLUSH, ROSE], rng, 3)
    return o


def st_mask_crest(p, kind, w, h, pts):
    o = _frame(p, pts, P_OGEE, GILT)
    leaf_mask(p, 0, h / 2 + o * 1.1, 0.34, 0.05)
    return o


def st_oval_ribbon(p, kind, w, h, pts):
    o = _frame(p, pts, P_THIN, GILT)
    ribbon_bow(p, 0, h / 2 + o + 0.05, 0.12, 0.03, (0.95, 0.72, 0.78))
    return o


def st_oval_pearl(p, kind, w, h, pts):
    o = _frame(p, pts, P_THIN, PEARLC, "pearl")
    nm = _normals(pts)
    for i in range(28):
        x, z = point_on(pts, nm, i / 28, o + 0.008)
        p.add(K.sphere(0.014, 6, 4), (0.95, 0.92, 0.94), "pearl", T(x, 0.006, z))
    return o


def st_tondo_garland(p, kind, w, h, pts):
    o = _frame(p, pts, P_ROUND, GILT)
    nm = _normals(pts)
    rng = random.Random(5)
    for i in range(22):
        x, z = point_on(pts, nm, i / 22, o * 0.55)
        a = math.degrees(math.atan2(z, x))
        p.add(K.leaf(0.085, 0.036), SAGE, "leaf", T(x, 0.045, z) @ R("Y", -a - 90 + (25 if i % 2 else -25)) @ R("X", 90))
    for t in (0.0, 0.25, 0.5, 0.75):
        x, z = point_on(pts, nm, t + 0.125, o * 0.55)
        K.bloom(p, (x, 0.05, z), 0.045, ROSE if t < 0.5 else BLUSH, rings=2, per=4, rng=rng, tilt=R("X", -90), finish="satin")
    return o


def st_rococo_arch(p, kind, w, h, pts):
    o = _frame(p, pts, P_BAROQUE, GILT)
    top = h / 2
    shell_crest(p, 0, top + o * 0.8, 0.26, 0.07)
    for sx in (-1, 1):
        corner_scrolls(p, sx * (w / 2 + o * 0.4), -h / 2 - o * 0.4, 0.14, 45 * sx, 0.06)
        p.add(K.scroll(0.06, 1.3, 10, 0.006), GILT, "gold", T(sx * (w / 2 + o * 0.6), 0.06, h / 2 - w / 2) @ S(sx, 1, 1) @ R("Y", 180))
    return o


STYLES = {
    "gilt_baroque": (st_gilt_baroque, ["land", "port", "full", "square"]),
    "gilt_simple": (st_gilt_simple, ["land", "port", "full", "square"]),
    "walnut_gold": (st_walnut_gold, ["land", "port", "square"]),
    "silver_leaf": (st_silver_leaf, ["land", "port", "square"]),
    "ebony_dark": (st_ebony_dark, ["land", "port", "square"]),
    "crocus_spring": (st_crocus_spring, ["land", "port", "square", "round"]),
    "pearl_roses": (st_pearl_roses, ["land", "port", "full", "square", "oval_p"]),
    "mask_crest": (st_mask_crest, ["port", "full", "oval_p"]),
    "oval_ribbon": (st_oval_ribbon, ["oval_p", "oval_l"]),
    "oval_pearl": (st_oval_pearl, ["oval_p", "oval_l"]),
    "tondo_garland": (st_tondo_garland, ["round"]),
    "rococo_arch": (st_rococo_arch, ["arch_p"]),
}


def build(style, shape):
    fn, _ = STYLES[style]
    kind, w, h = SHAPES[shape]
    name = "%s_%s" % (style, shape)
    p = K.Prop(name)
    pts = outline(kind, w, h)
    o = fn(p, kind, w, h, pts)
    back_panel(p, pts, o)
    plaque(p, w, h, drop=o + 0.03)
    ob = p.to_object(name)
    n = K.mesh_tris(ob)
    lo = K.lod(ob, 0.55)
    lo.name = name + "_lod1"
    return ob, lo, n


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    prev = args[args.index("--preview") + 1] if "--preview" in args else None
    over = []
    shown = []
    for style in sorted(STYLES):
        for shape in STYLES[style][1]:
            K.reset()
            ob, lo, n = build(style, shape)
            print("  %-28s %5d tris  lod1 %5d" % (ob.name, n, K.mesh_tris(lo)))
            if n > MAX_TRIS:
                over.append((ob.name, n))
            if prev:
                shown.append((style, shape))
            else:
                K.export_glb([ob, lo], os.path.join(OUT, ob.name + ".glb"))
    if prev:
        _preview(shown, prev)
    print("over budget:", over)
    if over:
        sys.exit(1)


def _preview(shown, path, cols=6):
    import manor_props as MP
    K.reset()
    objs = []
    for style, shape in shown:
        ob, lo, n = build(style, shape)
        bpy.data.objects.remove(lo)
        objs.append(ob)
    MP.preview(objs, path, cols)


if __name__ == "__main__":
    main()
