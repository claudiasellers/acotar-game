"""Procedural first-pass Feyre gowns and head accessories.

Reproducible build (needs characters/feyre/model/feyre.blend from build_feyre.py):
    python tools/blender/feyre/build_gowns.py

Writes (relative to the repo root):
    characters/feyre/wardrobe/gown_dinner.glb     floor-length draped dinner gown, thin straps
    characters/feyre/wardrobe/gown_ball.glb       princess ball gown, tulle tiers, little roses
    characters/feyre/wardrobe/gown_garden.glb     calf-length tea dress, puff sleeves
    characters/feyre/wardrobe/gown_solstice.glb   midsummer gown, flower garland, floaty sleeves
    characters/feyre/wardrobe/tiara.glb           gilt leaves + pearls (skinned to Head only)
    characters/feyre/wardrobe/flower_crown.glb    ring of oversized blooms + leaves (Head only)
    characters/feyre/wardrobe/gowns.blend         editable source: Feyre + all gown objects

Every gown is skinned to the same 60-bone armature as the body, carries a
`nourished` shape key copied from the body, and uses named material slots:
`fabric` (neutral near white, tinted per variant at runtime) plus accents
(`trim_gold`, `pearl`, `flowers`, `leaves`, `lining`, ...).  Tweak the numbers
in the gown_* functions and rebuild, or open gowns.blend and sculpt by hand.
"""

import math
import os
import sys

import bpy  # noqa: E402  (must come before bmesh when used as a module)
import bmesh
import numpy as np
from mathutils import Matrix, Vector, kdtree
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_feyre as bf  # noqa: E402
from build_feyre import (apply_weights, distance_weights, ensure_uvs, export_glb, make_material,  # noqa: E402
                         shell_from_body, skin_to_armature, smoothstep, tri_count, transfer_weights,
                         verts_np, REGIONS, WARDROBE_DIR, MODEL_DIR)

CLEAR = 0.008            # target clearance of loose cloth to the body (spec: >= 6 mm)
TRI_LIMIT_GOWN = 4000
TRI_LIMIT_ACC = 1500

# --------------------------------------------------------------------------
# Materials (fabric is neutral: the game tints it per variant)
# --------------------------------------------------------------------------
MATS = {
    "fabric": ((0.93, 0.93, 0.95), 0.32, 0.0),
    "trim_gold": ((0.96, 0.74, 0.26), 0.28, 0.85),
    "pearl": ((0.97, 0.95, 0.93), 0.12, 0.0),
    "flowers": ((1.00, 0.62, 0.74), 0.45, 0.0),
    "flower_centers": ((1.00, 0.85, 0.35), 0.40, 0.0),
    "leaves": ((0.50, 0.82, 0.55), 0.45, 0.0),
    "lining": ((0.99, 0.90, 0.94), 0.40, 0.0),
}


def mat(name):
    rgb, rough, metal = MATS[name]
    m = make_material(name, rgb, rough, metal, cull=False)
    bsdf = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
    if bsdf and name in ("fabric", "pearl", "flowers", "lining"):
        for key, val in (("Coat Weight", 0.35), ("Sheen Weight", 0.3)):
            if key in bsdf.inputs:
                bsdf.inputs[key].default_value = val
    return m


# --------------------------------------------------------------------------
# Geometry kit
# --------------------------------------------------------------------------
class Builder:
    """One garment = one bmesh; parts are tagged by vertex range so weights can differ per part."""

    def __init__(self, first="fabric"):
        self.bm = bmesh.new()
        self.slots = []
        self.parts = []          # (kind, i0, i1, params)
        if first:
            self.slot(first)

    def slot(self, name):
        if name not in self.slots:
            self.slots.append(name)
        return self.slots.index(name)

    def mark(self, kind, i0, **params):
        self.parts.append((kind, i0, len(self.bm.verts), params))

    def ellipsoid(self, centre, ax1, ax2, ax3, matname, u=6, v=4):
        """Squashed sphere whose axes are the vectors ax1..3 (their lengths are the radii)."""
        M = Matrix([[ax1[0], ax2[0], ax3[0], centre[0]], [ax1[1], ax2[1], ax3[1], centre[1]],
                    [ax1[2], ax2[2], ax3[2], centre[2]], [0, 0, 0, 1]])
        r = bmesh.ops.create_uvsphere(self.bm, u_segments=u, v_segments=v, radius=1.0, matrix=M)
        idx = self.slot(matname)
        for vtx in r["verts"]:
            for f in vtx.link_faces:
                f.material_index = idx

    def flower(self, c, n, size, petals, petal_mat="flowers", centre_mat="flower_centers", spin=0.0, ru=5, rv=3):
        n = Vector(n).normalized()
        t1 = n.cross(Vector((0, 0, 1)))
        if t1.length < 1e-3:
            t1 = n.cross(Vector((1, 0, 0)))
        t1.normalize()
        t2 = n.cross(t1)
        for i in range(petals):
            a = spin + 2 * math.pi * i / petals
            d = t1 * math.cos(a) + t2 * math.sin(a)
            e = n.cross(d).normalized()
            self.ellipsoid(Vector(c) + d * size * 0.55 + n * size * 0.18,
                           d * size * 0.58, e * size * 0.42, n * size * 0.24, petal_mat, ru, rv)
        self.ellipsoid(Vector(c) + n * size * 0.34, t1 * size * 0.30, t2 * size * 0.30, n * size * 0.22,
                       centre_mat, 6, 4)

    def grid(self, rings, matname_rows, closed=True):
        """rings: list of (cols,3) arrays.  matname_rows: list of material names per row.  Returns faces."""
        bm = self.bm
        vs = [[bm.verts.new(tuple(p)) for p in ring] for ring in rings]
        faces = []
        for r in range(len(vs) - 1):
            idx = self.slot(matname_rows[min(r, len(matname_rows) - 1)])
            cols = len(vs[r])
            rng = range(cols) if closed else range(cols - 1)
            for c in rng:
                c2 = (c + 1) % cols
                f = bm.faces.new((vs[r][c], vs[r][c2], vs[r + 1][c2], vs[r + 1][c]))
                f.material_index = idx
                faces.append(f)
        return faces

    def orient(self, faces, ref_fn):
        self.bm.normal_update()
        for f in faces:
            cen = f.calc_center_median()
            if f.normal.dot(ref_fn(cen)) < 0:
                f.normal_flip()


def smooth_curve(ctrl, n):
    C = np.array(ctrl, float)
    m = len(C)
    P = np.vstack([C[0] * 2 - C[1], C, C[-1] * 2 - C[-2]])
    out = []
    for s in np.linspace(0, m - 1, n):
        i = min(int(s), m - 2)
        t = s - i
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                          + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return np.array(out)


def add_skirt(B, head_rings, ctrl, nrings, cols, row_mats, fold=(0.0, 7, 0.0), wave=(0.0, 8), wave_from=0.7,
              kind="skirt", **kw):
    """Lathe skirt.  head_rings: fixed leading (z, rx, ry, cy) rings (e.g. waistband);
    ctrl: smooth profile (z, rx, ry, cy) control points that follow.  Angle 0 = front (-Y)."""
    i0 = len(B.bm.verts)
    prof = list(head_rings) + [tuple(p) for p in smooth_curve(ctrl, nrings)]
    a = 2 * math.pi * np.arange(cols) / cols
    rings = []
    n = len(prof)
    for k, (z, rx, ry, cy) in enumerate(prof):
        t = k / (n - 1)
        f = 1.0 + fold[0] * t ** 1.3 * np.sin(fold[1] * a + fold[2])
        zz = z + wave[0] * np.sin(wave[1] * a) * smoothstep(wave_from, 1.0, t) * (1.0 if k > len(head_rings) else 0.0)
        rings.append(np.stack([rx * f * np.sin(a), cy - ry * f * np.cos(a), zz], axis=1))
    faces = B.grid(rings, row_mats)
    B.orient(faces, lambda c: Vector((c.x, c.y - 0.01, 0)))
    B.mark(kind, i0, **kw)
    return rings


def add_sleeve(B, side, xs, radii, cols, mat_rows, cz=1.345, droop=0.0, wave=(0.0, 6), zoff=None):
    """Tube along the arm (T-pose, arm along +-X).  radii: (rz, ry) per ring."""
    i0 = len(B.bm.verts)
    a = 2 * math.pi * np.arange(cols) / cols
    rings = []
    n = len(xs)
    for k, (x, (rz, ry)) in enumerate(zip(xs, radii)):
        t = k / (n - 1)
        xx = x + wave[0] * np.sin(wave[1] * a) * smoothstep(0.7, 1.0, t)
        z0 = cz - droop * t * t
        rings.append(np.stack([side * xx, ry * np.cos(a), z0 + rz * np.sin(a)], axis=1))
    faces = B.grid(rings, mat_rows)
    B.orient(faces, lambda c: Vector((0, c.y, c.z - cz + droop * 0.5)))
    B.mark("sleeve", i0, side=side)


def add_bodice(B, body, base_P, nb, keep, offset=0.008, zmin=0.99):
    """Fitted bodice: torso faces of the body that pass `keep`, pushed out `offset`."""
    def ok(f):
        c = f.calc_center_median()
        return (f.verts[0].index < nb and REGIONS[f.material_index] == "torso" and c.z > zmin and keep(c))

    tmp = shell_from_body("tmp_bodice", body, base_P, ok, lambda co: offset, 100000, mat("fabric"))
    i0 = len(B.bm.verts)
    B.bm.from_mesh(tmp.data)
    for f in B.bm.faces[-len(tmp.data.polygons):]:
        f.material_index = 0
    bpy.data.objects.remove(tmp)
    B.mark("near", i0)


# --------------------------------------------------------------------------
# Body probes
# --------------------------------------------------------------------------
class BodyProbe:
    def __init__(self, body):
        me = body.data
        self.P = verts_np(me)
        kb = me.shape_keys.key_blocks["nourished"]
        a = np.empty(len(self.P) * 3)
        kb.data.foreach_get("co", a)
        self.Pn = a.reshape(-1, 3)
        tris = [tuple(p.vertices) for p in me.polygons]
        self.bvh = BVHTree.FromPolygons([tuple(p) for p in self.P], tris)
        self.bvh_n = BVHTree.FromPolygons([tuple(p) for p in self.Pn], tris)
        self.kd = kdtree.KDTree(len(self.P))
        for i, p in enumerate(self.P):
            self.kd.insert(p, i)
        self.kd.balance()
        self.delta = self.Pn - self.P

    def section(self, z):
        o = Vector((0, 0, z))
        x = self.bvh.ray_cast(o, Vector((1, 0, 0)))[0]
        yf = self.bvh.ray_cast(o, Vector((0, -1, 0)))[0]
        yb = self.bvh.ray_cast(o, Vector((0, 1, 0)))[0]
        return x.x, (yb.y - yf.y) / 2, (yb.y + yf.y) / 2

    def on_torso(self, z, theta_deg, lift=0.0):
        """Surface point + normal on the torso at height z, angle from the front (-Y)."""
        th = math.radians(theta_deg)
        d = Vector((math.sin(th), -math.cos(th), 0))
        hit = self.bvh.ray_cast(Vector((0, 0.0, z)), d)
        return hit[0] + hit[1] * lift, hit[1]

    def arm_radius(self, x):
        o = Vector((x, 0, 1.345))
        rs = []
        for d in ((0, 0, 1), (0, 0, -1), (0, 1, 0), (0, -1, 0)):
            h = self.bvh.ray_cast(o, Vector(d))[0]
            rs.append((h - o).length if h is not None else 0.04)
        return (rs[0] + rs[1]) / 2, (rs[2] + rs[3]) / 2

    def fit(self, P, idx, target=CLEAR, iters=4, nourished=False):
        """Push the selected vertices to >= target from the body surface."""
        P = P.copy()
        bvh = self.bvh_n if nourished else self.bvh
        for _ in range(iters):
            for i in idx:
                v = Vector(P[i])
                loc, nrm, _, d = bvh.find_nearest(v)
                if loc is not None and ((v - loc).dot(nrm) < 0 or d < target):
                    v = loc + nrm * target
                P[i] = v
        return P

    def clearance(self, P, nourished=False):
        bvh = self.bvh_n if nourished else self.bvh
        dmin, who = 9.0, -1
        for i, p in enumerate(P):
            v = Vector(p)
            loc, nrm, _, d = bvh.find_nearest(v)
            if (v - loc).dot(nrm) < 0:
                d = -d
            if d < dmin:
                dmin, who = d, i
        return dmin, who


# --------------------------------------------------------------------------
# Weights
# --------------------------------------------------------------------------
def top4(w):
    items = sorted(w.items(), key=lambda kv: -kv[1])[:4]
    s = sum(v for _, v in items) or 1.0
    return [(k, v / s) for k, v in items if v / s > 0.01]


def skirt_leg_weights(p, near, lmax, z_hi=0.90, z_lo=0.50):
    """Hips at the waist, easing into UpperLeg (own side) toward the hem; smooth across the centre line."""
    x, y, z = p
    k = float(smoothstep(z_hi, z_lo, z)) * lmax
    sl = float(smoothstep(-0.12, 0.12, x))
    custom = {"Hips": 1.0 - k, "LeftUpperLeg": k * sl, "RightUpperLeg": k * (1.0 - sl)}
    t = float(smoothstep(0.96, 0.88, z))        # near the waist blend toward the body-transfer weights
    out = {}
    for n, w in near.items():
        out[n] = out.get(n, 0.0) + (1.0 - t) * w
    for n, w in custom.items():
        out[n] = out.get(n, 0.0) + t * w
    return top4(out)


def compute_weights(B, P, probe, body, arm, spec):
    near_w, nn = transfer_weights(body, probe.P, P)
    out = [top4(dict(w)) for w in near_w]
    for kind, i0, i1, prm in B.parts:
        for i in range(i0, i1):
            if kind == "skirt":
                out[i] = skirt_leg_weights(P[i], dict(near_w[i]), prm.get("lmax", 0.7))
            elif kind == "sleeve":
                s = "Left" if prm["side"] > 0 else "Right"
                names = [s + "Shoulder", s + "UpperArm", s + "LowerArm", s + "Hand"]
                out[i] = distance_weights(P[i:i + 1], spec, names, k=3, power=3.0)[0]
            else:
                out[i] = top4(dict(near_w[i]))
    return out, nn


def finalize(B, name, probe, body, arm, spec, fit_kinds=("skirt", "sleeve")):
    """bmesh -> object: fit loose cloth, weights, armature, nourished key, UVs."""
    me = bpy.data.meshes.new(name)
    B.bm.to_mesh(me)
    B.bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for s in B.slots:
        me.materials.append(mat(s))
    for p in me.polygons:
        p.use_smooth = True
    P = verts_np(me)
    idx = [i for kind, i0, i1, _ in B.parts if kind in fit_kinds for i in range(i0, i1)]
    P = probe.fit(P, idx)
    me.vertices.foreach_set("co", P.ravel())
    me.update()
    w, nn = compute_weights(B, P, probe, body, arm, spec)
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
    Pn = probe.fit(P + d, range(len(P)), target=0.006, nourished=True)
    sk.data.foreach_set("co", Pn.ravel())
    sk.value = 0.0
    ensure_uvs(obj)
    return obj


# --------------------------------------------------------------------------
# Gowns
# --------------------------------------------------------------------------
def waist_rings(probe, extra_top=0.016, extra_bot=0.014):
    r0 = probe.section(1.02)
    r1 = probe.section(0.95)
    return [(1.02, r0[0] + extra_top, r0[1] + extra_top, r0[2]),
            (0.95, r1[0] + extra_bot, r1[1] + extra_bot, r1[2])]


def gown_dinner(probe, body, nb):
    B = Builder()
    add_bodice(B, body, probe.P, nb, lambda c: (c.z < 1.255) or (c.z < 1.40 and 0.05 < abs(c.x) < 0.078))
    # pearl row along the bodice top edge
    for k in range(22):
        th = -180 + 360 * k / 22
        pt, n = probe.on_torso(1.252, th, 0.017)
        B.ellipsoid(pt, Vector((0.0075, 0, 0)), Vector((0, 0.0075, 0)), Vector((0, 0, 0.0075)), "pearl", 6, 4)
    ctrl = [(0.95, 0.15, 0.108, 0.0), (0.84, 0.172, 0.126, 0.004), (0.66, 0.20, 0.155, 0.015),
            (0.46, 0.235, 0.195, 0.04), (0.26, 0.27, 0.24, 0.07), (0.035, 0.31, 0.30, 0.10)]
    n = 11
    rows = ["trim_gold"] + ["fabric"] * (n - 1) + ["trim_gold"]
    add_skirt(B, waist_rings(probe), ctrl, n, 40, rows, fold=(0.04, 9, 0.5), wave=(0.012, 9), lmax=0.85)
    return B


def gown_ball(probe, body, nb):
    B = Builder()
    add_bodice(B, body, probe.P, nb,
               lambda c: c.z < (1.29 - (0.035 * max(0.0, 1.0 - abs(c.x) / 0.09) if c.y < 0 else 0.0)))
    # lining / underskirt, then stacked tulle shells
    hr = waist_rings(probe)
    base = [(0.95, 0.15, 0.108, 0.0), (0.86, 0.24, 0.19, 0.0), (0.66, 0.43, 0.38, 0.0),
            (0.40, 0.58, 0.54, 0.0), (0.06, 0.70, 0.66, 0.0)]
    n = 8
    add_skirt(B, hr, base, n, 36, ["trim_gold"] + ["lining"] * n, lmax=0.4)
    for k in range(1, 4):
        sc = 1.0 + 0.05 * k
        layer = [(0.95 + 0.0 * k, hr[1][1] + 0.008 * k, hr[1][2] + 0.008 * k, 0.0)]
        layer += [(z + 0.0, rx * sc + 0.012 * k, ry * sc + 0.012 * k, cy) for z, rx, ry, cy in
                  [(0.84, 0.25, 0.20, 0), (0.62, 0.45, 0.40, 0), (0.36, 0.60, 0.56, 0), (0.06 + 0.07 * k, 0.70, 0.66, 0)]]
        add_skirt(B, [], layer, 7, 36, ["fabric"] * 8, fold=(0.03, 8 + k, k), wave=(0.02, 12 + 2 * k),
                  wave_from=0.8, lmax=0.4)
    # little roses at the waist
    for k, th in enumerate((-62, -31, 0, 31, 62)):
        pt, n_ = probe.on_torso(1.0, th, 0.018)
        B.flower(pt, n_, 0.021 if k % 2 else 0.025, 5, spin=0.4 * k)
        B.flower(pt + n_ * 0.011, n_, 0.012, 4, spin=0.9 + k)
    return B


def gown_garden(probe, body, nb):
    B = Builder()
    add_bodice(B, body, probe.P, nb,
               lambda c: abs(c.x) > 0.075 or c.z < (1.30 - (0.05 * (1 - (c.x / 0.075) ** 2) if c.y < 0 else -0.04)))
    ctrl = [(0.95, 0.15, 0.108, 0.0), (0.86, 0.20, 0.15, 0.0), (0.68, 0.30, 0.25, 0.0), (0.44, 0.40, 0.34, 0.0)]
    n = 8
    add_skirt(B, waist_rings(probe), ctrl, n, 40, ["trim_gold"] + ["fabric"] * n,
              fold=(0.05, 10, 0.0), wave=(0.03, 10), wave_from=0.75, lmax=0.7)
    # petticoat peeking under the hem
    ctrl2 = [(0.95, 0.14, 0.10, 0.0), (0.86, 0.19, 0.14, 0.0), (0.66, 0.28, 0.23, 0.0), (0.38, 0.385, 0.325, 0.0)]
    add_skirt(B, [], ctrl2, 5, 40, ["lining"] * 5, wave=(0.02, 10), wave_from=0.75, lmax=0.7)
    # puff sleeves
    for side in (1, -1):
        xs = [0.13, 0.17, 0.215, 0.26, 0.295]
        ra = probe.arm_radius(0.2)
        rs = [(ra[0] + 0.012, ra[1] + 0.012), (0.075, 0.075), (0.088, 0.088), (0.072, 0.072), (ra[0] + 0.006, ra[1] + 0.006)]
        add_sleeve(B, side, xs, rs, 16, ["fabric", "fabric", "fabric", "fabric"], droop=0.0)
        add_sleeve(B, side, [0.292, 0.3], [(ra[0] + 0.006, ra[1] + 0.006)] * 2, 16, ["trim_gold"])
    # little daisies down the front of the bodice
    for k, z in enumerate((1.04, 1.10, 1.16)):
        pt, n_ = probe.on_torso(z, 0, 0.017)
        B.flower(pt, n_, 0.016, 5, spin=0.3 * k)
    return B


def gown_solstice(probe, body, nb):
    B = Builder()
    add_bodice(B, body, probe.P, nb,
               lambda c: abs(c.x) > 0.085 or c.z < (1.27 - (0.045 * (1 - (c.x / 0.085) ** 2) if c.y < 0 else -0.05)))
    hr = waist_rings(probe)
    under = [(0.95, 0.15, 0.108, 0.0), (0.84, 0.20, 0.15, 0.0), (0.62, 0.30, 0.25, 0.01),
             (0.34, 0.40, 0.35, 0.03), (0.05, 0.47, 0.43, 0.06)]
    add_skirt(B, hr, under, 7, 36, ["trim_gold"] + ["lining"] * 7, fold=(0.04, 7, 0.0), wave=(0.015, 9), lmax=0.65)
    over = [(0.95, hr[1][1] + 0.008, hr[1][2] + 0.008, 0.0), (0.84, 0.225, 0.175, 0.0), (0.66, 0.34, 0.29, 0.01),
            (0.50, 0.42, 0.37, 0.02)]
    add_skirt(B, [], over, 6, 36, ["fabric"] * 6, fold=(0.06, 9, 1.0), wave=(0.05, 9), wave_from=0.6, lmax=0.65)
    # long floaty sleeves
    for side in (1, -1):
        xs = list(np.linspace(0.13, 0.80, 8))
        ra = probe.arm_radius(0.3)
        rs = [(ra[0] + 0.012 + 0.05 * (k / 7) ** 1.6, ra[1] + 0.012 + 0.05 * (k / 7) ** 1.6) for k in range(8)]
        add_sleeve(B, side, xs, rs, 14, ["fabric"] * 7, droop=0.03, wave=(0.03, 7))
    # flower garland across the bodice (a swag over the chest) + leaves
    for k in range(11):
        th = -75 + 150 * k / 10
        z = 1.205 + 0.03 * (th / 75.0) ** 2
        pt, n_ = probe.on_torso(z, th, 0.021)
        B.flower(pt, n_, 0.019, 5, spin=0.5 * k)
        t = Vector((math.cos(math.radians(th)), math.sin(math.radians(th)), 0))
        if k < 10:
            th2 = th + 7.5
            z2 = 1.205 + 0.03 * (th2 / 75.0) ** 2 - 0.012
            p2, n2 = probe.on_torso(z2, th2, 0.017)
            B.ellipsoid(p2, t * 0.016, n2.cross(t).normalized() * 0.007, n2 * 0.004, "leaves", 5, 3)
    return B


# --------------------------------------------------------------------------
# Head accessories (skinned only to Head)
# --------------------------------------------------------------------------
def head_radius_fn(body, hair, zc):
    pts = [Vector(v.co) for v in body.data.vertices if abs(v.co.z - zc) < 0.02 and v.co.z > 1.45]
    pts += [Vector(v.co) for v in hair.data.vertices if abs(v.co.z - zc) < 0.02]
    c = bf.HEAD_C
    bins = np.zeros(72)
    for p in pts:
        a = math.atan2(p.x - c.x, -(p.y - c.y))      # 0 = front
        k = int(((a + math.pi) / (2 * math.pi)) * 72) % 72
        bins[k] = max(bins[k], math.hypot(p.x - c.x, p.y - c.y))
    for _ in range(2):
        bins = np.maximum(bins, np.maximum(np.roll(bins, 1), np.roll(bins, -1)) * 0.98)
    base = float(np.median(bins[bins > 0])) if (bins > 0).any() else 0.09

    def R(a):
        k = int(((a + math.pi) / (2 * math.pi)) * 72) % 72
        return (bins[k] if bins[k] > 0 else base) + 0.004
    return R


def accessory_finish(B, name, arm):
    me = bpy.data.meshes.new(name)
    B.bm.to_mesh(me)
    B.bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for s in B.slots:
        me.materials.append(mat(s))
    for p in me.polygons:
        p.use_smooth = True
    g = obj.vertex_groups.new(name="Head")
    g.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    skin_to_armature(obj, arm)
    ensure_uvs(obj)
    return obj


def build_tiara(body, hair, arm):
    B = Builder(None)
    zc = 1.575
    R = head_radius_fn(body, hair, zc + 0.02)
    c = bf.HEAD_C
    span = math.radians(72)

    def pt(phi):
        r = R(phi) + 0.003
        z = zc + 0.032 * math.cos(phi * 1.25) ** 2
        return Vector((c.x + r * math.sin(phi), c.y - r * math.cos(phi), z)), r

    # band: small tube
    n = 31
    sec = 5
    rings = []
    for k in range(n):
        phi = -span + 2 * span * k / (n - 1)
        p, r = pt(phi)
        p2, _ = pt(phi + 0.01)
        p1, _ = pt(phi - 0.01)
        T = (p2 - p1).normalized()
        up = Vector((0, 0, 1))
        N = T.cross(up).normalized()
        U = N.cross(T).normalized()
        ring = []
        for j in range(sec):
            a = 2 * math.pi * j / sec
            ring.append(tuple(p + N * 0.0035 * math.cos(a) + U * 0.0045 * math.sin(a)))
        rings.append(np.array(ring))
    i0 = len(B.bm.verts)
    faces = B.grid(rings, ["trim_gold"])
    centres = [np.mean(r, axis=0) for r in rings]
    B.orient(faces, lambda cc: cc - Vector(min(centres, key=lambda q: (Vector(q) - cc).length_squared)))
    # leaves + pearls
    for k in range(9):
        phi = -span * 0.86 + 2 * span * 0.86 * k / 8
        p, r = pt(phi)
        out = Vector((math.sin(phi), -math.cos(phi), 0))
        T = Vector((math.cos(phi), math.sin(phi), 0))
        h = 0.020 + 0.022 * math.cos(phi * 1.25) ** 3
        tilt = out * 0.004
        B.ellipsoid(p + Vector((0, 0, h * 0.95)) + tilt, T * 0.0065, out * 0.0028, Vector((0, 0, h)), "trim_gold", 6, 4)
        B.ellipsoid(p + Vector((0, 0, h * 2.0)) + tilt, Vector((0.0055, 0, 0)), Vector((0, 0.0055, 0)),
                    Vector((0, 0, 0.0055)), "pearl", 6, 4)
        if k < 8:
            pb, _ = pt(phi + span * 0.86 / 4)
            B.ellipsoid(pb + out * 0.002 + Vector((0, 0, 0.005)), Vector((0.0048, 0, 0)), Vector((0, 0.0048, 0)),
                        Vector((0, 0, 0.0048)), "pearl", 6, 4)
    B.mark("acc", 0)
    return accessory_finish(B, "tiara", arm)


def build_flower_crown(body, hair, arm):
    B = Builder(None)
    zc = 1.585
    R = head_radius_fn(body, hair, zc + 0.01)
    c = bf.HEAD_C
    nb_ = 7
    for k in range(nb_):
        phi = 2 * math.pi * (k + 0.5) / nb_ - math.pi
        r = R(phi) + 0.012
        z = zc + 0.012 * math.cos(phi)
        p = Vector((c.x + r * math.sin(phi), c.y - r * math.cos(phi), z))
        out = Vector((math.sin(phi), -math.cos(phi), 0.25)).normalized()
        B.flower(p, out, 0.030 if k % 2 == 0 else 0.026, 5, spin=0.35 * k)
        # leaves either side
        T = Vector((math.cos(phi), math.sin(phi), 0))
        for s in (-1, 1):
            phi2 = phi + s * math.pi / nb_
            r2 = R(phi2) + 0.006
            p2 = Vector((c.x + r2 * math.sin(phi2), c.y - r2 * math.cos(phi2), zc + 0.012 * math.cos(phi2) - 0.004))
            o2 = Vector((math.sin(phi2), -math.cos(phi2), 0))
            T2 = Vector((math.cos(phi2), math.sin(phi2), 0))
            B.ellipsoid(p2, T2 * 0.022 * s, o2 * 0.006, Vector((0, 0, 0.009)), "leaves", 5, 3)
    B.mark("acc", 0)
    return accessory_finish(B, "flower_crown", arm)


# --------------------------------------------------------------------------
# Checks
# --------------------------------------------------------------------------
def pose_check(arm, obj):
    def snap():
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
    out = []
    worst = {"disp": 0.0, "over": 0, "stretch": 0.0, "nan": False}
    for bone in ("LeftUpperLeg", "RightUpperLeg"):
        for axis, label in ((0, "x"), (2, "z")):
            for deg in (40, -40):
                pb = arm.pose.bones[bone]
                pb.rotation_mode = "XYZ"
                e = [0, 0, 0]
                e[axis] = math.radians(deg)
                pb.rotation_euler = e
                P = snap()
                d = np.linalg.norm(P - rest, axis=1)
                piv = np.array(pb.bone.head_local)
                bound = 2.0 * np.linalg.norm(rest - piv, axis=1) * math.sin(math.radians(abs(deg)) / 2.0) + 1e-4
                over = int((d > bound * 1.05).sum())
                L = np.linalg.norm(P[edges[:, 0]] - P[edges[:, 1]], axis=1)
                stretch = float((L / np.maximum(L0, 1e-6)).max())
                worst["disp"] = max(worst["disp"], float(d.max()))
                worst["over"] += over
                worst["stretch"] = max(worst["stretch"], stretch)
                worst["nan"] |= bool(not np.isfinite(P).all())
                pb.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    return worst


# --------------------------------------------------------------------------
def main():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(MODEL_DIR, "feyre.blend"))
    for n in [o.name for o in bpy.data.objects if o.name.startswith("hunter_") or o.name == "Body_LOD1"]:
        bpy.data.objects.remove(bpy.data.objects[n])
    body = bpy.data.objects["Body"]
    arm = bpy.data.objects["Armature"]
    hair = bpy.data.objects["Hair_Braid"]
    spec = [(bn.name, tuple(bn.head_local), tuple(bn.tail_local), None, bn.use_deform) for bn in arm.data.bones]
    probe = BodyProbe(body)
    nb = infer_body_verts(body)
    os.makedirs(WARDROBE_DIR, exist_ok=True)

    coll = bpy.data.collections.new("Wardrobe_Gowns")
    bpy.context.scene.collection.children.link(coll)
    results = []
    gowns = []
    for name, fn in (("gown_dinner", gown_dinner), ("gown_ball", gown_ball),
                     ("gown_garden", gown_garden), ("gown_solstice", gown_solstice)):
        B = fn(probe, body, nb)
        o = finalize(B, name, probe, body, arm, spec)
        gowns.append(o)
    acc = [build_tiara(body, hair, arm), build_flower_crown(body, hair, arm)]
    for o in gowns + acc:
        coll.objects.link(o)
        bpy.context.scene.collection.objects.unlink(o)

    report = []
    for o in gowns + acc:
        P = verts_np(o.data)
        line = "%-14s tris=%5d verts=%5d slots=%s" % (o.name, tri_count(o), len(o.data.vertices),
                                                      [m.name for m in o.data.materials])
        if o in gowns:
            c0, w0 = probe.clearance(P)
            kb = o.data.shape_keys.key_blocks["nourished"]
            a = np.empty(len(P) * 3)
            kb.data.foreach_get("co", a)
            c1, w1 = probe.clearance(a.reshape(-1, 3), nourished=True)
            pc = pose_check(arm, o)
            line += "\n    min clearance rest=%.1f mm nourished=%.1f mm | pose UpperLeg +-40 (x,z): max disp=%.3f m," \
                    " verts over rigid bound=%d, max edge stretch=x%.2f, NaN=%s | limit %d tris %s" % (
                        c0 * 1000, c1 * 1000, pc["disp"], pc["over"], pc["stretch"], pc["nan"], TRI_LIMIT_GOWN,
                        "OK" if tri_count(o) <= TRI_LIMIT_GOWN else "OVER")
        else:
            line += "  groups=%s limit %d %s" % ([g.name for g in o.vertex_groups], TRI_LIMIT_ACC,
                                                 "OK" if tri_count(o) <= TRI_LIMIT_ACC else "OVER")
        report.append(line)
    report.append("bones = %d" % len(arm.data.bones))

    bpy.context.view_layer.update()
    for o in gowns + acc:
        export_glb(os.path.join(WARDROBE_DIR, o.name + ".glb"), [o], arm)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WARDROBE_DIR, "gowns.blend"), compress=True)
    print("\n==== GOWN BUILD REPORT ====")
    print("\n".join(report))


def infer_body_verts(body):
    """Neck-down verts come first in the Body mesh, the head shell is appended after them."""
    me = body.data
    n = len(me.vertices)
    # the head shell is a separate connected island at the end of the vertex list
    adj = [[] for _ in range(n)]
    for e in me.edges:
        a, b = e.vertices
        adj[a].append(b)
        adj[b].append(a)
    seen = np.zeros(n, bool)
    comps = []
    for s in range(n):
        if seen[s]:
            continue
        stack, comp = [s], []
        seen[s] = True
        while stack:
            v = stack.pop()
            comp.append(v)
            for w in adj[v]:
                if not seen[w]:
                    seen[w] = True
                    stack.append(w)
        comps.append((min(comp), len(comp)))
    comps.sort()
    return comps[-1][0] if len(comps) > 1 else n


if __name__ == "__main__":
    main()
