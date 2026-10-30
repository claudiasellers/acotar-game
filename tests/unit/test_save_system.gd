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
