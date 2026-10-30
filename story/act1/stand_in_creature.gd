## Behaviour for StandIns.creature(): report hits and the kill.
## The great wolf (ch1): the ash arrow wounds him in the side; the next arrow
## after that kills him. Wood alone only wounds. Other creatures die at once.
class_name StandInCreature
extends StaticBody3D

var kind: StringName
var dead: bool = false
var ash_in_him: bool = false


func on_arrow_hit(arrow: Node) -> void:
	if dead:
		return
	var cause: StringName = arrow.get_meta(&"item_id", &"arrow_wood") if arrow else &"arrow_wood"
	if kind == &"great_wolf":
		if not ash_in_him and cause != &"arrow_ash" and not arrow.has_meta(&"item_id"):
			cause = &"arrow_ash"  # untyped M0 arrows: the first one is the ash arrow
		if not ash_in_him:
			ash_in_him = cause == &"arrow_ash"
			EventBus.creature_hit.emit(StringName(name), kind, cause, &"side")
			return
	dead = true
	rotation.z = PI * 0.5
	EventBus.creature_killed.emit(StringName(name), kind, cause, global_position)
