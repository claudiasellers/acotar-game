## Contract: indoors her camera never slips back through a doorway into the next
## room (it stops in front of the jambs, easing in), a narrow corridor she walks
## along does not crush the arm, and a drape between the lens and her fades.
## CameraFade runs here only through its headless opt-in and PROBE_GROUP.
extends GutTest

const FEYRE := preload("res://characters/feyre/feyre.tscn")
## The wall behind her: its near face this far behind her (+z), 0.5 m thick.
const WALL_Z := 1.4
const WALL_T := 0.5


func before_each() -> void:
	CameraFade.headless_opt_in = true


func after_each() -> void:
	CameraFade.headless_opt_in = false


func _slab(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = center


## Floor and roof; side walls `half_width` either side of her along z.
func _room(half_width: float) -> void:
	_slab(Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	_slab(Vector3(0, 4.15, 0), Vector3(40, 0.3, 40))
	if half_width > 0.0:
		_slab(Vector3(-half_width - 0.15, 2, 0), Vector3(0.3, 4, 40))
		_slab(Vector3(half_width + 0.15, 2, 0), Vector3(0.3, 4, 40))


## A wall behind her with a doorway `door` wide straight behind her.
func _doorway_wall(door: float) -> void:
	var z := WALL_Z + WALL_T * 0.5
	var side := (20.0 - door * 0.5)
	_slab(Vector3(-door * 0.5 - side * 0.5, 2, z), Vector3(side, 4, WALL_T))
	_slab(Vector3(door * 0.5 + side * 0.5, 2, z), Vector3(side, 4, WALL_T))
	_slab(Vector3(0, 3.4, z), Vector3(door, 1.2, WALL_T))   # lintel


func _feyre() -> Feyre:
	var f := FEYRE.instantiate() as Feyre
	add_child_autofree(f)
	f.global_position = Vector3(0, 0.05, 0)
	return f


func test_a_doorway_behind_her_keeps_the_camera_in_her_room() -> void:
	_room(0.0)
	_doorway_wall(1.6)
	var f := _feyre()
	await wait_seconds(1.5)
	var cam := f.camera.global_position
	assert_lt(cam.z, WALL_Z - 0.1, "camera at z %.2f, wall face at %.2f: in front of the jambs" % [cam.z, WALL_Z])
	assert_gt(cam.z, 0.7, "but not crushed onto her (z %.2f)" % cam.z)


func test_the_pull_in_eases_rather_than_snapping() -> void:
	_room(0.0)
	var f := _feyre()
	await wait_seconds(1.5)
	var before := f.camera.global_position.z
	_doorway_wall(1.6)
	await wait_physics_frames(2)
	await wait_process_frames(1)
	var first := f.camera.global_position.z
	await wait_seconds(1.0)
	var settled := f.camera.global_position.z
	assert_lt(settled, WALL_Z - 0.1, "it does pull in")
	assert_gt(first - settled, 0.2, "not in one frame (%.2f -> %.2f -> %.2f)" % [before, first, settled])


func test_a_narrow_corridor_does_not_crush_the_arm() -> void:
	_room(0.75)
	var f := _feyre()
	await wait_seconds(1.5)
	assert_gt(f.camera.global_position.z, 2.0, "camera z %.2f along a 1.5 m corridor" % f.camera.global_position.z)


func test_a_drape_between_lens_and_her_fades() -> void:
	_room(0.0)
	var f := _feyre()
	await wait_seconds(1.5)
	var cam := f.camera.global_position
	var drape := MeshInstance3D.new()
	var quad := BoxMesh.new()
	quad.size = Vector3(1.2, 2.2, 0.04)
	drape.mesh = quad
	add_child_autofree(drape)
	drape.add_to_group(CameraFade.PROBE_GROUP)
	drape.global_position = Vector3(0, 1.4, cam.z * 0.5)
	await wait_seconds(0.4)
	assert_gt(drape.transparency, 0.5, "the drape is see-through while it hides her")
	drape.global_position.x = 5.0
	await wait_seconds(0.4)
	assert_almost_eq(drape.transparency, 0.0, 0.001, "and solid once it doesn't")


func test_indoors_furniture_behind_her_does_not_shove_the_camera_in() -> void:
	_room(0.0)
	# A canopy bed straight behind her: a box body with its own mesh, like PropLib's.
	var bed := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 3.2, 1.2)
	cs.shape = box
	bed.add_child(cs)
	var look := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	look.mesh = mesh
	bed.add_child(look)
	add_child_autofree(bed)
	look.add_to_group(CameraFade.PROBE_GROUP)
	bed.global_position = Vector3(0, 1.6, 1.6)
	var f := _feyre()
	await wait_seconds(1.5)
	assert_gt(f.camera.global_position.z, 2.0, "camera z %.2f: through the bed, not wedged against it" % f.camera.global_position.z)
	assert_gt(look.transparency, 0.5, "and the bed fades while it is between the lens and her")


func test_a_short_arm_moves_her_off_centre() -> void:
	var f := _feyre()
	assert_eq(f.close_shoulder(2.4), 0.0, "the usual arm is centred")
	assert_almost_eq(f.close_shoulder(FeyreCamera.ROOM_MIN_ARM), FeyreCamera.CLOSE_SHOULDER, 0.001, "the shortest is over her shoulder")
