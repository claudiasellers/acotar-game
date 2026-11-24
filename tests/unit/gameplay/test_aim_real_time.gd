## Focus slows the world, not her aim (archery gap report, gap 1): on a pad
## the look, the aim camera's ease and her turn with the camera all take the
## same real time inside the hush as outside it. The mouse is event-based and
## never slowed.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")
const FOCUS := 0.4

var hill: Node3D
var feyre: Feyre


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	StoryControl.release()
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	await wait_physics_frames(10)


func after_each() -> void:
	for action in [&"aim", &"look_right"]:
		Input.action_release(action)
	TimeScale.reset()


## Runs frames for `seconds` of the wall clock.
func _real(seconds: float) -> void:
	var until := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < until:
		await get_tree().process_frame


func _yaw_turned_in(seconds: float, scale: float) -> float:
	if scale < 1.0:
		TimeScale.request(&"test", scale)
	var before := feyre.camera.global_rotation.y
	Input.action_press(&"look_right", 1.0)
	await _real(seconds)
	Input.action_release(&"look_right")
	TimeScale.reset()
	return absf(angle_difference(before, feyre.camera.global_rotation.y))


func test_the_stick_turns_the_camera_as_far_in_the_hush_as_out_of_it() -> void:
	Input.action_press(&"aim")
	await _real(0.5)
	var plain := await _yaw_turned_in(0.4, 1.0)
	var hushed := await _yaw_turned_in(0.4, FOCUS)
	assert_gt(plain, 0.2, "the stick turns the camera")
	assert_almost_eq(hushed / plain, 1.0, 0.12, "turned %.3f rad at 1.0 and %.3f at %.1f" % [plain, hushed, FOCUS])


func _arm_after(seconds: float, scale: float) -> float:
	Input.action_release(&"aim")
	await _real(1.0)
	if scale < 1.0:
		TimeScale.request(&"test", scale)
	Input.action_press(&"aim")
	await _real(seconds)
	var arm := (feyre.camera.get_parent() as SpringArm3D).spring_length
	TimeScale.reset()
	return arm


func test_the_aim_camera_pulls_in_as_fast_in_the_hush() -> void:
	var plain := await _arm_after(0.25, 1.0)
	var hushed := await _arm_after(0.25, FOCUS)
	assert_lt(plain, 2.1, "a quarter second in, the arm is most of the way to 1.7 m")
	assert_almost_eq(hushed, plain, 0.15, "arm at %.2f m in the hush, %.2f m out of it" % [hushed, plain])


func _model_lag_after(seconds: float, scale: float) -> float:
	Input.action_press(&"aim")
	await _real(0.6)
	if scale < 1.0:
		TimeScale.request(&"test", scale)
	feyre.nudge_camera(1.2, 0.0)
	await _real(seconds)
	var lag := absf(angle_difference(feyre.model.rotation.y, feyre.camera_control.rig.rotation.y))
	TimeScale.reset()
	feyre.nudge_camera(-1.2, 0.0)
	await _real(0.5)
	return lag


func test_she_turns_with_the_camera_as_fast_in_the_hush() -> void:
	var plain := await _model_lag_after(0.12, 1.0)
	var hushed := await _model_lag_after(0.12, FOCUS)
	assert_lt(plain, 0.5, "she has mostly caught the camera up")
	assert_almost_eq(hushed, plain, 0.12, "lag %.2f rad in the hush, %.2f out of it" % [hushed, plain])


func test_every_real_time_clock_goes_through_time_scale() -> void:
	for path in ["res://characters/feyre/feyre.gd", "res://characters/feyre/camera/feyre_camera.gd",
			"res://characters/feyre/movement/ground_motor.gd", "res://systems/bow/bow_controller.gd"]:
		var source := FileAccess.get_file_as_string(path)
		assert_true(source.contains("TimeScale.real("), "%s reads real seconds" % path)
		assert_false(source.contains("maxf(Engine.time_scale"), "%s has no second way to work it out" % path)
