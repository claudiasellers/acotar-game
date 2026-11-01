## Headless ch 17 playthrough (L29), extending the Act I playtest: same walker,
## presses only, same report and exit codes. Starts from the dev jump
## (story/act3/summer/dev/faerie_jump.tscn) at night in the entrance hall.
##   tools/mq/godot.sh --fixed-fps 60 res://tools/playtest/p3_faerie_playtest.tscn -- --out=/tmp/p3f.json [--scenario=alone]
## held (default) passes with beats: spawn, carried_in, shelves, triage, words,
##   hand, held. She runs to the infirmary for the honey and willow bark on the
##   bandage shelves (they restock daily), then reads, cleans, dresses and binds
##   both stumps, hears him, takes his hand and stays; summer_faerie_comforted.
## alone passes with beats: spawn, carried_in, left_him, died_alone. She runs
##   for the stillroom and he dies alone: no comforted, the grave is dug.
##   (The daytime vigil is in tests/unit/story/test_summer_faerie_triage.gd.)
extends "res://tools/playtest/act1_playtest.gd"

const JUMP_SCENE := "res://story/act3/summer/dev/faerie_jump.tscn"
## The stillroom bench, through the service passage (gen_service).
const STILLROOM := Vector3(73.3, 0.0, -44.5)
## The infirmary's bandage shelves (gen_service.gd, larders infirmary_*).
const SHELVES := [Vector3(66.0, 0.0, -39.4), Vector3(72.0, 0.0, -39.4)]

var jump: Node
var triage: SummerFaerieTriage
var scenario: String = "held"


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.trim_prefix("--scenario=")
	EventBus.journal_entry_added.connect(func(id: StringName) -> void: _log("journal %s" % id))
	jump = (load(JUMP_SCENE) as PackedScene).instantiate()
	add_child(jump)
	game = jump.get(&"game")
	_load_seconds = Time.get_unix_time_from_system() - _started_at
	_log("faerie jump loaded in %.1f s (wall), scenario %s" % [_load_seconds, scenario])
	await _play()
	if not _finished:
		_release_all()
		_note_shutdown_suspects()
		await _settle(settle_limit)
		_finish(0 if beats.all(func(b: Dictionary) -> bool: return b.status == "pass") else 1)


func _play() -> void:
	_begin("spawn", "Feyre stands in the entrance hall at night in p3, controllable")
	if game == null or not await _until_wall(func() -> bool: return game.spawned, 900.0):
		return _fail("never spawned")
	feyre = game.feyre
	var anchor := _anchor(&"manor_window_hide")
	if anchor == null:
		return _fail("no manor_window_hide anchor")
	triage = anchor.get_node_or_null(^"SummerFaerieTriage") as SummerFaerieTriage
	if triage == null:
		return _fail("Act3Anchors didn't hang SummerFaerieTriage on the hall anchor")
	if not await _until(func() -> bool: return feyre.is_on_floor(), 20.0):
		return _fail("not standing: %s" % _v(feyre.global_position))
	_note("at %s, phase %s, night %s" % [_v(feyre.global_position), PhaseManager.current_phase, Clock.is_night()])
	_pass()

	_begin("carried_in", "Tamlin carries him in; he's laid on the hall table and the clock runs")
	if not await _until(func() -> bool: return triage.running and triage.state != null, 20.0):
		return _fail("the scene never started (can_start %s, here %s)" % [triage.can_start(), triage.player_present])
	if triage.faerie == null or triage.faerie.global_position.distance_to(triage.global_position) > 2.0:
		return _fail("no faerie on the table")
	_note("table at %s, blood %.0f" % [_v(triage.global_position), triage.state.blood])
	_pass()
	if scenario == "alone":
		await _play_alone()
		return

	_begin("shelves", "she runs to the infirmary for the wound herbs on the bandage shelves")
	if not triage.hinted and not await _until(func() -> bool: return triage.hinted, 6.0):
		return _fail("no hint about the shelves")
	for at: Vector3 in SHELVES:
		await _walk_to(at, 0.8, Callable(), 90.0)
		await _press(&"interact")
		await _wait(0.3)
	var herbs := Gameplay.inventory.count(&"ing_honey") + Gameplay.inventory.count(&"ing_willow_bark")
	_note("herbs %d, at %s, blood %.1f after %.1f s" % [herbs, _v(feyre.global_position), triage.state.blood, triage.state.elapsed])
	if herbs < 2:
		return _fail("took %d herbs from the shelves" % herbs)
	await _walk_to(_at(Vector3(2.3, 0, -1.4)), 0.8, Callable(), 90.0)
	_pass()

	_begin("triage", "read, clean, dress and bind both stumps from the bowl and the shelf herbs")
	var t0 := _sim_seconds()
	await _walk_to(_at(Vector3(2.3, 0, -1.4)), 0.5)
	for i in 2:
		if not await _do_wound("read %d" % i):
			return
		if i == 0:
			await _at_supplies()
			if not await _do_wound("clean %d" % i):
				return
		else:
			await _at_supplies()  # the second strip (the rag is still wet)
			if not await _do_wound("clean %d" % i):
				return
		if not await _do_wound("dress %d" % i):
			return
		if i == 0:
			await _at_supplies()
		if not await _do_wound("bind %d" % i):
			return
	var all_bound := triage.state.wounds.all(func(w: TriageWound) -> bool: return w.bound and w.dressed and w.cleaned and w.read)
	_note("triage in %.1f s, blood %.1f, rate %.3f/s, fire lily kept %d" % [_sim_seconds() - t0,
		triage.state.blood, triage.state.bleed_rate(), Gameplay.inventory.count(&"ing_fire_lily")])
	if not all_bound:
		return _fail("not every stump read, cleaned, dressed and bound")
	_pass()

	_begin("words", "he comes round: 'She took my wings.'")
	if not await _until(func() -> bool: return triage.spoke, 3.0):
		return _fail("he never spoke (blood %.1f)" % triage.state.blood)
	_pass()

	_begin("hand", "she takes his hand and promises")
	await _walk_to(_at(Vector3(-1.4, 0, -1.05)), 0.25)
	await _press(&"interact")
	await _wait(0.3)
	if not (triage.state.holding and triage.state.promised):
		return _fail("not holding (target %s at %s)" % [triage.target_at(feyre.global_position), _v(feyre.global_position)])
	_pass()

	_begin("held", "he dies holding her hand; awhile after; summer_faerie_comforted")
	if not await _until(func() -> bool: return WorldState.has_flag("summer_faerie_comforted"), 60.0):
		return _fail("comforted never raised (outcome %s, dead %s)" % [triage.outcome, triage.state.dead])
	_note("died at %.1f s of the clock, outcome %s" % [triage.state.died_at, triage.outcome])
	if triage.outcome != &"held":
		return _fail("outcome %s" % triage.outcome)
	_pass()


func _play_alone() -> void:
	_begin("left_him", "she runs for the stillroom instead of staying")
	await _walk_to(STILLROOM, 2.0, func() -> bool: return triage.state.dead, 120.0)
	_note("at %s, %.1f m from the table, blood %.1f" % [_v(feyre.global_position), _flat(triage.global_position), triage.state.blood])
	if _flat(triage.global_position) <= SummerFaerieTriage.NEAR:
		return _fail("never got away from the table")
	_pass()

	_begin("died_alone", "he dies alone: no comforted; the grave is dug")
	if not await _until(func() -> bool: return WorldState.has_flag("fact.summer_faerie_buried"), 240.0):
		return _fail("he never died (blood %.1f)" % triage.state.blood)
	if not WorldState.has_flag("fact.summer_faerie_died_alone") or WorldState.has_flag("summer_faerie_comforted"):
		return _fail("expected died_alone without comforted")
	_pass()


## A table-local point in world space.
func _at(local: Vector3) -> Vector3:
	return triage.to_global(local)


func _at_supplies() -> void:
	await _walk_to(_at(Vector3(1.1, 0, -1.15)), 0.3)
	await _press(&"interact")
	await _wait(0.2)
	_note("supplies: rag %s, linen %s (%d left)" % [triage.state.has_rag, triage.state.linen_held, triage.state.linen_left])


## Walks to the wounds, presses E, stays until the step is done.
func _do_wound(what: String) -> bool:
	await _walk_to(_at(Vector3(-0.15, 0, -1.15)), 0.3)
	await _press(&"interact")
	await _wait(0.2)
	if triage.state.work.is_empty():
		_fail("%s: E at the wounds started nothing (target %s, at %s)" % [what, triage.target_at(feyre.global_position), _v(feyre.global_position)])
		return false
	if not await _until(func() -> bool: return triage.state.work.is_empty(), 5.0):
		_fail("%s never finished" % what)
		return false
	return true


func _until_wall(cond: Callable, wall_seconds: float) -> bool:
	var end := Time.get_unix_time_from_system() + wall_seconds
	while Time.get_unix_time_from_system() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())
