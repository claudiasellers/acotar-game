# gate: needs:terrain
## Contract: Continue puts a mid-game player straight back where she was. The
## story is restored before the scene builds, so no earlier beat replays and the
## streamer never starts at the cottage; and it stays within a time budget.
extends GutTest

const GAME := "res://story/act1/act1_game.tscn"
const SLOT := "gut_continue"
## Headless, on a busy gate: about 7 to 11 s here, and it was 3 s more with the
## boot through the cottage. Real play adds the GPU's share on top.
const BUDGET_SECONDS := 45.0
const MANOR_BEDROOM := [20.15, 13.7, -63.54]


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()


func after_each() -> void:
	GameSettings.pending_load_slot = ""
	SaveSystem.delete_save(SLOT)
	WorldStreamer.track(null)
	WorldStreamer.unload_all()
	WorldState.clear()
	PhaseManager.phase_set = null
	PhaseManager.current_phase = &""


func _write_mid_game_save() -> void:
	var f := FileAccess.open("user://saves/%s.json" % SLOT, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"version": 2,
		"clock": {"day": 4, "time_of_day": 0.25},
		"world_state": {"flags": {"wolf_killed": true, "fact.wolf_skinned": true, "fact.wolf_spotted": true,
			"pelt_sold": true, "wall_crossed": true, "fact.manor_arrived": true}},
		"phase": {"phase": "p2_grounds", "phase_set": "res://data/phases/spring_court_phases.tres",
			"unlocked_regions": ["manor_estate", "manor_grounds", "manor_house"]},
		"world_deltas": {},
		"providers": {"player_placement": {"position": MANOR_BEDROOM, "yaw": 0.0}},
	}))
	f.close()


func _child_of(game: Node, type: Variant) -> Node:
	for child in game.get_children():
		if is_instance_of(child, type):
			return child
	return null


func test_continue_replays_no_earlier_beat_and_keeps_to_its_budget() -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.SAVE_DIR)
	_write_mid_game_save()
	GameSettings.pending_load_slot = SLOT
	var started := Time.get_ticks_msec()
	var game := (load(GAME) as PackedScene).instantiate()
	add_child_autofree(game)

	var feyre := game.get(&"feyre") as Feyre
	assert_eq(game.get_node(^"Act1Wayfinding").get(&"crows"), [] as Array[Node3D], "no hunt trail in the spring")
	assert_almost_eq(feyre.global_position.x, 20.15, 0.1, "she starts where she saved")
	assert_false(WorldStreamer.is_loaded(&"cottage"), "the boot never goes through the cottage")
	assert_does_not_have(WorldStreamer._pending.keys(), "hunting_forest", "nor the forest beside it")

	while not feyre.is_physics_processing() and (Time.get_ticks_msec() - started) / 1000.0 < BUDGET_SECONDS * 2.0:
		await wait_frames(1)
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	gut.p("Continue: %.1f s to control" % seconds)
	assert_lt(seconds, BUDGET_SECONDS, "Continue reaches control within its budget")
	assert_eq(PhaseManager.current_phase, &"p2_grounds")

	var journal := _child_of(game, GuideJournal) as GuideJournal
	assert_ne(String(journal.director.thread.id if journal.director.thread else &""), "hunt",
			"the opening need is long over")
	assert_eq(journal.director.tick(60.0, 0.0, false, true), {}, "no opening thought on Continue")
	assert_false(journal.showing)
	var panel := _child_of(game, SettingsPanel) as SettingsPanel
	assert_false(panel.get(&"_hint").visible, "the controls are taught on a new game only")
	var veil: Variant = game.get(&"veil")
	assert_not_null(veil, "something on screen while it loads")
	if veil != null:
		await wait_seconds(0.25)  # after a long frame, physics frames bunch up
		assert_gt(veil.seconds_to_control, 0.0, "and it lifts")
