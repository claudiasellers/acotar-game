"""The forage pickups: one cute, readable model per item that is foraged in the game.

    /opt/bpyenv/bin/python tools/blender/forage/build_forage.py [id ...]

Writes art/forage/<id>.glb (the model, then <id>_LOD1 at ~50%) for every id in
ITEMS: the ingredient_id of each human-realm *_find layer and every
forage_visuals key of the spring-court woods (ing_ and col_), i.e. what can be
picked today.  ScatterLayer / woods_scatter swap a pickable layer's mesh for
art/forage/<ingredient_id>.glb when it exists; decor layers keep theirs, so
the things you can pick read apart from the scenery.

R3 look: chunky, rounded, oversized (small finds x1.6), clear saturated colour with a
soft darker base; each kind has its own silhouette so it reads from 5 m.
R4: <= 3,000 tris, LOD1, origin = base centre on the ground.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402,F401
from mathutils import Vector as V  # noqa: E402

import forage_kit as fk  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "art", "forage")
MAX_TRIS = 3000

# palette (sRGB hex)
LEAF, LEAF_D, LEAF_L, MOSS, MOSS_D = "#5FA052", "#3E7A3F", "#8CC46A", "#6E9E4A", "#4A7436"
EVERG, EVERG_D, NEEDLE = "#2F6A4E", "#22503B", "#3C7A5A"
BARK, BARK_D, BARK_L, TWIG = "#7A5A44", "#5A4033", "#A0806A", "#6B4E3C"
STRAW, CREAM, WHITE, SNOW = "#D9C48E", "#F4ECD2", "#FAF7F0", "#EEF3F8"
RED, RED_D, ROSE, PINK, BLUSH = "#D93A3A", "#A82430", "#E0475E", "#F08AB0", "#F7C3D3"
ORANGE, AMBER, HONEY, YELLOW, BUTTER = "#EE7B30", "#E39A2C", "#F2B83A", "#F6D64A", "#FBE8A0"
BLUE, BLUE_D, SKY, PERI, LILAC, VIOLET, PURPLE = "#4C74C9", "#2F4E93", "#9FD0F0", "#9AA8E8", "#C3A6E8", "#8257C9", "#6A3FA8"
INK, CHAR, STONE, STONE_L, SLATE = "#2A2630", "#34302F", "#9C968E", "#C9C4BC", "#6E7280"
GLOW_G, GLOW_W = "#A9FFB8", "#FFF6C8"


# ------------------------------------------------------------------ helpers
def rosette(k, n, length, width, color, tilt=0.25, z=0.012, shape="oval", tip=None, phase=0.0, cup=0.25):
    for i in range(n):
        a = 2 * math.pi * i / n + phase + k.rng.uniform(-0.15, 0.15)
        d = V((math.cos(a), math.sin(a), tilt)).normalized()
        k.leaf((0, 0, z), d, length * k.rng.uniform(0.85, 1.1), width, k.jit(color), cup=cup, shape=shape, tip_c=tip)


def moss_pad(k, r, color=MOSS, h=0.03, n=5):
    for (x, y, _a) in [(0, 0, 0)] + k.ring_scatter(n, r * 0.45, r * 0.7):
        k.pebble((x, y, -0.006), (r * 0.5, r * 0.45, h), k.jit(color, 0.1), seed_jit=0.1, seg=(12, 6), flat=0.3,
                 grad=(fk.mix(color, "#B6D98A", 0.4), -0.004, h))


def berries(k, centre, n, r, color, spread, shine=0.35, seg=(7, 5)):
    c0 = V(centre)
    pts = [c0]
    for i in range(n - 1):
        a = 2.39996 * i
        rr = spread * math.sqrt((i + 1) / n)
        pts.append(c0 + V((math.cos(a) * rr, math.sin(a) * rr, k.rng.uniform(-0.3, 0.3) * spread)))
    for p in pts:
        rr = r * k.rng.uniform(0.85, 1.12)
        k.ell(p, rr, k.jit(color, 0.06), seg=seg, grad=(fk.mix(color, WHITE, shine), p.z - rr * 0.1, p.z + rr * 1.6))
    return pts


def bush(k, h, w, leaf=LEAF, leaf_d=LEAF_D, blobs=5, seg=(10, 7)):
    """A soft rounded bush made of overlapping leaf blobs. Returns surface points for fruit."""
    k.tube([V((0, 0, 0)), V((0, 0, h * 0.35))], [w * 0.06, w * 0.045], BARK_D, 6)
    tops = []
    for i in range(blobs):
        a = 2 * math.pi * i / blobs + k.rng.uniform(-0.3, 0.3)
        rr = w * 0.24 if i else 0.0
        c = V((math.cos(a) * rr, math.sin(a) * rr, h * (0.5 if i else 0.62) + k.rng.uniform(-0.05, 0.05) * h))
        rad = (w * k.rng.uniform(0.27, 0.33), w * k.rng.uniform(0.27, 0.33), h * k.rng.uniform(0.27, 0.33))
        k.ell(c, rad, leaf_d, seg=seg, grad=(leaf, c.z - rad[2] * 0.9, c.z + rad[2]))
        tops.append((c, rad))
    pts = []
    for c, rad in tops:
        for j in range(7):
            th = k.rng.uniform(0, 2 * math.pi)
            ph = k.rng.uniform(-0.1, 1.1)
            d = V((math.cos(th) * math.cos(ph), math.sin(th) * math.cos(ph), math.sin(ph)))
            p = c + V((d.x * rad[0], d.y * rad[1], d.z * rad[2])) * 0.98
            if p.z > h * 0.22:
                pts.append((p, d))
    return pts


def sprig(k, base, d, length, r, color=TWIG, leaves=0, leaf_c=LEAF, leaf_len=0.05, leaf_w=0.02, shape="oval"):
    base, d = V(base), V(d).normalized()
    tip = base + d * length
    k.stem(base, tip, r, color, bend=(0, 0, length * 0.08), n=4, sides=5)
    out = []
    for i in range(leaves):
        t = 0.3 + 0.65 * i / max(leaves - 1, 1)
        p = base + d * length * t
        s = 1 if i % 2 else -1
        side = d.cross(V((0, 0, 1)))
        side = side.normalized() if side.length > 1e-4 else V((1, 0, 0))
        ld = (side * s + d * 0.6 + V((0, 0, 0.25))).normalized()
        k.leaf(p, ld, leaf_len, leaf_w, k.jit(leaf_c), cup=0.2, shape=shape)
        out.append(p)
    return tip


# ------------------------------------------------------------------ berries / fruit on bushes
def b_hawthorn(k):
    pts = bush(k, 0.62, 0.62, "#6FA34E", "#41763A")
    for p, d in pts[::2]:
        berries(k, p + d * 0.025, 4, 0.026, RED, 0.035)
    for p, d in pts[1::4]:
        k.leaf(p, (d + V((0, 0, 0.4))).normalized(), 0.06, 0.035, "#7DB35A", cup=0.1, shape="heart")


def b_holly(k):
    pts = bush(k, 0.6, 0.58, "#2E7A4A", "#1F5634")
    for p, d in pts[::3]:
        for j in range(2):
            a = j * 2.6 + k.rng.uniform(0, 1)
            ld = (d + V((math.cos(a), math.sin(a), 0.3)) * 0.8).normalized()
            k.leaf(p, ld, 0.075, 0.03, "#2F8A52", cup=-0.15, fold=0.5, shape="lance", tip_c="#1E5A37")
    for p, d in pts[1::2]:
        berries(k, p + d * 0.02, 3, 0.022, "#E3262E", 0.026, shine=0.45)


def b_juniper(k):
    k.tube([V((0, 0, 0)), V((0, 0, 0.2))], [0.03, 0.022], BARK_D, 6)
    for i, (z, r) in enumerate(((0.22, 0.22), (0.4, 0.17), (0.56, 0.11), (0.68, 0.05))):
        k.cone((0, 0, z - 0.06), (0, 0, 1), 0.2, r, r * 0.35, "#2D6550", sides=10, grad=("#4E8C6E", z - 0.06, z + 0.14))
    for i in range(14):
        a = 2.39996 * i
        z = 0.2 + 0.45 * (i / 14)
        rr = 0.2 * (1 - (z - 0.15) / 0.6) + 0.03
        p = V((math.cos(a) * rr, math.sin(a) * rr, z))
        k.ell(p, 0.02, "#5672B8", seg=(8, 6), grad=("#B8C8EC", p.z - 0.005, p.z + 0.03))


def b_sloe(k):
    pts = bush(k, 0.55, 0.62, "#5C8E4A", "#3A6436")
    for p, d in pts[::4]:
        k.cone(p, (d + V((0, 0, 0.5))).normalized(), 0.06, 0.006, 0.0005, TWIG, sides=4)
    for p, d in pts[1::2]:
        berries(k, p + d * 0.03, 2, 0.034, "#3A3F78", 0.04, shine=0.55)
    for p, d in pts[2::5]:
        k.petal_ring(p + d * 0.02, d, 0.022, 5, WHITE, cup=0.2, heart=BUTTER, heart_r=0.007)


def b_rose_hip(k):
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.3
        tip = V((math.cos(a) * 0.26, math.sin(a) * 0.26, 0.5 + 0.08 * (i % 2)))
        pts = k.stem((0, 0, 0), tip, 0.014, "#7A4A3A", bend=(math.cos(a) * 0.06, math.sin(a) * 0.06, 0.12), n=6)
        for j, p in enumerate(pts[1:-1]):
            k.cone(p, (V((math.cos(a + 1.4 * (-1) ** j), math.sin(a + 1.4 * (-1) ** j), 0.4))), 0.022, 0.005, 0.0005,
                   "#B26A54", sides=4)
            k.leaf(p, V((math.cos(a - 0.8 * (-1) ** j), math.sin(a - 0.8 * (-1) ** j), 0.2)), 0.05, 0.022, "#6E9B4E",
                   cup=0.15)
        for j in range(3):
            q = tip + V((k.rng.uniform(-0.03, 0.03), k.rng.uniform(-0.03, 0.03), -0.015 * j))
            k.ell(q, (0.022, 0.022, 0.032), "#E2481F", seg=(9, 7), grad=("#FF9A5E", q.z - 0.01, q.z + 0.04))
            k.cone(q + V((0, 0, 0.03)), (0, 0, 1), 0.014, 0.008, 0.002, "#3C3022", sides=5)


def b_blackberry(k):
    pts = bush(k, 0.5, 0.66, "#5B8F45", "#38633A")
    for p, d in pts[::3]:
        k.leaf(p, (d + V((0, 0, 0.3))).normalized(), 0.07, 0.04, "#6EA250", cup=0.1, shape="oval", tip_c="#4A7A3A")
    for i, (p, d) in enumerate(pts[1::3]):
        c = p + d * 0.04
        col = "#2B2240" if i % 3 else "#C2344A"
        for j in range(9):
            a = 2.39996 * j
            q = c + V((math.cos(a) * 0.02 * math.sqrt(j / 9), math.sin(a) * 0.02 * math.sqrt(j / 9), 0.04 * (j / 9 - 0.5)))
            k.ell(q, 0.016, col, seg=(6, 4), grad=(fk.mix(col, WHITE, 0.35), q.z, q.z + 0.018))


def b_wild_strawberry(k):
    rosette(k, 7, 0.09, 0.04, "#5FA052", tilt=0.35, shape="round", tip="#86C064")
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.4
        tip = V((math.cos(a) * 0.1, math.sin(a) * 0.1, 0.05))
        k.stem((0, 0, 0.01), tip, 0.004, "#7BA84E", bend=(0, 0, 0.05))
        k.ell(tip - V((0, 0, 0.018)), (0.018, 0.018, 0.024), "#E8343F", seg=(9, 7), grad=("#FF7A6E", tip.z - 0.04, tip.z))
        for s in range(5):
            b = 2 * math.pi * s / 5
            k.ell(tip - V((0, 0, 0.018)) + V((math.cos(b) * 0.017, math.sin(b) * 0.017, 0.004 * (s - 2))), 0.0025,
                  BUTTER, seg=(4, 3))
        k.leaf(tip, V((math.cos(a + 2), math.sin(a + 2), 0.2)), 0.018, 0.008, LEAF, cup=0.0)
    for i in range(3):
        a = 2 * math.pi * i / 3 + 1.4
        c = V((math.cos(a) * 0.05, math.sin(a) * 0.05, 0.085))
        k.stem((0, 0, 0.01), c, 0.003, "#7BA84E")
        k.petal_ring(c, (0, 0, 1), 0.016, 5, WHITE, cup=0.1, heart=YELLOW, heart_r=0.006)


# ------------------------------------------------------------------ nuts
def acorn(k, c, yaw, scale=1.0, cap_only=False):
    c = V(c)
    s = scale
    if not cap_only:
        k.ell(c + V((0, 0, 0.022 * s)), (0.016 * s, 0.016 * s, 0.024 * s), "#B9823F", seg=(10, 7),
              grad=("#E2B160", c.z, c.z + 0.04 * s))
        k.cone(c + V((0, 0, 0.0)), (0, 0, -1), 0.006 * s, 0.004 * s, 0.0005, "#8A5E30", sides=5)
    top = c + V((0, 0, 0.034 * s)) if not cap_only else c + V((0, 0, 0.008 * s))
    k.ell(top, (0.019 * s, 0.019 * s, 0.011 * s), "#7A5A3A", seg=(10, 6), grad=("#A17A50", top.z - 0.01 * s, top.z + 0.01 * s),
          squash_bottom=None if not cap_only else 0.2)
    k.tube([top + V((0, 0, 0.008 * s)), top + V((0.006 * s, 0, 0.018 * s))], [0.003 * s, 0.002 * s], "#5A4030", 4)


def b_acorn(k):
    moss_pad(k, 0.13, "#8A7A55", 0.02, 4)
    for i, (x, y, a) in enumerate([(0, 0, 0)] + k.ring_scatter(5, 0.05, 0.1)):
        acorn(k, (x, y, 0.012), a, 1.25 if i == 0 else 1.0)
    k.leaf((0.02, -0.04, 0.01), (1, -0.6, 0.05), 0.11, 0.045, "#C8873E", cup=-0.05, shape="oval", tip_c="#9C5A2A")


def b_acorn_caps(k):
    moss_pad(k, 0.11, MOSS, 0.02, 4)
    for i, (x, y, a) in enumerate([(0, 0, 0)] + k.ring_scatter(5, 0.04, 0.085)):
        acorn(k, (x, y, 0.018), a, 1.3, cap_only=True)


def b_hazelnut(k):
    moss_pad(k, 0.12, "#8A7A55", 0.02, 4)
    for i, (x, y, a) in enumerate([(0, 0, 0)] + k.ring_scatter(5, 0.045, 0.09)):
        c = V((x, y, 0.03))
        k.ell(c, (0.022, 0.02, 0.022), "#A86E3A", seg=(10, 7), grad=("#D69A5A", c.z - 0.02, c.z + 0.02))
        k.ell(c + V((0, 0, 0.016)), (0.014, 0.013, 0.006), "#E4C79A", seg=(8, 4))
        if i < 2:
            for j in range(4):
                b = j * 1.57 + a
                k.leaf(c + V((0, 0, 0.012)), V((math.cos(b), math.sin(b), 0.9)), 0.03, 0.016, "#9BB86A", cup=-0.3)


# ------------------------------------------------------------------ flowers
def b_snowdrop(k):
    rosette(k, 6, 0.08, 0.012, "#5E9E7A", tilt=2.5, shape="lance", tip="#8CC4A0", cup=0.6)
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.5
        top = V((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.14 + 0.02 * (i % 2)))
        pts = k.stem((math.cos(a) * 0.01, math.sin(a) * 0.01, 0), top, 0.0035, "#6FAE86", bend=(0, 0, 0.02))
        hang = top + V((math.cos(a) * 0.02, math.sin(a) * 0.02, -0.006))
        k.tube([top, hang], [0.003, 0.003], "#6FAE86", 4)
        for j in range(3):
            b = 2 * math.pi * j / 3 + a
            d = V((math.cos(b) * 0.35, math.sin(b) * 0.35, -1)).normalized()
            k.leaf(hang, d, 0.032, 0.012, WHITE, up=V((math.cos(b), math.sin(b), 0)), cup=-0.25, shape="oval")
        k.ell(hang - V((0, 0, 0.012)), (0.007, 0.007, 0.01), "#EAF6EE", seg=(7, 5))
        k.ell(hang + V((0, 0, 0.002)), 0.005, "#7FC08F", seg=(6, 4))


def b_crocus(k):
    rosette(k, 7, 0.07, 0.008, "#4E8E52", tilt=3.0, shape="lance", cup=0.4)
    for i in range(3):
        a = 2 * math.pi * i / 3
        b = V((math.cos(a) * 0.025, math.sin(a) * 0.025, 0.0))
        top = b + V((0, 0, 0.07 + 0.012 * i))
        k.tube([b, top], [0.006, 0.005], "#E8E2EE", 5)
        for j in range(6):
            c = 2 * math.pi * j / 6 + 0.26 * (j % 2)
            d = V((math.cos(c) * 0.3, math.sin(c) * 0.3, 1)).normalized()
            k.leaf(top, d, 0.042, 0.016, "#9A6AD8", up=V((math.cos(c), math.sin(c), 0)), cup=-0.35, fold=0.4,
                   tip_c="#C9A8F2")
        k.ell(top + V((0, 0, 0.018)), (0.003, 0.003, 0.012), ORANGE, seg=(5, 4))


def b_primrose(k):
    rosette(k, 8, 0.1, 0.04, "#6AAA55", tilt=0.25, shape="oval", tip="#9ACB74", cup=0.15)
    for i in range(6):
        a = 2.39996 * i
        rr = 0.04 * math.sqrt((i + 1) / 6)
        c = V((math.cos(a) * rr, math.sin(a) * rr, 0.05 + 0.006 * (i % 3)))
        k.stem((0, 0, 0.01), c, 0.003, "#8ABF6A")
        k.petal_ring(c, (math.cos(a) * 0.2, math.sin(a) * 0.2, 1), 0.022, 5, "#FBEA9A", cup=0.12, width=0.7,
                     heart="#F2B23A", heart_r=0.007, tilt=a)


def b_violet(k):
    for i in range(7):
        a = 2 * math.pi * i / 7
        base = V((0, 0, 0.005))
        tip = V((math.cos(a) * 0.05, math.sin(a) * 0.05, 0.035))
        k.stem(base, tip, 0.0025, "#6E9E52")
        k.leaf(tip, V((math.cos(a), math.sin(a), 0.25)), 0.055, 0.045, k.jit("#5C9A4C"), cup=0.2, shape="heart")
    for i in range(5):
        a = 2.39996 * i + 0.4
        rr = 0.035 * math.sqrt((i + 1) / 5)
        c = V((math.cos(a) * rr, math.sin(a) * rr, 0.075 + 0.01 * (i % 2)))
        k.stem((0, 0, 0.005), c + V((0, 0, 0.01)), 0.0025, "#7DAE5E", bend=(0, 0, 0.02))
        f = V((math.cos(a), math.sin(a), 0.2)).normalized()
        k.petal_ring(c, f, 0.019, 5, "#7E4CC8", cup=0.05, width=0.75, heart=WHITE, heart_r=0.005, tilt=a)


def b_foxglove(k):
    rosette(k, 7, 0.12, 0.045, "#5E9450", tilt=0.25, shape="oval", tip="#8FBE70", cup=0.15)
    k.stem((0, 0, 0), (0, 0, 0.48), 0.007, "#5E8E4A", bend=(0.01, 0, 0.02), n=6)
    for i in range(16):
        t = i / 16
        z = 0.18 + 0.28 * t
        a = 2.39996 * i
        p = V((math.cos(a) * 0.012, math.sin(a) * 0.012, z))
        d = V((math.cos(a), math.sin(a), -0.55)).normalized()
        s = 1.0 - 0.55 * t
        k.bell(p, d, 0.014 * s, 0.045 * s, "#D96AA8", flare=1.25, sides=7, lip="#F7C3DE")
    k.ell((0.01, 0, 0.49), 0.008, "#A9CC80", seg=(6, 4))


def b_wild_hyacinth(k):
    rosette(k, 6, 0.13, 0.014, "#4F8E50", tilt=1.2, shape="lance", cup=0.5)
    for i in range(3):
        a = 2 * math.pi * i / 3
        base = V((math.cos(a) * 0.02, math.sin(a) * 0.02, 0))
        top = V((math.cos(a) * 0.08, math.sin(a) * 0.08, 0.24 - 0.02 * i))
        pts = k.stem(base, top, 0.004, "#5E9A58", bend=(0, 0, 0.06), n=6)
        for j in range(6):
            t = 0.3 + 0.7 * j / 6
            idx = min(int(t * (len(pts) - 1)), len(pts) - 2)
            p = pts[idx].lerp(pts[idx + 1], t * (len(pts) - 1) - idx)
            k.bell(p, V((math.cos(a) * 0.5, math.sin(a) * 0.5, -1)), 0.011, 0.026, "#5C6FD8", flare=1.35, sides=7,
                   lip="#9FB0F2")


def b_elderflower(k):
    k.stem((0, 0, 0), (0, 0, 0.18), 0.006, "#6E9850", n=4)
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.4
        k.leaf((0, 0, 0.08), V((math.cos(a), math.sin(a), 0.3)), 0.09, 0.03, "#5E9450", cup=0.2, shape="lance")
    for i in range(7):
        a = 2 * math.pi * i / 7
        tip = V((math.cos(a) * 0.07, math.sin(a) * 0.07, 0.24))
        k.stem((0, 0, 0.18), tip, 0.003, "#8AB070", bend=(0, 0, 0.02), n=3)
        berries(k, tip, 6, 0.008, "#F6EDC8", 0.022, shine=0.3, seg=(6, 4))
    berries(k, (0, 0, 0.25), 6, 0.008, "#F6EDC8", 0.022, shine=0.3, seg=(6, 4))


def b_meadowsweet(k):
    rosette(k, 5, 0.1, 0.035, "#5E9450", tilt=0.4, shape="lance", cup=0.2)
    for i in range(3):
        a = 2 * math.pi * i / 3 + 0.2
        top = V((math.cos(a) * 0.05, math.sin(a) * 0.05, 0.3 - 0.03 * i))
        k.stem((0, 0, 0), top, 0.004, "#8C6E50", bend=(0, 0, 0.04))
        for j in range(5):
            b = 2 * math.pi * j / 5
            berries(k, top + V((math.cos(b) * 0.025, math.sin(b) * 0.025, -0.008 * (j % 2))), 4, 0.009, "#F8EFCF", 0.016,
                    shine=0.25, seg=(6, 4))


def b_honeysuckle(k):
    rosette(k, 6, 0.08, 0.035, "#5E9A55", tilt=0.5, cup=0.2)
    k.stem((0, 0, 0), (0.02, 0, 0.2), 0.005, "#8A6A4E", bend=(0.03, 0, 0.02))
    for i in range(7):
        a = 2 * math.pi * i / 7
        d = V((math.cos(a), math.sin(a), 0.6)).normalized()
        base = V((0.02, 0, 0.21))
        col = ("#F7E7A8", "#F5C38E", "#F2A7BF")[i % 3]
        k.cone(base, d, 0.055, 0.004, 0.009, col, sides=6, grad=(BUTTER, base.z, base.z + 0.05))
        k.leaf(base + d * 0.055, (d + V((0, 0, -0.6))).normalized(), 0.02, 0.01, col, cup=0.1)
        k.tube([base + d * 0.05, base + d * 0.075], [0.0012, 0.001], "#E8C24A", 3)


def rose_bush(k, petal, petal_d):
    pts = bush(k, 0.42, 0.46, "#4F8A48", "#2F5E34", blobs=4)
    for i, (p, d) in enumerate(pts[::4]):
        c = p + d * 0.01
        for ring, (r, n, cup) in enumerate(((0.05, 6, 0.5), (0.038, 5, 0.9), (0.024, 4, 1.6))):
            k.petal_ring(c + d * 0.004 * ring, d, r, n, petal if ring < 2 else petal_d, cup=cup, width=0.85,
                         tilt=ring * 0.6 + i)
        k.ell(c + d * 0.016, 0.012, petal_d, seg=(6, 4))


def b_rose_red(k):
    rose_bush(k, "#E0405A", "#B32642")


def b_rose_white(k):
    rose_bush(k, "#FBF6EE", "#EAD9CF")


def b_blighted(k):
    rosette(k, 6, 0.09, 0.035, "#7E7A70", tilt=0.2, cup=0.3)
    for i in range(4):
        a = 2 * math.pi * i / 4
        top = V((math.cos(a) * 0.06, math.sin(a) * 0.06, 0.15 + 0.025 * i))
        k.stem((0, 0, 0), top, 0.006, "#55504E", bend=(math.cos(a) * 0.04, math.sin(a) * 0.04, 0.0))
        for ring, (r, n, cup) in enumerate(((0.045, 5, 0.6), (0.03, 4, 1.1))):
            k.petal_ring(top, (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.4), r, n, "#9E9AA6", cup=cup, width=0.7,
                         tilt=ring + a)
    for j in range(7):
        a = k.rng.uniform(0, 6.28)
        rr = k.rng.uniform(0.04, 0.12)
        k.leaf((math.cos(a) * rr, math.sin(a) * rr, 0.004), V((math.cos(a + 1), math.sin(a + 1), 0.02)), 0.025, 0.018,
               "#8E8A94", cup=-0.1, shape="round")


def b_faelight_dandelion(k):
    rosette(k, 7, 0.1, 0.022, "#5FA052", tilt=0.25, shape="lance", cup=0.2)
    for i in range(3):
        a = 2 * math.pi * i / 3 + 0.3
        top = V((math.cos(a) * 0.04, math.sin(a) * 0.04, 0.2 + 0.03 * i))
        k.stem((0, 0, 0), top, 0.0035, "#8AB86A", bend=(0, 0, 0.03))
        k.ell(top, 0.016, "#F2EEDC", seg=(8, 6))
        for j in range(14):
            u = (j + 0.5) / 14
            ph = math.asin(2 * u - 1)
            th = 2.39996 * j
            d = V((math.cos(ph) * math.cos(th), math.cos(ph) * math.sin(th), math.sin(ph)))
            k.tube([top + d * 0.014, top + d * 0.034], [0.0009, 0.0007], "#FFFFFF", 3, cap=False)
            k.ell(top + d * 0.036, 0.0045, GLOW_W, seg=(5, 3), glow=True)
    for j in range(4):
        p = V((k.rng.uniform(-0.08, 0.08), k.rng.uniform(-0.08, 0.08), k.rng.uniform(0.28, 0.38)))
        k.ell(p, 0.006, GLOW_W, seg=(5, 3), glow=True)


def b_wood_sorrel(k):
    for i in range(7):
        a = 2.39996 * i
        rr = 0.06 * math.sqrt((i + 1) / 7)
        top = V((math.cos(a) * rr, math.sin(a) * rr, 0.05 + 0.01 * (i % 3)))
        k.stem((0, 0, 0), top, 0.0025, "#B07A6A", bend=(0, 0, 0.02))
        for j in range(3):
            b = 2 * math.pi * j / 3 + a
            k.leaf(top, V((math.cos(b), math.sin(b), 0.1)), 0.026, 0.024, "#77BE5E", cup=0.25, fold=0.35, shape="heart")
    for i in range(3):
        a = 2 * math.pi * i / 3 + 1.0
        top = V((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.085))
        k.stem((0, 0, 0), top, 0.002, "#B07A6A")
        k.petal_ring(top, (0, 0, 1), 0.014, 5, "#FBF2F6", cup=0.45, width=0.7, heart=BUTTER, heart_r=0.004)


def b_wild_garlic(k):
    for i in range(6):
        a = 2 * math.pi * i / 6 + 0.2
        k.leaf((0, 0, 0.005), V((math.cos(a), math.sin(a), 0.9)), 0.15, 0.03, k.jit("#4E9A4E"), cup=0.45, shape="lance",
               tip_c="#7CC070")
    for i in range(3):
        a = 2 * math.pi * i / 3
        top = V((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.2 + 0.02 * i))
        k.stem((0, 0, 0), top, 0.003, "#6EAA60")
        for j in range(7):
            b = 2.39996 * j
            d = V((math.cos(b) * 0.7, math.sin(b) * 0.7, 0.7)).normalized()
            q = top + d * 0.03
            k.tube([top, q], [0.0015, 0.0012], "#8CC070", 3, cap=False)
            k.petal_ring(q, d, 0.014, 6, WHITE, cup=0.2, width=0.55, heart=BUTTER, heart_r=0.004)


def b_water_mint(k):
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.3
        top = V((math.cos(a) * 0.04, math.sin(a) * 0.04, 0.17 + 0.02 * (i % 2)))
        pts = k.stem((0, 0, 0), top, 0.004, "#7A5E78", bend=(0, 0, 0.02))
        for j, p in enumerate(pts[1:-1]):
            for s in (1, -1):
                b = a + s * 1.57 + j * 0.8
                k.leaf(p, V((math.cos(b), math.sin(b), 0.3)), 0.035, 0.022, "#4E9A62", cup=0.2, fold=0.3, tip_c="#7CC08E")
        berries(k, top, 7, 0.009, "#C8A4E8", 0.016, shine=0.3, seg=(6, 4))


def b_wintergreen(k):
    for i in range(9):
        a = 2.39996 * i
        rr = 0.08 * math.sqrt((i + 1) / 9)
        p = V((math.cos(a) * rr, math.sin(a) * rr, 0.012))
        k.leaf(p, V((math.cos(a), math.sin(a), 0.35)), 0.055, 0.03, k.jit("#2F7A4E"), cup=0.15, fold=0.2, tip_c="#4FA06C")
    berries(k, (0.01, -0.01, 0.035), 5, 0.014, "#E2263A", 0.03, shine=0.5)


def b_woad(k):
    rosette(k, 9, 0.13, 0.04, "#6C9C8E", tilt=0.2, shape="lance", tip="#9AC4B4", cup=0.2)
    k.stem((0, 0, 0), (0, 0, 0.3), 0.006, "#6C9C8E")
    for i in range(6):
        a = 2 * math.pi * i / 6
        tip = V((math.cos(a) * 0.08, math.sin(a) * 0.08, 0.33 + 0.02 * (i % 2)))
        k.stem((0, 0, 0.26), tip, 0.0025, "#7FA890", n=3)
        berries(k, tip, 5, 0.008, "#F5D63E", 0.016, shine=0.25, seg=(6, 4))
    berries(k, (0, 0, 0.34), 6, 0.008, "#F5D63E", 0.018, shine=0.25, seg=(6, 4))


def b_madder(k):
    for i in range(3):
        a = 2 * math.pi * i / 3
        top = V((math.cos(a) * 0.05, math.sin(a) * 0.05, 0.18 + 0.02 * i))
        pts = k.stem((0, 0, 0), top, 0.004, "#6E9450", bend=(0, 0, 0.03))
        for p in pts[1:]:
            for j in range(5):
                b = 2 * math.pi * j / 5 + a
                k.leaf(p, V((math.cos(b), math.sin(b), 0.15)), 0.035, 0.009, "#5E9450", cup=0.1, shape="lance")
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.6
        a0 = V((math.cos(a) * 0.01, math.sin(a) * 0.01, 0.01))
        a1 = V((math.cos(a) * 0.14, math.sin(a) * 0.14, 0.008))
        k.stem(a0, a1, 0.011, "#C0392B", bend=(math.sin(a) * 0.03, -math.cos(a) * 0.03, 0.012), n=6, tip=0.004)


# ------------------------------------------------------------------ fungi, lichen, bark
def stub(k, r=0.07, h=0.12, col=BARK, top=BARK_L, birch=False):
    k.cone((0, 0, 0), (0, 0, 1), h, r * 1.15, r, col, sides=12, grad=(fk.mix(col, WHITE, 0.15), 0.0, h))
    k.ell((0, 0, h), (r, r, r * 0.12), top, seg=(12, 4))
    k.ell((0, 0, h + r * 0.11), (r * 0.6, r * 0.6, r * 0.04), fk.mix(top, BARK_D, 0.4), seg=(10, 3))
    if birch:
        for i in range(5):
            a = k.rng.uniform(0, 6.28)
            z = k.rng.uniform(0.02, h - 0.02)
            c = V((math.cos(a) * r * 1.05, math.sin(a) * r * 1.05, z))
            k.ell(c, (0.012, 0.012, 0.004), "#2E2A2A", seg=(6, 3), rot=V((math.cos(a), math.sin(a), 0)))


def b_glowcap(k):
    moss_pad(k, 0.12, "#4F7E4A", 0.025, 5)
    for i, (x, y, a) in enumerate([(0, 0, 0)] + k.ring_scatter(4, 0.05, 0.09)):
        s = 1.25 if i == 0 else k.rng.uniform(0.6, 0.9)
        h = 0.07 * s
        k.tube([V((x, y, 0.01)), V((x, y, h))], [0.009 * s, 0.007 * s], "#EAF6DE", 6)
        cap = V((x, y, h))
        k.ell(cap, (0.03 * s, 0.03 * s, 0.022 * s), "#3CC86A", seg=(12, 6), glow=True, squash_bottom=0.15)
        for j in range(4):
            b = 2.39996 * j + i
            q = cap + V((math.cos(b) * 0.017 * s, math.sin(b) * 0.017 * s, 0.016 * s))
            k.ell(q, 0.004 * s, GLOW_W, seg=(5, 3), glow=True)


def b_tinder_fungus(k):
    stub(k, 0.08, 0.2, "#6E5A4A", "#B89878", birch=False)
    for i, (z, a, s) in enumerate(((0.07, 0.2, 1.0), (0.13, 1.4, 0.75), (0.17, -0.9, 0.6))):
        c = V((math.cos(a) * 0.09, math.sin(a) * 0.09, z))
        rot = V((math.cos(a) * 0.15, math.sin(a) * 0.15, 1))
        k.ell(c, (0.05 * s, 0.045 * s, 0.022 * s), "#8E7258", seg=(12, 6), rot=rot,
              grad=("#C9AE8E", c.z - 0.02, c.z + 0.02))
        for j in range(2):
            k.ell(c - V((0, 0, 0.006 + j * 0.008)) * s, (0.051 * s - j * 0.004, 0.046 * s - j * 0.004, 0.004), "#E0CDAE",
                  seg=(12, 3), rot=rot)


def b_chaga(k):
    stub(k, 0.075, 0.22, "#ECE8E0", "#D8CBB4", birch=True)
    c = V((0.06, 0.0, 0.13))
    k.pebble(c - V((0, 0, 0.04)), (0.05, 0.045, 0.045), "#2E2622", seed_jit=0.3, seg=(10, 7), flat=0.9,
             grad=("#4A3A30", c.z - 0.05, c.z + 0.05))
    k.ell(c + V((0.03, 0, -0.02)), (0.012, 0.03, 0.02), "#C07A3A", seg=(8, 5))


def b_oak_gall(k):
    moss_pad(k, 0.12, "#8A7A55", 0.018, 4)
    tip = sprig(k, (-0.12, 0.0, 0.02), (1, 0.1, 0.12), 0.24, 0.007, TWIG, leaves=3, leaf_c="#86A85A", leaf_len=0.05,
                leaf_w=0.025, shape="oval")
    for i, t in enumerate((0.25, 0.55, 0.8)):
        p = V((-0.12, 0, 0.02)) + V((1, 0.1, 0.12)).normalized() * 0.24 * t + V((0, 0, 0.022))
        k.ell(p, 0.02 - 0.003 * i, "#B07A44", seg=(10, 7), grad=("#DDB078", p.z - 0.01, p.z + 0.022))
        k.ell(p + V((0, 0, 0.018 - 0.003 * i)), 0.003, "#5A3E28", seg=(5, 3))
    del tip


def b_old_mans_beard(k):
    sprig(k, (-0.13, 0, 0.12), (1, 0.05, 0.05), 0.26, 0.012, "#5E5048")
    k.tube([V((-0.12, 0, 0)), V((-0.13, 0, 0.12))], [0.012, 0.012], "#5E5048", 5)
    k.tube([V((0.12, 0, 0)), V((0.12, 0, 0.13))], [0.012, 0.012], "#5E5048", 5)
    for i in range(12):
        x = -0.1 + 0.2 * i / 11
        top = V((x, k.rng.uniform(-0.01, 0.01), 0.13))
        L = k.rng.uniform(0.06, 0.11)
        bot = top + V((k.rng.uniform(-0.02, 0.02), k.rng.uniform(-0.02, 0.02), -L))
        k.stem(top, bot, 0.006, "#B8C9A2", bend=(0, 0.01, 0), n=4, tip=0.001)


def b_mistletoe(k):
    for i in range(5):
        a = 2 * math.pi * i / 5
        tip = V((math.cos(a) * 0.09, math.sin(a) * 0.09, 0.09 + 0.02 * (i % 2)))
        k.stem((0, 0, 0.01), tip, 0.006, "#9AB65A", bend=(0, 0, 0.03), n=4)
        for s in (0.6, -0.6):
            k.leaf(tip, V((math.cos(a + s), math.sin(a + s), 0.25)), 0.06, 0.02, "#A3C25E", cup=0.1, shape="lance",
                   tip_c="#C9DE86")
        berries(k, tip, 3, 0.011, "#F6F4E6", 0.014, shine=0.5)


def b_birch_bark(k):
    moss_pad(k, 0.13, MOSS, 0.02, 4)
    for i, (x, y, a) in enumerate([(0, 0, 0.3), (0.06, 0.05, 1.7), (-0.06, 0.04, 2.6)]):
        d = V((math.cos(a), math.sin(a), 0))
        s = d.cross(V((0, 0, 1)))
        c = V((x, y, 0.03))
        pts = []
        for j in range(9):
            th = 3.6 * j / 8
            r = 0.026 - 0.012 * j / 8
            pts.append(c + d * (0.0) + s * math.sin(th) * r + V((0, 0, math.cos(th) * r)))
        for half in (-1, 1):
            k.tube([p + d * half * 0.045 for p in pts], 0.004, "#F2EEE6", 5)
        for p in pts[::2]:
            k.tube([p - d * 0.045, p + d * 0.045], 0.0045, "#F2EEE6", 5)
        k.ell(c + s * 0.01 + V((0, 0, 0.026)), (0.006, 0.02, 0.002), "#2E2A2A", seg=(6, 3), rot=V((0, 0, 1)))


def b_willow_bark(k):
    moss_pad(k, 0.13, MOSS, 0.02, 4)
    for i in range(4):
        a = 0.4 + i * 0.35
        d = V((math.cos(a), math.sin(a), 0.0))
        c = V((k.rng.uniform(-0.03, 0.03), k.rng.uniform(-0.03, 0.03), 0.018 + 0.008 * i))
        k.stem(c - d * 0.11, c + d * 0.11, 0.011, "#8A7A5A", bend=(0, 0, 0.02), n=5, sides=5)
        k.stem(c - d * 0.1 + V((0, 0, 0.006)), c + d * 0.1 + V((0, 0, 0.006)), 0.008, "#C8D6A0", bend=(0, 0, 0.02), n=5,
               sides=5)
    k.leaf((0.04, 0.05, 0.03), (0.5, 1, 0.1), 0.09, 0.016, "#8FB070", shape="lance", cup=0.0)


def b_ash_wood(k):
    for i, (x, y) in enumerate(((0, 0), (0.035, 0.02), (-0.035, 0.02), (0.0, 0.04), (0.02, -0.03))):
        z = 0.03 + (0.045 if i == 3 else 0)
        a = V((x - 0.22, y, z))
        b = V((x + 0.22, y, z))
        k.tube([a, b], 0.022, "#C9C3B6", 8)
        k.ell(b, (0.003, 0.021, 0.021), "#EBDDC4", seg=(8, 4))
        k.ell(a, (0.003, 0.021, 0.021), "#EBDDC4", seg=(8, 4))
    for s in (-0.12, 0.12):
        k.tube([V((s, -0.05, 0.03)), V((s, 0, 0.1)), V((s, 0.07, 0.04))], 0.006, "#C04A5A", 5, cap=False)


def b_pine(k):
    moss_pad(k, 0.13, "#7E7050", 0.018, 4)
    for i, (x, y, a) in enumerate([(0, 0, 0.4)] + k.ring_scatter(2, 0.06, 0.08)):
        c = V((x, y, 0.035))
        d = V((math.cos(a), math.sin(a), 0.1)).normalized()
        s = 1.2 if i == 0 else 0.85
        for j in range(7):
            t = j / 6
            rr = (0.026 * math.sin(math.pi * (0.2 + 0.75 * t)) + 0.006) * s
            p = c + d * (t - 0.5) * 0.08 * s
            for q in range(6):
                b = 2 * math.pi * q / 6 + j * 0.5
                side, up, _ = fk.frame(d)
                sd = (side * math.cos(b) + up * math.sin(b))
                k.ell(p + sd * rr * 0.75, (0.008 * s, 0.008 * s, 0.005 * s), "#8A5A36", seg=(5, 3),
                      rot=(sd + d * -0.6), grad=("#C08A5A", p.z - 0.01, p.z + 0.03))
    for i in range(3):
        a = 1.0 + i * 0.5
        base = V((math.cos(a) * 0.05, math.sin(a) * 0.05, 0.02))
        tip = base + V((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.01))
        k.stem(base, tip, 0.004, TWIG)
        for j in range(8):
            t = 0.2 + 0.8 * j / 8
            p = base.lerp(tip, t)
            for s_ in (1, -1):
                k.tube([p, p + V((-math.sin(a) * s_ * 0.03, math.cos(a) * s_ * 0.03, 0.02))], [0.0016, 0.0008],
                       "#3D7A55", 3, cap=False)


def b_pine_resin(k):
    k.pebble((0, 0, 0), (0.12, 0.07, 0.03), BARK, seed_jit=0.15, seg=(12, 6), flat=0.4, grad=(BARK_L, 0.0, 0.05))
    for i, (x, y, s) in enumerate(((0.0, 0.0, 1.0), (0.05, 0.02, 0.7), (-0.05, -0.01, 0.75), (0.02, -0.035, 0.55))):
        c = V((x, y, 0.04))
        k.ell(c + V((0, 0, 0.012 * s)), (0.024 * s, 0.022 * s, 0.026 * s), "#E0901E", seg=(10, 7),
              grad=("#FFD36A", c.z, c.z + 0.05 * s))
        k.ell(c + V((0.006, -0.006, 0.03)) * s, 0.005 * s, "#FFF2C0", seg=(5, 3))


def b_honey(k):
    stub(k, 0.1, 0.12, BARK, BARK_L)
    c = V((0, 0, 0.13))
    for i in range(4):
        z = c.z + 0.035 + 0.045 * i
        r = 0.075 - 0.012 * i - (0.02 if i == 3 else 0)
        k.ell((0, 0, z), (r, r, 0.03), "#E8B048", seg=(12, 6), grad=("#F6D27A", z - 0.02, z + 0.03))
    k.ell((0, -0.06, 0.18), (0.016, 0.006, 0.012), "#3A2A20", seg=(8, 4))
    for j in range(3):
        a = 2 * math.pi * j / 3 + 0.4
        q = V((math.cos(a) * 0.1, math.sin(a) * 0.1, 0.12))
        k.tube([q + V((0, 0, 0.005)), q + V((0, 0, -0.04))], [0.008, 0.004], "#F2A830", 6)
    for j in range(3):
        p = V((math.cos(j * 2.1) * 0.13, math.sin(j * 2.1) * 0.13, 0.26 + 0.02 * j))
        k.ell(p, (0.008, 0.006, 0.006), "#F6C640", seg=(6, 4))
        k.ell(p + V((0.008, 0, 0)), (0.004, 0.006, 0.006), "#2E2620", seg=(5, 3))
        k.leaf(p + V((0, 0, 0.004)), (0.2, 1, 0.6), 0.012, 0.008, "#EAF6FF", cup=0.0, shape="round")


def b_thornbriar_sap(k):
    for i in range(3):
        a = 2 * math.pi * i / 3 + 0.5
        tip = V((math.cos(a) * 0.14, math.sin(a) * 0.14, 0.24))
        pts = k.stem((0, 0, 0), tip, 0.012, "#5E3E4A", bend=(math.cos(a) * 0.05, math.sin(a) * 0.05, 0.06), n=6, sides=6)
        for j, p in enumerate(pts[1:-1]):
            b = a + (1.6 if j % 2 else -1.6)
            k.cone(p, V((math.cos(b), math.sin(b), 0.3)), 0.04, 0.008, 0.0005, "#7A5060", sides=5)
            q = p + V((math.cos(a + 3.14) * 0.012, math.sin(a + 3.14) * 0.012, -0.004))
            k.ell(q, (0.009, 0.009, 0.013), "#C25A2E", seg=(8, 6), grad=("#FFB070", q.z - 0.01, q.z + 0.012))


def b_hollow_root(k):
    moss_pad(k, 0.14, MOSS, 0.022, 5)
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.3
        a0 = V((0, 0, 0.04))
        a1 = V((math.cos(a) * 0.16, math.sin(a) * 0.16, 0.012))
        k.stem(a0, a1, 0.02, "#EDE2C8", bend=(math.sin(a) * 0.03, -math.cos(a) * 0.03, 0.03), n=6, tip=0.004, sides=7)
    k.ell((0, 0, 0.05), (0.035, 0.035, 0.03), "#E4D6B6", seg=(10, 6))
    k.ell((0, 0, 0.07), (0.016, 0.016, 0.01), "#6E5A48", seg=(8, 4))
    for j in range(3):
        k.leaf((0, 0, 0.07), V((math.cos(j * 2.1), math.sin(j * 2.1), 1.2)), 0.07, 0.02, "#A8C890", cup=0.2, shape="lance")


# ------------------------------------------------------------------ moss, ice, water
def b_moss_star(k):
    moss_pad(k, 0.16, "#4E8E52", 0.05, 6)
    for j in range(14):
        a = k.rng.uniform(0, 6.28)
        rr = k.rng.uniform(0.0, 0.13)
        z = 0.05 * max(0.2, 1 - (rr / 0.16) ** 2) + 0.012
        k.ell((math.cos(a) * rr, math.sin(a) * rr, z), 0.0055, "#D8FFF0", seg=(5, 3), glow=True)


def b_ice_moss(k):
    moss_pad(k, 0.14, "#9FB8B4", 0.04, 6)
    for j in range(8):
        a = k.rng.uniform(0, 6.28)
        rr = k.rng.uniform(0.02, 0.1)
        b = V((math.cos(a) * rr, math.sin(a) * rr, 0.03))
        k.cone(b, (math.cos(a) * 0.3, math.sin(a) * 0.3, 1), k.rng.uniform(0.03, 0.06), 0.008, 0.001, "#E4F4FA", sides=5,
               grad=("#B8E2F4", b.z, b.z + 0.06))


def b_frozen_reed(k):
    k.pebble((0, 0, 0), (0.16, 0.13, 0.022), "#BFE2F2", seed_jit=0.08, seg=(12, 5), flat=0.3, grad=("#E8F6FC", 0, 0.03))
    for i in range(7):
        a = 2.39996 * i
        rr = 0.06 * math.sqrt((i + 1) / 7)
        b = V((math.cos(a) * rr, math.sin(a) * rr, 0.0))
        top = b + V((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.26 + 0.05 * (i % 3)))
        k.stem(b, top, 0.006, "#C9B88A", bend=(0, 0, 0.0), n=4, sides=5)
        if i % 2 == 0:
            k.ell(top - V((0, 0, 0.03)), (0.009, 0.009, 0.03), "#8A6A48", seg=(7, 5))
        k.ell(b + V((0, 0, 0.05)), (0.012, 0.012, 0.03), "#DDF2FA", seg=(6, 4))


def b_snowmelt(k):
    k.pebble((0, 0, 0), (0.12, 0.1, 0.05), STONE, seed_jit=0.15, seg=(12, 7), flat=0.4,
             grad=(SNOW, 0.02, 0.08))
    for i, (x, y, h) in enumerate(((0.0, 0.0, 0.12), (0.04, 0.03, 0.09), (-0.04, 0.02, 0.1), (0.02, -0.04, 0.08),
                                   (-0.03, -0.03, 0.07))):
        b = V((x, y, 0.06))
        k.cone(b, (0, 0, 1), h, 0.02, 0.002, "#A8DDF6", sides=7, grad=("#EAF8FF", b.z, b.z + h))
    k.ell((0.07, 0.06, 0.012), (0.04, 0.03, 0.006), "#9CD4F2", seg=(10, 4))


def b_river_silt(k):
    k.pebble((0, 0, 0), (0.14, 0.12, 0.03), "#8E7A5E", seed_jit=0.12, seg=(12, 6), flat=0.3,
             grad=("#B8A07A", 0.0, 0.04))
    k.ell((0.05, -0.03, 0.03), (0.04, 0.025, 0.004), "#B9D8E4", seg=(10, 3))
    for i in range(3):
        k.ell((-0.05 + 0.03 * i, 0.05, 0.035), 0.01, STONE_L, seg=(6, 4))


# ------------------------------------------------------------------ stones, earths, metal
def b_chalk(k):
    for i, (x, y, s) in enumerate(((0, 0, 1.0), (0.07, 0.04, 0.6), (-0.06, 0.05, 0.55))):
        k.pebble((x, y, 0), (0.06 * s, 0.045 * s, 0.04 * s), "#F2EFE6", seed_jit=0.22, seg=(9, 6), flat=0.5,
                 grad=("#FFFFFF", 0, 0.05 * s))
    k.ell((0.02, -0.035, 0.008), (0.03, 0.012, 0.003), "#E8E4DA", seg=(8, 3))


def b_flint(k):
    for i, (x, y, s) in enumerate(((0, 0, 1.0), (0.06, -0.03, 0.6))):
        k.pebble((x, y, 0), (0.05 * s, 0.04 * s, 0.035 * s), "#E8E2D4", seed_jit=0.25, seg=(9, 6), flat=0.5)
        k.ell((x - 0.015 * s, y - 0.01 * s, 0.045 * s), (0.032 * s, 0.026 * s, 0.022 * s), "#2C2C3A", seg=(6, 4),
              grad=("#5A6078", 0.02, 0.07))
    k.pebble((-0.07, 0.04, 0), (0.022, 0.015, 0.006), "#3A3A4A", seed_jit=0.1, seg=(6, 4), flat=0.6)


def b_clay(k):
    k.pebble((0, 0, 0), (0.08, 0.07, 0.045), "#9C7E6A", seed_jit=0.18, seg=(12, 7), flat=0.4,
             grad=("#C4A28C", 0.0, 0.06))
    for i in range(3):
        k.ell((-0.02 + 0.02 * i, 0.0, 0.085), (0.006, 0.014, 0.003), "#7E6252", seg=(6, 3))
    k.ell((0.06, -0.05, 0.004), (0.03, 0.02, 0.003), "#B4D2DC", seg=(8, 3))


def b_red_ochre(k):
    for i, (x, y, s) in enumerate(((0, 0, 1.0), (0.07, 0.03, 0.55), (-0.05, -0.05, 0.5))):
        k.pebble((x, y, 0), (0.06 * s, 0.05 * s, 0.045 * s), "#B2442E", seed_jit=0.25, seg=(10, 6), flat=0.5,
                 grad=("#E07A52", 0.0, 0.06 * s))
    for j in range(5):
        a = k.rng.uniform(0, 6.28)
        k.ell((math.cos(a) * 0.09, math.sin(a) * 0.09, 0.003), (0.012, 0.01, 0.003), "#C25A3E", seg=(6, 3))


def b_charcoal(k):
    for i, (x, y, a) in enumerate(((0, 0, 0.3), (0.05, 0.04, 1.4), (-0.05, 0.03, 2.2), (0.02, -0.05, 2.9))):
        d = V((math.cos(a), math.sin(a), 0))
        c = V((x, y, 0.022))
        k.tube([c - d * 0.05, c + d * 0.05], 0.02, "#2E2A2C", 6)
        k.ell(c + d * 0.05, (0.004, 0.02, 0.02), "#4A3E3A", seg=(6, 3), rot=d)
        for j in range(3):
            k.ell(c + d * (j - 1) * 0.03 + V((0, 0, 0.018)), (0.006, 0.012, 0.002), "#55504E", seg=(5, 3))
    k.ell((0.0, 0.0, 0.05), 0.006, "#F07A3A", seg=(5, 3), glow=True)


def b_iron(k):
    k.pebble((0, 0, 0), (0.1, 0.08, 0.015), "#6E5048", seed_jit=0.1, seg=(10, 5), flat=0.3)
    # a rusty horseshoe and a few nails
    pts = []
    for j in range(11):
        th = math.pi * (-0.15 + 1.3 * j / 10)
        pts.append(V((math.cos(th) * 0.05, math.sin(th) * 0.05 - 0.01, 0.022)))
    k.tube(pts, 0.009, "#9A5A3A", 6)
    for p in pts[1::3]:
        k.ell(p + V((0, 0, 0.008)), 0.003, "#5A3A2A", seg=(4, 3))
    for i in range(3):
        a = 0.6 + i * 0.9
        c = V((0.03 * i - 0.03, 0.05, 0.02))
        d = V((math.cos(a), math.sin(a), 0))
        k.tube([c - d * 0.03, c + d * 0.03], [0.004, 0.002], "#7A6A66", 4)
        k.ell(c - d * 0.03, (0.007, 0.007, 0.003), "#7A6A66", seg=(6, 3), rot=d)
    for j in range(12):
        a = k.rng.uniform(0, 6.28)
        rr = k.rng.uniform(0.02, 0.08)
        k.ell((math.cos(a) * rr, math.sin(a) * rr, 0.017), 0.004, "#A0603A", seg=(4, 3))


def b_salt(k):
    k.ell((0, 0, 0.09), (0.08, 0.07, 0.09), "#E6D8BC", seg=(12, 8), squash_bottom=0.85, grad=("#F4EAD6", 0.0, 0.18))
    k.cone((0, 0, 0.16), (0, 0, 1), 0.04, 0.04, 0.05, "#E6D8BC", sides=10)
    pts = [V((math.cos(a) * 0.043, math.sin(a) * 0.043, 0.168)) for a in (2 * math.pi * j / 12 for j in range(13))]
    k.tube(pts, 0.005, "#C24A5A", 5, cap=False)
    k.ell((0, 0, 0.2), (0.042, 0.042, 0.014), "#FFFFFF", seg=(10, 5))
    for j in range(5):
        a = k.rng.uniform(0, 6.28)
        k.ell((math.cos(a) * 0.1, math.sin(a) * 0.1, 0.005), 0.006, WHITE, seg=(5, 3))


# ------------------------------------------------------------------ feathers, shells, bone, keepsakes
def feather_pad(k, vane, bars=None, length=0.3, width=0.06, second=True):
    for a, c in ((0.6, "#C8873E"), (2.4, "#A8B860"), (4.2, "#D6A050")):
        k.leaf((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.003), V((math.cos(a), math.sin(a), 0.03)), 0.1, 0.04, c,
               cup=-0.05, fold=0.1)
    k.feather((-0.14, -0.02, 0.012), (1, 0.15, 0), length, width, vane, bars=bars, curl=0.05)
    if second:
        k.feather((-0.08, 0.06, 0.02), (1, -0.35, 0), length * 0.7, width * 0.85, vane, bars=bars, curl=0.04)


def b_crow_feather(k):
    feather_pad(k, "#2A2C3E", bars=[(0.0, 1.0, "#2A2C3E"), (0.55, 0.65, "#3E4A6A")])


def b_hawk_feather(k):
    feather_pad(k, "#B07A4A", bars=[(0.2, 0.3, "#5A3A28"), (0.45, 0.55, "#5A3A28"), (0.7, 0.8, "#5A3A28"),
                                    (0.9, 1.0, "#F2E6D0")])


def b_owl_feather(k):
    feather_pad(k, "#E6D2B4", bars=[(0.25, 0.32, "#A08060"), (0.5, 0.57, "#A08060"), (0.75, 0.82, "#A08060")],
                width=0.065)


def b_jay_feather(k):
    feather_pad(k, "#5A8AE0", bars=[(0.15, 0.25, "#1E2A5A"), (0.35, 0.45, "#FFFFFF"), (0.55, 0.65, "#1E2A5A"),
                                    (0.75, 0.85, "#BFD6FF")], length=0.22, width=0.045)


def b_snail_shell(k):
    moss_pad(k, 0.11, MOSS, 0.02, 4)
    for i, (x, y, a) in enumerate([(0, 0, 0.0)] + k.ring_scatter(2, 0.05, 0.07)):
        s = 1.3 if i == 0 else 0.9
        c = V((x, y, 0.035 * s))
        pts, radii = [], []
        for j in range(22):
            th = j * 0.42
            r = 0.026 * s * math.exp(-0.085 * j)
            pts.append(c + V((math.cos(th + a) * r, math.sin(th + a) * r, 0.002 * j * s)))
            radii.append(0.016 * s * math.exp(-0.085 * j))
        col = ("#E8C8A0", "#F2D8D0", "#D8C0E0")[i % 3]
        k.tube(pts, radii, col, 8, grad=("#8A5A40", c.z - 0.02, c.z + 0.04))


def b_robin_egg(k):
    moss_pad(k, 0.12, "#8A7A55", 0.02, 4)
    for i, (x, y, a) in enumerate(((-0.03, 0, 0.0), (0.04, 0.02, 2.5))):
        c = V((x, y, 0.035))
        d = V((math.cos(a), math.sin(a), 0.5)).normalized()
        k.ell(c, (0.024, 0.024, 0.028), "#9ED8E8", seg=(10, 7), rot=d, squash_bottom=None)
        k.ell(c + d * 0.02, (0.02, 0.02, 0.006), "#F4F2EA", seg=(10, 4), rot=d)
        for j in range(4):
            b = 2 * math.pi * j / 4 + a
            k.cone(c + d * 0.024, (d + V((math.cos(b), math.sin(b), 0)) * 0.6).normalized(), 0.01, 0.006, 0.0005,
                   "#B4E4F0", sides=4)


def antler(k, scale=1.0):
    s = scale
    main = [V((-0.14, 0, 0.02)), V((-0.06, 0.02, 0.03)), V((0.04, 0.0, 0.035)), V((0.14, -0.04, 0.06)),
            V((0.2, -0.08, 0.12))]
    main = [p * s for p in main]
    k.tube(main, [0.024 * s, 0.02 * s, 0.017 * s, 0.013 * s, 0.006 * s], "#E8DCC4", 7,
           grad=("#B89A78", 0.0, 0.05 * s))
    k.ell(main[0], (0.03 * s, 0.03 * s, 0.03 * s), "#8A6A50", seg=(8, 6))
    for p, d, L in ((main[1], V((0.1, 1, 0.8)), 0.1), (main[2], V((0.3, -1, 1.0)), 0.12), (main[3], V((0.4, 0.4, 1)), 0.08)):
        k.cone(p, d, L * s, 0.012 * s, 0.003 * s, "#EEE4D0", sides=6)


def b_shed_antler(k):
    k.pebble((0, 0, -0.004), (0.2, 0.12, 0.012), "#A89878", seed_jit=0.1, seg=(10, 5), flat=0.2)
    antler(k, 1.0)


def b_bone_charm(k):
    k.pebble((0, 0, -0.004), (0.1, 0.08, 0.01), "#A89878", seed_jit=0.1, seg=(10, 5), flat=0.2)
    pts = []
    for j in range(25):
        t = j / 24 * 2 * math.pi
        pts.append(V((math.sin(t) * 0.04, math.sin(2 * t) * 0.022, 0.03 + 0.006 * math.cos(t))))
    k.tube(pts, 0.009, "#F2EAD8", 6, cap=False)
    k.tube([V((-0.045, 0.0, 0.03)), V((-0.08, 0.04, 0.01)), V((-0.1, 0.0, 0.006))], 0.0025, "#8A5A3A", 4)
    k.tube([V((0.045, 0.0, 0.03)), V((0.08, -0.04, 0.01)), V((0.1, 0.01, 0.006))], 0.0025, "#8A5A3A", 4)


def b_odd_stone(k):
    pts = [V((math.cos(t) * 0.05, 0, 0.065 + math.sin(t) * 0.05)) for t in (2 * math.pi * j / 18 for j in range(19))]
    k.tube(pts, 0.026, "#9A9AA8", 9, cap=False, grad=("#C8C8D4", 0.0, 0.12))
    k.pebble((0.08, 0.05, 0), (0.025, 0.02, 0.012), "#B0AAA0", seed_jit=0.2, seg=(6, 4), flat=0.5)


def b_painted_pebble(k):
    k.pebble((0, 0, 0), (0.07, 0.055, 0.025), "#8E96A6", seed_jit=0.06, seg=(14, 8), flat=0.5,
             grad=("#B8C0CE", 0.0, 0.04))
    c = V((0, 0, 0.043))
    k.petal_ring(c, (0, 0, 1), 0.02, 5, "#F27AA0", cup=-0.15, width=0.7, heart=YELLOW, heart_r=0.007)
    k.leaf(c + V((0.012, -0.012, 0)), (1, -1, -0.1), 0.025, 0.01, "#6EAE5A", cup=-0.1, up=(0, 0, 1))


def b_river_glass(k):
    for i, (x, y, s, col) in enumerate(((0, 0, 1.0, "#8ED6A8"), (0.06, 0.03, 0.6, "#A8D8EE"), (-0.05, 0.04, 0.55,
                                                                                               "#C8EEC0"))):
        k.pebble((x, y, 0), (0.045 * s, 0.035 * s, 0.018 * s), col, seed_jit=0.12, seg=(10, 6), flat=0.5,
                 grad=("#F2FFF6", 0.0, 0.03 * s))


def b_old_arrowhead(k):
    k.pebble((0, 0, -0.004), (0.1, 0.08, 0.01), "#A89878", seed_jit=0.1, seg=(10, 5), flat=0.2)
    tip = V((0.07, 0, 0.012))
    k.cone((-0.01, 0, 0.012), (1, 0, 0), 0.08, 0.03, 0.001, "#8A5A44", sides=4, grad=("#B87A58", 0.0, 0.02))
    k.tube([V((-0.01, 0, 0.012)), V((-0.08, 0, 0.012))], [0.007, 0.006], "#6A5A50", 5)
    k.ell(V((-0.03, 0, 0.012)), (0.006, 0.012, 0.012), "#B24A3A", seg=(6, 4))
    del tip


def b_dead_chicken(k):
    # Suriel bait from the manor larder: a plucked hen lying on her side, neck limp, legs tied with twine.
    SKIN, SKIN_HI, LEG, RED = "#EBC9AE", "#F7E2D0", "#E8B444", "#D23A30"
    k.ell((0, 0, 0.048), (0.085, 0.062, 0.048), SKIN, seg=(14, 9), squash_bottom=0.75, grad=(SKIN_HI, 0.02, 0.09))
    k.ell((0.035, -0.005, 0.052), (0.05, 0.05, 0.038), SKIN_HI, seg=(10, 7), squash_bottom=0.8)
    k.ell((-0.088, 0, 0.06), (0.018, 0.016, 0.014), SKIN, seg=(8, 5))
    k.ell((-0.005, 0.005, 0.088), (0.06, 0.034, 0.012), "#E0B89A", seg=(10, 6))
    neck = [V((0.07, 0, 0.05)), V((0.1, 0.012, 0.035)), V((0.125, 0.028, 0.02)), V((0.14, 0.035, 0.016))]
    k.tube(neck, [0.02, 0.016, 0.013, 0.012], "#E6BDA4", 7)
    k.ell((0.152, 0.036, 0.017), (0.022, 0.016, 0.016), "#E6BDA4", seg=(9, 6))
    k.cone((0.17, 0.036, 0.016), (1, 0.15, -0.1), 0.016, 0.006, 0.001, "#E2A838", sides=5)
    for j in range(4):
        k.ell((0.138 + 0.011 * j, 0.036, 0.033 + 0.004 * math.sin(j * 1.7)), (0.007, 0.004, 0.009), RED, seg=(6, 4))
    k.ell((0.168, 0.036, 0.002), (0.006, 0.004, 0.008), RED, seg=(6, 4))
    k.ell((0.158, 0.05, 0.022), (0.004, 0.002, 0.0015), INK, seg=(5, 3))
    for y, z in ((0.03, 0.06), (-0.02, 0.035)):
        k.ell((-0.055, y, z), (0.04, 0.026, 0.026), SKIN, seg=(9, 6), rot=(1, 0.1, 0.3))
        a, b = V((-0.085, y, z + 0.004)), V((-0.135, y + 0.01, z - 0.005))
        k.tube([a, b], [0.007, 0.006], LEG, 5)
        for t in (-0.5, 0, 0.5):
            k.stem(b, b + V((-0.025, 0.02 * t, -0.008)), 0.003, LEG, bend=(0, 0, -0.004), n=3, sides=4, tip=0.0015)
    k.tube(k.curve((-0.115, 0.045, 0.06), (-0.11, -0.03, 0.03), bend=(0.0, 0.0, 0.03), n=5), 0.003, "#9A7A4E", 4)
    k.tube(k.curve((-0.11, -0.03, 0.03), (-0.12, 0.04, 0.052), bend=(0.0, 0.0, -0.025), n=5), 0.003, "#9A7A4E", 4)
    for v in k.bm.verts:  # drawn at 0.55 m nose to toe; L12 wants about 0.35 m after the small-find x1.6
        v.co *= 0.64


def b_trout(k):
    k.ell((0, 0, 0.008), (0.16, 0.12, 0.008), "#7EB8D8", seg=(12, 4), grad=("#B8E2F2", 0, 0.016))
    c = V((0, 0, 0.035))
    pts = [V((-0.11, 0, 0.03)), V((-0.05, 0, 0.035)), V((0.03, 0, 0.036)), V((0.09, 0, 0.033))]
    k.tube(pts, [0.008, 0.024, 0.026, 0.012], "#F0E2C8", 8, grad=("#7A8A52", c.z - 0.012, c.z + 0.02))
    for s in (1, -1):
        k.leaf(V((-0.11, 0, 0.03)), V((-1, s * 0.7, 0)), 0.04, 0.02, "#7A8A5A", up=(0, 0, 1), cup=0.0, shape="round")
    for j in range(8):
        k.ell((k.rng.uniform(-0.05, 0.07), k.rng.choice((-1, 1)) * 0.021, k.rng.uniform(0.033, 0.045)), 0.004, "#C2443A",
              seg=(5, 3))
    for s in (1, -1):
        k.ell((0.075, s * 0.014, 0.04), 0.005, INK, seg=(6, 4))


# ------------------------------------------------------------------ the list
ITEMS = {
    # human realm finds
    "ing_acorn": b_acorn, "ing_dead_chicken": b_dead_chicken, "ing_ash_wood": b_ash_wood, "ing_birch_bark": b_birch_bark, "ing_blackberry": b_blackberry,
    "ing_chaga": b_chaga, "ing_chalk": b_chalk, "ing_charcoal": b_charcoal, "ing_clay": b_clay,
    "ing_crow_feather": b_crow_feather, "ing_flint": b_flint, "ing_frozen_reed": b_frozen_reed,
    "ing_hawk_feather": b_hawk_feather, "ing_hawthorn_haw": b_hawthorn, "ing_hazelnut": b_hazelnut,
    "ing_holly_berry": b_holly, "ing_ice_moss": b_ice_moss, "ing_iron_filings": b_iron,
    "ing_juniper_berry": b_juniper, "ing_madder": b_madder, "ing_mistletoe": b_mistletoe, "ing_oak_gall": b_oak_gall,
    "ing_old_mans_beard": b_old_mans_beard, "ing_owl_feather": b_owl_feather, "ing_pine_needles": b_pine,
    "ing_pine_resin": b_pine_resin, "ing_red_ochre": b_red_ochre, "ing_rose_hip": b_rose_hip, "ing_salt": b_salt,
    "ing_shed_antler": b_shed_antler, "ing_sloe": b_sloe, "ing_snail_shell": b_snail_shell,
    "ing_snowdrop": b_snowdrop, "ing_snowmelt_water": b_snowmelt, "ing_tinder_fungus": b_tinder_fungus,
    "ing_willow_bark": b_willow_bark, "ing_wintergreen": b_wintergreen, "ing_woad": b_woad,
    # spring court woods
    "ing_blighted_petals": b_blighted, "ing_crocus": b_crocus, "ing_elderflower": b_elderflower,
    "ing_faelight_dandelion": b_faelight_dandelion, "ing_foxglove": b_foxglove, "ing_glowcap": b_glowcap,
    "ing_hollow_root": b_hollow_root, "ing_honey": b_honey, "ing_honeysuckle": b_honeysuckle,
    "ing_meadowsweet": b_meadowsweet, "ing_moss": b_moss_star, "ing_primrose": b_primrose,
    "ing_river_silt": b_river_silt, "ing_rose_red": b_rose_red, "ing_rose_white": b_rose_white,
    "ing_thornbriar_sap": b_thornbriar_sap, "ing_trout": b_trout, "ing_violet": b_violet,
    "ing_water_mint": b_water_mint, "ing_wild_garlic": b_wild_garlic, "ing_wild_hyacinth": b_wild_hyacinth,
    "ing_wild_strawberry": b_wild_strawberry, "ing_wood_sorrel": b_wood_sorrel,
    # spring court keepsakes
    "col_acorn_caps": b_acorn_caps, "col_bone_charm": b_bone_charm, "col_jay_feather": b_jay_feather,
    "col_odd_stone": b_odd_stone, "col_old_arrowhead": b_old_arrowhead,
    "col_painted_pebble": b_painted_pebble, "col_river_glass": b_river_glass, "col_robin_egg_shell": b_robin_egg,
    "col_shed_antler": b_shed_antler,
}


def build(item_id):
    fk.reset()
    k = fk.K(seed=sum(map(ord, item_id)))
    ITEMS[item_id](k)
    # small finds are drawn a little oversized so they read on snow and in grass from a few metres
    span = max(max(v.co[i] for v in k.bm.verts) - min(v.co[i] for v in k.bm.verts) for i in range(3))
    grow = 1.6 if span < 0.6 else 1.0
    for v in k.bm.verts:
        v.co *= grow
    ob = k.to_object(item_id)
    t = fk.tri_count(ob)
    if t > MAX_TRIS:
        dec = ob.modifiers.new("cap", "DECIMATE")
        dec.ratio = MAX_TRIS * 0.97 / t
        with bpy.context.temp_override(object=ob, active_object=ob):
            bpy.ops.object.modifier_apply(modifier=dec.name)
    lo = fk.lod(ob, 0.5)
    fk.export([ob, lo], os.path.join(OUT, item_id + ".glb"))
    print("FORAGE %-24s tris=%5d lod1=%5d (raw %d)" % (item_id, fk.tri_count(ob), fk.tri_count(lo), t))


def main():
    os.makedirs(OUT, exist_ok=True)
    only = [a for a in sys.argv[1:] if a in ITEMS]
    for item_id in (only or ITEMS):
        build(item_id)


if __name__ == "__main__":
    main()
