"""Build the human realm shared flora/rock library in one deterministic run.

Run (headless bpy):
  <bpyenv>/bin/python tools/blender/human_realm/build_flora.py [out_dir] [only_id ...]
Writes <out_dir>/<id>.glb for every asset and <id>_far.glb for every tree.
Default out_dir: world/human_realm/shared/assets/flora (relative to repo root).
Prints a budget table and exits non-zero if any asset breaks its budget.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flora_lib as fl  # noqa: E402
from mathutils import Vector as V  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "world/human_realm/shared/assets/flora")

ASSETS = {}  # id -> (fn, budget)


def asset(budget):
    def deco(fn):
        ASSETS[fn.__name__] = (fn, budget)
        return fn
    return deco


def ring_pts(rng, n, r, jitter=0.3):
    out = []
    for k in range(n):
        a = 2 * math.pi * k / n + rng.uniform(-jitter, jitter)
        rr = r * rng.uniform(0.4, 1.0)
        out.append(V((math.cos(a) * rr, math.sin(a) * rr, 0)))
    return out


def berry_cluster(b, center, n, r, spread, color, subdiv=0):
    for _ in range(n):
        off = V((b.rng.uniform(-1, 1), b.rng.uniform(-1, 1), b.rng.uniform(-0.6, 0.6))) * spread
        b.berry(center + off, r * b.rng.uniform(0.85, 1.15), color, subdiv)


def dead_leaves(b, tips, n, color="bracken", size=0.12):
    for p, d, _r in b.rng.sample(tips, min(n, len(tips))):
        for _ in range(2):
            dd = (d + V((b.rng.uniform(-1, 1), b.rng.uniform(-1, 1), -0.6))).normalized()
            b.leaf(p, dd, size, size * 0.55, fl.jitter(color, b.rng, 0.15))


# ===================================================================== trees
OAK = dict(depth=3, segs=[6, 3, 2, 2], sides=[10, 6, 4, 3], children=[5, 4, 3],
           spread=0.95, ratio=0.6, rratio=0.62, taper=0.6, wobble=0.28, droop=0.04,
           color="bark_wet", tip_color="bark_grey", child_start=0.45, up_bias=0.08)


@asset(6000)
def tree_oak_bare(b):
    tips = []
    fl.flare(b, V((0, 0, 0)), 0.5, 5, "bark_wet", 0.7, 1.0)
    fl.grow(b, V((0, 0, 0)), V((0.05, 0, 1)), 4.2, 0.48, 0, OAK, tips)
    # oaks hold a few dead leaves through winter (marcescence)
    dead_leaves(b, tips, 40, "bracken", 0.16)
    # snow resting in the main fork
    b.blob(V((0, 0, 3.6)), (0.35, 0.3, 0.12), 1, "snow", 0.2)


@asset(6000)
def tree_ash(b):
    # rare noble-grove ash: pale smooth grey, tall clean bole, stately domed crown
    cfg = dict(depth=3, segs=[8, 3, 2, 2], sides=[10, 6, 4, 3], children=[6, 3, 2],
               spread=0.68, ratio=0.55, rratio=0.55, taper=0.58, wobble=0.08, rise=0.12,
               color="bark_ash", tip_color="bark_ash_lt", child_start=0.6, up_bias=0.25)
    tips = []
    fl.flare(b, V((0, 0, 0)), 0.38, 6, "bark_ash", 0.5, 0.7)
    fl.grow(b, V((0, 0, 0)), V((0, 0, 1)), 7.5, 0.38, 0, cfg, tips)
    for p, d, _r in tips:  # black buds
        b.berry(p + d * 0.03, 0.035, "bark_wet")
    # hanging bunches of ash keys
    for p, d, _r in b.rng.sample(tips, min(10, len(tips))):
        for _ in range(4):
            dd = V((b.rng.uniform(-0.4, 0.4), b.rng.uniform(-0.4, 0.4), -1))
            b.leaf(p, dd, 0.14, 0.04, "straw_dark")


@asset(6000)
def tree_birch(b):
    cfg = dict(depth=3, segs=[10, 3, 2, 2], sides=[10, 5, 3, 3], children=[7, 4, 3],
               spread=0.65, ratio=0.5, rratio=0.45, taper=0.5, wobble=0.18, droop=0.22,
               color="bark_birch", child_start=0.5, up_bias=0.05)
    tips = []
    rng = b.rng
    start = len(b.bm.faces)
    fl.grow(b, V((0, 0, 0)), V((0.04, 0.02, 1)), 7.0, 0.2, 0, cfg, tips)
    b.bm.faces.ensure_lookup_table()
    for i, f in enumerate(b.bm.faces):
        if i < start:
            continue
        z = f.calc_center_median().z
        if rng.random() < (0.32 if z < 2 else 0.18):
            b._paint([f], fl.col("birch_mark"))
        elif z > 6:
            b._paint([f], fl.mix("bark_birch", "willow_red", 0.6))
    # dark base ring
    b.tube([V((0, 0, -0.1)), V((0, 0, 0.5))], [0.25, 0.21], 8, "bark_wet", cap=False)
    # purple-brown twig haze on drooping tips
    for p, d, _r in tips:
        dd = (d + V((0, 0, -0.8))).normalized()
        b.tube([p, p + dd * 0.4], [0.012, 0.004], 3, "willow_red", cap=False)


@asset(6000)
def tree_pine(b):
    # Scots pine: bare lower trunk, orange upper, flat-topped clumpy crown
    pts, _ = b.branch_curve(V((0, 0, 0)), V((0, 0, 1)), 11.0, 9, 0.06)
    radii = [0.36 - 0.27 * (i / 9) for i in range(10)]
    b.tube(pts, radii, 8, "bark_pine", "orange_hip", cap=True)
    fl.flare(b, V((0, 0, 0)), 0.36, 4, "bark_pine", 0.35, 0.5)
    rng = b.rng
    for k in range(14):
        h = 5.8 + k * 0.38
        a = k * 2.4 + rng.uniform(-0.3, 0.3)
        L = 2.0 - k * 0.09
        d = V((math.cos(a), math.sin(a), 0.25))
        base = V((pts[0].x, pts[0].y, h))
        bp, end = b.branch_curve(base, d, L, 2, 0.15)
        b.tube(bp, [0.09, 0.06, 0.03], 4, "bark_pine", cap=False)
        b.blob(bp[-1] + V((0, 0, 0.15)), (0.9, 0.9, 0.42), 1,
               "evergreen" if k % 2 else "evergreen_lt", 0.25, snow=0.65)
        mid = bp[1]
        b.blob(mid + V((0, 0, 0.2)), (0.55, 0.55, 0.3), 1, "evergreen_lt", 0.3, snow=0.65)
    b.blob(pts[-1] + V((0, 0, 0.1)), (0.8, 0.8, 0.45), 1, "evergreen", 0.25, snow=0.65)
    # a few dead lower stubs
    for k in range(4):
        a = rng.uniform(0, 6.28)
        base = V((0, 0, 2.5 + k * 0.9))
        b.tube([base, base + V((math.cos(a), math.sin(a), 0.1)) * 0.5], [0.04, 0.015], 3, "wood_dead")


@asset(6000)
def tree_spruce(b):
    H = 10.0
    b.tube([V((0, 0, 0)), V((0, 0, 2)), V((0, 0, H))], [0.28, 0.22, 0.03], 7, "bark_brown")
    tiers = 12
    for k in range(tiers):
        t = k / tiers
        z = 0.9 + t * (H - 1.6)
        r = 2.4 * (1 - t) ** 1.05 + 0.25
        h = 1.5 * (1 - t * 0.4)
        b.cone(V((0, 0, z)), h, r, 14, "spruce", "evergreen", droop=0.35,
               snow=0.45, ragged=0.2)
        nsp = max(3, int(8 * (1 - t)))
        for j in range(nsp):  # drooping branch sprays past the tier edge
            a = 2 * math.pi * j / nsp + k * 0.7
            d = V((math.cos(a), math.sin(a), 0))
            p = V((0, 0, z)) + d * r * 0.85 + V((0, 0, -0.3 * r * 0.35))
            tip = p + d * r * 0.3 + V((0, 0, -0.18))
            b.tube([p, tip], [0.12 * r * 0.4 + 0.05, 0.02], 4, "spruce", cap=False)
            if (j + k) % 2 == 0:
                b.blob(p + V((0, 0, 0.12)), (0.2 * r * 0.4 + 0.1, 0.18, 0.06), 0, "snow", 0.2)
    b.cone(V((0, 0, H - 0.7)), 1.0, 0.3, 6, "spruce")
    # cones hanging near the top
    for k in range(6):
        a = k * 1.1
        p = V((math.cos(a) * 0.6, math.sin(a) * 0.6, H - 2.5 + b.rng.uniform(-0.5, 0.5)))
        b.blob(p, (0.04, 0.04, 0.1), 0, "cone", 0.1)


@asset(4000)
def tree_dead_snag(b):
    pts, _ = b.branch_curve(V((0, 0, 0)), V((0.08, 0, 1)), 5.5, 7, 0.1)
    radii = [0.4 - 0.15 * (i / 7) for i in range(8)]
    b.tube(pts, radii, 12, "wood_dead", "bark_grey", cap=False)
    # jagged broken top: a crown of spikes
    top = pts[-1]
    for k in range(6):
        a = 2 * math.pi * k / 6
        o = V((math.cos(a), math.sin(a), 0)) * radii[-1] * 0.8
        b.cone(top + o, b.rng.uniform(0.2, 0.9), 0.1, 4, "wood_dead", bottom=False)
    b.blob(top, (radii[-1], radii[-1], 0.08), 1, "wood_cut", 0.1)
    fl.flare(b, V((0, 0, 0)), 0.42, 5, "wood_dead", 0.6, 0.9)
    cfg = dict(depth=2, segs=[3, 2, 2], sides=[6, 4, 3], children=[3, 2], spread=0.6, ratio=0.5,
               rratio=0.6, taper=0.3, wobble=0.2, color="wood_dead", child_start=0.5,
               leader=False)
    for k in range(4):
        a = k * 1.9 + 0.4
        base = pts[3 + k]
        fl.grow(b, base, V((math.cos(a), math.sin(a), 0.4)), 1.6 - k * 0.2, 0.09, 0, cfg, [])
    # tinder fungus brackets and woodpecker holes
    for k in range(4):
        a = 1.0 + k * 0.4
        z = 1.2 + k * 0.6
        p = V((math.cos(a) * 0.36, math.sin(a) * 0.36, z))
        b.blob(p, (0.18, 0.18, 0.1), 1, "tinder", 0.15, snow=0.5)


@asset(5000)
def tree_willow_pollard(b):
    pts, _ = b.branch_curve(V((0, 0, 0)), V((0.05, 0, 1)), 2.0, 4, 0.12)
    b.tube(pts, [0.42, 0.38, 0.4, 0.45, 0.5], 9, "bark_grey", "bark_wet", cap=False)
    head = pts[-1]
    b.blob(head, (0.6, 0.6, 0.35), 2, "bark_wet", 0.4)
    for k in range(5):  # knuckles
        a = k * 1.25
        b.blob(head + V((math.cos(a) * 0.45, math.sin(a) * 0.45, 0.1)), 0.18, 1, "bark_grey", 0.3)
    fl.flare(b, V((0, 0, 0)), 0.42, 4, "bark_grey", 0.4, 0.6)
    rng = b.rng
    for k in range(34):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.15, 0.5)
        base = head + V((math.cos(a) * r, math.sin(a) * r, 0.2))
        d = V((math.cos(a) * 0.35, math.sin(a) * 0.35, 1))
        L = rng.uniform(1.4, 3.2)
        p, _ = b.branch_curve(base, d, L, 3, 0.05)
        c = "willow_red" if rng.random() < 0.6 else "willow_yellow"
        b.tube(p, [0.03, 0.022, 0.014, 0.006], 3, c, cap=False)


@asset(15000)
def tree_waiting_oak(b):
    """Hero oak where Feyre waits: huge, gnarled, low near-flat sitting branch."""
    cfg = dict(depth=4, segs=[10, 4, 3, 2, 2], sides=[16, 10, 6, 4, 3], children=[6, 4, 3, 2],
               spread=1.0, ratio=0.62, rratio=0.6, taper=0.62, wobble=0.3, droop=0.05,
               color="bark_wet", tip_color="bark_grey", child_start=0.5, up_bias=0.05)
    tips = []
    fl.flare(b, V((0, 0, 0)), 1.3, 7, "bark_wet", 1.4, 2.2)
    fl.grow(b, V((0, 0, 0)), V((0.06, -0.03, 1)), 6.0, 1.25, 0, cfg, tips)
    # the waiting branch: thick, near-horizontal at ~1.7 m, toward +X (sit spot ~2.6 m out)
    pts = [V((0.6, 0, 1.6)), V((1.6, 0.05, 1.75)), V((2.6, 0.1, 1.72)),
           V((3.6, 0.2, 1.85)), V((4.6, 0.4, 2.2)), V((5.5, 0.6, 2.8))]
    b.tube(pts, [0.42, 0.34, 0.3, 0.26, 0.2, 0.12], 10, "bark_wet", "bark_grey", cap=True)
    sub = dict(cfg, depth=2, children=[3, 2], segs=[3, 2, 2], sides=[5, 4, 3])
    fl.grow(b, pts[-1], V((0.6, 0.2, 0.8)), 2.4, 0.12, 0, sub, tips)
    fl.grow(b, pts[3], V((0.2, -0.8, 0.6)), 2.0, 0.12, 0, sub, tips)
    # bark worn smooth where she sits: lighter strip
    b.blob(V((2.6, 0.1, 1.98)), (0.45, 0.22, 0.05), 1, "bark_grey", 0.1)
    # burls and a hollow
    for k, (a, z, r) in enumerate([(0.5, 1.0, 0.45), (2.4, 2.4, 0.38), (4.1, 0.7, 0.5), (5.3, 3.3, 0.32)]):
        b.blob(V((math.cos(a) * 1.1, math.sin(a) * 1.1, z)), r, 1, "bark_wet", 0.4)
    b.blob(V((-0.95, -0.55, 1.1)), (0.25, 0.25, 0.45), 1, "charcoal", 0.15)
    # ivy-dark moss on the north side, dead leaves held in the crown, mistletoe
    for k in range(10):
        a = 3.6 + b.rng.uniform(-0.6, 0.6)
        z = b.rng.uniform(0.2, 2.5)
        b.blob(V((math.cos(a) * 1.2, math.sin(a) * 1.2, z)), (0.25, 0.25, 0.4), 0, "moss_ice", 0.2)
    dead_leaves(b, tips, 70, "bracken", 0.18)
    for p, _d, _r in b.rng.sample(tips, 3):
        b.blob(p, 0.4, 1, "mistletoe", 0.35)
        berry_cluster(b, p, 5, 0.03, 0.3, "mistletoe_berry")


# ------------------------------------------------------------- far LODs
def far_tree(b, kind):
    if kind in ("tree_spruce",):
        b.tube([V((0, 0, 0)), V((0, 0, 1.2))], [0.28, 0.25], 5, "bark_brown")
        b.cone(V((0, 0, 1.0)), 5.0, 2.5, 8, "spruce", droop=0.2, snow=0.5)
        b.cone(V((0, 0, 4.2)), 5.8, 1.5, 8, "spruce", "evergreen", droop=0.2, snow=0.5)
        return
    if kind == "tree_pine":
        b.tube([V((0, 0, 0)), V((0, 0, 7)), V((0, 0, 10.5))], [0.36, 0.2, 0.1], 5, "bark_pine", "orange_hip")
        b.blob(V((0, 0, 9.4)), (2.3, 2.3, 1.3), 1, "evergreen", 0.25, snow=0.6)
        return
    spec = {
        "tree_oak_bare": (4.2, 0.48, "bark_wet", (4.2, 4.2, 3.0), 6.6, "bark_grey"),
        "tree_ash": (7.5, 0.38, "bark_ash", (3.4, 3.4, 3.8), 10.0, "bark_ash_lt"),
        "tree_birch": (7.0, 0.2, "bark_birch", (2.2, 2.2, 3.4), 8.6, "willow_red"),
        "tree_dead_snag": (5.6, 0.4, "wood_dead", None, 0, ""),
        "tree_willow_pollard": (2.0, 0.45, "bark_grey", (1.5, 1.5, 1.5), 3.6, "willow_red"),
        "tree_waiting_oak": (6.0, 1.25, "bark_wet", (8.0, 8.0, 4.6), 9.6, "bark_grey"),
    }[kind]
    h, r, c, crown, cz, cc = spec
    b.tube([V((0, 0, 0)), V((0, 0, h * 0.6)), V((0, 0, h))], [r, r * 0.8, r * 0.55], 6, c)
    if crown:
        # a twig-haze crown: two low lumps reading as fine branches at distance
        b.blob(V((0, 0, cz)), crown, 1, cc, 0.3)
        b.blob(V((crown[0] * 0.4, 0, cz - crown[2] * 0.5)), tuple(x * 0.6 for x in crown), 0, cc, 0.3)
    if kind == "tree_waiting_oak":
        b.tube([V((0.6, 0, 1.6)), V((3.0, 0.1, 1.75)), V((5.5, 0.6, 2.8))], [0.42, 0.3, 0.12], 5, c)


# ================================================================== shrubs
@asset(1500)
def holly_bush(b):
    rng = b.rng
    for k in range(6):
        a = k * 1.05 + rng.uniform(-0.3, 0.3)
        r = 0.45 if k else 0
        p = V((math.cos(a) * r, math.sin(a) * r, 0.7 + rng.uniform(-0.1, 0.5)))
        b.blob(p, (0.55, 0.55, 0.6), 1, "holly_leaf", 0.35, color2="evergreen")
        berry_cluster(b, p + V((0, 0, 0.25)), 5, 0.035, 0.45, "red")
    b.blob(V((0, 0, 1.55)), (0.4, 0.4, 0.4), 1, "holly_leaf", 0.35)
    b.tube([V((0, 0, 0)), V((0, 0, 0.5))], [0.08, 0.06], 5, "bark_grey")


@asset(1500)
def juniper_shrub(b):
    rng = b.rng
    for k in range(5):
        a = k * 1.3
        r = 0.25 if k else 0
        h = rng.uniform(1.2, 2.0) if k else 2.2
        p = V((math.cos(a) * r, math.sin(a) * r, h * 0.5))
        b.blob(p, (0.32, 0.32, h * 0.5), 1, "juniper", 0.3, snow=0.6, color2="evergreen")
        berry_cluster(b, p, 6, 0.028, 0.35, "juniper_berry")


def arch_canes(b, n, color, height, reach, sides=4, thorn=False):
    rng = b.rng
    ends = []
    for k in range(n):
        a = 2 * math.pi * k / n + rng.uniform(-0.4, 0.4)
        d = V((math.cos(a), math.sin(a), 0))
        L = reach * rng.uniform(0.7, 1.1)
        h = height * rng.uniform(0.7, 1.1)
        pts = [V((0, 0, 0)) + d * 0.05]
        for i in range(1, 6):
            t = i / 5
            pts.append(d * L * t + V((0, 0, h * math.sin(t * math.pi * 0.85))))
        b.tube(pts, [0.025, 0.022, 0.018, 0.014, 0.01, 0.005], sides, color, cap=False)
        ends.append(pts)
    return ends


@asset(1500)
def blackberry_bramble(b):
    canes = arch_canes(b, 11, "red_deep", 0.9, 1.4)
    for pts in canes:
        berry_cluster(b, pts[3] + V((0, 0, -0.04)), 3, 0.02, 0.03, "charcoal")
        b.leaf(pts[3], V((0.3, 0.2, -0.6)), 0.1, 0.07, "red_deep")
    b.blob(V((0, 0, 0.1)), (0.3, 0.3, 0.12), 1, "straw_dark", 0.3)


@asset(1500)
def wild_rose_briar(b):
    canes = arch_canes(b, 9, "willow_red", 1.3, 1.1)
    for pts in canes:
        for p in pts[2:]:
            if b.rng.random() < 0.7:
                b.blob(p + V((0, 0, -0.03)), (0.025, 0.025, 0.04), 0, "orange_hip", 0.1)
    b.blob(V((0, 0, 0.1)), (0.25, 0.25, 0.12), 1, "straw_dark", 0.3)


def twiggy_shrub(b, color, height, spread_r, berry, berry_col, n_berries, berry_r):
    cfg = dict(depth=2, segs=[4, 2, 2], sides=[5, 3, 3], children=[4, 3], spread=0.8,
               ratio=0.55, rratio=0.6, taper=0.5, wobble=0.35, color=color,
               child_start=0.35, up_bias=0.1)
    tips = []
    for k in range(4):
        a = k * 1.6
        d = V((math.cos(a) * spread_r, math.sin(a) * spread_r, 1))
        fl.grow(b, V((math.cos(a) * 0.1, math.sin(a) * 0.1, 0)), d, height * 0.55, 0.05, 0, cfg, tips)
    if berry:
        for p, d, _r in b.rng.sample(tips, min(n_berries, len(tips))):
            berry_cluster(b, p, 2, berry_r, 0.05, berry_col)
    return tips


@asset(1500)
def blackthorn_sloe(b):
    tips = twiggy_shrub(b, "bark_wet", 2.0, 0.5, True, "sloe", 10, 0.03)
    for p, d, _r in tips[::2]:  # thorns
        b.cone(p, 0.08, 0.008, 3, "bark_wet", bottom=False)


@asset(1500)
def hawthorn(b):
    # small gnarled tree-shrub
    cfg = dict(depth=2, segs=[5, 3, 2], sides=[6, 4, 3], children=[4, 4], spread=0.9,
               ratio=0.55, rratio=0.55, taper=0.55, wobble=0.35, droop=0.05,
               color="bark_grey", tip_color="bark_wet", child_start=0.5, up_bias=0.05)
    tips = []
    fl.grow(b, V((0, 0, 0)), V((0.15, 0, 1)), 1.6, 0.09, 0, cfg, tips)
    for p, d, _r in tips:
        berry_cluster(b, p, 3, 0.028, 0.06, "red")


@asset(1500)
def hazel_shrub(b):
    rng = b.rng
    for k in range(9):
        a = 2 * math.pi * k / 9 + rng.uniform(-0.3, 0.3)
        d = V((math.cos(a) * 0.3, math.sin(a) * 0.3, 1))
        pts, _ = b.branch_curve(V((math.cos(a) * 0.12, math.sin(a) * 0.12, 0)), d, rng.uniform(2.0, 3.0), 4, 0.06)
        b.tube(pts, [0.035, 0.03, 0.022, 0.015, 0.006], 4, "bark_brown", "bark_grey", cap=False)
        for i in (2, 3, 4):  # catkins: lamb's tails
            p = pts[i]
            b.tube([p, p + V((rng.uniform(-0.03, 0.03), 0.02, -0.09))], [0.012, 0.006], 3, "willow_yellow", cap=False)
    b.blob(V((0, 0, 0.06)), (0.22, 0.22, 0.1), 1, "bark_grey", 0.3)


@asset(1500)
def frozen_reeds(b):
    rng = b.rng
    b.blob(V((0, 0, 0.0)), (0.6, 0.6, 0.05), 1, "ice", 0.1)
    for k in range(26):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(0, 0.45)
        base = V((math.cos(a) * r, math.sin(a) * r, 0))
        d = V((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), 1))
        L = rng.uniform(0.9, 1.6)
        b.blade(base, d, L, 0.035, "reed", "straw", bend=0.06, segs=2)
        if k % 3 == 0:  # seed heads
            b.blob(base + d.normalized() * L, (0.025, 0.025, 0.09), 0, "straw_dark", 0.1)


@asset(1500)
def dead_bracken(b):
    rng = b.rng
    for k in range(9):
        a = 2 * math.pi * k / 9 + rng.uniform(-0.3, 0.3)
        d = V((math.cos(a), math.sin(a), 1.2))
        L = rng.uniform(0.6, 0.9)
        b.blade(V((0, 0, 0)), d, L, 0.22, "bracken", "straw_dark", bend=0.55, segs=4)
        b.tube([V((0, 0, 0)), d.normalized() * L * 0.6], [0.01, 0.005], 3, "bracken", cap=False)


@asset(800)
def winter_grass_tuft(b):
    rng = b.rng
    for k in range(18):
        a = rng.uniform(0, 6.28)
        d = V((math.cos(a) * rng.uniform(0.2, 0.7), math.sin(a) * rng.uniform(0.2, 0.7), 1))
        b.blade(V((math.cos(a) * 0.04, math.sin(a) * 0.04, 0)), d, rng.uniform(0.3, 0.5), 0.04,
                "straw_dark", "straw", bend=0.35, segs=2)


@asset(800)
def snow_mound(b):
    b.blob(V((0, 0, 0)), (1.1, 0.8, 0.35), 2, "snow", 0.25, flat_bottom=0.0)


@asset(1500)
def willow_withies(b):
    rng = b.rng
    b.blob(V((0, 0, 0.08)), (0.25, 0.25, 0.14), 1, "bark_grey", 0.3)
    for k in range(22):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(0, 0.2)
        base = V((math.cos(a) * r, math.sin(a) * r, 0.12))
        d = V((math.cos(a) * 0.25, math.sin(a) * 0.25, 1))
        pts, _ = b.branch_curve(base, d, rng.uniform(1.2, 2.2), 3, 0.04)
        c = "willow_red" if rng.random() < 0.55 else "willow_yellow"
        b.tube(pts, [0.016, 0.012, 0.008, 0.004], 3, c, cap=False)


@asset(800)
def woad_rosette(b):
    rng = b.rng
    for k in range(14):
        a = k * 2.4
        t = k / 14
        d = V((math.cos(a), math.sin(a), 0.25 + t * 0.6))
        b.leaf(V((0, 0, 0.02)), d, 0.28 - t * 0.1, 0.09, fl.mix("woad_leaf", "frost", 0.15 * rng.random()))
    b.tube([V((0, 0, 0)), V((0, 0, 0.35))], [0.012, 0.005], 3, "straw_dark")
    b.blob(V((0, 0, 0.36)), 0.03, 0, "straw", 0.1)


@asset(1000)
def madder_patch(b):
    rng = b.rng
    for k in range(10):
        a = rng.uniform(0, 6.28)
        d = V((math.cos(a), math.sin(a), 0.5))
        pts, _ = b.branch_curve(V((0, 0, 0)), d, rng.uniform(0.4, 0.7), 3, 0.25, droop=0.1)
        b.tube(pts, [0.008, 0.007, 0.005, 0.003], 3, "madder_leaf", cap=False)
        for p in pts[1:]:
            for j in range(3):  # whorled leaves
                aa = j * 2.1 + a
                b.leaf(p, V((math.cos(aa), math.sin(aa), 0.1)), 0.06, 0.02, "madder_leaf")
    for k in range(4):  # exposed red roots
        a = k * 1.6
        pts = [V((0, 0, 0.01)), V((math.cos(a) * 0.15, math.sin(a) * 0.15, 0.03)),
               V((math.cos(a + 0.4) * 0.3, math.sin(a + 0.4) * 0.3, 0.0))]
        b.tube(pts, [0.012, 0.01, 0.004], 4, "madder_root", cap=False)
    b.blob(V((0, 0, 0)), (0.2, 0.2, 0.04), 1, "soil", 0.2)


# ============================================================= small forage
@asset(500)
def snowdrop_cluster(b):
    rng = b.rng
    for k in range(6):
        a = k * 1.05 + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.02, 0.09)
        base = V((math.cos(a) * r, math.sin(a) * r, 0))
        h = rng.uniform(0.12, 0.18)
        top = base + V((0.0, 0.0, h))
        nod = top + V((math.cos(a) * 0.025, math.sin(a) * 0.025, -0.005))
        b.tube([base, top, nod], [0.004, 0.003, 0.002], 3, "snowdrop_green", cap=False)
        b.cone(nod + V((0, 0, -0.035)), 0.035, 0.014, 5, "snowdrop", bottom=True)
        b.berry(nod, 0.006, "snowdrop_green")
        b.blade(base, V((math.cos(a + 1) * 0.2, math.sin(a + 1) * 0.2, 1)), h * 0.8, 0.012, "snowdrop_green", segs=1, bend=0.1)


@asset(500)
def wintergreen_patch(b):
    rng = b.rng
    for k in range(12):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(0, 0.15)
        p = V((math.cos(a) * r, math.sin(a) * r, 0.02))
        b.leaf(p, V((math.cos(a), math.sin(a), 0.4)), 0.07, 0.05, "wintergreen")
    berry_cluster(b, V((0, 0, 0.04)), 7, 0.012, 0.08, "red")


@asset(500)
def mistletoe_clump(b):
    rng = b.rng
    tips = []
    for k in range(9):
        a = 2 * math.pi * k / 9
        d = V((math.cos(a), math.sin(a), rng.uniform(0.2, 1.0)))
        p0 = V((0, 0, 0.05))
        p1 = p0 + d.normalized() * 0.15
        b.tube([p0, p1], [0.008, 0.006], 3, "mistletoe", cap=False)
        for s in (-0.5, 0.5):  # forked pairs
            dd = (d + V((math.cos(a + s * 2), math.sin(a + s * 2), 0.3))).normalized()
            b.leaf(p1, dd, 0.07, 0.025, "mistletoe")
        tips.append(p1)
    for p in tips[::2]:
        b.berry(p, 0.012, "mistletoe_berry")


@asset(500)
def chaga_growth(b):
    # a section of fallen birch with the black cracked conk on it
    b.tube([V((-0.35, 0, 0.12)), V((0.35, 0, 0.12))], [0.12, 0.12], 7, "bark_birch", cap=True)
    b.blob(V((0.0, 0.0, 0.25)), (0.13, 0.1, 0.09), 1, "chaga", 0.45, color2="chaga_inner")
    b.blob(V((0.05, 0.02, 0.29)), (0.06, 0.05, 0.03), 0, "chaga_inner", 0.2)


@asset(500)
def tinder_fungus(b):
    b.tube([V((0, 0, 0)), V((0, 0, 0.45))], [0.12, 0.1], 7, "wood_dead", cap=True)
    for k, (a, z, r) in enumerate([(0.3, 0.12, 0.09), (0.5, 0.25, 0.07), (2.8, 0.33, 0.06)]):
        p = V((math.cos(a) * 0.11, math.sin(a) * 0.11, z))
        b.blob(p, (r, r, r * 0.6), 1, "tinder", 0.12, snow=0.5)
        b.blob(p + V((math.cos(a) * r * 0.5, math.sin(a) * r * 0.5, -r * 0.35)), (r * 0.8, r * 0.8, 0.012), 0, "tinder_rim", 0.05)


@asset(500)
def oak_gall_twig(b):
    pts = [V((-0.25, 0, 0.02)), V((0, 0.03, 0.04)), V((0.22, -0.02, 0.06))]
    b.tube(pts, [0.012, 0.009, 0.005], 4, "bark_grey", cap=False)
    for p in (V((-0.1, 0.02, 0.06)), V((0.08, 0.0, 0.08)), V((0.18, -0.02, 0.08))):
        b.blob(p, 0.03, 1, "gall", 0.08)
        b.berry(p + V((0, 0, 0.028)), 0.004, "charcoal")
    b.leaf(pts[2], V((1, 0.4, -0.2)), 0.08, 0.05, "bracken")


@asset(500)
def old_mans_beard(b):
    # fallen lichen-draped twig: pale grey-green strands hanging below
    pts = [V((-0.3, 0, 0.18)), V((0, 0.02, 0.2)), V((0.3, -0.02, 0.15))]
    b.tube(pts, [0.015, 0.012, 0.008], 4, "bark_grey", cap=False)
    b.tube([V((-0.3, 0, 0.18)), V((-0.32, 0, 0.0))], [0.012, 0.01], 3, "bark_grey", cap=False)
    b.tube([V((0.3, -0.02, 0.15)), V((0.31, 0, 0.0))], [0.01, 0.008], 3, "bark_grey", cap=False)
    rng = b.rng
    for k in range(12):
        t = k / 11
        p = pts[0].lerp(pts[2], t)
        b.blade(p, V((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), -1)), rng.uniform(0.08, 0.15), 0.03,
                "lichen", "lichen_grey", bend=0.0, segs=2)


def nut_scatter(b, n, kind):
    rng = b.rng
    b.blob(V((0, 0, 0)), (0.25, 0.25, 0.015), 1, "bracken", 0.2)
    for k in range(n):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(0, 0.2)
        p = V((math.cos(a) * r, math.sin(a) * r, 0.025))
        if kind == "acorn":
            b.blob(p, (0.012, 0.012, 0.018), 0, "acorn", 0.05)
            b.blob(p + V((0, 0, 0.012)), (0.013, 0.013, 0.007), 0, "acorn_cap", 0.05)
        elif kind == "hazel":
            b.blob(p, (0.012, 0.012, 0.012), 0, "hazelnut", 0.08)
            b.blob(p + V((0, 0, 0.01)), (0.008, 0.008, 0.004), 0, "straw", 0.05)
        else:
            b.blob(p + V((0, 0, 0.01)), (0.022, 0.022, 0.04), 0, "cone", 0.35, snow=0.7)


@asset(500)
def acorn_scatter(b):
    nut_scatter(b, 5, "acorn")


@asset(500)
def hazelnut_scatter(b):
    nut_scatter(b, 6, "hazel")


@asset(500)
def pine_cone_scatter(b):
    rng = b.rng
    for k in range(4):
        a = k * 1.7
        p = V((math.cos(a) * 0.1, math.sin(a) * 0.1, 0.025))
        d = V((math.cos(a + 1), math.sin(a + 1), 0.0))
        b.tube([p - d * 0.035, p, p + d * 0.035], [0.012, 0.025, 0.006], 6, "cone", cap=True)
    for k in range(12):  # needles
        a = rng.uniform(0, 6.28)
        r = rng.uniform(0, 0.2)
        p = V((math.cos(a) * r, math.sin(a) * r, 0.003))
        b.blade(p, V((math.cos(a + 1.3), math.sin(a + 1.3), 0.02)), 0.06, 0.006, "straw_dark", segs=1, bend=0)


@asset(500)
def pine_resin_blob(b):
    # a chunk of pine bark weeping amber
    b.box(V((0, 0, 0.06)), (0.3, 0.14, 0.12), "bark_pine", bevel_noise=0.015)
    for k, p in enumerate([V((-0.05, -0.06, 0.12)), V((0.06, -0.07, 0.08)), V((0.0, -0.075, 0.03))]):
        b.blob(p, (0.025, 0.02, 0.035), 1, "resin", 0.2)


@asset(500)
def ice_moss(b):
    b.rock(V((0, 0, 0)), (0.15, 0.12, 0.08), 1, "rock", snow=None)
    b.blob(V((0, 0, 0.1)), (0.17, 0.14, 0.06), 1, "moss_ice", 0.4, snow=0.85, color2="frost")


@asset(500)
def flint_nodule(b):
    rng = b.rng

    def paint(f):
        return fl.jitter("flint_cortex" if f.normal.z > 0.2 and rng.random() < 0.6 else "flint", rng, 0.08)
    b.rock(V((0, 0, 0)), (0.09, 0.07, 0.06), 1, "flint", noise_amt=0.5, snow=None)
    b.blob(V((0.03, 0.02, 0.07)), (0.05, 0.04, 0.03), 1, "flint_cortex", 0.4)
    b.blob(V((-0.06, 0.0, 0.03)), (0.035, 0.03, 0.03), 0, "flint", 0.1)


@asset(500)
def chalk_lump(b):
    b.rock(V((0, 0, 0)), (0.13, 0.1, 0.08), 1, "chalk", noise_amt=0.3, snow=None)
    b.rock(V((0.13, 0.05, 0)), (0.05, 0.04, 0.04), 0, "chalk", snow=None)


@asset(500)
def red_ochre_rock(b):
    b.rock(V((0, 0, 0)), (0.16, 0.13, 0.1), 1, "ochre", noise_amt=0.4, snow=0.75)
    b.rock(V((0.15, -0.05, 0)), (0.06, 0.05, 0.04), 0, "ochre", snow=None)


@asset(500)
def clay_lump(b):
    b.blob(V((0, 0, 0.04)), (0.18, 0.15, 0.08), 1, "clay", 0.2, flat_bottom=0.5)
    b.blob(V((0.0, 0.0, 0.1)), (0.05, 0.05, 0.02), 0, fl.mix("clay", "soil", 0.5), 0.1)  # thumb dent
    b.blob(V((0.12, 0.08, 0.02)), (0.06, 0.05, 0.03), 0, "clay", 0.2)


@asset(500)
def shed_antler(b):
    beam = [V((0, 0, 0.04)), V((0.12, 0.04, 0.06)), V((0.25, 0.04, 0.05)),
            V((0.38, -0.02, 0.06)), V((0.48, -0.08, 0.08))]
    b.tube(beam, [0.025, 0.022, 0.02, 0.016, 0.008], 5, "antler", "antler_tip", cap=False)
    b.blob(V((0, 0, 0.04)), (0.035, 0.035, 0.03), 0, "antler", 0.2)  # burr
    for i, (dx, dy) in [(1, (0.05, 0.12)), (2, (0.02, 0.14)), (3, (0.06, 0.1))]:
        p = beam[i]
        b.tube([p, p + V((dx, dy, 0.08)), p + V((dx * 1.4, dy * 1.4, 0.04))], [0.013, 0.008, 0.003],
               4, "antler", "antler_tip", cap=False)


def feather(b, length, vane_c, bar_c, bars, width):
    rng = b.rng
    q0 = V((0, 0, 0.004))
    d = V((1, 0.15, 0.02)).normalized()
    b.tube([q0, q0 + d * length], [0.0025, 0.0008], 3, "quill", cap=False)
    for k in range(bars):
        t0 = 0.18 + 0.82 * k / bars
        t1 = 0.18 + 0.82 * (k + 1) / bars
        w = width * math.sin(math.pi * (0.15 + 0.85 * (t0 + t1) / 2)) * (0.6 if k == bars - 1 else 1)
        c = bar_c if (bar_c and k % 2) else vane_c
        p0 = q0 + d * length * t0
        p1 = q0 + d * length * t1
        side = V((-d.y, d.x, 0))
        b.mesh_from([p0, p1, p1 + side * w, p0 + side * w * 0.95,
                     p1 - side * w * 0.7, p0 - side * w * 0.65],
                    [[0, 1, 2, 3], [3, 2, 1, 0], [0, 5, 4, 1], [1, 4, 5, 0]], c)


@asset(300)
def feather_crow(b):
    feather(b, 0.22, "crow", None, 6, 0.028)


@asset(300)
def feather_owl(b):
    feather(b, 0.17, "owl", "owl_bar", 8, 0.04)


@asset(300)
def feather_hawk(b):
    feather(b, 0.2, "hawk", "hawk_bar", 8, 0.032)


@asset(500)
def snail_shells(b):
    rng = b.rng
    for k in range(4):
        a = k * 1.6
        c = V((math.cos(a) * 0.07, math.sin(a) * 0.07, 0.0))
        s = rng.uniform(0.7, 1.2)
        pts, radii = [], []
        for i in range(9):  # coiled tube = banded shell
            t = i / 8
            ang = t * 4.0
            rr = 0.016 * s * (1 - t * 0.7)
            pts.append(c + V((math.cos(ang) * rr, math.sin(ang) * rr, 0.012 * s + t * 0.012 * s)))
            radii.append(0.012 * s * (1 - t * 0.75))
        b.tube(pts, radii, 5, "shell", "shell_band", cap=True)


@asset(500)
def ash_deadfall(b):
    """Cut/fallen limb from the walled grove's ash: pale bark, sawn butt end."""
    pts, _ = b.branch_curve(V((-0.6, 0, 0.06)), V((1, 0.1, 0)), 1.3, 4, 0.1)
    for p in pts:
        p.z = max(p.z, 0.06)
    b.tube(pts, [0.06, 0.05, 0.04, 0.03, 0.02], 6, "bark_ash", "bark_ash_lt", cap=True)
    d0 = (pts[0] - pts[1]).normalized()
    b.blob(pts[0] + d0 * 0.005, (0.01, 0.058, 0.058), 0, "wood_cut", 0.02)  # sawn face
    for i in (1, 2, 3):
        p = pts[i]
        b.tube([p, p + V((0.15, 0.25 * (-1) ** i, 0.1))], [0.02, 0.006], 3, "bark_ash", cap=False)
    for k in range(6):  # a bunch of keys still attached
        b.leaf(pts[3] + V((0, 0, 0.02)), V((b.rng.uniform(-1, 1), b.rng.uniform(-1, 1), -0.3)), 0.1, 0.03, "straw_dark")


@asset(500)
def charcoal_lump(b):
    rng = b.rng
    b.blob(V((0, 0, 0)), (0.25, 0.25, 0.02), 1, fl.mix("charcoal", "bark_grey", 0.5), 0.3)
    for k in range(6):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(0, 0.15)
        b.box(V((math.cos(a) * r, math.sin(a) * r, 0.03)), (rng.uniform(0.05, 0.11), 0.04, 0.035),
              "charcoal", rot_z=rng.uniform(0, 3), bevel_noise=0.008)


@asset(500)
def icicle_cluster(b):
    # a snow-capped stone ledge with icicles hanging off the overhang
    b.rock(V((0, 0, 0)), (0.35, 0.25, 0.22), 1, "rock_dark", snow=0.5)
    b.box(V((0.12, 0.0, 0.42)), (0.5, 0.45, 0.06), "snow")
    rng = b.rng
    for k in range(9):
        x = -0.05 + k * 0.045 + rng.uniform(-0.01, 0.01)
        L = rng.uniform(0.12, 0.35)
        tip = V((0.36, 0.12 - k * 0.03, 0.39))
        p = V((x + 0.12 if False else 0.32 + rng.uniform(-0.03, 0.03), -0.18 + k * 0.045, 0.4))
        b.cone(p, -L, 0.022, 5, "ice", "frost")


# ================================================================ rocks/wood
@asset(800)
def rock_boulder_a(b):
    b.rock(V((0, 0, 0)), (1.0, 0.8, 0.7), 2, "rock", 0.38, snow=0.5)


@asset(800)
def rock_boulder_b(b):
    b.rock(V((0, 0, 0)), (1.6, 1.1, 1.1), 2, "rock_warm", 0.32, snow=0.55, facet=1.6)


@asset(800)
def rock_boulder_c(b):
    b.rock(V((0, 0, 0)), (0.7, 0.6, 1.1), 2, "rock_dark", 0.4, snow=0.55, facet=2.8)
    b.rock(V((0.7, 0.3, 0)), (0.3, 0.3, 0.25), 1, "rock_dark", snow=0.5)


@asset(800)
def rock_flat(b):
    b.rock(V((0, 0, 0)), (1.3, 1.0, 0.22), 2, "rock", 0.25, snow=0.35, flat=0.6, facet=1.5)


@asset(800)
def rock_scree(b):
    rng = b.rng
    for k in range(9):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(0, 0.8)
        s = rng.uniform(0.08, 0.22)
        b.rock(V((math.cos(a) * r, math.sin(a) * r, 0)), (s, s * 0.8, s * 0.6), 1,
               "rock" if k % 2 else "rock_dark", 0.4, snow=0.55)


@asset(800)
def log_fallen(b):
    pts = [V((-2.0, 0, 0.3)), V((-0.7, 0.05, 0.28)), V((0.6, -0.05, 0.26)), V((2.0, 0.05, 0.22))]
    b.tube(pts, [0.32, 0.3, 0.27, 0.24], 9, "bark_wet", "bark_grey", cap=False)
    # broken end (pale splintered) and sawn end rings
    b.cone(V((2.0, 0.05, 0.22)), 0.0001, 0.24, 9, "wood_cut", bottom=False)
    for k in range(4):
        a = k * 1.6
        b.cone(V((2.0, 0.05 + math.cos(a) * 0.12, 0.22 + math.sin(a) * 0.12)), 0.0, 0.05, 3, "wood_dead")
    b.blob(V((-2.0, 0, 0.3)), (0.08, 0.3, 0.3), 1, "wood_dead", 0.25)
    # branch stubs, moss on the side, snow along the top
    for x, a in ((-1.2, 0.8), (0.2, -0.9), (1.2, 0.6)):
        p = V((x, 0, 0.5))
        b.tube([p, p + V((0.2, math.sin(a) * 0.4, 0.3))], [0.06, 0.03], 4, "bark_grey")
    b.blob(V((0, -0.22, 0.25)), (1.4, 0.12, 0.18), 1, "moss_ice", 0.3)
    b.blob(V((0, 0, 0.55)), (1.8, 0.2, 0.06), 1, "snow", 0.2)


@asset(800)
def stump(b):
    b.tube([V((0, 0, 0)), V((0, 0, 0.3)), V((0, 0, 0.55))], [0.42, 0.36, 0.34], 10, "bark_wet", "bark_grey", cap=False)
    b.cone(V((0, 0, 0.55)), 0.04, 0.34, 10, "wood_cut", bottom=False)
    b.blob(V((0, 0, 0.6)), (0.15, 0.15, 0.015), 0, fl.mix("wood_cut", "bark_brown", 0.4), 0.05)  # ring
    fl.flare(b, V((0, 0, 0)), 0.4, 5, "bark_wet", 0.3, 0.45)
    b.blob(V((0.32, 0.1, 0.2)), (0.1, 0.1, 0.06), 1, "tinder", 0.2)


@asset(800)
def stone_wall_section(b):
    """Dry-stone field wall, 3 m long, ~1 m high, snow along the top."""
    rng = b.rng
    L, H = 3.0, 1.0
    rows = 4
    for r in range(rows):
        z = r * H / rows
        x = -L / 2
        while x < L / 2 - 0.1:
            w = rng.uniform(0.35, 0.6)
            w = min(w, L / 2 - x)
            c = fl.jitter(["rock", "rock_warm", "rock_dark"][rng.randrange(3)], rng, 0.1)
            depth = 0.55 - r * 0.06
            b.box(V((x + w / 2, rng.uniform(-0.03, 0.03), z + H / rows / 2)),
                  (w * 0.96, depth, H / rows * 0.9), c[:3], rot_z=rng.uniform(-0.05, 0.05),
                  bevel_noise=0.025)
            x += w
    # coping stones on edge
    x = -L / 2
    while x < L / 2 - 0.05:
        b.box(V((x + 0.09, 0, H + 0.12)), (0.12, 0.42, 0.26), "rock_dark", rot_z=0, bevel_noise=0.02)
        x += 0.18
    b.blob(V((0, 0, H + 0.27)), (L / 2, 0.22, 0.06), 1, "snow", 0.2)


TREES = ["tree_oak_bare", "tree_ash", "tree_birch", "tree_pine", "tree_spruce",
         "tree_dead_snag", "tree_willow_pollard", "tree_waiting_oak"]


def main():
    args = sys.argv[1:]
    out = OUT
    if args and ("/" in args[0] or args[0].startswith(".")):
        out = os.path.abspath(args.pop(0))
    only = set(args)
    os.makedirs(out, exist_ok=True)
    bad = []
    rows = []
    for i, (name, (fn, budget)) in enumerate(sorted(ASSETS.items())):
        if only and name not in only:
            continue
        seed = sum(ord(c) for c in name) * 7 + i
        fl.reset_scene()
        b = fl.Builder(seed)
        fn(b)
        tris = b.tri_count()
        ob = b.to_object(name)
        fl.export(ob, os.path.join(out, name + ".glb"))
        rows.append((name, tris, budget))
        if tris > budget:
            bad.append(name)
        if name in TREES:
            fl.reset_scene()
            fb = fl.Builder(seed + 1)
            far_tree(fb, name)
            ftris = fb.tri_count()
            fob = fb.to_object(name + "_far")
            fl.export(fob, os.path.join(out, name + "_far.glb"))
            rows.append((name + "_far", ftris, 300))
            if ftris > 300:
                bad.append(name + "_far")
    for name, tris, budget in rows:
        print("%-26s %6d / %6d %s" % (name, tris, budget, "OVER" if tris > budget else ""))
    print("assets:", len(rows))
    if bad:
        print("OVER BUDGET:", bad)
        sys.exit(1)


if __name__ == "__main__":
    main()
