## Contract: indoors (anything roofing her within FeyreCamera.INDOOR_PROBE) her camera stays
## in the room, at most INDOOR_RISE above its pivot and clear of the ceiling, even when
## the player looks steeply down; outdoors the usual high orbit is untouched.
extends GutTest

const FEYRE := preload("res://characters/feyre/feyre.tscn")


func _slab(y: float, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = y
	body.add_child(shape)
	add_child_autofree(body)


func _feyre(roof_y: float) -> Feyre:
	_slab(-0.5, Vector3(60, 1, 60))
	if roof_y > 0.0:
		# A cottage-like room: roof well above beams that have no collision.
		_slab(roof_y, Vector3(12, 0.3, 12))
	var f := FEYRE.instantiate() as Feyre
	add_child_autofree(f)
	f.global_position = Vector3(0, 0.05, 0)
	return f


func test_looking_down_indoors_keeps_the_camera_under_the_beams() -> void:
	var f := _feyre(5.0)
	await wait_process_frames(5)
	f.nudge_camera(0.0, deg_to_rad(-60.0))
	# Time, not frames: the indoor blend and arm length ease over seconds, and a fast
	# headless loop can run 40 frames in well under the 0.3 s blend.
	await wait_seconds(1.0)
	assert_lte(f.camera_rise(), FeyreCamera.INDOOR_RISE + 0.05, "camera %.2f m above her head" % f.camera_rise())


func test_a_low_ceiling_pulls_the_camera_lower_still() -> void:
	var f := _feyre(2.4)
	await wait_process_frames(5)
	f.nudge_camera(0.0, deg_to_rad(-60.0))
	# Time, not frames: the indoor blend and arm length ease over seconds, and a fast
	# headless loop can run 40 frames in well under the 0.3 s blend.
	await wait_seconds(1.0)
	var ceiling_gap := (2.4 - 0.15) - f.camera.global_position.y
	assert_gte(ceiling_gap, FeyreCamera.INDOOR_CEILING_GAP - 0.05, "camera %.2f m under the ceiling" % ceiling_gap)


func test_outdoors_the_camera_still_orbits_high() -> void:
	var f := _feyre(0.0)
	await wait_process_frames(5)
	f.nudge_camera(0.0, deg_to_rad(-60.0))
	# Time, not frames: the indoor blend and arm length ease over seconds, and a fast
	# headless loop can run 40 frames in well under the 0.3 s blend.
	await wait_seconds(1.0)
	assert_gt(f.camera_rise(), 2.0, "outdoors a steep look still lifts the camera")
