## The small "E   step in" card a scene shows while it waits on her press,
## the same card ForageFocus shows over a find ("E   pick rose hips"): it says
## what E does here, never what to do next (R2). One per scene, made on demand.
class_name PressCard
extends CanvasLayer

const NODE_NAME := "PressCard"

var _card: PanelContainer
var _label: Label


static func find_or_make(owner_node: Node) -> PressCard:
	var card := owner_node.get_node_or_null(NODE_NAME) as PressCard
	if card == null:
		card = PressCard.new()
		card.name = NODE_NAME
		owner_node.add_child(card)
	return card


## Hides the card on `owner_node`, if it has one.
static func hide_on(owner_node: Node) -> void:
	var card := owner_node.get_node_or_null(NODE_NAME) as PressCard
	if card:
		card.show_text("")


func _ready() -> void:
	layer = 11
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	_card = PanelContainer.new()
	var style := UiStyle.panel_box()
	style.set_content_margin_all(8)
	style.shadow_size = 4
	_card.add_theme_stylebox_override(&"panel", style)
	_label = UiStyle.label("", 17)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_card.add_child(_label)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.position = Vector2(0, -150)
	_card.visible = false
	anchor.add_child(_card)


## "" hides it; "step in" shows "E   step in".
func show_text(verb: String) -> void:
	if _card == null:
		return
	_card.visible = verb != ""
	if verb != "":
		_label.text = "E   %s" % verb


func text() -> String:
	return _label.text if _card and _card.visible else ""
