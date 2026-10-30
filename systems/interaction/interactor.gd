## Feyre's one "interact" (E / gamepad X): the nearest thing in reach, in this
## order: a carcass to harvest, a stuck arrow, a forage spot, a forage field
## instance, a station (hearth, wardrobe, mirror...).
##
## Pickup shapes other lanes implement (no class dependency):
## - group "forage": harvest() -> StringName
## - group "forage_field": pick_nearest(world_pos, radius) -> StringName
## - group "harvestable": harvest() -> Array[Dictionary] of {item_id, qty}
## - group "station": station_id, use(user)
class_name Interactor
extends Node

signal picked(item_id: StringName, count: int)
signal station_used(station_id: StringName)

const REACH := 2.5
const DRESSING_STATIONS: Array[StringName] = [&"wardrobe", &"dressing_mirror"]
const DRESSING_ROOM := preload("res://ui/dressing_room/dressing_room.gd")
const PAINTING_UI := preload("res://ui/painting/painting_ui.gd")
const COLLECTION_UI := preload("res://ui/collection_book/collection_book_ui.gd")

var feyre: Feyre


func _ready() -> void:
	feyre = get_parent() as Feyre
	Gameplay.listen(&"story_item_granted", _on_story_item_granted)
	Gameplay.collection.discovered.connect(_on_discovered)
	Gameplay.collection.reward_earned.connect(_on_reward)
	_ensure_actions()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_collection") and feyre:
		get_viewport().set_input_as_handled()
		COLLECTION_UI.open(feyre)
	elif event.is_action_pressed(&"weave_crown") and feyre:
		get_viewport().set_input_as_handled()
		weave_crown()


## Weaves a crown from picked blooms and puts it on (C / d-pad down).
func weave_crown() -> StringName:
	var piece := CrownWeaver.weave(Gameplay.inventory, Gameplay.wardrobe)
	if piece == &"":
		var missing := CrownWeaver.blooms_missing(Gameplay.inventory)
		FindCard.note(get_tree(), "A crown needs five flowers, three of one colour. %d more to find." % missing)
		return &""
	Juice.burst(feyre, &"outfit")
	return piece


## A carcass in reach is skinned before the arrows in it are pulled (F6).
func interact() -> bool:
	return _harvest() or pick_up_arrow() or _forage() or _field() or _station()


func pick_up_arrow() -> bool:
	var nearest := _nearest(get_tree().get_nodes_in_group(Arrow.STUCK_GROUP))
	if nearest == null:
		return false
	var arrow := nearest as Arrow
	var item := arrow.data.item_id if arrow and arrow.data else &"arrow_wood"
	if Gameplay.inventory.add(item, 1) == 0:
		return false
	nearest.queue_free()
	feyre.quiver_changed.emit(Gameplay.inventory.arrow_count())
	_picked(item, 1, null)
	return true


func _forage() -> bool:
	var spot := _nearest(get_tree().get_nodes_in_group(&"forage"))
	if spot == null or not spot.has_method(&"harvest"):
		return false
	var id := StringName(spot.harvest())
	return _take(id, 1, spot)


func _field() -> bool:
	var pos := feyre.global_position + Vector3.UP * 0.3
	for field in get_tree().get_nodes_in_group(ForageScatter.GROUP):
		var id := &""
		if field.has_method(&"pick_nearest"):
			id = StringName(field.pick_nearest(pos, REACH))
		elif field is MultiMeshInstance3D and field.has_meta(&"ingredient_id"):
			id = ForageScatter.pick_from(field, pos, REACH)
		if id != &"":
			return _take(id, 1, null)
	return false


func _harvest() -> bool:
	var carcass := _nearest(get_tree().get_nodes_in_group(&"harvestable"))
	if carcass == null or not carcass.has_method(&"harvest"):
		return false
	var got := false
	for entry: Dictionary in carcass.harvest():
		got = _take(StringName(entry.get("item_id", &"")), int(entry.get("qty", 1)), null) or got
	return got


func _station() -> bool:
	var station := _nearest(get_tree().get_nodes_in_group(&"station"))
	if station == null:
		return false
	var id := StringName(station.get(&"station_id")) if &"station_id" in station else &""
	if station.has_method(&"use"):
		station.use(feyre)
	if DRESSING_STATIONS.has(id):
		DRESSING_ROOM.open(feyre, id)
	elif id == &"easel":
		PAINTING_UI.open(feyre, station)
	station_used.emit(id)
	return true


func _take(id: StringName, count: int, source: Node) -> bool:
	if id == &"" or count <= 0:
		return false
	var added := Gameplay.inventory.add(id, count)
	if added > 0:
		_picked(id, added, source)
	return added > 0


func _picked(id: StringName, count: int, source: Node) -> void:
	picked.emit(id, count)
	var item := ItemCatalog.get_item(id)
	Juice.pickup(source, feyre, item.color if item else Color(1, 0.9, 0.95), item != null and item.is_rare())


func _nearest(nodes: Array) -> Node3D:
	var best: Node3D = null
	var best_d := REACH
	for n in nodes:
		if not n is Node3D or not (n as Node3D).is_inside_tree():
			continue
		var d := feyre.global_position.distance_to((n as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


## Story gifts: outfits go to the wardrobe, hairstyles are simply known
## (all are available), everything else goes in the bags.
func _on_story_item_granted(item_id: StringName, count: int) -> void:
	if WardrobeCatalog.piece(item_id):
		if Gameplay.wardrobe.grant(item_id):
			Juice.burst(feyre, &"outfit")
		return
	if WardrobeCatalog.hair(item_id):
		Juice.burst(feyre, &"unlock")
		return
	if Gameplay.inventory.add(item_id, count) > 0:
		Juice.burst(feyre, &"unlock")
	feyre.quiver_changed.emit(Gameplay.inventory.arrow_count())


func _on_discovered(entry_id: StringName, tab: StringName) -> void:
	if is_inside_tree() and not COLLECTION_UI.is_open():
		FindCard.show_find(get_tree(), entry_id, tab)


func _on_reward(reward: CollectionReward) -> void:
	if is_inside_tree():
		FindCard.show_reward(get_tree(), reward)
		Juice.burst(feyre, &"unlock")


## J / gamepad Back opens the collection book; C / d-pad down weaves a crown
## (added in code, R14).
func _ensure_actions() -> void:
	for spec in [[&"open_collection", KEY_J, JOY_BUTTON_BACK], [&"weave_crown", KEY_C, JOY_BUTTON_DPAD_DOWN]]:
		if InputMap.has_action(spec[0]):
			continue
		InputMap.add_action(spec[0])
		var key := InputEventKey.new()
		key.physical_keycode = spec[1]
		InputMap.action_add_event(spec[0], key)
		var pad := InputEventJoypadButton.new()
		pad.button_index = spec[2]
		InputMap.action_add_event(spec[0], pad)
