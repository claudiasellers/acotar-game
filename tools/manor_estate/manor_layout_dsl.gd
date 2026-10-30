## Helpers that keep the house generators short and readable.
##
## A generator (tools/manor_estate/gen_<part>.gd, run with
## `godot --headless -s tools/manor_estate/gen_<part>.gd`) builds one
## ManorHouseLayout with these helpers and saves it with save().
class_name ManorLayoutDSL
extends RefCounted

const OUT_DIR := "res://data/regions/spring_court/manor_estate/house/"

var layout := ManorHouseLayout.new()


func _init(part_id: StringName) -> void:
	layout.part_id = part_id


func room(id: StringName, display_name: String, level: int, rect: Rect2, canon: String = "X",
		floor_kind: StringName = &"wood", wall_color: Color = Color(1.0, 0.88, 0.90),
		ceiling_height: float = 0.0, kind: StringName = &"room") -> ManorRoomDef:
	var r := ManorRoomDef.new()
	r.id = id
	r.display_name = display_name
	r.level = level
	r.rect = rect
	r.canon = canon
	r.floor_kind = floor_kind
	r.wall_color = wall_color
	r.ceiling_height = ceiling_height
	r.kind = kind
	layout.rooms.append(r)
	return r


## Adds a prop to a room. x/z are room-local from the rect's min corner, y above the floor.
func prop(r: ManorRoomDef, prop_id: StringName, x: float, z: float, yaw_deg: float = 0.0,
		y: float = 0.0, scale: float = 1.0) -> ManorPropPlacement:
	var p := ManorPropPlacement.new()
	p.prop_id = prop_id
	p.position = Vector3(x, y, z)
	p.yaw_deg = yaw_deg
	p.scale = scale
	r.props.append(p)
	return p


func door(level: int, at: Vector2, kind: StringName = &"door", width: float = 1.6,
		height: float = 2.8) -> ManorDoorDef:
	var d := ManorDoorDef.new()
	d.level = level
	d.at = at
	d.kind = kind
	d.width = width
	d.height = height
	layout.doors.append(d)
	return d


func secret_door(level: int, at: Vector2, secret_id: StringName, disguise: StringName = &"bookcase",
		width: float = 1.4) -> ManorDoorDef:
	var d := door(level, at, &"secret", width, 2.6)
	d.secret_id = secret_id
	d.disguise = disguise
	return d


func locked_door(level: int, at: Vector2, requires_flag: String, disguise: StringName = &"door") -> ManorDoorDef:
	var d := door(level, at, &"locked")
	d.requires_flag = requires_flag
	d.disguise = disguise
	return d


func stair(id: StringName, level_from: int, rect: Rect2, rise_toward: StringName,
		style: StringName = &"grand") -> ManorStairDef:
	var s := ManorStairDef.new()
	s.id = id
	s.level_from = level_from
	s.rect = rect
	s.rise_toward = rise_toward
	s.style = style
	layout.stairs.append(s)
	return s


func station(station_id: StringName, display_name: String, level: int, at: Vector3,
		prop_id: StringName, yaw_deg: float = 0.0, canon: String = "X") -> ManorStationDef:
	var s := ManorStationDef.new()
	s.station_id = station_id
	s.display_name = display_name
	s.level = level
	s.position = at
	s.prop_id = prop_id
	s.yaw_deg = yaw_deg
	s.canon = canon
	layout.stations.append(s)
	return s


func secret(secret_id: StringName, kind: StringName, level: int, at: Vector3,
		item_id: StringName = &"", prop_id: StringName = &"", notes: String = "") -> ManorSecretDef:
	var s := ManorSecretDef.new()
	s.secret_id = secret_id
	s.kind = kind
	s.level = level
	s.position = at
	s.item_id = item_id
	s.prop_id = prop_id
	s.notes = notes
	layout.secrets.append(s)
	return s


func roof(rect: Rect2, base_level: int, style: StringName = &"hip", height: float = 6.0,
		color: Color = Color(0.60, 0.52, 0.80)) -> ManorRoofDef:
	var r := ManorRoofDef.new()
	r.rect = rect
	r.base_level = base_level
	r.style = style
	r.height = height
	r.color = color
	layout.roofs.append(r)
	return r


func anchor(anchor_id: StringName, level: int, at: Vector3, yaw_deg: float = 0.0) -> ManorAnchorDef:
	var a := ManorAnchorDef.new()
	a.anchor_id = anchor_id
	a.level = level
	a.position = at
	a.yaw_deg = yaw_deg
	layout.anchors.append(a)
	return a


func save() -> Error:
	face_walls()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var path := OUT_DIR + "%s.tres" % layout.part_id
	var err := ResourceSaver.save(layout, path)
	print("[manor] wrote %s: %d rooms, %d doors, %d stairs, %d stations, %d secrets (err %d)" % [
		path, layout.rooms.size(), layout.doors.size(), layout.stairs.size(),
		layout.stations.size(), layout.secrets.size(), err])
	return err


## Props and stations standing against a wall with a square-on yaw are turned
## to face into the room, and chairs drawn up to a table turn to face it.
## Catalogue convention: a prop's front faces -Z at yaw 0
## (PropLib), so the north wall gets 180, south 0, west -90, east 90. Hand
## layouts mixed conventions while props were boxes; the Blender models have
## fronts, so this keeps every wardrobe, bookcase and fireplace the right way round.
const WALL_REACH := 0.6

func face_walls() -> void:
	for r in layout.rooms:
		for p in r.props:
			p.yaw_deg = _wall_yaw(r, p.prop_id, p.position.x, p.position.z, p.yaw_deg)
			if String(p.prop_id).begins_with("chair"):
				p.yaw_deg = _table_yaw(r, p)
	for s in layout.stations:
		for r in layout.rooms:
			if r.level == s.level and r.rect.has_point(Vector2(s.position.x, s.position.z)):
				s.yaw_deg = _wall_yaw(r, s.prop_id, s.position.x - r.rect.position.x, s.position.z - r.rect.position.y, s.yaw_deg)
				break


static func _wall_yaw(r: ManorRoomDef, prop_id: StringName, x: float, z: float, yaw: float) -> float:
	var q := fposmod(yaw, 90.0)
	if q > 1.0 and q < 89.0:
		return yaw
	var size := PropLib.size_of(prop_id)
	var dist := [z, r.rect.size.y - z, x, r.rect.size.x - x]        # n, s, w, e
	var facing := [180.0, 0.0, -90.0, 90.0]
	var k := 0
	for i in 4:
		if dist[i] < dist[k]:
			k = i
	# along-wall props are their depth from the wall; turned ones their width
	var turned := absf(fposmod(yaw, 180.0) - 90.0) < 1.0
	var reach := (size.x if (k < 2) == turned else size.z) * 0.5 + WALL_REACH
	return facing[k] if dist[k] <= reach else yaw


## Chairs within reach of a table or desk face its nearest edge point.
static func _table_yaw(r: ManorRoomDef, chair: ManorPropPlacement) -> float:
	var best := 2.5
	var yaw := chair.yaw_deg
	for t in r.props:
		var tid := String(t.prop_id)
		if not (tid.begins_with("table") or tid.begins_with("desk")):
			continue
		var half := PropLib.size_of(t.prop_id) * 0.5 * t.scale
		var local := Basis(Vector3.UP, deg_to_rad(-t.yaw_deg)) * (chair.position - t.position)
		var near := Vector3(clampf(local.x, -half.x, half.x), 0.0, clampf(local.z, -half.z, half.z))
		var to := Basis(Vector3.UP, deg_to_rad(t.yaw_deg)) * (near - local)
		to.y = 0.0
		if to.length() < best and to.length() > 0.01:
			best = to.length()
			yaw = rad_to_deg(atan2(-to.x, -to.z))
	return yaw
