extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SLOT := "gut_test_slot"


func before_each() -> void:
	WorldState.clear()
	Clock.paused = true
	PhaseManager.start(TEST_SET)


func after_each() -> void:
	SaveSystem.delete_save(SLOT)
	Clock.paused = false


func test_file_round_trip_restores_everything() -> void:
	WorldState.raise_deed("fact.test.reached_summit")
	WorldState.set_flag("arrows_crafted", 4)
	Clock.from_dict({"time_of_day": 0.62, "day": 3})
	assert_eq(SaveSystem.save_game(SLOT), OK)

	WorldState.clear()
	PhaseManager.start(TEST_SET)
	Clock.from_dict({"time_of_day": 0.1, "day": 1})

	assert_eq(SaveSystem.load_game(SLOT), OK)
	assert_true(WorldState.has_flag("fact.test.reached_summit"))
	assert_eq(int(WorldState.get_flag("arrows_crafted")), 4)
	assert_eq(PhaseManager.current_phase, &"m0_summit")
	assert_true(PhaseManager.is_region_unlocked(&"test_meadow"))
	assert_eq(Clock.day, 3)
	assert_almost_eq(Clock.time_of_day, 0.62, 0.0001)


func test_missing_slot_reports_not_found() -> void:
	assert_eq(SaveSystem.load_game("no_such_slot"), ERR_FILE_NOT_FOUND)


class FakeProvider:
	extends RefCounted
	var state: Dictionary = {}

	func save_state() -> Dictionary:
		return state.duplicate(true)

	func load_state(data: Dictionary) -> void:
		state = data.duplicate(true)


func test_providers_and_world_deltas_round_trip() -> void:
	WorldDeltas.clear()
	var inventory := FakeProvider.new()
	inventory.state = {"arrow_ash": 1, "obj_wolf_pelt": 1}
	SaveSystem.register_provider("inventory", inventory)
	WorldDeltas.mark_picked(&"hunting_forest", "scatter_a:12", 2.0)
	WorldDeltas.set_container("cottage_chest", {"wardrobe_hunting_cloak": 1})
	WorldDeltas.set_region_value(&"cottage", "door", "broken")
	assert_eq(SaveSystem.save_game(SLOT), OK)

	inventory.state = {}
	WorldDeltas.clear()
	assert_eq(SaveSystem.load_game(SLOT), OK)
	assert_eq(int(inventory.state.get("arrow_ash", 0)), 1)
	assert_true(WorldDeltas.is_picked(&"hunting_forest", "scatter_a:12"))
	assert_eq(int(WorldDeltas.get_container("cottage_chest").get("wardrobe_hunting_cloak", 0)), 1)
	assert_eq(WorldDeltas.get_region_value(&"cottage", "door"), "broken")
	SaveSystem.unregister_provider("inventory")
	WorldDeltas.clear()


func _path() -> String:
	return "%s/%s.json" % [SaveSystem.SAVE_DIR, SLOT]


func _overwrite(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_a_save_that_will_not_read_falls_back_to_the_last_good_one() -> void:
	WorldState.set_flag("first", true)
	assert_eq(SaveSystem.save_game(SLOT), OK)
	WorldState.set_flag("second", true)
	assert_eq(SaveSystem.save_game(SLOT), OK)
	assert_false(FileAccess.file_exists(_path() + ".part"), "nothing left half-written")
	_overwrite(_path(), "{ half a sav")
	WorldState.clear()
	assert_eq(SaveSystem.load_game(SLOT), OK)
	assert_true(WorldState.has_flag("first"))
	assert_false(WorldState.has_flag("second"), "the backup is the save before")


func test_unreadable_and_newer_saves_are_refused() -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.SAVE_DIR)
	_overwrite(_path(), "not json")
	assert_eq(SaveSystem.load_game(SLOT), ERR_PARSE_ERROR)
	_overwrite(_path(), JSON.stringify({"version": SaveSystem.FORMAT_VERSION + 1}))
	assert_eq(SaveSystem.load_game(SLOT), ERR_FILE_UNRECOGNIZED)


func test_begin_load_restores_the_story_and_leaves_providers_for_finish_load() -> void:
	var provider := FakeProvider.new()
	provider.state = {"spot": "bed"}
	SaveSystem.register_provider("gut_two_step", provider)
	WorldState.set_flag("wolf_killed", true)
	assert_eq(SaveSystem.save_game(SLOT), OK)
	WorldState.clear()
	provider.state = {}
	assert_eq(SaveSystem.begin_load(SLOT), OK)
	assert_true(WorldState.has_flag("wolf_killed"), "story first")
	assert_eq(provider.state, {}, "providers wait")
	assert_eq(SaveSystem.loading_state("gut_two_step"), {"spot": "bed"}, "but what's saved can be read")
	watch_signals(EventBus)
	SaveSystem.finish_load(SLOT)
	assert_eq(provider.state, {"spot": "bed"})
	assert_signal_emitted(EventBus, "game_loaded")
	SaveSystem.unregister_provider("gut_two_step")


func test_a_loaded_game_keeps_its_thoughts_seen() -> void:
	var journal := GuideJournal.new()
	add_child_autofree(journal)
	var need := journal.director.thread
	journal.director.shown_tier = 1
	assert_eq(SaveSystem.save_game(SLOT), OK)
	journal.director.shown_tier = -1
	journal.director.announced = false
	assert_eq(SaveSystem.load_game(SLOT), OK)
	assert_eq(journal.director.thread, need)
	assert_eq(journal.director.shown_tier, 1, "the tier she'd reached")
	assert_eq(journal.director.tick(60.0, 0.0, false, true), {}, "nothing opens the session")


func test_landmark_thoughts_already_had_stay_had() -> void:
	var thoughts := Act1LandmarkThoughts.new()
	add_child_autofree(thoughts)
	thoughts.reached[&"bark"] = true
	assert_eq(SaveSystem.save_game(SLOT), OK)
	thoughts.reached.clear()
	assert_eq(SaveSystem.load_game(SLOT), OK)
	assert_true(thoughts.reached.has(&"bark"))


func test_a_load_makes_its_slot_the_one_saved_to_and_carries_play_time() -> void:
	SaveSystem.play_seconds = 754.0
	assert_eq(SaveSystem.save_game(SLOT), OK)
	SaveSystem.begin_new("slot_2")
	assert_eq(SaveSystem.play_seconds, 0.0, "a new story starts its own clock")
	assert_eq(SaveSystem.load_game(SLOT), OK)
	assert_eq(SaveSystem.active_slot, SLOT, "Save & Title and autosave now write here")
	assert_eq(int(SaveSystem.play_seconds), 754)
	SaveSystem.active_slot = "slot_0"
	SaveSystem.play_seconds = 0.0


func test_slot_info_names_where_the_story_is() -> void:
	assert_eq(SaveSystem.slot_info(SLOT), {}, "an empty slot")
	Clock.from_dict({"time_of_day": 0.4, "day": 5})
	SaveSystem.play_seconds = 3725.0
	assert_eq(SaveSystem.save_game(SLOT), OK)
	var info := SaveSystem.slot_info(SLOT)
	assert_true(info.readable)
	assert_eq(info.phase, "Explore the hill")
	assert_eq(info.day, 5)
	assert_eq(info.play_seconds, 3725)
	assert_almost_eq(float(info.saved_at), Time.get_unix_time_from_system(), 5.0)
	assert_string_starts_with(TitleSlots.details(info), "Day 5  ·  1 h 2 min played  ·  saved ")
	SaveSystem.play_seconds = 0.0
