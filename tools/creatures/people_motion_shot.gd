## Villagers walking and noticing Feyre in the real village square, for judging
## the motion by eye (lane L22). Needs a GPU (Mac shots, docs/SHOTS.md):
##   godot res://tools/creatures/people_motion_shot.tscn -- <out_dir> [numbers]
## walk_sheet.png: eight frames across one stride of a village man walking
## past side-on (left to right, top row then bottom). notice_before.png and
## notice.png: three villagers and Tamlin, then Feyre steps in among them and
## the heads come round to her. Prints each head's turn toward her.
extends Node

const TILE := Vector2i(960, 540)

var _out := "user://people_motion"
var _world: World
var _cam: Camera3D
var _numbers := false
var _sq: Vector3


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else _out
	_numbers = args.has("numbers")
	DirAccess.make_dir_recursive_absolute(_out)
	Clock.paused = true
	Clock.time_of_day = 0.45
	var root := get_tree().root
	root.size = Vector2i(1920, 1080)
	_world = load("res://world/shared/world/world.tscn").instantiate() as World
	root.add_child(_world)
	var sq := HumanRealmLayout.VILLAGE_SQUARE
	_sq = _ground(Vector3(sq.x, 0.0, sq.y))
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.far = 900.0
	_world.add_child(_cam)
	_cam.make_current()
	_world.grade.swap_to(&"human_winter", 0.0)
	for def in _region_defs():
		if Vector2(def.center.x - _sq.x, def.center.z - _sq.z).length() < def.radius + 200.0:
			var scene: PackedScene = load(def.scene_path)
			if scene != null:
				_world.regions.add_child(scene.instantiate())
	print("world up; regions near the square: ", _world.regions.get_child_count())
	await _settle(2.0)
	await _walk_sheet()
	await _notice()
	get_tree().quit(0)


## A woman walks along +X past the camera at her own walking speed.
func _walk_sheet() -> void:
	var walker := _npc("human_man", _sq + Vector3(-3.0, 0.0, 0.0), -PI * 0.5)
	var a: PersonAnimator = walker.animators[0]
	var speed := a.native_walk
	var dur: float = CreatureAnimator.read_gaits(PersonAnimator.GAITS_FILE % "human_man")[&"walk"][1]
	print("walker native speed %.2f m/s" % speed)
	_cam.global_position = _sq + Vector3(0.0, 1.0, 4.2)
	_cam.look_at(_sq + Vector3(0.0, 0.85, 0.0))
	var sheet := Image.create(TILE.x * 4, TILE.y * 2, false, Image.FORMAT_RGB8)
	var t := 0.0
	var next := 0
	var start := 1.5  # into a steady stride before the first frame
	while next < 8:
		var dt := get_process_delta_time()
		t += dt
		walker.global_position = _ground(walker.global_position + Vector3(speed * dt, 0.0, 0.0))
		_cam.global_position.x = walker.global_position.x
		if t >= start + dur * next / 8.0:
			if not _numbers:
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((next % 4) * TILE.x, (next / 4) * TILE.y))
			print("walk frame %d at %.2f s, blend %.2f, rate %.2f" % [next, t, float(a.tree.get(&"parameters/loco/blend_position")), float(a.tree.get(&"parameters/loco_rate/scale"))])
			next += 1
		await get_tree().process_frame
	if not _numbers:
		sheet.save_png(_out + "/walk_sheet.png")
	walker.queue_free()


## Villagers stand about; Feyre walks in among them and the heads come round.
func _notice() -> void:
	var c := _sq + Vector3(0.0, 0.0, 12.0)
	var people: Array[Node3D] = []
	# Three villagers talking in a ring, Tamlin a little apart, facing them.
	people.append(_npc("human_man", c + Vector3(-1.2, 0.0, 0.0), atan2(-2.4, 0.4)))
	people.append(_npc("human_elder", c + Vector3(1.2, 0.0, -0.4), atan2(2.4, -0.4)))
	people.append(_npc("human_youth", c + Vector3(0.0, 0.0, -1.6), PI))
	for p in people:
		(p as CourtNpc).set_talking(true)
	var tamlin_scene := "res://characters/tamlin/tamlin_model.tscn"
	if ResourceLoader.exists(tamlin_scene):
		var t := (load(tamlin_scene) as PackedScene).instantiate() as Node3D
		_world.add_child(t)
		t.global_position = _ground(c + Vector3(2.6, 0.0, 1.4))
		t.rotation.y = atan2(2.6, 1.4)
		people.append(t)
	_cam.global_position = _ground(c + Vector3(3.2, 0.0, 6.8)) + Vector3.UP * 1.6
	_cam.look_at(c + Vector3(0.3, 1.25, 0.6))
	await _settle(2.0)
	await _save(_out + "/notice_before.png")
	# Feyre herself (dressed by her wardrobe), coming up at their front left.
	var feyre := (load("res://characters/feyre/feyre.tscn") as PackedScene).instantiate() as Feyre
	_world.add_child(feyre)
	feyre.global_position = _ground(c + Vector3(-0.4, 0.0, 2.6)) + Vector3.UP * 0.1
	feyre.model.rotation.y = atan2(-0.4, 2.6)
	_cam.make_current()
	await _settle(2.5)
	for p in people:
		var n: NoticePlayer = _notice_of(p)
		if n:
			print("%s notices her: weight %.2f" % [p.name, n.weight])
	await _save(_out + "/notice.png")


func _notice_of(p: Node3D) -> NoticePlayer:
	var found := p.find_children("NoticePlayer*", "NoticePlayer", true, false)
	return found[0] as NoticePlayer if not found.is_empty() else null


func _npc(id: String, at: Vector3, yaw: float) -> CourtNpc:
	var npc := (load("res://creatures/people/scenes/%s.tscn" % id) as PackedScene).instantiate() as CourtNpc
	npc.wander_radius = 0.0
	_world.add_child(npc)
	npc.global_position = _ground(at)
	npc.rotation.y = yaw
	return npc


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, WorldHeight.height_at(p.x, p.z), p.z)


func _settle(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await get_tree().process_frame


func _save(path: String) -> void:
	if _numbers:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _region_defs() -> Array[RegionDef]:
	var out: Array[RegionDef] = []
	var dir := DirAccess.open("res://data/regions/human_realm")
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var def := load("res://data/regions/human_realm/" + f) as RegionDef
			if def != null:
				out.append(def)
	return out
