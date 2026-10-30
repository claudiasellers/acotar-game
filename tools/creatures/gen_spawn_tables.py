"""Writes the Spring Court ambient spawn tables: data/creatures/spawn/<region>.tres.

Run: python3 tools/creatures/gen_spawn_tables.py
Edit TABLES below, rerun, commit both. Region lanes place a CreatureSpawner
(creatures/spawning/creature_spawner.gd) with `table` pointing at their file.
Hours: start > end wraps midnight; equal means all day.
"""

import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "data", "creatures", "spawn")

SCENES = {
    "butterflies": "res://creatures/ambient/scenes/butterflies.tscn",
    "faelights": "res://creatures/ambient/scenes/faelights.tscn",
    "songbird_blue": "res://creatures/ambient/scenes/songbird_blue.tscn",
    "songbird_rose": "res://creatures/ambient/scenes/songbird_rose.tscn",
    "songbird_gold": "res://creatures/ambient/scenes/songbird_gold.tscn",
    "rabbit": "res://creatures/ambient/scenes/rabbit.tscn",
    "lamb": "res://creatures/ambient/scenes/lamb.tscn",
    "swan": "res://creatures/ambient/scenes/swan.tscn",
    "deer": "res://creatures/prey/deer.tscn",
}

# (entry id, scene, count per group, groups, cluster radius, start, end, on_water, canon)
DAY = (7.0, 19.0)
NIGHT = (20.0, 5.0)
SONG = (5.0, 20.5)
ALL = (0.0, 0.0)


def birds(groups):
    return [
        ("songbirds_blue", "songbird_blue", 3, groups, 5.0, *SONG, False, "C"),
        ("songbirds_rose", "songbird_rose", 3, groups, 5.0, *SONG, False, "C"),
        ("songbirds_gold", "songbird_gold", 3, max(1, groups - 1), 5.0, *SONG, False, "C"),
    ]


TABLES = {
    "manor_grounds": birds(4) + [
        ("butterflies_roses", "butterflies", 1, 6, 0.0, *DAY, False, "X"),
        ("faelights_gardens", "faelights", 1, 4, 0.0, *NIGHT, False, "X"),
        ("rabbits_lawns", "rabbit", 3, 3, 6.0, *ALL, False, "C"),
        ("swans_pond", "swan", 2, 1, 6.0, 6.0, 21.0, True, "X"),
    ],
    "border_woods": birds(3) + [
        ("butterflies_glades", "butterflies", 1, 3, 0.0, *DAY, False, "X"),
        ("faelights_woods", "faelights", 1, 3, 0.0, *NIGHT, False, "X"),
        ("rabbits", "rabbit", 2, 4, 5.0, *ALL, False, "C"),
        ("deer", "deer", 3, 2, 8.0, *ALL, False, "C"),
    ],
    "eastern_woods": birds(2) + [
        ("faelights_woods", "faelights", 1, 2, 0.0, *NIGHT, False, "X"),
        ("deer", "deer", 3, 2, 8.0, *ALL, False, "C"),
        ("rabbits", "rabbit", 2, 2, 5.0, *ALL, False, "C"),
    ],
    "starlight_glen": birds(2) + [
        ("faelights_pool", "faelights", 1, 6, 0.0, *NIGHT, False, "C?"),
        ("butterflies_glen", "butterflies", 1, 3, 0.0, *DAY, False, "X"),
        ("swans_pool", "swan", 2, 1, 5.0, 6.0, 21.0, True, "X"),
    ],
    "solstice_meadow": birds(3) + [
        ("butterflies_meadow", "butterflies", 1, 8, 0.0, *DAY, False, "X"),
        ("faelights_meadow", "faelights", 1, 5, 0.0, *NIGHT, False, "C"),
        ("rabbits", "rabbit", 3, 3, 6.0, *ALL, False, "C"),
    ],
    "blossom_vale": birds(4) + [
        ("butterflies_blossom", "butterflies", 1, 8, 0.0, *DAY, False, "X"),
        ("lambs", "lamb", 4, 3, 7.0, 6.0, 20.0, False, "X"),
        ("rabbits", "rabbit", 3, 3, 6.0, *ALL, False, "C"),
        ("faelights_vale", "faelights", 1, 3, 0.0, *NIGHT, False, "X"),
    ],
    "rosewild": birds(3) + [
        ("butterflies_roses", "butterflies", 1, 6, 0.0, *DAY, False, "X"),
        ("faelights_roses", "faelights", 1, 3, 0.0, *NIGHT, False, "X"),
        ("rabbits", "rabbit", 2, 2, 5.0, *ALL, False, "C"),
    ],
}


def write(region, entries):
    used = sorted({e[1] for e in entries})
    ids = {name: i + 2 for i, name in enumerate(used)}
    lines = [f'[gd_resource type="Resource" script_class="CreatureSpawnTable" load_steps={len(used) + len(entries) + 3} format=3]', ""]
    lines.append('[ext_resource type="Script" path="res://creatures/spawning/creature_spawn_table.gd" id="1"]')
    lines.append(f'[ext_resource type="Script" path="res://creatures/spawning/spawn_entry.gd" id="{len(used) + 2}"]')
    for name in used:
        lines.append(f'[ext_resource type="PackedScene" path="{SCENES[name]}" id="{ids[name]}"]')
    lines.append("")
    entry_script = len(used) + 2
    for i, (eid, scene, count, groups, radius, start, end, water, canon) in enumerate(entries):
        lines += [
            f'[sub_resource type="Resource" id="e{i}"]',
            f'script = ExtResource("{entry_script}")',
            f'id = &"{eid}"',
            f'scene = ExtResource("{ids[scene]}")',
            f"count = {count}",
            f"cluster_radius = {radius}",
            f"groups = {groups}",
            f"start_hour = {start}",
            f"end_hour = {end}",
            f"on_water = {'true' if water else 'false'}",
            f'canon = "{canon}"',
            "",
        ]
    subs = ", ".join(f'SubResource("e{i}")' for i in range(len(entries)))
    lines += ["[resource]", 'script = ExtResource("1")', f'region_id = &"{region}"',
              f'entries = Array[ExtResource("{entry_script}")]([{subs}])', ""]
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, f"{region}.tres"), "w") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    for region, entries in TABLES.items():
        write(region, entries)
        print(region, len(entries), "entries")
