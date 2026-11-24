## "E  Brew at the kitchen range": the key hint within arm's reach of any
## station that brews (lane L62), a KeyPrompt in HudLayout's PROMPT zone. A
## hint at arm's length, never a marker (R2). It also gives Feyre her brew
## tells (BrewTells), so a brew shows however she drank it.
class_name BrewPrompt
extends Node

const REACH := 2.5

var showing: Node3D = null
var _prompt: KeyPrompt


func _init() -> void:
	name = "BrewPrompt"


func _ready() -> void:
	_prompt = KeyPrompt.make(self)


func _process(_delta: float) -> void:
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre:
		BrewTells.ensure(feyre)
	showing = target(feyre)
	_prompt.say(KeyPrompt.key(&"interact"), "Brew at the %s" % label_for(showing).to_lower() if showing else "")


## The brewing station Feyre is within reach of, or null.
func target(feyre: Node3D) -> Node3D:
	if feyre == null or not StoryControl.can_interact():
		return null
	var best: Node3D = null
	var best_d := REACH
	for group: StringName in [&"station", ChemistryStations.HEARTH_GROUP]:
		for st in get_tree().get_nodes_in_group(group):
			if not st is Node3D or not brews(st):
				continue
			var d := feyre.global_position.distance_to((st as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = st
	return best


static func brews(st: Node) -> bool:
	if st is CookingStation:
		return true
	var id := StringName(st.get(&"station_id")) if &"station_id" in st else &""
	return ChemistryStations.data_for(st, id) != null


static func label_for(st: Node) -> String:
	if st is CookingStation and (st as CookingStation).station:
		return (st as CookingStation).station.display_name
	var shown := String(st.get(&"display_name")) if &"display_name" in st else ""
	if shown != "":
		return shown
	var id := StringName(st.get(&"station_id")) if &"station_id" in st else &""
	var data := ChemistryStations.data_for(st, id)
	return data.display_name if data else "Hearth"
