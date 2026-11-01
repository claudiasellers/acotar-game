## A caption never outlives its scene (L24-10): it clears when the scene that
## spoke it finishes or leaves the tree, on a phase change, on a load and on a
## dev jump, and it steps aside while a menu pauses the tree.
extends GutTest

var caption: Act2Caption


func before_each() -> void:
	Act2Caption.clear_all(get_tree())
	get_tree().paused = false


func after_each() -> void:
	get_tree().paused = false
	Act2Caption.clear_all(get_tree())


func _space(id: StringName) -> SceneSpace:
	var s := SceneSpace.new()
	s.space_id = id
	add_child_autofree(s)
	return s


func test_line_clears_when_its_scene_finishes() -> void:
	var s := _space(&"caption_test_a")
	caption = Act2Caption.find_or_make(s)
	caption.say("Tamlin", "The table. Clear it off!", 30.0)
	assert_eq(caption.showing, "The table. Clear it off!")
	EventBus.scene_space_finished.emit(&"some_other_scene")
	assert_ne(caption.showing, "", "another scene ending leaves it")
	EventBus.scene_space_finished.emit(&"caption_test_a")
	assert_eq(caption.showing, "", "its own scene ending clears it")


func test_line_clears_when_its_scene_leaves_the_tree() -> void:
	var s := _space(&"caption_test_b")
	caption = Act2Caption.find_or_make(s)
	caption.say("", "A thought.", 30.0)
	remove_child(s)
	assert_eq(caption.showing, "")
	s.free()


func test_child_node_speaks_for_its_scene() -> void:
	var s := _space(&"caption_test_c")
	var prop := Node3D.new()
	s.add_child(prop)
	caption = Act2Caption.find_or_make(prop)
	caption.say("Lucien", "Polite.", 30.0)
	EventBus.scene_space_finished.emit(&"caption_test_c")
	assert_eq(caption.showing, "")


func test_phase_change_load_and_dev_jump_clear_it() -> void:
	caption = Act2Caption.find_or_make(self)
	caption.say("Tamlin", "One.", 30.0)
	EventBus.phase_changed.emit(&"p3_house", &"p4_studio")
	assert_eq(caption.showing, "", "phase change")
	caption.say("Tamlin", "Two.", 30.0)
	EventBus.game_loaded.emit("test")
	assert_eq(caption.showing, "", "load")
	caption.say("Tamlin", "Three.", 30.0)
	Act2Caption.clear_all(get_tree())
	assert_eq(caption.showing, "", "dev jump")


func test_line_still_times_out_and_hides_under_a_paused_menu() -> void:
	caption = Act2Caption.find_or_make(self)
	caption.say("", "Short.", 0.2)
	get_tree().paused = true
	caption._process(1.0)
	assert_false(caption.visible, "hidden while a menu pauses the tree")
	assert_eq(caption.showing, "Short.", "its clock waits under the menu")
	get_tree().paused = false
	caption._process(0.0)
	assert_true(caption.visible)
	await wait_seconds(0.5)
	assert_eq(caption.showing, "", "times out once play resumes")
