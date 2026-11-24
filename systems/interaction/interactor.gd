## Feyre's one "interact" (E / gamepad X): the nearest thing in reach, in the
## order of ORDER below (a stuck arrow, a carcass, a forage spot, a forage
## field instance, a station: hearth, wardrobe, mirror, bed...).
##
## Pickup shapes other lanes implement (no class dependency):
## - group "forage": harvest() -> StringName, and `item_id` so her bags can be
##   checked before it is taken
## - group "forage_field": a MultiMeshInstance3D with meta "ingredient_id"
##   (ForageScatter.nearest_unpicked / take)
## - group "harvestable": harvest() -> Array[Dictionary] of {item_id, qty}, and
##   `items` (the same list) so her bags can be checked first
## - group "station": station_id, use(user)
## Whatever E would do is offered on the one use prompt ("E   pick rose hips").
class_name Interactor
extends Node

signal picked(item_id: StringName, count: int)
signal station_used(station_id: StringName)

const REACH := 2.5
## Stuck arrows this close to a carcass come back when it is harvested.
const CARCASS_ARROWS := 2.0
## Each further arrow pulled in one press chimes this much higher, up to COMBO_MAX steps.
const COMBO_PITCH := 0.06
const COMBO_MAX := 8
## Her thought when a steeped arrow comes back as a plain one.
const SPENT_LINE := "The steeping's spent, but the shaft is good."
const DRESSING_STATIONS: Array[StringName] = [&"wardrobe", &"dressing_mirror"]
const DRESSING_ROOM := preload("res://ui/dressing_room/dressing_room.gd")
const PAINTING_UI := preload("res://ui/studio/studio_ui.gd")
const COLLECTION_UI := preload("res://ui/collection_book/collection_book_ui.gd")

## What E does, in this order: a stuck arrow, a carcass, a forage spot, a
## forage field, a station. A stuck arrow wins over the carcass it sits in or
## beside (F26: an ash arrow by the wolf was lost to the skinning and
## soft-locked the chain); the carcass is skinned before its arrows are pulled
## (F6). Nothing is taken unless it fits in her bags (UX review G1): a target
## that doesn't fit gives way to the next one that does, and when none does
## she says there's no room and nothing changes.
const ORDER: Array[StringName] = [&"arrow", &"carcass", &"spot", &"field", &"station"]
## Her "no room" line waits this long before it is said again (ms).
const NO_ROOM_GAP_MS := 4000
var _spent_ms: int = -NO_ROOM_GAP_MS
const NO_ROOM_LINES := {
	Inventory.QUIVER: "My quiver's full.",
	Inventory.BOWS: "I can't carry another bow.",
	Inventory.KEEPSAKES: "No room for another keepsake.",
	Inventory.POUCH: "No room left in the satchel.",
	Inventory.SATCHEL: "No room left in the satchel.",
}
## The use prompt is refreshed this often (seconds).
const PROMPT_REFRESH := 0.15

var feyre: Feyre
var forage_focus: ForageFocus
var _no_room_ms: int = -NO_ROOM_GAP_MS
var _prompt_since: float = 0.0


func _ready() -> void:
	feyre = get_parent() as Feyre
	Gameplay.listen(&"story_item_granted", _on_story_item_granted)
	Gameplay.collection.discovered.connect(_on_discovered)
	Gameplay.collection.reward_earned.connect(_on_reward)
	_ensure_actions()
	# The collection book is a page of the menu shell, opened with J.
	CollectionTab.ensure(get_tree())
	var windows := Timer.new()
	windows.name = "ForageWindows"
	windows.wait_time = 4.0
	windows.autostart = true
	windows.timeout.connect(update_forage_windows)
	add_child(windows)
	update_forage_windows.call_deferred()
	forage_focus = ForageFocus.new(self)
	add_child(forage_focus)


## Windowed finds (dawn, dusk, night, rain, mist, snow) in any lane's forage
## fields show only while their window is open, so nothing visible ever
## refuses E. Returns how many fields are hidden.
func update_forage_windows() -> int:
	if not is_inside_tree():
		return 0
	var now := ForageRegistry.current_conditions(get_tree())
	var hidden := 0
	for field in get_tree().get_nodes_in_group(ForageScatter.GROUP):
		if not field is Node3D or not field.has_meta(&"ingredient_id"):
			continue
		var item := ItemCatalog.get_item(StringName(field.get_meta(&"ingredient_id")))
		if item == null or (item.bound == &"" and not (item is IngredientData and (item as IngredientData).night_only)):
			continue
		var open := ForageRegistry.in_window(item, now.hour, now.weather)
		(field as Node3D).visible = open
		if not open:
			hidden += 1
	return hidden


func _process(delta: float) -> void:
	_prompt_since += delta
	if _prompt_since < PROMPT_REFRESH or feyre == null or not feyre.is_inside_tree():
		return
	_prompt_since = 0.0
	var t := target()
	UsePrompt.of(get_tree()).offer(self, String(t.get("verb", "")))


func interact() -> bool:
	var t := target()
	if t.is_empty():
		return false
	if not t.fits:
		_no_room(t.item)
		return true
	match t.kind:
		&"arrow":
			return _collect_arrows(t.node)
		&"carcass":
			return _skin(t.node)
		&"spot":
			return _take(StringName(t.node.harvest()), 1, t.node)
		&"field":
			return _take(ForageScatter.take(t.node, t.index), 1, null)
		&"station":
			return _use_station(t.node, t.id)
	return false


## E without stations (in the saddle, MountDirector): an arrow, a carcass or
## a find. True when E did something, "no room" included.
func pick_up() -> bool:
	var t := target()
	if t.is_empty() or t.kind == &"station":
		return false
	return interact()


func pick_up_arrow() -> bool:
	var t := _target_of(&"arrow")
	if t.is_empty():
		return false
	if not t.fits:
		_no_room(t.item)
		return true
	return _collect_arrows(t.node)


## Pulls the arrow, and with it every other arrow stuck in the same body
## (bow design §8.3), each chime a little higher than the last. A full quiver
## stops it there and says so.
func _collect_arrows(node: Node) -> bool:
	var body := _struck_body(node)
	if not _collect_arrow(node):
		return false
	if body == null:
		return true
	var pulled := 1
	for a in get_tree().get_nodes_in_group(Arrow.STUCK_GROUP):
		if a == node or not body.is_ancestor_of(a):
			continue
		if Gameplay.inventory.room_for(_arrow_item(a)) == 0:
			_no_room(_arrow_item(a))
			break
		_collect_arrow(a, pulled)
		pulled += 1
	return true


## The creature (alive or a carcass) an arrow is stuck in, or null.
func _struck_body(node: Node) -> Node:
	var up := node.get_parent()
	while up != null:
		if up is Creature or up.is_in_group(&"harvestable"):
			return up
		up = up.get_parent()
	return null


## What E would do now: {"kind", "node", "verb", "fits", "item", ...}, or {}.
## The first target that fits wins; if none fits, the first that doesn't.
func target() -> Dictionary:
	var refused := {}
	for kind in ORDER:
		var t := _target_of(kind)
		if t.is_empty():
			continue
		if t.fits:
			return t
		if refused.is_empty():
			refused = t
	return refused


func _target_of(kind: StringName) -> Dictionary:
	var inv := Gameplay.inventory
	match kind:
		&"arrow":
			var node := _nearest(get_tree().get_nodes_in_group(Arrow.STUCK_GROUP))
			if node == null:
				return {}
			var item := _arrow_item(node)
			return {"kind": kind, "node": node, "item": item, "verb": "pull the arrow",
				"fits": inv.room_for(item) > 0}
		&"carcass":
			var node := _nearest(get_tree().get_nodes_in_group(&"harvestable"))
			if node == null or not node.has_method(&"harvest"):
				return {}
			var items: Array = node.get(&"items") if &"items" in node else []
			var first := StringName(items[0].get("item_id", &"")) if not items.is_empty() else &""
			return {"kind": kind, "node": node, "item": first, "verb": "skin the %s" % _creature_name(node),
				"fits": inv.fits(items)}
		&"spot":
			var node := _nearest(get_tree().get_nodes_in_group(&"forage"))
			if node == null or not node.has_method(&"harvest") or not node.is_visible_in_tree():
				return {}
			var item := StringName(node.get(&"item_id")) if &"item_id" in node else &""
			return {"kind": kind, "node": node, "item": item, "verb": "take %s" % _item_name(item, "it"),
				"fits": item == &"" or inv.room_for(item) > 0}
		&"field":
			var find := forage_focus.nearest(feyre.global_position, REACH) if forage_focus else {}
			if find.is_empty():
				return {}
			var index := ForageScatter.nearest_unpicked(find.field, find.position, 0.25)
			if index < 0:
				return {}
			return {"kind": kind, "node": find.field, "index": index, "item": find.id,
				"verb": "pick %s" % _item_name(find.id, "it"), "fits": inv.room_for(find.id) > 0}
		&"station":
			# L62: the cottage hearth (a plain node in group "hearth") brews too.
			var node := _nearest(get_tree().get_nodes_in_group(&"station") \
					+ get_tree().get_nodes_in_group(ChemistryStations.HEARTH_GROUP))
			if node == null:
				return {}
			var id := StringName(node.get(&"station_id")) if &"station_id" in node else &""
			if not _station_does_something(node, id):
				return {}
			return {"kind": kind, "node": node, "id": id, "item": &"", "verb": _station_verb(node, id), "fits": true}
	return {}


## `nth` is how many she has already pulled in this one press (0 for the first).
func _collect_arrow(node: Node, nth: int = 0) -> bool:
	var item := _arrow_item(node)
	if Gameplay.inventory.add(item, 1) == 0:
		return false
	if (node as Arrow) and (node as Arrow).data and (node as Arrow).data.steeped:
		_spent()
	var chime := SoundDirector.current.play(&"arrow_retrieve",
			(node as Node3D).global_position if node is Node3D else Vector3.INF) if SoundDirector.current else null
	if chime and nth > 0:
		chime.set(&"pitch_scale", float(chime.get(&"pitch_scale")) * (1.0 + COMBO_PITCH * mini(nth, COMBO_MAX)))
	node.remove_from_group(Arrow.STUCK_GROUP)
	node.queue_free()
	feyre.quiver_changed.emit(Gameplay.inventory.arrow_count())
	picked_up(item, 1, null)
	return true


func _skin(carcass: Node3D) -> bool:
	var got := false
	var pulled := 0
	for entry: Dictionary in carcass.harvest():
		got = _take(StringName(entry.get("item_id", &"")), int(entry.get("qty", 1)), null) or got
	# Skinning it, she pulls her arrows out of it too, so none leave with the body.
	for a in get_tree().get_nodes_in_group(Arrow.STUCK_GROUP):
		if a is Node3D and (a as Node3D).global_position.distance_to(carcass.global_position) <= CARCASS_ARROWS:
			if _collect_arrow(a, pulled):
				pulled += 1
				got = true
	return got


func _use_station(station: Node3D, id: StringName) -> bool:
	if station.has_method(&"use"):
		station.use(feyre)
	if DRESSING_STATIONS.has(id):
		DRESSING_ROOM.open(feyre, id)
	elif id == &"easel":
		PAINTING_UI.open(feyre, station)
	elif StationUses.of(id):
		StationUses.perform(self, station, StationUses.of(id))
	else:
		ChemistryStations.open(feyre, station, id)
	station_used.emit(id)
	return true


## A plain ManorStation or SimpleStation does nothing by itself: it is a target
## only when something here runs it. Anything else (a whorl stone, the mare, a
## wayside nook, a lever) has its own use().
func _station_does_something(station: Node, id: StringName) -> bool:
	if DRESSING_STATIONS.has(id) or id == &"easel":
		return true
	var row := StationUses.of(id)
	if row:
		return row.open_now()
	if ChemistryStations.data_for(station, id) != null:
		return true
	var script := station.get_script() as Script
	return script != ManorStation and script != SimpleStation and station.has_method(&"use")


## The use prompt's verb. Brewing stations show BrewPrompt, and stations with
## their own use() offer their own verb, so they offer nothing here.
func _station_verb(_station: Node, id: StringName) -> String:
	if DRESSING_STATIONS.has(id):
		return "dress"
	if id == &"easel":
		return "paint"
	return StationUses.verb(id)


func _take(id: StringName, count: int, source: Node) -> bool:
	if id == &"" or count <= 0:
		return false
	var added := Gameplay.inventory.add(id, count)
	if added > 0:
		picked_up(id, added, source)
	return added > 0


## Something went into her bags: the picked signal and its sparkle, chime and
## arc (R3). StationUses calls it too.
func picked_up(id: StringName, count: int, source: Node) -> void:
	picked.emit(id, count)
	var item := ItemCatalog.get_item(id)
	Juice.pickup(source, feyre, item.color if item else Color(1, 0.9, 0.95), item != null and item.is_rare())


## No room for `item`: nothing is taken; the log says so in her voice (once in
## a few seconds) and the satchel glyph hears Inventory.refused.
func _no_room(item: StringName) -> void:
	Gameplay.inventory.refuse(item)
	var now := Time.get_ticks_msec()
	if now - _no_room_ms < NO_ROOM_GAP_MS or not is_inside_tree():
		return
	_no_room_ms = now
	PickupLog.of(get_tree()).note(NO_ROOM_LINES.get(Gameplay.inventory.container_for(item), NO_ROOM_LINES[Inventory.SATCHEL]))


## A steeped arrow came back plain: the log says why, once in a few seconds.
func _spent() -> void:
	var now := Time.get_ticks_msec()
	if now - _spent_ms < NO_ROOM_GAP_MS or not is_inside_tree():
		return
	_spent_ms = now
	PickupLog.of(get_tree()).note(SPENT_LINE)


func _arrow_item(node: Node) -> StringName:
	var arrow := node as Arrow
	return arrow.data.retrieved_item() if arrow and arrow.data else &"arrow_wood"


func _item_name(id: StringName, fallback: String) -> String:
	var item := ItemCatalog.get_item(id)
	return item.display_name.to_lower() if item else fallback


func _creature_name(carcass: Node) -> String:
	var id := String(carcass.get(&"creature_id")) if &"creature_id" in carcass else ""
	return id.replace("_", " ") if id != "" else "kill"


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
		Gameplay.wardrobe.grant(item_id)   # WardrobeApplier sparkles it (L64)
		return
	if WardrobeCatalog.hair(item_id):
		Juice.burst(feyre, &"unlock")
		return
	if Gameplay.inventory.add(item_id, count) > 0:
		Juice.burst(feyre, &"unlock")
	feyre.quiver_changed.emit(Gameplay.inventory.arrow_count())


func _on_discovered(entry_id: StringName, tab: StringName) -> void:
	if is_inside_tree() and not COLLECTION_UI.is_open():
		PickupLog.of(get_tree()).find(entry_id, tab)


func _on_reward(reward: CollectionReward) -> void:
	if is_inside_tree():
		PickupLog.of(get_tree()).reward(reward)
		Juice.burst(feyre, &"unlock")


## J / gamepad Back opens the collection book (added in code, R14).
func _ensure_actions() -> void:
	for spec in [[&"open_collection", KEY_J, JOY_BUTTON_BACK]]:
		if InputMap.has_action(spec[0]):
			continue
		InputMap.add_action(spec[0])
		var key := InputEventKey.new()
		key.physical_keycode = spec[1]
		InputMap.action_add_event(spec[0], key)
		var pad := InputEventJoypadButton.new()
		pad.button_index = spec[2]
		InputMap.action_add_event(spec[0], pad)
