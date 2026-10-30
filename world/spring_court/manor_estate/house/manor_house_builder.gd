## Builds the manor house from every ManorHouseLayout in LAYOUT_DIR.
##
## Rooms get a floor slab, walls inset half a wall thickness from their rect
## (so neighbours never share a face), a ceiling, auto windows in exterior walls
## and openings wherever a door sits on a wall line. Stairs get steps plus a
## smooth ramp collider and cut a hole in the floor above.
class_name ManorHouseBuilder
extends RefCounted

const LAYOUT_DIR := "res://data/regions/spring_court/manor_estate/house/"
const WALL := 0.25          # per-room wall thickness; neighbours make 0.5 m
const SLAB := 0.3
const SKIN := 0.12          # facade skin outside exterior walls
const WINDOW_SPACING := 4.2
const WINDOW_WIDTH := 1.5
const SILL := 0.9
const DOOR_TOLERANCE := 0.6

const FLOOR_COLORS := {
	&"wood": Color(0.80, 0.58, 0.44), &"marble": Color(0.98, 0.93, 0.93),
	&"stone": Color(0.94, 0.85, 0.80), &"tile": Color(0.98, 0.76, 0.74),
	&"carpet": Color(0.93, 0.52, 0.66), &"flagstone": Color(0.90, 0.82, 0.78),
}
const FACADE := Color(0.99, 0.94, 0.94)


static func floor_y(level: int) -> float:
	if level < 0:
		return ManorSitePlan.HOUSE_FLOOR_Y - ManorSitePlan.CELLAR_DEPTH * -level
	return ManorSitePlan.HOUSE_FLOOR_Y + ManorSitePlan.HOUSE_STOREY * level


static func storey_height(level: int) -> float:
	return floor_y(level + 1) - floor_y(level)


static func ceiling_of(room: ManorRoomDef) -> float:
	if room.ceiling_height > 0.0:
		return room.ceiling_height
	return storey_height(room.level) - SLAB - 0.02


static func load_layouts(dir: String = LAYOUT_DIR) -> Array[ManorHouseLayout]:
	var out: Array[ManorHouseLayout] = []
	var files := ResourceLoader.list_directory(dir) if ResourceLoader.has_method("list_directory") else DirAccess.get_files_at(dir)
	for f in files:
		var file := String(f).trim_suffix(".remap")
		if file.ends_with(".tres") or file.ends_with(".res"):
			var layout := load(dir + file) as ManorHouseLayout
			if layout:
				out.append(layout)
	return out


## Builds the whole house under a node named "House".
static func build(parent: Node3D, layouts: Array[ManorHouseLayout] = []) -> Node3D:
	if layouts.is_empty():
		layouts = load_layouts()
	var house := Node3D.new()
	house.name = "House"
	parent.add_child(house)
	var all := ManorHouseIndex.new(layouts)
	for room in all.rooms:
		_build_room(house, room, all)
	for door in all.doors:
		_build_door_leaf(house, door, all)
	for stair in all.stairs:
		_build_stair(house, stair)
	for station in all.stations:
		_build_station(house, station)
	for secret in all.secrets:
		_build_secret(house, secret)
	for roof in all.roofs:
		_build_roof(house, roof)
	return house


# --- Rooms -----------------------------------------------------------------

static func _build_room(house: Node3D, room: ManorRoomDef, all: ManorHouseIndex) -> void:
	var node := Node3D.new()
	node.name = String(room.id)
	house.add_child(node)
	var y := floor_y(room.level)
	if room.kind != &"exterior":
		var fc: Color = room.floor_color if room.floor_color.a > 0.0 else FLOOR_COLORS.get(room.floor_kind, FLOOR_COLORS[&"wood"])
		var floor_mat := EstateKit.pearl(fc) if room.floor_kind == &"marble" else EstateKit.mat(fc, 0.7)
		for r in _subtract(room.rect, all.stair_holes_on(room.level)):
			EstateKit.box(node, Vector3(r.get_center().x, y - SLAB * 0.5, r.get_center().y),
					Vector3(r.size.x, SLAB, r.size.y), floor_mat)
		var ceil_mat := EstateKit.mat(room.wall_color.lightened(0.25), 0.9)
		var ch := ceiling_of(room)
		for r in _subtract(room.rect, all.stair_holes_on(room.level + 1) if ch < storey_height(room.level) else []):
			EstateKit.box(node, Vector3(r.get_center().x, y + ch + 0.05, r.get_center().y),
					Vector3(r.size.x, 0.1, r.size.y), ceil_mat, false)
		_build_walls(node, room, all, y, ch)
	var origin := Vector3(room.rect.position.x, y, room.rect.position.y)
	for p in room.props:
		var prop := PropLib.build(p.prop_id)
		prop.position = origin + p.position
		prop.rotation.y = deg_to_rad(p.yaw_deg)
		if p.scale != 1.0:
			prop.scale = Vector3.ONE * p.scale
		node.add_child(prop)


static func _build_walls(node: Node3D, room: ManorRoomDef, all: ManorHouseIndex, y: float, h: float) -> void:
	var r := room.rect
	var mat := EstateKit.mat(room.wall_color, 0.9)
	var skin := EstateKit.mat(FACADE, 0.8, 0.0, "facade")
	var glass := EstateKit.mat(EstateKit.GLASS, 0.05, 0.0, "glass")
	var frame := EstateKit.mat(EstateKit.CREAM, 0.6, 0.0, "window_frame")
	# Each side: start, end (along the wall line), the inward normal.
	var sides := [
		[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(0, 1)],   # north
		[Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(0, -1)],             # south
		[Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Vector2(1, 0)],   # west
		[Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(-1, 0)],             # east
	]
	for side in sides:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var n: Vector2 = side[2]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		# Openings along the wall: [from, to, bottom, top, is_window].
		var openings: Array = []
		for door in all.doors_on_level(room.level):
			var d: Vector2 = door.at - a
			var along := d.dot(dir)
			var off := absf(d.dot(n))
			if off <= DOOR_TOLERANCE and along > -0.01 and along < length + 0.01:
				openings.append([along - door.width * 0.5, along + door.width * 0.5, 0.0, minf(door.height, h - 0.2), false])
		var exterior_any := false
		if room.windows and room.kind != &"corridor" or room.windows and room.level >= 0:
			var count := int(floor(length / WINDOW_SPACING))
			for i in count:
				var along := (i + 0.5) * length / count
				var outside := a + dir * along - n * 0.8
				if all.is_inside_any(room.level, outside) or room.level < 0:
					continue
				var clash := false
				for o in openings:
					if along + WINDOW_WIDTH > o[0] - 0.4 and along - WINDOW_WIDTH < o[1] + 0.4:
						clash = true
				if not clash:
					openings.append([along - WINDOW_WIDTH * 0.5, along + WINDOW_WIDTH * 0.5, SILL, minf(h - 0.5, SILL + 2.6), true])
		openings.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
		var cursor := 0.0
		var pieces: Array = []   # [from, to, bottom, top]
		for o in openings:
			var from := clampf(o[0], 0.0, length)
			var to := clampf(o[1], 0.0, length)
			if from > cursor:
				pieces.append([cursor, from, 0.0, h])
			if o[2] > 0.0:
				pieces.append([from, to, 0.0, o[2]])
			if o[3] < h:
				pieces.append([from, to, o[3], h])
			if o[4]:
				var mid: Vector2 = a + dir * ((from + to) * 0.5) + n * WALL * 0.5
				var size := Vector3(absf(dir.x) * (to - from) + absf(n.x) * 0.04, o[3] - o[2], absf(dir.y) * (to - from) + absf(n.y) * 0.04)
				EstateKit.box(node, Vector3(mid.x, y + (o[2] + o[3]) * 0.5, mid.y), size, glass)
				var sill := Vector3(absf(dir.x) * (to - from + 0.2) + absf(n.x) * 0.4, 0.08, absf(dir.y) * (to - from + 0.2) + absf(n.y) * 0.4)
				EstateKit.box(node, Vector3(mid.x, y + o[2], mid.y), sill, frame, false)
				exterior_any = true
			cursor = maxf(cursor, to)
		if cursor < length:
			pieces.append([cursor, length, 0.0, h])
		var mid_outside := a + dir * (length * 0.5) - n * 0.8
		var exterior := room.level >= 0 and (exterior_any or not all.is_inside_any(room.level, mid_outside))
		for p in pieces:
			var seg_len: float = p[1] - p[0]
			if seg_len < 0.02 or p[3] - p[2] < 0.02:
				continue
			var c: Vector2 = a + dir * ((p[0] + p[1]) * 0.5) + n * WALL * 0.5
			var size := Vector3(absf(dir.x) * seg_len + absf(n.x) * WALL, p[3] - p[2], absf(dir.y) * seg_len + absf(n.y) * WALL)
			EstateKit.box(node, Vector3(c.x, y + (p[2] + p[3]) * 0.5, c.y), size, mat)
			if exterior and not all.is_inside_any(room.level, a + dir * ((p[0] + p[1]) * 0.5) - n * 0.8):
				var sc: Vector2 = a + dir * ((p[0] + p[1]) * 0.5) - n * SKIN * 0.5
				var ssize := Vector3(absf(dir.x) * seg_len + absf(n.x) * SKIN, p[3] - p[2], absf(dir.y) * seg_len + absf(n.y) * SKIN)
				EstateKit.box(node, Vector3(sc.x, y + (p[2] + p[3]) * 0.5, sc.y), ssize, skin, false)
		# Band of facade between storeys so the outside reads as one building.
		if exterior and room.level >= 0 and not all.is_inside_any(room.level, mid_outside):
			var top := a + dir * (length * 0.5) - n * SKIN * 0.5
			var band := Vector3(absf(dir.x) * length + absf(n.x) * SKIN * 2.0, SLAB + 0.4, absf(dir.y) * length + absf(n.y) * SKIN * 2.0)
			EstateKit.box(node, Vector3(top.x, y + h + 0.2, top.y), band, skin, false)


## Rect minus a list of holes, as up to 4 rects per hole (grid split).
static func _subtract(rect: Rect2, holes: Array) -> Array[Rect2]:
	var parts: Array[Rect2] = [rect]
	for hole in holes:
		var h: Rect2 = hole
		var next: Array[Rect2] = []
		for p in parts:
			if not p.intersects(h):
				next.append(p)
				continue
			var i := p.intersection(h)
			if i.position.y > p.position.y:
				next.append(Rect2(p.position.x, p.position.y, p.size.x, i.position.y - p.position.y))
			if i.end.y < p.end.y:
				next.append(Rect2(p.position.x, i.end.y, p.size.x, p.end.y - i.end.y))
			if i.position.x > p.position.x:
				next.append(Rect2(p.position.x, i.position.y, i.position.x - p.position.x, i.size.y))
			if i.end.x < p.end.x:
				next.append(Rect2(i.end.x, i.position.y, p.end.x - i.end.x, i.size.y))
		parts = next
	return parts


# --- Doors -----------------------------------------------------------------

static func _build_door_leaf(house: Node3D, door: ManorDoorDef, all: ManorHouseIndex) -> void:
	var y := floor_y(door.level)
	var along_x := all.door_runs_along_x(door)
	var size := Vector3(door.width if along_x else 0.12, door.height, 0.12 if along_x else door.width)
	var center := Vector3(door.at.x, y + door.height * 0.5, door.at.y)
	# Frame for every doorway.
	var frame_mat := EstateKit.mat(EstateKit.OAK_DARK, 0.6, 0.0, "door_frame")
	var lintel := Vector3(size.x + (0.3 if along_x else 0.0), 0.18, size.z + (0.0 if along_x else 0.3))
	if door.kind != &"secret":
		lintel = Vector3(lintel.x if along_x else 0.62, 0.18, 0.62 if along_x else lintel.z)
		EstateKit.box(house, center + Vector3(0, door.height * 0.5 + 0.09, 0), lintel, frame_mat, false)
	match door.kind:
		&"locked", &"secret":
			var leaf := ManorDoorLeaf.new()
			leaf.name = "Door_%s" % (door.secret_id if door.secret_id != &"" else StringName("%d_%d" % [int(door.at.x), int(door.at.y)]))
			leaf.open_flag = door.requires_flag if door.kind == &"locked" else "fact.manor.secret_%s" % door.secret_id
			leaf.position = center
			house.add_child(leaf)
			var look := _leaf_material(door.disguise)
			EstateKit.box(leaf, Vector3.ZERO, Vector3(size.x, door.height, size.z) + (Vector3(0, 0, 0.36) if along_x else Vector3(0.36, 0, 0)), look)
			if door.disguise == &"bookcase":
				var shelf := EstateKit.mat(EstateKit.OAK, 0.7)
				for i in 5:
					EstateKit.box(leaf, Vector3(0, -door.height * 0.5 + 0.3 + i * 0.55, 0),
							Vector3(size.x * 0.96 if along_x else 0.42, 0.05, 0.42 if along_x else size.z * 0.96), shelf, false)
			leaf.refresh()
		&"gate":
			var gate := RegionGate.new()
			gate.name = "Gate_%s" % door.region_id
			gate.region_id = door.region_id
			gate.position = center
			house.add_child(gate)
			EstateKit.box(gate, Vector3.ZERO, size + Vector3(0, 0, 0.1), EstateKit.mat(EstateKit.OAK, 0.55, 0.0, "front_door"))
			EstateKit.box(gate, Vector3(0, 0.0, 0.0), Vector3(0.1, 0.1, 0.1) + (Vector3(0.0, 0.0, 0.2) if along_x else Vector3(0.2, 0, 0)), EstateKit.mat(EstateKit.GOLD, 0.3, 0.9, "brass"), false)


static func _leaf_material(disguise: StringName) -> Material:
	match disguise:
		&"bookcase": return EstateKit.mat(EstateKit.OAK_DARK, 0.7)
		&"panel": return EstateKit.mat(Color(0.62, 0.48, 0.34), 0.7)
		&"wall": return EstateKit.mat(Color(0.93, 0.89, 0.82), 0.9)
		&"fireplace": return EstateKit.mat(EstateKit.MARBLE, 0.4)
		&"mirror": return EstateKit.mat(Color(0.85, 0.88, 0.9), 0.05, 0.9)
	return EstateKit.mat(EstateKit.OAK, 0.6)


# --- Stairs ----------------------------------------------------------------

static func _build_stair(house: Node3D, stair: ManorStairDef) -> void:
	var y0 := floor_y(stair.level_from)
	var rise := floor_y(stair.level_from + 1) - y0
	var r := stair.rect
	var dir := _dir(stair.rise_toward)
	var along_z := dir.x == 0.0
	var run := r.size.y if along_z else r.size.x
	var width := r.size.x if along_z else r.size.y
	var start := r.get_center() - dir * run * 0.5
	var node := Node3D.new()
	node.name = "Stair_%s" % stair.id
	house.add_child(node)
	var mat := EstateKit.mat(EstateKit.MARBLE if stair.style == &"grand" else EstateKit.WARM_STONE, 0.5)
	var steps := int(ceil(rise / 0.19))
	var tread := run / steps
	for i in steps:
		var c := start + dir * (tread * (i + 0.5))
		var h := rise * (i + 1) / steps
		var size := Vector3(width if along_z else tread, h, tread if along_z else width)
		EstateKit.box(node, Vector3(c.x, y0 + h * 0.5, c.y), size, mat, false, 0.0, 120.0)
	# Smooth ramp collider so walking up never snags.
	var body := StaticBody3D.new()
	body.collision_layer = EstateKit.WORLD_LAYER
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var length := sqrt(run * run + rise * rise)
	shape.size = Vector3(width, 0.2, length) if along_z else Vector3(length, 0.2, width)
	cs.shape = shape
	body.add_child(cs)
	var mid := r.get_center()
	body.position = Vector3(mid.x, y0 + rise * 0.5 - 0.1, mid.y)
	var angle := atan2(rise, run)
	if along_z:
		body.rotation.x = angle * (1.0 if dir.y > 0.0 else -1.0)
	else:
		body.rotation.z = angle * (-1.0 if dir.x > 0.0 else 1.0)
	node.add_child(body)
	# Balustrades along both long sides.
	var rail := EstateKit.mat(EstateKit.CREAM if stair.style == &"grand" else EstateKit.OAK, 0.5)
	for s in [-1.0, 1.0]:
		var side: Vector2 = Vector2(dir.y, dir.x) * (width * 0.5 - 0.06) * s
		var c := r.get_center() + side
		var rs := Vector3(0.12, 0.12, length) if along_z else Vector3(length, 0.12, 0.12)
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = rs
		post.mesh = bm
		post.material_override = rail
		post.position = Vector3(c.x, y0 + rise * 0.5 + 1.0, c.y)
		post.rotation = body.rotation
		node.add_child(post)


static func _dir(rise_toward: StringName) -> Vector2:
	match rise_toward:
		&"south": return Vector2(0, 1)
		&"east": return Vector2(1, 0)
		&"west": return Vector2(-1, 0)
	return Vector2(0, -1)


## World XZ point just past the top step (where you arrive upstairs).
static func stair_top(stair: ManorStairDef) -> Vector2:
	var dir := _dir(stair.rise_toward)
	var run := stair.rect.size.y if dir.x == 0.0 else stair.rect.size.x
	return stair.rect.get_center() + dir * (run * 0.5 + 0.6)


static func stair_bottom(stair: ManorStairDef) -> Vector2:
	var dir := _dir(stair.rise_toward)
	var run := stair.rect.size.y if dir.x == 0.0 else stair.rect.size.x
	return stair.rect.get_center() - dir * (run * 0.5 + 0.6)


# --- Stations, secrets, roofs ----------------------------------------------

static func _build_station(house: Node3D, def: ManorStationDef) -> void:
	var station := ManorStation.new()
	station.name = "Station_%s" % def.station_id
	station.station_id = def.station_id
	station.display_name = def.display_name
	station.position = Vector3(def.position.x, floor_y(def.level) + def.position.y, def.position.z)
	station.rotation.y = deg_to_rad(def.yaw_deg)
	house.add_child(station)
	if def.prop_id != &"":
		station.add_child(PropLib.build(def.prop_id))


static func _build_secret(house: Node3D, def: ManorSecretDef) -> void:
	var at := Vector3(def.position.x, floor_y(def.level) + def.position.y, def.position.z)
	match def.kind:
		&"lever":
			var lever := ManorSecretLever.new()
			lever.name = "Lever_%s" % def.secret_id
			lever.secret_id = def.secret_id
			lever.position = at
			house.add_child(lever)
			lever.add_child(PropLib.build(def.prop_id if def.prop_id != &"" else &"secret_lever"))
		&"keepsake":
			var k := ManorKeepsake.new()
			k.name = "Keepsake_%s" % def.secret_id
			k.item_id = def.item_id
			k.secret_id = def.secret_id
			k.position = at
			house.add_child(k)
			k.add_child(PropLib.build(def.prop_id if def.prop_id != &"" else &"keepsake_glint"))
		&"discovery":
			var t := ActionTrigger.new()
			t.name = "Discovery_%s" % def.secret_id
			t.flag = "fact.manor.secret_%s" % def.secret_id
			t.collision_mask = 1 << 1
			var cs := CollisionShape3D.new()
			var s := SphereShape3D.new()
			s.radius = 2.0
			cs.shape = s
			t.add_child(cs)
			t.position = at
			house.add_child(t)


static func _build_roof(house: Node3D, roof: ManorRoofDef) -> void:
	var y := floor_y(roof.base_level + 1) - 0.02
	var r := roof.rect
	var mat := EstateKit.mat(roof.color, 0.35)
	var mi := MeshInstance3D.new()
	match roof.style:
		&"cone", &"dome":
			var cone := CylinderMesh.new()
			cone.bottom_radius = minf(r.size.x, r.size.y) * 0.55
			cone.top_radius = 0.05 if roof.style == &"cone" else cone.bottom_radius * 0.6
			cone.height = roof.height
			cone.radial_segments = 20
			mi.mesh = cone
			mi.position = Vector3(r.get_center().x, y + roof.height * 0.5, r.get_center().y)
			if roof.style == &"dome":
				var sphere := SphereMesh.new()
				sphere.radius = cone.bottom_radius
				sphere.height = cone.bottom_radius * 2.0
				sphere.is_hemisphere = true
				mi.mesh = sphere
				mi.position.y = y
		&"flat":
			var slab := BoxMesh.new()
			slab.size = Vector3(r.size.x + 0.6, 0.4, r.size.y + 0.6)
			mi.mesh = slab
			mi.position = Vector3(r.get_center().x, y + 0.2, r.get_center().y)
			var parapet := EstateKit.mat(FACADE, 0.8, 0.0, "facade")
			for s in [[Vector2(0, -0.5), true], [Vector2(0, 0.5), true], [Vector2(-0.5, 0), false], [Vector2(0.5, 0), false]]:
				var off: Vector2 = s[0] * r.size
				var sz := Vector3(r.size.x + 0.6, 1.1, 0.3) if s[1] else Vector3(0.3, 1.1, r.size.y + 0.6)
				EstateKit.box(house, Vector3(r.get_center().x + off.x, y + 0.95, r.get_center().y + off.y), sz, parapet)
		_:
			var prism := PrismMesh.new()
			var along_x := r.size.x >= r.size.y if roof.style == &"hip" else roof.style == &"gable_x"
			prism.size = Vector3(r.size.y + 0.8, roof.height, r.size.x + 0.8) if along_x else Vector3(r.size.x + 0.8, roof.height, r.size.y + 0.8)
			mi.mesh = prism
			mi.position = Vector3(r.get_center().x, y + roof.height * 0.5, r.get_center().y)
			if along_x:
				mi.rotation.y = PI * 0.5
	mi.material_override = mat
	house.add_child(mi)
