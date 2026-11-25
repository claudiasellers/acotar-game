"""Writes the looted weapons and the families' loot tables (catalogue
plans/hostile-fae/monster-gear.md, docs/contracts/monster_gear.md).

Run: python3 tools/combat/gen_weapons.py
Edit WEAPONS / LOOT below, rerun, commit the outputs. Never edit the outputs.

Writes:
  data/combat/weapons/<id>.tres   WeaponData
  data/combat/loot/<family>.tres  LootTable
"""

import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_WEAPONS = os.path.join(ROOT, "data", "combat", "weapons")
OUT_LOOT = os.path.join(ROOT, "data", "combat", "loot")

# id, name, family, kind, power, swing_s, reach_m, stagger_s, durability,
# imbue slots, two-handed, trait, trait count, unique, canon, description
WEAPONS = [
    # Gloamers (§2.1): stolen mortal tools, plain iron [C: inert].
    ("wpn_gloamer_hookknife", "Gloamer Hook-knife", "gloamer", "sickle", 1.25, 0.6, 1.9, 1.2, 18, 1, False, "bleed", 0, False, "X",
     "A mortal sickle blade bent tighter and lashed to a bone handle. A button hangs off the cord."),
    ("wpn_gloamer_knuckleclub", "Knuckle-club", "gloamer", "club", 1.8, 1.0, 2.0, 1.6, 22, 1, False, "stun", 0, False, "X",
     "A knotted root studded with bent nails, a horseshoe hammered round its head."),
    ("wpn_gloamer_trinket_flail", "Trinket Flail", "gloamer", "whip", 1.1, 0.75, 2.6, 0.8, 14, 1, False, "glint", 0, False, "X",
     "A cord ending in a fist of stolen keys, spoons and a bell. Gloamers can't look away from it."),
    ("wpn_gloamer_scythe_glaive", "Scythe-glaive", "gloamer", "spear", 1.6, 0.95, 2.8, 1.2, 16, 2, True, "sweep", 3, False, "X",
     "A scythe blade set crosswise on a crooked pole, bound in rags and wire and bells."),
    ("wpn_woodcutter_hatchet", "Woodcutter's Hatchet", "", "axe", 1.5, 0.8, 1.8, 1.3, 20, 1, False, "", 0, False, "X",
     "A plain mortal hatchet, the handle gnawed, a ribbon tied on."),
    ("wpn_pruning_hook", "Pruning Hook", "", "sickle", 1.3, 0.65, 2.3, 1.1, 18, 1, False, "hamstring", 0, False, "X",
     "A long orchard pruning hook with blossom twigs caught in the binding."),
    # Naga (§2.2): trophies only; they carry nothing [C].
    ("wpn_naga_talon_knife", "Naga-talon Knife", "naga", "knife", 1.4, 0.6, 1.8, 1.2, 20, 1, False, "bleed", 0, False, "X",
     "One of its black polished talons, wrapped in a strip of its own shed skin."),
    ("wpn_naga_talon_hook", "Talon Hook", "naga", "sickle", 1.5, 0.7, 2.0, 1.2, 18, 1, False, "hamstring", 0, False, "X",
     "A single hooked talon bound to a reed haft with sinew."),
    ("wpn_fishers_gaff", "Fisher's Gaff", "", "spear", 1.3, 0.8, 2.6, 1.0, 15, 1, True, "weakspot", 0, False, "X",
     "A mortal fisherman's iron gaff on an alder pole, the line still knotted round it."),
    # Briarlings (§2.3).
    ("wpn_briar_thorn_whip", "Thorn Whip", "briarling", "whip", 0.9, 0.65, 3.0, 0.8, 12, 1, False, "sweep", 2, False, "X",
     "A living briar cane, still leafing, its thorns rose-red at the tips."),
    ("wpn_briar_rose_shiv", "Rosebriar Shiv", "briarling", "knife", 1.1, 0.45, 1.6, 1.0, 10, 1, False, "bleed", 0, False, "X",
     "The long heart-thorn from its core, wrapped in a rose leaf."),
    # The Hollow Hob (§2.4): the mortal pile, and one unique trophy.
    ("wpn_smiths_hammer", "Smith's Hammer", "", "club", 2.4, 1.2, 1.8, 2.0, 30, 1, False, "stun", 0, False, "X",
     "A mortal smith's hammer, iron black with age, rehafted on a gnawed oak root."),
    ("wpn_shepherds_crook", "Shepherd's Crook", "", "spear", 1.2, 0.85, 2.6, 1.6, 22, 1, True, "hamstring", 0, False, "X",
     "A shepherd's iron crook, wool still caught in the hook. It trips what it catches."),
    ("wpn_hob_tooth_cleaver", "Hob-tooth Cleaver", "hob", "axe", 2.2, 0.9, 1.9, 1.8, 28, 2, False, "stun", 0, True, "X",
     "One of the Hob's blunt teeth, split and bound to a stone-heavy handle. It hums when swung."),
    # Blackveins (§2.5).
    ("wpn_blackvein_veinhook", "Veinhook", "blackvein", "sickle", 1.2, 0.55, 2.0, 1.0, 14, 1, False, "hamstring", 0, False, "X",
     "A long hooked finger, pearl-white with a black vein through it, its knuckle wrapped in silk."),
    ("wpn_blackvein_jaw_shears", "Jaw-shears", "blackvein", "knife", 1.6, 0.65, 1.7, 1.2, 16, 2, False, "bleed", 0, False, "X",
     "Half of its sideways jaw, hooked teeth along the inner edge."),
    # Martax (§2.6).
    ("wpn_martax_tooth_club", "Three-row Club", "martax", "club", 2.2, 1.1, 2.1, 1.7, 24, 2, True, "bleed", 0, False, "X",
     "A martax thigh bone set with three rows of its serrated teeth."),
    ("wpn_martax_fang_knife", "Martax-fang Knife", "martax", "knife", 1.6, 0.65, 1.8, 1.3, 22, 1, False, "", 0, False, "X",
     "A long yellowed fang with a serrated edge, gripped in matted mane hair."),
    # Hollow-crows (§2.7).
    ("wpn_crow_beak_awl", "Crow-beak Awl", "crow", "knife", 0.9, 0.4, 1.5, 0.8, 8, 1, False, "weakspot", 0, False, "X",
     "A hollow-crow's too-long beak on a twig, an eye-spot feather tied on."),
]

# family: carried mix by member index, (leader_at, leader weapon), trophies
# with chances, camp weapon, camp coins.
LOOT = {
    "gloamer": {
        "container": "camp_gloamer_hoard_log",
        "carried": ["wpn_gloamer_hookknife", "wpn_gloamer_knuckleclub", "wpn_gloamer_hookknife", "wpn_gloamer_trinket_flail"],
        "leader": (5, "wpn_gloamer_scythe_glaive"),
        "trophies": [], "camp_weapon": "wpn_gloamer_hookknife", "coins": (3, 8),
    },
    "naga": {
        "container": "camp_naga_reed_cache",
        "carried": [], "leader": (0, ""),
        "trophies": [("wpn_naga_talon_knife", 0.25), ("wpn_naga_talon_hook", 0.15)],
        "camp_weapon": "wpn_fishers_gaff", "coins": (2, 6),
    },
    "briarling": {
        "container": "camp_briar_seedpods",
        "carried": [], "leader": (0, ""),
        "trophies": [("wpn_briar_thorn_whip", 0.2), ("wpn_briar_rose_shiv", 0.2)],
        "camp_weapon": "", "coins": (0, 0),
    },
    "hob": {
        "container": "camp_hob_loot_pile",
        "carried": [], "leader": (0, ""),
        "trophies": [("wpn_hob_tooth_cleaver", 1.0)],
        "camp_weapon": "wpn_smiths_hammer", "coins": (15, 30),
    },
    "blackvein": {
        "container": "camp_blackvein_cocoon",
        "carried": [], "leader": (0, ""),
        "trophies": [("wpn_blackvein_veinhook", 0.25), ("wpn_blackvein_jaw_shears", 0.1)],
        "camp_weapon": "", "coins": (1, 5),
    },
    "martax": {
        "container": "camp_martax_den_hoard",
        "carried": [], "leader": (0, ""),
        "trophies": [("wpn_martax_tooth_club", 0.2), ("wpn_martax_fang_knife", 0.3)],
        "camp_weapon": "", "coins": (5, 12),
    },
    "crow": {
        "container": "",
        "carried": [], "leader": (0, ""),
        "trophies": [("wpn_crow_beak_awl", 0.1)],
        "camp_weapon": "", "coins": (0, 0),
    },
}


def _b(v):
    return "true" if v else "false"


def write_weapon(row):
    (wid, name, family, kind, power, swing, reach, stagger, dur, slots, two, trait, count,
     unique, canon, desc) = row
    lines = [
        '[gd_resource type="Resource" script_class="WeaponData" format=3]', "",
        '[ext_resource type="Script" path="res://systems/weapons/weapon_data.gd" id="1"]', "",
        "[resource]", 'script = ExtResource("1")',
        f'id = &"{wid}"', f'display_name = "{name}"', f'family = &"{family}"', f'kind = &"{kind}"',
        f"power = {power}", f"swing_s = {swing}", f"reach_m = {reach}", f"stagger_s = {stagger}",
        f"durability = {dur}", f"imbue_slots = {slots}", f"two_handed = {_b(two)}",
        f'trait_id = &"{trait}"', f"trait_count = {count}", f"unique = {_b(unique)}",
        f'canon = "{canon}"', f'description = "{desc}"', "",
    ]
    with open(os.path.join(OUT_WEAPONS, f"{wid}.tres"), "w") as f:
        f.write("\n".join(lines))


def _names(ids):
    return "Array[StringName]([%s])" % ", ".join(f'&"{i}"' for i in ids)


def write_loot(family, spec):
    trophies = spec["trophies"]
    lines = [
        '[gd_resource type="Resource" script_class="LootTable" format=3]', "",
        '[ext_resource type="Script" path="res://systems/weapons/loot_table.gd" id="1"]', "",
        "[resource]", 'script = ExtResource("1")',
        f'family = &"{family}"', f"carried = {_names(spec['carried'])}",
        f"leader_at = {spec['leader'][0]}", f'leader_weapon = &"{spec["leader"][1]}"',
        "carried_wear = Vector2(0.5, 0.9)",
        f"trophies = {_names([t[0] for t in trophies])}",
        "trophy_chances = PackedFloat32Array(%s)" % ", ".join(str(t[1]) for t in trophies),
        f'camp_weapon = &"{spec["camp_weapon"]}"',
        f"camp_coins = Vector2i({spec['coins'][0]}, {spec['coins'][1]})",
        f'camp_container = &"{spec["container"]}"', "",
    ]
    with open(os.path.join(OUT_LOOT, f"{family}.tres"), "w") as f:
        f.write("\n".join(lines))


def main():
    os.makedirs(OUT_WEAPONS, exist_ok=True)
    os.makedirs(OUT_LOOT, exist_ok=True)
    ids = {r[0] for r in WEAPONS}
    for fam, spec in LOOT.items():
        for wid in spec["carried"] + [spec["leader"][1], spec["camp_weapon"]] + [t[0] for t in spec["trophies"]]:
            if wid and wid not in ids:
                raise SystemExit(f"loot {fam} names unknown weapon {wid}")
    for row in WEAPONS:
        write_weapon(row)
    for fam, spec in LOOT.items():
        write_loot(fam, spec)
    print(f"gen_weapons: {len(WEAPONS)} weapons, {len(LOOT)} loot tables")


if __name__ == "__main__":
    main()
