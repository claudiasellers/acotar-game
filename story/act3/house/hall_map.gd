## Feyre's map of the halls (ch12, L28): from the night after the puca, every
## room she walks into is inked onto her page (HallMapPage), with a little
## picture instead of a name, since she can't write. From the four tower tops
## she sketches what she sees from the windows onto the world map
## (WorldMapHud.reveal_place). Hung on the hall_mark_1 anchor by Act3Anchors;
## the house is the anchor's parent (ManorHouseBuilder puts the anchors there),
## so rooms are tested in house space. State lives in WorldState facts, so a
## reload keeps the page:
##   fact.hall_room.<room_id>.<level>   a room on her page (corridors repeat ids per storey)
##   fact.hall_rooms_enough     plan.min_rooms rooms are on it
##   fact.hall_view.<room_id>   a tower view sketched
## Never marks where the story wants her (R2): it only draws where she has been.
class_name HallMap
extends Node3D

signal room_sketched(room_id: StringName)
signal view_sketched(room_id: StringName, places: PackedStringArray)

const PLAN_PATH := "res://data/story/act3/house/hall_map_plan.tres"
const CHECK_EVERY := 0.25
const ROOM_FACT := "fact.hall_room."
const VIEW_FACT := "fact.hall_view."
const ENOUGH_FACT := "fact.hall_rooms_enough"

@export var plan: HallMapPlan
## Tick from _physics_process. Tests turn this off and call check_at() directly.
@export var auto_tick: bool = true
## {id, name, level, rect: Rect2, kind} for every room the page can hold.
var rooms: Array[Dictionary] = []
## Overridable for tests: draws a place on the world map; true if drawn.
var reveal_fn: Callable = _reveal_on_map
var _t: float = 0.0


func _ready() -> void:
	if plan == null and ResourceLoader.exists(PLAN_PATH):
		plan = load(PLAN_PATH) as HallMapPlan
	if rooms.is_empty():
		rooms = load_rooms()


static func load_rooms() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for layout in ManorHouseBuilder.load_layouts():
		for r: ManorRoomDef in layout.rooms:
			if r.kind == &"exterior":
				continue
			out.append({"id": r.id, "name": r.display_name, "level": r.level, "rect": r.rect, "kind": r.kind})
	return out


func _physics_process(delta: float) -> void:
	if not auto_tick or not mapping():
		return
	_t += delta
	if _t < CHECK_EVERY:
		return
	_t = 0.0
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	var anchor := get_parent()
	var house := anchor.get_parent() as Node3D if anchor else null
	if p == null or house == null:
		return
	check_at(house.to_local(p.global_position))


## Mapping runs from the night after the puca on (ch12) and never stops.
func mapping() -> bool:
	return plan != null and WorldState.has_flag(plan.start_flag)


## Inks the room at a house-space point, if it is new. Returns its id or &"".
func check_at(local: Vector3) -> StringName:
	if not mapping():
		return &""
	var room := room_at(rooms, local)
	if room.is_empty():
		return &""
	var id := StringName(room["id"])
	if WorldState.has_flag(room_fact(room)):
		return &""
	WorldState.set_flag(room_fact(room))
	room_sketched.emit(id)
	if is_inside_tree():
		HallMapPage.find_or_make(self).sketch_room(id)
	if sketched_count() >= plan.min_rooms and not WorldState.has_flag(ENOUGH_FACT):
		WorldState.set_flag(ENOUGH_FACT)
	if plan.lookouts.has(id) or plan.lookouts.has(String(id)):
		_sketch_view(id)
	return id


func _sketch_view(id: StringName) -> void:
	if WorldState.has_flag(VIEW_FACT + String(id)):
		return
	var places := PackedStringArray(plan.lookouts.get(id, plan.lookouts.get(String(id), [])))
	var drawn := PackedStringArray()
	for place in places:
		if bool(reveal_fn.call(StringName(place))):
			drawn.append(place)
	WorldState.set_flag(VIEW_FACT + String(id))
	view_sketched.emit(id, drawn)
	if is_inside_tree() and not drawn.is_empty():
		Juice.burst(get_tree().get_first_node_in_group(&"player"), &"unlock")
		HallMapPage.find_or_make(self).sketch_view(id)


func sketched_count() -> int:
	var n := 0
	for r in rooms:
		if WorldState.has_flag(room_fact(r)):
			n += 1
	return n


func is_sketched(id: StringName) -> bool:
	for r in rooms:
		if StringName(r["id"]) == id and WorldState.has_flag(room_fact(r)):
			return true
	return false


## The fact for one room on one storey.
static func room_fact(room: Dictionary) -> String:
	return "%s%s.%d" % [ROOM_FACT, String(room["id"]), int(room["level"])]


## The room holding a house-space point, on the level whose floor is under it.
static func room_at(list: Array[Dictionary], local: Vector3) -> Dictionary:
	var level := level_at(local.y)
	var at := Vector2(local.x, local.z)
	var best: Dictionary = {}
	for r in list:
		if int(r["level"]) != level or not (r["rect"] as Rect2).has_point(at):
			continue
		# Prefer a room over the corridor it opens off, the smaller rect.
		if best.is_empty() or (r["rect"] as Rect2).get_area() < (best["rect"] as Rect2).get_area():
			best = r
	return best


## The storey whose finished floor is just under a house-space height.
static func level_at(y: float) -> int:
	var level := -1
	for l in [0, 1, 2, 3]:
		if y >= ManorHouseBuilder.floor_y(l) - 0.6:
			level = l
	return level


## The little picture she draws in a room instead of its name.
func pictogram_for(id: StringName) -> String:
	if plan and (plan.pictograms.has(id) or plan.pictograms.has(String(id))):
		return String(plan.pictograms.get(id, plan.pictograms.get(String(id), "")))
	return HallMap.guess_pictogram(String(id))


static func guess_pictogram(id: String) -> String:
	var table := [["kitchen", "pot"], ["bakery", "pot"], ["pantry", "pot"], ["bedroom", "bed"], ["dorm", "bed"],
			["suite", "bed"], ["bedchamber", "bed"], ["bath", "bath"], ["wash", "bath"], ["library", "book"],
			["study", "book"], ["reading", "book"], ["schoolroom", "book"], ["music", "harp"], ["conservatory", "flower"],
			["flower", "flower"], ["rose", "flower"], ["garden", "flower"], ["observatory", "star"], ["moon", "star"],
			["lantern", "star"], ["dining", "cup"], ["tea", "cup"], ["morning", "cup"], ["painting", "brush"],
			["gallery", "brush"], ["portrait", "brush"], ["armory", "bow"], ["ballroom", "crown"], ["infirmary", "bandage"],
			["stillroom", "bottle"], ["cellar", "bottle"], ["wine", "bottle"], ["sewing", "needle"], ["linen", "needle"],
			["weaving", "needle"], ["dressing", "crown"], ["jewel", "crown"], ["candle", "candle"], ["shrine", "candle"],
			["crypt", "candle"], ["stair", "stair"], ["vault", "key"], ["strongroom", "key"], ["store", "key"]]
	for pair in table:
		if id.contains(String(pair[0])):
			return String(pair[1])
	return ""


func _reveal_on_map(place_id: StringName) -> bool:
	if not is_inside_tree():
		return false
	var drew := false
	for node in get_tree().get_nodes_in_group(MapSettings.GROUP):
		if node is WorldMapHud:
			drew = (node as WorldMapHud).reveal_place(place_id, true) or drew
	return drew
