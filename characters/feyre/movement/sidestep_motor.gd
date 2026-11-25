## Feyre's sidestep: her one defensive move (health-interactions §3.5 #9, bow
## design §3). With the bow raised, the jump key is the sidestep: DISTANCE in
## TIME the way the stick points (back from her aim if it points nowhere),
## with a short spell nothing can hurt her in from its second frame. It costs
## STAMINA, works crouched, and keeps half her draw.
##
## A press waits BUFFER real seconds for the moment it can run. That wait does
## not count down during a hit-stop, so a press on the first frame of a freeze
## runs on the frame the freeze ends (§3.5 #2).
##
## The owner calls `press()` on the key, `wait(real_delta, frozen)` every
## frame, and in its physics step `begin()` when `wanted()` and she can, then
## `step()` for her ground speed while `active`.
class_name SidestepMotor
extends RefCounted

signal stepped(direction: Vector3)

const DISTANCE := 2.2
const TIME := 0.25
const STAMINA := 12.0
## From the end of one to the start of the next.
const COOLDOWN := 0.45
const BUFFER := 0.15
## Nothing lands on her this long (Gentle Mode: longer), from this physics frame of the step.
const IFRAMES := 0.2
const IFRAMES_GENTLE := 0.3
const IFRAMES_FROM_FRAME := 2

var active: bool = false
var direction := Vector3.ZERO
## True for the one physics frame her spell of safety begins on.
var safe_now: bool = false

var _buffer: float = 0.0
var _left: float = 0.0
var _cooldown: float = 0.0
var _frame: int = 0


func press() -> void:
	_buffer = BUFFER


## Counts the press's wait down in real seconds; a hit-stop holds it.
func wait(real_delta: float, frozen: bool) -> void:
	if not frozen:
		_buffer = maxf(_buffer - real_delta, 0.0)


func wanted() -> bool:
	return _buffer > 0.0


func ready() -> bool:
	return not active and _cooldown <= 0.0


## Starts the step along `toward` (flat, any length).
func begin(toward: Vector3) -> void:
	direction = Vector3(toward.x, 0.0, toward.z).normalized()
	active = true
	_left = TIME
	_frame = 0
	_buffer = 0.0
	stepped.emit(direction)


## One physics frame. Returns her ground velocity for it (zero when not stepping).
func step(delta: float) -> Vector3:
	safe_now = false
	if not active:
		_cooldown = maxf(_cooldown - delta, 0.0)
		return Vector3.ZERO
	_frame += 1
	safe_now = _frame == IFRAMES_FROM_FRAME
	var take := minf(delta, _left)
	_left -= take
	if _left <= 0.0:
		active = false
		_cooldown = COOLDOWN
	# The last frame carries only what is left, so the whole step is DISTANCE.
	return direction * (DISTANCE / TIME) * (take / delta if delta > 0.0 else 0.0)


func iframes(gentle: bool) -> float:
	return IFRAMES_GENTLE if gentle else IFRAMES


## A teleport, a cutscene, a climb: whatever she was doing is over.
func cancel() -> void:
	active = false
	safe_now = false
	_buffer = 0.0
	_left = 0.0
