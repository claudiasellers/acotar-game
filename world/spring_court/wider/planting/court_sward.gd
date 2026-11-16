class_name CourtSward
extends Node3D
## The grass of a place, laid round whoever is looking (docs/lanes/
## court-planting-by-place.md). A region's open ground is far too much grass
## to hold at once (the glen alone would be four million tufts), so the sward
## lives in cells of CELL metres: the cells within REACH of the camera are
## grown on worker threads from the land itself, and let go when the camera
## has left them behind. A cell is the same every time it grows.
##
## What grows where, read from the land:
##   sward       everywhere a small plant can stand: not water, not a path, not
##               rock, and only on the region's own ground
##   fine grass  mixed through it close to the eye
##   long grass  at the water's edge, in the dips, and round a trunk's foot
##   daisies     on slopes that face the sun, in the open
## Far cells draw fewer of their tufts (a cell's tufts are in no order, so the
## first n are an even thinning).

const GROUP := &"court_sward"
const CELL := 16.0
## How far the sward is laid from the camera (m), and how far out the cells
## are let go (so walking a cell's edge does not grow and drop it).
const REACH := 84.0
const DROP := 100.0
## Tufts tried per m2 (about a fifth find water, path, rock or a thin place).
const DENSITY := 4.6
## Share of a cell's tufts drawn by distance from the camera: all of them to
## FULL metres (and past it in the sward's far form), thinning to FAR_SHARE at
## REACH.
const FULL := 34.0
const FAR_SHARE := 0.4
## Fine grass is drawn within this many metres only.
const FINE_REACH := 40.0
## Cells grown at once, and applied per frame.
const WORKERS := 4
const APPLY_PER_FRAME := 3
## The lattice a cell reads the land on (m): heights and the distances to
## paths and brooks are sampled here and read between.
const LATTICE := 1.0

@export var content: CourtRegionContent
## Trunks to grow long grass round (the place's planting gives them).
var trunks := PackedVector2Array()

var _cells := {}      # Vector2i -> Node3D (holding the cell's multimeshes), or null while it grows
var _tasks := {}      # Vector2i -> task id
var _done := {}       # Vector2i -> grown data, waiting to be applied
var _lock := Mutex.new()
var _trunk_grid := {}
var _last_cell := Vector2i(1 << 30, 0)
var _wave := FastNoiseLite.new()
var _closing := false
var _last_eye := Vector2(INF, INF)


func _ready() -> void:
	add_to_group(GROUP)
	_wave.seed = 7
	_wave.frequency = 0.035
	for t in trunks:
		var key := Vector2i(floori(t.x / 4.0), floori(t.y / 4.0))
		if not _trunk_grid.has(key):
			_trunk_grid[key] = PackedVector2Array()
		(_trunk_grid[key] as PackedVector2Array).append(t)


func _exit_tree() -> void:
	_closing = true
	for key: Vector2i in _tasks:
		WorkerThreadPool.wait_for_task_completion(_tasks[key])
	_tasks.clear()
	_done.clear()


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or content == null:
		return
	_tend(cam.global_position, false)


## Lay the sward round a standpoint now, every cell (for a still picture, or
## a test): no waiting on the workers.
func settle(eye: Vector3) -> void:
	_tend(eye, true)


func _tend(eye: Vector3, now: bool) -> void:
	var here := Vector2(eye.x, eye.z)
	var cell := Vector2i(floori(here.x / CELL), floori(here.y / CELL))
	# take what the workers have grown
	var applied := 0
	_lock.lock()
	var ready_keys: Array = _done.keys()
	_lock.unlock()
	for key: Vector2i in ready_keys:
		if applied >= APPLY_PER_FRAME and not now:
			break
		if WorkerThreadPool.is_task_completed(_tasks[key]):
			WorkerThreadPool.wait_for_task_completion(_tasks[key])
			_tasks.erase(key)
			_lock.lock()
			var data: Dictionary = _done[key]
			_done.erase(key)
			_lock.unlock()
			_apply(key, data)
			applied += 1
	if cell != _last_cell or now:
		_last_cell = cell
		var span := int(ceil(REACH / CELL)) + 1
		var wanted: Array[Vector2i] = []
		for dz in range(-span, span + 1):
			for dx in range(-span, span + 1):
				var key := cell + Vector2i(dx, dz)
				if _cell_distance(key, here) < REACH and not _cells.has(key):
					wanted.append(key)
		# nearest first
		wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _cell_distance(a, here) < _cell_distance(b, here))
		for key in wanted:
			if now:
				_cells[key] = null
				_apply(key, _grow(key))
			elif _tasks.size() < WORKERS:
				_cells[key] = null
				_tasks[key] = WorkerThreadPool.add_task(_grow_task.bind(key), false, "court_sward")
			else:
				_last_cell = Vector2i(1 << 30, 0)   # more to start next frame
				break
		for key: Vector2i in _cells.keys():
			if _cell_distance(key, here) > DROP and not _tasks.has(key):
				if _cells[key] != null:
					(_cells[key] as Node3D).queue_free()
				_cells.erase(key)
	# thin the far cells, hide fine grass past its reach
	if applied == 0 and here.distance_to(_last_eye) < 1.5 and not now:
		return
	_last_eye = here
	for key: Vector2i in _cells:
		var holder := _cells[key] as Node3D
		if holder == null:
			continue
		var d := _cell_distance(key, here)
		var share := 1.0 if d <= FULL else lerpf(1.0, FAR_SHARE, clampf((d - FULL) / (REACH - FULL), 0.0, 1.0))
		for child: MultiMeshInstance3D in holder.get_children():
			var mm := child.multimesh
			if child.name == &"fine":
				child.visible = d < FINE_REACH
			elif child.name == &"sward":
				child.visible = d <= FULL
			elif child.name == &"sward_far":
				# past the near cells the sward is its far form (a third of the blades, broader), thinning out
				child.visible = d > FULL
				var far_count := int(mm.instance_count * lerpf(1.0, FAR_SHARE, clampf((d - FULL) / (REACH - FULL), 0.0, 1.0)))
				if mm.visible_instance_count != far_count:
					mm.visible_instance_count = far_count
			else:
				var count := int(mm.instance_count * share) if share < 0.999 else -1
				if mm.visible_instance_count != count:
					mm.visible_instance_count = count
		holder.visible = d < REACH + CELL


static func _cell_distance(key: Vector2i, here: Vector2) -> float:
	# from the eye to the nearest point of the cell
	var lo := Vector2(key) * CELL
	return here.distance_to(here.clamp(lo, lo + Vector2(CELL, CELL)))


func _grow_task(key: Vector2i) -> void:
	if _closing:
		return
	var data := _grow(key)
	_lock.lock()
	_done[key] = data
	_lock.unlock()


## One cell's tufts, read from the land: { kind: PackedFloat32Array of
## 12-float transforms, relative to the cell's middle }, and "mid".
func _grow(key: Vector2i) -> Dictionary:
	var origin := Vector2(key) * CELL
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([content.seed, key.x, key.y, "sward"])
	# the land on a lattice (one row and column beyond, for slopes)
	var n := int(CELL / LATTICE) + 3
	var heights := PackedFloat32Array()
	var paths := PackedFloat32Array()
	var brooks := PackedFloat32Array()
	heights.resize(n * n)
	paths.resize(n * n)
	brooks.resize(n * n)
	var any_ground := false
	for j in n:
		for i in n:
			var x := origin.x + (i - 1) * LATTICE
			var z := origin.y + (j - 1) * LATTICE
			heights[j * n + i] = WorldHeight.height_at(x, z)
			paths[j * n + i] = CourtLandHabitats.path_distance(x, z)
			brooks[j * n + i] = CourtHeight.distance_to_brook(x, z)
	# the lie of the land round the cell, for the dips (a coarse lattice out to 14 m)
	var mid2 := origin + Vector2(CELL, CELL) * 0.5
	var mid := Vector3(mid2.x, WorldHeight.height_at(mid2.x, mid2.y), mid2.y)
	var round_about := 0.0
	for k in 8:
		var q := mid2 + Vector2.from_angle(TAU * k / 8.0) * (CELL * 0.5 + 14.0)
		round_about += CourtHeight.height_at(q.x, q.y) / 8.0
	var lakes: Array = CourtHeight.lakes()
	var out := {"sward": PackedFloat32Array(), "fine": PackedFloat32Array(), "tall": PackedFloat32Array(), "daisy": PackedFloat32Array(),
		"mid": mid}
	for t in int(CELL * CELL * DENSITY):
		var px := rng.randf() * CELL
		var pz := rng.randf() * CELL
		var turn := rng.randf() * TAU
		var size := rng.randf_range(0.85, 1.4)
		var tall_y := rng.randf_range(0.8, 1.3)
		var roll := rng.randf()
		var p := origin + Vector2(px, pz)
		# soft thin places
		if rng.randf() > 0.84 + 0.16 * _wave.get_noise_2d(p.x * 2.0, p.y * 2.0):
			continue
		var fx := px / LATTICE + 1.0
		var fz := pz / LATTICE + 1.0
		var i0 := int(fx)
		var j0 := int(fz)
		var u := fx - i0
		var v := fz - j0
		var a := j0 * n + i0
		var path_d := lerpf(lerpf(paths[a], paths[a + 1], u), lerpf(paths[a + n], paths[a + n + 1], u), v)
		var brook_d := lerpf(lerpf(brooks[a], brooks[a + 1], u), lerpf(brooks[a + n], brooks[a + n + 1], u), v)
		if path_d < 0.25 or brook_d < 0.15:
			continue
		var h00 := heights[a]
		var h10 := heights[a + 1]
		var h01 := heights[a + n]
		var h11 := heights[a + n + 1]
		# rock: too steep to grow on
		if maxf(absf(h10 - h00), absf(h01 - h00)) > 0.7 * LATTICE:
			continue
		var y := lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), v)
		# standing water: a lake or the pool, and the river
		var wet_edge := brook_d < 1.6
		var in_water := false
		for l: Dictionary in lakes:
			var from_rim: float = p.distance_to(l["center"]) - float(l["radius"])
			if from_rim < 0.2:
				in_water = true
			elif from_rim < 2.4:
				wet_edge = true
		if in_water or MacroHeight.distance_to_river(p.x, p.y) < MacroHeight.RIVER_HALF_WIDTH + 0.5 or not content.owns(p):
			continue
		any_ground = true
		size *= 1.0 + 0.3 * _wave.get_noise_2d(p.x * 5.0, p.y * 5.0)
		var kind := "sward"
		var in_dip := round_about - y > 2.2 and absf(h10 - h00) + absf(h01 - h00) < 0.12
		var sunny := h00 - h01 > 0.085 * LATTICE   # the ground falls to the south (+z)
		if (wet_edge or in_dip or _by_trunk(p)) and roll < 0.5:
			kind = "tall"
			if in_dip:
				size *= 1.2
		elif roll < (0.07 if sunny else 0.008) and _wave.get_noise_2d(p.x * 3.0, p.y * 3.0) > -0.1 and not _shaded(p):
			kind = "daisy"
			size = lerpf(0.7, 1.1, roll * 12.0 - floorf(roll * 12.0))
			tall_y = 1.0
		elif roll < 0.3:
			kind = "fine"
		var b := Basis(Vector3.UP, turn).scaled(Vector3(size, size * tall_y, size))
		var arr: PackedFloat32Array = out[kind]
		arr.append_array(PackedFloat32Array([b.x.x, b.y.x, b.z.x, p.x - mid.x, b.x.y, b.y.y, b.z.y, y - mid.y, b.x.z, b.y.z, b.z.z, p.y - mid.z]))
		out[kind] = arr
	out["empty"] = not any_ground
	return out


func _by_trunk(p: Vector2) -> bool:
	return _near_trunk(p, 1.6)


func _shaded(p: Vector2) -> bool:
	return _near_trunk(p, 4.0)


func _near_trunk(p: Vector2, within: float) -> bool:
	var key := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := key + Vector2i(dx, dz)
			if _trunk_grid.has(k):
				for t: Vector2 in _trunk_grid[k]:
					if t.distance_to(p) < within:
						return true
	return false


func _apply(key: Vector2i, data: Dictionary) -> void:
	if not _cells.has(key):
		return   # dropped while it grew
	var holder := Node3D.new()
	holder.name = "cell_%d_%d" % [key.x, key.y]
	holder.position = data["mid"]
	var pick := absi(hash(key))
	var meshes := {
		"sward": CourtPlacePlants.glade("grass_sward_" + "abc"[pick % 3]),
		"sward_far": CourtPlacePlants.glade("grass_sward_far_" + "abc"[pick % 3]),
		"fine": CourtPlacePlants.glade("grass_glade_" + "abc"[(pick / 3) % 3]),
		"tall": CourtPlacePlants.glade("grass_tall_" + "ab"[(pick / 9) % 2]),
		"daisy": FloraLibrary.mesh(&"daisy"),
	}
	for kind: String in meshes:
		var buffer: PackedFloat32Array = data["sward" if kind == "sward_far" else kind]
		if buffer.is_empty() or meshes[kind] == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[kind]
		mm.instance_count = buffer.size() / 12
		mm.buffer = buffer
		var mmi := MultiMeshInstance3D.new()
		mmi.name = kind
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# a cell's tufts stand within its square and a tuft's height of its middle's level, give or take the slope
		mmi.custom_aabb = AABB(Vector3(-CELL * 0.5 - 1.0, -CELL, -CELL * 0.5 - 1.0), Vector3(CELL + 2.0, CELL * 2.0, CELL + 2.0))
		holder.add_child(mmi)
	_cells[key] = holder
	add_child(holder)


## How many cells are laid (grown and applied) and how many tufts they hold.
func census() -> Dictionary:
	var cells := 0
	var tufts := 0
	for key: Vector2i in _cells:
		var holder := _cells[key] as Node3D
		if holder == null:
			continue
		cells += 1
		for child: MultiMeshInstance3D in holder.get_children():
			tufts += child.multimesh.instance_count
	return {"cells": cells, "tufts": tufts, "growing": _tasks.size()}
