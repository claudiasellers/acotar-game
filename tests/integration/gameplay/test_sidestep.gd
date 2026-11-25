## Health-interactions §3.5 #9 (slice HF): the sidestep as behaviour. 2.2 m in
## a quarter second, a moment nothing can hurt her in from its second frame,
## 12 stamina, half the draw kept, a gasp and a shake of the stamina bow when
## she has no breath for it, and its hint while one is after her. Drives
## SidestepMotor, the bow and Feyre directly, never a key or button.
extends GutTest

const BodyTick := preload("res://tests/fixtures/body_tick.gd")
const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")
const DT := 1.0 / 60.0

var hill: Node3D
var feyre: Feyre
var bow: BowController


func before_each() -> void:
	TimeScale.reset()
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	StoryControl.release()
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	bow = feyre.bow_controller
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	await wait_until(func() -> bool: return feyre.is_on_floor(), 5.0)
	await wait_physics_frames(5)
	# The test ticks her and her bow by hand.
	feyre.set_physics_process(false)
	bow.set_physics_process(false)
	Gameplay.inventory.add(&"arrow_wood", 4)


func after_each() -> void:
	TimeScale.reset()


## The bow up (aim held), and the string too when `draw`.
func _raise(draw: bool = false) -> void:
	for i in 40:
		bow.update_bow(DT, true, draw)


## `count` of her own physics ticks, each exactly DT long.
func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		BodyTick.tick(feyre, DT)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func test_it_is_2_2_m_in_a_quarter_second_straight_back_from_her_aim() -> void:
	_raise()
	var from := feyre.global_position
	var stamina := feyre.stamina
	feyre.sidestep.press()
	await _ticks(1)
	assert_true(feyre.sidestep.active, "she moves on the tick after the press")
	await _ticks(roundi(SidestepMotor.TIME / DT))
	assert_false(feyre.sidestep.active, "over in %.2f s" % SidestepMotor.TIME)
	var moved := _flat(feyre.global_position - from)
	assert_almost_eq(moved.length(), SidestepMotor.DISTANCE, 0.3, "about 2.2 m, was %.2f" % moved.length())
	var back := Vector3.BACK.rotated(Vector3.UP, feyre._camera_rig.rotation.y)
	assert_gt(moved.normalized().dot(back), 0.95, "straight back from her aim")
	assert_eq(feyre.jump_motor.jumps_used, 0, "no jump")
	assert_almost_eq(feyre.stamina, stamina - SidestepMotor.STAMINA, 0.5)
	assert_true(feyre.is_aiming, "the bow stays up")


func test_the_draw_drops_to_half_and_is_not_lost() -> void:
	_raise(true)
	assert_eq(bow.draw_amount, 1.0)
	feyre.sidestep.press()
	await _ticks(1)
	bow.update_bow(DT, true, true)
	assert_true(bow.is_drawing, "still drawing")
	assert_between(bow.draw_amount, 0.45, 0.75, "half the draw, building again")


func test_nothing_can_hurt_her_from_its_second_frame_and_only_for_a_moment() -> void:
	_raise()
	var health := feyre.vitals.health
	feyre.sidestep.press()
	await _ticks(1)
	assert_true(feyre.sidestep.active)
	assert_false(feyre.vitals.is_invulnerable(), "the first frame is honest")
	await _ticks(1)
	assert_true(feyre.vitals.is_invulnerable(), "safe from the second frame")
	EventBus.player_hit.emit(&"naga_1", &"naga_claw", 1.0, feyre.global_position + Vector3(1, 0, 0))
	assert_eq(feyre.vitals.health, health, "the claw finds nothing")
	await wait_physics_frames(40)
	assert_false(feyre.vitals.is_invulnerable(), "and it is only a moment")
	EventBus.player_hit.emit(&"naga_1", &"naga_claw", 1.0, feyre.global_position + Vector3(1, 0, 0))
	assert_lt(feyre.vitals.health, health)


func test_with_no_breath_she_gasps_the_stamina_bow_shakes_and_she_stays_put() -> void:
	_raise()
	feyre.stamina = SidestepMotor.STAMINA - 1.0
	var sound := SoundDirector.new()
	add_child_autofree(sound)
	var hud := VitalsHud.new()
	add_child_autofree(hud)
	await wait_frames(2)
	hud._stamina_timer = 0.0
	var from := feyre.global_position
	feyre.sidestep.press()
	await _ticks(3)
	assert_false(feyre.sidestep.active, "not enough stamina")
	assert_false(feyre.sidestep.wanted(), "the press is spent")
	assert_has(sound.played, &"breath_winded", "heard: a gasp, never silence")
	assert_gt(hud._stamina_timer, 0.0, "seen: the stamina bow shows itself and shakes its head")
	assert_almost_eq(_flat(feyre.global_position - from).length(), 0.0, 0.05, "and she has not moved")


func test_the_next_one_waits_for_the_cooldown() -> void:
	_raise()
	feyre.sidestep.press()
	await _ticks(1 + roundi(SidestepMotor.TIME / DT))
	feyre.sidestep.press()
	await _ticks(3)
	assert_false(feyre.sidestep.active, "the next one waits %.2f s" % SidestepMotor.COOLDOWN)


func test_its_hint_is_held_while_one_is_after_her_and_learnt_on_the_first_step() -> void:
	var hints := KeyHints.of(get_tree())
	hints.forget_taught()
	GameSettings.set_value(&"key_hints", true)
	var naga: NagaRoamer = preload("res://creatures/hostile/naga_roamer.tscn").instantiate()
	hill.add_child(naga)
	naga.set_physics_process(false)
	naga.global_position = feyre.global_position + Vector3(6, 0, 0)
	naga.ladder.state = HostileLadder.State.ENGAGED
	feyre._hold_sidestep_hint()
	assert_ne(hints.wanted(), &"sidestep", "not with the bow down")
	_raise()
	feyre._hold_sidestep_hint()
	assert_eq(hints.wanted(), &"sidestep")
	naga.ladder.state = HostileLadder.State.ROUTINE
	feyre._hold_sidestep_hint()
	assert_ne(hints.wanted(), &"sidestep", "and not once it has lost her")
	naga.ladder.state = HostileLadder.State.ENGAGED
	feyre.sidestep.press()
	await _ticks(1)
	assert_true(feyre.sidestep.active)
	feyre._hold_sidestep_hint()
	assert_false(hints.teaches(&"sidestep"), "used once, it is learnt")
	assert_ne(hints.wanted(), &"sidestep")
