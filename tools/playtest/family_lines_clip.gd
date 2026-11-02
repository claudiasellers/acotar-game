## Proof clip for L34-5: Nesta, Elain and their father speak only face to face.
## From the real game scene, through Feyre's own camera, at dusk in winter:
##   yard     she stands in the snow a step from Nesta, through the wall, and
##            looks at the cottage: no family line
##   inside   she walks in by the door (whoever she sees ahead may speak), then
##            looks at the empty corner: none while she does
##   faces    she turns to each of them in turn, up close: each one speaks
## Headless it plays and logs each line (with where she stood and whether they
## were face to face); with a display it also writes frames:
##   {out}/family_####.jpg at 4 fps (1280x720) plus the playtest report.
## Exits 0 when the yard and the corner are silent for the family and at least
## two of them speak once she's looking at them.
extends "res://tools/playtest/act1_playtest.gd"

const FPS := 4.0
const SAVE_SIZE := Vector2i(1280, 720)
const COTTAGE := &"act1_cottage_interior"
const FAMILY := [&"nesta", &"elain", &"father"]
const HOUR := 18.0

var _rec: bool = false
var _rec_left: float = 0.0
var _rec_count: int = 0
var _frames_dir: String = ""
var _t0: int = 0
var _phase: String = "spawn"
## {phase: [speakers of family lines heard in it]}
var family_heard: Dictionary = {}
var director: DialogueDirector
var cottage: Node3D


func _process(delta: float) -> void:
	if not _rec or DisplayServer.get_name() == "headless":
		return
	_rec_left -= delta / maxf(Engine.time_scale, 0.01)
	if _rec_left > 0.0:
		return
	_rec_left = 1.0 / FPS
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	img.resize(SAVE_SIZE.x, SAVE_SIZE.y, Image.INTERPOLATE_BILINEAR)
	img.save_jpg("%s/family_%04d.jpg" % [_frames_dir, _rec_count], 0.88)
	_rec_count += 1


func _secs() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0


func _play() -> void:
	_frames_dir = out_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(_frames_dir)
	_begin("spawn", "Feyre at the cottage, controllable, at dusk")
	if not await _until(func() -> bool: return game.spawned, 30.0):
		return _fail("never spawned")
	feyre = game.feyre
	await _until(func() -> bool: return StoryControl.mode == StoryControl.Mode.FULL, 10.0)
	director = get_tree().get_first_node_in_group(DialogueDirector.GROUP) as DialogueDirector
	cottage = _anchor(COTTAGE)
	if director == null or cottage == null:
		return _fail("no DialogueDirector or cottage anchor")
	_t0 = Time.get_ticks_msec()
	director.line_spoken.connect(_on_line)
	Clock.time_of_day = HOUR / 24.0
	# Let her waking thoughts and the family settle into their evening spots.
	await _wait(8.0)
	_pass()

	_phase = "yard"
	_begin("yard", "in the snow a step from Nesta, through the wall, looking at the cottage")
	var nesta := _member(&"nesta")
	if nesta == null:
		return _fail("Nesta isn't home")
	var outside := _local_to_world(_yard_spot(nesta))
	_place(outside)
	_rec = true
	await _look_at(nesta, 16.0)
	_note("%5.1f s  yard: she's %.1f m from Nesta, inside %s; family heard %s" % [_secs(),
		_flat(nesta.global_position), director.in_cottage(feyre.global_position), family_heard.get("yard", [])])
	if not (family_heard.get("yard", []) as Array).is_empty():
		return _fail("a family line in the yard: %s" % [family_heard["yard"]])
	_pass()

	_phase = "inside"
	_begin("inside", "in by the door, looking at the empty corner")
	var door := _anchor(&"act1_cottage_door")
	if door:
		await _walk_to(door.global_position, 0.8, Callable(), 25.0)
	var middle := _local_to_world(Vector3(0.3, 0.0, 0.0))
	await _walk_to(middle, 0.6, Callable(), 15.0)
	if not director.in_cottage(feyre.global_position):
		_workaround("walk in", func() -> void: _place(middle))
	# Walking in she may see one of them ahead: that's face to face, and fine.
	# The corner is the test.
	_note("%5.1f s  walked in: family heard %s" % [_secs(), family_heard.get("inside", [])])
	_phase = "corner"
	await _look_at_point(_local_to_world(Vector3(-1.3, 1.4, 2.8)), 12.0)
	_note("%5.1f s  corner: family heard %s" % [_secs(), family_heard.get("corner", [])])
	if not (family_heard.get("corner", []) as Array).is_empty():
		return _fail("a family line while she looked away: %s" % [family_heard["corner"]])
	_pass()

	_phase = "faces"
	_begin("faces", "up to each of them in turn, looking at them")
	for id: StringName in FAMILY:
		var m := _member(id)
		if m == null:
			_note("%s isn't home" % id)
			continue
		var mid := middle - m.global_position
		var spot := m.global_position + Vector3(mid.x, 0.0, mid.z).normalized() * 1.8
		await _walk_to(spot, 0.5, Callable(), 12.0)
		await _look_at(m, 14.0)
	await _wait(4.0)
	_rec = false
	var spoke: Array = family_heard.get("faces", []) + family_heard.get("inside", [])
	_note("frames %d; family heard face to face: %s" % [_rec_count, spoke])
	var who := {}
	for s: String in spoke:
		who[s] = true
	if who.size() < 2:
		return _fail("only %s spoke face to face" % [who.keys()])
	_pass()


func _on_line(id: StringName, speaker: StringName, text: String, _at: Vector3, _inner: bool) -> void:
	var family := speaker in FAMILY
	var f2f := "-"
	if family:
		var m := _member(speaker)
		f2f = str(m != null and director.face_to_face(m, feyre.global_position))
		var list: Array = family_heard.get(_phase, [])
		list.append(String(speaker))
		family_heard[_phase] = list
	_note("%5.1f s  %-6s [%s] %s: %s  (in cottage %s, face to face %s)" % [_secs(), _phase, id, speaker, text,
		director.in_cottage(feyre.global_position), f2f])


func _member(id: StringName) -> Node3D:
	for node in get_tree().get_nodes_in_group(DialogueDirector.PRESENCE_GROUP):
		if node is Node3D and StringName(node.get_meta(&"speaker", "")) == id and (node as Node3D).is_visible_in_tree():
			return node as Node3D
	for node in get_tree().get_nodes_in_group(FamilyMember.GROUP):
		if (node as FamilyMember).member_id == id:
			return node as Node3D
	return null


## Just outside the nearest wall from `m`, in cottage-local space.
func _yard_spot(m: Node3D) -> Vector3:
	var local := cottage.global_transform.affine_inverse() * m.global_position
	var floor := DialogueDirector.COTTAGE_FLOOR
	var gaps := [local.x - floor.position.x, floor.end.x - local.x, local.z - floor.position.y, floor.end.y - local.z]
	var best := 0
	for i in 4:
		if gaps[i] < gaps[best]:
			best = i
	match best:
		0: return Vector3(floor.position.x - 1.0, 0.0, local.z)
		1: return Vector3(floor.end.x + 1.0, 0.0, local.z)
		2: return Vector3(local.x, 0.0, floor.position.y - 1.0)
	return Vector3(local.x, 0.0, floor.end.y + 1.0)


func _local_to_world(local: Vector3) -> Vector3:
	return cottage.global_transform * local


func _place(at: Vector3) -> void:
	WorldStreamer.update_for(at)
	PlayerPlacement.new(feyre).load_state({"position": [at.x, at.y + 0.3, at.z]})


func _look_at(node: Node3D, seconds: float) -> void:
	var t := 0.0
	while t < seconds and is_instance_valid(node):
		_turn_camera_to(node.global_position + Vector3.UP * 1.5)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _look_at_point(point: Vector3, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		_turn_camera_to(point)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


## The clip has its own beats, not the chain's.
func _missing_beats() -> PackedStringArray:
	return PackedStringArray()
