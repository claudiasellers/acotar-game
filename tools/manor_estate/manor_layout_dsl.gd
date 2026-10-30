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
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var path := OUT_DIR + "%s.tres" % layout.part_id
	var err := ResourceSaver.save(layout, path)
	print("[manor] wrote %s: %d rooms, %d doors, %d stairs, %d stations, %d secrets (err %d)" % [
		path, layout.rooms.size(), layout.doors.size(), layout.stairs.size(),
		layout.stations.size(), layout.secrets.size(), err])
	return err
