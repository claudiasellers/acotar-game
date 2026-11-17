## The card E opens at a marked pair of whorl stones: her pictogram sketch of
## the stones she has marked, and one button per pair she can ride to, named
## as the map names the place. Picking one closes the card and starts the ride.
## Pauses the game while open; Esc or "Stay" closes it. No objective text (R2).
class_name WhorlTravelCard
extends CanvasLayer

const NODE_NAME := "WhorlTravelCard"

static var _open: WhorlTravelCard

var from: WhorlStoneDef
var to: Array[WhorlStoneDef] = []
var sketch: WhorlSketch
var buttons: Array[Button] = []


static func is_open() -> bool:
	return _open != null and is_instance_valid(_open)


static func current() -> WhorlTravelCard:
	return _open if is_open() else null


static func open(tree: SceneTree, here: WhorlStoneDef, dests: Array[WhorlStoneDef], _user: Node = null) -> WhorlTravelCard:
	if is_open() or dests.is_empty():
		return current()
	var card := WhorlTravelCard.new()
	card.name = NODE_NAME
	card.from = here
	card.to = dests
	tree.root.add_child(card)
	_open = card
	tree.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return card


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel_box())
	panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	var title := UiStyle.label("The stones I've marked", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	box.add_child(row)
	sketch = WhorlSketch.new()
	sketch.here = from
	sketch.stones = to
	sketch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sketch)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(300, 0)
	list.add_theme_constant_override(&"separation", 8)
	row.add_child(list)
	for d in to:
		var b := UiStyle.button(WhorlStones.place_label(d))
		b.name = "Ride_%s" % d.id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override(&"font_focus_color", UiStyle.TEXT)
		b.add_theme_color_override(&"font_hover_pressed_color", UiStyle.TEXT)
		var dest := d
		b.focus_entered.connect(func() -> void: sketch.pick(dest))
		b.mouse_entered.connect(func() -> void: sketch.pick(dest))
		b.pressed.connect(func() -> void: choose(dest))
		list.add_child(b)
		buttons.append(b)
	var stay := UiStyle.button("Stay")
	stay.name = "Stay"
	stay.add_theme_color_override(&"font_focus_color", UiStyle.TEXT)
	stay.pressed.connect(close)
	list.add_child(stay)
	if not buttons.is_empty():
		buttons[0].grab_focus.call_deferred()
		sketch.pick(to[0])
	Juice.bounce_control(panel, 0.05)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Picks a destination: closes the card and rides there.
func choose(dest: WhorlStoneDef) -> WhorlRide:
	var tree := get_tree()
	close()
	return WhorlStones.travel(tree, dest)


func close() -> void:
	var tree := get_tree()
	if _open == self:
		_open = null
	queue_free()
	if tree:
		tree.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
