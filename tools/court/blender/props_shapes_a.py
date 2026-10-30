"""Court-props builders, part A: palette, shared motifs, Hill of the Rite, watchtower, fells.

A builder has the signature  fn(mb, rng, out, **params)  where mb is the base MB,
rng a seeded random.Random, and out a dict where it may store extra MBs:
  out["col"]   collision boxes (exported as <id>_col, static body, layer 1)
  out["climb"] climbable quads (exported as <id>_climb)
Front of every asset faces Blender -Y (glTF / Godot +Z).
"""
import math
from mathutils import Vector
import props_lib as L
from props_lib import T, C, G, MB, TAU

# ------------------------------------------------------------------ palette (sRGB hex)
P = {
    "pearl": C("f4eee8"), "pearl_lilac": C("ece2f2"), "pearl_rose": C("f6e4e6"), "stone_pale": C("e3dcd6"),
    "rose": C("f4a6c0"), "blush": C("f9d3dc"), "lilac": C("c9b3e6"), "peri": C("a9b8f0"), "mint": C("b5ead0"),
    "butter": C("fce79a"), "gold": C("e7c25b"), "gold_dk": C("c99a3a"), "rosegold": C("e8b4a0"), "cream": C("fff6e0"),
    "leaf": C("8cd3a0"), "leaf_dk": C("5fb884"), "moss": C("a6e3b8"), "wood": C("c99a74"), "wood_dk": C("a87a5a"),
    "wood_pale": C("e2c3a2"), "sky": C("bee3f8"), "water": C("9fd8f0"), "white": C("ffffff"), "coral": C("f7a08c"),
    "teal": C("8fd9c8"), "berry": C("e86a9a"), "plum": C("9a6fb8"), "door_mint": C("9ed8c0"), "red": C("e8707e"),
    "lantern": C("ffe7a8", True), "glow_rose": C("ffc4dc", True), "glow_lilac": C("dccaff", True),
    "glow_teal": C("a8fff0", True), "glow_star": C("f4f6ff", True), "glow_gold": C("ffd88a", True),
    "flame": C("ffb45c", True), "flame_core": C("fff0a8", True), "window_glow": C("ffe2a0", True),
    # autumn
    "crimson": C("b3263a"), "amber": C("e39a2d"), "au_gold": C("d9a520"), "rust": C("9e4a2a"), "au_stone": C("c9b4a0"),
    "au_stone_dk": C("a38c78"), "thorn": C("5a2430"), "thorn_dk": C("3c1820"), "ward": C("ffc86b", True),
    # blight (dark, desaturated, never pastel)
    "bl_black": C("161618"), "bl_dk": C("2a2a2d"), "bl_grey": C("45454a"), "bl_ash": C("67676c"), "bl_bone": C("8e8b86"),
}
FLOWER_COLS = ["rose", "lilac", "butter", "peri", "blush", "coral", "white", "berry"]


def pc(name):
    return P[name]


def colbox(out, sx, sy, sz, xf=None, base=True):
    """Add a collision box to out['col']."""
    mbc = out.setdefault("col", MB())
    L.box(mbc, sx, sy, sz, P["white"], xf, base)


def colcyl(out, r, h, xf=None, seg=10):
    mbc = out.setdefault("col", MB())
    L.cyl(mbc, r, r, h, seg, P["white"], xf, smooth=False)


def climb_band(out, r, a0, a1, z0, z1, cols=3, rows=4, off=0.12):
    """Climbable quads on a cylinder face between angles a0..a1 (deg)."""
    mbc = out.setdefault("climb", MB())
    for i in range(cols):
        for j in range(rows):
            aa = math.radians(a0 + (a1 - a0) * i / cols)
            ab = math.radians(a0 + (a1 - a0) * (i + 1) / cols)
            za = z0 + (z1 - z0) * j / rows
            zb = z0 + (z1 - z0) * (j + 1) / rows
            rr = r + off
            q = [(rr * math.cos(aa), rr * math.sin(aa), za), (rr * math.cos(ab), rr * math.sin(ab), za),
                 (rr * math.cos(ab), rr * math.sin(ab), zb), (rr * math.cos(aa), rr * math.sin(aa), zb)]
            mbc.add(q, [[0, 1, 2, 3]], P["mint"], None, False)


def ivy(mb, rng, pts, size=0.22, cols=("leaf", "leaf_dk", "moss"), flowers=0.25, xf=None):
    """Leaf blobs at points (list of (pos, normal_yaw_deg))."""
    for p, yaw in pts:
        s = size * rng.uniform(0.7, 1.3)
        L.sphere(mb, s, s * 0.35, s * 0.8, P[cols[rng.randrange(len(cols))]],
                 (xf or T()) @ T(*p, rz=yaw + 90, rx=rng.uniform(-25, 25)), 5, 3)
        if rng.random() < flowers:
            L.ball(mb, p, s * 0.35, P[FLOWER_COLS[rng.randrange(len(FLOWER_COLS))]], 5, 3, xf)


def ivy_on_cyl(mb, rng, r, a0, a1, z0, z1, n, **kw):
    pts = []
    for _ in range(n):
        a = rng.uniform(a0, a1)
        z = rng.uniform(z0, z1)
        rr = r(z) if callable(r) else r
        pts.append(((rr * math.cos(math.radians(a)), rr * math.sin(math.radians(a)), z), a))
    ivy(mb, rng, pts, **kw)


def flecks(mb, rng, n, sx, sy, z0, z1, col, size=0.05):
    """Tiny gold flecks / glitter specks scattered on the surface of a rough ellipsoid volume."""
    for _ in range(n):
        a = rng.uniform(0, TAU)
        z = rng.uniform(z0, z1)
        t = (z - z0) / max(1e-3, z1 - z0)
        k = math.sqrt(max(0.05, 1 - (2 * t - 1) ** 2)) if z1 - z0 > 0 else 1
        x, y = math.cos(a) * sx / 2 * (0.75 + 0.3 * k), math.sin(a) * sy / 2 * (0.75 + 0.3 * k)
        L.sphere(mb, size, size, size, col, T(x, y, z, rz=math.degrees(a)), 4, 2)


def hanging_ribbon(mb, top, length, col, sway, width=0.08, n=6, side=(1, 0, 0)):
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((top[0] + sway[0] * t * t, top[1] + sway[1] * t * t, top[2] - length * t))
    L.strip(mb, pts, Vector(side), width, col)


# ------------------------------------------------------------------ Hill of the Rite

def standing_stone(mb, rng, out, h=4.0, w=1.4, d=0.8, lean=0.0, spirals=1, ribbon=None):
    stone = P["stone_pale"]
    L.rock(mb, w, d, h, stone, rng, T(rx=lean), seg=10, rings=9, jit=0.06, e=0.55)
    xf = T(rx=lean)
    # carved spirals (gold-flecked raised beads) on the front face
    for k in range(spirals):
        zc = h * (0.62 - 0.28 * k)
        L.spiral_beads(mb, 0.04, w * 0.24, 2.2, 22, 0.045, P["gold"], xf @ T(0, -d * 0.43, zc))
    flecks(mb, rng, 14, w * 0.95, d * 0.95, h * 0.1, h * 0.85, P["gold"], 0.03)
    # moss cushion and wildflowers at the foot
    for i in range(7):
        a = TAU * i / 7 + rng.uniform(0, 0.4)
        L.sphere(mb, 0.35, 0.3, 0.12, P["moss"], T(math.cos(a) * w * 0.5, math.sin(a) * d * 0.6, 0.0), 6, 3)
        if i % 2 == 0:
            L.bloom(mb, (math.cos(a) * w * 0.62, math.sin(a) * d * 0.75, 0.12), 0.09, P[FLOWER_COLS[i % 8]], P["butter"], detail=0)
    if ribbon:
        zr = h * 0.42
        L.torus(mb, w * 0.42, 0.035, P[ribbon], xf @ T(0, 0, zr, s=(1, d / w, 1)), 16, 4)
        hanging_ribbon(mb, (0.1, -d * 0.45, zr), h * 0.32, P[ribbon], (0.25, -0.15), 0.09)
        hanging_ribbon(mb, (-0.12, -d * 0.45, zr), h * 0.26, P["gold"], (-0.2, -0.2), 0.06)
    colbox(out, w * 0.85, d * 0.85, h * 0.95, T(rx=lean))


def altar_stone(mb, rng, out):
    s = P["stone_pale"]
    L.rbox(mb, 0.6, 0.9, 0.8, s, T(-0.65, 0, 0), e=0.4)
    L.rbox(mb, 0.6, 0.9, 0.8, s, T(0.65, 0, 0), e=0.4)
    L.rbox(mb, 2.4, 1.3, 0.35, s, T(0, 0, 0.75), seg=10, rings=6, e=0.3)
    L.torus(mb, 0.5, 0.025, P["gold"], T(0, 0, 1.1, s=(1.8, 0.95, 1)), 24, 4)
    L.spiral_beads(mb, 0.03, 0.32, 2.5, 26, 0.035, P["gold"], T(0, 0, 1.1, rx=90))
    for i, x in enumerate((-0.95, -0.75, 0.8, 1.0)):
        hh = 0.12 + 0.06 * (i % 2)
        L.cyl(mb, 0.04, 0.04, hh, 8, P["cream"], T(x, 0.45 - 0.1 * i % 0.3, 1.1))
        L.sphere(mb, 0.025, 0.025, 0.05, P["flame"], T(x, 0.45 - 0.1 * i % 0.3, 1.1 + hh + 0.03), 5, 3)
    for i in range(6):
        L.bloom(mb, (-0.4 + i * 0.16, -0.4 + 0.05 * (i % 2), 1.1), 0.07, P[FLOWER_COLS[i]], P["butter"], detail=0)
    hanging_ribbon(mb, (-1.1, -0.66, 1.05), 0.7, P["rose"], (0, -0.05), 0.07)
    hanging_ribbon(mb, (1.1, -0.66, 1.05), 0.7, P["lilac"], (0, -0.05), 0.07)
    flecks(mb, rng, 12, 2.3, 1.2, 0.2, 1.0, P["gold"], 0.025)
    colbox(out, 2.4, 1.3, 1.1)


def _rock_chain(mb, rng, pts, size, col, moss=True, seg=8, rings=6):
    for p, s in zip(pts, size):
        sx, sy, sz = s
        L.rock(mb, sx, sy, sz, col, rng, T(p[0], p[1], p[2] - sz * 0.1, rz=rng.uniform(0, 360)), seg=seg, rings=rings, jit=0.18)
        if moss and rng.random() < 0.55:
            L.sphere(mb, sx * 0.35, sy * 0.35, sz * 0.12, P["moss"], T(p[0], p[1], p[2] + sz * 0.78), 6, 3)


def cave_mouth(mb, rng, out):
    stone = P["stone_pale"]
    pts, sizes = [], []
    n = 13
    for i in range(n):
        t = i / (n - 1)
        a = math.pi * t
        x = -4.6 * math.cos(a)
        z = 5.2 * math.sin(a) ** 0.8
        pts.append((x, rng.uniform(-0.3, 0.3), max(0.0, z - 1.0)))
        big = 2.6 if i in (0, 1, n - 2, n - 1) else 1.9
        sizes.append((big * rng.uniform(0.9, 1.15), 3.0 * rng.uniform(0.85, 1.1), big * 1.1))
    _rock_chain(mb, rng, pts, sizes, stone)
    # flank masses that tie the arch into the hill
    for sx in (-1, 1):
        L.rock(mb, 2.8, 4.0, 3.2, P["pearl_lilac"], rng, T(sx * 5.4, 0.8, 0), seg=10, rings=7)
    # gold-flecked lintel spiral and ribbons tied across the mouth
    L.spiral_beads(mb, 0.05, 0.55, 2.5, 30, 0.07, P["gold"], T(0, -1.55, 5.3))
    flecks(mb, rng, 30, 9.0, 3.0, 0.5, 5.5, P["gold"], 0.05)
    rib = L.catenary((-3.4, -1.4, 4.2), (3.4, -1.4, 4.2), 0.8, 10)
    L.tube(mb, rib, 0.025, P["gold"], seg=4)
    for i, p in enumerate(rib[1:-1:2]):
        hanging_ribbon(mb, tuple(p), 0.9 + 0.2 * (i % 2), P[["rose", "lilac", "butter", "peri", "mint"][i % 5]], (0.05, -0.1), 0.08)
    ivy(mb, rng, [((rng.uniform(-4.5, 4.5), -1.5, rng.uniform(0.2, 1.4)), -90) for _ in range(14)], 0.3, flowers=0.5)
    colbox(out, 2.6, 3.0, 4.5, T(-4.4, 0, 0))
    colbox(out, 2.6, 3.0, 4.5, T(4.4, 0, 0))
    colbox(out, 9.0, 3.0, 1.6, T(0, 0, 4.4))
    colbox(out, 2.8, 4.0, 3.0, T(5.4, 0.8, 0))
    colbox(out, 2.8, 4.0, 3.0, T(-5.4, 0.8, 0))


def cave_wall(mb, rng, out, length=6.0, height=4.0, curve=0.8):
    stone = P["pearl_lilac"]
    pts, sizes = [], []
    cols_n, rows_n = 5, 3
    for i in range(cols_n):
        for j in range(rows_n):
            t = i / (cols_n - 1) - 0.5
            x = t * length
            y = curve * (4 * t * t - 1) * 0.5
            z = j * height / rows_n
            pts.append((x + rng.uniform(-0.2, 0.2), y, z))
            sizes.append((length / cols_n * 1.4, 1.4 * rng.uniform(0.8, 1.2), height / rows_n * 1.5))
    _rock_chain(mb, rng, pts, sizes, stone, moss=False, seg=7, rings=5)
    flecks(mb, rng, 22, length, 1.2, 0.3, height, P["gold"], 0.04)
    # pale glow lichen
    for _ in range(10):
        L.sphere(mb, 0.12, 0.05, 0.09, P["glow_teal"], T(rng.uniform(-length / 2, length / 2), -0.75, rng.uniform(0.3, height)), 5, 3)
    colbox(out, length, 1.4, height, T(0, -curve * 0.1, 0))


def cave_pillar(mb, rng, out):
    prof = []
    for k in range(9):
        z = 5.0 * k / 8
        r = 0.9 - 0.45 * math.sin(math.pi * k / 8) + rng.uniform(-0.06, 0.06)
        prof.append((r, z, rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05)))
    L.lathe(mb, prof, 12, P["stone_pale"])
    for k in range(4):
        L.torus(mb, 0.55 + 0.1 * (k % 2), 0.02, P["gold"], T(0, 0, 1.2 + k * 0.9, rx=rng.uniform(-8, 8)), 14, 3)
    flecks(mb, rng, 16, 1.2, 1.2, 0.3, 4.6, P["gold"], 0.03)
    for i in range(5):
        a = TAU * i / 5
        L.rock(mb, 0.5, 0.5, 0.4, P["pearl_lilac"], rng, T(math.cos(a) * 0.95, math.sin(a) * 0.95, 0), seg=6, rings=4)
    colcyl(out, 0.75, 5.0)


def cave_pool_rim(mb, rng, out):
    n = 12
    for i in range(n):
        a = TAU * i / n
        L.rock(mb, 1.1, 0.8, 0.55, P["pearl"], rng, T(math.cos(a) * 1.9, math.sin(a) * 1.5, 0, rz=math.degrees(a) + 90), seg=7, rings=5)
    L.disc(mb, 1.75, 20, P["glow_teal"], T(0, 0, 0.18, s=(1, 0.8, 1)))
    L.disc(mb, 1.0, 14, P["glow_star"], T(0, 0, 0.19, s=(1, 0.8, 1)))
    flecks(mb, rng, 18, 4.2, 3.4, 0.15, 0.5, P["glow_star"], 0.035)
    for i in range(4):
        a = TAU * i / 4 + 0.3
        L.prism(mb, 0.06, 0.25, P["glow_lilac"], T(math.cos(a) * 2.1, math.sin(a) * 1.7, 0.35, rx=15, rz=math.degrees(a)))
    colbox(out, 4.6, 3.8, 0.4)


def bonfire(mb, rng, out):
    for i in range(14):
        a = TAU * i / 14
        L.rock(mb, 0.42, 0.34, 0.3, P["stone_pale"], rng, T(math.cos(a) * 1.15, math.sin(a) * 1.15, 0, rz=math.degrees(a)), seg=6, rings=4)
    for i in range(8):
        a = TAU * i / 8
        base = Vector((math.cos(a) * 0.85, math.sin(a) * 0.85, 0.05))
        tip = Vector((math.cos(a) * 0.1, math.sin(a) * 0.1, 1.6))
        L.tube(mb, [base, tip], 0.08, P["wood_dk"] if i % 2 else P["wood"], seg=6, r_end=0.05)
    for i in range(3):
        a = TAU * i / 3 + 0.4
        L.cyl(mb, 0.12, 0.12, 1.4, 7, P["wood"], T(math.cos(a) * 0.25, math.sin(a) * 0.25, 0.15, ry=90, rz=math.degrees(a)))
    for k, (r, h, c) in enumerate(((0.55, 1.5, "flame"), (0.35, 1.9, "flame_core"), (0.25, 1.2, "glow_gold"))):
        for j in range(3):
            a = TAU * j / 3 + k
            L.cone(mb, r * 0.6, h * (0.8 + 0.1 * j), 7, P[c], T(math.cos(a) * 0.15 * k, math.sin(a) * 0.15 * k, 0.2))
    for i in range(10):
        L.ball(mb, (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(1.8, 2.6)), 0.03, P["flame_core"], 4, 2)
    colcyl(out, 1.3, 0.35)


def rite_drum(mb, rng, out):
    xf = T(0, 0, 1.3, rx=80)
    L.lathe(mb, [(0.72, -0.18), (0.75, -0.18), (0.75, 0.18), (0.72, 0.18)], 24, P["wood"], xf, False, False)
    L.disc(mb, 0.72, 24, P["cream"], xf @ T(0, 0, 0.17))
    L.disc(mb, 0.72, 24, P["cream"], xf @ T(0, 0, -0.17, rx=180))
    L.spiral_beads(mb, 0.02, 0.45, 2.4, 22, 0.03, P["crimson"], xf @ T(0, 0, 0.18, rx=-90))
    L.torus(mb, 0.74, 0.03, P["gold"], xf @ T(0, 0, 0.18), 24, 4)
    L.torus(mb, 0.74, 0.03, P["gold"], xf @ T(0, 0, -0.18), 24, 4)
    for i in range(8):
        a = TAU * i / 8
        L.tube(mb, [(0.74 * math.cos(a), 0.74 * math.sin(a), -0.18), (0.74 * math.cos(a + 0.4), 0.74 * math.sin(a + 0.4), 0.18)],
               0.012, P["rose"], seg=3, xf=xf)
    for sx in (-1, 1):
        L.tube(mb, [(sx * 0.55, -0.35, 0.0), (sx * 0.6, -0.05, 1.2)], 0.045, P["wood_dk"], seg=6)
        L.tube(mb, [(sx * 0.55, 0.35, 0.0), (sx * 0.6, 0.05, 1.2)], 0.045, P["wood_dk"], seg=6)
        L.ball(mb, (sx * 0.6, 0, 1.25), 0.06, P["gold"], 6, 4)
    L.tube(mb, [(-0.55, 0, 0.35), (0.55, 0, 0.35)], 0.035, P["wood_dk"], seg=6)
    for sx in (-1, 1):
        L.tube(mb, [(sx * 0.3, -0.5, 0.02), (sx * 0.2, -0.3, 0.05)], 0.02, P["wood_pale"], seg=5)
        L.ball(mb, (sx * 0.2, -0.3, 0.05), 0.05, P["blush"], 6, 4)
    hanging_ribbon(mb, (0.6, 0, 1.2), 0.8, P["gold"], (0.1, -0.15), 0.06)
    hanging_ribbon(mb, (-0.6, 0, 1.2), 0.8, P["rose"], (-0.1, -0.15), 0.06)
    colbox(out, 1.5, 0.8, 2.0)


def terrace_wall(mb, rng, out, radius=10.0, length=8.0, height=1.4):
    ang = length / radius
    courses = 3
    for c in range(courses):
        n = 9 + (c % 2)
        for i in range(n):
            t = (i + 0.5 * (c % 2)) / n
            a = -ang / 2 + ang * t
            x = math.sin(a) * radius
            y = radius - math.cos(a) * radius
            sw = length / n * 1.05
            L.rbox(mb, sw, 0.7, height / courses * 1.05, P["stone_pale"] if (i + c) % 3 else P["pearl_rose"],
                   T(x, y, c * height / courses, rz=math.degrees(a)), seg=6, rings=4, e=0.35, rng=rng, jit=0.05)
    for i in range(14):
        t = i / 13
        a = -ang / 2 + ang * t
        p = (math.sin(a) * radius, radius - math.cos(a) * radius + 0.1, height)
        L.sphere(mb, 0.35, 0.3, 0.14, P["moss"], T(*p), 6, 3)
        if i % 2 == 0:
            L.bloom(mb, (p[0], p[1] - 0.25, p[2] + 0.05), 0.1, P[FLOWER_COLS[i % 8]], P["butter"], detail=0)
    for k in range(4):
        a = -ang / 2 + ang * (k + 0.5) / 4
        p = (math.sin(a) * radius, radius - math.cos(a) * radius - 0.38, height * 0.85)
        hanging_ribbon(mb, p, 0.6, P[["rose", "gold", "lilac", "peri"][k]], (0, -0.05), 0.06)
    for k in range(4):
        a = -ang / 2 + ang * (k + 0.5) / 4
        colbox(out, length / 4 * 1.02, 0.7, height, T(math.sin(a) * radius, radius - math.cos(a) * radius, 0, rz=math.degrees(a)))


def ribbon_pole(mb, rng, out):
    L.cyl(mb, 0.09, 0.07, 4.2, 10, P["pearl"])
    for k in range(5):
        L.torus(mb, 0.085, 0.018, P["gold"], T(0, 0, 0.6 + k * 0.8), 10, 3)
    L.ball(mb, (0, 0, 4.3), 0.13, P["gold"], 10, 6)
    L.cone(mb, 0.05, 0.25, 6, P["gold"], T(0, 0, 4.4))
    cols = ["rose", "lilac", "butter", "mint", "peri", "blush", "gold", "coral"]
    for i, c in enumerate(cols):
        a = TAU * i / len(cols)
        top = (math.cos(a) * 0.1, math.sin(a) * 0.1, 4.15)
        hanging_ribbon(mb, top, 2.4 + 0.3 * (i % 3), P[c], (math.cos(a) * 0.7, math.sin(a) * 0.7), 0.1, n=8,
                       side=(-math.sin(a), math.cos(a), 0))
    L.rock(mb, 0.7, 0.7, 0.3, P["stone_pale"], rng, seg=7, rings=4)
    for i in range(6):
        a = TAU * i / 6
        L.bloom(mb, (math.cos(a) * 0.45, math.sin(a) * 0.45, 0.15), 0.08, P[FLOWER_COLS[i]], P["butter"], detail=0)
    colcyl(out, 0.15, 4.2, seg=6)


# ------------------------------------------------------------------ watchtower

def _tower_r(z):
    return 3.2 - 0.03 * z


def watchtower_base(mb, rng, out, height=13.0):
    out["keep_origin"] = True
    stone = P["pearl"]
    prof = [(3.45, 0.0), (3.45, 0.6), (_tower_r(0.6), 0.6)]
    for k in range(1, 7):
        z = 0.6 + (height - 0.6) * k / 6
        prof.append((_tower_r(z), z))
    L.lathe(mb, prof, 20, stone, cap_bot=False, cap_top=False)
    for z in (0.6, height - 0.2):
        L.torus(mb, _tower_r(z) + 0.03, 0.12, P["rosegold"], T(0, 0, z), 20, 3)
    # pastel plaster band
    L.lathe(mb, [(_tower_r(5.0) + 0.02, 5.0), (_tower_r(8.4) + 0.02, 8.4)], 20, P["blush"], cap_bot=False, cap_top=False)
    # round door (front, -Y)
    yd = -_tower_r(1.5) - 0.02
    L.rbox(mb, 1.5, 0.3, 2.4, P["door_mint"], T(0, yd, 0.6), e=0.5, seg=8, rings=6)
    L.torus(mb, 0.78, 0.07, P["gold"], T(0, yd - 0.12, 1.9, rx=90, s=(1, 1.5, 1)), 12, 3, arc=0.5)
    L.ball(mb, (0.45, yd - 0.17, 1.6), 0.07, P["gold"], 6, 4)
    # arched glowing windows at angles
    for k, (ang, z) in enumerate(((30, 3.0), (150, 3.4), (250, 6.6), (90, 10.4))):
        a = math.radians(ang)
        r = _tower_r(z) + 0.02
        L.rbox(mb, 0.75, 0.15, 1.3, P["window_glow"], T(r * math.cos(a), r * math.sin(a), z, rz=ang + 90), e=0.5, seg=6, rings=4)
        L.torus(mb, 0.42, 0.06, P["gold"], T(r * math.cos(a) * 1.01, r * math.sin(a) * 1.01, z + 0.85, rz=ang + 90, rx=90, s=(1, 1.2, 1)), 8, 3, arc=0.5)
        L.rbox(mb, 0.95, 0.35, 0.18, P["wood_pale"], T((r + 0.12) * math.cos(a), (r + 0.12) * math.sin(a), z - 0.12, rz=ang + 90), seg=6, rings=4)
        for b in range(2):
            L.bloom(mb, ((r + 0.2) * math.cos(a + (b - 1) * 0.08), (r + 0.2) * math.sin(a + (b - 1) * 0.08), z + 0.08),
                    0.1, P[FLOWER_COLS[(k + b) % 8]], P["butter"], detail=0)
    # ivy handhold ladder up the front face above the door
    ivy_on_cyl(mb, rng, lambda z: _tower_r(z) + 0.05, -112, -68, 2.8, height, 30, size=0.38, flowers=0.25)
    climb_band(out, _tower_r(8.0), -115, -65, 2.8, height, cols=3, rows=5)
    for i in range(6):
        a = TAU * i / 6 + 0.5
        L.rock(mb, 0.8, 0.6, 0.5, P["stone_pale"], rng, T(3.9 * math.cos(a), 3.9 * math.sin(a), 0), seg=6, rings=4)
        L.bloom(mb, (4.1 * math.cos(a + 0.2), 4.1 * math.sin(a + 0.2), 0.1), 0.14, P[FLOWER_COLS[i]], P["butter"], detail=0)
    colcyl(out, 3.2, height, seg=12)




def watchtower_stair(mb, rng, out, height=13.0):
    """Exterior spiral stair of the watchtower; shares watchtower_base's origin (place both at the same transform)."""
    out["keep_origin"] = True
    # exterior spiral stair: 300 deg from beside the door round to the top, leaving the ivy face (-120..-60) open
    steps = 44
    a0, a1 = -55.0, 235.0
    for i in range(steps):
        t = (i + 0.5) / steps
        ang = a0 + (a1 - a0) * t
        z = 0.6 + (height - 0.9) * t
        a = math.radians(ang)
        rr = _tower_r(z) + 0.6
        xf = T(rr * math.cos(a), rr * math.sin(a), z - 0.3, rz=ang)
        L.box(mb, 1.2, 0.62, 0.3, P["stone_pale"] if i % 2 else P["pearl_rose"], xf)
        colbox(out, 1.2, 0.62, 0.3, xf)
        if i % 4 == 0:
            ro = rr + 0.55
            L.cyl(mb, 0.04, 0.04, 0.9, 5, P["gold"], T(ro * math.cos(a), ro * math.sin(a), z))
            L.ball(mb, (ro * math.cos(a), ro * math.sin(a), z + 0.95), 0.06, P["gold"], 5, 3)
    rail = []
    for i in range(23):
        t = i / 22
        ang = math.radians(a0 + (a1 - a0) * t)
        z = 0.6 + (height - 0.9) * t + 0.95
        ro = _tower_r(z) + 1.15
        rail.append((ro * math.cos(ang), ro * math.sin(ang), z))
    L.tube(mb, rail, 0.035, P["gold"], seg=4)


def watchtower_top(mb, rng, out):
    """Platform; origin is the top of watchtower_base (place at +13 m)."""
    out["keep_origin"] = True
    r = _tower_r(13.0)
    L.lathe(mb, [(r, 0.0), (r + 0.35, 0.45), (3.75, 0.8)], 22, P["stone_pale"], cap_bot=False, cap_top=True, col_cap=P["pearl_rose"])
    L.torus(mb, 3.72, 0.07, P["gold"], T(0, 0, 0.8), 22, 4)
    gap = (-140.0, -55.0)  # open wedge where the stair and the ivy arrive
    arc_len = (360.0 - (gap[1] - gap[0])) / 360.0
    L.lathe(mb, [(3.35, 0.8), (3.75, 0.8), (3.75, 1.35), (3.35, 1.35), (3.35, 0.8)], 24, P["pearl"],
            T(), False, False, smooth=False, phase=math.radians(gap[1]), arc=arc_len)
    merl = 12
    for i in range(merl):
        ang = gap[1] + 10 + (360 - (gap[1] - gap[0]) - 20) * i / (merl - 1)
        a = math.radians(ang)
        xf = T(3.55 * math.cos(a), 3.55 * math.sin(a), 1.35, rz=ang + 90)
        L.rbox(mb, 0.75, 0.4, 0.65, P["pearl"] if i % 2 else P["pearl_rose"], xf, seg=6, rings=4, e=0.4)
        L.ball(mb, (3.55 * math.cos(a), 3.55 * math.sin(a), 2.05), 0.07, P["gold"], 5, 3)
        if i % 3 == 0:
            L.cyl(mb, 0.035, 0.035, 2.2, 5, P["gold"], T(3.55 * math.cos(a), 3.55 * math.sin(a), 2.0))
            c = ["rose", "lilac", "butter", "mint"][i // 3 % 4]
            pts = [(3.55 * math.cos(a), 3.55 * math.sin(a), 4.1 - 0.12 * k) for k in range(1)]
            top = Vector((3.55 * math.cos(a), 3.55 * math.sin(a), 4.1))
            outv = Vector((math.cos(a), math.sin(a), 0))
            L.strip(mb, [top, top + outv * 0.6 + Vector((0, 0, -0.1)), top + outv * 1.3 + Vector((0, 0, -0.05))],
                    Vector((0, 0, 1)), [0.7, 0.55, 0.05], P[c])
            colbox(out, 0.75, 0.4, 0.65, xf)
    # central pastel canopy mast with big banner and lantern
    L.cyl(mb, 0.08, 0.06, 4.0, 8, P["pearl"], T(0, 0, 0.8))
    L.ball(mb, (0, 0, 4.9), 0.15, P["gold"], 8, 5)
    L.strip(mb, [(0, 0, 4.6), (1.0, 0.0, 4.45), (2.0, 0.1, 4.5)], Vector((0, 0, 1)), [1.0, 0.85, 0.15], P["rose"])
    L.cyl(mb, 0.18, 0.18, 0.35, 8, P["lantern"], T(0, 0, 2.6))
    L.cone(mb, 0.25, 0.25, 8, P["gold"], T(0, 0, 2.95))
    for i in range(6):
        a = TAU * i / 6
        L.rbox(mb, 0.6, 0.6, 0.45, P["wood_pale"], T(2.6 * math.cos(a), 2.6 * math.sin(a), 0.8), seg=6, rings=4) if i in (1, 3) else None
        if i in (2, 4, 5):
            L.lathe(mb, [(0.18, 0.8), (0.22, 0.95), (0.12, 1.1)], 8, P["blush"], T(2.9 * math.cos(a), 2.9 * math.sin(a), 0))
            L.bloom(mb, (2.9 * math.cos(a), 2.9 * math.sin(a), 1.15), 0.15, P[FLOWER_COLS[i]], P["butter"], detail=1)
    climb_band(out, 3.75, -115, -65, -0.3, 1.35, cols=3, rows=1, off=0.05)
    colcyl(out, 3.75, 0.8, seg=12)


def watchtower_ruined(mb, rng, out):
    out["keep_origin"] = True
    prof = [(3.3, 0.0)] + [(_tower_r(z), z) for z in (0.5, 3.0, 5.5, 7.0)]
    L.lathe(mb, prof, 20, P["pearl_lilac"], cap_bot=False, cap_top=True, col_cap=P["moss"])
    for i in range(20):
        a = TAU * (i + 0.5) / 20
        h = rng.uniform(0.0, 2.6) if not (-2.2 < a - math.pi * 1.5 < -1.5) else rng.uniform(1.2, 2.6)
        if h < 0.25:
            continue
        r = _tower_r(7.0)
        L.rock(mb, 1.05, 0.55, h + 0.4, P["pearl_lilac"] if i % 2 else P["stone_pale"], rng,
               T(r * math.cos(a), r * math.sin(a), 6.8, rz=math.degrees(a) + 90), seg=5, rings=3, jit=0.12, e=0.4)
    L.torus(mb, _tower_r(0.6) + 0.03, 0.12, P["rosegold"], T(0, 0, 0.6), 20, 4)
    L.torus(mb, _tower_r(4.0) + 0.03, 0.12, P["rosegold"], T(0, 0, 4.0), 20, 4, arc=0.6)
    yd = -_tower_r(1.5) - 0.02
    L.rbox(mb, 1.5, 0.3, 2.3, P["wood_dk"], T(0, yd, 0.5), e=0.5, seg=8, rings=6)
    for i in range(14):
        a = math.radians(-55 + 290 * (i + 0.5) / 44)
        z = 0.6 + 12.1 * (i + 0.5) / 44
        rr = _tower_r(z) + 0.6
        xf = T(rr * math.cos(a), rr * math.sin(a), z - 0.3, rz=math.degrees(a))
        L.box(mb, 1.2, 0.62, 0.3, P["stone_pale"], xf)
        colbox(out, 1.2, 0.62, 0.3, xf)
    ivy_on_cyl(mb, rng, lambda z: _tower_r(z) + 0.05, -115, -65, 0.8, 7.6, 28, size=0.38, flowers=0.35)
    ivy_on_cyl(mb, rng, lambda z: _tower_r(z) + 0.05, 20, 160, 0.3, 5.0, 14, size=0.34, flowers=0.3)
    climb_band(out, _tower_r(4.0), -115, -65, 1.0, 7.4, cols=3, rows=4)
    for i in range(8):
        a = rng.uniform(0, TAU)
        d = rng.uniform(3.8, 5.6)
        L.rock(mb, rng.uniform(0.6, 1.3), rng.uniform(0.5, 1.0), rng.uniform(0.4, 0.8), P["pearl_lilac"], rng,
               T(d * math.cos(a), d * math.sin(a), 0, rz=rng.uniform(0, 360)), seg=6, rings=4)
        L.sphere(mb, 0.4, 0.35, 0.12, P["moss"], T(d * math.cos(a), d * math.sin(a), 0.45), 5, 2)
        L.bloom(mb, (d * math.cos(a) + 0.4, d * math.sin(a), 0.1), 0.13, P[FLOWER_COLS[i % 8]], P["butter"], detail=0)
    colcyl(out, 3.2, 8.0, seg=12)


# ------------------------------------------------------------------ fells

def fells_cairn(mb, rng, out):
    z = 0.0
    for k in range(7):
        s = 1.2 * (1 - k * 0.12)
        h = 0.32 * (1 - k * 0.06)
        L.rock(mb, s, s * 0.85, h, [P["stone_pale"], P["pearl_lilac"], P["pearl_rose"]][k % 3], rng,
               T(rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), z, rz=rng.uniform(0, 360)), seg=7, rings=4, jit=0.1)
        z += h * 0.85
    L.ball(mb, (0, 0, z + 0.05), 0.08, P["gold"], 6, 4)
    hanging_ribbon(mb, (0.15, -0.3, z - 0.3), 0.7, P["rose"], (0.3, -0.2), 0.07)
    hanging_ribbon(mb, (-0.15, -0.3, z - 0.3), 0.6, P["peri"], (-0.25, -0.2), 0.06)
    for i in range(5):
        a = TAU * i / 5
        L.bloom(mb, (0.8 * math.cos(a), 0.8 * math.sin(a), 0.05), 0.09, P[FLOWER_COLS[i + 1]], P["butter"], detail=0)
        L.sphere(mb, 0.3, 0.25, 0.1, P["moss"], T(0.7 * math.cos(a + 0.5), 0.7 * math.sin(a + 0.5), 0), 6, 3)
    colcyl(out, 0.6, z, seg=8)


def sheepfold_wall(mb, rng, out, length=6.0, height=1.1):
    for c in range(3):
        n = 8 + c % 2
        for i in range(n):
            x = -length / 2 + length * (i + 0.5 * (c % 2) + 0.5) / (n + 0.5 * (c % 2))
            L.rbox(mb, length / n * 1.1, 0.6 - c * 0.08, height / 3 * 1.1, P["stone_pale"] if (i + c) % 3 else P["pearl_lilac"],
                   T(x, 0, c * height / 3, rz=rng.uniform(-6, 6)), seg=6, rings=4, rng=rng, jit=0.06)
    for i in range(8):
        x = -length / 2 + length * (i + 0.5) / 8
        L.sphere(mb, 0.4, 0.28, 0.1, P["moss"], T(x, 0, height), 6, 3)
        if i % 3 == 1:
            L.bloom(mb, (x, -0.3, 0.15), 0.1, P[FLOWER_COLS[i % 8]], P["butter"], detail=0)
    for i in range(3):
        L.sphere(mb, 0.08, 0.06, 0.06, P["cream"], T(rng.uniform(-length / 2, length / 2), 0.22, height * 0.6), 5, 3)
    colbox(out, length, 0.6, height)


def overlook_bench(mb, rng, out):
    s = P["stone_pale"]
    for sx in (-0.8, 0.8):
        L.rbox(mb, 0.4, 0.55, 0.45, s, T(sx, 0, 0), e=0.4)
    L.rbox(mb, 2.1, 0.6, 0.16, P["pearl"], T(0, 0, 0.42), e=0.3, seg=8, rings=5)
    L.rbox(mb, 2.1, 0.18, 0.7, P["pearl"], T(0, 0.3, 0.55), e=0.3, seg=8, rings=5)
    L.spiral_beads(mb, 0.02, 0.18, 2.0, 16, 0.025, P["gold"], T(0, 0.2, 0.95))
    L.torus(mb, 0.25, 0.02, P["gold"], T(-0.7, 0.2, 0.95, rx=90), 12, 3)
    L.torus(mb, 0.25, 0.02, P["gold"], T(0.7, 0.2, 0.95, rx=90), 12, 3)
    L.rbox(mb, 0.55, 0.45, 0.1, P["rose"], T(-0.45, -0.03, 0.58), e=0.5, seg=6, rings=4)
    for i in range(6):
        a = TAU * i / 6
        L.bloom(mb, (math.cos(a) * 1.1, 0.25 + math.sin(a) * 0.4, 0.05), 0.1, P[FLOWER_COLS[i]], P["butter"], detail=0)
    L.sphere(mb, 0.5, 0.3, 0.1, P["moss"], T(0.8, 0.25, 1.22), 6, 3)
    colbox(out, 2.1, 0.7, 0.6)


def escarpment_rock(mb, rng, out, sx=7.0, sy=4.0, sz=6.0, parts=4):
    for k in range(parts):
        t = k / max(1, parts - 1) - 0.5
        L.rock(mb, sx * rng.uniform(0.45, 0.6), sy * rng.uniform(0.7, 1.0), sz * rng.uniform(0.6, 1.0),
               [P["pearl_lilac"], P["stone_pale"], P["pearl_rose"]][k % 3], rng,
               T(t * sx * 0.55, rng.uniform(-0.3, 0.3), 0, rz=rng.uniform(0, 360)), seg=10, rings=7, jit=0.15, e=0.55)
    for k in range(parts):
        t = k / max(1, parts - 1) - 0.5
        L.sphere(mb, sx * 0.2, sy * 0.3, 0.35, P["moss"], T(t * sx * 0.5, 0, sz * 0.82), 8, 4)
    for i in range(12):
        L.bloom(mb, (rng.uniform(-sx / 2, sx / 2) * 0.8, rng.uniform(-sy / 2, sy / 2) * 0.5, sz * 0.86), 0.16,
                P[FLOWER_COLS[i % 8]], P["butter"], detail=0)
    flecks(mb, rng, 18, sx, sy, 0.5, sz * 0.8, P["gold"], 0.05)
    colbox(out, sx * 0.85, sy * 0.85, sz * 0.85)
