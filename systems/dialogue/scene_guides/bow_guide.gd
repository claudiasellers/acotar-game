## Feyre's one thought about her own bow hand: the first time she lets an
## arrow go well short of a full draw (a weak, short shot) she tells herself
## to draw it farther back. Once a game, wherever it
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
		bow.loosed_short.connect(func(_draw: float) -> void: on_short_shot())


## Says it unless a scene's own beat is being spoken: that thought comes first,
## and this one waits for her next early release.
func on_short_shot() -> bool:
	var d := DialogueDirector.of(get_tree())
	if d == null or d.beat_speaking():
		return false
	return not d.say_beat(SCENE, BEAT).is_empty()
