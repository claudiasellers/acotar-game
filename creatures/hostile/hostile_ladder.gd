## The hostile perception ladder (docs/contracts/hostiles.md): turns a
## creature's awareness (0..1) into ROUTINE, CURIOUS, SEARCHING, STARTLE,
## ENGAGED or LOST, with BotW's startle window and a wary spell after it
## loses her. Pure: no nodes, so tests step it directly.
class_name HostileLadder
extends RefCounted

enum State { ROUTINE, CURIOUS, SEARCHING, STARTLE, ENGAGED, LOST }

const CURIOUS_AT := 0.15
const SEARCH_AT := 0.4
const ENGAGE_AT := 0.7

## The freeze-and-stare before it commits; breaking sight now drops it back.
var startle_seconds: float = 0.8
## How long awareness must stay under SEARCH_AT before it gives up.
var lost_seconds: float = 6.0
## How long it stays jumpy after giving up.
var wary_seconds: float = 90.0
## Stimulus multiplier while wary.
var wary_gain: float = 1.3

var state: State = State.ROUTINE
var _startle_left: float = 0.0
var _below_left: float = 0.0
var _wary_left: float = 0.0


func step(awareness: float, delta: float) -> State:
	_wary_left = maxf(_wary_left - delta, 0.0)
	match state:
		State.ROUTINE, State.CURIOUS:
			if awareness >= ENGAGE_AT:
				_enter_startle()
			elif awareness >= SEARCH_AT:
				_enter_search()
			elif awareness >= CURIOUS_AT:
				state = State.CURIOUS
			else:
				state = State.ROUTINE
		State.SEARCHING:
			if awareness >= ENGAGE_AT:
				_enter_startle()
			elif _count_below(awareness, delta):
				_enter_lost()
		State.STARTLE:
			_startle_left -= delta
			if _startle_left <= 0.0:
				if awareness >= ENGAGE_AT:
					state = State.ENGAGED
					_below_left = lost_seconds
				else:
					_enter_search()
		State.ENGAGED:
			if _count_below(awareness, delta):
				_enter_lost()
		State.LOST:
			if awareness >= ENGAGE_AT:
				_enter_startle()
			elif _wary_left <= 0.0:
				state = State.ROUTINE
	return state


## Multiplier for new stimulus: higher while wary.
func sensitivity() -> float:
	return wary_gain if _wary_left > 0.0 else 1.0


func is_wary() -> bool:
	return _wary_left > 0.0


## Hunting her (engaged) or about to (the startle window).
func is_hostile() -> bool:
	return state == State.ENGAGED or state == State.STARTLE


## Forced give-up (she was knocked down, it was driven off).
func give_up() -> void:
	_enter_lost()


func _enter_startle() -> void:
	state = State.STARTLE
	_startle_left = startle_seconds


func _enter_search() -> void:
	state = State.SEARCHING
	_below_left = lost_seconds


func _enter_lost() -> void:
	state = State.LOST
	_wary_left = wary_seconds


## True once awareness has stayed under SEARCH_AT for lost_seconds.
func _count_below(awareness: float, delta: float) -> bool:
	if awareness >= SEARCH_AT:
		_below_left = lost_seconds
		return false
	_below_left -= delta
	return _below_left <= 0.0


static func state_name(s: State) -> StringName:
	return [&"routine", &"curious", &"searching", &"startle", &"engaged", &"lost"][s]
