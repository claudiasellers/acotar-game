## Contract (owner): under a roof and in every manor room the camera's yaw is the
## player's alone: with no look input it does not turn, however she walks, sprints
## or changes keys. Outdoors "camera follows while running" brings it back to the
## frame the keys steer in, and repeated key presses never spiral it.
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


func test_outdoors_the_camera_swings_back_behind_a_sprint() -> void:
	var f := _feyre(false)
	await wait_seconds(0.6)
	var yaw := f.camera_yaw()
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	await wait_seconds(0.2)
	f.nudge_camera(1.0, 0.0)   # the player looked away mid-run
	await wait_seconds(1.8)
	assert_lt(absf(angle_difference(yaw, f.camera_yaw())), 0.15, "back behind the run")


func test_outdoors_repeated_presses_do_not_spiral() -> void:
	var f := _feyre(false)
	await wait_seconds(0.6)
	var yaw := f.camera_yaw()
	Input.action_press(&"sprint")
	for key: StringName in [&"move_left", &"move_left", &"move_back", &"move_left"]:
		Input.action_press(key)
		await wait_seconds(0.8)
		Input.action_release(key)
		await wait_seconds(0.1)
	assert_eq(f.camera_yaw(), yaw, "the keys steer; they never turn the camera")


func test_every_manor_room_is_indoors_without_a_collider() -> void:
	for r: ManorRoomDef in ManorHouseIndex.new(ManorHouseBuilder.load_layouts()).interior_rooms():
		var y := ManorHouseBuilder.floor_y(r.level) + 1.5
		assert_false(is_nan(ManorIndoors.ceiling_in(r.rect.get_center(), y)), "%s reads as a room" % r.id)
	assert_true(is_nan(ManorIndoors.ceiling_in(Vector2(0, 300), 10.0)), "the grounds do not")


func test_a_top_floor_room_counts_with_no_roof_over_her() -> void:
	var house := Node3D.new()
	house.add_to_group(ManorIndoors.GROUP)
	add_child_autofree(house)
	var index := ManorHouseIndex.new(ManorHouseBuilder.load_layouts())
	var room := index.find_room(&"attic_long_hall")
	var at := room.rect.get_center()
	var floor_y := ManorHouseBuilder.floor_y(room.level)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = Vector3(at.x, floor_y - 0.5, at.y)
	var f := FEYRE.instantiate() as Feyre
	add_child_autofree(f)
	f.global_position = Vector3(at.x, floor_y + 0.05, at.y)
	await wait_seconds(0.6)
	assert_true(f.is_indoors())
