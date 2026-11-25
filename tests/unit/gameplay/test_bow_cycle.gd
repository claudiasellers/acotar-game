## Contract for the bow's shot cycle and Focus (plans/combat/bow-combat-design.md
## §13 B1). Hold fire to draw, release at full draw to loose; an early release
## lets the string down; the bow stays raised and nocks again after the
## follow-through; Focus slows the world through TimeScale only while held, at
## a known stamina cost. The old click-to-fire bow is gone, not optional.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")
const TICK := 1.0 / 60.0

var hill: Node3D
var feyre: Feyre
var bow: BowController
var fired: Array[Arrow] = []


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	StoryControl.release()
	TimeScale.reset()
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	bow = feyre.bow_controller
	# The test drives the bow tick by tick; her own tick would read real input.
	bow.set_physics_process(false)
	Gameplay.inventory.add(&"arrow_wood", 8)
	fired = []
	feyre.arrow_fired.connect(func(a: Arrow) -> void: fired.append(a))
	await wait_physics_frames(10)
	_calm()


func after_each() -> void:
	for action in [&"aim", &"fire", &"focus", &"sprint", &"move_forward"]:
		Input.action_release(action)
	StoryControl.release()
	TimeScale.reset()


## A rested, warm, fed Feyre, so the numbers are the bow's own.
func _calm() -> void:
	feyre.body_state.hunger = 0.0
	feyre.body_state.cold = 0.0
	feyre.body_state.fae_toll = 0.0
	feyre.vitals.dread = 0.0
	feyre.stamina = feyre.max_stamina
	feyre._exhausted = false


## One tick of `real` seconds on the clock the player feels.
func _tick(aim: bool, fire: bool, focus: bool = false, real: float = TICK) -> Arrow:
	return bow.update_bow(real * Engine.time_scale, aim, fire, focus)


## Ticks for `seconds` of real time; returns the first arrow loosed.
func _hold(seconds: float, aim: bool, fire: bool, focus: bool = false) -> Arrow:
	var got: Arrow = null
	for i in roundi(seconds / TICK):
		var arrow := _tick(aim, fire, focus)
		if got == null:
			got = arrow
	return got


func test_hold_to_full_draw_and_release_looses_one_full_power_arrow() -> void:
	var before := Gameplay.inventory.arrow_count()
	assert_null(_hold(0.2, true, false), "raising the bow looses nothing")
	assert_true(bow.is_aiming and bow.is_nocked, "raised, with an arrow on the string")
	assert_false(bow.is_drawing, "the string is not drawn until fire is held")
	assert_null(_hold(bow.bow.draw_time + 0.05, true, true), "holding the draw looses nothing")
	assert_almost_eq(bow.draw_amount, 1.0, 0.001, "a full draw")
	var arrow := _tick(true, false)
	assert_not_null(arrow, "letting go at full draw looses")
	assert_eq(Gameplay.inventory.arrow_count(), before - 1)
	if arrow:
		assert_almost_eq(arrow.linear_velocity.length(), bow.bow.max_speed, 0.01, "at full power")


func test_an_early_release_lets_the_string_down_and_keeps_the_arrow() -> void:
	watch_signals(bow)
	var before := Gameplay.inventory.arrow_count()
	_hold(0.2, true, false)
	var early := bow.bow.draw_time - bow.tuning.release_buffer_s - 0.05
	_hold(early, true, true)
	assert_null(_hold(0.5, true, false), "no weak shot")
	assert_signal_emitted(bow, "let_down")
	assert_eq(fired.size(), 0)
	assert_eq(Gameplay.inventory.arrow_count(), before, "the arrow is still hers")
	assert_true(bow.is_aiming, "and the bow is still up")


func test_a_release_just_short_of_full_draw_still_looses_at_full_draw() -> void:
	_hold(0.2, true, false)
	var held := bow.bow.draw_time - bow.tuning.release_buffer_s + 0.03
	_hold(held, true, true)
	assert_lt(bow.draw_amount, 1.0)
	var waited := 0.0
	var arrow: Arrow = null
	while arrow == null and waited < 0.5:
		arrow = _tick(true, false)
		waited += TICK
	assert_not_null(arrow, "the buffered release looses")
	assert_almost_eq(held + waited, bow.bow.draw_time, 0.04, "the moment the draw is full, not before")
	if arrow:
		assert_almost_eq(arrow.linear_velocity.length(), bow.bow.max_speed, 0.01)


func test_the_bow_stays_raised_and_the_second_arrow_follows_in_time() -> void:
	_hold(0.2, true, false)
	_hold(bow.bow.draw_time + 0.02, true, true)
	assert_not_null(_tick(true, false), "the first arrow")
	assert_true(bow.is_aiming, "the bow stays up after a shot")
	var since := 0.0
	var second: Arrow = null
	while second == null and since < 2.0:
		# Fire held again at once; she lets go the tick the draw is full.
		second = _tick(true, bow.draw_amount < 1.0)
		since += TICK
	assert_not_null(second, "a second arrow without lowering the bow")
	assert_almost_eq(since, bow.tuning.follow_through_s + bow.bow.draw_time, 0.05,
		"follow-through then a full draw (0.55 s on the hunting bow)")
	assert_eq(fired.size(), 2)


func test_lowering_the_bow_mid_draw_looses_nothing() -> void:
	_hold(0.2, true, false)
	_hold(bow.bow.draw_time + 0.1, true, true)
	assert_null(_tick(false, true), "letting go of aim is a cancel")
	assert_null(_hold(0.3, false, false))
	assert_eq(fired.size(), 0)


func test_focus_slows_the_world_only_while_held_and_nocked() -> void:
	_hold(0.1, false, false, true)
	assert_eq(Engine.time_scale, 1.0, "Focus does nothing with the bow down")
	_hold(0.3, true, false, true)
	assert_true(bow.is_focused)
	assert_eq(Engine.time_scale, bow.tuning.focus_scale, "the hush")
	assert_true(TimeScale.is_requested(BowController.SLOW_ID))
	_tick(true, false, false)
	assert_false(bow.is_focused)
	assert_eq(Engine.time_scale, 1.0, "time runs the moment Focus is let go")
	Gameplay.inventory.remove(&"arrow_wood", 1000)
	_hold(0.3, true, false, true)
	assert_eq(Engine.time_scale, 1.0, "nothing on the string, nothing to steady")


func test_focus_costs_28_a_second_and_half_again_in_full_dread() -> void:
	_hold(0.2, true, false)
	var before := feyre.stamina
	_hold(1.0, true, false, true)
	assert_almost_eq(before - feyre.stamina, 28.0, 0.5, "28 stamina per real second")
	_tick(true, false)
	_calm()
	feyre.vitals.dread = 1.0
	before = feyre.stamina
	_hold(1.0, true, false, true)
	assert_almost_eq(before - feyre.stamina, 42.0, 0.75, "42 at full dread")


func test_focus_from_full_lasts_3_6_seconds_then_waits_for_her_breath() -> void:
	feyre.max_stamina = 100.0
	feyre.stamina = 100.0
	_hold(0.2, true, false)
	var lasted := 0.0
	_tick(true, false, true)
	while bow.is_focused and lasted < 10.0:
		_tick(true, false, true)
		lasted += TICK
	assert_almost_eq(lasted, 3.6, 0.1, "100 stamina of Focus")
	assert_eq(Engine.time_scale, 1.0)
	assert_true(feyre.is_winded())
	_tick(true, false, false)
	feyre.stamina = 30.0
	feyre._update_stamina(0.0)
	_hold(0.2, true, false, true)
	assert_false(bow.is_focused, "winded: no Focus below 35%")
	_tick(true, false, false)
	feyre.stamina = 40.0
	feyre._update_stamina(0.0)
	_hold(0.2, true, false, true)
	assert_true(bow.is_focused, "her breath is back")


func test_focus_holds_a_moment_after_the_shot_then_needs_a_fresh_press() -> void:
	_hold(0.2, true, false, true)
	_hold(bow.bow.draw_time + 0.02, true, true, true)
	assert_not_null(_tick(true, false, true), "loosed in the hush")
	assert_true(bow.is_focused, "the hush holds so she sees the arrow leave")
	_hold(bow.tuning.focus_hold_after_release_s + 0.05, true, false, true)
	assert_false(bow.is_focused, "then it ends, though the key is still down")
	assert_eq(Engine.time_scale, 1.0)
	_tick(true, false, false)
	_hold(0.1, true, false, true)
	assert_true(bow.is_focused, "a fresh press brings it back")


func test_a_blow_breaks_focus() -> void:
	_hold(0.3, true, false, true)
	assert_true(bow.is_focused)
	EventBus.player_hit.emit(&"test", &"bite", 1.0, Vector3.ZERO)
	assert_false(bow.is_focused)
	assert_false(TimeScale.is_requested(BowController.SLOW_ID), "the hush is gone; only the hit-stop holds time now")


## Shift and L3 are sprint and Focus both: with the bow raised they are Focus,
## and she neither sprints nor stands up from her crouch.
func test_the_sprint_key_is_focus_while_the_bow_is_raised() -> void:
	bow.set_physics_process(true)
	feyre.crouch.set_crouched(true)
	Input.action_press(&"aim")
	await wait_physics_frames(12)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	Input.action_press(&"focus")
	await wait_physics_frames(12)
	assert_true(bow.is_aiming)
	assert_false(feyre.is_running(), "no sprint with the bow up")
	assert_true(feyre.crouch.crouched, "and she stays in her crouch")
	assert_true(bow.is_focused, "the key is Focus here")


func _wheel(button: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = Vector2(320, 240)
	e.global_position = e.position
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func test_the_mouse_wheel_changes_arrows_only_while_raised() -> void:
	Gameplay.inventory.add(&"arrow_ash", 1)
	bow.selected = &"arrow_wood"
	_tick(false, false)
	_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await wait_physics_frames(2)
	assert_eq(bow.selected, &"arrow_wood", "the wheel is free when the bow is down")
	_tick(true, false)
	_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await wait_physics_frames(2)
	assert_eq(bow.selected, &"arrow_ash", "raised, it chooses the arrow")
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	await wait_physics_frames(2)
	assert_eq(bow.selected, &"arrow_wood", "and back")


func _pad_buttons(action: StringName) -> Array[int]:
	var out: Array[int] = []
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			out.append((e as InputEventJoypadButton).button_index)
	return out


func test_the_bow_actions_live_in_the_input_map() -> void:
	for action in [&"focus", &"cycle_arrow", &"arrow_next", &"arrow_prev", &"cycle_bow", &"craft_arrow"]:
		assert_true(ProjectSettings.has_setting("input/%s" % action), "%s is in project.godot" % action)
	assert_eq(_pad_buttons(&"cycle_arrow"), [JOY_BUTTON_DPAD_LEFT] as Array[int], "arrows on D-pad left")
	assert_eq(_pad_buttons(&"cycle_bow"), [JOY_BUTTON_DPAD_RIGHT] as Array[int], "bows on D-pad right")


## One version of the bow: none of the old one's parts are left, and only
## TimeScale writes Engine.time_scale.
func test_the_old_bow_is_gone() -> void:
	var source := FileAccess.get_file_as_string("res://systems/bow/bow_controller.gd")
	for gone in ["Engine.time_scale =", "_spent", "_fire_queued", "_fire_pressed", "_ensure_actions",
			"SLOW_TIME", "_apply_sway", "nock_time", "const TUNING_"]:
		assert_false(source.contains(gone), "%s is gone from the bow" % gone)
	assert_true(BowController.TUNING is BowTuning, "the feel numbers load from data/bows/bow_tuning.tres")
	for file in DirAccess.get_files_at("res://systems/bow"):
		if file.ends_with(".gd"):
			assert_false(FileAccess.get_file_as_string("res://systems/bow/" + file).contains("Engine.time_scale ="),
				"%s leaves the clock to TimeScale" % file)
