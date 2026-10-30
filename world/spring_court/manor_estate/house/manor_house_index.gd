## Every layout part merged into one queryable house: room lookups by level and
## point, the door/stair graph, and validation used by the builder and tests.
class_name ManorHouseIndex
extends RefCounted

var rooms: Array[ManorRoomDef] = []
var doors: Array[ManorDoorDef] = []
var stairs: Array[ManorStairDef] = []
var stations: Array[ManorStationDef] = []
var secrets: Array[ManorSecretDef] = []
var roofs: Array[ManorRoofDef] = []


func _init(layouts: Array[ManorHouseLayout]) -> void:
	for l in layouts:
		rooms.append_array(l.rooms)
		doors.append_array(l.doors)
		stairs.append_array(l.stairs)
		stations.append_array(l.stations)
		secrets.append_array(l.secrets)
		roofs.append_array(l.roofs)


## Real rooms (not exterior dressing).
func interior_rooms() -> Array[ManorRoomDef]:
	return rooms.filter(func(r: ManorRoomDef) -> bool: return r.kind != &"exterior")


## True if `room` occupies `level` (double-height rooms fill the level above too).
static func occupies(room: ManorRoomDef, level: int) -> bool:
	if room.kind == &"exterior":
		return false
	if room.level == level:
		return true
	return level > room.level and ManorHouseBuilder.ceiling_of(room) > \
			ManorHouseBuilder.floor_y(level) - ManorHouseBuilder.floor_y(room.level)


func rooms_at(level: int, p: Vector2) -> Array[ManorRoomDef]:
	var out: Array[ManorRoomDef] = []
	for r in rooms:
		if r.level == level and r.kind != &"exterior" and r.rect.has_point(p):
			out.append(r)
	return out


func is_inside_any(level: int, p: Vector2) -> bool:
	for r in rooms:
		if occupies(r, level) and r.rect.has_point(p):
			return true
	return false


func doors_on_level(level: int) -> Array[ManorDoorDef]:
	return doors.filter(func(d: ManorDoorDef) -> bool: return d.level == level)


func stair_holes_on(level: int) -> Array:
	var out: Array = []
	for s in stairs:
		if s.level_from + 1 == level:
			out.append(s.rect)
	return out


## Doors run along X when they sit on a north or south wall line of a room.
func door_runs_along_x(door: ManorDoorDef) -> bool:
	for r in rooms:
		if r.level != door.level or r.kind == &"exterior":
			continue
		var on_x_range := door.at.x > r.rect.position.x and door.at.x < r.rect.end.x
		if on_x_range and (absf(door.at.y - r.rect.position.y) < 0.6 or absf(door.at.y - r.rect.end.y) < 0.6):
			return true
	return false


## Rooms a door joins (one or two; one means it leads outside).
func door_rooms(door: ManorDoorDef) -> Array[ManorRoomDef]:
	var out: Array[ManorRoomDef] = []
	for off in [Vector2(0, 0.7), Vector2(0, -0.7), Vector2(0.7, 0), Vector2(-0.7, 0)]:
		for r in rooms_at(door.level, door.at + off):
			if not out.has(r):
				out.append(r)
	return out


## Adjacency: room id -> Array of room ids. Secret/locked doors count only when
## `include_hidden` is true.
func graph(include_hidden: bool = true) -> Dictionary:
	var g := {}
	for r in interior_rooms():
		g[r.id] = []
	for d in doors:
		if not include_hidden and (d.kind == &"secret" or d.kind == &"locked"):
			continue
		var joined := door_rooms(d)
		for a in joined:
			for b in joined:
				if a != b and not g[a.id].has(b.id):
					g[a.id].append(b.id)
	for s in stairs:
		var lower := rooms_at(s.level_from, ManorHouseBuilder.stair_bottom(s))
		lower.append_array(rooms_at(s.level_from, s.rect.get_center()))
		var upper := rooms_at(s.level_from + 1, ManorHouseBuilder.stair_top(s))
		for a in lower:
			for b in upper:
				if not g[a.id].has(b.id):
					g[a.id].append(b.id)
				if not g[b.id].has(a.id):
					g[b.id].append(a.id)
	return g


## Room ids reachable from `start` over the graph.
func reachable(start: StringName, include_hidden: bool = true) -> Dictionary:
	var g := graph(include_hidden)
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: StringName = queue.pop_front()
		for nxt in g.get(cur, []):
			if not seen.has(nxt):
				seen[nxt] = true
				queue.append(nxt)
	return seen


## Pairs of rooms that overlap on a level (a layout bug). Returns "a/b" strings.
func overlaps() -> PackedStringArray:
	var out := PackedStringArray()
	var list := interior_rooms()
	for i in list.size():
		for j in range(i + 1, list.size()):
			var a := list[i]
			var b := list[j]
			for level in range(-1, 5):
				if occupies(a, level) and occupies(b, level):
					var inter := a.rect.intersection(b.rect)
					if inter.size.x > 0.05 and inter.size.y > 0.05:
						out.append("%s/%s@%d" % [a.id, b.id, level])
	return out


func find_room(id: StringName) -> ManorRoomDef:
	for r in rooms:
		if r.id == id:
			return r
	return null
