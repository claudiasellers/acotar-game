## Contract (T094): a wall beside her never lets the lens graze or pass it. The
## over-the-shoulder offset is swept out from the pivot and the arm sweeps a ball
## Feyre.LENS_RADIUS wide, so the camera keeps a margin from a wall on the shoulder
## side; in the open the full shoulder offset is untouched.
extends GutTest

const FEYRE := preload("res://characters/feyre/feyre.tscn")


func after_each() -> void:
	Input.action_release(&"aim")


func _slab(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = center


## Open ground (no roof, so the indoor and room rules stay out of it) and, if
## `face` > 0, a wall along z on her right whose near face is `face` m from her.
func _aiming_feyre(face: float, thick: float) -> Feyre:
	_slab(Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	if face > 0.0:
		_slab(Vector3(face + thick * 0.5, 2, 0), Vector3(thick, 4, 40))
	var f := FEYRE.instantiate() as Feyre
	add_child_autofree(f)
	f.global_position = Vector3(0, 0.05, 0)
	# Aiming puts the arm 0.55 m over her right shoulder, the widest offset.
	Input.action_press(&"aim")
	await wait_seconds(1.0)
	return f


func test_a_wall_beside_the_arm_keeps_a_margin() -> void:
	# The old offset put the lens 0.05 m from this face.
	var f := await _aiming_feyre(0.6, 0.3)
	var cam := f.camera.global_position
	assert_lt(cam.x, 0.6 - 0.1, "lens at x %.2f, wall face at 0.60: a margin off it" % cam.x)
	assert_gt(cam.z, 1.0, "and the arm is not crushed (z %.2f)" % cam.z)


func test_a_thin_wall_at_her_shoulder_is_never_passed() -> void:
	# The old offset put the lens at x 0.55, through this 0.1 m wall into the next room.
	var f := await _aiming_feyre(0.4, 0.1)
	var cam := f.camera.global_position
	assert_lt(cam.x, 0.4 - 0.1, "lens at x %.2f, wall face at 0.40: on her side of it" % cam.x)


func test_in_the_open_the_full_shoulder_offset_stays() -> void:
	var f := await _aiming_feyre(0.0, 0.0)
	assert_almost_eq(f.camera.global_position.x, 0.55, 0.03, "nothing beside her: the usual offset")
