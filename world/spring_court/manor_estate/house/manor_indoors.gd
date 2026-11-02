## Is a point inside the manor? Reads the room layouts, not colliders: the top
## storeys have no ceiling collider, and the camera has to know them as rooms too.
class_name ManorIndoors
extends RefCounted

const GROUP := &"manor_house"

## {rect: Rect2, floor: float, top: float} per room, in house space.
static var _rooms: Array[Dictionary] = []


## World height of the ceiling over `at` when it stands in a manor room, else NAN.
static func ceiling_over(tree: SceneTree, at: Vector3) -> float:
	var house := tree.get_first_node_in_group(GROUP) as Node3D
	if house == null:
		return NAN
	var local := house.to_local(at)
	var top := ceiling_in(Vector2(local.x, local.z), local.y)
	return NAN if is_nan(top) else house.to_global(Vector3(local.x, top, local.z)).y


## House-space version of ceiling_over: the lowest ceiling of the rooms holding the point.
static func ceiling_in(p: Vector2, y: float) -> float:
	var best := NAN
	for r in _load():
		if y >= float(r["floor"]) and y < float(r["top"]) and (r["rect"] as Rect2).has_point(p):
			best = float(r["top"]) if is_nan(best) else minf(best, float(r["top"]))
	return best


static func _load() -> Array[Dictionary]:
	if _rooms.is_empty():
		for layout in ManorHouseBuilder.load_layouts():
			for r: ManorRoomDef in layout.rooms:
				if r.kind != &"exterior":
					var y := ManorHouseBuilder.floor_y(r.level)
					_rooms.append({"rect": r.rect, "floor": y, "top": y + ManorHouseBuilder.ceiling_of(r)})
	return _rooms
