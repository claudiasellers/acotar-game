## One of the evening's deeds in the cottage after the sale (CottageEvening):
## lay the meat and the silver on the table, feed a log to the fire, change at
## the painted dresser, sit to supper. E does it once and raises its fact; the
## family's words follow the fact (R2). Open only on the evening itself (the
## pelt sold, the beast not yet come) and until it is done. A deed with `needs`
## still open gives her thought about the first one instead.
class_name EveningStation
extends KeepsakeStation

const SCENE := &"cottage_evening"

## The use prompt's verb.
@export var use_verb: String = ""
## Facts that must be raised first, each with the thought beat for when it isn't.
@export var needs: PackedStringArray = PackedStringArray()
@export var wait_beats: PackedStringArray = PackedStringArray()


func open_now() -> bool:
	return WorldState.has_flag("pelt_sold") and not WorldState.has_flag("beast_claim_accepted") \
			and not WorldState.has_flag(fact)


## The first need not yet met, or -1.
func missing() -> int:
	for i in needs.size():
		if not WorldState.has_flag(needs[i]):
			return i
	return -1


func use(user: Node) -> void:
	if not open_now():
		return
	var m := missing()
	if m >= 0:
		var d := DialogueDirector.of(get_tree())
		if d and m < wait_beats.size():
			d.say_beat(SCENE, StringName(wait_beats[m]))
		return
	super.use(user)
