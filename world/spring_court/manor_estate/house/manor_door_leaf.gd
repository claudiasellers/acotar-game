## A door leaf (locked door or disguised secret door) that swings away for good
## once its flag is raised in WorldState. Never an invisible wall.
class_name ManorDoorLeaf
extends Node3D

@export var open_flag: String


func _ready() -> void:
	EventBus.flag_changed.connect(_on_flag_changed)
	refresh()


func is_open() -> bool:
	return open_flag != "" and WorldState.has_flag(open_flag)


func refresh() -> void:
	if not is_inside_tree():
		return
	var open := is_open()
	visible = not open
	for body in find_children("*", "CollisionObject3D", true, false):
		body.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag == open_flag:
		refresh()
