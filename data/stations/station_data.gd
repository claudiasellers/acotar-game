## A chemistry station (root doc §5): hearth, kitchen, stillroom...
class_name StationData
extends Resource

@export var id: StringName
@export var display_name: String
## Methods allowed here: roast, stew, infuse, cook, preserve, bake, distill,
## salve, steep, tincture.
@export var methods: Array[StringName] = []
## Phase that unlocks it (informational; story gates the room itself).
@export var phase: int = 0
## Safe to combine fae ingredients here (halves fae toll).
@export var fae_safe: bool = false
@export var max_ingredients: int = 4
