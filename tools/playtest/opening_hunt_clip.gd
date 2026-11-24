## Proof clip for the opening hunt (plans/onboarding/plan.md): from a new
## game she walks down the doe trail to her empty snare, checks it, nocks at
## the rabbit beyond it (ears up), looses (it bolts), and fetches her arrow.
## Headless it plays it and reports the prompts, the rabbit's states and her
## quiver; with a GPU it also writes frames, as wolf_hunt_clip.gd does:
##   shot opening res://tools/playtest/opening_hunt_clip.tscn -- --out={out}/report.json
extends "res://tools/playtest/wolf_hunt_clip.gd"


func _play() -> void:
	if not await _spawn_in():
		return
	var hunt := get_tree().get_first_node_in_group(OpeningHunt.GROUP) as OpeningHunt
	var keys: KeyPrompts = null
	for child in game.get_children():
		if child is KeyPrompts:
			keys = child
	if hunt == null or keys == null:
		return _fail("no OpeningHunt or KeyPrompts in the game")
	# A new player: nothing taught yet, whatever an earlier run left behind.
	keys.taught.clear()
	var cfg := ConfigFile.new()
	cfg.load(keys.settings_path)
	if cfg.has_section(KeyPrompts.SECTION):
		cfg.erase_section(KeyPrompts.SECTION)
		cfg.save(keys.settings_path)
	_t0 = Time.get_ticks_msec()
	_note("quiver at the start: %s; key hints %s" % [_quiver(), GameSettings.get_value(&"key_hints")])
	if Gameplay.inventory.arrow_count() != 3 or Gameplay.inventory.count(&"arrow_ash") != 1:
		return _fail("she doesn't start with two plain arrows and the ash: %s" % _quiver())

	_begin("snare", "walk down the doe trail to her snare; the key shows in reach; it is empty")
	var spot := OpeningHunt.snare_spot()
	var near := Act1Wayfinding.trail_obstacles(PackedVector2Array([spot, OpeningHunt.rabbit_spot()]))
	_note("snare %s with %.1f m of open ground round it; rabbit %.1f m on, %.1f m clear of her line, %.2f m over the snow" % [spot,
		OpeningHunt._open_round(spot, near), spot.distance_to(OpeningHunt.rabbit_spot()),
		OpeningHunt._sight_open(spot, OpeningHunt.rabbit_spot(), near),
		OpeningHunt._seen_over_snow(spot, OpeningHunt.rabbit_spot())])
	var seen: Array = []
	var watch := func() -> void:
		if keys.current != &"" and not seen.has(keys.current):
			seen.append(keys.current)
			_note("%5.1f s  prompt: %s %s" % [_secs(), keys.current, KeyPrompts.row(keys.current)])
	var journal := get_tree().get_first_node_in_group(GuideSettings.GROUP) as GuideJournal
	var thoughts: Array = []
	var think := func() -> void:
		if journal and journal.showing and journal.shown_thread and not thoughts.has(journal.shown_thread.id):
			thoughts.append(journal.shown_thread.id)
			_note("%5.1f s  she thinks: %s" % [_secs(), journal.line])
	get_tree().process_frame.connect(think)
	get_tree().process_frame.connect(watch)
	await _walk_to(_on_ground(spot), 25.0, Callable(), 240.0)
	_rec = true
	if not await _until(func() -> bool: return hunt.snare != null, 5.0):
		return _fail("the snare was never built; she is %.0f m from its spot" % _flat(_on_ground(spot)))
	await _walk_to(hunt.snare.global_position, 1.5, Callable(), 40.0)
	await _hold_on(func() -> Node3D: return hunt.snare, Callable(), 1.5)
	_note("%5.1f s  at the snare (%.1f m): prompt %s" % [_secs(), _flat(hunt.snare.global_position), keys.current])
	if keys.current != &"snare":
		return _fail("no snare prompt beside the snare (prompt '%s')" % keys.current)
	await _press(&"interact")
	if not await _until(func() -> bool: return hunt.snare_checked and hunt.rabbit != null, 2.0):
		return _fail("E on the snare did nothing")
	_pass()

	_begin("rabbit", "a rabbit beyond the snare: ears up when she nocks, gone when she looses")
	var rabbit := hunt.rabbit
	_note("%5.1f s  rabbit %.0f m off, state %s, awareness %.2f" % [_secs(), _flat(rabbit.global_position),
		rabbit.state, rabbit.senses.awareness])
	await _hold_on(func() -> Node3D: return rabbit, Callable(), 2.5)
	if rabbit.state == Prey.State.FLEE:
		return _fail("the rabbit bolted before she had nocked")
	var states: Array = []
	var note_state := func() -> void:
		if is_instance_valid(rabbit) and (states.is_empty() or states.back() != rabbit.state):
			states.append(rabbit.state)
			_note("%5.1f s  rabbit state %s, awareness %.2f, nocked %s" % [_secs(), rabbit.state,
				rabbit.senses.awareness, feyre.bow_controller.is_nocked])
	get_tree().physics_frame.connect(note_state)
	await _shoot_at(rabbit)
	await _until(func() -> bool: return hunt.rabbit_done, OpeningHunt.GONE_SECONDS + 3.0)
	get_tree().physics_frame.disconnect(note_state)
	_note("%5.1f s  rabbit gone %s; states %s; quiver %s" % [_secs(), hunt.rabbit_done, states, _quiver()])
	if not states.has(Prey.State.FLEE) or not hunt.rabbit_done:
		return _fail("the rabbit never bolted and left")
	if WorldState.has_flag("rabbit_killed") or Gameplay.inventory.count(&"meat_raw") > 0:
		return _fail("something was killed before the doe")
	_pass()

	_begin("retrieve", "her arrow is where it fell; the key shows beside it; she has three again")
	var arrows := get_tree().get_nodes_in_group(Arrow.STUCK_GROUP)
	if arrows.is_empty():
		return _fail("no arrow left in the world to fetch")
	var id := StringName(arrows[0].get(&"arrow_id"))
	await _walk_to((arrows[0] as Node3D).global_position, 1.5, Callable(), 60.0)
	await _wait(0.5)
	_note("%5.1f s  beside the %s arrow: prompt %s" % [_secs(), id, keys.current])
	var prompted := keys.current == &"retrieve"
	await _press(&"interact")
	await _wait(0.5)
	if Gameplay.inventory.arrow_count() < 3:
		await _retrieve_arrow(id)
	# A bot is quicker than her thoughts: the snare's is still up when the rabbit goes.
	await _until(func() -> bool: return thoughts.has(&"onboarding_rabbit_gone"), 15.0)
	await _wait(2.0)
	get_tree().process_frame.disconnect(watch)
	get_tree().process_frame.disconnect(think)
	_rec = false
	_note("%5.1f s  quiver %s; prompts seen %s; taught %s; lines %s; frames %d" % [_secs(), _quiver(), seen,
		keys.taught.keys().filter(func(k: StringName) -> bool: return keys.taught[k]), spoken, _rec_count])
	if journal and journal.mode == GuideSettings.Mode.AUTO:
		for thought: StringName in [&"onboarding_snare", &"onboarding_rabbit_gone"]:
			if not thoughts.has(thought):
				return _fail("she never thought %s (thoughts %s)" % [thought, thoughts])
	if not prompted:
		return _fail("no pick-up prompt beside her arrow")
	if Gameplay.inventory.arrow_count() != 3:
		return _fail("she didn't get her arrow back: %s" % _quiver())
	_pass()


func _on_ground(p: Vector2) -> Vector3:
	return Vector3(p.x, WorldHeight.height_at(p.x, p.y), p.y)
