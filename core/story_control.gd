## How much of Feyre the player holds right now.
##
## Anchored scene spaces narrow control for a few seconds (root design doc
## §12: dialogue is never a mode, Feyre keeps limited control). Gameplay asks
## before acting; it never needs to know which scene is running.
##
## Control is narrowed by holds, each keyed by the object that owns it:
## `hold(self, mode)` / `release(self)`. The effective mode is the most
## restrictive live hold. A hold whose owner is freed, or whose owner Node
## leaves the tree, is dropped on its own, so a scene freed mid-run (a save
## loading, its region streaming out) can never leave her controls narrowed.
##
## `set_mode()` and a bare `release()` are kept for dev tools and tests: they
## act on one anonymous hold, `set_mode(FULL)` and `release()` drop every hold.
extends Node

signal mode_changed(mode: Mode)
signal focus_changed(target: Node3D)

enum Mode {
	FULL,  ## Normal play.
	WALK,  ## Move and look, no bow and no interaction.
	LOOK,  ## Only the camera moves.
	NONE,  ## Fully staged: input is ignored.
}

## The effective mode: the most restrictive live hold (FULL when none).
var mode: Mode = Mode.FULL:
	get:
		_prune()
		return mode
## What the camera drifts toward during a moment (null for none).
var focus: Node3D = null
## Optional actions that stay available in WALK/LOOK, e.g. &"interact" during
## a decision window. Those of the hold that sets the effective mode.
var allowed_actions: PackedStringArray = []:
	get:
		_prune()
		return allowed_actions
## Camera shake 0..1 for frightening moments (the beast in the room).
var shake: float = 0.0

## instance id -> {who: WeakRef, mode: Mode, allowed: PackedStringArray,
## order: int, on_exit: Callable (its tree_exiting hook, Nodes only)}
var _holds: Dictionary = {}
var _order: int = 0
var _pruning: bool = false


## Narrows control on behalf of `who` (a scene passes `self`). Replaces any
## hold `who` already has; FULL is the same as release(who).
func hold(who: Object, new_mode: Mode, allowed: PackedStringArray = PackedStringArray()) -> void:
	if who == null or not is_instance_valid(who):
		return
	if new_mode == Mode.FULL:
		_drop(who.get_instance_id())
		_recompute()
		return
	var id := who.get_instance_id()
	var on_exit: Callable = Callable()
	if _holds.has(id):
		on_exit = _holds[id].on_exit
	elif who is Node:
		on_exit = _on_owner_exiting.bind(id)
		(who as Node).tree_exiting.connect(on_exit, CONNECT_ONE_SHOT)
	_order += 1
	_holds[id] = {"who": weakref(who), "mode": new_mode, "allowed": allowed, "order": _order, "on_exit": on_exit}
	_recompute()


## Drops `who`'s hold. Once no hold is left, the moment's focus and shake
## go too (a scene still holding keeps its own). With no one named, drops every
## hold: dev jumps, tests, a save loading.
func release(who: Object = null) -> void:
	if who == null:
		for id: int in _holds.keys():
			_drop(id)
	else:
		_drop(who.get_instance_id())
	_prune()
	if _holds.is_empty():
		shake = 0.0
		set_focus(null)
	_recompute()


## Dev tools and tests: one anonymous hold. FULL drops every hold.
func set_mode(new_mode: Mode, allowed: PackedStringArray = PackedStringArray()) -> void:
	if new_mode == Mode.FULL:
		for id: int in _holds.keys():
			_drop(id)
		_recompute()
		return
	hold(self, new_mode, allowed)


## The live owners holding control right now (debug and tests).
func holders() -> Array[Object]:
	_prune()
	var out: Array[Object] = []
	for id: int in _holds:
		var o: Object = (_holds[id].who as WeakRef).get_ref()
		if o != null:
			out.append(o)
	return out


func set_focus(target: Node3D) -> void:
	if target == focus:
		return
	focus = target
	focus_changed.emit(target)


func can_move() -> bool:
	return mode == Mode.FULL or mode == Mode.WALK


func can_look() -> bool:
	return mode != Mode.NONE


func can_shoot() -> bool:
	return mode == Mode.FULL or allowed_actions.has("fire")


func can_interact() -> bool:
	return mode == Mode.FULL or allowed_actions.has("interact")


func _process(_delta: float) -> void:
	_prune()


func _on_owner_exiting(id: int) -> void:
	if _holds.has(id):
		_drop(id)
		_settle_orphaned()


func _drop(id: int) -> void:
	if not _holds.has(id):
		return
	var o: Object = (_holds[id].who as WeakRef).get_ref()
	var on_exit: Callable = _holds[id].on_exit
	_holds.erase(id)
	if o is Node and on_exit.is_valid() and (o as Node).tree_exiting.is_connected(on_exit):
		(o as Node).tree_exiting.disconnect(on_exit)


## Drops holds whose owner has been freed.
func _prune() -> void:
	if _pruning or _holds.is_empty():
		return
	var dead: Array[int] = []
	for id: int in _holds:
		if (_holds[id].who as WeakRef).get_ref() == null:
			dead.append(id)
	if dead.is_empty():
		return
	for id in dead:
		_holds.erase(id)
	_settle_orphaned()


## An owner went away without releasing: once nothing holds, its focus and
## shake go too.
func _settle_orphaned() -> void:
	if _holds.is_empty():
		shake = 0.0
		set_focus(null)
	_recompute()


func _recompute() -> void:
	_pruning = true
	var best_mode: Mode = Mode.FULL
	var best_allowed := PackedStringArray()
	var best_order := -1
	for id: int in _holds:
		var h: Dictionary = _holds[id]
		if (h.who as WeakRef).get_ref() == null:
			continue
		var m: Mode = h.mode
		if m > best_mode or (m == best_mode and int(h.order) > best_order):
			best_mode = m
			best_allowed = h.allowed
			best_order = int(h.order)
	allowed_actions = best_allowed
	var changed := best_mode != mode
	mode = best_mode
	_pruning = false
	if changed:
		mode_changed.emit(mode)
