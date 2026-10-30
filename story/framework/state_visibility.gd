## Shows its children only in the right story state: the broken cottage door
## after the beast, the empty pelt rack after the sale. Collision follows
## visibility, like RegionGate.
class_name StateVisibility
extends Node3D

## Visible only once this flag is set (empty: no requirement).
@export var show_when_flag: String = ""
## Hidden once this flag is set (empty: never hidden by a flag).
@export var hide_when_flag: String = ""


func _ready() -> void:
	EventBus.flag_changed.connect(_on_flag_changed)
	EventBus.game_loaded.connect(func(_slot: String) -> void: refresh())
	refresh()


func should_show() -> bool:
	if show_when_flag != "" and not WorldState.has_flag(show_when_flag):
		return false
	if hide_when_flag != "" and WorldState.has_flag(hide_when_flag):
		return false
	return true


func refresh() -> void:
	var shown := should_show()
	visible = shown
	for body in find_children("*", "CollisionObject3D", true, false):
		body.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag == show_when_flag or flag == hide_when_flag:
		refresh()
