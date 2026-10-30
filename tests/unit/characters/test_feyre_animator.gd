extends GutTest

const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"sprint", &"jump_start", &"jump_rise",
		&"jump_fall", &"jump_land", &"jump_double", &"jump_flourish", &"land_hero"]


func _animator() -> FeyreAnimator:
	var a := FeyreAnimator.new()
	autofree(a)
	a.native_speeds = {&"walk": 1.131, &"run": 4.451, &"sprint": 5.71}
	a.gait_points = {&"walk": 1.6, &"run": 5.5, &"sprint": 9.0}
	return a


func test_moves_library_has_every_clip_on_her_skeleton() -> void:
	var lib := FeyreAnimator.load_library()
	assert_not_null(lib)
	for clip in CLIPS:
		assert_true(lib.has_animation(clip), String(clip))
	var walk := lib.get_animation(&"walk")
	assert_eq(walk.loop_mode, Animation.LOOP_LINEAR)
	var paths := []
	for t in walk.get_track_count():
		paths.append(String(walk.track_get_path(t)))
	assert_has(paths, "Armature/Skeleton3D:LeftUpperArm")
	assert_has(paths, "Armature/Skeleton3D:RightUpperLeg")


func test_default_pace_plays_the_run_clip_feet_matched() -> void:
	var b := _animator().loco_blend(5.5)
	assert_almost_eq(b.x, 5.5, 0.001)
	assert_almost_eq(b.y, 5.5 / 4.451, 0.01)


func test_sprint_plays_the_sprint_clip_within_cadence_cap() -> void:
	var b := _animator().loco_blend(9.0)
	assert_almost_eq(b.x, 9.0, 0.001)
	assert_almost_eq(b.y, 9.0 / 5.71, 0.01)
	assert_lte(b.y, FeyreAnimator.MAX_SCALE)


func test_between_points_rate_matches_blended_native_speed() -> void:
	var b := _animator().loco_blend(3.2)
	var t := (3.2 - 1.6) / (5.5 - 1.6)
	assert_almost_eq(b.y, 3.2 / lerpf(1.131, 4.451, t), 0.01)


func test_standing_is_idle() -> void:
	assert_eq(_animator().loco_blend(0.0), Vector2(0.0, 1.0))


func test_feyre_gets_the_tree_and_animator() -> void:
	var feyre := (load("res://characters/feyre/feyre.tscn") as PackedScene).instantiate() as Feyre
	add_child_autofree(feyre)
	var a := feyre.model.find_child("FeyreAnimator", true, false) as FeyreAnimator
	assert_not_null(a)
	assert_not_null(a.tree)
	assert_true(a.tree.active)
	assert_almost_eq(float(a.gait_points[&"sprint"]), feyre.sprint_speed, 0.001)
