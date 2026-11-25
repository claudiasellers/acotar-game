## Contract for the bow's shot cycle and Focus (plans/combat/bow-combat-design.md
## §13 B1). Fire alone raises the bow and draws; letting go looses, weaker the
## earlier it is let go; aim is an optional steadier, closer view; the bow
## stays up a moment after a draw for the next arrow; Focus slows the world
## through TimeScale only while held, at a known stamina cost. Drives the bow's
## own code (update_bow), never a key or button.
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


func test_left_mouse_alone_raises_draws_and_shoots() -> void:
	var before := Gameplay.inventory.arrow_count()
	assert_false(bow.is_aiming, "the bow is down")
	assert_null(_tick(false, true), "the press looses nothing")
	assert_true(bow.is_aiming and bow.is_nocked and bow.is_drawing, "it is up, nocked and drawing on the press")
	assert_false(bow.is_precise, "without aim held it is a shot from the hip")
	assert_null(_hold(bow.bow.draw_time + 0.05, false, true))
	var arrow := _tick(false, false)
	assert_not_null(arrow, "letting go shoots, with aim never touched")
	assert_eq(Gameplay.inventory.arrow_count(), before - 1)
	if arrow:
		assert_almost_eq(arrow.linear_velocity.length(), bow.bow.max_speed, 0.01, "a full draw is full power")
	assert_true(bow.is_up(), "and the bow stays in her hands for the next one")
	assert_false(bow.is_aiming, "though nothing is held")


func test_an_early_release_is_a_weaker_arrow_never_nothing() -> void:
	watch_signals(bow)
	_hold(bow.bow.draw_time * 0.3, false, true)
	var drawn := bow.draw_amount
	assert_between(drawn, 0.2, 0.4)
	var arrow := _tick(false, false)
	assert_not_null(arrow, "it flies")
	assert_signal_not_emitted(bow, "let_down")
	assert_signal_emitted(bow, "loosed_short")
	if arrow:
		assert_almost_eq(arrow.linear_velocity.length(), bow.bow.max_speed * bow.power(drawn), 0.01)
		assert_lt(arrow.linear_velocity.length(), bow.bow.max_speed * 0.7, "well short of full power")


func test_power_runs_from_the_floor_to_full_with_the_draw() -> void:
	assert_eq(bow.power(0.0), bow.tuning.min_power)
	assert_eq(bow.power(1.0), 1.0)
	assert_gt(bow.power(0.6), bow.power(0.3))
	# The quickest click there is still shoots.
	_tick(false, true)
	var arrow := _tick(false, false)
	assert_not_null(arrow, "one tick of fire is a shot")
	if arrow:
		assert_almost_eq(arrow.linear_velocity.length(), bow.bow.max_speed * bow.tuning.min_power, bow.bow.max_speed * 0.08)


func test_right_mouse_is_precision_not_a_gate() -> void:
	_hold(0.2, true, false)
	assert_true(bow.is_aiming and bow.is_precise and bow.is_nocked)
	assert_false(bow.is_drawing, "aim alone draws nothing")
	var precise := bow.sway_degrees()
	_tick(false, false)
	_tick(false, true)
	bow._settle = 1.0
	var hip := bow.sway_degrees()
	_tick(true, true)
	bow._settle = 1.0
	assert_almost_eq(hip, bow.sway_degrees() * bow.tuning.hip_sway, 0.001, "from the hip the ring is wider")
	assert_gt(precise, 0.0)
	assert_eq(bow.fov_offset(), bow.tuning.fov_raised, "aim held narrows the view")
	_tick(false, true)
	assert_eq(bow.fov_offset(), 0.0, "the hip does not")


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


func test_letting_go_of_aim_mid_draw_takes_the_shot_back() -> void:
	watch_signals(bow)
	var before := Gameplay.inventory.arrow_count()
	_hold(0.2, true, false)
	_hold(bow.bow.draw_time + 0.1, true, true)
	assert_null(_tick(false, true), "letting go of aim with the string held is a cancel")
	assert_signal_emitted(bow, "let_down")
	assert_false(bow.is_aiming, "the bow comes down")
	assert_null(_hold(0.3, false, true), "and that press of fire is spent")
	assert_null(_hold(0.1, false, false))
	assert_eq(fired.size(), 0)
	assert_eq(Gameplay.inventory.arrow_count(), before, "the arrow is still hers")
	_hold(bow.bow.draw_time + 0.05, false, true)
	assert_not_null(_tick(false, false), "a fresh press shoots again")


func test_a_draw_from_the_hip_is_not_cancelled_by_aim_it_never_had() -> void:
	_hold(bow.bow.draw_time + 0.05, false, true)
	assert_null(_tick(false, true))
	assert_true(bow.is_drawing, "still drawn: aim was never part of it")
	assert_not_null(_tick(false, false))


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


func test_a_bow_raised_only_to_aim_comes_down_with_the_aim() -> void:
	_hold(0.3, true, false)
	assert_true(bow.is_up())
	_tick(false, false)
	assert_false(bow.is_up(), "no draw, no shot: nothing keeps it up")


func test_after_a_shot_the_bow_stays_up_for_the_next_arrow() -> void:
	_hold(0.3, false, true)
	_tick(false, false)
	assert_eq(fired.size(), 1)
	assert_true(bow.is_up(), "up for the follow-up")
	assert_false(bow.is_aiming, "but she is not aiming")


func test_stowed_the_bow_comes_down_and_stays_down() -> void:
	_hold(0.4, true, true, true)
	assert_true(bow.is_focused)
	bow.stow(true)
	_tick(true, true, true)
	assert_false(bow.is_up(), "down")
	assert_false(bow.is_drawing)
	assert_false(bow.is_focused, "the hush ends")
	assert_false(TimeScale.is_requested(BowController.SLOW_ID), "and time is let go")
	_hold(1.5, false, true)
	_tick(false, false)
	assert_eq(fired.size(), 0, "nothing is loosed from the saddle")
	bow.stow(false)
	_hold(0.3, false, true)
	_tick(false, false)
	assert_eq(fired.size(), 1, "hers again")


func test_a_scene_that_allows_the_fire_button_has_not_handed_her_the_bow() -> void:
	StoryControl.hold(self, StoryControl.Mode.LOOK, PackedStringArray(["fire"]))
	_hold(1.5, false, true)
	_tick(false, false)
	assert_eq(fired.size(), 0, "the bracelets' button looses no arrow")
	assert_false(bow.is_up())
	StoryControl.release(self)
	StoryControl.hold(self, StoryControl.Mode.LOOK, PackedStringArray(["shoot"]))
	_hold(0.3, false, true)
	_tick(false, false)
	assert_eq(fired.size(), 1, "a scene that says shoot does")
	StoryControl.release(self)


func test_select_arrow_puts_it_on_the_string_and_says_so() -> void:
	Gameplay.inventory.add(&"arrow_ash", 1)
	watch_signals(bow)
	bow.select_arrow(&"arrow_ash")
	assert_eq(bow.selected, &"arrow_ash")
	assert_signal_emitted_with_parameters(bow, "arrow_type_changed", [&"arrow_ash"])
