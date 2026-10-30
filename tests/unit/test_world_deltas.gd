extends GutTest


func before_each() -> void:
	WorldDeltas.clear()
	Clock.paused = true
	Clock.from_dict({"time_of_day": 0.5, "day": 1})


func after_each() -> void:
	WorldDeltas.clear()
	Clock.paused = false


func test_picked_forage_respawns_after_its_time() -> void:
	WorldDeltas.mark_picked(&"hunting_forest", "rosehip:3", 1.0)
	assert_true(WorldDeltas.is_picked(&"hunting_forest", "rosehip:3"))
	Clock.advance(Clock.DAY_LENGTH_SECONDS * 0.9)
	assert_true(WorldDeltas.is_picked(&"hunting_forest", "rosehip:3"))
	Clock.advance(Clock.DAY_LENGTH_SECONDS * 0.2)
	assert_false(WorldDeltas.is_picked(&"hunting_forest", "rosehip:3"))


func test_zero_respawn_means_gone_for_good() -> void:
	WorldDeltas.mark_picked(&"cottage", "ash_sapling:0", 0.0)
	Clock.advance(Clock.DAY_LENGTH_SECONDS * 30.0)
	assert_true(WorldDeltas.is_picked(&"cottage", "ash_sapling:0"))
	assert_eq(Array(WorldDeltas.picked_in(&"cottage")), ["ash_sapling:0"])


func test_containers_are_copied_not_shared() -> void:
	var contents := {"ing_salt": 2}
	WorldDeltas.set_container("larder", contents)
	contents["ing_salt"] = 99
	assert_eq(WorldDeltas.get_container("larder")["ing_salt"], 2)
