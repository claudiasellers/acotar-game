## A market buyer Feyre can walk up to (lane L53): E opens the sell screen
## (MarketMenu) for that buyer. A station like any other (Interactor, group
## "station"); no collision of its own.
class_name MarketStation
extends SimpleStation

const GROUP := &"market_station"

var buyer: MarketBuyer
## The presence speaker who sells here (the mercenary), if any: she turns to
## talk while the screen is open.
var speaker_id: StringName = &""


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = 0


func use(user: Node) -> void:
	super.use(user)
	MarketMenu.open_for(get_tree(), buyer, speaker())


func speaker() -> Node3D:
	if speaker_id == &"":
		return null
	var best: Node3D = null
	for n in get_tree().get_nodes_in_group(DialogueDirector.PRESENCE_GROUP):
		if n is Node3D and n.has_meta(&"speaker") and StringName(n.get_meta(&"speaker")) == speaker_id:
			if best == null or global_position.distance_to(n.global_position) < global_position.distance_to(best.global_position):
				best = n
	return best
