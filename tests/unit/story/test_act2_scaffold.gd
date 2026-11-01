## Act II scaffold contract (docs/contracts/act2.md): the registry builds
## coded scenes that keep their moment's gates, stage marks follow the anchor,
## lines play as timed beats, and deeds come only from ActionTriggers.
extends GutTest

var root: Node3D
var feyre: Node3D


class ProbeSpace:
	extends Act2Space

	func _build_beats() -> Array:
		return [
			say(&"hello"),
			reach(&"door", 1.0),
			Beats.until(func() -> bool: return presses() >= 1, "until E"),
			Beats.raise("first_dinner_eaten"),
		]


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	root = Node3D.new()
	add_child_autofree(root)
	feyre = Node3D.new()
	feyre.add_to_group(&"player")
	root.add_child(feyre)


func after_each() -> void:
	StoryControl.release()


func _stage() -> Act2Stage:
	var stage := Act2Stage.new()
	stage.marks = {&"door": Vector3(0, 0, -4), &"seat": Vector3(2, 0, 0)}
	stage.lines = {&"hello": {"who": "Tamlin", "text": "Sit. Eat."}}
	stage.extra_require = PackedStringArray(["fact.alis_bathed"])
	return stage


func _probe(moment: StoryMoment = null) -> ProbeSpace:
	var space := ProbeSpace.new()
	space.moment = moment if moment else StoryDirector.get_moment(&"first_dinner")
	space.stage = _stage()
	space.auto_tick = false
	space.position = Vector3(10, 0, 10)
	space.rotation.y = PI * 0.5
	root.add_child(space)
	return space


func test_registry_rows_build_act2_spaces_with_stages() -> void:
	for id in Act2Spaces.CODED:
		var moment := StoryDirector.get_moment(StringName(id))
		assert_not_null(moment, "%s is a data moment" % id)
		var space := Act2Spaces.space_for(moment)
		assert_true(space is Act2Space, "%s is coded" % id)
		assert_not_null((space as Act2Space).stage, "%s has a stage" % id)
		space.free()
	for anchor_id in Act2Spaces.EXTRA:
		for spec: Dictionary in Act2Spaces.EXTRA[anchor_id]:
			var space := Act2Spaces._make(spec)
			assert_true(space is Act2Space, "%s builds" % spec["name"])
			space.free()
	pass_test("every registry row builds")


func test_uncoded_moments_stay_generic() -> void:
	var moment := StoryDirector.get_moment(&"wound_dressing")
	assert_null(Act2Spaces.space_for(moment))
	var space := StoryDirector._space_for(moment)
	assert_true(space is MomentSpace)
	space.free()


func test_gates_come_from_the_moment_plus_the_stage() -> void:
	var space := _probe()
	assert_true(space.require_flags.has("wall_crossed"), "the moment's gate")
	assert_true(space.require_flags.has("fact.alis_bathed"), "the stage's extra gate")
	assert_eq(space.done_flags, PackedStringArray(["first_dinner_eaten"]))
	WorldState.set_flag("wall_crossed")
	assert_false(space.can_start())
	WorldState.set_flag("fact.alis_bathed")
	assert_true(space.can_start())


func test_marks_follow_the_anchor() -> void:
	var space := _probe()
	var door := space.mark(&"door")
	# Turned a quarter: the anchor's -Z (forward) points at world -X.
	assert_almost_eq(door.x, 6.0, 0.01)
	assert_almost_eq(door.z, 10.0, 0.01)
	assert_eq(space.mark(&"missing"), space.global_position)


func test_cast_builds_fallbacks_and_dismiss_frees_them() -> void:
	var space := _probe()
	var alis := space.cast(&"alis", &"seat", &"door")
	assert_not_null(alis)
	assert_true(space.is_ancestor_of(alis), "the fallback hangs under the scene")
	assert_almost_eq(alis.global_position.distance_to(space.mark(&"seat")), 0.0, 0.01)
	assert_eq(space.actor(&"alis"), alis)
	space.dismiss(&"alis")
	assert_null(space.actor(&"alis"))


func test_scene_plays_lines_waits_for_feyre_and_raises_through_a_trigger() -> void:
	WorldState.set_flag("wall_crossed")
	WorldState.set_flag("fact.alis_bathed")
	var space := _probe()
	feyre.global_position = Vector3(30, 0, 30)
	assert_true(space.start())
	assert_eq(space.current_beat_label(), "say hello")
	for _i in 60:
		space.tick(0.1)
	assert_eq(space.current_beat_label(), "reach door", "the line ran its reading time")
	feyre.global_position = space.mark(&"door")
	space.tick(0.1)
	assert_eq(space.current_beat_label(), "until E")
	space.press_interact()
	space.tick(0.1)
	assert_false(space.running)
	assert_true(WorldState.has_flag("first_dinner_eaten"))
	assert_not_null(space.get_node_or_null(^"Raise_first_dinner_eaten") as ActionTrigger, "raised by an ActionTrigger")
	assert_false(space.can_start(), "never replays")


func test_director_hangs_extra_scenes_once() -> void:
	for anchor_id in Act2Spaces.EXTRA:
		var anchor := Marker3D.new()
		anchor.name = String(anchor_id)
		anchor.add_to_group(&"story_anchor")
		root.add_child(anchor)
		var first := StoryDirector.attach_anchor(anchor).size()
		var count := anchor.get_child_count()
		assert_eq(StoryDirector.attach_anchor(anchor).size(), first)
		assert_eq(anchor.get_child_count(), count, "attaching twice adds nothing")
	pass_test("every extra anchor attaches idempotently")
