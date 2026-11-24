## Every key, on the settings page: what each action does, its key or mouse
## button and its pad button, read from the InputMap as it is bound now (the
## UX review, 2026-11-24: most keys were never listed anywhere). Read-only.
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
	[&"crouch", "Crouch", "", ""],
	[&"interact", "Use, pick up, talk", "", ""],
	[&"aim", "Aim the bow", "", ""],
	[&"fire", "Loose the arrow", "", ""],
	[&"cycle_arrow", "Next kind of arrow", "", ""],
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

var rows: VBoxContainer


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
		old.free()
	rows.add_child(BookKit.section("Every key"))
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
	if said[1] != "":
		board.add_child(BookKit.key_cap(said[1]))
	if said[2] != "":
		row.add_child(BookKit.key_cap(said[2]))
	return row
