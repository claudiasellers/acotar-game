## Feyre's own plan of the manor's inside: the rooms she has walked into,
## sketched in pencil as she goes, inked once she has drawn the hall map
## (manor_map_drawn), and growing after that. No names (she cannot read yet):
## lines, Xs for doors, circles for windows, a few pictures. Her own rooms are
## known from the night she arrives; the rest only once she has been in them,
## so the cellars and Lucien's rooms stay off until she finds them (R2: it
## never shows her where the story wants her). Owned by WorldMapHud and saved
## with it.
extends RefCounted

## Her suite, and the way to it from the grand stair: known from arrival.
const SUITE: Array[StringName] = [&"feyre_bedroom", &"feyre_morning_room", &"feyre_bath", &"dressing_room"]
const WAY_HOME: Array[StringName] = [&"entrance_hall", &"upper_hall", &"east_corridor"]
const KNOWN_FLAG := "fact.manor_arrived"
const INKED_FLAG := "manor_map_drawn"
const LEVELS: Array[int] = [-1, 0, 1, 2, 3]
## She is on a level once her feet are within this of its floor.
const STEP := 0.6

var index: ManorHouseIndex
## Rooms she has been in (id -> true).
var seen: Dictionary = {}
## Where she is, in house space (updated by locate()).
var inside: bool = false
var level: int = 0
var room: StringName = &""
var at: Vector2 = Vector2.ZERO
## Her facing in house space, radians, 0 = north (-Z), clockwise.
var angle: float = 0.0
## Story facts, injectable for tests.
var has_flag: Callable = func(flag: String) -> bool: return WorldState.has_flag(flag)


func _init(layouts: Array[ManorHouseLayout] = []) -> void:
	index = ManorHouseIndex.new(layouts if not layouts.is_empty() else ManorHouseBuilder.load_layouts())


func known() -> bool:
	return has_flag.call(KNOWN_FLAG)


func inked() -> bool:
	return has_flag.call(INKED_FLAG)


## The level whose floor her feet are on, from house-space height.
static func level_at(y: float) -> int:
	var out := LEVELS[0]
	for l in LEVELS:
		if y >= ManorHouseBuilder.floor_y(l) - STEP:
			out = l
	return out


## Where she is, from her position and facing in house space. Returns inside.
func locate(local: Vector3, local_angle: float = 0.0) -> bool:
	at = Vector2(local.x, local.z)
	angle = local_angle
	level = level_at(local.y)
	room = &""
	for r in index.rooms:
		if r.kind != &"exterior" and r.level == level and r.rect.has_point(at):
			room = r.id
			break
	if room == &"":
		# A double-height room seen from its upper level, or the stair between.
		for r in index.rooms:
			if ManorHouseIndex.occupies(r, level) and r.rect.has_point(at):
				room = r.id
				break
	inside = room != &"" or _on_stair()
	if room != &"":
		seen[room] = true
	return inside


func _on_stair() -> bool:
	for s in index.stairs:
		if (s.level_from == level or s.level_from + 1 == level) and s.rect.has_point(at):
			return true
	return false


func shows(r: ManorRoomDef) -> bool:
	if r.kind == &"exterior":
		return false
	if seen.has(r.id):
		return true
	return known() and (r.id in SUITE or r.id in WAY_HOME)


## The rooms drawn on a level.
func rooms_on(l: int) -> Array[ManorRoomDef]:
	var out: Array[ManorRoomDef] = []
	for r in index.rooms:
		if r.level == l and shows(r):
			out.append(r)
	return out


## Levels with anything to draw, low to high.
func levels_shown() -> Array[int]:
	var out: Array[int] = []
	for l in LEVELS:
		if not rooms_on(l).is_empty():
			out.append(l)
	return out


## Doors on a level that touch a drawn room. Secret ones only once found.
func doors_on(l: int) -> Array[ManorDoorDef]:
	var shown := rooms_on(l)
	var out: Array[ManorDoorDef] = []
	for d in index.doors_on_level(l):
		if d.kind == &"secret" and not has_flag.call("fact.manor.secret_%s" % d.secret_id):
			continue
		for r in shown:
			if r.rect.grow(0.7).has_point(d.at):
				out.append(d)
				break
	return out


## Flights that start or end on a level, inside a drawn room.
func stairs_on(l: int) -> Array[ManorStairDef]:
	var shown := rooms_on(l)
	var out: Array[ManorStairDef] = []
	for s in index.stairs:
		if s.level_from != l and s.level_from + 1 != l:
			continue
		for r in shown:
			if r.rect.intersects(s.rect):
				out.append(s)
				break
	return out


## Window spots (house XZ) on a drawn room's outside walls.
func windows_of(r: ManorRoomDef) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not r.windows or r.level < 0:
		return out
	var rc := r.rect
	var edges := [
		[rc.position, Vector2(1, 0), rc.size.x, Vector2(0, -1)],
		[Vector2(rc.position.x, rc.end.y), Vector2(1, 0), rc.size.x, Vector2(0, 1)],
		[rc.position, Vector2(0, 1), rc.size.y, Vector2(-1, 0)],
		[Vector2(rc.end.x, rc.position.y), Vector2(0, 1), rc.size.y, Vector2(1, 0)],
	]
	for e: Array in edges:
		var length: float = e[2]
		var n := int(floor(length / ManorHouseBuilder.WINDOW_SPACING))
		for i in n:
			var p: Vector2 = e[0] + e[1] * (length * (i + 0.5) / n)
			if not index.is_inside_any(r.level, p + e[3] * 0.8):
				out.append(p)
	return out


## The middle of everything drawn on a level (house XZ), for the full map.
func bounds_of(l: int) -> Rect2:
	var rooms := rooms_on(l)
	if rooms.is_empty():
		return Rect2(at - Vector2(10, 10), Vector2(20, 20))
	var b := rooms[0].rect
	for r in rooms:
		b = b.merge(r.rect)
	return b


func save_state() -> Array:
	var out: Array = []
	for id: StringName in seen:
		out.append(String(id))
	return out


func load_state(data: Variant) -> void:
	seen.clear()
	if data is Array:
		for id: Variant in data:
			seen[StringName(str(id))] = true
