extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")


func before_each() -> void:
	WorldState.clear()
	PhaseManager.start(TEST_SET)


func test_starts_on_first_phase_with_its_regions() -> void:
	assert_eq(PhaseManager.current_phase, &"m0_explore")
	assert_true(PhaseManager.is_region_unlocked(&"test_hill"))
	assert_false(PhaseManager.is_region_unlocked(&"test_meadow"))


func test_deed_advances_phase_and_unlocks_region() -> void:
	watch_signals(EventBus)
	WorldState.raise_deed("fact.test.reached_summit")
	assert_eq(PhaseManager.current_phase, &"m0_summit")
	assert_true(PhaseManager.is_region_unlocked(&"test_meadow"))
	assert_signal_emitted_with_parameters(EventBus, "region_unlocked", [&"test_meadow"])


func test_unrelated_flag_does_not_advance() -> void:
	WorldState.raise_deed("fact.test.target_hit")
	assert_eq(PhaseManager.current_phase, &"m0_explore")


func test_flags_already_met_chain_through_phases() -> void:
	WorldState.raise_deed("fact.test.target_hit")
	WorldState.raise_deed("fact.test.reached_summit")
	assert_eq(PhaseManager.current_phase, &"m0_marksman")


func test_unlocks_are_permanent() -> void:
	WorldState.raise_deed("fact.test.reached_summit")
	WorldState.raise_deed("fact.test.target_hit")
	assert_true(PhaseManager.is_region_unlocked(&"test_hill"))
	assert_true(PhaseManager.is_region_unlocked(&"test_meadow"))


func test_dict_round_trip() -> void:
	WorldState.raise_deed("fact.test.reached_summit")
	var saved := PhaseManager.to_dict()
	PhaseManager.start(TEST_SET)
	PhaseManager.from_dict(saved)
	assert_eq(PhaseManager.current_phase, &"m0_summit")
	assert_true(PhaseManager.is_region_unlocked(&"test_meadow"))
