## Act I playtest fixes F5 (drop-aware aim) and F4 (no tunnelling).
extends GutTest

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child_autofree(world)


func _wall(at: Vector3, box_size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.global_position = at
	return body


func _fire(from: Vector3, velocity: Vector3) -> Arrow:
	var arrow := Arrow.create(load("res://data/arrows/wood.tres"))
	world.add_child(arrow)
	arrow.launch(from, velocity.normalized(), velocity.length())
	return arrow


func test_prediction_shows_the_drop_and_matches_the_flight() -> void:
	_wall(Vector3(0, 0, -24.5), Vector3(30, 20, 1))
	await wait_physics_frames(2)
	var from := Vector3(0, 1.45, 0)
	var v := Vector3(0, 0, -48)
	var data: ArrowData = load("res://data/arrows/wood.tres")
	var guess := BowController.predict_path(from, v, data.drag, world.get_world_3d().direct_space_state)
	assert_true(guess.hit, "the wall is in range")
	assert_lt(guess.point.y, from.y - 0.4, "aiming dead level lands visibly low at 24 m")
	var arrow := _fire(from, v)
	for i in 120:
		await wait_physics_frames(1)
		if arrow.stuck:
			break
	assert_true(arrow.stuck)
	var tip := arrow.global_position - arrow.global_basis.z * Arrow.LENGTH * 0.35
	assert_almost_eq(tip.y, guess.point.y, 0.3, "real flight lands where the reticle said")


func test_fast_arrow_cannot_skip_a_thin_collider() -> void:
	_wall(Vector3(0, 1.45, -30), Vector3(10, 10, 0.02))
	await wait_physics_frames(2)
	var arrow := _fire(Vector3(0, 1.45, 0), Vector3(0, 0, -150))
	arrow.continuous_cd = false
	for i in 60:
		await wait_physics_frames(1)
		if arrow.stuck:
			break
	assert_true(is_instance_valid(arrow) and arrow.stuck, "the swept ray catches it")
	assert_gt(arrow.global_position.z, -31.0, "it stopped at the wall, not beyond")
