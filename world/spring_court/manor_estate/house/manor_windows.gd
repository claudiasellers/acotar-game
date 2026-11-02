## Where the builder cuts doors and windows into a room's walls, without the
## builder (it needs the autoloads, and the layout generators run without them).
## Same rules and numbers as ManorHouseBuilder._build_walls; a test keeps the
## constants equal. Used for curtains (ManorRoomFinish) and by the refurnish
## generators to keep furniture off windows and doors.
class_name ManorWindows
extends RefCounted

const SPACING := 4.2          # ManorHouseBuilder.WINDOW_SPACING
const WIDTH := 1.5            # ManorHouseBuilder.WINDOW_WIDTH
const SILL := 0.9             # ManorHouseBuilder.SILL
const DOOR_TOLERANCE := 0.6   # ManorHouseBuilder.DOOR_TOLERANCE


## The four walls as [a, b, inward normal] in world XZ, in the builder's order.
static func sides_of(r: Rect2) -> Dictionary:
	return {
		"n": [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(0, 1)],
		"s": [Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(0, -1)],
		"w": [Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Vector2(1, 0)],
		"e": [Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(-1, 0)],
	}


## Doors and windows along one wall of `room`: [t0, t1, kind], t from the
## wall's start (sides_of). Mirrors the opening and window rules of
## ManorHouseBuilder._build_walls, so curtains and furniture line up with the
## windows it cuts.
static func openings(all: ManorHouseIndex, room: ManorRoomDef, side: String) -> Array:
	var s: Array = sides_of(room.rect)[side]
	var a: Vector2 = s[0]
	var b: Vector2 = s[1]
	var n: Vector2 = s[2]
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var out: Array = []
	for door in all.doors_on_level(room.level):
		var d: Vector2 = door.at - a
		var along := d.dot(dir)
		if absf(d.dot(n)) <= DOOR_TOLERANCE and along > -0.01 and along < length + 0.01:
			out.append([along - door.width * 0.5, along + door.width * 0.5, &"door"])
	if room.windows and (room.kind != &"corridor" or room.level >= 0) and room.level >= 0:
		var count := int(floor(length / SPACING))
		for i in count:
			var along := (i + 0.5) * length / count
			if all.is_inside_any(room.level, a + dir * along - n * 0.8):
				continue
			var clash := false
			for o in out:
				if along + WIDTH > o[0] - 0.4 and along - WIDTH < o[1] + 0.4:
					clash = true
			if not clash:
				out.append([along - WIDTH * 0.5, along + WIDTH * 0.5, &"window"])
	out.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	return out
