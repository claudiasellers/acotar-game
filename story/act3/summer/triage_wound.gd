## One wing stump of the Summer faerie (ch 17: "black velvety stumps",
## jagged, "The wounds aren't clotting"). Steps, in the order Feyre does them:
## read (find where it bleeds from), clean (the wet rag), dress (a salve or
## forage pressed in), bind (Tamlin's linen). Each step only helps; a bad
## dressing makes it worse. Nothing ever stops it: binding soaks through.
class_name TriageWound
extends RefCounted

enum Step { READ, CLEAN, DRESS, BIND, NONE }

## Blood per second from one untreated stump (two stumps: dead in ~167 s).
const BASE_RATE := 0.30
## Never less than this, however well it is dressed (Tamlin's magic fails too).
const FLOOR_RATE := 0.05
## Linen pressure keeps this share of the bleeding (unread: it misses the vessel).
const BOUND_SHARE := 0.6
const BOUND_SHARE_UNREAD := 0.8
## A dressing on an unread or uncleaned stump works at this share.
const BLIND_SHARE := 0.5
## Bound linen soaks through: the rate grows by this share per second bound.
const SOAK_PER_SECOND := 0.01

const SECONDS := {Step.READ: 1.5, Step.CLEAN: 2.0, Step.DRESS: 2.0, Step.BIND: 2.5}

var side: StringName
var read: bool = false
var cleaned: bool = false
var dressed: bool = false
var bound: bool = false
## Dressing rating from TriageMath, [-0.5, 0.65].
var dressing: float = 0.0
var bound_seconds: float = 0.0


func _init(s: StringName = &"left") -> void:
	side = s


## Blood per second from this stump right now.
func rate() -> float:
	var factor := 1.0
	if dressed:
		var share := 1.0
		if not cleaned:
			share *= BLIND_SHARE
		if not read:
			share *= BLIND_SHARE
		factor *= 1.0 - dressing * share
	if bound:
		factor *= BOUND_SHARE if read else BOUND_SHARE_UNREAD
		factor *= 1.0 + SOAK_PER_SECOND * bound_seconds
	return maxf(BASE_RATE * factor, FLOOR_RATE)


func tick(delta: float) -> void:
	if bound:
		bound_seconds += delta


## The next step that still helps, given what she holds. NONE when done or
## when the step needs something she lacks (the rag, linen, a dressing).
func next_step(has_rag: bool, has_dressing: bool, has_linen: bool) -> Step:
	if not read:
		return Step.READ
	if not cleaned and has_rag and not dressed:
		return Step.CLEAN
	if not dressed and not bound and has_dressing:
		return Step.DRESS
	if not bound and has_linen:
		return Step.BIND
	return Step.NONE


## Both treated enough for him to come round (dressed or bound).
func tended() -> bool:
	return dressed or bound
