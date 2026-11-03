## The touchable world's one hookup in the World scene (T5): for every region
## WorldStreamer loads, adds that region's loose props (PropField, from
## data/props/placements/<id>.tres). Later slices add the nav bake, weather
## visuals and element chemistry here, so World needs just this one node.
class_name TouchWorld
extends Node


func _ready() -> void:
	var streamer := Gameplay.autoload(&"WorldStreamer")
	if streamer == null:
		return
	streamer.region_loaded.connect(_on_region_loaded)
	for id in streamer.loaded_ids():
		var root: Node3D = streamer.loaded_root(StringName(id))
		if root:
			_on_region_loaded(StringName(id), root)


func _on_region_loaded(id: StringName, root: Node3D) -> void:
	add_props(id, root)


## Adds the region's PropField under `root`. Returns it (null if the region has none).
static func add_props(id: StringName, root: Node3D) -> PropField:
	if root.has_node(^"Props"):
		return root.get_node(^"Props") as PropField
	var placements := PropPlacements.for_region(id)
	if placements == null:
		return null
	var field := PropField.new()
	field.name = "Props"
	field.placements = placements
	root.add_child(field)
	return field
