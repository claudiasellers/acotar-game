"""The seeded layout of the court's hostile camps (lane L91, docs/contracts/hostiles.md).

gen_hostile_sites.py owns the output; this module only decides where the
generated camps go, so there is one generator and one table. Each region gets a
quota per family (the owner's size ladder, plan section 2 rule 9: about half
common gloamer packs, a third naga, a fifth small briarlings, the one Hob), and
every camp is anchored to a reason a player can read:

  naga       on the bank of a named water (the Thornwater, a brook, a lake, the
             eastern stream), 8-35 m from it, at dusk out of the reeds;
  gloamer    a wood-edge nook, a landmark's outskirts or a ride off a road,
             50-180 m from the nearest road so the pack reads from the way;
  briarling  inside a rose zone (Rosewild, the vale's and meadow's brakes).

Candidates are scored (sightline band to a road, nearness to the anchor,
clearance) and picked greedily with a fixed seed, checked as they go against
the same overlap rules the generator enforces, plus landmark keep-outs.
"""

import math
import os
import random
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SEED = 9100
LEASH_SCALE = 1.6
CORRIDOR = 60.0

# Region rects from docs/contracts/world.md section 1: (min_x, max_x, min_z, max_z).
REGIONS = {
    "border_woods": [(-700, 500, 500, 1400), (-700, -600, 300, 500), (600, 500, 300, 500)],
    "eastern_woods": [(650, 1850, -650, 550)],
    "western_fells": [(-1800, -1500, -900, 1400), (-1500, -700, 600, 1400)],
    "starlight_glen": [(-1500, -600, -500, 600)],
    "fae_village": [(-1500, -600, -1250, -500)],
    "rosewild": [(-600, 500, -800, -500)],
    "solstice_meadow": [(-600, 300, -1350, -800)],
    "hill_of_the_rite": [(300, 1300, -1500, -700)],
    "blighted_reaches": [(-600, 1700, -1700, -1500), (-600, 300, -1700, -1350), (1300, 1700, -1500, -700)],
    "blossom_vale": [(500, 1500, 500, 1400)],
}

# Quotas of NEW camps per region and family, on top of the authored sites in
# gen_hostile_sites.SITES. With them the ladder is 30 gloamer packs (50%),
# 19 naga camps (32%), 10 briarling brakes (17%) and the one Hob.
QUOTA = {
    "border_woods": {"naga": 2, "gloamer": 2},
    "eastern_woods": {"naga": 1, "gloamer": 1},
    "western_fells": {"naga": 1, "gloamer": 2},
    "starlight_glen": {"naga": 4, "gloamer": 2, "briarling": 1},
    "fae_village": {"naga": 2, "gloamer": 2},
    "rosewild": {"naga": 1, "gloamer": 1, "briarling": 3},
    "solstice_meadow": {"gloamer": 2, "briarling": 2},
    "hill_of_the_rite": {"gloamer": 4, "briarling": 1},
    "blighted_reaches": {"gloamer": 4},
    "blossom_vale": {"naga": 3, "briarling": 2},
}

# The blight widens the hostile range in waves (plan section 6.2): few camps
# from naga_survived, more from P4 and P5, most once the glamour lifts. In
# phase order; every name is verbatim from the timeline (R2).
WAVES = ["naga_survived", "starlight_pool_found", "stranger_met", "bite_endured", "glamour_lifted",
         "solstice_danced"]
# Per region, how its new packs spread over the waves (weights, in WAVES order).
WAVE_BIAS = {
    "blighted_reaches": [0, 0, 1, 0, 3, 0],
    "hill_of_the_rite": [0, 0, 0, 1, 1, 0],
    "solstice_meadow": [0, 0, 0, 0, 0, 1],
}
DEFAULT_BIAS = [1, 1, 1, 0, 1, 0]

# Family shapes: territory radius, members (by wave index), roamer scene.
FAMILY = {
    "gloamer": {"radius": 35.0, "roamer": "gloamer_roamer", "count": [3, 4, 4, 4, 5, 5], "road": (62.0, 180.0)},
    "naga": {"radius": 35.0, "roamer": "naga_roamer", "count": [2, 2, 2, 2, 2, 2], "road": (60.0, 400.0)},
    "briarling": {"radius": 14.0, "roamer": "briarling_roamer", "count": [2, 2, 3, 3, 3, 3], "road": (30.0, 150.0)},
}

# Ground where no camp goes: (x, z, radius, why).
KEEP_OUT_CIRCLES = [
    (1560.0, -430.0, 330.0, "the Bogge's heart (eastern woods): its own dread, nothing else lives there"),
    (-420.0, 1000.0, 150.0, "the Bogge's hunt (border woods, P2 story beat)"),
    (-930.0, -800.0, 250.0, "the village green: folk live here"),
    (-150.0, -1060.0, 140.0, "the Solstice dance floor"),
    (690.0, -982.0, 120.0, "the Calanmai cave"),
    (650.0, -1050.0, 170.0, "the Calanmai bonfires and terraces"),
    (-830.0, 625.0, 230.0, "the Suriel's glade"),
    (-100.0, 1380.0, 160.0, "the wall gap"),
    # Ground too steep for a camp, found by tools/creatures/site_ground_probe.tscn
    # (a home point or camp piece over 35 degrees).
    (-1212.0, -90.0, 30.0, "Looking Lake's drop-off"),
    (197.0, -1593.0, 30.0, "the Hollow Steading's scarp"),
    (838.0, -1248.0, 25.0, "the stone ring's terrace edge"),
]
# Rects (min_x, max_x, min_z, max_z) where no camp goes.
KEEP_OUT_RECTS = [
    (-660.0, 660.0, -560.0, 560.0, "the manor estate and its ward veil"),
    (-1800.0, -600.0, -1700.0, -1250.0, "the sealed Autumn foothills"),
]
# Every camp keeps this far inside the map's walkable land.
WALK = (-1760.0, 1700.0, -1680.0, 1360.0)

ROSE_ZONES = [(-600, 500, -800, -500), (400, 650, -700, -500)]
# Brakes outside the Rosewild: the vale's rose glades and the meadow's briars.
BRAKE_POINTS = [
    ("vale_rose_glade", 1300.0, 700.0), ("vale_hedge_roses", 760.0, 1250.0), ("orchard_roses", 1420.0, 900.0),
    ("meadow_briars_west", -470.0, -1000.0), ("meadow_briars_east", 220.0, -1180.0),
    ("knoll_roses", -1250.0, 40.0), ("sycamore_briars", 1180.0, -900.0),
]


def _read(path):
    p = os.path.join(ROOT, path)
    return open(p).read() if os.path.exists(p) else ""


def _densify(pts, step=5.0):
    out = []
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(bx - ax, bz - az) / step))
        for i in range(n):
            t = i / n
            out.append((ax + (bx - ax) * t, az + (bz - az) * t))
    if pts:
        out.append(pts[-1])
    return out


def woods_ways():
    """The woods lanes' roads and paths (border and eastern woods), by control point.

    Their meander is at most 6 m; the keep-out margin covers it."""
    out = []
    for path in ("world/spring_court/border_woods/border_woods_terrain.gd",
                 "world/spring_court/eastern_woods/eastern_woods_terrain.gd"):
        text = _read(path)
        consts = {m.group(1): (float(m.group(2)), float(m.group(3)))
                  for m in re.finditer(r"const (\w+) := Vector[23]\((-?[\d.]+),\s*(-?[\d.]+)", text)}
        for m in re.finditer(r'"kind": &"(road|path)".*?PackedVector2Array\(\[(.*?)\]\)', text, re.S):
            pts = []
            for tok in re.finditer(r"Vector2\((-?[\d.]+),\s*(-?[\d.]+)\)|\b([A-Z_]{3,})\b", m.group(2)):
                if tok.group(3):
                    if tok.group(3) in consts:
                        pts.append(consts[tok.group(3)])
                else:
                    pts.append((float(tok.group(1)), float(tok.group(2))))
            name = os.path.basename(path).split("_terrain")[0] + "_" + m.group(1)
            out += [(name, x, z) for x, z in _densify(pts)]
    return out


def woods_landmarks():
    """Named places in the woods lanes' terrain (knolls, dells, the falls)."""
    out = []
    for path, names in (("world/spring_court/border_woods/border_woods_terrain.gd",
                         ["CROCUS_KNOLL", "FALLS_LIP", "WILLOW_GLEN", "FAELIGHT_HOLLOW", "BLUEBELL_DELL",
                          "MOONSTONE_RING", "GREAT_OAK"]),
                        ("world/spring_court/eastern_woods/eastern_woods_terrain.gd", ["STREAM_GLEN", "REED_MARSH"])):
        text = _read(path)
        for n in names:
            m = re.search(r"const %s := Vector[23]\((-?[\d.]+),\s*(-?[\d.]+)" % n, text)
            if m:
                out.append((n.lower(), float(m.group(1)), float(m.group(2))))
    return out


def court_places():
    """court_height.gd SITES: (id, x, z, region, kind) for landmark, anchor, nook and water."""
    out = []
    for m in re.finditer(r'&"(\w+)":\s*\[(-?[\d.]+),\s*(-?[\d.]+),\s*&"(\w+)",\s*&"(\w+)"\]',
                         _read("world/spring_court/wider/court_height.gd")):
        out.append((m.group(1), float(m.group(2)), float(m.group(3)), m.group(4), m.group(5)))
    return out


def waters():
    """Named water lines and shores as (name, points, keep) where keep is the
    channel's half-width plus its bank (no core inside it)."""
    out = []
    text = _read("world/shared/terrain/macro_height.gd")
    block = re.search(r"THORNWATER := PackedVector2Array\(\[(.*?)\]\)", text, re.S)
    if block:
        pts = [(float(a), float(b)) for a, b in re.findall(r"Vector2\((-?[\d.]+),\s*(-?[\d.]+)\)", block.group(1))]
        out.append(("the Thornwater", _densify(pts), 14.0))
    court = _read("world/spring_court/wider/court_height.gd")
    brooks = re.search(r"const BROOKS := \[(.*?)\n\]", court, re.S)
    if brooks:
        for m in re.finditer(r'\[&"(\w+)",\s*[\d.]+,\s*\[(.*?)\]\]', brooks.group(1)):
            pts = [(float(a), float(b)) for a, b in re.findall(r"\[(-?[\d.]+),\s*(-?[\d.]+)\]", m.group(2))]
            out.append((m.group(1).replace("_", " "), _densify(pts), 4.0))
    lakes = re.search(r"const LAKES := \[(.*?)\n\]", court, re.S)
    if lakes:
        for m in re.finditer(r'\[&"(\w+)",\s*(-?[\d.]+),\s*(-?[\d.]+),\s*([\d.]+)', lakes.group(1)):
            cx, cz, r = float(m.group(2)), float(m.group(3)), float(m.group(4))
            n = max(12, int(TAU * r / 5.0))
            ring = [(cx + math.cos(TAU * i / n) * r, cz + math.sin(TAU * i / n) * r) for i in range(n + 1)]
            out.append((m.group(1).replace("_", " "), ring, 2.0))
    east = _read("world/spring_court/eastern_woods/eastern_woods_terrain.gd")
    m = re.search(r'"kind": &"stream", "width": 7\.0.*?PackedVector2Array\(\[(.*?)\]\)', east, re.S)
    if m:
        pts = [(float(a), float(b)) for a, b in re.findall(r"Vector2\((-?[\d.]+),\s*(-?[\d.]+)\)", m.group(1))]
        out.append(("the glen stream", _densify(pts), 12.0))
    return out


TAU = math.tau


def region_of(x, z):
    for rid, rects in REGIONS.items():
        for x0, x1, z0, z1 in rects:
            if min(x0, x1) <= x <= max(x0, x1) and z0 <= z <= z1:
                return rid
    return None


def _in_rects(x, z, rects, margin=0.0):
    return any(r[0] - margin <= x <= r[1] + margin and r[2] - margin <= z <= r[3] + margin for r in rects)


def kept_out(x, z, leash):
    for cx, cz, r, _why in KEEP_OUT_CIRCLES:
        if math.hypot(x - cx, z - cz) < r + leash:
            return True
    for x0, x1, z0, z1, _why in KEEP_OUT_RECTS:
        if x0 - leash <= x <= x1 + leash and z0 - leash <= z <= z1 + leash:
            return True
    return not (WALK[0] + leash <= x <= WALK[1] - leash and WALK[2] + leash <= z <= WALK[3] - leash)


def _nearest(points, x, z):
    best, name = 1e9, ""
    for p in points:
        d = math.hypot(p[-2] - x, p[-1] - z)
        if d < best:
            best, name = d, p[0]
    return best, name


def _water_distance(water_lines, x, z):
    best, name = 1e9, ""
    for nm, pts, keep in water_lines:
        for px, pz in pts:
            d = math.hypot(px - x, pz - z) - keep
            if d < best:
                best, name = d, nm
    return best, name


# Members by water: the river and the glen stream hold a hunting party, a
# pool holds one.
NAGA_BY_WATER = {"the Thornwater": 3, "the glen stream": 3, "starlight pool": 1, "hollow pool": 1,
                 "mill pond": 1, "pond of watchers": 1}
# R9 headroom (gen_hostile_sites.budget): one member fewer in the two river
# parties that share a view in the border woods, the densest region.
TRIM = {"naga_great_oak": 2, "naga_willow_glen": 2}

# What a camp is called after its place: the first by a place takes the first
# word, a second by the same place the next (and so on).
NOUNS = {
    "naga": ["Reeds", "Shallows", "Bend", "Mudbank", "Sedge"],
    "gloamer": ["Edge", "Scrape", "Ride", "Run", "Rookery", "Lair"],
    "briarling": ["Brake", "Tangle", "Thicket"],
}


def _slug(text):
    slug = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
    return slug[4:] if slug.startswith("the_") else slug


def _title(text):
    words = text.replace("_", " ").split()
    keep = {"of", "the", "by", "at", "on"}
    return " ".join(w if (i and w in keep) else w[:1].upper() + w[1:] for i, w in enumerate(words))


def _wave_for(region, family, k, n):
    """Which wave (index into WAVES) the k-th of n new camps in a region gets."""
    if family == "naga":
        return 0  # naga wait for their canon meeting and no longer (plan rule 1)
    bias = list(WAVE_BIAS.get(region, DEFAULT_BIAS))
    if family == "briarling":
        bias[0] = 0  # the Rosewild's gate, P4 (bestiary section 7.1)
    pool = [w for w, c in enumerate(bias) for _ in range(c)] or [len(WAVES) - 1]
    return pool[(k * len(pool)) // n] if n > 1 else pool[-1]


def plan(authored, roads, anchors, stones):
    """New camps as SITES rows, plus a list of (id, reason) for the report.

    `authored` are gen_hostile_sites.SITES rows already placed; every new camp is
    checked against them and against each other."""
    rng = random.Random(SEED)
    names_used = {}
    places = court_places()
    lmarks = [(n, x, z) for n, x, z, _r, k in places if k in ("landmark", "anchor")] + woods_landmarks()
    nooks = [(n, x, z, r) for n, x, z, r, k in places if k == "nook"]
    water_lines = waters()
    named = [(n, x, z) for n, x, z, _r, k in places if k != "water"] + woods_landmarks()
    for a in authored:
        tail = a[0].split("_", 1)[1]
        if any(tail == q[0] for q in named):
            names_used[tail] = 1
    all_roads = [(n, x, z) for n, x, z in roads] + woods_ways()
    chosen = list(authored)
    out, reasons = [], []
    used_ids = {s[0] for s in authored}

    def clear(x, z, radius):
        leash = radius * LEASH_SCALE
        if kept_out(x, z, leash):
            return False
        for s in chosen:
            d = math.hypot(s[4][0] - x, s[4][1] - z)
            if d <= leash or d <= s[5] * LEASH_SCALE or d - radius - s[5] < CORRIDOR:
                return False
        for _n, px, pz in stones + anchors:
            if math.hypot(px - x, pz - z) <= leash + 4.0:
                return False
        for _n, px, pz in lmarks:
            if math.hypot(px - x, pz - z) <= leash + 6.0:
                return False
        for _n, px, pz in all_roads:
            if math.hypot(px - x, pz - z) <= leash + 8.0:
                return False
        return True

    def candidates(region, family):
        rects = REGIONS[region]
        out_c = []
        if family == "naga":
            for nm, pts, keep in water_lines:
                for i in range(0, len(pts) - 1, 3):
                    (ax, az), (bx, bz) = pts[i], pts[min(i + 1, len(pts) - 1)]
                    dx, dz = bx - ax, bz - az
                    ln = math.hypot(dx, dz) or 1.0
                    nx, nz = -dz / ln, dx / ln
                    for side in (1.0, -1.0):
                        off = keep + rng.uniform(10.0, 26.0)
                        x, z = ax + nx * off * side, az + nz * off * side
                        if region_of(x, z) == region:
                            out_c.append((x, z, f"the bank of {nm}", nm))
        else:
            step = 40.0
            for x0, x1, z0, z1 in rects:
                gx = min(x0, x1)
                while gx <= max(x0, x1):
                    gz = z0
                    while gz <= z1:
                        x, z = gx + rng.uniform(-14, 14), gz + rng.uniform(-14, 14)
                        if region_of(x, z) == region:
                            if family == "briarling":
                                bd, bname = _nearest([(n, bx, bz) for n, bx, bz in BRAKE_POINTS], x, z)
                                in_rose = _in_rects(x, z, ROSE_ZONES)
                                if in_rose or bd < 70.0:
                                    anchor = bname if not in_rose else _nearest([(n, nx_, nz_) for n, nx_, nz_, _r in nooks] + [(n, lx, lz) for n, lx, lz in lmarks], x, z)[1]
                                    out_c.append((x, z, "a rose brake" + (f" near {anchor}" if anchor else ""), anchor or region))
                            else:
                                nd, nname = _nearest([(n, nx_, nz_) for n, nx_, nz_, _r in nooks], x, z)
                                ld, lname = _nearest(lmarks, x, z)
                                if nd < 120.0:
                                    out_c.append((x, z, f"the wood edge by {nname}", nname))
                                elif ld < 260.0:
                                    out_c.append((x, z, f"the outskirts of {lname}", lname))
                                else:
                                    rd, rname = _nearest(all_roads, x, z)
                                    out_c.append((x, z, f"a ride off the {rname.replace('_', ' ')}", rname))
                        gz += step
                    gx += step
        return out_c

    def score(family, x, z, anchor_name):
        lo, hi = FAMILY[family]["road"]
        rd, _ = _nearest(all_roads, x, z)
        s = 0.0
        if lo <= rd <= hi:
            s += 3.0 - abs(rd - (lo + hi) * 0.5) / (hi - lo)  # a sightline from the way
        else:
            s -= 2.0
        if family == "naga":
            wd, _ = _water_distance(water_lines, x, z)
            s += 2.0 if 8.0 <= wd <= 35.0 else -10.0
        # Spread: favour ground far from every camp already placed.
        near = min([math.hypot(c[4][0] - x, c[4][1] - z) for c in chosen] or [1e4])
        s += min(near, 400.0) / 200.0
        return s + rng.random() * 0.5

    for region in REGIONS:
        for family, n in QUOTA.get(region, {}).items():
            pool = candidates(region, family)
            pool.sort(key=lambda c: -score(family, c[0], c[1], c[3]))
            k = 0
            for x, z, why, anchor in pool:
                if k >= n:
                    break
                radius = FAMILY[family]["radius"]
                if not clear(x, z, radius):
                    continue
                # Named for the nearest place a player knows that no camp is
                # named for yet (within half again the nearest's distance);
                # failing that, the nearest, with the family's next word.
                ranked = sorted(named, key=lambda q: math.hypot(q[1] - x, q[2] - z))
                near_d = math.hypot(ranked[0][1] - x, ranked[0][2] - z)
                place = ranked[0][0]
                for q in ranked:
                    if math.hypot(q[1] - x, q[2] - z) > max(300.0, near_d * 1.5):
                        break
                    if not names_used.get(q[0]):
                        place = q[0]
                        break
                j = names_used.get(place, 0)
                names_used[place] = j + 1
                noun = NOUNS[family][j % len(NOUNS[family])]
                sid = f"{family}_{_slug(place)}" + ("" if j == 0 else f"_{_slug(noun)}")
                base, i = sid, 2
                while sid in used_ids:
                    sid, i = f"{base}_{i}", i + 1
                title = f"{_title(place)} {noun}"
                wave = _wave_for(region, family, k, n)
                count = FAMILY[family]["count"][wave]
                if family == "naga":
                    count = NAGA_BY_WATER.get(anchor, count)
                count = TRIM.get(sid, count)
                row = (sid, family, title, region, (round(x, 1), round(z, 1)), radius,
                       FAMILY[family]["roamer"], count, [WAVES[wave]], "X")
                chosen.append(row)
                out.append(row)
                used_ids.add(sid)
                reasons.append((sid, f"{why} ({title})"))
                k += 1
            if k < n:
                reasons.append((f"{region}/{family}", f"SHORT: placed {k} of {n}"))
    return out, reasons


# --- camp gear (CampDressing, creatures/hostile/camp_dressing.gd) -------------
# Kits of L88's camp pieces: (model id, bearing, radius m, yaw). The bearing is
# relative to the camp's approach (toward the nearest road, so the far tell
# faces the way); a bearing in WATER_KITS is relative to the water instead.
# The loot container is L75's (CampContainer) and not listed here.
KITS = {
    "gloamer": [
        [("camp_gloamer_rag_nest", 0.0, 0.0, 0.0), ("camp_gloamer_squabble_pile", 2.2, 5.5, 0.7),
         ("camp_gloamer_shiny_line", -2.0, 6.5, 0.0), ("camp_gloamer_trinket_cords", 0.0, 13.0, 1.5708),
         ("camp_skull_stake", 0.35, 18.0, 0.0)],
        [("camp_gloamer_rag_nest", 0.5, 2.5, 0.4), ("camp_hide_lean_to", 3.14159, 6.0, 3.14159),
         ("camp_gloamer_shiny_line", -1.4, 6.0, 0.9), ("camp_gloamer_squabble_pile", 1.6, 7.0, -0.5),
         ("camp_bone_totem", 0.0, 16.0, 0.0)],
        [("camp_gloamer_rag_nest", 0.8, 3.0, 0.0), ("camp_gloamer_rag_nest", -2.4, 3.5, 1.9),
         ("camp_gloamer_trinket_cords", 3.44, 10.0, 1.2), ("camp_gloamer_squabble_pile", -0.9, 6.5, 0.3),
         ("camp_skull_stake", 0.0, 17.0, 0.0)],
    ],
    "naga": [
        [("camp_naga_reed_nest", 0.0, 0.0, 0.0), ("camp_naga_basking_stone", 0.0, 9.0, 0.6),
         ("camp_naga_midden", 1.6, 6.5, 0.0)],
        [("camp_naga_reed_nest", 0.4, 2.0, 1.1), ("camp_naga_basking_stone", -0.5, 8.0, 0.0),
         ("camp_naga_basking_stone", 0.7, 11.0, 2.2), ("camp_naga_midden", 3.14159, 6.0, 0.8)],
    ],
    "briarling": [
        [("camp_briar_uprooted_ring", 0.0, 0.0, 0.0), ("camp_briar_thorn_cage", 1.3, 5.0, 0.0)],
        [("camp_briar_uprooted_ring", 0.0, 0.0, 1.0), ("camp_briar_thorn_cage", 1.3, 5.0, 0.0),
         ("camp_briar_thorn_cage", -2.0, 6.0, 2.0)],
    ],
    # The Hob's hollow: what it ate. Its sleep stone waits on the Hob lying on
    # its rest point (a follow-up for L75's HobRoamer), so it is left out.
    "hob": [
        [("camp_hob_sheep_bones", 1.2, 7.0, 0.3), ("camp_hob_sheep_bones", -2.2, 9.0, 2.0)],
    ],
}
WATER_KITS = {"naga"}


def kit_for(site, roads, water_lines=None):
    """(ids, offsets, yaws) for a site row: its family's kit, picked by its id,
    turned to its approach (or its water, for the naga)."""
    sid, family, core = site[0], site[1], site[4]
    kits = KITS.get(family)
    if not kits:
        return [], [], []
    kit = kits[sum(ord(c) for c in sid) % len(kits)]
    x, z = core
    if family in WATER_KITS:
        _d, _n, wx, wz = _nearest_water_point(water_lines if water_lines is not None else waters(), x, z)
        a0 = math.atan2(wz - z, wx - x)
    else:
        best, a0 = 1e9, 0.0
        for _n, px, pz in roads:
            d = math.hypot(px - x, pz - z)
            if d < best:
                best, a0 = d, math.atan2(pz - z, px - x)
    ids, offs, yaws = [], [], []
    for mid, bearing, r, yaw in kit:
        a = a0 + bearing
        ids.append(mid)
        offs.append((round(math.cos(a) * r, 2), round(math.sin(a) * r, 2)))
        # rotation.y that turns a piece's front (-Z) to face out from the core
        # along its bearing, then the kit's own turn.
        yaws.append(round(math.atan2(-math.cos(a), -math.sin(a)) + yaw, 3))
    return ids, offs, yaws


def _nearest_water_point(water_lines, x, z):
    best = (1e9, "", x + 1.0, z)
    for nm, pts, keep in water_lines:
        for px, pz in pts:
            d = math.hypot(px - x, pz - z) - keep
            if d < best[0]:
                best = (d, nm, px, pz)
    return best


def all_roads(roads):
    """Court roads plus the woods lanes' ways, as (name, x, z)."""
    return list(roads) + woods_ways()
