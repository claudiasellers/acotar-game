## The Weapons page of Feyre's journal (the UX review's G28, 2026-11-25): the
## weapons she has taken, which WeaponRack carries with no screen of its own.
## The left sheet lists the boot knife and each looted weapon; the right
## sheet is the one she has turned to: what it does beside her knife, how
## worn it is, what its imbue slots hold, and the choice the game used to
## make for her: take it in hand, put it away, or leave it lying here.
## Words are WeaponWords'; this only reads the rack and calls hold, put_away
## and drop.
class_name WeaponsTab
extends MenuTab

const DAB := 34.0
const ROW_HEIGHT := 62.0
## The row that is the boot knife (WeaponRack.held uses the same).
const KNIFE := -1
const KNIFE_LINE := "Always with me."

## The rack row the right sheet shows.
var showing: int = KNIFE

var _count: Label
var _list: VBoxContainer
var _name: Label
var _note: Label
var _does: Label
var _wear: Label
var _steeps: Label
var _hold: Button
var _leave: Button
var _rows: Array[Button] = []


func _init() -> void:
	name = "Weapons"
	tab_id = &"weapons"
	tab_title = "Weapons"
	tab_order = 6
	opens_in_story = true


func _ready() -> void:
	_build()


func available() -> bool:
	return is_inside_tree() and _player() != null


func rack() -> WeaponRack:
	return WeaponRack.of(_player())


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _shown() -> void:
	showing = rack().held
	_refresh()


## Turns the right sheet to a row: KNIFE, or an index of the rack.
func show_weapon(index: int) -> void:
	showing = index
	_write_page(rack())


## Takes the shown weapon in hand, or puts it away if it is the one held.
func hold_or_put_away() -> void:
	var r := rack()
	r.hold(KNIFE if showing == r.held else showing)
	_refresh()


## Leaves the shown weapon lying at her feet.
func leave_here() -> void:
	var r := rack()
	var feyre := _player()
	if showing < 0 or showing >= r.carried.size():
		return
	var share := r.wear_of(showing)
	var inst := r.drop(showing)
	WeaponDrop.spawn(feyre.get_parent(), feyre.global_position, inst.id, share, inst.imbue)
	showing = r.held
	_refresh()


func _build() -> void:
	var left := column(left_sheet(), 8)
	var head := HBoxContainer.new()
	left.add_child(head)
	var title := BookKit.title("Weapons")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_count = BookKit.label("", &"SatchelWhere")
	_count.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_count)
	left.add_child(BookKit.label("What I've taken from the things that tried to kill me.", &"SatchelWhere", true))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_list)

	var right := column(right_sheet(), 8)
	_name = BookKit.label("", &"SatchelHeading")
	right.add_child(_name)
	_note = BookKit.label("", &"SatchelWhere", true)
	right.add_child(_note)
	right.add_child(BookKit.section("What it does"))
	_does = BookKit.label("", &"SatchelBody", true)
	right.add_child(_does)
	right.add_child(BookKit.section("How it's holding up"))
	_wear = BookKit.label("", &"SatchelBody", true)
	right.add_child(_wear)
	right.add_child(BookKit.section("Steeped with"))
	_steeps = BookKit.label("", &"SatchelBody", true)
	right.add_child(_steeps)
	right.add_child(BookKit.gap(8.0))
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override(&"separation", 10)
	right.add_child(choices)
	_hold = LoosePage.button("")
	_hold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hold.pressed.connect(hold_or_put_away)
	choices.add_child(_hold)
	_leave = LoosePage.button("Leave it here")
	_leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leave.pressed.connect(leave_here)
	choices.add_child(_leave)
	set_hints([["Q E", "Page"], ["Esc", "Back"]])


func _refresh() -> void:
	var r := rack()
	showing = clampi(showing, KNIFE, r.carried.size() - 1)
	_count.text = "%d of %d carried" % [r.carried.size(), r.capacity]
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	var group := ButtonGroup.new()
	for i in range(KNIFE, r.carried.size()):
		var row := _row(r, i, group)
		_rows.append(row)
		_list.add_child(row)
	if _list.is_visible_in_tree():
		_rows[showing - KNIFE].grab_focus.call_deferred()
	_write_page(r)


## One weapon: a dab of paint, its name, and whether it is in her hand.
func _row(r: WeaponRack, index: int, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.name = "Row%d" % (index + 1)
	b.theme_type_variation = &"SatchelSlot"
	b.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	b.focus_mode = Control.FOCUS_ALL
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = index == showing
	b.pressed.connect(show_weapon.bind(index))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override(&"separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var dab := BookKit.wash(DAB, index + 1)
	dab.modulate.a = LoosePage.DAB_LIFT
	dab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dab)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override(&"separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	words.add_child(BookKit.label(_name_of(r, index), &"SatchelBody"))
	words.add_child(BookKit.label(KNIFE_LINE if index == KNIFE else WeaponWords.wear(r, index), &"SatchelSmall"))
	if index == r.held:
		var badge := BookKit.slot_badge("in hand")
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)
	return b


func _name_of(r: WeaponRack, index: int) -> String:
	return WeaponWords.KNIFE_NAME if index == KNIFE else WeaponWords.name_of(r.carried[index].id)


func _write_page(r: WeaponRack) -> void:
	_name.text = _name_of(r, showing)
	_hold.text = "Put it away" if showing == r.held else "Take it in hand"
	_leave.visible = showing != KNIFE
	if showing == KNIFE:
		_note.text = WeaponWords.KNIFE_NOTE
		_does.text = "What every other blade is measured against."
		_wear.text = "Sound."
		_steeps.text = WeaponWords.NO_SLOTS
		_hold.visible = r.held != KNIFE
		_hold.text = "Take it in hand"
		return
	_hold.visible = true
	var w := WeaponTable.get_weapon(r.carried[showing].id)
	_note.text = w.description
	_does.text = "\n".join(WeaponWords.does(w))
	_wear.text = WeaponWords.wear(r, showing)
	_steeps.text = "\n".join(WeaponWords.steeps(r.carried[showing].imbue))
