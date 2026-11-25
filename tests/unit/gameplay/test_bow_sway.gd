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


func test_low_breath_shakes_the_aim() -> void:
	_hold(1.0)
	var settled := bow.sway_degrees()
	feyre.stamina = 20.0
	assert_almost_eq(bow.sway_degrees(), settled * 1.5, 0.001, "below a quarter stamina")
	feyre._exhausted = true
	assert_almost_eq(bow.sway_degrees(), settled * 2.0 + bow.tuning.breath_winded_tremor, 0.001, "winded")

