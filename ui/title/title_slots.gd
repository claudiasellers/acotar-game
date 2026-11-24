## The title's story slots (SaveSystem.SLOTS, shown as Story 1 to 3), written
## on the first page of the journal once its cover is lifted. Load lists them
## to play one; New Game lists them to begin in one. Each used slot shows
## where the story is, the play time and when it was saved. Overwriting or
## deleting a story asks first, here on the page: the question replaces the
## list, and Keep it is where the focus starts.
class_name TitleSlots
extends VBoxContainer

signal chosen(slot: String)
signal closed

enum Mode { LOAD, NEW }

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## The blot of wash before each story's name, in px.
const BLOT := 34.0

var mode: Mode = Mode.LOAD
## The slot a question is about, while one is asked.
var asking: String = ""


func _init() -> void:
	name = "Slots"
	add_theme_constant_override(&"separation", 6)


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
	ScreenStack.push(self, ScreenStack.Flag.MOUSE)
	_show_list()


func close() -> void:
	visible = false
	ScreenStack.pop(self)
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


## Esc or B while the slot list is the top screen.
func screen_cancel() -> void:
	back()


## The list focuses its own slot (see _show_list).
func screen_focus() -> void:
	pass


func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()


func _show_list() -> void:
	asking = ""
	_clear()
	add_child(BookKit.label("Continue which story?" if mode == Mode.LOAD else "Begin in which story?", &"SatchelHeading"))
	add_child(HSeparator.new())
	add_child(BookKit.gap(10))
	for slot in SaveSystem.SLOTS:
		_slot_row(slot)
	add_child(BookKit.spring())
	if mode == Mode.NEW:
		var hints := CheckBox.new()
		hints.name = "KeyHints"
		hints.text = "Show key hints"
		hints.focus_mode = Control.FOCUS_ALL
		hints.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hints.button_pressed = bool(GameSettings.get_value(&"key_hints"))
		hints.toggled.connect(func(on: bool) -> void: GameSettings.set_value(&"key_hints", on))
		add_child(hints)
		add_child(BookKit.gap(8))
	var back_button := _button("Back", close)
	back_button.name = "Back"
	_focus_first()


func _slot_row(slot: String) -> void:
	var info := SaveSystem.slot_info(slot)
	var row := HBoxContainer.new()
	row.name = slot
	row.add_theme_constant_override(&"separation", 12)
	add_child(row)
	var blot := BookKit.wash(BLOT, SaveSystem.SLOTS.find(slot))
	blot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(blot)
	var title := slot_name(slot)
	if info.is_empty():
		title += "  ·  Empty"
	elif String(info.phase) != "":
		title += "  ·  " + String(info.phase)
	var main := _button(title, _pick.bind(slot), row)
	main.name = "Pick"
	main.disabled = mode == Mode.LOAD and (info.is_empty() or not info.readable)
	if mode == Mode.LOAD and not info.is_empty():
		var room := Control.new()
		room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(room)
		var del := BookKit.chip("Delete", false)
		del.name = "Delete"
		del.focus_mode = Control.FOCUS_ALL
		del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		del.pressed.connect(_ask.bind(slot))
		row.add_child(del)
	if not info.is_empty():
		var note := BookKit.label(details(info), &"SatchelSmall")
		note.name = slot + "_details"
		add_child(note)
	add_child(BookKit.gap(8))


func _pick(slot: String) -> void:
	if mode == Mode.NEW and SaveSystem.has_save(slot):
		_ask(slot)
	else:
		chosen.emit(slot)


## Asked on the page: overwriting (New Game) or deleting (Load) a story.
func _ask(slot: String) -> void:
	_clear()
	asking = slot
	var overwrite := mode == Mode.NEW
	var question := ("Begin anew in %s?" if overwrite else "Let %s go?") % slot_name(slot)
	add_child(BookKit.label(question, &"SatchelHeading"))
	add_child(HSeparator.new())
	add_child(BookKit.label("The story saved there will be lost." if overwrite else "It can't be brought back.", &"SatchelBody"))
	add_child(BookKit.gap(18))
	var yes := _button("Begin anew" if overwrite else "Delete it", _confirmed.bind(slot))
	yes.name = "Yes"
	var keep := _button("Keep it", back)
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


func _button(text: String, callback: Callable, parent: Node = self) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = JournalTheme.PAGE_CHOICE
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.pressed.connect(callback)
	parent.add_child(b)
	return b
