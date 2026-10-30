extends GutTest


class TwoStep:
	extends SceneSpace

	func _build_beats() -> Array:
		return [
			Beats.control(StoryControl.Mode.LOOK, self),
			Beats.wait(1.0),
			Beats.decision([{"action": &"interact", "fact": "fact.test.took_knife"}], 2.0, "fact.test.froze"),
			Beats.raise("fact.test.scene_done"),
		]


var space: TwoStep


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	space = TwoStep.new()
	space.auto_tick = false
	space.space_id = &"two_step"
	space.done_flags = PackedStringArray(["fact.test.scene_done"])
	add_child_autofree(space)


func after_each() -> void:
	StoryControl.release()


func test_limits_control_then_releases_it() -> void:
	assert_true(space.start())
	assert_eq(StoryControl.mode, StoryControl.Mode.LOOK)
	assert_eq(StoryControl.focus, space)
	assert_false(StoryControl.can_move())
	space.tick(1.1)
	space.choose(&"interact")
	space.tick(0.1)
	assert_false(space.running)
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL)
	assert_null(StoryControl.focus)


func test_decision_records_the_choice_through_a_trigger() -> void:
	space.start()
	space.tick(1.1)
	space.choose(&"interact")
	space.tick(0.1)
	assert_true(WorldState.has_flag("fact.test.took_knife"))
	assert_false(WorldState.has_flag("fact.test.froze"))
	assert_true(WorldState.has_flag("fact.test.scene_done"))
	assert_not_null(space.get_node_or_null(^"Raise_fact_test_took_knife"), "raised by an ActionTrigger")


func test_decision_times_out_to_the_default() -> void:
	space.start()
	space.tick(1.1)
	space.tick(2.1)
	assert_true(WorldState.has_flag("fact.test.froze"))


func test_done_flag_prevents_replay() -> void:
	space.start()
	space.tick(5.0)
	space.tick(5.0)
	assert_false(space.can_start())
	assert_false(space.start())


func test_state_visibility_follows_flags() -> void:
	var broken := StateVisibility.new()
	broken.show_when_flag = "fact.test.door_broken"
	var whole := StateVisibility.new()
	whole.hide_when_flag = "fact.test.door_broken"
	add_child_autofree(broken)
	add_child_autofree(whole)
	assert_false(broken.visible)
	assert_true(whole.visible)
	WorldState.raise_deed("fact.test.door_broken")
	assert_true(broken.visible)
	assert_false(whole.visible)
