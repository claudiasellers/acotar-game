## Contract (L80-25): with the bow up and no aim held (the main way to shoot)
## the ring always stands clear of Feyre's own body on screen, at rest and at
## full draw, so a target low and close in front of her is never behind her.
## Her capsule's screen bounds are projected through the camera on screen.
extends GutTest

const FEYRE := preload("res://characters/feyre/feyre.tscn")
## Pixels (at 1080 high) between her capsule's edge and the ring's centre.
const HIP_RING_CLEAR_PX := 64.0
const DT := 1.0 / 60.0

var feyre: Feyre


func before_each() -> void:
	Gameplay.reset()
	StoryControl.release()
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = Vector3(0, -0.5, 0)
	feyre = FEYRE.instantiate() as Feyre
	add_child_autofree(feyre)
	feyre.global_position = Vector3(0, 0.05, 0)
	feyre.bow_controller.set_physics_process(false)
	Gameplay.inventory.add(&"arrow_wood", 5)


## The right-hand edge (screen x) of her capsule as the camera sees it.
func _body_right_edge() -> float:
	var capsule: CapsuleShape3D = null
	var at := Transform3D()
	for child in feyre.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is CapsuleShape3D:
			capsule = (child as CollisionShape3D).shape
			at = (child as CollisionShape3D).global_transform
	assert_not_null(capsule, "she has her capsule")
	var cam := get_viewport().get_camera_3d()
	var edge := -INF
	for y: float in [-capsule.height * 0.5, 0.0, capsule.height * 0.5]:
		for i in 12:
			var a := TAU * i / 12.0
			var p := at * Vector3(cos(a) * capsule.radius, y, sin(a) * capsule.radius)
			edge = maxf(edge, cam.unproject_position(p).x)
	return edge


func _clear_px() -> float:
	var reticle := feyre.bow_controller.reticle
	assert_true(reticle.visible, "the ring is on screen from the hip")
	var scale := get_viewport().get_visible_rect().size.y / 1080.0
	return (reticle._screen.x - _body_right_edge()) / scale


func _hold(seconds: float, fire: bool) -> void:
	for i in roundi(seconds / DT):
		feyre.bow_controller.update_bow(DT, false, fire)
		await get_tree().physics_frame


func test_the_ring_stands_clear_of_her_at_full_draw_from_the_hip() -> void:
	await _hold(1.2, true)
	assert_eq(feyre.bow_controller.draw_amount, 1.0)
	assert_false(feyre.bow_controller.is_precise)
	var clear := _clear_px()
	assert_gt(clear, HIP_RING_CLEAR_PX, "ring %.0f px clear of her body" % clear)


func test_and_at_rest_with_the_bow_still_up_after_a_shot() -> void:
	await _hold(0.5, true)
	await _hold(1.0, false)
	assert_true(feyre.bow_controller.is_up(), "still up for the next arrow")
	assert_false(feyre.bow_controller.is_aiming)
	var clear := _clear_px()
	assert_gt(clear, HIP_RING_CLEAR_PX, "ring %.0f px clear of her body" % clear)


func test_looking_down_at_something_low_and_close_keeps_it_clear() -> void:
	feyre.nudge_camera(0.0, -0.35)
	await _hold(1.2, true)
	var clear := _clear_px()
	assert_gt(clear, HIP_RING_CLEAR_PX, "ring %.0f px clear of her body" % clear)
