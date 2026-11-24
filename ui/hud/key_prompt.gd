## The one key prompt: a dark pill in HudLayout's PROMPT zone with a key cap
## and what the key does here ("E  pick rose hips"), or a few of them in a row.
## It says what a key does, never what to do next (R2). Every prompt in play
## is one of these: the press card, the pick card, the stations' hints and
## Act I's taught keys. It fades in when told and out when cleared.
class_name KeyPrompt
extends PanelContainer

const FADE := 0.2
## Space between one key's words and the next key.
const BETWEEN := 34
## Actions other systems add in code once they are up (bow_controller.gd).
const UNBOUND := {&"cycle_arrow": "Q"}
const PAD_BUTTONS := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB"}
const PAD_AXES := {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}
const MOUSE := {MOUSE_BUTTON_LEFT: "Left mouse", MOUSE_BUTTON_RIGHT: "Right mouse"}

var _row: HBoxContainer
var _pairs: Array = []
var _on: bool = false


## A hidden prompt in `zone`, kept by `keeper`.
static func make(keeper: Node, zone: HudLayout.Zone = HudLayout.Zone.PROMPT) -> KeyPrompt:
	var prompt := KeyPrompt.new()
	HudLayout.of(keeper.get_tree()).place(prompt, zone, keeper)
	return prompt


## What an action's key is called on what she is holding: its first key or
## mouse button, or its first pad button once the pad is in use.
static func key(action: StringName) -> String:
	if not InputMap.has_action(action):
		return UNBOUND.get(action, "")
	var pad := SatchelHud.pad_active
	for e in InputMap.action_get_events(action):
		if pad and e is InputEventJoypadButton and PAD_BUTTONS.has((e as InputEventJoypadButton).button_index):
			return PAD_BUTTONS[(e as InputEventJoypadButton).button_index]
		if pad and e is InputEventJoypadMotion and PAD_AXES.has((e as InputEventJoypadMotion).axis):
			return PAD_AXES[(e as InputEventJoypadMotion).axis]
		if not pad and e is InputEventMouseButton and MOUSE.has((e as InputEventMouseButton).button_index):
			return MOUSE[(e as InputEventMouseButton).button_index]
	return BookKit.key_word(action)


func _init() -> void:
	theme_type_variation = &"PromptPill"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.add_theme_constant_override(&"separation", 10)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)


## Shows one key and its words. "" for the words hides the prompt.
func say(cap: String, words: String) -> void:
	says([[cap, words]] if words != "" else [])


## Shows a row of [key, words]; a pair with no key is words alone. [] hides.
func says(pairs: Array) -> void:
	_on = not pairs.is_empty()
	if not _on or pairs == _pairs:
		if _on:
			visible = true
		return
	_pairs = pairs.duplicate(true)
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	for i in pairs.size():
		var pair: Array = pairs[i]
		if i > 0:
			var space := BookKit.gap(0)
			space.custom_minimum_size.x = BETWEEN - 2 * _row.get_theme_constant(&"separation")
			_row.add_child(space)
		if String(pair[0]) != "":
			var cap := PanelContainer.new()
			cap.theme_type_variation = &"PromptKey"
			cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cap.add_child(BookKit.label(String(pair[0]), &"PromptKeyLabel"))
			_row.add_child(cap)
		var words := BookKit.label(String(pair[1]), &"PromptText")
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(words)
	visible = true


func clear() -> void:
	_on = false


func showing() -> bool:
	return _on


## What it says while it shows: "E   pick rose hips", pairs joined by a dot.
func text() -> String:
	if not _on:
		return ""
	var parts := PackedStringArray()
	for pair: Array in _pairs:
		parts.append(("%s   %s" % pair) if String(pair[0]) != "" else String(pair[1]))
	return "  ·  ".join(parts)


func _process(delta: float) -> void:
	modulate.a = move_toward(modulate.a, 1.0 if _on else 0.0, delta / FADE)
	if not _on and modulate.a <= 0.0:
		visible = false
