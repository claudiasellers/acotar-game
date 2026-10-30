import bpy  # noqa: F401  (provides mathutils)
"""Pure-python mesh builder used by the court-props generators.

Everything is built in Blender space (Z up, metres) into an MB (mesh builder)
holding vertices, faces, per-face colours (linear RGBA, alpha 1 = glow) and
per-face smooth flags. No bpy here except mathutils, so it is deterministic.
"""
import math
from mathutils import Matrix, Vector, Euler

TAU = math.tau


def srgb_to_lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def C(hexs: str, glow: bool = False) -> tuple:
    h = hexs.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return (round(srgb_to_lin(r), 5), round(srgb_to_lin(g), 5), round(srgb_to_lin(b), 5), 1.0 if glow else 0.0)


def G(col: tuple) -> tuple:
    """Same colour, glowing."""
    return (col[0], col[1], col[2], 1.0)


def mix(a: tuple, b: tuple, t: float) -> tuple:
    return tuple(round(a[i] * (1 - t) + b[i] * t, 5) for i in range(3)) + (a[3],)


def T(x=0.0, y=0.0, z=0.0, rx=0.0, ry=0.0, rz=0.0, s=1.0) -> Matrix:
    """Translation @ rotation (degrees, XYZ) @ scale."""
    if isinstance(s, (int, float)):
        s = (s, s, s)
    m_s = Matrix.Diagonal((s[0], s[1], s[2], 1.0))
    m_r = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_matrix().to_4x4()
    return Matrix.Translation((x, y, z)) @ m_r @ m_s


class MB:
    def __init__(self) -> None:
        self.v: list = []
        self.f: list = []
        self.c: list = []
        self.s: list = []

    def add(self, verts, faces, col, xf=None, smooth=True) -> None:
        base = len(self.v)
        for p in verts:
            p = Vector(p)
            if xf is not None:
                p = xf @ p
            self.v.append(p)
        for fc in faces:
            self.f.append([base + i for i in fc])
            self.c.append(col)
            self.s.append(smooth)

    def tris(self) -> int:
        return sum(len(f) - 2 for f in self.f)


# ---------------------------------------------------------------- primitives

def lathe(mb, prof, seg, col, xf=None, cap_bot=True, cap_top=True, smooth=True, phase=0.0, arc=1.0, col_cap=None):
    """Revolve profile [(r, z) or (r, z, dx, dy)] around Z. r==0 makes a pole."""
    verts, faces, rings = [], [], []
    full = arc >= 0.999
    n = seg if full else seg + 1
    for p in prof:
        r, z = p[0], p[1]
        dx = p[2] if len(p) > 2 else 0.0
        dy = p[3] if len(p) > 3 else 0.0
        if r < 1e-6:
            rings.append([len(verts)])
            verts.append((dx, dy, z))
            continue
        ring = []
        for i in range(n):
            a = phase + TAU * arc * i / seg
            ring.append(len(verts))
            verts.append((dx + r * math.cos(a), dy + r * math.sin(a), z))
        rings.append(ring)
    for a_r, b_r in zip(rings, rings[1:]):
        if len(a_r) == 1 and len(b_r) == 1:
            continue
        m = seg if full else seg
        for i in range(m):
            j = (i + 1) % n if full else i + 1
            if len(a_r) == 1:
                faces.append([a_r[0], b_r[i], b_r[j]])
            elif len(b_r) == 1:
                faces.append([a_r[i], a_r[j], b_r[0]])
            else:
                faces.append([a_r[i], a_r[j], b_r[j], b_r[i]])
    mb.add(verts, faces, col, xf, smooth)
    cc = col_cap or col
    if full:
        if cap_bot and len(rings[0]) > 1:
            p = prof[0]
            disc(mb, p[0], seg, cc, (xf or Matrix()) @ T(p[2] if len(p) > 2 else 0, p[3] if len(p) > 3 else 0, p[1], rx=180, rz=0), phase=-phase)
        if cap_top and len(rings[-1]) > 1:
            p = prof[-1]
            disc(mb, p[0], seg, cc, (xf or Matrix()) @ T(p[2] if len(p) > 2 else 0, p[3] if len(p) > 3 else 0, p[1]), phase=phase)


def disc(mb, r, seg, col, xf=None, phase=0.0, rx=None):
    verts = [(r * math.cos(phase + TAU * i / seg), r * math.sin(phase + TAU * i / seg), 0.0) for i in range(seg)]
    if rx is not None:
        verts = [(x, y * rx / r, 0.0) for x, y, _ in verts]
    mb.add(verts, [list(range(seg))], col, xf, smooth=False)


def cyl(mb, r0, r1, h, seg, col, xf=None, caps=True, smooth=True, col_cap=None):
    lathe(mb, [(r0, 0.0), (r1, h)], seg, col, xf, caps, caps, smooth, col_cap=col_cap)


def cone(mb, r, h, seg, col, xf=None, cap=True):
    lathe(mb, [(r, 0.0), (0.0, h)], seg, col, xf, cap, False)


def _sphere_grid(seg, rings):
    verts = [(0.0, 0.0, -1.0)]
    for k in range(1, rings):
        th = math.pi * k / rings - math.pi / 2
        for i in range(seg):
            a = TAU * i / seg
            verts.append((math.cos(th) * math.cos(a), math.cos(th) * math.sin(a), math.sin(th)))
    verts.append((0.0, 0.0, 1.0))
    top = len(verts) - 1
    faces = []
    for i in range(seg):
        faces.append([0, 1 + (i + 1) % seg, 1 + i])
    for k in range(rings - 2):
        b0, b1 = 1 + k * seg, 1 + (k + 1) * seg
        for i in range(seg):
            j = (i + 1) % seg
            faces.append([b0 + i, b0 + j, b1 + j, b1 + i])
    b = 1 + (rings - 2) * seg
    for i in range(seg):
        faces.append([b + i, b + (i + 1) % seg, top])
    return verts, faces


def sphere(mb, rx, ry, rz, col, xf=None, seg=8, rings=6, smooth=True):
    v, f = _sphere_grid(seg, rings)
    mb.add([(x * rx, y * ry, z * rz) for x, y, z in v], f, col, xf, smooth)


def ball(mb, pos, r, col, seg=8, rings=6, xf=None):
    m = (xf or Matrix()) @ T(*pos)
    sphere(mb, r, r, r, col, m, seg, rings)


def rbox(mb, sx, sy, sz, col, xf=None, seg=8, rings=6, e=0.3, rng=None, jit=0.0, base=True):
    """Rounded 'pillow' box. Origin at bottom centre when base=True."""
    v, f = _sphere_grid(seg, rings)
    out = []
    for x, y, z in v:
        def sp(a):
            return math.copysign(abs(a) ** e, a)
        px, py, pz = sp(x), sp(y), sp(z)
        if rng is not None and jit > 0:
            k = 1.0 + rng.uniform(-jit, jit)
            px, py, pz = px * k, py * k, pz * k
        out.append((px * sx / 2, py * sy / 2, pz * sz / 2 + (sz / 2 if base else 0.0)))
    mb.add(out, f, col, xf, True)


def rock(mb, sx, sy, sz, col, rng, xf=None, seg=8, rings=6, jit=0.22, e=0.7, flat_base=True):
    v, f = _sphere_grid(seg, rings)
    out = []
    for x, y, z in v:
        k = 1.0 + rng.uniform(-jit, jit)
        px = math.copysign(abs(x) ** e, x) * k
        py = math.copysign(abs(y) ** e, y) * k
        pz = math.copysign(abs(z) ** e, z) * k
        if flat_base and pz < -0.55:
            pz = -0.55 - (pz + 0.55) * 0.15
        out.append((px * sx / 2, py * sy / 2, (pz + 0.6) * sz / 1.6 * 1.0))
    mb.add(out, f, col, xf, True)


def box(mb, sx, sy, sz, col, xf=None, base=True):
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    z0, z1 = (0.0, sz) if base else (-hz, hz)
    v = [(-hx, -hy, z0), (hx, -hy, z0), (hx, hy, z0), (-hx, hy, z0),
         (-hx, -hy, z1), (hx, -hy, z1), (hx, hy, z1), (-hx, hy, z1)]
    f = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    mb.add(v, f, col, xf, smooth=False)


def torus(mb, R, r, col, xf=None, seg=16, segr=6, arc=1.0, smooth=True):
    full = arc >= 0.999
    n = seg if full else seg + 1
    v, f = [], []
    for i in range(n):
        a = TAU * arc * i / seg
        for j in range(segr):
            b = TAU * j / segr
            rr = R + r * math.cos(b)
            v.append((rr * math.cos(a), rr * math.sin(a), r * math.sin(b)))
    for i in range(seg):
        i2 = (i + 1) % n if full else i + 1
        for j in range(segr):
            j2 = (j + 1) % segr
            f.append([i * segr + j, i2 * segr + j, i2 * segr + j2, i * segr + j2])
    mb.add(v, f, col, xf, smooth)


def tube(mb, pts, r, col, seg=6, xf=None, r_end=None, caps=True):
    """Tube along a polyline of Vectors (radius tapers to r_end)."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    r_end = r if r_end is None else r_end
    v, f = [], []
    up = Vector((0, 0, 1))
    for k, p in enumerate(pts):
        d = (pts[min(k + 1, n - 1)] - pts[max(k - 1, 0)]).normalized()
        ref = up if abs(d.dot(up)) < 0.95 else Vector((1, 0, 0))
        a = d.cross(ref).normalized()
        b = d.cross(a).normalized()
        rr = r + (r_end - r) * k / max(1, n - 1)
        for i in range(seg):
            t = TAU * i / seg
            v.append(p + (a * math.cos(t) + b * math.sin(t)) * rr)
    for k in range(n - 1):
        for i in range(seg):
            j = (i + 1) % seg
            f.append([k * seg + i, k * seg + j, (k + 1) * seg + j, (k + 1) * seg + i])
    if caps:
        f.append(list(range(seg))[::-1])
        f.append([(n - 1) * seg + i for i in range(seg)])
    mb.add(v, f, col, xf, True)


def strip(mb, pts, side, widths, col, xf=None, two_sided=True, cols=None):
    """Flat ribbon along pts; side = Vector giving width direction (per point list or one)."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    if not isinstance(widths, (list, tuple)):
        widths = [widths] * n
    sides = side if isinstance(side, list) else [Vector(side)] * n
    v = []
    for p, w, s in zip(pts, widths, sides):
        s = Vector(s).normalized()
        v.append(p - s * w / 2)
        v.append(p + s * w / 2)
    for k in range(n - 1):
        q = [2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2]
        c = cols[k % len(cols)] if cols else col
        mb.add([v[i] for i in q], [[0, 1, 2, 3]], c, xf, True)
        if two_sided:
            mb.add([v[i] for i in q], [[3, 2, 1, 0]], c, xf, True)


def tri_flag(mb, a, b, tip, col, xf=None):
    mb.add([a, b, tip], [[0, 1, 2], [2, 1, 0]], col, xf, False)


def prism(mb, r, h, col, xf=None, sides=6, tip=0.35):
    """Crystal: hex prism with a pointed top."""
    lathe(mb, [(r, 0.0), (r, h), (0.0, h + r * tip * 3)], sides, col, xf, True, False, smooth=False)


def catenary(a, b, sag, n):
    a, b = Vector(a), Vector(b)
    out = []
    for i in range(n + 1):
        t = i / n
        p = a.lerp(b, t)
        p.z -= sag * 4 * t * (1 - t)
        out.append(p)
    return out


def bloom(mb, pos, r, col, center, xf=None, petals=5, detail=1, tilt=0.0):
    m = (xf or Matrix()) @ T(*pos, rx=tilt)
    if detail == 0:
        sphere(mb, r, r, r * 0.7, col, m, 6, 4)
        return
    for i in range(petals):
        a = TAU * i / petals
        sphere(mb, r * 0.55, r * 0.38, r * 0.18, col, m @ T(math.cos(a) * r * 0.55, math.sin(a) * r * 0.55, 0, rz=math.degrees(a)), 5, 3)
    sphere(mb, r * 0.3, r * 0.3, r * 0.22, center, m @ T(0, 0, r * 0.08), 5, 3)


def spiral_beads(mb, r0, r1, turns, n, br, col, xf=None, seg=4):
    """Raised spiral carving made of small beads in the local XZ plane (face toward -Y)."""
    for i in range(n):
        t = i / max(1, n - 1)
        a = TAU * turns * t
        rr = r0 + (r1 - r0) * t
        sphere(mb, br, br * 0.6, br, col, (xf or Matrix()) @ T(rr * math.cos(a), 0.0, rr * math.sin(a)), seg, 3)
