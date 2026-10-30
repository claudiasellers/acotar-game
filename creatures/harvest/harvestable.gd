## What a carcass gives up: pelt, meat, sinew. The systems lane's inventory
## calls harvest() when Feyre interacts with it (group "harvestable").
class_name Harvestable
extends Node3D

signal harvested(items: Array[Dictionary])

const GROUP := &"harvestable"

var creature_id: StringName = &""
var kind: StringName = &""
var items: Array[Dictionary] = []
var is_harvested: bool = false


func _ready() -> void:
	add_to_group(GROUP)


func setup(id: StringName, creature_kind: StringName, yield_items: Array[Dictionary]) -> void:
	creature_id = id
	kind = creature_kind
	items = yield_items


## Returns [{item_id, qty}, ...] once; empty afterwards.
func harvest() -> Array[Dictionary]:
	if is_harvested:
		return []
	is_harvested = true
	harvested.emit(items)
	if EventBus.has_signal(&"creature_harvested"):
		var ids := PackedStringArray()
		for item in items:
			ids.append(String(item.item_id))
		EventBus.emit_signal(&"creature_harvested", creature_id, kind, ids)
	remove_from_group(GROUP)
	return items


## The nearest unharvested carcass within reach of `at`, or null.
static func nearest(tree: SceneTree, at: Vector3, reach: float = 2.5) -> Harvestable:
	var best: Harvestable = null
	var best_distance := reach
	for node in tree.get_nodes_in_group(GROUP):
		var h := node as Harvestable
		var d := h.global_position.distance_to(at)
		if d <= best_distance:
			best = h
			best_distance = d
	return best
