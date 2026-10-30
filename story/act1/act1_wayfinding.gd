## Teaching the way through the world, not markers (R2), for Act I's opening:
##   - fresh doe tracks in the snow from the end of the deer trail to the doe
##     clearing, so following the trail past the treeline leads somewhere;
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
const CROWS := 6
const CROW_HEIGHT := 38.0
const LANTERN_STEP := 32.0
const SMOKE_SPOTS := [
	Vector2(380.0, 2250.0), Vector2(415.0, 2215.0), Vector2(330.0, 2300.0), Vector2(460.0, 2320.0),
]

var tracks: MultiMeshInstance3D
var crows: Array[Node3D] = []
var _crow_phase: Array[float] = []
var _t: float = 0.0


func _ready() -> void:
	name = "Act1Wayfinding"
	_build_tracks()
	_build_crows()
	_build_smoke()
	_build_lanterns()
	EventBus.flag_changed.connect(_on_flag)
	_on_flag("", null)


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


func _build_tracks() -> void:
	var pts := track_points()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.1
	mesh.bottom_radius = 0.1
	mesh.height = 0.02
	mesh.radial_segments = 8
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.40, 0.52)
	mat.roughness = 1.0
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = pts.size() * 2
	for i in pts.size():
		var p := pts[i]
		var ahead := pts[mini(i + 1, pts.size() - 1)] - p if i + 1 < pts.size() else p - pts[i - 1]
		var yaw := atan2(-ahead.x, -ahead.y)
		var side := Vector2(ahead.y, -ahead.x).normalized() * (0.14 if i % 2 == 0 else -0.14)
		for hoof in 2:
			var q := p + side + ahead.normalized() * (0.09 * hoof)
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3(0.7, 1.0, 1.25))
			var at := Vector3(q.x, WorldHeight.height_at(q.x, q.y) + 0.005, q.y)
			mm.set_instance_transform(i * 2 + hoof, Transform3D(basis, at))
	tracks = MultiMeshInstance3D.new()
	tracks.name = "DoeTracks"
	tracks.multimesh = mm
	tracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracks.visibility_range_end = 140.0
	add_child(tracks)


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
