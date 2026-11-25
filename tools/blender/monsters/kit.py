"""Monster kit, part 1: forms, the sculpt, the game mesh and its baked textures.

Every monster is one generator script in this folder that calls the kit:

    forms (tubes, ellipsoids)  ->  union()      one watertight sculpt (voxel remesh)
    cutters                    ->  carve()      mouth, sockets, nostrils
    numpy fields               ->  displace()   muscle, ridges, folds
    sculpt + hard parts        ->  game_mesh()  decimated to the triangle budget
    procedural materials       ->  bake()       albedo, normal and ORM maps (WebP)

The sculpt carries the form; the micro surface (scales, pores, cracks) is a
procedural bump in the sculpt's material and reaches the game mesh through the
normal map. Hard parts (teeth, claws, horns, eyes) are modelled directly at
game resolution and baked from themselves, so they stay crisp.

Deterministic: no randomness beyond seeded hashes, so regenerating a monster
gives the same files (R15).

Axes: +y is forward, +z is up, +x is the creature's right. Metres.
"""

import math
import os

import bpy
import bmesh  # after bpy: the module only exists once bpy is loaded
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))


# ------------------------------------------------------------------ scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.render.fps = 30
    return scn


def _link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def activate(obj, also=()):
    bpy.ops.object.select_all(action="DESELECT")
    for o in also:
        o.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_modifier(obj, mod):
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def join(objs, name):
    objs = [o for o in objs if o is not None]
    activate(objs[0], objs)
    if len(objs) > 1:
        bpy.ops.object.join()
    out = bpy.context.view_layer.objects.active
    out.name = name
    out.data.name = name
    return out


def duplicate(obj, name):
    c = obj.copy()
    c.data = obj.data.copy()
    c.name = name
    c.data.name = name
    return _link(c)


def tris(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


# ------------------------------------------------------------------ numpy access

def co(obj):
    P = np.empty(len(obj.data.vertices) * 3, dtype=np.float64)
    obj.data.vertices.foreach_get("co", P)
    return P.reshape(-1, 3)


def set_co(obj, P):
    obj.data.vertices.foreach_set("co", np.asarray(P, dtype=np.float64).ravel())
    obj.data.update()


def normals(obj):
    N = np.empty(len(obj.data.vertices) * 3, dtype=np.float64)
    obj.data.vertices.foreach_get("normal", N)
    return N.reshape(-1, 3)


def sat(x):
    return np.clip(x, 0.0, 1.0)


def ss(x):
    x = sat(x)
    return x * x * (3.0 - 2.0 * x)


def seg_dist(P, a, b):
    """Distance of each point to segment ab, and the parameter along it."""
    a = np.asarray(a, dtype=np.float64)
    b = np.asarray(b, dtype=np.float64)
    ab = b - a
    t = sat(((P - a) @ ab) / max(float(ab @ ab), 1e-12))
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1), t


def path_dist(P, pts):
    d = np.full(len(P), 1e9)
    for a, b in zip(pts[:-1], pts[1:]):
        d = np.minimum(d, seg_dist(P, a, b)[0])
    return d


def hash3(P, seed=0.0):
    """Cheap deterministic hash in 0..1 per point."""
    h = np.sin(P[:, 0] * 127.1 + P[:, 1] * 311.7 + P[:, 2] * 74.7 + seed * 19.19) * 43758.5453
    return h - np.floor(h)


# ------------------------------------------------------------------ forms
# A form is a lump of clay: a mesh (for the voxel union's topology) plus a
# signed distance function and a blend radius. union() melts the forms into
# each other by their blend radii, so a muscle reads as a swell under the skin
# and not as a ball glued on.

_SDF = {}          # object name -> (sdf(P) -> distances, blend radius k, (lo, hi) bounds)


def _register(obj, fn, k, lo, hi):
    _SDF[obj.name] = (fn, k, (np.asarray(lo) - 0.02, np.asarray(hi) + 0.02))
    return obj


def _ellipsoid_sdf(q, r):
    """iq's bound for an ellipsoid; q in the ellipsoid's frame."""
    k0 = np.linalg.norm(q / r, axis=1)
    k1 = np.linalg.norm(q / (r * r), axis=1)
    return np.where(k1 > 1e-9, k0 * (k0 - 1.0) / np.maximum(k1, 1e-9), -float(np.min(r)))


def _catmull(pts, vals, n):
    """Resamples a polyline and its per-point values to n samples (Catmull-Rom)."""
    pts = [np.asarray(p, dtype=np.float64) for p in pts]
    vals = [np.asarray(v, dtype=np.float64) for v in vals]
    seg_len = [np.linalg.norm(b - a) for a, b in zip(pts[:-1], pts[1:])]
    total = sum(seg_len)
    out_p, out_v = [], []
    for i in range(n):
        s = total * i / (n - 1)
        k = 0
        while k < len(seg_len) - 1 and s > seg_len[k]:
            s -= seg_len[k]
            k += 1
        u = min(s / max(seg_len[k], 1e-9), 1.0)

        def cr(arr):
            p0 = arr[max(k - 1, 0)]
            p1, p2 = arr[k], arr[k + 1]
            p3 = arr[min(k + 2, len(arr) - 1)]
            return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u
                          + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)
        out_p.append(cr(pts))
        out_v.append(np.maximum(cr(vals), 1e-4))
    return out_p, out_v


def _frames(C, side):
    """Parallel-transported (x, y, tangent) frames along a sampled centreline."""
    n = len(C)
    side = np.asarray(side, dtype=np.float64)
    X, Y, T = [], [], []
    prev = None
    for i in range(n):
        t = C[min(i + 1, n - 1)] - C[max(i - 1, 0)]
        t = t / max(np.linalg.norm(t), 1e-9)
        x = (side if prev is None else prev)
        x = x - t * (x @ t)
        if np.linalg.norm(x) < 1e-6:
            x = np.cross(t, (0, 0, 1.0))
        x = x / np.linalg.norm(x)
        prev = x
        X.append(x)
        Y.append(np.cross(t, x))
        T.append(t)
    return np.array(X), np.array(Y), np.array(T)


def tube(name, pts, radii, side=(1, 0, 0), k=0.02, segs=20, rings_per_m=60, cap=1.0):
    """A lofted limb through `pts`. `radii` is one number or an (a, b) pair per
    point: a = half width along `side`, b = half depth across it. Ends are
    rounded (`cap` scales how far they bulge). `k` is the blend radius."""
    radii = [(r, r) if np.isscalar(r) else tuple(r) for r in radii]
    length = sum(np.linalg.norm(np.subtract(b, a)) for a, b in zip(pts[:-1], pts[1:]))
    n = max(int(length * rings_per_m), 2 * len(pts), 6)
    C, R = _catmull(pts, radii, n)
    X, Y, T = _frames(C, side)
    bm = bmesh.new()
    rings = []

    def ring(center, x, y, a, b):
        return [bm.verts.new(center + x * (a * math.cos(2 * math.pi * j / segs)) + y * (b * math.sin(2 * math.pi * j / segs)))
                for j in range(segs)]

    CAP = 5
    for kk in range(CAP, 0, -1):          # start cap, pole first
        ang = (math.pi / 2) * kk / CAP
        a, b = R[0]
        rings.append(ring(C[0] - T[0] * (min(a, b) * math.sin(ang) * cap), X[0], Y[0],
                          max(a * math.cos(ang), 1e-4), max(b * math.cos(ang), 1e-4)))
    for i in range(n):
        rings.append(ring(C[i], X[i], Y[i], R[i][0], R[i][1]))
    for kk in range(1, CAP + 1):
        ang = (math.pi / 2) * kk / CAP
        a, b = R[-1]
        rings.append(ring(C[-1] + T[-1] * (min(a, b) * math.sin(ang) * cap), X[-1], Y[-1],
                          max(a * math.cos(ang), 1e-4), max(b * math.cos(ang), 1e-4)))
    for r0, r1 in zip(rings[:-1], rings[1:]):
        for j in range(segs):
            bm.faces.new((r0[j], r0[(j + 1) % segs], r1[(j + 1) % segs], r1[j]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = _link(bpy.data.objects.new(name, me))

    # the distance field: a denser resample of the same loft
    m = max(int(length * 220), 8)
    Cs, Rs = _catmull(pts, radii, m)
    Cs, Rs = np.array(Cs), np.array(Rs)
    Xs, Ys, Ts = _frames(list(Cs), side)

    def sdf(P):
        if len(P) > 20000:                   # in slices: the distance table is points x samples
            return np.concatenate([sdf(P[j:j + 20000]) for j in range(0, len(P), 20000)])
        d2 = ((P[:, None, :] - Cs[None, :, :]) ** 2).sum(axis=2)
        i = np.argmin(d2, axis=1)
        rel = P - Cs[i]
        u = (rel * Xs[i]).sum(axis=1)
        v = (rel * Ys[i]).sum(axis=1)
        w = (rel * Ts[i]).sum(axis=1)
        a, b = Rs[i, 0], Rs[i, 1]
        r = np.sqrt(u * u + v * v)
        s = np.sqrt((u / a) ** 2 + (v / b) ** 2)
        d = np.where(s > 1e-6, r * (1.0 - 1.0 / np.maximum(s, 1e-6)), -np.minimum(a, b))
        end = ((i == 0) & (w < 0)) | ((i == m - 1) & (w > 0))
        if end.any():
            c = np.maximum(np.minimum(a, b) * cap, 1e-4)
            q = np.stack([u, v, w], axis=1)[end]
            rr = np.stack([a, b, c], axis=1)[end]
            k0 = np.linalg.norm(q / rr, axis=1)
            k1 = np.linalg.norm(q / (rr * rr), axis=1)
            d[end] = np.where(k1 > 1e-9, k0 * (k0 - 1.0) / np.maximum(k1, 1e-9), -c[end])
        return d

    rmax = float(Rs.max())
    return _register(obj, sdf, k, Cs.min(axis=0) - rmax, Cs.max(axis=0) + rmax)


def ellipsoid(name, center, radii, rot=(0, 0, 0), k=0.03, segs=24):
    """An ellipsoid lump of clay; `rot` is XYZ euler in degrees; `k` the blend radius."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2, radius=1.0)
    o = bpy.context.view_layer.objects.active
    o.name = name
    r = np.array(radii if not np.isscalar(radii) else (radii,) * 3, dtype=np.float64)
    Rm = (Matrix.Rotation(math.radians(rot[2]), 4, "Z") @ Matrix.Rotation(math.radians(rot[1]), 4, "Y")
          @ Matrix.Rotation(math.radians(rot[0]), 4, "X"))
    o.data.transform(Matrix.Translation(center) @ Rm @ Matrix.Diagonal((r[0], r[1], r[2], 1.0)))
    R3 = np.array(Rm.to_3x3())
    c = np.asarray(center, dtype=np.float64)

    def sdf(P):
        return _ellipsoid_sdf((P - c) @ R3, r)

    rm = float(r.max())
    return _register(o, sdf, k, c - rm, c + rm)


def horn(name, base, tip, radius, bend=(0, 0, 0), segs=8, rings=7, flat=1.0, tip_r=0.04):
    """A curved, pointed hard part (tooth, claw, horn, spine) at game resolution.
    `bend` pulls the middle of the curve sideways (a vector, metres); `flat`
    squashes the section across the bend (1 = round)."""
    base = np.asarray(base, dtype=np.float64)
    tip = np.asarray(tip, dtype=np.float64)
    bend = np.asarray(bend, dtype=np.float64)
    axis = tip - base
    length = np.linalg.norm(axis)
    axis /= max(length, 1e-9)
    x = bend - axis * (bend @ axis)
    if np.linalg.norm(x) < 1e-6:
        x = np.cross(axis, (0.0, 0.0, 1.0))
        if np.linalg.norm(x) < 1e-6:
            x = np.array((1.0, 0.0, 0.0))
    x /= np.linalg.norm(x)
    y = np.cross(axis, x)
    bm = bmesh.new()
    loops = []
    for i in range(rings):
        u = i / (rings - 1)
        c = base + (tip - base) * u + bend * (4.0 * u * (1.0 - u)) * 0.5
        r = radius * ((1.0 - u) ** 0.8 * (1.0 - tip_r) + tip_r)
        loops.append([bm.verts.new(c + x * (r * math.cos(2 * math.pi * j / segs))
                                   + y * (r * flat * math.sin(2 * math.pi * j / segs))) for j in range(segs)])
    apex = bm.verts.new(tip + bend * 0.0)
    for r0, r1 in zip(loops[:-1], loops[1:]):
        for j in range(segs):
            bm.faces.new((r0[j], r0[(j + 1) % segs], r1[(j + 1) % segs], r1[j]))
    for j in range(segs):
        bm.faces.new((loops[-1][j], loops[-1][(j + 1) % segs], apex))
    bm.faces.new(list(reversed(loops[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = _link(bpy.data.objects.new(name, me))
    # "grad": 0 at the root, 1 at the point, for root-to-tip colour
    P = co(obj)
    u = sat(((P - base) @ axis) / max(length, 1e-9))
    attr = me.color_attributes.new("grad", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.stack([u, u, u, np.ones_like(u)], axis=1).astype(np.float32).ravel())
    shade_smooth(obj)
    return obj


def ribbon(name, pts, widths, face, thick=0.004, ragged=0.0, seed=0.0, rings=None):
    """A strip of cloth at game resolution (a torn hem, a veil's tail): a thin
    closed loft through `pts`, `widths` wide, its flat side facing `face`,
    ending in a point. `ragged` (0..1) makes the edges uneven. Carries "grad",
    0 at the root and 1 at the tip."""
    n = rings or len(pts)
    C, W = _catmull(pts, [(w, w) for w in widths], n)
    face = np.asarray(face, dtype=np.float64)
    bm = bmesh.new()
    loops, us = [], []
    for i in range(n):
        t = C[min(i + 1, n - 1)] - C[max(i - 1, 0)]
        t /= max(np.linalg.norm(t), 1e-9)
        across = np.cross(t, face)
        across /= max(np.linalg.norm(across), 1e-9)
        out = np.cross(across, t)
        h1 = math.sin(i * 12.9898 + seed * 78.233) * 43758.5453
        h2 = math.sin(i * 39.3467 + seed * 11.135) * 24634.6345
        h1, h2 = h1 - math.floor(h1) - 0.5, h2 - math.floor(h2) - 0.5
        w = W[i][0] * (1.0 + ragged * 0.9 * h1) * 0.5
        c = C[i] + across * (W[i][0] * ragged * 0.35 * h2 * (i > 0))
        loops.append([bm.verts.new(c + across * w), bm.verts.new(c + out * (thick * 0.5)),
                      bm.verts.new(c - across * w), bm.verts.new(c - out * (thick * 0.5))])
        us.extend([i / n] * 4)
    t = C[-1] - C[-2]
    apex = bm.verts.new(C[-1] + t / max(np.linalg.norm(t), 1e-9) * W[-1][0] * 1.2)
    us.append(1.0)
    for r0, r1 in zip(loops[:-1], loops[1:]):
        for j in range(4):
            bm.faces.new((r0[j], r0[(j + 1) % 4], r1[(j + 1) % 4], r1[j]))
    for j in range(4):
        bm.faces.new((loops[-1][j], loops[-1][(j + 1) % 4], apex))
    bm.faces.new(list(reversed(loops[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # the two long edges stay hard, so each side shades as flat cloth
    for r0, r1 in zip(loops, loops[1:] + [[apex] * 4]):
        for j in (0, 2):
            e = bm.edges.get((r0[j], r1[j]))
            if e is not None:
                e.smooth = False
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = _link(bpy.data.objects.new(name, me))
    u = np.array(us)
    attr = me.color_attributes.new("grad", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.stack([u, u, u, np.ones_like(u)], axis=1).astype(np.float32).ravel())
    shade_smooth(obj)
    return obj


def ball(name, center, radius, segs=12, rings=8):
    """A game-resolution sphere (an eye)."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=radius, location=center)
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix.Identity(4)
    shade_smooth(o)
    return o


def tag(obj, part):
    """Marks every vertex of a piece with a part number that survives joining,
    so the rig can bind hard parts to their bones (0 = the skinned body)."""
    attr = obj.data.attributes.get("part") or obj.data.attributes.new("part", "INT", "POINT")
    attr.data.foreach_set("value", [part] * len(obj.data.vertices))
    return obj


def parts_of(obj):
    a = obj.data.attributes.get("part")
    out = np.zeros(len(obj.data.vertices), dtype=np.int32)
    if a is not None:
        a.data.foreach_get("value", out)
    return out


def mirror_x(obj, name=None):
    """A mirrored copy across the creature's midline."""
    c = duplicate(obj, name or obj.name + "_m")
    c.data.transform(Matrix.Diagonal((-1, 1, 1, 1)))
    c.data.flip_normals()
    if obj.name in _SDF:
        fn, k, (lo, hi) = _SDF[obj.name]
        flip = np.array((-1.0, 1.0, 1.0))
        _SDF[c.name] = (lambda P, fn=fn: fn(P * flip), k, (np.array((-hi[0], lo[1], lo[2])), np.array((-lo[0], hi[1], hi[2]))))
    return c


# ------------------------------------------------------------------ sculpt

def field(forms):
    """The melted clay: forms folded together with a smooth minimum, each by
    its own blend radius. Returns f(P) -> signed distance."""
    entries = [_SDF[o.name] for o in forms if o.name in _SDF]

    def f(P):
        d = np.full(len(P), 1e3)
        for fn, k, (lo, hi) in entries:
            near = np.all((P > lo - 2 * k) & (P < hi + 2 * k), axis=1)
            if not near.any():
                continue
            di = fn(P[near])
            a = d[near]
            h = np.maximum(k - np.abs(a - di), 0.0) / k
            d[near] = np.minimum(a, di) - h * h * k * 0.25
        return d
    return f


def union(objs, name, voxel=0.006, relax_iters=2, project=4, cut=()):
    """Fuses the forms into one watertight sculpt: a voxel union for the
    topology, then every vertex is pulled onto the smoothly blended surface.
    `cut` forms are pressed into that surface as pits (sockets, nostrils): no
    boolean, so the mesh stays one clean skin. Give it a few more `project`
    rounds for deep ones."""
    f0 = field(objs)
    f = f0
    if cut:
        fc = field(cut)
        for c in cut:
            _SDF.pop(c.name, None)
            bpy.data.objects.remove(c, do_unlink=True)

        def f(P):
            return np.maximum(f0(P), -fc(P))
    for o in objs:
        _SDF.pop(o.name, None)
    obj = join(objs, name)
    obj.data.remesh_voxel_size = voxel
    obj.data.remesh_voxel_adaptivity = 0.0
    obj.data.use_remesh_fix_poles = False
    activate(obj)
    bpy.ops.object.voxel_remesh()
    e = voxel * 0.5
    offs = np.array(((1, -1, -1), (-1, -1, 1), (-1, 1, -1), (1, 1, 1)), dtype=np.float64)
    for it in range(project):
        P = co(obj)
        g = np.zeros_like(P)
        for o_ in offs:                      # tetrahedral gradient
            g += o_[None, :] * f(P + o_ * e)[:, None]
        g /= np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-9)
        d = f(P)
        set_co(obj, P - g * np.clip(d, -0.03, 0.03)[:, None])
        if relax_iters and it < project - 1:
            m = obj.modifiers.new("relax", "SMOOTH")
            m.factor = 0.5
            m.iterations = relax_iters
            apply_modifier(obj, m)
    return obj


def cached(path, make):
    """Iteration aid: the sculpt's geometry is saved to `path` (an .npz) the
    first time and reloaded after. Pass None for a normal build."""
    def load():
        d = np.load(path)
        me = bpy.data.meshes.new("cached")
        me.from_pydata(d["v"].tolist(), [], d["f"].tolist())
        me.update()
        return _link(bpy.data.objects.new("cached", me))

    if path and os.path.exists(path):
        return load()
    obj = make()
    if path:
        me = obj.data
        if any(len(p.vertices) != 3 for p in me.polygons):
            activate(obj)
            m = obj.modifiers.new("tri", "TRIANGULATE")
            apply_modifier(obj, m)
        f = np.empty(len(me.polygons) * 3, dtype=np.int32)
        me.polygons.foreach_get("vertices", f)
        np.savez_compressed(path, v=co(obj), f=f.reshape(-1, 3))
        # hand back what a later run will load, so both give the same game
        # mesh and UVs and an earlier bake still fits (--keepbake)
        bpy.data.objects.remove(obj)
        return load()
    return obj


def carve(obj, cutters):
    """Subtracts cutter forms (mouth cavity, eye sockets, nostrils)."""
    for c in cutters:
        before = obj.data.copy()
        n = len(obj.data.vertices)
        m = obj.modifiers.new("carve", "BOOLEAN")
        m.operation = "DIFFERENCE"
        m.object = c
        m.solver = "EXACT"
        apply_modifier(obj, m)
        if len(obj.data.vertices) < n * 0.5:
            # the exact solver gives up on a sculpt with hollows inside it and returns scraps
            old = obj.data
            obj.data = before
            bpy.data.meshes.remove(old)
            m = obj.modifiers.new("carve", "BOOLEAN")
            m.operation = "DIFFERENCE"
            m.object = c
            m.solver = "MANIFOLD"
            apply_modifier(obj, m)
        else:
            bpy.data.meshes.remove(before)
        _SDF.pop(c.name, None)
        bpy.data.objects.remove(c, do_unlink=True)
    return obj


def drop_hollows(obj):
    """Keeps only the sculpt's outer shell: the closed pockets clay leaves
    inside a body (between a robe and the limbs in it) are deleted."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    seen, shells = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        shell, stack = [], [v]
        seen.add(v.index)
        while stack:
            u = stack.pop()
            shell.append(u)
            for e in u.link_edges:
                w = e.other_vert(u)
                if w.index not in seen:
                    seen.add(w.index)
                    stack.append(w)
        shells.append(shell)
    shells.sort(key=len, reverse=True)
    gone = [v for sh in shells[1:] for v in sh]
    if gone:
        bmesh.ops.delete(bm, geom=gone, context="VERTS")
        bm.to_mesh(obj.data)
        obj.data.update()
    bm.free()
    return len(shells) - 1


def displace(obj, field):
    """Moves each vertex along its normal by field(P, N) metres (numpy arrays)."""
    P = co(obj)
    N = normals(obj)
    set_co(obj, P + N * np.asarray(field(P, N))[:, None])


def relax(obj, iterations=3, factor=0.5, mask=None):
    """Smooths the sculpt; `mask(P)` in 0..1 limits where."""
    vg = None
    if mask is not None:
        vg = obj.vertex_groups.new(name="_relax")
        w = sat(mask(co(obj)))
        for i in np.nonzero(w > 0.01)[0]:
            vg.add([int(i)], float(w[i]), "REPLACE")
    m = obj.modifiers.new("relax", "SMOOTH")
    m.factor = factor
    m.iterations = iterations
    if vg is not None:
        m.vertex_group = vg.name
    apply_modifier(obj, m)
    if vg is not None:
        obj.vertex_groups.remove(vg)


def paint(obj, name, field):
    """Writes a 0..1 mask as a colour attribute the sculpt's material can read
    (zones: belly, ridge, wet, bone...). `field(P, N)` returns one value or RGB."""
    P, N = co(obj), normals(obj)
    v = np.asarray(field(P, N), dtype=np.float32)
    if v.ndim == 1:
        v = np.repeat(v[:, None], 3, axis=1)
    rgba = np.concatenate([sat(v), np.ones((len(P), 1), dtype=np.float32)], axis=1)
    attr = obj.data.color_attributes.get(name) or obj.data.color_attributes.new(name, "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", rgba.ravel())
    return attr


def shade_smooth(obj):
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    obj.data.update()


# ------------------------------------------------------------------ game mesh

def game_mesh(sculpt, name, budget, keep=None, keep_bias=0.8):
    """Decimates a copy of the sculpt to `budget` triangles. `keep(P)` in 0..1
    marks where detail matters (face, hands): those areas keep more of their
    density (`keep_bias` 0..1; 0.8 gives a head about a sixth of the budget)."""
    low = duplicate(sculpt, name)
    for a in [a.name for a in low.data.color_attributes]:
        low.data.color_attributes.remove(low.data.color_attributes[a])
    m = low.modifiers.new("dec", "DECIMATE")
    m.ratio = min(1.0, budget / tris(low))
    if keep is not None:
        # the collapse takes high-weight vertices first, and steeply: body 0.5, kept areas less
        w = 0.5 * (1.0 - keep_bias * sat(keep(co(low))))
        vg = low.vertex_groups.new(name="_keep")
        for i in range(len(w)):
            vg.add([i], float(w[i]), "REPLACE")
        m.vertex_group = vg.name
    apply_modifier(low, m)
    for vg in list(low.vertex_groups):
        low.vertex_groups.remove(vg)
    shade_smooth(low)
    return low


def triangulate(obj):
    """Turns every face into triangles in place (shape keys and weights kept)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def unwrap(obj, margin=0.004, boost=None, centre=(0, 0, 0)):
    """Smart-projects obj. `boost(P)` (a scale per vertex, about `centre`)
    swells parts of the mesh while it is unwrapped, so they get more texture."""
    P = co(obj)
    if boost is not None:
        c = np.array(centre)
        set_co(obj, c + (P - c) * boost(P)[:, None])
    _smart_project(obj, margin)
    if boost is not None:
        set_co(obj, P)


def _smart_project(obj, margin):
    activate(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=margin, area_weight=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")


# ------------------------------------------------------------------ materials

def sculpt_material(name, build):
    """A procedural material for a sculpt or a hard part. `build(nt, bsdf)` wires
    colour, roughness and bump into the Principled node; whatever it wires is
    what the bake captures."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    build(nt, bsdf)
    return mat


def plain(name, rgb, rough=0.5, emission=None, strength=0.0):
    def build(nt, bsdf):
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        if emission is not None:
            bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
            bsdf.inputs["Emission Strength"].default_value = strength
    return sculpt_material(name, build)


def node(nt, kind, **props):
    n = nt.nodes.new(kind)
    for k, v in props.items():
        if k.startswith("in_"):
            n.inputs[k[3:].replace("_", " ")].default_value = v
        else:
            setattr(n, k, v)
    return n


class Graph:
    """Short hands for wiring a procedural material. Values are sockets or
    plain numbers / colour tuples."""

    def __init__(self, nt):
        self.nt = nt

    def _set(self, sock, v):
        if hasattr(v, "is_linked") or isinstance(v, bpy.types.NodeSocket):
            self.nt.links.new(v, sock)
        elif isinstance(v, (tuple, list)) and len(v) == 3 and sock.type == "RGBA":
            sock.default_value = (*v, 1.0)
        else:
            sock.default_value = v

    def position(self):
        return self.nt.nodes.new("ShaderNodeNewGeometry").outputs["Position"]

    def attr(self, name):
        n = self.nt.nodes.new("ShaderNodeAttribute")
        n.attribute_name = name
        return n.outputs["Color"]

    def split(self, color):
        n = self.nt.nodes.new("ShaderNodeSeparateColor")
        self._set(n.inputs["Color"], color)
        return n.outputs["Red"], n.outputs["Green"], n.outputs["Blue"]

    def combine(self, r, g, b):
        n = self.nt.nodes.new("ShaderNodeCombineColor")
        for s, v in zip(n.inputs, (r, g, b)):
            self._set(s, v)
        return n.outputs["Color"]

    def voronoi(self, vector, scale, feature="DISTANCE_TO_EDGE", randomness=1.0):
        n = self.nt.nodes.new("ShaderNodeTexVoronoi")
        n.feature = feature
        self._set(n.inputs["Vector"], vector)
        n.inputs["Scale"].default_value = scale
        n.inputs["Randomness"].default_value = randomness
        return n.outputs["Distance"], n.outputs.get("Color")

    def noise(self, vector, scale, detail=3.0, rough=0.55):
        n = self.nt.nodes.new("ShaderNodeTexNoise")
        self._set(n.inputs["Vector"], vector)
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        return n.outputs["Fac"]

    def scale_vec(self, vector, xyz):
        n = self.nt.nodes.new("ShaderNodeVectorMath")
        n.operation = "MULTIPLY"
        self._set(n.inputs[0], vector)
        n.inputs[1].default_value = xyz
        return n.outputs["Vector"]

    def math(self, op, a, b=0.0, clamp=False):
        n = self.nt.nodes.new("ShaderNodeMath")
        n.operation = op
        n.use_clamp = clamp
        self._set(n.inputs[0], a)
        self._set(n.inputs[1], b)
        return n.outputs[0]

    def smooth(self, x, lo, hi):
        """smoothstep(lo, hi, x)"""
        n = self.nt.nodes.new("ShaderNodeMapRange")
        n.interpolation_type = "SMOOTHSTEP"
        self._set(n.inputs["Value"], x)
        self._set(n.inputs["From Min"], lo)
        self._set(n.inputs["From Max"], hi)
        return n.outputs["Result"]

    def mix(self, f, a, b):
        n = self.nt.nodes.new("ShaderNodeMix")
        n.data_type = "FLOAT"
        self._set(n.inputs[0], f)
        self._set(n.inputs[2], a)
        self._set(n.inputs[3], b)
        return n.outputs[0]

    def mix_rgb(self, f, a, b):
        n = self.nt.nodes.new("ShaderNodeMix")
        n.data_type = "RGBA"
        self._set(n.inputs[0], f)
        self._set(n.inputs[6], a)
        self._set(n.inputs[7], b)
        return n.outputs[2]

    def dot(self, a, b):
        n = self.nt.nodes.new("ShaderNodeVectorMath")
        n.operation = "DOT_PRODUCT"
        for s, v in zip(n.inputs, (a, b)):
            if isinstance(v, bpy.types.NodeSocket):
                self.nt.links.new(v, s)
            else:
                s.default_value = v
        return n.outputs["Value"]

    def sub_vec(self, a, b):
        n = self.nt.nodes.new("ShaderNodeVectorMath")
        n.operation = "SUBTRACT"
        self._set(n.inputs[0], a)
        n.inputs[1].default_value = b
        return n.outputs["Vector"]

    def bump(self, height, distance, strength=1.0):
        n = self.nt.nodes.new("ShaderNodeBump")
        self._set(n.inputs["Height"], height)
        n.inputs["Distance"].default_value = distance
        n.inputs["Strength"].default_value = strength
        return n.outputs["Normal"]

    def out(self, bsdf, color=None, rough=None, normal=None, emission=None, strength=1.0):
        if color is not None:
            self._set(bsdf.inputs["Base Color"], color)
        if rough is not None:
            self._set(bsdf.inputs["Roughness"], rough)
        if normal is not None:
            self._set(bsdf.inputs["Normal"], normal)
        if emission is not None:
            self._set(bsdf.inputs["Emission Color"], emission)
            bsdf.inputs["Emission Strength"].default_value = strength


def set_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


# ------------------------------------------------------------------ bake

def _image(name, size, colorspace, color=(0, 0, 0, 1)):
    img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
    img.generated_color = color
    img.colorspace_settings.name = colorspace
    return img


def _save(img, path):
    img.filepath_raw = path
    img.file_format = "WEBP"
    scn = bpy.context.scene
    scn.render.image_settings.file_format = "WEBP"
    scn.render.image_settings.quality = 90
    img.save_render(path, scene=scn)
    return path


def _fill_misses(images, covered, size, rounds=64):
    """Texels the bake's rays missed (a thin lip, a deep fold) take the
    colour of their nearest baked neighbours, in every map alike."""
    cov = covered.reshape(size, size).copy()
    arrs = []
    for img in images:
        a = np.empty(size * size * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        arrs.append(a.reshape(size, size, 4))
    for _ in range(rounds):
        if cov.all():
            break
        n = np.zeros((size, size), dtype=np.float32)
        sums = [np.zeros_like(a) for a in arrs]
        for axis, step in ((0, 1), (0, -1), (1, 1), (1, -1)):
            c = np.roll(cov, step, axis=axis)
            n += c
            for sm, a in zip(sums, arrs):
                sm += np.roll(a, step, axis=axis) * c[:, :, None]
        new = (~cov) & (n > 0)
        for sm, a in zip(sums, arrs):
            a[new] = sm[new] / n[new][:, None]
        cov |= new
    for img, a in zip(images, arrs):
        img.pixels.foreach_set(a.ravel())
        img.update()


def _wire_game_material(nt, bsdf, tex, albedo, normal, orm_img, emit):
    has_emit = emit is not None
    # the game material: glTF reads occlusion from R, roughness from G, metallic from B
    tex.image = albedo
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nrm_tex = node(nt, "ShaderNodeTexImage", image=normal)
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nrm_tex.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    orm_tex = node(nt, "ShaderNodeTexImage", image=orm_img)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(orm_tex.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    # the exporter finds the occlusion map through a "glTF Material Output" group
    grp = bpy.data.node_groups.get("glTF Material Output") or bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
    if "Occlusion" not in [i.name for i in grp.interface.items_tree]:
        grp.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    g = nt.nodes.new("ShaderNodeGroup")
    g.node_tree = grp
    nt.links.new(sep.outputs["Red"], g.inputs["Occlusion"])
    if has_emit:
        em_tex = node(nt, "ShaderNodeTexImage", image=emit)
        nt.links.new(em_tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0


def baked_material(low, name, out_dir):
    """The game material from maps an earlier bake() left in out_dir (the same
    sculpt gives the same mesh and UVs, so a clip change needs no new bake).
    Returns (material, {key: path}), or None when the maps are not there."""
    paths = {k: os.path.join(out_dir, f"{name}_{k}.webp") for k in ("albedo", "normal", "orm", "emit", "mask")}
    paths = {k: p for k, p in paths.items() if os.path.exists(p)}
    if not all(k in paths for k in ("albedo", "normal", "orm")):
        return None
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    set_material(low, mat)
    imgs = {}
    for k, p in paths.items():
        imgs[k] = bpy.data.images.load(p)
        imgs[k].colorspace_settings.name = "sRGB" if k in ("albedo", "emit") else "Non-Color"
    tex = nt.nodes.new("ShaderNodeTexImage")
    _wire_game_material(nt, bsdf, tex, imgs["albedo"], imgs["normal"], imgs["orm"], imgs.get("emit"))
    return mat, paths


def bake(sources, low, name, out_dir, size=2048, extrusion=0.02, ao_samples=48, ao_strength=0.6, masks=None):
    """Bakes the sources (sculpt + hard parts, with their procedural materials)
    onto `low`'s UVs: <name>_albedo.webp, <name>_normal.webp, <name>_orm.webp
    (occlusion, roughness, metallic), <name>_emit.webp when anything glows,
    and <name>_mask.webp when `masks` ({source object: material whose emission
    is the mask colour}) is given: free channels the game shader reads (glint
    zone, seams, scars). Gives `low` one material that uses the maps and
    returns (material, {key: path})."""
    os.makedirs(out_dir, exist_ok=True)
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.render.bake.use_selected_to_active = True
    scn.render.bake.cage_extrusion = extrusion
    scn.render.bake.max_ray_distance = extrusion * 2.5
    scn.render.bake.margin = 12
    scn.render.bake.use_clear = True

    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    set_material(low, mat)
    tex = nt.nodes.new("ShaderNodeTexImage")
    nt.nodes.active = tex

    def run(kind, img, samples, **kw):
        tex.image = img
        scn.cycles.samples = samples
        activate(low, sources)
        bpy.ops.object.bake(type=kind, **kw)

    albedo = _image(name + "_albedo", size, "sRGB")
    run("DIFFUSE", albedo, 4, pass_filter={"COLOR"})
    normal = _image(name + "_normal", size, "Non-Color", (0.5, 0.5, 1, 1))
    run("NORMAL", normal, 4)
    rough = _image(name + "_rough", size, "Non-Color")
    run("ROUGHNESS", rough, 4)
    ao = _image(name + "_ao", size, "Non-Color", (1, 1, 1, 1))
    run("AO", ao, ao_samples)
    emit = _image(name + "_emit", size, "sRGB")
    run("EMIT", emit, 4)

    def restore(kept):
        for o, mats in kept.items():
            o.data.materials.clear()
            for m_ in mats:
                o.data.materials.append(m_)

    # which texels did the rays reach at all?
    kept = {o: list(o.data.materials) for o in sources}
    white = plain("_coverage", (0, 0, 0), 1.0, emission=(1, 1, 1), strength=1.0)
    for o in sources:
        set_material(o, white)
    cover = _image(name + "_cover", size, "Non-Color")
    scn.render.bake.margin = 0
    run("EMIT", cover, 1)
    scn.render.bake.margin = 12
    restore(kept)

    mask = None
    if masks:
        kept = {o: list(o.data.materials) for o in sources}
        black = plain("_mask_black", (0, 0, 0), 1.0)
        for o in sources:
            set_material(o, masks.get(o, black))
        mask = _image(name + "_mask", size, "Non-Color")
        run("EMIT", mask, 4)
        restore(kept)

    C = np.empty(size * size * 4, dtype=np.float32)
    cover.pixels.foreach_get(C)
    hit = C.reshape(-1, 4)[:, 0] > 0.5
    # inside the islands only: grow the reached area by the bake margin first
    maps = [albedo, normal, rough, ao, emit] + ([mask] if mask is not None else [])
    print(f"bake {name}: {100.0 * hit.mean():.1f}% of the atlas reached")
    _fill_misses(maps, hit, size)
    bpy.data.images.remove(cover)

    n = size * size * 4
    A = np.empty(n, dtype=np.float32)
    Rg = np.empty(n, dtype=np.float32)
    ao.pixels.foreach_get(A)
    rough.pixels.foreach_get(Rg)
    A = A.reshape(-1, 4)
    Rg = Rg.reshape(-1, 4)
    orm = np.ones((size * size, 4), dtype=np.float32)
    orm[:, 0] = 1.0 - ao_strength * (1.0 - A[:, 0])
    orm[:, 1] = Rg[:, 0]
    orm[:, 2] = 0.0
    orm_img = _image(name + "_orm", size, "Non-Color")
    orm_img.pixels.foreach_set(orm.ravel())
    E = np.empty(n, dtype=np.float32)
    emit.pixels.foreach_get(E)
    has_emit = float(E.reshape(-1, 4)[:, :3].max()) > 0.02

    paths = {}
    for key, img in ((("albedo", albedo), ("normal", normal), ("orm", orm_img)) + ((("emit", emit),) if has_emit else ())
                     + ((("mask", mask),) if mask is not None else ())):
        paths[key] = _save(img, os.path.join(out_dir, f"{name}_{key}.webp"))
        img.source = "FILE"
        img.filepath = paths[key]
        img.reload()

    _wire_game_material(nt, bsdf, tex, albedo, normal, orm_img, emit if has_emit else None)
    for img in (rough, ao) + (() if has_emit else (emit,)):
        bpy.data.images.remove(img)
    return mat, paths


# ------------------------------------------------------------------ export

def export_gltf(name, objs, out_dir):
    """<out_dir>/<name>.gltf with its buffer inlined (the repo's convention:
    one .gltf per model) and its textures left as the .webp files beside it.
    Skins, shape keys and one animation per NLA track."""
    import base64
    import json
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = os.path.join(out_dir, f"{name}.gltf")
    animated = any(o.type == "ARMATURE" for o in objs)
    extra = dict(export_animations=True, export_animation_mode="NLA_TRACKS", export_skins=True,
                 export_force_sampling=True, export_optimize_animation_size=True,
                 export_morph=True, export_morph_normal=False) if animated else {}
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLTF_SEPARATE", export_yup=True,
                              export_apply=False, export_materials="EXPORT", export_image_format="NONE",
                              export_tangents=True, export_vertex_color="NONE", export_attributes=False, **extra)
    with open(path) as f:
        doc = json.load(f)
    for buf in doc["buffers"]:
        bin_path = os.path.join(out_dir, buf["uri"])
        with open(bin_path, "rb") as f:
            data = f.read()
        buf["uri"] = "data:application/octet-stream;base64," + base64.b64encode(data).decode("ascii")
        os.remove(bin_path)
    with open(path, "w") as f:
        json.dump(doc, f, separators=(",", ":"))
    return path
