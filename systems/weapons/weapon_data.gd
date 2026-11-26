## One looted weapon's row (docs/contracts/monster_gear.md; the catalogue is
## plans/hostile-fae/monster-gear.md). Rows live in data/combat/weapons/<id>.tres,
## written by tools/combat/gen_weapons.py. A held weapon takes the boot knife's
## place in the Strike key (StrikeController) until it breaks.
class_name WeaponData
extends Resource

## Its item id, which is also its model id (art/monster_gear/<id>.glb).
@export var id: StringName
@export var display_name: String = ""
## The family it comes from (&"" for a mortal tool found anywhere).
@export var family: StringName = &""
## knife, sickle, club, spear, whip, axe (the swing and sound class).
@export var kind: StringName = &"knife"
## Damage as a multiple of the target's arrow_damage (the boot knife is 1).
## Sneak and finisher multiply on top.
@export var power: float = 1.0
## Seconds between strikes.
@export var swing_s: float = 0.7
## How far it reaches, metres.
@export var reach_m: float = 1.8
## How long a hit that doesn't kill drives the target back.
@export var stagger_s: float = 1.2
## Hits before it breaks.
@export var durability: int = 20
## Imbue slots (ImbueSlots): weapon elements at a tier.
@export var imbue_slots: int = 1
@export var two_handed: bool = false
## bleed, hamstring, sweep, stun, weakspot, glint, or &"" (catalogue §1.3).
@export var trait_id: StringName = &""
## sweep: how many it can hit in one swing.
@export var trait_count: int = 0
## Never drops twice; its pieces become a keepsake when it breaks.
@export var unique: bool = false
@export var canon: String = "X"
@export_multiline var description: String = ""

const MODEL := "res://art/monster_gear/%s.glb"


func model_path() -> String:
	return MODEL % id


func has_model() -> bool:
	return ResourceLoader.exists(model_path())
