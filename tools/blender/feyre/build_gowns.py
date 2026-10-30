"""Storybook-princess gowns and head accessories for Feyre.

Reproducible build (needs characters/feyre/model/feyre.blend from build_feyre.py):
    /opt/bpyenv/bin/python tools/blender/feyre/build_gowns.py

Writes (relative to the repo root, all in characters/feyre/wardrobe/):
    gown_dinner.glb      rose dinner gown: thin straps, sweetheart bodice, flowing scalloped skirt
    gown_ball.glb        blush ball gown: off-shoulder puffs, huge bell skirt of scalloped tulle tiers, roses
    gown_garden.glb      mint tea dress: puff sleeves, calf-length full skirt, daisies, pearl buttons
    gown_solstice.glb    periwinkle midsummer gown: bell sleeves, flower garland, floaty overskirt
    gown_rose_petal.glb  rose strapless gown: petal-collar bodice, five tiers of petal hems
    gown_starlight.glb   deep periwinkle night gown: off-shoulder, high-low tulle with gold and pearl stars
    tiara.glb            gold spires, pearls and gems on feyre_shape.CROWN_RING (Head bone only)
    flower_crown.glb     Alis's polished crown of oversized blooms (Head only)
    woven_crown.glb      hand-woven wildflower wreath, a little uneven (Head only)
    gowns.blend          editable source: Feyre + every garment

Every garment is skinned to the 60-bone armature of feyre.blend.  Gowns follow the body (weights
transferred from it, skirts blend Hips -> UpperLeg) and carry a `nourished` shape key.  The main
cloth surface is the material `fabric` (slot 0, tinted per variant by the game); trims, flowers and
leaves are separate palette-coloured materials.  Inside gowns.blend the datablocks are called
`<object>:<material>`; they get their plain names only while exporting.  Everything is seeded.
"""

import math
import os
import sys
from typing import Callable, Dict, List, Optional, Sequence, Tuple

import bpy  # noqa: E402  (must come before bmesh when used as a module)
import bmesh
import numpy as np
from mathutils import Matrix, Vector, kdtree
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_feyre as bf  # noqa: E402
import feyre_shape as fs  # noqa: E402
from build_feyre import (REGIONS, MODEL_DIR, WARDROBE_DIR, apply_weights, distance_weights,  # noqa: E402
                         ensure_uvs, export_glb, make_material, skin_to_armature, smoothstep,
                         tri_count, verts_np)

SEED = 7
COLS = 48                      # columns of every lathe ring (bodice and skirts share them)
ANG = 2 * math.pi * np.arange(COLS) / COLS   # angle 0 = front (-Y), +90 deg = her left (+X)
CLEAR = 0.008                  # loose cloth keeps this far from the body
TRI_GOWN = 5000
TRI_ACC = 3000
Arr = np.ndarray

# --------------------------------------------------------------------------
# Palette and materials
# --------------------------------------------------------------------------
ROSE, BLUSH, LILAC, PERI, BUTTER = "F4A6C0", "FAD4DC", "C8A8E9", "A7B5F2", "FCE9A6"
PEARL, GOLD_LIT, GOLD, MINT, DEEP = "FBF7F2", "F2D27A", "D4A94F", "B5E3C0", "8793E4"

# name -> (hex, roughness, metallic); gown palettes override fabric / lining / flowers
TRIMS: Dict[str, Tuple[str, float, float]] = {
    "fabric": (PEARL, 0.34, 0.0), "lining": (BLUSH, 0.40, 0.0),
    "trim_gold": (GOLD, 0.30, 0.55), "pearl": (PEARL, 0.15, 0.0), "gem": (PERI, 0.10, 0.0),
    "flowers": (ROSE, 0.45, 0.0), "flowers_b": (BUTTER, 0.45, 0.0), "flowers_c": (LILAC, 0.45, 0.0),
    "flower_centers": (GOLD_LIT, 0.40, 0.0), "leaves": (MINT, 0.45, 0.0),
}
SHEEN = ("fabric", "lining", "pearl", "flowers", "flowers_b", "flowers_c")


def srgb_to_linear(h: str) -> Tuple[float, float, float]:
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)  # type: ignore


def make_mat(owner: str, name: str, spec: Tuple[str, float, float]) -> bpy.types.Material:
    m = make_material("%s:%s" % (owner, name), srgb_to_linear(spec[0]), spec[1], spec[2], cull=False)
    bsdf = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
    if bsdf and name in SHEEN:
        for key, val in (("Coat Weight", 0.30), ("Sheen Weight", 0.30)):
            if key in bsdf.inputs:
                bsdf.inputs[key].default_value = val
    return m


# --------------------------------------------------------------------------
# Geometry kit
# --------------------------------------------------------------------------
class Builder:
    """One garment = one bmesh; parts are tagged by vertex range so weights can differ per part."""

    def __init__(self, owner: str, first: Optional[str] = "fabric", palette: Optional[dict] = None):
        self.owner = owner
        self.bm = bmesh.new()
        self.slots: List[str] = []
        self.parts: List[tuple] = []     # (kind, i0, i1, params)
        self.pal = {**TRIMS, **(palette or {})}
        if first:
            self.slot(first)

    def slot(self, name: str) -> int:
        if name not in self.slots:
            self.slots.append(name)
        return self.slots.index(name)

    def mark(self, kind: str, i0: int, **params) -> None:
        self.parts.append((kind, i0, len(self.bm.verts), params))

    def ellipsoid(self, c, a1, a2, a3, mat: str, u: int = 5, v: int = 3) -> None:
        """Squashed sphere with axes a1..a3 (their lengths are the radii; a3 is the pole axis)."""
        M = Matrix([[a1[0], a2[0], a3[0], c[0]], [a1[1], a2[1], a3[1], c[1]],
                    [a1[2], a2[2], a3[2], c[2]], [0, 0, 0, 1]])
        r = bmesh.ops.create_uvsphere(self.bm, u_segments=u, v_segments=v, radius=1.0, matrix=M)
        idx = self.slot(mat)
        for vt in r["verts"]:
            for f in vt.link_faces:
                f.material_index = idx

    def bead(self, c, r: float, mat: str = "pearl", u: int = 5, v: int = 3) -> None:
        self.ellipsoid(c, Vector((r, 0, 0)), Vector((0, r, 0)), Vector((0, 0, r)), mat, u, v)

    def grid(self, rings: Sequence[Arr], mats: Sequence[str], closed: bool = True) -> list:
        vs = [[self.bm.verts.new(tuple(p)) for p in ring] for ring in rings]
        faces = []
        for r in range(len(vs) - 1):
            idx = self.slot(mats[min(r, len(mats) - 1)])
            cols = len(vs[r])
            for c in (range(cols) if closed else range(cols - 1)):
                c2 = (c + 1) % cols
                f = self.bm.faces.new((vs[r][c], vs[r][c2], vs[r + 1][c2], vs[r + 1][c]))
                f.material_index = idx
                faces.append(f)
        return faces

    def orient(self, faces: list, ref: Callable[[Vector], Vector]) -> None:
        self.bm.normal_update()
        for f in faces:
            if f.normal.dot(ref(f.calc_center_median())) < 0:
                f.normal_flip()

    def tube(self, path: Arr, radii, sec: int, mat: str, up: Optional[Vector] = None, squash: float = 1.0,
             cap: bool = True) -> None:
        """Tube along a polyline.  `up` fixes the frame (for planar rings); otherwise it is parallel-transported."""
        n = len(path)
        rad = np.full(n, radii, float) if np.isscalar(radii) else np.asarray(radii, float)
        T = np.gradient(path, axis=0)
        T /= np.linalg.norm(T, axis=1)[:, None] + 1e-12
        ref = Vector((0, 0, 1)) if up is None else up
        Nv = Vector(T[0]).cross(ref)
        if Nv.length < 1e-4:
            Nv = Vector(T[0]).cross(Vector((1, 0, 0)))
        Nv.normalize()
        rings = []
        for i in range(n):
            t = Vector(T[i])
            if up is not None:
                Nv = t.cross(up)
                Nv = Nv.normalized() if Nv.length > 1e-4 else Vector((1, 0, 0))
            else:
                Nv = (Nv - t * Nv.dot(t)).normalized()
            U = Nv.cross(t).normalized()
            rings.append(np.array([Vector(path[i]) + Nv * rad[i] * math.cos(2 * math.pi * j / sec)
                                   + U * rad[i] * squash * math.sin(2 * math.pi * j / sec) for j in range(sec)]))
        faces = self.grid(rings, [mat])
        cen = [Vector(p) for p in path]
        self.orient(faces, lambda c: c - min(cen, key=lambda q: (q - c).length_squared))
        if cap:
            idx = self.slot(mat)
            for ring in (rings[0], rings[-1]):
                f = self.bm.faces.new([self.bm.verts.new(tuple(p)) for p in ring])
                f.material_index = idx

    def flower(self, c, n, size: float, petals: int, pmat: str = "flowers", cmat: str = "flower_centers",
               spin: float = 0.0, rng: Optional[np.random.Generator] = None, centre: bool = True,
               u: int = 5, v: int = 3) -> None:
        """Flat bloom facing n.  With an rng the petals vary in length and angle (hand-made look)."""
        n = Vector(n).normalized()
        t1 = n.cross(Vector((0, 0, 1)))
        if t1.length < 1e-3:
            t1 = n.cross(Vector((1, 0, 0)))
        t1.normalize()
        t2 = n.cross(t1)
        for i in range(petals):
            a = spin + 2 * math.pi * i / petals
            k = 1.0
            if rng is not None:
                a += rng.uniform(-0.18, 0.18)
                k = rng.uniform(0.82, 1.18)
            d = t1 * math.cos(a) + t2 * math.sin(a)
            e = n.cross(d).normalized()
            s = size * k
            self.ellipsoid(Vector(c) + d * s * 0.55 + n * s * 0.16, d * s * 0.58, e * s * 0.42, n * s * 0.22, pmat, u, v)
        if centre:
            self.ellipsoid(Vector(c) + n * size * 0.30, t1 * size * 0.28, t2 * size * 0.28, n * size * 0.22, cmat, 5, 3)

    def rose(self, c, n, size: float, spin: float = 0.0, pmat: str = "flowers") -> None:
        """Oversized layered bloom: outer petals, a raised inner ring and a bud."""
        n = Vector(n).normalized()
        self.flower(c, n, size, 6, pmat, centre=False, spin=spin)
        self.flower(Vector(c) + n * size * 0.14, n, size * 0.62, 5, pmat, spin=spin + 0.5)

    def leaf(self, c, along, out, length: float, width: float, mat: str = "leaves") -> None:
        a = Vector(along).normalized()
        o = Vector(out).normalized()
        self.ellipsoid(c, a * length, a.cross(o).normalized() * width, o * width * 0.35, mat, 5, 3)

    def star(self, c, n, size: float, mat: str = "trim_gold", spin: float = 0.0) -> None:
        """Four-point sparkle: two crossed flat diamonds (16 tris)."""
        n = Vector(n).normalized()
        t1 = n.cross(Vector((0, 0, 1)))
        t1 = t1.normalized() if t1.length > 1e-3 else Vector((1, 0, 0))
        t2 = n.cross(t1)
        t1, t2 = t1 * math.cos(spin) + t2 * math.sin(spin), t2 * math.cos(spin) - t1 * math.sin(spin)
        for x, y in ((t1, t2), (t2, t1)):
            self.ellipsoid(c, y * size * 0.22, n * size * 0.08, x * size, mat, 4, 2)

    def bow(self, c, out, size: float, mat: str = "fabric") -> None:
        out = Vector(out).normalized()
        side = out.cross(Vector((0, 0, 1))).normalized()
        up = Vector((0, 0, 1))
        for s in (1, -1):
            self.ellipsoid(Vector(c) + side * s * size * 0.55 + out * size * 0.05, side * s * size * 0.55,
                           out * size * 0.14, (up * 0.55 + side * s * 0.0) * size * 0.5, mat, 6, 4)
            self.ellipsoid(Vector(c) + side * s * size * 0.22 - up * size * 0.55 + out * size * 0.05,
                           side * size * 0.14, out * size * 0.07, up * size * 0.62, mat, 5, 3)
        self.bead(Vector(c) + out * size * 0.12, size * 0.17, mat)


def smooth_curve(ctrl: Sequence[Sequence[float]], n: int) -> Arr:
    C = np.array(ctrl, float)
    P = np.vstack([C[0] * 2 - C[1], C, C[-1] * 2 - C[-2]])
    out = []
    for s in np.linspace(0, len(C) - 1, n):
        i = min(int(s), len(C) - 2)
        t = s - i
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                          + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return np.array(out)


class Profile:
    """Skirt silhouette: (z, rx, ry, cy) control points, top to hem; `at(z)` gives (rx, ry, cy) back."""

    def __init__(self, ctrl):
        d = smooth_curve(ctrl, 160)
        self.d = d[np.argsort(d[:, 0])]

    def at(self, z: float) -> Tuple[float, float, float]:
        return tuple(float(np.interp(z, self.d[:, 0], self.d[:, k])) for k in (1, 2, 3))  # type: ignore


def hem_off(h: Optional[tuple], a: Arr) -> Arr:
    """Hem height offset per angle: ("sin", amp, m, phase) waves, ("scallop", amp, m, phase) petals."""
    if h is None:
        return np.zeros_like(a)
    kind, amp, m, ph = h
    if kind == "sin":
        return amp * np.sin(m * a + ph)
    u = (m * a / (2 * math.pi) + ph) % 1.0
    return -amp * np.sqrt(np.clip(1 - (2 * u - 1) ** 2, 0, 1))


def skirt(B: Builder, ctrl, nrows: int, mats: Sequence[str], waist: Optional[Arr] = None, fold=(0.0, 7, 0.0),
          hem=None, hem_from: float = 0.55, bulge=None, lmax: float = 0.7) -> List[Arr]:
    """Lathe skirt.  `waist` (the bodice's bottom ring) is joined as the first ring."""
    i0 = len(B.bm.verts)
    prof = smooth_curve(ctrl, nrows)
    rings = [waist.copy()] if waist is not None else []
    for k, (z, rx, ry, cy) in enumerate(prof):
        t = k / (len(prof) - 1)
        f = 1.0 + fold[0] * t ** 1.3 * np.sin(fold[1] * ANG + fold[2])
        if bulge:
            f = f * (1.0 + bulge[0] * t * np.cos(bulge[1] * ANG + bulge[2]))
        dz = hem_off(hem, ANG) * smoothstep(hem_from, 1.0, t)
        rings.append(np.stack([rx * f * np.sin(ANG), cy - ry * f * np.cos(ANG), z + dz], axis=1))
    faces = B.grid(rings, mats)
    B.orient(faces, lambda c: Vector((c.x, c.y - 0.01, 0)))
    B.mark("skirt", i0, lmax=lmax)
    return rings


def tier(base: Profile, zt: float, zb: float, flare: float, mats, B: Builder, rows: int = 4, gap: float = 0.010,
         **kw) -> List[Arr]:
    """A ruffle tier hanging from zt to zb, always outside `base` by at least `gap`, flaring toward its hem."""
    ctrl = []
    for k in range(rows):
        s = k / (rows - 1)
        z = zt + (zb - zt) * s
        rx, ry, cy = base.at(z)
        ctrl.append((z, rx + gap + flare * s ** 1.5, ry + gap + flare * s ** 1.5, cy))
    return skirt(B, ctrl, rows, mats, **kw)


def sleeve(B: Builder, side: int, xs, radii, mats: Sequence[str], cols: int = 16, cy: float = 0.01,
           cz: float = 1.285, hem: Optional[tuple] = None) -> None:
    """Tube along the T-pose arm.  radii: (rz, ry) per ring; hem = (amp, m) scallops the last ring along the arm."""
    i0 = len(B.bm.verts)
    a = 2 * math.pi * np.arange(cols) / cols
    rings = []
    for k, (x, (rz, ry)) in enumerate(zip(xs, radii)):
        xx = x + (hem[0] * np.sin(hem[1] * a) * smoothstep(0.75, 1.0, k / (len(xs) - 1)) if hem else 0.0)
        rings.append(np.stack([side * xx * np.ones(cols), cy + ry * np.cos(a), cz + rz * np.sin(a)], axis=1))
    faces = B.grid(rings, mats)
    B.orient(faces, lambda c: Vector((0, c.y - cy, c.z - cz)))
    B.mark("sleeve", i0, side=side)


# --------------------------------------------------------------------------
# Body probe (BVH on the Body mesh, rest and nourished)
# --------------------------------------------------------------------------
class BodyProbe:
    def __init__(self, body: bpy.types.Object):
        me = body.data
        self.body = body
        self.P = verts_np(me)
        a = np.empty(len(self.P) * 3)
        me.shape_keys.key_blocks["nourished"].data.foreach_get("co", a)
        self.Pn = a.reshape(-1, 3)
        self.delta = self.Pn - self.P
        tris = [tuple(p.vertices) for p in me.polygons]
        self.bvh = BVHTree.FromPolygons([tuple(p) for p in self.P], tris)
        self.bvh_n = BVHTree.FromPolygons([tuple(p) for p in self.Pn], tris)
        self.kd = kdtree.KDTree(len(self.P))
        for i, p in enumerate(self.P):
            self.kd.insert(p, i)
        self.kd.balance()
        votes = np.zeros((len(self.P), len(REGIONS)))
        for p in me.polygons:
            for v in p.vertices:
                votes[v, p.material_index] += 1
        self.region = votes.argmax(axis=1)
        nrm = np.empty(len(self.P) * 3)
        me.vertices.foreach_get("normal", nrm)
        self.N = nrm.reshape(-1, 3)
        self.zs = np.arange(0.80, 1.34, 0.01)
        self.cys = np.array([self._cy(z) for z in self.zs])

    def _cy(self, z: float) -> float:
        yf = self.bvh.ray_cast(Vector((0, 0, z)), Vector((0, -1, 0)))[0]
        yb = self.bvh.ray_cast(Vector((0, 0, z)), Vector((0, 1, 0)))[0]
        return (yb.y + yf.y) / 2 if yf is not None and yb is not None else 0.0

    def cy(self, z: float) -> float:
        return float(np.interp(z, self.zs, self.cys))

    def torso_pt(self, z: float, a: float, off: float = 0.0) -> Vector:
        """Point on the torso at height z and angle a (0 = front), pushed `off` outward along the ray."""
        o = Vector((0, self.cy(z), z))
        d = Vector((math.sin(a), -math.cos(a), 0))
        hit = self.bvh.ray_cast(o, d)[0]
        return hit + d * off

    def on_torso(self, z: float, deg: float, lift: float = 0.0):
        """Surface point (lifted along the normal) + normal on the torso."""
        a = math.radians(deg)
        o = Vector((0, self.cy(z), z))
        d = Vector((math.sin(a), -math.cos(a), 0))
        hit = self.bvh.ray_cast(o, d)
        return hit[0] + hit[1] * lift, hit[1]

    def shoulder_z(self, x: float, y: float) -> float:
        h = self.bvh.ray_cast(Vector((x, y, 1.45)), Vector((0, 0, -1)))[0]
        return h.z if h is not None else 1.3

    def arm_radius(self, x: float) -> Tuple[float, float]:
        o = Vector((x, 0.01, 1.285))
        rs = []
        for d in ((0, 0, 1), (0, 0, -1), (0, 1, 0), (0, -1, 0)):
            h = self.bvh.ray_cast(o, Vector(d))[0]
            rs.append((h - o).length if h is not None else 0.04)
        return (rs[0] + rs[1]) / 2, (rs[2] + rs[3]) / 2

    def fit(self, P: Arr, idx, target: float = CLEAR, iters: int = 4, nourished: bool = False) -> Arr:
        """Push the selected vertices out to >= target from the body surface."""
        P = P.copy()
        bvh = self.bvh_n if nourished else self.bvh
        for _ in range(iters):
            for i in idx:
                v = Vector(P[i])
                loc, nrm, _, d = bvh.find_nearest(v)
                if loc is not None and ((v - loc).dot(nrm) < 0 or d < target):
                    P[i] = loc + nrm * target
        return P

    def clearance(self, P: Arr, nourished: bool = False) -> float:
        bvh = self.bvh_n if nourished else self.bvh
        dmin = 9.0
        for p in P:
            v = Vector(p)
            loc, nrm, _, d = bvh.find_nearest(v)
            dmin = min(dmin, -d if (v - loc).dot(nrm) < 0 else d)
        return dmin


# --------------------------------------------------------------------------
# Weights and finishing
# --------------------------------------------------------------------------
def top4(w: dict) -> list:
    items = sorted(w.items(), key=lambda kv: -kv[1])[:4]
    s = sum(v for _, v in items) or 1.0
    return [(k, v / s) for k, v in items if v / s > 0.01]


def skirt_leg_weights(p, near: dict, lmax: float, z_hi: float = 0.90, z_lo: float = 0.50) -> list:
    """Hips at the waist, easing into the UpperLeg of its own side toward the hem."""
    x, _, z = p
    k = float(smoothstep(z_hi, z_lo, z)) * lmax
    sl = float(smoothstep(-0.12, 0.12, x))
    custom = {"Hips": 1.0 - k, "LeftUpperLeg": k * sl, "RightUpperLeg": k * (1.0 - sl)}
    t = float(smoothstep(0.96, 0.88, z))        # near the waist blend toward the body-transfer weights
    out: dict = {}
    for n, w in near.items():
        out[n] = out.get(n, 0.0) + (1.0 - t) * w
    for n, w in custom.items():
        out[n] = out.get(n, 0.0) + t * w
    return top4(out)


def compute_weights(B: Builder, P: Arr, probe: BodyProbe, spec) -> Tuple[list, list]:
    near_w, nn = bf.transfer_weights(probe.body, probe.P, P)
    out = [top4(dict(w)) for w in near_w]
    for kind, i0, i1, prm in B.parts:
        for i in range(i0, i1):
            if kind == "skirt":
                out[i] = skirt_leg_weights(P[i], dict(near_w[i]), prm.get("lmax", 0.7))
            elif kind == "sleeve":
                s = "Left" if prm["side"] > 0 else "Right"
                names = [s + n for n in ("Shoulder", "UpperArm", "LowerArm", "Hand")]
                out[i] = distance_weights(P[i:i + 1], spec, names, k=3, power=3.0)[0]
    return out, nn


def new_object(B: Builder, name: str) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    B.bm.to_mesh(me)
    B.bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for s in B.slots:
        me.materials.append(make_mat(name, s, B.pal[s]))
    for p in me.polygons:
        p.use_smooth = True
    return obj


def finalize_gown(B: Builder, name: str, probe: BodyProbe, arm, spec) -> bpy.types.Object:
    obj = new_object(B, name)
    me = obj.data
    P = verts_np(me)
    loose = [i for k, i0, i1, _ in B.parts if k in ("skirt", "sleeve") for i in range(i0, i1)]
    tight = [i for k, i0, i1, _ in B.parts if k == "bodice" for i in range(i0, i1)]
    deco = [i for k, i0, i1, _ in B.parts if k == "near" for i in range(i0, i1)]
    P = probe.fit(probe.fit(probe.fit(P, loose, CLEAR), tight, 0.006), deco, 0.001)
    me.vertices.foreach_set("co", P.ravel())
    me.update()
    w, nn = compute_weights(B, P, probe, spec)
    apply_weights(obj, w)
    skin_to_armature(obj, arm)
    # nourished: follow the body's delta, fading out with distance from the body surface.
    obj.shape_key_add(name="Basis", from_mix=False)
    sk = obj.shape_key_add(name="nourished", from_mix=False)
    d = np.zeros_like(P)
    for i, lst in enumerate(nn):
        dist = probe.kd.find(Vector(P[i]))[2]
        fall = float(np.clip(1.0 - max(0.0, dist - 0.02) / 0.10, 0.0, 1.0))
        d[i] = sum(probe.delta[j] * f for j, f in lst) * fall
    Pn = probe.fit(probe.fit(probe.fit(P + d, loose, 0.010, nourished=True), tight, 0.008, nourished=True),
                   deco, 0.001, nourished=True)
    sk.data.foreach_set("co", Pn.ravel())
    sk.value = 0.0
    ensure_uvs(obj)
    return obj


def finalize_head(B: Builder, name: str, arm) -> bpy.types.Object:
    obj = new_object(B, name)
    g = obj.vertex_groups.new(name="Head")
    g.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    skin_to_armature(obj, arm)
    ensure_uvs(obj)
    return obj


# --------------------------------------------------------------------------
# Gown parts
# --------------------------------------------------------------------------
Neck = Sequence[Tuple[float, float]]
SWEET: Neck = ((0, 1.235), (32, 1.262), (62, 1.215), (90, 1.185), (118, 1.20), (150, 1.245), (180, 1.262))
SCOOP: Neck = ((0, 1.205), (35, 1.215), (65, 1.200), (90, 1.185), (118, 1.20), (150, 1.245), (180, 1.262))
STRAIGHT: Neck = ((0, 1.225), (35, 1.23), (65, 1.205), (90, 1.185), (118, 1.20), (150, 1.235), (180, 1.245))
HIGH: Neck = ((0, 1.255), (35, 1.255), (65, 1.222), (90, 1.19), (118, 1.21), (150, 1.255), (180, 1.275))
WAIST_Z = 0.985


def edge(knots: Neck) -> Callable[[float], float]:
    ds, zs = zip(*knots)

    def f(a: float) -> float:
        d = abs(math.degrees((a + math.pi) % (2 * math.pi) - math.pi))
        return float(np.interp(d, ds, zs))
    return f


def bodice(B: Builder, probe: BodyProbe, neck: Neck, mats: Sequence[str], tv: Sequence[float] = None,
           off: float = 0.010) -> Tuple[Arr, Arr]:
    """Fitted bodice lofted from rays cast at the torso.  Returns (bottom ring, top ring).  The bottom edge
    dips to a soft point at the front."""
    tv = tv or [0.0, 0.10, 0.22, 0.36, 0.50, 0.64, 0.78, 0.90, 0.96, 1.0]
    top = edge(neck)
    i0 = len(B.bm.verts)
    rings = []
    for t in tv:
        pts = []
        for a in ANG:
            zb = WAIST_Z - 0.032 * math.exp(-(a / 0.6) ** 2) - 0.032 * math.exp(-((a - 2 * math.pi) / 0.6) ** 2)
            pts.append(probe.torso_pt(zb + (top(a) - zb) * t, a, off))
        rings.append(np.array(pts))
    faces = B.grid(rings, mats)
    B.orient(faces, lambda c: Vector((c.x, c.y - probe.cy(c.z), 0)))
    B.mark("bodice", i0)
    return rings[0], rings[-1]


def straps(B: Builder, probe: BodyProbe, top_ring: Arr, mat: str = "fabric", width: float = 0.007) -> None:
    """Thin shoulder straps from the bodice top edge (front and back) over each shoulder."""
    i0 = len(B.bm.verts)
    for s in (1, -1):
        f = top_ring[int(round(s * 24 / 360 * COLS)) % COLS]
        b = top_ring[int(round(s * 152 / 360 * COLS)) % COLS]
        path = [Vector(f)]
        for t in np.linspace(0.12, 0.88, 9):
            y = f[1] + (b[1] - f[1]) * t
            x = s * (0.066 + 0.016 * math.sin(math.pi * t))
            path.append(Vector((x, y, probe.shoulder_z(abs(x), y) + width * 1.4)))
        path.append(Vector(b))
        B.tube(smooth_curve(np.array(path), 20), width, 4, mat, squash=0.4, cap=False)
    B.mark("near", i0)


def pearl_edge(B: Builder, top_ring: Arr, probe: BodyProbe, every: int = 2, r: float = 0.0062) -> None:
    i0 = len(B.bm.verts)
    for i in range(0, COLS, every):
        p = Vector(top_ring[i])
        o = Vector((p.x, p.y - probe.cy(p.z), 0)).normalized()
        B.bead(p + o * 0.004, r)
    B.mark("near", i0)


def waist_bow(B: Builder, probe: BodyProbe, size: float = 0.05, mat: str = "fabric", deg: float = 180) -> None:
    i0 = len(B.bm.verts)
    pt, n = probe.on_torso(1.0, deg, 0.020)
    B.bow(pt, n, size, mat)
    B.mark("near", i0)


def bloom_cluster(B: Builder, probe: BodyProbe, z: float, deg: float, size: float, seed: int, mats=("flowers", "flowers_b")) -> None:
    i0 = len(B.bm.verts)
    pt, n = probe.on_torso(z, deg, 0.02)
    t = n.cross(Vector((0, 0, 1))).normalized()
    B.rose(pt, n, size, pmat=mats[0])
    B.rose(pt + t * size * 0.85 - Vector((0, 0, size * 0.5)) + n * 0.004, n, size * 0.7, spin=1.0, pmat=mats[1])
    B.leaf(pt - t * size * 0.8 - Vector((0, 0, size * 0.55)), t * -1 - Vector((0, 0, 0.5)), n, size * 1.0, size * 0.4)
    B.leaf(pt + Vector((0, 0, size * 1.0)) - t * size * 0.3, t * 0.3 + Vector((0, 0, 1)), n, size * 0.9, size * 0.35)
    B.mark("near", i0)


def scatter(B: Builder, rings: List[Arr], rng: np.random.Generator, n_star: int, n_pearl: int, rows: Tuple[int, int],
            size: Tuple[float, float], lmax: float) -> None:
    """Gold sparkles and tiny pearls pinned to a skirt layer."""
    i0 = len(B.bm.verts)
    for k in range(n_star + n_pearl):
        r = int(rng.integers(rows[0], min(rows[1], len(rings) - 1)))
        c = int(rng.integers(0, COLS))
        p = Vector(rings[r][c])
        out = Vector((p.x, p.y - 0.02, 0)).normalized()
        if k < n_star:
            B.star(p + out * 0.005, out + Vector((0, 0, 0.1)), rng.uniform(*size), "trim_gold" if k % 3 else "flower_centers",
                   spin=rng.uniform(-0.5, 0.5))
        else:
            B.bead(p + out * 0.004, rng.uniform(0.0035, 0.0055), "pearl", 4, 2)
    B.mark("skirt", i0, lmax=lmax)


def puff_sleeves(B: Builder, probe: BodyProbe, mats: Sequence[str], big: float = 0.085, reach: float = 0.30,
                 trim: Optional[str] = "trim_gold") -> None:
    for s in (1, -1):
        xs = [0.105, 0.135, 0.17, 0.215, 0.255, reach - 0.015, reach]
        ra = probe.arm_radius(reach)
        rs = [(0.068, 0.072), (0.076, 0.078), (big * 0.9, big * 0.9), (big, big), (big * 0.82, big * 0.82),
              (ra[0] + 0.008, ra[1] + 0.008), (ra[0] + 0.008, ra[1] + 0.008)]
        sleeve(B, s, xs, rs, list(mats), 16)
        if trim:
            sleeve(B, s, [reach - 0.004, reach + 0.008], [(ra[0] + 0.009, ra[1] + 0.009)] * 2, [trim], 16)


# --------------------------------------------------------------------------
# The six gowns.  Each returns (builder); palette colours are set in GOWNS below.
# --------------------------------------------------------------------------
def rows(n: int, mid: str = "fabric", last: Optional[str] = None, first: Optional[str] = None) -> List[str]:
    r = [mid] * n
    if last:
        r[-1] = last
    if first:
        r[0] = first
    return r


def gown_dinner(B: Builder, probe: BodyProbe, rng) -> None:
    mats = rows(9, "fabric", "trim_gold", "trim_gold")
    W, T = bodice(B, probe, SWEET, mats)
    straps(B, probe, T)
    pearl_edge(B, T, probe)
    ctrl = [(0.915, 0.185, 0.145, 0.006), (0.74, 0.215, 0.185, 0.02), (0.52, 0.26, 0.235, 0.04),
            (0.30, 0.31, 0.29, 0.065), (0.08, 0.35, 0.34, 0.09)]
    base = Profile(ctrl)
    rings = skirt(B, ctrl, 10, rows(10, "fabric"), waist=W, fold=(0.05, 8, 0.4),
                  hem=("scallop", 0.035, 8, 0.0), hem_from=0.7, lmax=0.85)
    tier(base, 0.20, 0.06, 0.05, rows(3, "lining"), B, rows=4, hem=("sin", 0.015, 12, 0.5), hem_from=0.4,
         fold=(0.04, 12, 0.3), lmax=0.85)
    waist_bow(B, probe, 0.07, "trim_gold")
    bloom_cluster(B, probe, 1.0, 52, 0.03, 1)


def gown_ball(B: Builder, probe: BodyProbe, rng) -> None:
    W, T = bodice(B, probe, SCOOP, rows(9, "fabric", "trim_gold", "trim_gold"))
    pearl_edge(B, T, probe, 3, 0.0065)
    puff_sleeves(B, probe, ["fabric"] * 6, big=0.09, reach=0.27, trim="lining")
    ctrl = [(0.915, 0.19, 0.15, 0.0), (0.80, 0.29, 0.25, 0.0), (0.56, 0.45, 0.41, 0.0), (0.30, 0.55, 0.52, 0.0),
            (0.07, 0.61, 0.58, 0.0)]
    base = Profile(ctrl)
    skirt(B, ctrl, 8, rows(8, "lining"), waist=W, lmax=0.4)
    for k, (zt, zb) in enumerate(((0.84, 0.58), (0.66, 0.38), (0.48, 0.08))):
        tier(base, zt, zb, 0.07, rows(3, "fabric" if k != 1 else "lining"), B, rows=4, gap=0.012 + 0.003 * k,
             hem=("scallop", 0.03, 10, 0.5 * k), hem_from=0.5, fold=(0.03, 8 + k, k), lmax=0.4)
    for i, deg in enumerate((-65, -33, 0, 33, 65)):
        pt, n = probe.on_torso(1.0, deg, 0.02)
        i0 = len(B.bm.verts)
        B.rose(pt, n, 0.030 if i % 2 == 0 else 0.024, spin=0.5 * i, pmat="flowers" if i % 2 == 0 else "flowers_b")
        B.mark("near", i0)
    waist_bow(B, probe, 0.075, "fabric")


def gown_garden(B: Builder, probe: BodyProbe, rng) -> None:
    W, T = bodice(B, probe, SCOOP, rows(9, "fabric", "trim_gold", "fabric"))
    puff_sleeves(B, probe, ["fabric"] * 6, big=0.078, reach=0.29)
    ctrl = [(0.915, 0.185, 0.145, 0.0), (0.78, 0.26, 0.22, 0.0), (0.60, 0.34, 0.30, 0.0), (0.42, 0.40, 0.36, 0.0)]
    base = Profile(ctrl)
    skirt(B, ctrl, 7, rows(7, "fabric"), waist=W, fold=(0.04, 10, 0.0), hem=("sin", 0.02, 10, 0.0), hem_from=0.7, lmax=0.7)
    tier(base, 0.50, 0.37, 0.05, rows(3, "lining"), B, rows=4, hem=("scallop", 0.02, 16, 0.0), hem_from=0.4,
         fold=(0.04, 16, 0.0), lmax=0.7)
    i0 = len(B.bm.verts)
    for i, z in enumerate((1.14, 1.09, 1.04)):                       # pearl buttons
        pt, n = probe.on_torso(z, 0, 0.012)
        B.bead(pt, 0.0065)
    for i, (z, deg) in enumerate(((1.15, 38), (1.09, 52), (1.2, 22))):   # daisies
        pt, n = probe.on_torso(z, deg, 0.016)
        B.flower(pt, n, 0.024 - 0.003 * i, 6, "flowers_b", spin=0.4 * i)
    B.mark("near", i0)
    waist_bow(B, probe, 0.06, "trim_gold")


def gown_solstice(B: Builder, probe: BodyProbe, rng) -> None:
    W, T = bodice(B, probe, SWEET, rows(9, "fabric", "trim_gold", "trim_gold"))
    for s in (1, -1):                                                # long floaty bell sleeves
        xs = list(np.linspace(0.105, 0.72, 9))
        ra = probe.arm_radius(0.4)
        rs = [(0.070, 0.074)] + [(ra[0] + 0.012 + 0.040 * (k / 7) ** 1.8, ra[1] + 0.012 + 0.040 * (k / 7) ** 1.8)
                                  for k in range(1, 9)]
        sleeve(B, s, xs, rs, rows(8), 16, hem=(0.03, 6))
    ctrl = [(0.915, 0.185, 0.145, 0.0), (0.74, 0.25, 0.21, 0.01), (0.50, 0.33, 0.29, 0.03),
            (0.26, 0.40, 0.36, 0.05), (0.05, 0.46, 0.43, 0.07)]
    base = Profile(ctrl)
    skirt(B, ctrl, 9, rows(9, "lining"), waist=W, fold=(0.04, 7, 0.0), lmax=0.65)
    tier(base, 0.88, 0.16, 0.10, rows(3, "fabric"), B, rows=6, gap=0.012, fold=(0.07, 9, 1.0),
         hem=("sin", 0.05, 6, 0.5), hem_from=0.5, lmax=0.65)
    i0 = len(B.bm.verts)
    for k in range(11):                                              # woven flower garland across the bodice
        th = -76 + 152 * k / 10
        pt, n = probe.on_torso(1.205 + 0.03 * (th / 76) ** 2, th, 0.021)
        B.flower(pt, n, 0.021, 5, ("flowers", "flowers_b", "flowers_c")[k % 3], spin=0.5 * k)
        if k < 10:
            th2 = th + 7.6
            p2, n2 = probe.on_torso(1.193 + 0.03 * (th2 / 76) ** 2, th2, 0.017)
            t = Vector((math.cos(math.radians(th2)), math.sin(math.radians(th2)), 0))
            B.leaf(p2, t, n2, 0.017, 0.007)
    B.mark("near", i0)
    bloom_cluster(B, probe, 0.99, 50, 0.028, 4, ("flowers", "flowers_c"))


def gown_rose_petal(B: Builder, probe: BodyProbe, rng) -> None:
    W, T = bodice(B, probe, STRAIGHT, rows(9, "fabric", None, "trim_gold"))
    i0 = len(B.bm.verts)
    for i in range(16):                                              # petal collar around the neckline
        a = 2 * math.pi * (i + 0.5) / 16
        if abs(math.sin(a / 2 - 0.0)) < 0.0:
            continue
        p = Vector(T[int(i * COLS / 16 + 1) % COLS])
        out = Vector((p.x, p.y - probe.cy(p.z), 0.35)).normalized()
        side = out.cross(Vector((0, 0, 1))).normalized()
        B.ellipsoid(p + out * 0.010 + Vector((0, 0, 0.012)), side * 0.021, out.cross(side).normalized() * 0.005,
                    (out + Vector((0, 0, 1.0))).normalized() * 0.032, "fabric" if i % 2 else "lining", 6, 3)
    B.mark("near", i0)
    ctrl = [(0.915, 0.185, 0.145, 0.0), (0.74, 0.225, 0.19, 0.01), (0.52, 0.27, 0.24, 0.03), (0.28, 0.31, 0.29, 0.05),
            (0.10, 0.33, 0.31, 0.06)]
    base = Profile(ctrl)
    skirt(B, ctrl, 8, rows(8, "lining"), waist=W, lmax=0.8)
    for k, (zt, zb) in enumerate(((0.90, 0.68), (0.78, 0.52), (0.64, 0.38), (0.50, 0.24), (0.36, 0.08))):
        tier(base, zt, zb, 0.04 + 0.01 * k, rows(3, "fabric" if k % 2 == 0 else "lining"), B, rows=3,
             gap=0.010 + 0.003 * k, hem=("scallop", 0.045, 8, 0.5 * (k % 2)), hem_from=0.3,
             bulge=(0.07, 8, math.pi * (k % 2)), lmax=0.8)
    pt, n = probe.on_torso(1.01, 0, 0.022)
    i0 = len(B.bm.verts)
    B.rose(pt, n, 0.040, pmat="flowers")
    B.leaf(pt + Vector((0.045, 0, -0.012)), Vector((1, 0, -0.2)), n, 0.030, 0.011)
    B.leaf(pt + Vector((-0.045, 0, -0.012)), Vector((-1, 0, -0.2)), n, 0.030, 0.011)
    B.mark("near", i0)


def gown_starlight(B: Builder, probe: BodyProbe, rng) -> None:
    W, T = bodice(B, probe, SWEET, rows(9, "fabric", "trim_gold", "trim_gold"))
    puff_sleeves(B, probe, ["lining"] * 6, big=0.07, reach=0.22, trim=None)
    ctrl = [(0.915, 0.185, 0.145, 0.0), (0.74, 0.25, 0.21, 0.01), (0.50, 0.34, 0.30, 0.03),
            (0.26, 0.42, 0.38, 0.05), (0.06, 0.47, 0.44, 0.07)]
    base = Profile(ctrl)
    skirt(B, ctrl, 9, rows(9, "lining"), waist=W, fold=(0.03, 6, 0.0), lmax=0.65)
    over = tier(base, 0.90, 0.10, 0.09, rows(5, "fabric"), B, rows=6, gap=0.012, fold=(0.04, 6, 0.5),
                hem=("sin", 0.07, 4, 0.0), hem_from=0.5, lmax=0.65)
    scatter(B, over, rng, 34, 34, (1, 6), (0.011, 0.020), 0.65)
    i0 = len(B.bm.verts)
    for i in range(7):                                               # sparkles along the bodice
        a = math.radians(-60 + 20 * i)
        pt, n = probe.on_torso(1.12 + 0.045 * math.sin(i * 2.1), math.degrees(a), 0.013)
        B.star(pt, n, 0.012 + 0.003 * (i % 2), "trim_gold", spin=0.3 * i)
    B.mark("near", i0)
    pearl_edge(B, T, probe, 3, 0.0058)


GOWNS: Dict[str, dict] = {
    "gown_dinner": dict(fn=gown_dinner, pal={"fabric": (ROSE, 0.34, 0.0), "lining": (LILAC, 0.40, 0.0)}),
    "gown_ball": dict(fn=gown_ball, pal={"fabric": (BLUSH, 0.34, 0.0), "lining": (PEARL, 0.40, 0.0),
                                         "flowers": (ROSE, 0.45, 0.0)}),
    "gown_garden": dict(fn=gown_garden, pal={"fabric": (MINT, 0.38, 0.0), "lining": (PEARL, 0.40, 0.0)}),
    "gown_solstice": dict(fn=gown_solstice, pal={"fabric": (PERI, 0.32, 0.0), "lining": (PEARL, 0.40, 0.0)}),
    "gown_rose_petal": dict(fn=gown_rose_petal, pal={"fabric": (ROSE, 0.34, 0.0), "lining": (BLUSH, 0.40, 0.0)}),
    "gown_starlight": dict(fn=gown_starlight, pal={"fabric": (DEEP, 0.32, 0.0), "lining": (LILAC, 0.40, 0.0)}),
}


# --------------------------------------------------------------------------
# Head accessories (feyre_shape.CROWN_RING; skinned to the Head bone only)
# --------------------------------------------------------------------------
RING = fs.CROWN_RING
RING_TILT = math.tan(math.radians(RING["tilt_deg"]))
RING_UP = Vector((0, -RING_TILT, 1)).normalized()


def ring_pt(phi: float, dr: float = 0.0, dz: float = 0.0) -> Vector:
    cx, cy, cz = RING["centre"]
    y = cy - (RING["ry"] + dr) * math.cos(phi)
    return Vector((cx + (RING["rx"] + dr) * math.sin(phi), y, cz + RING_TILT * (y - cy) + dz))


def ring_out(phi: float) -> Vector:
    return Vector((math.sin(phi), -math.cos(phi), 0))


def ring_tan(phi: float) -> Vector:
    return Vector((math.cos(phi), math.sin(phi), 0))


def build_tiara(arm) -> bpy.types.Object:
    B = Builder("tiara", "trim_gold")
    span = math.radians(80)
    n = 11
    phis = np.linspace(-span, span, 41)
    band = np.array([ring_pt(p, 0.004) for p in phis])
    B.tube(band, 0.0042, 5, "trim_gold", up=RING_UP, squash=1.25, cap=True)
    tips = []
    for k in range(n):
        phi = -span + 2 * span * k / (n - 1)
        h = 0.015 + 0.022 * math.cos(phi * 1.1) ** 3
        base = ring_pt(phi, 0.004)
        tips.append((phi, base + RING_UP * h * 2.0))
        B.ellipsoid(base + RING_UP * h * 0.95, ring_tan(phi) * 0.0058, ring_out(phi) * 0.0030, RING_UP * h, "trim_gold", 6, 3)
        B.bead(base + RING_UP * (h * 2.0 + 0.003), 0.0050 + 0.0025 * (k == n // 2))
    for (p0, a), (p1, b) in zip(tips[:-1], tips[1:]):                # little scrolled arches between spires
        pm = ring_pt((p0 + p1) / 2, 0.004)
        h = (min(a.z, b.z) - pm.z) * 0.55
        path = []
        for t in np.linspace(0, 1, 7):
            phi = p0 + (p1 - p0) * t
            path.append(ring_pt(phi, 0.004) + RING_UP * (0.004 + h * math.sin(math.pi * t)))
        B.tube(np.array(path), 0.0022, 4, "trim_gold", up=RING_UP, cap=False)
        B.bead(pm + RING_UP * 0.0045, 0.0035)
    c0 = ring_pt(0.0, 0.005)
    B.ellipsoid(c0 + RING_UP * 0.016, ring_tan(0) * 0.0085, ring_out(0) * 0.0045, RING_UP * 0.013, "gem", 6, 4)
    for s in (-1, 1):
        p = ring_pt(s * math.radians(26), 0.005)
        B.ellipsoid(p + RING_UP * 0.010, ring_tan(0) * 0.0050, ring_out(0) * 0.0032, RING_UP * 0.0070, "gem", 5, 3)
    B.mark("acc", 0)
    return finalize_head(B, "tiara", arm)


def build_flower_crown(arm) -> bpy.types.Object:
    B = Builder("flower_crown", "flowers")
    nb = 9
    ring = np.array([ring_pt(p, 0.003, -0.002) for p in np.linspace(0, 2 * math.pi, 49)])
    B.tube(ring, 0.0035, 5, "leaves", up=RING_UP, cap=False)
    mats = ("flowers", "flowers_b", "flowers_c")
    for k in range(nb):
        phi = 2 * math.pi * (k + 0.5) / nb
        size = 0.040 if k % 2 == 0 else 0.034
        p = ring_pt(phi, 0.014, 0.004)
        n = (ring_out(phi) * 0.75 + RING_UP * 0.5).normalized()
        B.flower(p, n, size, 6, mats[k % 3], centre=False, u=4, v=3, spin=0.3 * k)
        B.flower(p + n * size * 0.14, n, size * 0.6, 5, mats[(k + 1) % 3], u=4, v=3, spin=0.6 + 0.3 * k)
        for s in (-1, 1):
            ph2 = phi + s * math.pi / nb
            q = ring_pt(ph2, 0.008, -0.004)
            B.leaf(q, ring_tan(ph2) * s + RING_UP * 0.1, ring_out(ph2) + RING_UP * 0.5, 0.020, 0.0075)
        pb = ring_pt(phi + math.pi / nb, 0.010, 0.006)
        B.bead(pb, 0.0045)
    B.mark("acc", 0)
    return finalize_head(B, "flower_crown", arm)


def build_woven_crown(arm) -> bpy.types.Object:
    rng = np.random.default_rng(SEED + 3)
    B = Builder("woven_crown", "fabric", {"fabric": (BUTTER, 0.55, 0.0), "flowers_b": (LILAC, 0.55, 0.0),
                                          "leaves": ("9CCFAA", 0.55, 0.0)})
    ph = rng.uniform(0, 6.28, 4)
    phis = np.linspace(0, 2 * math.pi, 67)
    for strand in (0, 1):                                            # two vines twisted round each other, unevenly
        pts = []
        for p in phis:
            amp = 0.0052 + 0.0016 * math.sin(5 * p + ph[0])
            tw = 9 * p + strand * math.pi + 0.5 * math.sin(3 * p + ph[1])
            dr = 0.004 + 0.003 * math.sin(2 * p + ph[2]) + amp * math.cos(tw)
            dz = 0.004 * math.sin(3 * p + ph[3]) + amp * math.sin(tw)
            pts.append(ring_pt(p, dr, dz))
        B.tube(np.array(pts), 0.0030 + 0.0006 * strand, 4, "leaves", up=RING_UP, cap=False)
    slots = np.sort(rng.uniform(0, 1, 13) * 0.5 + np.arange(13) / 13 * 0.5) * 2 * math.pi
    for k, phi in enumerate(slots):
        size = rng.uniform(0.022, 0.036)
        p = ring_pt(phi, 0.011 + rng.uniform(-0.002, 0.004), rng.uniform(-0.006, 0.010))
        n = (ring_out(phi) * 0.7 + RING_UP * rng.uniform(0.25, 0.7) + ring_tan(phi) * rng.uniform(-0.35, 0.35)).normalized()
        small = k % 4 == 3
        B.flower(p, n, size * (0.75 if small else 1.0), 5 if small else int(rng.integers(5, 7)),
                 "flowers_b" if small else "fabric", "flower_centers", rng=rng, u=4, v=3, spin=rng.uniform(0, 6.28))
    for k in range(16):                                              # leaves poking out at odd angles
        phi = rng.uniform(0, 2 * math.pi)
        q = ring_pt(phi, rng.uniform(0.006, 0.013), rng.uniform(-0.005, 0.008))
        along = ring_tan(phi) * rng.uniform(-1, 1) + ring_out(phi) * rng.uniform(0.3, 1) + RING_UP * rng.uniform(-0.2, 0.7)
        B.leaf(q, along, ring_out(phi) + RING_UP, rng.uniform(0.013, 0.024), rng.uniform(0.005, 0.0085))
    for k in range(6):                                               # buds
        phi = rng.uniform(0, 2 * math.pi)
        B.bead(ring_pt(phi, 0.012, rng.uniform(0.002, 0.012)), rng.uniform(0.0035, 0.005), "flowers_b", 4, 2)
    phi0 = math.pi + 0.15                                            # the knot at the back, with two loose ends
    knot = ring_pt(phi0, 0.007)
    B.bead(knot, 0.0085, "leaves", 5, 3)
    for s, length in ((1, 0.085), (-1, 0.060)):
        path = [knot + Vector((s * 0.004 * t, 0.002 * t * t, -length * t)) + ring_tan(phi0) * s * 0.012 * t * t
                for t in np.linspace(0, 1, 6)]
        B.tube(np.array(path), 0.0022, 3, "leaves", cap=False)
        B.bead(path[-1], 0.0045, "flowers_b", 4, 2)
    B.mark("acc", 0)
    return finalize_head(B, "woven_crown", arm)


# --------------------------------------------------------------------------
# Checks
# --------------------------------------------------------------------------
def positions(obj: bpy.types.Object, key: Optional[str] = None) -> Arr:
    if key is None:
        return verts_np(obj.data)
    a = np.empty(len(obj.data.vertices) * 3)
    obj.data.shape_keys.key_blocks[key].data.foreach_get("co", a)
    return a.reshape(-1, 3)


def audit(probe: BodyProbe, obj: bpy.types.Object) -> dict:
    """Poke-through (body verts of torso/legs/arms lying outside the garment) and region coverage."""
    tris = [tuple(p.vertices) for p in obj.data.polygons]
    cover_idx = [i for i in range(len(probe.P)) if REGIONS[probe.region[i]] in ("torso", "legs", "arms")]
    res = {}
    for label, Bp, Gp in (("rest", probe.P, positions(obj)), ("nourished", probe.Pn, positions(obj, "nourished"))):
        bvh = BVHTree.FromPolygons([tuple(p) for p in Gp], tris)
        covered = np.zeros(len(Bp), bool)
        poke = 0
        for i in cover_idx:
            n = Vector(probe.N[i])
            o = Vector(Bp[i])
            if bvh.ray_cast(o + n * 1e-4, n, 1.0)[0] is not None:
                covered[i] = True
            elif bvh.ray_cast(o - n * 1e-4, -n, 0.05)[0] is not None:
                poke += 1
                covered[i] = True
        res[label] = (poke, {r: float(covered[probe.region == REGIONS.index(r)].mean()) for r in ("torso", "arms", "legs")})
    res["clearance"] = (probe.clearance(positions(obj)), probe.clearance(positions(obj, "nourished"), True))
    return res


def pose_check(arm, obj: bpy.types.Object) -> str:
    def snap() -> Arr:
        bpy.context.view_layer.update()
        ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        m = ev.to_mesh()
        a = np.empty(len(m.vertices) * 3)
        m.vertices.foreach_get("co", a)
        ev.to_mesh_clear()
        return a.reshape(-1, 3).copy()

    rest = snap()
    edges = np.array([(e.vertices[0], e.vertices[1]) for e in obj.data.edges])
    L0 = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
    long = L0 > 0.01
    edges, L0 = edges[long], L0[long]
    out = []
    for bone, rot in (("LeftUpperLeg", (-60, 0, 0)), ("Spine", (20, 0, 0)), ("LeftUpperArm", (0, 0, -60))):
        pb = arm.pose.bones[bone]
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = [math.radians(a) for a in rot]
        P = snap()
        d = np.linalg.norm(P - rest, axis=1)
        L = np.linalg.norm(P[edges[:, 0]] - P[edges[:, 1]], axis=1)
        ok = np.isfinite(P).all()
        out.append("%s %.2fm x%.1f%s" % (bone[:8] + str(rot[0] or rot[2]), d.max(), (L / np.maximum(L0, 1e-6)).max(),
                                         "" if ok else " NaN"))
        pb.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    return " | ".join(out)


def export_named(path: str, obj: bpy.types.Object, arm) -> None:
    """Export with the plain material names (`fabric`, ...); the datablocks are `<object>:<name>` otherwise."""
    mats = list(obj.data.materials)
    longs = [m.name for m in mats]
    for m in mats:
        m.name = m.name.split(":")[-1]
    export_glb(path, [obj], arm)
    for m, n in zip(mats, longs):
        m.name = n


# --------------------------------------------------------------------------
def main() -> None:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(MODEL_DIR, "feyre.blend"))
    for n in [o.name for o in bpy.data.objects if o.name.startswith("hunter_") or o.name == "Body_LOD1"]:
        bpy.data.objects.remove(bpy.data.objects[n])
    body, arm = bpy.data.objects["Body"], bpy.data.objects["Armature"]
    spec = [(bn.name, tuple(bn.head_local), tuple(bn.tail_local), None, bn.use_deform) for bn in arm.data.bones]
    probe = BodyProbe(body)
    os.makedirs(WARDROBE_DIR, exist_ok=True)
    rng = np.random.default_rng(SEED)

    gowns, acc = [], []
    for name, g in GOWNS.items():
        B = Builder(name, "fabric", g["pal"])
        g["fn"](B, probe, rng)
        gowns.append(finalize_gown(B, name, probe, arm, spec))
    acc = [build_tiara(arm), build_flower_crown(arm), build_woven_crown(arm)]

    coll = bpy.data.collections.new("Wardrobe")
    bpy.context.scene.collection.children.link(coll)
    for o in gowns + acc:
        coll.objects.link(o)
        bpy.context.scene.collection.objects.unlink(o)

    lines = []
    for o in gowns + acc:
        t = tri_count(o)
        line = "%-16s tris=%4d/%d slots=%s" % (o.name, t, TRI_GOWN if o in gowns else TRI_ACC,
                                              ",".join(m.name.split(":")[-1] for m in o.data.materials))
        if o in gowns:
            a = audit(probe, o)
            cov = " ".join("%s=%.0f%%" % (r, 100 * f) for r, f in a["rest"][1].items())
            line += "\n    poke rest=%d nourished=%d | clearance %.1f/%.1f mm | covers %s\n    pose: %s" % (
                a["rest"][0], a["nourished"][0], a["clearance"][0] * 1000, a["clearance"][1] * 1000, cov,
                pose_check(arm, o))
        lines.append(line)

    bpy.context.view_layer.update()
    for o in gowns + acc:
        export_named(os.path.join(WARDROBE_DIR, o.name + ".glb"), o, arm)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WARDROBE_DIR, "gowns.blend"), compress=True)
    print("\n==== GOWN BUILD REPORT ====")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
