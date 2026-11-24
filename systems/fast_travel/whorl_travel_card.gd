## The card E opens at a marked pair of whorl stones: her pictogram sketch of
## the stones she has marked, and one button per pair she can ride to, named
## as the map names the place. Picking one closes the card and starts the ride.
## Pauses the game while open; Esc or "Stay" closes it. No objective text (R2).
class_name WhorlTravelCard
extends CanvasLayer

const NODE_NAME := "WhorlTravelCard"
const WIDTH := 840.0

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
	ScreenStack.push(card)
	return card


func _ready() -> void:
	var page := LoosePage.lay(self, WIDTH, 14)
	var box := page.column
	var title := BookKit.label("The stones I've marked", &"SatchelHeading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	box.add_child(row)
	sketch = WhorlSketch.new()
	sketch.here = from
	sketch.stones = to
	sketch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sketch)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(290, 0)
	list.add_theme_constant_override(&"separation", 8)
	row.add_child(list)
	list.add_child(BookKit.label("From %s" % WhorlStones.place_label(from), &"SatchelSmall"))
	for d in to:
		var b := _tab(WhorlStones.place_label(d))
		b.name = "Ride_%s" % d.id
		var dest := d
		b.focus_entered.connect(func() -> void: sketch.pick(dest))
		b.mouse_entered.connect(func() -> void: sketch.pick(dest))
		b.pressed.connect(func() -> void: choose(dest))
		list.add_child(b)
		buttons.append(b)
	var stay := _tab("Stay")
	stay.name = "Stay"
	stay.pressed.connect(close)
	list.add_child(stay)
	if not buttons.is_empty():
		buttons[0].grab_focus.call_deferred()
		sketch.pick(to[0])
	page.settle()


func _tab(text: String) -> Button:
	var b := LoosePage.button(text)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


## Esc or B while the card is the top screen.
func screen_cancel() -> void:
	close()


## Picks a destination: closes the card and rides there.
func choose(dest: WhorlStoneDef) -> WhorlRide:
	var tree := get_tree()
	close()
	return WhorlStones.travel(tree, dest)


func close() -> void:
	if _open == self:
		_open = null
	ScreenStack.pop(self)
	queue_free()
