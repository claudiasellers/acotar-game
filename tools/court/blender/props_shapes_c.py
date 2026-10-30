"""Court-props builders, part C: small collectibles and mineral / forage ingredients (<= 600 tris each).

They lie on the ground (origin at base centre) and are bright and slightly oversized so they read and glint.
"""
import math
from mathutils import Vector
import props_lib as L
from props_lib import T, C, TAU
from props_shapes_a import P, FLOWER_COLS


def feather(mb, rng, out, length=0.26, width=0.06, bands=("peri",), tip=None, quill="cream", curve=0.02, n=10):
    pts, ws, cols = [], [], []
    for k in range(n + 1):
        t = k / n
        x = -length / 2 + length * t
        pts.append((x, curve * math.sin(math.pi * t) * 0.5, 0.012 + curve * math.sin(math.pi * t)))
        ws.append(width * (0.35 + 0.65 * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.6) if t > 0.12 else width * 0.15)
    for k in range(n):
        c = bands[k % len(bands)]
        if tip and k >= n - 2:
            c = tip
        cols.append(P[c] if isinstance(c, str) else c)
    L.strip(mb, pts, Vector((0, 1, 0.15)), ws, None, cols=cols)
    L.tube(mb, [(-length / 2 - 0.03, 0, 0.012)] + pts[1:], 0.004, P[quill] if isinstance(quill, str) else quill, seg=3, r_end=0.002)
    for k in (2, 4, 6):
        p = pts[k]
        L.strip(mb, [(p[0] - 0.02, p[1] + ws[k] * 0.5, p[2]), (p[0] - 0.04, p[1] + ws[k] * 0.7, p[2])], Vector((1, 0, 0)), 0.012, cols[k])


def shell_mussel(mb, rng, out):
    for sx in (-1, 1):
        L.sphere(mb, 0.09, 0.045, 0.03, P["plum"], T(0, sx * 0.03, 0.03, rx=sx * 50, rz=8 * sx), 10, 6)
        L.sphere(mb, 0.075, 0.035, 0.022, C("e9e4ff"), T(0, sx * 0.025, 0.033, rx=sx * 50 + 180, rz=8 * sx), 8, 5)
    for k in range(3):
        L.torus(mb, 0.05 + 0.015 * k, 0.003, P["peri"], T(0.0, 0.0, 0.05, rx=90, s=(1.6, 1, 1)), 10, 3, arc=0.5)


def snail_spiral(mb, rng, out, col="butter", band="rose"):
    pts = []
    n = 26
    for k in range(n):
        t = k / (n - 1)
        a = TAU * 2.3 * t
        r = 0.05 * (1 - t) + 0.006
        pts.append((r * math.cos(a), 0.012 * t, 0.055 + r * math.sin(a)))
    for k in range(n - 1):
        r = 0.032 * (1 - k / n) + 0.006
        L.tube(mb, [pts[k], pts[k + 1]], r, P[col] if k % 4 else P[band], seg=6, caps=False)
    L.sphere(mb, 0.035, 0.03, 0.03, P[col], T(0.04, 0, 0.022, ry=-30), 6, 4)


def hagstone(mb, rng, out):
    L.torus(mb, 0.045, 0.03, P["pearl_lilac"], T(0, 0, 0.03, s=(1.3, 1, 0.8)), 12, 6)
    for _ in range(5):
        L.ball(mb, (rng.uniform(-0.06, 0.06), rng.uniform(-0.04, 0.04), 0.045), 0.006, P["gold"], 4, 2)
    L.torus(mb, 0.045, 0.005, P["rose"], T(0.05, 0, 0.03, ry=90), 8, 3)


def crystal_cluster(mb, rng, out, cols=("white", "blush"), n=6, h=0.12, glow=False):
    for i in range(n):
        a = TAU * i / n
        rr = 0.0 if i == 0 else 0.025
        hh = h if i == 0 else h * rng.uniform(0.45, 0.8)
        c = P[cols[i % len(cols)]]
        L.prism(mb, 0.016 if i else 0.022, hh, L.G(c) if glow else c, T(rr * math.cos(a), rr * math.sin(a), 0.0, rx=35 * math.sin(a) * (i > 0), ry=-35 * math.cos(a) * (i > 0)))
    L.rock(mb, 0.08, 0.07, 0.025, P["pearl"], rng, seg=6, rings=4)


def gem(mb, rng, out, col="red", r=0.035, facets=8):
    L.lathe(mb, [(0.0, 0.0), (r, r * 0.9), (r * 0.65, r * 1.35), (0.0, r * 1.4)], facets, P[col], smooth=False)
    L.ball(mb, (r * 0.2, -r * 0.3, r * 1.25), r * 0.15, P["white"], 4, 2)


def amber(mb, rng, out):
    L.rock(mb, 0.07, 0.05, 0.045, P["amber"], rng, seg=8, rings=5, jit=0.08, e=0.9)
    L.sphere(mb, 0.008, 0.004, 0.006, P["wood_dk"], T(0.01, 0, 0.025), 5, 3)
    L.ball(mb, (-0.015, -0.02, 0.04), 0.008, P["butter"], 4, 2)


def obsidian(mb, rng, out):
    L.lathe(mb, [(0.0, 0.0), (0.03, 0.01), (0.022, 0.06), (0.0, 0.11, 0.01, 0.0)], 5, C("1d1726"), T(rx=60), smooth=False)
    L.ball(mb, (0.0, -0.03, 0.04), 0.005, P["glow_lilac"], 4, 2)


def fossil(mb, rng, out):
    L.rock(mb, 0.11, 0.09, 0.03, P["cream"], rng, seg=10, rings=4, jit=0.05, e=0.5)
    pts = [(0.042 * (1 - t) * math.cos(TAU * 2.2 * t), 0.042 * (1 - t) * math.sin(TAU * 2.2 * t), 0.03) for t in [k / 22 for k in range(23)]]
    L.tube(mb, pts, 0.004, P["wood_pale"], seg=3)
    for k in range(0, 20, 2):
        p = pts[k]
        L.ball(mb, p, 0.005, P["gold"], 4, 2)


def painted_pebble(mb, rng, out):
    L.rock(mb, 0.09, 0.07, 0.035, P["sky"], rng, seg=10, rings=5, jit=0.04, e=0.6)
    L.bloom(mb, (0, 0, 0.034), 0.022, P["rose"], P["butter"], detail=1)
    for i in range(6):
        a = TAU * i / 6
        L.ball(mb, (0.034 * math.cos(a), 0.027 * math.sin(a), 0.03), 0.004, P["white"], 4, 2)


def mask_shard(mb, rng, out):
    L.lathe(mb, [(0.0, 0.0), (0.05, 0.012), (0.08, 0.035)], 8, P["bl_grey"], T(rx=90) @ T(0, 0, -0.02), cap_top=False, arc=0.35)
    L.sphere(mb, 0.016, 0.006, 0.01, P["bl_black"], T(0.03, 0.0, 0.025), 5, 2)


def mural_chip(mb, rng, out):
    L.rbox(mb, 0.09, 0.07, 0.018, P["pearl_lilac"], seg=6, rings=3, e=0.3)
    L.spiral_beads(mb, 0.004, 0.025, 1.8, 10, 0.005, P["gold"], T(0, 0, 0.018, rx=90))
    L.box(mb, 0.07, 0.008, 0.004, P["rose"], T(0, 0.028, 0.017))


def coin(mb, rng, out):
    L.cyl(mb, 0.03, 0.03, 0.005, 14, P["gold"], smooth=False)
    L.torus(mb, 0.028, 0.0025, P["gold_dk"], T(0, 0, 0.005), 14, 3)
    L.lathe(mb, [(0.012, 0.0), (0.0, 0.003)], 6, P["gold_dk"], T(0, 0, 0.005), cap_bot=False)
    for i in range(5):
        a = TAU * i / 5
        L.ball(mb, (0.019 * math.cos(a), 0.019 * math.sin(a), 0.006), 0.002, P["gold_dk"], 3, 2)


def ribbon_coil(mb, rng, out, cols=("red", "gold"), length=0.3):
    pts = []
    for k in range(13):
        t = k / 12
        a = TAU * 1.4 * t
        r = 0.04 + 0.02 * t
        pts.append((r * math.cos(a) + 0.1 * t, r * math.sin(a), 0.015 + 0.004 * k))
    pts += [(0.16 + 0.03 * k, 0.03 * math.sin(k), 0.01) for k in range(1, 5)]
    L.strip(mb, pts, Vector((0, 0, 1)), 0.022, None, cols=[P[c] for c in cols])


def solstice_bead(mb, rng, out):
    L.sphere(mb, 0.025, 0.025, 0.025, P["glow_gold"], T(0, 0, 0.025), 10, 7)
    L.torus(mb, 0.025, 0.004, P["rose"], T(0, 0, 0.025), 12, 3)
    L.tube(mb, [(-0.07, 0, 0.003), (-0.025, 0, 0.022)], 0.002, P["cream"], seg=3)
    L.tube(mb, [(0.025, 0, 0.022), (0.07, 0.01, 0.003)], 0.002, P["cream"], seg=3)


def leaf(mb, rng, out, col="gold", vein="butter", length=0.12, w=0.06):
    n = 8
    pts = [(-length / 2 + length * k / n, 0, 0.005 + 0.012 * math.sin(math.pi * k / n)) for k in range(n + 1)]
    ws = [w * math.sin(math.pi * k / n) ** 0.7 + 0.002 for k in range(n + 1)]
    L.strip(mb, pts, Vector((0, 1, 0)), ws, P[col])
    L.tube(mb, [(-length / 2 - 0.02, 0, 0.004)] + pts, 0.0025, P[vein], seg=3)


def acorn(mb, rng, out):
    L.lathe(mb, [(0.0, 0.0), (0.016, 0.006), (0.019, 0.025), (0.017, 0.035)], 10, P["wood_pale"], T(rx=80) @ T(0, 0.02, -0.02))
    L.lathe(mb, [(0.019, 0.032), (0.022, 0.042), (0.0, 0.05)], 10, P["wood_dk"], T(rx=80) @ T(0, 0.02, -0.02), cap_bot=True)
    L.torus(mb, 0.018, 0.0025, P["gold"], T(rx=80) @ T(0, 0.02, 0.0), 10, 3)
    L.spiral_beads(mb, 0.001, 0.008, 1.5, 6, 0.0025, P["rose"], T(0, -0.006, 0.02))


def antler(mb, rng, out, scale=1.0, tines=3):
    s = scale
    beam = [(-0.18 * s, 0, 0.02 * s), (-0.05 * s, 0.03 * s, 0.03 * s), (0.08 * s, 0.02 * s, 0.05 * s), (0.2 * s, 0.07 * s, 0.07 * s)]
    L.tube(mb, beam, 0.018 * s, P["cream"], seg=6, r_end=0.008 * s)
    L.ball(mb, beam[0], 0.026 * s, P["wood_pale"], 6, 4)
    for k in range(tines):
        b = Vector(beam[k + 1 if k + 1 < len(beam) else -1])
        L.tube(mb, [b, b + Vector((0.03 * s, -0.04 * s, 0.07 * s))], 0.01 * s, P["cream"], seg=5, r_end=0.004 * s)


def wool_tuft(mb, rng, out):
    for i in range(9):
        L.ball(mb, (rng.uniform(-0.04, 0.04), rng.uniform(-0.03, 0.03), 0.02 + rng.uniform(0, 0.02)), rng.uniform(0.018, 0.03), P["cream"] if i % 3 else P["blush"], 6, 4)


def glass_bead(mb, rng, out):
    L.sphere(mb, 0.022, 0.022, 0.022, P["teal"], T(0, 0, 0.022), 8, 5, smooth=False)
    L.torus(mb, 0.008, 0.002, P["white"], T(0, 0, 0.022, rx=90), 8, 3)
    L.ball(mb, (0.008, -0.014, 0.034), 0.004, P["white"], 3, 2)


def candle_stub(mb, rng, out):
    L.cyl(mb, 0.025, 0.025, 0.05, 10, P["cream"], col_cap=P["blush"])
    for i in range(3):
        a = TAU * i / 3 + 0.4
        L.sphere(mb, 0.007, 0.007, 0.018, P["cream"], T(0.025 * math.cos(a), 0.025 * math.sin(a), 0.035), 5, 3)
    L.cyl(mb, 0.002, 0.002, 0.012, 3, P["wood_dk"], T(0, 0, 0.05))
    L.cyl(mb, 0.038, 0.04, 0.008, 10, P["gold"])


def beetle(mb, rng, out):
    L.sphere(mb, 0.025, 0.017, 0.012, C("2fbf9e"), T(0, 0, 0.012), 10, 6)
    L.box(mb, 0.046, 0.002, 0.002, P["gold"], T(0, 0, 0.023))
    L.sphere(mb, 0.009, 0.009, 0.007, C("4a3ea8"), T(0.027, 0, 0.009), 6, 4)
    for sx in (-1, 0, 1):
        for sy in (-1, 1):
            L.tube(mb, [(sx * 0.012, sy * 0.012, 0.006), (sx * 0.018, sy * 0.025, 0.0)], 0.0015, C("4a3ea8"), seg=3, caps=False)
    L.ball(mb, (0.006, -0.008, 0.021), 0.003, P["white"], 3, 2)


def snake_skin(mb, rng, out):
    pts = [(-0.14 + 0.28 * t, 0.035 * math.sin(TAU * 1.3 * t), 0.008) for t in [k / 14 for k in range(15)]]
    L.tube(mb, pts, 0.01, P["pearl"], seg=5, r_end=0.003)
    for k in range(0, 14, 2):
        L.ball(mb, pts[k], 0.0045, P["pearl_lilac"], 3, 2)


def driftwood(mb, rng, out):
    pts = [(-0.18, 0, 0.02), (-0.06, 0.02, 0.025), (0.05, -0.015, 0.02), (0.18, 0.01, 0.018)]
    L.tube(mb, pts, 0.02, P["wood_pale"], seg=6, r_end=0.01)
    L.tube(mb, [(0.0, 0.0, 0.025), (0.06, 0.06, 0.03)], 0.008, P["wood_pale"], seg=4, r_end=0.004)
    L.torus(mb, 0.016, 0.002, P["wood"], T(-0.1, 0.012, 0.022, ry=90), 6, 3)


def robin_egg(mb, rng, out):
    L.lathe(mb, [(0.0, 0.0), (0.022, 0.012), (0.026, 0.03), (0.022, 0.042)], 10, C("8fd3e8"), cap_top=False)
    L.lathe(mb, [(0.0, 0.0), (0.018, 0.012), (0.022, 0.03)], 8, C("7cc4dc"), T(0.06, 0.0, 0.0, rx=150), cap_top=False)
    for i in range(6):
        L.ball(mb, (rng.uniform(-0.015, 0.015), rng.uniform(-0.02, -0.01), rng.uniform(0.01, 0.03)), 0.0025, P["wood"], 3, 2)


def seed_pod(mb, rng, out):
    L.lathe(mb, [(0.0, 0.0), (0.02, 0.01), (0.026, 0.05), (0.018, 0.08), (0.0, 0.1)], 6, P["wood_pale"], T(rx=80))
    for k in range(5):
        L.ball(mb, (0.0, 0.012 - k * 0.018, 0.024), 0.008, P["butter"], 5, 3)
    L.strip(mb, [(-0.005, 0.0, 0.03), (-0.04, 0.03, 0.04)], Vector((0, 0, 1)), 0.03, P["cream"])


def bone(mb, rng, out):
    L.cyl(mb, 0.012, 0.012, 0.16, 6, P["cream"], T(-0.08, 0, 0.018, ry=90))
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.ball(mb, (sx * 0.085, sy * 0.012, 0.018), 0.016, P["cream"], 6, 4)


def pinecone(mb, rng, out):
    for k in range(7):
        t = k / 6
        r = 0.035 * math.sin(math.pi * (0.15 + 0.8 * t)) + 0.006
        L.lathe(mb, [(r, 0.0), (r * 0.6, 0.02)], 8, P["wood"] if k % 2 else P["wood_dk"], T(0, 0, 0.035, ry=80) @ T(0, 0, -0.05 + 0.015 * k), cap_bot=False, cap_top=False, phase=0.4 * k)
    L.ball(mb, (0.07, 0, 0.03), 0.006, P["wood_dk"], 4, 2)


def lump(mb, rng, out, col="amber", s=0.1, flecks_col=None, n=2):
    for i in range(n):
        L.rock(mb, s * rng.uniform(0.7, 1.0), s * rng.uniform(0.6, 0.9), s * 0.5, P[col] if isinstance(col, str) else col, rng,
               T(rng.uniform(-s / 3, s / 3), rng.uniform(-s / 3, s / 3), 0, rz=rng.uniform(0, 360)), seg=7, rings=5, jit=0.15)
    if flecks_col:
        for _ in range(8):
            L.ball(mb, (rng.uniform(-s / 2.5, s / 2.5), rng.uniform(-s / 3, s / 3), rng.uniform(s * 0.15, s * 0.4)), s * 0.04, P[flecks_col], 3, 2)


def salt(mb, rng, out):
    for i in range(10):
        s = rng.uniform(0.012, 0.025)
        L.box(mb, s, s, s, P["white"] if i % 3 else P["pearl_rose"], T(rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), rng.uniform(0, 0.015), rx=rng.uniform(0, 40), rz=rng.uniform(0, 90)))
    L.lathe(mb, [(0.0, 0.0), (0.04, 0.003), (0.0, 0.025)], 8, P["white"])


def iron_filings(mb, rng, out):
    L.lathe(mb, [(0.0, 0.0), (0.05, 0.003), (0.0, 0.025)], 8, C("4a3f45"))
    for i in range(14):
        L.box(mb, 0.012, 0.002, 0.002, C("8c6b5f") if i % 2 else C("c76a3c"), T(rng.uniform(-0.035, 0.035), rng.uniform(-0.035, 0.035), rng.uniform(0.003, 0.02), rz=rng.uniform(0, 180)))
    L.ball(mb, (0.01, -0.01, 0.025), 0.004, P["white"], 3, 2)


def starlight_water(mb, rng, out):
    L.disc(mb, 0.18, 14, P["glow_teal"], T(0, 0, 0.004))
    L.torus(mb, 0.17, 0.006, P["glow_star"], T(0, 0, 0.004), 16, 3)
    for i in range(9):
        a = rng.uniform(0, TAU)
        r = rng.uniform(0.0, 0.15)
        z = rng.uniform(0.02, 0.12)
        p = (r * math.cos(a), r * math.sin(a), z)
        for ax in ((90, 0), (0, 90)):
            L.lathe(mb, [(0.0, -0.025), (0.006, 0.0), (0.0, 0.025)], 4, P["glow_star"], T(*p, rx=ax[0], ry=ax[1]), smooth=False)


def rite_spring(mb, rng, out):
    L.rock(mb, 0.42, 0.34, 0.2, P["stone_pale"], rng, seg=9, rings=5, jit=0.12)
    L.rock(mb, 0.2, 0.18, 0.16, P["pearl_lilac"], rng, T(0.12, 0.08, 0.1), seg=6, rings=4, jit=0.12)
    L.sphere(mb, 0.08, 0.08, 0.05, P["glow_teal"], T(0, -0.02, 0.2), 8, 4)
    L.disc(mb, 0.15, 10, P["water"], T(0.0, -0.18, 0.015))
    for i in range(6):
        L.ball(mb, (rng.uniform(-0.05, 0.05), -0.02 + rng.uniform(-0.05, 0.05), 0.25 + 0.03 * i), 0.012, P["glow_star"], 4, 2)
    L.strip(mb, [(0.0, -0.06, 0.2), (0.0, -0.14, 0.12), (0.0, -0.17, 0.02)], Vector((1, 0, 0)), 0.05, P["glow_teal"])
    L.spiral_beads(mb, 0.004, 0.035, 1.8, 10, 0.006, P["gold"], T(-0.1, -0.15, 0.1))
    L.sphere(mb, 0.07, 0.06, 0.02, P["moss"], T(-0.12, 0.08, 0.17), 5, 3)


def rose_dew(mb, rng, out):
    leaf(mb, rng, out, col="leaf", vein="leaf_dk", length=0.14, w=0.07)
    for i in range(5):
        L.sphere(mb, 0.008, 0.008, 0.006, C("e8fbff", True), T(-0.04 + 0.02 * i, 0.012 * (i % 2 - 0.5), 0.018), 6, 4)
    L.bloom(mb, (0.08, 0.02, 0.02), 0.03, P["rose"], P["butter"], detail=1)


def honey(mb, rng, out):
    L.lathe(mb, [(0.13, 0.0), (0.13, 0.4), (0.09, 0.4), (0.09, 0.0)], 10, P["wood"], T(-0.2, 0, 0.13, ry=90), cap_bot=False, cap_top=False)
    L.disc(mb, 0.13, 10, P["wood_pale"], T(0.2, 0, 0.13, ry=90))
    for i in range(7):
        a = TAU * i / 7
        L.lathe(mb, [(0.022, 0.0), (0.022, 0.05)], 6, P["amber"], T(0.15, 0.045 * math.cos(a), 0.13 + 0.045 * math.sin(a), ry=90), cap_top=True, col_cap=P["butter"], smooth=False)
    L.lathe(mb, [(0.022, 0.0), (0.022, 0.05)], 6, P["amber"], T(0.15, 0, 0.13, ry=90), col_cap=P["butter"], smooth=False)
    L.strip(mb, [(0.21, 0.02, 0.08), (0.215, 0.02, 0.03), (0.22, 0.02, 0.0)], Vector((0, 1, 0)), [0.03, 0.02, 0.015], P["au_gold"])
    L.ball(mb, (0.06, -0.12, 0.2), 0.012, P["butter"], 5, 3)


def fae_bell(mb, rng, out):
    L.lathe(mb, [(0.0, 0.055), (0.012, 0.052), (0.022, 0.035), (0.03, 0.008), (0.036, 0.0)], 12, P["gold"], T(rx=70) @ T(0, 0, -0.03), cap_bot=False)
    L.ball(mb, (0, 0, 0.0), 0.008, P["rosegold"], 4, 2, T(rx=70) @ T(0, 0, -0.03))
    L.torus(mb, 0.008, 0.002, P["gold"], T(rx=70) @ T(0, 0, 0.03), 6, 3)
    L.strip(mb, [(0.0, 0.03, 0.04), (0.03, 0.06, 0.01), (0.06, 0.05, 0.003)], Vector((0, 0, 1)), 0.012, P["rose"])


def heart_stone(mb, rng, out):
    for sx in (-1, 1):
        L.sphere(mb, 0.028, 0.02, 0.028, P["rose"], T(sx * 0.018, 0, 0.012, rz=sx * 30, s=1), 8, 5)
    L.lathe(mb, [(0.0, 0.0), (0.03, 0.035), (0.0, 0.04)], 8, P["rose"], T(0, 0.035, 0.012, rx=90))
    L.ball(mb, (-0.015, -0.01, 0.03), 0.005, P["white"], 3, 2)


def flint(mb, rng, out):
    L.rock(mb, 0.08, 0.06, 0.04, C("3a3640"), rng, seg=6, rings=4, jit=0.25, e=0.9)
    L.rock(mb, 0.05, 0.05, 0.03, P["cream"], rng, T(0.03, 0.01, 0.0), seg=5, rings=4, jit=0.2)
    L.ball(mb, (-0.01, -0.025, 0.03), 0.004, P["white"], 3, 2)


def river_pearl(mb, rng, out):
    L.lathe(mb, [(0.0, 0.0), (0.045, 0.01), (0.06, 0.025)], 10, P["sky"], cap_top=False)
    L.lathe(mb, [(0.0, 0.002), (0.04, 0.01), (0.055, 0.024)], 10, C("eae4ff"), T(0, 0, 0.002), cap_top=False)
    L.sphere(mb, 0.016, 0.016, 0.016, C("fff4fa"), T(0, 0, 0.012), 10, 6)
    L.ball(mb, (0.005, -0.006, 0.033), 0.003, P["glow_star"], 3, 2)


def horseshoe(mb, rng, out):
    L.torus(mb, 0.05, 0.008, C("c48a62"), T(0, 0, 0.006, s=(1, 1.1, 0.6)), 14, 4, arc=0.7)
    for i in range(6):
        a = TAU * 0.7 * (i + 0.5) / 6
        L.ball(mb, (0.05 * math.cos(a), 0.055 * math.sin(a), 0.01), 0.003, P["gold"], 3, 2)
    L.strip(mb, [(-0.04, -0.03, 0.008), (-0.07, -0.06, 0.004)], Vector((0, 0, 1)), 0.008, P["rose"])


def carved_bird(mb, rng, out):
    L.sphere(mb, 0.035, 0.022, 0.025, P["wood_pale"], T(0, 0, 0.025), 8, 5)
    L.ball(mb, (0.035, 0, 0.045), 0.016, P["wood_pale"], 7, 5)
    L.cone(mb, 0.006, 0.014, 4, P["gold"], T(0.05, 0, 0.045, ry=90))
    L.strip(mb, [(-0.03, 0, 0.03), (-0.06, 0, 0.045)], Vector((0, 1, 0)), [0.025, 0.035], P["wood"])
    for sy in (-1, 1):
        L.sphere(mb, 0.022, 0.004, 0.012, P["wood"], T(-0.003, sy * 0.021, 0.03, rx=sy * 10), 6, 3)
        L.ball(mb, (0.043, sy * 0.012, 0.05), 0.003, P["plum"], 3, 2)
    L.cyl(mb, 0.03, 0.03, 0.005, 10, P["wood"])


def seed_packet(mb, rng, out):
    L.box(mb, 0.07, 0.1, 0.008, P["cream"], T(rz=10))
    L.box(mb, 0.07, 0.025, 0.004, P["rose"], T(rz=10) @ T(0, 0.04, 0.008))
    L.bloom(mb, (0.0, -0.01, 0.009), 0.018, P["lilac"], P["butter"], T(rz=10), detail=1)
    L.tube(mb, [(-0.03, 0.035, 0.012), (0.0, 0.025, 0.018), (0.03, 0.035, 0.012)], 0.002, P["gold"], seg=3, xf=T(rz=10))
    for i in range(3):
        L.ball(mb, (0.05 + 0.01 * i, -0.04, 0.003), 0.003, P["wood_dk"], 3, 2)


def ribbon_scrap(mb, rng, out):
    pts = [(-0.1 + 0.2 * t, 0.025 * math.sin(TAU * t * 1.5), 0.004 + 0.012 * math.sin(math.pi * t * 2) ** 2) for t in [k / 10 for k in range(11)]]
    L.strip(mb, pts, Vector((0, 1, 0.3)), 0.028, None, cols=[P["lilac"], P["lilac"], P["gold"]])


def pressed_petal(mb, rng, out):
    for i in range(5):
        a = TAU * i / 5
        L.sphere(mb, 0.028, 0.017, 0.002, P["rose"] if i % 2 else P["blush"], T(0.022 * math.cos(a), 0.022 * math.sin(a), 0.003, rz=math.degrees(a)), 7, 3)
    L.ball(mb, (0, 0, 0.004), 0.008, P["butter"], 5, 3)
    L.box(mb, 0.1, 0.12, 0.001, P["cream"], T(0.0, 0.0, 0.0, rz=12))


# --------------------------------------------------------------- feather recipes
FEATHERS = {
    "col_blue_jay_feather": dict(length=0.24, width=0.05, bands=("peri", "peri", C("2f3a8a"), "white"), tip="white"),
    "col_feather_kingfisher": dict(length=0.16, width=0.04, bands=(C("2ab3c9"), C("1f8fb8")), tip="coral"),
    "col_feather_pheasant": dict(length=0.42, width=0.04, bands=(C("c8743a"), C("6e3a24")), tip="au_gold"),
    "col_feather_swan": dict(length=0.3, width=0.08, bands=("white", "pearl"), tip="white"),
    "col_feather_heron": dict(length=0.32, width=0.055, bands=(C("b9c7d8"), C("9fb1c8")), tip=C("3a4258")),
    "ing_crow_feather": dict(length=0.26, width=0.06, bands=(C("16141c"), C("231e33")), tip=C("2b2a4a"), quill=C("2a2a30")),
    "col_wren_feather": dict(length=0.12, width=0.035, bands=(C("b07a4e"), C("7a5134")), tip="cream"),
    "ing_hawk_feather": dict(length=0.3, width=0.06, bands=(C("b6824e"), "cream"), tip=C("5a3a24")),
    "ing_owl_feather": dict(length=0.22, width=0.07, bands=("cream", C("c9a27a"), C("8a6446")), tip="cream"),
}
