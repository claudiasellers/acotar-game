extends GutTest
## Contract test for the mare's feel (L47-6, docs/contracts/mount.md): the
## vault on and slide off are motions, never teleports; called, she pulls up
## with her near side to Feyre; the gallop never lopes in slow motion.

const HORSE := preload("res://creatures/fae/white_horse.tscn")
const FEYRE_MODEL := preload("res://characters/feyre/model/feyre_model.tscn")
const STEP := 1.0 / 60.0


class Rider:
	extends Node3D
	var model: Node3D


var horse: WhiteHorse
var rider: Rider
var pose: RidePose


func before_each() -> void:
	var body := Node3D.new()  # stands in for MareMount: the horse's parent
	add_child_autofree(body)
	horse = HORSE.instantiate() as WhiteHorse
	body.add_child(horse)
	rider = Rider.new()
	add_child_autofree(rider)
	rider.model = FEYRE_MODEL.instantiate() as Node3D
	rider.add_child(rider.model)
	rider.global_position = Vector3(-1.6, 0.0, 0.3)
	await wait_process_frames(2)
	pose = Saddle.seat(rider)
	pose.amount = 0.0


func _flat_ground(_x: float, _z: float) -> float:
	return 0.0


func test_the_vault_on_is_a_motion_and_ends_in_the_seat() -> void:
	var m := MountMotion.new()
	m.begin_on(rider, horse, pose, _flat_ground)
	var frames := 0
	while m.tick(STEP):
		frames += 1
		assert_lt(frames, 600, "it ends")
	assert_almost_eq(m.t, MountMotion.ON_TIME, 0.001)
	assert_between(MountMotion.ON_TIME, 0.8, 1.6, "quick, but seen")
	assert_lt(m.max_hip_step, 0.16, "no frame moves her hips more than 16 cm at 60 fps")
	assert_lt(m.max_hip_speed, 9.0, "a vault, not a teleport (m/s)")
	var hips := rider.global_position + Vector3.UP * m.drop
	assert_lt(hips.distance_to(horse.seat_point()), 0.03, "she ends in the saddle")
	assert_almost_eq(pose.amount, 1.0, 0.01, "in the seat pose")
	assert_false(pose.has_overrides(), "the swing's overrides are cleared")


func test_the_slide_off_lands_beside_her() -> void:
	pose.amount = 1.0
	Saddle.place(rider, horse)
	var landing := Vector3(-1.3, 0.0, 0.0)
	var m := MountMotion.new()
	m.begin_off(rider, horse, pose, landing)
	while m.tick(STEP):
		pass
	assert_lt(m.max_hip_step, 0.16)
	assert_lt(rider.global_position.distance_to(landing), 0.05, "on the ground where she landed")
	assert_almost_eq(pose.amount, 0.0, 0.01, "out of the seat pose")


func test_an_override_aims_a_bone() -> void:
	var sk := Saddle.skeleton_of(rider)
	var b := sk.find_bone(&"RightUpperArm")
	var c := sk.find_bone(&"RightLowerArm")
	pose.set_override(&"RightUpperArm", 1.0, 0.0, 0.0, 1.0)  # straight ahead
	assert_true(pose.has_overrides())
	assert_almost_eq(pose.override_dir(&"RightUpperArm", 1.0, 0.0, 0.0).dot(pose.forward), 1.0, 0.001)
	# Modifier results only hold inside the skeleton's update: read them there.
	var seen: Array[Vector3] = []
	var read := func() -> void:
		seen.append((sk.get_bone_global_pose(c).origin - sk.get_bone_global_pose(b).origin).normalized())
	sk.skeleton_updated.connect(read)
	await wait_process_frames(3)
	sk.skeleton_updated.disconnect(read)
	assert_gt(seen.size(), 0, "the skeleton updated")
	if not seen.is_empty():
		assert_gt(seen.back().dot(pose.forward), 0.95, "the arm points where it was told")
	pose.set_override(&"RightUpperArm", 0, 0, 0, 0.0)
	assert_false(pose.has_overrides())


func test_called_she_presents_her_near_side() -> void:
	var m := MareMount.new()
	add_child_autofree(m)
	for from: Vector3 in [Vector3(0, 0, -30), Vector3(25, 0, 10), Vector3(-8, 0, 40)]:
		var rider_at := Vector3(2, 0, 3)
		var spot: Array = m.presenting_spot(from, rider_at)
		var centre: Vector3 = spot[0]
		var f: Vector3 = spot[1]
		var right := f.cross(Vector3.UP)
		var to_rider := (rider_at - centre).normalized()
		assert_gt(to_rider.dot(-right), 0.99, "Feyre on her left (near) side, from %s" % from)
		assert_almost_eq(centre.distance_to(rider_at), MareMount.PRESENT_GAP, 0.01)
		assert_gt(f.dot((rider_at - from).normalized()), -0.01, "she carries on her way, no U-turn")


func test_the_gallop_never_lopes_in_slow_motion() -> void:
	var a := horse.animator
	assert_not_null(a)
	var canter: Array = a.gait_for(10.0)
	assert_eq(canter[0], &"gallop")
	assert_gte(float(canter[1]), MareAnimator.GALLOP_MIN_RATE, "a canter's beat, not a slow-motion lope")
	assert_eq(a.gait_for(MountData.new().walk_speed)[0], &"walk")
	assert_eq(a.gait_for(5.0)[0], &"trot")
