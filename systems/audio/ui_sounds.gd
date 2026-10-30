## Glassy hover and bell press for every button in the game, and a harp rise
## and fall when the game pauses (a menu opens) and resumes. Hooks buttons as
## they enter the tree, so no menu has to know about sound. A button with meta
## `silent` = true is skipped.
class_name UiSounds
extends Node

const HOVER_GAP_MS := 60

var director: SoundDirector
var hovers: int = 0
var presses: int = 0
var _last_hover_ms: int = -1000
var _was_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		hook(node)
	_was_paused = get_tree().paused


func _process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused != _was_paused:
		_was_paused = paused
		if director:
			director.play(&"ui_open" if paused else &"ui_close")


func hook(node: Node) -> void:
	if not (node is BaseButton) or node.get_meta(&"silent", false) or node.has_meta(&"_ui_sounds"):
		return
	var button := node as BaseButton
	button.set_meta(&"_ui_sounds", true)
	button.mouse_entered.connect(_on_hover.bind(button))
	button.focus_entered.connect(_on_hover.bind(button))
	button.pressed.connect(_on_press)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		hook(node)


func _on_hover(button: BaseButton) -> void:
	if button.disabled:
		return
	var now := Time.get_ticks_msec()
	if now - _last_hover_ms < HOVER_GAP_MS:
		return
	_last_hover_ms = now
	hovers += 1
	if director:
		director.play(&"ui_hover")


func _on_press() -> void:
	presses += 1
	if director:
		director.play(&"ui_click")
