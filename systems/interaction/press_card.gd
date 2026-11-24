## The small "E   step in" prompt a scene shows while it waits on her press:
## it says what E does here, never what to do next (R2). One per scene, made
## on demand; the prompt itself is a KeyPrompt in HudLayout's PROMPT zone.
class_name PressCard
extends Node

const NODE_NAME := "PressCard"

var _prompt: KeyPrompt


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
	_prompt = KeyPrompt.make(self)


## "" hides it; "step in" shows "E   step in".
func show_text(verb: String) -> void:
	if _prompt:
		_prompt.say(KeyPrompt.key(&"interact"), verb)


func text() -> String:
	return _prompt.text() if _prompt else ""
