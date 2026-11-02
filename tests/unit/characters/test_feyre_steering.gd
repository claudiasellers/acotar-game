## Contract (owner): turning the camera does not change the way she walks. The
## move keys steer in the frame the camera had when they went down; letting go
## frees it. Aiming and drawing follow the camera so she can strafe a shot.
extends GutTest

const FEYRE := preload("res://characters/feyre/feyre.tscn")


func after_each() -> void:
	for a in [&"move_forward", &"move_left", &"aim"]:
		Input.action_release(a)


func test_the_frame_holds_while_keys_are_down() -> void:
	var s := SteerFrame.new()
	assert_eq(s.yaw(Vector2.UP, 0.3), 0.3)
	assert_eq(s.yaw(Vector2.UP, 1.9), 0.3, "camera turned mid-stride: still the first frame")
	assert_eq(s.yaw(Vector2(-1, -1).normalized(), 2.5), 0.3, "adding a key steers in the same frame")
	assert_eq(s.yaw(Vector2.ZERO, 2.5), 2.5, "let go: free")
	assert_eq(s.yaw(Vector2.UP, 2.5), 2.5, "the next press takes the camera's frame then")


func test_live_frames_follow_the_camera() -> void:
	var s := SteerFrame.new()
	s.yaw(Vector2.UP, 0.0)
	assert_eq(s.yaw(Vector2.UP, 1.0, true), 1.0)
	assert_false(s.is_held())


func _feyre() -> Feyre:
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
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


func test_turning_the_camera_mid_walk_keeps_her_heading() -> void:
	var f := _feyre()
	await wait_seconds(0.3)
	Input.action_press(&"move_forward")
	await wait_seconds(0.6)
	var before := _heading(f)
	assert_almost_eq(before.y, -1.0, 0.05, "walks away from the camera (-z) at first: %s" % before)
	f.nudge_camera(PI / 2.0, 0.0)   # swing the camera a quarter turn mid-stride
	await wait_seconds(0.6)
	var after := _heading(f)
	assert_gt(before.dot(after), 0.99, "same heading after the camera turned (%s -> %s)" % [before, after])
	Input.action_release(&"move_forward")
	await wait_seconds(0.4)
	Input.action_press(&"move_forward")
	await wait_seconds(0.6)
	var fresh := _heading(f)
	var cam_fwd := Vector2(0, -1).rotated(-f.camera_yaw())
	assert_gt(fresh.dot(cam_fwd), 0.95, "a fresh press walks where the camera now looks (%s vs %s)" % [fresh, cam_fwd])


func test_aiming_still_strafes_with_the_camera() -> void:
	var f := _feyre()
	await wait_seconds(0.3)
	Input.action_press(&"aim")
	Input.action_press(&"move_forward")
	await wait_seconds(0.4)
	f.nudge_camera(PI / 2.0, 0.0)
	await wait_seconds(0.6)
	var cam_fwd := Vector2(0, -1).rotated(-f.camera_yaw())
	assert_gt(_heading(f).dot(cam_fwd), 0.95, "aiming: moves with the camera (%s vs %s)" % [_heading(f), cam_fwd])
