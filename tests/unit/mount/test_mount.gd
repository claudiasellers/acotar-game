extends GutTest
## Contract test for the white mare mount (L47, docs/contracts/mount.md).

const HORSE := preload("res://creatures/fae/white_horse.tscn")
const FEYRE_MODEL := preload("res://characters/feyre/model/feyre_model.tscn")
const GAITS := "res://data/animation/creatures/white_horse_gaits.txt"
const FEYRE_SPRINT := 13.1


## Just enough of Feyre for the director: a body in group "player" with a model.
class Rider:
	extends CharacterBody3D
	var model: Node3D
	var yaw: float = 0.0

	func _init() -> void:
		add_to_group(&"player")
		collision_layer = 1 << 1
		var shape := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		cap.height = 1.6
		shape.shape = cap
		shape.position = Vector3.UP * 0.8
		add_child(shape)
		model = Node3D.new()
		model.name = "Model"
		add_child(model)

	func camera_yaw() -> float:
		return yaw

	func nudge_camera(dy: float, _dp: float) -> void:
		yaw += dy


var director: MountDirector
var rider: Rider


func before_each() -> void:
	WorldState.clear()
	WorldDeltas.clear()
	StoryControl.set_mode(StoryControl.Mode.FULL)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	rider = Rider.new()
	add_child_autofree(rider)
	rider.global_position = Vector3(10, 0, 10)
	director = MountDirector.new()
	add_child_autofree(director)


func _ready_mare() -> MareMount:
	WorldState.set_flag("first_dinner_eaten", true)
	var m := director.spawn_mare(Vector3(12, 0.05, 10), 0.0)
	return m


func test_data_makes_her_faster_than_feyre() -> void:
	var d := load("res://data/mount/white_mare.tres") as MountData
	assert_not_null(d)
	assert_gt(d.gallop_speed, FEYRE_SPRINT, "the gallop beats her sprint")
	assert_lte(d.gallop_speed, 15.0, "streaming look-ahead cap (director, L40 numbers)")
	assert_gt(d.canter_speed, 8.22, "a canter beats her run")
	assert_true(d.no_ride_regions.has("suriel_glade"), "the Suriel glade is no place for a horse")


func test_one_rigged_horse_under_budget() -> void:
	var h := HORSE.instantiate() as WhiteHorse
	add_child_autofree(h)
	assert_not_null(h.animator, "the white horse is rigged and animated")
	var anim := h.model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in [&"idle", &"walk", &"trot", &"gallop", &"graze"]:
		assert_true(anim.has_animation(clip), "clip %s" % clip)
	var tris := 0
	for mi: MeshInstance3D in h.model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	assert_between(tris, 4000, 15000, "R4 creature budget")
	var gaits := CreatureAnimator.read_gaits(GAITS)
	assert_gt(float(gaits[&"gallop"][0]), 14.0, "a horse's gallop clip, long-striding")
	assert_eq(h.animator.gait_for(0.0)[0], &"idle")
	assert_eq(h.animator.gait_for(1.5)[0], &"walk")
	assert_eq(h.animator.gait_for(5.0)[0], &"trot")
	assert_eq(h.animator.gait_for(15.0)[0], &"gallop")


func test_nothing_before_the_first_dinner() -> void:
	assert_false(director.available())
	assert_eq(director.block_reason(rider.global_position), &"not_yet")
	assert_false(director.whistle())


func test_first_ride_is_a_deed_and_unlocks_the_whistle() -> void:
	var m := _ready_mare()
	assert_true(m.is_in_group(&"station"), "E on her mounts")
	assert_false(director.whistle(), "she doesn't know the whistle until she has been ridden")
	watch_signals(EventBus)
	assert_true(director.mount(rider))
	assert_signal_emitted_with_parameters(EventBus, "deed_performed", ["fact.mare_ridden"])
	assert_true(director.riding)
	assert_false(rider.is_physics_processing(), "the mare carries her")
	assert_false(m.is_in_group(&"station"))
	assert_eq(m.state, MareMount.State.RIDDEN)
	director.dismount()
	assert_false(director.riding)
	assert_true(rider.is_physics_processing())
	assert_true(m.is_in_group(&"station"))
	assert_true(director.unlocked())


func test_no_riding_in_scenes_south_of_the_wall_or_in_dread() -> void:
	_ready_mare()
	WorldState.set_flag("fact.mare_ridden", true)
	EventBus.scene_space_started.emit(&"bogge")
	assert_eq(director.block_reason(rider.global_position), &"scene")
	assert_false(director.whistle())
	EventBus.scene_space_finished.emit(&"bogge")
	StoryControl.set_mode(StoryControl.Mode.WALK)
	assert_eq(director.block_reason(rider.global_position), &"story")
	StoryControl.set_mode(StoryControl.Mode.FULL)
	assert_eq(director.block_reason(Vector3(0, 0, 1500)), &"realm", "not in the human realm")
	var dread := Node3D.new()
	add_child_autofree(dread)
	dread.global_position = Vector3(40, 0, 10)
	DreadField.attach(dread, 20.0, 8.0)
	assert_eq(director.block_reason(Vector3(40, 0, 10)), &"dread")
	assert_eq(director.block_reason(rider.global_position), &"")


func test_a_scene_takes_her_out_of_the_saddle() -> void:
	_ready_mare()
	director.mount(rider)
	EventBus.scene_space_started.emit(&"puca")
	assert_false(director.riding)
	EventBus.scene_space_finished.emit(&"puca")


func test_the_whistle_brings_her() -> void:
	var m := _ready_mare()
	WorldState.set_flag("fact.mare_ridden", true)
	m.global_position = Vector3(40, 0.05, 10)
	assert_true(director.whistle())
	assert_eq(m.state, MareMount.State.COMING)
	for i in 240:
		await wait_physics_frames(1)
		if m.state == MareMount.State.STANDING:
			break
	assert_eq(m.state, MareMount.State.STANDING, "she arrives and stands")
	assert_lt(m.global_position.distance_to(rider.global_position), 6.0)


func test_riding_never_skips_a_deed_trigger() -> void:
	var m := _ready_mare()
	var t := ActionTrigger.new()
	t.flag = "fact.test.low_trigger"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 0.4, 4)
	shape.shape = box
	t.add_child(shape)
	add_child_autofree(t)
	t.global_position = Vector3(12, 0.2, 2)  # knee-high, under where she sits
	director.mount(rider)
	await wait_physics_frames(2)
	m.global_position = Vector3(12, 0.05, 2)
	await wait_physics_frames(3)
	director.sweep_triggers()
	assert_true(WorldState.has_flag("fact.test.low_trigger"), "the mare's pass counts as Feyre's")


func test_she_balks_at_dread() -> void:
	var m := _ready_mare()
	var dread := Node3D.new()
	add_child_autofree(dread)
	dread.global_position = Vector3(12, 0, -20)
	DreadField.attach(dread, 18.0, 8.0)
	director.mount(rider)
	m.global_position = Vector3(12, 0.05, -4)
	m.rotation.y = 0.0  # facing -Z, toward the dread
	watch_signals(m)
	for i in 30:
		m.steer = Vector3(0, 0, -1)
		m.gallop = true
		await wait_physics_frames(1)
	assert_signal_emitted(m, "balked")
	assert_gt(m.global_position.z, -6.0, "she won't carry Feyre into it")


func test_ride_pose_drives_her_legs() -> void:
	var model := FEYRE_MODEL.instantiate() as Node3D
	add_child_autofree(model)
	var sk := model.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	var pose := RidePose.attach(sk)
	for bone in ["LeftUpperLeg", "RightLowerLeg", "LeftLowerArm"]:
		assert_has(pose.driven_bones(), bone)
	assert_gt(pose.hip_height, 0.6, "hips a leg's length above her feet")
	assert_almost_eq(pose.forward.dot(pose.up), 0.0, 0.05)


func test_the_camera_never_fades_her() -> void:
	var h := HORSE.instantiate() as WhiteHorse
	add_child_autofree(h)
	var meshes := h.find_children("*", "GeometryInstance3D", true, false)
	assert_gt(meshes.size(), 0)
	CameraFade.headless_opt_in = true
	# Its owner is a bystander, not an ancestor of the horse (owners never fade).
	var bystander := Node.new()
	add_child_autofree(bystander)
	var fade := CameraFade.new()
	bystander.add_child(fade)
	for g in meshes:
		g.add_to_group(CameraFade.PROBE_GROUP)
	var hits := fade.near_meshes(h.global_position + Vector3.UP * 1.2, 3.0)
	hits.append_array(fade.sight_blockers(h.global_position + Vector3(0, 2.5, 4), h.global_position + Vector3.UP * 1.5))
	CameraFade.headless_opt_in = false
	for g in meshes:
		g.remove_from_group(CameraFade.PROBE_GROUP)
	assert_eq(hits.size(), 0, "the mare stays solid under the chase camera")
