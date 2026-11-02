"""Reusable picture motifs for the reference pass: skies, land, water, trees,
flowers, buildings, animals and small figures. All coordinates are uv (0..1,
origin top-left). Every function draws straight into a painter.Ref.
"""

import math
import random

import numpy as np

from painter import C, mix, shade, jitter, blur_arr

# ------------------------------------------------------------------ light by time of day
# sky stops (top -> horizon), sun/light colour, haze, shadow tint

TIMES = {
    "dawn": dict(sky=[(0, "#a9b4e6"), (0.55, "#f3c1d3"), (1, "#ffe0c2")], light="#ffd9b8", haze="#f6cfd8", sun="#fff0d6", dark=0.0),
    "morning": dict(sky=[(0, "#9fc4f0"), (0.6, "#c9e0f6"), (1, "#f4ecdf")], light="#fff4dc", haze="#dfe8f2", sun="#fffaf0", dark=0.0),
    "noon": dict(sky=[(0, "#8db8ee"), (0.7, "#bcd8f4"), (1, "#e6f0f6")], light="#fffbea", haze="#d8e6f0", sun="#ffffff", dark=0.0),
    "golden": dict(sky=[(0, "#b7b4e8"), (0.45, "#f6c6c8"), (0.8, "#ffd7a8"), (1, "#ffe9b8")], light="#ffcf8a", haze="#f7d4c2", sun="#fff2c4", dark=0.05),
    "dusk": dict(sky=[(0, "#4f4b8f"), (0.45, "#9a77b8"), (0.8, "#f19ab0"), (1, "#ffc59a")], light="#f7a98f", haze="#c58fb0", sun="#ffd7a0", dark=0.25),
    "twilight": dict(sky=[(0, "#2f3270"), (0.5, "#6b62a8"), (1, "#c69ac4")], light="#c9b2e8", haze="#8a7ab4", sun="#f4e6ff", dark=0.4),
    "night": dict(sky=[(0, "#141a3c"), (0.6, "#2c3570"), (1, "#4c4f8a")], light="#b8c4f4", haze="#3c4278", sun="#f4f2ff", dark=0.62),
    "storm": dict(sky=[(0, "#3a3446"), (0.6, "#6e5a68"), (1, "#a9786c")], light="#e0a080", haze="#7a6470", sun="#f0c0a0", dark=0.45),
    "overcast": dict(sky=[(0, "#b9bfd2"), (1, "#e4e2e6")], light="#f2f0f0", haze="#d6d8e0", sun="#ffffff", dark=0.1),
}

SEASONS = {
    "spring": dict(grass=["#9fd6a2", "#7cc29a", "#c4e8b0"], tree=["#f7c6d6", "#f3a8c0", "#fde2ea"], leaf="#7cc29a", flower=["#f6a6c6", "#c8b6f2", "#fff1a8", "#ffffff"]),
    "summer": dict(grass=["#7cc68a", "#5fae7c", "#a8dc94"], tree=["#5fae7c", "#4f9a82", "#88c890"], leaf="#4f9a82", flower=["#ff9cae", "#ffd36a", "#b8a8f2", "#ffffff"]),
    "autumn": dict(grass=["#d6b878", "#c39a5e", "#e8cf92"], tree=["#f09a5a", "#e8704e", "#f6c060"], leaf="#d8804e", flower=["#f6c060", "#e87a5a", "#b05a68"]),
    "winter": dict(grass=["#eef0f8", "#d8dcf0", "#ffffff"], tree=["#e6eaf8", "#c8cfe8", "#b0b8dc"], leaf="#8a96c0", flower=["#ffffff", "#cfd8ff"]),
    "blight": dict(grass=["#9a9480", "#7e7a70", "#b0a890"], tree=["#7a6a68", "#5e5258", "#958478"], leaf="#6e6a5c", flower=["#8a7a80"]),
}


def tod(name):
    return TIMES[name]


# ------------------------------------------------------------------ sky

def sky(r, time, seed, clouds=0.5, horizon=0.6, swirl=False):
    t = TIMES[time]
    r.vgrad(t["sky"], 0.0, horizon)
    if clouds > 0:
        n = r.noise(3.0, seed, 4)
        n2 = r.noise(1.4, seed + 3, 2)
        band = np.clip(1 - np.abs(r.v - horizon * 0.45) / (horizon * 0.5), 0, 1)
        m = np.clip((n * 0.65 + n2 * 0.35 - (0.62 - clouds * 0.25)) * 4.0, 0, 1) * band
        lit = mix(t["light"], "#ffffff", 0.35)
        under = mix(t["haze"], t["sky"][0][1], 0.35)
        shading = np.clip(n - r.noise(3.0, seed + 11, 3) * 0.3, 0, 1)[..., None]
        img = under * (1 - shading) + lit * shading
        r.put(img, m * 0.85)
    if swirl:
        sw = r.noise(5.0, seed + 21, 3)
        stripes = (np.sin((r.u * 18 + sw * 9 + r.v * 6)) * 0.5 + 0.5) * np.clip(1 - r.v / horizon, 0, 1)
        r.put(mix(t["light"], "#ffffff", 0.5), stripes * 0.18)


def sun(r, cx, cy, rad, time, glow=3.0):
    t = TIMES[time]
    r.rgrad(cx, cy, rad * glow, [(0, t["sun"]), (1, t["sun"])], mask=np.clip(1 - np.sqrt(((r.u - cx) * r.w / r.h) ** 2 + (r.v - cy) ** 2) / (rad * glow), 0, 1) ** 2 * 0.6)
    r.put(t["sun"], r.circle(cx, cy, rad, blur=1.5))


def moon(r, cx, cy, rad, crescent=False):
    r.put("#cdd2f0", np.clip(1 - np.sqrt(((r.u - cx) * r.w / r.h) ** 2 + (r.v - cy) ** 2) / (rad * 4), 0, 1) ** 2 * 0.45)
    r.shaded(r.circle(cx, cy, rad, blur=1.0), "#f6f2ff", light=(0.5, -0.3), k=0.15)
    if crescent:
        r.put(r.rgb[int(cy * r.h), max(0, int((cx - rad * 3) * r.w))], r.circle(cx + rad * 0.45 * r.h / r.w, cy - rad * 0.1, rad * 0.9, blur=1.0))


def stars(r, seed, n=160, horizon=0.6, big=0.08):
    rng = random.Random(seed)
    for _ in range(n):
        x, y = rng.random(), rng.random() ** 1.4 * horizon
        s = rng.uniform(0.0015, 0.004) * (3 if rng.random() < big else 1)
        r.put(rng.choice(["#ffffff", "#fff3d0", "#dfe6ff", "#ffd6ec"]), r.circle(x, y, s, blur=0.5), alpha=rng.uniform(0.6, 1.0))
        r.mark_detail(r.circle(x, y, s * 1.5, blur=0.5), 0.8)


def rays(r, cx, cy, time, n=7, seed=0, strength=0.22):
    rng = random.Random(seed)
    col = TIMES[time]["light"]
    for i in range(n):
        a = math.radians(rng.uniform(40, 140))
        spread = math.radians(rng.uniform(2, 5))
        L = 2.0
        pts = [(cx, cy), (cx + math.cos(a - spread) * L, cy + math.sin(a - spread) * L), (cx + math.cos(a + spread) * L, cy + math.sin(a + spread) * L)]
        m = r.poly(pts, blur=6) * np.clip(1 - np.abs(r.v - cy) * 1.2, 0, 1)
        r.put(col, m, alpha=strength * rng.uniform(0.5, 1.0))


# ------------------------------------------------------------------ land

def ridge(seed, base, amp, freq=3.0, sharp=False):
    rng = random.Random(seed)
    ph = [rng.uniform(0, 6.28) for _ in range(5)]
    fr = [freq, freq * 2.1, freq * 4.3, freq * 8.7, freq * 0.5]
    am = [1.0, 0.45, 0.2, 0.08, 0.6]

    def f(u):
        s = 0.0
        for k in range(5):
            v = math.sin(u * fr[k] * math.pi + ph[k])
            s += (1 - abs(v) if sharp and k < 3 else v * 0.5 + 0.5) * am[k]
        return base - amp * s / sum(am)
    return f


def land_layer(r, profile, col_top, col_bottom, haze=None, haze_k=0.0, texture=0.0, seed=0):
    m = r.below(profile)
    top, bot = C(col_top), C(col_bottom)
    if haze is not None:
        top, bot = mix(top, haze, haze_k), mix(bot, haze, haze_k * 0.7)
    img = np.empty((r.h, r.w, 3), np.float32)
    t = np.clip((r.v - 0.3) * 1.6, 0, 1)[..., None]
    img[:] = top * (1 - t) + bot * t
    if texture > 0:
        n = (r.noise(14.0, seed, 3) - 0.5)[..., None] * texture
        img = img + n
    r.put(np.clip(img, 0, 1), m)
    return m


def mountains(r, seed, base, amp, col, time, snow=True, haze_k=0.55):
    t = TIMES[time]
    prof = ridge(seed, base, amp, 2.2, sharp=True)
    m = r.below(prof)
    col = mix(col, t["haze"], haze_k)
    lit, dark = shade(col, 0.18), shade(col, -0.18)
    lr = r.noise(6.0, seed + 5, 3)
    img = dark * (1 - lr[..., None]) + lit * lr[..., None]
    r.put(img, m)
    if snow:
        us = np.linspace(0, 1, r.w)
        vs = np.array([prof(float(x)) for x in us])[None, :]
        cap = np.clip(1 - (r.v - vs) / (amp * 0.35), 0, 1) * (r.v >= vs) * np.clip((lr - 0.3) * 3, 0, 1)
        r.put(mix("#f8f6ff", t["light"], 0.3), cap * 0.9)
    return m


def hills(r, seed, base, amp, cols, time, haze_k=0.25, freq=1.6):
    t = TIMES[time]
    prof = ridge(seed, base, amp, freq)
    return land_layer(r, prof, cols[0], cols[1], t["haze"], haze_k, texture=0.05, seed=seed)


def water(r, top, bottom, time, seed, col=None, reflect=True):
    t = TIMES[time]
    m = np.clip((r.v - top) * 400, 0, 1) * np.clip((bottom - r.v) * 400, 0, 1)
    sky_col = C(col) if col is not None else mix(t["sky"][-1][1], t["sky"][0][1], 0.35)
    deep = shade(sky_col, -0.2)
    k = np.clip((r.v - top) / max(1e-4, bottom - top), 0, 1)[..., None]
    img = sky_col * (1 - k) + deep * k
    n = value_noise_stretched(r, seed)
    streak = np.clip((n - 0.72) * 6, 0, 1)[..., None]
    img = img + (mix(t["light"], "#ffffff", 0.4) - img) * streak * 0.55
    r.put(img, m)
    return m


def value_noise_stretched(r, seed):
    """Noise stretched 12:1 along x: broken horizontal glints on water."""
    from painter import value_noise
    from PIL import Image
    n = value_noise(max(8, r.w // 12), r.h, 60, seed)
    img = Image.fromarray((n * 255).astype(np.uint8), "L").resize((r.w, r.h), Image.BILINEAR)
    return np.asarray(img, np.float32) / 255.0


def foreground_shade(r, top, k=0.18):
    """Repoussoir: the near ground darkens toward the frame's lower edge."""
    t = np.clip((r.v - top) / max(1e-4, 1 - top), 0, 1)[..., None]
    r.rgb = r.rgb * (1 - t * k) + r.rgb * np.array([0.55, 0.5, 0.62], np.float32) * (t * k)


def meadow(r, top, season, time, seed, flowers=0.5, flower_cols=None, scale=1.0):
    s = SEASONS[season]
    t = TIMES[time]
    m = np.clip((r.v - top) * 300, 0, 1)
    k = np.clip((r.v - top) / (1 - top), 0, 1)[..., None]
    a = mix(s["grass"][2], t["haze"], 0.25)
    b = shade(s["grass"][0], -0.08)
    img = a * (1 - k) + b * k
    n = (r.noise(10, seed, 3) - 0.5)[..., None] * 0.12
    # broad patches of light and shade across the field, as a painter blocks them in
    patch = (r.noise(2.2, seed + 7, 2) - 0.5)[..., None]
    img = img * (1 + patch * 0.35)
    r.put(np.clip(img + n, 0, 1), m)
    if flowers > 0:
        rng = random.Random(seed + 99)
        cols = flower_cols or s["flower"]
        n_f = int(flowers * 520 * scale)
        for _ in range(n_f):
            y = top + (1 - top) * rng.random() ** 0.7
            x = rng.random()
            depth = (y - top) / (1 - top)
            rad = 0.002 + depth * 0.009
            c = jitter(rng.choice(cols), rng, 0.04)
            r.put(c, r.circle(x, y, rad, blur=0.4))
            if depth > 0.5:
                r.mark_detail(r.circle(x, y, rad, blur=0.4), 0.5)
    return m


# ------------------------------------------------------------------ trees and plants

def tree(r, x, base, height, kind, season, time, seed, light=(-0.6, -0.5)):
    """One stylised tree whose trunk foot is at (x, base); height in uv(v)."""
    rng = random.Random(seed)
    s = SEASONS[season]
    t = TIMES[time]
    trunk = mix("#8e6a6e", t["haze"], 0.1)
    w_ratio = r.h / r.w
    if kind == "conifer":
        col = mix("#4f8a7a", s["tree"][0] if season == "winter" else "#4f8a7a", 0.4)
        for i in range(4):
            y0 = base - height * (0.15 + i * 0.2)
            wdt = height * (0.45 - i * 0.09) * w_ratio
            m = r.poly([(x - wdt, y0), (x + wdt, y0), (x, y0 - height * 0.38)])
            r.shaded(m, jitter(col, rng, 0.03), light, 0.25)
            if season == "winter":
                r.put("#f4f6ff", r.poly([(x - wdt * 0.7, y0 - height * 0.05), (x + wdt * 0.2, y0 - height * 0.08), (x, y0 - height * 0.36)]) * 0.8)
        r.put(trunk, r.poly([(x - 0.004, base), (x + 0.004, base), (x + 0.003, base - height * 0.2), (x - 0.003, base - height * 0.2)]))
        return
    if kind == "birch":
        r.put("#f2ede8", r.poly([(x - 0.004, base), (x + 0.004, base), (x + 0.002, base - height), (x - 0.002, base - height)]))
        for i in range(6):
            yy = base - height * rng.uniform(0.1, 0.9)
            r.put("#4a3c44", r.ellipse(x, yy, 0.003, 0.002, blur=0.3))
        for i in range(5):
            cy = base - height * rng.uniform(0.55, 0.95)
            cx = x + rng.uniform(-0.05, 0.05) * height
            r.shaded(r.blob(cx, cy, height * 0.13, 0.3, seed + i), jitter(s["tree"][1] if season != "spring" else "#a8d8a0", rng, 0.04), light, 0.25)
        return
    if kind == "willow":
        r.put(trunk, r.poly([(x - 0.006, base), (x + 0.006, base), (x + 0.004, base - height * 0.55), (x - 0.004, base - height * 0.55)]))
        crown = r.blob(x, base - height * 0.72, height * 0.3, 0.15, seed, squash=0.8)
        r.shaded(crown, s["tree"][0] if season in ("spring", "autumn") else "#8fc89a", light, 0.25)
        strands = []
        for i in range(26):
            sx = x + rng.uniform(-0.3, 0.3) * height * w_ratio
            sy = base - height * rng.uniform(0.6, 0.9)
            strands.append([(sx, sy), (sx + 0.004, sy + height * 0.3), (sx + 0.002, sy + height * rng.uniform(0.45, 0.62))])
        r.put(shade(s["leaf"], 0.15), r.lines(strands, max(1, r.w // 280)))
        return
    # round crowned (blossom, oak, orchard)
    trunk_h = height * 0.45
    r.put(trunk, r.poly([(x - 0.007 * height * 3, base), (x + 0.007 * height * 3, base), (x + 0.003, base - trunk_h), (x - 0.003, base - trunk_h)]))
    crown_col = s["tree"] if kind == "blossom" else [s["leaf"], shade(s["leaf"], 0.15), shade(s["leaf"], -0.1)]
    if kind == "blossom" and season == "summer":
        crown_col = ["#f7c6d6", "#fde2ea", "#f3a8c0"]
    for i in range(7):
        a = rng.uniform(0, math.pi * 2)
        d = rng.uniform(0, 0.22) * height
        cx = x + math.cos(a) * d * w_ratio
        cy = base - height * 0.68 + math.sin(a) * d * 0.6
        r.shaded(r.blob(cx, cy, height * rng.uniform(0.16, 0.24), 0.2, seed * 7 + i), jitter(rng.choice(crown_col), rng, 0.03), light, 0.3, rim=0.25)


def grove(r, seed, n, base_lo, base_hi, h_lo, h_hi, kinds, season, time, x_lo=0.0, x_hi=1.0, avoid=None):
    rng = random.Random(seed)
    items = []
    for i in range(n):
        x = rng.uniform(x_lo, x_hi)
        if avoid and avoid[0] < x < avoid[1]:
            continue
        b = rng.uniform(base_lo, base_hi)
        items.append((b, x, rng.choice(kinds), rng.uniform(h_lo, h_hi) * (0.6 + 0.4 * (b - base_lo) / max(1e-4, base_hi - base_lo + 1e-4))))
    for b, x, kind, hgt in sorted(items):
        tree(r, x, b, hgt, kind, season, time, rng.randrange(1 << 30))


def flower_head(r, x, y, rad, kind, col, rng, light=(-0.6, -0.5)):
    """A single bloom (uv centre, rad in v units)."""
    col = C(col)
    if kind == "rose":
        r.shaded(r.circle(x, y, rad), col, light, 0.3)
        for i in range(3):
            rr = rad * (0.75 - i * 0.22)
            r.put(shade(col, -0.25 + i * 0.05), r.lines([[(x + math.cos(a) * rr * r.h / r.w, y + math.sin(a) * rr) for a in np.linspace(i, i + 4.6, 9)]], max(1, rad * r.h * 0.12)))
        r.mark_detail(r.circle(x, y, rad), 0.6)
    elif kind == "peony":
        for i in range(9):
            a = i / 9 * 6.28 + rng.uniform(-0.2, 0.2)
            r.shaded(r.circle(x + math.cos(a) * rad * 0.45 * r.h / r.w, y + math.sin(a) * rad * 0.4, rad * 0.55), jitter(col, rng, 0.03), light, 0.25)
        r.shaded(r.circle(x, y, rad * 0.5), shade(col, 0.15), light, 0.2)
        r.mark_detail(r.circle(x, y, rad), 0.4)
    elif kind == "tulip":
        w = rad * 0.75 * r.h / r.w
        m = r.poly([(x - w, y - rad * 0.6), (x - w * 0.4, y - rad * 0.1), (x, y - rad * 0.7), (x + w * 0.4, y - rad * 0.1), (x + w, y - rad * 0.6), (x + w * 0.9, y + rad * 0.4), (x, y + rad * 0.8), (x - w * 0.9, y + rad * 0.4)])
        r.shaded(m, col, light, 0.3)
        r.mark_detail(m, 0.5)
    elif kind in ("daisy", "maiden_lace", "crocus_top", "anemone"):
        petals = 8 if kind != "crocus_top" else 6
        for i in range(petals):
            a = i / petals * 6.28
            r.put(jitter(col, rng, 0.02), r.ellipse(x + math.cos(a) * rad * 0.55 * r.h / r.w, y + math.sin(a) * rad * 0.55, rad * 0.32 * r.h / r.w, rad * 0.2, angle=a))
        r.put("#f4c04a" if kind != "anemone" else "#2a2238", r.circle(x, y, rad * 0.25))
        r.mark_detail(r.circle(x, y, rad), 0.5)
    elif kind == "morning_glory":
        r.shaded(r.circle(x, y, rad), col, light, 0.2)
        r.put("#fff8f0", r.circle(x, y, rad * 0.35))
        for i in range(5):
            a = i / 5 * 6.28
            r.put(shade(col, 0.35), r.lines([[(x, y), (x + math.cos(a) * rad * 0.95 * r.h / r.w, y + math.sin(a) * rad * 0.95)]], max(1, rad * r.h * 0.08)))
        r.mark_detail(r.circle(x, y, rad), 0.5)
    elif kind == "plume":  # goldenrod, lilac, wisteria, foxglove
        for i in range(16):
            yy = y - rad * 1.2 + i * rad * 0.16
            ww = rad * 0.5 * (1 - abs(i - 6) / 12)
            r.put(jitter(col, rng, 0.05), r.circle(x + rng.uniform(-ww, ww) * r.h / r.w, yy, rad * 0.16))
    elif kind == "iris":
        for a, k in ((-1.9, 1.0), (-1.2, 1.0), (1.3, 1.1), (1.9, 1.1), (0.0, 0.8)):
            r.shaded(r.ellipse(x + math.cos(a - 1.57) * rad * 0.4 * r.h / r.w, y + math.sin(a - 1.57) * rad * 0.4 * k, rad * 0.22 * r.h / r.w, rad * 0.5, angle=a), col, light, 0.3)
        r.put("#ffd760", r.ellipse(x, y + rad * 0.15, rad * 0.06 * r.h / r.w, rad * 0.25))
    else:
        r.shaded(r.circle(x, y, rad), col, light, 0.3)


def leaf(r, x, y, ang, length, col, width_k=0.35):
    dx, dy = math.cos(ang) * length * r.h / r.w, math.sin(ang) * length
    nx, ny = -math.sin(ang) * length * width_k * r.h / r.w, math.cos(ang) * length * width_k
    m = r.poly([(x, y), (x + dx * 0.5 + nx, y + dy * 0.5 + ny), (x + dx, y + dy), (x + dx * 0.5 - nx, y + dy * 0.5 - ny)])
    r.shaded(m, col, k=0.25)


# ------------------------------------------------------------------ buildings

ALABASTER = "#f6efe6"


def manor(r, cx, base, width, time, seed, roses=True):
    """The Spring Court manor: alabaster, patios and balconies, veiled in roses
    and ivy (spring-manor-house.md, verified)."""
    rng = random.Random(seed)
    t = TIMES[time]
    wall = mix(ALABASTER, t["light"], 0.15)
    hgt = width * 0.32 * r.w / r.h
    x0, x1 = cx - width / 2, cx + width / 2
    # wings
    for wx0, wx1, hk in ((x0, x0 + width * 0.3, 0.75), (x1 - width * 0.3, x1, 0.75), (cx - width * 0.22, cx + width * 0.22, 1.0)):
        top = base - hgt * hk
        r.shaded(r.poly([(wx0, base), (wx1, base), (wx1, top), (wx0, top)], blur=0.5), wall, (-0.8, -0.3), 0.12)
        r.put(mix("#9fb4d8", t["sky"][0][1], 0.3), r.poly([(wx0 - 0.004, top), (wx1 + 0.004, top), ((wx0 + wx1) / 2, top - hgt * 0.25)], blur=0.5))
        cols = max(2, int((wx1 - wx0) / width * 14))
        for row in range(2):
            for c in range(cols):
                wx = wx0 + (c + 0.5) * (wx1 - wx0) / cols
                wy = top + (row + 0.35) * (base - top) / 2.3
                win = r.poly([(wx - 0.004, wy), (wx + 0.004, wy), (wx + 0.004, wy + hgt * 0.16), (wx - 0.004, wy + hgt * 0.16)], blur=0.3)
                r.put("#8fa6cf" if t["dark"] < 0.3 else "#ffd98a", win)
    # towers with cone roofs
    for tx in (x0 + 0.01, x1 - 0.01):
        top = base - hgt * 1.15
        tw = width * 0.05
        r.shaded(r.poly([(tx - tw, base), (tx + tw, base), (tx + tw, top), (tx - tw, top)], blur=0.4), wall, (-0.8, -0.3), 0.15)
        r.put("#e8a8bc", r.poly([(tx - tw * 1.2, top), (tx + tw * 1.2, top), (tx, top - hgt * 0.45)], blur=0.4))
    # grand stair and portico
    r.put(shade(wall, -0.05), r.poly([(cx - width * 0.09, base), (cx + width * 0.09, base), (cx + width * 0.05, base - hgt * 0.15), (cx - width * 0.05, base - hgt * 0.15)]))
    for i in range(4):
        px = cx - width * 0.06 + i * width * 0.04
        r.put(shade(wall, 0.1), r.poly([(px - 0.003, base - hgt * 0.15), (px + 0.003, base - hgt * 0.15), (px + 0.003, base - hgt * 0.75), (px - 0.003, base - hgt * 0.75)], blur=0.3))
    if roses:
        for i in range(int(width * 260)):
            x = rng.uniform(x0, x1)
            y = base - rng.random() ** 2 * hgt * 0.7
            r.put(rng.choice(["#f39cb8", "#e8708f", "#7cc29a", "#5fae7c"]), r.circle(x, y, rng.uniform(0.003, 0.007), blur=0.4))
    r.mark_detail(r.poly([(x0, base), (x1, base), (x1, base - hgt), (x0, base - hgt)]), 0.25)


def cottage(r, cx, base, size, time, snow=False):
    t = TIMES[time]
    w = size * r.h / r.w
    r.shaded(r.poly([(cx - w, base), (cx + w, base), (cx + w, base - size * 0.8), (cx - w, base - size * 0.8)]), "#c8b8a8", (-0.7, -0.4), 0.15)
    r.put("#ece6f4" if snow else "#9a7a6a", r.poly([(cx - w * 1.2, base - size * 0.75), (cx + w * 1.2, base - size * 0.75), (cx, base - size * 1.5)]))
    r.put("#ffd98a" if t["dark"] > 0.2 else "#6a5a70", r.poly([(cx - w * 0.5, base - size * 0.5), (cx - w * 0.2, base - size * 0.5), (cx - w * 0.2, base - size * 0.25), (cx - w * 0.5, base - size * 0.25)]))


def ruin(r, cx, base, size, time, seed):
    rng = random.Random(seed)
    stone = mix("#e8dccc", TIMES[time]["haze"], 0.2)
    n = 6
    for i in range(n):
        x = cx + (i - n / 2) * size * 0.35 * r.h / r.w
        hk = rng.uniform(0.4, 1.0)
        r.shaded(r.poly([(x - 0.008, base), (x + 0.008, base), (x + 0.007, base - size * hk), (x - 0.007, base - size * hk)], blur=0.4), stone, (-0.7, -0.3), 0.2)
    r.put(stone, r.poly([(cx - size * 1.1 * r.h / r.w, base - size * 1.0), (cx - size * 0.1 * r.h / r.w, base - size * 1.0), (cx - size * 0.1 * r.h / r.w, base - size * 0.92), (cx - size * 1.1 * r.h / r.w, base - size * 0.92)]))
    for i in range(30):
        r.put(rng.choice(["#7cc29a", "#5fae7c", "#f39cb8"]), r.circle(cx + rng.uniform(-1.1, 1.1) * size * r.h / r.w, base - rng.random() * size * 0.8, rng.uniform(0.003, 0.008)))


def bridge(r, cx, y, span, time):
    stone = mix("#efe4d8", TIMES[time]["haze"], 0.2)
    pts = [(cx - span / 2, y)]
    for i in range(13):
        a = math.pi * i / 12
        pts.append((cx - span / 2 + span * i / 12, y - math.sin(a) * span * 0.25 * r.w / r.h))
    pts += [(cx + span / 2, y), (cx + span / 2, y - span * 0.32 * r.w / r.h), (cx - span / 2, y - span * 0.32 * r.w / r.h)]
    outer = r.poly([(cx - span / 2 - 0.01, y), (cx + span / 2 + 0.01, y), (cx + span / 2 + 0.01, y - span * 0.32 * r.w / r.h), (cx - span / 2 - 0.01, y - span * 0.32 * r.w / r.h)])
    hole = r.poly(pts[:14] + [(cx + span / 2, y)])
    r.shaded(np.clip(outer - hole, 0, 1), stone, (-0.6, -0.4), 0.15)


def tower(r, cx, base, height, time, roof="#b8a8e0"):
    stone = mix(ALABASTER, TIMES[time]["haze"], 0.2)
    w = height * 0.12 * r.h / r.w
    r.shaded(r.poly([(cx - w, base), (cx + w, base), (cx + w * 0.85, base - height), (cx - w * 0.85, base - height)]), stone, (-0.8, -0.3), 0.2)
    r.put(roof, r.poly([(cx - w * 1.2, base - height), (cx + w * 1.2, base - height), (cx, base - height * 1.35)]))


def wall_veil(r, x, time, seed, strength=0.55):
    """The Wall: invisible and magical; painted as a shimmering vertical veil."""
    n = r.noise(4.0, seed, 3)
    band = np.exp(-((r.u - x - (n - 0.5) * 0.04) ** 2) / 0.0009)
    shimmer = (np.sin(r.v * 160 + n * 20) * 0.5 + 0.5) * 0.5 + 0.5
    r.put(mix("#f2ecff", TIMES[time]["light"], 0.2), band * shimmer * strength)


def bonfire(r, x, base, size, seed):
    rng = random.Random(seed)
    r.put("#ffb860", np.clip(1 - np.sqrt(((r.u - x) * r.w / r.h) ** 2 + ((r.v - base + size * 0.4) * 1.0) ** 2) / (size * 3.0), 0, 1) ** 2 * 0.8)
    for i in range(9):
        fx = x + rng.uniform(-0.4, 0.4) * size * r.h / r.w
        fh = size * rng.uniform(0.6, 1.3)
        w = size * 0.18 * r.h / r.w
        r.put(rng.choice(["#ffd27a", "#ff9a52", "#ffe9a8"]), r.poly([(fx - w, base), (fx + w, base), (fx + rng.uniform(-w, w), base - fh)], blur=1.0))
    for i in range(30):
        r.put("#ffe0a0", r.circle(x + rng.uniform(-1, 1) * size * r.h / r.w, base - size * rng.uniform(1.0, 3.2), 0.002))


def faelights(r, seed, n, region=(0, 0, 1, 1), cols=("#fff2b8", "#ffd6f0", "#d8e8ff")):
    rng = random.Random(seed)
    for _ in range(n):
        x = rng.uniform(region[0], region[2])
        y = rng.uniform(region[1], region[3])
        s = rng.uniform(0.003, 0.009)
        c = rng.choice(cols)
        r.put(c, np.clip(1 - np.sqrt(((r.u - x) * r.w / r.h) ** 2 + (r.v - y) ** 2) / (s * 5), 0, 1) ** 2 * 0.6)
        r.put(c, r.circle(x, y, s, blur=0.6))
        r.mark_detail(r.circle(x, y, s * 2), 0.4)


def petals(r, seed, n, cols=("#f7c6d6", "#fde2ea", "#f3a8c0")):
    rng = random.Random(seed)
    for _ in range(n):
        x, y = rng.random(), rng.random()
        s = rng.uniform(0.003, 0.007)
        r.put(rng.choice(cols), r.ellipse(x, y, s * r.h / r.w * 1.6, s, angle=rng.uniform(0, 3.14)))


def snowfall(r, seed, n):
    rng = random.Random(seed)
    for _ in range(n):
        r.put("#ffffff", r.circle(rng.random(), rng.random(), rng.uniform(0.0015, 0.004), blur=0.5), alpha=0.8)


def mist(r, y, depth, col, seed, k=0.5):
    n = r.noise(3.0, seed, 3)
    m = np.clip(1 - np.abs(r.v - y) / depth, 0, 1) * (0.6 + 0.4 * n)
    r.put(col, m * k)


# ------------------------------------------------------------------ animals (side view, facing right unless flip)

def _fl(x0, dx, flip):
    return x0 - dx if flip else x0 + dx


def lamb(r, x, base, size, flip=False, col="#fbf6f0", face="#4a3c44", light=(-0.6, -0.5)):
    w = size * r.h / r.w
    body = np.zeros((r.h, r.w), np.float32)
    for i in range(7):
        a = i / 7 * 6.28
        body = np.maximum(body, r.circle(x + math.cos(a) * w * 0.35, base - size * 0.55 + math.sin(a) * size * 0.18, size * 0.24))
    for lx in (-0.25, -0.05, 0.12, 0.3):
        r.put(face, r.poly([(x + lx * w - 0.002, base), (x + lx * w + 0.002, base), (x + lx * w + 0.002, base - size * 0.4), (x + lx * w - 0.002, base - size * 0.4)], blur=0.3))
    r.shaded(body, col, light, 0.25)
    hx = _fl(x, w * 0.58, flip)
    head = r.ellipse(hx, base - size * 0.72, w * 0.13, size * 0.14, angle=(-0.5 if flip else 0.5))
    r.shaded(head, face, light, 0.2)
    r.put(col, r.circle(_fl(x, w * 0.5, flip), base - size * 0.85, size * 0.1))
    r.mark_detail(head, 0.5)


def horse(r, x, base, size, col="#faf6f2", mane="#e8dcd8", flip=False, light=(-0.6, -0.5), rider=None):
    """A mare in profile; size = height at the withers in v."""
    w = size * r.h / r.w
    s = size
    f = (lambda d: x - d) if flip else (lambda d: x + d)
    legs = []
    for lx in (-0.42, -0.3, 0.32, 0.45):
        legs.append(r.poly([(f(lx * w) - 0.003, base), (f(lx * w) + 0.003, base), (f(lx * w) + 0.004, base - s * 0.55), (f(lx * w) - 0.004, base - s * 0.55)], blur=0.3))
    for m in legs:
        r.shaded(m, shade(col, -0.08), light, 0.2)
    body = r.ellipse(x, base - s * 0.7, w * 0.55, s * 0.22)
    neck = r.poly([(f(w * 0.3), base - s * 0.8), (f(w * 0.55), base - s * 1.25), (f(w * 0.7), base - s * 1.18), (f(w * 0.55), base - s * 0.62)])
    head = r.ellipse(f(w * 0.75), base - s * 1.12, w * 0.17, s * 0.08, angle=(-0.9 if flip else 0.9))
    r.shaded(np.maximum(np.maximum(body, neck), head), col, light, 0.22, rim=0.2)
    r.put(mane, r.lines([[(f(w * 0.32), base - s * 0.86), (f(w * 0.45), base - s * 1.1), (f(w * 0.58), base - s * 1.27)]], max(2, s * r.h * 0.05)))
    r.put(mane, r.lines([[(f(-w * 0.53), base - s * 0.78), (f(-w * 0.7), base - s * 0.5), (f(-w * 0.66), base - s * 0.3)]], max(2, s * r.h * 0.05)))
    r.mark_detail(head, 0.4)
    if rider is not None:
        figure(r, f(w * 0.0), base - s * 0.85, s * 0.9, rider, seated=True)


def deer(r, x, base, size, col="#c9a98a", flip=False, stag=False, light=(-0.6, -0.5)):
    w = size * r.h / r.w
    f = (lambda d: x - d) if flip else (lambda d: x + d)
    for lx in (-0.38, -0.28, 0.3, 0.4):
        r.put(shade(col, -0.15), r.poly([(f(lx * w) - 0.002, base), (f(lx * w) + 0.002, base), (f(lx * w) + 0.003, base - size * 0.6), (f(lx * w) - 0.003, base - size * 0.6)], blur=0.3))
    body = r.ellipse(x, base - size * 0.72, w * 0.48, size * 0.18)
    neck = r.poly([(f(w * 0.28), base - size * 0.8), (f(w * 0.45), base - size * 1.25), (f(w * 0.58), base - size * 1.2), (f(w * 0.48), base - size * 0.66)])
    head = r.ellipse(f(w * 0.6), base - size * 1.22, w * 0.12, size * 0.06, angle=(-0.5 if flip else 0.5))
    r.shaded(np.maximum(np.maximum(body, neck), head), col, light, 0.22, rim=0.2)
    r.put("#fbf3ea", r.ellipse(f(-w * 0.45), base - size * 0.78, w * 0.05, size * 0.06))
    if stag:
        segs = []
        for side in (-1, 1):
            bx, by = f(w * 0.52), base - size * 1.3
            segs.append([(bx, by), (f(w * (0.48 + side * 0.08)), by - size * 0.3), (f(w * (0.44 + side * 0.15)), by - size * 0.48)])
            segs.append([(f(w * (0.48 + side * 0.08)), by - size * 0.3), (f(w * (0.58 + side * 0.1)), by - size * 0.38)])
        r.put("#e8d8c0", r.lines(segs, max(1, size * r.h * 0.025)))
    r.mark_detail(head, 0.4)


def fox(r, x, base, size, flip=False, col="#e8875a", light=(-0.6, -0.5)):
    w = size * r.h / r.w
    f = (lambda d: x - d) if flip else (lambda d: x + d)
    body = r.ellipse(x, base - size * 0.45, w * 0.45, size * 0.2)
    head = r.poly([(f(w * 0.35), base - size * 0.65), (f(w * 0.8), base - size * 0.55), (f(w * 0.45), base - size * 0.4)])
    ears = r.poly([(f(w * 0.4), base - size * 0.62), (f(w * 0.45), base - size * 0.85), (f(w * 0.52), base - size * 0.64)])
    tail = r.ellipse(f(-w * 0.6), base - size * 0.42, w * 0.32, size * 0.12, angle=(0.4 if flip else -0.4))
    r.shaded(np.maximum.reduce([body, head, ears, tail]), col, light, 0.25, rim=0.2)
    r.put("#fbf3ea", r.ellipse(f(-w * 0.88), base - size * 0.5, w * 0.06, size * 0.06))
    for lx in (-0.3, 0.3):
        r.put("#4a3c44", r.poly([(f(lx * w) - 0.002, base), (f(lx * w) + 0.002, base), (f(lx * w) + 0.002, base - size * 0.3), (f(lx * w) - 0.002, base - size * 0.3)], blur=0.3))
    r.mark_detail(head, 0.4)


def hare(r, x, base, size, col="#c9a98a", flip=False):
    w = size * r.h / r.w
    f = (lambda d: x - d) if flip else (lambda d: x + d)
    m = np.maximum.reduce([r.ellipse(x, base - size * 0.35, w * 0.35, size * 0.3), r.circle(f(w * 0.35), base - size * 0.65, size * 0.16),
                           r.ellipse(f(w * 0.3), base - size * 1.0, w * 0.05, size * 0.25, angle=(0.3 if flip else -0.3))])
    r.shaded(m, col, k=0.25, rim=0.2)


def swan(r, x, y, size, flip=False, col="#fbf8f6"):
    w = size * r.h / r.w
    f = (lambda d: x - d) if flip else (lambda d: x + d)
    body = r.ellipse(x, y - size * 0.25, w * 0.5, size * 0.22)
    neck = r.lines([[(f(w * 0.3), y - size * 0.35), (f(w * 0.42), y - size * 0.75), (f(w * 0.32), y - size * 1.05), (f(w * 0.45), y - size * 1.1)]], max(2, size * r.h * 0.09))
    r.shaded(np.maximum(body, neck), col, k=0.15, rim=0.2)
    r.put("#f29a52", r.poly([(f(w * 0.45), y - size * 1.12), (f(w * 0.6), y - size * 1.05), (f(w * 0.45), y - size * 1.04)]))


def bird(r, x, y, size, col="#5a4a6a"):
    w = size * r.h / r.w
    r.put(col, r.lines([[(x - w, y - size * 0.2), (x - w * 0.4, y - size * 0.45), (x, y)], [(x, y), (x + w * 0.4, y - size * 0.45), (x + w, y - size * 0.2)]], max(1, size * r.h * 0.12)))


def butterfly(r, x, y, size, col):
    w = size * r.h / r.w
    for s in (-1, 1):
        r.put(col, r.ellipse(x + s * w * 0.5, y - size * 0.2, w * 0.5, size * 0.45, angle=s * 0.4))
        r.put(shade(col, 0.2), r.ellipse(x + s * w * 0.4, y + size * 0.3, w * 0.32, size * 0.3, angle=-s * 0.4))
    r.put("#3a2e40", r.ellipse(x, y, w * 0.08, size * 0.5))
    r.mark_detail(r.circle(x, y, size), 0.5)


# ------------------------------------------------------------------ figures (small, in landscapes)

def figure(r, x, base, height, col, seated=False, gown=True, mask=None, skin="#f2d2c0", hair="#7a5a48", arms_up=False, light=(-0.6, -0.5)):
    """A small figure: head, bodice, a flared gown or a coat and legs."""
    w = height * r.h / r.w
    head_r = height * 0.075
    hy = base - height + head_r
    if seated:
        body = r.poly([(x - w * 0.12, hy + head_r), (x + w * 0.12, hy + head_r), (x + w * 0.18, base), (x - w * 0.18, base)])
        r.shaded(body, col, light, 0.25)
    elif gown:
        bod = r.poly([(x - w * 0.08, hy + head_r * 1.3), (x + w * 0.08, hy + head_r * 1.3), (x + w * 0.06, base - height * 0.55), (x - w * 0.06, base - height * 0.55)])
        skirt = r.poly([(x - w * 0.06, base - height * 0.56), (x + w * 0.06, base - height * 0.56), (x + w * 0.26, base), (x - w * 0.26, base)])
        r.shaded(np.maximum(bod, skirt), col, light, 0.28, rim=0.2)
    else:
        coat = r.poly([(x - w * 0.1, hy + head_r * 1.3), (x + w * 0.1, hy + head_r * 1.3), (x + w * 0.12, base - height * 0.42), (x - w * 0.12, base - height * 0.42)])
        r.shaded(coat, col, light, 0.28, rim=0.2)
        for s in (-1, 1):
            r.put(shade(col, -0.35), r.poly([(x + s * w * 0.06 - w * 0.03, base - height * 0.43), (x + s * w * 0.06 + w * 0.03, base - height * 0.43), (x + s * w * 0.07 + w * 0.025, base), (x + s * w * 0.07 - w * 0.025, base)], blur=0.3))
    if arms_up:
        r.put(skin, r.lines([[(x - w * 0.07, hy + head_r * 1.6), (x - w * 0.16, hy - head_r * 0.5)], [(x + w * 0.07, hy + head_r * 1.6), (x + w * 0.16, hy - head_r * 0.5)]], max(1, height * r.h * 0.03)))
    r.shaded(r.circle(x, hy, head_r), skin, light, 0.2)
    r.put(hair, r.ellipse(x, hy - head_r * 0.35, head_r * 1.05 * r.h / r.w, head_r * 0.75))
    if mask:
        r.put(mask, r.ellipse(x, hy - head_r * 0.05, head_r * 0.95 * r.h / r.w, head_r * 0.35))
    r.mark_detail(r.circle(x, hy, head_r * 1.3), 0.5)
