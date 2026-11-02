## Scratch (never committed): from the Bogge's safety mark, the chain's puca_gate walk.
extends "res://tools/playtest/act2_dangers_clip.gd"

var _trace_t := 0.0

func _physics_process(delta: float) -> void:
	if feyre == null:
		return
	_trace_t += delta
	if _trace_t >= 2.0:
		_trace_t = 0.0
		var sp := _find_named(&"Moment_puca") as SceneSpace
		var extra := ""
		if sp:
			var at: Vector3 = sp.global_transform * sp.arrive_offset
			extra = " arrive_at %s dy %.2f flat %.1f here %s run %s" % [_v(at), feyre.global_position.y - at.y, Vector2(feyre.global_position.x - at.x, feyre.global_position.z - at.z).length(), sp._player_here(), sp.running]
		_log("TRACE %s %s floor %s%s" % [_v(feyre.global_position), _region(), _last_floor, extra])

func _play() -> void:
	_begin("probe_setup", "deeds to the puca, stand at the Bogge's safety mark")
	if not await _until(func() -> bool: return game.spawned, 60.0):
		return _fail("never spawned")
	feyre = game.feyre
	for flag: String in JUMP + ["curtain_trap_set", "bogge_survived"]:
		WorldState.raise_deed(flag)
	await _wait(1.0)
	var hunt := Vector3(BorderWoodsTerrain.BOGGE_HUNT.x, 0.0, BorderWoodsTerrain.BOGGE_HUNT.y)
	if not await _jump_near(&"bogge_hunt_path", hunt):
		return _fail("no bogge anchor")
	var space := await _scene_at(&"bogge_hunt_path", &"Moment_bogge") as BoggeHunt
	await _place(space.mark(&"safety"), space.mark(&"elm"))
	_note("phase %s at %s" % [PhaseManager.current_phase, _v(feyre.global_position)])
	_pass()
	await Act2GroundsBeats.new(self)._puca_gate()
