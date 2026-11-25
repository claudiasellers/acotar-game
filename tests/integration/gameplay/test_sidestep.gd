## Health-interactions §3.5 #9 (slice HF): with the bow raised the jump key is
## a sidestep. 2.2 m, a moment nothing can hurt her in, 12 stamina, half the
## draw kept; a press made in a hit-stop runs as the freeze ends.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")

var hill: Node3D
var feyre: Feyre


func before_each() -> void:
	TimeScale.reset()
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	await wait_until(func() -> bool: return feyre.is_on_floor(), 5.0)
	await wait_physics_frames(5)


func after_each() -> void:
	for action: StringName in [&"aim", &"fire", &"jump", &"move_left"]:
		Input.action_release(action)
	TimeScale.reset()


func _raise() -> void:
	Input.action_press(&"aim")
	await wait_until(func() -> bool: return feyre.bow_controller.is_nocked, 3.0)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func test_space_with_the_bow_raised_steps_her_back_and_does_not_jump() -> void:
	await _raise()
	var from := feyre.global_position
	var stamina := feyre.stamina
	var jump := InputEventAction.new()
	jump.action = &"jump"
	jump.pressed = true
	Input.parse_input_event(jump)
	await wait_physics_frames(2)
	assert_true(feyre.sidestep.active, "she moves within a frame or two of the press")
	await wait_until(func() -> bool: return not feyre.sidestep.active, 1.0)
	await wait_physics_frames(20)
	var moved := _flat(feyre.global_position - from)
	assert_between(moved.length(), 1.8, 2.6, "about 2.2 m, was %.2f" % moved.length())
	var back := Vector3.BACK.rotated(Vector3.UP, feyre._camera_rig.rotation.y)
	assert_gt(moved.normalized().dot(back), 0.95, "straight back from her aim")
	assert_eq(feyre.jump_motor.jumps_used, 0, "no jump")
	assert_almost_eq(feyre.stamina, stamina - SidestepMotor.STAMINA, 0.01)
	assert_true(feyre.is_aiming, "the bow stays up")
	assert_false(KeyHints.of(get_tree()).teaches(&"sidestep"), "and the hint for it has done its work")


func test_it_goes_the_way_the_stick_points() -> void:
	await _raise()
	var from := feyre.global_position
	Input.action_press(&"move_left")
	feyre.sidestep.press()
	await wait_until(func() -> bool: return feyre.sidestep.active, 1.0)
	await wait_until(func() -> bool: return not feyre.sidestep.active, 1.0)
	Input.action_release(&"move_left")
	var left := Vector3.LEFT.rotated(Vector3.UP, feyre._camera_rig.rotation.y)
	assert_gt(_flat(feyre.global_position - from).normalized().dot(left), 0.9)


func test_the_draw_drops_to_half_and_is_not_lost() -> void:
	await _raise()
	Input.action_press(&"fire")
	await wait_until(func() -> bool: return feyre.bow_controller.draw_amount >= 1.0, 3.0)
	feyre.sidestep.press()
	await wait_physics_frames(2)
	assert_true(feyre.is_drawing, "still drawing")
	assert_between(feyre.bow_controller.draw_amount, 0.45, 0.75, "half the draw, building again")


func test_a_claw_landing_inside_the_step_does_nothing() -> void:
	await _raise()
	var health := feyre.vitals.health
	feyre.sidestep.press()
	await wait_until(func() -> bool: return feyre.sidestep.active, 1.0)
	assert_false(feyre.vitals.is_invulnerable(), "the first frame is honest")
	await wait_physics_frames(1)
	assert_true(feyre.vitals.is_invulnerable(), "safe from the second frame")
	# A claw whose wind-up ends 0.15 s after she stepped.
	await wait_physics_frames(8)
	EventBus.player_hit.emit(&"naga_1", &"naga_claw", 1.0, feyre.global_position + Vector3(1, 0, 0))
	assert_eq(feyre.vitals.health, health, "the claw finds nothing")
	await wait_physics_frames(30)
	assert_false(feyre.vitals.is_invulnerable(), "and it is only a moment")
	EventBus.player_hit.emit(&"naga_1", &"naga_claw", 1.0, feyre.global_position + Vector3(1, 0, 0))
	assert_lt(feyre.vitals.health, health)


func test_without_the_bow_up_space_is_still_a_jump() -> void:
	var jump := InputEventAction.new()
	jump.action = &"jump"
	jump.pressed = true
	Input.parse_input_event(jump)
	await wait_physics_frames(3)
	assert_false(feyre.sidestep.active)
	assert_false(feyre.sidestep.wanted())
	assert_eq(feyre.jump_motor.jumps_used, 1)


func test_no_breath_no_step_and_no_two_in_a_row() -> void:
	await _raise()
	feyre.stamina = SidestepMotor.STAMINA - 1.0
	feyre.sidestep.press()
	await wait_physics_frames(3)
	assert_false(feyre.sidestep.active, "not enough stamina")
	feyre.stamina = feyre.max_stamina
	feyre.sidestep.press()
	await wait_until(func() -> bool: return feyre.sidestep.active, 1.0)
	await wait_until(func() -> bool: return not feyre.sidestep.active, 1.0)
	feyre.sidestep.press()
	await wait_physics_frames(6)
	assert_false(feyre.sidestep.active, "the next one waits %.2f s" % SidestepMotor.COOLDOWN)


func test_a_press_at_the_start_of_the_longest_freeze_runs_as_it_ends() -> void:
	await _raise()
	feyre.hit_stop.hit(&"heavy", true)
	feyre.sidestep.press()
	var began := Time.get_ticks_usec()
	while feyre.hit_stop.active():
		assert_false(feyre.sidestep.active, "nothing starts inside the freeze")
		await get_tree().process_frame
	assert_gt((Time.get_ticks_usec() - began) / 1000000.0, SidestepMotor.BUFFER, "the freeze outlasts the buffer")
	assert_true(feyre.sidestep.wanted() or feyre.sidestep.active, "the press outlived the freeze")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(feyre.sidestep.active, "and runs on the frame the freeze ends")


func test_its_key_is_named_while_the_bow_is_up_and_one_is_after_her() -> void:
	var hints := KeyHints.of(get_tree())
	hints.forget_taught()
	GameSettings.set_value(&"key_hints", true)
	var naga: NagaRoamer = preload("res://creatures/hostile/naga_roamer.tscn").instantiate()
	hill.add_child(naga)
	naga.set_physics_process(false)
	naga.global_position = feyre.global_position + Vector3(6, 0, 0)
	naga.ladder.state = HostileLadder.State.ENGAGED
	await wait_frames(3)
	assert_ne(hints.wanted(), &"sidestep", "not with the bow down")
	await _raise()
	await wait_frames(2)
	assert_eq(hints.wanted(), &"sidestep")
	naga.ladder.state = HostileLadder.State.ROUTINE
	await wait_frames(2)
	assert_ne(hints.wanted(), &"sidestep", "and not once it has lost her")
	naga.ladder.state = HostileLadder.State.ENGAGED
	feyre.sidestep.press()
	await wait_until(func() -> bool: return feyre.sidestep.active, 1.0)
	await wait_frames(2)
	assert_ne(hints.wanted(), &"sidestep", "used once, it is learnt")


## UX review G4j: the jump key is named at the first ledge she could climb,
## and never again once she has jumped.
func test_the_jump_key_is_named_at_a_ledge_until_she_jumps() -> void:
	var hints := KeyHints.of(get_tree())
	hints.forget_taught()
	GameSettings.set_value(&"key_hints", true)
	await wait_frames(3)
	assert_ne(hints.wanted(), &"jump", "open ground")
	var block := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 1.2, 3)
	shape.shape = box
	block.add_child(shape)
	hill.add_child(block)
	var forward := -feyre.model.global_basis.z
	block.global_position = feyre.global_position + forward * 2.0 + Vector3.UP * 0.6
	await wait_physics_frames(3)
	await wait_frames(2)
	assert_false(feyre.mantle.find_ledge().is_empty(), "a ledge in reach")
	assert_eq(hints.wanted(), &"jump")
	Input.action_press(&"jump")
	await wait_physics_frames(3)
	await wait_frames(2)
	assert_false(hints.teaches(&"jump"), "learnt with her first jump")
	assert_ne(hints.wanted(), &"jump")
