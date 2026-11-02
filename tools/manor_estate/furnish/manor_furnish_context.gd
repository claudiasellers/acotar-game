## What the furnisher needs to know about the whole house while one part's
## generator runs: every room, door and stair (the other parts read from their
## saved layouts), the windows the builder will cut, the door aprons, and the
## story's keep-clear zones.
class_name ManorFurnishContext
extends RefCounted

var index: ManorHouseIndex
var keep_clear: Array = []
var _openings: Dictionary = {}


## `current` is the layout being generated; the other parts and the anchors
## come from disk (the generators run one part at a time).
func _init(current: ManorHouseLayout) -> void:
	var layouts: Array[ManorHouseLayout] = [current]
	var dir := ManorLayoutDSL.OUT_DIR
	for part in ["ground", "upper", "service", "anchors"]:
		if part == String(current.part_id):
			continue
		var path: String = dir + part + ".tres"
		if ResourceLoader.exists(path):
			var l := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ManorHouseLayout
			if l != null:
				layouts.append(l)
	index = ManorHouseIndex.new(layouts)
	keep_clear = ManorKeepClear.zones(index.anchors)


static func ceiling_of(room: ManorRoomDef) -> float:
	if room.ceiling_height > 0.0:
		return room.ceiling_height
	var storey := ManorSitePlan.CELLAR_DEPTH if room.level < 0 else ManorSitePlan.HOUSE_STOREY
	return storey - 0.32     # ManorHouseBuilder.SLAB + 0.02, as gen_ground._ceiling


static func sides_of(r: Rect2) -> Dictionary:
	return ManorWindows.sides_of(r)


## Doors and windows along one wall: [t0, t1, kind] (ManorWindows.openings).
func openings(room: ManorRoomDef, side: String) -> Array:
	var key := "%s/%d/%s" % [room.id, room.level, side]
	if not _openings.has(key):
		_openings[key] = ManorWindows.openings(index, room, side)
	return _openings[key]


## World rects in front of each door of `room`, inside it, kept clear of furniture.
func door_aprons(room: ManorRoomDef) -> Array:
	var key := "apron/%s/%d" % [room.id, room.level]
	if _openings.has(key):
		return _openings[key]
	var out: Array = []
	var sides := sides_of(room.rect)
	for side in sides:
		var s: Array = sides[side]
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var n: Vector2 = s[2]
		var dir := (b - a).normalized()
		for o in openings(room, side):
			if o[2] != &"door":
				continue
			var p0: Vector2 = a + dir * (o[0] - 0.2)
			var p1: Vector2 = a + dir * (o[1] + 0.2) + n * (ManorFurnisher.WALL_FACE + ManorFurnisher.DOOR_APRON)
			out.append(Rect2(p0, Vector2.ZERO).expand(p1).abs())
	_openings[key] = out
	return out


func in_stair(level: int, rect: Rect2) -> bool:
	for s in index.stairs:
		if (s.level_from == level or s.level_from + 1 == level) and s.rect.grow(0.4).intersects(rect):
			return true
	return false
