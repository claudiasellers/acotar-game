## Headless p3 playthrough of the Suriel and the naga (L26), extending the
## Act I playtest: same walker, presses only, same report and exit codes.
## Starts from the dev jump (story/act3/dev/p3_jump.tscn) in the Suriel's
## glade and plays the canon way: scout the stream, rig the snare in the
## birches, lay the rabbit, hide downwind, go to the Suriel, hear it out,
## then fight the naga until Tamlin comes.
##   tools/mq/godot.sh --fixed-fps 60 res://tools/playtest/p3_suriel_playtest.tscn -- --out=/tmp/p3.json
## Passes when the log has "PLAYTEST exit 0" and these beats pass: spawn,
## scout_stream, set_snare, hide_downwind, suriel_caught, answers, naga.
## final_phase stays p3_house_and_woods with suriel_bound and naga_survived.
extends "res://tools/playtest/act1_playtest.gd"

const JUMP_SCENE := "res://story/act3/dev/p3_jump.tscn"

var jump: Node
var snare: SurielSnare
var ambush: NagaAmbush
var journal_seen: int = 0


func _run() -> void:
	EventBus.journal_entry_added.connect(func(id: StringName) -> void:
		journal_seen += 1
		_log("journal %s" % id))
	jump = (load(JUMP_SCENE) as PackedScene).instantiate()
	add_child(jump)
	game = jump.get(&"game")
	_load_seconds = Time.get_unix_time_from_system() - _started_at
	_log("p3 jump loaded in %.1f s (wall)" % _load_seconds)
	await _play()
	if not _finished:
		_release_all()
		_note_shutdown_suspects()
		await _settle(settle_limit)
		_finish(0 if beats.all(func(b: Dictionary) -> bool: return b.status == "pass") else 1)


func _play() -> void:
	_begin("spawn", "Feyre stands in the Suriel's glade in p3, controllable")
	# The glade builds in the background (wall-clock bound, minutes headless).
	if game == null or not await _until_wall(func() -> bool: return game.spawned, 900.0):
		return _fail("never spawned")
	feyre = game.feyre
	await _until(func() -> bool: return _anchor(&"suriel_snare") != null, 10.0)
	var anchor := _anchor(&"suriel_snare")
	if anchor == null:
		return _fail("no suriel_snare anchor")
	snare = anchor.get_node_or_null(^"SurielSnare") as SurielSnare
	ambush = anchor.get_node_or_null(^"NagaAmbush") as NagaAmbush
	if snare == null or ambush == null:
		return _fail("Act3Anchors didn't hang SurielSnare/NagaAmbush on the anchor")
	_note("at %s in %s, phase %s" % [_v(feyre.global_position), _region(), PhaseManager.current_phase])
	if PhaseManager.current_phase != &"p3_house_and_woods":
		return _fail("not in p3")
	_pass()
	if _beat.id == stop_after:
		return

	_begin("scout_stream", "walk to the Thornwater first (her escape route)")
	var bank := _nearest_bank(snare.birch_center)
	await _walk_to(bank, 3.0, func() -> bool: return snare.scouted, 60.0)
	if not await _until(func() -> bool: return snare.running and snare.scouted, 5.0):
		return _fail("scouted never set (running %s, river %.0f m)" % [snare.running, MacroHeight.distance_to_river(feyre.global_position.x, feyre.global_position.z)])
	_pass()

	_begin("set_snare", "in the young birches: E rigs the double loop and lays the rabbit")
	await _walk_to(snare.birch_center, 3.0)
	await _press(&"interact")
	await _wait(0.3)
	if snare.snare_at == Vector3.INF:
		return _fail("E in the birches didn't rig the snare (loops %d, %.0f m from the ring)" % [
			SnarePlan.loops_from(Gameplay.inventory), _flat(snare.birch_center)])
	_note("snare with %d loops, bait %s (%.2f)" % [snare.loops, snare.bait_id, snare.bait])
	if snare.loops != 2 or snare.bait_id != &"ing_rabbit":
		return _fail("expected a double loop baited with the rabbit")
	_pass()

	_begin("hide_downwind", "16 m downwind, still, until the Suriel comes")
	var w: Vector3 = snare.wind_fn.call(snare.snare_at)
	var down := Vector3(w.x, 0.0, w.z).normalized()
	await _walk_to(snare.snare_at + down * 16.0, 2.0)
	_release_all()
	# Turn round to watch the snare, as a player would.
	for i in 90:
		_turn_camera_to(snare.snare_at + Vector3.UP)
		await get_tree().physics_frame
	var wait := SnarePlan.wait_seconds(snare.bait) + 15.0
	if not await _until(func() -> bool: return snare.stage >= SurielSnare.Stage.ARRIVE, wait):
		return _fail("no Suriel after %.0f s (stage %s, waited %.1f, smelled %.1f)" % [wait, snare.stage, snare.waited, snare.smelled_seconds])
	_note("waited %.1f s, smelled %.1f s" % [snare.waited, snare.smelled_seconds])
	_pass()

	_begin("suriel_caught", "the snare takes it; she goes down to it")
	if not await _until(func() -> bool: return snare.stage >= SurielSnare.Stage.SNARED, 30.0):
		return _fail("the Suriel never reached the snare")
	await _walk_to(snare.snare_at, 3.0, func() -> bool: return snare.stage >= SurielSnare.Stage.ANSWERS)
	if snare.stage < SurielSnare.Stage.ANSWERS:
		return _fail("walked up but it never answered")
	_note("quality %.2f -> %d answers" % [snare.quality, snare.answers_due])
	_pass()

	_begin("answers", "hear it out; suriel_bound")
	if not await _until(func() -> bool: return WorldState.has_flag("suriel_bound"), 90.0):
		return _fail("suriel_bound never raised (%d answers heard)" % snare.answers_heard.size())
	if journal_seen != snare.answers_due:
		return _fail("%d journal entries for %d answers" % [journal_seen, snare.answers_due])
	_pass()

	_begin("naga", "four naga; kill one, live until Tamlin comes; naga_survived")
	if not await _until(func() -> bool: return ambush.running, 10.0):
		return _fail("NagaAmbush never started")
	var t0 := _sim_seconds()
	var next_note := t0
	while not WorldState.has_flag("naga_survived") and _sim_seconds() - t0 < 150.0:
		var target := _nearest_naga()
		if _sim_seconds() >= next_note:
			next_note = _sim_seconds() + 10.0
			_note("fight: nearest naga %s, quiver %s, control %s, strikes %d, falls %d, at %s" % [
				"%.1f m" % target.global_position.distance_to(feyre.global_position) if target else "none",
				_quiver(), _mode(), ambush.strikes, ambush.falls, _v(feyre.global_position)])
		if target == null:
			await _wait(0.5)
			continue
		if target.global_position.distance_to(feyre.global_position) <= NagaAmbush.KNIFE_REACH:
			await _press(&"interact")
			await _wait(0.3)
		elif target.global_position.distance_to(feyre.global_position) > 18.0:
			await _wait(0.2)  # out of a sure shot: let it come
		elif not await _shoot_at(target):
			await _wait(0.3)
	_note("strikes %d, falls %d, kills %d, Tamlin %s" % [ambush.strikes, ambush.falls, ambush.kills, ambush.tamlin_came])
	if not WorldState.has_flag("naga_survived"):
		return _fail("naga_survived never raised")
	_pass()


func _until_wall(cond: Callable, wall_seconds: float) -> bool:
	var end := Time.get_unix_time_from_system() + wall_seconds
	while Time.get_unix_time_from_system() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _nearest_bank(from: Vector3) -> Vector3:
	var best := from
	var best_d := INF
	for i in 36:
		for r in [10.0, 20.0, 30.0, 40.0, 50.0]:
			var p: Vector3 = from + Vector3(cos(TAU * i / 36.0), 0.0, sin(TAU * i / 36.0)) * float(r)
			var d := MacroHeight.distance_to_river(p.x, p.z)
			if d <= MacroHeight.RIVER_HALF_WIDTH + 4.0 and float(r) < best_d:
				best_d = float(r)
				best = p
	return best


func _nearest_naga() -> Creature:
	var best: Creature = null
	for id: StringName in ambush.naga:
		var c := ambush.naga[id] as Creature
		if c and is_instance_valid(c) and c.alive and (best == null or
				c.global_position.distance_to(feyre.global_position) < best.global_position.distance_to(feyre.global_position)):
			best = c
	return best
