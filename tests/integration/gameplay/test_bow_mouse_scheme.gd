## T096 contract: the bow on mouse, as the owner plays it. Hold right mouse to
## raise the bow and aim; a left click while it is up looses one arrow; letting
## go lowers it and looses nothing. After a shot the bow comes down and needs a
## fresh right-mouse press. Q cycles the arrow types she has. Driven by real
## InputEventMouseButton / InputEventKey events through Feyre's controller.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")

var hill: Node3D
var feyre: Feyre
var fired: Array = []


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	StoryControl.release()
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	fired = []
	feyre.arrow_fired.connect(func(a: Arrow) -> void: fired.append(a))
	await wait_physics_frames(10)


func after_each() -> void:
	_mouse(MOUSE_BUTTON_LEFT, false)
	_mouse(MOUSE_BUTTON_RIGHT, false)
	Input.action_release(&"aim")
	Input.action_release(&"fire")
	StoryControl.release()
	Engine.time_scale = 1.0


func _mouse(button: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = Vector2(320, 240)
	e.global_position = e.position
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()


func _raised() -> bool:
	return feyre.is_aiming or feyre.bow_controller.is_drawing


## Right mouse held, then a quick left click (down and up inside one frame).
func _aim_and_click(hold_frames: int = 20) -> void:
	_mouse(MOUSE_BUTTON_RIGHT, true)
	await wait_physics_frames(hold_frames)
	_mouse(MOUSE_BUTTON_LEFT, true)
	_mouse(MOUSE_BUTTON_LEFT, false)
	await wait_physics_frames(2)


func test_right_held_and_a_left_click_looses_exactly_one_arrow() -> void:
	var before := Gameplay.inventory.arrow_count()
	await _aim_and_click()
	assert_eq(fired.size(), 1, "one click, one arrow")
	assert_eq(Gameplay.inventory.arrow_count(), before - 1)
	await wait_physics_frames(10)
	assert_eq(fired.size(), 1, "and only one")


func test_a_quick_click_right_after_raising_still_fires() -> void:
	await _aim_and_click(2)
	assert_eq(fired.size(), 1, "a click while the bow is up always fires")


func test_letting_go_of_right_mouse_lowers_the_bow_and_fires_nothing() -> void:
	var before := Gameplay.inventory.arrow_count()
	_mouse(MOUSE_BUTTON_RIGHT, true)
	await wait_physics_frames(30)
	assert_true(_raised(), "right mouse raises the bow")
	_mouse(MOUSE_BUTTON_RIGHT, false)
	await wait_physics_frames(3)
	assert_false(_raised(), "letting go lowers it")
	assert_eq(fired.size(), 0, "no arrow")
	assert_eq(Gameplay.inventory.arrow_count(), before)
	assert_eq(Engine.time_scale, 1.0, "time runs again")


func test_left_mouse_alone_does_not_shoot() -> void:
	_mouse(MOUSE_BUTTON_LEFT, true)
	await wait_physics_frames(40)
	_mouse(MOUSE_BUTTON_LEFT, false)
	await wait_physics_frames(3)
	assert_eq(fired.size(), 0, "the bow is down: no arrow")
	assert_false(_raised())


func test_after_a_shot_the_bow_lowers_until_a_fresh_right_press() -> void:
	await _aim_and_click()
	assert_eq(fired.size(), 1)
	await wait_physics_frames(3)
	assert_false(_raised(), "the bow comes down after the shot, right mouse still held")
	assert_false(feyre.bow_controller.visual.wants_raised(), "the bow model lowers too")
	_mouse(MOUSE_BUTTON_LEFT, true)
	_mouse(MOUSE_BUTTON_LEFT, false)
	await wait_physics_frames(3)
	assert_eq(fired.size(), 1, "clicking with the bow down does nothing")
	_mouse(MOUSE_BUTTON_RIGHT, false)
	await wait_physics_frames(2)
	await _aim_and_click()
	assert_eq(fired.size(), 2, "a fresh right press raises it and the next click fires")


func test_ten_aim_and_shoot_cycles_all_fire() -> void:
	var before := Gameplay.inventory.arrow_count()
	assert_gte(before, 10, "the hill gives her enough arrows")
	for i in 10:
		await _aim_and_click(8 + i % 3 * 6)
		_mouse(MOUSE_BUTTON_RIGHT, false)
		await wait_physics_frames(2)
		assert_eq(fired.size(), i + 1, "cycle %d fired" % (i + 1))
	assert_eq(Gameplay.inventory.arrow_count(), before - 10)


func test_q_cycles_the_arrow_types_she_has_and_skips_empty_ones() -> void:
	var bow := feyre.bow_controller
	var types := BowController.arrow_types()
	assert_gte(types.size(), 3, "at least three arrow types exist")
	var have: Array[StringName] = [types[0], types[types.size() - 1]]
	for t in types:
		Gameplay.inventory.remove(t, 1000)
	for t in have:
		Gameplay.inventory.add(t, 2)
	bow.selected = have[0]
	_key(KEY_Q)
	assert_eq(bow.selected, have[1], "Q skips the types she has none of")
	_key(KEY_Q)
	assert_eq(bow.selected, have[0], "and wraps round")
	assert_true(bow.quiver_card._panel.visible, "the quiver card names the arrow")
	_key(KEY_Q)
	await _aim_and_click()
	assert_eq(fired.size(), 1)
	if not fired.is_empty():
		assert_eq((fired[0] as Arrow).data.item_id, have[1], "the chosen type flies")
