## One story phase: what it opens in the world and which deeds end it.
class_name PhaseDef
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var notes: String
## Regions whose RegionGate opens when this phase begins (permanent).
@export var unlocked_regions: PackedStringArray = []
## Regions that close again when this phase begins (rare).
@export var locked_regions: PackedStringArray = []
@export var exit_condition: ExitCondition
## Empty for the last phase of a world.
@export var next_phase: StringName
