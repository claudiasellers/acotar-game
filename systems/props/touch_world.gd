## The touchable world's one hookup in the World scene (T5): for every region
## WorldStreamer loads, adds that region's loose props (PropField, from
## data/props/placements/<id>.tres, a child of the region so it goes with it),
## runs the navmesh tile around Feyre (NavBaker), the element chemistry
## (ElementField: fire, water, wind) and the spring weather visuals
## (SpringWeather), so World needs just this one node.
## A Spring Court region's grass, reeds and hay are registered with the
## ElementField as ground fuel once its scatter is built, and dropped when it
## streams out. The human realm is winter: its ground never burns.
class_name TouchWorld
extends Node

var nav: NavBaker
var elements: ElementField
var weather: SpringWeather


func _ready() -> void:
	nav = NavBaker.new()
	nav.name = "NavBaker"
	add_child(nav)
	elements = ElementField.new()
	elements.name = "ElementField"
	add_child(elements)
	weather = SpringWeather.new()
	weather.name = "SpringWeather"
	add_child(weather)
	var streamer := Gameplay.autoload(&"WorldStreamer")
	if streamer == null:
		return
	streamer.region_loaded.connect(_on_region_loaded)
	streamer.region_unloaded.connect(_on_region_unloaded)
	for id in streamer.loaded_ids():
		var root: Node3D = streamer.loaded_root(StringName(id))
		if root:
			_on_region_loaded(StringName(id), root)


func _on_region_loaded(id: StringName, root: Node3D) -> void:
	add_props(id, root)
	add_ground_fuel(id, root)


## Props go with their region root; the cached nav source and the ground fuel are ours to drop.
func _on_region_unloaded(id: StringName) -> void:
	nav.region_unloaded(id)
	elements.remove_ground(id)


## Registers a Spring region's flammable scatter with the ElementField, now
## or when the region finishes building it (CourtRegion, WoodsRegion `built`).
func add_ground_fuel(id: StringName, root: Node3D, threaded: bool = true) -> void:
	if not is_spring(root):
		return
	if root.get(&"is_built") == false and root.has_signal(&"built"):
		root.connect(&"built", func() -> void:
			if is_instance_valid(root) and root.is_inside_tree():
				elements.add_ground(id, scatter_fields(root), GroundFuel.clearings(root), threaded), CONNECT_ONE_SHOT)
		return
	elements.add_ground(id, scatter_fields(root), GroundFuel.clearings(root), threaded)


static func is_spring(root: Node) -> bool:
	return root.scene_file_path.contains("/spring_court/")


## Every ScatterField under a region root.
static func scatter_fields(root: Node) -> Array:
	return root.find_children("*", "ScatterField", true, false)


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
