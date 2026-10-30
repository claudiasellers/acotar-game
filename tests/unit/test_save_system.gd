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
