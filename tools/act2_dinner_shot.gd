## Clip and stills of the first dinner in the real manor (R17 proof, L24):
##   godot res://tools/act2_dinner_shot.tscn -- [out_dir]
## Loads the estate as the game would show it, dev-jumps the story to "Alis
## has bathed her" (this probe sets those two flags; the game never does),
## walks Feyre to her chair and plays the scene with input-like calls: one
## try to rise, then bites until the torte vanishes. Writes clip frames
## (960x540 JPG, 5 fps) to <out>/clip/ and three full-size stills.
extends Node

const ESTATE := "res://world/spring_court/manor_estate/manor_estate.tscn"
const FPS := 5.0

var out: String
var frame: int = 0
var _capturing: bool = false
var _next_ms: int = 0
var stills: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_environment("SHOTS_OUT")
	if out == "":
		out = "user://"
	DirAccess.make_dir_recursive_absolute(out.path_join("clip"))
	var estate := (load(ESTATE) as PackedScene).instantiate()
	get_tree().root.add_child(estate)
	get_tree().current_scene = estate
	if estate.get(&"feyre") == null:
		ShotLook.dress(estate, &"manor_interior")
		estate.call(&"_spawn_feyre")
	Clock.from_dict({"time_of_day": 20.0 / 24.0, "day": 2})
	Clock.paused = true
	StoryDirector.attach_all(estate)
	var feyre := estate.get(&"feyre") as Node3D
	var anchor := ReturnHome.find_anchor(get_tree(), &"manor_dining_table")
	var dinner := anchor.get_node(^"Moment_first_dinner") as FirstDinner
	var settle := 4.0 if OS.get_environment("SHOTS_QUALITY") == "look" else 1.0
	# Dev jump (probe only): the ride and Alis's bath are done.
	WorldState.set_flag("wall_crossed")
	WorldState.set_flag("fact.alis_bathed")
	for piece in [AlisWelcome.TUNIC, AlisWelcome.TROUSERS]:
		Gameplay.wardrobe.grant(piece)
		Gameplay.wardrobe.equip(piece)
	Gameplay.wardrobe.unequip_slot(&"outer")
	feyre.global_position = anchor.global_position + Vector3.UP * 0.2
	print("probe: estate up, dinner can_start=%s running=%s" % [dinner.can_start(), dinner.running])
	await _seconds(settle)
	_capturing = true
	await _until(func() -> bool: return dinner.current_beat_label().begins_with("reach feyre_chair"), 20.0)
	await _walk(feyre, dinner.mark(&"feyre_chair"), 1.0, 12.0)
	print("probe: walking, beat '%s'" % dinner.current_beat_label())
	await _until(func() -> bool: return dinner.current_beat_label() == "until she rises", 40.0)
	print("probe: seated, beat '%s'" % dinner.current_beat_label())
	await _still("dinner_seated")
	await _chair_views(dinner)
	dinner.nudge()
	await _until(func() -> bool: return dinner.current_beat_label() == "until her first bite", 30.0)
	for i in 4:
		dinner.press_interact()
		await _seconds(0.25)
		if i == 0:
			await _still("dinner_first_bite")
		await _seconds(1.2)
	await _until(func() -> bool: return WorldState.has_flag("first_dinner_eaten"), 15.0)
	await _seconds(1.0)
	await _still("dinner_torte_gone")
	await _seconds(2.0)
	_capturing = false
	print("first_dinner_eaten=%s shoves=%d bites=%d frames=%d" % [WorldState.has_flag("first_dinner_eaten"), dinner.shoves, dinner.bites, frame])
	get_tree().quit()


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _process(_delta: float) -> void:
	if _headless() or not _capturing or Time.get_ticks_msec() < _next_ms:
		return
	_next_ms = Time.get_ticks_msec() + int(1000.0 / FPS)
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	img.save_jpg(out.path_join("clip/f%04d.jpg" % frame), 0.82)
	frame += 1


func _still(still_name: String) -> void:
	if stills >= 6 or _headless():
		print("still %s (headless: not drawn)" % still_name)
		return
	stills += 1
	await RenderingServer.frame_post_draw
	var path := out.path_join("%s.png" % still_name)
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.is_empty():
		print("no image for ", still_name)
		return
	img.save_png(path)
	print("saved ", path)


## Walks her there with the move action, like the playtest walker.
func _walk(feyre: Node3D, to: Vector3, radius: float, seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		var d := Vector2(to.x - feyre.global_position.x, to.z - feyre.global_position.z)
		if d.length() <= radius:
			break
		if feyre.has_method(&"nudge_camera"):
			var want := atan2(-d.x, -d.y)
			feyre.call(&"nudge_camera", wrapf(want - float(feyre.call(&"camera_yaw")), -PI, PI), 0.0)
			var frame: Variant = feyre.get(&"steer_frame")
			if frame is SteerFrame:
				(frame as SteerFrame).release()   # steering by the camera: a fresh press each frame
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	if Vector2(to.x - feyre.global_position.x, to.z - feyre.global_position.z).length() > radius:
		feyre.global_position = Vector3(to.x, feyre.global_position.y, to.z)


func _until(cond: Callable, seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until and not cond.call():
		await get_tree().process_frame


## Each seated figure from the side, table to the right: are the legs clear?
func _chair_views(dinner: FirstDinner) -> void:
	var was := get_viewport().get_camera_3d()
	var side := Camera3D.new()
	side.fov = 42.0
	dinner.add_child(side)
	for view: Array in [[&"tamlin_seat", Vector3(-0.4, 0.8, 2.6)], [&"lucien_seat", Vector3(2.4, 0.8, 0.2)], [&"feyre_seat", Vector3(0.4, 0.8, 2.6)]]:
		var at := dinner.mark(view[0])
		side.global_position = at + view[1]
		side.look_at(at + Vector3.UP * 0.55, Vector3.UP)
		side.make_current()
		await _still("dinner_side_%s" % view[0])
	was.make_current()
	side.queue_free()


func _seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
