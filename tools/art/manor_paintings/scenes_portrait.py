"""Portraits: busts, half-lengths, full-lengths and pairs of the court and its
history. Canon (keeper, ch19/ch32): portraits painted before Amarantha's
masquerade 49 years ago show the court unmasked; after it, masked. Tamlin's
family has no physical description [X]. Faces follow the game's stylised
look (R3): larger eyes, clean shapes, pointed High Fae ears."""

import math
import random

import numpy as np

import motifs as M
from painter import C, mix, shade, jitter

LIGHT = (-0.6, -0.55)

SKINS = {"rose": "#f6d6cc", "fair": "#f8e2d8", "golden": "#f0c8a0", "olive": "#d8b090", "bronze": "#c08a68",
         "umber": "#8e5e48", "deep": "#6a4236", "pearl": "#f2e6ec", "bark": "#a07860", "blue": "#8ab0d8", "moss": "#a8c8a0"}
HAIRS = {"gold": "#e8c070", "honey": "#d8a060", "auburn": "#b8583a", "russet": "#c8603a", "chestnut": "#7a4a34", "black": "#2a2030",
         "silver": "#e4e2ee", "white": "#f6f2f6", "rose": "#f0a8c0", "lilac": "#c8b0e8", "brown": "#6a4a3a", "copper": "#d8784a"}
EYES = {"green": "#4fa878", "jade": "#3f9a7a", "blue": "#6a90d8", "grey": "#8a90a8", "amber": "#d8983a", "brown": "#6a4430",
        "violet": "#8a6ac8", "russet": "#b0603a"}

BACKS = {
    "umber": [(0, "#4a3430"), (1, "#2a1e1e")],
    "plum": [(0, "#4a3048"), (1, "#24162a")],
    "teal": [(0, "#3a5a5a"), (1, "#1e2e30")],
    "rose": [(0, "#f2c8d4"), (1, "#d8a0b4")],
    "pearl": [(0, "#efe8ec"), (1, "#d8ccd8")],
    "lilac": [(0, "#d8ccf0"), (1, "#a898c8")],
    "mint": [(0, "#cfe8da"), (1, "#a0c8b4")],
    "sky": [(0, "#bcd0f0"), (1, "#f2dce4")],
    "storm": [(0, "#4a4058"), (1, "#2a2232")],
}


def face(r, cx, cy, size, q, rng, turn=0.0):
    """A head centred at (cx, cy); size = head height in v. q holds skin, hair,
    eyes, hair_style, ears, mask, mask_col, crown, expression, beard."""
    k = r.h / r.w
    hw, hh = size * 0.4 * k, size * 0.5
    skin = C(SKINS.get(q.get("skin", "fair"), q.get("skin", "fair")) if isinstance(q.get("skin", "fair"), str) else q["skin"])
    hair = C(HAIRS.get(q.get("hair", "gold"), "#e8c070"))
    style = q.get("hair_style", "long")
    # hair behind
    if style in ("long", "waves", "braid"):
        back = r.poly([(cx - hw * 1.25, cy - hh * 0.3), (cx + hw * 1.25, cy - hh * 0.3), (cx + hw * 1.45, cy + hh * 1.8), (cx - hw * 1.45, cy + hh * 1.8)])
        r.shaded(back, shade(hair, -0.1), LIGHT, 0.25)
    elif style == "updo":
        r.shaded(r.ellipse(cx + turn * hw * 0.3, cy - hh * 0.95, hw * 0.8, hh * 0.38), hair, LIGHT, 0.3)
    # neck
    r.shaded(r.poly([(cx - hw * 0.42, cy + hh * 0.6), (cx + hw * 0.42, cy + hh * 0.6), (cx + hw * 0.5, cy + hh * 1.35), (cx - hw * 0.5, cy + hh * 1.35)]), shade(skin, -0.08), LIGHT, 0.2)
    # ears (pointed for High Fae)
    for s in (-1, 1):
        ex = cx + s * hw * 0.98
        if q.get("ears", "fae") == "fae":
            m = r.poly([(ex, cy - hh * 0.05), (ex + s * hw * 0.32, cy - hh * 0.55), (ex + s * hw * 0.05, cy + hh * 0.25)])
        else:
            m = r.ellipse(ex, cy + hh * 0.05, hw * 0.12, hh * 0.18)
        r.shaded(m, shade(skin, -0.05), LIGHT, 0.25)
    # head
    head = r.poly([(cx + hw * math.cos(a) * (0.82 + 0.18 * max(0, -math.sin(a))), cy + hh * math.sin(a) * (1.0 if math.sin(a) < 0 else 1.08))
                   for a in np.linspace(0, 2 * math.pi, 48, endpoint=False)], blur=0.8)
    r.shaded(head, skin, LIGHT, 0.22, rim=0.15)
    fx = cx + turn * hw * 0.18
    # cheeks
    for s in (-1, 1):
        r.put("#f39cb0", r.ellipse(fx + s * hw * 0.5, cy + hh * 0.3, hw * 0.2, hh * 0.1, blur=3.0), alpha=0.35)
    # eyes (larger, R3), brows
    ey = cy + hh * 0.05
    eye_col = C(EYES.get(q.get("eyes", "green"), "#4fa878"))
    for s in (-1, 1):
        ex = fx + s * hw * 0.38 * (1 - 0.25 * turn * s)
        ew, eh = hw * 0.24 * (1 - 0.3 * turn * s), hh * 0.13
        r.put("#fbf8f4", r.ellipse(ex, ey, ew, eh, blur=0.4))
        r.put(eye_col, r.ellipse(ex + turn * ew * 0.2, ey + eh * 0.05, ew * 0.55, eh * 0.95, blur=0.4))
        r.put("#1e1620", r.ellipse(ex + turn * ew * 0.2, ey + eh * 0.05, ew * 0.25, eh * 0.45, blur=0.3))
        r.put("#ffffff", r.ellipse(ex - ew * 0.15, ey - eh * 0.3, ew * 0.12, eh * 0.22, blur=0.3))
        r.put("#2a1e24", r.lines([[(ex - ew * 1.1, ey - eh * 0.2), (ex - ew * 0.3, ey - eh * 1.0), (ex + ew * 0.6, ey - eh * 0.9), (ex + ew * 1.15, ey - eh * 0.2)]], max(1, size * r.h * 0.018)))
        r.put(shade(hair, -0.2), r.lines([[(ex - ew * 0.9, ey - eh * 2.0), (ex + ew * 0.1, ey - eh * 2.5), (ex + ew * 1.0, ey - eh * 2.1)]], max(1, size * r.h * 0.022)))
    # nose and mouth
    r.put(shade(skin, -0.2), r.lines([[(fx + hw * 0.03, cy + hh * 0.2), (fx + hw * 0.08, cy + hh * 0.38), (fx - hw * 0.05, cy + hh * 0.42)]], max(1, size * r.h * 0.012)), alpha=0.6)
    mouth_col = q.get("lips", "#d86a7a")
    expr = q.get("expression", "calm")
    if expr == "smile":
        r.put(mouth_col, r.lines([[(fx - hw * 0.2, cy + hh * 0.58), (fx, cy + hh * 0.64), (fx + hw * 0.2, cy + hh * 0.58)]], max(2, size * r.h * 0.03)))
    elif expr == "stern":
        r.put(shade(mouth_col, -0.25), r.lines([[(fx - hw * 0.18, cy + hh * 0.6), (fx + hw * 0.18, cy + hh * 0.6)]], max(2, size * r.h * 0.022)))
    else:
        r.put(mouth_col, r.ellipse(fx, cy + hh * 0.6, hw * 0.16, hh * 0.05, blur=0.5))
    if q.get("beard"):
        r.shaded(r.poly([(cx - hw * 0.8, cy + hh * 0.35), (cx + hw * 0.8, cy + hh * 0.35), (cx + hw * 0.45, cy + hh * 1.0), (cx - hw * 0.45, cy + hh * 1.0)]), hair, LIGHT, 0.2)
        r.put(mouth_col, r.ellipse(fx, cy + hh * 0.6, hw * 0.14, hh * 0.04, blur=0.5), alpha=0.7)
    # mask over the eyes (after the curse; ch7/ch32)
    if q.get("mask"):
        _mask(r, fx, ey, hw, hh, q["mask"], C(q.get("mask_col", "#7cc29a")), rng)
    # hair in front
    if style in ("long", "waves", "braid", "updo", "short", "curls"):
        fr = r.poly([(cx - hw * 1.08, cy - hh * 0.05), (cx - hw * 1.05, cy - hh * 0.7), (cx - hw * 0.3, cy - hh * 1.12), (cx + hw * 0.5, cy - hh * 1.1),
                     (cx + hw * 1.08, cy - hh * 0.65), (cx + hw * 1.1, cy - hh * 0.05), (cx + hw * 0.75, cy - hh * 0.55), (cx + turn * hw * 0.3, cy - hh * 0.62), (cx - hw * 0.75, cy - hh * 0.5)])
        r.shaded(fr, hair, LIGHT, 0.3, rim=0.3)
        for i in range(6):
            x0 = cx + rng.uniform(-0.8, 0.8) * hw
            r.put(shade(hair, 0.25), r.lines([[(x0, cy - hh * 0.95), (x0 + hw * 0.2, cy - hh * 0.6)]], max(1, size * r.h * 0.01)), alpha=0.6)
    if style == "curls":
        for i in range(14):
            a = rng.uniform(math.pi * 0.9, math.pi * 2.1)
            r.shaded(r.circle(cx + math.cos(a) * hw * 1.05, cy + math.sin(a) * hh * 0.95, hh * 0.18), hair, LIGHT, 0.3)
    if style == "braid":
        for i in range(6):
            r.shaded(r.ellipse(cx + hw * 1.1, cy + hh * (0.4 + i * 0.25), hw * 0.2, hh * 0.13), hair, LIGHT, 0.3)
    crown = q.get("crown")
    if crown == "flowers":
        for i in range(9):
            a = math.pi * (1.1 + i * 0.1)
            M.flower_head(r, cx + math.cos(a) * hw * 1.05, cy - hh * 0.55 + math.sin(a) * hh * 0.45, hh * 0.12,
                          rng.choice(["rose", "daisy", "peony"]), rng.choice(["#f39cb8", "#fff1a8", "#c8b6f2", "#fbfbff"]), rng)
    elif crown == "circlet":
        r.put("#e6c068", r.lines([[(cx - hw * 1.0, cy - hh * 0.62), (cx, cy - hh * 0.8), (cx + hw * 1.0, cy - hh * 0.62)]], max(2, size * r.h * 0.025)))
        r.put("#7cc29a", r.circle(cx, cy - hh * 0.8, hh * 0.06))
    elif crown == "antlers":
        for s in (-1, 1):
            r.put("#e8d8c0", r.lines([[(cx + s * hw * 0.6, cy - hh * 0.85), (cx + s * hw * 1.1, cy - hh * 1.5), (cx + s * hw * 1.6, cy - hh * 1.7)],
                                      [(cx + s * hw * 0.95, cy - hh * 1.3), (cx + s * hw * 0.8, cy - hh * 1.75)]], max(2, size * r.h * 0.03)))
    elif crown == "roses":
        for i in range(7):
            a = math.pi * (1.1 + i * 0.13)
            M.flower_head(r, cx + math.cos(a) * hw * 1.05, cy - hh * 0.55 + math.sin(a) * hh * 0.45, hh * 0.14, "rose", rng.choice(["#e8708f", "#f39cb8", "#d0485e"]), rng)
    r.mark_detail(r.ellipse(cx, cy, hw * 1.3, hh * 1.2), 1.0)


def _mask(r, fx, ey, hw, hh, kind, col, rng):
    pts = [(fx - hw * 1.08, ey - hh * 0.1), (fx - hw * 0.8, ey - hh * 0.38), (fx, ey - hh * 0.26), (fx + hw * 0.8, ey - hh * 0.38), (fx + hw * 1.08, ey - hh * 0.1),
           (fx + hw * 0.7, ey + hh * 0.3), (fx, ey + hh * 0.14), (fx - hw * 0.7, ey + hh * 0.3)]
    m = r.poly(pts, blur=0.6)
    r.shaded(m, col, LIGHT, 0.3, rim=0.3)
    if kind == "leaf":  # Tamlin's: emerald leaf-whorls (keeper)
        for i in range(10):
            a = rng.uniform(math.pi * 0.9, math.pi * 2.1)
            M.leaf(r, fx + math.cos(a) * hw * 0.7, ey + math.sin(a) * hh * 0.25, a, hh * 0.28, shade(col, rng.uniform(-0.1, 0.2)))
    elif kind == "fox":  # Lucien's bronze fox
        for s in (-1, 1):
            r.shaded(r.poly([(fx + s * hw * 0.5, ey - hh * 0.3), (fx + s * hw * 0.85, ey - hh * 0.75), (fx + s * hw * 0.95, ey - hh * 0.2)]), col, LIGHT, 0.3)
    elif kind == "feather":
        for i in range(7):
            a = math.pi * (1.15 + i * 0.1)
            r.put(shade(col, rng.uniform(-0.1, 0.2)), r.ellipse(fx + math.cos(a) * hw * 0.95, ey - hh * 0.3 + math.sin(a) * hh * 0.35, hw * 0.08, hh * 0.25, angle=a + 1.57))
    elif kind == "butterfly":
        for s in (-1, 1):
            r.shaded(r.ellipse(fx + s * hw * 0.65, ey - hh * 0.15, hw * 0.45, hh * 0.3, angle=s * 0.4), col, LIGHT, 0.3)
    elif kind == "filigree":
        for i in range(8):
            a = rng.uniform(0, 6.28)
            r.put("#fff0c0", r.lines([[(fx + math.cos(a) * hw * 0.6, ey + math.sin(a) * hh * 0.15), (fx + math.cos(a + 0.5) * hw * 0.8, ey + math.sin(a + 0.5) * hh * 0.2)]], 1), alpha=0.7)
    elif kind == "flowers":
        for i in range(6):
            M.flower_head(r, fx + rng.uniform(-0.9, 0.9) * hw, ey - hh * rng.uniform(0.2, 0.35), hh * 0.08, "rose", rng.choice(["#f39cb8", "#fff1a8", "#fbfbff"]), rng)
    for s in (-1, 1):  # eye holes, eyes painted again inside
        r.put("#1a1218", r.ellipse(fx + s * hw * 0.38, ey, hw * 0.26, hh * 0.13, blur=0.5), alpha=0.85)
        r.put("#e8f0e0", r.ellipse(fx + s * hw * 0.38, ey + hh * 0.01, hw * 0.06, hh * 0.05, blur=0.3), alpha=0.9)


def _garment(r, cx, top, width, q, rng, bottom=1.02):
    k = r.h / r.w
    col = C(q.get("garment", "#c8b6f2"))
    kind = q.get("dress", "gown")
    w = width * k
    body = r.poly([(cx - w * 0.28, top), (cx + w * 0.28, top), (cx + w * 0.62, top + 0.06), (cx + w * 0.72, bottom), (cx - w * 0.72, bottom), (cx - w * 0.62, top + 0.06)])
    r.shaded(body, col, LIGHT, 0.3, rim=0.25)
    if kind == "gown":
        r.put(mix(q.get("skin_c", "#f8e2d8"), col, 0.0), r.poly([(cx - w * 0.3, top - 0.005), (cx + w * 0.3, top - 0.005), (cx, top + 0.09)]))
        r.put("#e6c068", r.lines([[(cx - w * 0.34, top), (cx, top + 0.1), (cx + w * 0.34, top)]], max(2, r.h * 0.006)))
        for i in range(12):
            a = i / 11
            M.flower_head(r, cx - w * 0.34 + a * w * 0.68, top + 0.003 + math.sin(a * math.pi) * 0.09, 0.008, "rose", "#fbe0e8", rng)
    elif kind == "coat":
        r.put(shade(col, -0.25), r.poly([(cx - w * 0.06, top), (cx + w * 0.06, top), (cx + w * 0.04, bottom), (cx - w * 0.04, bottom)]))
        for i in range(5):
            r.put("#e6c068", r.circle(cx + w * 0.09, top + 0.06 + i * 0.07, 0.006))
        r.put("#e6c068", r.lines([[(cx - w * 0.6, top + 0.07), (cx - w * 0.3, top + 0.02)], [(cx + w * 0.6, top + 0.07), (cx + w * 0.3, top + 0.02)]], max(2, r.h * 0.008)))
    elif kind == "armour":
        for i in range(4):
            r.put(shade(col, 0.25), r.lines([[(cx - w * 0.55, top + 0.08 + i * 0.07), (cx + w * 0.55, top + 0.08 + i * 0.07)]], max(1, r.h * 0.004)))
        r.shaded(r.ellipse(cx - w * 0.62, top + 0.05, w * 0.18, 0.05), shade(col, 0.15), LIGHT, 0.3)
        r.shaded(r.ellipse(cx + w * 0.62, top + 0.05, w * 0.18, 0.05), shade(col, 0.15), LIGHT, 0.3)
    elif kind == "robe":
        r.put(shade(col, 0.2), r.lines([[(cx - w * 0.3, top), (cx - w * 0.1, bottom)], [(cx + w * 0.3, top), (cx + w * 0.1, bottom)]], max(2, r.h * 0.01)))
    if q.get("sash"):
        r.put(q["sash"], r.lines([[(cx - w * 0.55, top + 0.05), (cx + w * 0.5, top + 0.3)]], max(3, r.h * 0.02)))
    if q.get("jewel"):
        r.shaded(r.circle(cx, top + 0.05, 0.015), q["jewel"], LIGHT, 0.3)
        r.put("#e6c068", r.lines([[(cx - w * 0.25, top - 0.01), (cx, top + 0.04), (cx + w * 0.25, top - 0.01)]], 1))


def _backdrop(r, q, rng):
    back = q.get("back", "umber")
    if back == "garden":
        M.sky(r, "golden", q["seed"], 0.4, 0.75)
        M.hills(r, q["seed"] + 1, 0.72, 0.05, ["#b5e3c0", "#9fd6a2"], "golden", 0.4)
        M.grove(r, q["seed"] + 2, 8, 0.7, 0.78, 0.12, 0.2, ["blossom"], "spring", "golden")
    elif back == "roses":
        r.vgrad(BACKS["rose"])
        for i in range(60):
            M.flower_head(r, rng.random(), rng.random() ** 0.6, rng.uniform(0.015, 0.03), "rose", rng.choice(["#e8708f", "#f39cb8", "#d0485e", "#fde2ea"]), rng)
            if i % 2:
                M.leaf(r, rng.random(), rng.random(), rng.uniform(0, 6.28), 0.04, "#5fae7c")
    elif back == "drape":
        r.vgrad(BACKS[q.get("drape_base", "plum")])
        col = C(q.get("drape_col", "#8a4a6a"))
        for i in range(9):
            x = rng.uniform(0, 0.4)
            r.put(shade(col, rng.uniform(-0.2, 0.15)), r.lines([[(x, 0), (x + rng.uniform(-0.02, 0.05), 1.0)]], r.w * 0.04, blur=5.0), alpha=0.7)
        r.put("#e6c068", r.lines([[(0.0, 0.05), (0.3, 0.1)]], 3), alpha=0.6)
    elif back == "column":
        r.vgrad(BACKS[q.get("drape_base", "umber")])
        r.shaded(r.poly([(0.72, 0), (0.86, 0), (0.86, 1), (0.72, 1)]), "#d8ccc4", LIGHT, 0.3)
        M.sky(r, "dusk", q["seed"], 0.4, 0.8)
        r.rgb[:, : int(r.w * 0.7)] = r.rgb[:, : int(r.w * 0.7)] * 0.0 + C(BACKS[q.get("drape_base", "umber")][0][1])
    elif back == "night":
        r.vgrad([(0, "#141a3c"), (1, "#3c4278")])
        M.stars(r, q["seed"], 90, 1.0)
    else:
        r.rgrad(0.3, 0.25, 1.1, BACKS.get(back, BACKS["umber"]))


def portrait(r, q):
    """Bust or half-length of one sitter (q['kind'] = 'bust' | 'half')."""
    rng = random.Random(q["seed"])
    _backdrop(r, q, rng)
    kind = q.get("kind", "bust")
    if kind == "bust":
        cx, cy, size = 0.5, 0.36, 0.34
        top = 0.66
    else:
        cx, cy, size = 0.5, 0.26, 0.24
        top = 0.47
    q = dict(q)
    q["skin_c"] = SKINS.get(q.get("skin", "fair"), "#f8e2d8")
    _garment(r, cx, top, size * 1.6, q, rng)
    if q.get("holds"):
        HOLDS[q["holds"]](r, cx + 0.12, top + 0.2, rng)
    face(r, cx, cy, size, q, rng, q.get("turn", 0.0))
    if q.get("pet"):
        PETS[q["pet"]](r, rng)


def full_length(r, q):
    """A standing sitter in a landscape or hall (portrait_masked at scale)."""
    rng = random.Random(q["seed"])
    _backdrop(r, q, rng)
    k = r.h / r.w
    cx = q.get("x", 0.5)
    if q.get("back") in ("garden",):
        M.meadow(r, 0.82, "spring", "golden", q["seed"], 0.5)
    else:
        r.put(shade(C(BACKS.get(q.get("back", "umber"), BACKS["umber"])[1][1]), -0.2), r.poly([(0, 0.86), (1, 0.86), (1, 1), (0, 1)]))
    col = C(q.get("garment", "#c8b6f2"))
    if q.get("dress", "gown") == "gown":
        skirt = r.poly([(cx - 0.05 * k, 0.4), (cx + 0.05 * k, 0.4), (cx + 0.28 * k, 0.93), (cx - 0.28 * k, 0.93)])
        r.shaded(skirt, col, LIGHT, 0.3, rim=0.3)
        for i in range(5):
            x = cx + (i - 2) * 0.05 * k
            r.put(shade(col, -0.15), r.lines([[(cx + (i - 2) * 0.012 * k, 0.45), (x, 0.92)]], 3, blur=2.0), alpha=0.5)
    else:
        for s in (-1, 1):
            r.shaded(r.poly([(cx + s * 0.03 * k - 0.025 * k, 0.6), (cx + s * 0.03 * k + 0.025 * k, 0.6), (cx + s * 0.035 * k + 0.02 * k, 0.92), (cx + s * 0.035 * k - 0.02 * k, 0.92)]), "#5a4a5a", LIGHT, 0.25)
        r.shaded(r.poly([(cx - 0.09 * k, 0.24), (cx + 0.09 * k, 0.24), (cx + 0.1 * k, 0.64), (cx - 0.1 * k, 0.64)]), col, LIGHT, 0.3, rim=0.3)
    bod = r.poly([(cx - 0.07 * k, 0.22), (cx + 0.07 * k, 0.22), (cx + 0.05 * k, 0.42), (cx - 0.05 * k, 0.42)])
    r.shaded(bod, col, LIGHT, 0.3, rim=0.3)
    skin = SKINS.get(q.get("skin", "fair"), "#f8e2d8")
    for s in (-1, 1):
        r.put(skin, r.lines([[(cx + s * 0.075 * k, 0.24), (cx + s * 0.1 * k, 0.36), (cx + s * 0.04 * k, 0.44)]], max(2, r.h * 0.012)))
    face(r, cx, 0.15, 0.11, q, rng, q.get("turn", 0.0))
    if q.get("holds"):
        HOLDS[q["holds"]](r, cx + 0.04 * k, 0.45, rng)
    if q.get("pet"):
        PETS[q["pet"]](r, rng)


def pair(r, q):
    """Two sitters side by side (a mated pair, siblings)."""
    rng = random.Random(q["seed"])
    _backdrop(r, q, rng)
    for i, sit in enumerate(q["sitters"]):
        s = dict(q)
        s.update(sit)
        cx = 0.32 if i == 0 else 0.68
        size = 0.2 if i == 0 else 0.21
        cy = 0.34 if i == 0 else 0.3
        s["skin_c"] = SKINS.get(s.get("skin", "fair"), "#f8e2d8")
        _garment(r, cx, cy + size * 0.85, size * 1.7, s, rng)
        face(r, cx, cy, size, s, rng, 0.25 if i == 0 else -0.25)


def _rose_hold(r, x, y, rng):
    r.put("#4f9a82", r.lines([[(x, y + 0.12), (x - 0.02, y)]], 3))
    M.flower_head(r, x - 0.02, y - 0.01, 0.03, "rose", "#e8708f", rng)


def _book_hold(r, x, y, rng):
    r.shaded(r.poly([(x - 0.06, y), (x + 0.06, y - 0.02), (x + 0.07, y + 0.08), (x - 0.05, y + 0.1)]), "#8a5a78", LIGHT, 0.25)


def _sword_hold(r, x, y, rng):
    r.put("#d8dce8", r.lines([[(x, y + 0.3), (x + 0.01, y - 0.2)]], max(3, r.h * 0.012)))
    r.put("#e6c068", r.lines([[(x - 0.04, y - 0.18), (x + 0.05, y - 0.19)]], max(3, r.h * 0.01)))


def _fan_hold(r, x, y, rng):
    for i in range(9):
        a = math.pi * (1.1 + i * 0.1)
        r.put(rng.choice(["#f6f2fa", "#f3c8d8"]), r.lines([[(x, y), (x + math.cos(a) * 0.08 * r.h / r.w, y + math.sin(a) * 0.08)]], max(2, r.h * 0.01)))


def _bird_hold(r, x, y, rng):
    r.shaded(r.ellipse(x, y, 0.03 * r.h / r.w, 0.022), "#8ab0e8", LIGHT, 0.3)
    r.put("#f6c84a", r.poly([(x + 0.025 * r.h / r.w, y - 0.005), (x + 0.04 * r.h / r.w, y), (x + 0.025 * r.h / r.w, y + 0.005)]))


def _lamb_pet(r, rng):
    M.lamb(r, 0.25, 0.98, 0.16)


def _hound_pet(r, rng):
    M.fox(r, 0.78, 0.98, 0.18, flip=True, col="#e8dcd0")


def _fox_pet(r, rng):
    M.fox(r, 0.76, 0.98, 0.16, flip=True)


HOLDS = {"rose": _rose_hold, "book": _book_hold, "sword": _sword_hold, "fan": _fan_hold, "bird": _bird_hold}
PETS = {"lamb": _lamb_pet, "hound": _hound_pet, "fox": _fox_pet}
