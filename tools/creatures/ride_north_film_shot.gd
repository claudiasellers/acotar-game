## The ride north as the player sees it, staged (lane L22,
## story/staging/ride_north_staging.gd): the real RideNorth space on the real
## wall-seam path, Feyre on the white horse, faster than in play so the probe
## is short. Needs a GPU (Mac shots, docs/SHOTS.md):
##   godot res://tools/creatures/ride_north_film_shot.tscn -- <out_dir> [numbers]
## film_sheet.png: a frame a moment into each shot (setting off, her view,
## the sleep, the wall into spring, the drive, after she gets down).
extends Node

const FEYRE := "res://characters/feyre/feyre.tscn"
const TILE := Vector2i(960, 540)
const SPEED := 12.0
const MAX_SECONDS := 240.0

var _out := "user://ride_north_film"
var _numbers := false
var _sheet: Image
var _frame := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else _out
	_numbers = args.has("numbers")
	DirAccess.make_dir_recursive_absolute(_out)
	Clock.paused = true
	Clock.time_of_day = 0.4
	get_tree().root.size = Vector2i(1920, 1080)
	var world := load("res://world/shared/world/world.tscn").instantiate() as World
	get_tree().root.add_child(world)
	world.grade.swap_to(&"human_winter", 0.0)
	var def := load("res://data/regions/human_realm/wall_seam.tres") as RegionDef
	world.regions.add_child((load(def.scene_path) as PackedScene).instantiate())
	await _settle(1.5)
	# The story spawner puts the real white horse down for the ride.
	world.add_child(StorySpawner.new())
	var path := get_tree().root.find_child("WallSeamPath", true, false) as Path3D
	if path == null:
		push_error("no WallSeamPath")
		get_tree().quit(1)
		return
	var start := path.global_transform * path.curve.get_point_position(0)
	var feyre := (load(FEYRE) as PackedScene).instantiate() as Feyre
	world.add_child(feyre)
	feyre.global_position = start + Vector3.UP * 1.2
	await _settle(1.5)
	var ride := RideNorth.new()
	ride.ride_speed = SPEED
	world.add_child(ride)
	ride.global_position = start
	var staging := ride.find_children("*", "RideNorthStaging", false, false)[0] as RideNorthStaging
	_sheet = Image.create(TILE.x * 3, TILE.y * 2, false, Image.FORMAT_RGB8)
	WorldState.set_flag("beast_claim_accepted", true)
	var last := &""
	var t0 := Time.get_ticks_msec()
	var grab_at := -1.0
	while (Time.get_ticks_msec() - t0) / 1000.0 < MAX_SECONDS:
		await get_tree().process_frame
		var now := (Time.get_ticks_msec() - t0) / 1000.0
		if staging.shot_name != last:
			last = staging.shot_name
			if ride.path:
				print("  path %.0f m, seam at %.0f m, at %.0f m" % [ride.path_length(), ride.seam_at(), ride.progress])
			print("%.1f s: shot %s, beat '%s', control %d" % [now, last, ride.current_beat_label(), StoryControl.mode])
			grab_at = now + (0.4 if last == &"released" else (2.6 if last == &"sleep" else 1.2))
		if grab_at > 0.0 and now >= grab_at and _frame < 6 and last != &"dark":
			grab_at = -1.0
			await _grab(String(last))
		if staging.shot_name == &"released" and _frame >= 6:
			break
		if not ride.running and WorldState.has_flag("wall_crossed") and staging.shot_name == &"released" and grab_at < 0.0:
			break
	if not _numbers:
		_sheet.save_png(_out + "/film_sheet.png")
	print("done: wall_crossed %s, her camera %s" % [WorldState.has_flag("wall_crossed"),
			get_viewport().get_camera_3d() == feyre.camera])
	get_tree().quit(0)


func _grab(label: String) -> void:
	var cam := get_viewport().get_camera_3d()
	var rider := get_tree().get_first_node_in_group(&"player") as Node3D
	var aim := rider.global_position + Vector3.UP * 1.2 if rider else Vector3.ZERO
	print("  frame %d (%s): fov %.1f, cam at %s, rider at %s, rider in frame %s" % [_frame, label,
			cam.fov, cam.global_position, aim, not cam.is_position_behind(aim) and
			Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).has_point(cam.unproject_position(aim))])
	if not _numbers:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		_sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((_frame % 3) * TILE.x, (_frame / 3) * TILE.y))
	_frame += 1


func _settle(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await get_tree().process_frame
