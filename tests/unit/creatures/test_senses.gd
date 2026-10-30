extends GutTest


func test_target_ahead_in_range_is_seen() -> void:
	assert_true(CreatureSenses.in_sight_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -10), 120.0, 40.0))


func test_target_behind_is_not_seen() -> void:
	assert_false(CreatureSenses.in_sight_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, 10), 250.0, 40.0))


func test_target_beyond_range_is_not_seen() -> void:
	assert_false(CreatureSenses.in_sight_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -50), 120.0, 40.0))


func test_hearing_falls_off_and_scales_with_loudness() -> void:
	var near := CreatureSenses.hearing_strength(5.0, 1.0, 40.0)
	var far := CreatureSenses.hearing_strength(30.0, 1.0, 40.0)
	var quiet := CreatureSenses.hearing_strength(30.0, 0.5, 40.0)
	assert_gt(near, far)
	assert_eq(quiet, 0.0, "a quiet sound at 30 m is out of a 40 m * 0.5 earshot")


func test_scent_carries_downwind_only() -> void:
	var wind := Vector3(3.0, 0.0, 0.0)
	var source := Vector3.ZERO
	var downwind := CreatureSenses.scent_strength(source, Vector3(30, 0, 0), wind, 70.0)
	var upwind := CreatureSenses.scent_strength(source, Vector3(-30, 0, 0), wind, 70.0)
	var crosswind := CreatureSenses.scent_strength(source, Vector3(0, 0, 30), wind, 70.0)
	assert_gt(downwind, 0.3)
	assert_eq(upwind, 0.0)
	assert_eq(crosswind, 0.0)


func test_calm_air_pools_scent_nearby() -> void:
	assert_gt(CreatureSenses.scent_strength(Vector3.ZERO, Vector3(5, 0, 0), Vector3.ZERO, 70.0), 0.5)
	assert_eq(CreatureSenses.scent_strength(Vector3.ZERO, Vector3(30, 0, 0), Vector3.ZERO, 70.0), 0.0)


func test_noise_raises_awareness_of_creatures_in_earshot() -> void:
	var near := CreatureSenses.new()
	var far := CreatureSenses.new()
	add_child_autofree(near)
	add_child_autofree(far)
	far.global_position = Vector3(200, 0, 0)
	watch_signals(near)
	CreatureSenses.emit_noise(get_tree(), Vector3(3, 0, 0), 1.0)
	assert_gt(near.awareness, 0.5)
	assert_eq(far.awareness, 0.0)
	assert_signal_emitted(near, "sensed")


func test_awareness_decays() -> void:
	var s := CreatureSenses.new()
	add_child_autofree(s)
	s.stimulate(&"sound", Vector3.ZERO, 0.5)
	s._physics_process(1.0)
	assert_almost_eq(s.awareness, 0.5 - s.decay, 0.001)
