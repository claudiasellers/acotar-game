## Feyre's jump: the vertical half of her movement, kept apart from the
## controller so it can be tuned and tested on its own.
##
## An air triple jump: jump 1 from the ground (or within coyote time of a
## ledge), then jumps 2 and 3 any time she is still airborne. Every jump
## *sets* her upward speed to v = sqrt(2 g h), so each one stacks from
## wherever she is, rising or falling. Walking off a ledge skips jump 1.
## Take-off happens on the press frame; animation and squash play on top.
## Feel: jump buffering before landing, a short hop when jump 1 is released
## early, a floaty apex while held and a faster fall.
##
## The owner calls `step()` once per physics frame before move_and_slide and
## writes the returned vertical velocity; `jumped` and `landed` drive the
## animation, the air redirect and the juice.
class_name JumpMotor
extends RefCounted

signal jumped(index: int)
signal landed(impact_speed: float, index: int)

## Apex heights (m) of jump 1, 2 (spin) and 3 (flip).
const HEIGHTS: Array[float] = [3.1, 2.8, 3.35]
const MAX_JUMPS := 3

var rise_gravity: float = 22.0
var fall_gravity: float = 34.0
var coyote_time: float = 0.12
var buffer_time: float = 0.15
## Gravity scale near the apex (|vy| below apex_hang_speed) while jump is held.
var apex_hang_scale: float = 0.55
var apex_hang_speed: float = 1.6
## Rising velocity kept when jump 1 is released early (a short hop).
var jump_cut: float = 0.5
var terminal_speed: float = 30.0

## Gentle Mode: wider coyote and buffer windows.
var forgiving: bool = false:
	set(value):
		forgiving = value
		coyote_time = 0.22 if value else 0.12
		buffer_time = 0.25 if value else 0.15

## The jump she is in (1..3); 0 on the ground or after walking off an edge.
var jump_index: int = 0
## Jumps spent since she last stood on the ground.
var jumps_used: int = 0
var airborne: bool = false
var rising: bool = false

var _coyote: float = 0.0
var _buffer: float = 0.0
var _cut_done: bool = false
## Last airborne vertical velocity (the floor zeroes it before we see the landing).
var _air_vy: float = 0.0


func launch_speed(index: int) -> float:
	return sqrt(2.0 * rise_gravity * HEIGHTS[clampi(index, 1, MAX_JUMPS) - 1])


## Called by the owner when a jump press is consumed by something else (a mantle).
func consume_buffer() -> void:
	_buffer = 0.0


## Advances one physics frame. `pressed` is the just-pressed edge, `held` the
## button state. Returns the new vertical velocity.
func step(delta: float, on_floor: bool, vy: float, pressed: bool, held: bool,
		can_jump: bool = true) -> float:
	if pressed:
		_buffer = buffer_time
	else:
		_buffer = maxf(_buffer - delta, 0.0)

	var grounded := on_floor and vy <= 0.01
	if grounded:
		if airborne:
			landed.emit(maxf(-_air_vy, 0.0), jump_index)
		airborne = false
		rising = false
		jump_index = 0
		jumps_used = 0
		_coyote = coyote_time
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		if not airborne:
			airborne = true

	if _buffer > 0.0 and can_jump:
		if grounded or (jumps_used == 0 and _coyote > 0.0):
			return _launch(1)
		if airborne and jumps_used < MAX_JUMPS:
			# Walked off a ledge: the first air press is the spin.
			return _launch(maxi(jumps_used, 1) + 1)

	if grounded:
		return vy

	var g := rise_gravity if vy > 0.0 else fall_gravity
	if held and absf(vy) < apex_hang_speed:
		g *= apex_hang_scale
	if vy > 0.0 and not held and not _cut_done and jump_index == 1:
		_cut_done = true
		vy *= jump_cut
	vy = maxf(vy - g * delta, -terminal_speed)
	rising = vy > 0.0
	_air_vy = vy
	return vy


func _launch(index: int) -> float:
	jump_index = index
	jumps_used = index
	airborne = true
	rising = true
	_cut_done = false
	_buffer = 0.0
	_coyote = 0.0
	var v := launch_speed(index)
	_air_vy = v
	jumped.emit(index)
	return v
