## One step of an anchored scene: wait, limit control, cue an actor, wait for
## a deed, offer a decision window. A SceneSpace runs its beats in order.
##
## Beats are ticked, never awaited, so tests can drive a whole scene by
## calling SceneSpace.tick() with a fixed delta.
class_name SceneBeat
extends RefCounted

var label: String = ""


func enter(_space: SceneSpace) -> void:
	pass


## Returns true when the beat is finished.
func tick(_space: SceneSpace, _delta: float) -> bool:
	return true


## Timed beats (waits, rides, decision windows) use up the tick's delta;
## instant beats pass it on to the next beat.
func consumes_time() -> bool:
	return false


func exit(_space: SceneSpace) -> void:
	pass
