## How much of Feyre the player holds right now.
##
## Anchored scene spaces narrow control for a few seconds (root design doc
## §12: dialogue is never a mode, Feyre keeps limited control). Gameplay asks
## before acting; it never needs to know which scene is running.
extends Node

signal mode_changed(mode: Mode)
signal focus_changed(target: Node3D)

enum Mode {
	FULL,  ## Normal play.
	WALK,  ## Move and look, no bow and no interaction.
	LOOK,  ## Only the camera moves.
	NONE,  ## Fully staged: input is ignored.
}

var mode: Mode = Mode.FULL
## What the camera drifts toward during a moment (null for none).
var focus: Node3D = null
## Optional actions that stay available in WALK/LOOK, e.g. &"interact" during
## a decision window.
var allowed_actions: PackedStringArray = []


func set_mode(new_mode: Mode, allowed: PackedStringArray = PackedStringArray()) -> void:
	allowed_actions = allowed
	if new_mode == mode:
		return
	mode = new_mode
	mode_changed.emit(mode)


func set_focus(target: Node3D) -> void:
	if target == focus:
		return
	focus = target
	focus_changed.emit(target)


func release() -> void:
	set_focus(null)
	set_mode(Mode.FULL)


func can_move() -> bool:
	return mode == Mode.FULL or mode == Mode.WALK


func can_look() -> bool:
	return mode != Mode.NONE


func can_shoot() -> bool:
	return mode == Mode.FULL or allowed_actions.has("fire")


func can_interact() -> bool:
	return mode == Mode.FULL or allowed_actions.has("interact")
