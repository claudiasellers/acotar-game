## Bakes the navmesh creatures and people walk on (T5), off the main thread:
## one tile around Feyre (TILE metres square, TILE_HEIGHT tall) from the
## loaded regions' static colliders plus the Terrain3D heightmap, re-baked
## when she wanders RECENTER metres from its centre. Region colliders are
## parsed once, when the region is ready, and cached.
## The manor's levels bake inside the same tile, all storeys at once, so the
## stairs join them (separate per-level regions would cut every flight at the
## level line). Creatures beyond the tile steer straight (NavMover's
## fallback), which is what they always did.
class_name NavBaker
extends Node

const TILE := 192.0
const RECENTER := 56.0
const TILE_HEIGHT := 160.0
const WORLD_LAYER := 1 << 0
## Main-thread parsing per frame while a region's colliders are read.
const PARSE_BUDGET_US := 4000

var tile_region: NavigationRegion3D
var tile_centre := Vector3.INF
var _sources: Dictionary = {}  # region id -> NavigationMeshSourceGeometryData3D
var _baking := false


## A walker-sized navmesh (people, wolves, the beast squeezes through doors).
static func make_mesh(aabb: AABB) -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.25
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 46.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = WORLD_LAYER
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nm.filter_baking_aabb = aabb
	return nm


## Parses `root`'s static colliders (main thread) into source geometry.
static func parse(root: Node, aabb: AABB = AABB()) -> NavigationMeshSourceGeometryData3D:
	var data := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(make_mesh(aabb), data, root)
	return data


## Bakes `region` from `source` inside `aabb`; synchronous unless `threaded`.
static func bake(region: NavigationRegion3D, source: NavigationMeshSourceGeometryData3D, aabb: AABB,
		threaded: bool = false, done: Callable = Callable()) -> void:
	var nm := make_mesh(aabb)
	if not threaded:
		NavigationServer3D.bake_from_source_geometry_data(nm, source)
		region.navigation_mesh = nm
		if done.is_valid():
			done.call()
		return
	NavigationServer3D.bake_from_source_geometry_data_async(nm, source, func() -> void:
		if is_instance_valid(region):
			region.navigation_mesh = nm
		if done.is_valid():
			done.call())


## The manor house's footprint and every level's floor-to-ceiling band, in
## world space (house layouts are in world coordinates).
static func manor_aabb() -> AABB:
	var span := Rect2()
	var lo := INF
	var hi := -INF
	var first := true
	for layout in ManorHouseBuilder.load_layouts():
		for room in layout.rooms:
			span = room.rect if first else span.merge(room.rect)
			first = false
			lo = minf(lo, ManorHouseBuilder.floor_y(room.level))
			hi = maxf(hi, ManorHouseBuilder.floor_y(room.level) + ManorHouseBuilder.storey_height(room.level))
	if first:
		return AABB()
	span = span.grow(2.0)
	return AABB(Vector3(span.position.x, lo - 0.5, span.position.y), Vector3(span.size.x, hi - lo + 1.0, span.size.y))


## Bakes `root`'s colliders inside `aabb` into a new NavigationRegion3D under
## `parent`, synchronously (tests, probes, the touch test).
static func bake_area(root: Node, aabb: AABB, parent: Node) -> NavigationRegion3D:
	var region := NavigationRegion3D.new()
	region.name = "NavArea"
	parent.add_child(region)
	bake(region, parse(root, aabb), aabb)
	return region


func _ready() -> void:
	tile_region = NavigationRegion3D.new()
	tile_region.name = "NavTile"
	add_child(tile_region)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_tick)
	add_child(timer)


func region_unloaded(id: StringName) -> void:
	_sources.erase(id)
	tile_centre = Vector3.INF


func _tick() -> void:
	var streamer := Gameplay.autoload(&"WorldStreamer")
	if streamer == null:
		return
	for id in streamer.loaded_ids():
		var sid := StringName(id)
		if _sources.has(sid) or not streamer.is_ready(sid):
			continue
		var root: Node3D = streamer.loaded_root(sid)
		if root == null:
			continue
		_sources[sid] = null  # parsing
		_parse_paced(sid, root)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player and not _baking and (tile_centre == Vector3.INF or _flat(player.global_position - tile_centre) > RECENTER):
		_bake_tile(player.global_position)


## Parses a region one child subtree per frame, so a big region (the manor:
## ~200 ms in one go) never hitches; the tile rebakes when it is done.
func _parse_paced(id: StringName, root: Node3D) -> void:
	var data := NavigationMeshSourceGeometryData3D.new()
	# Big holders (the house, the grounds) split into their children.
	var units: Array[Node] = []
	for child in root.get_children():
		if child.get_child_count() > 8 and not child is CollisionObject3D:
			units.append_array(child.get_children())
		else:
			units.append(child)
	var t0 := Time.get_ticks_usec()
	for unit in units:
		if not is_instance_valid(unit) or not _sources.has(id):
			return
		data.merge(parse(unit))
		if Time.get_ticks_usec() - t0 > PARSE_BUDGET_US:
			await get_tree().process_frame
			t0 = Time.get_ticks_usec()
	if _sources.has(id):
		_sources[id] = data
		tile_centre = Vector3.INF


func _bake_tile(at: Vector3) -> void:
	var source := NavigationMeshSourceGeometryData3D.new()
	for data: Variant in _sources.values():
		if data is NavigationMeshSourceGeometryData3D:
			source.merge(data)
	var aabb := AABB(Vector3(at.x - TILE * 0.5, at.y - TILE_HEIGHT * 0.5, at.z - TILE * 0.5), Vector3(TILE, TILE_HEIGHT, TILE))
	var terrain := _terrain()
	if terrain and terrain.has_method(&"generate_nav_mesh_source_geometry"):
		var faces: PackedVector3Array = terrain.call(&"generate_nav_mesh_source_geometry", aabb, false)
		if not faces.is_empty():
			source.add_faces(faces, Transform3D.IDENTITY)
	if not source.has_data():
		return
	_baking = true
	tile_centre = at
	bake(tile_region, source, aabb, true, func() -> void: _baking = false)


func _terrain() -> Node:
	for n in get_tree().get_nodes_in_group(&"world"):
		var t: Variant = n.get(&"terrain")
		if t is Node:
			return t
	return null


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
