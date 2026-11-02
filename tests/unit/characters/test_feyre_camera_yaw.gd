## Contract (owner): under a roof the camera's yaw is the player's alone. With no
## look input it does not turn, however she walks, sprints or changes keys.
## Outdoors "camera follows while running" still swings it behind her.
extends GutTest

const FEYRE := preload("res://characters/feyre/feyre.tscn")


func after_each() -> void:
	for a in [&"move_forward", &"move_left", &"move_back", &"sprint"]:
		Input.action_release(a)


func _slab(y: float, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = y
	body.add_child(shape)
	add_child_autofree(body)


func _feyre(roofed: bool) -> Feyre:
	_slab(-0.5, Vector3(200, 1, 200))
	if roofed:
		_slab(5.0, Vector3(200, 0.3, 200))
	var f := FEYRE.instantiate() as Feyre
	add_child_autofree(f)
	f.global_position = Vector3(0, 0.05, 0)
	return f


func test_she_can_stand_still_without_the_camera_turning() -> void:
	var f := _feyre(true)
	await wait_seconds(0.6)
	var yaw := f.camera_yaw()
	await wait_seconds(0.6)
	assert_eq(f.camera_yaw(), yaw)


func test_sprinting_indoors_never_turns_the_camera() -> void:
	var f := _feyre(true)
	await wait_seconds(0.6)
	assert_true(f.is_indoors())
	var yaw := f.camera_yaw()
	Input.action_press(&"sprint")
	# A fresh press each time: this is what stacked the swings into a spin.
	for key: StringName in [&"move_left", &"move_left", &"move_back", &"move_forward"]:
		Input.action_press(key)
		await wait_seconds(0.8)
		Input.action_release(key)
		await wait_seconds(0.1)
	assert_eq(f.camera_yaw(), yaw, "no look input, so no turn")


func test_outdoors_the_camera_still_follows_a_sprint() -> void:
	var f := _feyre(false)
	await wait_seconds(0.6)
	var yaw := f.camera_yaw()
	Input.action_press(&"sprint")
	Input.action_press(&"move_left")
	await wait_seconds(1.5)
	assert_gt(absf(angle_difference(yaw, f.camera_yaw())), 0.5, "swung behind her")
