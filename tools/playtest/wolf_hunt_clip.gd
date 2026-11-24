## Proof clip for L34-4: the ch1 wolf hunt with Feyre's guiding thoughts,
## the camera finding the doe and then him, and the lens tightening as she
## lines up the shot. From the real game scene, through her own camera.
## Headless it plays the hunt and logs every thought (no frames); with a GPU
## (Mac shots, docs/contracts/shots.md) it also writes frames:
##   shot wolf res://tools/playtest/wolf_hunt_clip.tscn -- --out={out}/report.json
## Writes {out}/wolf_####.jpg at 4 fps (1280x720) plus the playtest report,
## whose notes list each line with the second it was spoken.
##
## Unlike the chain's bot, she plays it like a newcomer: walks in, watches,
## and waits without drawing until her own thoughts nudge her, then draws,
## holds the drawn bow on him for a moment, and shoots: ash first, then wood.
extends "res://tools/playtest/act1_playtest.gd"

const FPS := 4.0
const SAVE_SIZE := Vector2i(1280, 720)
## The longest she waits for the nudge before drawing anyway.
const WAIT_FOR_NUDGE := 45.0
## How far to the side of an animal she rests her view, as a share of its distance.
const BESIDE := 0.16

var _rec: bool = false
var _rec_left: float = 0.0
var _rec_count: int = 0
var _frames_dir: String = ""
var _t0: int = 0
var spoken: Array = []


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
	img.save_jpg("%s/wolf_%04d.jpg" % [_frames_dir, _rec_count], 0.88)
	_rec_count += 1


func _secs() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0


func _play() -> void:
	var hunt := await _enter_hunt()
	if hunt == null:
		return
	await _watch_and_shoot(hunt)


## Waits for her at the cottage with control, and listens for her lines.
## False (the beat already failed) if she never got there.
func _spawn_in() -> bool:
	_frames_dir = out_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(_frames_dir)
	_begin("spawn", "Feyre at the cottage, controllable")
	if not await _until(func() -> bool: return game.spawned, 30.0):
		_fail("never spawned")
		return false
	feyre = game.feyre
	feyre.arrow_fired.connect(func(arrow: Node) -> void:
		arrow.hit.connect(func(collider: Node, at: Vector3) -> void:
			_last_landing = at
			_log("arrow %s hit %s at %s" % [arrow.get(&"arrow_id"), collider.name if collider else "nothing", _v(at)])))
	await _until(func() -> bool: return StoryControl.mode == StoryControl.Mode.FULL, 10.0)
	var director := get_tree().get_first_node_in_group(DialogueDirector.GROUP) as DialogueDirector
	if director == null:
		_fail("no DialogueDirector in the game")
		return false
	director.line_spoken.connect(func(id: StringName, _s: StringName, text: String, _at: Vector3, _inner: bool) -> void:
		spoken.append(String(id))
		_note("%5.1f s  [%s] %s" % [_secs(), id, text]))
	_pass()
	return true


## Spawns, walks to the clearing and starts recording as the hunt begins.
## Null (the beat already failed) if any of that didn't happen.
func _enter_hunt() -> WolfKill:
	if not await _spawn_in():
		return null

	_begin("walk_in", "walk to the clearing until the hunt starts")
	var clearing := _anchor(&"act1_wolf_clearing")
	if clearing == null:
		await _walk_region(&"hunting_forest")
		clearing = _anchor(&"act1_wolf_clearing")
	if clearing == null:
		_fail("no act1_wolf_clearing anchor")
		return null
	var hunt := clearing.get_node_or_null(^"WolfKill") as WolfKill
	if hunt == null:
		_fail("no WolfKill under the clearing")
		return null
	await _walk_to(clearing.global_position, 3.0, func() -> bool: return hunt.running)
	if not await _until(func() -> bool: return hunt.running, 20.0):
		_fail("the hunt never started")
		return null
	var spot := hunt.global_transform * hunt.doe_offset
	var here := Vector2(feyre.global_position.x, feyre.global_position.z)
	_note("hunt began %.0f m from the doe's spot; her line to it is %.1f m clear of the wood" % [_flat(spot),
		Act1Wayfinding.sight_open(here, Vector2(spot.x, spot.z), hunt._trees)])
	_t0 = Time.get_ticks_msec()
	_rec = true
	_pass()
	return hunt


func _watch_and_shoot(hunt: WolfKill) -> void:
	_begin("watch", "the doe, golden eyes, his size; she waits without drawing until nudged")
	await _hold_on(func() -> Node3D: return hunt.doe, func() -> bool: return hunt.wolf != null, 20.0)
	await _hold_on(func() -> Node3D: return hunt.wolf,
			func() -> bool: return spoken.has("wh_nudge_draw"), WAIT_FOR_NUDGE)
	_note("%5.1f s  nudged: %s, wolf state %s" % [_secs(), spoken.has("wh_nudge_draw"),
		(hunt.wolf as GreatWolf).state if hunt.wolf is GreatWolf else -1])
	await _hold_on(func() -> Node3D: return hunt.wolf, Callable(), 3.0)
	_pass()

	_begin("shoot", "draw on him and hold; ash into his side; then the eye")
	focus_shots = true
	var wolf := hunt.wolf
	for shot in 12:
		if WorldState.has_flag("wolf_killed") or not is_instance_valid(wolf):
			break
		if not hunt.ash_struck and Gameplay.inventory.count(&"arrow_ash") == 0:
			if not await _retrieve_arrow(&"ash"):
				# Lost: the hunt gives one back after a few seconds.
				await _until(func() -> bool: return Gameplay.inventory.count(&"arrow_ash") > 0, 8.0)
		if hunt.ash_struck and Gameplay.inventory.arrow_count() == 0:
			if not await _retrieve_arrow(&"wood"):
				await _until(func() -> bool: return Gameplay.inventory.arrow_count() > 0, 8.0)
		await _select_arrow(&"arrow_ash" if not hunt.ash_struck else &"arrow_wood")
		if _flat(wolf.global_position) > 30.0:
			await _walk_to(wolf.global_position, 22.0, Callable(), 20.0)
		await _shoot_at(wolf)
		await _wait(1.0)
	await _until(func() -> bool: return WorldState.has_flag("wolf_killed"), 10.0)
	await _wait(12.0)
	_rec = false
	_note("frames %d; lines %s" % [_rec_count, spoken])
	if not WorldState.has_flag("wolf_killed"):
		return _fail("no wolf_killed")
	for id in ["wh_doe", "wh_eyes", "wh_pony", "wh_nudge_draw", "wh_ash", "wh_dying"]:
		if not spoken.has(id):
			return _fail("never heard %s" % id)
	_pass()


## Keeps her view on a node until `until` or `seconds` pass.
func _hold_on(node: Callable, until: Callable, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		if until.is_valid() and until.call():
			return
		var n: Node3D = node.call()
		if is_instance_valid(n):
			# A little to the right of it, as a player holds the view: the animal sits beside her, not behind her head.
			var to := n.global_position - feyre.global_position
			_turn_camera_to(n.global_position + Vector3.UP * 0.9 + to.cross(Vector3.UP).normalized() * to.length() * BESIDE)
		await get_tree().physics_frame
		var before := t
		t += get_physics_process_delta_time()
		if int(before / 2.0) != int(t / 2.0):
			_where()
	return


func _where() -> void:
	var space := _anchor(&"act1_wolf_clearing").get_node_or_null(^"WolfKill") as WolfKill
	if space == null or not is_instance_valid(space.wolf):
		return
	var w := space.wolf
	var d: Node3D = space.doe if is_instance_valid(space.doe) else null
	_note("%5.1f s  wolf %s state %s, doe %s alive %s state %s, apart %.1f m, her %.0f m" % [_secs(), _v(w.global_position),
		w.get(&"state"), _v(d.global_position) if d else "-", d.get(&"alive") if d else "-", d.get(&"state") if d else "-",
		w.global_position.distance_to(d.global_position) if d else -1.0, _flat(w.global_position)])


## The clip has its own beats, not the chain's.
func _missing_beats() -> PackedStringArray:
	return PackedStringArray()
