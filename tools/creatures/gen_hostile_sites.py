"""Writes the hostile-fae sites and roamer data (docs/contracts/hostiles.md).

Run: python3 tools/creatures/gen_hostile_sites.py
Edit SITES / ROAMERS below, rerun, commit the outputs. Never edit the outputs.

Writes:
  data/creatures/hostile/<roamer>.tres         CreatureData for each roamer
  creatures/hostile/<roamer>.tscn              the roamer scene
  data/creatures/hostile_sites/<site>.tres     HostileSiteData
  creatures/hostile/sites/<site>.tscn          a HostileSite holding that data

SPAWN (region -> entries) is read by gen_spawn_tables.py, which appends one
all-day SpawnEntry per site to that region's table, gated on the site's flags.

Fails (exit 1) when a layout breaks the overlap rules (plan section 4.1):
  1. no leash ring reaches another site's core, unless the pair is in PAIRS;
  2. every pair of sites keeps a >= 60 m corridor beyond both territories;
  3. no leash ring covers a road point, a whorl stone or a story anchor.
Roads and anchors are read from world/spring_court/wider/court_height.gd,
whorl stones from tools/fast_travel/place_whorl_stones.gd, so moving one of
those re-runs the check against the new ground.
"""

import math
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA_ROAMERS = os.path.join(ROOT, "data", "creatures", "hostile")
DATA_SITES = os.path.join(ROOT, "data", "creatures", "hostile_sites")
SCENE_ROAMERS = os.path.join(ROOT, "creatures", "hostile")
SCENE_SITES = os.path.join(ROOT, "creatures", "hostile", "sites")

CORRIDOR = 60.0
LEASH_SCALE = 1.6

# Roamers: kind stays the family's (faces, voices, bestiary share it); the
# data file is separate so the canon story creature is never touched.
ROAMERS = {
    "naga_roamer": {
        "script": "res://creatures/hostile/naga_roamer.gd",
        "node": "NagaRoamer",
        "model": "res://creatures/models/fae/naga.gltf",
        "fields": [
            ("kind", '&"naga"'),
            ("display_name", '"Naga"'),
            ("fae", "true"),
            ("canon", '"C"'),
            ("body_length", "0.6"),
            ("body_height", "1.95"),
            ("body_width", "0.55"),
            ("walk_speed", "2.0"),
            ("run_speed", "8.0"),
            ("turn_speed", "8.0"),
            ("sight_range", "36.0"),
            ("hearing_range", "40.0"),
            ("scent_range", "98.0"),
            # 6 plain wood arrows to the body, 2 to the throat (the top 22%
            # of its height), 1 ash: a mortal wound that kills in 4 s, or at
            # once on any other hit (health-interactions §2.2).
            ("max_health", "48.0"),
            ("arrow_damage", "8.0"),
            ("lethal_arrow_ids", "Array[StringName]([&\"ash\"])"),
            ("lethal_delay", "4.0"),
            ("weak_zone_height", "0.78"),
            ("weak_zone_name", '&"throat"'),
            # Burns at 6 HP/s; burning reeds within 3 m send it running.
            ("burn_dps", "6.0"),
            ("leaves_prints", "true"),
            ("stride", "0.9"),
            ("print_size", "0.12"),
        ],
        # The family's values on the shared brain (HostileRoamer exports).
        "scene_fields": [
            ("strike_reach", "1.7"),
            ("strike_cooldown", "1.65"),
            ("attack_id", '&"naga_claw"'),
            ("grab_attack", '&"naga_coil"'),
            ("lunge_attack", '&"naga_lunge"'),
            ("dread_radius", "Vector2(30, 10)"),
        ],
    },
    # Briarlings (bestiary §7): a rose bush from the flora table by id, so a
    # flora swap of that rose reaches it (no model file).
    "briarling_roamer": {
        "script": "res://creatures/hostile/briarling_roamer.gd",
        "node": "BriarlingRoamer",
        "model": None,
        "fields": [
            ("kind", '&"briarling"'),
            ("display_name", '"Briarling"'),
            ("fae", "true"),
            ("canon", '"X"'),
            ("body_length", "0.8"),
            ("body_height", "0.7"),
            ("body_width", "0.8"),
            ("coat_color", "Color(0.93, 0.66, 0.74, 1)"),
            ("walk_speed", "1.5"),
            ("run_speed", "6.0"),
            ("turn_speed", "8.0"),
            # Sight x0.7, hearing x1.2, scent x0.5 of the shared 45/40/70.
            ("sight_range", "31.5"),
            ("hearing_range", "48.0"),
            ("scent_range", "35.0"),
            # 2 wood arrows (8 into 16), ash 1, the heart-knot x3, burns 8 HP/s.
            ("max_health", "16.0"),
            ("arrow_damage", "8.0"),
            ("lethal_arrow_ids", "Array[StringName]([&\"ash\"])"),
            ("lethal_delay", "0.0"),
            ("weak_zone_height", "0.5"),
            ("weak_zone_name", '&"heart_knot"'),
            ("burn_dps", "8.0"),
            ("leaves_prints", "true"),
            ("stride", "0.3"),
            ("print_size", "0.05"),
            ("flora_id", '&"flora_bush_rose"'),
        ],
        "scene_fields": [
            ("strike_reach", "1.3"),
            ("strike_cooldown", "1.65"),
            ("attack_id", '&"briarling_lash"'),
            ("grab_attack", '&"briarling_snare"'),
            ("dread_radius", "Vector2(14, 5)"),
        ],
    },
}

# id, family, display name, region (whose spawn table carries it), core (x, z),
# territory radius, roamer, count, require_flags, canon note.
SITES = [
    ("naga_reed_marsh", "naga", "Reed Marsh", "eastern_woods", (1180.0, 330.0), 45.0,
     "naga_roamer", 4, ["naga_survived"], "X"),
    # Moved 32 m south-west of the plan's (1060, -190) and drawn in to 35 m so
    # the leash stays off the Stream Glen whorl stone at (1096, -168).
    ("naga_stream_glen", "naga", "Stream Glen", "eastern_woods", (1040.0, -215.0), 35.0,
     "naga_roamer", 2, ["naga_survived"], "X"),
    ("naga_falls_bluff", "naga", "Falls Bluff Pool", "border_woods", (210.0, 638.0), 35.0,
     "naga_roamer", 1, ["naga_survived"], "X"),
    ("naga_weir", "naga", "The Weir", "blossom_vale", (1350.0, 1140.0), 40.0,
     "naga_roamer", 2, ["naga_survived"], "X"),
    # Suriel Glade has no spawn table of its own; Border Woods carries it.
    ("naga_backwater", "naga", "The Backwater", "border_woods", (-790.0, 735.0), 45.0,
     "naga_roamer", 3, ["naga_survived"], "X"),
    # The weakest folk first (design reconciliation C19, progression §8a.1b):
    # one small brake at the rose garden's outer edge, from naga_survived.
    ("briarling_rose_garden_edge", "briarling", "Rose Garden Brake", "manor_grounds", (-60.0, -560.0), 12.0,
     "briarling_roamer", 3, ["naga_survived"], "X"),
]

# Sites placed and checked but carried by no spawn table yet. The rose-garden
# brake waits for L83's briarling rig and rose-bush swap (C19); that hand-in
# takes it off this list.
HELD = {"briarling_rose_garden_edge"}

# Pairs allowed to overlap (host/lookout, shifts, contested borders).
PAIRS = set()

SPAWN = {}
for _s in SITES:
    if _s[0] in HELD:
        continue
    SPAWN.setdefault(_s[3], []).append({
        "id": "site_" + _s[0],
        "scene": f"res://creatures/hostile/sites/{_s[0]}.tscn",
        "require_flags": list(_s[8]),
        "canon": _s[9],
    })


def _floats(text):
    return [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?", text)]


def read_roads():
    """Densified road points (every 5 m) from court_height.gd PATHS."""
    path = os.path.join(ROOT, "world", "spring_court", "wider", "court_height.gd")
    if not os.path.exists(path):
        return []
    text = open(path).read()
    block = re.search(r"const PATHS := \[(.*?)\n\]", text, re.S)
    if not block:
        return []
    out = []
    for m in re.finditer(r'\[&"(\w+)",\s*[\d.]+,\s*\[(.*?)\]\]', block.group(1)):
        pts = re.findall(r"\[(-?[\d.]+),\s*(-?[\d.]+)\]", m.group(2))
        pts = [(float(a), float(b)) for a, b in pts]
        for (ax, az), (bx, bz) in zip(pts, pts[1:]):
            n = max(1, int(math.hypot(bx - ax, bz - az) / 5.0))
            for i in range(n + 1):
                t = i / n
                out.append((m.group(1), ax + (bx - ax) * t, az + (bz - az) * t))
    return out


def read_anchors():
    """Story anchors (type &"anchor") from court_height.gd's site list."""
    path = os.path.join(ROOT, "world", "spring_court", "wider", "court_height.gd")
    if not os.path.exists(path):
        return []
    out = []
    for m in re.finditer(r'&"(\w+)":\s*\[(-?[\d.]+),\s*(-?[\d.]+),\s*&"\w+",\s*&"anchor"\]', open(path).read()):
        out.append((m.group(1), float(m.group(2)), float(m.group(3))))
    return out


def read_whorl_stones():
    path = os.path.join(ROOT, "tools", "fast_travel", "place_whorl_stones.gd")
    if not os.path.exists(path):
        return []
    out = []
    for m in re.finditer(r'\["(\w+)",\s*&"\w+",\s*&"\w+",\s*Vector2\((-?[\d.]+),\s*(-?[\d.]+)\)', open(path).read()):
        out.append((m.group(1), float(m.group(2)), float(m.group(3))))
    return out


def check_overlap(sites, roads, anchors, stones):
    """Returns a list of broken rules (empty when the layout is good)."""
    errors = []
    for i, a in enumerate(sites):
        ax, az = a[4]
        for b in sites[i + 1:]:
            bx, bz = b[4]
            d = math.hypot(bx - ax, bz - az)
            pair = frozenset((a[0], b[0]))
            if pair in PAIRS:
                continue
            if d <= a[5] * LEASH_SCALE or d <= b[5] * LEASH_SCALE:
                errors.append(f"{a[0]} and {b[0]}: a leash ring reaches the other's core ({d:.0f} m)")
            if d - a[5] - b[5] < CORRIDOR:
                errors.append(f"{a[0]} and {b[0]}: corridor {d - a[5] - b[5]:.0f} m < {CORRIDOR:.0f} m")
    for s in sites:
        sx, sz = s[4]
        leash = s[5] * LEASH_SCALE
        for name, x, z in stones:
            if math.hypot(x - sx, z - sz) <= leash:
                errors.append(f"{s[0]}: leash covers the {name} whorl stone")
        for name, x, z in anchors:
            if math.hypot(x - sx, z - sz) <= leash:
                errors.append(f"{s[0]}: leash covers the {name} story anchor")
        hit = sorted({name for name, x, z in roads if math.hypot(x - sx, z - sz) <= leash})
        for name in hit:
            errors.append(f"{s[0]}: leash covers the {name} road")
    return errors


def write_roamer(rid, spec):
    os.makedirs(DATA_ROAMERS, exist_ok=True)
    model = spec.get("model")
    lines = [f'[gd_resource type="Resource" script_class="CreatureData" load_steps={3 if model else 2} format=3]', "",
             '[ext_resource type="Script" path="res://creatures/creature_data.gd" id="1"]']
    if model:
        lines.append(f'[ext_resource type="PackedScene" path="{model}" id="2"]')
    lines += ["", "[resource]", 'script = ExtResource("1")']
    lines += [f"{k} = {v}" for k, v in spec["fields"]]
    if model:
        lines.append('model_scene = ExtResource("2")')
    lines.append("")
    with open(os.path.join(DATA_ROAMERS, f"{rid}.tres"), "w") as f:
        f.write("\n".join(lines))
    scene = ["[gd_scene load_steps=3 format=3]", "",
             f'[ext_resource type="Script" path="{spec["script"]}" id="1"]',
             f'[ext_resource type="Resource" path="res://data/creatures/hostile/{rid}.tres" id="2"]', "",
             f'[node name="{spec["node"]}" type="CharacterBody3D"]',
             'script = ExtResource("1")', 'data = ExtResource("2")']
    scene += [f"{k} = {v}" for k, v in spec.get("scene_fields", [])]
    scene.append("")
    with open(os.path.join(SCENE_ROAMERS, f"{rid}.tscn"), "w") as f:
        f.write("\n".join(scene))


def write_site(site):
    sid, family, name, region, core, radius, roamer, count, flags, canon = site
    os.makedirs(DATA_SITES, exist_ok=True)
    os.makedirs(SCENE_SITES, exist_ok=True)
    flag_list = ", ".join(f'"{f}"' for f in flags)
    lines = ['[gd_resource type="Resource" script_class="HostileSiteData" load_steps=3 format=3]', "",
             '[ext_resource type="Script" path="res://creatures/hostile/hostile_site_data.gd" id="1"]',
             f'[ext_resource type="PackedScene" path="res://creatures/hostile/{roamer}.tscn" id="2"]', "",
             "[resource]", 'script = ExtResource("1")',
             f'id = &"{sid}"', f'family = &"{family}"', f'display_name = "{name}"',
             f'region_id = &"{region}"', f"core = Vector2({core[0]}, {core[1]})",
             f"territory_radius = {radius}", f"leash_scale = {LEASH_SCALE}",
             'member_scene = ExtResource("2")', f"count = {count}",
             f"require_flags = PackedStringArray({flag_list})", f'canon = "{canon}"', ""]
    with open(os.path.join(DATA_SITES, f"{sid}.tres"), "w") as f:
        f.write("\n".join(lines))
    node = "".join(p.capitalize() for p in sid.split("_"))
    scene = ["[gd_scene load_steps=3 format=3]", "",
             '[ext_resource type="Script" path="res://creatures/hostile/hostile_site.gd" id="1"]',
             f'[ext_resource type="Resource" path="res://data/creatures/hostile_sites/{sid}.tres" id="2"]', "",
             f'[node name="{node}" type="Node3D"]', 'script = ExtResource("1")', 'data = ExtResource("2")', ""]
    with open(os.path.join(SCENE_SITES, f"{sid}.tscn"), "w") as f:
        f.write("\n".join(scene))


def main():
    roads, anchors, stones = read_roads(), read_anchors(), read_whorl_stones()
    errors = check_overlap(SITES, roads, anchors, stones)
    print(f"overlap check: {len(SITES)} sites, {len(roads)} road points, {len(anchors)} anchors, {len(stones)} whorl stones")
    if errors:
        for e in errors:
            print("  FAIL", e)
        sys.exit(1)
    for rid, spec in ROAMERS.items():
        write_roamer(rid, spec)
    for s in SITES:
        write_site(s)
        print(s[0], s[3], s[7], "members")


if __name__ == "__main__":
    main()
