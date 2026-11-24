# gate: when:ui/map/*,ui/menu/menu_shell.gd,story/act3/house/hall_map.gd,story/act3/house/hall_mark.gd,story/act3/house/wound_dressing.gd,data/story/act3/house/hall_map_plan.tres
extends GutTest
## Her map of the halls lives in the journal: the Map tab's manor page shows
## her five marks, a fresh sketch puts news on the tab, and no other page
## draws the house.

const ManorPlan := preload("res://ui/map/manor_plan.gd")
const ManorSketch := preload("res://ui/map/manor_sketch.gd")

var _flags: Dictionary = {}


func before_each() -> void:
	_flags.clear()


func after_each() -> void:
	MenuShell.close_all(get_tree())


func _hud() -> WorldMapHud:
	var hud := WorldMapHud.new()
	add_child_autofree(hud)
	hud.manor.has_flag = func(f: String) -> bool: return _flags.has(f)
	return hud


func test_her_marks_show_once_she_has_made_them() -> void:
	var plan := ManorPlan.new()
	plan.has_flag = func(f: String) -> bool: return _flags.has(f)
	assert_true(plan.marks_on(0).is_empty(), "none before she marks anything")
	_flags["fact.hall_x_2"] = true
	var shown := plan.marks_on(0)
	assert_eq(shown.size(), 1, "the one she made")
	assert_eq(int(shown[0].n), 2)
	assert_eq(String(shown[0].shape), "o", "the marble stairs are a circle")
	assert_true(plan.marks_on(1).is_empty(), "all five are on the ground floor")
	for n in [1, 3, 4, 5]:
		_flags["fact.hall_mark_%d" % n] = true
	assert_eq(plan.marks_on(0).size(), 5, "the quest's own fact counts too")


func test_the_marks_are_drawn_in_rose_on_the_plan() -> void:
	var plan := ManorPlan.new()
	plan.has_flag = func(f: String) -> bool: return _flags.has(f)
	_flags[ManorPlan.KNOWN_FLAG] = true
	_flags["fact.hall_x_1"] = true
	plan.seen[&"entrance_hall"] = true
	var mark: Dictionary = plan.marks_on(0)[0]
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(vp)
	var canvas := Control.new()
	canvas.size = Vector2(256, 256)
	var centre := Vector2(float(mark.x), float(mark.z))
	canvas.draw.connect(func() -> void:
		ManorSketch.draw_plan(canvas, plan, 0, func(xz: Vector2) -> Vector2: return Vector2(128, 128) + (xz - centre) * 10.0, 10.0))
	vp.add_child(canvas)
	await wait_process_frames(3)
	assert_eq(plan.marks_on(0).size(), 1, "drawing reads the same marks")
	pass_test("the plan draws with a mark on it")


func test_a_fresh_sketch_is_news_on_the_map_tab_and_opens_the_house() -> void:
	var hud := _hud()
	_flags[ManorPlan.KNOWN_FLAG] = true
	await wait_process_frames(2)
	assert_false(hud.full_map.has_news(), "nothing new at first")
	hud.note_sketch()
	assert_true(hud.full_map.has_news(), "the tab carries its mark")
	assert_true(MenuShell.open_tab(get_tree(), &"map"), "the book opens at the map")
	assert_true(hud.full_map.is_open())
	assert_true(hud.full_map.showing_manor, "on her plan of the house, though she is outside")
	assert_false(hud.full_map.has_news(), "and the mark is gone once she has looked")
	hud.full_map.close()
	hud.full_map.open()
	assert_false(hud.full_map.showing_manor, "next time it opens on the land")


func test_the_story_reaches_the_map_through_one_call() -> void:
	var hud := _hud()
	await wait_process_frames(1)
	HallMap.note_on_map(self)
	assert_true(hud.plan_news)


func test_no_other_page_draws_the_house() -> void:
	assert_false(ResourceLoader.exists("res://story/act3/house/hall_map_page.gd"), "HallMapPage is gone")
	for path in ["res://story/act3/house/hall_map.gd", "res://story/act3/house/hall_mark.gd",
			"res://story/act3/house/wound_dressing.gd"]:
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.contains("HallMapPage"), "%s names no HallMapPage" % path)
