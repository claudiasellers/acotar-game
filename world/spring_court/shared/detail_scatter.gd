## Dense ground cover (grass, bluebells, anemones, moss...) built only around
## Feyre, in square cells generated on a worker thread from the region's
## biomes. Far cells are freed; the same cell always regenerates identically.
class_name DetailScatter
extends Node3D

const CELL := 48.0
const RADIUS_CELLS := 2

var def: WoodsRegionDef
var bounds: Rect2

var _cells: Dictionary = {}       # Vector2i -> Node3D
var _pending: Dictionary = {}     # Vector2i -> task id
var _results: Dictionary = {}     # Vector2i -> Dictionary of placements
var _mutex := Mutex.new()
var _timer := 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	_collect()
	var focus: Variant = _focus()
	if focus == null:
		return
	var here := Vector2i(floori(focus.x / CELL), floori(focus.z / CELL))
	var wanted := {}
	for dz in range(-RADIUS_CELLS, RADIUS_CELLS + 1):
		for dx in range(-RADIUS_CELLS, RADIUS_CELLS + 1):
			var key := here + Vector2i(dx, dz)
			var rect := Rect2(key.x * CELL, key.y * CELL, CELL, CELL)
			if rect.intersects(bounds):
				wanted[key] = true
	for key: Vector2i in _cells.keys():
		if not wanted.has(key):
			_cells[key].queue_free()
			_cells.erase(key)
	for key: Vector2i in wanted:
		if not _cells.has(key) and not _pending.has(key):
			_pending[key] = WorkerThreadPool.add_task(_generate.bind(key))


func _exit_tree() -> void:
	for key in _pending:
		WorkerThreadPool.wait_for_task_completion(_pending[key])
	_pending.clear()


func cell_count() -> int:
	return _cells.size()


## Placements for one cell (pure, deterministic): { species: PackedFloat32Array }.
func placements_for(key: Vector2i) -> Dictionary:
	var rect := Rect2(key.x * CELL, key.y * CELL, CELL, CELL).intersection(bounds)
	return WoodsScatter.place(def, rect, "detail", key.x * 7919 + key.y)


func _generate(key: Vector2i) -> void:
	var data := placements_for(key)
	_mutex.lock()
	_results[key] = data
	_mutex.unlock()


func _collect() -> void:
	_mutex.lock()
	var done := _results.duplicate()
	_results.clear()
	_mutex.unlock()
	for key: Vector2i in done:
		if _pending.has(key):
			WorkerThreadPool.wait_for_task_completion(_pending[key])
			_pending.erase(key)
		_cells[key] = _build_cell(key, done[key])


func _build_cell(key: Vector2i, data: Dictionary) -> Node3D:
	var cell := Node3D.new()
	cell.name = "Cell_%d_%d" % [key.x, key.y]
	var origin := Vector3((key.x + 0.5) * CELL, 0.0, (key.y + 0.5) * CELL)
	cell.position = origin
	for species: StringName in data:
		var inst: PackedFloat32Array = data[species]
		var n := inst.size() / ScatterLayer.STRIDE
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = FloraLibrary.mesh(species)
		mm.instance_count = n
		for i in n:
			var o := i * ScatterLayer.STRIDE
			var s := inst[o + 4]
			var t := Transform3D(Basis(Vector3.UP, inst[o + 3]).scaled(Vector3(s, s, s)),
					Vector3(inst[o], inst[o + 1], inst[o + 2]) - origin)
			mm.set_instance_transform(i, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = float(FloraLibrary.info(species).get("range", 70.0))
		mmi.visibility_range_end_margin = 6.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mmi.set_instance_shader_parameter(&"wind_amount", 0.8)
		cell.add_child(mmi)
	add_child(cell)
	return cell


func _focus() -> Variant:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null:
		return player.global_position
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam != null:
		return cam.global_position
	return null
