## Every key, on the settings page: what each action does, its key or mouse
## button and its pad button, read from the InputMap as it is bound now (the
## UX review, 2026-11-24: most keys were never listed anywhere). A key or
## mouse button is hers to change: press its cap, then the key she wants
## (Esc leaves it be). A key another row had is swapped with this one's; a
## key that moves her is refused. The pad's buttons and the rows whose words
## are given here (movement, the mouse, the quick slots) are not changed here.
## An action no system has added yet (the title has no bow) is left out.
class_name KeyList
extends ScrollContainer

## [action, what it does, keyboard words, pad words]. Words given here stand
## in where the InputMap cannot say it (sticks, the mouse, a chord).
const ROWS: Array[Array] = [
	[&"move_forward", "Move", "scheme", "Left stick"],
	[&"look_left", "Look around", "Mouse", "Right stick"],
	[&"sprint", "Sprint", "", ""],
	[&"jump", "Jump and climb", "", ""],
	[&"jump", "Sidestep, bow raised", "", ""],
	[&"crouch", "Crouch", "", ""],
	[&"interact", "Use, pick up, talk", "", ""],
	[&"fire", "Draw and loose: hold, let go", "", ""],
	[&"aim", "Steady your aim (optional)", "", ""],
	[&"focus", "Steady your breath, bow up", "", ""],
	[&"strike", "Knife", "", ""],
	[&"cycle_arrow", "Next kind of arrow", "", ""],
	[&"arrow_next", "Next arrow, bow up", "", ""],
	[&"arrow_prev", "Previous arrow, bow up", "", ""],
	[&"craft_arrow", "Make an arrow", "", ""],
	[&"cycle_bow", "Change bow", "", ""],
	[&"call_mount", "Whistle for the mare", "", ""],
	[&"camera_recenter", "Camera behind her", "", ""],
	[&"guide_open", "Her thought, again", "", ""],
	[&"satchel_open", "Satchel", "", "LB"],
	[&"quick_1", "Quick slots", "1 – 4", "LB + d-pad"],
	[&"open_collection", "Collection", "", ""],
	[&"journal_open", "Sketchbook", "", ""],
	[&"map_open", "Map", "", ""],
	[&"map_minimap", "Minimap on and off", "", ""],
]
const WORDS_WIDTH := 300.0
const BOARD_WIDTH := 190.0

const LISTENING := "Press a key"

var rows: VBoxContainer
## What the last change did, or why it was refused.
var note: Label
## The action waiting for its new key, or &"" for none.
var listening: StringName = &""
var _said: String = ""


func _init() -> void:
	name = "Keys"
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	set_anchors_preset(Control.PRESET_FULL_RECT)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override(&"separation", 6)
	add_child(rows)


## Reads the InputMap again (the movement keys may have changed).
func refresh() -> void:
	for old in rows.get_children():
		rows.remove_child(old)
		old.queue_free()
	rows.add_child(BookKit.section("Every key"))
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 10)
	rows.add_child(top)
	note = BookKit.label(_said if _said != "" else "Press a key's cap to change it.", &"SatchelSmall", true)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(note)
	var reset := BookKit.chip("Reset keys", false)
	reset.name = "Reset"
	reset.focus_mode = Control.FOCUS_ALL
	reset.pressed.connect(func() -> void:
		_said = "Every key is as it came."
		InputSettings.reset_keys())
	top.add_child(reset)
	for spec: Array in ROWS:
		if InputMap.has_action(spec[0]):
			rows.add_child(_row(spec))
	rows.add_child(_row([ScreenStack.PAUSE, "Pause and settings", "", ""]))


## What is on a row: [what it does, keyboard words, pad words].
static func words(spec: Array) -> Array[String]:
	var board: String = spec[2]
	if board == "scheme":
		board = InputSettings.SCHEME_NAMES[InputSettings.scheme]
	elif board == "":
		board = KeyPrompt.board_word(spec[0])
	var pad: String = spec[3] if spec[3] != "" else KeyPrompt.pad_word(spec[0])
	return [spec[1], board, pad]


func _row(spec: Array) -> Control:
	var said := words(spec)
	var row := HBoxContainer.new()
	row.name = String(spec[0])
	row.add_theme_constant_override(&"separation", 10)
	var what := BookKit.label(said[0], &"SatchelBody")
	what.custom_minimum_size.x = WORDS_WIDTH
	row.add_child(what)
	var board := HBoxContainer.new()
	board.custom_minimum_size.x = BOARD_WIDTH
	row.add_child(board)
	if can_change(spec):
		var cap := BookKit.chip(LISTENING if listening == spec[0] else said[1], false)
		cap.name = "Bind"
		cap.focus_mode = Control.FOCUS_ALL
		cap.pressed.connect(func() -> void:
			listening = spec[0]
			cap.text = LISTENING)
		board.add_child(cap)
	elif said[1] != "":
		board.add_child(BookKit.key_cap(said[1]))
	if said[2] != "":
		row.add_child(BookKit.key_cap(said[2]))
	return row


## Whether a row's key is hers to change: its words come from the InputMap.
static func can_change(spec: Array) -> bool:
	return spec[2] == "" and InputMap.has_action(spec[0])


## The actions whose keys can be swapped with one another.
static func changeable() -> Array[StringName]:
	var out: Array[StringName] = []
	for spec: Array in ROWS:
		if can_change(spec) and not out.has(spec[0]):
			out.append(spec[0])
	return out


## The next key or mouse button pressed is the listening row's.
func _input(event: InputEvent) -> void:
	if listening == &"" or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	var button := event as InputEventMouseButton
	if (key == null or not key.pressed or key.echo) and (button == null or not button.pressed):
		return
	get_viewport().set_input_as_handled()
	var action := listening
	listening = &""
	# The row that has this key now, and will take the listening row's.
	var had := &""
	for other: StringName in changeable():
		if other != action and InputSettings.board_events(other).any(func(e: InputEvent) -> bool:
				return InputSettings.signature(e) == InputSettings.signature(event)):
			had = other
	if key != null and key.physical_keycode == KEY_ESCAPE:
		_said = ""
	elif InputSettings.rebind(action, event, changeable()):
		_said = "%s is now %s." % [_what(action), KeyPrompt.board_word(action)]
		if had != &"":
			_said += " %s moved to %s." % [_what(had), KeyPrompt.board_word(had)]
	else:
		_said = "That key moves her."
	refresh()


func _what(action: StringName) -> String:
	for spec: Array in ROWS:
		if spec[0] == action:
			return String(spec[1]).get_slice(":", 0).get_slice(",", 0)
	return String(action)
