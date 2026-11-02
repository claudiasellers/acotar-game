## L47 proof for the white mare: mount at the stables, gallop the Wall road
## (the drive, then the border woods), get down, whistle her back. From the
## real game scene through Feyre's own camera, plus the streaming numbers at
## full gallop (the director's ask: does the world arrive before she does?).
##   cloud, numbers only:  godot --headless --max-fps 60 res://tools/playtest/mount_ride_clip.tscn -- --out=/tmp/mare/report.json
##   Mac, frames + numbers: shot mare res://tools/playtest/mount_ride_clip.tscn -- --out={out}/report.json
## On a GPU it writes {out}/<mount|gallop|dismount|whistle>_####.jpg at 4 fps
## (1280x720 from the 1920x1080 render). It jumps ahead (dev only): it raises
## the deeds up to the first dinner itself.
extends "res://tools/playtest/act1_playtest.gd"

const FPS := 4.0
const SAVE_SIZE := Vector2i(1280, 720)
const GALLOP_FRAMES := 120
const JUMP := ["wolf_killed", "pelt_sold", "beast_claim_accepted", "wall_crossed",
	"fact.manor_arrived", "fact.alis_bathed", "first_dinner_eaten"]
## The ride: out of the stable yard, across to the drive, down the Wall road
## (data/wayside/wall_manor.tres) through the border woods.
const ROUTE := [Vector2(-130, 8), Vector2(-120, 60), Vector2(-60, 160), Vector2(0, 280),
	Vector2(-30, 620), Vector2(-60, 950), Vector2(-85, 1250)]

var director: MountDirector
var _rec_prefix: String = ""
var _rec_left: float = 0.0
var _rec_count: int = 0
var _rec_cap: int = 9999
var _frames_dir: String = ""
var _wp: int = 0
var _gallop: bool = true
var _stop: bool = false


func _process(delta: float) -> void:
	if _rec_prefix == "" or DisplayServer.get_name() == "headless":
		return
	_rec_left -= delta
	if _rec_left > 0.0 or _rec_count >= _rec_cap:
		return
	_rec_left = 1.0 / FPS
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	img.resize(SAVE_SIZE.x, SAVE_SIZE.y, Image.INTERPOLATE_BILINEAR)
	img.save_jpg("%s/%s_%04d.jpg" % [_frames_dir, _rec_prefix, _rec_count], 0.88)
	_rec_count += 1


func _record(prefix: String, cap: int = 9999) -> void:
	_rec_prefix = prefix
	_rec_count = 0
	_rec_left = 0.0
	_rec_cap = cap


func _stop_recording() -> void:
	if _rec_prefix != "":
		_note("%s: %d frames" % [_rec_prefix, _rec_count])
	_rec_prefix = ""


func _pilot() -> Array:
	if _stop or director.mare == null:
		return [Vector3.ZERO, false]
	var at := director.mare.global_position
	while _wp < ROUTE.size() - 1 and Vector2(at.x, at.z).distance_to(ROUTE[_wp]) < 10.0:
		_wp += 1
	var to := Vector3(ROUTE[_wp].x - at.x, 0.0, ROUTE[_wp].y - at.z)
	if _wp == ROUTE.size() - 1 and to.length() < 10.0:
		return [Vector3.ZERO, false]
	return [to.normalized(), _gallop]


func _play() -> void:
	_frames_dir = out_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(_frames_dir)
	_begin("clip_setup", "load, jump past the first dinner, stand in the stable yard")
	if not await _until(func() -> bool: return game.spawned, 60.0):
		return _fail("never spawned")
	feyre = game.feyre
	for flag: String in JUMP:
		WorldState.raise_deed(flag)
	Clock.from_dict({"time_of_day": 0.4, "day": Clock.day})
	director = game.get_node_or_null(^"MountDirector") as MountDirector
	if director == null:
		return _fail("no MountDirector in the game scene")
	var home := director.data.home
	feyre.global_position = home + Vector3(4.0, 40.0, 7.0)
	feyre.velocity = Vector3.ZERO
	if not await _until_wall(func() -> bool: return director.mare != null and is_instance_valid(director.mare), 400.0):
		return _fail("the mare never appeared at the stables (region %s, loaded %s)" % [_region(), WorldStreamer.loaded_ids()])
	await _wait(2.0)
	_note("mare at %s, Feyre at %s, region %s" % [_v(director.mare.global_position), _v(feyre.global_position), _region()])
	_pass()

	_begin("mount", "E on the mare in the yard: the first ride is a deed")
	for i in 40:
		_turn_camera_to(director.mare.global_position + Vector3.UP * 1.2)
		await get_tree().physics_frame
	_record("mount")
	await _wait(1.0)
	if not director.mount(feyre):
		_stop_recording()
		return _fail("mount refused: %s" % director.last_block)
	await _wait(2.0)
	_stop_recording()
	if not WorldState.has_flag(MountDirector.RIDDEN_FLAG):
		return _fail("fact.mare_ridden was not raised")
	_note("riding; seat %s, feyre %s" % [_v(director.seat_point()), _v(feyre.global_position)])
	_pass()

	_begin("gallop", "sprint down the Wall road: the drive, then the border woods, at %.0f m/s" % director.data.gallop_speed)
	director.autopilot = _pilot
	var stats := {"frames": 0, "unbuilt_frames": 0, "no_ground_frames": 0, "ahead_unbuilt_frames": 0,
		"regions": {}, "top_speed": 0.0, "metres": 0.0, "stuck_hops": 0}
	var last := director.mare.global_position
	var started := Time.get_ticks_msec()
	var stuck := 0.0
	_record("gallop", GALLOP_FRAMES)
	while _wp < ROUTE.size() - 1 or Vector2(director.mare.global_position.x, director.mare.global_position.z).distance_to(ROUTE[-1]) > 12.0:
		await get_tree().physics_frame
		if not director.riding:
			_stop_recording()
			return _fail("fell out of the saddle at %s (block %s)" % [_v(feyre.global_position), director.block_reason(feyre.global_position)])
		var m := director.mare
		var at := m.global_position
		stats.frames += 1
		stats.metres += Vector2(at.x - last.x, at.z - last.z).length()
		last = at
		stats.top_speed = maxf(stats.top_speed, m.speed)
		_measure(stats, at, m.heading())
		stuck = stuck + get_physics_process_delta_time() if m.speed < 1.0 else 0.0
		if stuck > 2.0:
			# Walled in (a hedge, a gate): hop ahead along the road and count it.
			var to := Vector3(ROUTE[_wp].x - at.x, 0.0, ROUTE[_wp].y - at.z).normalized()
			m.global_position = at + to * 6.0 + Vector3.UP * 1.5
			stats.stuck_hops += 1
			stuck = 0.0
			_note("hop at %s toward waypoint %d" % [_v(at), _wp])
		if Time.get_ticks_msec() - started > 600000:
			_stop_recording()
			return _fail("ride took over 10 min wall")
	_stop_recording()
	var secs := stats.frames / float(Engine.physics_ticks_per_second)
	_note("rode %.0f m in %.1f s game (avg %.1f m/s, top %.1f m/s), %d hops" % [stats.metres, secs, stats.metres / maxf(secs, 0.01), stats.top_speed, stats.stuck_hops])
	_note("pop-in: %d of %d frames in an unbuilt region, %d with the region 60 m ahead unbuilt, %d with no ground under her" % [stats.unbuilt_frames, stats.frames, stats.ahead_unbuilt_frames, stats.no_ground_frames])
	for id: String in stats.regions:
		var r: Dictionary = stats.regions[id]
		_note("  %s: built %s m before she reached it; %d frames inside unbuilt" % [id, str(snappedf(r.get("lead", -1.0), 0.1)), r.get("late", 0)])
	_beat["pop_in"] = stats
	if stats.no_ground_frames > 0 or stats.unbuilt_frames > 30:
		_note("FAIL-ISH: the world arrived late at full gallop")
	_pass()

	_begin("dismount", "rein in, then E: she gets down on the near side")
	_stop = true
	await _until(func() -> bool: return director.mare.speed < 0.3, 8.0)
	_record("dismount")
	await _wait(1.0)
	director.dismount()
	await _wait(2.5)
	_stop_recording()
	if director.riding or not feyre.is_physics_processing():
		return _fail("still in the saddle")
	_note("Feyre on foot at %s, mare at %s (%.1f m)" % [_v(feyre.global_position), _v(director.mare.global_position), feyre.global_position.distance_to(director.mare.global_position)])
	_pass()

	_begin("whistle", "walk off, whistle: she gallops in from out of sight and stands beside her")
	director.free_mare()
	await _wait(1.0)
	_record("whistle")
	if not director.whistle():
		_stop_recording()
		return _fail("whistle not answered: %s" % director.last_block)
	var t0 := _sim_seconds()
	var came := await _until(func() -> bool: return director.mare != null and director.mare.state == MareMount.State.STANDING, 25.0)
	await _wait(2.0)
	_stop_recording()
	if not came:
		return _fail("she never arrived (at %s)" % _v(director.mare.global_position))
	_note("arrived in %.1f s, %.1f m from Feyre" % [_sim_seconds() - t0, director.mare.global_position.distance_to(feyre.global_position)])
	_pass()
	_finish(0)


func _measure(stats: Dictionary, at: Vector3, heading: Vector3) -> void:
	var region := WorldStreamer.region_at(at)
	if region:
		var id := String(region.id)
		var r: Dictionary = stats.regions.get(id, {})
		stats.regions[id] = r
		if not _built(id):
			stats.unbuilt_frames += 1
			r["late"] = int(r.get("late", 0)) + 1
	var ahead := WorldStreamer.region_at(at + heading * 60.0)
	if ahead and not _built(String(ahead.id)):
		stats.ahead_unbuilt_frames += 1
	# The first frame each region near her is built: how far she still was from it.
	for id: String in WorldStreamer.loaded_ids():
		var r: Dictionary = stats.regions.get(id, {})
		if not r.has("lead") and _built(id):
			var def := WorldStreamer.get_region(StringName(id))
			r["lead"] = def.edge_distance(at) if def else -1.0
			stats.regions[id] = r
	if is_nan(director.ground_at(at.x, at.z)):
		stats.no_ground_frames += 1


func _built(id: String) -> bool:
	if not WorldStreamer.is_loaded(StringName(id)):
		return false
	var root := WorldStreamer.loaded_root(StringName(id))
	if root == null:
		return false
	for n in [root] + root.get_children():
		if &"is_built" in n:
			return bool(n.get(&"is_built"))
	return true
