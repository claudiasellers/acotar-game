## The foyer's grand marble staircase dressed as one (L38, hall probe L48-1:
## the flight was a solid pink block, its sides and the face under the landing
## a blank wall the first thing seen on entering).
##
## Closed strings panelled in the hall's boiserie with raking panels, a gilt
## capping, turned marble balusters and a cream handrail on both sides, square
## newels with gilt finials at the foot, a rose runner held by gilt stair rods,
## and under the landing a panelled face with an arched niche (the statue and
## the sconces that go with it are props: ManorFurnishAct1._entrance_hall).
##
## Everything here is look only and built in the house's space: the flight's
## ramp collider, its rect and the hole above are ManorHouseBuilder's, as before.
class_name ManorGrandStair
extends RefCounted

const STRING_T := 0.16        # string (side wall) thickness
const STRING_UP := 0.16       # string top above the nosing line
const PROUD := 0.012          # strings and the end face stand this far outside the rect
const CAP := 0.05             # gilt capping on the strings
const BALUSTER_H := 0.78
const BALUSTER_PITCH := 0.3
const RAIL := Vector2(0.16, 0.09)
const NEWEL := Vector3(0.42, 1.15, 0.42)
const RUNNER := 0.5           # share of the flight's width the runner covers
const RUNNER_COLOR := Color(0.78, 0.33, 0.45)
## The niche under the landing: width, sill, straight jamb height, depth.
const NICHE_W := 1.0
const NICHE_SILL := 0.35
const NICHE_JAMB := 2.3
const NICHE_D := 0.6
const END_T := 0.14
const END_PANELS := 7

static var _mats: Dictionary = {}
static var _baluster: ArrayMesh


## A flight of `steps` steps over `run` m along `dir`, rising `rise` m from y0.
## `room` is the room the flight stands in (its walls set the panelling).
static func build(node: Node3D, stair: ManorStairDef, room: ManorRoomDef, y0: float, rise: float) -> void:
	var dir := ManorHouseBuilder._dir(stair.rise_toward)
	var along_z := dir.x == 0.0
	var run := stair.rect.size.y if along_z else stair.rect.size.x
	var width := stair.rect.size.x if along_z else stair.rect.size.y
	var foot := stair.rect.get_center() - dir * run * 0.5
	var f := _Frame.new(Vector3(foot.x, y0, foot.y), Vector3(dir.x, 0.0, dir.y))
	var steps := int(ceil(rise / 0.19))
	var tread := run / steps
	var step_h := rise / steps
	var marble := EstateKit.mat(EstateKit.MARBLE, 0.5)
	var gilt := ManorRoomFinish.gilt()
	# the steps are slabs, so the niche can sit under the landing
	var st := _begin()
	for i in steps:
		var h := step_h * (i + 1)
		_cuboid(st, f, i * tread, (i + 1) * tread, -width * 0.5, width * 0.5, maxf(0.0, h - step_h - 0.14), h)
	_add(node, "Steps", st, marble)
	# rose runner over treads and risers, a gilt rod at the foot of each riser
	var rw := width * RUNNER
	st = _begin()
	var rods := _begin()
	for i in steps:
		var h := step_h * (i + 1)
		_cuboid(st, f, i * tread - 0.015, (i + 1) * tread, -rw * 0.5, rw * 0.5, h - step_h, h + 0.012)
		if i > 0:
			_cuboid(rods, f, i * tread - 0.045, i * tread - 0.02, -rw * 0.5 - 0.06, rw * 0.5 + 0.06, h - step_h + 0.012, h - step_h + 0.037)
	_add(node, "Runner", st, EstateKit.mat(RUNNER_COLOR, 0.95))
	_add(node, "StairRods", rods, gilt)
	# strings: from the floor to a line STRING_UP above the nosings, flat at the top
	var t0 := step_h + STRING_UP
	var slope := rise / run
	var a_top := minf(run, (rise - t0) / slope)
	var line := func(a: float) -> float: return minf(rise, t0 + a * slope)
	var outer := width * 0.5 + PROUD
	var string_poly := PackedVector2Array([Vector2(0, 0), Vector2(run, 0), Vector2(run, rise - 0.01), Vector2(a_top, rise - 0.01), Vector2(0, t0)])
	var strings := _begin()
	var caps := _begin()
	var rail := _begin()
	for s: float in [-1.0, 1.0]:
		_prism(strings, f, string_poly, s * (outer - STRING_T), s * outer)
		_prism(caps, f, PackedVector2Array([Vector2(0, t0), Vector2(a_top, rise), Vector2(a_top, rise + CAP), Vector2(0, t0 + CAP)]),
				s * (outer - STRING_T - 0.02), s * (outer + 0.02))
		# a gilt bead run along the string's face under the capping
		_prism(caps, f, PackedVector2Array([Vector2(0, t0 - 0.12), Vector2(a_top, rise - 0.12), Vector2(a_top, rise - 0.1), Vector2(0, t0 - 0.1)]),
				s * outer, s * (outer + 0.012))
		# handrail on the balusters, from the newel to the landing
		var mid := s * (outer - STRING_T * 0.5)
		var r0 := 0.3
		var y_r := CAP + BALUSTER_H
		_prism(rail, f, PackedVector2Array([Vector2(r0, line.call(r0) + y_r), Vector2(a_top, rise + y_r), Vector2(a_top, rise + y_r + RAIL.y),
				Vector2(r0, line.call(r0) + y_r + RAIL.y)]), mid - RAIL.x * 0.5, mid + RAIL.x * 0.5)
		# newel at the foot
		_cuboid(rail, f, 0.0, NEWEL.z, mid - NEWEL.x * 0.5, mid + NEWEL.x * 0.5, 0.0, NEWEL.y)
		_cuboid(caps, f, -0.04, NEWEL.z + 0.04, mid - NEWEL.x * 0.5 - 0.04, mid + NEWEL.x * 0.5 + 0.04, NEWEL.y, NEWEL.y + 0.06)
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.22
		sm.radial_segments = 12
		sm.rings = 6
		ball.mesh = sm
		ball.material_override = _satin_gold()
		ball.position = f.at(NEWEL.z * 0.5, mid, NEWEL.y + 0.06 + 0.11)
		node.add_child(ball)
		# balusters
		var a := NEWEL.z + 0.2
		while a < a_top - 0.1:
			var b := MeshInstance3D.new()
			b.mesh = _baluster_mesh()
			b.material_override = marble
			b.position = f.at(a, mid, line.call(a) + CAP)
			node.add_child(b)
			a += BALUSTER_PITCH
	_add(node, "Strings", strings, _rake_material(room, stair, run, rise, t0, foot, dir))
	_add(node, "Capping", caps, gilt)
	_add(node, "Handrail", rail, EstateKit.mat(EstateKit.CREAM, 0.5))
	_end_face(node, f, stair, room, run, rise, outer)


## The face under the landing: hall panelling with an arched niche in the
## middle panel, a gilt architrave round it and a keystone.
static func _end_face(node: Node3D, f: _Frame, stair: ManorStairDef, room: ManorRoomDef, run: float, rise: float, outer: float) -> void:
	var a0 := run - END_T + PROUD      # back of the face
	var a1 := run + PROUD              # the face
	var ab := a0 - NICHE_D             # the niche's back wall
	var top := rise - 0.01
	var hw := NICHE_W * 0.5
	var spring := NICHE_SILL + NICHE_JAMB
	var arc: Array[Vector2] = []       # (s, y) round the arch, s from -hw to +hw
	for k in 13:
		var ang := PI - PI * k / 12.0
		arc.append(Vector2(cos(ang) * hw, spring + sin(ang) * hw))
	var face := _begin()
	for side: float in [-1.0, 1.0]:
		# one half of the face, round the half-opening (a simple polygon)
		var poly := PackedVector2Array([Vector2(side * outer, 0), Vector2(0, 0), Vector2(0, NICHE_SILL), Vector2(side * hw, NICHE_SILL)])
		for k in range(0, 7):
			var p: Vector2 = arc[k] if side < 0.0 else arc[12 - k]
			poly.append(p)
		poly.append(Vector2(0, top))
		poly.append(Vector2(side * outer, top))
		_flat(face, f, poly, a1, 1.0)
	_add(node, "EndFace", face, _end_material(room, stair, run, outer))
	# the niche: sill, jambs, the vault and the back
	var inside := _begin()
	_quad(inside, f.at(a1, -hw, NICHE_SILL), f.at(a1, hw, NICHE_SILL), f.at(ab, hw, NICHE_SILL), f.at(ab, -hw, NICHE_SILL), f.up)
	_quad(inside, f.at(a1, -hw, NICHE_SILL), f.at(ab, -hw, NICHE_SILL), f.at(ab, -hw, spring), f.at(a1, -hw, spring), f.right)
	_quad(inside, f.at(a1, hw, NICHE_SILL), f.at(a1, hw, spring), f.at(ab, hw, spring), f.at(ab, hw, NICHE_SILL), -f.right)
	for k in 12:
		var p: Vector2 = arc[k]
		var q: Vector2 = arc[k + 1]
		var mid := (p + q) * 0.5
		var n := -(f.right * mid.x + f.up * (mid.y - spring)).normalized()
		_quad(inside, f.at(a1, p.x, p.y), f.at(ab, p.x, p.y), f.at(ab, q.x, q.y), f.at(a1, q.x, q.y), n)
	var back := PackedVector2Array([Vector2(-hw, NICHE_SILL), Vector2(hw, NICHE_SILL)])
	for k in range(12, -1, -1):
		back.append(arc[k])
	_flat(inside, f, back, ab, 1.0)
	_add(node, "Niche", inside, EstateKit.mat(room.wall_color.lerp(EstateKit.PEARL, 0.45), 0.8))
	# gilt architrave round the opening, a keystone and the sill's nosing
	var trim := _begin()
	var band := 0.07
	var lip := 0.025
	_cuboid(trim, f, a1, a1 + lip, -hw - band, -hw, NICHE_SILL, spring)
	_cuboid(trim, f, a1, a1 + lip, hw, hw + band, NICHE_SILL, spring)
	for k in 12:
		var p: Vector2 = arc[k]
		var q: Vector2 = arc[k + 1]
		var po := Vector2(p.x, p.y - spring).normalized() * (hw + band) + Vector2(0, spring)
		var qo := Vector2(q.x, q.y - spring).normalized() * (hw + band) + Vector2(0, spring)
		_flat(trim, f, PackedVector2Array([p, po, qo, q]), a1 + lip, 1.0, true)
	_cuboid(trim, f, a1, a1 + 0.05, -0.09, 0.09, spring + hw - 0.02, spring + hw + 0.2)
	_cuboid(trim, f, a1 - 0.02, a1 + 0.06, -hw - band - 0.04, hw + band + 0.04, NICHE_SILL - 0.06, NICHE_SILL)
	_add(node, "NicheTrim", trim, ManorRoomFinish.gilt())


# --- materials -----------------------------------------------------------------

## The hall's boiserie with panels that step down under the strings' rake,
## laid out from the foot so a whole number of them fills the flight.
static func _rake_material(room: ManorRoomDef, stair: ManorStairDef, run: float, rise: float, t0: float, foot: Vector2, dir: Vector2) -> Material:
	var base := ManorRoomLook.wall_material(room)
	if not base is ShaderMaterial:
		return base
	var key := "rake_%s" % stair.id
	if _mats.has(key):
		return _mats[key]
	var m := (base as ShaderMaterial).duplicate() as ShaderMaterial
	m.resource_name = "boiserie_" + key
	var along_z := dir.x == 0.0
	var a0 := foot.y if along_z else foot.x
	var dsign := dir.y if along_z else dir.x
	var pw := run / roundf(run / 1.6)
	m.set_shader_parameter(&"panel_width", pw)
	m.set_shader_parameter(&"panel_phase", -a0)
	m.set_shader_parameter(&"rake", Vector4(1.0, a0, dsign * rise / run, t0))
	_mats[key] = m
	return m


## The hall's boiserie on the face under the landing, END_PANELS panels across
## it with the middle one centred on the flight (the niche sits in it).
static func _end_material(room: ManorRoomDef, stair: ManorStairDef, run: float, outer: float) -> Material:
	var base := ManorRoomLook.wall_material(room)
	if not base is ShaderMaterial:
		return base
	var key := "end_%s" % stair.id
	if _mats.has(key):
		return _mats[key]
	var m := (base as ShaderMaterial).duplicate() as ShaderMaterial
	m.resource_name = "boiserie_" + key
	var dir := ManorHouseBuilder._dir(stair.rise_toward)
	var c := stair.rect.get_center()
	var centre := c.x if dir.x == 0.0 else c.y
	var pw := outer * 2.0 / END_PANELS
	m.set_shader_parameter(&"panel_width", pw)
	m.set_shader_parameter(&"panel_phase", 0.5 * pw - centre)
	_mats[key] = m
	return m


static func _satin_gold() -> StandardMaterial3D:
	return EstateKit.mat(EstateKit.GOLD, 0.35, 0.0)


# --- geometry ------------------------------------------------------------------

## The flight's frame: `a` metres along the rise from the foot, `s` across it,
## `y` up from the foot's floor.
class _Frame:
	var origin: Vector3
	var fwd: Vector3
	var right: Vector3
	var up := Vector3.UP

	func _init(o: Vector3, forward: Vector3) -> void:
		origin = o
		fwd = forward
		right = Vector3.UP.cross(forward).normalized()

	func at(a: float, s: float, y: float) -> Vector3:
		return origin + fwd * a + right * s + up * y


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _add(node: Node3D, name: String, st: SurfaceTool, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = st.commit()
	mi.material_override = mat
	node.add_child(mi)


## One triangle facing `n` (Godot's front faces wind clockwise seen from the front).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(v)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)


## Axis box in the frame: a0..a1 along, s0..s1 across, y0..y1 up.
static func _cuboid(st: SurfaceTool, f: _Frame, a0: float, a1: float, s0: float, s1: float, y0: float, y1: float) -> void:
	var p := func(a: float, s: float, y: float) -> Vector3: return f.at(a, s, y)
	_quad(st, p.call(a0, s0, y1), p.call(a1, s0, y1), p.call(a1, s1, y1), p.call(a0, s1, y1), f.up)
	_quad(st, p.call(a0, s0, y0), p.call(a1, s0, y0), p.call(a1, s1, y0), p.call(a0, s1, y0), -f.up)
	_quad(st, p.call(a0, s0, y0), p.call(a0, s1, y0), p.call(a0, s1, y1), p.call(a0, s0, y1), -f.fwd)
	_quad(st, p.call(a1, s0, y0), p.call(a1, s1, y0), p.call(a1, s1, y1), p.call(a1, s0, y1), f.fwd)
	_quad(st, p.call(a0, s0, y0), p.call(a1, s0, y0), p.call(a1, s0, y1), p.call(a0, s0, y1), -f.right)
	_quad(st, p.call(a0, s1, y0), p.call(a1, s1, y0), p.call(a1, s1, y1), p.call(a0, s1, y1), f.right)


## A polygon in the (a, y) plane extruded across s0..s1.
static func _prism(st: SurfaceTool, f: _Frame, poly: PackedVector2Array, s0: float, s1: float) -> void:
	var lo := minf(s0, s1)
	var hi := maxf(s0, s1)
	var tris := Geometry2D.triangulate_polygon(poly)
	for i in range(0, tris.size(), 3):
		var q: Array[Vector2] = [poly[tris[i]], poly[tris[i + 1]], poly[tris[i + 2]]]
		_tri(st, f.at(q[0].x, lo, q[0].y), f.at(q[1].x, lo, q[1].y), f.at(q[2].x, lo, q[2].y), -f.right)
		_tri(st, f.at(q[0].x, hi, q[0].y), f.at(q[1].x, hi, q[1].y), f.at(q[2].x, hi, q[2].y), f.right)
	var ccw := _area(poly) > 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var e := (q - p).normalized()
		var out2 := Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x)
		var n := (f.fwd * out2.x + f.up * out2.y).normalized()
		_quad(st, f.at(p.x, lo, p.y), f.at(q.x, lo, q.y), f.at(q.x, hi, q.y), f.at(p.x, hi, p.y), n)


## A flat polygon in the (s, y) plane at `a`, facing +fwd (or -fwd when facing < 0).
## `slab` gives it the trim's 2.5 cm depth back to the face.
static func _flat(st: SurfaceTool, f: _Frame, poly: PackedVector2Array, a: float, facing: float, slab: bool = false) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		tris = PackedInt32Array()
		for i in range(1, poly.size() - 1):
			tris.append_array([0, i, i + 1])
	var n := f.fwd * facing
	for i in range(0, tris.size(), 3):
		var q: Array[Vector2] = [poly[tris[i]], poly[tris[i + 1]], poly[tris[i + 2]]]
		_tri(st, f.at(a, q[0].x, q[0].y), f.at(a, q[1].x, q[1].y), f.at(a, q[2].x, q[2].y), n)
	if slab:
		for i in poly.size():
			var p := poly[i]
			var q := poly[(i + 1) % poly.size()]
			var mid := (p + q) * 0.5
			var e := (q - p).normalized()
			var side := f.right * e.y - f.up * e.x
			var c := _centroid(poly)
			if side.dot(f.right * (mid.x - c.x) + f.up * (mid.y - c.y)) < 0.0:
				side = -side
			_quad(st, f.at(a, p.x, p.y), f.at(a, q.x, q.y), f.at(a - 0.025, q.x, q.y), f.at(a - 0.025, p.x, p.y), side.normalized())


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		s += p.x * q.y - q.x * p.y
	return s * 0.5


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / poly.size()


## A turned vase baluster, BALUSTER_H tall, base at the origin.
static func _baluster_mesh() -> ArrayMesh:
	if _baluster != null:
		return _baluster
	var prof := [[0.0, 0.0], [0.07, 0.0], [0.07, 0.06], [0.048, 0.08], [0.048, 0.12], [0.082, 0.3], [0.068, 0.4],
			[0.034, 0.5], [0.03, 0.58], [0.05, 0.64], [0.05, 0.71], [0.07, 0.73], [0.07, 0.78], [0.0, 0.78]]
	var seg := 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in prof.size() - 1:
		var r0: float = prof[i][0]
		var y0: float = prof[i][1] * BALUSTER_H / 0.78
		var r1: float = prof[i + 1][0]
		var y1: float = prof[i + 1][1] * BALUSTER_H / 0.78
		for k in seg:
			var t0 := TAU * k / seg
			var t1 := TAU * (k + 1) / seg
			var a := Vector3(cos(t0) * r0, y0, sin(t0) * r0)
			var b := Vector3(cos(t1) * r0, y0, sin(t1) * r0)
			var c := Vector3(cos(t1) * r1, y1, sin(t1) * r1)
			var d := Vector3(cos(t0) * r1, y1, sin(t0) * r1)
			var tm := (t0 + t1) * 0.5
			var slope := Vector2(r1 - r0, y1 - y0)
			var n := Vector3(cos(tm) * slope.y, -slope.x, sin(tm) * slope.y).normalized()
			if r0 > 0.0001:
				_tri(st, a, b, c, n)
			if r1 > 0.0001:
				_tri(st, a, c, d, n)
	_baluster = st.commit()
	return _baluster
