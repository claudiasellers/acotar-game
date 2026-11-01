## R17 proof clip for L25 (the Bogge and the puca), from the real game scene
## through Feyre's own camera. Needs a GPU (Mac shots, docs/contracts/shots.md):
##   shot dangers res://tools/playtest/act2_dangers_clip.tscn -- --out={out}/report.json
## Writes {out}/bogge_####.jpg and {out}/puca_####.jpg at 10 fps (1280x720,
## from a 1920x1080 render) plus the playtest-style report.json.
##
## The clip only exists to be looked at, so it jumps ahead: it raises the
## Act I and first-dinner deeds itself and moves Feyre to each scene. The
## scenes themselves then play untouched, driven by presses and camera turns:
##   Bogge: walk in with Lucien; stare at the elm; one 0.3 s glance back (it
##          half-forms, the fog thickens); back to the elm; then turn and
##          linger until it is real and comes.
##   Puca:  night in the garden; follow the silent father to the open gate;
##          Tamlin; look again until it darts.
extends "res://tools/playtest/act1_playtest.gd"

const FPS := 10.0
const SAVE_SIZE := Vector2i(1280, 720)
## Deeds before the Bogge (dev jump, pictures only).
const JUMP := ["wolf_killed", "pelt_sold", "beast_claim_accepted", "wall_crossed",
	"fact.manor_arrived", "fact.alis_bathed", "first_dinner_eaten"]

var _rec_prefix: String = ""
var _rec_left: float = 0.0
var _rec_count: int = 0
var _frames_dir: String = ""


func _process(delta: float) -> void:
	if _rec_prefix == "":
		return
	_rec_left -= delta
	if _rec_left > 0.0:
		return
	_rec_left = 1.0 / FPS
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	img.resize(SAVE_SIZE.x, SAVE_SIZE.y, Image.INTERPOLATE_BILINEAR)
	img.save_jpg("%s/%s_%04d.jpg" % [_frames_dir, _rec_prefix, _rec_count], 0.88)
	_rec_count += 1


func _record(prefix: String) -> void:
	_rec_prefix = prefix
	_rec_count = 0
	_rec_left = 0.0


func _stop_recording() -> void:
	_note("%s: %d frames" % [_rec_prefix, _rec_count])
	_rec_prefix = ""


func _play() -> void:
	_frames_dir = out_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(_frames_dir)
	_begin("clip_setup", "load, jump to the Bogge's path")
	if not await _until(func() -> bool: return game.spawned, 60.0):
		return _fail("never spawned")
	feyre = game.feyre
	for flag: String in JUMP:
		WorldState.raise_deed(flag)
	await _wait(1.0)
	_note("phase %s" % PhaseManager.current_phase)
	var hunt := Vector3(BorderWoodsTerrain.BOGGE_HUNT.x, 0.0, BorderWoodsTerrain.BOGGE_HUNT.y)
	if not await _jump_near(&"bogge_hunt_path", hunt):
		return _fail("no bogge_hunt_path anchor after the jump")
	_pass()
	await _bogge_clip()
	await _puca_clip()


## Puts her well short of an anchor and waits for the region to stream in.
func _jump_near(anchor_id: StringName, at: Vector3) -> bool:
	feyre.global_position = at + Vector3.UP * 40.0
	feyre.velocity = Vector3.ZERO
	await _until(func() -> bool: return _anchor(anchor_id) != null, 90.0)
	var anchor := _anchor(anchor_id)
	if anchor == null:
		return false
	await _wait(4.0)
	return true


func _place(p: Vector3, face: Vector3) -> void:
	p.y = _ground_at(p) + 0.4
	feyre.global_position = p
	feyre.velocity = Vector3.ZERO
	await _wait(0.5)
	for i in 30:
		_turn_camera_to(face + Vector3.UP * 1.6)
		await get_tree().physics_frame


func _bogge_clip() -> void:
	_begin("bogge_clip", "Lucien freezes; eyes on the elm; a glance; then she lingers and it comes")
	var space := _find_named(&"Moment_bogge") as BoggeHunt
	if space == null:
		return _fail("the bogge moment isn't the coded BoggeHunt")
	await _place(space.mark(&"retry"), space.mark(&"freeze"))
	await _wait(2.0)
	_record("bogge")
	await _walk_to(space.mark(&"freeze"), 2.0, func() -> bool: return space.running and StoryControl.mode == StoryControl.Mode.LOOK, 60.0)
	var elm := space.mark(&"elm") + Vector3.UP * 3.0
	await _hold_view(func() -> Vector3: return elm, func() -> bool: return space.current_beat_label() == "it passes behind her", 30.0)
	await _hold_view(func() -> Vector3: return elm, Callable(), 5.0)
	_note("glance back")
	await _hold_view(func() -> Vector3: return _bogge_point(space), Callable(), 0.45)
	_note("after the glance: acknowledged %.2f, fog %.3f" % [space.acknowledged, space.fog_density()])
	await _hold_view(func() -> Vector3: return elm, Callable(), 3.5)
	_note("turning to look at it")
	await _hold_view(func() -> Vector3: return _bogge_point(space), func() -> bool: return not space.running, 8.0)
	await _wait(3.0)
	_stop_recording()
	_note("fails %d, fact.bogge_looked %s" % [space.fail_count, WorldState.has_flag("fact.bogge_looked")])
	if space.fail_count < 1:
		return _fail("lingering never made it real")
	_pass()


func _bogge_point(space: BoggeHunt) -> Vector3:
	var b := space.bogge()
	return b.global_position + Vector3.UP * 1.8 if b else space.mark(&"freeze")


func _puca_clip() -> void:
	_begin("puca_clip", "night garden; follow Father to the gate; Tamlin; look again until it darts")
	WorldState.raise_deed("curtain_trap_set")
	WorldState.raise_deed("bogge_survived")
	Clock.from_dict({"time_of_day": 0.93, "day": Clock.day})
	if not await _jump_near(&"garden_gate", Vector3(0.0, 0.0, -194.0)):
		return _fail("no garden_gate anchor after the jump")
	var space := _find_named(&"Moment_puca") as PucaLure
	if space == null:
		return _fail("the puca moment isn't the coded PucaLure")
	await _place(space.mark(&"house") + (space.mark(&"house") - space.mark(&"hedge")).normalized() * 6.0, space.mark(&"hedge"))
	_record("puca")
	if not await _until(func() -> bool: return space.running, 15.0):
		_stop_recording()
		return _fail("the puca never came (can_start %s, night %s)" % [space.can_start(), Clock.is_night()])
	await _hold_view(func() -> Vector3: return _puca_point(space), Callable(), 3.0)
	await _walk_to(space.mark(&"gate"), 2.0, func() -> bool: return space.current_beat_label() != "follow him to the gate" or not space.running, 200.0)
	await _hold_view(func() -> Vector3: return _puca_point(space), func() -> bool: return not space.running, 45.0)
	await _wait(1.0)
	_stop_recording()
	_note("shapes %s, puca_resisted %s" % [space.shifts_seen, WorldState.has_flag("puca_resisted")])
	if not WorldState.has_flag("puca_resisted"):
		return _fail("no puca_resisted (beat '%s')" % space.current_beat_label())
	_pass()


func _puca_point(space: PucaLure) -> Vector3:
	var p := space.puca()
	return p.global_position + Vector3.UP * 1.3 if p else space.mark(&"beyond")


## Keeps turning the camera to a moving point for up to `seconds`.
func _hold_view(point: Callable, until: Callable, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		if until.is_valid() and until.call():
			return
		_turn_camera_to(point.call())
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
