## Health-interactions §3.5 #9 and #2: the sidestep's own numbers.
extends GutTest

const TICK := 1.0 / 60.0

var motor: SidestepMotor


func before_each() -> void:
	motor = SidestepMotor.new()


func test_it_covers_its_distance_in_its_time() -> void:
	motor.begin(Vector3(3, 5, 0))
	assert_eq(motor.direction, Vector3.RIGHT, "flat and unit length")
	var moved := Vector3.ZERO
	var frames := 0
	while motor.active and frames < 60:
		moved += motor.step(TICK) * TICK
		frames += 1
	assert_almost_eq(moved.length(), SidestepMotor.DISTANCE, 0.001)
	assert_almost_eq(frames * TICK, SidestepMotor.TIME, TICK)


func test_safety_begins_on_its_second_frame_once() -> void:
	motor.begin(Vector3.BACK)
	var safe: Array[int] = []
	for frame in range(1, 30):
		motor.step(TICK)
		if motor.safe_now:
			safe.append(frame)
	assert_eq(safe, [SidestepMotor.IFRAMES_FROM_FRAME] as Array[int])
	assert_eq(motor.iframes(false), 0.2)
	assert_eq(motor.iframes(true), 0.3)


func test_the_next_one_waits_out_the_cooldown() -> void:
	motor.begin(Vector3.BACK)
	while motor.active:
		motor.step(TICK)
	assert_false(motor.ready())
	var waited := 0.0
	while not motor.ready() and waited < 2.0:
		motor.step(TICK)
		waited += TICK
	assert_almost_eq(waited, SidestepMotor.COOLDOWN, TICK * 1.5)


func test_a_press_waits_a_short_while_then_lapses() -> void:
	motor.press()
	motor.wait(0.1, false)
	assert_true(motor.wanted())
	motor.wait(0.06, false)
	assert_false(motor.wanted())


func test_a_freeze_holds_the_press() -> void:
	motor.press()
	for i in 12:
		motor.wait(TICK, true)
	assert_true(motor.wanted(), "still wanted after a 12-frame freeze")
	motor.begin(Vector3.BACK)
	assert_false(motor.wanted(), "and spent once it runs")
