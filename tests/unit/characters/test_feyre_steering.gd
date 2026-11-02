## Contract: camera-relative steering as shipped third-person games do it. The
## player's own look steers; camera moves the player didn't make (follow-behind,
## story glances, recentre, nudges) don't; pressing a new direction takes the
## camera's frame again. Aiming and drawing follow the camera.
extends GutTest

const FEYRE := preload("res://characters/feyre/feyre.tscn")


func after_each() -> void:
	GameSettings.set_value(&"mouse_steers", false)
	for a in [&"move_forward", &"move_left", &"move_right", &"aim", &"sprint"]:
		Input.action_release(a)


func test_automatic_camera_turns_do_not_steer() -> void:
	var s := SteerFrame.new()
	assert_eq(s.yaw(Vector2.UP, 0.3, 0.0), 0.3)
	assert_almost_eq(s.yaw(Vector2.UP, 1.3, 1.0), 0.3, 0.001, "camera auto-turned 1 rad: same heading")


func test_the_players_own_look_steers() -> void:
	var s := SteerFrame.new()
	s.yaw(Vector2.UP, 0.3, 0.0)
	assert_almost_eq(s.yaw(Vector2.UP, 0.8, 0.0), 0.8, 0.001, "mouse turned 0.5 rad: she turns with it")
	assert_almost_eq(s.yaw(Vector2.UP, 1.8, 1.0), 0.8, 0.001, "then an auto turn of 1 rad does not")


func test_a_new_direction_takes_the_cameras_frame() -> void:
	var s := SteerFrame.new()
	s.yaw(Vector2.UP, 0.0, 0.0)
	s.yaw(Vector2.UP, 1.0, 1.0)
	assert_almost_eq(s.yaw(Vector2(-1, -1).normalized(), 1.0, 1.0), 1.0, 0.001, "pressed left too: the camera's frame")
	assert_almost_eq(s.yaw(Vector2.ZERO, 2.0, 2.0), 2.0, 0.001, "let go: free")


func test_live_frames_follow_the_camera() -> void:
	var s := SteerFrame.new()
	s.yaw(Vector2.UP, 0.0, 0.0)
	assert_eq(s.yaw(Vector2.UP, 1.0, 1.0, true), 1.0)
	assert_false(s.is_held())


func _feyre() -> Feyre:
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	floor.add_child(shape)
	add_child_autofree(floor)
	floor.global_position = Vector3(0, -0.5, 0)
	var f := FEYRE.instantiate() as Feyre
	add_child_autofree(f)
	f.global_position = Vector3(0, 0.05, 0)
	return f


func _heading(f: Feyre) -> Vector2:
	return Vector2(f.velocity.x, f.velocity.z).normalized()


func _speed(f: Feyre) -> float:
	return Vector2(f.velocity.x, f.velocity.z).length()


func _cam_forward(f: Feyre) -> Vector2:
	return Vector2(0, -1).rotated(-f.camera_yaw())


func test_an_automatic_camera_turn_mid_run_keeps_her_heading() -> void:
	var f := _feyre()
	await wait_seconds(0.3)
	Input.action_press(&"move_forward")
	await wait_seconds(0.5)
	var before := _heading(f)
	f.nudge_camera(PI / 2.0, 0.0)
	await wait_seconds(0.5)
	assert_gt(before.dot(_heading(f)), 0.99, "same heading after the camera was turned for her")


func _mouse_turn(f: Feyre, radians: float) -> void:
	f._look(-radians if not GameSettings.invert_x else radians, 0.0)


func test_by_default_the_keys_alone_steer_her_mid_stride() -> void:
	GameSettings.set_value(&"mouse_steers", false)
	var f := _feyre()
	await wait_seconds(0.3)
	Input.action_press(&"move_forward")
	await wait_seconds(0.5)
	var before := _heading(f)
	_mouse_turn(f, 0.8)
	await wait_seconds(0.6)
	assert_gt(before.dot(_heading(f)), 0.99, "the mouse turned the camera, not her (%s -> %s)" % [before, _heading(f)])
	Input.action_release(&"move_forward")
	await wait_seconds(0.3)
	Input.action_press(&"move_forward")
	await wait_seconds(0.6)
	assert_gt(_heading(f).dot(_cam_forward(f)), 0.97, "a fresh press goes the way the camera now faces")


func test_with_the_setting_on_the_mouse_steers_her() -> void:
	GameSettings.set_value(&"mouse_steers", true)
	var f := _feyre()
	await wait_seconds(0.3)
	Input.action_press(&"move_forward")
	await wait_seconds(0.5)
	_mouse_turn(f, 0.8)
	await wait_seconds(0.6)
	GameSettings.set_value(&"mouse_steers", false)
	assert_gt(_heading(f).dot(_cam_forward(f)), 0.97, "runs where the camera now looks (%s vs %s)" % [_heading(f), _cam_forward(f)])
	var facing := Vector2(0, -1).rotated(-f.model.rotation.y)
	assert_gt(facing.dot(_heading(f)), 0.98, "her body faces her path, not at an angle to it")


func test_aiming_still_strafes_with_the_camera() -> void:
	var f := _feyre()
	await wait_seconds(0.3)
	Input.action_press(&"aim")
	Input.action_press(&"move_forward")
	await wait_seconds(0.4)
	f.nudge_camera(PI / 2.0, 0.0)
	await wait_seconds(0.6)
	assert_gt(_heading(f).dot(_cam_forward(f)), 0.95, "aiming: moves with the camera")


func test_shift_and_forward_breaks_straight_into_a_run_then_a_sprint() -> void:
	var f := _feyre()
	await wait_seconds(0.3)
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	await wait_seconds(0.12)
	assert_gt(_speed(f), f.run_speed * 0.9, "a run within 0.12 s (%.1f m/s)" % _speed(f))
	await wait_seconds(0.3)
	assert_gt(_speed(f), f.sprint_speed * 0.95, "a full sprint within 0.42 s (%.1f m/s)" % _speed(f))


func test_she_stops_quickly_when_the_keys_are_let_go() -> void:
	var f := _feyre()
	await wait_seconds(0.3)
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	await wait_seconds(1.0)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	var from := f.global_position
	await wait_seconds(0.3)
	assert_lt(_speed(f), 0.5, "stopped within 0.3 s")
	assert_lt(from.distance_to(f.global_position), 2.5, "and within 2.5 m of a sprint")


func test_a_quarter_turn_keeps_her_speed_and_faces_her_path() -> void:
	var f := _feyre()
	await wait_seconds(0.3)
	Input.action_press(&"move_forward")
	await wait_seconds(0.6)
	var cruise := _speed(f)
	Input.action_release(&"move_forward")
	Input.action_press(&"move_right")
	var slowest := INF
	var worst_angle := 0.0
	for i in 30:
		await wait_physics_frames(1)
		slowest = minf(slowest, _speed(f))
		var facing := Vector2(0, -1).rotated(-f.model.rotation.y)
		worst_angle = maxf(worst_angle, rad_to_deg(facing.angle_to(_heading(f))))
	assert_gt(slowest, cruise * 0.85, "no dip through the turn (%.1f of %.1f m/s)" % [slowest, cruise])
	assert_lt(absf(worst_angle), 30.0, "her body never runs at an angle to her path (%.0f deg)" % worst_angle)
	assert_gt(_heading(f).dot(Vector2(1, 0).rotated(-f.camera_yaw())), 0.98, "and she's going right")
