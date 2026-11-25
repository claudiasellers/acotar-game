## Contract for the bow's aim and sway (plans/combat/bow-combat-design.md §13
## B2): calm, the arrow goes exactly to the crosshair, however she moves or
## turns; sway is her body failing her (a draw held too long, low breath, cold
## or hurt), by the doc's amounts; the crosshair and the arrow share it; Focus
## steadies it.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")
const TICK := 1.0 / 60.0

var hill: Node3D
var feyre: Feyre
var bow: BowController


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
	bow.set_physics_process(false)
	feyre.set_physics_process(false)
	Gameplay.inventory.add(&"arrow_wood", 30)
	await wait_physics_frames(10)
	feyre.velocity = Vector3.ZERO
	feyre.body_state.hunger = 0.0
	feyre.body_state.cold = 0.0
	feyre.body_state.fae_toll = 0.0
	feyre.vitals.dread = 0.0
	feyre.max_stamina = 100.0
	feyre.stamina = 100.0
	feyre._exhausted = false


func after_each() -> void:
	StoryControl.release()
	TimeScale.reset()


func _hold(seconds: float, fire: bool = false, focus: bool = false) -> void:
	for i in roundi(seconds / TICK):
		bow.update_bow(TICK * Engine.time_scale, true, fire, focus)


func _plain() -> Vector3:
	return (feyre.aim_point() - bow.muzzle()).normalized()


func test_the_arrow_leaves_along_the_direction_the_crosshair_shows() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261124
	var worst := 0.0
	for shot in 100:
		Gameplay.inventory.add(&"arrow_wood", 1)
		# Calm on the even shots, short of breath on the odd; a different
		# moment of the wobble each time.
		feyre.stamina = 100.0 if shot % 2 == 0 else 20.0
		_hold(rng.randf_range(0.05, 0.9))
		feyre.nudge_camera(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.05, 0.05))
		bow.update_bow(TICK, true, false)
		var shown := bow.shot_direction()
		var arrow := bow.release()
		assert_not_null(arrow)
		if arrow == null:
			break
		worst = maxf(worst, rad_to_deg(shown.angle_to(arrow.linear_velocity.normalized())))
		arrow.free()
	assert_lt(worst, 0.05, "crosshair and arrow agree within 0.05 degrees (worst %.4f)" % worst)


func test_calm_the_shot_goes_exactly_to_the_crosshair() -> void:
	_hold(TICK)
	assert_eq(bow.sway_degrees(), 0.0, "no sway the moment the bow is up")
	assert_lt(rad_to_deg(bow.shot_direction().angle_to(_plain())), 0.001)
	_hold(bow.bow.draw_time + 0.5, true)
	assert_eq(bow.sway_degrees(), 0.0, "nor at full draw")
	assert_lt(rad_to_deg(bow.shot_direction().angle_to(_plain())), 0.001)


func test_walking_and_turning_do_not_shake_her_aim() -> void:
	feyre.velocity = Vector3(2.5, 0.0, 0.0)
	_hold(0.5)
	assert_eq(bow.sway_degrees(), 0.0, "walking with the bow up")
	for i in 12:
		feyre.nudge_camera(deg_to_rad(4.0), 0.0)
		bow.update_bow(TICK, true, false)
	assert_eq(bow.sway_degrees(), 0.0, "a flick shot goes where the crosshair is")


func test_low_breath_shakes_the_aim() -> void:
	_hold(0.5)
	var own := bow.bow.sway_degrees
	feyre.stamina = 20.0
	assert_almost_eq(bow.sway_degrees(), own * (bow.tuning.breath_low - 1.0), 0.001, "below a quarter stamina")
	feyre._exhausted = true
	assert_almost_eq(bow.sway_degrees(), own * (bow.tuning.breath_winded - 1.0) + bow.tuning.breath_winded_tremor,
		0.001, "winded")
	var swayed := rad_to_deg(bow.shot_direction().angle_to(_plain()))
	assert_gt(swayed, 0.0, "the shot is off the crosshair's centre")
	assert_lt(swayed, bow.sway_degrees() * 1.5, "by no more than the sway")


func test_a_draw_held_too_long_trembles() -> void:
	_hold(bow.bow.draw_time + bow.tuning.fatigue_after_s - 0.2, true)
	assert_eq(bow.sway_degrees(), 0.0, "steady until the arm tires")
	_hold(1.5, true)
	feyre.stamina = 100.0
	feyre._exhausted = false
	assert_gt(bow.sway_degrees(), 0.2, "then the hold shows")
	assert_lte(bow.sway_degrees(), bow.bow.sway_degrees * (bow.tuning.fatigue_max - 1.0) + 0.001)


func test_hungry_and_cold_in_the_winter_wood_her_hands_are_steady() -> void:
	_hold(0.5)
	feyre.body_state.hunger = 0.55
	feyre.body_state.cold = 0.5
	assert_eq(bow.sway_degrees(), 0.0, "ordinary hardship does not move the shot")


func test_frozen_and_starving_her_hands_shake() -> void:
	_hold(0.5)
	feyre.body_state.hunger = 1.0
	feyre.body_state.cold = 1.0
	var body := feyre.body_state
	var t := bow.tuning
	assert_gt(body.sway_multiplier(), t.steady_body, "BodyState reports it")
	assert_almost_eq(bow.sway_degrees(), bow.bow.sway_degrees * (body.sway_multiplier() - t.steady_body)
		+ body.tremor_degrees() - t.steady_tremor, 0.001)
	assert_gt(bow.sway_degrees(), 1.0)


func test_focus_steadies_what_sway_there_is() -> void:
	_hold(0.5)
	feyre.stamina = 20.0
	var shaky := bow.sway_degrees()
	_hold(TICK, false, true)
	assert_true(bow.is_focused)
	assert_almost_eq(bow.sway_degrees(), shaky * bow.tuning.focus_sway, 0.001)


func test_the_crosshair_moves_with_the_sway_and_only_with_it() -> void:
	var reticle := bow.reticle
	_hold(0.5)
	reticle._process(0.0)
	assert_almost_eq(reticle.at.distance_to(reticle.size * 0.5), 0.0, 0.01, "calm: dead centre")
	_hold(bow.bow.draw_time + 0.2, true)
	reticle._process(0.0)
	assert_almost_eq(reticle.at.distance_to(reticle.size * 0.5), 0.0, 0.01, "and it stays there through the draw")
	feyre._exhausted = true
	_hold(0.4)
	reticle._process(0.0)
	var lands := bow.muzzle() + bow.shot_direction() * bow.muzzle().distance_to(feyre.aim_point())
	var want := feyre.camera.unproject_position(lands) * (reticle.size.y / get_viewport().get_visible_rect().size.y)
	assert_gt(reticle.at.distance_to(reticle.size * 0.5), 1.0, "winded, it wanders")
	assert_almost_eq(reticle.at.distance_to(want), 0.0, 3.0, "to where the arrow would go")
