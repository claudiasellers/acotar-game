"""The Hollow Hob (bestiary §10): creatures/models/fae/hollow_hob.gltf with its
textures, skeleton and clips, and data/animation/creatures/hollow_hob_gaits.txt.

    /opt/bpyenv/bin/python tools/blender/monsters/hob.py [--preview DIR views...] [--fast]

--preview DIR also renders check sheets there. --fast bakes 1K maps and a
coarser sculpt, for iterating; never commit a --fast build.

The model is the body (one skinned mesh: skin, moss, grass, teeth, eyes, lids
and the necklace's cord) and eight more meshes, `charm_1`..`charm_8`, each
skinned to the bone of its own name so the game can hide one when it is cut.
`charm_1` (the horseshoes at the throat) is the weak spot; the `charm` socket
bone sits on it.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import bpy  # noqa: E402
import bmesh  # noqa: E402,I001
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import hob_body as hb  # noqa: E402
import hob_clips  # noqa: E402
import hob_rig  # noqa: E402
import kit  # noqa: E402
import rig  # noqa: E402

NAME = "hollow_hob"
OUT = os.path.join(kit.ROOT, "creatures", "models", "fae")
BODY_TRIS = 10600

# part numbers on the game mesh (kit.tag): 0 skin, 1 upper teeth, 2 lower
# teeth, 10 eyes, 11/12 lids (right/left), 60 the cord, 61+k grass on mantle
# bone k, 71..78 the charms.


# ------------------------------------------------------------------ materials

GRANITE = (0.275, 0.25, 0.215)
GRANITE_DARK = (0.14, 0.13, 0.118)
GRANITE_WARM = (0.3, 0.24, 0.18)
CRACK = (0.055, 0.052, 0.048)
SOFT = (0.31, 0.28, 0.24)
MOSS = (0.15, 0.2, 0.055)
MOSS_DARK = (0.04, 0.075, 0.022)
MOSS_DRY = (0.25, 0.22, 0.08)
LICHEN = (0.5, 0.53, 0.4)
LICHEN_OCHRE = (0.5, 0.39, 0.14)
MOUTH = (0.085, 0.03, 0.03)
NAIL = (0.1, 0.09, 0.075)


def _scaled(g, colour, factor):
    n = g.nt.nodes.new("ShaderNodeVectorMath")
    n.operation = "SCALE"
    g.nt.links.new(colour, n.inputs[0])
    g.nt.links.new(factor, n.inputs["Scale"])
    return n.outputs["Vector"]


def skin_material():
    """Weathered granite: slabs split by deep cracks, finer crazing between,
    pale lichen on the ledges, and moss in cushions over the back that creeps
    out along the cracks."""
    def build(nt, bsdf):
        g = kit.Graph(nt)
        P = g.position()
        moss, mouth, up = g.split(g.attr("zone_a"))
        nail, soft, _ = g.split(g.attr("zone_b"))
        Pw = g.nt.nodes.new("ShaderNodeVectorMath")
        Pw.operation = "ADD"
        nt.links.new(P, Pw.inputs[0])
        nt.links.new(g.combine(g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, 2.2, 3.0), 0.5), 0.5),
                               g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, 2.9, 3.0), 0.5), 0.5),
                               g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, 2.5, 3.0), 0.5), 0.5)), Pw.inputs[1])
        Pw = Pw.outputs["Vector"]
        e1, _ = g.voronoi(g.scale_vec(Pw, (1.0, 1.0, 0.7)), 3.4)
        _, cell = g.voronoi(g.scale_vec(Pw, (1.0, 1.0, 0.7)), 3.4, feature="F1")
        slab, _, _ = g.split(cell)
        e2, _ = g.voronoi(Pw, 12.0)
        # the big fissures vary in width and die out in places; fine crazing only in patches
        wide = g.math("ADD", 0.008, g.math("MULTIPLY", g.noise(P, 5.0, 2.0), 0.035))
        crack1 = g.math("MULTIPLY", g.math("SUBTRACT", 1.0, g.smooth(e1, 0.0, wide)), g.smooth(g.noise(P, 1.7, 2.0), 0.3, 0.5))
        patch = g.smooth(g.noise(P, 2.6, 3.0), 0.52, 0.66)
        crack2 = g.math("MULTIPLY", g.math("SUBTRACT", 1.0, g.smooth(e2, 0.0, 0.02)), g.math("MULTIPLY", patch, 0.55))
        crack = g.math("MAXIMUM", crack1, crack2)
        crack = g.math("MULTIPLY", crack, g.math("SUBTRACT", 1.0, g.math("MULTIPLY", soft, 0.5)))
        mottle = g.noise(P, 13.0, 4.0)
        grain = g.noise(P, 110.0, 3.0)
        base = g.mix_rgb(g.smooth(mottle, 0.3, 0.7), GRANITE_DARK, GRANITE)
        base = g.mix_rgb(g.math("MULTIPLY", g.smooth(g.noise(P, 1.3, 3.0), 0.4, 0.7), 0.6), base, GRANITE_WARM)
        speck = g.smooth(g.noise(P, 380.0, 1.0), 0.62, 0.72)
        base = g.mix_rgb(g.math("MULTIPLY", speck, 0.35), base, (0.06, 0.06, 0.06))
        base = _scaled(g, base, g.math("ADD", 0.82, g.math("MULTIPLY", slab, 0.3)))
        base = g.mix_rgb(g.math("MULTIPLY", soft, 0.7), base, SOFT)
        base = _scaled(g, base, g.math("ADD", 0.9, g.math("MULTIPLY", grain, 0.2)))
        col = g.mix_rgb(crack, base, CRACK)
        # lichen: pale rosettes on what faces the sky, ochre ones lower down
        ledge = g.smooth(up, 0.2, 0.7)
        l1 = g.math("MULTIPLY", g.smooth(g.noise(P, 6.0, 4.0, 0.7), 0.6, 0.66), ledge)
        l2 = g.math("MULTIPLY", g.smooth(g.noise(g.scale_vec(P, (1.3, 1.1, 0.9)), 8.5, 4.0, 0.7), 0.63, 0.68), g.math("ADD", 0.25, g.math("MULTIPLY", ledge, 0.5)))
        col = g.mix_rgb(g.math("MULTIPLY", l1, 0.85), col, LICHEN)
        col = g.mix_rgb(g.math("MULTIPLY", l2, 0.8), col, LICHEN_OCHRE)
        # moss
        edge_n = g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, 8.0, 3.0), 0.5), 0.8)
        mfac = g.smooth(g.math("ADD", moss, edge_n), 0.3, 0.55)
        creep = g.math("MULTIPLY", g.math("MULTIPLY", crack, g.smooth(g.math("ADD", moss, g.math("MULTIPLY", up, 0.25)), 0.08, 0.4)), 0.9)
        mfac = g.math("MAXIMUM", mfac, creep)
        mcol = g.mix_rgb(g.noise(P, 55.0, 3.0), MOSS_DARK, MOSS)
        mcol = g.mix_rgb(g.smooth(g.noise(P, 4.5, 3.0, 0.7), 0.5, 0.7), mcol, MOSS_DRY)
        mcol = g.mix_rgb(g.math("MULTIPLY", g.smooth(g.noise(P, 2.1, 3.0), 0.5, 0.7), 0.7), mcol, MOSS_DARK)
        col = g.mix_rgb(mfac, col, mcol)
        col = g.mix_rgb(nail, col, NAIL)
        col = g.mix_rgb(mouth, col, MOUTH)
        skin = g.math("MAXIMUM", nail, mouth)
        rock_h = g.math("ADD", g.math("MULTIPLY", crack, -1.0), g.math("ADD", g.math("MULTIPLY", grain, 0.22), g.math("MULTIPLY", mottle, 0.25)))
        rock_h = g.math("ADD", rock_h, g.math("MULTIPLY", g.math("MAXIMUM", l1, l2), 0.12))
        rock_h = g.math("ADD", rock_h, g.math("MULTIPLY", g.noise(P, 30.0, 4.0, 0.7), 0.5))
        moss_h = g.math("ADD", g.math("MULTIPLY", g.noise(P, 170.0, 2.0), 0.7), g.math("MULTIPLY", g.noise(P, 40.0, 3.0), 0.9))
        height = g.mix(mfac, rock_h, moss_h)
        height = g.mix(skin, height, g.math("MULTIPLY", grain, 0.1))
        rough = g.mix(crack, g.mix(soft, 0.86, 0.8), 0.96)
        rough = g.mix(mfac, rough, 0.97)
        rough = g.mix(nail, rough, 0.42)
        rough = g.mix(mouth, rough, 0.4)
        g.out(bsdf, color=col, rough=rough, normal=g.bump(height, 0.012))
    return kit.sculpt_material("hob_skin", build)


def grad_material(name, root, tip, rough=0.9, lo=0.0, hi=1.0):
    def build(nt, bsdf):
        g = kit.Graph(nt)
        grad, _, _ = g.split(g.attr("grad"))
        g.out(bsdf, color=g.mix_rgb(g.smooth(grad, lo, hi), root, tip), rough=rough)
    return kit.sculpt_material(name, build)


def eye_material(side):
    """Small, pale, wet: a washed-out grey-blue iris round a pinprick pupil."""
    c = tuple(hb.EYE * (side, 1, 1))
    out_dir = np.array((0.22 * side, 0.97, -0.05))
    out_dir /= np.linalg.norm(out_dir)

    def build(nt, bsdf):
        g = kit.Graph(nt)
        v = g.sub_vec(g.position(), c)
        o = g.math("DIVIDE", g.dot(v, tuple(out_dir)), hb.EYE_R)          # 1 at the pupil
        iris = g.smooth(o, 0.8, 0.86)
        pupil = g.smooth(o, 0.975, 0.985)
        ring = g.math("MULTIPLY", g.smooth(o, 0.8, 0.84), g.math("SUBTRACT", 1.0, g.smooth(o, 0.84, 0.9)))
        white = g.mix_rgb(g.noise(g.position(), 300.0, 2.0), (0.62, 0.56, 0.47), (0.7, 0.66, 0.58))
        ic = g.mix_rgb(g.smooth(o, 0.86, 0.97), (0.5, 0.6, 0.66), (0.74, 0.8, 0.8))
        ic = g.mix_rgb(ring, ic, (0.2, 0.26, 0.3))
        col = g.mix_rgb(iris, white, ic)
        col = g.mix_rgb(pupil, col, (0.005, 0.005, 0.005))
        g.out(bsdf, color=col, rough=0.05, emission=g.mix_rgb(pupil, g.mix_rgb(iris, (0, 0, 0), ic), (0, 0, 0)), strength=0.5)
    return kit.sculpt_material(f"hob_eye{side}", build)


# ------------------------------------------------------------------ small meshes

def _mesh(name, verts, faces, grad=None, smooth=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    o = kit._link(bpy.data.objects.new(name, me))
    if grad is not None:
        u = np.asarray(grad, dtype=np.float32)
        attr = me.color_attributes.new("grad", "FLOAT_COLOR", "POINT")
        attr.data.foreach_set("color", np.stack([u, u, u, np.ones_like(u)], axis=1).ravel())
    if smooth:
        kit.shade_smooth(o)
    return o


def sweep(name, path, section, closed=False, up=(0, 0, 1)):
    """A section (list of (a, b) offsets) swept along a path: rope, horseshoe, ring."""
    path = [np.asarray(p, dtype=np.float64) for p in path]
    n, m = len(path), len(section)
    up = np.asarray(up, dtype=np.float64)
    verts, faces = [], []
    for i, c in enumerate(path):
        a = path[(i + 1) % n] if (closed or i < n - 1) else c
        b = path[(i - 1) % n] if (closed or i > 0) else c
        t = a - b
        t /= max(np.linalg.norm(t), 1e-9)
        x = np.cross(t, up)
        if np.linalg.norm(x) < 1e-5:
            x = np.cross(t, (1.0, 0.0, 0.0))
        x /= np.linalg.norm(x)
        y = np.cross(x, t)
        for sa, sb in section:
            verts.append(c + x * sa + y * sb)
    rings = n if closed else n - 1
    for i in range(rings):
        j = (i + 1) % n
        for k in range(m):
            k2 = (k + 1) % m
            faces.append((i * m + k, i * m + k2, j * m + k2, j * m + k))
    if not closed:
        faces.append(tuple(range(m - 1, -1, -1)))
        faces.append(tuple((n - 1) * m + k for k in range(m)))
    o = _mesh(name, verts, faces)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()
    return o


def _ngon(r, n, squash=1.0):
    return [(r * math.cos(2 * math.pi * k / n), r * squash * math.sin(2 * math.pi * k / n)) for k in range(n)]


def blade(name, root, d, length, width, face, droop=0.25, zig=0.0, rings=4):
    """A blade of grass or a fern frond: a flat, two-sided, pointed strip that
    bends over under its own weight. `zig` notches the edges (a fern)."""
    root, d, face = (np.asarray(v, dtype=np.float64) for v in (root, d, face))
    d = d / np.linalg.norm(d)
    across = np.cross(d, face)
    across /= max(np.linalg.norm(across), 1e-9)
    verts, grad, front = [], [], []
    for i in range(rings):
        u = i / rings
        c = root + d * (length * u) + np.array((0, 0, -1.0)) * (length * droop * u * u)
        w = width * (1.0 - 0.75 * u ** 1.5) * (1.0 + zig * (1 if i % 2 else -1) * (i > 0)) * 0.5
        verts += [c - across * w, c + across * w]
        grad += [u, u]
    tip = root + d * length + np.array((0, 0, -1.0)) * (length * droop)
    verts.append(tip)
    grad.append(1.0)
    for i in range(rings - 1):
        front.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    front.append((2 * rings - 2, 2 * rings - 1, 2 * rings))
    n = len(verts)
    faces = front + [tuple(n + k for k in reversed(f)) for f in front]
    return _mesh(name, verts + verts, faces, grad + grad)


def box(name, centre, size, rot_z=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(centre) @ Matrix.Rotation(rot_z, 4, "Z") @ Matrix.Diagonal((*size, 1.0)))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return kit._link(bpy.data.objects.new(name, me))


# ------------------------------------------------------------------ sculpt

def sculpt(voxel):
    """Returns the sculpt and the necklace's layout (read off the clay's surface)."""
    mid, side = hb.forms()
    body = mid + side + [kit.mirror_x(o) for o in side]
    f = kit.field(body)
    lumps = hb.mantle(f)
    f_all = kit.field(body + lumps)
    cord = necklace_layout(f_all)
    path = os.environ.get("MONSTER_SCULPT_CACHE")

    def make():
        s = kit.union(body + lumps, "hob_sculpt", voxel=voxel)
        kit.carve(s, hb.cutters())
        return s
    if path and os.path.exists(path):
        for o in body + lumps:
            kit._SDF.pop(o.name, None)
            bpy.data.objects.remove(o, do_unlink=True)
    s = kit.cached(path, make)
    s.name = "hob_sculpt"
    kit.displace(s, hb.rock_field)
    kit.shade_smooth(s)

    def za(P, N):
        z = hb.zones(P, N)
        return np.stack([z["moss"], z["mouth"], z["up"]], axis=1)

    def zb(P, N):
        z = hb.zones(P, N)
        return np.stack([z["nail"], z["soft"], np.zeros(len(P))], axis=1)
    kit.paint(s, "zone_a", za)
    kit.paint(s, "zone_b", zb)
    kit.set_material(s, skin_material())
    return s, cord


def necklace_layout(f):
    """The cord's path: a loop of twisted grass and old rope lying on the
    shoulders and hanging to the breastbone. Returns dict(path, bottom, hooks)."""
    half = [(0.0, -0.36, 3.72), (0.2, -0.3, 3.78), (0.34, -0.1, 3.76), (0.4, 0.14, 3.6), (0.39, 0.36, 3.36), (0.3, 0.5, 3.14),
            (0.16, 0.57, 3.0), (0.0, 0.6, 2.95)]
    P, N = hb._onto(f, np.array(half))
    P = P + N * 0.026
    P[0, 0] = P[-1, 0] = 0.0
    loop = [tuple(p) for p in P] + [(-p[0], p[1], p[2]) for p in P[-2:0:-1]]
    n = 44
    pts = loop + [loop[0]]
    C, _ = kit._catmull(pts, [(1.0, 1.0)] * len(pts), n + 1)
    C = np.array(C[:-1])
    bottom = C[np.argmin(C[:, 2])]
    front = [i for i in range(n) if C[i, 1] > 0.3 and C[i, 2] < 3.5]
    right = sorted([i for i in front if C[i, 0] > 0.04], key=lambda i: C[i, 2])
    left = sorted([i for i in front if C[i, 0] < -0.04], key=lambda i: C[i, 2])
    hooks = [bottom]
    for k in range(4):
        if len(hooks) < 8 and k * 2 + 1 < len(right):
            hooks.append(C[right[k * 2 + 1]])
        if len(hooks) < 8 and k * 2 + 1 < len(left):
            hooks.append(C[left[k * 2 + 1]])
    while len(hooks) < 8:
        hooks.append(C[right[-1]])
    return dict(path=C, bottom=bottom, hooks=[h + np.array((0, 0.012, -0.02)) for h in hooks])


# ------------------------------------------------------------------ hard parts

def hard_parts(cord):
    """Teeth, eyes, lids, the mantle's grass and ferns, the cord and the charms,
    at game resolution. Returns [(object, part number)]."""
    out = []
    rng = np.random.RandomState(5)

    def add(o, part, mat):
        kit.set_material(o, mat)
        out.append((kit.tag(o, part), part))

    # blunt, stained, uneven teeth; two lower ones stand up outside the lip
    tooth = grad_material("hob_tooth", (0.3, 0.2, 0.1), (0.62, 0.55, 0.38), rough=0.4, lo=0.0, hi=0.6)
    ys = np.linspace(0.47, 0.672, 8)
    for s in (1, -1):
        for i, y in enumerate(ys):
            if (i, s) in ((2, 1), (5, -1)):          # gaps
                continue
            w = hb.jaw_half_width(y) * 0.94
            long = 0.03 + 0.02 * rng.rand()
            root = np.array((s * w, y, hb.mouth_z(y) + 0.012))
            add(kit.horn(f"tooth_u{s}{i}", root, root + (s * 0.004 * rng.randn(), 0.004, -long), 0.017 + 0.007 * rng.rand(),
                         segs=5, rings=3, flat=0.8, tip_r=0.6), 1, tooth)
        for i, y in enumerate(np.linspace(0.49, 0.655, 6)):
            w = hb.jaw_half_width(y) * 0.8
            tusk = i == 4
            long = 0.07 if tusk else 0.026 + 0.016 * rng.rand()
            root = np.array((s * (w + 0.012 * tusk), y + 0.01 * tusk, hb.mouth_z(y) - 0.02))
            add(kit.horn(f"tooth_l{s}{i}", root, root + (s * 0.006 * tusk, 0.004, long), (0.024 if tusk else 0.016) + 0.005 * rng.rand(),
                         segs=5, rings=3 + tusk, flat=0.8, tip_r=0.45 if tusk else 0.6), 2, tooth)
    lid = kit.plain("hob_lid", (0.2, 0.18, 0.16), 0.8)
    for s in (1, -1):
        flip = np.array((s, 1, 1))
        add(kit.ball(f"eye{s}", tuple(hb.EYE * flip), hb.EYE_R, segs=12, rings=8), 10, eye_material(s))
        add(eyelid(s), 11 if s > 0 else 12, lid)

    # the mantle's growth: grass in tufts on the cushions, a few ferns between
    grass = grad_material("hob_grass", (0.1, 0.15, 0.04), (0.4, 0.42, 0.14), rough=0.85)
    fern = grad_material("hob_fern", (0.08, 0.16, 0.05), (0.2, 0.34, 0.1), rough=0.8)
    up = np.array((0, 0, 1.0))
    for li, (c, r, n) in enumerate(hb.LUMPS):
        scalp = r < 0.13
        if not scalp and rng.rand() < 0.5:
            continue
        root = c + n * r * 0.2
        bone = hob_rig.moss_bone_near(root)
        ferny = (not scalp) and rng.rand() < 0.3
        count = 3 if ferny else (3 if scalp else 3 + int(rng.rand() * 3))
        for k in range(count):
            d = n * 0.7 + up * (0.3 + 0.3 * rng.rand()) + rng.normal(size=3) * 0.6
            face = np.cross(d, rng.normal(size=3))
            off = rng.normal(size=3) * r * 0.22
            off -= n * (off @ n)
            if ferny:
                o = blade(f"fern{li}_{k}", root + off, d, 0.34 + 0.2 * rng.rand(), 0.15, face, droop=0.4, zig=0.28, rings=6)
                add(o, 61 + bone, fern)
            else:
                L = (0.16 + 0.1 * rng.rand()) if scalp else (0.26 + 0.24 * rng.rand())
                o = blade(f"grass{li}_{k}", root + off, d, L, 0.075 + 0.03 * rng.rand(), face, droop=0.45 + 0.35 * rng.rand(), rings=3)
                add(o, 61 + bone, grass)

    # the cord
    rope = kit.sculpt_material("hob_rope", _rope)
    add(sweep("cord", cord["path"], _ngon(0.024, 5), closed=True), 60, rope)
    for i, o in enumerate(charms(cord["hooks"])):
        out.append((kit.tag(o, 71 + i), 71 + i))
    return out


def _rope(nt, bsdf):
    g = kit.Graph(nt)
    P = g.position()
    x, y, z = g.split(P)
    twist = g.math("SINE", g.math("MULTIPLY", g.math("ADD", g.math("ADD", x, y), z), 190.0))
    fibre = g.noise(g.scale_vec(P, (1.0, 1.0, 1.0)), 260.0, 2.0)
    col = g.mix_rgb(g.smooth(twist, -0.6, 0.6), (0.2, 0.15, 0.075), (0.42, 0.34, 0.17))
    col = g.mix_rgb(g.math("MULTIPLY", g.smooth(g.noise(P, 9.0, 2.0), 0.5, 0.7), 0.6), col, (0.2, 0.26, 0.09))
    g.out(bsdf, color=col, rough=0.92, normal=g.bump(g.math("ADD", g.math("MULTIPLY", twist, 0.5), fibre), 0.004))


def eyelid(side):
    """The upper lid: a cap over the eye, modelled open (lifted back under the
    brow). Turning `eyelid_<side>` forward closes it."""
    r_ = hb.EYE_R * 1.2
    c = hb.EYE * (side, 1, 1)
    o = kit.ball(f"lid{side}", tuple(c), r_, segs=12, rings=10)
    pole = np.array((0.0, -0.42, 0.9))
    pole /= np.linalg.norm(pole)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    gone = [v for v in bm.verts if (np.array(v.co) - c) @ pole < r_ * math.cos(math.radians(78))]
    bmesh.ops.delete(bm, geom=gone, context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    return o


LID_SHUT = 82.0        # degrees of `eyelid_*` pitch that close the eye


def charms(hooks):
    """The eight things it took from mortals, each hanging under its hook on
    the cord (bestiary §10.3). Returns the meshes in socket order."""
    S = 1.5                                   # a little over life size, so they read at its scale
    iron = kit.sculpt_material("hob_iron", lambda nt, bsdf: _metal(nt, bsdf, (0.11, 0.085, 0.07), (0.3, 0.13, 0.05), 0.75))
    pewter = kit.sculpt_material("hob_pewter", lambda nt, bsdf: _metal(nt, bsdf, (0.4, 0.4, 0.38), (0.22, 0.22, 0.2), 0.42))
    brass = kit.sculpt_material("hob_brass", lambda nt, bsdf: _metal(nt, bsdf, (0.55, 0.42, 0.15), (0.2, 0.26, 0.14), 0.4))
    rose = kit.sculpt_material("hob_rosegold", lambda nt, bsdf: _metal(nt, bsdf, (0.74, 0.45, 0.36), (0.5, 0.3, 0.24), 0.28))
    bone = kit.plain("hob_bone", (0.7, 0.63, 0.48), 0.5)
    pearl = kit.plain("hob_pearl", (0.83, 0.8, 0.74), 0.22)
    silk = grad_material("hob_ribbon", (0.5, 0.09, 0.12), (0.36, 0.1, 0.12), rough=0.6)
    twine = kit.plain("hob_twine", (0.3, 0.24, 0.12), 0.9)
    out = []

    def done(i, pieces):
        h = np.asarray(hooks[i])
        # a loop of twine from the cord to the charm
        t = box(f"twine{i}", tuple(h + (0, 0, -0.012 * S)), (0.008 * S, 0.008 * S, 0.06 * S))
        kit.set_material(t, twine)
        o = kit.join(list(pieces) + [t], f"charm_{i + 1}")
        kit.shade_smooth(o)
        out.append(o)

    def shoe(name, top, R, turn):
        """An iron horseshoe hanging by its arch, open end down."""
        pts = []
        for k in range(11):
            a = math.radians(-125 + 250 * k / 10)
            pinch = 1.0 - 0.18 * (abs(k - 5) / 5.0) ** 2
            p = np.array((R * math.sin(a) * pinch, 0.0, R * math.cos(a) - R))
            pts.append(top + (p[0] * math.cos(turn), p[0] * math.sin(turn), p[2]))
        o = sweep(name, pts, [(-0.019 * S, -0.006 * S), (0.019 * S, -0.006 * S), (0.019 * S, 0.006 * S), (-0.019 * S, 0.006 * S)],
                  up=(-math.sin(turn), math.cos(turn), 0))
        kit.set_material(o, iron)
        return o

    def ring(name, centre, R, r_, mat, turn=0.0, n=14, sides=5):
        pts = [centre + (R * math.sin(2 * math.pi * k / n) * math.cos(turn), R * math.sin(2 * math.pi * k / n) * math.sin(turn),
                         R * math.cos(2 * math.pi * k / n)) for k in range(n)]
        o = sweep(name, pts, _ngon(r_, sides), closed=True, up=(-math.sin(turn), math.cos(turn), 0))
        kit.set_material(o, mat)
        return o

    def ball(name, centre, radii, mat, segs=10, rings=6):
        o = kit.ball(name, (0, 0, 0), 1.0, segs=segs, rings=rings)
        o.data.transform(Matrix.Translation(centre) @ Matrix.Diagonal((*radii, 1.0)))
        kit.set_material(o, mat)
        return o

    # 1: iron horseshoes, two tied together: the weak spot, the biggest thing on the cord
    h = np.asarray(hooks[0]) + (0, 0.012, -0.045 * S)
    done(0, [shoe("shoe_a", h, 0.085 * S, 0.12), shoe("shoe_b", h + (0.03, 0.02 * S, -0.012), 0.068 * S, -0.45)])
    # 2: a child's iron bracelet
    h = np.asarray(hooks[1]) + (0, 0.01, -0.04 * S)
    done(1, [ring("bracelet", h + (0, 0, -0.03 * S), 0.03 * S, 0.0055 * S, iron, turn=0.5)])
    # 3: a pewter locket
    h = np.asarray(hooks[2]) + (0, 0.012, -0.04 * S)
    done(2, [ball("locket", h + (0, 0, -0.028 * S), (0.022 * S, 0.008 * S, 0.028 * S), pewter),
             ring("locket_bail", h + (0, 0, 0.004 * S), 0.007 * S, 0.0025 * S, pewter, turn=1.57, n=8, sides=4)])
    # 4: a little bell
    h = np.asarray(hooks[3]) + (0, 0.012, -0.04 * S)
    prof = [(0.004, 0.0), (0.012, -0.004), (0.016, -0.02), (0.02, -0.036), (0.027, -0.044)]
    verts, faces = [], []
    for k, (rr, zz) in enumerate(prof):
        for j in range(8):
            verts.append(h + (rr * S * math.cos(2 * math.pi * j / 8), rr * S * math.sin(2 * math.pi * j / 8), zz * S))
    for k in range(len(prof) - 1):
        for j in range(8):
            faces.append((k * 8 + j, k * 8 + (j + 1) % 8, (k + 1) * 8 + (j + 1) % 8, (k + 1) * 8 + j))
    faces.append(tuple(range(7, -1, -1)))
    faces.append(tuple((len(prof) - 1) * 8 + j for j in range(8)))
    bell = _mesh("bell", verts, faces)
    kit.set_material(bell, brass)
    done(3, [bell, ball("clapper", h + (0, 0, -0.046 * S), (0.006 * S,) * 3, iron, segs=6, rings=4)])
    # 5: a bone comb
    h = np.asarray(hooks[4]) + (0, 0.012, -0.04 * S)
    pieces = [box("comb_spine", tuple(h + (0, 0, -0.008 * S)), (0.07 * S, 0.006 * S, 0.018 * S), rot_z=-0.3)]
    for k in range(6):
        dx = (-0.029 + 0.0116 * k) * S
        pieces.append(box(f"comb_tooth{k}", tuple(h + (dx * math.cos(-0.3), dx * math.sin(-0.3), -0.036 * S)), (0.006 * S, 0.004 * S, 0.04 * S), rot_z=-0.3))
    for o in pieces:
        kit.set_material(o, bone)
    done(4, pieces)
    # 6: a rose-gold circlet
    h = np.asarray(hooks[5]) + (0, 0.014, -0.04 * S)
    done(5, [ring("circlet", h + (0, 0, -0.075 * S), 0.075 * S, 0.0045 * S, rose, turn=-0.35, n=18)])
    # 7: a pearl
    h = np.asarray(hooks[6]) + (0, 0.012, -0.04 * S)
    done(6, [ball("pearl", h + (0, 0, -0.016 * S), (0.016 * S,) * 3, pearl, segs=10, rings=7)])
    # 8: a ribbon
    h = np.asarray(hooks[7]) + (0, 0.012, -0.03 * S)
    rb = kit.ribbon("ribbon_a", [h, h + (0.01, 0.004, -0.1), h + (0.03, 0.0, -0.2), h + (0.02, 0.01, -0.29)], [0.03, 0.032, 0.03, 0.026],
                    (0.2, 1, 0), thick=0.003, ragged=0.25, seed=3.0, rings=5)
    rb2 = kit.ribbon("ribbon_b", [h, h + (-0.02, 0.006, -0.08), h + (-0.045, 0.0, -0.17)], [0.03, 0.03, 0.026],
                     (-0.2, 1, 0), thick=0.003, ragged=0.25, seed=8.0, rings=4)
    kit.set_material(rb, silk)
    kit.set_material(rb2, silk)
    done(7, [rb, rb2])
    return out


def _metal(nt, bsdf, colour, tarnish, rough):
    g = kit.Graph(nt)
    P = g.position()
    f = g.smooth(g.noise(P, 60.0, 3.0), 0.45, 0.7)
    g.out(bsdf, color=g.mix_rgb(f, colour, tarnish), rough=g.mix(f, rough, min(rough + 0.3, 0.95)),
          normal=g.bump(g.noise(P, 240.0, 2.0), 0.0015))


# ------------------------------------------------------------------ build

def build(fast=False, bake=True):
    kit.reset()
    s, cord = sculpt(0.02 if fast else 0.013)
    hard = hard_parts(cord)
    low = kit.game_mesh(s, NAME, BODY_TRIS, keep=lambda P: hb.zones(P, np.zeros_like(P))["keep"])
    kit.tag(low, 0)
    arm = rig.build_armature(NAME, hob_rig.bones(cord))
    rig.skin(low, arm, fix=hob_rig.fix_weights)
    pieces = []
    for o, part in hard:
        g = kit.duplicate(o, o.name + "_g")
        if part == 60:
            # the back of the cord lies on the shoulders; the front hangs with the necklace bone
            P = kit.co(g)
            w = kit.ss((P[:, 1] - 0.0) / 0.3)
            for name, col in (("necklace", w), ("chest", 1.0 - w)):
                vg = g.vertex_groups.new(name=name)
                for j in np.nonzero(col > 1e-3)[0]:
                    vg.add([int(j)], float(col[j]), "REPLACE")
        else:
            rig.bind_rigid(g, hob_rig.part_bone(part))
        pieces.append(g)
    low = kit.join([low] + pieces, NAME)
    kit.triangulate(low)          # the engine's tangents then match the bake's
    if bake:
        # the head gets twice its share of the texture and the charms three times theirs
        part = kit.parts_of(low)
        kit.unwrap(low, boost=lambda P: 1.0 + 0.9 * kit.ss((P[:, 2] - 3.42) / 0.1) * kit.ss((P[:, 1] - 0.1) / 0.1) + 2.0 * (part >= 71),
                   centre=(0.0, 0.4, 3.7))
    rig.attach(low, arm)
    paths = {}
    kept = kit.baked_material(low, NAME, OUT) if bake == "keep" else None
    if kept:
        _, paths = kept
    elif bake:
        mat, paths = kit.bake([s] + [o for o, _ in hard], low, NAME, OUT, size=1024 if fast else 4096, extrusion=0.05)
    else:
        kit.set_material(low, kit.plain("clay", (0.3, 0.3, 0.28), 0.7))
    charm_objs = split_charms(low, arm)
    r = rig.Rig(arm, low, hob_rig.spec())
    hob_clips.author(r)
    r.finish()
    return s, hard, low, arm, r, paths, charm_objs


def split_charms(low, arm):
    """Cuts each charm off the body mesh into its own skinned mesh, `charm_<n>`."""
    out = []
    for i in range(hob_rig.CHARMS):
        part = kit.parts_of(low)
        sel = part == 71 + i
        if not sel.any():
            continue
        before = set(bpy.data.objects)
        kit.activate(low)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_mode(type="VERT")
        bpy.ops.mesh.select_all(action="DESELECT")
        bpy.ops.object.mode_set(mode="OBJECT")
        low.data.vertices.foreach_set("select", sel.tolist())
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        new = [o for o in bpy.data.objects if o not in before][0]
        new.name = f"charm_{i + 1}"
        new.data.name = f"charm_{i + 1}"
        out.append(new)
    return out


VIEWS = {
    "front34": ((6.0, 10.6, 3.4), (0, 0, 2.3), 50),
    "side": ((12.0, 0.3, 2.8), (0, 0.2, 2.3), 50),
    "back34": ((-5.5, -10.6, 3.8), (0, 0, 2.3), 50),
    "face": ((1.1, 2.9, 3.9), (0, 0.5, 3.66), 70),
    "face_side": ((2.4, 0.7, 3.72), (0, 0.5, 3.66), 85),
    "hand": ((3.6, 2.0, 1.6), (1.85, 0.05, 0.9), 85),
    "foot": ((2.4, 2.4, 0.9), (0.5, 0.25, 0.25), 70),
    "chest": ((1.2, 4.6, 3.3), (0, 0.5, 3.15), 70),
}

if __name__ == "__main__":
    args = sys.argv[1:]
    fast = "--fast" in args
    s, hard, low, arm, r, paths, charm_objs = build(fast, bake="keep" if "--keepbake" in args else "--nobake" not in args)
    for name, rep in r.report.items():
        print(f"clip {name}: " + " ".join(f"{k}={v:.4f}" for k, v in rep.items()))
    pp = kit.parts_of(low)
    print("verts by part:", {int(k): int((pp == k).sum()) for k in np.unique(pp)})
    print(f"{NAME}: body {kit.tris(low)} tris, charms {sum(kit.tris(o) for o in charm_objs)} tris")
    hide = [s] + [o for o, _ in hard]
    if "--preview" in args:
        import preview
        d = args[args.index("--preview") + 1]
        for v in args[args.index("--preview") + 2:]:
            if v.startswith("--"):
                break
            if v in VIEWS:
                preview.shot(os.path.join(d, f"low_{v}.png"), VIEWS[v], hide=hide, samples=12, res=(700, 860))
            elif v.startswith("sculpt_"):
                preview.shot(os.path.join(d, f"{v}.png"), VIEWS[v[7:]], hide=[low] + charm_objs + [o for o, _ in hard], samples=12, res=(700, 860))
            else:
                clip, cam, at = (v.split("@") + ["", ""])[:3]
                views = dict(front=((0.0, 15.0, 2.4), (0, 0, 2.1), 60), q=((10.5, 10.5, 3.6), (0, 0, 2.0), 60),
                             side=((15.0, 0.0, 2.4), (0, 0.0, 2.1), 60), top=((0.6, 2.6, 13.0), (0.6, 0.6, 0.4), 50),
                             back=((-9.0, -11.0, 4.0), (0, 0, 2.0), 60), face=((1.6, 4.4, 3.2), (0, 0.6, 3.0), 60))
                kw = dict(view=views[cam or "q"])
                if at:
                    ts = [float(x) for x in at.split(",")]
                    kw.update(at=ts, frames=len(ts), res=(900, 700))
                preview.strip(arm, low, clip, os.path.join(d, f"clip_{clip}{'_' + cam if cam else ''}.png"), extra=hide, **kw)
    if "--noexport" not in args:
        for o in hide:
            bpy.data.objects.remove(o, do_unlink=True)
        path = kit.export_gltf(NAME, [low] + charm_objs + [arm], OUT)
        rig.write_gaits(NAME, r, "creatures/models/fae/hollow_hob.gltf")
        print(f"{NAME}: {kit.tris(low) + sum(kit.tris(o) for o in charm_objs)} tris -> {path}")
