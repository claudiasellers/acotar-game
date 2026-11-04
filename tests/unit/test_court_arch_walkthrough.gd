## Contract: a flower arch has solid posts and an open middle. The court model
## loader must keep the arch's authored collision and not box its whole bounds in.
extends GutTest

const FEYRE := preload("res://characters/feyre/feyre.tscn")
const ARCH := &"solstice_flower_arch"


func after_each() -> void:
	Input.action_release(&"move_forward")


func _world(arch_x: float) -> void:
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor.add_child(shape)
	add_child_autofree(floor)
	floor.global_position = Vector3(0, -0.5, 0)
	var region := CourtRegion.new()
	var arch := region._model(ARCH)
	region.free()
	add_child_autofree(arch)
	arch.global_position = Vector3(arch_x, 0, 0)


func test_the_arch_has_no_box_over_its_opening() -> void:
	_world(0.0)
	var bodies := 0
	for b: Node in get_children():
		for body: StaticBody3D in b.find_children("*", "StaticBody3D", true, false):
			bodies += 1
			for cs: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
				assert_false(cs.shape is BoxShape3D and (cs.shape as BoxShape3D).size.x > 2.0 and cs.position.y > 0.5,
						"no box spanning the opening")
	assert_gt(bodies, 0, "the arch keeps its own post collision")


func test_feyre_runs_through_the_middle_and_out_the_far_side() -> void:
	_world(0.0)
	var f := FEYRE.instantiate() as Feyre
	add_child_autofree(f)
	f.global_position = Vector3(0, 0.05, 5)
	Input.action_press(&"move_forward")
	await wait_physics_frames(150)
	assert_lt(f.global_position.z, -3.0, "came out the far side")
	assert_lt(absf(f.global_position.x), 0.8, "straight through the middle")


func test_the_posts_are_still_solid() -> void:
	_world(0.0)
	var f := FEYRE.instantiate() as Feyre
	add_child_autofree(f)
	f.global_position = Vector3(-1.3, 0.05, 5)
	Input.action_press(&"move_forward")
	await wait_physics_frames(150)
	assert_gt(f.global_position.z, -1.0, "stopped by the post")
