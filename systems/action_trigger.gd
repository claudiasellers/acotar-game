## The only thing that raises story flags (root design doc §4.1).
##
## Fires when the player walks into it, or when gameplay code calls fire()
## (an arrow hitting a target, a snare closing, a painting finished).
class_name ActionTrigger
extends Area3D

@export var flag: String
@export var once: bool = true
@export var fire_on_body_enter: bool = true
## Only bodies in this group fire it on contact. Empty means any body.
@export var required_group: StringName = &"player"

var fired: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func fire() -> void:
	if once and fired:
		return
	if flag.is_empty():
		push_warning("ActionTrigger '%s' has no flag set" % name)
		return
	fired = true
	WorldState.raise_deed(flag)


func _on_body_entered(body: Node3D) -> void:
	if not fire_on_body_enter:
		return
	if required_group == &"" or body.is_in_group(required_group):
		fire()
