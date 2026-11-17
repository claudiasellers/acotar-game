## L47-6 proof, in the real game scene through Feyre's own camera: the whistle
## (fingers to her lips, a whinny back, a gallop in with petals, pulling up
## side-on), the vault into the saddle, a canter and gallop with turns past the
## stables, reining in, and the slide down. Frames at 24 fps for a clip.
##   Mac: shot marefeel res://tools/playtest/mare_feel_clip.tscn -- --out={out}/report.json
##   Writes {out}/<whistle|mount|ride|dismount>_####.jpg (1280x720) and numbers.
extends "res://tools/playtest/mount_ride_clip.gd"

const CLIP_FPS := 24.0
## A loop past the stable yard and down the drive (open ground, no hedges).
const LOOP := [Vector2(-120, 30), Vector2(-90, 80), Vector2(-40, 120), Vector2(-70, 60), Vector2(-120, 20)]

var _clip_left: float = 0.0
var _lp: int = 0
var _lap_t: float = 0.0


func _process(delta: float) -> void:
	if _rec_prefix == "" or DisplayServer.get_name() == "headless":
		return
	_clip_left -= delta
	if _clip_left > 0.0:
		return
	_clip_left += 1.0 / CLIP_FPS
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	img.resize(SAVE_SIZE.x, SAVE_SIZE.y, Image.INTERPOLATE_BILINEAR)
	img.save_jpg("%s/%s_%04d.jpg" % [_frames_dir, _rec_prefix, _rec_count], 0.9)
	_rec_count += 1


func _loop_pilot() -> Array:
	if director.mare == null:
		return [Vector3.ZERO, false]
	_lap_t += get_process_delta_time()
	var at := director.mare.global_position
	if Vector2(at.x, at.z).distance_to(LOOP[_lp]) < 9.0:
		_lp = (_lp + 1) % LOOP.size()
	var to := Vector3(LOOP[_lp].x - at.x, 0.0, LOOP[_lp].y - at.z)
	# A canter for the first stretch, then the gallop.
	return [to.normalized(), _lap_t > 4.0]


func _play() -> void:
	_frames_dir = out_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(_frames_dir)
	_begin("clip_setup", "load, jump past the first dinner and the first ride, stand by the stables")
	if not await _until(func() -> bool: return game.spawned, 60.0):
		return _fail("never spawned")
	feyre = game.feyre
	for flag: String in JUMP:
		WorldState.raise_deed(flag)
	WorldState.raise_deed(MountDirector.RIDDEN_FLAG)
	WorldDeltas.set_region_value(MountDirector.DELTAS, "whistle_taught", true)
	Clock.from_dict({"time_of_day": 0.42, "day": Clock.day})
	director = game.get_node_or_null(^"MountDirector") as MountDirector
	if director == null:
		return _fail("no MountDirector in the game scene")
	var home := director.data.home
	feyre.global_position = home + Vector3(10.0, 40.0, 40.0)
	feyre.velocity = Vector3.ZERO
	if not await _until_wall(func() -> bool: return director.mare != null and is_instance_valid(director.mare), 400.0):
		return _fail("the mare never appeared at the stables")
	await _wait(2.0)
	# Stand her on the ground (she was dropped in from above while the yard loaded).
	var spot := home + Vector3(10.0, 0.0, 40.0)
	var gy := director.ground_at(spot.x, spot.z)
	if not is_nan(gy):
		feyre.global_position = Vector3(spot.x, gy + 0.05, spot.z)
		feyre.velocity = Vector3.ZERO
	feyre.set_physics_process(true)
	await _wait(1.0)
	_note("Feyre at %s (ground %s), on floor %s" % [_v(feyre.global_position), str(gy), feyre.is_on_floor()])
	if not await _until(func() -> bool: return director.block_reason(feyre.global_position) == &"", 20.0):
		workarounds.append("StoryControl.release() (dev jump)")
		StoryControl.release()
	director.free_mare()
	_pass()

	_begin("whistle", "H: fingers to her lips, a whinny back, she gallops in and pulls up side-on")
	for i in 30:
		_turn_camera_to(feyre.global_position + Vector3(-6.0, 1.0, -8.0))
		await get_tree().physics_frame
	_record("whistle")
	await _wait(0.5)
	if not director.whistle():
		_stop_recording()
		return _fail("whistle not answered: %s" % director.last_block)
	var t0 := _sim_seconds()
	var came: bool = await _until(func() -> bool:
		return director.mare != null and director.mare.state == MareMount.State.STANDING and is_nan(director.mare._present_yaw), 25.0)
	await _wait(1.2)
	_stop_recording()
	if not came:
		return _fail("she never arrived")
	var m := director.mare
	var to_f := feyre.global_position - m.global_position
	to_f.y = 0.0
	_note("arrived in %.1f s, %.2f m away, side %.2f (1 = Feyre square on her near side)" % [_sim_seconds() - t0, to_f.length(), to_f.normalized().dot(-m.global_basis.x)])
	_pass()

	_begin("mount", "E: the vault up from her near side")
	for i in 20:
		_turn_camera_to(m.global_position + Vector3.UP * 1.3)
		await get_tree().physics_frame
	_record("mount")
	await _wait(0.4)
	if not director.mount(feyre):
		_stop_recording()
		return _fail("mount refused: %s" % director.last_block)
	var mm := director.motion
	if mm:
		_note("  from %s stand %s seat %s mare %s" % [_v(mm._from), _v(mm._stand), _v(mm.horse.seat_point()), _v(m.global_position)])
	var prev := Vector3.INF
	for i in 120:
		await get_tree().process_frame
		if mm and not mm.done():
			var h := feyre.global_position
			if prev != Vector3.INF and h.distance_to(prev) > 0.3:
				_note("  jump %.2f m at t %.2f" % [h.distance_to(prev), mm.t])
			prev = h
	_stop_recording()
	_note("vault %.2f s, peak hip speed %.1f m/s, largest frame step %.2f m" % [mm.t if mm else -1.0, mm.max_hip_speed if mm else -1.0, mm.max_hip_step if mm else -1.0])
	_pass()

	_begin("ride", "a canter then a gallop with turns past the stables, Feyre's own chase camera")
	director.autopilot = _loop_pilot
	_record("ride")
	await _wait(12.0)
	director.autopilot = func() -> Array: return [Vector3.ZERO, false]
	await _until(func() -> bool: return director.mare.speed < 0.3, 6.0)
	await _wait(0.6)
	_stop_recording()
	_pass()

	_begin("dismount", "hold E: the slide down her near side")
	_record("dismount")
	await _wait(0.4)
	director.dismount()
	var dm := director.motion
	await _wait(2.0)
	_stop_recording()
	if director.riding or not feyre.is_physics_processing():
		return _fail("still in the saddle")
	_note("slide off %.2f s, peak hip speed %.1f m/s" % [dm.t if dm else -1.0, dm.max_hip_speed if dm else -1.0])
	_pass()

	_begin("tend", "hold E: brush her to a gleam, feed her, make and put on a garland, bows and a lilac saddle cloth")
	for id: String in ["ing_lilac", "ing_lavender", "ing_crocus", "ing_heather"]:
		Gameplay.inventory.add(StringName(id), 3)
	Gameplay.inventory.add(&"ing_spider_silk", 6)
	Gameplay.inventory.add(&"ing_manor_fruit", 2)
	var v := director.open_tending()
	if v == null:
		return _fail("tending would not open (mare state %s)" % director.mare.state)
	_record("tend")
	await _wait(0.8)
	for i in 48:
		v._brush_at = Vector2(v.size.x * (0.18 + 0.12 * sin(i * 0.4)), v.size.y * 0.45)
		v._stroke(0.2)
		await get_tree().process_frame
	await _wait(0.6)
	v._feed(&"ing_manor_fruit", null)
	await _wait(1.6)
	for id: StringName in [&"garland_lilac", &"bows_lilac", &"cloth_lilac"]:
		var piece := MareTack.piece(id)
		v._show(MareTack.SLOT_NAMES[piece.slot])
		await _wait(0.5)
		if not MareTack.owned(id) and not MareTack.make(piece, Gameplay.inventory):
			_note("  could not make %s" % id)
			continue
		MareTack.wear(piece)
		v._apply(true)
		v._show(MareTack.SLOT_NAMES[piece.slot])
		await _wait(1.2)
	_note("shine %.2f, worn %s, hung %s" % [MareCare.shine(), MareTack.worn(), MareLook.hung(director.mare.horse)])
	v.close()
	await _wait(1.0)
	_stop_recording()
	_pass()
	_finish(0)
