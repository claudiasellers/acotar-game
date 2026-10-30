"""Everyday wardrobe for Feyre: tops, trousers, shoes, outerwear, masks and small jewellery.

Reproducible build (needs characters/feyre/model/feyre.blend from build_feyre.py):
    /opt/bpyenv/bin/python tools/blender/feyre/build_wardrobe.py [name ...]

Writes characters/feyre/wardrobe/<name>.glb for every entry of PIECES (all of them when no names are
given) and wardrobe.blend (only on a full build).  The meshes are shared by the colour variants of the
wardrobe data: the game tints the surface `fabric` (always slot 0) with the variant colour, and every
other surface keeps its palette colour.

Three ways of building, all skinned to the 60-bone armature of feyre.blend:
  * shells   copied from the body faces of chosen regions, cut with planes, pushed out along the
             normals, edges smoothed and piped (`bind`).  Weights come from the body.
  * lathes   skirts, peplums, capelets and cloaks from build_gowns' kit (skirts blend Hips -> UpperLeg,
             capes use distance weights on the shoulder chain).
  * trinkets jewellery, ribbons, clips and masks; head pieces ride the Head bone only.
Body garments carry a `nourished` shape key like the gowns.  Everything is seeded.
"""

import math
import os
import sys
from typing import Callable, List, Optional, Sequence, Tuple

import bpy  # noqa: E402  (must come before bmesh when used as a module)
import bmesh
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_feyre as bf  # noqa: E402
import build_gowns as bg  # noqa: E402
import feyre_shape as fs  # noqa: E402
from build_feyre import MODEL_DIR, REGIONS, WARDROBE_DIR, apply_weights, distance_weights, smoothstep  # noqa: E402
from build_gowns import (ANG, COLS, BodyProbe, Builder, ring_out, ring_pt, ring_tan, RING_UP,  # noqa: E402
                         smooth_curve)

SEED = 11
TRI_CLOTH = 5000                # same ceiling as the gowns
TRI_ACC = 3000                  # R4 prop budget
Arr = np.ndarray
V = Vector

# Palette (experience-bar 2.2); the fabric entry is only the untinted default.
PEARL, BLUSH, ROSE, LILAC, PERI = "FBF7F2", "FAD4DC", "F4A6C0", "C8A8E9", "A7B5F2"
BUTTER, MINT, GOLD, GOLD_LIT, SAGE = "FCE9A6", "B5E3C0", "D4A94F", "F2D27A", "9CCFAA"
LEATHER, LEATHER_D, CREAM = "B08A84", "8E6A6E", "F6EBDD"
PAL = {
    "leather": (LEATHER, 0.55, 0.0), "leather_d": (LEATHER_D, 0.50, 0.0), "cord": (CREAM, 0.7, 0.0),
    "lace": (PEARL, 0.45, 0.0), "lining": (BLUSH, 0.40, 0.0), "sole": ("7E6266", 0.7, 0.0),
    "paint_a": (PERI, 0.6, 0.0), "paint_b": (ROSE, 0.6, 0.0), "paint_c": (BUTTER, 0.6, 0.0),
    "leaves": (SAGE, 0.5, 0.0), "chain": (GOLD, 0.30, 0.6), "silk": (BLUSH, 0.35, 0.0),
}
METAL = (GOLD_LIT, 0.28, 0.65)
CLOAK_BONES = ["Neck", "UpperChest", "LeftShoulder", "RightShoulder", "Chest", "Spine", "Hips",
               "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"]
CAPE_BONES = ["Neck", "UpperChest", "LeftShoulder", "RightShoulder", "Chest", "LeftUpperArm", "RightUpperArm"]


# --------------------------------------------------------------------------
# Geometry helpers
# --------------------------------------------------------------------------
def boundary_loops(bm: bmesh.types.BMesh) -> List[list]:
    """Ordered vertex loops along the open edges."""
    nb = {}
    for e in bm.edges:
        if e.is_boundary:
            a, b = e.verts
            nb.setdefault(a, []).append(b)
            nb.setdefault(b, []).append(a)
    seen, loops = set(), []
    for start in nb:
        if start in seen:
            continue
        loop, prev, cur = [start], None, start
        seen.add(start)
        while True:
            nxt = [v for v in nb[cur] if v is not prev and v not in seen]
            if not nxt:
                break
            prev, cur = cur, nxt[0]
            seen.add(cur)
            loop.append(cur)
        if len(loop) > 4:
            loops.append(loop)
    return loops


def drop_islands(bm: bmesh.types.BMesh, min_faces: int = 40) -> None:
    left = set(bm.faces)
    kill = []
    while left:
        seed = left.pop()
        comp, stack = [seed], [seed]
        while stack:
            f = stack.pop()
            for e in f.edges:
                for g in e.link_faces:
                    if g in left:
                        left.discard(g)
                        comp.append(g)
                        stack.append(g)
        if len(comp) < min_faces:
            kill += comp
    if kill:
        bmesh.ops.delete(bm, geom=kill, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")


def smooth_boundary(bm: bmesh.types.BMesh, iters: int = 6) -> None:
    """Straighten the stair-stepped edges left by the per-face region filter."""
    for loop in boundary_loops(bm):
        P = np.array([v.co[:] for v in loop])
        closed = (loop[0].co - loop[-1].co).length < 0.03
        for _ in range(iters):
            Q = P.copy()
            if closed:
                Q = 0.5 * P + 0.25 * (np.roll(P, 1, 0) + np.roll(P, -1, 0))
            else:
                Q[1:-1] = 0.5 * P[1:-1] + 0.25 * (P[:-2] + P[2:])
            P = Q
        for v, p in zip(loop, P):
            v.co = p


def loop_paths(bm: bmesh.types.BMesh, step: float = 0.013) -> List[Arr]:
    out = []
    for loop in boundary_loops(bm):
        P = np.array([v.co[:] for v in loop])
        if np.linalg.norm(P[0] - P[-1]) < 0.03:
            P = np.vstack([P, P[:1]])
        n = max(8, int(np.sum(np.linalg.norm(np.diff(P, axis=0), axis=1)) / step))
        idx = np.linspace(0, len(P) - 1, n)
        out.append(np.array([P[int(i)] + (P[min(int(i) + 1, len(P) - 1)] - P[int(i)]) * (i - int(i)) for i in idx]))
    return out


class Shell:
    """Body faces of chosen regions, cut by planes and offset: the base of every fitted garment."""

    def __init__(self, probe: BodyProbe):
        self.src = bmesh.new()
        self.src.from_mesh(probe.body.data)
        for layer in list(self.src.verts.layers.shape):
            self.src.verts.layers.shape.remove(layer)
        self.probe = probe

    def make(self, keep: Callable[[str, Vector], bool], off: Callable[[Vector], float],
             cuts: Sequence[Tuple[tuple, tuple]] = (), max_tris: Optional[int] = None) -> bmesh.types.BMesh:
        bm = self.src.copy()
        bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if not keep(REGIONS[f.material_index], f.calc_center_median())]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        for co, no in cuts:                  # removes the side the normal points to
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-5,
                                   plane_co=co, plane_no=no, clear_outer=True)
        drop_islands(bm)
        bm.normal_update()
        for v in bm.verts:
            v.co = v.co + v.normal * off(v.co)
        smooth_boundary(bm)
        if max_tris and sum(len(f.verts) - 2 for f in bm.faces) > max_tris:
            me = bpy.data.meshes.new("_tmp")
            bm.to_mesh(me)
            bm.free()
            ob = bpy.data.objects.new("_tmp", me)
            bpy.context.scene.collection.objects.link(ob)
            bf.decimate_to(ob, max_tris)
            bm = bmesh.new()
            me = ob.data
            bm.from_mesh(me)
            bpy.data.objects.remove(ob)
            bpy.data.meshes.remove(me)
        return bm


def add_bm(B: Builder, bm: bmesh.types.BMesh, mat: str, kind: str, **prm) -> None:
    i0 = len(B.bm.verts)
    idx = B.slot(mat)
    vmap = {v: B.bm.verts.new(v.co) for v in bm.verts}
    for f in bm.faces:
        nf = B.bm.faces.new([vmap[v] for v in f.verts])
        nf.material_index = idx
    B.mark(kind, i0, **prm)


def bind(B: Builder, bm: bmesh.types.BMesh, r: float, mat: str, kind: str = "shell", squash: float = 1.0,
         where: Callable[[Arr], bool] = lambda p: True, **prm) -> None:
    """Pipe the open edges of a shell (hems, cuffs, necklines)."""
    for path in loop_paths(bm):
        if not where(path.mean(axis=0)):
            continue
        i0 = len(B.bm.verts)
        B.tube(path, r, 4, mat, squash=squash, cap=False)
        B.mark(kind, i0, **prm)


def girth(probe: BodyProbe, z: float) -> Tuple[float, float, float]:
    cy = probe.cy(z)
    rx = max(abs(probe.torso_pt(z, a).x) for a in (math.pi / 2, -math.pi / 2))
    ry = max(cy - probe.torso_pt(z, 0.0).y, probe.torso_pt(z, math.pi).y - cy)
    return rx, ry, cy


def limb_ring(probe: BodyProbe, c, axis, off: float, n: int = 16, phase: float = 0.0) -> Arr:
    """Points on the limb surface around `c` (rays perpendicular to `axis`), lifted by `off`."""
    c, ax = V(c), V(axis).normalized()
    e1 = ax.cross(V((0, 0, 1)) if abs(ax.z) < 0.9 else V((1, 0, 0))).normalized()
    e2 = ax.cross(e1).normalized()
    pts = []
    for k in range(n):
        t = phase + 2 * math.pi * k / n
        d = e1 * math.cos(t) + e2 * math.sin(t)
        hit = probe.bvh.ray_cast(c, d, 0.2)[0]
        pts.append((hit if hit is not None else c + d * 0.03) + d * off)
    pts.append(pts[0])
    return np.array(pts)


def neck_ring(probe: BodyProbe, zfn: Callable[[float], float], off: float, n: int = 48) -> Arr:
    """A loop round the neck/collarbones; zfn(angle) gives its height (angle 0 = front)."""
    pts = []
    for k in range(n + 1):
        a = 2 * math.pi * k / n
        z = zfn(a)
        o = V((0, 0.010, z))
        d = V((math.sin(a), -math.cos(a), 0))
        hit = probe.bvh.ray_cast(o, d, 0.3)[0]
        pts.append((hit if hit is not None else o + d * 0.05) + d * off)
    return np.array(pts)


def on_face(probe: BodyProbe, x: float, z: float, lift: float) -> Tuple[Vector, Vector]:
    loc, nrm, _, _ = probe.bvh.ray_cast(V((x, -0.3, z)), V((0, 1, 0)), 0.5)
    if loc is None or loc.y > 0.0:          # past the silhouette: nearest point on the side of the head
        loc, nrm, _, _ = probe.bvh.find_nearest(V((x, -0.02, z)))
    return loc + nrm * lift, nrm


def ear_lobe(probe: BodyProbe, s: int) -> Vector:
    loc = probe.bvh.ray_cast(V((0.093 * s, 0.013, 1.492)), V((0, 0, -1)), 0.04)[0]
    return loc if loc is not None else V((0.092 * s, 0.013, 1.476))


def wrist(s: int, x: float = 0.605) -> Vector:
    return V((s * x, float(fs.WRIST[1]), float(fs.WRIST[2])))


def zig(a: float) -> float:
    """|angle| in degrees, 0 = front, 180 = back."""
    return abs(math.degrees((a + math.pi) % (2 * math.pi) - math.pi))


# --------------------------------------------------------------------------
# Trinket shapes
# --------------------------------------------------------------------------
def butterfly(B: Builder, c, n, up, size: float, wing: str = "fabric", body: str = "chain") -> None:
    n, up = V(n).normalized(), V(up).normalized()
    side = up.cross(n).normalized()
    up = n.cross(side).normalized()
    for s in (1, -1):
        a = (side * s * 0.8 + up * 0.6).normalized()
        b = n.cross(a).normalized()
        B.ellipsoid(V(c) + a * size * 0.55, a * size * 0.58, b * size * 0.40, n * size * 0.05, wing, 6, 3)
        a = (side * s * 0.7 - up * 0.7).normalized()
        b = n.cross(a).normalized()
        B.ellipsoid(V(c) + a * size * 0.36, a * size * 0.38, b * size * 0.26, n * size * 0.05, wing, 5, 3)
    B.ellipsoid(V(c) + n * size * 0.05, side * size * 0.07, n * size * 0.07, up * size * 0.42, body, 5, 3)


def teardrop(B: Builder, top, down, size: float, mat: str) -> None:
    down = V(down).normalized()
    s1 = down.cross(V((1, 0, 0)) if abs(down.x) < 0.9 else V((0, 1, 0))).normalized()
    s2 = down.cross(s1)
    B.ellipsoid(V(top) + down * size * 0.95, s1 * size * 0.55, s2 * size * 0.55, down * size * 0.75, mat, 6, 4)
    B.ellipsoid(V(top) + down * size * 0.35, s1 * size * 0.26, s2 * size * 0.26, down * size * 0.45, mat, 5, 3)


def torus(B: Builder, c, axis, R: float, r: float, mat: str, n: int = 24, sec: int = 5) -> None:
    ax = V(axis).normalized()
    e1 = ax.cross(V((0, 0, 1)) if abs(ax.z) < 0.9 else V((1, 0, 0))).normalized()
    e2 = ax.cross(e1)
    path = np.array([V(c) + (e1 * math.cos(t) + e2 * math.sin(t)) * R for t in np.linspace(0, 2 * math.pi, n + 1)])
    B.tube(path, r, sec, mat, up=ax, cap=False)


def heart(B: Builder, c, n, size: float, mat: str) -> None:
    n = V(n).normalized()
    side = n.cross(V((0, 0, 1))).normalized()
    up = side.cross(n).normalized() * -1 if side.cross(n).z < 0 else side.cross(n).normalized()
    for s in (1, -1):
        B.ellipsoid(V(c) + side * s * size * 0.32 + up * size * 0.18, side * size * 0.40, n * size * 0.18,
                    up * size * 0.40, mat, 5, 3)
    B.ellipsoid(V(c) - up * size * 0.22, side * size * 0.42, n * size * 0.17, up * size * 0.45, mat, 5, 3)


# --------------------------------------------------------------------------
# Finishing
# --------------------------------------------------------------------------
FIT = {"shell": 0.005, "skirt": bg.CLEAR, "sleeve": bg.CLEAR, "near": 0.001}


def finalize(B: Builder, name: str, probe: BodyProbe, arm, spec) -> bpy.types.Object:
    obj = bg.new_object(B, name)
    me = obj.data
    P = bf.verts_np(me)
    fits = []
    for kind, i0, i1, prm in B.parts:
        t = prm.get("fit", FIT.get(kind))
        if t:
            fits.append((range(i0, i1), t))
            P = probe.fit(P, range(i0, i1), t)
    me.vertices.foreach_set("co", P.ravel())
    me.update()
    w, nn = bg.compute_weights(B, P, probe, spec)
    for kind, i0, i1, prm in B.parts:
        if kind == "cape":
            w[i0:i1] = distance_weights(P[i0:i1], spec, prm.get("bones", CAPE_BONES), k=3, power=3.0)
    apply_weights(obj, w)
    bf.skin_to_armature(obj, arm)
    obj.shape_key_add(name="Basis", from_mix=False)
    sk = obj.shape_key_add(name="nourished", from_mix=False)
    d = np.zeros_like(P)
    for i, lst in enumerate(nn):
        dist = probe.kd.find(V(P[i]))[2]
        fall = float(np.clip(1.0 - max(0.0, dist - 0.02) / 0.10, 0.0, 1.0))
        d[i] = sum(probe.delta[j] * f for j, f in lst) * fall
    Pn = P + d
    for idx, t in fits:
        Pn = probe.fit(Pn, idx, t + 0.002, nourished=True)
    sk.data.foreach_set("co", Pn.ravel())
    sk.value = 0.0
    bf.ensure_uvs(obj)
    return obj


def finalize_head(B: Builder, name: str, probe: BodyProbe, arm, spec) -> bpy.types.Object:
    return bg.finalize_head(B, name, arm)


# --------------------------------------------------------------------------
# Tops and bottoms
# --------------------------------------------------------------------------
def z_below(z):            # cut: remove everything below z
    return ((0, 0, z), (0, 0, -1))


def z_above(z):
    return ((0, 0, z), (0, 0, 1))


def x_beyond(x):           # cut both arms at |x| = x (two planes)
    return [((x, 0, 0), (1, 0, 0)), ((-x, 0, 0), (-1, 0, 0))]


def neckline(depth_front: float, width: float, z_back: float = 1.325) -> Callable[[Vector], bool]:
    """True when a point is inside the neck hole: a U at the front `depth_front` below z_back."""
    def hole(c: Vector) -> bool:
        if c.z > z_back + 0.008:
            return True
        front = smoothstep(0.0, -0.06, c.y)
        u = min(1.0, abs(c.x) / width)
        return c.z > z_back - front * depth_front * (1.0 - u * u)
    return hole


def peplum(B: Builder, probe: BodyProbe, z0: float, z1: float, flare: float, mats, nrows: int = 6,
           hem=None, lmax: float = 0.6, fold=(0.04, 7, 0.0), gap: float = 0.010) -> List[Arr]:
    rx, ry, cy = girth(probe, z0)
    ctrl = []
    for k in range(4):
        s = k / 3
        z = z0 + (z1 - z0) * s
        if z > 0.86:
            gx, gy, gc = girth(probe, z)
            rx, ry, cy = max(rx, gx), max(ry, gy), gc
        ctrl.append((z, rx + gap + flare * s ** 1.3, ry + gap + flare * 0.8 * s ** 1.3, cy))
    return bg.skirt(B, ctrl, nrows, mats, fold=fold, hem=hem, lmax=lmax)


def belt(B: Builder, probe: BodyProbe, z: float, width: float, mat: str, off: float = 0.012,
         buckle: Optional[str] = "chain") -> None:
    i0 = len(B.bm.verts)
    path = np.array([probe.torso_pt(z, a, off) for a in np.append(ANG, ANG[0])])
    B.tube(path, 0.0025, 6, mat, up=V((0, 0, 1)), squash=width / 2 / 0.0025, cap=False)
    if buckle:
        p, n = probe.on_torso(z, 0.0, off + 0.003)
        B.ellipsoid(p, V((0.012, 0, 0)), n * 0.003, V((0, 0, width * 0.6)), buckle, 6, 3)
    B.mark("shell", i0, fit=off - 0.003)


def buttons(B: Builder, probe: BodyProbe, zs, lift: float, r: float = 0.0042, mat: str = "chain", deg=0.0) -> None:
    i0 = len(B.bm.verts)
    for z in zs:
        p, n = probe.on_torso(z, deg, lift)
        B.ellipsoid(p, V((r, 0, 0)), n * r * 0.5, V((0, 0, r)), mat, 6, 3)
    B.mark("near", i0, fit=lift - 0.002)


def build_spring_tunic(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    hole = neckline(0.11, 0.075)
    bm = sh.make(lambda r, c: r in ("torso", "arms") and not hole(c),
                 lambda c: 0.006, [z_below(0.90)] + x_beyond(0.30))
    add_bm(B, bm, "fabric", "shell", fit=0.006)
    bind(B, bm, 0.0028, "silk", where=lambda p: p[2] > 1.1 and abs(p[0]) < 0.2)
    bm.free()
    for s in (1, -1):                                    # flutter sleeves over the short sleeve
        ra = probe.arm_radius(0.26)
        xs = [0.19, 0.23, 0.27, 0.31, 0.335]
        rs = [(ra[0] + 0.012, ra[1] + 0.012), (ra[0] + 0.016, ra[1] + 0.016), (ra[0] + 0.022, ra[1] + 0.024),
              (ra[0] + 0.030, ra[1] + 0.032), (ra[0] + 0.034, ra[1] + 0.036)]
        bg.sleeve(B, s, xs, rs, ["fabric"], 16, hem=(0.010, 5))
    peplum(B, probe, 0.94, 0.70, 0.07, ["fabric"] * 5 + ["silk"], 7, hem=("sin", 0.018, 5, 0.6), lmax=0.7)
    belt(B, probe, 0.975, 0.020, "silk", buckle=None)
    i0 = len(B.bm.verts)
    p, n = probe.on_torso(0.975, -40, 0.020)
    B.bow(p, n, 0.045, "silk")
    B.mark("near", i0, fit=0.012)


def build_spring_trousers(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    bm = sh.make(lambda r, c: r == "legs" or (r == "torso" and c.z < 1.0),
                 lambda c: 0.006 + 0.020 * float(smoothstep(0.62, 0.14, c.z)), [z_above(0.99), z_below(0.11)],
                 max_tris=3600)
    add_bm(B, bm, "fabric", "shell", fit=0.006)
    bind(B, bm, 0.0035, "silk", squash=1.6)
    bm.free()


def build_painter_smock(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    hole = neckline(0.06, 0.07)
    bm = sh.make(lambda r, c: r in ("torso", "arms") and not hole(c),
                 lambda c: 0.012 + 0.006 * (abs(c.x) > 0.2), [z_below(0.90)] + x_beyond(0.50))
    add_bm(B, bm, "fabric", "shell", fit=0.012)
    bind(B, bm, 0.0065, "fabric", where=lambda p: abs(p[0]) > 0.4, fit=0.012)          # rolled cuffs
    bind(B, bm, 0.0030, "cord", where=lambda p: p[2] > 1.1 and abs(p[0]) < 0.2, fit=0.012)
    bm.free()
    rings = peplum(B, probe, 0.96, 0.66, 0.06, ["fabric"] * 6, 7, fold=(0.05, 6, 0.3), lmax=0.65, gap=0.016)
    i0 = len(B.bm.verts)                                # patch pocket on the skirt, her right
    r = rings[3]
    c = V(r[int(round(-28 / 360 * COLS)) % COLS])
    out = V((c.x, c.y - 0.01, 0)).normalized()
    side = out.cross(V((0, 0, 1))).normalized()
    B.ellipsoid(c + out * 0.004, side * 0.042, out * 0.004, V((0, 0, 0.036)), "cord", 6, 3)
    for k, (deg, z) in enumerate(((20, 1.08), (-15, 1.15), (35, 0.99), (-5, 0.93), (10, 1.22))):   # paint
        p, n = probe.on_torso(z, deg, 0.0175)
        t = n.cross(V((0, 0, 1))).normalized()
        a = rng.uniform(0, math.pi)
        e1 = t * math.cos(a) + V((0, 0, 1)) * math.sin(a)
        B.ellipsoid(p, e1 * rng.uniform(0.010, 0.018), n * 0.0015, n.cross(e1) * rng.uniform(0.006, 0.011),
                    ("paint_a", "paint_b", "paint_c")[k % 3], 6, 3)
    B.mark("near", i0, fit=0.016)
    i0 = len(B.bm.verts)
    for s in (1, -1):
        c = V((s * 0.47, 0.008, 1.285 + 0.06))
        B.ellipsoid(c, V((0.012, 0, 0)), V((0, 0.010, 0)), V((0, 0, 0.0015)), "paint_a" if s > 0 else "paint_c", 6, 3)
    B.mark("near", i0, fit=0.018)


def leathers(B: Builder, probe: BodyProbe, sh: Shell, z_hem: float, collar_hole) -> bmesh.types.BMesh:
    bm = sh.make(lambda r, c: r in ("torso", "arms", "legs") and not collar_hole(c),
                 lambda c: 0.0065, [z_below(z_hem)] + x_beyond(0.60), max_tris=2600)
    add_bm(B, bm, "fabric", "shell", fit=0.0065)
    return bm


def build_riding_leathers(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    bm = leathers(B, probe, sh, 0.30, neckline(0.02, 0.06, 1.335))
    bind(B, bm, 0.0035, "leather_d", fit=0.0065)
    bm.free()
    peplum(B, probe, 0.99, 0.80, 0.045, ["fabric"] * 3 + ["leather_d"], 5, fold=(0.02, 4, 0.0), lmax=0.55, gap=0.014)
    belt(B, probe, 0.985, 0.026, "leather_d", off=0.016)
    buttons(B, probe, np.linspace(1.03, 1.27, 6), 0.010)


def build_woods_leathers(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    hole = neckline(0.07, 0.06)
    bm = leathers(B, probe, sh, 0.24, hole)
    bind(B, bm, 0.0030, "leather_d", fit=0.0065)
    bm.free()
    i0 = len(B.bm.verts)                                # laced front
    pts = []
    for k, z in enumerate(np.linspace(1.04, 1.22, 9)):
        p, _ = probe.on_torso(z, 6.0 if k % 2 else -6.0, 0.009)
        pts.append(p)
    B.tube(smooth_curve(np.array(pts), 40), 0.0016, 4, "cord", cap=False)
    for z in np.linspace(1.04, 1.22, 5):
        for deg in (-6.0, 6.0):
            p, n = probe.on_torso(z, deg, 0.008)
            B.bead(p, 0.0022, "chain", 4, 2)
    B.mark("near", i0, fit=0.007)
    belt(B, probe, 0.975, 0.022, "leather_d", off=0.014)
    i0 = len(B.bm.verts)                                # pouch on her right hip
    p, n = probe.on_torso(0.95, -70, 0.03)
    t = n.cross(V((0, 0, 1))).normalized()
    B.ellipsoid(p, t * 0.032, n * 0.016, V((0, 0, 0.036)), "leather_d", 8, 5)
    B.ellipsoid(p + V((0, 0, 0.022)) + n * 0.006, t * 0.033, n * 0.010, V((0, 0, 0.016)), "leather", 6, 3)
    B.mark("shell", i0, fit=0.014)
    i0 = len(B.bm.verts)                                # leaf-cut shoulder mantle
    rings = []
    prof = [(1.345, 0.068, 0.064), (1.31, 0.13, 0.095), (1.275, 0.205, 0.120), (1.235, 0.225, 0.135)]
    for k, (z, rx, ry) in enumerate(prof):
        dz = bg.hem_off(("scallop", 0.030, 12, 0.0), ANG) if k == len(prof) - 1 else 0.0 * ANG
        rings.append(np.stack([rx * np.sin(ANG), 0.010 - ry * np.cos(ANG), z + dz], axis=1))
    faces = B.grid(rings, ["leaves", "leaves", "leaves"])
    B.orient(faces, lambda c: V((c.x, c.y - 0.01, 0)))
    B.mark("cape", i0, fit=0.012)


def build_vest(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    def hole(c: Vector) -> bool:
        if c.z > 1.33:
            return True
        return c.y < -0.01 and c.z > 1.14 + 2.4 * abs(c.x)
    bm = sh.make(lambda r, c: r == "torso" and not hole(c) and c.z > 0.9, lambda c: 0.017, [z_below(0.93)], max_tris=2600)
    add_bm(B, bm, "fabric", "shell", fit=0.016)
    bind(B, bm, 0.0032, "chain", fit=0.016)
    bm.free()
    i0 = len(B.bm.verts)                                # gold vines and little roses down both fronts
    for s in (1, -1):
        pts = []
        for k, z in enumerate(np.linspace(0.95, 1.20, 14)):
            deg = s * (22 + 7 * math.sin(k * 1.3))
            pts.append(probe.on_torso(z, deg, 0.0195)[0])
        B.tube(smooth_curve(np.array(pts), 40), 0.0014, 4, "chain", cap=False)
        for k, z in enumerate((1.00, 1.12)):
            p, n = probe.on_torso(z, s * (22 + 7 * math.sin(k * 4.0 + 1.0)), 0.021)
            B.rose(p, n, 0.013, spin=k, pmat="flowers")
            t = n.cross(V((0, 0, 1))).normalized()
            B.leaf(p + t * 0.012 - V((0, 0, 0.006)), t + V((0, 0, -0.4)), n, 0.011, 0.005, "leaves")
    B.mark("near", i0, fit=0.018)
    buttons(B, probe, np.linspace(0.96, 1.12, 4), 0.020, r=0.0040)


# --------------------------------------------------------------------------
# Outerwear
# --------------------------------------------------------------------------
def build_capelet(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    i0 = len(B.bm.verts)
    prof = [(1.345, 0.072, 0.066), (1.325, 0.115, 0.088), (1.30, 0.175, 0.112), (1.265, 0.225, 0.130),
            (1.215, 0.245, 0.150), (1.165, 0.255, 0.162)]
    rings = [np.stack([rx * np.sin(ANG), 0.012 - ry * np.cos(ANG), z + 0.0 * ANG], axis=1) for z, rx, ry in prof]
    faces = B.grid(rings, ["fabric"])
    B.orient(faces, lambda c: V((c.x, c.y - 0.012, 0)))
    B.mark("cape", i0, fit=0.010)
    i0 = len(B.bm.verts)                                # frill of silk petals round the hem
    hem = rings[-1]
    for k in range(0, COLS, 2):
        p = V(hem[k])
        out = V((p.x, p.y - 0.012, 0)).normalized()
        down = (V((0, 0, -1)) + out * 0.45).normalized()
        side = out.cross(V((0, 0, 1))).normalized()
        sz = 0.026 + 0.004 * math.sin(k * 1.7)
        B.ellipsoid(p + down * sz * 0.65 + out * 0.003, side * sz * 0.62, down.cross(side).normalized() * 0.003,
                    down * sz * 0.75, "fabric" if k % 4 else "lining", 6, 3)
    B.mark("cape", i0, fit=0.010)
    i0 = len(B.bm.verts)                                # silk bow at the throat
    B.bow(V((0, -0.082, 1.318)), V((0, -1, 0.15)), 0.040, "lining")
    B.mark("cape", i0, fit=0.008, bones=["Neck", "UpperChest"])


def build_velvet_cloak(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    gap = math.radians(42)
    nr, nc = 24, 44
    sh_r = girth(probe, 1.24)[0] + 0.07
    outer, inner = [], []
    for r in range(nr):
        t = r / (nr - 1)
        z = 1.375 - t * (1.375 - 0.26)
        rx = np.interp(t, [0, 0.05, 0.11, 0.22, 1.0], [0.074, 0.15, sh_r, sh_r + 0.02, 0.34])
        ry = np.interp(t, [0, 0.05, 0.11, 0.22, 1.0], [0.070, 0.105, 0.130, 0.150, 0.27])
        row, row_in = [], []
        for c in range(nc):
            a = gap + (2 * math.pi - 2 * gap) * c / (nc - 1)
            fold = 1.0 + 0.045 * t ** 1.2 * math.sin(a * 9.0)
            p = (rx * fold * math.sin(a), -ry * fold * math.cos(a) + 0.014, z)
            row.append(p)
            k = 1.0 - 0.0035 / max(rx, ry)
            row_in.append((p[0] * k, (p[1] - 0.014) * k + 0.014, z))
        outer.append(np.array(row))
        inner.append(np.array(row_in))
    i0 = len(B.bm.verts)
    f1 = B.grid(outer, ["fabric"], closed=False)
    B.orient(f1, lambda c: V((c.x, c.y - 0.014, 0)))
    f2 = B.grid(inner, ["lining"], closed=False)
    B.orient(f2, lambda c: -V((c.x, c.y - 0.014, 0)))
    B.mark("cape", i0, fit=0.014, bones=CLOAK_BONES)
    i0 = len(B.bm.verts)                                # stand-up collar and a gold clasp
    col = [np.array([(0.076 * math.sin(a), 0.014 - 0.072 * math.cos(a), z) for a in
                     np.linspace(gap * 0.8, 2 * math.pi - gap * 0.8, 30)]) for z in (1.37, 1.405, 1.425)]
    col[2][:, :2] = (col[2][:, :2] - [0, 0.014]) * 1.12 + [0, 0.014]
    f3 = B.grid(col, ["fabric", "lining"], closed=False)
    B.orient(f3, lambda c: V((c.x, c.y - 0.014, 0)))
    for s in (1, -1):
        p = V(outer[1][0 if s > 0 else -1]) + V((0, -0.006, 0))
        torus(B, p, V((0, 1, 0.2)), 0.009, 0.0022, "chain", 16, 4)
        B.bead(p + V((0, -0.002, 0)), 0.0045, "gem", 5, 3)
    B.tube(np.array([V(outer[1][0]) + V((0, -0.007, 0)), V((0, -0.098, 1.335)), V(outer[1][-1]) + V((0, -0.007, 0))]),
           0.0012, 4, "chain", cap=False)
    B.mark("cape", i0, fit=0.010, bones=["Neck", "UpperChest"])


# --------------------------------------------------------------------------
# Feet and hands
# --------------------------------------------------------------------------
def flat_sole(B: Builder, i0: int, depth: float = 0.0) -> None:
    B.bm.verts.ensure_lookup_table()
    for i in range(i0, len(B.bm.verts)):
        v = B.bm.verts[i]
        if v.co.z < 0.012:
            v.co.z = max(v.co.z, 0.0) * 0.3 - depth


def build_riding_boots(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    bm = sh.make(lambda r, c: r == "feet" or (r == "legs" and c.z < 0.53),
                 lambda c: 0.009 + 0.003 * (c.z > 0.2), [z_above(0.50)], max_tris=2300)
    i0 = len(B.bm.verts)
    add_bm(B, bm, "fabric", "shell", fit=0.008)
    flat_sole(B, i0)
    bind(B, bm, 0.007, "leather_d", where=lambda p: p[2] > 0.3, fit=0.012)
    bm.free()
    i0 = len(B.bm.verts)
    for s in (1, -1):
        heel = V((s * 0.090, 0.040, 0.012))
        B.ellipsoid(heel, V((0.024, 0, 0)), V((0, 0.024, 0)), V((0, 0, 0.012)), "sole", 8, 4)
        ring = limb_ring(probe, (s * 0.090, 0.012, 0.12), (0, 0, 1), 0.012, 16)
        B.tube(ring, 0.0025, 5, "leather_d", up=V((0, 0, 1)), squash=2.4, cap=False)
        side = ring[4 if s > 0 else 12]
        B.ellipsoid(V(side) + V((s * 0.003, 0, 0)), V((0.002, 0, 0)), V((0, 0.008, 0)), V((0, 0, 0.007)), "chain", 5, 3)
    B.mark("shell", i0, fit=0.008)


def build_slippers(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    bm = sh.make(lambda r, c: r == "feet" and (c.z < 0.040 or c.y < float(fs.BALL[1]) + 0.010),
                 lambda c: 0.0035, [z_above(0.07)])
    i0 = len(B.bm.verts)
    add_bm(B, bm, "fabric", "shell", fit=0.003)
    flat_sole(B, i0)
    bind(B, bm, 0.0022, "lining", fit=0.003)
    bm.free()
    i0 = len(B.bm.verts)
    for s in (1, -1):
        y = float(fs.BALL[1]) + 0.004
        top = probe.bvh.ray_cast(V((s * float(fs.BALL[0]), y, 0.2)), V((0, 0, -1)), 0.3)[0]
        B.bow(top + V((0, -0.002, 0.006)), V((0, -0.5, 1)), 0.026, "lining")
    B.mark("near", i0, fit=0.004)


def build_gloves_lace(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    parts = []
    for s in (1, -1):
        b = sh.make(lambda r, c, s=s: (r == "hands" or (r == "arms" and abs(c.x) > 0.53)) and c.x * s > 0,
                    lambda c: 0.0018, [((s * 0.555, 0, 0), (-s, 0, 0))], max_tris=1050)
        add_bm(B, b, "fabric", "near", fit=0.0016)
        parts.append(b)
    for b in parts:
        for path in loop_paths(b):
            i0 = len(B.bm.verts)
            B.tube(path, 0.0018, 4, "lace", cap=False)
            for k in range(0, len(path) - 1, 2):     # scalloped lace edge
                p = V(path[k])
                s = 1 if p.x > 0 else -1
                B.ellipsoid(p + V((-s * 0.004, 0, 0)), V((0.0045, 0, 0)), V((0, 0.0035, 0)), V((0, 0, 0.0035)),
                            "lace", 4, 2)
            B.mark("near", i0, fit=0.002)
        b.free()


def build_stockings(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    bm = sh.make(lambda r, c: r in ("feet", "legs") and c.z < 0.74, lambda c: 0.0016, [z_above(0.71)],
                 max_tris=2000)
    add_bm(B, bm, "fabric", "near", fit=0.0014)
    for path in loop_paths(bm):
        i0 = len(B.bm.verts)
        B.tube(path, 0.0030, 4, "lace", squash=2.2, cap=False)
        for k in range(0, len(path) - 1, 2):
            p = V(path[k])
            B.bead(p + V((0, 0, 0.007)), 0.0040, "lace", 4, 2)
        B.mark("near", i0, fit=0.002)
    bm.free()


# --------------------------------------------------------------------------
# Masks (fused to the face: no strap, the edge thins into the skin)
# --------------------------------------------------------------------------
def sd_ellipse(X, Z, cx, cz, rx, rz, rot=0.0):
    c, s = math.cos(rot), math.sin(rot)
    x, z = X - cx, Z - cz
    u, w = c * x + s * z, -s * x + c * z
    k = np.sqrt((u / rx) ** 2 + (w / rz) ** 2)
    return (k - 1.0) * min(rx, rz)


def sd_leaf(X, Z, a, b, w):
    """Pointed leaf (vesica) from point a to point b, half-width w."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    L = np.linalg.norm(b - a)
    d = (b - a) / L
    u = (X - a[0]) * d[0] + (Z - a[1]) * d[1] - L / 2
    v = -(X - a[0]) * d[1] + (Z - a[1]) * d[0]
    R = (L * L / 4 + w * w) / (2 * w)
    return np.sqrt(u * u + (np.abs(v) + R - w) ** 2) - R


def sd_tri(X, Z, p0, p1, p2):
    """Signed distance to a 2D triangle."""
    P = np.stack([X, Z], -1)
    pts = [np.asarray(p, float) for p in (p0, p1, p2)]
    d = np.full(np.shape(X), 1e9)
    cr = []
    for i in range(3):
        a, b = pts[i], pts[(i + 1) % 3]
        e = b - a
        w = P - a
        t = np.clip((w @ e) / (e @ e), 0, 1)
        q = w - t[..., None] * e
        d = np.minimum(d, np.sum(q * q, -1))
        cr.append(e[0] * w[..., 1] - e[1] * w[..., 0])
    inside = ((cr[0] > 0) & (cr[1] > 0) & (cr[2] > 0)) | ((cr[0] < 0) & (cr[1] < 0) & (cr[2] < 0))
    return np.where(inside, -1.0, 1.0) * np.sqrt(d)


def bg_smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b + (a - b) * h - k * h * (1 - h)


def eye_holes(X, Z):
    d = np.full(X.shape, 1e9)
    for s in (1, -1):
        d = np.minimum(d, sd_ellipse(X, Z, s * fs.EYE_X, fs.EYE_Z + 0.001, 0.0225, 0.0150, s * math.radians(-6)))
    return d


def mask_sheet(B: Builder, probe: BodyProbe, sdf: Callable, h: float = 0.0032, lift: float = 0.0030) -> None:
    """Quad sheet over the face from a 2D outline (x, z); vertices dropped onto the face along +Y."""
    x0, x1, z0, z1 = -0.095, 0.095, 1.44, 1.63
    xs = np.arange(x0, x1 + h / 2, h)
    zs = np.arange(z0, z1 + h / 2, h)
    XC, ZC = np.meshgrid(xs[:-1] + h / 2, zs[:-1] + h / 2, indexing="ij")
    keep = sdf(XC, ZC) < 0
    used = {}
    quads = []
    for i, j in zip(*np.nonzero(keep)):
        q = []
        for di, dj in ((0, 0), (1, 0), (1, 1), (0, 1)):
            key = (i + di, j + dj)
            if key not in used:
                used[key] = len(used)
            q.append(used[key])
        quads.append(q)
    P2 = np.zeros((len(used), 2))
    for (i, j), k in used.items():
        P2[k] = (xs[i], zs[j])
    # snap the outer ring of vertices onto the outline
    edge_count = {}
    for q in quads:
        for a, b in zip(q, q[1:] + q[:1]):
            key = (min(a, b), max(a, b))
            edge_count[key] = edge_count.get(key, 0) + 1
    rim = sorted({v for e, c in edge_count.items() if c == 1 for v in e})
    eps = 1e-4
    for _ in range(3):
        Pr = P2[rim]
        d = sdf(Pr[:, 0], Pr[:, 1])
        gx = (sdf(Pr[:, 0] + eps, Pr[:, 1]) - sdf(Pr[:, 0] - eps, Pr[:, 1])) / (2 * eps)
        gz = (sdf(Pr[:, 0], Pr[:, 1] + eps) - sdf(Pr[:, 0], Pr[:, 1] - eps)) / (2 * eps)
        g = np.maximum(np.sqrt(gx * gx + gz * gz), 1e-6)
        P2[rim] = Pr - (d / g)[:, None] * np.stack([gx / g, gz / g], 1)
    depth = -sdf(P2[:, 0], P2[:, 1])
    i0 = len(B.bm.verts)
    verts = []
    for (x, z), dd in zip(P2, depth):
        lft = 0.0006 + (lift - 0.0006) * float(smoothstep(0.0, 0.007, dd))
        verts.append(B.bm.verts.new(on_face(probe, float(x), float(z), lft)[0]))
    idx = B.slot("fabric")
    for q in quads:
        f = B.bm.faces.new([verts[k] for k in q])
        f.material_index = idx
    B.bm.normal_update()
    vs = set(verts)
    for f in [f for f in B.bm.faces if f.verts[0] in vs]:
        if f.normal.y > 0:
            f.normal_flip()
    B.mark("acc", i0)


def face_tube(B: Builder, probe: BodyProbe, pts2: Sequence[Tuple[float, float]], r: float, lift: float, mat: str,
              n: int = 16) -> None:
    P = smooth_curve(np.array(pts2), n)
    path = np.array([on_face(probe, float(x), float(z), lift)[0] for x, z in P])
    B.tube(path, r, 4, mat, cap=True)


def build_mask_butterfly(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    def sdf(X, Z):
        d = np.full(np.shape(X), 1e9)
        for s in (1, -1):
            d = bg_smin(d, sd_ellipse(X, Z, s * 0.050, 1.536, 0.046, 0.031, s * math.radians(28)), 0.008)
            d = bg_smin(d, sd_ellipse(X, Z, s * 0.040, 1.486, 0.030, 0.018, s * math.radians(-24)), 0.008)
        d = bg_smin(d, sd_ellipse(X, Z, 0.0, 1.512, 0.010, 0.040), 0.006)
        return np.maximum(d, -eye_holes(X, Z))
    mask_sheet(B, probe, sdf)
    i0 = len(B.bm.verts)
    for s in (1, -1):                                   # antennae and pearls along the upper wings
        face_tube(B, probe, [(0.0, 1.548), (s * 0.006, 1.566), (s * 0.016, 1.582), (s * 0.026, 1.590)], 0.0013,
                  0.004, "chain", 12)
        B.bead(on_face(probe, s * 0.028, 1.591, 0.004)[0], 0.0030, "pearl", 5, 3)
        for t in np.linspace(0.15, 0.85, 5):
            a = math.pi * (0.2 + 0.9 * t)
            x = s * (0.050 + 0.040 * math.cos(a) * 0.95)
            z = 1.536 + 0.028 * math.sin(a)
            B.bead(on_face(probe, x, z, 0.0042)[0], 0.0022, "pearl", 4, 2)
    B.mark("acc", i0)


def build_mask_fox(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    def sdf(X, Z):
        d = sd_ellipse(X, Z, 0.0, 1.512, 0.082, 0.036)
        for s in (1, -1):
            d = bg_smin(d, sd_tri(X, Z, (s * 0.030, 1.540), (s * 0.078, 1.528), (s * 0.068, 1.606)), 0.006)
            d = bg_smin(d, sd_tri(X, Z, (s * 0.050, 1.500), (s * 0.090, 1.505), (s * 0.075, 1.462)), 0.006)
        d = bg_smin(d, sd_tri(X, Z, (-0.016, 1.50), (0.016, 1.50), (0.0, 1.468)), 0.006)
        return np.maximum(d, -eye_holes(X, Z))
    mask_sheet(B, probe, sdf)
    i0 = len(B.bm.verts)
    for s in (1, -1):                                   # cream inner ears and brow strokes
        c, _ = on_face(probe, s * 0.062, 1.565, 0.0042)
        B.ellipsoid(c, V((0.007, 0, 0)), V((0, 0.0012, 0)), V((0, 0, 0.018)), "cord", 6, 3)
        face_tube(B, probe, [(s * 0.020, 1.535), (s * 0.034, 1.541), (s * 0.050, 1.540)], 0.0012, 0.0045, "chain", 8)
    B.mark("acc", i0)


LEAVES = [((0.0, 1.512), (0.0, 1.600), 0.012), ((0.004, 1.535), (0.060, 1.598), 0.013),
          ((-0.004, 1.535), (-0.060, 1.598), 0.013), ((0.010, 1.53), (0.093, 1.545), 0.016),
          ((-0.010, 1.53), (-0.093, 1.545), 0.016), ((0.012, 1.505), (0.088, 1.478), 0.015),
          ((-0.012, 1.505), (-0.088, 1.478), 0.015), ((0.006, 1.500), (0.040, 1.462), 0.011),
          ((-0.006, 1.500), (-0.040, 1.462), 0.011)]


def build_mask_leaf(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    def sdf(X, Z):
        d = sd_ellipse(X, Z, 0.0, 1.515, 0.070, 0.030)
        for a, b, w in LEAVES:
            d = bg_smin(d, sd_leaf(X, Z, a, b, w), 0.004)
        return np.maximum(d, -eye_holes(X, Z))
    mask_sheet(B, probe, sdf, h=0.0036)
    i0 = len(B.bm.verts)                                # gold veins
    for a, b, w in LEAVES:
        a, b = np.array(a), np.array(b)
        pts = [tuple(a + (b - a) * t) for t in (0.18, 0.5, 0.88)]
        face_tube(B, probe, pts, 0.0010, 0.0040, "chain", 8)
    B.mark("acc", i0)


# --------------------------------------------------------------------------
# Head pieces
# --------------------------------------------------------------------------
def build_circlet(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    def pt(phi: float, lift: float = 0.0030) -> Vector:
        """Low on the brow at the front, on CROWN_RING (over the hair) at the back."""
        w = (0.5 + 0.5 * math.cos(phi)) ** 2
        p = ring_pt(phi, -0.030 * w, -0.026 * w - 0.006)
        out = ring_out(phi)
        hit = probe.bvh.ray_cast(p + out * 0.08, -out, 0.2)[0]
        if hit is not None and (hit - p).dot(out) > -lift:
            p = hit + out * lift
        return p
    path = smooth_curve(np.array([pt(p) for p in np.linspace(0, 2 * math.pi, 49)[:-1]] + [pt(0.0)]), 65)
    B.tube(path, 0.0022, 5, "fabric", up=RING_UP, squash=1.3, cap=False)
    front = pt(0.0, 0.0045)
    for s in (1, -1):                                   # filigree loops either side of the drop
        for k in range(3):
            phi = s * (0.10 + 0.07 * k)
            torus(B, pt(phi, 0.0042) + V((0, 0, 0.0028)), ring_out(phi), 0.0040 - 0.0006 * k, 0.0009, "fabric", 12, 3)
    B.bead(front + V((0, -0.002, -0.004)), 0.0022, "fabric", 5, 3)
    teardrop(B, front + V((0, -0.003, -0.006)), V((0, -0.25, -1)), 0.0075, "gem")
    B.mark("acc", 0)


def hair_pt(phi: float, dz: float, dr: float = 0.002) -> Tuple[Vector, Vector]:
    p = ring_pt(phi, dr, dz)
    n = (ring_out(phi) + RING_UP * 0.35).normalized()
    return p, n


def build_butterfly_clips(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    for k, (deg, dz, size) in enumerate(((62, 0.004, 0.026), (84, -0.016, 0.021), (100, 0.010, 0.017))):
        p, n = hair_pt(math.radians(deg), dz)
        up = (RING_UP + ring_tan(math.radians(deg)) * (0.4 - 0.3 * k)).normalized()
        butterfly(B, p, n, up, size)
    B.mark("acc", 0)


def build_hair_ribbon(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    p, n = hair_pt(math.pi, -0.035, 0.008)
    B.bow(p, n, 0.060, "fabric")
    for s, length in ((1, 0.14), (-1, 0.12)):
        side = V((s, 0, 0))
        path = np.array([p + side * 0.010 + V((0, 0.004 * t, -length * t)) + side * 0.020 * math.sin(t * 2.4)
                         for t in np.linspace(0, 1, 8)])
        B.tube(path, 0.0016, 4, "fabric", up=V((0, 1, 0)), squash=6.0, cap=True)
    B.mark("acc", 0)


def build_pearl_pins(B: Builder, probe: BodyProbe, sh: Shell, rng) -> None:
    for k, (deg, dz) in enumerate(((55, 0.012), (70, -0.006), (88, 0.010), (108, -0.010), (-60, 0.006),
                                   (-80, -0.010), (-100, 0.008))):
        p, n = hair_pt(math.radians(deg), dz, 0.0)
        B.bead(p, 0.0050 if k % 3 == 0 else 0.0040, "fabric", 6, 4)
        B.bead(p - n * 0.003, 0.0024, "chain", 4, 2)
    B.mark("acc", 0)


def ear_pieces(B: Builder, probe: BodyProbe, fn) -> None:
    for s in (1, -1):
        fn(ear_lobe(probe, s), s)
    B.mark("acc", 0)


def build_earrings_drop(B, probe, sh, rng):
    def one(L, s):
        B.bead(L + V((s * 0.001, 0, -0.001)), 0.0020, "chain", 4, 2)
        B.tube(np.array([L + V((0, 0, -0.002)), L + V((0, 0, -0.008))]), 0.0006, 3, "chain")
        teardrop(B, L + V((0, 0, -0.008)), V((0, 0, -1)), 0.0058, "fabric")
    ear_pieces(B, probe, one)


def build_earrings_hoop(B, probe, sh, rng):
    ear_pieces(B, probe, lambda L, s: torus(B, L + V((s * 0.001, 0, -0.0105)), V((1, 0, 0)), 0.0105, 0.0011,
                                            "fabric", 24, 4))


def build_earrings_pearl(B, probe, sh, rng):
    def one(L, s):
        B.bead(L + V((s * 0.001, 0, -0.001)), 0.0020, "chain", 4, 2)
        B.bead(L + V((s * 0.001, 0, -0.0072)), 0.0042, "fabric", 6, 4)
    ear_pieces(B, probe, one)


def build_earrings_rose(B, probe, sh, rng):
    def one(L, s):
        n = V((s, 0.0, -0.2)).normalized()
        B.rose(L + V((s * 0.002, 0, -0.002)), n, 0.0085, spin=0.4 * s, pmat="fabric")
        B.leaf(L + V((s * 0.002, 0.005, -0.006)), V((0, 1, -1)), n, 0.0055, 0.0024, "leaves")
    ear_pieces(B, probe, one)


def build_earrings_star(B, probe, sh, rng):
    ear_pieces(B, probe, lambda L, s: B.star(L + V((s * 0.002, 0, -0.001)), V((s, 0, 0)), 0.0070, "fabric"))


# --------------------------------------------------------------------------
# Neck pieces
# --------------------------------------------------------------------------
def chain_z(front: float, back: float = 1.335) -> Callable[[float], float]:
    return lambda a: float(np.interp(zig(a), [0, 50, 95, 180], [front, front + 0.035, back - 0.012, back]))


def pendant_drop(probe: BodyProbe, path: Arr) -> Tuple[Vector, Vector]:
    p = V(path[0])
    return p + V((0, -0.002, -0.004)), V((0, -0.18, -1)).normalized()


def build_necklace_choker(B, probe, sh, rng):
    path = neck_ring(probe, lambda a: 1.372, 0.0025)
    B.tube(path, 0.0020, 6, "fabric", up=V((0, 0, 1)), squash=4.2, cap=False)
    p = V(path[0])
    B.ellipsoid(p + V((0, -0.004, -0.002)), V((0.0085, 0, 0)), V((0, 0.0025, 0)), V((0, 0, 0.0105)), "chain", 8, 4)
    B.ellipsoid(p + V((0, -0.0062, -0.002)), V((0.0060, 0, 0)), V((0, 0.0018, 0)), V((0, 0, 0.0078)), "pearl", 8, 4)
    B.mark("near", 0, fit=0.0015)


def build_necklace_locket(B, probe, sh, rng):
    path = neck_ring(probe, chain_z(1.215), 0.0022)
    B.tube(path, 0.0010, 4, "fabric", up=V((0, 0, 1)), cap=False)
    top, down = pendant_drop(probe, path)
    B.bead(top, 0.0022, "fabric", 4, 2)
    heart(B, top + down * 0.012 + V((0, -0.003, 0)), V((0, -1, 0)), 0.016, "fabric")
    B.mark("near", 0, fit=0.0015)


def build_necklace_pearl(B, probe, sh, rng):
    path = neck_ring(probe, chain_z(1.245), 0.0045, 96)
    L = np.cumsum(np.r_[0, np.linalg.norm(np.diff(path, axis=0), axis=1)])
    for s in np.arange(0, L[-1] - 0.004, 0.0088):
        p = np.array([np.interp(s, L, path[:, k]) for k in range(3)])
        a = math.atan2(p[0], -(p[1] - 0.01))
        r = 0.0040 + 0.0008 * math.cos(a) ** 8
        B.bead(p, r, "fabric", 5, 3)
    B.mark("near", 0, fit=0.002)


def build_necklace_pendant(B, probe, sh, rng):
    path = neck_ring(probe, chain_z(1.225), 0.0022)
    B.tube(path, 0.0009, 4, "chain", up=V((0, 0, 1)), cap=False)
    top, down = pendant_drop(probe, path)
    B.bead(top, 0.0022, "chain", 4, 2)
    teardrop(B, top + V((0, -0.002, -0.001)), down, 0.0105, "fabric")
    B.mark("near", 0, fit=0.0015)


def build_ribbon_sash(B, probe, sh, rng):
    path = neck_ring(probe, lambda a: 1.330 + 0.010 * math.cos(a), 0.0030)
    B.tube(path, 0.0018, 6, "fabric", up=V((0, 0, 1)), squash=6.5, cap=False)
    deg = -32.0
    a = math.radians(deg)
    p = V(path[int(round((a % (2 * math.pi)) / (2 * math.pi) * (len(path) - 1)))])
    out = V((p.x, p.y - 0.01, 0)).normalized()
    B.bow(p + out * 0.006, out, 0.050, "fabric")
    for s, length in ((1, 0.17), (-1, 0.14)):
        pts = []
        for t in np.linspace(0.0, 1.0, 8):
            z = p.z - 0.012 - length * t
            q = probe.torso_pt(min(z, 1.33), a + s * 0.10 * t + s * 0.06, 0.010)
            pts.append(q)
        B.tube(np.array(pts), 0.0016, 4, "fabric", up=out, squash=7.0, cap=True)
    B.mark("near", 0, fit=0.004)


# --------------------------------------------------------------------------
# Wrist pieces (left wrist unless they come in pairs)
# --------------------------------------------------------------------------
def build_charm_bracelet(B, probe, sh, rng):
    ring = limb_ring(probe, wrist(1, 0.600), (1, 0, 0), 0.0030, 20)
    B.tube(ring, 0.0012, 4, "fabric", up=V((1, 0, 0)), cap=False)
    bottom = sorted(range(len(ring) - 1), key=lambda k: ring[k][2])[:5]
    for j, k in enumerate(sorted(bottom, key=lambda k: ring[k][1])):
        p = V(ring[k]) + V((0, 0, -0.004))
        B.bead(p + V((0, 0, 0.002)), 0.0012, "fabric", 4, 2)
        kind = j % 3
        if kind == 0:
            heart(B, p + V((0, 0, -0.003)), V((1, 0, 0)), 0.0075, "fabric")
        elif kind == 1:
            B.star(p + V((0, 0, -0.003)), V((1, 0, 0)), 0.0050, "chain")
        else:
            B.bead(p + V((0, 0, -0.002)), 0.0030, "pearl", 5, 3)
    B.mark("near", 0, fit=0.0015)


def build_flower_wristlet(B, probe, sh, rng):
    ring = limb_ring(probe, wrist(1, 0.596), (1, 0, 0), 0.0025, 20)
    B.tube(ring, 0.0016, 5, "silk", up=V((1, 0, 0)), squash=3.5, cap=False)
    top = V(ring[max(range(len(ring) - 1), key=lambda k: ring[k][2])])
    n = V((0, -0.25, 1)).normalized()
    B.rose(top + n * 0.006, n, 0.020, pmat="fabric")
    for s in (1, -1):
        q = top + V((s * 0.013, 0.006, -0.002))
        B.flower(q + n * 0.004, (n + V((s * 0.4, 0, 0))).normalized(), 0.011, 5, "fabric", "flower_centers", rng=rng)
        B.leaf(top + V((s * 0.006, -0.014, 0.0)), V((s * 0.4, -1, 0.2)), n, 0.014, 0.005, "leaves")
    B.bead(top + V((0, 0.014, 0.004)), 0.0028, "pearl", 5, 3)
    B.mark("near", 0, fit=0.0015)


def build_bangle(B, probe, sh, rng):
    for k, x in enumerate((0.598, 0.586)):
        c = wrist(1, x)
        R = max(probe.arm_radius(x)) + 0.006
        torus(B, c + V((0, 0, -0.004 * k)), V((1, 0, 0.12 * (k - 0.5))), R, 0.0024 - 0.0006 * k, "fabric", 28, 5)
    B.mark("near", 0, fit=0.002)


def build_ribbon_cuff(B, probe, sh, rng):
    for s in (1, -1):
        ring = limb_ring(probe, wrist(s, 0.598), (1, 0, 0), 0.0022, 20)
        B.tube(ring, 0.0014, 5, "fabric", up=V((1, 0, 0)), squash=4.5, cap=False)
        top = V(ring[max(range(len(ring) - 1), key=lambda k: ring[k][2])])
        B.bow(top + V((0, 0, 0.004)), V((0, -0.2, 1)), 0.026, "fabric")
    B.mark("near", 0, fit=0.0015)


# --------------------------------------------------------------------------
# name -> (builder, finaliser, palette overrides, budget, audit as clothing)
# --------------------------------------------------------------------------
BODY, HEAD = finalize, finalize_head
PIECES = {
    "spring_tunic": (build_spring_tunic, BODY, {"fabric": (MINT, 0.32, 0.0)}, TRI_CLOTH, True),
    "spring_trousers": (build_spring_trousers, BODY, {"fabric": (MINT, 0.32, 0.0)}, TRI_CLOTH, True),
    "painter_smock": (build_painter_smock, BODY, {"fabric": (CREAM, 0.8, 0.0)}, TRI_CLOTH, True),
    "riding_leathers": (build_riding_leathers, BODY, {"fabric": ("A07870", 0.55, 0.0)}, TRI_CLOTH, True),
    "woods_leathers": (build_woods_leathers, BODY, {"fabric": ("9C8A70", 0.6, 0.0)}, TRI_CLOTH, True),
    "vest": (build_vest, BODY, {"fabric": (PERI, 0.45, 0.0)}, TRI_CLOTH, True),
    "capelet": (build_capelet, BODY, {"fabric": (BLUSH, 0.40, 0.0)}, TRI_CLOTH, False),
    "velvet_cloak": (build_velvet_cloak, BODY, {"fabric": ("8793E4", 0.55, 0.0)}, TRI_CLOTH, False),
    "riding_boots": (build_riding_boots, BODY, {"fabric": (LEATHER_D, 0.45, 0.0)}, TRI_ACC, False),
    "slippers": (build_slippers, BODY, {"fabric": (BLUSH, 0.40, 0.0)}, TRI_ACC, False),
    "gloves_lace": (build_gloves_lace, BODY, {"fabric": (PEARL, 0.45, 0.0)}, TRI_ACC, False),
    "stockings": (build_stockings, BODY, {"fabric": (BLUSH, 0.45, 0.0)}, TRI_ACC, False),
    "mask_butterfly": (build_mask_butterfly, HEAD, {"fabric": (LILAC, 0.35, 0.0)}, TRI_ACC, False),
    "mask_fox": (build_mask_fox, HEAD, {"fabric": ("E8A27A", 0.45, 0.0)}, TRI_ACC, False),
    "mask_leaf": (build_mask_leaf, HEAD, {"fabric": (MINT, 0.40, 0.0)}, TRI_ACC, False),
    "circlet": (build_circlet, HEAD, {"fabric": METAL}, TRI_ACC, False),
    "butterfly_clips": (build_butterfly_clips, HEAD, {"fabric": (LILAC, 0.35, 0.1)}, TRI_ACC, False),
    "hair_ribbon": (build_hair_ribbon, HEAD, {"fabric": (ROSE, 0.35, 0.0)}, TRI_ACC, False),
    "pearl_pins": (build_pearl_pins, HEAD, {"fabric": (PEARL, 0.15, 0.0)}, TRI_ACC, False),
    "earrings_drop": (build_earrings_drop, HEAD, {"fabric": ("6FCB9A", 0.08, 0.0)}, TRI_ACC, False),
    "earrings_hoop": (build_earrings_hoop, HEAD, {"fabric": METAL}, TRI_ACC, False),
    "earrings_pearl": (build_earrings_pearl, HEAD, {"fabric": (PEARL, 0.15, 0.0)}, TRI_ACC, False),
    "earrings_rose": (build_earrings_rose, HEAD, {"fabric": (ROSE, 0.40, 0.0)}, TRI_ACC, False),
    "earrings_star": (build_earrings_star, HEAD, {"fabric": METAL}, TRI_ACC, False),
    "necklace_choker": (build_necklace_choker, BODY, {"fabric": (LILAC, 0.5, 0.0)}, TRI_ACC, False),
    "necklace_locket": (build_necklace_locket, BODY, {"fabric": METAL}, TRI_ACC, False),
    "necklace_pearl": (build_necklace_pearl, BODY, {"fabric": (PEARL, 0.15, 0.0)}, TRI_ACC, False),
    "necklace_pendant": (build_necklace_pendant, BODY, {"fabric": ("6FCB9A", 0.08, 0.0)}, TRI_ACC, False),
    "ribbon_sash": (build_ribbon_sash, BODY, {"fabric": (PERI, 0.35, 0.0)}, TRI_ACC, False),
    "charm_bracelet": (build_charm_bracelet, BODY, {"fabric": ("D9DDE3", 0.25, 0.7)}, TRI_ACC, False),
    "flower_wristlet": (build_flower_wristlet, BODY, {"fabric": (BLUSH, 0.45, 0.0)}, TRI_ACC, False),
    "bangle": (build_bangle, BODY, {"fabric": METAL}, TRI_ACC, False),
    "ribbon_cuff": (build_ribbon_cuff, BODY, {"fabric": (LILAC, 0.35, 0.0)}, TRI_ACC, False),
}


def main(only: Sequence[str] = ()) -> None:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(MODEL_DIR, "feyre.blend"))
    for n in [o.name for o in bpy.data.objects if o.name.startswith("hunter_") or o.name == "Body_LOD1"]:
        bpy.data.objects.remove(bpy.data.objects[n])
    body, arm = bpy.data.objects["Body"], bpy.data.objects["Armature"]
    spec = [(bn.name, tuple(bn.head_local), tuple(bn.tail_local), None, bn.use_deform) for bn in arm.data.bones]
    probe = BodyProbe(body)
    sh = Shell(probe)
    os.makedirs(WARDROBE_DIR, exist_ok=True)
    names = [n for n in PIECES if not only or n in only]
    coll = bpy.data.collections.new("Wardrobe")
    bpy.context.scene.collection.children.link(coll)
    lines, built = [], []
    for name in names:
        fn, fin, pal, budget, cloth = PIECES[name]
        rng = np.random.default_rng(SEED + len(name))
        B = Builder(name, "fabric", {**PAL, **pal})
        fn(B, probe, sh, rng)
        obj = fin(B, name, probe, arm, spec)
        t = bf.tri_count(obj)
        line = "%-16s tris=%4d/%d%s slots=%s" % (name, t, budget, " OVER" if t > budget else "",
                                                ",".join(m.name.split(":")[-1] for m in obj.data.materials))
        if cloth:
            a = bg.audit(probe, obj)
            cov = " ".join("%s=%.0f%%" % (r, 100 * f) for r, f in a["rest"][1].items())
            line += "\n    poke %d/%d | clear %.1f/%.1f mm | %s | %s" % (
                a["rest"][0], a["nourished"][0], a["clearance"][0] * 1000, a["clearance"][1] * 1000, cov,
                bg.pose_check(arm, obj))
        lines.append(line)
        coll.objects.link(obj)
        bpy.context.scene.collection.objects.unlink(obj)
        built.append(obj)
    bpy.context.view_layer.update()
    for o in built:
        bg.export_named(os.path.join(WARDROBE_DIR, o.name + ".glb"), o, arm)
    if not only:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WARDROBE_DIR, "wardrobe.blend"), compress=True)
    print("\n==== WARDROBE BUILD REPORT ====")
    print("\n".join(lines))


if __name__ == "__main__":
    main([a for a in sys.argv[1:] if a in PIECES])
