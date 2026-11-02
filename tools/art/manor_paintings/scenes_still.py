"""Still lifes: a vase of flowers, fruit, the house's tableware and keepsakes
on a ledge or a draped table. The ch7 hall painting (a green glass vase of
roses, tulips, morning glory, goldenrod, maiden's lace and peonies against a
dark ground) is the canon anchor; the rest vary vessel, flowers, objects,
ground and light."""

import math
import random

import numpy as np

import motifs as M
from painter import C, mix, shade, jitter

LIGHT = (-0.65, -0.55)

FLOWERS = {
    "rose": ("rose", ["#f39cb8", "#e8708f", "#fde2ea", "#f7c6d6", "#d0485e"]),
    "tulip": ("tulip", ["#f26f86", "#ffd36a", "#f7a3c0", "#e85a4a"]),
    "morning_glory": ("morning_glory", ["#8fa0f0", "#b8a8f2", "#7a8ae0"]),
    "goldenrod": ("plume", ["#f6c84a", "#ffd760"]),
    "maiden_lace": ("maiden_lace", ["#fbf7f0", "#f4efe6"]),
    "peony": ("peony", ["#f7a8c0", "#fbd0dc", "#e8809a"]),
    "iris": ("iris", ["#9a7ae0", "#b8a8f2", "#7a62c8"]),
    "daffodil": ("daisy", ["#ffe070", "#fff1a8"]),
    "snowdrop": ("tulip", ["#fbfbff", "#eef0fa"]),
    "crocus": ("tulip", ["#b8a0f0", "#d8c8ff", "#fff1a8"]),
    "lilac": ("plume", ["#c8a8e8", "#d8c0f0", "#b090d8"]),
    "wisteria": ("plume", ["#b8a8f2", "#c8b6f2", "#a898e0"]),
    "foxglove": ("plume", ["#e888b8", "#f0a8c8"]),
    "anemone": ("anemone", ["#e8506a", "#fbfbff", "#8a70d8"]),
    "camellia": ("rose", ["#e8506a", "#fbfbff"]),
    "lily": ("daisy", ["#fff6ee", "#ffd8e0"]),
    "sweet_pea": ("tulip", ["#f7a8c8", "#d8b8f0", "#fbe0e8"]),
    "hellebore": ("anemone", ["#d8a8c0", "#e8e0f0", "#a87898"]),
    "ranunculus": ("peony", ["#ffb890", "#f7a8c0", "#ffe0a0"]),
    "poppy": ("anemone", ["#ff6a5a", "#ff8a6a"]),
    "bluebell": ("plume", ["#8aa0f0", "#a8b8f8"]),
}

VESSELS = {
    "green_glass": ("#6fb89a", 0.55, "vase"),
    "crystal": ("#e8f0fa", 0.35, "vase"),
    "porcelain": ("#f6f2fa", 1.0, "urn"),
    "gilt_urn": ("#e6c068", 1.0, "urn"),
    "rose_ewer": ("#f3a8c0", 1.0, "ewer"),
    "blue_jug": ("#8aa8e0", 1.0, "jug"),
    "stone_crock": ("#b8a898", 1.0, "jug"),
    "silver_bowl": ("#d8dce8", 1.0, "bowl"),
    "basket": ("#c8a070", 1.0, "basket"),
    "copper_pot": ("#e8956a", 1.0, "jug"),
}

GROUNDS = {
    "dark": [(0, "#2a1e2a"), (0.6, "#3a2836"), (1, "#24181e")],
    "umber": [(0, "#3e2c28"), (1, "#2a1e1c")],
    "plum": [(0, "#3a2440"), (1, "#24162a")],
    "pearl": [(0, "#f2ece6"), (1, "#e4dce0")],
    "blush": [(0, "#f6dce4"), (1, "#e8c8d4")],
    "mint": [(0, "#d8eee2"), (1, "#c0dccc")],
    "lilac": [(0, "#e4dcf4"), (1, "#cfc4e8")],
    "window": None,
}

TABLES = {"marble": "#efe6e8", "oak": "#9a7468", "rose_cloth": "#f3b8c8", "white_cloth": "#f4f0ee",
          "lilac_cloth": "#c8b8e8", "mint_cloth": "#b8e0c8", "ledge": "#c8b8a8", "gilt": "#d8b060"}


def still_life(r, p):
    rng = random.Random(p["seed"])
    ground = p.get("ground", "dark")
    if ground == "window":
        r.vgrad([(0, "#c8d8f0"), (1, "#f2e8e8")])
        r.put("#f6efe6", r.poly([(0, 0), (0.12, 0), (0.12, 0.7), (0, 0.7)]))
        r.put("#f6efe6", r.poly([(0.88, 0), (1, 0), (1, 0.7), (0.88, 0.7)]))
        r.put("#f6efe6", r.poly([(0.12, 0.33), (0.88, 0.33), (0.88, 0.35), (0.12, 0.35)]))
        M.hills(r, p["seed"], 0.62, 0.06, ["#b5e3c0", "#9fd6a2"], "noon", 0.4)
        M.grove(r, p["seed"] + 1, 6, 0.6, 0.66, 0.08, 0.12, ["blossom"], "spring", "noon", 0.14, 0.86)
    else:
        r.rgrad(0.35, 0.3, 1.0, GROUNDS[ground])
    if ground in ("dark", "umber", "plum"):
        r.rgrad(0.4, 0.4, 0.55, [(0, mix(GROUNDS[ground][0][1], "#7a5a60", 0.35)), (1, GROUNDS[ground][0][1])],
                mask=np.clip(1 - np.sqrt((r.u - 0.4) ** 2 + (r.v - 0.4) ** 2) / 0.55, 0, 1))
    ty = p.get("table_y", 0.74)
    tcol = TABLES[p.get("table", "marble")]
    r.shaded(r.poly([(0, ty), (1, ty), (1, 1), (0, 1)]), tcol, (-0.3, -1.0), 0.18)
    r.put(shade(tcol, -0.25), r.poly([(0, ty + 0.06), (1, ty + 0.06), (1, ty + 0.075), (0, ty + 0.075)]))
    if "cloth" in p.get("table", ""):
        for i in range(6):
            x = rng.uniform(0.05, 0.95)
            r.put(shade(tcol, -0.12), r.lines([[(x, ty + 0.08), (x + rng.uniform(-0.03, 0.03), 1.0)]], 3, blur=2.0), alpha=0.6)
    vx = p.get("vase_x", 0.5)
    vessel = p.get("vessel", "green_glass")
    vtop = _vessel(r, vx, ty + 0.03, p.get("vase_h", 0.26), vessel, rng)
    if p.get("flowers"):
        _bouquet(r, vx, vtop, p.get("bouquet_r", 0.24), p["flowers"], rng, p.get("blooms", 26), p.get("droop", True))
    for obj in p.get("objects", []):
        OBJECTS[obj[0]](r, obj[1], ty + 0.04 + obj[2] if len(obj) > 2 else ty + 0.04, rng)
    if p.get("fallen", True) and p.get("flowers"):
        for i in range(5):
            name = rng.choice(p["flowers"])
            col = rng.choice(FLOWERS[name][1])
            x = rng.uniform(0.15, 0.85)
            r.put(col, r.ellipse(x, ty + rng.uniform(0.05, 0.1), 0.014, 0.006, angle=rng.uniform(0, 3)))
    if p.get("butterfly"):
        M.butterfly(r, *p["butterfly"])


def _vessel(r, x, base, h, vessel, rng):
    col, alpha, kind = VESSELS[vessel]
    w = h * r.h / r.w
    if kind == "vase":
        prof = [(0.22, 0), (0.34, 0.15), (0.38, 0.45), (0.25, 0.75), (0.18, 0.88), (0.24, 1.0)]
    elif kind == "urn":
        prof = [(0.25, 0), (0.2, 0.08), (0.42, 0.35), (0.4, 0.6), (0.24, 0.82), (0.32, 1.0)]
    elif kind == "ewer":
        prof = [(0.24, 0), (0.36, 0.3), (0.3, 0.62), (0.16, 0.85), (0.22, 1.0)]
    elif kind == "jug":
        prof = [(0.3, 0), (0.38, 0.4), (0.34, 0.75), (0.28, 1.0)]
    elif kind == "bowl":
        prof = [(0.2, 0), (0.5, 0.25), (0.62, 0.55), (0.62, 0.6)]
        h *= 0.5
    else:  # basket
        prof = [(0.45, 0), (0.6, 0.6), (0.62, 0.65)]
        h *= 0.55
    left = [(x - pw * w, base - py * h) for pw, py in prof]
    right = [(x + pw * w, base - py * h) for pw, py in prof][::-1]
    m = r.poly(left + right, blur=0.8)
    if alpha < 1.0:
        behind = r.rgb.copy()
        r.shaded(m, col, LIGHT, 0.3)
        r.rgb = r.rgb * alpha + behind * (1 - alpha) * (m[..., None]) + r.rgb * (1 - alpha) * (1 - m[..., None])
        r.put("#ffffff", r.ellipse(x - w * 0.2, base - h * 0.45, w * 0.04, h * 0.2), alpha=0.55)
        r.put(shade(col, -0.2), r.ellipse(x, base - h * 0.3, w * 0.25, h * 0.12), alpha=0.25)  # water line
    else:
        r.shaded(m, col, LIGHT, 0.32, rim=0.25)
        r.put("#ffffff", r.ellipse(x - w * 0.22, base - h * 0.5, w * 0.035, h * 0.16), alpha=0.5)
        if vessel in ("porcelain", "rose_ewer", "blue_jug"):
            for i in range(5):
                a = rng.uniform(-0.25, 0.25)
                M.flower_head(r, x + a * w, base - h * rng.uniform(0.3, 0.7), h * 0.05, "rose",
                              rng.choice(["#e8708f", "#7a90d8", "#7cc29a"]), rng)
        if kind == "urn":
            r.put("#e6c068", r.poly([(x - w * 0.42, base - h * 0.36), (x + w * 0.42, base - h * 0.36), (x + w * 0.42, base - h * 0.39), (x - w * 0.42, base - h * 0.39)]))
        if kind == "basket":
            for i in range(8):
                yy = base - h * i / 8
                r.put(shade(col, -0.2), r.lines([[(x - w * 0.6, yy), (x + w * 0.6, yy)]], 1), alpha=0.5)
    r.mark_detail(m, 0.25)
    return base - h * prof[-1][1]


def _bouquet(r, cx, top, rad, names, rng, n, droop):
    stems = []
    heads = []
    for i in range(n):
        a = rng.uniform(math.pi * 1.05, math.pi * 1.95)
        d = rad * math.sqrt(rng.random()) * 1.0
        hx = cx + math.cos(a) * d * r.h / r.w * 1.15
        hy = top + math.sin(a) * d * 0.95 - rad * 0.1
        if droop and rng.random() < 0.25:
            hx = cx + (rng.choice([-1, 1]) * rad * rng.uniform(0.8, 1.1)) * r.h / r.w
            hy = top + rng.uniform(-0.02, 0.06)
        name = names[i % len(names)]
        stems.append([(cx + rng.uniform(-0.01, 0.01), top + 0.02), ((cx + hx) / 2, (top + hy) / 2 - 0.02), (hx, hy)])
        heads.append((hy, hx, name))
    r.put("#4f9a82", r.lines(stems, max(1, r.w // 240)))
    for i in range(n // 2):
        x = cx + rng.uniform(-1, 1) * rad * r.h / r.w
        y = top - rng.uniform(0, rad * 0.9)
        M.leaf(r, x, y, rng.uniform(0, 6.28), rad * rng.uniform(0.25, 0.4), jitter("#5fae7c", rng, 0.05))
    for hy, hx, name in sorted(heads, key=lambda t: -abs(t[1] - cx)):
        kind, cols = FLOWERS[name]
        size = rad * (0.13 if kind != "plume" else 0.2) * rng.uniform(0.85, 1.2)
        M.flower_head(r, hx, hy, size, kind, jitter(rng.choice(cols), rng, 0.03), rng, LIGHT)


# ------------------------------------------------------------------ objects on the table

def _fruit(col, rad=0.045, k=1.0):
    def f(r, x, y, rng):
        m = r.circle(x, y - rad * k, rad * k)
        r.shaded(m, col, LIGHT, 0.35, rim=0.2)
        r.put("#ffffff", r.circle(x - rad * 0.35 * k * r.h / r.w, y - rad * 1.35 * k, rad * 0.18 * k), alpha=0.5)
        r.mark_detail(m, 0.3)
    return f


def _grapes(col):
    def f(r, x, y, rng):
        for i in range(14):
            gx = x + rng.uniform(-0.05, 0.05) * r.h / r.w
            gy = y - 0.02 - rng.uniform(0, 0.08)
            r.shaded(r.circle(gx, gy, 0.016), jitter(col, rng, 0.03), LIGHT, 0.35)
        r.put("#5fae7c", r.ellipse(x, y - 0.11, 0.03, 0.015, angle=0.3))
    return f


def _torte(r, x, y, rng):
    w = 0.09 * r.h / r.w
    r.shaded(r.poly([(x - w, y), (x + w, y), (x + w * 0.9, y - 0.07), (x - w * 0.9, y - 0.07)]), "#5a3430", LIGHT, 0.2)
    r.put("#f6e8e0", r.ellipse(x, y + 0.004, w * 1.25, 0.012))
    r.put("#f39cb8", r.circle(x, y - 0.08, 0.014))


def _tart(r, x, y, rng):
    w = 0.07 * r.h / r.w
    r.shaded(r.ellipse(x, y - 0.015, w, 0.022), "#e8c080", LIGHT, 0.25)
    r.put("#fff07a", r.ellipse(x, y - 0.02, w * 0.8, 0.014))


def _goblet(col):
    def f(r, x, y, rng):
        w = 0.035 * r.h / r.w
        r.put("#e6c068", r.poly([(x - w * 0.7, y), (x + w * 0.7, y), (x + w * 0.1, y - 0.03), (x + w * 0.1, y - 0.07), (x - w * 0.1, y - 0.07), (x - w * 0.1, y - 0.03)]))
        r.shaded(r.poly([(x - w, y - 0.07), (x + w, y - 0.07), (x + w * 1.1, y - 0.15), (x - w * 1.1, y - 0.15)]), "#e6c068", LIGHT, 0.3)
        r.put(col, r.ellipse(x, y - 0.148, w * 1.0, 0.008))
    return f


def _teacups(r, x, y, rng):
    for dx in (-0.05, 0.05):
        cx = x + dx * r.h / r.w
        r.put("#f6f2fa", r.ellipse(cx, y, 0.05 * r.h / r.w, 0.01))
        r.shaded(r.poly([(cx - 0.032 * r.h / r.w, y - 0.04), (cx + 0.032 * r.h / r.w, y - 0.04), (cx + 0.02 * r.h / r.w, y - 0.005), (cx - 0.02 * r.h / r.w, y - 0.005)]), "#f6f2fa", LIGHT, 0.2)
        r.put("#f39cb8", r.poly([(cx - 0.03 * r.h / r.w, y - 0.03), (cx + 0.03 * r.h / r.w, y - 0.03), (cx + 0.029 * r.h / r.w, y - 0.025), (cx - 0.029 * r.h / r.w, y - 0.025)]))


def _mask(col):
    """A court mask on the table (the Spring Court's masks, ch7)."""
    def f(r, x, y, rng):
        w = 0.09 * r.h / r.w
        m = r.poly([(x - w, y - 0.03), (x - w * 0.5, y - 0.06), (x, y - 0.045), (x + w * 0.5, y - 0.06), (x + w, y - 0.03), (x + w * 0.6, y - 0.005), (x, y - 0.02), (x - w * 0.6, y - 0.005)])
        r.shaded(m, col, LIGHT, 0.3, rim=0.25)
        for s in (-1, 1):
            r.put("#2a1e2a", r.ellipse(x + s * w * 0.45, y - 0.033, w * 0.18, 0.009))
        for i in range(6):
            M.leaf(r, x + rng.uniform(-w, w), y - 0.05 - rng.uniform(0, 0.02), rng.uniform(3.5, 6.0), 0.03, shade(col, 0.1))
        r.mark_detail(m, 0.5)
    return f


def _candle(r, x, y, rng):
    w = 0.012 * r.h / r.w
    r.put("#e6c068", r.ellipse(x, y, w * 2.5, 0.008))
    r.shaded(r.poly([(x - w, y - 0.005), (x + w, y - 0.005), (x + w, y - 0.16), (x - w, y - 0.16)]), "#fbf3e8", LIGHT, 0.15)
    r.put("#ffd27a", np.clip(1 - np.sqrt(((r.u - x) * r.w / r.h) ** 2 + (r.v - y + 0.18) ** 2) / 0.08, 0, 1) ** 2 * 0.5)
    r.put("#fff0b0", r.ellipse(x, y - 0.18, w * 0.6, 0.016))


def _book(r, x, y, rng):
    w = 0.1 * r.h / r.w
    col = rng.choice(["#8a5a78", "#5a7a9a", "#a86a5a", "#6a8a6a"])
    r.shaded(r.poly([(x - w, y), (x + w, y), (x + w, y - 0.03), (x - w, y - 0.03)]), col, LIGHT, 0.2)
    r.put("#f6efe0", r.poly([(x - w * 0.95, y - 0.008), (x + w * 0.95, y - 0.008), (x + w * 0.95, y - 0.022), (x - w * 0.95, y - 0.022)]))
    r.put("#e6c068", r.poly([(x - w * 0.6, y), (x - w * 0.5, y), (x - w * 0.5, y - 0.03), (x - w * 0.6, y - 0.03)]))


def _quill(r, x, y, rng):
    r.put("#f6f2fa", r.ellipse(x, y - 0.06, 0.008, 0.07, angle=0.5))
    r.put("#3a2e3a", r.lines([[(x + 0.02, y - 0.002), (x - 0.02, y - 0.12)]], 1))


def _shell(r, x, y, rng):
    w = 0.05 * r.h / r.w
    m = r.poly([(x - w, y), (x + w, y), (x, y - 0.06)])
    r.shaded(m, "#f8d8d8", LIGHT, 0.25)
    for i in range(5):
        r.put("#e8b0b8", r.lines([[(x, y - 0.06), (x - w + i * w / 2, y)]], 1), alpha=0.6)


def _pearls(r, x, y, rng):
    for i in range(18):
        a = i / 18 * 6.28
        r.shaded(r.circle(x + math.cos(a) * 0.06 * r.h / r.w, y - 0.01 + math.sin(a) * 0.012, 0.007), "#f6f2fa", LIGHT, 0.3)


def _bread(r, x, y, rng):
    w = 0.08 * r.h / r.w
    r.shaded(r.ellipse(x, y - 0.03, w, 0.035), "#d8a070", LIGHT, 0.3)
    for i in range(3):
        r.put("#f0d0a0", r.lines([[(x - w * 0.5 + i * w * 0.4, y - 0.05), (x - w * 0.3 + i * w * 0.4, y - 0.02)]], 2))


def _cheese(r, x, y, rng):
    w = 0.07 * r.h / r.w
    r.shaded(r.poly([(x - w, y), (x + w, y), (x + w * 0.6, y - 0.05), (x - w, y - 0.04)]), "#ffe08a", LIGHT, 0.2)


def _honey(r, x, y, rng):
    w = 0.035 * r.h / r.w
    r.shaded(r.poly([(x - w, y), (x + w, y), (x + w * 1.1, y - 0.08), (x - w * 1.1, y - 0.08)]), "#f6b840", LIGHT, 0.25)
    r.put("#f6efe6", r.poly([(x - w * 1.2, y - 0.08), (x + w * 1.2, y - 0.08), (x + w, y - 0.1), (x - w, y - 0.1)]))


def _game_birds(r, x, y, rng):
    """A hunting still life: a brace of pheasant on the ledge (Feyre's hunt)."""
    w = 0.12 * r.h / r.w
    r.shaded(r.ellipse(x, y - 0.03, w, 0.03, angle=-0.15), "#a86a4a", LIGHT, 0.3)
    r.put("#5a8a7a", r.ellipse(x + w * 0.9, y - 0.05, w * 0.18, 0.015))
    r.put("#c8504a", r.circle(x + w * 1.05, y - 0.055, 0.008))
    r.put("#8a5a40", r.lines([[(x - w, y - 0.03), (x - w * 1.8, y - 0.01)]], 3))


def _skull_cup(r, x, y, rng):  # an hourglass: vanitas, for the dark works
    w = 0.03 * r.h / r.w
    r.put("#e6c068", r.poly([(x - w * 1.3, y), (x + w * 1.3, y), (x + w * 1.3, y - 0.008), (x - w * 1.3, y - 0.008)]))
    r.put("#e6c068", r.poly([(x - w * 1.3, y - 0.12), (x + w * 1.3, y - 0.12), (x + w * 1.3, y - 0.128), (x - w * 1.3, y - 0.128)]))
    r.put("#e8f0fa", r.poly([(x - w, y - 0.008), (x + w, y - 0.008), (x, y - 0.064), (x + w, y - 0.12), (x - w, y - 0.12), (x, y - 0.064)]), alpha=0.6)
    r.put("#f0d8a0", r.poly([(x - w * 0.7, y - 0.008), (x + w * 0.7, y - 0.008), (x, y - 0.04)]))


OBJECTS = {
    "apple": _fruit("#e8506a"), "green_apple": _fruit("#a8d880"), "pear": _fruit("#d8d060", 0.04, 1.2), "lemon": _fruit("#ffe060", 0.035),
    "peach": _fruit("#ffb890"), "plum": _fruit("#7a4a8a", 0.03), "pomegranate": _fruit("#c8384a", 0.05), "orange": _fruit("#ffa040", 0.04),
    "fig": _fruit("#6a4a6a", 0.03), "cherries": _grapes("#c8203a"), "grapes": _grapes("#8a6ac8"), "green_grapes": _grapes("#b8d880"),
    "torte": _torte, "tart": _tart, "wine": _goblet("#f6e8c0"), "red_wine": _goblet("#8a2040"), "teacups": _teacups,
    "mask_leaf": _mask("#5fae7c"), "mask_gold": _mask("#e6c068"), "mask_fox": _mask("#c8784a"), "mask_lilac": _mask("#c8b6f2"),
    "candle": _candle, "book": _book, "quill": _quill, "shell": _shell, "pearls": _pearls, "bread": _bread, "cheese": _cheese,
    "honey": _honey, "game_birds": _game_birds, "hourglass": _skull_cup,
}
