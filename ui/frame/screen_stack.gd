## The open screens, and the four things only an open screen may change: the
## pause, the mouse, who answers Esc, and where gamepad focus sits. A screen is
## any node that takes the player out of the world (the book, the pause panel,
## a station, the title). It calls push() when it opens and pop() when it
## closes, and never touches the pause, the mouse or Esc itself.
## Autoload. Contract: docs/contracts/ui-frame.md.
extends Node

enum Flag {
	PAUSES = 1,  ## The game is paused while this screen is open.
	MOUSE = 2,  ## The mouse pointer shows while this screen is open.
}

## After every push and pop. `top` is null when no screen is open.
signal changed(top: Node)
## Esc or Start with no screen open.
signal pause_requested

## Screens open at once. The layer band above SCREEN starts at LINE.
const MAX_DEPTH := UiLayers.LINE - UiLayers.SCREEN - 1
const PLAYER_GROUP := &"player"


class Entry:
	var screen: Node
	var flags: int
	var process_mode_before: Node.ProcessMode
	var focus_before: Control
	var cancel: Callable
	var on_exit: Callable


var _entries: Array[Entry] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	JournalTheme.follow_story()
	add_child(HudLayout.new())


## `cancel` is for a screen built without a script of its own; a screen
## with one implements screen_cancel() instead.
func push(screen: Node, flags: int = Flag.PAUSES | Flag.MOUSE, cancel: Callable = Callable()) -> void:
	if has(screen):
		return
	assert(_entries.size() < MAX_DEPTH, "too many screens open at once")
	var e := Entry.new()
	e.screen = screen
	e.flags = flags
	e.process_mode_before = screen.process_mode
	e.focus_before = get_viewport().gui_get_focus_owner()
	e.cancel = cancel
	e.on_exit = pop.bind(screen)
	screen.tree_exiting.connect(e.on_exit)
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_entries.append(e)
	_place()
	_apply()
	_focus(screen)
	changed.emit(screen)


func pop(screen: Node) -> void:
	var i := _index_of(screen)
	if i < 0:
		return
	var e := _entries[i]
	_entries.remove_at(i)
	screen.tree_exiting.disconnect(e.on_exit)
	screen.process_mode = e.process_mode_before
	if not is_inside_tree():
		return
	_place()
	_apply()
	if is_instance_valid(e.focus_before) and e.focus_before.is_visible_in_tree():
		e.focus_before.grab_focus()
	else:
		get_viewport().gui_release_focus()
	changed.emit(top())


func top() -> Node:
	return null if _entries.is_empty() else _entries[-1].screen


func has(screen: Node) -> bool:
	return _index_of(screen) >= 0


func is_empty() -> bool:
	return _entries.is_empty()


## Whether the pointer shows: a screen wants it, or there is no one to steer.
func mouse_shown() -> bool:
	return _any(Flag.MOUSE) or get_tree().get_first_node_in_group(PLAYER_GROUP) == null


func layer_of(screen: Node) -> int:
	return UiLayers.SCREEN + maxi(_index_of(screen), 0)


func _index_of(screen: Node) -> int:
	for i in _entries.size():
		if _entries[i].screen == screen:
			return i
	return -1


func _any(flag: Flag) -> bool:
	for e in _entries:
		if e.flags & flag:
			return true
	return false


func _place() -> void:
	for i in _entries.size():
		var layer := _entries[i].screen as CanvasLayer
		if layer:
			layer.layer = UiLayers.SCREEN + i


func _apply() -> void:
	get_tree().paused = _any(Flag.PAUSES)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mouse_shown() else Input.MOUSE_MODE_CAPTURED


func _focus(screen: Node) -> void:
	if screen.has_method(&"screen_focus"):
		screen.call(&"screen_focus")
		return
	var first := _first_focusable(screen)
	if first:
		first.grab_focus()


func _first_focusable(node: Node) -> Control:
	var c := node as Control
	if c and c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree():
		return c
	for child in node.get_children():
		var found := _first_focusable(child)
		if found:
			return found
	return null


## Whether `event` is a press the stack answers (Esc, Start, B). A screen that
## swallows the rest of the input while it is open lets these through.
func answers(event: InputEvent) -> bool:
	return not event.is_echo() \
			and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"))


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and not mouse_shown() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# The window lost the pointer (alt-tab, a web canvas): a click takes it back.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if not answers(event):
		return
	if _entries.is_empty():
		if event.is_action_pressed(&"pause"):
			pause_requested.emit()
			get_viewport().set_input_as_handled()
		return
	var screen := top()
	if _entries[-1].cancel.is_valid():
		_entries[-1].cancel.call()
	elif screen.has_method(&"screen_cancel"):
		screen.call(&"screen_cancel")
	else:
		pop(screen)
		if screen is CanvasItem or screen is CanvasLayer:
			screen.set(&"visible", false)
	get_viewport().set_input_as_handled()
