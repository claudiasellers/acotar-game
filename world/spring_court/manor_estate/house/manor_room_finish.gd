## Room finishes beyond walls and props (L38, quality audit A2-A4): patterned
## floors, plaster ceilings that don't turn lawn-green, cornices, ceiling roses
## over the chandeliers, timber beams in the working rooms, and curtains with a
## pelmet at every state-room window.
##
## Materials are shared by pattern and colour, so the whole house adds a few
## draw calls, not one per room. Canon (keeper, 2026-11-02): the foyer floor is
## black-and-white checkered marble; the gallery has pale wooden floors; Feyre's
## curtains are emerald silk with gold velvet; the dining room has velvet drapes.
class_name ManorRoomFinish
extends RefCounted

const FLOOR_SHADER := preload("res://world/spring_court/manor_estate/house/manor_floor.gdshader")
const PLASTER_SHADER := preload("res://world/spring_court/manor_estate/house/plaster_ceiling.gdshader")

enum Floor { PARQUET, CHECKER, TILE, BOARDS, FLAGS }

## Floor per room: [pattern, base, alt, joint, gloss]. Rooms not listed use
## FLOOR_BY_KIND (state rooms) or keep their plain floor.
const FLOORS := {
	&"entrance_hall": [Floor.CHECKER, Color(0.90, 0.86, 0.79), Color(0.075, 0.068, 0.062), Color(0.86, 0.68, 0.36), 0.6],
	&"gallery": [Floor.BOARDS, Color(0.86, 0.74, 0.62), Color(0.80, 0.66, 0.55), Color(0.62, 0.48, 0.42), 0.35],
	&"svc_kitchen": [Floor.TILE, Color(0.85, 0.58, 0.52), Color(0.82, 0.70, 0.60), Color(0.80, 0.76, 0.70), 0.25],
	&"svc_infirmary": [Floor.TILE, Color(0.78, 0.84, 0.82), Color(0.84, 0.82, 0.80), Color(0.72, 0.74, 0.74), 0.3],
}
const FLOOR_BY_KIND := {
	&"wood": [Floor.PARQUET, Color(0.80, 0.59, 0.46), Color(0.70, 0.48, 0.38), Color(0.52, 0.36, 0.30), 0.4],
	&"tile": [Floor.TILE, Color(0.84, 0.76, 0.74), Color(0.74, 0.84, 0.80), Color(0.78, 0.74, 0.72), 0.3],
	&"stone": [Floor.FLAGS, Color(0.82, 0.74, 0.70), Color(0.76, 0.68, 0.66), Color(0.62, 0.55, 0.54), 0.0],
	&"flagstone": [Floor.FLAGS, Color(0.80, 0.72, 0.66), Color(0.72, 0.64, 0.60), Color(0.58, 0.52, 0.50), 0.0],
}
## Service and cellar wood is plain boards, not parquet.
const SERVICE_WOOD := [Floor.BOARDS, Color(0.78, 0.60, 0.48), Color(0.72, 0.54, 0.44), Color(0.55, 0.40, 0.34), 0.15]

## Curtain fabric per room: [drape, pelmet/trim]. Others: their wall colour, deepened.
const CURTAINS := {
	&"feyre_bedroom": [Color(0.16, 0.56, 0.40), Color(0.92, 0.74, 0.36)],
	&"dining_hall": [Color(0.78, 0.36, 0.50), Color(0.90, 0.74, 0.40)],
	&"library": [Color(0.48, 0.52, 0.82), Color(0.90, 0.74, 0.40)],
	&"entrance_hall": [Color(0.74, 0.60, 0.86), Color(0.92, 0.80, 0.50)],
	&"gallery": [Color(0.96, 0.90, 0.86), Color(0.90, 0.78, 0.50)],
	&"tamlin_study": [Color(0.40, 0.58, 0.44), Color(0.86, 0.70, 0.40)],
	&"tamlin_bedchamber": [Color(0.46, 0.62, 0.48), Color(0.90, 0.74, 0.40)],
}
## Rooms that keep bare windows (canon: the painting room's clear, bright light,
## and L30's nook dresses its own window).
const BARE_WINDOWS := [&"painting_room"]

## Ceilings: rooms whose trim is timber beams rather than a cornice.
const BEAMED := [&"tamlin_study", &"svc_kitchen", &"svc_alis_room", &"svc_servants_hall"]

const CORNICE_DEPTH := 0.22
const CORNICE_DROP := 0.26
const BEAM_PITCH := 1.7

static var _floors: Dictionary = {}
static var _plasters: Dictionary = {}
static var _mats: Dictionary = {}


static func is_service(room: ManorRoomDef) -> bool:
	return String(room.id).begins_with("svc_") or room.level < 0 or room.level == 2


## The patterned floor for `room`, or null to keep the builder's plain one.
static func floor_material(room: ManorRoomDef) -> Material:
	var spec: Array = FLOORS.get(room.id, [])
	if spec.is_empty():
		if room.floor_kind == &"wood" and is_service(room):
			spec = SERVICE_WOOD
		else:
			spec = FLOOR_BY_KIND.get(room.floor_kind, [])
	if spec.is_empty():
		return null
	var key := "%d|%s|%s" % [spec[0], (spec[1] as Color).to_html(), (spec[2] as Color).to_html()]
	if _floors.has(key):
		return _floors[key]
	var m := ShaderMaterial.new()
	m.shader = FLOOR_SHADER
	m.resource_name = "floor_%d" % spec[0]
	m.set_shader_parameter(&"pattern", spec[0])
	m.set_shader_parameter(&"base", spec[1])
	m.set_shader_parameter(&"alt", spec[2])
	m.set_shader_parameter(&"joint", spec[3])
	m.set_shader_parameter(&"gloss", spec[4])
	_floors[key] = m
	return m


## Plaster that ignores the green ambient (plaster_ceiling.gdshader).
static func plaster(color: Color) -> ShaderMaterial:
	var c := Color(minf(color.r, 0.85), minf(color.g, 0.85), minf(color.b, 0.85))
	var key := c.to_html(false)
	if _plasters.has(key):
		return _plasters[key]
	var m := ShaderMaterial.new()
	m.shader = PLASTER_SHADER
	m.resource_name = "plaster_" + key
	m.set_shader_parameter(&"color", c)
	_plasters[key] = m
	return m


## The ceiling field colour for a plain room: pearl warmed by the walls.
static func ceiling_color(room: ManorRoomDef) -> Color:
	return room.wall_color.lerp(Color(0.98, 0.95, 0.92), 0.6)


## Gilt and timber that ignore ambient like the plaster, with the same bounce.
static func _mat(kind: StringName, color: Color, roughness: float, metallic: float, bounce: float) -> CandyMaterial:
	var key := "%s|%s" % [kind, color.to_html()]
	if _mats.has(key):
		return _mats[key]
	var m := MaterialLibrary.surface()
	m.resource_name = "finish_" + String(kind)
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.disable_ambient_light = true
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = bounce
	_mats[key] = m
	return m


static func gilt() -> CandyMaterial:
	return _mat(&"gilt", Color(0.90, 0.75, 0.42), 0.35, 0.6, 0.22)


static func timber() -> CandyMaterial:
	return _mat(&"timber", Color(0.62, 0.44, 0.36), 0.75, 0.0, 0.3)


# --- ceiling trim ---------------------------------------------------------------

## Cornice round the room's ceiling (state rooms) or timber beams across its
## short span (BEAMED rooms and the service floors), plus a gilt-ringed rose
## over every chandelier. Coffered and sky rooms keep their own ceilings and
## only get the roses. One mesh, no collision. Returns it, or null.
static func add_trim(node: Node3D, room: ManorRoomDef, origin: Vector3, ceiling: float, holes: Array = []) -> MeshInstance3D:
	if room.kind == &"exterior":
		return null
	var plasterst := SurfaceTool.new()
	var giltst := SurfaceTool.new()
	var woodst := SurfaceTool.new()
	for st in [plasterst, giltst, woodst]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var counts := [0, 0, 0]
	var rect := room.rect.grow(-ManorHouseBuilder.WALL)
	var y := origin.y + ceiling
	var open: Array = holes.filter(func(h: Rect2) -> bool: return h.intersects(room.rect))
	var special := ManorRoomLook.is_coffered(room) or ManorRoomLook.has_sky(room)
	var beamed := BEAMED.has(room.id) or (is_service(room) and room.level >= 0 and not special)
	if beamed and not special:
		var along_x := rect.size.x < rect.size.y     # beams span the short way
		var span := rect.size.y if along_x else rect.size.x
		var n := maxi(1, int(span / BEAM_PITCH))
		for i in n:
			var t := (i + 0.5) * span / n
			var r := Rect2(rect.position.x, rect.position.y + t - 0.11, rect.size.x, 0.22) if along_x \
					else Rect2(rect.position.x + t - 0.11, rect.position.y, 0.22, rect.size.y)
			for piece in ManorHouseBuilder._subtract(r, open):
				_box(woodst, piece, y - 0.14, 0.28)
				counts[2] += 1
	elif not special and room.level >= 0:
		# a stepped cove cornice with a gilt bead (state rooms and passages)
		for band in [[CORNICE_DEPTH, CORNICE_DROP * 0.55], [CORNICE_DEPTH * 0.55, CORNICE_DROP]]:
			for r in _ring(rect, band[0]):
				for piece in ManorHouseBuilder._subtract(r, open):
					_box(plasterst, piece, y - band[1] * 0.5, band[1])
					counts[0] += 1
		if ManorRoomLook.is_state_room(room):
			for r in _ring(rect.grow(-CORNICE_DEPTH), 0.035):
				for piece in ManorHouseBuilder._subtract(r, open):
					_box(giltst, piece, y - CORNICE_DROP * 0.5, 0.035)
					counts[1] += 1
	# a rose over each chandelier
	if room.level >= 0:
		for p in room.props:
			if not String(p.prop_id).begins_with("chandelier"):
				continue
			var c := Vector3(origin.x + p.position.x, y - 0.02, origin.z + p.position.z)
			var big := p.prop_id == &"chandelier_crystal"
			var rr := 0.75 if big else 0.45
			_disc(plasterst, c, rr, 0.05, 20)
			_disc(giltst, c - Vector3(0, 0.03, 0), rr * 0.55, 0.03, 16)
			_ring_disc(giltst, c - Vector3(0, 0.02, 0), rr, rr - 0.05, 0.03, 24)
			counts[0] += 1
			counts[1] += 2
	if counts[0] + counts[1] + counts[2] == 0:
		return null
	var mesh := ArrayMesh.new()
	var mats := [plaster(ceiling_color(room).lightened(0.05)), gilt(), timber()]
	var sts := [plasterst, giltst, woodst]
	for i in 3:
		if counts[i] > 0:
			sts[i].generate_normals()
			mesh = ManorMeshMerger.commit(sts[i], mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mats[i])
	var mi := MeshInstance3D.new()
	mi.name = "CeilingTrim"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	return mi


## The four strips `w` wide along the inside of `r`.
static func _ring(r: Rect2, w: float) -> Array[Rect2]:
	return [Rect2(r.position.x, r.position.y, r.size.x, w), Rect2(r.position.x, r.end.y - w, r.size.x, w),
		Rect2(r.position.x, r.position.y + w, w, r.size.y - 2.0 * w), Rect2(r.end.x - w, r.position.y + w, w, r.size.y - 2.0 * w)]


static func _box(st: SurfaceTool, r: Rect2, cy: float, h: float) -> void:
	if r.size.x < 0.02 or r.size.y < 0.02:
		return
	var b := BoxMesh.new()
	b.size = Vector3(r.size.x, h, r.size.y)
	ManorMeshMerger.append(st, b, Transform3D(Basis(), Vector3(r.get_center().x, cy, r.get_center().y)))


static func _disc(st: SurfaceTool, c: Vector3, r: float, h: float, seg: int) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r * 0.92
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	ManorMeshMerger.append(st, m, Transform3D(Basis(), c - Vector3(0, h * 0.5, 0)))


static func _ring_disc(st: SurfaceTool, c: Vector3, r_out: float, r_in: float, h: float, seg: int) -> void:
	var m := TorusMesh.new()
	m.outer_radius = r_out
	m.inner_radius = r_in
	m.rings = seg
	m.ring_segments = 6
	ManorMeshMerger.append(st, m, Transform3D(Basis().scaled(Vector3(1, h / maxf(r_out - r_in, 0.01), 1)), c))


# --- windows and curtains -----------------------------------------------------------

## Pleated floor-length drapes either side of each window of a state room,
## tied back with gilt, under a pelmet with a gilt edge. One mesh per room.
## Drapes hang centred DRAPE_OUT beyond each side of the window, DRAPE_W wide:
## the inner edge just over the façade's reveal casing (L42), off the wall.
const DRAPE_OUT := 0.42
const DRAPE_W := 0.62


static func has_curtains(room: ManorRoomDef) -> bool:
	if room.level < 0 or room.kind == &"exterior" or BARE_WINDOWS.has(room.id):
		return false
	return ManorRoomLook.is_state_room(room) or CURTAINS.has(room.id)


## How far beyond a window's edge its drapes reach along the wall.
static func drape_reach(room: ManorRoomDef) -> float:
	return DRAPE_OUT + DRAPE_W * 0.5 if has_curtains(room) else 0.0


static func add_curtains(node: Node3D, room: ManorRoomDef, all: ManorHouseIndex, y: float, h: float) -> MeshInstance3D:
	if not has_curtains(room):
		return null
	var cols: Array = CURTAINS.get(room.id, [room.wall_color.darkened(0.18).lerp(Color(0.86, 0.52, 0.66), 0.25),
			Color(0.90, 0.76, 0.44)])
	var drape := SurfaceTool.new()
	var trim := SurfaceTool.new()
	drape.begin(Mesh.PRIMITIVE_TRIANGLES)
	trim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	var sides := ManorWindows.sides_of(room.rect)
	for side in sides:
		var s: Array = sides[side]
		var a: Vector2 = s[0]
		var dir: Vector2 = (s[1] - s[0]).normalized()
		var n: Vector2 = s[2]
		for o in ManorWindows.openings(all, room, side):
			if o[2] != &"window":
				continue
			any = true
			# the pelmet clears the façade's room-side reveal (L42): above sill + 2.8
			var top := minf(h - 0.5, ManorWindows.SILL + 2.6) + 0.4
			var face := a + n * (ManorHouseBuilder.WALL + 0.07)
			for edge in [[o[0] - DRAPE_OUT, -1.0], [o[1] + DRAPE_OUT, 1.0]]:
				var c: Vector2 = face + dir * float(edge[0])
				_drape(drape, c, dir, n, y + 0.02, y + top, DRAPE_W)
				var tie := c + n * 0.06
				var tb := BoxMesh.new()
				tb.size = Vector3(absf(dir.x) * 0.5 + absf(n.x) * 0.12, 0.07, absf(dir.y) * 0.5 + absf(n.y) * 0.12)
				ManorMeshMerger.append(trim, tb, Transform3D(Basis(), Vector3(tie.x, y + 1.05, tie.y)))
			var mid: Vector2 = face + dir * ((o[0] + o[1]) * 0.5) + n * 0.08
			var len: float = o[1] - o[0] + 2.0 * (DRAPE_OUT + DRAPE_W * 0.5) + 0.1
			var pel := BoxMesh.new()
			pel.size = Vector3(absf(dir.x) * len + absf(n.x) * 0.2, 0.42, absf(dir.y) * len + absf(n.y) * 0.2)
			ManorMeshMerger.append(drape, pel, Transform3D(Basis(), Vector3(mid.x, y + top + 0.05, mid.y)), false)
			var bead := BoxMesh.new()
			bead.size = Vector3(absf(dir.x) * (len + 0.04) + absf(n.x) * 0.23, 0.05, absf(dir.y) * (len + 0.04) + absf(n.y) * 0.23)
			ManorMeshMerger.append(trim, bead, Transform3D(Basis(), Vector3(mid.x, y + top - 0.16, mid.y)))
	if not any:
		return null
	drape.generate_normals()
	var mesh := ManorMeshMerger.commit(drape)
	var fabric := MaterialLibrary.surface()
	fabric.resource_name = "curtain"
	fabric.albedo_color = cols[0]
	fabric.roughness = 0.75
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED     # pleats read from both sides
	mesh.surface_set_material(0, fabric)
	trim.generate_normals()
	mesh = ManorMeshMerger.commit(trim, mesh)
	var tm := MaterialLibrary.surface()
	tm.resource_name = "curtain_trim"
	tm.albedo_color = cols[1]
	tm.roughness = 0.4
	tm.metallic = 0.5
	mesh.surface_set_material(1, tm)
	var mi := MeshInstance3D.new()
	mi.name = "Curtains"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	return mi


## One drape: a pleated panel `w` wide centred at c, gathered at the tie-back.
static func _drape(st: SurfaceTool, c: Vector2, dir: Vector2, n: Vector2, y0: float, y1: float, w: float) -> void:
	const PLEATS := 7
	const ROWS := [0.0, 0.18, 0.3, 0.36, 0.42, 0.6, 1.0]   # tie-back near 0.36 of the height
	var cols := PLEATS * 2 + 1
	var grid: Array = []
	for ri in ROWS.size():
		var v: float = ROWS[ri]
		var yy := lerpf(y0, y1, v)
		var gather := 1.0 - 0.55 * exp(-pow((v - 0.36) / 0.12, 2.0))
		var row: Array = []
		for k in cols:
			var u := float(k) / (cols - 1) - 0.5
			var depth := (0.06 if k % 2 == 0 else -0.02) * (1.2 - gather * 0.4)
			var p := c + dir * (u * w * gather) + n * (0.06 + depth)
			row.append(Vector3(p.x, yy, p.y))
		grid.append(row)
	for ri in ROWS.size() - 1:
		for k in cols - 1:
			var a: Vector3 = grid[ri][k]
			var b: Vector3 = grid[ri][k + 1]
			var cc: Vector3 = grid[ri + 1][k + 1]
			var d: Vector3 = grid[ri + 1][k]
			for tri in [[a, b, cc], [a, cc, d]]:
				for v in tri:
					st.add_vertex(v)
