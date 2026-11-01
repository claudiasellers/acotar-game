## The wayside director (L23): streams the little things to find and do on
## the walks between places, built from every WaysideRoute in data/wayside/.
## Spots within SPAWN_RADIUS of Feyre get a node (one per spot, a few dozen at
## most); spots past FREE_RADIUS are freed. What she has found is kept in
## WorldDeltas under region "wayside", so it saves with the world.
##
## Add one to the game scene: add_child(Wayside.new()).
class_name Wayside
extends Node3D

const DATA_DIR := "res://data/wayside"
const REGION := &"wayside"
const SPAWN_RADIUS := 150.0
const FREE_RADIUS := 200.0
const CHECK_SECONDS := 0.5
## kind -> node script. Each extends WaysideSpotNode.
const KINDS := {
	&"rest": preload("res://systems/wayside/spots/wayside_rest.gd"),
	&"shimmer": preload("res://systems/wayside/spots/wayside_shimmer.gd"),
	&"pond_faeries": preload("res://systems/wayside/spots/wayside_pond_faeries.gd"),
	&"vignette": preload("res://systems/wayside/spots/wayside_vignette.gd"),
	&"nook": preload("res://systems/wayside/spots/wayside_nook.gd"),
	&"crossing": preload("res://systems/wayside/spots/wayside_crossing.gd"),
	&"snare": preload("res://systems/wayside/spots/wayside_snare.gd"),
	&"sentry": preload("res://systems/wayside/spots/wayside_sentry.gd"),
}

signal spot_found(spot_id: StringName, kind: StringName)

var routes: Array[WaysideRoute] = []
## spot id -> WaysideSpotNode currently in the tree.
var live: Dictionary = {}
## Overrides the player lookup (tests, tools).
var target: Node3D = null

var _spots: Array[WaysideSpot] = []
var _check_left := 0.0
var _last_point := Vector3.INF


func _ready() -> void:
	name = "Wayside"
	if routes.is_empty():
		load_routes(DATA_DIR)
	EventBus.flag_changed.connect(func(_f: String, _v: Variant) -> void: _check_left = 0.0)


func load_routes(dir_path: String) -> void:
	routes.clear()
	_spots.clear()
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	for file in DirAccess.get_files_at(dir_path):
		var clean := file.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var route := load("%s/%s" % [dir_path, clean]) as WaysideRoute
		if route:
			add_route(route)


func add_route(route: WaysideRoute) -> void:
	routes.append(route)
	_spots.append_array(route.spots)


func spots() -> Array[WaysideSpot]:
	return _spots


func _process(delta: float) -> void:
	var who := _who()
	if who == null:
		return
	_check_left -= delta
	# A teleport (a save loaded, a travel, a shot camera) updates at once.
	var jumped := who.global_position.distance_to(_last_point) > 40.0
	if _check_left > 0.0 and not jumped:
		return
	_check_left = CHECK_SECONDS
	_last_point = who.global_position
	update_for(who.global_position)


## Builds the spots near `point` and frees the far ones. Returns how many live.
func update_for(point: Vector3) -> int:
	var flat := Vector2(point.x, point.z)
	for spot in _spots:
		var d := flat.distance_to(Vector2(spot.position.x, spot.position.z))
		var has := live.has(spot.id)
		var active := spot.is_active(_flag)
		if not has and active and d <= SPAWN_RADIUS:
			_spawn(spot)
		elif has and (d > FREE_RADIUS or not active):
			var node: Node = live[spot.id]
			live.erase(spot.id)
			if is_instance_valid(node):
				node.queue_free()
	return live.size()


static func is_found(spot_id: StringName) -> bool:
	return WorldDeltas.get_region_value(REGION, String(spot_id), null) != null


static func mark_found(spot_id: StringName, value: Variant = true) -> void:
	WorldDeltas.set_region_value(REGION, String(spot_id), value)


static func found_value(spot_id: StringName, default: Variant = null) -> Variant:
	return WorldDeltas.get_region_value(REGION, String(spot_id), default)


func _spawn(spot: WaysideSpot) -> void:
	var script: GDScript = KINDS.get(spot.kind)
	if script == null:
		push_warning("Wayside: unknown kind '%s' for %s" % [spot.kind, spot.id])
		return
	var node: WaysideSpotNode = script.new()
	node.spot = spot
	node.director = self
	node.name = String(spot.id)
	add_child(node)
	node.global_position = spot.position
	node.rotation.y = spot.yaw
	live[spot.id] = node


## Feyre; with no player (shot probes, tools), the current camera.
func _who() -> Node3D:
	if target and is_instance_valid(target):
		return target
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	if p:
		return p
	return get_viewport().get_camera_3d() if is_inside_tree() else null


func _flag(flag: String) -> bool:
	return bool(WorldState.get_flag(flag, false))
