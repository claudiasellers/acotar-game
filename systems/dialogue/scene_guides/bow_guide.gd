## Feyre's one thought about her own bow hand: the first time she lets the
## string down short of a full draw (nothing looses, the arrow stays nocked)
## she tells herself to draw it farther back. Once a game, wherever it
## happens; DialogueDirector keeps the once (the line is a once-line at
## "bow.let_down" in data/dialogue/lines/human_wilds.tres). A child of the
## BowController, and it only listens.
class_name BowGuide
extends Node

const SCENE := &"bow"
const BEAT := &"let_down"


func _ready() -> void:
	name = "BowGuide"
	var bow := get_parent() as BowController
	if bow:
		bow.let_down.connect(on_let_down)


## Says it unless a scene's own beat is being spoken: that thought comes first,
## and this one waits for her next early release.
func on_let_down() -> bool:
	var d := DialogueDirector.of(get_tree())
	if d == null or d.beat_speaking():
		return false
	return not d.say_beat(SCENE, BEAT).is_empty()
