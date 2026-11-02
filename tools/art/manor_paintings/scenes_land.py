"""Landscapes, pastorals and outdoor genre scenes (festivals, hunts, history
out of doors). A recipe dict drives each one; see catalog.py for the keys."""

import random

import numpy as np

import motifs as M
from painter import mix, shade

FEATURES = {}


def feature(name):
    def deco(fn):
        FEATURES[name] = fn
        return fn
    return deco


def landscape(r, p):
    """Back to front: sky, far range, hills, water, groves, the feature, the
    near meadow, animals and figures, then light effects."""
    rng = random.Random(p["seed"])
    time = p.get("time", "golden")
    season = p.get("season", "spring")
    s = M.SEASONS[season]
    # composition varies by seed unless the recipe fixes it: a high or low
    # horizon, and often a big framing tree (repoussoir) on one side
    horizon = p.get("horizon", round(rng.uniform(0.44, 0.62), 3))
    if "near_trees" not in p and p.get("frame_tree", rng.random() < 0.6) and p.get("far") not in ("cliffs", "peak"):
        side = rng.choice([0.04, 0.1, 0.9, 0.96])
        kinds = [k for k in p.get("trees", ["blossom", "round"]) if k != "birch"] or ["round"]
        p = dict(p, near_trees=[(side, rng.choice(kinds))], near_tree_h=rng.uniform(0.62, 0.85))
        if p.get("avoid") is None:
            p["avoid"] = (side - 0.12, side + 0.12)
    M.sky(r, time, p["seed"], p.get("clouds", 0.5), horizon + 0.08, swirl=p.get("eye") == "fae")
    if time in ("night", "twilight"):
        M.stars(r, p["seed"] + 1, int(140 * (1.0 if time == "night" else 0.4)), horizon)
    sx, sy = p.get("sun_at", (rng.uniform(0.25, 0.75), horizon - 0.12))
    if time in ("night", "twilight") and p.get("moon", True):
        M.moon(r, sx, max(0.1, sy - 0.15), 0.045, crescent=p.get("crescent", False))
    elif time not in ("storm", "overcast") and p.get("show_sun", True):
        M.sun(r, sx, sy, 0.035 if time in ("dawn", "golden", "dusk") else 0.025, time)
    far = p.get("far", "hills")
    if far == "mountains":
        M.mountains(r, p["seed"] + 2, horizon + 0.02, p.get("mount_h", 0.22), p.get("mount_col", "#9a8fc8"), time, snow=season != "summer" or True)
    elif far == "peak":
        _lone_peak(r, p, horizon, time)
    elif far == "sea":
        M.water(r, horizon - 0.01, horizon + 0.12, time, p["seed"], col=p.get("sea_col"))
    elif far == "cliffs":
        M.water(r, horizon - 0.01, 1.0, time, p["seed"], col=p.get("sea_col", "#8fd0d8"))
        M.land_layer(r, M.ridge(p["seed"] + 3, horizon + 0.05, 0.25, 1.2, True), "#e8c8b8", "#c8a0a0", M.TIMES[time]["haze"], 0.25)
    if far not in ("sea", "cliffs"):
        M.hills(r, p["seed"] + 4, horizon + 0.05, 0.08, [mix(s["grass"][1], "#8fa8d8", 0.3), s["grass"][0]], time, 0.45)
    if p.get("mid_trees", True):
        M.grove(r, p["seed"] + 5, p.get("mid_n", 10), horizon + 0.06, horizon + 0.13, 0.07, 0.13,
                p.get("trees", ["blossom", "round"]), season, time, avoid=p.get("avoid"))
    near = p.get("near_top", 0.8)
    if p.get("water") == "lake":
        M.water(r, horizon + 0.1, near + 0.02, time, p["seed"] + 6, col=p.get("lake_col"))
    else:
        M.hills(r, p["seed"] + 7, horizon + 0.2, 0.05, [s["grass"][2], s["grass"][0]], time, 0.15, freq=1.1)
        if p.get("water") == "river":
            _river(r, p, horizon, time)
    for fname in p.get("features", []):
        FEATURES[fname](r, p, horizon, time, season)
    M.meadow(r, near, season, time, p["seed"] + 8, p.get("flowers", 0.35), p.get("flower_cols"))
    M.foreground_shade(r, near, p.get("fore_shade", 0.2))
    if p.get("near_trees"):
        for i, (x, kind) in enumerate(p["near_trees"]):
            M.tree(r, x, 1.02, p.get("near_tree_h", 0.62), kind, season, time, p["seed"] + 30 + i)
    for fname in p.get("fore", []):
        FEATURES[fname](r, p, horizon, time, season)
    if p.get("_overlay"):
        p["_overlay"](r)  # build.py: a Blender tableau, under the light effects
    _fx(r, p, time, horizon)


def _fx(r, p, time, horizon):
    fx = p.get("fx", [])
    seed = p["seed"]
    if "rays" in fx:
        sx, sy = p.get("sun_at", (0.5, horizon - 0.12))
        M.rays(r, sx, sy, time, 8, seed)
    if "mist" in fx:
        M.mist(r, horizon + 0.12, 0.08, M.TIMES[time]["haze"], seed, 0.55)
    if "petals" in fx:
        M.petals(r, seed + 3, 60)
    if "faelights" in fx:
        M.faelights(r, seed + 4, 26, (0.05, horizon - 0.1, 0.95, 0.95))
    if "wisps" in fx:
        M.faelights(r, seed + 5, 40, (0.05, horizon + 0.05, 0.95, 0.9), ("#d8fff0", "#bfe8ff", "#fff6c8"))
    if "snow" in fx:
        M.snowfall(r, seed + 6, 220)
    if "butterflies" in fx:
        rng = random.Random(seed + 7)
        for _ in range(6):
            M.butterfly(r, rng.uniform(0.1, 0.9), rng.uniform(0.45, 0.85), 0.018, rng.choice(["#c8b6f2", "#f6a6c6", "#fff1a8", "#a8d8f0"]))
    if "fireflies" in fx:
        M.faelights(r, seed + 8, 50, (0, horizon, 1, 1), ("#fff2a0", "#ffe080"))


def _river(r, p, horizon, time):
    rng = random.Random(p["seed"] + 9)
    pts_l, pts_r = [], []
    x = p.get("river_x", 0.5)
    for i in range(12):
        t = i / 11
        y = horizon + 0.1 + t * (1.0 - horizon - 0.1)
        x += rng.uniform(-0.03, 0.03)
        hw = 0.01 + t * 0.12
        pts_l.append((x - hw, y))
        pts_r.append((x + hw, y))
    m = r.poly(pts_l + pts_r[::-1], blur=1.0)
    sky = mix(M.TIMES[time]["sky"][-1][1], "#a8c8f0", 0.3)
    img = np.empty((r.h, r.w, 3), np.float32)
    img[:] = sky
    streak = (np.sin(r.v * 700 + r.noise(8.0, p["seed"], 2) * 25) > 0.8).astype(np.float32)[..., None]
    img = img + (np.array([1, 1, 1], np.float32) - img) * streak * 0.35
    r.put(img, m)


def _lone_peak(r, p, horizon, time):
    """A mammoth, solitary peak, bald of snow, bald of life (ch13): the
    mountain at the heart of Prythian, unnamed."""
    M.mountains(r, p["seed"] + 2, horizon + 0.02, 0.1, "#a8a8d0", time, snow=True, haze_k=0.6)
    cx = p.get("peak_x", 0.5)
    m = r.poly([(cx - 0.22, horizon + 0.03), (cx - 0.05, horizon - 0.38), (cx + 0.02, horizon - 0.41), (cx + 0.24, horizon + 0.03)], blur=1.0)
    r.shaded(m, mix("#4a3e52", M.TIMES[time]["haze"], 0.15), (-0.7, -0.3), 0.25)


# ------------------------------------------------------------------ features

@feature("manor")
def _manor(r, p, horizon, time, season):
    M.manor(r, p.get("manor_x", 0.5), horizon + 0.15, p.get("manor_w", 0.42), time, p["seed"] + 11)


@feature("cottage")
def _cottage(r, p, horizon, time, season):
    M.cottage(r, p.get("cottage_x", 0.3), horizon + 0.17, 0.07, time, snow=season == "winter")


@feature("ruin")
def _ruin(r, p, horizon, time, season):
    M.ruin(r, p.get("ruin_x", 0.62), horizon + 0.18, 0.13, time, p["seed"] + 12)


@feature("bridge")
def _bridge(r, p, horizon, time, season):
    M.bridge(r, p.get("bridge_x", 0.5), horizon + 0.22, 0.28, time)


@feature("tower")
def _tower(r, p, horizon, time, season):
    M.tower(r, p.get("tower_x", 0.7), horizon + 0.12, 0.28, time, p.get("roof", "#b8a8e0"))


@feature("wall")
def _wall(r, p, horizon, time, season):
    M.wall_veil(r, p.get("wall_x", 0.55), time, p["seed"] + 13, p.get("wall_k", 0.6))


@feature("stones")
def _stones(r, p, horizon, time, season):
    rng = random.Random(p["seed"] + 14)
    cx = p.get("stones_x", 0.5)
    for i in range(7):
        x = cx + (i - 3) * 0.045 + rng.uniform(-0.01, 0.01)
        hh = rng.uniform(0.05, 0.09)
        b = horizon + 0.16 + abs(i - 3) * 0.004
        r.shaded(r.poly([(x - 0.012, b), (x + 0.012, b), (x + 0.009, b - hh), (x - 0.01, b - hh * 0.95)]), mix("#c8c0d0", M.TIMES[time]["haze"], 0.2), (-0.7, -0.3), 0.25)


@feature("bonfire")
def _bonfire(r, p, horizon, time, season):
    M.bonfire(r, p.get("fire_x", 0.5), p.get("fire_y", horizon + 0.2), p.get("fire_size", 0.12), p["seed"] + 15)


@feature("dancers")
def _dancers(r, p, horizon, time, season):
    rng = random.Random(p["seed"] + 16)
    cx, cy = p.get("fire_x", 0.5), p.get("fire_y", horizon + 0.2)
    n = p.get("dancers_n", 10)
    for i in range(n):
        a = i / n * 6.28
        x = cx + np.cos(a) * 0.28
        y = cy + 0.05 + np.sin(a) * 0.06
        dark = M.TIMES[time]["dark"] > 0.3
        col = "#2c2440" if dark else rng.choice(["#f6a6c6", "#c8b6f2", "#a8d8f0", "#fff1a8"])
        M.figure(r, x, y + 0.08, 0.12 + (np.sin(a) * 0.03), col, gown=rng.random() < 0.6,
                 skin="#3a2e44" if dark else "#f2d2c0", hair="#2a2238" if dark else "#7a5a48", arms_up=rng.random() < 0.5)


@feature("lambs")
def _lambs(r, p, horizon, time, season):
    rng = random.Random(p["seed"] + 17)
    for i in range(p.get("lambs_n", 5)):
        y = rng.uniform(0.78, 0.94)
        M.lamb(r, rng.uniform(0.1, 0.9), y, 0.06 + (y - 0.78) * 0.5, flip=rng.random() < 0.5)


@feature("deer")
def _deer(r, p, horizon, time, season):
    rng = random.Random(p["seed"] + 18)
    for i in range(p.get("deer_n", 3)):
        y = rng.uniform(0.86, 0.97)
        M.deer(r, rng.uniform(0.15, 0.85), y, 0.13 + (y - 0.86) * 0.6, flip=rng.random() < 0.5, stag=i == 0 and p.get("stag", True))


@feature("mare")
def _mare(r, p, horizon, time, season):
    M.horse(r, p.get("mare_x", 0.4), p.get("mare_y", 0.9), p.get("mare_s", 0.2), flip=p.get("mare_flip", False),
            rider=p.get("rider"))


@feature("riders")
def _riders(r, p, horizon, time, season):
    rng = random.Random(p["seed"] + 19)
    for i in range(p.get("riders_n", 3)):
        x = 0.2 + i * 0.25 + rng.uniform(-0.04, 0.04)
        y = 0.82 + rng.uniform(-0.03, 0.05)
        M.horse(r, x, y, 0.17, col=rng.choice(["#faf6f2", "#c9a98a", "#8e6a6e", "#e8dcd8"]), flip=False,
                rider=rng.choice(["#6fa889", "#c8506a", "#7a90c8", "#d8a050"]))
    for i in range(p.get("hounds_n", 4)):
        M.fox(r, 0.5 + i * 0.1 + rng.uniform(-0.03, 0.03), 0.92 + rng.uniform(-0.02, 0.02), 0.05, col="#e8dcd0")


@feature("swans")
def _swans(r, p, horizon, time, season):
    rng = random.Random(p["seed"] + 20)
    for i in range(p.get("swans_n", 3)):
        M.swan(r, rng.uniform(0.2, 0.8), horizon + 0.2 + rng.uniform(0, 0.04), 0.05, flip=rng.random() < 0.5)


@feature("strollers")
def _strollers(r, p, horizon, time, season):
    rng = random.Random(p["seed"] + 21)
    for i in range(p.get("strollers_n", 3)):
        y = rng.uniform(0.82, 0.95)
        M.figure(r, rng.uniform(0.15, 0.85), y, 0.22 + (y - 0.82) * 0.8, rng.choice(["#f6a6c6", "#c8b6f2", "#a8d8f0", "#fff1a8", "#b5e3c0"]),
                 gown=rng.random() < 0.6, mask=rng.choice([None, "#e6c068", "#7cc29a"]) if p.get("masked") else None)


@feature("picnic")
def _picnic(r, p, horizon, time, season):
    r.put("#f8d8e4", r.poly([(0.35, 0.86), (0.65, 0.86), (0.7, 0.95), (0.3, 0.95)]))
    for i, x in enumerate((0.4, 0.5, 0.58)):
        M.figure(r, x, 0.93, 0.17, ["#c8b6f2", "#a8d8f0", "#f6a6c6"][i], seated=True)
    r.put("#e6c068", r.circle(0.46, 0.9, 0.012))


@feature("boat")
def _boat(r, p, horizon, time, season):
    y = horizon + 0.21
    r.shaded(r.poly([(0.38, y - 0.02), (0.56, y - 0.02), (0.53, y + 0.01), (0.41, y + 0.01)]), "#f3a8c0", k=0.2)
    M.figure(r, 0.45, y - 0.015, 0.09, "#c8b6f2", seated=True)
    M.figure(r, 0.5, y - 0.015, 0.09, "#a8d8f0", seated=True, gown=False)


@feature("battle")
def _battle(r, p, horizon, time, season):
    """The War (ch13 mural: bloodied mud; human soldiers facing High Fae in
    their glimmering armour, faeries with claws and fangs). Not softened."""
    rng = random.Random(p["seed"] + 22)
    mud = "#4a3036"
    r.put(mud, r.below(lambda u: horizon + 0.2 + 0.02 * np.sin(u * 9)))
    for i in range(30):
        x, y = rng.random(), rng.uniform(horizon + 0.22, 1.0)
        r.put(rng.choice(["#7a1f2c", "#5a1a24", "#3a2228"]), r.ellipse(x, y, rng.uniform(0.01, 0.05), rng.uniform(0.004, 0.012)), alpha=0.7)
    for side in (0, 1):
        for i in range(18):
            x = (0.05 + rng.uniform(0, 0.4)) if side == 0 else (0.55 + rng.uniform(0, 0.4))
            y = rng.uniform(horizon + 0.25, 0.98)
            hgt = 0.08 + (y - horizon) * 0.3
            if side == 0:
                M.figure(r, x, y, hgt, rng.choice(["#6a5a50", "#5a4a48", "#7a6658"]), gown=False, skin="#d8b8a0", hair="#4a3a34")
            else:
                M.figure(r, x, y, hgt * 1.1, rng.choice(["#d8dcf0", "#e6c068", "#c8d0e8"]), gown=False, skin="#f2e2d8", hair="#e8e0f0")
                r.put("#ffffff", r.circle(x, y - hgt * 0.6, 0.004), alpha=0.8)
    for x in (0.2, 0.75):
        r.put("#2a1e24", r.lines([[(x, horizon + 0.25), (x + 0.01, horizon - 0.1)]], 3))
        r.put("#8a2030" if x < 0.5 else "#e6c068", r.poly([(x + 0.01, horizon - 0.1), (x + 0.09, horizon - 0.08), (x + 0.01, horizon - 0.04)]))
    M.mist(r, horizon + 0.15, 0.1, "#6e5a68", p["seed"], 0.5)


@feature("signing")
def _signing(r, p, horizon, time, season):
    """The Treaty: two delegations at a long table under a pavilion."""
    r.shaded(r.poly([(0.15, 0.78), (0.85, 0.78), (0.82, 0.86), (0.18, 0.86)]), "#f6efe6", k=0.12)
    r.put("#e6c068", r.poly([(0.1, horizon - 0.05), (0.9, horizon - 0.05), (0.5, horizon - 0.22)]))
    for x in (0.12, 0.88):
        r.put("#f6efe6", r.poly([(x - 0.01, 0.86), (x + 0.01, 0.86), (x + 0.01, horizon - 0.05), (x - 0.01, horizon - 0.05)]))
    for i in range(5):
        M.figure(r, 0.2 + i * 0.06, 0.8, 0.2, ["#7a6658", "#6a5a50"][i % 2], gown=False, skin="#d8b8a0", hair="#5a4034")
        M.figure(r, 0.56 + i * 0.06, 0.8, 0.23, ["#c8b6f2", "#e6c068", "#a8d8f0"][i % 3], gown=i % 2 == 0, skin="#f2e2d8", hair="#e8d8c0")
    r.put("#fbf3e4", r.poly([(0.46, 0.79), (0.54, 0.79), (0.55, 0.81), (0.45, 0.81)]))
