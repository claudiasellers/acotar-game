"""Shared shapes for the monster weapons and camp gear (lane L88, headless bpy).

Builds on prop_kit / upcoming_kit (one mesh per prop, colour per corner, the
finish in UV.x) and adds the crude vocabulary these need: wind-bent shafts,
knapped and chipped blades, bones, fangs, skulls, lashings, rags and feathers.
Everything is seeded, so a rebuild writes the same file.

R3: this is the horror side of the contrast. The palette is bone, char, rust,
dried blood and river-dark scale, and nothing here glows. The only candy
colours are on the things the monsters stole.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401,I001
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import prop_kit as K  # noqa: E402
import upcoming_kit as U  # noqa: E402
from prop_kit import R, S, T  # noqa: E402,F401

# ------------------------------------------------------------------ palette

def grim(r, g, b):
    """The palette is written as it should read on screen under the game's
    tonemap: dark, but never crushed to black. This lifts the stored value so
    the darks keep their colour and their sheen (bestiary 1.1)."""
    return tuple(round(v ** 0.62, 3) for v in (r, g, b))


BONE = grim(0.74, 0.68, 0.54)
BONE_OLD = grim(0.52, 0.45, 0.33)
BONE_DARK = grim(0.30, 0.25, 0.19)
DRIFTWOOD = grim(0.36, 0.29, 0.24)
BOGWOOD = grim(0.19, 0.15, 0.14)
CHAR = grim(0.10, 0.09, 0.09)
ASH = grim(0.42, 0.40, 0.40)
RUST = grim(0.40, 0.19, 0.11)
BLACK_IRON = grim(0.17, 0.16, 0.20)
FLINT = grim(0.21, 0.22, 0.27)
FLINT_EDGE = grim(0.44, 0.45, 0.50)
SINEW = grim(0.50, 0.38, 0.26)
HIDE = grim(0.33, 0.23, 0.16)
HIDE_PALE = grim(0.50, 0.40, 0.29)
BLOOD = grim(0.26, 0.05, 0.05)
REED = grim(0.50, 0.47, 0.26)
REED_DARK = grim(0.30, 0.29, 0.15)
SCALE = grim(0.11, 0.19, 0.17)
SCALE_PALE = grim(0.42, 0.47, 0.38)
THORN = grim(0.20, 0.09, 0.11)
BRIAR = grim(0.22, 0.24, 0.13)
PETAL_DEAD = grim(0.42, 0.22, 0.24)
GRANITE = grim(0.33, 0.31, 0.29)
MOSS = grim(0.20, 0.26, 0.10)
MEAT = grim(0.42, 0.16, 0.14)
FAT = grim(0.62, 0.52, 0.40)
FEATHER = grim(0.08, 0.08, 0.11)
# stolen things keep the court's colours: the one bright note on each piece
STOLEN_ROSE = (0.80, 0.42, 0.52)
STOLEN_PERI = (0.52, 0.58, 0.82)
STOLEN_MINT = (0.50, 0.76, 0.66)
SILVER = (0.70, 0.70, 0.76)
GILT = K.GOLD
BRASS = (0.62, 0.48, 0.22)
CORD_GREEN = grim(0.20, 0.30, 0.16)
IRON = grim(0.16, 0.13, 0.12)            # mortal iron: black-brown
IRON_WORN = grim(0.46, 0.44, 0.45)      # where an edge has worn bright
BOTTLE = (0.25, 0.42, 0.30, 0.55)


class Prop(U.Prop):
    """Crude, grown and beaten things are rounded: only a real edge (a blade,
    a cut end) shades hard."""

    def add(self, part, color, finish="satin", matrix=None, smooth=True, sharp_deg=72.0, shade=None):
        return super().add(part, color, finish, matrix, smooth, sharp_deg, shade)


def h1(x, seed=0.0):
    """A fixed hash in 0..1."""
    v = math.sin(x * 127.1 + seed * 311.7) * 43758.5453
    return v - math.floor(v)


def wob(x, seed=0.0):
    """Smooth 1D noise in -1..1."""
    i = math.floor(x)
    f = x - i
    f = f * f * (3 - 2 * f)
    return (h1(i, seed) * (1 - f) + h1(i + 1, seed) * f) * 2 - 1


def mottle(base, dark, freq=40.0, seed=0.0, lift=None):
    """Vertex shade: blotches between base and dark, and toward `lift` on a
    second, finer pattern (old bone, chapped hide, lichen on stone)."""
    def shade(co):
        f = 0.5 + 0.5 * math.sin(co.x * freq + seed + math.sin(co.z * freq * 0.7 + co.y * freq * 1.3) * 1.7)
        c = K.mix(base, dark, f * f)
        if lift:
            g = 0.5 + 0.5 * math.sin(co.z * freq * 2.3 + co.x * freq * 1.9 + seed * 2.0)
            c = K.mix(c, lift, max(g - 0.7, 0.0) * 2.0)
        return c
    return shade


def tipped(base, tip, z0, z1, also=None):
    """Vertex shade: base below z0 running to tip at z1 (a bloodied point, a
    charred end), on top of `also` if given."""
    def shade(co):
        c = also(co) if also else base
        return K.mix(c, tip, U._smooth(z0, z1, co.z))
    return shade


# ------------------------------------------------------------------ lofts


def loft(rings, cap0=True, cap1=True):
    """Skins a list of rings (each the same number of points, counter-clockwise
    seen from the far end). Explicit winding, the same faces every run."""
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(vs, vs[1:]):
        for s in range(n):
            k = (s + 1) % n
            bm.faces.new((a[s], a[k], b[k], b[s]))
    if cap0:
        bm.faces.new(list(reversed(vs[0])))
    if cap1:
        bm.faces.new(vs[-1])
    # whichever way the rings were wound, the faces look outward: the signed
    # volume says which, so no builder has to think about ring order
    vol = 0.0
    for f in bm.faces:
        v0 = f.verts[0].co
        for a, b in zip(f.verts[1:], f.verts[2:]):
            vol += v0.dot(a.co.cross(b.co))
    if vol < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    return bm


def curved_blade(path, widths, thick, seed=1.0, chip=0.0, flip=False, back=0.4):
    """A blade swept along `path` [(y, z)] in the YZ plane (a sickle, a scythe,
    a talon). The cutting edge is on the side the path turns toward when it
    bends to +Y going up; flip=True puts it on the other side. widths and
    thick are floats or one per point."""
    n = len(path)
    rings = []
    for i, (y, z) in enumerate(path):
        a, b = path[max(i - 1, 0)], path[min(i + 1, n - 1)]
        t = Vector((0, b[0] - a[0], b[1] - a[1])).normalized()
        nr = Vector((0, t.z, -t.y)) * (-1.0 if flip else 1.0)
        w = widths[i] if isinstance(widths, (list, tuple)) else widths
        th = thick[i] if isinstance(thick, (list, tuple)) else thick
        c = Vector((0, y, z))
        we = w * (1.0 - back) - chip * max(0.0, wob(i * 1.9, seed)) - chip * 0.6 * h1(i, seed + 2.0)
        rings.append([tuple(c - nr * w * back), (th / 2, c.y, c.z), tuple(c + nr * max(we, 0.0005)), (-th / 2, c.y, c.z)])
    return loft(rings)


def arc(cy, cz, r, a0, a1, n, squash=1.0):
    """Points [(y, z)] on a circle arc in the YZ plane, degrees."""
    return [(cy + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cz + r * squash * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
            for i in range(n + 1)]


def wedge(stations, sides_round=0.25):
    """An axe or hammer head running out along +Y. stations: [(y, z_low,
    z_high, half_thick)]: an eight-sided section at each."""
    rings = []
    for y, z0, z1, t in stations:
        c = sides_round * min(t, (z1 - z0) / 2)
        rings.append([(-t, y, z0 + c), (-t + c, y, z0), (t - c, y, z0), (t, y, z0 + c), (t, y, z1 - c), (t - c, y, z1), (-t + c, y, z1), (-t, y, z1 - c)])
    return loft(rings)


def crack(p, a, b, seed=1.0, r=0.0012, n=6, color=None):
    """A dark jagged crack from a to b, sitting just proud of the surface: the
    look of a weapon near its last hit."""
    a, b = Vector(a), Vector(b)
    d = (b - a)
    side = d.cross(Vector((1, 0, 0)))
    if side.length < 1e-5:
        side = d.cross(Vector((0, 1, 0)))
    side.normalize()
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append(tuple(a.lerp(b, t) + side * d.length * 0.08 * wob(i * 1.7, seed) * math.sin(math.pi * t)))
    p.add(K.tube(pts, [r * (0.4 + math.sin(math.pi * i / n)) for i in range(n + 1)], 3), color or CHAR, "matte")


def shaft(length, r0, r1=None, seed=1.0, bend=0.012, knots=0, sides=7, z0=0.0, n=None):
    """A cut branch from z0 up: it wanders, swells at its knots and is never
    round. bend is the sideways wander in metres."""
    r1 = r0 if r1 is None else r1
    n = n or max(6, int(length / 0.09))
    rings = []
    for i in range(n + 1):
        t = i / n
        z = z0 + length * t
        cx = bend * wob(t * 3.1, seed) * math.sin(math.pi * min(t * 1.4, 1.0))
        cy = bend * wob(t * 2.7, seed + 9.0)
        r = r0 + (r1 - r0) * t
        for k in range(knots):
            kz = h1(k, seed + 3.0)
            r *= 1.0 + 0.32 * math.exp(-((t - kz) / 0.035) ** 2)
        ring = []
        for s in range(sides):
            a = 2 * math.pi * s / sides
            rr = r * (1.0 + 0.10 * wob(s * 1.7 + t * 2.0, seed + 5.0))
            ring.append((cx + rr * math.cos(a), cy + rr * math.sin(a) * 0.92, z))
        rings.append(ring)
    return loft(rings)


def blade(stations, thick, seed=1.0, chip=0.0, belly=0.5):
    """A knapped or ground blade standing up Z. stations: [(z, back, edge)],
    the back at Y=back and the cutting edge at Y=edge (edge > back), so the
    edge faces +Y. `thick` is the spine thickness (a float or one per
    station); chip pushes the edge in and out by that many metres."""
    rings = []
    for i, (z, yb, ye) in enumerate(stations):
        t = thick[i] if isinstance(thick, (list, tuple)) else thick
        ye2 = ye - chip * max(0.0, wob(i * 1.9, seed)) - chip * 0.6 * h1(i, seed + 2.0)
        ym = yb + (ye2 - yb) * (1.0 - belly)
        rings.append([(0.0, yb, z), (t / 2, ym, z), (0.0, max(ye2, yb + 1e-4), z), (-t / 2, ym, z)])
    return loft(rings)


def leaf_stations(length, width, n=10, back=0.5, z0=0.0, lean=0.0):
    """Stations for a leaf or spear-point blade: widest a third of the way up."""
    out = []
    for i in range(n + 1):
        t = i / n
        w = width * (math.sin(math.pi * min(t / 0.66, 1.0) * 0.5) if t < 0.33 else (1.0 - ((t - 0.33) / 0.67) ** 1.6)) + 0.0012
        c = lean * t * t
        out.append((z0 + length * t, c - w * back, c + w * (1.0 - back)))
    return out


def fang(length, r, curve=0.3, sides=6, n=7):
    """A curved tooth or thorn from the origin up Z, hooking toward +Y."""
    pts, radii = [], []
    for i in range(n + 1):
        t = i / n
        pts.append((0.0, curve * length * t * t, length * t))
        radii.append(max(r * (1.0 - t ** 1.4), r * 0.03))
    return K.tube(pts, radii, sides)


def bone(length, r, knob=1.9, sides=8):
    """A long bone lying up Z from 0: a waisted shaft with a two-lobed head at
    each end."""
    prof = [(0.0, 0.0), (r * knob * 0.7, r * 0.5), (r * knob, r * 1.6), (r * 1.15, r * 3.2), (r * 0.92, length * 0.5),
            (r * 1.1, length - r * 3.2), (r * knob * 0.95, length - r * 1.6), (r * knob * 0.7, length - r * 0.5), (0.0, length)]
    bm = K.lathe(prof, sides)
    for v in bm.verts:           # squeeze the heads into two lobes
        e = min(v.co.z, length - v.co.z)
        if e < r * 3.0:
            v.co.y *= 0.72
            v.co.x *= 1.0 + 0.18 * (1.0 - e / (r * 3.0))
    return bm


def lash(r, z0, z1, turns, cord=0.004, sides=4, squash=1.0, slack=0.0, seed=1.0):
    """Cord or sinew wound round a shaft of radius r from z0 to z1."""
    n = int(turns * 9)
    pts = []
    for i in range(n + 1):
        t = i / n
        a = 2 * math.pi * turns * t
        rr = r + cord * 0.6 + slack * h1(i, seed)
        pts.append((rr * math.cos(a), rr * math.sin(a) * squash, z0 + (z1 - z0) * t + cord * 0.5 * wob(i * 0.8, seed)))
    bm = K.tube(pts, cord, sides)
    # the turns underneath: a sleeve, so a gap between coils shows more binding and never the bare shaft
    lo, hi = min(z0, z1), max(z0, z1)
    ring = [[bm.verts.new(((r + cord * 0.35) * math.cos(2 * math.pi * s / 8), (r + cord * 0.35) * math.sin(2 * math.pi * s / 8) * squash, z)) for s in range(8)] for z in (lo, hi)]
    for s in range(8):
        k = (s + 1) % 8
        bm.faces.new((ring[0][s], ring[0][k], ring[1][k], ring[1][s]))
    bm.faces.new(list(reversed(ring[0])))
    bm.faces.new(ring[1])
    return bm


def rag(length, width, seed=1.0, sway=0.25, n=6, thick=0.003):
    """A torn strip hanging down -Z from the origin, its end ragged."""
    path = []
    for i in range(n + 1):
        t = i / n
        path.append((sway * length * wob(t * 2.2, seed) * t, -length * t))
    bm = U.ribbon(path, width, thick)
    for v in bm.verts:
        t = -v.co.z / length
        v.co.y *= 1.0 - 0.45 * t * h1(round(v.co.y * 500), seed)
        if t > 0.9:
            v.co.z += length * 0.12 * h1(v.co.y * 90.0, seed + 4.0)
    return bm


def feather(length, width):
    """A flat quill up Z from the origin."""
    bm = K.leaf(length, width)
    return bm


def skull(r, seed=1.0, snout=0.9, n=10):
    """A beast's skull, crown up Z, muzzle toward +Y, resting on its jaw line.
    One closed shell: the sockets are added as dark discs by `skull_on`."""
    bm = U.sphere(r, n, 8)
    for v in bm.verts:
        p = v.co
        if p.y > 0:                  # pull the face out into a muzzle
            k = (p.y / r)
            p.y += r * snout * k * k
            p.x *= 1.0 - 0.45 * k
            p.z *= 1.0 - 0.5 * k
            p.z -= r * 0.28 * k
        p.x *= 0.82
        p.z *= 0.9 + 0.04 * wob(p.x * 30, seed)
        if p.z < -r * 0.45:
            p.z = -r * 0.45 + (p.z + r * 0.45) * 0.25
    return bm


def skull_on(p, m, r, color=BONE, seed=1.0, snout=0.9, horns=0.0, jaw=True):
    """Adds a whole skull to prop p at matrix m: shell, sockets, nose, teeth,
    optional horns of that length."""
    p.add(skull(r, seed, snout), color, "matte", m, shade=mottle(color, BONE_OLD, 60.0 / max(r, 0.02) * 0.05, seed, K.lighter(color, 0.15)))
    for sx in (-1, 1):
        p.add(U.sphere(r * 0.27, 7, 5), CHAR, "matte", m @ T(sx * r * 0.42, r * 0.62, r * 0.12) @ S(0.6, 0.75, 1.0))
    p.add(U.sphere(r * 0.14, 6, 4), CHAR, "matte", m @ T(0, r * (1.0 + snout * 0.82), -r * 0.08) @ S(1.0, 0.6, 0.8))
    if jaw:
        for i in range(5):
            for sx in (-1, 1):
                y = r * (0.75 + snout * 0.2 * i)
                p.add(K.cyl(r * 0.05, r * 0.2, 4, r2=0.0), K.lighter(color, 0.1), "satin",
                      m @ T(sx * r * (0.36 - 0.05 * i), y, -r * 0.42) @ R("X", 180))
    if horns > 0:
        for sx in (-1, 1):
            p.add(fang(horns, r * 0.2, 0.5, 6, 6), BONE_DARK, "satin",
                  m @ T(sx * r * 0.5, -r * 0.1, r * 0.6) @ R("Y", sx * 55) @ R("Z", sx * -30))


def stone(r, seed, flat=1.0, sub=2):
    bm = U.rock(r, sub, seed, 0.2)
    for v in bm.verts:
        v.co.z *= flat
    return bm


def ground_ring(p, r, n, size, seed, color=GRANITE, flat=0.7):
    """A ring of field stones (a hearth, a nest edge)."""
    for i in range(n):
        a = 2 * math.pi * i / n + 0.2 * wob(i, seed)
        s = size * (0.75 + 0.5 * h1(i, seed))
        p.add(stone(s, seed + i, flat), color, "matte", T(r * math.cos(a), r * math.sin(a), s * flat * 0.45) @ R("Z", i * 47.0),
              shade=mottle(color, K.darker(color, 0.35), 24.0, seed + i, MOSS if h1(i, seed + 7) > 0.6 else None))


def cord_between(a, b, sag, r=0.004, n=10, sides=4):
    """A slack cord from a to b; returns (bmesh, points) so things can hang off it."""
    a, b = Vector(a), Vector(b)
    pts = []
    for i in range(n + 1):
        t = i / n
        q = a.lerp(b, t)
        q.z -= sag * 4 * t * (1 - t)
        pts.append(tuple(q))
    return K.tube(pts, r, sides), pts


def pole_between(a, b, r, seed=1.0, sides=6):
    """A rough pole from a to b (any direction)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bm = shaft(d.length, r, r * 0.8, seed, bend=d.length * 0.012, knots=2, sides=sides)
    m = Matrix.Translation(a) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bm.transform(m)
    return bm


def wood(base, seed=0.0, amount=0.3):
    return mottle(base, K.darker(base, amount), 55.0, seed, K.lighter(base, 0.12))


def forked_stake(p, x, y, h, r, seed, lean=0.0):
    """A stake driven into the ground with a fork at the top; returns the crotch."""
    m = T(x, y, -0.05) @ R("Y", lean)
    p.add(shaft(h, r * 1.2, r, seed, 0.02, 2, 6), DRIFTWOOD, "matte", m, shade=wood(DRIFTWOOD, seed))
    for sx in (-1, 1):
        p.add(shaft(h * 0.16, r * 0.8, r * 0.5, seed + sx, 0.004, 0, 5), DRIFTWOOD, "matte", m @ T(0, 0, h - 0.01) @ R("Y", sx * 32),
              shade=wood(DRIFTWOOD, seed + 1))
    return m @ Vector((0, 0, h + 0.01))


# ------------------------------------------------------------------ stolen things


def trinket(p, kind, m, seed=1.0):
    """One stolen thing hanging from the origin of m down -Z: the only clean
    colour on a monster's gear. kinds: spoon, key, bell, ring, button, ribbon,
    thimble, fork, coin."""
    if kind == "spoon":
        p.add(K.tube([(0, 0, 0), (0, 0.002, -0.07), (0, 0, -0.09)], [0.0022, 0.003, 0.004], 5), SILVER, "mirror", m)
        p.add(U.sphere(0.014, 8, 5), SILVER, "mirror", m @ T(0, 0, -0.108) @ S(1.0, 0.25, 1.5))
    elif kind == "fork":
        p.add(K.tube([(0, 0, 0), (0, 0.002, -0.08)], [0.0022, 0.0035], 5), SILVER, "mirror", m)
        for i in range(3):
            p.add(K.cyl(0.0014, 0.04, 4, r2=0.0004), SILVER, "mirror", m @ T((i - 1) * 0.006, 0, -0.08) @ R("X", 180))
    elif kind == "key":
        p.add(K.torus(0.011, 0.0025, 10, 4), GILT, "gold", m @ T(0, 0, -0.012) @ R("X", 90))
        p.add(K.cyl(0.0025, 0.055, 5), GILT, "gold", m @ T(0, 0, -0.022) @ R("X", 180))
        for dz in (0.0, 0.012):
            p.add(K.box(0.012, 0.003, 0.006), GILT, "gold", m @ T(0.007, 0, -0.07 + dz))
    elif kind == "bell":
        p.add(K.lathe([(0.003, 0.0), (0.008, -0.004), (0.011, -0.018), (0.016, -0.03), (0.017, -0.033)], 8, cap_bottom=False, cap_top=False),
              GILT, "gold", m)
        p.add(U.sphere(0.004, 5, 4), BLACK_IRON, "matte", m @ T(0, 0, -0.031))
    elif kind == "ring":
        p.add(K.torus(0.010, 0.002, 10, 4), GILT, "gold", m @ T(0, 0, -0.012) @ R("X", 90))
        p.add(U.sphere(0.0045, 6, 4), STOLEN_ROSE, "pearl", m @ T(0, 0, -0.024))
    elif kind == "button":
        p.add(K.lathe([(0.0, 0.0), (0.011, 0.001), (0.012, 0.003), (0.0, 0.004)], 8), K.PEARL, "pearl", m @ T(0, 0, -0.014) @ R("X", 90))
    elif kind == "thimble":
        p.add(K.lathe([(0.009, -0.022), (0.008, -0.004), (0.005, 0.0), (0.0, 0.0)], 8, cap_bottom=False), SILVER, "mirror", m)
    elif kind == "coin":
        p.add(K.lathe([(0.0, 0.0), (0.012, 0.0), (0.012, 0.002), (0.0, 0.002)], 8), GILT, "gold", m @ T(0, 0, -0.014) @ R("X", 90))
    elif kind == "ribbon":
        col = (STOLEN_ROSE, STOLEN_PERI, STOLEN_MINT)[int(h1(seed) * 3) % 3]
        p.add(rag(0.14, 0.014, seed, 0.3, 6, 0.0012), col, "fabric", m)


def trinkets_on(p, pts, kinds, seed=1.0, drop=0.03):
    """Hangs trinkets on short threads along a cord's points."""
    step = max(1, (len(pts) - 2) // len(kinds))
    for i, kind in enumerate(kinds):
        q = Vector(pts[min(1 + i * step, len(pts) - 2)])
        d = drop * (0.6 + 0.8 * h1(i, seed))
        p.add(K.tube([tuple(q), (q.x, q.y, q.z - d)], 0.0012, 3), SINEW, "matte")
        trinket(p, kind, T(q.x, q.y, q.z - d) @ R("Z", 360 * h1(i, seed + 1.0)), seed + i)
