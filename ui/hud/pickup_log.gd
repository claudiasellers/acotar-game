## The pickup log: what she has just put in her bags, in HudLayout's PICKUPS
## zone (left, mid-screen). One row a thing, "Rose hips ×2", on a dark trail
## that fades to nothing rightwards; picking more of the same adds to its row.
## A row stays a few seconds and the oldest go first. It says what she got,
## never what is left to find (R2).
class_name PickupLog
extends VBoxContainer

const HOLD := 2.8
const FADE := 0.5
const MAX_ROWS := 4
const ICON := 30.0
const WIDTH := 300.0

## id -> its Row, while it shows.
var _rows: Dictionary[StringName, Row] = {}


## An empty log in the PICKUPS zone, kept by `keeper`.
static func make(keeper: Node) -> PickupLog:
	var log := PickupLog.new()
	HudLayout.of(keeper.get_tree()).place(log, HudLayout.Zone.PICKUPS, keeper)
	return log


func _init() -> void:
	name = "PickupLog"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 4)


## `count` more of `id` went into her bags.
func add(id: StringName, count: int) -> void:
	var row := _rows.get(id) as Row
	if row == null or row.leaving():
		row = Row.new(id)
		_rows[id] = row
		add_child(row)
		while get_child_count() > MAX_ROWS:
			var oldest := get_child(0)
			remove_child(oldest)
			oldest.queue_free()
	row.more(count)


## What the log reads now, top to bottom: ["Rose hips ×2", ...].
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for row in get_children():
		if not (row as Row).leaving():
			out.append((row as Row).text())
	return out


class Row extends PanelContainer:
	var count: int = 0
	var _label: Label
	var _name: String
	var _left: float = 0.0

	func _init(id: StringName) -> void:
		theme_type_variation = &"PickupRow"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.x = PickupLog.WIDTH
		modulate.a = 0.0
		var item := ItemCatalog.get_item(id)
		_name = item.display_name if item else String(id).capitalize()
		var box := HBoxContainer.new()
		box.add_theme_constant_override(&"separation", 12)
		add_child(box)
		var icon := ItemIcon.make(item.icon if item else &"trinket", item.color if item else JournalTheme.wash(0),
				false, item != null and item.rarity == &"shiny", PickupLog.ICON)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		_label = BookKit.label("", &"PickupText")
		box.add_child(_label)

	func more(n: int) -> void:
		count += n
		_label.text = text()
		_left = PickupLog.HOLD

	func text() -> String:
		return "%s  ×%d" % [_name, count]

	func leaving() -> bool:
		return _left <= 0.0

	func _process(delta: float) -> void:
		_left -= delta
		modulate.a = move_toward(modulate.a, 0.0 if leaving() else 1.0, delta / PickupLog.FADE)
		if leaving() and modulate.a <= 0.0:
			queue_free()
