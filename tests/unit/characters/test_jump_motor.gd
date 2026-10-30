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


## One frame over a floor at `floor_y`. Returns the frame's height.
func _tick(pressed: bool, held: bool, floor_y: float = 0.0) -> float:
	var on_floor := y <= floor_y + 0.0001
	vy = motor.step(DT, on_floor, vy, pressed, held)
	y += vy * DT
	if y < floor_y:
		y = floor_y
		vy = 0.0
	return y


## Ticks until she lands (plus the frame that reports it). Returns the apex.
func _fly(held: bool) -> float:
	var apex := y
	for f in 600:
		apex = maxf(apex, _tick(false, held))
		if y <= 0.0 and vy <= 0.0:
			break
	_tick(false, false)
	return apex


func test_takeoff_on_the_press_frame() -> void:
	_tick(true, true)
	assert_eq(jumps, [1])
	assert_gt(y, 0.0, "already off the ground on the press frame")


func test_full_jump_reaches_first_height() -> void:
	_tick(true, true)
	var apex := _fly(true)
	# Holding jump also hangs at the apex, a touch higher than h.
	assert_between(apex, JumpMotor.HEIGHTS[0] - 0.1, JumpMotor.HEIGHTS[0] + 0.4)
	assert_eq(lands, [1])


func test_tap_is_a_short_hop() -> void:
	_tick(true, true)
	var apex := _fly(false)
	assert_lt(apex, JumpMotor.HEIGHTS[0] * 0.4)


func test_fall_is_faster_than_rise() -> void:
	_tick(true, false)
	var up := 0
	while vy > 0.0:
		_tick(false, true)
		up += 1
	var down := 0
	while y > 0.0 and down < 600:
		_tick(false, false)
		down += 1
	assert_gt(motor.fall_gravity, motor.rise_gravity)
	assert_lt(down, up)


func test_air_jumps_stack_from_anywhere() -> void:
	_tick(true, true)
	for i in 20:
		_tick(false, true)
	var y2 := y
	_tick(true, true)
	assert_eq(jumps, [1, 2])
	assert_almost_eq(vy, motor.launch_speed(2) - motor.rise_gravity * DT, 0.5)
	for i in 20:
		_tick(false, true)
	_tick(true, true)
	assert_eq(jumps, [1, 2, 3])
	var apex := _fly(true)
	assert_gt(apex, y2 + JumpMotor.HEIGHTS[1] + 1.0, "the chain climbs well above one jump")
	assert_eq(lands, [3])


func test_air_jump_while_falling_still_goes_up() -> void:
	_tick(true, true)
	while vy > -5.0:
		_tick(false, false)
	_tick(true, true)
	assert_gt(vy, 10.0)


func test_only_three_jumps() -> void:
	_tick(true, true)
	_tick(true, true)
	_tick(true, true)
	_tick(true, true)
	assert_eq(jumps, [1, 2, 3])


func test_chain_resets_on_landing() -> void:
	_tick(true, true)
	_tick(true, true)
	_tick(true, true)
	_fly(false)
	_tick(true, true)
	assert_eq(jumps, [1, 2, 3, 1])


func test_buffered_press_jumps_on_landing() -> void:
	_tick(true, true)
	_tick(true, true)
	_tick(true, true)
	while vy > -0.1 or y > 0.15:
		_tick(false, false)
	# Pressed a few frames before touching down, jumps all spent.
	_tick(true, true)
	while y > 0.0:
		_tick(false, true)
	_tick(false, true)
	assert_eq(jumps, [1, 2, 3, 1])


func test_coyote_time_after_walking_off() -> void:
	y = 2.0
	_tick(false, false, 2.0)
	for i in 4:
		_tick(false, false, -10.0)
	_tick(true, true, -10.0)
	assert_eq(jumps, [1])


func test_walking_off_gives_spin_and_flip() -> void:
	y = 2.0
	_tick(false, false, 2.0)
	for i in 20:
		_tick(false, false, -10.0)
	_tick(true, true, -10.0)
	_tick(true, true, -10.0)
	_tick(true, true, -10.0)
	assert_eq(jumps, [2, 3])


func test_gentle_mode_widens_windows() -> void:
	motor.forgiving = true
	assert_gt(motor.coyote_time, 0.2)
	assert_gt(motor.buffer_time, 0.2)
