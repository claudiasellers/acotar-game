## Takes every shot and check of one request in a single run, so the level
## loads once (format: docs/contracts/shot_request.md). Use the wrapper:
##   tools/shots/take_shots.sh <request.json> [out_dir]
## or directly:
##   godot --path . res://tools/shots/shot_runner.tscn -- <request.json> [out_dir]
## The render loop stays off while the level loads and settles (each
## software-rendered frame costs seconds); every shot is a few forced draws.
## Writes <out_dir>/<shot>.png and <out_dir>/results.json. Exit 0 = every
## shot saved, 1 = bad request or scene, 2 = a shot failed. Failed checks are
## data (results.json, "FAIL" lines), not a failed run.
extends Node

## Frames to wait for nodes in this group to leave it (systems that build
## after _ready join it while busy) before shooting anyway.
const BUSY_GROUP := &"shot_busy"
const MAX_BUSY_FRAMES := 600

var _t0: int = 0
var _req: ShotRequest
var _out_dir: String
var _root: Node
var _world: World
var _cam: Camera3D
var _results := {}


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	RenderingServer.render_loop_enabled = false
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_fail(1, "usage: shot_runner.tscn -- <request.json> [out_dir]")
		return
	_req = ShotRequest.from_file(args[0])
	_out_dir = args[1] if args.size() > 1 else "user://shots/%s" % _req.id
	if not _req.errors.is_empty():
		_fail(1, "bad request: " + "; ".join(_req.errors))
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var headless := DisplayServer.get_name() == "headless"
	_results = {
		"id": _req.id,
		"scene": _req.scene,
		"renderer": "headless" if headless else str(ProjectSettings.get_setting_with_override(&"rendering/renderer/rendering_method")),
		"device": RenderingServer.get_video_adapter_name(),
		"terrain_clamped": ShotQuality.on_lavapipe(),
		"threads": OS.get_environment("LP_NUM_THREADS"),
		"timings_ms": {},
		"shots": [],
		"checks": [],
	}
	if not await _load_scene():
		_fail(1, "cannot load scene '%s'" % _req.scene_path())
		return
	var first_pos := _first_position()
	await _stream_to(first_pos)
	_results.timings_ms.ready = Time.get_ticks_msec() - _t0
	var failed := 0
	for check in _req.checks:
		var r := await _check(check)
		_results.checks.append(r)
		if r.ok == false:
			print("FAIL %s %s" % [r.name, r.get("error", JSON.stringify(r.get("values", {})))])
	for shot in _req.shots:
		var r := await _shot(shot, headless)
		_results.shots.append(r)
		if r.has("error"):
			failed += 1
			printerr("SHOT %s failed: %s" % [shot.name, r.error])
		else:
			print("SHOT %s -> %s | %d ms | draw_calls %d | primitives %d" % [shot.name, r.file, r.ms, r.draw_calls, r.primitives])
	_results.timings_ms.total = Time.get_ticks_msec() - _t0
	_results.checks_failed = _results.checks.filter(func(c: Dictionary) -> bool: return c.ok == false).size()
	_write_results()
	print("SHOTS %s | %d shots (%d failed), %d checks (%d failed) | ready %d ms, total %d ms | %s" % [
		_req.id, _req.shots.size(), failed, _req.checks.size(), _results.checks_failed,
		_results.timings_ms.ready, _results.timings_ms.total, _out_dir])
	get_tree().quit(2 if failed > 0 else 0)


func _load_scene() -> bool:
	var packed := load(_req.scene_path()) as PackedScene
	if packed == null:
		return false
	_root = packed.instantiate()
	get_tree().root.add_child(_root)
	_world = _root as World
	if _world != null:
		Clock.paused = true
		Clock.time_of_day = _req.time_of_day
		WorldStreamer.synchronous = true
		WorldStreamer.configure_from_tree("res://data/regions", _world.regions)
	ShotQuality.guard_software_renderer(get_tree().root, _root)
	_cam = Camera3D.new()
	_cam.name = "ShotCamera"
	_cam.far = 1200.0
	_root.add_child(_cam)
	_cam.make_current()
	await get_tree().process_frame
	return true


## Loads the regions around `pos` (world only) and waits until the level says
## it is ready: nothing left in BUSY_GROUP, after two frames for deferred
## setup. No rendering happens here.
func _stream_to(pos: Vector3) -> void:
	if _world != null:
		WorldStreamer.update_for(pos)
	await get_tree().process_frame
	await get_tree().process_frame
	var frames := 0
	while not get_tree().get_nodes_in_group(BUSY_GROUP).is_empty() and frames < MAX_BUSY_FRAMES:
		await get_tree().process_frame
		frames += 1
	if frames >= MAX_BUSY_FRAMES:
		push_warning("shot_runner: still busy after %d frames: %s" % [frames, get_tree().get_nodes_in_group(BUSY_GROUP)])


func _check(check: Dictionary) -> Dictionary:
	if check.has("near"):
		await _stream_to(ShotRequest._vec3(check.near, Vector3.ZERO))
	await get_tree().physics_frame
	var space := _root.get_viewport().find_world_3d().direct_space_state
	return ShotChecks.run(check, _root, space, _world != null)


func _shot(shot: Dictionary, headless: bool) -> Dictionary:
	var t := Time.get_ticks_msec()
	var r := {"name": shot.name, "quality": shot.quality}
	if headless:
		r.error = "no renderer (headless); run without --headless for shots"
		return r
	var eye: Vector3 = shot.eye
	var at: Vector3 = shot.at
	if shot.ground:
		eye.y += WorldHeight.height_at(eye.x, eye.z)
		at.y += WorldHeight.height_at(at.x, at.z)
	if _world != null:
		Clock.time_of_day = shot.time_of_day
		if shot.grade != &"":
			_world.grade.swap_to(shot.grade, 0.0)
	_cam.fov = shot.fov
	_cam.global_position = eye
	if not eye.is_equal_approx(at):
		_cam.look_at(at)
	await _stream_to(eye)
	if not str(shot.frame).is_empty() and not _use_frame(shot.frame):
		r.error = "no shot_frame marker '%s'" % shot.frame
		return r
	await _stream_to(_cam.global_position)
	var vp := get_tree().root
	ShotQuality.apply(shot.quality, vp, _root, shot.size)
	await get_tree().process_frame
	if shot.quality == ShotQuality.LAYOUT:
		for i in maxi(1, shot.settle_draws):
			RenderingServer.force_draw(true, 0.0)
	else:
		# Look shots run the real loop so TAA, GI, particles and animation
		# settle with time: settle_draws frames and at least warmup seconds.
		RenderingServer.render_loop_enabled = true
		var until := Time.get_ticks_msec() + int(shot.warmup_s * 1000.0)
		var frames := 0
		while frames < shot.settle_draws or Time.get_ticks_msec() < until:
			await get_tree().process_frame
			frames += 1
		await RenderingServer.frame_post_draw
		RenderingServer.render_loop_enabled = false
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		r.error = "empty frame"
		return r
	var file := "%s/%s.png" % [_out_dir, shot.name]
	var err := img.save_png(file)
	if err != OK:
		r.error = "save_png %s" % error_string(err)
		return r
	r.file = file
	r.size = [img.get_width(), img.get_height()]
	r.draw_calls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	r.primitives = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	r.objects = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	r.ms = Time.get_ticks_msec() - t
	return r


## Authored framings (group "shot_frame", meta "shot" = id) win over eye/at.
func _use_frame(id: String) -> bool:
	for m in get_tree().get_nodes_in_group(&"shot_frame"):
		if m.get_meta(&"shot", "") == id:
			_cam.global_transform = (m as Node3D).global_transform
			_cam.fov = m.get_meta(&"fov", 50.0)
			if m.has_meta(&"time_of_day") and _world != null:
				Clock.time_of_day = m.get_meta(&"time_of_day")
			return true
	return false


func _first_position() -> Vector3:
	if not _req.shots.is_empty():
		return _req.shots[0].eye
	for c in _req.checks:
		if c.has("near"):
			return ShotRequest._vec3(c.near, Vector3.ZERO)
	return Vector3.ZERO


func _write_results() -> void:
	var f := FileAccess.open("%s/results.json" % _out_dir, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_results, "\t"))


func _fail(code: int, msg: String) -> void:
	printerr("shot_runner: " + msg)
	if _out_dir != "":
		_results.error = msg
		_write_results()
	get_tree().quit(code)
