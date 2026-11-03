## The title's story slots (SaveSystem.SLOTS, shown as Story 1 to 3), in the
## menu's own place and type. Load lists them to play one; New Game lists them
## to begin in one. Each used slot shows where the story is, the play time and
## when it was saved. Overwriting or deleting a story asks first, here on the
## title: the question replaces the list, and Keep it is where the focus starts.
class_name TitleSlots
extends VBoxContainer

signal chosen(slot: String)
signal closed

enum Mode { LOAD, NEW }

const FONT_MEDIUM := preload("res://ui/title/fonts/EBGaramond-Medium.ttf")
const FONT_ITALIC := preload("res://ui/title/fonts/EBGaramond-MediumItalic.ttf")
const PEARL := Color(0.95, 0.92, 0.96)
const BUTTER := Color(1.0, 0.91, 0.62)
const SHADOW := Color(0.12, 0.08, 0.18, 0.75)
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var mode: Mode = Mode.LOAD
## The slot a question is about, while one is asked.
var asking: String = ""
var _on_focus: Callable


func _init(on_focus: Callable = Callable()) -> void:
	name = "Slots"
	_on_focus = on_focus
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override(&"separation", 6)


## The title's menu look: Garamond, pearl going butter on focus, no box.
static func style(b: Button, font_size: int) -> void:
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_font_override(&"font", FONT_MEDIUM)
	b.add_theme_font_size_override(&"font_size", font_size)
	for state: StringName in [&"font_color", &"font_pressed_color"]:
		b.add_theme_color_override(state, PEARL)
	for state: StringName in [&"font_hover_color", &"font_focus_color", &"font_hover_pressed_color"]:
		b.add_theme_color_override(state, BUTTER)
	b.add_theme_color_override(&"font_disabled_color", Color(PEARL, 0.45))
	b.add_theme_color_override(&"font_outline_color", SHADOW)
	b.add_theme_constant_override(&"outline_size", 6)
	var empty := StyleBoxEmpty.new()
	for box: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
		b.add_theme_stylebox_override(box, empty)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())


static func slot_name(slot: String) -> String:
	return "Story %d" % (SaveSystem.SLOTS.find(slot) + 1)


## "Day 4  ·  2 h 13 min played  ·  saved 3 Nov 2026, 14:05"
static func details(info: Dictionary) -> String:
	if not info.get("readable", false):
		return "This save can't be read"
	var parts: Array[String] = []
	if int(info.day) > 0:
		parts.append("Day %d" % int(info.day))
	var played := int(info.play_seconds)
	if played >= 0:
		var h := played / 3600
		var m := (played % 3600) / 60
		parts.append(("%d h %d min played" % [h, m]) if h > 0 else ("%d min played" % m))
	parts.append("saved " + when(int(info.saved_at)))
	return "  ·  ".join(parts)


static func when(unix: int) -> String:
	var local := unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	return "%d %s %d, %02d:%02d" % [d.day, MONTHS[int(d.month) - 1], d.year, d.hour, d.minute]


func open(new_mode: Mode) -> void:
	mode = new_mode
	visible = true
	_show_list()


func close() -> void:
	visible = false
	asking = ""
	closed.emit()


## Back out one step: from a question to the list, from the list to the menu.
func back() -> void:
	if asking != "":
		var slot := asking
		_show_list()
		_focus_slot(slot)
	else:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		back()
		get_viewport().set_input_as_handled()


func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()


func _show_list() -> void:
	asking = ""
	_clear()
	add_child(_label("Continue which story?" if mode == Mode.LOAD else "Begin in which story?", FONT_ITALIC, 30))
	for slot in SaveSystem.SLOTS:
		_slot_row(slot)
	var back_button := _button("Back", 34, close)
	back_button.name = "Back"
	_focus_first()


func _slot_row(slot: String) -> void:
	var info := SaveSystem.slot_info(slot)
	var row := HBoxContainer.new()
	row.name = slot
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override(&"separation", 26)
	add_child(row)
	if mode == Mode.LOAD and not info.is_empty():
		var del := _button("Delete", 26, _ask.bind(slot), row)
		del.name = "Delete"
		del.add_theme_font_override(&"font", FONT_ITALIC)
	var title := slot_name(slot)
	if info.is_empty():
		title += "  ·  Empty"
	elif String(info.phase) != "":
		title += "  ·  " + String(info.phase)
	var main := _button(title, 38, _pick.bind(slot), row)
	main.name = "Pick"
	main.disabled = mode == Mode.LOAD and (info.is_empty() or not info.readable)
	if not info.is_empty():
		var note := _label(details(info), FONT_ITALIC, 22)
		note.name = slot + "_details"
		add_child(note)


func _pick(slot: String) -> void:
	if mode == Mode.NEW and SaveSystem.has_save(slot):
		_ask(slot)
	else:
		chosen.emit(slot)


## The in-game confirm: overwriting (New Game) or deleting (Load) a story.
func _ask(slot: String) -> void:
	_clear()
	asking = slot
	var overwrite := mode == Mode.NEW
	var question := ("Begin anew in %s?" if overwrite else "Let %s go?") % slot_name(slot)
	add_child(_label(question, FONT_MEDIUM, 40))
	add_child(_label("The story saved there will be lost." if overwrite else "It can't be brought back.", FONT_ITALIC, 26))
	var yes := _button("Begin anew" if overwrite else "Delete it", 38, _confirmed.bind(slot))
	yes.name = "Yes"
	var keep := _button("Keep it", 38, back)
	keep.name = "Keep"
	keep.grab_focus.call_deferred()


func _confirmed(slot: String) -> void:
	if mode == Mode.NEW:
		asking = ""
		chosen.emit(slot)
		return
	SaveSystem.delete_save(slot)
	_show_list()
	if not SaveSystem.any_save():
		close()  # nothing left to load


func _focus_first() -> void:
	for b in find_children("Pick", "Button", true, false):
		if not (b as Button).disabled:
			(b as Button).grab_focus.call_deferred()
			return
	(get_node(^"Back") as Button).grab_focus.call_deferred()


func _focus_slot(slot: String) -> void:
	var b := get_node_or_null(NodePath(slot + "/Pick")) as Button
	if b and not b.disabled:
		b.grab_focus.call_deferred()


func _button(text: String, font_size: int, callback: Callable, parent: Node = self) -> Button:
	var b := Button.new()
	b.text = text
	style(b, font_size)
	if _on_focus.is_valid():
		b.focus_entered.connect(_on_focus.bind(b))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _label(text: String, font: Font, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", Color(0.99, 0.95, 0.90))
	l.add_theme_color_override(&"font_shadow_color", SHADOW)
	l.add_theme_constant_override(&"shadow_offset_y", 2)
	l.add_theme_constant_override(&"shadow_outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
