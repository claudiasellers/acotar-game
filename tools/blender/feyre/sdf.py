"""Tiny signed-distance sculpting kit (numpy only) for the Feyre builders.

Shapes are combined with smooth unions/subtractions on a dense grid, but each
operation only touches its own bounding box, so a whole body at 2.5 mm costs
seconds.  `surface_nets` turns the grid into a quad mesh (one vertex per
sign-changing cell), which the builders then smooth and decimate in Blender.

Convention: negative inside.  Coordinates are Blender metres (Z up).
"""

import math

import numpy as np


# --------------------------------------------------------------------------
# Primitives: each returns (fn(X, Y, Z) -> distance, (lo, hi) bounding box)
# --------------------------------------------------------------------------
def sphere(c, r):
    c = np.asarray(c, float)

    def f(X, Y, Z):
        return np.sqrt((X - c[0]) ** 2 + (Y - c[1]) ** 2 + (Z - c[2]) ** 2) - r
    return f, (c - r, c + r)


def ellipsoid(c, radii, rot=None):
    """Approximate ellipsoid distance (iq).  `rot` is a 3x3 world->local matrix."""
    c = np.asarray(c, float)
    r = np.asarray(radii, float)
    R = None if rot is None else np.asarray(rot, float)

    def f(X, Y, Z):
        x, y, z = X - c[0], Y - c[1], Z - c[2]
        if R is not None:
            x, y, z = (R[0, 0] * x + R[0, 1] * y + R[0, 2] * z,
                       R[1, 0] * x + R[1, 1] * y + R[1, 2] * z,
                       R[2, 0] * x + R[2, 1] * y + R[2, 2] * z)
        k0 = np.sqrt((x / r[0]) ** 2 + (y / r[1]) ** 2 + (z / r[2]) ** 2)
        k1 = np.sqrt((x / r[0] ** 2) ** 2 + (y / r[1] ** 2) ** 2 + (z / r[2] ** 2) ** 2)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
    m = float(r.max())
    return f, (c - m, c + m)


def round_cone(a, b, ra, rb):
    """Capsule with different end radii (exact, iq)."""
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    ba = b - a
    l2 = float(ba @ ba)
    rr = ra - rb
    a2 = l2 - rr * rr
    il2 = 1.0 / l2

    def f(X, Y, Z):
        px, py, pz = X - a[0], Y - a[1], Z - a[2]
        y = px * ba[0] + py * ba[1] + pz * ba[2]
        z = y - l2
        qx = px * l2 - ba[0] * y
        qy = py * l2 - ba[1] * y
        qz = pz * l2 - ba[2] * y
        x2 = qx * qx + qy * qy + qz * qz
        y2 = y * y * l2
        z2 = z * z * l2
        k = math.copysign(1.0, rr) * rr * rr * x2
        d_a = np.sqrt(x2 + y2) * il2 - ra
        d_b = np.sqrt(x2 + z2) * il2 - rb
        d_m = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - ra
        out = np.where(np.sign(z) * a2 * z2 > k, d_b, np.where(np.sign(y) * a2 * y2 < k, d_a, d_m))
        return out
    m = max(ra, rb)
    return f, (np.minimum(a, b) - m, np.maximum(a, b) + m)


def capsule(a, b, r):
    return round_cone(a, b, r, r + 1e-6)


def tube(points, radii):
    """Chain of round cones through `points` (a smooth tapering limb/lock)."""
    parts = [round_cone(points[i], points[i + 1], radii[i], radii[i + 1]) for i in range(len(points) - 1)]
    fns = [p[0] for p in parts]

    def f(X, Y, Z):
        d = fns[0](X, Y, Z)
        for g in fns[1:]:
            d = np.minimum(d, g(X, Y, Z))
        return d
    lo = np.min([p[1][0] for p in parts], axis=0)
    hi = np.max([p[1][1] for p in parts], axis=0)
    return f, (lo, hi)


def halfspace(point, normal, extent):
    """Points on the +normal side are outside.  `extent` = (lo, hi) to limit work."""
    p = np.asarray(point, float)
    n = np.asarray(normal, float)
    n = n / np.linalg.norm(n)

    def f(X, Y, Z):
        return (X - p[0]) * n[0] + (Y - p[1]) * n[1] + (Z - p[2]) * n[2]
    return f, (np.asarray(extent[0], float), np.asarray(extent[1], float))


def custom(fn, lo, hi):
    return fn, (np.asarray(lo, float), np.asarray(hi, float))


# --------------------------------------------------------------------------
# Smooth booleans
# --------------------------------------------------------------------------
def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


# --------------------------------------------------------------------------
# Grid
# --------------------------------------------------------------------------
class Grid:
    """Dense SDF grid; every op is applied inside its own bounding box only."""

    FAR = 0.05

    def __init__(self, lo, hi, h):
        self.h = float(h)
        self.lo = np.asarray(lo, float)
        n = np.ceil((np.asarray(hi, float) - self.lo) / self.h).astype(int) + 1
        self.n = n
        self.F = np.full(tuple(n), self.FAR, np.float32)
        self.axes = [self.lo[i] + self.h * np.arange(n[i]) for i in range(3)]

    def _slices(self, lo, hi, pad):
        s = []
        for i in range(3):
            a = int(max(0, math.floor((lo[i] - pad - self.lo[i]) / self.h)))
            b = int(min(self.n[i], math.ceil((hi[i] + pad - self.lo[i]) / self.h) + 1))
            if b <= a:
                return None
            s.append(slice(a, b))
        return tuple(s)

    def _coords(self, sl):
        X = self.axes[0][sl[0]][:, None, None]
        Y = self.axes[1][sl[1]][None, :, None]
        Z = self.axes[2][sl[2]][None, None, :]
        return X, Y, Z

    def union(self, prim, k=0.0, pad=None):
        f, (lo, hi) = prim
        sl = self._slices(lo, hi, (pad if pad is not None else 0.0) + 2.0 * k + 2 * self.h)
        if sl is None:
            return
        d = f(*self._coords(sl)).astype(np.float32)
        self.F[sl] = smin(self.F[sl], d, k)

    def subtract(self, prim, k=0.0, pad=None):
        f, (lo, hi) = prim
        sl = self._slices(lo, hi, (pad if pad is not None else 0.0) + 2.0 * k + 2 * self.h)
        if sl is None:
            return
        d = f(*self._coords(sl)).astype(np.float32)
        self.F[sl] = smax(self.F[sl], -d, k)

    def intersect(self, prim, k=0.0):
        """Keep only the inside of `prim` (within its box; outside the box is cleared)."""
        f, (lo, hi) = prim
        sl = self._slices(lo, hi, 2.0 * k + 2 * self.h)
        keep = np.full(self.F.shape, self.FAR, np.float32)
        if sl is not None:
            d = f(*self._coords(sl)).astype(np.float32)
            keep[sl] = smax(self.F[sl], d, k)
        self.F = keep

    def sample(self, P):
        """Trilinear SDF at points P (N,3)."""
        g = (np.asarray(P, float) - self.lo) / self.h
        i0 = np.clip(np.floor(g).astype(int), 0, self.n - 2)
        t = np.clip(g - i0, 0.0, 1.0)
        out = np.zeros(len(P))
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    w = ((t[:, 0] if dx else 1 - t[:, 0]) * (t[:, 1] if dy else 1 - t[:, 1])
                         * (t[:, 2] if dz else 1 - t[:, 2]))
                    out += w * self.F[i0[:, 0] + dx, i0[:, 1] + dy, i0[:, 2] + dz]
        return out


def surface_nets(grid):
    """Naive surface nets.  Returns (verts (V,3), quads (Q,4)) with outward winding."""
    F = grid.F
    inside = F < 0
    n = np.array(F.shape)
    cell_dims = n - 1
    acc_idx, acc_pts = [], []
    quads = []
    for axis in range(3):
        a = [slice(None)] * 3
        b = [slice(None)] * 3
        a[axis] = slice(0, -1)
        b[axis] = slice(1, None)
        cross = inside[tuple(a)] != inside[tuple(b)]
        I = np.argwhere(cross)
        if len(I) == 0:
            continue
        f0 = F[tuple(a)][cross].astype(float)
        f1 = F[tuple(b)][cross].astype(float)
        t = f0 / (f0 - f1)
        pts = I.astype(float)
        pts[:, axis] += t
        # the 4 cells sharing this edge
        o1, o2 = [(axis + 1) % 3, (axis + 2) % 3]
        offs = [(0, 0), (1, 0), (1, 1), (0, 1)]
        cells = []
        for d1, d2 in offs:
            C = I.copy()
            C[:, o1] -= d1
            C[:, o2] -= d2
            cells.append(C)
        valid = np.ones(len(I), bool)
        for C in cells:
            valid &= (C >= 0).all(1) & (C < cell_dims).all(1)
        lin = [np.ravel_multi_index(C[valid].T, cell_dims) for C in cells]
        for L in lin:
            acc_idx.append(L)
            acc_pts.append(pts[valid])
        q = np.stack(lin, axis=1)
        # outward direction along the edge axis: from inside to outside
        out_sign = np.where(inside[tuple(a)][cross][valid], 1.0, -1.0)
        quads.append((q, axis, out_sign))
    idx = np.concatenate(acc_idx)
    pts = np.concatenate(acc_pts)
    uniq, inv = np.unique(idx, return_inverse=True)
    cnt = np.bincount(inv, minlength=len(uniq)).astype(float)
    V = np.stack([np.bincount(inv, weights=pts[:, i], minlength=len(uniq)) / cnt for i in range(3)], 1)
    V = grid.lo + V * grid.h
    Q = []
    for q, axis, s in quads:
        qi = np.searchsorted(uniq, q)
        # orient: normal of (v1-v0)x(v3-v0) should point along +/-axis by s
        p0, p1, p3 = V[qi[:, 0]], V[qi[:, 1]], V[qi[:, 3]]
        nrm = np.cross(p1 - p0, p3 - p0)[:, axis]
        flip = np.sign(nrm) != s
        qi[flip] = qi[flip][:, ::-1]
        Q.append(qi)
    return V, np.concatenate(Q)
