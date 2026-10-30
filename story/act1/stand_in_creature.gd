## Behaviour for StandIns.creature(): report the kill, then topple.
class_name StandInCreature
extends StaticBody3D

var kind: StringName
var dead: bool = false


func on_arrow_hit(arrow: Node) -> void:
	if dead:
		return
	var cause: StringName = arrow.get_meta(&"item_id", &"arrow_ash") if arrow else &"arrow_ash"
	if kind == &"great_wolf" and cause != &"arrow_ash":
		# He is High Fae: wood only angers him.
		position += -global_basis.z * 0.6
		return
	dead = true
	rotation.z = PI * 0.5
	EventBus.creature_killed.emit(StringName(name), kind, cause, global_position)
