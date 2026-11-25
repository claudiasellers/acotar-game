"""The briarling (bestiary 7): a rose bush that unfolds into a thing of thorn ribs.

One skeleton, two forms. The model stands as the creature: a cage of woven
cane on six stem-legs, two lashing limbs held up in front, and a head that is
a rose opened backwards round rings of thorn teeth. The bush is a pose of the
same rig: feet drawn in to one root, the canes arching out and up, the lashes
wrapped over the top, the bloom shut and turned to the sky.

Everything but the cage is built at game resolution and painted by its own
procedural material; the cage is sculpted and baked like any other monster.

Run:
    /opt/bpyenv/bin/python tools/blender/monsters/briarling.py [--preview DIR] [--fast] [--nobake]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import bmesh  # noqa: E402,I001
import numpy as np  # noqa: E402
from mathutils import Quaternion, Vector  # noqa: E402

import kit  # noqa: E402
import rig  # noqa: E402
from biped import Keys  # noqa: E402
from rig import pulse, rot, seg, smooth, wave  # noqa: E402

NAME = "briarling"
OUT = os.path.join(kit.ROOT, "creatures", "models", "fae")
CAGE_TRIS = 1000

# the court's flora palette (tools/court/blender/flora_lib.py), linear
ROSE, ROSE_DEEP, BLUSH = (1.0, 0.115, 0.36), (0.807, 0.032, 0.159), (1.0, 0.451, 0.624)
LEAF, LEAF_DEEP = (0.115, 0.624, 0.194), (0.028, 0.342, 0.102)


def _v(*p):
    return np.array(p, dtype=np.float64)


def _unit(v):
    v = np.asarray(v, dtype=np.float64)
    return v / max(np.linalg.norm(v), 1e-9)


def _rng(seed):
    return np.random.default_rng(seed)


# ---- where things are (the creature standing; x right, y forward, z up)
C = _v(0.0, 0.0, 0.40)                         # the middle of the cage
CAGE_R = _v(0.12, 0.17, 0.11)
KNOT = _v(0.0, 0.118, 0.335)                   # the heart-knot, low in the chest
NECK = (_v(0.0, 0.14, 0.45), _v(0.0, 0.215, 0.56), _v(0.0, 0.27, 0.66))
BLOOM = NECK[2]
FACE = _unit(_v(0.0, 0.78, 0.62))              # the way the bloom looks
BLOOM_R = 0.1

LEGS = ("r0", "r1", "r2", "l0", "l1", "l2")     # front, middle, rear
LEG_YAW = dict(r0=52.0, r1=0.0, r2=-54.0)       # degrees from straight out to the side


def leg_points(leg):
    """hip, the end of the coxa, the knee and the foot of one leg."""
    s = 1.0 if leg[0] == "r" else -1.0
    a = math.radians(LEG_YAW["r" + leg[1]])
    out = _v(s * math.cos(a), math.sin(a), 0.0)
    y = (0.105, 0.0, -0.11)[int(leg[1])]
    hip = _v(s * 0.1, y, 0.405)
    reach = (0.44, 0.47, 0.44)[int(leg[1])]
    return (hip, hip + out * 0.08 + _v(0, 0, 0.07), hip + out * 0.235 + _v(0, 0, 0.165), _v(0, y * 0.75, 0.0) + out * reach + _v(0, 0, 0.012), out)


def lash_points(side):
    s = 1.0 if side == "r" else -1.0
    return [_v(s * x, y, z) for x, y, z in ((0.065, 0.115, 0.475), (0.15, 0.2, 0.67), (0.2, 0.37, 0.81), (0.18, 0.55, 0.79), (0.13, 0.7, 0.68))]


ROOTS = 4
ROOT_LEN = 0.3


# ------------------------------------------------------------------ game-resolution pieces

class Piece:
    """A mesh built by hand: vertices, faces, and a "grad" colour per vertex
    (r = along the piece, g = across it, b = which of its kind)."""

    def __init__(self):
        self.P, self.F, self.G = [], [], []

    def vert(self, p, grad=(0.0, 0.0, 0.0)):
        self.P.append(np.asarray(p, dtype=np.float64))
        self.G.append(grad)
        return len(self.P) - 1

    def face(self, *idx):
        self.F.append(idx)

    def build(self, name, closed=False, tint=None):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(p) for p in self.P], [], self.F)
        me.update()
        if closed:                                  # canes and thorns: normals outward
            bm = bmesh.new()
            bm.from_mesh(me)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(me)
            bm.free()
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        g = np.array(self.G, dtype=np.float32)
        attr = me.color_attributes.new("grad", "FLOAT_COLOR", "POINT")
        attr.data.foreach_set("color", np.concatenate([g, np.ones((len(g), 1), dtype=np.float32)], axis=1).ravel())
        t = np.asarray(tint(g) if tint is not None else np.full((len(g), 3), 0.5), dtype=np.float32)
        attr = me.color_attributes.new("tint", "FLOAT_COLOR", "POINT")
        attr.data.foreach_set("color", np.concatenate([t, np.zeros((len(g), 1), dtype=np.float32)], axis=1).ravel())   # alpha 0: the court's foliage material reads alpha as glow
        kit.shade_smooth(o)
        return o


def _ramp(u, stops):
    """Colours along 0..1: stops = [(at, rgb), ...]."""
    u = np.clip(np.asarray(u, dtype=np.float64), 0.0, 1.0)
    xs = [a for a, _ in stops]
    return np.stack([np.interp(u, xs, [c[i] for _, c in stops]) for i in range(3)], axis=1)


# The colour each kind of piece carries in its vertices. The court's foliage
# material reads it, so a briarling under that material is the bush it copies;
# the baked maps are painted from the same colours.
CANE_GREEN, CANE_RED, ROOT_BROWN = (0.085, 0.15, 0.045), (0.2, 0.06, 0.04), (0.09, 0.065, 0.04)
TINTS = dict(
    cane=lambda g: np.where(g[:, 2:3] > 0.5, np.array(ROOT_BROWN), _ramp(g[:, 0], [(0.0, CANE_GREEN), (0.7, CANE_GREEN), (1.0, CANE_RED)])),
    thorn=lambda g: _ramp(g[:, 0], [(0.0, (0.2, 0.1, 0.05)), (0.8, (0.04, 0.01, 0.01))]),
    leaf=lambda g: _ramp(g[:, 0], [(0.0, LEAF_DEEP), (1.0, tuple(0.65 * np.array(LEAF_DEEP) + 0.35 * np.array(LEAF)))]) * (1.0 - 0.3 * g[:, 2:3]),
    rose=lambda g: _ramp(g[:, 0], [(0.0, ROSE_DEEP), (0.5, ROSE), (1.0, tuple(0.5 * np.array(ROSE) + 0.5 * np.array(BLUSH)))]),
    blush=lambda g: _ramp(g[:, 0], [(0.0, ROSE), (0.5, BLUSH), (1.0, (0.85, 0.62, 0.7))]),
    throat=lambda g: _ramp(g[:, 0], [(0.0, (0.3, 0.02, 0.07)), (1.0, (0.02, 0.002, 0.006))]),
)


def cane(pc, pts, radii, segs=5, rings=8, kind=0.0, side=(1, 0, 0)):
    """A stem through `pts`, ending in a point."""
    Cs, R = kit._catmull([tuple(p) for p in pts], [(r, r) for r in radii], rings)
    X, Y, T = kit._frames(Cs, side)
    loops = []
    for i in range(rings):
        loops.append([pc.vert(Cs[i] + (X[i] * math.cos(2 * math.pi * j / segs) + Y[i] * math.sin(2 * math.pi * j / segs)) * R[i][0],
                              (i / (rings - 1), j / segs, kind)) for j in range(segs)])
    tip = pc.vert(Cs[-1] + T[-1] * R[-1][0] * 2.5, (1.0, 0.0, kind))
    for a, b in zip(loops[:-1], loops[1:]):
        for j in range(segs):
            pc.face(a[j], a[(j + 1) % segs], b[(j + 1) % segs], b[j])
    for j in range(segs):
        pc.face(loops[-1][j], loops[-1][(j + 1) % segs], tip)
    pc.face(*reversed(loops[0]))
    return Cs, X, Y, T


def thorn(pc, base, out, along, size, kind=0.0):
    """A hooked rose thorn: broad at the base, its point swept back along the stem."""
    out, along = _unit(out), _unit(along)
    across = np.cross(out, along)
    b = [pc.vert(base + along * size * 0.5, (0.0, 0.0, kind)), pc.vert(base - along * size * 0.3 + across * size * 0.22, (0.0, 0.5, kind)),
         pc.vert(base - along * size * 0.3 - across * size * 0.22, (0.0, 1.0, kind))]
    tip = pc.vert(base + out * size - along * size * 0.45, (1.0, 0.0, kind))
    for j in range(3):
        pc.face(b[j], b[(j + 1) % 3], tip)


def leaflet(pc, root, along, face, length, width, kind):
    """An ovate leaflet with a drawn-out point, folded a little along its midrib
    and arched over its length."""
    along, face = _unit(along), _unit(face)
    across = np.cross(face, along)
    a = pc.vert(root, (0.0, 0.0, kind))
    side = {}
    for s in (1.0, -1.0):
        side[s] = [pc.vert(root + along * length * u + across * s * width * w + face * (width * w * 0.42 - length * 0.1 * (u - 0.45) ** 2 * 4.0), (u, w / 0.5, kind))   # grad lays the leaflet flat on its swatch
                   for u, w in ((0.17, 0.33), (0.47, 0.5), (0.78, 0.31))]
    tip = pc.vert(root + along * length - face * length * 0.12, (1.0, 0.0, kind))
    for s in (1.0, -1.0):
        q = (a, side[s][0], side[s][1], side[s][2], tip)
        pc.face(*(q if s < 0 else reversed(q)))


def spray(pc, root, along, face, size, kind, rng):
    """A rose leaf: leaflets on a thin stalk, the end one largest."""
    along, face = _unit(along), _unit(face)
    across = np.cross(face, along)
    w = size * 0.012
    end = root + along * size * 0.5 - face * size * 0.05
    q = [pc.vert(root + across * w, (0.0, 1.0, kind)), pc.vert(root - across * w, (0.0, 1.0, kind)),
         pc.vert(end - across * w * 0.6, (0.0, 1.0, kind)), pc.vert(end + across * w * 0.6, (0.0, 1.0, kind))]
    pc.face(*q)
    at = root + (end - root) * 0.55
    for s in (1.0, -1.0):
        d = _unit(along * 0.55 + across * s + face * rng.uniform(-0.1, 0.2))
        leaflet(pc, at, d, face + across * s * 0.25, size * 0.4, size * 0.27, kind)
    leaflet(pc, end, along - face * 0.1, face, size * 0.52, size * 0.33, kind)


def petal(pc, hinge, out, face, length, width, cup, kind, nu=3, nv=4):
    """One rose petal from its hinge: `out` is the way it lies, `face` its
    inner side; `cup` curls it toward `face`."""
    out, face = _unit(out), _unit(face)
    across = np.cross(face, out)
    grid = []
    for i in range(nv + 1):
        t = i / nv
        row = []
        half = width * 0.5 * (0.28 + 0.72 * math.sin(math.pi * min(t * 0.62 + 0.14, 1.0)) ** 0.8) * (1.0 - 0.35 * max(t - 0.8, 0.0) / 0.2)
        ang = cup * t
        c = hinge + (out * math.sin(ang) + face * (1.0 - math.cos(ang))) * (length / max(cup, 1e-3)) if cup > 1e-3 else hinge + out * length * t
        d = out * math.cos(ang) + face * math.sin(ang)                # the way it runs here
        n = face * math.cos(ang) - out * math.sin(ang)
        for j in range(nu + 1):
            s = j / nu * 2.0 - 1.0
            lip = 0.12 * length * (t ** 3) * (1.0 - s * s)            # the rim rolls back
            row.append(pc.vert(c + across * half * s + n * (half * 0.5 * s * s - lip) + d * 0.0, (t, abs(s), kind)))
        grid.append(row)
    for a, b in zip(grid[:-1], grid[1:]):
        for j in range(nu):
            pc.face(a[j], b[j], b[j + 1], a[j + 1])


def bud(pc, centre, axis, radius, kind):
    """A rose not yet open: five petals wrapped round a tight heart."""
    axis = _unit(axis)
    x = _unit(np.cross(axis, (0.3, 0.2, 1.0)))
    y = np.cross(axis, x)
    for i in range(4):
        a = 2 * math.pi * (i + 0.5 * kind) / 4.0
        r = x * math.cos(a) + y * math.sin(a)
        petal(pc, centre + r * radius * 0.2, r * 0.55 + axis * 0.83, axis * 0.6 - r, radius * 1.55, radius * 1.5, 1.15, kind, nu=2, nv=2)
    top = pc.vert(centre + axis * radius * 1.05, (0.25, 0.3, kind))
    ring = [pc.vert(centre + axis * radius * 0.55 + (x * math.cos(2 * math.pi * j / 5 + 0.6) + y * math.sin(2 * math.pi * j / 5 + 0.6)) * radius * 0.5,
                    (0.1, 0.6, kind)) for j in range(5)]
    for j in range(5):
        pc.face(ring[j], ring[(j + 1) % 5], top)


# ------------------------------------------------------------------ the cage (sculpted)

def cage_forms():
    t, e = kit.tube, kit.ellipsoid
    forms = [e("core", tuple(C), tuple(CAGE_R * (0.8, 0.86, 0.78)), k=0.01, segs=24)]
    canes = []
    for i, y in enumerate((-0.135, -0.085, -0.03, 0.03, 0.085, 0.135)):          # the ribs
        s = math.sqrt(max(1.0 - (y / (CAGE_R[1] * 1.03)) ** 2, 0.02))
        lean = 0.02 * math.sin(i * 1.9)
        pts = []
        for j in range(13):
            a = 2 * math.pi * j / 12 + 0.26 * i
            pts.append((C[0] + math.cos(a) * CAGE_R[0] * s, C[1] + y + lean * math.sin(a), C[2] + math.sin(a) * CAGE_R[2] * s))
        canes.append(t(f"rib{i}", pts, [0.0125] * 13, k=0.006, segs=10, rings_per_m=220))
    for i in range(8):                                                              # the long canes woven through them
        a = 2 * math.pi * (i + 0.5) / 8
        pts = []
        for j in range(9):
            u = -0.94 + 1.88 * j / 8
            s = math.sqrt(max(1.0 - u * u, 0.0))
            over = 1.0 + 0.085 * math.cos(math.pi * j + i * math.pi)                # over one rib, under the next
            aa = a + 0.5 * u
            pts.append((C[0] + math.cos(aa) * CAGE_R[0] * s * over, C[1] + u * CAGE_R[1], C[2] + math.sin(aa) * CAGE_R[2] * s * over))
        canes.append(t(f"long{i}", pts, [0.008] + [0.0115] * 7 + [0.008], k=0.006, segs=10, rings_per_m=220))
    neck = t("neck", [tuple(NECK[0] - _v(0, 0.04, 0.05)), tuple(NECK[0]), tuple(NECK[1]), tuple(BLOOM - FACE * 0.03)], [0.02, 0.019, 0.016, 0.02], k=0.012,
             segs=12, rings_per_m=160)
    knot = [e("knot", tuple(KNOT), (0.046, 0.04, 0.042), k=0.008, segs=16), e("knot_b", tuple(KNOT + _v(0.02, 0.012, -0.02)), (0.024, 0.022, 0.02), k=0.008, segs=12),
            e("knot_c", tuple(KNOT + _v(-0.024, 0.006, 0.016)), (0.02, 0.019, 0.022), k=0.008, segs=12)]
    return forms, canes + [neck], knot


def cage_material():
    def build(nt, bsdf):
        g = kit.Graph(nt)
        P = g.position()
        cane_m, knot_m, _ = g.split(g.attr("zone"))
        streak = g.noise(g.scale_vec(P, (1.0, 0.2, 1.0)), 260.0, 3.0)
        blotch = g.noise(P, 34.0, 2.0)
        col = g.mix_rgb(g.smooth(blotch, 0.4, 0.66), (0.075, 0.15, 0.04), (0.17, 0.085, 0.045))        # green cane going red-brown
        col = g.mix_rgb(g.math("MULTIPLY", g.smooth(streak, 0.5, 0.75), 0.5), col, (0.24, 0.2, 0.1))
        col = g.mix_rgb(cane_m, (0.012, 0.01, 0.008), col)                                             # between the canes: dark
        burl, _ = g.voronoi(P, 210.0)
        wet = g.mix_rgb(g.smooth(burl, 0.0, 0.25), (0.012, 0.004, 0.004), (0.085, 0.022, 0.018))
        col = g.mix_rgb(knot_m, col, wet)
        rough = g.mix(knot_m, g.mix(cane_m, 0.9, 0.5), 0.12)
        height = g.mix(knot_m, g.math("MULTIPLY", streak, 0.35), g.smooth(burl, 0.0, 0.3))
        g.out(bsdf, color=col, rough=rough, normal=g.bump(height, 0.0012))
    return kit.sculpt_material("briar_cage", build)


# ------------------------------------------------------------------ materials of the hand-built pieces

def cane_material():
    def build(nt, bsdf):
        g = kit.Graph(nt)
        P = g.position()
        along, _, kind = g.split(g.attr("grad"))
        streak = g.noise(g.scale_vec(P, (0.3, 0.3, 1.0)), 240.0, 3.0)
        col = g.mix_rgb(g.smooth(g.noise(P, 30.0, 2.0), 0.4, 0.66), (0.075, 0.15, 0.04), (0.17, 0.085, 0.045))
        col = g.mix_rgb(g.math("MULTIPLY", g.smooth(streak, 0.5, 0.75), 0.5), col, (0.24, 0.2, 0.1))
        col = g.mix_rgb(g.smooth(along, 0.72, 1.0), col, (0.2, 0.05, 0.035))                           # young red growth at the tip
        root = g.mix_rgb(g.smooth(streak, 0.3, 0.7), (0.05, 0.035, 0.022), (0.12, 0.09, 0.06))
        col = g.mix_rgb(g.smooth(kind, 0.4, 0.6), col, root)                                           # kind 1: a root
        g.out(bsdf, color=col, rough=g.mix(g.smooth(kind, 0.4, 0.6), 0.5, 0.85), normal=g.bump(streak, 0.0007))
    return kit.sculpt_material("briar_cane", build)


def thorn_material():
    def build(nt, bsdf):
        g = kit.Graph(nt)
        along, _, kind = g.split(g.attr("grad"))
        col = g.mix_rgb(g.smooth(along, 0.05, 0.75), (0.2, 0.1, 0.05), (0.035, 0.008, 0.008))          # darker at the point
        tooth = g.mix_rgb(g.smooth(along, 0.0, 0.8), (0.3, 0.2, 0.12), (0.05, 0.01, 0.01))
        g.out(bsdf, color=g.mix_rgb(g.smooth(kind, 0.4, 0.6), col, tooth), rough=0.28)
    return kit.sculpt_material("briar_thorn", build)


def leaf_material():
    def build(nt, bsdf):
        g = kit.Graph(nt)
        P = g.position()
        along, across, kind = g.split(g.attr("grad"))
        col = g.mix_rgb(g.smooth(g.noise(P, 60.0, 2.0), 0.35, 0.7), LEAF_DEEP, (0.05, 0.42, 0.12))
        col = g.mix_rgb(g.math("MULTIPLY", g.smooth(kind, 0.2, 0.9), 0.35), col, (0.02, 0.2, 0.07))    # some leaves older and darker
        rib = g.math("SUBTRACT", 1.0, g.smooth(across, 0.0, 0.16))
        vein = g.smooth(g.math("SINE", g.math("MULTIPLY", g.math("ADD", along, g.math("MULTIPLY", across, 0.45)), 34.0)), 0.75, 1.0)
        col = g.mix_rgb(g.math("MAXIMUM", g.math("MULTIPLY", rib, 0.7), g.math("MULTIPLY", vein, 0.25)), col, LEAF)
        height = g.math("ADD", g.math("MULTIPLY", rib, -1.0), g.math("MULTIPLY", vein, -0.5))
        g.out(bsdf, color=col, rough=0.3, normal=g.bump(height, 0.0008))
    return kit.sculpt_material("briar_leaf", build)


def petal_material(name, deep, mid, pale):
    def build(nt, bsdf):
        g = kit.Graph(nt)
        P = g.position()
        along, across, kind = g.split(g.attr("grad"))
        col = g.mix_rgb(g.smooth(along, 0.0, 0.5), deep, mid)
        col = g.mix_rgb(g.math("MULTIPLY", g.smooth(along, 0.55, 1.0), 0.7), col, pale)
        vein = g.noise(g.scale_vec(P, (1.0, 1.0, 0.25)), 380.0, 2.0)
        col = g.mix_rgb(g.math("MULTIPLY", g.smooth(vein, 0.55, 0.8), 0.18), col, deep)
        g.out(bsdf, color=col, rough=0.5, normal=g.bump(vein, 0.0004))
    return kit.sculpt_material(name, build)


def throat_material():
    def build(nt, bsdf):
        g = kit.Graph(nt)
        along, _, _ = g.split(g.attr("grad"))
        col = g.mix_rgb(g.smooth(along, 0.0, 1.0), (0.3, 0.02, 0.07), (0.02, 0.002, 0.006))
        g.out(bsdf, color=col, rough=0.14)
    return kit.sculpt_material("briar_throat", build)


# ------------------------------------------------------------------ the hard parts

PETALS = 6


def petal_frames():
    """For each petal bone: its hinge and the way it points when the mouth is open."""
    x = _unit(np.cross(FACE, (0.0, 0.0, 1.0)))
    y = np.cross(FACE, x)
    out = []
    for i in range(PETALS):
        a = 2 * math.pi * i / PETALS + math.pi / 2
        r = x * math.cos(a) + y * math.sin(a)
        out.append((BLOOM + r * 0.034, r, np.cross(r, FACE)))
    return out


def hard_parts():
    """[(object, part number, bone or [bones])], each its own bake source."""
    out = []
    mats = dict(cane=cane_material(), thorn=thorn_material(), leaf=leaf_material(), throat=throat_material(),
                rose=petal_material("briar_rose", ROSE_DEEP, ROSE, BLUSH), blush=petal_material("briar_blush", ROSE, BLUSH, (0.85, 0.62, 0.7)))
    rng = _rng(7)

    def add(pc, name, mat, part, bone):
        o = pc.build(name, closed=mat in ("cane", "thorn"), tint=TINTS[mat])
        kit.set_material(o, mats[mat])
        kit.tag(o, part)
        out.append((o, part, bone))

    # ---- the legs: one cane each, thorns and leaves on the bones they ride
    for leg in LEGS:
        hip, cox, knee, foot, radial = leg_points(leg)
        pc = Piece()
        Cs, X, Y, T = cane(pc, [hip, cox, knee, knee * 0.45 + foot * 0.55 + radial * 0.035, foot], [0.016, 0.0155, 0.0145, 0.011, 0.005], segs=5, rings=9)
        add(pc, f"leg_{leg}", "cane", 10, [f"coxa_{leg}", f"femur_{leg}", f"tibia_{leg}"])
        on = dict(femur=(Piece(), Piece()), tibia=(Piece(), Piece()))
        up = _v(0, 0, 1)
        for seg_name, a, b, n_thorn, n_leaf, r in (("femur", cox, knee, 2, 4, 0.015), ("tibia", knee, foot, 5, 9, 0.011)):
            d = _unit(b - a)
            side = _unit(np.cross(d, radial + up * 0.3))
            for k in range(n_thorn):
                u = (k + 0.6) / (n_thorn + 0.4)
                ang = rng.uniform(0, 2 * math.pi)
                o = _unit(radial * math.cos(ang) + side * math.sin(ang) + up * 0.3)
                thorn(on[seg_name][0], a + (b - a) * u + o * r * 0.7, o, d, rng.uniform(0.032, 0.046))
            flat = _unit(np.cross(side, d))                           # the leaves lie flat to the dome the canes make as a bush
            for k in range(n_leaf):
                u = (k + 0.4) / n_leaf * (0.9 if seg_name == "tibia" else 1.0)
                way = 1.0 if k % 2 == 0 else -1.0
                o = _unit(side * way + d * rng.uniform(-0.5, 0.3) + flat * rng.uniform(-0.25, 0.25))
                spray(on[seg_name][1], a + (b - a) * u + o * r * 0.5, o, _unit(flat + o * rng.uniform(-0.2, 0.2) + d * rng.uniform(-0.2, 0.2)),
                      rng.uniform(0.19, 0.26), rng.uniform(0, 1), rng)
        for seg_name, (th, lf) in on.items():
            add(th, f"thorns_{seg_name}_{leg}", "thorn", 20, f"{seg_name}_{leg}")
            add(lf, f"leaves_{seg_name}_{leg}", "leaf", 30, f"{seg_name}_{leg}")
        d = _unit(foot - knee)                                      # two blooms on each shin: on the dome when it is a bush
        side = _unit(np.cross(d, radial + up * 0.3))
        flat = _unit(np.cross(side, d))
        for n, (u, way) in enumerate(((0.38, 1.0), (0.74, -1.0))):
            pc = Piece()
            axis = _unit(side * way * 0.75 - flat * 0.66)
            pale = (LEGS.index(leg) + n) % 2
            bud(pc, knee + (foot - knee) * u + axis * 0.03, axis, 0.046, float(pale))
            add(pc, f"bud{n}_{leg}", "blush" if pale else "rose", 40, f"tibia_{leg}")

    # ---- the lashing limbs
    for side, s in (("r", 1.0), ("l", -1.0)):
        pts = lash_points(side)
        pc = Piece()
        cane(pc, pts, [0.0135, 0.0125, 0.0105, 0.008, 0.004], segs=4, rings=11)
        add(pc, f"lash_{side}", "cane", 11, [f"lash_{k}_{side}" for k in range(4)])
        for k in range(4):
            a, b = pts[k], pts[k + 1]
            d = _unit(b - a)
            up = _unit(np.cross(d, (s, 0, 0)))
            th, lf = Piece(), Piece()
            for j in range(2):
                o = _unit(up * (1.0 if j == 0 else -0.8) + np.cross(d, up) * rng.uniform(-0.5, 0.5))
                thorn(th, a + (b - a) * (0.3 + 0.45 * j) + o * 0.008, o, d, rng.uniform(0.024, 0.034))
            for j in range(2 if k < 3 else 1):
                o = _unit(np.cross(d, up) * (1.0 if (j + k) % 2 == 0 else -1.0) + up * 0.5)
                spray(lf, a + (b - a) * (0.25 + 0.5 * j) + o * 0.006, o - d * 0.2, _unit(up + o * 0.2), rng.uniform(0.1, 0.135), rng.uniform(0, 1), rng)
            add(th, f"thorns_lash{k}_{side}", "thorn", 21, f"lash_{k}_{side}")
            add(lf, f"leaves_lash{k}_{side}", "leaf", 31, f"lash_{k}_{side}")

    # ---- leaves and thorns on the cage itself
    th, lf = Piece(), Piece()
    for k in range(16):
        a = rng.uniform(0.15, math.pi - 0.15) if k < 13 else rng.uniform(math.pi + 0.5, 2 * math.pi - 0.5)
        u = rng.uniform(-0.8, 0.75)
        sdir = math.sqrt(1.0 - u * u)
        n = _unit(_v(math.cos(a) * sdir / CAGE_R[0], u / CAGE_R[1], math.sin(a) * sdir / CAGE_R[2]))
        p = C + _v(math.cos(a) * sdir * CAGE_R[0], u * CAGE_R[1], math.sin(a) * sdir * CAGE_R[2]) * 1.06
        if k % 3 == 2:
            thorn(th, p, n, _v(0, 1, 0), rng.uniform(0.022, 0.03))
        else:
            spray(lf, p, _unit(n + _v(0, -0.4, 0.3)), _unit(_v(0, 0, 1) + n * 0.4), rng.uniform(0.12, 0.15), rng.uniform(0, 1), rng)
    add(th, "thorns_cage", "thorn", 22, "cage")
    add(lf, "leaves_cage", "leaf", 32, "cage")

    # ---- the bloom: twelve petals on six bones, round a throat ringed with thorns
    for i, (hinge, r, _) in enumerate(petal_frames()):
        pc = Piece()
        petal(pc, hinge, _unit(r * 0.96 - FACE * 0.28), FACE, 0.098, 0.092, 0.7, i / PETALS)
        r2 = _unit(r + np.cross(FACE, r) * 0.58)                                    # the inner whorl sits between
        petal(pc, BLOOM + r2 * 0.022 + FACE * 0.004, _unit(r2 * 0.9 + FACE * 0.2), FACE, 0.068, 0.064, 0.8, i / PETALS, nu=2, nv=3)
        add(pc, f"petal_{i}", "rose", 50 + i, f"petal_{i}")
    x = _unit(np.cross(FACE, (0.0, 0.0, 1.0)))
    y = np.cross(FACE, x)
    pc = Piece()
    rings = []
    for k, (depth, rad) in enumerate(((0.008, 0.04), (-0.014, 0.03), (-0.04, 0.016))):
        rings.append([pc.vert(BLOOM + FACE * depth + (x * math.cos(2 * math.pi * j / 8) + y * math.sin(2 * math.pi * j / 8)) * rad, (k / 2.0, 0.0, 0.0))
                      for j in range(8)])
    for a, b in zip(rings[:-1], rings[1:]):
        for j in range(8):
            pc.face(a[j], b[j], b[(j + 1) % 8], a[(j + 1) % 8])
    end = pc.vert(BLOOM - FACE * 0.05, (1.0, 0.0, 0.0))
    for j in range(8):
        pc.face(rings[-1][j], end, rings[-1][(j + 1) % 8])
    add(pc, "throat", "throat", 60, "bloom")
    pc = Piece()
    for n, rad, depth, size, turn in ((9, 0.04, 0.008, 0.04, 0.0), (7, 0.03, -0.01, 0.03, 0.4)):
        for j in range(n):
            a = 2 * math.pi * (j + turn) / n
            r = x * math.cos(a) + y * math.sin(a)
            thorn(pc, BLOOM + FACE * depth + r * rad, _unit(-r * 0.75 + FACE * 0.66), -FACE, size * (0.85 + 0.3 * rng.random()), 1.0)
    add(pc, "teeth", "thorn", 61, "bloom")
    pc = Piece()                                                    # the green cup under the bloom
    for i in range(5):
        a = 2 * math.pi * i / 5
        r = x * math.cos(a) + y * math.sin(a)
        leaflet(pc, BLOOM - FACE * 0.03 + r * 0.016, _unit(r - FACE * 0.25), -FACE, 0.06, 0.03, 0.5)
    add(pc, "sepals", "leaf", 33, "bloom")

    # ---- the roots, stowed along the inside of the cage
    for i in range(ROOTS):
        a, b = root_rest(i)
        pc = Piece()
        d = b - a
        cane(pc, [a, a + d * 0.3 + _v(0.004, 0, 0.004), a + d * 0.65 - _v(0.004, 0, 0.003), b], [0.009, 0.008, 0.0055, 0.002], segs=4, rings=6, kind=1.0)
        add(pc, f"root_{i}", "cane", 70 + i, f"roots_{i}")
    return out


def root_rest(i):
    x = (-0.045, -0.015, 0.015, 0.045)[i]
    a = _v(x, -0.13, C[2] - 0.02)
    return a, a + _v(0, ROOT_LEN, 0)


# ------------------------------------------------------------------ rig

def bones():
    B = [("root", (0, 0, 0), (0, 0.1, 0), None, False),
         ("body", tuple(C), tuple(C + _v(0, 0.1, 0)), "root", False),
         ("cage", tuple(C - _v(0, 0.15, 0)), tuple(C + _v(0, 0.15, 0)), "body", True),
         ("heart_knot", tuple(KNOT), tuple(KNOT + _v(0, 0.04, -0.02)), "cage", False),
         ("neck", tuple(NECK[0]), tuple(NECK[1]), "cage", True),
         ("neck_1", tuple(NECK[1]), tuple(BLOOM - FACE * 0.03), "neck", True),
         ("bloom", tuple(BLOOM - FACE * 0.03), tuple(BLOOM + FACE * 0.05), "neck_1", True),
         ("mouth", tuple(BLOOM), tuple(BLOOM + FACE * 0.04), "bloom", False)]
    for i, (hinge, r, _) in enumerate(petal_frames()):
        B.append((f"petal_{i}", tuple(hinge), tuple(hinge + r * 0.08), "bloom", True))
    for leg in LEGS:
        hip, cox, knee, foot, radial = leg_points(leg)
        B.append((f"coxa_{leg}", tuple(hip), tuple(cox), "cage", True))
        B.append((f"femur_{leg}", tuple(cox), tuple(knee), f"coxa_{leg}", True))
        B.append((f"tibia_{leg}", tuple(knee), tuple(foot), f"femur_{leg}", True))
        B.append((f"tip_{leg}", tuple(foot), tuple(foot + radial * 0.03), f"tibia_{leg}", False))
    for side in ("r", "l"):
        pts = lash_points(side)
        par = "cage"
        for k in range(4):
            B.append((f"lash_{k}_{side}", tuple(pts[k]), tuple(pts[k + 1]), par, True))
            par = f"lash_{k}_{side}"
    for i in range(ROOTS):
        a, b = root_rest(i)
        B.append((f"roots_{i}", tuple(a), tuple(b), "cage", True))
    return B


def spec():
    return dict(legs={leg: (f"femur_{leg}", f"tibia_{leg}", None, f"tip_{leg}") for leg in LEGS}, pole_space="cage",
                core=["cage"], radius=dict(cage=0.1))


# ------------------------------------------------------------------ poses

def _lash(curl=0.0, spread=0.0, lift=0.0):
    """Four bones' pitch and yaw (p0, y0, p1, y1, ...) from three plain numbers."""
    out = []
    for k, w in enumerate((0.5, 1.0, 1.2, 1.3)):
        out += [curl * w + (lift if k == 0 else 0.0), spread * (1.0 if k == 0 else 0.25)]
    return tuple(out)


STAND = dict(x=0.0, y=0.0, z=0.0, pitch=0.0, yaw=0.0, roll=0.0, neck_p=0.0, neck_yaw=0.0, bloom_p=0.0, bloom_yaw=0.0, bloom_roll=0.0,
             open=1.0, tuck=0.0, splay=0.0, air=0.0, lash_r=_lash(), lash_l=_lash(), roots=0.0, root_reach=1.0, ground=0.0,
             leaves=0.0, thorns=0.0, coxa=0.0,
             **{f"f_{leg}": (0.0, 0.0, 0.0) for leg in LEGS})
# The bush: the feet drawn to one root, the canes arching, the lashes wrapped over, the bloom shut.
BUSH = dict(STAND, z=-0.285, pitch=0.0, neck_p=-12.0, bloom_p=-10.0, open=0.0, tuck=1.0, coxa=30.0,
            lash_r=(-8.0, 44.0, 26.0, 30.0, 44.0, 30.0, 46.0, 24.0), lash_l=(-8.0, 44.0, 26.0, 30.0, 44.0, 30.0, 46.0, 24.0))


def bush_tip(leg):
    """Where a leg's point is held when it is a cane of the bush (given as at
    rest, carried by the cage): up over the body, so the cane arches out and back in."""
    hip, cox, knee, foot, radial = leg_points(leg)
    return _v(0, hip[1] * 0.5, 0.92 + 0.05 * math.sin(LEGS.index(leg) * 2.1)) + radial * (0.1 + 0.05 * math.cos(LEGS.index(leg) * 1.7))


def pose(r, q):
    p = rig.Pose()
    p.body(loc=(q["x"], q["y"], q["z"]), pitch=q["pitch"], yaw=q["yaw"], roll=q["roll"])
    p.turn("neck", pitch=q["neck_p"] * 0.5, yaw=q["neck_yaw"] * 0.5)
    p.turn("neck_1", pitch=q["neck_p"] * 0.5, yaw=q["neck_yaw"] * 0.5)
    p.turn("bloom", pitch=q["bloom_p"], yaw=q["bloom_yaw"], roll=q["bloom_roll"])
    shut = 1.0 - q["open"]
    for i, (hinge, radial, axis) in enumerate(petal_frames()):
        p.fk[f"petal_{i}"] = Quaternion(Vector(axis), math.radians(-(104.0 + 8.0 * math.sin(i * 2.3)) * shut))
    for leg in LEGS:
        hip, cox, knee, foot, radial = leg_points(leg)
        s = 1.0 if leg[0] == "r" else -1.0
        axis = Vector(np.cross(radial, (0, 0, 1)))                      # lifts the coxa: the knee goes up and in
        p.fk[f"coxa_{leg}"] = Quaternion(axis, math.radians(-q["coxa"]))
        off = q[f"f_{leg}"]
        rest = r.rest_ball(leg)
        ball = Vector((rest.x + off[0] + radial[0] * q["splay"], rest.y + off[1] + radial[1] * q["splay"], rest.z + off[2]))
        tuck = q["tuck"]
        carried = (knee * 0.3 + foot * 0.7 + _v(0, 0, 0.1)) * (1.0 - tuck) + bush_tip(leg) * tuck
        p.foot(leg, ball=tuple(ball), carried=tuple(carried), space="cage", mix=max(q["air"], tuck),
               knee=tuple(radial * 1.0 + _v(0, 0, 1.2)), yaw=0.0)
    for side, s in (("r", 1.0), ("l", -1.0)):
        L = q[f"lash_{side}"]
        for k in range(4):
            p.turn(f"lash_{k}_{side}", pitch=L[2 * k], yaw=-s * L[2 * k + 1])
    for i in range(ROOTS):                                               # out of the cage and along the ground, toward what it wants
        k = smooth(q["roots"])
        if k > 0.0:
            a, b = root_rest(i)
            fan = (i - 1.5) * 24.0 * (1.0 - 0.6 * q["root_reach"])
            target = _v((i - 1.5) * 0.05, 0.1, 0.014 - (C[2] + q["z"]) + C[2])
            p.fk[f"roots_{i}"] = Quaternion().slerp(rot(yaw=-fan), k)
            p.offsets[f"roots_{i}"] = Vector(tuple((target - a) * k)) + Vector((0.0, 0.16 * q["root_reach"] * k, 0.0))
    if q["ground"]:
        p.rest_on_ground(q["ground"])
    p.key("leaves_turn", q["leaves"])
    p.key("thorns_up", q["thorns"])
    return p


def shape_keys(low):
    """leaves_turn: every leaf swings to face forward (toward her). thorns_up:
    the thorns stand off the canes and lengthen."""
    P = kit.co(low)
    part = kit.parts_of(low)
    low.shape_key_add(name="Basis")
    me = low.data
    # islands, so each spray or thorn turns about its own root
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    seen = np.zeros(len(P), dtype=bool)
    islands = []
    for v in bm.verts:
        if seen[v.index] or part[v.index] not in (20, 21, 22, 30, 31, 32):
            continue
        stack, isle = [v], []
        seen[v.index] = True
        while stack:
            w = stack.pop()
            isle.append(w.index)
            for e in w.link_edges:
                o = e.other_vert(w)
                if not seen[o.index]:
                    seen[o.index] = True
                    stack.append(o)
        islands.append(np.sort(np.array(isle)))
    bm.free()
    turn, lift = P.copy(), P.copy()
    for isle in islands:
        Q = P[isle]
        kind = part[isle[0]]
        if kind >= 30:                                   # a leaf: turn about its root to look along +y
            root = Q[0]
            c = Q.mean(axis=0) - root
            aim = _unit(_unit(c) * 0.45 + _v(0.0, 0.8, 0.25))
            q = rig._swing(Vector(_unit(c)), Vector(aim))
            R = np.array(q.to_matrix())
            turn[isle] = root + (Q - root) @ R.T
        else:                                            # a thorn: its base stays, its point stands out
            base = Q[:3].mean(axis=0)
            lift[isle[3]] = Q[3] + (Q[3] - base) * 0.55
    low.shape_key_add(name="leaves_turn").data.foreach_set("co", turn.ravel())
    low.shape_key_add(name="thorns_up").data.foreach_set("co", lift.ravel())


def author(r):
    def keyed(name, base, keys, loop=False, more=None, **kw):
        K = Keys(base, keys)

        def fn(t):
            q = K(t)
            if more is not None:
                more(t, q)
            return pose(r, q)
        r.clip(name, K.duration, fn, loop=loop, **kw)

    def additive(name, duration, fn, loop=False):
        def frame(t):
            p = rig.Pose()
            fn(t, p)
            return p
        r.clip(name, duration, frame, loop=loop)

    def feet(**kw):
        """f_<leg> offsets from a few words: all=(x, y, z), or one leg's own."""
        out = {}
        for leg in LEGS:
            v = kw.get(leg, kw.get("all", (0.0, 0.0, 0.0)))
            out[f"f_{leg}"] = (v[0] * (1.0 if leg[0] == "r" else -1.0), v[1], v[2])
        return out

    DRAWN = _lash(curl=-16.0, spread=10.0, lift=-14.0)          # a lash pulled back over the shoulder
    STRUCK = _lash(curl=34.0, spread=-6.0, lift=26.0)           # and thrown forward and down
    LIMP = _lash(curl=42.0, spread=24.0, lift=40.0)

    # ---- the bush, and what gives it away
    keyed("bush", BUSH, [(0.0, {}), (1.0, {})], loop=True)
    additive("leaves_turn", 0.8, lambda t, p: p.key("leaves_turn", smooth(seg(t, 0.0, 0.7))))
    keyed("thorns_lift", BUSH, [(0.0, {}), (0.35, dict(thorns=1.0, z=-0.275), "out"), (0.6, dict(thorns=1.0))],
          more=lambda t, q: q.update(roll=0.8 * rig.ring(t, 0.05, 1.0, 14.0, 5.0)))

    def unfolding(t, q):                                         # the canes come down one after another, not together
        for i, leg in enumerate(LEGS):
            lag = (0.0, 0.1, 0.05, 0.07, 0.02, 0.12)[i]
            q[f"f_{leg}"] = (0.0, 0.0, 0.05 * pulse(t, 0.3 + lag, 0.55 + lag, 0.75 + lag))
    keyed("unfold", BUSH, [
        (0.0, {}), (0.25, dict(z=-0.27, thorns=1.0, lash_r=_lash(curl=10.0, spread=40.0), lash_l=_lash(curl=10.0, spread=40.0))),
        (0.7, dict(STAND, open=0.0, z=-0.06, pitch=-8.0, neck_p=-20.0, thorns=1.0, tuck=0.0, coxa=6.0), "smooth"),
        (0.95, dict(z=0.035, pitch=4.0, neck_p=6.0, open=0.9, thorns=0.4), "snap"),
        (1.2, dict(STAND))], more=unfolding)
    keyed("fold", STAND, [
        (0.0, {}), (0.25, dict(open=0.0, neck_p=-10.0, z=-0.05, lash_r=_lash(curl=14.0, spread=30.0), lash_l=_lash(curl=14.0, spread=30.0))),
        (0.55, dict(z=-0.24, tuck=0.35, coxa=12.0, neck_p=-12.0), "slow"),
        (0.85, dict(BUSH, z=-0.28), "out"), (1.0, dict(BUSH))])

    # ---- standing
    keyed("idle", STAND, [(0.0, {}), (2.0, {})], loop=True,
          more=lambda t, q: q.update(z=0.006 * wave(t, 2.0), bloom_yaw=6.0 * wave(t, 2.0, 0.2), neck_p=2.0 * wave(t, 1.0), open=0.86 + 0.14 * wave(t, 1.0, 0.3),
                                     lash_r=_lash(curl=3.0 * wave(t, 2.0, 0.1)), lash_l=_lash(curl=3.0 * wave(t, 2.0, 0.6))))

    stance = {leg: r.rest_ball(leg).y for leg in LEGS}
    tripod = dict(r0=0.0, l1=0.0, r2=0.0, l0=0.5, r1=0.5, l2=0.5)

    def walk_up(t, ph, p):
        q = dict(STAND, z=-0.03 + 0.006 * math.cos(4 * math.pi * ph), roll=2.5 * math.sin(2 * math.pi * ph), yaw=3.0 * math.cos(2 * math.pi * ph),
                 neck_p=4.0, bloom_yaw=-3.0 * math.cos(2 * math.pi * ph), lash_r=_lash(curl=4.0 * math.sin(2 * math.pi * ph), lift=-4.0),
                 lash_l=_lash(curl=-4.0 * math.sin(2 * math.pi * ph), lift=-4.0))
        full = pose(r, q)
        for k in ("body_loc", "body_rot", "fk", "offsets", "keys"):
            setattr(p, k, getattr(full, k))
    r.gait("walk", speed=1.5, stride=0.5, duty=0.6, phases=tripod, lift=0.07, upper=walk_up, stance_y=stance, heel_off=0.0, swing_heel=0.0,
           toe_swing=0.0, yaw=0.0)

    def run_up(t, ph, p):
        q = dict(STAND, z=-0.1 + 0.008 * math.cos(4 * math.pi * ph), pitch=7.0, roll=3.5 * math.sin(2 * math.pi * ph), neck_p=-8.0, open=1.0,
                 lash_r=_lash(curl=-10.0, spread=8.0, lift=-12.0), lash_l=_lash(curl=-10.0, spread=8.0, lift=-12.0))
        full = pose(r, q)
        for k in ("body_loc", "body_rot", "fk", "offsets", "keys"):
            setattr(p, k, getattr(full, k))
    r.gait("run", speed=6.0, stride=0.8, duty=0.4, phases=tripod, lift=0.09, upper=run_up, stance_y=stance, heel_off=0.0, swing_heel=0.0,
           toe_swing=0.0, yaw=0.0)

    # ---- its evening
    keyed("pick", STAND, [
        (0.0, dict(pitch=14.0, z=-0.07, neck_p=26.0, bloom_p=22.0, open=0.5, lash_r=_lash(curl=26.0, lift=22.0))),
        (0.5, dict(neck_p=34.0, bloom_p=30.0, open=0.15, lash_r=_lash(curl=38.0, lift=30.0)), "whip"),        # a nip at something on the ground
        (0.8, dict(neck_p=20.0, bloom_p=4.0, open=0.0, lash_r=_lash(curl=20.0, lift=10.0))),
        (1.2, dict(neck_p=24.0, bloom_p=18.0, bloom_roll=14.0, open=0.4)),
        (1.6, dict(pitch=14.0, z=-0.07, neck_p=26.0, bloom_p=22.0, bloom_roll=0.0, open=0.5, lash_r=_lash(curl=26.0, lift=22.0)))], loop=True)
    SEAT = dict(STAND, z=-0.24, pitch=-10.0, splay=0.07, neck_p=18.0, bloom_p=24.0, open=0.3)
    keyed("weave", SEAT, [(0.0, {}), (2.0, {})], loop=True,
          more=lambda t, q: q.update(lash_r=_lash(curl=30.0 + 7.0 * wave(t, 0.5), spread=-16.0 + 6.0 * wave(t, 1.0), lift=22.0),
                                     lash_l=_lash(curl=30.0 + 7.0 * wave(t, 0.5, 0.5), spread=-16.0 - 6.0 * wave(t, 1.0), lift=22.0),
                                     bloom_roll=6.0 * wave(t, 2.0), neck_p=18.0 + 2.0 * wave(t, 1.0)))
    keyed("squabble", STAND, [
        (0.0, {}), (0.2, dict(y=-0.04, z=-0.04, pitch=-8.0, lash_r=DRAWN, lash_l=DRAWN, open=1.0, thorns=1.0)),
        (0.36, dict(y=0.12, z=-0.02, pitch=10.0, neck_p=10.0, lash_r=_lash(curl=20.0, spread=-14.0, lift=18.0), lash_l=_lash(curl=20.0, spread=-14.0, lift=18.0)), "whip"),
        (0.55, dict(y=0.08, open=0.2), "snap"), (0.7, dict(open=1.0, bloom_roll=10.0), "snap"), (1.0, dict(STAND))])
    additive("carry", 1.0, lambda t, p: [p.turn(f"lash_{k}_r", pitch=(-30.0, -34.0, 20.0, 46.0)[k] + 2.0 * wave(t, 1.0, 0.1 * k), yaw=(-8.0, 0.0, 0.0, 0.0)[k])
                                          for k in range(4)], loop=True)
    keyed("snatch", STAND, [
        (0.0, {}), (0.14, dict(y=-0.03, lash_r=DRAWN, pitch=-5.0)),
        (0.26, dict(y=0.1, z=-0.05, pitch=10.0, lash_r=_lash(curl=30.0, spread=-10.0, lift=24.0)), "whip"),
        (0.36, dict(lash_r=_lash(curl=44.0, spread=-10.0, lift=6.0)), "snap"),                            # the hook closes on it
        (0.5, dict(STAND, lash_r=_lash(curl=30.0, lift=-30.0)))], contact=0.26)

    # ---- attacks
    keyed("telegraph_briarling_lash", STAND, [
        (0.0, {}), (0.24, dict(y=-0.03, pitch=-7.0, yaw=-8.0, lash_r=DRAWN, thorns=1.0, open=1.0), "out"), (0.4, dict(pitch=-8.0))])
    keyed("attack_briarling_lash", dict(STAND, y=-0.03, pitch=-8.0, yaw=-8.0, lash_r=DRAWN, thorns=1.0), [
        (0.0, {}), (0.1, dict(y=0.08, pitch=9.0, yaw=10.0, z=-0.03, lash_r=STRUCK), "whip"),
        (0.2, dict(lash_r=_lash(curl=40.0, spread=-14.0, lift=30.0))), (0.4, dict(STAND))], contact=0.1)
    LOW = dict(STAND, z=-0.2, pitch=6.0, splay=0.07, neck_p=10.0, open=1.0, thorns=1.0)
    keyed("telegraph_briarling_snare", STAND, [
        (0.0, {}), (0.36, dict(LOW, roots=0.55, root_reach=0.0), "out"), (0.6, dict(roots=0.6))])
    keyed("attack_briarling_snare", dict(LOW, roots=0.6, root_reach=0.0), [
        (0.0, {}), (0.2, dict(roots=1.0, root_reach=1.0, y=0.04), "whip"), (0.4, dict(root_reach=0.9))], contact=0.2)
    keyed("snare_hold", dict(LOW, roots=1.0, root_reach=0.9), [(0.0, {}), (1.0, {})], loop=True,
          more=lambda t, q: q.update(root_reach=0.9 - 0.12 * pulse(t % 0.5, 0.0, 0.12, 0.4), y=-0.02 * pulse(t % 0.5, 0.0, 0.12, 0.4),
                                     open=0.6 + 0.4 * wave(t, 0.5), bloom_roll=5.0 * wave(t, 1.0)))
    keyed("snare_cut", dict(LOW, roots=1.0, root_reach=0.9), [
        (0.0, {}), (0.08, dict(y=-0.1, z=-0.1, pitch=-16.0, root_reach=0.3, open=1.0, lash_r=_lash(curl=-20.0, spread=30.0), lash_l=_lash(curl=-20.0, spread=30.0)), "snap"),
        (0.3, dict(roots=0.2, root_reach=0.0, y=-0.14, neck_p=-10.0)), (0.6, dict(STAND, y=-0.1))])

    # ---- hurt
    for side, s in (("l", 1.0), ("r", -1.0)):
        additive(f"hit_{side}", 0.25, lambda t, p, s=s: (p.body(loc=(0.03 * s * pulse(t, 0.0, 0.06, 0.25), 0.0, -0.02 * pulse(t, 0.0, 0.08, 0.25)),
                                                                roll=-12.0 * s * pulse(t, 0.0, 0.06, 0.25)),
                                                          p.turn("neck", roll=10.0 * s * pulse(t, 0.0, 0.08, 0.25)),
                                                          p.key("thorns_up", pulse(t, 0.0, 0.05, 0.25))))
    keyed("stagger", STAND, [
        (0.0, {}), (0.12, dict(y=-0.1, z=-0.08, pitch=-14.0, roll=8.0, neck_p=-16.0, open=0.2, lash_r=LIMP, lash_l=_lash(curl=-10.0, spread=30.0)), "snap"),
        (0.45, dict(y=-0.14, z=-0.12, roll=-6.0, neck_p=10.0, **feet(r1=(0.05, -0.06, 0.0), l2=(0.0, -0.08, 0.0)))),
        (0.8, dict(STAND, y=-0.14))])
    SLUMP = dict(STAND, z=-0.275, pitch=4.0, splay=0.12, neck_p=38.0, bloom_p=20.0, open=0.0, lash_r=LIMP, lash_l=LIMP)
    keyed("sleep_fall", STAND, [
        (0.0, {}), (0.3, dict(z=-0.06, roll=5.0, neck_p=14.0, open=0.4)), (0.75, dict(SLUMP, z=-0.26, roll=-3.0), "slow"), (1.0, dict(SLUMP))])
    keyed("sleep", SLUMP, [(0.0, {}), (3.0, {})], loop=True, more=lambda t, q: q.update(z=-0.275 + 0.004 * wave(t, 3.0), open=0.04 * (1.0 + wave(t, 3.0))))
    keyed("wake", SLUMP, [
        (0.0, {}), (0.2, dict(neck_p=10.0, open=0.6, thorns=1.0), "snap"), (0.6, dict(STAND, z=0.02, thorns=0.6), "out"), (0.8, dict(STAND))])
    keyed("burn", STAND, [(0.0, {}), (0.8, {})], loop=True,
          more=lambda t, q: q.update(roll=9.0 * wave(t, 0.2), pitch=7.0 * wave(t, 0.27, 0.3), z=-0.05 + 0.03 * wave(t, 0.4), yaw=10.0 * wave(t, 0.8),
                                     neck_p=-14.0 + 16.0 * wave(t, 0.4, 0.2), bloom_roll=20.0 * wave(t, 0.2, 0.4), open=1.0, thorns=1.0,
                                     lash_r=_lash(curl=24.0 * wave(t, 0.4), spread=20.0, lift=-10.0), lash_l=_lash(curl=24.0 * wave(t, 0.4, 0.5), spread=20.0, lift=-10.0)))
    for side, s in (("l", 1.0), ("r", -1.0)):
        keyed(f"death_{side}", STAND, [
            (0.0, {}), (0.12, dict(roll=-14.0 * s, z=0.02, open=1.0, thorns=1.0, lash_r=_lash(curl=-20.0, spread=30.0), lash_l=_lash(curl=-20.0, spread=30.0)), "snap"),
            (0.6, dict(roll=-58.0 * s, x=-0.12 * s, z=-0.2, air=0.6, neck_p=24.0, open=0.4, thorns=0.0, lash_r=LIMP, lash_l=LIMP), "slow"),
            (0.9, dict(roll=-82.0 * s, x=-0.18 * s, ground=1.0, air=1.0, neck_p=40.0, open=0.1), "lin"),
            (1.4, dict(roll=-86.0 * s, neck_p=46.0, open=0.0))])
    FLAT = dict(STAND, z=-0.29, pitch=3.0, splay=0.3, neck_p=58.0, bloom_p=30.0, open=1.0, lash_r=_lash(curl=48.0, spread=50.0, lift=44.0),
                lash_l=_lash(curl=48.0, spread=50.0, lift=44.0), coxa=-18.0)
    keyed("death_heart_knot", STAND, [
        (0.0, {}), (0.08, dict(z=0.05, pitch=-12.0, open=1.0, thorns=1.0, lash_r=_lash(curl=-24.0, spread=40.0), lash_l=_lash(curl=-24.0, spread=40.0)), "snap"),
        (0.2, dict(z=0.06, pitch=-14.0)),                                                             # the pop, held for a breath
        (0.55, dict(FLAT, z=-0.24, thorns=0.0), "whip"), (0.75, dict(FLAT)), (1.2, dict(FLAT, neck_p=62.0))])


# ------------------------------------------------------------------ build

# The sheets (leaves, petals, thorns, the throat) do not get islands of their
# own in the atlas: every leaflet shares one painted leaf, every petal one petal,
# in a strip down the right of it, and the hide shader multiplies that detail by
# the colour in the vertices. So a leaf has as much texture as the whole cage,
# and its colour is the same one the court's foliage material shows in bush form.
STRIP = 0.755                                   # u from here on is the strip (the shader knows this number)
NEUTRAL = 0.6                                   # the detail value that leaves the vertex colour as it is
SWATCH = dict(leaf=(0.0, 0.5), petal=(0.5, 0.75), thorn=(0.75, 0.875), throat=(0.875, 1.0))
SWATCH_OF = {20: "thorn", 21: "thorn", 22: "thorn", 61: "thorn", 30: "leaf", 31: "leaf", 32: "leaf", 33: "leaf", 40: "petal", 60: "throat",
             **{50 + i: "petal" for i in range(6)}}


def lay_out(low):
    """UVs: the cage and the canes unwrapped into the left of the atlas, every
    sheet onto its swatch by the "grad" its vertices carry."""
    me = low.data
    part = kit.parts_of(low)
    n = len(me.polygons)
    first = np.zeros(n, dtype=np.int32)
    me.polygons.foreach_get("loop_start", first)
    lv = np.zeros(len(me.loops), dtype=np.int32)
    me.loops.foreach_get("vertex_index", lv)
    sheet_poly = np.isin(part[lv[first]], list(SWATCH_OF))
    me.polygons.foreach_set("hide", sheet_poly)
    me.update()
    kit._smart_project(low, 0.004)
    me.polygons.foreach_set("hide", np.zeros(n, dtype=bool))
    me.update()
    uv = np.zeros(len(me.loops) * 2, dtype=np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    g = np.zeros(len(me.vertices) * 4, dtype=np.float32)
    me.color_attributes["grad"].data.foreach_get("color", g)
    g = g.reshape(-1, 4)[lv]
    lp = part[lv]
    sheet = np.isin(lp, list(SWATCH_OF))
    uv[~sheet, 0] *= STRIP - 0.01
    for num, name in SWATCH_OF.items():
        m = lp == num
        v0, v1 = SWATCH[name]
        uv[m, 0] = STRIP + 0.012 + np.clip(g[m, 1], 0.0, 1.0) * (1.0 - STRIP - 0.024)
        uv[m, 1] = v0 + 0.01 + np.clip(g[m, 0], 0.0, 1.0) * (v1 - v0 - 0.02)
    me.uv_layers.active.data.foreach_set("uv", uv.ravel())
    me.update()


def _enc(x):
    """Linear to the sRGB values an albedo image stores."""
    x = np.clip(x, 0.0, 1.0)
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * x ** (1.0 / 2.4) - 0.055)


def _noise(shape, cells, seed):
    """Smooth value noise, 0..1."""
    r = np.random.default_rng(seed).random((cells[0] + 2, cells[1] + 2))
    y = np.linspace(0, cells[0], shape[0], endpoint=False)
    x = np.linspace(0, cells[1], shape[1], endpoint=False)
    yi, xi = y.astype(int), x.astype(int)
    fy, fx = (y - yi)[:, None], (x - xi)[None, :]
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a, b = r[yi][:, xi], r[yi][:, xi + 1]
    c, d = r[yi + 1][:, xi], r[yi + 1][:, xi + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def paint_swatches(maps, size):
    """Paints the strip into the baked maps (kit.bake calls this before it saves)."""
    x0 = int(STRIP * size)
    arr = {}
    for k, img in maps.items():
        a = np.empty(size * size * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        arr[k] = a.reshape(size, size, 4)

    def put(name, lum, colour, height, rough, bump):
        v0, v1 = SWATCH[name]
        y0, y1 = int(v0 * size), int(v1 * size)
        rgb = lum[:, :, None] * np.asarray(colour)[None, None, :] if np.ndim(colour) == 1 else lum[:, :, None] * colour
        arr["albedo"][y0:y1, x0:, :3] = _enc(NEUTRAL * rgb)
        gy, gx = np.gradient(height)
        nrm = np.stack([-gx * bump, -gy * bump, np.ones_like(gx)], axis=2)
        nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
        arr["normal"][y0:y1, x0:, :3] = nrm * 0.5 + 0.5
        arr["rough"][y0:y1, x0:, :3] = np.broadcast_to(np.asarray(rough, dtype=np.float32), lum.shape)[:, :, None]
        arr["ao"][y0:y1, x0:, :3] = 1.0
        if "emit" in arr:
            arr["emit"][y0:y1, x0:, :3] = 0.0

    def grid(name):
        v0, v1 = SWATCH[name]
        h, w = int(v1 * size) - int(v0 * size), size - x0
        t = np.linspace(0, 1, h)[:, None] * np.ones((1, w))          # along the piece
        a = np.ones((h, 1)) * np.linspace(0, 1, w)[None, :]          # from its midrib out to its edge
        return t, a

    # the leaf: a pale midrib, side veins sweeping to the edge, the blade quilted between them
    t, a = grid("leaf")
    rib = np.exp(-(a / 0.035) ** 2)
    ph = (t * 8.5 - a * 2.6) % 1.0
    vein = np.exp(-((ph - 0.5) / 0.06) ** 2) * (1.0 - a) ** 0.6 * kit.ss((t - 0.04) / 0.1)
    quilt = np.sin(np.pi * ph) ** 0.6
    mott = _noise(t.shape, (24, 10), 3)
    lum = (0.9 + 0.15 * quilt * (1.0 - 0.5 * a)) * (0.93 + 0.14 * mott) * (1.0 - 0.12 * kit.ss((a - 0.7) / 0.3))
    line = np.clip(rib + 0.55 * vein, 0.0, 1.0)
    colour = (1.0 - line)[:, :, None] * np.ones(3)[None, None, :] + line[:, :, None] * np.array((1.4, 1.3, 0.9))[None, None, :]
    put("leaf", lum, colour, 0.8 * quilt - 1.6 * rib - 0.8 * vein + 0.25 * mott, 0.52 - 0.14 * line, size * 0.0035)

    # a petal: deep at its base, fine streaks running out to a paler rim
    t, a = grid("petal")
    streak = _noise(t.shape, (5, 70), 5)
    lum = (0.72 + 0.4 * kit.ss(t / 0.75)) * (0.93 + 0.12 * streak) * (1.0 + 0.08 * kit.ss((t - 0.85) / 0.15))
    put("petal", lum, (1.0, 1.0, 1.0), streak * 0.6 + 0.3 * np.cos(a * np.pi), 0.58, size * 0.003)

    # a thorn: dull at the base, polished to its point
    t, a = grid("thorn")
    put("thorn", 0.9 + 0.2 * t, (1.0, 1.0, 1.0), np.zeros_like(t), 0.5 - 0.3 * t, 0.0)
    t, a = grid("throat")
    put("throat", np.ones_like(t), (1.0, 1.0, 1.0), np.zeros_like(t), 0.16 + 0.0 * t, 0.0)

    for k, img in maps.items():
        img.pixels.foreach_set(arr[k].ravel())
        img.update()


def build(fast=False, bake=True):
    kit.reset()
    core, canes, knot = cage_forms()
    cane_f, knot_f = kit.field(canes), kit.field(knot)
    s = kit.union(core + canes + knot, NAME + "_sculpt", voxel=0.0045 if fast else 0.003, project=5)
    kit.drop_hollows(s)
    kit.shade_smooth(s)
    kit.paint(s, "zone", lambda P, N: np.stack([kit.ss(1.0 - cane_f(P) / 0.004) * (1.0 - kit.ss(1.0 - knot_f(P) / 0.003)), kit.ss(1.0 - knot_f(P) / 0.003),
                                                np.zeros(len(P))], axis=1))
    kit.set_material(s, cage_material())
    hard = hard_parts()
    low = kit.game_mesh(s, NAME, CAGE_TRIS, keep=lambda P: kit.ss(1.0 - knot_f(P) / 0.02), keep_bias=0.5)
    kit.tag(low, 0)
    Q = kit.co(low)
    knot_w = kit.ss(1.0 - knot_f(Q) / 0.004)[:, None]
    tint = np.array(CANE_GREEN)[None, :] * (1.0 - knot_w) + np.array((0.07, 0.018, 0.015))[None, :] * knot_w
    attr = low.data.color_attributes.new("tint", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.concatenate([tint, np.zeros((len(Q), 1))], axis=1).astype(np.float32).ravel())
    arm = rig.build_armature(NAME, bones())
    rig.bind_near(low, arm, ["cage", "neck", "neck_1", "bloom"], sigma=0.02)
    pieces = []
    for o, part, bone in hard:
        g = kit.duplicate(o, o.name + "_g")
        if isinstance(bone, list):
            rig.bind_chain(g, arm, bone)
        else:
            rig.bind_rigid(g, bone)
        pieces.append(g)
    low = kit.join([low] + pieces, NAME)
    kit.triangulate(low)
    if bake:
        lay_out(low)
    rig.attach(low, arm)
    sources = [s] + [o for o, _, _ in hard]
    paths = {}
    if bake:                                    # only the cage and the canes are baked; the sheets take their swatches
        baked = [s] + [o for o, part, _ in hard if part not in SWATCH_OF]
        _, paths = kit.bake(baked, low, NAME, OUT, size=1024 if fast else 2048, extrusion=0.004, paint=paint_swatches)
    else:
        kit.set_material(low, kit.plain("clay", (0.2, 0.22, 0.22), 0.5))
    shape_keys(low)
    r = rig.Rig(arm, low, spec())
    author(r)
    r.finish()
    return sources, low, arm, r, paths


if __name__ == "__main__":
    args = sys.argv[1:]
    hide, low, arm, r, paths = build("--fast" in args, bake="--nobake" not in args)
    for name, rep in r.report.items():
        print(f"clip {name}: " + " ".join(f"{k}={v:.4f}" for k, v in rep.items()))
    print(f"{NAME}: {kit.tris(low)} tris, {len(arm.data.bones)} bones")
    if "--debug" in args:
        M, _ = r.solve(pose(r, dict(BUSH)))
        for b in ("cage", "bloom", "coxa_r0", "femur_r0", "tibia_r0", "tip_r0", "femur_r1", "tibia_r1", "tip_r1", "tibia_r2", "tip_r2", "lash_1_r", "lash_3_r"):
            print("bush", b, [round(v, 3) for v in M[b].to_translation()])
    if "--preview" in args:
        import preview
        d = args[args.index("--preview") + 1]
        want = [a for a in args[args.index("--preview") + 2:] if not a.startswith("--")]
        cams = dict(q=((1.5, 1.9, 1.0), (0, 0.05, 0.4), 50), side=((2.6, 0.1, 0.5), (0, 0.1, 0.42), 60), top=((0.0, -0.05, 3.2), (0, 0.05, 0.2), 50),
                    face=((0.35, 0.95, 0.9), (0, 0.27, 0.66), 70), front=((0.0, 2.6, 0.6), (0, 0, 0.4), 60))
        for v in want:
            if v in cams:
                preview.shot(os.path.join(d, f"{NAME}_low_{v}.png"), cams[v], hide=hide, samples=24, res=(900, 700))
            else:
                clip, cam, at = (v.split("@") + ["q", ""])[:3]
                ts = [float(x) for x in at.split(",")] if at else [0.0, 0.33, 0.66, 1.0]
                preview.strip(arm, low, clip, os.path.join(d, f"{NAME}_clip_{clip}_{cam}.png"), extra=hide, view=cams[cam or "q"], at=ts, frames=len(ts),
                              res=(1100, 880) if len(ts) == 1 else (700, 560))
    if "--noexport" not in args:
        for o in hide:
            bpy.data.objects.remove(o, do_unlink=True)
        low.data.color_attributes.remove(low.data.color_attributes["grad"])
        path = kit.export_gltf(NAME, [low, arm], OUT, vertex_color="tint")
        rig.write_gaits(NAME, r, f"creatures/models/fae/{NAME}.gltf")
        print(f"{NAME}: {kit.tris(low)} tris -> {path}")
