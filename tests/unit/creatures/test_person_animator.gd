extends GutTest
## Lane L22: villagers and court folk move on a real skeleton, and people turn
## their heads to Feyre. Contract: docs/contracts/creature_motion.md.

const CLIPS: Array[StringName] = [&"idle", &"walk", &"talk", &"flinch", &"bow"]
## A villager, a court fae, and a glamoured figure (two rigged layers).
const IDS := ["human_woman", "fae_fox", "alis"]

var _feyre: Node3D


func before_each() -> void:
	WorldState.clear()


func after_each() -> void:
	if is_instance_valid(_feyre):
		_feyre.free()


func _npc(id: String) -> CourtNpc:
	var npc := (load("res://creatures/people/scenes/%s.tscn" % id) as PackedScene).instantiate() as CourtNpc
	npc.wander_radius = 0.0
	add_child_autofree(npc)
	return npc


func _player(at: Vector3) -> Node3D:
	_feyre = Node3D.new()
	_feyre.name = "FakeFeyre"
	_feyre.add_to_group(&"player")
	add_child(_feyre)
	_feyre.global_position = at
	return _feyre


func test_people_are_rigged_with_their_clips() -> void:
	for id in IDS:
		var npc := _npc(id)
		assert_false(npc.animators.is_empty(), id + " has an animator")
		for a in npc.animators:
			assert_not_null(a.skeleton, id)
			for c in CLIPS:
				assert_true(a.anim.has_animation(c), "%s %s" % [id, c])
			assert_between(a.native_walk, 0.6, 2.0, id + " native walk speed")
			assert_true(a.skeleton.find_bone("head") != -1 or a.skeleton.find_bone("Head") != -1, id + " has a head bone")
	assert_eq(_npc("alis").animators.size(), 2, "both glamour layers")


func test_walk_blend_follows_ground_speed() -> void:
	var npc := _npc("human_woman")
	var a: PersonAnimator = npc.animators[0]
	a._process(0.016)  # first frame: picks its own offset
	for i in 30:
		npc.global_position += Vector3(0, 0, -a.native_walk * 0.016)
		a._process(0.016)
	assert_almost_eq(float(a.tree.get(&"parameters/loco/blend_position")), a.native_walk, 0.08, "walking")
	assert_almost_eq(a.loco_rate(a.native_walk), 1.0, 0.01, "feet match the ground at native speed")
	assert_eq(a.loco_rate(a.native_walk * 3.0), PersonAnimator.MAX_RATE)
	for i in 60:
		a._process(0.016)
	assert_almost_eq(float(a.tree.get(&"parameters/loco/blend_position")), 0.0, 0.05, "stopped: idle")


func test_rigged_model_is_not_squashed_to_breathe() -> void:
	var npc := _npc("human_woman")
	for i in 20:
		npc._process(0.1)
	assert_eq(npc.current_model().scale, Vector3.ONE, "breath comes from the ribs, not a y-scale")


func test_gesture_fires_on_the_visible_model() -> void:
	var npc := _npc("human_woman")
	npc.gesture(&"bow")
	var a: PersonAnimator = npc.animators[0]
	assert_true(bool(a.tree.get(&"parameters/bow_shot/active")) or int(a.tree.get(&"parameters/bow_shot/request")) == AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func test_head_turns_to_feyre_in_front_and_not_behind() -> void:
	var npc := _npc("human_woman")
	npc.global_position = Vector3.ZERO
	var a: PersonAnimator = npc.animators[0]
	await wait_process_frames(3)
	assert_not_null(a.notice, "notice attached")
	var sk := a.skeleton
	var head := sk.find_bone("head")
	if head == -1:
		head = sk.find_bone("Head")    # the villagers are on the main cast's rig since L52
	var seen := {"basis": Basis.IDENTITY}
	sk.skeleton_updated.connect(func() -> void: seen.basis = sk.get_bone_global_pose(head).basis)
	await wait_process_frames(3)
	var rest: Basis = seen.basis
	# She stands off his right front, 3 m away.
	var feyre := _player(Vector3(2.2, 0.0, -2.2))
	await wait_seconds(1.6)
	assert_gt(a.notice.weight, 0.95, "eased in")
	var axis := a.notice.look.forward_axis
	var fwd_rest := _axis(rest, axis)
	var fwd_now := _axis(seen.basis, axis)
	var to_her := (sk.global_basis.inverse() * (feyre.global_position + Vector3.UP * 1.55 - sk.global_transform * sk.get_bone_global_pose(head).origin)).normalized()
	assert_gt(fwd_now.dot(to_her), fwd_rest.dot(to_her) + 0.15, "head turned toward her")
	# Behind him: he does not see her, the head eases back.
	feyre.global_position = Vector3(0.0, 0.0, 4.0)
	await wait_seconds(1.2)
	assert_lt(a.notice.weight, 0.05, "eased back")


func test_hidden_layer_does_not_animate() -> void:
	var npc := _npc("alis")
	await wait_process_frames(2)
	for a in npc.animators:
		assert_eq(a.tree.active, a.get_parent().is_visible_in_tree(), "only the visible form runs")


static func _axis(b: Basis, axis: int) -> Vector3:
	return b[axis / 2].normalized() * (1.0 if axis % 2 == 0 else -1.0)


func test_main_cast_notice_feyre_too() -> void:
	for id in ["tamlin", "lucien", "nesta", "elain", "father"]:
		var path := "res://characters/%s/%s_model.tscn" % [id, id]
		if not ResourceLoader.exists(path):
			continue
		var m := (load(path) as PackedScene).instantiate() as Node3D
		add_child_autofree(m)
		var notice: NoticePlayer = m.get(&"notice")
		assert_not_null(notice, id)
		if notice:
			assert_eq(notice.look.bone_name, "Head", id)
