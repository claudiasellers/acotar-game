## Which world stations brew (lane L62). The manor's kitchen range, bread
## oven, stillroom bench and hearths are ManorStations, and the cottage hearth
## is a plain node in group "hearth"; this maps each to its StationData and
## binds a CookingStation child to it on first use, so all of them cook through
## the one chemistry path (CookingStation.cook -> Chemistry.combine).
class_name ChemistryStations
extends RefCounted

## ManorStation.station_id -> StationData.
const BY_ID := {
	&"hearth": preload("res://data/stations/hearth.tres"),
	&"kitchen": preload("res://data/stations/manor_kitchen.tres"),
	&"bread_oven": preload("res://data/stations/manor_kitchen.tres"),
	&"stillroom": preload("res://data/stations/stillroom.tres"),
}
## Plain nodes in this group (the cottage hearth) are hearths.
const HEARTH_GROUP := &"hearth"
const BOUND := &"ChemistryStation"


## The StationData a world node brews with, or null when it doesn't.
static func data_for(node: Node, station_id: StringName = &"") -> StationData:
	if node == null or node is CookingStation:
		return null
	if BY_ID.has(station_id):
		return BY_ID[station_id]
	if node.is_in_group(HEARTH_GROUP):
		return BY_ID[&"hearth"]
	return null


## The CookingStation that brews for `node` (made on first use), or null.
static func bind(node: Node, station_id: StringName = &"") -> CookingStation:
	if node is CookingStation:
		return node
	var data := data_for(node, station_id)
	if data == null or not node is Node3D:
		return null
	var bound := node.get_node_or_null(NodePath(BOUND)) as CookingStation
	if bound:
		return bound
	bound = CookingStation.new()
	bound.name = BOUND
	var named := data.duplicate() as StationData
	var shown := String(node.get(&"display_name")) if &"display_name" in node else ""
	if shown != "":
		named.display_name = shown
	bound.station = named
	# Its fire, warmth and interaction already belong to the node it sits on.
	bound.lit = false
	node.add_child(bound)
	bound.remove_from_group(&"station")
	bound.remove_from_group(ElementState.HEAT_GROUP)
	return bound


## Opens the brewing screen for `node` if it brews. Returns true when it did.
static func open(feyre: Feyre, node: Node, station_id: StringName = &"") -> bool:
	var station := bind(node, station_id)
	if station == null:
		return false
	BrewMenu.open_for(feyre, station)
	return true
