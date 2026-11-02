"""Plates, maps and symbolic works: bestiary plates and botanical plates in ink
and wash on parchment (library, stillroom), maps of the court, the Cauldron
(ch13 mural, panel a), and painted interiors (the masquerade, the ballroom)."""

import math
import random

import numpy as np

import motifs as M
from painter import C, mix, shade, jitter

INK = "#3a2a30"


def parchment(r, seed, tone="#efe2c8"):
    r.fill(tone)
    n = r.noise(4.0, seed, 4)
    r.put(shade(tone, -0.12), np.clip((n - 0.55) * 2.5, 0, 1) * 0.5)
    r.rgrad(0.5, 0.5, 0.85, [(0, tone), (0.7, tone), (1, shade(tone, -0.25))], mask=np.clip((np.sqrt((r.u - 0.5) ** 2 + (r.v - 0.5) ** 2) - 0.3) * 2.5, 0, 1))
    m = 0.04
    r.put(INK, r.lines([[(m, m), (1 - m, m), (1 - m, 1 - m), (m, 1 - m), (m, m)]], 2), alpha=0.7)
    r.put(INK, r.lines([[(m * 1.5, m * 1.5), (1 - m * 1.5, m * 1.5), (1 - m * 1.5, 1 - m * 1.5), (m * 1.5, 1 - m * 1.5), (m * 1.5, m * 1.5)]], 1), alpha=0.5)


def script_lines(r, seed, x0, y0, x1, n, gap=0.022):
    """Lines of looping script. Feyre can't read (ch13): it is never legible."""
    rng = random.Random(seed)
    segs = []
    for i in range(n):
        y = y0 + i * gap
        x = x0
        pts = []
        end = x1 - rng.uniform(0, 0.15) * (x1 - x0)
        while x < end:
            pts.append((x, y + rng.uniform(-0.004, 0.004)))
            x += rng.uniform(0.006, 0.012)
            if rng.random() < 0.12:
                segs.append(pts)
                pts = []
                x += 0.015
        if len(pts) > 1:
            segs.append(pts)
    segs = [s for s in segs if len(s) > 1]
    if segs:
        r.put(INK, r.lines(segs, 1, blur=0.3), alpha=0.65)


def plate(r, p):
    """A bestiary plate of the creatures of the Spring Court woods."""
    parchment(r, p["seed"], p.get("tone", "#efe2c8"))
    PLATES[p["creature"]](r, p, random.Random(p["seed"]))
    script_lines(r, p["seed"] + 1, 0.12, 0.86, 0.88, 3)


def _wash(r, mask, col, k=0.55):
    r.put(col, mask * k)
    edge = np.clip(mask - np.roll(mask, 2, axis=1), 0, 1)
    r.put(INK, edge, alpha=0.8)


def _suriel(r, p, rng):
    """Tall, thin, corpse-like; veiled tattered robe; hunched; knobby spine;
    lipless mouth, long teeth, milky swirling eyes (suriel.md). Not cute."""
    robe = r.poly([(0.42, 0.25), (0.6, 0.24), (0.66, 0.5), (0.72, 0.82), (0.6, 0.8), (0.55, 0.84), (0.45, 0.8), (0.32, 0.83), (0.38, 0.5)])
    _wash(r, robe, "#3a3238", 0.85)
    for i in range(8):
        x = rng.uniform(0.34, 0.7)
        r.put("#2a2228", r.poly([(x, 0.78), (x + 0.02, 0.88), (x + 0.03, 0.79)]), alpha=0.8)
    head = r.ellipse(0.5, 0.2, 0.06, 0.07)
    _wash(r, head, "#cfc4b8", 0.9)
    r.put("#2a1e22", r.ellipse(0.5, 0.25, 0.035, 0.012))
    for i in range(7):
        x = 0.475 + i * 0.008
        r.put("#efe8d8", r.lines([[(x, 0.245), (x, 0.262)]], 1))
    for s in (-1, 1):
        r.put("#e8e8f0", r.ellipse(0.5 + s * 0.022, 0.19, 0.014, 0.011))
        r.put("#b8b8c8", r.ellipse(0.5 + s * 0.022, 0.19, 0.006, 0.005), alpha=0.7)
    for s in (-1, 1):
        arm = r.lines([[(0.5 + s * 0.08, 0.32), (0.5 + s * 0.16, 0.5), (0.5 + s * 0.14, 0.62)]], 4)
        _wash(r, arm, "#8a8478", 0.9)
        for f in range(4):
            r.put("#d8c070", r.lines([[(0.5 + s * 0.14, 0.62), (0.5 + s * (0.13 + f * 0.012), 0.67)]], 1))


def _naga(r, p, rng):
    """Humanoid, serpentine; dark scales; amber almond eyes; silvery forked
    tongue; black talons (naga.md)."""
    body = r.poly([(0.42, 0.3), (0.58, 0.3), (0.6, 0.55), (0.56, 0.7), (0.64, 0.82), (0.36, 0.82), (0.44, 0.7), (0.4, 0.55)])
    _wash(r, body, "#2e3a34", 0.85)
    for i in range(60):
        r.put("#4a5a4e", r.ellipse(rng.uniform(0.42, 0.58), rng.uniform(0.32, 0.8), 0.008, 0.005), alpha=0.6)
    head = r.poly([(0.44, 0.14), (0.56, 0.14), (0.6, 0.22), (0.55, 0.3), (0.45, 0.3), (0.4, 0.22)])
    _wash(r, head, "#2e3a34", 0.9)
    for s in (-1, 1):
        r.put("#f0a830", r.ellipse(0.5 + s * 0.03, 0.2, 0.016, 0.008, angle=s * 0.3))
        r.put("#1a1214", r.ellipse(0.5 + s * 0.03, 0.2, 0.003, 0.007))
    r.put("#d8dce8", r.lines([[(0.5, 0.28), (0.5, 0.32), (0.49, 0.34)], [(0.5, 0.32), (0.51, 0.34)]], 1))
    for s in (-1, 1):
        arm = r.lines([[(0.5 + s * 0.09, 0.34), (0.5 + s * 0.2, 0.46), (0.5 + s * 0.22, 0.58)]], 5)
        _wash(r, arm, "#2e3a34", 0.9)
        for f in range(4):
            r.put("#0e0a0c", r.lines([[(0.5 + s * 0.22, 0.58), (0.5 + s * (0.2 + f * 0.012), 0.63)]], 2))


def _bogge(r, p, rng):
    """No description; it becomes real if you acknowledge it (bogge.md). The
    plate shows only a darkness that never resolves, and the empty space
    the scribe left beside it."""
    n = r.noise(5.0, p["seed"], 4)
    d = np.sqrt((r.u - 0.5) ** 2 / 0.06 + (r.v - 0.48) ** 2 / 0.09)
    m = np.clip((1.0 - d) * 1.6 + (n - 0.5) * 1.2, 0, 1)
    r.put("#14100e", m * 0.92)
    for i in range(40):
        a = rng.uniform(0, 6.28)
        rr = rng.uniform(0.18, 0.3)
        r.put("#14100e", r.lines([[(0.5 + math.cos(a) * 0.12, 0.48 + math.sin(a) * 0.15), (0.5 + math.cos(a) * rr, 0.48 + math.sin(a) * rr * 1.2)]], 1), alpha=0.5)
    for s in (-1, 1):
        r.put("#3a3028", r.circle(0.5 + s * 0.035, 0.4, 0.006), alpha=0.6)


def _puca(r, p, rng):
    """No true form is described [X]: it wears what you long for. The plate
    shows a beckoning figure whose shadow is something else."""
    fig = r.poly([(0.46, 0.25), (0.54, 0.25), (0.58, 0.72), (0.42, 0.72)])
    _wash(r, fig, "#8a7a68", 0.6)
    _wash(r, r.circle(0.5, 0.2, 0.05), "#c8b8a0", 0.6)
    r.put(INK, r.lines([[(0.55, 0.35), (0.66, 0.3), (0.7, 0.27)]], 2))
    sh = r.poly([(0.5, 0.72), (0.75, 0.74), (0.88, 0.8), (0.86, 0.84), (0.6, 0.8)])
    r.put("#1a1214", sh, alpha=0.7)
    for i in range(5):
        x = 0.7 + i * 0.03
        r.put("#1a1214", r.poly([(x, 0.76), (x + 0.012, 0.7), (x + 0.02, 0.77)]), alpha=0.7)


def _faerie(r, p, rng):
    """A lesser faerie of the garden, wings spread (plate of the court's small folk)."""
    col = p.get("wing", "#c8d8f8")
    for s in (-1, 1):
        _wash(r, r.ellipse(0.5 + s * 0.16, 0.38, 0.15, 0.2, angle=s * 0.5), col, 0.45)
        _wash(r, r.ellipse(0.5 + s * 0.12, 0.6, 0.09, 0.12, angle=-s * 0.5), col, 0.45)
    _wash(r, r.ellipse(0.5, 0.5, 0.03, 0.16), p.get("body", "#a8c8a0"), 0.8)
    _wash(r, r.circle(0.5, 0.31, 0.05), p.get("body", "#a8c8a0"), 0.8)
    for s in (-1, 1):
        r.put(INK, r.lines([[(0.5 + s * 0.02, 0.27), (0.5 + s * 0.06, 0.17)]], 1))


def _lamb_plate(r, p, rng):
    M.lamb(r, 0.5, 0.75, 0.42)


def _stag_plate(r, p, rng):
    M.deer(r, 0.45, 0.82, 0.38, stag=True)


def _fox_plate(r, p, rng):
    M.fox(r, 0.48, 0.75, 0.42)


def _hare_plate(r, p, rng):
    M.hare(r, 0.5, 0.75, 0.38)


def _swan_plate(r, p, rng):
    M.swan(r, 0.5, 0.78, 0.4)


def _butterflies(r, p, rng):
    for i in range(9):
        M.butterfly(r, 0.2 + (i % 3) * 0.3, 0.2 + (i // 3) * 0.24, 0.05, rng.choice(["#c8b6f2", "#f6a6c6", "#fff1a8", "#a8d8f0", "#ffb890", "#b5e3c0"]))


PLATES = {"suriel": _suriel, "naga": _naga, "bogge": _bogge, "puca": _puca, "faerie": _faerie, "lamb": _lamb_plate,
          "stag": _stag_plate, "fox": _fox_plate, "hare": _hare_plate, "swan": _swan_plate, "butterflies": _butterflies}


HABITS = {
    "rose_red": "shrub", "rose_white": "shrub", "wild_hyacinth": "bulb", "foxglove": "rosette", "lavender": "branching",
    "honeysuckle": "climber", "elderflower": "shrub", "wild_strawberry": "creeper", "moonflower": "climber",
    "faelight_dandelion": "rosette", "woad": "branching", "madder": "creeper", "snowdrop": "bulb", "wisteria": "climber",
    "lilac": "shrub", "crab_apple": "shrub", "buttercup": "branching", "iris": "bulb", "crocus": "bulb", "daffodil": "bulb",
    "peony": "branching", "tulip": "bulb", "morning_glory": "climber", "goldenrod": "branching", "maidens_lace": "branching",
    "blackberry": "creeper",
}


def botanical(r, p):
    """One plant in its own habit (a bulb with blade leaves, a climber on its
    cane, a rosette with a tall spike, a woody shrub, a creeper with runners),
    ink and wash, often with an enlarged bloom in a ringed inset, for the
    stillroom and the pressed-flower study. Plants are the game's forage."""
    rng = random.Random(p["seed"])
    parchment(r, p["seed"], p.get("tone", "#f2e8d4"))
    habit = p.get("habit", HABITS.get(p["id"].replace("botanical_", ""), "upright"))
    kind, cols = p.get("bloom", ("rose", ["#f39cb8"]))
    leaf_c = p.get("leaf", rng.choice(["#7cc29a", "#6fae86", "#8ccaa0", "#5f9e80"]))
    stem_c = p.get("stem", "#5f8a6a")
    lw = max(2, r.w // 160)
    ground = 0.8
    blooms = []

    def stem_path(x0, y0, x1, y1, bend, n=10):
        pts = []
        for i in range(n + 1):
            t = i / n
            pts.append((x0 + (x1 - x0) * t + bend * math.sin(t * math.pi), y0 + (y1 - y0) * t))
        return pts

    if habit == "bulb":
        r.shaded(r.ellipse(0.5, ground + 0.02, 0.05, 0.045), "#e8d8c0", (-0.5, -0.6), 0.3)
        for i in range(5):
            a = -math.pi / 2 + (i - 2) * 0.22 + rng.uniform(-0.05, 0.05)
            M.leaf(r, 0.5, ground - 0.01, a, rng.uniform(0.32, 0.45), jitter(leaf_c, rng, 0.03), 0.07)
        st = stem_path(0.5, ground, 0.52, 0.28, 0.02)
        r.put(stem_c, r.lines([st], lw))
        blooms.append((st[-1], 1.0))
    elif habit == "climber":
        r.put("#b8a088", r.lines([[(0.3, 0.84), (0.33, 0.12)]], max(2, r.w // 120)))  # the cane it climbs
        st = []
        for i in range(30):
            t = i / 29
            st.append((0.33 + 0.12 * math.sin(t * 9 + 0.5) * (1 - t * 0.3), 0.82 - t * 0.66))
        r.put(stem_c, r.lines([st], lw))
        for i in range(2, 29, 3):
            x, y = st[i]
            M.leaf(r, x, y, rng.choice([0.3, 2.8]) + rng.uniform(-0.3, 0.3), 0.07, jitter(leaf_c, rng, 0.03), 0.55)
        for i in (8, 15, 21, 27):
            blooms.append((st[i], 0.7))
    elif habit == "rosette":
        for i in range(9):
            a = math.pi + i * math.pi / 8 + rng.uniform(-0.1, 0.1)
            M.leaf(r, 0.5, ground, a, rng.uniform(0.14, 0.2), jitter(leaf_c, rng, 0.03), 0.38)
        st = stem_path(0.5, ground, 0.5, 0.22, rng.uniform(-0.03, 0.03))
        r.put(stem_c, r.lines([st], lw))
        for i in range(3, 9):
            blooms.append((st[i], 0.55))
        blooms.append((st[-1], 0.8))
    elif habit == "shrub":
        trunk = stem_path(0.5, ground, 0.48, 0.5, 0.02, 6)
        r.put("#8e6a6e", r.lines([trunk], lw + 2))
        for k in range(4):
            x0, y0 = trunk[rng.randint(2, 5)]
            x1, y1 = 0.5 + rng.uniform(-0.28, 0.28), rng.uniform(0.2, 0.42)
            br = stem_path(x0, y0, x1, y1, rng.uniform(-0.04, 0.04), 6)
            r.put("#8e6a6e", r.lines([br], lw))
            for (x, y) in br[2:]:
                M.leaf(r, x, y, rng.uniform(0, 6.28), 0.05, jitter(leaf_c, rng, 0.04), 0.5)
            blooms.append((br[-1], 0.75))
    elif habit == "creeper":
        for k in range(3):
            run = stem_path(0.5, ground - 0.04, 0.5 + (k - 1) * 0.3, ground - rng.uniform(0.0, 0.12), 0.05, 8)
            r.put(stem_c, r.lines([run], lw))
            for (x, y) in run[2::2]:
                for d in (-0.6, 0.0, 0.6):
                    M.leaf(r, x, y, -math.pi / 2 + d, 0.06, jitter(leaf_c, rng, 0.03), 0.6)
        st = stem_path(0.5, ground - 0.04, 0.47, 0.45, 0.03, 6)
        r.put(stem_c, r.lines([st], lw))
        blooms += [(st[-1], 0.8), (st[3], 0.6)]
    else:  # branching / upright
        st = stem_path(0.5, ground, 0.5, 0.25, rng.uniform(-0.03, 0.03))
        r.put(stem_c, r.lines([st], lw))
        for i in range(2, 9):
            sx, sy = st[i]
            side = 1 if i % 2 else -1
            M.leaf(r, sx, sy, -math.pi / 2 + side * rng.uniform(0.7, 1.1), rng.uniform(0.08, 0.13), jitter(leaf_c, rng, 0.03), 0.3)
        blooms.append((st[-1], 1.0))
        if habit == "branching":
            for i in (4, 6):
                x0, y0 = st[i]
                x1 = x0 + (0.16 if i == 4 else -0.15)
                br = stem_path(x0, y0, x1, y0 - 0.2, 0.0, 5)
                r.put(stem_c, r.lines([br], max(1, lw - 1)))
                blooms.append((br[-1], 0.75))
    if habit not in ("bulb", "climber"):
        roots = []
        for i in range(7):
            a = math.pi / 2 + rng.uniform(-0.9, 0.9)
            roots.append([(0.5, ground), (0.5 + math.cos(a) * 0.05, ground + math.sin(a) * 0.03), (0.5 + math.cos(a) * 0.1, ground + math.sin(a) * 0.08)])
        r.put("#8a6a5a", r.lines(roots, 1))
    rad = p.get("bloom_r", 0.06)
    for (x, y), k in blooms:
        M.flower_head(r, x, y, rad * k, kind, cols[0] if k >= 0.75 else cols[min(1, len(cols) - 1)], rng)
    if p.get("berries"):
        for (x, y), k in blooms[:3]:
            for i in range(5):
                r.shaded(r.circle(x + rng.uniform(-0.04, 0.04), y + 0.05 + rng.uniform(-0.03, 0.03), 0.013), p["berries"], k=0.35)
    if rng.random() < 0.6:
        # the inset: one bloom enlarged in a ringed circle, top corner
        ix = rng.choice([0.24, 0.76])
        iy = 0.2
        r.put(shade(p.get("tone", "#f2e8d4"), 0.15), r.circle(ix, iy, 0.1))
        r.put(INK, r.lines([[(ix + 0.1 * r.h / r.w * math.cos(a), iy + 0.1 * math.sin(a)) for a in np.linspace(0, 6.3, 40)]], 1), alpha=0.7)
        M.flower_head(r, ix, iy, 0.07, kind, cols[0], rng)
        r.mark_detail(r.circle(ix, iy, 0.1), 0.5)
    script_lines(r, p["seed"] + 2, 0.15, 0.87, 0.85, 2)


def court_map(r, p):
    """A painted map of the Spring Court: woods, the manor, the Wall to the
    south (a dark smear, ch13) and Spring's crocuses, lambs and roses."""
    rng = random.Random(p["seed"])
    parchment(r, p["seed"], "#f2e6cc")
    land = r.blob(0.5, 0.45, 0.36, 0.22, p["seed"], squash=0.85, n=72)
    r.put("#cfe6c4", land * 0.8)
    r.put("#b8d0e8", (1 - land) * 0.35)
    for i in range(80):
        x, y = rng.uniform(0.2, 0.8), rng.uniform(0.2, 0.7)
        if land[int(y * r.h), int(x * r.w)] > 0.5 and rng.random() < 0.6:
            M.tree(r, x, y, 0.035, "round", "spring", "noon", rng.randrange(1 << 20))
    r.put("#2a2028", r.lines([[(0.1, 0.8), (0.3, 0.78), (0.5, 0.81), (0.7, 0.79), (0.9, 0.8)]], 6, blur=2.5), alpha=0.75)
    M.manor(r, 0.5, 0.5, 0.12, "noon", p["seed"], roses=False)
    for i, (x, y) in enumerate([(0.25, 0.3), (0.75, 0.3), (0.3, 0.65), (0.7, 0.62)]):
        if i % 3 == 0:
            M.lamb(r, x, y, 0.05)
        else:
            M.flower_head(r, x, y, 0.025, "rose" if i % 2 else "tulip", "#e8708f" if i % 2 else "#b8a0f0", rng)
    r.put(INK, r.lines([[(0.86, 0.12), (0.86, 0.22)], [(0.82, 0.17), (0.9, 0.17)]], 2))
    script_lines(r, p["seed"] + 3, 0.1, 0.88, 0.5, 2)


def cauldron(r, p):
    """The making of the world (ch13 mural, panel a): a black cauldron tipped by
    glowing, slender female hands in a starry, endless night, spilling golden
    liquid effervescent with small symbols. The gold falls into darkness where
    a dim land is just forming."""
    rng = random.Random(p["seed"])
    r.vgrad([(0, "#0b0f2a"), (0.55, "#1c2050"), (1, "#0e1028")])
    neb = r.noise(2.5, p["seed"] + 3, 4)
    r.put("#5a3a7a", np.clip((neb - 0.5) * 2.2, 0, 1) * 0.45)
    r.put("#2f5a7a", np.clip((r.noise(3.0, p["seed"] + 4, 3) - 0.55) * 2.5, 0, 1) * 0.35)
    M.stars(r, p["seed"], 320, 1.0, 0.1)
    # the land forming far below
    r.put("#1a1830", r.below(lambda u: 0.9 - 0.05 * math.sin(u * 5.0 + 1.0)), alpha=1.0)
    cx, cy, tilt = 0.4, 0.33, 0.42
    ca, sa = math.cos(tilt), math.sin(tilt)

    def rot(x, y):
        return cx + (x * ca - y * sa) * r.h / r.w, cy + (x * sa + y * ca)
    body = r.poly([rot(0.19 * math.cos(t), 0.04 + 0.17 * math.sin(t)) for t in np.linspace(0, math.pi, 40)] +
                  [rot(-0.2, -0.02), rot(0.2, -0.02)], blur=1.0)
    r.shaded(body, "#16121c", (-0.4, -0.7), 0.3, rim=0.25)
    rim = r.ellipse(*rot(0, -0.02), 0.2 * r.h / r.w, 0.045, blur=1.0, angle=tilt)
    r.put("#2a2434", rim)
    inner = r.ellipse(*rot(0, -0.02), 0.17 * r.h / r.w, 0.032, blur=1.0, angle=tilt)
    r.put("#f2b83a", inner, alpha=0.9)
    r.put("#fff0a0", r.ellipse(*rot(0.03, -0.025), 0.08 * r.h / r.w, 0.015, blur=2.0, angle=tilt), alpha=0.7)
    lip = rot(0.2, -0.01)
    # two hands from above, gripping the rim; they glow
    for s, (hx, hy) in ((-1, rot(-0.17, -0.05)), (1, rot(0.12, -0.07))):
        top = (hx + s * 0.08, -0.05)
        arm = r.poly([(top[0] - 0.025, top[1]), (top[0] + 0.025, top[1]), (hx + 0.012, hy - 0.04), (hx - 0.012, hy - 0.04)], blur=1.2)
        glow = np.clip(1 - np.sqrt(((r.u - hx) * r.w / r.h) ** 2 + (r.v - hy + 0.06) ** 2) / 0.22, 0, 1) ** 2
        r.put("#d8c8ff", glow * 0.45)
        r.put("#f8f0ff", arm * 0.95)
        palm = r.ellipse(hx, hy - 0.035, 0.022 * r.h / r.w, 0.03, blur=1.0)
        r.put("#fbf4ff", palm)
        for f in range(4):
            fx = hx + (f - 1.5) * 0.009 * r.h / r.w
            r.put("#f6eeff", r.lines([[(fx, hy - 0.02), (fx + s * 0.004, hy + 0.012 + 0.006 * (f % 2))]], max(2, r.w // 160), blur=0.6))
        r.mark_detail(np.maximum(arm, palm), 0.5)
    # the pour
    lx, ly = lip
    left, right = [], []
    for i in range(14):
        t = i / 13
        x = lx + 0.03 + t * 0.2 + 0.02 * math.sin(t * 5)
        y = ly + t * (0.92 - ly)
        wdt = 0.012 + t * 0.06
        left.append((x - wdt, y))
        right.append((x + wdt, y))
    stream = r.poly(left + right[::-1], blur=3.0)
    r.put("#e8a83a", stream, alpha=0.85)
    core = r.poly([(x + (rx - x) * 0.35, y) for (x, y), (rx, _) in zip(left, right)] + [(x - (x - lx2) * 0.35, y) for (x, y), (lx2, _) in list(zip(right, left))[::-1]], blur=2.0)
    r.put("#fff2b0", core, alpha=0.8)
    pool = r.ellipse(lx + 0.25, 0.92, 0.2 * r.h / r.w, 0.035, blur=4.0)
    r.put("#f6c84a", pool, alpha=0.7)
    # effervescent symbols: tiny rings, crosses, spirals and sparks
    for i in range(110):
        t = rng.random() ** 0.8
        x = lx + 0.03 + t * 0.2 + rng.uniform(-0.12, 0.12) * (0.3 + t)
        y = ly + t * (0.92 - ly) + rng.uniform(-0.03, 0.03)
        k = rng.random()
        sz = rng.uniform(0.006, 0.013)
        col = rng.choice(["#fff6c8", "#ffe08a", "#fbe8ff"])
        if k < 0.3:
            r.put(col, r.circle(x, y, sz * 0.5, blur=0.4), alpha=0.9)
        elif k < 0.55:
            r.put(col, r.lines([[(x - sz, y), (x + sz, y)], [(x, y - sz), (x, y + sz)]], 1, blur=0.3))
        elif k < 0.8:
            pts = [(x + sz * a / 6 * math.cos(a), y + sz * a / 6 * math.sin(a)) for a in np.linspace(0, 6, 12)]
            r.put(col, r.lines([pts], 1, blur=0.3))
        else:
            r.put(col, r.lines([[(x - sz, y + sz), (x, y - sz), (x + sz, y + sz)]], 1, blur=0.3))
    r.mark_detail(np.clip(body + rim, 0, 1), 0.3)


def interior(r, p):
    """A painted room: the masquerade (before the curse, masks were for a
    night, ch32) or a ballroom of dancers under chandeliers."""
    rng = random.Random(p["seed"])
    wall = p.get("wall", "#f2d8e0")
    r.vgrad([(0, shade(wall, -0.2)), (0.6, wall), (1, shade(wall, -0.1))])
    for i in range(5):
        x = 0.1 + i * 0.2
        r.shaded(r.poly([(x - 0.025, 0.12), (x + 0.025, 0.12), (x + 0.025, 0.7), (x - 0.025, 0.7)]), "#f6efe6", (-0.6, -0.3), 0.2)
        r.put("#e6c068", r.poly([(x - 0.035, 0.1), (x + 0.035, 0.1), (x + 0.035, 0.13), (x - 0.035, 0.13)]))
    r.put(p.get("floor", "#e8dce8"), r.poly([(0, 0.7), (1, 0.7), (1, 1), (0, 1)]))
    for i in range(12):
        r.put("#f6efe6", r.lines([[(0.5, 0.7), (i / 11 * 1.6 - 0.3, 1.0)]], 1), alpha=0.4)
    for i, x in enumerate((0.25, 0.5, 0.75)):
        r.put("#ffe8b0", np.clip(1 - np.sqrt(((r.u - x) * r.w / r.h) ** 2 + (r.v - 0.12) ** 2) / 0.14, 0, 1) ** 2 * 0.6)
        r.put("#e6c068", r.ellipse(x, 0.12, 0.05, 0.02))
        for k in range(8):
            r.put("#fff6d8", r.circle(x + (k - 3.5) * 0.012, 0.14 + (k % 2) * 0.01, 0.004))
    n = p.get("dancers", 12)
    for i in range(n):
        x = rng.uniform(0.06, 0.94)
        y = rng.uniform(0.78, 0.98)
        h = 0.22 + (y - 0.78) * 0.9
        col = rng.choice(p.get("gowns", ["#f6a6c6", "#c8b6f2", "#a8d8f0", "#fff1a8", "#b5e3c0", "#e6c068"]))
        mask = rng.choice(["#e6c068", "#7cc29a", "#f6f2fa", "#c8784a"]) if p.get("masked", True) else None
        M.figure(r, x, y, h, col, gown=rng.random() < 0.6, mask=mask, skin=rng.choice(["#f6d6cc", "#f0c8a0", "#c08a68", "#8e5e48"]),
                 hair=rng.choice(["#e8c070", "#2a2030", "#b8583a", "#e4e2ee", "#7a4a34"]))
    if p.get("petals"):
        M.petals(r, p["seed"] + 4, 50)


def allegory_backdrop(r, p):
    """Backdrops for season allegories and figure scenes (sitters paint over)."""
    from scenes_land import landscape
    landscape(r, p)
