## Feyre's jump: the vertical half of her movement, kept apart from the
## controller so it can be tuned and tested on its own.
##
## Feel rules (platformer standards): coyote time after leaving a ledge,
## jump buffering before landing, variable height (let go early for a hop),
## a floaty apex while held and a faster fall. Landing and jumping again
## within a short window while moving chains a triple jump: each jump is
## higher, the third is a flourish.
##
## The owner calls `step()` once per physics frame before move_and_slide and
## writes the returned vertical velocity; `jumped` and `landed` drive the
## animation and the juice.
class_name JumpMotor
extends RefCounted

signal jumped(index: int)
signal landed(impact_speed: float, index: int)

## Apex heights (m) and times to apex (s) for the 1st, 2nd and 3rd jump.
const HEIGHTS: Array[float] = [1.15, 1.6, 2.4]
const APEX_TIMES: Array[float] = [0.36, 0.40, 0.48]

var coyote_time: float = 0.12
var buffer_time: float = 0.14
## Seconds after landing in which the next jump chains (2nd, then 3rd).
var chain_window: float = 0.18
## Minimum ground speed (m/s) to chain into the 2nd and the 3rd jump.
var chain_min_speed: Array[float] = [2.5, 4.0]
## Fall gravity as a multiple of the current jump's rise gravity.
var fall_multiplier: float = 1.9
## Gravity scale near the apex while jump is held.
var apex_hang_scale: float = 0.55
var apex_hang_speed: float = 1.2
## Rising velocity kept when jump is released early.
var jump_cut: float = 0.55
var terminal_speed: float = 25.0
## Gravity (m/s²) used when she walks off an edge without jumping.
var fall_gravity: float = 30.0

## Gentle Mode: wider windows and an easier triple jump.
var forgiving: bool = false:
	set(value):
		forgiving = value
		coyote_time = 0.22 if value else 0.12
		buffer_time = 0.25 if value else 0.14
		chain_window = 0.35 if value else 0.18
		chain_min_speed.assign([1.5, 2.5] if value else [2.5, 4.0])

## 0 on the ground; 1, 2 or 3 while airborne from that jump.
var jump_index: int = 0
var airborne: bool = false
var rising: bool = false

var _coyote: float = 0.0
var _buffer: float = 0.0
var _since_landing: float = INF
var _last_landed_index: int = 0
var _cut_done: bool = false
## Last airborne vertical velocity (the floor zeroes it before we see the landing).
var _air_vy: float = 0.0


func rise_gravity(index: int) -> float:
	var i := clampi(index, 1, 3) - 1
	return 2.0 * HEIGHTS[i] / (APEX_TIMES[i] * APEX_TIMES[i])


func launch_speed(index: int) -> float:
	var i := clampi(index, 1, 3) - 1
	return 2.0 * HEIGHTS[i] / APEX_TIMES[i]


## Called by the owner when a jump press is consumed by something else (a mantle).
func consume_buffer() -> void:
	_buffer = 0.0


## Advances one physics frame. `pressed` is the just-pressed edge, `held` the
## button state, `ground_speed` her horizontal speed. Returns the new vertical velocity.
func step(delta: float, on_floor: bool, vy: float, pressed: bool, held: bool,
		ground_speed: float, can_jump: bool = true) -> float:
	if pressed:
		_buffer = buffer_time
	else:
		_buffer = maxf(_buffer - delta, 0.0)

	if on_floor and vy <= 0.01:
		if airborne:
			airborne = false
			rising = false
			_last_landed_index = jump_index
			_since_landing = 0.0
			landed.emit(maxf(-_air_vy, 0.0), jump_index)
			jump_index = 0
		else:
			_since_landing += delta
		_coyote = coyote_time
	else:
		_coyote = maxf(_coyote - delta, 0.0)

	if _buffer > 0.0 and can_jump and (on_floor or (jump_index == 0 and _coyote > 0.0)):
		return _launch(ground_speed)

	if on_floor and vy <= 0.01:
		return vy

	# In the air (jumped or walked off an edge).
	if not airborne:
		airborne = true
	var g := fall_gravity
	if jump_index > 0:
		var up := rise_gravity(jump_index)
		if vy > 0.0:
			g = up
			if held and vy < apex_hang_speed:
				g *= apex_hang_scale
			elif not held and not _cut_done and jump_index < 3:
				_cut_done = true
				vy *= jump_cut
		else:
			g = up * (apex_hang_scale if held and vy > -apex_hang_speed else fall_multiplier)
	vy = maxf(vy - g * delta, -terminal_speed)
	rising = vy > 0.0
	_air_vy = vy
	return vy


func _launch(ground_speed: float) -> float:
	var index := 1
	if _since_landing <= chain_window and _last_landed_index > 0 and _last_landed_index < 3 \
			and ground_speed >= chain_min_speed[_last_landed_index - 1]:
		index = _last_landed_index + 1
	jump_index = index
	airborne = true
	rising = true
	_cut_done = false
	_buffer = 0.0
	_coyote = 0.0
	_since_landing = INF
	jumped.emit(index)
	return launch_speed(index)
