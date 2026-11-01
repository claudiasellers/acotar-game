## Lane L22: cast models act out their own story cues (CastCues), here
## Lucien's leaves_sick from ch17.
extends GutTest


func _bone(sk: Skeleton3D, bone: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin


func _lucien(at: Vector3) -> Node3D:
	var lucien := StandIns.figure("lucien")
	lucien.add_to_group(&"story_actor_lucien")
	add_child_autofree(lucien)
	lucien.global_position = at
	return lucien


func test_the_model_faces_minus_z_and_the_hunch_bends_him_forward() -> void:
	var lucien := _lucien(Vector3.ZERO)
	await wait_process_frames(2)
	var sk: Skeleton3D = lucien.get(&"skeleton")
	var toes := _bone(sk, "LeftToes") - _bone(sk, "LeftFoot")
	assert_lt(toes.z, 0.0, "his toes point along -Z: -Z is his front")
	# Modifiers apply inside the skeleton's update: read the head there.
	var seen := {}
	sk.skeleton_updated.connect(func() -> void: seen["head"] = _bone(sk, "Head"))
	await wait_process_frames(2)
	var head: Vector3 = seen["head"]
	(lucien.get(&"cues") as CastCues).hunch.amount = 1.0
	await wait_process_frames(2)
	var bent: Vector3 = seen["head"]
	assert_lt(bent.z, head.z - 0.2, "bent forward")
	assert_lt(bent.y, head.y - 0.1, "and down")


func test_leaves_sick_backs_off_retches_and_walks_out() -> void:
	var faerie := Node3D.new()
	faerie.add_to_group(&"story_actor_summer_faerie")
	add_child_autofree(faerie)
	faerie.global_position = Vector3(1.0, 0.9, -35.0)
	# As the ch17 triage places him: no exit given, he is in the manor's hall.
	var lucien := _lucien(Vector3(2.4, 0.0, -33.4))
	await wait_process_frames(1)
	var cues: CastCues = lucien.get(&"cues")
	EventBus.story_actor_cue.emit(&"lucien", &"leaves_sick")
	assert_eq(cues.stage, &"back")
	var start := lucien.global_position
	await wait_seconds(CastCues.BACK_SECONDS + 0.2)
	assert_gt(Vector2(lucien.global_position.x - 1.0, lucien.global_position.z + 35.0).length(),
			Vector2(start.x - 1.0, start.z + 35.0).length() + 1.0, "backed away from the table")
	assert_eq(cues.stage, &"retch")
	await wait_seconds(0.3)
	assert_gt(cues.hunch.amount, 0.6, "bent double")
	await wait_seconds(8.5)
	assert_eq(cues.stage, &"gone")
	assert_almost_eq(lucien.global_position.z, ManorSitePlan.FRONT_DOOR.z + 0.8, 0.35, "out by the front doors")
	assert_almost_eq(lucien.global_position.x, ManorSitePlan.FRONT_DOOR.x, 0.35)
	assert_false(lucien.visible, "out of sight")
	assert_false((lucien.get(&"notice") as NoticePlayer).enabled)


func test_cues_for_others_leave_him_be() -> void:
	var lucien := _lucien(Vector3.ZERO)
	await wait_process_frames(1)
	EventBus.story_actor_cue.emit(&"tamlin", &"leaves_sick")
	assert_eq((lucien.get(&"cues") as CastCues).stage, &"")


func test_an_exit_the_scene_gives_wins() -> void:
	var lucien := _lucien(Vector3(40.0, 0.0, 40.0))
	lucien.set_meta(&"exit_to", Vector3(40.0, 0.0, 46.0))
	await wait_process_frames(1)
	EventBus.story_actor_cue.emit(&"lucien", &"leaves_sick")
	await wait_seconds(11.0)
	assert_eq((lucien.get(&"cues") as CastCues).stage, &"gone")
	assert_almost_eq(lucien.global_position.z, 46.0, 0.35)
