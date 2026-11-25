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
## The tile's terrain faces are read a strip this wide at a time, under
## FrameBudget (T161: the whole tile in one call held a frame ~80-110 ms).
const TERRAIN_STRIP := 8.0

var tile_region: NavigationRegion3D
var tile_centre := Vector3.INF
var _sources: Dictionary = {}  # region id -> NavigationMeshSourceGeometryData3D
var _baking := false
## The tile bake in flight: bake()'s job, [WorkerThreadPool task id], or [-1].
var _bake_job: Array = [-1]


## A walker-sized navmesh (people, wolves, the beast squeezes through doors).
static func make_mesh(aabb: AABB) -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.25
	nm.agent_height = 1.5
	# One cell (0.25 = cell_height) and triangles only: at two cells (0.5) over
	# stepped terrain, and with merged 6-vertex polygons, the bake leaves three
	# polygons on one edge and the server logs "Navigation region synchronization
	# had N edge error(s)" (T129; the stable-yard hills, e.g. tiles centred (60,-40)).
	# Stairs are smooth ramps and risers are 0.19, so nothing walkable is lost.
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 46.0
	nm.cell_size = 0.25
	nm.vertices_per_polygon = 3.0
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = WORLD_LAYER
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nm.filter_baking_aabb = aabb
	return nm


## Thread of the last parse (tests check it is the main thread).
static var last_parse_thread: int = -1


## Parses `root`'s static colliders into source geometry. Main thread only:
## it reads the scene tree; only the bake itself goes to a worker thread, and
## nothing on that thread touches scenes, glTF or CourtAssets (F27, L32-3, F37).
static func parse(root: Node, aabb: AABB = AABB()) -> NavigationMeshSourceGeometryData3D:
	last_parse_thread = OS.get_thread_caller_id()
	assert(last_parse_thread == OS.get_main_thread_id(), "NavBaker.parse off the main thread")
	var data := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(make_mesh(aabb), data, root)
	return data


## Bakes `region` from `source` inside `aabb`; synchronous unless `threaded`.
## Returns the job, [WorkerThreadPool task id] while a threaded bake may still
## run, [-1] once it is claimed. join() it before the engine can shut down.
##
## The threaded bake runs on a pool task of ours, not the navigation server's
## bake_from_source_geometry_data_async: that one can't be waited for (it only
## reports done on a main-thread sync, a frame later), and one still on the
## server's thread at quit aborted the process in the engine's shutdown with
## "recursive_mutex lock failed: Invalid argument" (T146).
## `parts` (more source geometry) and `faces` (world-space triangles) are
## merged into `source` first, on the bake's own thread when threaded.
static func bake(region: NavigationRegion3D, source: NavigationMeshSourceGeometryData3D, aabb: AABB,
		threaded: bool = false, done: Callable = Callable(), parts: Array = [],
		faces: PackedVector3Array = PackedVector3Array()) -> Array:
	var nm := make_mesh(aabb)
	if not threaded:
		_assemble(source, parts, faces)
		NavigationServer3D.bake_from_source_geometry_data(nm, source)
		drop_overlapping_polygons(nm)
		region.navigation_mesh = nm
		if done.is_valid():
			done.call()
		return [-1]
	var job: Array = [-1]
	# The bake runs on a pool thread: hand the result to the main thread.
	# Hold the region weakly: a lambda capturing a freed node logs "Lambda capture
	# at index 0 was freed" when the scene is freed before the bake lands (T110).
	var region_ref: WeakRef = weakref(region)
	var land := func() -> void:
		NavBaker.join(job)
		var r := region_ref.get_ref() as NavigationRegion3D
		if r != null:
			r.navigation_mesh = nm
		if done.is_valid():
			done.call()
	# Clean the mesh on the same thread (it touches only `nm`), so the main
	# thread only assigns it.
	job[0] = WorkerThreadPool.add_task(func() -> void:
		NavBaker._assemble(source, parts, faces)
		NavigationServer3D.bake_from_source_geometry_data(nm, source)
		NavBaker.drop_overlapping_polygons(nm)
		land.call_deferred(), false, "nav_bake")
	return job


## Pure data (the parts are cached and never changed once made), so it is safe on the bake thread.
static func _assemble(source: NavigationMeshSourceGeometryData3D, parts: Array, faces: PackedVector3Array) -> void:
	for data: NavigationMeshSourceGeometryData3D in parts:
		source.merge(data)
	if not faces.is_empty():
		source.add_faces(faces, Transform3D.IDENTITY)


## Waits for a threaded bake() job to finish, once; later calls do nothing.
## Main thread only.
static func join(job: Array) -> void:
	if job.is_empty() or int(job[0]) < 0:
		return
	var task := int(job[0])
	job[0] = -1
	WorkerThreadPool.wait_for_task_completion(task)


## Recast can leave three polygons on one edge where stepped terrain folds over
## itself. The navigation server then logs "Navigation region synchronization had
## N edge error(s)" (an error to GUT) and the edge connects wrongly (T129). Drops
## the smallest polygon of any such edge, to 1 cm; returns how many it dropped.
## Still needed after T142: rare, but measured (three triangles on one vertex
## pair, court tile at (-222,-104)). The commoner cause of that warning, distinct
## vertices sharing one server edge key, is navigation/3d/merge_rasterizer_cell_scale.
## Pure data on `nm`, so it is safe on the bake thread.
static func drop_overlapping_polygons(nm: NavigationMesh) -> int:
	var verts := nm.get_vertices()
	var count := nm.get_polygon_count()
	var polys: Array[PackedInt32Array] = []
	var edges := {}  # sorted vertex-key pair -> polygon indices
	for i in count:
		var poly := nm.get_polygon(i)
		polys.append(poly)
		for j in poly.size():
			var ka := Vector3i((verts[poly[j]] * 100.0).round())
			var kb := Vector3i((verts[poly[(j + 1) % poly.size()]] * 100.0).round())
			if ka == kb:
				continue
			var key := [ka, kb] if (ka.x < kb.x or (ka.x == kb.x and (ka.y < kb.y or (ka.y == kb.y and ka.z < kb.z)))) else [kb, ka]
			if edges.has(key):
				edges[key].append(i)
			else:
				edges[key] = [i]
	var dropped := {}
	for key: Array in edges:
		var users: Array = edges[key]
		while users.size() > 2:
			var worst := -1
			var worst_area := INF
			for u: int in users:
				if dropped.has(u):
					continue
				var a := _poly_area(verts, polys[u])
				if a < worst_area:
					worst_area = a
					worst = u
			if worst < 0:
				break
			dropped[worst] = true
			users = users.filter(func(u: int) -> bool: return not dropped.has(u))
	if dropped.is_empty():
		return 0
	nm.clear_polygons()
	for i in count:
		if not dropped.has(i):
			nm.add_polygon(polys[i])
	return dropped.size()


static func _poly_area(verts: PackedVector3Array, poly: PackedInt32Array) -> float:
	var sum := Vector3.ZERO
	for j in range(1, poly.size() - 1):
		sum += (verts[poly[j]] - verts[poly[0]]).cross(verts[poly[j + 1]] - verts[poly[0]])
	return sum.length()


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


## Leaving the tree (a scene change, New Game's relaunch, quitting, a test's
## end): a tile still baking is waited for here, so no bake outlives the game
## into the engine's shutdown (T146).
func _exit_tree() -> void:
	NavBaker.join(_bake_job)


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


## Reads the tile's terrain a strip a frame (paced), then bakes on a worker,
## which also merges the regions' cached sources in.
func _bake_tile(at: Vector3) -> void:
	_baking = true
	_gather_paced(weakref(self), at, BuildPace.new(get_tree()))


static func _gather_paced(me: WeakRef, at: Vector3, pace: BuildPace) -> void:
	var b := me.get_ref() as NavBaker
	if b == null:
		return
	var parts: Array = []
	for data: Variant in b._sources.values():
		if data is NavigationMeshSourceGeometryData3D and (data as NavigationMeshSourceGeometryData3D).has_data():
			parts.append(data)
	var aabb := AABB(Vector3(at.x - TILE * 0.5, at.y - TILE_HEIGHT * 0.5, at.z - TILE * 0.5), Vector3(TILE, TILE_HEIGHT, TILE))
	var terrain := b._terrain()
	var faces := PackedVector3Array()
	if terrain and terrain.has_method(&"generate_nav_mesh_source_geometry"):
		var tref: WeakRef = weakref(terrain)
		b = null
		var x := aabb.position.x
		while x < aabb.end.x:
			# Strips overlap a metre each side, so no row of quads falls between two.
			var strip := AABB(Vector3(x - 1.0, aabb.position.y, aabb.position.z), Vector3(TERRAIN_STRIP + 2.0, aabb.size.y, aabb.size.z))
			faces.append_array(terrain.call(&"generate_nav_mesh_source_geometry", strip, false))
			x += TERRAIN_STRIP
			terrain = null
			await pace.tick()
			b = me.get_ref() as NavBaker
			terrain = tref.get_ref() as Node
			if b == null:
				return
			if terrain == null:
				b._baking = false
				return
			b = null
		b = me.get_ref() as NavBaker
	if b == null:
		return
	if parts.is_empty() and faces.is_empty():
		b._baking = false
		return
	b.tile_centre = at
	b._bake_job = bake(b.tile_region, NavigationMeshSourceGeometryData3D.new(), aabb, true, func() -> void:
		var nb := me.get_ref() as NavBaker
		if nb != null:
			nb._baking = false, parts, faces)


func _terrain() -> Node:
	for n in get_tree().get_nodes_in_group(&"world"):
		var t: Variant = n.get(&"terrain")
		if t is Node:
			return t
	return null


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
