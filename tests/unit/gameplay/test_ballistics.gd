extends GutTest

const WOOD := preload("res://data/arrows/wood.tres")


func test_drag_shortens_range() -> void:
	var vacuum := Ballistics.simulate(48.0, 10.0, 0.0, Vector3.ZERO)
	var air := Ballistics.simulate(48.0, 10.0, WOOD.drag, Vector3.ZERO)
	assert_lt(air.distance, vacuum.distance * 0.9)
	assert_gt(air.distance, 40.0, "a full-draw arrow still flies far")


func test_crosswind_drifts_downwind() -> void:
	var r := Ballistics.simulate(40.0, 8.0, WOOD.drag, Vector3(5.0, 0, 0))
	assert_gt(r.drift, 0.15)
	var l := Ballistics.simulate(40.0, 8.0, WOOD.drag, Vector3(-5.0, 0, 0))
	assert_lt(l.drift, -0.15)


func test_headwind_shortens_tailwind_lengthens() -> void:
	var calm := Ballistics.simulate(40.0, 8.0, WOOD.drag, Vector3.ZERO)
	var head := Ballistics.simulate(40.0, 8.0, WOOD.drag, Vector3(0, 0, 6.0))
	var tail := Ballistics.simulate(40.0, 8.0, WOOD.drag, Vector3(0, 0, -6.0))
	assert_lt(head.distance, calm.distance)
	assert_gt(tail.distance, calm.distance)


func test_wet_fletching_flies_short() -> void:
	var dry := Ballistics.simulate(44.0, 8.0, WOOD.drag, Vector3.ZERO)
	var wet := Ballistics.simulate(44.0 * WOOD.wet_speed_multiplier, 8.0, WOOD.drag * WOOD.wet_drag_multiplier, Vector3.ZERO)
	assert_lt(wet.distance, dry.distance * 0.85)


func test_slow_time_only_while_drawing_aiming_with_stamina() -> void:
	assert_eq(BowController.slow_time_scale(true, true, 50.0, 0.8), BowController.SLOW_TIME_SCALE)
	assert_eq(BowController.slow_time_scale(true, false, 50.0, 0.8), 1.0)
	assert_eq(BowController.slow_time_scale(true, true, 0.0, 0.8), 1.0)
	assert_eq(BowController.slow_time_scale(true, true, 50.0, 0.1), 1.0)
	assert_eq(BowController.slow_time_scale(false, true, 50.0, 0.8), 1.0)
