# gate: needs:terrain
## T144 contract: play a story, Save & Title, then New Game over that story's
## slot. Leaving the game while regions are still streaming in raises no
## engine error (nothing lands in the dead world, nothing polls it), the old
## story is gone from the slot, the fresh program is started on this project
## with the slot chosen, and a game started after the teardown reaches control.
extends GutTest

const GAME := "res://story/act1/act1_game.tscn"
const TITLE_SCENE := "res://ui/title/title_screen.tscn"
const SLOT := "slot_2"
const MANOR_BEDROOM := [20.15, 13.7, -63.54]
const CONTROL_SECONDS := 90.0


func _reset() -> void:
	GameSettings.pending_load_slot = ""
	WorldStreamer.track(null)
	WorldStreamer.unload_all()
	WorldState.clear()
	Gameplay.reset()
	StoryControl.release()
	PhaseManager.phase_set = null
	PhaseManager.current_phase = &""


func before_each() -> void:
	_reset()


func after_each() -> void:
	SaveSystem.delete_save(SLOT)
	SaveSystem.active_slot = "slot_0"
	SaveSystem.play_seconds = 0.0
	_reset()


func _write_mid_game_save() -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.SAVE_DIR)
	var f := FileAccess.open("%s/%s.json" % [SaveSystem.SAVE_DIR, SLOT], FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"version": 2, "saved_at": 2000, "play_seconds": 600,
		"clock": {"day": 4, "time_of_day": 0.25},
		"world_state": {"flags": {"wolf_killed": true, "fact.wolf_skinned": true, "fact.wolf_spotted": true,
			"pelt_sold": true, "wall_crossed": true, "fact.manor_arrived": true}},
		"phase": {"phase": "p2_grounds", "phase_set": "res://data/phases/spring_court_phases.tres",
			"unlocked_regions": ["manor_estate", "manor_grounds", "manor_house"]},
		"world_deltas": {},
		"providers": {"player_placement": {"position": MANOR_BEDROOM, "yaw": 0.0}},
	}))
	f.close()


func _until_control(game: Node) -> Feyre:
	var feyre := game.get(&"feyre") as Feyre
	var started := Time.get_ticks_msec()
	while not feyre.is_physics_processing() and (Time.get_ticks_msec() - started) / 1000.0 < CONTROL_SECONDS:
		await wait_process_frames(1)
	return feyre


func test_new_game_over_a_played_story() -> void:
	# Continue the story in the slot, to control.
	_write_mid_game_save()
	GameSettings.pending_load_slot = SLOT
	var game := (load(GAME) as PackedScene).instantiate()
	add_child(game)
	var feyre: Feyre = await _until_control(game)
	assert_true(feyre.is_physics_processing(), "Continue reaches control")
	GameSettings.pending_load_slot = ""

	# Save & Title, as change_scene does it: out of the tree at once, freed a
	# little later, with the neighbours still streaming in behind her.
	assert_eq(SaveSystem.save_game(SLOT), OK)
	WorldStreamer.update_for(Vector3(MANOR_BEDROOM[0], MANOR_BEDROOM[1], MANOR_BEDROOM[2]))
	var in_flight := WorldStreamer._pending.size() + WorldStreamer._queue.size()
	remove_child(game)
	await wait_process_frames(3)
	game.free()
	var settle := Time.get_ticks_msec()
	while Time.get_ticks_msec() - settle < 4000:
		await wait_process_frames(1)
	gut.p("loads in flight when she left: %d" % in_flight)
	assert_eq(WorldStreamer.loaded_ids(), PackedStringArray(), "the dead world's regions are forgotten")
	assert_true(WorldStreamer._pending.is_empty() and WorldStreamer._queue.is_empty(), "and nothing more streams into it")
	assert_false(SaveSystem.can_autosave(), "no game is up to save")

	# New Game, over the story in the slot.
	var title := (load(TITLE_SCENE) as PackedScene).instantiate() as Control
	var relaunched: Array[PackedStringArray] = []
	title.set(&"relaunch", func(args: PackedStringArray) -> void: relaunched.append(args))
	add_child_autofree(title)
	await wait_process_frames(1)  # the menu takes its focus, as a player would see it
	title.call(&"_on_new_game")
	await wait_process_frames(1)
	var slots := title.get_node(^"Slots") as TitleSlots
	(slots.get_node(NodePath("%s/Pick" % SLOT)) as Button).pressed.emit()
	assert_eq(slots.asking, SLOT, "a used slot asks first")
	await wait_process_frames(1)  # Keep takes the focus before she answers
	title.set(&"_leaving", true)  # the wash would end in _load_game; call it here
	(slots.get_node(^"Yes") as Button).pressed.emit()
	assert_false(SaveSystem.has_save(SLOT), "the old story and its backup are gone")
	assert_eq(SaveSystem.active_slot, SLOT)
	title.call(&"_load_game")
	assert_eq(relaunched.size(), 1, "a game was played, so a fresh program starts")
	if relaunched.size() == 1:
		var args := relaunched[0]
		var at := args.find("--path")
		assert_gt(at, -1, "the fresh program is told where the project is")
		if at > -1:
			assert_eq(args[at + 1].simplify_path(), ProjectSettings.globalize_path("res://").simplify_path())
		assert_has(args, "--new-story=%s" % SLOT, "and which slot the new story is in")

	# The fresh program's new game: on this streamer, after that teardown, it
	# still gets to control (in the same program, the harder case).
	_reset()
	var fresh := (load(GAME) as PackedScene).instantiate()
	add_child_autofree(fresh)
	var her: Feyre = await _until_control(fresh)
	assert_true(her.is_physics_processing(), "the new game reaches control")
	assert_eq(PhaseManager.current_phase, &"p0_winter", "and it is the start of the story")
