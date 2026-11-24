## "E  Trade with the clothier": the key hint by a market buyer (lane L53),
## a KeyPrompt in HudLayout's PROMPT zone. Shown only within reach of someone
## who buys, never from afar (R2: a hint at arm's length, not a marker). At
## the fur stall with the wolf's pelt, Act I's own "sell the pelt" prompt
## (KeyPrompts) speaks instead.
class_name MarketPrompt
extends Node

const REACH := 2.5

var showing: StringName = &""
var _prompt: KeyPrompt


func _init() -> void:
	name = "MarketPrompt"


func _ready() -> void:
	_prompt = KeyPrompt.make(self)


func _process(_delta: float) -> void:
	var who := target()
	var buyer := _buyer_of(who) if who else null
	showing = buyer.id if buyer else &""
	_prompt.say(KeyPrompt.key(&"interact"), "Trade with %s" % buyer.display_name if buyer else "")


## The buyer station Feyre is within reach of, or null.
func target() -> Node3D:
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre == null or not StoryControl.can_interact():
		return null
	var best: Node3D = null
	var best_d := REACH
	for st in get_tree().get_nodes_in_group(&"station"):
		var ok := st is MarketStation or (st is FurStall and not (st as FurStall).has_pelt()
				and not FurStall.cobbler().offers(Gameplay.inventory).is_empty())
		if not ok or _buyer_of(st) == null:
			continue
		var d := feyre.global_position.distance_to((st as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = st
	return best


func _buyer_of(st: Node) -> MarketBuyer:
	if st is MarketStation:
		return (st as MarketStation).buyer
	return FurStall.cobbler() if st is FurStall else null
