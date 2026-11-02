## Keeps the regions around Feyre loaded and the rest unloaded.
##
## A region loads when Feyre is within `load_margin` of its edge, or when it is
## a neighbor of the region she stands in. It unloads only past
## `unload_margin`, so walking along a border never thrashes. Loading is
## threaded; set `synchronous` for tests and tools.
##
## Loads queue nearest first, with one in flight besides the region she is
## in (or arriving at, after a teleport). That region skips the queue, and
## nothing else is requested or instanced until it has landed, so it never
## waits behind its neighbours (act1-fixlist F16: the manor took 97 s behind
## seven parallel loads).
##
## Locks are not the streamer's job: a loaded region that the phase has not
## opened is still loaded, and its RegionGate keeps Feyre out.
extends Node

signal region_loaded(region_id: StringName, root: Node3D)
signal region_unloaded(region_id: StringName)

@export var load_margin: float = 300.0
@export var unload_margin: float = 450.0
@export var update_interval: float = 0.5
## Background loads in flight at once, besides her region.
@export var max_in_flight: int = 1
var synchronous: bool = false

var _regions: Dictionary = {}   # id (String) -> RegionDef
var _loaded: Dictionary = {}    # id -> Node3D
var _pending: Dictionary = {}   # id -> scene path being loaded in a thread
var _parent: Node3D
var _target: Node3D
var _timer: float = 0.0
var _focus: String = ""      # the region at the last update point: loads first
var _queue: Array[String] = []  # wanted, not started; nearest first


## Sets the regions of the current world and where their scenes are added.
func configure(regions: Array, parent: Node3D) -> void:
	unload_all()
	_regions.clear()
	for region in regions:
		if region is RegionDef:
			_regions[String(region.id)] = region
	_parent = parent


## Loads every RegionDef .tres in a folder (e.g. res://data/regions/human_realm).
func configure_from_dir(dir_path: String, parent: Node3D) -> void:
	var regions: Array = []
	for file in DirAccess.get_files_at(dir_path):
		var clean := file.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			var res := load("%s/%s" % [dir_path, clean])
			if res is RegionDef:
				regions.append(res)
	configure(regions, parent)


## Every RegionDef under a folder at any depth (res://data/regions for the
## whole map). Other resources there (biome tables, layouts) are skipped by
## their header, without loading them.
func configure_from_tree(root_dir: String, parent: Node3D) -> void:
	configure(find_region_defs(root_dir), parent)


static func find_region_defs(root_dir: String) -> Array:
	var regions: Array = []
	if not DirAccess.dir_exists_absolute(root_dir):
		return regions
	for file in DirAccess.get_files_at(root_dir):
		var clean := file.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var path := "%s/%s" % [root_dir, clean]
		if not FileAccess.get_file_as_string(path).substr(0, 200).contains('script_class="RegionDef"'):
			continue
		var res := load(path)
		if res is RegionDef:
			regions.append(res)
	for sub in DirAccess.get_directories_at(root_dir):
		regions.append_array(find_region_defs("%s/%s" % [root_dir, sub]))
	return regions


func track(target: Node3D) -> void:
	_target = target
	_timer = 0.0


func get_region(region_id: StringName) -> RegionDef:
	return _regions.get(String(region_id))


func is_loaded(region_id: StringName) -> bool:
	return _loaded.has(String(region_id))


func loaded_root(region_id: StringName) -> Node3D:
	return _loaded.get(String(region_id))


func loaded_ids() -> PackedStringArray:
	return PackedStringArray(_loaded.keys())


## The region Feyre is standing in. In the wider court the macro-map's
## rectangles decide (docs/contracts/world.md), because the streaming circles
## overlap a lot there: the Blighted Reaches' circle covers the solstice
## plateau more deeply than the meadow's own does. Elsewhere, the circle whose
## edge she is deepest inside.
func region_at(point: Vector3) -> RegionDef:
	var mapped := CourtMap.region_at(point.x, point.z)
	if mapped != &"" and _regions.has(String(mapped)):
		return _regions[String(mapped)]
	var best: RegionDef = null
	var best_d := 0.0
	for region: RegionDef in _regions.values():
		var d := region.edge_distance(point)
		if d <= 0.0 and (best == null or d < best_d):
			best = region
			best_d = d
	return best


## The set of region ids that should be loaded for a point.
func wanted_at(point: Vector3) -> PackedStringArray:
	var wanted := {}
	var here := region_at(point)
	if here:
		wanted[String(here.id)] = true
		for neighbor in here.neighbors:
			if _regions.has(neighbor):
				wanted[neighbor] = true
	for region: RegionDef in _regions.values():
		if region.edge_distance(point) <= load_margin:
			wanted[String(region.id)] = true
	return PackedStringArray(wanted.keys())


## Brings the loaded set in line with a point. Called on a timer while
## tracking; call it directly to stream immediately (teleports, loading a save).
func update_for(point: Vector3) -> void:
	var wanted := wanted_at(point)
	var here := region_at(point)
	_focus = String(here.id) if here else ""
	_queue.clear()
	for id in wanted:
		if not _loaded.has(id) and not _pending.has(id) and id != _focus:
			_queue.append(id)
	_queue.sort_custom(func(a: String, b: String) -> bool:
		return _regions[a].edge_distance(point) < _regions[b].edge_distance(point))
	if _focus != "" and not _loaded.has(_focus) and not _pending.has(_focus):
		_begin_load(_focus)
	_pump()
	for id in _loaded.keys():
		if wanted.has(id):
			continue
		var region: RegionDef = _regions.get(id)
		if region == null or region.edge_distance(point) > unload_margin:
			_unload(id)


func unload_all() -> void:
	for id in _loaded.keys():
		_unload(id)
	_pending.clear()
	_queue.clear()
	_focus = ""


## True while the region she is in is still loading.
func _focus_waiting() -> bool:
	return _focus != "" and _pending.has(_focus)


## Starts queued loads while there is room and her region is not waiting.
func _pump() -> void:
	while not _queue.is_empty() and not _focus_waiting():
		if _pending.size() >= max_in_flight:
			return
		var id: String = _queue.pop_front()
		if not _loaded.has(id) and not _pending.has(id):
			_begin_load(id)


func _process(delta: float) -> void:
	_poll_pending()
	if _target == null or not is_instance_valid(_target):
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = update_interval
		update_for(_target.global_position)


func _begin_load(id: String) -> void:
	var region: RegionDef = _regions[id]
	if region.scene_path.is_empty():
		push_warning("WorldStreamer: region '%s' has no scene" % id)
		return
	if synchronous:
		_finish_load(id, load(region.scene_path) as PackedScene)
		return
	var err := ResourceLoader.load_threaded_request(region.scene_path)
	if err != OK:
		push_error("WorldStreamer: cannot load '%s' (%s)" % [region.scene_path, error_string(err)])
		return
	_pending[id] = region.scene_path


func _poll_pending() -> void:
	for id in _pending.keys():
		if id != _focus and _focus_waiting():
			continue  # a finished neighbour waits: instancing it would slow hers
		var path: String = _pending[id]
		match ResourceLoader.load_threaded_get_status(path):
			ResourceLoader.THREAD_LOAD_LOADED:
				_pending.erase(id)
				_finish_load(id, ResourceLoader.load_threaded_get(path) as PackedScene)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_pending.erase(id)
				push_error("WorldStreamer: loading '%s' failed" % path)
	_pump()


func _finish_load(id: String, scene: PackedScene) -> void:
	if scene == null or _parent == null or not is_instance_valid(_parent):
		return
	var root := scene.instantiate() as Node3D
	if root == null:
		push_error("WorldStreamer: region '%s' root must be a Node3D" % id)
		return
	root.name = "Region_%s" % id
	_parent.add_child(root)
	_loaded[id] = root
	region_loaded.emit(StringName(id), root)


func _unload(id: String) -> void:
	var root: Node3D = _loaded.get(id)
	_loaded.erase(id)
	if root and is_instance_valid(root):
		root.queue_free()
	region_unloaded.emit(StringName(id))
