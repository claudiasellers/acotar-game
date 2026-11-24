## Proof clip for the tracking rules (plans/hostile-fae/health-interactions.md
## §3.6, R17): in the real ch1 hunt she walks 80 m away from the great wolf
## with her back to him, stands until he has given himself away twice, then
## turns and finds him again. Headless it plays it and reports the numbers
## (the farthest he got from her, the cues, the line); with a GPU it also
## writes frames, as wolf_hunt_clip.gd does:
##   shot lost res://tools/playtest/wolf_lost_clip.tscn -- --out={out}/report.json
extends "res://tools/playtest/wolf_hunt_clip.gd"

const AWAY_METRES := 80.0


func _play() -> void:
	var hunt := await _enter_hunt()
	if hunt == null:
		return

	_begin("close", "watch the doe, then walk to within 28 m of him so the leash arms")
	await _hold_on(func() -> Node3D: return hunt.doe, func() -> bool: return hunt.wolf != null, 20.0)
	var wolf := hunt.wolf as GreatWolf
	if wolf == null or wolf.leash == null or wolf.nudge == null:
		return _fail("the great wolf has no leash or nudge")
	await _walk_to(wolf.global_position, 28.0, Callable(), 40.0)
	await _hold_on(func() -> Node3D: return wolf, Callable(), 2.0)
	_note("%5.1f s  %.0f m from him, leash armed %s, wolf state %s" % [_secs(), _flat(wolf.global_position),
		wolf.leash.armed, wolf.state])
	if not wolf.leash.armed:
		return _fail("the leash never armed")
	_pass()

	_begin("walk_away", "walk %d m away with her back to him; he is never more than his leash from her" % AWAY_METRES)
	var away := Creature.away_from(feyre.global_position, wolf.global_position)
	var target := feyre.global_position + away * AWAY_METRES
	var worst := {"far": 0.0, "seen_closing": 0, "last": _flat(wolf.global_position)}
	var watch := func() -> void:
		if not is_instance_valid(wolf):
			return
		var d := _flat(wolf.global_position)
		worst.far = maxf(worst.far, d)
		if FollowLeash.sees(wolf) and d < float(worst.last) - 0.01 and wolf.velocity.length() > 0.2:
			worst.seen_closing += 1
		worst.last = d
	get_tree().physics_frame.connect(watch)
	await _walk_to(target, 4.0, Callable(), 90.0)
	get_tree().physics_frame.disconnect(watch)
	_note("%5.1f s  walked to %.0f m from where she started; farthest he got %.1f m; frames she saw him closing %d; he is %.0f m off, state %s" % [
		_secs(), AWAY_METRES - _flat(target), worst.far, worst.seen_closing, _flat(wolf.global_position), wolf.state])
	if float(worst.far) > wolf.leash.metres:
		return _fail("he got %.1f m from her, past his %.0f m leash" % [worst.far, wolf.leash.metres])
	_pass()

	_begin("lost", "stand with her back to him until he has cued twice and she says she's lost him")
	var cues: Array = []
	wolf.nudge.cued.connect(func(count: int) -> void:
		cues.append(count)
		_note("%5.1f s  cue %d from %s, %.0f m off" % [_secs(), count, _v(wolf.global_position), _flat(wolf.global_position)]))
	var back := feyre.global_position + away * 30.0
	var t := 0.0
	while t < 90.0 and cues.size() < 2:
		_turn_camera_to(back + Vector3.UP * 1.5)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	await _wait(4.0)
	_note("%5.1f s  cues %s; lost line said %s" % [_secs(), cues, spoken.has("wh_lost")])
	if cues.size() < 2:
		return _fail("he never cued twice in 90 s")
	if not spoken.has("wh_lost"):
		return _fail("she never said she had lost him")
	_pass()

	_begin("find", "turn to the sound and walk until she sees him")
	var seen := {"at": -1.0}
	var found := func() -> bool:
		if float(seen.at) < 0.0 and FollowLeash.sees(wolf):
			seen.at = _flat(wolf.global_position)
		return float(seen.at) >= 0.0
	await _hold_on(func() -> Node3D: return wolf, found, 3.0)
	if not found.call():
		await _walk_to(wolf.global_position, 12.0, found, 40.0)
	await _hold_on(func() -> Node3D: return wolf, Callable(), 4.0)
	_rec = false
	_note("%5.1f s  found him %s, first seen at %.0f m; cues reset to %d; frames %d" % [_secs(), found.call(),
		seen.at, wolf.nudge.count, _rec_count])
	if not found.call():
		return _fail("she never found him again")
	_pass()
