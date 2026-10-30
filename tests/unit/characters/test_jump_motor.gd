extends GutTest

const DT := 1.0 / 60.0

var motor: JumpMotor
var y: float
var vy: float
var jumps: Array[int]
var lands: Array[int]


func before_each() -> void:
	motor = JumpMotor.new()
	y = 0.0
	vy = 0.0
	jumps = []
	lands = []
	motor.jumped.connect(func(i: int) -> void: jumps.append(i))
	motor.landed.connect(func(_s: float, i: int) -> void: lands.append(i))


## One frame on flat ground at y = 0. Returns the frame's height.
func _tick(pressed: bool, held: bool, speed: float = 0.0, floor_y: float = 0.0) -> float:
	var on_floor := y <= floor_y + 0.0001
	vy = motor.step(DT, on_floor, vy, pressed, held, speed)
	y += vy * DT
	if y < floor_y:
		y = floor_y
		vy = 0.0
	return y


## Presses jump once, holds it for `hold_frames`, returns the apex.
func _jump(hold_frames: int, speed: float = 0.0) -> float:
	var apex := 0.0
	_tick(true, true, speed)
	for f in 240:
		apex = maxf(apex, _tick(false, f < hold_frames, speed))
		if y <= 0.0 and vy <= 0.0:
			break
	# The frame after touching down reports the landing.
	_tick(false, false, speed)
	return apex


func test_full_jump_reaches_first_height() -> void:
	var apex := _jump(999)
	assert_almost_eq(apex, JumpMotor.HEIGHTS[0], 0.12)
	assert_eq(jumps, [1])
	assert_eq(lands, [1])


func test_tap_is_a_short_hop() -> void:
	var apex := _jump(1)
	assert_lt(apex, 0.55)
	assert_gt(apex, 0.2)


func test_fall_is_faster_than_rise() -> void:
	_tick(true, true)
	var up_frames := 0
	while vy > 0.0:
		_tick(false, false)
		up_frames += 1
	assert_gt(motor.rise_gravity(1) * motor.fall_multiplier, motor.rise_gravity(1))
	var down_frames := 0
	while y > 0.0 and down_frames < 300:
		_tick(false, false)
		down_frames += 1
	assert_lt(down_frames, up_frames + 2)


func test_triple_jump_chains_while_running() -> void:
	var a1 := _jump(999, 5.5)
	var a2 := _jump(999, 5.5)
	var a3 := _jump(999, 5.5)
	assert_eq(jumps, [1, 2, 3])
	assert_gt(a2, a1 + 0.3)
	assert_gt(a3, a2 + 0.5)
	assert_almost_eq(a3, JumpMotor.HEIGHTS[2], 0.15)
	# After the third, the chain starts over.
	_tick(false, false, 5.5)
	_jump(999, 5.5)
	assert_eq(jumps[-1], 1)


func test_chain_needs_speed_and_timing() -> void:
	_jump(999, 0.0)
	_jump(999, 0.0)
	assert_eq(jumps, [1, 1], "standing still never chains")
	jumps.clear()
	for i in 30:
		_tick(false, false)
	_jump(999, 5.5)
	for i in 30:
		_tick(false, false, 5.5)
	_jump(999, 5.5)
	assert_eq(jumps, [1, 1], "half a second on the ground breaks the chain")


func test_third_needs_running_speed() -> void:
	_jump(999, 5.5)
	_jump(999, 5.5)
	_tick(false, false, 3.0)
	_jump(999, 3.0)
	assert_eq(jumps, [1, 2, 1])


func test_buffered_press_jumps_on_landing() -> void:
	_tick(true, true)
	while vy > -0.1 or y > 0.15:
		_tick(false, true)
	# Pressed a few frames before touching down.
	_tick(true, true)
	while y > 0.0:
		_tick(false, true)
	_tick(false, true)
	assert_eq(jumps.size(), 2)


func test_coyote_time_after_walking_off() -> void:
	y = 2.0
	# Standing on a 2 m ledge, then it is gone.
	_tick(false, false, 4.0, 2.0)
	for i in 4:
		_tick(false, false, 4.0, -10.0)
	_tick(true, true, 4.0, -10.0)
	assert_eq(jumps, [1])
	assert_gt(vy, 0.0)


func test_no_jump_after_coyote_expires() -> void:
	y = 2.0
	_tick(false, false, 4.0, 2.0)
	for i in 20:
		_tick(false, false, 4.0, -10.0)
	_tick(true, true, 4.0, -10.0)
	assert_eq(jumps, [])


func test_no_double_jump_in_air() -> void:
	_tick(true, true)
	for i in 10:
		_tick(false, true)
	_tick(true, true)
	assert_eq(jumps, [1])


func test_gentle_mode_widens_windows() -> void:
	motor.forgiving = true
	assert_gt(motor.coyote_time, 0.2)
	assert_gt(motor.chain_window, 0.3)
	_jump(999, 2.0)
	for i in 15:
		_tick(false, false, 2.0)
	_jump(999, 2.0)
	assert_eq(jumps, [1, 2])
