## The small "E   step in" card a scene shows while it waits on her press,
## the same card ForageFocus shows over a find ("E   pick rose hips"): it says
## what E does here, never what to do next (R2). One per scene, made on demand.
## The card sits in HudLayout's PROMPT zone.
class_name PressCard
extends Node

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


## The card itself, hidden, in the PROMPT zone and kept by `keeper`.
static func make_card(keeper: Node) -> PanelContainer:
	var card := PanelContainer.new()
	var style := UiStyle.panel_box()
	style.set_content_margin_all(8)
	style.shadow_size = 4
	card.add_theme_stylebox_override(&"panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UiStyle.label("", 17)
	label.name = "Label"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	card.add_child(label)
	card.visible = false
	HudLayout.of(keeper.get_tree()).place(card, HudLayout.Zone.PROMPT, keeper)
	return card


func _ready() -> void:
	_card = make_card(self)
	_label = _card.get_node(^"Label") as Label


## "" hides it; "step in" shows "E   step in".
func show_text(verb: String) -> void:
	if _card == null:
		return
	_card.visible = verb != ""
	if verb != "":
		_label.text = "E   %s" % verb


func text() -> String:
	return _label.text if _card and _card.visible else ""
