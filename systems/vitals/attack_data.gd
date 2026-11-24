## One way Feyre can be hurt: a monster move or a hazard (docs/contracts/vitals.md §3).
## Rows live in data/combat/attacks/<family>_<move>.tres, written by
## tools/vitals/gen_attack_rows.gd. Hostile-fae owns its families' rows.
class_name AttackData
extends Resource

@export var id: StringName
## A hit whose id equals a family resolves to that family's is_default row.
@export var family: StringName
@export var is_default: bool = false
## Health points (her max is 100).
@export var damage: float = 10.0
## bite, claw, blunt, thorn, fire, cold, venom, fall.
@export var damage_kind: StringName = &"bite"
## light, medium, heavy, none.
@export var reaction: StringName = &"light"
@export var knockback_m: float = 0.0
## Applied with the hit, exactly like a player_status_applied.
@export var status_tag: StringName = &""
@export var status_magnitude: float = 0.0
@export var status_seconds: float = 0.0
## Added to dread before her dread-gain scale.
@export var dread_spike: float = 0.1
## false: this row can't take her below floor_hp.
@export var can_knock_down: bool = true
@export var floor_hp: float = 0.0
@export var canon: String = "X"
