## Measures how readable the beast at the door is under the scene's real
## lighting (lane L55): night, the dread grade at full, the staged cameras.
##   godot res://tools/creatures/beast_door_light_probe.tscn -- <out_dir> [off] [no_feyre] [gains=1,2,4]
## off: without BeastDoorLighting (the "before"). no_feyre: a bare camera
## stands in for her (cloud lavapipe crashes on it, F46). Prints per frame: frame mean
## luma, share of near-black pixels (<30) and the mean luma inside the beast's
## screen box; writes light_sheet_g<gain>.png (four frames) per gain.
extends Node

const FEYRE := "res://characters/feyre/feyre.tscn"
const TILE := Vector2i(960, 540)


class FakeBeastSpace:
	extends Node3D
	var running: bool = true
	var space_id: StringName = &"beast_door"
	var beast: Node3D


var _out := "user://beast_door_light"
var _frame := 0
var _staging: BeastDoorStaging
var _beast: Node3D
var _rig: BeastDoorLighting
var _gains: Array[float] = [1.0]
var _sheets: Array[Image] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else _out
	var lit := not args.has("off")
	DirAccess.make_dir_recursive_absolute(_out)
	Clock.paused = true
	Clock.time_of_day = 0.9
	get_tree().root.size = Vector2i(1920, 1080)
	var world := load("res://world/shared/world/world.tscn").instantiate() as World
	get_tree().root.add_child(world)
	world.grade.swap_to(&"human_winter", 0.0)
	var def := load("res://data/regions/human_realm/cottage.tres") as RegionDef
	world.regions.add_child((load(def.scene_path) as PackedScene).instantiate())
	await _settle(2.0)
	var door := _anchor(&"act1_cottage_door")
	var inside := _anchor(&"act1_cottage_interior")
	if door == null or inside == null:
		push_error("cottage anchors missing")
		get_tree().quit(1)
		return
	var room := inside.get_parent() as Node3D
	var at := room.to_global(Vector3(1.4, 0.0, 0.4)) + Vector3.UP * 0.1
	var to_door := door.global_position - at
	if args.has("no_feyre"):
		# Cloud lavapipe crashes on her model (F46): an eye in her place.
		var eye := Node3D.new()
		eye.add_to_group(&"player")
		world.add_child(eye)
		eye.global_position = at
		var cam := Camera3D.new()
		cam.fov = 70.0
		eye.add_child(cam)
		eye.set(&"camera", cam)
		cam.position = Vector3(0, 1.6, 0)
		cam.look_at(door.global_position + Vector3.UP * 1.4)
		cam.current = true
	else:
		var feyre := (load(FEYRE) as PackedScene).instantiate() as Feyre
		world.add_child(feyre)
		feyre.global_position = at
		feyre.model.rotation.y = atan2(-to_door.x, -to_door.z)
		var rig := feyre.camera.get_parent().get_parent().get_parent() as Node3D
		rig.rotation.y = feyre.model.rotation.y
	var father := (load("res://creatures/family/father.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(father)
	father.global_position = inside.global_position + (inside.global_basis * Vector3(1.4, 0.0, 1.0))
	var space := FakeBeastSpace.new()
	world.add_child(space)
	space.global_transform = inside.global_transform
	var beast := (load("res://creatures/beast/beast_actor.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(beast)
	beast.global_transform = door.global_transform
	beast.global_position += door.global_basis.z * 3.0
	var latch := door.get_node_or_null(^"CottageDoorLatch") as Node3D
	(beast as BeastActor).door = latch if latch else door
	space.beast = beast
	_beast = beast
	_staging = BeastDoorStaging.new()
	space.add_child(_staging)
	if lit:
		_rig = BeastDoorLighting.new()
		space.add_child(_rig)
	for a in args:
		if a.begins_with("gains="):
			_gains.clear()
			for g in a.trim_prefix("gains=").split(","):
				_gains.append(float(g))
	for g in _gains:
		_sheets.append(Image.create(TILE.x * 2, TILE.y * 2, false, Image.FORMAT_RGB8))
	await _settle(2.0)
	# As BeastDoor plays it: dread builds, then full dread as the door breaks.
	EventBus.mood_requested.emit(&"dread", 1.0, 0.2)
	await _settle(0.4)
	StoryControl.set_mode(StoryControl.Mode.WALK)
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	await _settle(0.6)
	await _grab("door bursts")
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	StoryControl.set_focus(beast)
	await _settle(2.4)
	await _grab("fills the room")
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"accuse")
	StoryControl.set_mode(StoryControl.Mode.LOOK, PackedStringArray(["fire"]))
	await _settle(1.2)
	await _grab("throw window")
	StoryControl.set_focus(null)
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"speak")
	EventBus.story_actor_cue.emit(&"father", &"plead")
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	await _settle(2.4)
	await _grab("father pleads")
	for i in _gains.size():
		_sheets[i].save_png(_out + "/light_sheet_g%s.png" % _gains[i])
	get_tree().quit(0)


func _grab(label: String) -> void:
	for i in _gains.size():
		if _rig != null:
			_rig.gain = _gains[i]
			_rig._apply()
		await get_tree().process_frame
		await get_tree().process_frame
		await _grab_one(label, i)
	_frame += 1


func _grab_one(label: String, gi: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var cam := get_viewport().get_camera_3d()
	var box := _screen_box(cam, img.get_size())
	var stats := _luma(img, Rect2i(Vector2i.ZERO, img.get_size()))
	var beast_stats := _luma(img, box) if box.has_area() else [0.0, 0.0]
	print("LIGHT gain %.1f frame %d %s: shot %s, mean %.1f, dark<30 %.0f%%, beast box %s mean %.1f" % [
			_gains[gi], _frame, label, _staging.shot_name, stats[0], stats[1] * 100.0, box, beast_stats[0]])
	img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
	_sheets[gi].blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((_frame % 2) * TILE.x, (_frame / 2) * TILE.y))


## [mean luma 0..255, share of pixels under 30], sampled every 4th pixel.
static func _luma(img: Image, r: Rect2i) -> Array:
	var sum := 0.0
	var dark := 0
	var n := 0
	for y in range(r.position.y, r.end.y, 4):
		for x in range(r.position.x, r.end.x, 4):
			var c := img.get_pixel(x, y)
			var l := (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0
			sum += l
			dark += 1 if l < 30.0 else 0
			n += 1
	return [sum / maxi(n, 1), float(dark) / maxi(n, 1)]


func _screen_box(cam: Camera3D, size: Vector2i) -> Rect2i:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for mi in _beast.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree():
			continue
		var aabb := m.global_transform * m.get_aabb()
		for i in 8:
			var p := aabb.get_endpoint(i)
			if cam.is_position_behind(p):
				continue
			var s := cam.unproject_position(p)
			lo = lo.min(s)
			hi = hi.max(s)
	if lo.x == INF:
		return Rect2i()
	var r := Rect2i(Vector2i(lo.floor()), Vector2i((hi - lo).ceil()))
	return r.intersection(Rect2i(Vector2i.ZERO, size))


func _anchor(id: StringName) -> Node3D:
	for a in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(a.get_meta(&"anchor_id", a.name)) == id:
			return a as Node3D
	return null


func _settle(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await get_tree().process_frame
