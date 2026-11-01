## Contract: docs/contracts/creature_motion.md (lane L22).
extends GutTest

const GREAT_WOLF := preload("res://creatures/wolves/great_wolf.tscn")
const WOLF := preload("res://creatures/wolves/wolf.tscn")
const DEER := preload("res://creatures/prey/deer.tscn")
const HARE := preload("res://creatures/prey/hare.tscn")
const CLIPS: Array[StringName] = [&"idle", &"walk", &"trot", &"gallop", &"graze", &"hit_l", &"hit_r",
		&"death_l", &"death_r"]


func before_each() -> void:
	WorldState.clear()


func _spawn(scene: PackedScene) -> Creature:
	var c := scene.instantiate() as Creature
	add_child_autofree(c)
	return c


func _arrow(at: Vector3, id: StringName = &"wood") -> Node3D:
	var a := Node3D.new()
	a.set_meta(&"arrow_id", id)
	add_child_autofree(a)
	a.global_position = at
	return a


func test_every_quadruped_is_rigged_with_the_full_clip_set() -> void:
	for scene in [GREAT_WOLF, WOLF, DEER, HARE]:
		var c := _spawn(scene)
		assert_not_null(c.animator, "%s has an animator" % c.data.kind)
		assert_not_null(c.animator.skeleton, "%s has a skeleton" % c.data.kind)
		assert_gte(c.animator.skeleton.get_bone_count(), 25, "%s: a real skeleton" % c.data.kind)
		for clip in CLIPS:
			assert_true(c.animator.anim.has_animation(clip), "%s has %s" % [c.data.kind, clip])
		assert_eq(c.animator.anim.get_animation(&"walk").loop_mode, Animation.LOOP_LINEAR, "gaits loop")
		assert_eq(c.animator.anim.get_animation(&"death_l").loop_mode, Animation.LOOP_NONE, "death holds")
	assert_true(_spawn(GREAT_WOLF).animator.anim.has_animation(&"stalk"), "wolves stalk")


func test_gait_speeds_come_from_the_generator_and_rise_with_the_gait() -> void:
	var a := _spawn(GREAT_WOLF).animator
	var walk: float = a.native_speeds[&"walk"]
	var trot: float = a.native_speeds[&"trot"]
	var gallop: float = a.native_speeds[&"gallop"]
	assert_gt(walk, 0.3)
	assert_gt(trot, walk)
	assert_gt(gallop, trot)
	# Planted paws match the ground: rate 1 between gait points, scaled past the
	# gallop up to the cadence cap, slowed for the first steps.
	assert_eq(a.loco_rate((walk + trot) * 0.5), 1.0)
	assert_almost_eq(a.loco_rate(gallop * 1.2), 1.2, 0.001)
	assert_eq(a.loco_rate(gallop * 5.0), CreatureAnimator.MAX_RATE)
	assert_almost_eq(a.loco_rate(walk * 0.7), 0.7, 0.001)
	# His run speed is within the cadence cap, so his paws don't skate.
	assert_lte(_spawn(GREAT_WOLF).data.run_speed / gallop, CreatureAnimator.MAX_RATE)


func test_an_arrow_flinches_the_side_it_struck() -> void:
	var c := _spawn(GREAT_WOLF)
	var right := c.global_transform * Vector3(0.6, 0.9, 0.0)
	c.on_arrow_hit(_arrow(right))
	assert_eq(c.animator.last_hit_side, 1, "struck on the right")
	assert_true(c.alive, "wood only stings him")
	var left := c.global_transform * Vector3(-0.6, 0.9, 0.0)
	c.on_arrow_hit(_arrow(left))
	assert_eq(c.animator.last_hit_side, -1, "then on the left")


func test_the_great_wolf_falls_away_from_the_killing_arrow_and_lies_down() -> void:
	var c := _spawn(GREAT_WOLF) as GreatWolf
	var a := c.animator
	a.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var spine := a.skeleton.find_bone("spine")
	a.tree.advance(0.5)
	var standing := (a.skeleton.global_transform * a.skeleton.get_bone_global_pose(spine).origin).y
	# Ash in his right side, then the second arrow in the eye from the same side.
	var right := c.global_transform * Vector3(0.7, 1.2, 0.0)
	c.on_arrow_hit(_arrow(right, &"ash"))
	assert_true(c.alive)
	assert_eq(c.state, GreatWolf.State.STARE, "he stops and looks; no charge")
	c.on_arrow_hit(_arrow(c.global_transform * Vector3(0.3, 1.6, -1.6)))
	assert_false(c.alive)
	assert_eq(a.fell_to, -1, "struck on the right, he goes down on his left flank")
	a.tree.advance(0.02)
	assert_eq(a.tree.get(&"parameters/life/current_state"), "death_l")
	var t := 0.0
	while t < a.death_length() + 0.2:
		a.tree.advance(0.1)
		t += 0.1
	var lying := (a.skeleton.global_transform * a.skeleton.get_bone_global_pose(spine).origin).y
	assert_gt(standing, 1.0, "the great wolf stands pony-high (%.2f m)" % standing)
	assert_lt(lying, standing * 0.5, "and ends lying on the ground (%.2f m)" % lying)
	assert_almost_eq(c.model.rotation.z, 0.0, 0.01, "no statue topple: the clip carries the fall")
	assert_gt(a.death_length(), 6.0, "he dies slowly")


func test_a_stuck_arrow_rides_the_nearest_bone() -> void:
	var c := _spawn(WOLF)
	var arrow := Node3D.new()
	arrow.add_to_group(&"stuck_arrows")
	c.add_child(arrow)
	arrow.global_position = c.global_transform * Vector3(0.0, 0.6, 0.45)
	await wait_frames(2)
	assert_true(arrow.get_parent() is BoneAttachment3D, "pinned to a bone")
	var bone := (arrow.get_parent() as BoneAttachment3D).bone_name
	assert_true(bone in ["hips", "spine", "ribs", "tail0", "upper_hl_l", "upper_hl_r"], "near the haunch, got %s" % bone)


func test_unrigged_models_keep_the_old_topple() -> void:
	var c := _spawn(GREAT_WOLF)
	var bare := Creature.new()
	autofree(bare)
	assert_null(CreatureAnimator.attach(bare), "no model, no animator")
	assert_not_null(c.animator)
