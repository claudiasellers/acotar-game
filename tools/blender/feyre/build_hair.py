"""Feyre's 16 hairstyles as separate skinned glbs (swap like clothes).

Reproducible build (cloud Blender module):
    /opt/bpyenv/bin/python tools/blender/feyre/build_hair.py [style ...]

Writes characters/feyre/hair/<id>.glb for every id in data/wardrobe/hair/*.tres
(mesh_path res://characters/feyre/hair/<id>.glb) and hair.blend as the editable
source.  Needs characters/feyre/model/feyre.blend (Armature) from build_feyre.py.

Each style is sculpted as a signed-distance field on top of her head: a scalp
cap trimmed at the hairline, chunky locks laid over it (they make the stylised
strand grooves), and per-style braids, buns, curls, ribbons and flowers.  The
body is subtracted at the end so hair never cuts into her face or shoulders.
Every style stays inside feyre_shape.CROWN_RING at crown height so crowns and
tiaras fit all of them.

Weights: Head on the scalp, the Braid_1..4 chain for whatever hangs down her
back, UpperChest/Shoulders for locks over the front.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import bmesh  # noqa: E402
import numpy as np  # noqa: E402

import build_feyre as bf  # noqa: E402
import feyre_shape as fs  # noqa: E402
import sdf  # noqa: E402

HAIR_DIR = os.path.join(bf.REPO, "characters", "feyre", "hair")
H = 0.0025
LO = np.array([-0.17, -0.15, 0.99])
HI = np.array([0.17, 0.22, 1.76])
MAX_TRIS = 5600
SKULL_C = np.array([0.0, 0.012, 1.535])
RNG = np.random.default_rng(1966)


def srgb(hexstr):
    c = [int(hexstr[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


HAIR_RGB = srgb("#B08552")       # brassy golden-brown, warmed for the pastel world
HAIR_WET_RGB = srgb("#86603C")
FLOWER_RGBS = [srgb("#F4A6C0"), srgb("#FCE9A6"), srgb("#C8A8E9"), srgb("#FBF7F2"), srgb("#A7B5F2")]
CENTRE_RGB = srgb("#F2D27A")
RIBBON_RGB = srgb("#F4A6C0")
LEAF_RGB = srgb("#7CC29A")


# --------------------------------------------------------------------------
# Head geometry helpers (shared body grid)
# --------------------------------------------------------------------------
class Head:
    def __init__(self):
        self.body = fs.build_grid(H)
        off = np.round((LO - self.body.lo) / H).astype(int)
        self.grid_template = sdf.Grid(LO, HI, H)
        n = self.grid_template.n
        self.Fb = np.full(tuple(n), sdf.Grid.FAR, np.float32)
        src = self.body.F[off[0]:off[0] + n[0], off[1]:off[1] + n[1], off[2]:off[2] + n[2]]
        self.Fb[:src.shape[0], :src.shape[1], :src.shape[2]] = src

    def sample(self, P):
        return self.body.sample(np.atleast_2d(P))

    def scalp(self, theta, phi, off=0.0):
        """Point on the skin along a ray from the skull centre (theta from the front, +left)."""
        d = np.array([math.sin(theta) * math.cos(phi), -math.cos(theta) * math.cos(phi), math.sin(phi)])
        rs = np.linspace(0.02, 0.16, 280)
        F = self.sample(SKULL_C[None] + rs[:, None] * d[None])
        ins = np.nonzero(F < 0)[0]
        r = rs[ins[-1]] if len(ins) else 0.09
        return SKULL_C + d * (r + off)

    def push_out(self, P, margin):
        """Move points that are closer than `margin` to the body outwards along the gradient."""
        P = np.array(P, float)
        e = 0.002
        for _ in range(10):
            f = self.sample(P)
            bad = f < margin
            if not bad.any():
                break
            g = np.stack([(self.sample(P + np.eye(3)[i] * e) - self.sample(P - np.eye(3)[i] * e)) / (2 * e)
                          for i in range(3)], 1)
            g /= np.maximum(np.linalg.norm(g, axis=1)[:, None], 1e-6)
            P[bad] += g[bad] * (margin - f[bad])[:, None]
        return P


def hairline(theta):
    a = np.abs(theta) / math.pi  # 0 front .. 1 back
    return np.interp(a, [0.0, 0.14, 0.28, 0.42, 0.55, 0.75, 1.0], [1.592, 1.586, 1.55, 1.515, 1.49, 1.445, 1.425])


# --------------------------------------------------------------------------
# Style building blocks.  Each returns nothing; they write into the Style.
# --------------------------------------------------------------------------
class Style:
    def __init__(self, head, sid):
        self.head = head
        self.id = sid
        self.g = sdf.Grid(LO, HI, H)
        self.tags = {"flowers": [], "centres": [], "ribbon": [], "leaves": []}
        self.flower_cols = []
        self.wet = False

    def outer(self, theta, phi, off=0.0):
        """Point on the hair built so far (falls back to the scalp) along a skull ray."""
        d = np.array([math.sin(theta) * math.cos(phi), -math.cos(theta) * math.cos(phi), math.sin(phi)])
        rs = np.linspace(0.02, 0.20, 360)
        F = np.minimum(self.g.sample(SKULL_C[None] + rs[:, None] * d[None]),
                       self.head.sample(SKULL_C[None] + rs[:, None] * d[None]))
        ins = np.nonzero(F < 0)[0]
        r = rs[ins[-1]] if len(ins) else 0.1
        return SKULL_C + d * (r + off)

    # -- primitives ----------------------------------------------------------
    def lock(self, pts, r0, r1=None, k=0.004, taper=0.35):
        pts = [tuple(p) for p in pts]
        n = len(pts)
        r1 = r0 * taper if r1 is None else r1
        radii = [r0 + (r1 - r0) * (i / (n - 1)) ** 1.3 for i in range(n)]
        self.g.union(sdf.tube(pts, radii), k)

    def cap(self, thick=0.013, back_extra=0.010, line=hairline):
        X, Y, Z = self.g._coords(tuple(slice(None) for _ in range(3)))
        th = np.arctan2(X, -(Y - SKULL_C[1]))
        hl = line(th)
        back = np.clip((Y - SKULL_C[1]) / 0.08, 0, 1)
        t = thick + back_extra * back * (Z > 1.50)
        t = t * (0.55 + 0.45 * np.clip((Z - hl) / 0.025, 0, 1))
        d = self.head.Fb - t
        d = sdf.smax(d, hl - Z, 0.006)
        d = sdf.smax(d, 1.38 - Z, 0.01)
        self.g.F = sdf.smin(self.g.F, d.astype(np.float32), 0.004)

    def skull_lock(self, th0, ph0, th1, ph1, off, r, n=9, sag=0.0):
        pts = []
        for i in range(n):
            t = i / (n - 1)
            th = th0 + (th1 - th0) * t
            ph = ph0 + (ph1 - ph0) * t - sag * math.sin(math.pi * t)
            pts.append(self.head.scalp(th, ph, off))
        self.lock(pts, r, r * 0.55)
        return pts

    def cap_locks(self, part_th, n=26, off=0.0115, r=0.0085, back=True, sides=True, front_sweep=True):
        """Locks from the parting over the skull: gives the cap direction and grooves."""
        ph_part = math.radians(70)
        targets = []
        if back:
            targets += [(math.radians(a), math.radians(-5)) for a in np.linspace(105, 255, n // 2)]
        if sides:
            targets += [(math.radians(a), math.radians(5)) for a in (70, 85, -70, -85)]
        if front_sweep:
            targets += [(math.radians(a), math.radians(30)) for a in (-40, -55, 40)]
        for th1, ph1 in targets:
            th1 = th1 if th1 <= math.pi else th1 - 2 * math.pi
            j = RNG.uniform(-0.04, 0.04)
            self.skull_lock(part_th + j, ph_part + j, th1, ph1, off, r * RNG.uniform(0.85, 1.1))

    def fringe(self, part_th, side=1, n=5, depth=0.0):
        """Side-swept fringe: locks from the parting across the forehead to the far temple."""
        for i in range(n):
            t = i / max(1, n - 1)
            th0 = part_th + math.radians(-6 + 8 * t) * side
            ph0 = math.radians(72 - 6 * t)
            th1 = -side * math.radians(48 + 22 * t)
            ph1 = math.radians(26 - 10 * t) - depth
            self.skull_lock(th0, ph0, th1, ph1, 0.009 + 0.002 * t, 0.0085 - 0.0012 * t, n=11, sag=math.radians(14))

    def hang(self, start, length, drift, r0=0.010, r1=None, wave=0.0, curl=0.0, n=12, front=False):
        """A lock that falls from `start` under gravity, kept clear of the body."""
        s = np.asarray(start, float)
        radial = np.array([s[0], s[1] - 0.01, 0.0])
        radial /= max(np.linalg.norm(radial), 1e-6)
        side = np.cross([0, 0, 1], radial)
        pts = []
        ph = RNG.uniform(0, 2 * math.pi)
        for i in range(n):
            t = i / (n - 1)
            p = s + np.array([0, 0, -length * t]) + radial * drift * t ** 0.8
            if front:
                p += np.array([0, -0.035 * t, 0])
            p += side * wave * math.sin(t * 3 * math.pi + ph) * t
            if curl > 0:
                a = t * 3.0 * math.pi + ph
                p += (side * math.cos(a) + radial * math.sin(a)) * curl * t ** 1.2
            pts.append(p)
        pts = self.head.push_out(np.array(pts), (r0 + 0.004))
        pts[0] = s
        self.lock(pts, r0, r1 if r1 is not None else r0 * 0.35, k=0.011)
        return pts

    def back_mass(self, bottom_z, n=16, spread=0.05, r=0.021, wave=0.0, curl=0.0, arc=(95, 265)):
        for a in np.linspace(arc[0], arc[1], n):
            th = math.radians(a)
            th = th if th <= math.pi else th - 2 * math.pi
            st = self.head.scalp(th, math.radians(RNG.uniform(5, 18)), 0.006)
            L = st[2] - bottom_z + RNG.uniform(-0.02, 0.02)
            self.hang(st, L, spread * RNG.uniform(0.8, 1.2), r * RNG.uniform(0.85, 1.15), wave=wave, curl=curl)

    def front_locks(self, bottom_z, sides=(1, -1), n=2, r=0.011, wave=0.0, curl=0.0):
        for s in sides:
            for i in range(n):
                th = s * math.radians(78 + 10 * i)
                st = self.head.scalp(th, math.radians(8 - 6 * i), 0.006)
                self.hang(st, st[2] - bottom_z - 0.02 * i, 0.035, r, wave=wave, curl=curl, front=True)

    def braid(self, pts, width=0.022, lobes=14, r=None, fishtail=False):
        """Herringbone braid along a path (points from top to tip)."""
        P = np.array(pts, float)
        seg = np.linalg.norm(np.diff(P, axis=0), axis=1)
        L = np.concatenate([[0], np.cumsum(seg)])
        m = lobes * (2 if fishtail else 1)
        r = r or width * (0.36 if fishtail else 0.48)
        for i in range(m):
            t = (i + 0.5) / m
            s = t * L[-1]
            j = min(np.searchsorted(L, s) - 1, len(P) - 2)
            j = max(j, 0)
            u = (s - L[j]) / max(seg[j], 1e-9)
            c = P[j] + (P[j + 1] - P[j]) * u
            tang = (P[j + 1] - P[j]) / max(seg[j], 1e-9)
            out = np.array([c[0], c[1] - 0.0, 0.0]) - np.array([0, 0.0, 0])
            side = np.cross(tang, out if np.linalg.norm(out) > 1e-3 else np.array([0, -1.0, 0]))
            side /= max(np.linalg.norm(side), 1e-9)
            sg = 1 if i % 2 == 0 else -1
            taper = 1.0 - 0.45 * t
            w = width * taper
            step = L[-1] / m
            a = c + side * sg * w * 0.30 - tang * step * 0.7
            b = c - side * sg * w * 0.12 + tang * step * 1.0
            self.g.union(sdf.capsule(a, b, r * taper), 0.005)
        tip = P[-1]
        self.tie(tip, (P[-1] - P[-2]), width * 0.36)
        tuft = [tip + (P[-1] - P[-2]) / max(np.linalg.norm(P[-1] - P[-2]), 1e-9) * d for d in (0.0, 0.03, 0.055)]
        self.lock(tuft, width * 0.33, width * 0.12, k=0.004)

    def tie(self, c, axis, r):
        axis = np.asarray(axis, float)
        axis /= max(np.linalg.norm(axis), 1e-9)
        prim = sdf.capsule(np.asarray(c) - axis * 0.004, np.asarray(c) + axis * 0.004, r)
        self.g.union(prim, 0.002)
        self.tags["ribbon"].append(prim)

    def bun(self, c, R, wraps=9, axis=(0, 1, 0)):
        c = np.asarray(c, float)
        ax = np.asarray(axis, float)
        ax /= np.linalg.norm(ax)
        u = np.cross(ax, [0, 0, 1])
        if np.linalg.norm(u) < 1e-3:
            u = np.array([1.0, 0, 0])
        u /= np.linalg.norm(u)
        v = np.cross(ax, u)
        self.g.union(sdf.sphere(c, R * 0.72), 0.01)
        for i in range(wraps):
            a = 2 * math.pi * i / wraps
            p0 = c + (u * math.cos(a) + v * math.sin(a)) * R * 0.55
            p1 = c + (u * math.cos(a + 1.9) + v * math.sin(a + 1.9)) * R * 0.55 + ax * R * 0.25
            self.g.union(sdf.capsule(p0, p1, R * 0.36), 0.004)

    def rose_bun(self, c, R, axis):
        c = np.asarray(c, float)
        ax = np.asarray(axis, float)
        ax /= np.linalg.norm(ax)
        u = np.cross(ax, [0, 0, 1])
        u /= np.linalg.norm(u)
        v = np.cross(ax, u)
        self.g.union(sdf.sphere(c, R * 0.6), 0.01)
        for i in range(13):  # a spiral of petal-shaped coils
            t = i / 12
            a = t * 3.2 * math.pi
            rr = R * (0.25 + 0.65 * t)
            p = c + (u * math.cos(a) + v * math.sin(a)) * rr + ax * R * 0.35 * (1 - t)
            q = c + (u * math.cos(a + 0.9) + v * math.sin(a + 0.9)) * rr + ax * R * 0.35 * (1 - t)
            self.g.union(sdf.capsule(p, q, R * (0.16 + 0.14 * t)), 0.003)

    def flower(self, c, size=0.009, normal=None, col=0):
        c = np.asarray(c, float)
        n = np.asarray(normal if normal is not None else c - SKULL_C, float)
        n /= np.linalg.norm(n)
        u = np.cross(n, [0, 0, 1])
        if np.linalg.norm(u) < 1e-3:
            u = np.array([1.0, 0, 0])
        u /= np.linalg.norm(u)
        v = np.cross(n, u)
        petals = []
        for i in range(5):
            a = 2 * math.pi * i / 5 + RNG.uniform(0, 0.3)
            pc = c + (u * math.cos(a) + v * math.sin(a)) * size * 0.62 + n * size * 0.15
            pr = sdf.sphere(pc, size * 0.48)
            self.g.union(pr, 0.002)
            petals.append(pr)
        cen = sdf.sphere(c + n * size * 0.35, size * 0.3)
        self.g.union(cen, 0.002)
        self.tags["flowers"].append(petals)
        self.flower_cols.append(col)
        self.tags["centres"].append(cen)

    def ribbon_bow(self, c, size=0.018, normal=(0, 1, 0)):
        c = np.asarray(c, float)
        n = np.asarray(normal, float)
        n /= np.linalg.norm(n)
        for s in (1, -1):
            lp = c + np.array([s * size, 0, size * 0.25])
            prim = sdf.ellipsoid(lp, (size * 0.75, size * 0.28, size * 0.45))
            self.g.union(prim, 0.002)
            self.tags["ribbon"].append(prim)
            tail = sdf.capsule(c, c + np.array([s * size * 0.5, n[1] * 0.004, -size * 1.6]), size * 0.16)
            self.g.union(tail, 0.002)
            self.tags["ribbon"].append(tail)
        knot = sdf.sphere(c, size * 0.3)
        self.g.union(knot, 0.002)
        self.tags["ribbon"].append(knot)

    # -- finish --------------------------------------------------------------
    def carve_body(self, margin=0.0012):
        self.g.F = sdf.smax(self.g.F, -(self.head.Fb - margin), 0.002).astype(np.float32)

    def crown_check(self):
        c = np.array(fs.CROWN_RING["centre"])
        rx, ry = fs.CROWN_RING["rx"], fs.CROWN_RING["ry"]
        tilt = math.radians(fs.CROWN_RING["tilt_deg"])
        pts = []
        for i in range(72):
            a = 2 * math.pi * i / 72
            x, y = rx * math.sin(a), -ry * math.cos(a)
            pts.append(c + np.array([x, y, -y * math.tan(tilt) * -1.0]))
        return float(np.min(self.g.sample(np.array(pts))))


# --------------------------------------------------------------------------
# The 16 styles
# --------------------------------------------------------------------------
PART = math.radians(22)  # side parting on her left
BACK_CHAIN = [(0.0, 0.095, 1.47), (0.0, 0.112, 1.40), (0.0, 0.118, 1.30), (0.0, 0.114, 1.20),
              (0.0, 0.106, 1.12)]


def swept_back(st, fringe=True):
    st.cap()
    st.cap_locks(PART, front_sweep=False)
    if fringe:
        st.fringe(PART, 1, n=4)


def loose_base(st, bottom=1.13, wave=0.0, curl=0.0, r=0.021):
    st.cap()
    st.cap_locks(PART)
    st.fringe(PART, 1, n=6)
    st.back_mass(bottom, n=12, spread=0.055, r=r, wave=wave, curl=curl)
    st.front_locks(bottom + 0.06, n=2, r=r * 0.8, wave=wave, curl=curl)


def style_braid(st):
    swept_back(st)
    for s in (1, -1):  # face-framing wisps
        st.hang(st.head.scalp(s * math.radians(70), math.radians(16), 0.005), 0.07, 0.01, 0.0055, wave=0.004)
    top = st.outer(math.pi, math.radians(-12), 0.0)
    chain = [top] + [np.array(p) + (0, 0.012, 0) for p in BACK_CHAIN[1:]]
    st.braid(chain, width=0.042, lobes=14)


def style_hunters_knot(st):
    swept_back(st)
    c = st.outer(math.pi, math.radians(-14), 0.016)
    st.bun(c, 0.034, wraps=8, axis=(0, 1, 0.2))
    st.lock([c + (0, 0.01, -0.02), c + (0.004, 0.016, -0.05), c + (0.008, 0.014, -0.08)], 0.011, 0.004)


def style_loose(st):
    loose_base(st)


def style_wet(st):
    st.wet = True
    st.cap(0.006, back_extra=0.002)
    st.cap_locks(PART, n=18, off=0.005, r=0.006)
    st.fringe(PART, 1, n=3, depth=math.radians(4))
    st.back_mass(1.15, n=16, spread=0.02, r=0.014, wave=0.002)
    st.front_locks(1.22, n=2, r=0.011)


def style_soft_curls(st):
    loose_base(st, bottom=1.16, wave=0.003, curl=0.007, r=0.021)


def style_ribboned_curls(st):
    loose_base(st, bottom=1.20, wave=0.003, curl=0.008, r=0.021)
    st.ribbon_bow(st.outer(math.pi, math.radians(22), 0.006), 0.026)


def style_half_up(st):
    loose_base(st, bottom=1.15, wave=0.003)
    st.braid([(-0.07, 0.07, 1.56), (-0.035, 0.105, 1.555), (0.0, 0.115, 1.55)], width=0.018, lobes=5)
    st.braid([(0.07, 0.07, 1.56), (0.035, 0.105, 1.555), (0.0, 0.115, 1.55)], width=0.018, lobes=5)
    st.ribbon_bow((0.0, 0.122, 1.552), 0.020)


def style_high_ponytail(st):
    st.cap()
    st.cap_locks(PART, front_sweep=False)
    st.fringe(PART, 1, n=3)
    base = st.outer(math.pi, math.radians(48), 0.006)
    st.tie(base, (0, 0.6, 0.8), 0.016)
    for i in range(9):
        a = 2 * math.pi * i / 9
        off = np.array([math.cos(a) * 0.009, math.sin(a) * 0.009, 0.0])
        pts = [base + off, base + off * 1.2 + (0, 0.026, -0.004), base + off * 1.6 + (0, 0.040, -0.04),
               base + off * 1.9 + (0, 0.046, -0.11), base + off * 1.8 + (0, 0.044, -0.19),
               base + off * 1.2 + (0, 0.040, -0.26)]
        pts = st.head.push_out(np.array(pts), 0.02)
        st.lock(pts, 0.015, 0.005, k=0.009)


def style_ballerina_bun(st):
    st.cap(0.008)
    st.cap_locks(PART, n=20, front_sweep=False)
    st.bun(st.outer(math.radians(180), math.radians(62), 0.024), 0.046, wraps=10, axis=(0, 0.45, 0.9))


def style_rose_bun(st):
    swept_back(st)
    c = st.outer(math.pi, math.radians(-8), 0.020)
    st.rose_bun(c, 0.040, axis=(0, 1, 0.15))
    st.flower(st.outer(math.radians(150), math.radians(4), 0.004), 0.012, normal=(0.4, 1, 0.2), col=0)


def style_twin_braids(st):
    st.cap(0.009)
    st.cap_locks(0.0, n=20, front_sweep=False)
    for s in (1, -1):
        path = [(0.072 * s, 0.045, 1.48), (0.095 * s, 0.025, 1.40), (0.11 * s, -0.01, 1.32),
                (0.105 * s, -0.045, 1.24), (0.095 * s, -0.06, 1.17)]
        path = st.head.push_out(np.array(path), 0.016)
        st.braid(path, width=0.024, lobes=11)


def style_fishtail_braid(st):
    swept_back(st)
    path = [(0.065, 0.06, 1.47), (0.10, 0.025, 1.39), (0.115, -0.02, 1.31), (0.105, -0.055, 1.22),
            (0.09, -0.07, 1.13)]
    path = st.head.push_out(np.array(path), 0.018)
    st.braid(path, width=0.030, lobes=12, fishtail=True)


def style_crown_braid(st):
    """Milkmaid crown: all the length braided and pinned in one thick band right round her head, higher
    over the brow and lower at the nape, sitting proud of the smooth swept-back cap."""
    swept_back(st, fringe=False)
    st.fringe(PART, 1, n=2)
    pts = []
    for i in range(37):
        a = math.radians(-180 + 360 * i / 36)
        p = st.outer(a, math.radians(25 + 9 * math.cos(a)), 0.009)
        pts.append(p)
    st.braid(pts, width=0.034, lobes=30)


def style_waterfall_braid(st):
    loose_base(st, bottom=1.14, wave=0.003)
    pts = [st.head.scalp(math.radians(a), math.radians(30 if abs(a) < 120 else 26), 0.012)
           for a in np.linspace(75, 285, 15)]
    pts = [p if True else p for p in pts]
    pts = [(p[0], p[1], p[2]) for p in pts]
    pts2 = [st.outer(math.radians(a if a <= 180 else a - 360), math.radians(26), 0.004)
            for a in np.linspace(75, 285, 15)]
    st.braid(pts2, width=0.018, lobes=12)
    del pts


def style_flower_crown_hair(st):
    loose_base(st, bottom=1.12, wave=0.005)
    for i, a in enumerate(np.linspace(-150, 150, 11)):
        p = st.outer(math.radians(a), math.radians(34), 0.002)
        st.flower(p, 0.011, col=i % 4)
    for i, (x, z) in enumerate(((0.10, 1.38), (-0.10, 1.36), (0.105, 1.30), (0.04, 1.25))):
        p = st.head.push_out(np.array([[x, 0.08, z]]), 0.03)[0]
        st.flower(p, 0.008, normal=(np.sign(x) * 0.5, 0.6, 0), col=(i + 2) % 4)


def style_loose_with_flowers(st):
    loose_base(st, bottom=1.13)
    base = st.outer(math.radians(-80), math.radians(22), 0.003)
    for i, d in enumerate(((0, 0, 0), (0.0, 0.016, 0.012), (0.0, 0.012, -0.014), (0.0, -0.014, 0.008))):
        st.flower(base + np.array(d), 0.010 - 0.0012 * i, normal=(-1, 0.1, 0.2), col=(0, 3, 1, 2)[i])


STYLES = {
    "braid": style_braid,
    "hunters_knot": style_hunters_knot,
    "loose": style_loose,
    "wet": style_wet,
    "soft_curls": style_soft_curls,
    "ribboned_curls": style_ribboned_curls,
    "half_up": style_half_up,
    "high_ponytail": style_high_ponytail,
    "ballerina_bun": style_ballerina_bun,
    "rose_bun": style_rose_bun,
    "twin_braids": style_twin_braids,
    "fishtail_braid": style_fishtail_braid,
    "crown_braid": style_crown_braid,
    "waterfall_braid": style_waterfall_braid,
    "flower_crown_hair": style_flower_crown_hair,
    "hair_loose_with_flowers": style_loose_with_flowers,
}


# --------------------------------------------------------------------------
# Mesh, materials, weights
# --------------------------------------------------------------------------
def mesh_style(st, spec, arm):
    V, Q = sdf.surface_nets(st.g)
    me = bpy.data.meshes.new("hair_" + st.id)
    me.from_pydata(V.tolist(), [], Q.tolist())
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj = bf.link(bpy.data.objects.new("hair_" + st.id, me))
    sm = obj.modifiers.new("Smooth", "SMOOTH")
    sm.iterations = 2
    sm.factor = 0.5
    bf.bake_modifiers(obj)
    bf.decimate_to(obj, MAX_TRIS)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.validate()
    me = obj.data

    rgb = HAIR_WET_RGB if st.wet else HAIR_RGB
    mats = [bf.make_material("hair_wet" if st.wet else "hair", rgb, 0.22 if st.wet else 0.42)]
    P = bf.verts_np(me)
    X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
    vmat = np.zeros(len(P), int)

    def tag(prims, idx):
        if not prims:
            return
        d = np.min([p[0](X, Y, Z) for p in prims], axis=0)
        vmat[d < 0.0018] = idx

    if st.tags["ribbon"]:
        mats.append(bf.make_material("ribbon", RIBBON_RGB, 0.35))
        tag(st.tags["ribbon"], len(mats) - 1)
    if st.tags["flowers"]:
        cols = sorted(set(st.flower_cols))
        base = len(mats)
        for c in cols:
            mats.append(bf.make_material("flower_%d" % c, FLOWER_RGBS[c], 0.5))
        for petals, c in zip(st.tags["flowers"], st.flower_cols):
            tag(petals, base + cols.index(c))
        mats.append(bf.make_material("flower_centre", CENTRE_RGB, 0.35))
        tag(st.tags["centres"], len(mats) - 1)
    for m in mats:
        me.materials.append(m)
    for p in me.polygons:
        ms = [vmat[v] for v in p.vertices]
        p.material_index = max(set(ms), key=ms.count)
        p.use_smooth = True
    bf.box_uvs(obj, 8.0)

    # Weights.
    w_head = bf.smoothstep(1.40, 1.47, Z)
    back = Y > 0.035
    chain_names = ["Braid_%d" % i for i in range(1, 5)]
    names, Hd, Tl = bf.bone_segments(spec, chain_names)
    D = bf.seg_dist(P, Hd, Tl)
    weights = []
    for i in range(len(P)):
        lst = [("Head", float(w_head[i]))]
        rest = 1.0 - w_head[i]
        if rest > 1e-3:
            if back[i]:
                j = np.argsort(D[i])[:2]
                inv = 1.0 / (D[i, j] ** 2 + 1e-6)
                inv /= inv.sum()
                lst += [(names[j[0]], float(rest * inv[0])), (names[j[1]], float(rest * inv[1]))]
            else:
                side = "Left" if X[i] > 0 else "Right"
                sh = float(bf.smoothstep(0.03, 0.10, abs(X[i])))
                lst += [("UpperChest", float(rest * (1 - 0.5 * sh))), (side + "Shoulder", float(rest * 0.5 * sh))]
        weights.append([(n, w) for n, w in lst if w > 0.005])
    bf.apply_weights(obj, weights)
    bf.skin_to_armature(obj, arm)
    return obj


def hair_ids():
    root = os.path.join(bf.REPO, "data", "wardrobe", "hair")
    ids = []
    if os.path.isdir(root):
        for f in sorted(os.listdir(root)):
            if f.endswith(".tres"):
                for line in open(os.path.join(root, f)):
                    if line.startswith("mesh_path"):
                        ids.append(line.split("/")[-1].split(".glb")[0])
    return ids


def main():
    only = [a for a in sys.argv[1:] if a in STYLES]
    os.makedirs(HAIR_DIR, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=os.path.join(bf.MODEL_DIR, "feyre.blend"))
    arm = bpy.data.objects["Armature"]
    for o in list(bpy.data.objects):
        if o.name not in ("Armature",):
            bpy.data.objects.remove(o)
    spec = bf.skeleton_spec()
    head = Head()
    report = []
    data_ids = hair_ids()
    missing = [i for i in data_ids if i not in STYLES]
    if missing:
        report.append("data ids without a style: %s" % missing)
    for sid, fn in STYLES.items():
        if only and sid not in only:
            continue
        st = Style(head, sid)
        fn(st)
        st.carve_body()
        clear = st.crown_check()
        obj = mesh_style(st, spec, arm)
        bf.export_glb(os.path.join(HAIR_DIR, sid + ".glb"), [obj], arm)
        P = bf.verts_np(obj.data)
        report.append("%-24s tris=%5d mats=%d low_z=%.3f crown_clear=%.4f" % (
            sid, bf.tri_count(obj), len(obj.data.materials), P[:, 2].min(), clear))
    for o in list(bpy.data.objects):
        if o.type == "MESH" and not o.name.startswith("hair_"):
            bpy.data.objects.remove(o)
    bpy.context.preferences.filepaths.save_version = 0
    if not only:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HAIR_DIR, "hair.blend"), compress=True)
    print("\n==== HAIR BUILD REPORT ====")
    print("\n".join(report))


if __name__ == "__main__":
    main()
