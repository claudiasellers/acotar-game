## Contract: the game saves itself on a phase change and on sleeping, and never
## when a save would be half a game: mid-load, mid-cutscene, or with no game up.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SLOT := "gut_autosave"
const PATH := "user://saves/gut_autosave.json"

var _placement := FakePlacement.new()


class FakePlacement:
	extends RefCounted
	var valid := true

	func save_state() -> Dictionary:
		return {"position": [1.0, 2.0, 3.0]} if valid else {}

	func load_state(_d: Dictionary) -> void:
		pass


func before_each() -> void:
	WorldState.clear()
	Clock.paused = true
	StoryControl.release()
	PhaseManager.start(TEST_SET)
	SaveSystem.delete_save(SLOT)
	SaveSystem.active_slot = SLOT
	_placement = FakePlacement.new()
	SaveSystem.register_provider(SaveSystem.PLACEMENT_KEY, _placement)
	SaveSystem._autosave_due = false


func after_each() -> void:
	SaveSystem.unregister_provider(SaveSystem.PLACEMENT_KEY)
	SaveSystem.active_slot = "slot_0"
	SaveSystem._autosave_due = false
	SaveSystem._loading = {}
	SaveSystem._open_spaces.clear()
	SaveSystem.delete_save(SLOT)
	StoryControl.release()
	Clock.paused = false


func _advance_phase() -> void:
	PhaseManager._enter_phase(&"m0_summit")


func test_a_phase_change_saves_and_keeps_the_last_good_save_as_backup() -> void:
	_advance_phase()
	assert_true(FileAccess.file_exists(PATH), "the phase change wrote a save")
	var first := FileAccess.get_file_as_string(PATH)
	WorldState.set_flag("later", true)
	assert_true(SaveSystem.autosave())
	assert_true(FileAccess.file_exists(PATH + ".bak"), "the previous save stays as the backup")
	assert_ne(FileAccess.get_file_as_string(PATH), first)


func test_sleeping_saves() -> void:
	assert_true(SaveSystem.autosave())
	assert_true(FileAccess.file_exists(PATH))


func test_no_autosave_during_a_load() -> void:
	SaveSystem._loading = {"version": 2}
	_advance_phase()
	assert_false(FileAccess.file_exists(PATH), "nothing is written between begin_load and finish_load")


func test_a_save_waits_out_a_cutscene_then_happens_once_it_ends() -> void:
	StoryControl.set_mode(StoryControl.Mode.NONE)
	_advance_phase()
	assert_false(FileAccess.file_exists(PATH), "not mid-step")
	StoryControl.release()
	assert_true(FileAccess.file_exists(PATH), "it saves when control returns")


func test_a_save_waits_out_an_open_scene_space() -> void:
	EventBus.scene_space_started.emit(&"film_x")
	_advance_phase()
	assert_false(FileAccess.file_exists(PATH))
	EventBus.scene_space_finished.emit(&"film_x")
	assert_true(FileAccess.file_exists(PATH))


func test_no_autosave_without_a_game_or_without_feyre_placed() -> void:
	SaveSystem.unregister_provider(SaveSystem.PLACEMENT_KEY)
	_advance_phase()
	assert_false(FileAccess.file_exists(PATH), "no game scene, nothing to save")
	SaveSystem.register_provider(SaveSystem.PLACEMENT_KEY, _placement)
	_placement.valid = false
	SaveSystem._autosave_due = false
	assert_false(SaveSystem.autosave(), "a freed player would save without her place")
	assert_false(FileAccess.file_exists(PATH))


func test_finishing_a_load_is_not_news() -> void:
	SaveSystem._loading = {"version": 2}
	_advance_phase()
	SaveSystem.finish_load(SLOT)
	assert_false(FileAccess.file_exists(PATH), "Continue never rewrites the save it just read")


func test_the_hitch_is_small() -> void:
	var t := Time.get_ticks_usec()
	for i in 20:
		SaveSystem.autosave()
	var ms := (Time.get_ticks_usec() - t) / 20000.0
	gut.p("autosave: %.2f ms each (test state)" % ms)
	assert_lt(ms, 16.0, "well inside one frame")
