## A short anchored look at something Feyre just did, then the deed's flag:
## the tally on the beam, the pelt coming off, the coin on the stall.
## Subclasses call trigger() when the deed happens (heard on EventBus).
class_name DeedMoment
extends SceneSpace

## Flag raised at the end of the moment.
@export var deed_flag: String
@export var look_seconds: float = 2.5
## What the camera drifts to; the space itself when empty.
@export var focus_path: NodePath

var _triggered: bool = false


func can_start() -> bool:
	return _triggered and super.can_start()


func trigger() -> void:
	_triggered = true
	start()


func _build_beats() -> Array:
	var focus := get_node_or_null(focus_path) as Node3D
	return [
		Beats.control(StoryControl.Mode.LOOK, focus if focus else self),
		Beats.wait(look_seconds),
		Beats.raise(deed_flag),
	]
