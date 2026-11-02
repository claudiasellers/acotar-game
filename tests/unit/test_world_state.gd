extends GutTest


func before_each() -> void:
	WorldState.clear()


func test_set_and_read_flag() -> void:
	WorldState.set_flag("wolf_killed")
	assert_true(WorldState.has_flag("wolf_killed"))
	assert_false(WorldState.has_flag("suriel_bound"))


func test_false_and_zero_values_are_not_set() -> void:
	WorldState.set_flag("door_open", false)
	WorldState.set_flag("arrows_left", 0)
	assert_false(WorldState.has_flag("door_open"))
	assert_false(WorldState.has_flag("arrows_left"))
	assert_eq(WorldState.get_flag("arrows_left"), 0)


func test_change_emits_once() -> void:
	watch_signals(EventBus)
	WorldState.set_flag("wolf_killed")
	WorldState.set_flag("wolf_killed")
	assert_signal_emit_count(EventBus, "flag_changed", 1)


func test_raise_deed_announces_the_deed() -> void:
	watch_signals(EventBus)
	WorldState.raise_deed("suriel_bound")
	assert_true(WorldState.has_flag("suriel_bound"))
	assert_signal_emitted_with_parameters(EventBus, "deed_performed", ["suriel_bound"])


func test_dict_round_trip() -> void:
	WorldState.set_flag("wolf_killed")
	WorldState.set_flag("pelts_sold", 3)
	var saved := WorldState.to_dict()
	WorldState.clear()
	WorldState.from_dict(saved)
	assert_true(WorldState.has_flag("wolf_killed"))
	assert_eq(WorldState.get_flag("pelts_sold"), 3)


func test_string_valued_facts_are_truthy_when_not_empty() -> void:
	WorldState.clear()
	WorldState.set_flag("fact.test.kept_id", "snowy_forest")
	WorldState.set_flag("fact.test.kept_name", &"snowy_forest")
	WorldState.set_flag("fact.test.empty_id", "")
	WorldState.set_flag("fact.test.empty_name", &"")
	WorldState.set_flag("fact.test.quality", 0.0)
	assert_true(WorldState.has_flag("fact.test.kept_id"), "a String id")
	assert_true(WorldState.has_flag("fact.test.kept_name"), "a StringName id")
	assert_false(WorldState.has_flag("fact.test.empty_id"))
	assert_false(WorldState.has_flag("fact.test.empty_name"))
	assert_false(WorldState.has_flag("fact.test.quality"))
	assert_false(WorldState.has_flag("fact.test.never_set"))
	WorldState.clear()
