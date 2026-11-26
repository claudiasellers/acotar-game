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
            # R9: stops drawing past 120 m, well past any leash (56 m) plus the fade.
            ("draw_distance", "120.0"),
            ("stride", "0.9"),
            ("print_size", "0.12"),
            # Element row (plan §7): fire, frost and sleep weak, light normal.
            ("element_rows", '{\n&"fire": 1.5,\n&"frost": 1.5,\n&"light": 1.0,\n&"sleep": 1.5\n}'),
        ],
        # The family's values on the shared brain (HostileRoamer exports).
        "scene_fields": [
            ("strike_reach", "1.7"),
            ("strike_cooldown", "1.65"),
            ("attack_id", '&"naga_claw"'),
            ("grab_attack", '&"naga_coil"'),
            ("lunge_attack", '&"naga_lunge"'),
            ("dread_radius", "Vector2(30, 10)"),
            # Circling on stalk, it laughs now and then (L81 G21).
            ("taunt_clip", '&"laugh"'),
        ],
    },
    # Briarlings (bestiary §7): L83's rigged thorn-folk, whose bush pose and
    # leaf swatches match the court's rose bush (and never sway).
    "briarling_roamer": {
        "script": "res://creatures/hostile/briarling_roamer.gd",
        "node": "BriarlingRoamer",
        "model": "res://creatures/models/fae/briarling.gltf",
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
            # Small means fragile (owner, 2026-11-25): one wood arrow or one
            # knife hit (8 into 8), ash 1, burns 8 HP/s; a box 1.5x its body.
            ("max_health", "8.0"),
            ("arrow_damage", "8.0"),
            ("lethal_arrow_ids", "Array[StringName]([&\"ash\"])"),
            ("lethal_delay", "0.0"),
            ("weak_zone_height", "0.5"),
            ("weak_zone_name", '&"heart_knot"'),
            ("burn_dps", "8.0"),
            ("leaves_prints", "true"),
            # R9: stops drawing past 120 m, well past any leash (56 m) plus the fade.
            ("draw_distance", "120.0"),
            ("stride", "0.3"),
            ("print_size", "0.05"),
            ("hit_box_scale", "1.5"),
            # Element row (plan §7): fire and sleep weak, frost normal.
            ("element_rows", '{\n&"fire": 1.5,\n&"frost": 1.0,\n&"sleep": 1.5\n}'),
        ],
        "scene_fields": [
            ("strike_reach", "1.3"),
            ("strike_cooldown", "1.65"),
            ("attack_id", '&"briarling_lash"'),
            ("grab_attack", '&"briarling_snare"'),
            ("dread_radius", "Vector2(14, 5)"),
        ],
    },
    # Gloamers (bestiary §16): L83's knuckle-loping pack scavengers, the
    # common tier on the wood edges, out from dusk to dawn.
    "gloamer_roamer": {
        "script": "res://creatures/hostile/gloamer_roamer.gd",
        "node": "GloamerRoamer",
        "model": "res://creatures/models/fae/gloamer.gltf",
        "fields": [
            ("kind", '&"gloamer"'),
            ("display_name", '"Gloamer"'),
            ("fae", "true"),
            ("canon", '"X"'),
            # 1.6 m standing, 1.1 m on the lope.
            ("body_length", "0.7"),
            ("body_height", "1.3"),
            ("body_width", "0.6"),
            ("walk_speed", "2.0"),
            ("run_speed", "6.5"),
            ("turn_speed", "8.0"),
            # Sight x0.9, hearing x1.1, scent x1.0 of the shared 45/40/70.
            ("sight_range", "40.5"),
            ("hearing_range", "44.0"),
            ("scent_range", "70.0"),
            # 3 wood arrows (24 HP, 8 each), 1 to the throat (x3), ash 1;
            # 2 knife hits (12 each, knife_scale 1.5).
            ("max_health", "24.0"),
            ("arrow_damage", "8.0"),
            ("knife_scale", "1.5"),
            ("lethal_arrow_ids", "Array[StringName]([&\"ash\"])"),
            ("lethal_delay", "0.0"),
            ("weak_zone_height", "0.8"),
            ("weak_zone_name", '&"throat"'),
            # Burns at 6 HP/s and flees fire.
            ("burn_dps", "6.0"),
            ("leaves_prints", "true"),
            # R9: stops drawing past 120 m, well past any leash (56 m) plus the fade.
            ("draw_distance", "120.0"),
            ("stride", "0.6"),
            ("print_size", "0.1"),
            # Element row (plan §7): fire, light and sleep weak, frost normal.
            ("element_rows", '{\n&"fire": 1.5,\n&"frost": 1.0,\n&"light": 1.5,\n&"sleep": 1.5\n}'),
        ],
        "scene_fields": [
            ("strike_reach", "1.2"),
            ("strike_cooldown", "1.65"),
            ("attack_id", '&"gloamer_rake"'),
            ("dread_radius", "Vector2(20, 6)"),
            # The chitter that becomes a shriek and sets the pack off.
            ("call_clip", '&"call"'),
            # Half the pack down, the rest scatter into the trees.
            ("rout_share", "0.5"),
            # A glint thrown the other way pulls two off to fight over it.
            ("glint_drawn", "2"),
            ("glint_clip", '&"grab_shiny"'),
            ("squabble_clip", '&"squabble"'),
        ],
    },
    "hob_roamer": {
        "script": "res://creatures/hostile/hob_roamer.gd",
        "node": "HobRoamer",
        "model": "res://creatures/models/fae/hollow_hob.gltf",
        "fields": [
            ("kind", '&"hob"'),
            ("display_name", '"Hollow Hob"'),
            ("fae", "true"),
            ("canon", '"X"'),
            # About 6.7 m standing, 3.7 m hunched (the box), 3 m lying
            # (bestiary §10.3); the size is in the model's data (L83-9).
            ("body_length", "3.0"),
            ("body_height", "3.7"),
            ("body_width", "2.4"),
            ("walk_speed", "1.0"),
            ("run_speed", "4.0"),
            ("turn_speed", "1.5"),
            # Sight x0.6, hearing x1.3, scent x0.8 of the shared 45/40/70
            # (plan §4 table); asleep it half sees again (HobRoamer).
            ("sight_range", "27.0"),
            ("hearing_range", "52.0"),
            ("scent_range", "56.0"),
            # 30 wood arrows (300 HP, 10 each), 3 ash; the throat charm x3.
            ("max_health", "300.0"),
            ("arrow_damage", "10.0"),
            ("lethal_arrow_ids", "Array[StringName]([&\"ash\"])"),
            ("lethal_delay", "0.0"),
            ("ash_hits", "3"),
            ("weak_zone_height", "3.2"),
            ("weak_zone_name", '&"charm"'),
            # She can't stand at its middle: the knife and the sneak reach
            # past its origin by this.
            ("reach_margin", "1.6"),
            # Fire sends it into the river (plan §7: fire strong, the rest plain).
            ("burn_dps", "4.0"),
            ("fire_fear_radius", "6.0"),
            ("element_rows", '{\n&"fire": 1.5,\n&"frost": 1.0,\n&"light": 1.0,\n&"sleep": 1.0\n}'),
            ("leaves_prints", "true"),
            # R9: stops drawing past 120 m, well past any leash (56 m) plus the fade.
            ("draw_distance", "120.0"),
            ("stride", "1.8"),
            ("print_size", "0.45"),
        ],
        "scene_fields": [
            ("strike_reach", "4.0"),
            ("strike_cooldown", "3.0"),
            ("attack_id", '&"hob_swat"'),
            ("dread_radius", "Vector2(35, 12)"),
            # It stands, roaring.
            ("call_clip", '&"stand_roar"'),
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
    # The common tier's gloamer packs (plan §6.2; bestiary §16): few from
    # naga_survived, more from P4 (starlight_pool_found) and stranger_met, most
    # once the glamour lifts. The brackenhound packs follow with their brain.
    ("gloamer_hollow_log_edge", "gloamer", "Hollow Log Edge", "border_woods", (-380.0, 520.0), 35.0,
     "gloamer_roamer", 3, ["naga_survived"], "X"),
    ("gloamer_woodcutters_edge", "gloamer", "Woodcutter's Edge", "eastern_woods", (820.0, 200.0), 35.0,
     "gloamer_roamer", 4, ["naga_survived"], "X"),
    ("gloamer_ash_ride", "gloamer", "Ash Ride", "eastern_woods", (1550.0, 260.0), 35.0,
     "gloamer_roamer", 4, ["stranger_met"], "X"),
    ("gloamer_orchard_wall", "gloamer", "Orchard Wall", "blossom_vale", (1150.0, 1000.0), 35.0,
     "gloamer_roamer", 4, ["starlight_pool_found"], "X"),
    ("gloamer_hedge_lane", "gloamer", "Hedge Lane", "blossom_vale", (500.0, 1000.0), 35.0,
     "gloamer_roamer", 3, ["stranger_met"], "X"),
    ("gloamer_shepherds_rocks", "gloamer", "Shepherd's Rocks", "western_fells", (-1250.0, 400.0), 35.0,
     "gloamer_roamer", 4, ["starlight_pool_found"], "X"),
    ("gloamer_fell_gate_edge", "gloamer", "Fell Gate Edge", "western_fells", (-1050.0, 750.0), 35.0,
     "gloamer_roamer", 5, ["glamour_lifted"], "X"),
    ("gloamer_steading_fields", "gloamer", "Steading Fields", "blighted_reaches", (600.0, -1550.0), 35.0,
     "gloamer_roamer", 5, ["glamour_lifted"], "X"),
    ("gloamer_grey_hedgerow", "gloamer", "Grey Hedgerow", "blighted_reaches", (-500.0, -1600.0), 35.0,
     "gloamer_roamer", 5, ["glamour_lifted"], "X"),
    ("gloamer_ash_pits", "gloamer", "Ash Pits", "blighted_reaches", (1200.0, -1450.0), 35.0,
     "gloamer_roamer", 4, ["glamour_lifted"], "X"),
    # The giant (plan §5.7, bestiary §10): one Hollow Hob asleep in the
    # Silent Hollow from P4.
    ("hob_silent_hollow", "hob", "Silent Hollow", "western_fells", (-1300.0, 900.0), 35.0,
     "hob_roamer", 1, ["starlight_pool_found"], "X"),
]

# Sites placed and checked but carried by no spawn table yet. The rose-garden
# brake waits for L83's briarling rig and rose-bush swap (C19); that hand-in
# takes it off this list.
HELD = {"briarling_rose_garden_edge"}

# Pairs allowed to overlap (host/lookout, shifts, contested borders).
PAIRS = set()

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


# The seeded layout (lane L91, tools/creatures/site_layout.py): the authored
# sites above stay as they are; the layout adds the rest of the court's camps
# around them, each anchored to a reason, under the same overlap rules.
try:
    import site_layout
except ImportError:
    sys.path.insert(0, os.path.dirname(__file__))
    import site_layout
AUTHORED = list(SITES)
PLACED, REASONS = site_layout.plan(AUTHORED, read_roads(), read_anchors(), read_whorl_stones())
SITES = AUTHORED + PLACED

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
    ids, offs, yaws = DRESSING.get(sid, ([], [], []))
    scene = [f"[gd_scene load_steps={4 if ids else 3} format=3]", "",
             '[ext_resource type="Script" path="res://creatures/hostile/hostile_site.gd" id="1"]',
             f'[ext_resource type="Resource" path="res://data/creatures/hostile_sites/{sid}.tres" id="2"]']
    if ids:
        scene.append('[ext_resource type="Script" path="res://creatures/hostile/camp_dressing.gd" id="3"]')
    scene += ["", f'[node name="{node}" type="Node3D"]', 'script = ExtResource("1")', 'data = ExtResource("2")', ""]
    if ids:
        scene += ['[node name="CampDressing" type="Node3D" parent="."]', 'script = ExtResource("3")',
                  "pieces = Array[StringName]([%s])" % ", ".join(f'&"{i}"' for i in ids),
                  "offsets = PackedVector2Array(%s)" % ", ".join(f"{x}, {z}" for x, z in offs),
                  "yaws = PackedFloat32Array(%s)" % ", ".join(str(y) for y in yaws), ""]
    with open(os.path.join(SCENE_SITES, f"{sid}.tscn"), "w") as f:
        f.write("\n".join(scene))


# Camp gear per site (lane L91): its family's kit turned to its approach.
_ROADS_ALL = site_layout.all_roads(read_roads())
_WATERS = site_layout.waters()
DRESSING = {s[0]: site_layout.kit_for(s, _ROADS_ALL, _WATERS) for s in SITES}


def remove_stale():
    """Deletes site outputs whose id is no longer in SITES (R18: one layout)."""
    keep = {s[0] for s in SITES}
    for folder, ext in ((DATA_SITES, ".tres"), (SCENE_SITES, ".tscn")):
        if not os.path.isdir(folder):
            continue
        for name in os.listdir(folder):
            if name.endswith(ext) and name[: -len(ext)] not in keep:
                os.remove(os.path.join(folder, name))


def report():
    """Per region: camps by tier, members, and the camp gear's draw-call cost."""
    tiers = {"gloamer": "common", "naga": "bigger", "hob": "giant", "briarling": "small"}
    rows = {}
    for s in SITES:
        r = rows.setdefault(s[3], {"common": 0, "bigger": 0, "giant": 0, "small": 0, "members": 0, "pieces": 0})
        r[tiers.get(s[1], "small")] += 1
        r["members"] += s[7]
        r["pieces"] += len(DRESSING.get(s[0], ([],))[0])
    total = {k: sum(r[k] for r in rows.values()) for k in ("common", "bigger", "giant", "small", "members", "pieces")}
    n = sum(total[k] for k in ("common", "bigger", "giant", "small"))
    print("region               common bigger giant small members gear")
    for region in sorted(rows):
        r = rows[region]
        print(f"{region:20s} {r['common']:6d} {r['bigger']:6d} {r['giant']:5d} {r['small']:5d} {r['members']:7d} {r['pieces']:4d}")
    print(f"{'total':20s} {total['common']:6d} {total['bigger']:6d} {total['giant']:5d} {total['small']:5d} "
          f"{total['members']:7d} {total['pieces']:4d}")
    print("ladder: common %.0f%%, bigger %.0f%%, small %.0f%%, giant %d" % (
        100.0 * total["common"] / n, 100.0 * total["bigger"] / n, 100.0 * total["small"] / n, total["giant"]))
    budget()
    for sid, why in REASONS:
        print(f"  {sid}: {why}")


# Draw calls per member (its model's primitives) and per camp piece (the
# prop_kit's two surfaces). Members draw wherever they are loaded; gear only
# inside CampDressing.VISIBLE_TO (120 m). Shadows are counted for every member
# and every tall piece, which overstates both (the sun's shadows end at 220 m).
MEMBER_DRAWS = {"gloamer": 1, "naga": 1, "briarling": 1, "hob": 9}
PIECE_DRAWS = 2
GEAR_RANGE = 120.0
# Members stop drawing past CreatureData.draw_distance (180 m for the roamers):
# the worst view sees every member within that of the eye, so a pair of camps
# up to twice it apart.
MEMBER_RANGE = 120.0
BUDGET = 1500


def budget():
    """R9: each region's scatter report plus every camp loaded with it."""
    regions_dir = os.path.join(ROOT, "data", "regions", "spring_court")
    tall = {r["id"] for r in _manifest() if r.get("size_m", [0, 0, 0])[1] >= 1.0}
    worst = (0, "")
    print("R9 draw calls (scatter report + camps with neighbours loaded; gear within 120 m):")
    for region in sorted({s[3] for s in SITES}):
        path = os.path.join(regions_dir, f"{region}.tres")
        text = open(path).read() if os.path.exists(path) else ""
        m = re.search(r'neighbors = PackedStringArray\((.*?)\)', text)
        loaded = {region} | set(re.findall(r'"(\w+)"', m.group(1) if m else ""))
        rp = re.search(r'report_path = "res://(.*?)"', text)
        base = None
        if rp and os.path.exists(os.path.join(ROOT, rp.group(1))):
            import json
            base = json.load(open(os.path.join(ROOT, rp.group(1)))).get("draw_calls")
        sites = [s for s in SITES if s[3] in loaded and s[0] not in HELD]
        members, gear = 0, 0
        for a in sites:
            near = [b for b in sites if math.hypot(a[4][0] - b[4][0], a[4][1] - b[4][1]) <= GEAR_RANGE]
            g = sum(PIECE_DRAWS * (2 if pid in tall else 1) for b in near for pid in DRESSING.get(b[0], ([],))[0])
            gear = max(gear, g)
            seen = [b for b in sites if math.hypot(a[4][0] - b[4][0], a[4][1] - b[4][1]) <= MEMBER_RANGE * 2]
            members = max(members, sum(b[7] * MEMBER_DRAWS.get(b[1], 1) * 2 for b in seen))
        total = (base or 0) + members + gear
        note = "" if base is not None else " (no scatter report in the tree: a generated one)"
        print(f"  {region:18s} scatter {base if base is not None else '-':>5} + members {members:3d} + gear {gear:3d} = {total:5d}{note}")
        if base is not None and total > worst[0]:
            worst = (total, region)
    print(f"  worst: {worst[1]} {worst[0]} of {BUDGET}")


def _manifest():
    import json
    path = os.path.join(ROOT, "art", "monster_gear", "monster_gear_manifest.json")
    return json.load(open(path)).get("assets", []) if os.path.exists(path) else []


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
    remove_stale()
    for s in SITES:
        write_site(s)
    report()


if __name__ == "__main__":
    main()
