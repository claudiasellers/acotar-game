## Contract for the bow's visible sway (plans/combat/bow-combat-design.md §13
## B2): the ring and the arrow share one direction, the sway settles when she
## holds still, and stance, breath, fatigue and Focus change it by the doc's
## amounts.
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


func test_the_arrow_leaves_along_the_direction_the_ring_shows() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261124
	var worst := 0.0
	for shot in 100:
		Gameplay.inventory.add(&"arrow_wood", 1)
		# A different moment of the wobble each time, settled or not.
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
	assert_lt(worst, 0.05, "ring and arrow agree within 0.05 degrees (worst %.4f)" % worst)


func test_predicted_impact_carries_the_sway() -> void:
	_hold(0.05)
	var from := bow.muzzle()
	var swayed := bow.shot_direction()
	var plain := (feyre.aim_point() - from).normalized()
	assert_gt(rad_to_deg(swayed.angle_to(plain)), 0.0, "unsettled, the shot is off the crosshair")
	assert_lt(rad_to_deg(swayed.angle_to(plain)), bow.sway_degrees() * 1.5, "by no more than the sway")


func test_sway_settles_when_she_holds_still() -> void:
	_hold(TICK)
	assert_almost_eq(bow.sway_degrees(), bow.bow.sway_degrees, 0.1, "just raised: the bow's full sway")
	_hold(bow.tuning.settle_s + 0.05)
	assert_lte(bow.sway_degrees(), 0.55, "settled and still on the hunting bow")
	assert_almost_eq(bow.unsettled(), 0.0, 0.01)


func test_walking_keeps_the_aim_wild() -> void:
	feyre.velocity = Vector3(2.5, 0.0, 0.0)
	_hold(1.0)
	assert_gte(bow.sway_degrees(), 2.3, "walking with the bow up")
	feyre.crouch.set_crouched(true)
	assert_lt(bow.sway_degrees(), 2.3, "a crouch-walk is steadier than a walk")
	feyre.velocity = Vector3.ZERO
	_hold(bow.tuning.settle_s + 0.05)
	assert_almost_eq(bow.sway_degrees(), bow.bow.sway_degrees * bow.tuning.settle_floor * bow.tuning.stance_crouched,
		0.01, "crouched and still is the steadiest stance")


func test_a_fast_turn_unsettles_the_aim() -> void:
	_hold(bow.tuning.settle_s + 0.05)
	var settled := bow.sway_degrees()
	for i in 12:
		feyre.nudge_camera(deg_to_rad(2.0), 0.0)
		bow.update_bow(TICK, true, false)
	assert_gt(bow.sway_degrees(), settled * 1.5, "a flick shot is a wild shot")


func test_focus_steadies_and_settles_faster() -> void:
	_hold(bow.tuning.settle_s * 0.5 + 0.05, false, true)
	assert_lte(bow.sway_degrees(), 0.22, "Focused and settled")
	feyre.vitals.dread = 0.8
	assert_almost_eq(bow.sway_degrees(), bow.bow.sway_degrees * bow.tuning.settle_floor * bow.tuning.focus_sway_panic,
		0.01, "panic gives a shakier Focus")


func test_a_long_hold_tires_her_arm() -> void:
	_hold(1.0)
	var settled := bow.sway_degrees()
	_hold(bow.bow.draw_time + bow.tuning.fatigue_after_s - 0.1, true)
	assert_almost_eq(bow.sway_degrees(), settled, 0.001, "no tremble before 3 s at full draw")
	var before := feyre.stamina
	_hold(1.0, true)
	assert_gt(bow.sway_degrees(), settled * 1.15, "the arm starts to tremble")
	assert_almost_eq(before - feyre.stamina, bow.tuning.hold_drain * 0.9, 1.0, "and holding costs stamina")
	_hold(10.0, true)
	feyre.stamina = 100.0
	feyre._exhausted = false
	assert_almost_eq(bow.sway_degrees(), settled * bow.tuning.fatigue_max, 0.001, "capped at twice")


func test_low_breath_shakes_the_aim() -> void:
	_hold(1.0)
	var settled := bow.sway_degrees()
	feyre.stamina = 20.0
	assert_almost_eq(bow.sway_degrees(), settled * 1.5, 0.001, "below a quarter stamina")
	feyre._exhausted = true
	assert_almost_eq(bow.sway_degrees(), settled * 2.0 + bow.tuning.breath_winded_tremor, 0.001, "winded")


## Design doc §9: from 100 stamina, Focus for 1.5 s (42) leaves room for two
## sidesteps (24) and a bash (15) with 19 to spare.
func test_the_stamina_budget_for_one_fight() -> void:
	_hold(0.2)
	_hold(1.5, false, true)
	var spent := 100.0 - feyre.stamina
	assert_almost_eq(spent, 42.0, 1.0, "1.5 s of Focus")
	assert_gte(100.0 - spent - 24.0 - 15.0, 18.0, "an opener and its defence fit in one bar")
