## What brews (lane L62): `brews()` says whether a station brews and
## `label_for()` names it, so Interactor offers "brew at the kitchen range" in
## the one key prompt like any other station. This node only gives Feyre her
## brew tells (BrewTells), so a brew shows however she drank it.
class_name BrewPrompt
extends Node


func _init() -> void:
	name = "BrewPrompt"


func _process(_delta: float) -> void:
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre:
		BrewTells.ensure(feyre)


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
