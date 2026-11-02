## Teaching the way through the world, not markers (R2), for Act I's opening:
##   - a trodden line through the snow from the cottage yard up the deer trail
##     (wider, a path the deer use every morning) and on as the doe's fresh
##     furrow to the clearing (narrower), with prints big enough to read from
##     Feyre's camera: the small authored prints alone vanished in the snow;
##   - crows circling high over the clearing, readable from ~150 m, until the
##     wolf is skinned;
##   - chimney smoke over the village and a line of lit lanterns along the
##     cottage road, so the village reads from the cottage door.
## Built once at fixed world positions (HumanRealmLayout) on the terrain height.
class_name Act1Wayfinding
extends Node3D

## The end of the cottage's deer trail (cottage_gen.gd deer_trail_points()).
const TRAIL_END := Vector2(-205.0, 2088.0)
const TRACK_STEP := 1.3
## A walking doe's stride (0.5 to 0.7 m), and a print a touch larger than
## life (~0.08 m) so it reads from Feyre's camera at 3 to 8 m (cloud shot
## L27-6: 0.16 m read as specks past 5 m).
const PRINT_STEP := 0.6
const PRINT_LENGTH := 0.22
## The doe's wander either side of the line (m), and the room she leaves
## round trunks and rocks (planner, L27-7).
const WANDER := 0.8
const OBSTACLE_CLEARANCE := 1.0
const MAX_DETOUR := 3.5
## Footprint radius at scale 1 by scatter layer id, first match wins (trees:
## trunk, from the ForestTrunkCollision radii, rounded up; a spruce by its
## skirt of low branches, which sweep the snow: cloud shot L27-7).
const OBSTACLE_RADII := {
	"boulder": 1.1, "rock": 1.0, "stump": 0.45, "log": 1.2, "deadfall": 1.2,
	"spruce": 1.7, "tree": 0.4, "pine": 0.4, "snag": 0.35,
}
const COTTAGE_GEN := preload("res://world/human_realm/cottage/cottage_gen.gd")
## Trodden snow reads by value, not by markers: a cool shadow-blue band
## darker than the drifts, with a deeper rut down the middle where the hooves
## go, so it reads as a groove that leads the eye into the trees.
const TRODDEN := Color(0.50, 0.57, 0.72)
const RUT := Color(0.31, 0.37, 0.53)
const DEER_TRAIL_WIDTH := 1.1
const DOE_FURROW_WIDTH := 0.6
## The doe's line is one fresh pass, not a path: fainter than the deer trail.
const DOE_STRENGTH := 0.85
## The band fades in over this many metres from the yard (no hard start).
const BAND_FADE_IN := 4.0
const BAND_STEP := 0.75
const BAND_LIFT := 0.05
const CROWS := 6
const CROW_HEIGHT := 38.0
const LANTERN_STEP := 32.0
const SMOKE_SPOTS := [
	Vector2(380.0, 2250.0), Vector2(415.0, 2215.0), Vector2(330.0, 2300.0), Vector2(460.0, 2320.0),
]

var tracks: Node3D
var bands: Array[MeshInstance3D] = []
var crows: Array[Node3D] = []
var _crow_phase: Array[float] = []
var _t: float = 0.0


func _ready() -> void:
	name = "Act1Wayfinding"
	# Past the winter the hunt's trail is over; planning it reads every
	# human-realm scatter layer (0.7 s on each Continue).
	if not Act1LandmarkThoughts.past_winter():
		_build_hunt_trail()
	_build_smoke()
	_build_lanterns()
	EventBus.flag_changed.connect(_on_flag)
	_on_flag("", null)


func _build_hunt_trail() -> void:
	# One path for the furrow and the prints: the doe's wandering line round
	# the trees, so they never read as two trails (L27-8).
	var path := doe_path()
	_build_band(path[0], DEER_TRAIL_WIDTH, "DeerTrailBand", 1.0, BAND_FADE_IN)
	_build_band(path[1], DOE_FURROW_WIDTH, "DoeFurrow", DOE_STRENGTH, 0.0)
	_build_tracks(path)
	_build_crows()


## The track line: a lazy S from the trail's end to the doe's grazing spot.
static func track_points(step: float = TRACK_STEP) -> PackedVector2Array:
	var a := TRAIL_END
	var b := HumanRealmLayout.DOE_CLEARING
	var mid := a.lerp(b, 0.5)
	var side := (b - a).orthogonal().normalized()
	var c1 := a.lerp(mid, 0.6) + side * 28.0
	var c2 := mid.lerp(b, 0.4) - side * 22.0
	var dense := PackedVector2Array()
	for i in 400:
		var t := float(i) / 399.0
		dense.append(a.bezier_interpolate(c1, c2, b, t))
	var pts := PackedVector2Array([dense[0]])
	var left := 0.0
	for i in range(1, dense.size()):
		left += dense[i].distance_to(dense[i - 1])
		if left >= step:
			pts.append(dense[i])
			left = 0.0
	return pts


## The walked path as [cottage deer trail, doe's line to the clearing]: both
## resampled at her stride and wandered round trunks and rocks as one line,
## so the two join without a step. Bands and prints are both built from it.
static func doe_path() -> Array[PackedVector2Array]:
	var trail := _resample(COTTAGE_GEN.deer_trail_points(), PRINT_STEP)
	var doe := _resample(track_points(), PRINT_STEP)
	var all := PackedVector2Array(trail)
	all.append_array(doe)
	var walked := wander_line(all, trail_obstacles(all))
	return [walked.slice(0, trail.size()), walked.slice(trail.size())]


func _build_tracks(path: Array[PackedVector2Array]) -> void:
	var pts := PackedVector2Array(path[0])
	pts.append_array(path[1])
	var obstacles := trail_obstacles(pts)
	# Cloven prints as decals (HoofPrint): projected onto the ground actually
	# drawn, so terrain LOD and snow cover never swallow them, and dark and
	# deep enough to read from Feyre's walking camera. Pairs alternate sides,
	# toes toward the doe.
	tracks = Node3D.new()
	tracks.name = "DoeTracks"
	add_child(tracks)
	for i in pts.size():
		var p := pts[i]
		var ahead := pts[mini(i + 1, pts.size() - 1)] - p if i + 1 < pts.size() else p - pts[i - 1]
		var yaw := atan2(-ahead.x, -ahead.y)
		# A walking doe: one print per step, left and right of her line.
		var q := p + Vector2(ahead.y, -ahead.x).normalized() * (0.1 if i % 2 == 0 else -0.1)
		if not is_clear(q, obstacles, 0.0):
			continue  # a detour capped at MAX_DETOUR: skip, never print in a trunk
		var d := HoofPrint.make(PRINT_LENGTH, 30.0)
		d.position = Vector3(q.x, WorldHeight.height_at(q.x, q.y), q.y)
		d.rotation.y = yaw
		tracks.add_child(d)


## The doe's actual path along `line`: a slow wander either side of it (a
## deer doesn't walk a ruler line) that bends round every trunk and rock in
## `obstacles` (Vector3(x, z, radius)) with OBSTACLE_CLEARANCE to spare.
static func wander_line(line: PackedVector2Array, obstacles: Array[Vector3]) -> PackedVector2Array:
	var n := line.size()
	if n < 3:
		return line
	var normals := PackedVector2Array()
	var off := PackedFloat32Array()
	var s := 0.0
	for i in n:
		var ahead := line[mini(i + 1, n - 1)] - line[maxi(i - 1, 0)]
		normals.append(Vector2(ahead.y, -ahead.x).normalized())
		if i > 0:
			s += line[i].distance_to(line[i - 1])
		# Low frequency only: two slow waves, never per-print jitter.
		off.append(WANDER * (0.7 * sin(s / 14.0 * TAU) + 0.3 * sin(s / 37.0 * TAU + 1.3)))
	var near := _obstacles_by_point(line, obstacles)
	for pass_i in 8:
		var moved := false
		for i in n:
			for o: Vector3 in near[i]:
				var p := line[i] + normals[i] * off[i]
				var need := o.z + OBSTACLE_CLEARANCE
				var d := p.distance_to(Vector2(o.x, o.y))
				if d < need:
					var away := (p - Vector2(o.x, o.y)).dot(normals[i])
					off[i] += (1.0 if away >= 0.0 else -1.0) * (need - d + 0.05)
					moved = true
		if not moved:
			break
		# Spread each detour along the line so the path bends, not kinks.
		if pass_i < 6:
			var smooth := PackedFloat32Array(off)
			for i in n:
				var sum := 0.0
				var w := 0.0
				for k in range(maxi(i - 6, 0), mini(i + 7, n)):
					var wk := 1.0 - absf(k - i) / 7.0
					sum += off[k] * wk
					w += wk
				smooth[i] = sum / w if absf(off[i]) <= absf(sum / w) + 1.5 else off[i]
			off = smooth
	var out := PackedVector2Array()
	for i in n:
		out.append(line[i] + normals[i] * clampf(off[i], -MAX_DETOUR, MAX_DETOUR))
	return out


## Trunks and rocks near `line` from the human realm's scatter (the same
## layers ForestTrunkCollision and the rock colliders are built from), as
## Vector3(x, z, radius). Trees by trunk, rocks, stumps and logs by footprint.
static func trail_obstacles(line: PackedVector2Array) -> Array[Vector3]:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for p in line:
		lo = lo.min(p)
		hi = hi.max(p)
	lo -= Vector2.ONE * 6.0
	hi += Vector2.ONE * 6.0
	var out: Array[Vector3] = []
	var realm := DirAccess.open("res://world/human_realm")
	if realm == null:
		return out
	for region in realm.get_directories():
		var dir := "res://world/human_realm/%s/scatter" % region
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			var file := f.trim_suffix(".remap")
			if not file.ends_with(".tres"):
				continue
			var r := _obstacle_radius(file.get_basename())
			var layer := load(dir.path_join(file)) as ScatterLayer
			if layer == null or layer.is_forage():
				continue
			if r <= 0.0 and layer.tags.has("tree"):
				r = 0.4
			if r <= 0.0:
				continue
			for i in layer.count():
				var at := layer.position_of(i)
				if at.x >= lo.x and at.x <= hi.x and at.z >= lo.y and at.z <= hi.y:
					out.append(Vector3(at.x, at.z, r * layer.instances[i * ScatterLayer.STRIDE + 4]))
	return out


static func is_clear(p: Vector2, obstacles: Array, margin: float) -> bool:
	for o: Vector3 in obstacles:
		if p.distance_to(Vector2(o.x, o.y)) < o.z + margin:
			return false
	return true


static func _obstacle_radius(id: String) -> float:
	for key: String in OBSTACLE_RADII:
		if id.contains(key):
			return OBSTACLE_RADII[key]
	return 0.0


## For each line point, the obstacles within reach of any detour from it.
static func _obstacles_by_point(line: PackedVector2Array, obstacles: Array[Vector3]) -> Array:
	var out: Array = []
	for p in line:
		var near: Array[Vector3] = []
		for o in obstacles:
			if p.distance_to(Vector2(o.x, o.y)) < o.z + OBSTACLE_CLEARANCE + MAX_DETOUR:
				near.append(o)
		out.append(near)
	return out


## A soft-edged ribbon of trodden snow along `line` (world XZ), following the
## ground across its width: clear at the edges, trodden blue, a darker rut in
## the middle. `strength` scales its opacity; it fades in over `fade_in` m.
func _build_band(line: PackedVector2Array, width: float, band_name: String, strength: float, fade_in: float) -> void:
	var pts := _resample(line, BAND_STEP)
	if pts.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Across the band: edge, trodden, rut, rut, trodden, edge.
	var across := [-0.5, -0.3, -0.1, 0.1, 0.3, 0.5]
	var alpha := [0.0, 0.85, 1.0, 1.0, 0.85, 0.0]
	var tone := [TRODDEN, TRODDEN, RUT, RUT, TRODDEN, TRODDEN]
	var rows: Array = []
	for i in pts.size():
		var ahead := pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]
		var side := Vector2(ahead.y, -ahead.x).normalized()
		# A little wander in width, the way snow fills a path unevenly.
		var w := width * (1.0 + 0.18 * sin(i * 0.37) * sin(i * 0.11 + 1.0))
		var row: Array[Vector3] = []
		for a: float in across:
			var q := pts[i] + side * a * w
			row.append(Vector3(q.x, WorldHeight.height_at(q.x, q.y) + BAND_LIFT, q.y))
		rows.append(row)
	for i in rows.size() - 1:
		for k in across.size() - 1:
			var quad := [[i, k], [i, k + 1], [i + 1, k + 1], [i, k], [i + 1, k + 1], [i + 1, k]]
			for v: Array in quad:
				var c: Color = tone[v[1]]
				var fade := clampf(v[0] * BAND_STEP / fade_in, 0.0, 1.0) if fade_in > 0.0 else 1.0
				c.a = alpha[v[1]] * strength * fade
				st.set_color(c)
				st.set_normal(Vector3.UP)
				st.add_vertex(rows[v[0]][v[1]])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var band := MeshInstance3D.new()
	band.name = band_name
	band.mesh = st.commit()
	band.material_override = mat
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(band)
	bands.append(band)


## Evenly spaced points along a polyline.
static func _resample(line: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if line.is_empty():
		return out
	out.append(line[0])
	var left := 0.0
	for i in range(1, line.size()):
		var a := line[i - 1]
		var b := line[i]
		var seg := a.distance_to(b)
		var d := step - left
		while d <= seg:
			out.append(a.lerp(b, d / seg))
			d += step
		left = seg - (d - step)
	return out


func _build_crows() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.07)
	mat.roughness = 0.8
	# Black against the pale sky from the treeline: the winter fog would erase them.
	mat.disable_fog = true
	var root := Node3D.new()
	root.name = "Crows"
	var c := HumanRealmLayout.DOE_CLEARING
	root.position = Vector3(c.x, WorldHeight.height_at(c.x, c.y) + CROW_HEIGHT, c.y)
	add_child(root)
	for i in CROWS:
		var crow := Node3D.new()
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.24, 1.0)
		bm.material = mat
		body.mesh = bm
		crow.add_child(body)
		for s in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			wing.name = "WingL" if s < 0 else "WingR"
			var wm := BoxMesh.new()
			wm.size = Vector3(1.0, 0.04, 0.45)
			wm.material = mat
			wing.mesh = wm
			wing.position = Vector3(s * 0.6, 0.05, 0.02)
			crow.add_child(wing)
		root.add_child(crow)
		crows.append(crow)
		_crow_phase.append(TAU * i / CROWS + randf() * 0.4)


func _process(delta: float) -> void:
	if crows.is_empty() or not crows[0].is_visible_in_tree():
		return
	_t += delta
	for i in crows.size():
		var r := 12.0 + 5.0 * (i % 3)
		var w := 0.32 + 0.05 * (i % 2)
		var a := _crow_phase[i] + _t * w
		var crow := crows[i]
		crow.position = Vector3(cos(a) * r, sin(_t * 0.7 + i) * 1.5 + (i % 3) * 2.0, sin(a) * r)
		crow.rotation.y = -a  # tangent to the circle
		var flap := sin(_t * 7.0 + i * 1.3) * 0.5 if int(_t * 0.5 + i) % 3 != 0 else 0.1
		(crow.get_child(1) as Node3D).rotation.z = flap
		(crow.get_child(2) as Node3D).rotation.z = -flap


func _build_smoke() -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 3.0)
	quad.material = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(0.78, 0.78, 0.82, 0.55))
	fade.set_color(1, Color(0.85, 0.85, 0.9, 0.0))
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 2.6))
	for spot: Vector2 in SMOKE_SPOTS:
		var smoke := CPUParticles3D.new()
		smoke.name = "ChimneySmoke"
		smoke.mesh = quad
		smoke.amount = 18
		smoke.lifetime = 10.0
		smoke.preprocess = 10.0
		smoke.direction = Vector3.UP
		smoke.spread = 8.0
		smoke.initial_velocity_min = 1.6
		smoke.initial_velocity_max = 2.2
		smoke.gravity = Vector3(0.35, 0.15, -0.1)
		smoke.scale_amount_curve = grow
		smoke.color_ramp = fade
		smoke.position = Vector3(spot.x, WorldHeight.height_at(spot.x, spot.y) + 9.0, spot.y)
		add_child(smoke)


## Lanterns along the cottage road (HumanRealmLayout.ROADS[0]), village side last.
func _build_lanterns() -> void:
	var road: PackedVector2Array = HumanRealmLayout.ROADS[0]
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.25, 0.18, 0.12)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.78, 0.45)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.68, 0.32)
	glow.emission_energy_multiplier = 3.0
	var post := CylinderMesh.new()
	post.top_radius = 0.06
	post.bottom_radius = 0.08
	post.height = 2.4
	post.material = wood
	var lamp := SphereMesh.new()
	lamp.radius = 0.2
	lamp.height = 0.4
	lamp.material = glow
	var root := Node3D.new()
	root.name = "Lanterns"
	add_child(root)
	var left := LANTERN_STEP * 0.5
	for i in range(1, road.size()):
		var a := road[i - 1]
		var b := road[i]
		var length := a.distance_to(b)
		var side := (b - a).orthogonal().normalized() * 3.2
		var d := left
		while d < length:
			var p := a.lerp(b, d / length) + side
			var y := WorldHeight.height_at(p.x, p.y)
			var pole := MeshInstance3D.new()
			pole.mesh = post
			pole.position = Vector3(p.x, y + 1.2, p.y)
			root.add_child(pole)
			var light := MeshInstance3D.new()
			light.mesh = lamp
			light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			light.position = Vector3(p.x, y + 2.5, p.y)
			root.add_child(light)
			d += LANTERN_STEP
		left = d - length


func _on_flag(_flag: String, _value: Variant) -> void:
	var circling := not WorldState.has_flag("fact.wolf_skinned")
	for crow in crows:
		crow.visible = circling
