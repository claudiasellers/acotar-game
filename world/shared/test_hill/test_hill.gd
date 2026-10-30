## M0 test ground: a sculpted hill to run, climb and shoot on, wired to a tiny
## phase ladder so the whole deed -> flag -> phase -> region loop is exercised.
##
## Everything is generated in code; real regions use Terrain3D (World lane, M1).
extends Node3D

const SIZE := 256
const PHASES := preload("res://data/phases/m0_test_phases.tres")
const FEYRE_SCENE := preload("res://characters/feyre/feyre.tscn")
const HUD_SCRIPT := preload("res://ui/debug_hud.gd")
const TARGET_SCRIPT := preload("res://world/shared/test_hill/archery_target.gd")

const HILL_CENTER := Vector2(30.0, -40.0)
const SPAWN := Vector2(0.0, 70.0)

var sun: DirectionalLight3D
var feyre: Feyre


func _ready() -> void:
	if PhaseManager.phase_set == null:
		PhaseManager.start(PHASES)
	_build_environment()
	_build_terrain()
	_build_flowers()
	_build_ledges()
	_build_summit_trigger()
	_build_thorn_gate()
	_build_target()
	feyre = FEYRE_SCENE.instantiate()
	feyre.position = Vector3(SPAWN.x, height_at(SPAWN.x, SPAWN.y) + 0.2, SPAWN.y)
	add_child(feyre)
	var hud := CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	add_child(hud)


func _process(_delta: float) -> void:
	# The sun follows the in-game clock: 0.25 is sunrise, 0.75 sunset.
	var angle := (Clock.time_of_day - 0.25) * TAU
	sun.rotation = Vector3(-sin(angle) * deg_to_rad(80.0) - 0.05, deg_to_rad(-35.0), 0.0)
	sun.light_energy = clampf(sin(angle) * 1.6, 0.0, 1.3)


## Terrain height in metres at a world x/z position.
static func height_at(x: float, z: float) -> float:
	var hill := 26.0 * exp(-(pow(x - HILL_CENTER.x, 2) + pow(z - HILL_CENTER.y, 2)) / (2.0 * 28.0 * 28.0))
	var ridge := 9.0 * exp(-pow(x + 70.0, 2) / (2.0 * 14.0 * 14.0)) * (0.6 + 0.4 * sin(z * 0.03))
	var rolling := 1.6 * sin(x * 0.045) * cos(z * 0.038) + 0.7 * sin(x * 0.13 + z * 0.09)
	var edge := clampf((maxf(absf(x), absf(z)) - 100.0) / 28.0, 0.0, 1.0)
	return hill + ridge + rolling + edge * edge * 18.0


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.38, 0.55, 0.78)
	sky_mat.sky_horizon_color = Color(0.86, 0.80, 0.78)
	sky_mat.ground_horizon_color = Color(0.70, 0.66, 0.62)
	sky_mat.ground_bottom_color = Color(0.25, 0.28, 0.22)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.sdfgi_enabled = true
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.80, 0.82)
	env.fog_density = 0.0015
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	env.volumetric_fog_albedo = Color(1.0, 0.95, 0.92)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.93, 0.84)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)


func _build_terrain() -> void:
	var count := SIZE + 1
	var half := SIZE * 0.5
	var heights := PackedFloat32Array()
	heights.resize(count * count)
	for zi in count:
		for xi in count:
			heights[zi * count + xi] = height_at(xi - half, zi - half)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in count:
		for xi in count:
			var h := heights[zi * count + xi]
			var slope := absf(heights[zi * count + mini(xi + 1, SIZE)] - h) \
					+ absf(heights[mini(zi + 1, SIZE) * count + xi] - h)
			st.set_color(_ground_color(h, slope, xi, zi))
			st.set_uv(Vector2(xi, zi) / 8.0)
			st.add_vertex(Vector3(xi - half, h, zi - half))
	for zi in SIZE:
		for xi in SIZE:
			var i := zi * count + xi
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + count)
			st.add_index(i + 1)
			st.add_index(i + count + 1)
			st.add_index(i + count)
	st.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	st.set_material(material)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	ground.add_child(mesh_instance)
	var shape := HeightMapShape3D.new()
	shape.map_width = count
	shape.map_depth = count
	shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	ground.add_child(collision)
	add_child(ground)


func _ground_color(h: float, slope: float, xi: int, zi: int) -> Color:
	var grass := Color(0.36, 0.52, 0.24).lerp(Color(0.52, 0.62, 0.30), clampf(h / 26.0, 0.0, 1.0))
	var jitter := 0.04 * sin(xi * 1.7 + zi * 2.3)
	grass = grass.lightened(jitter) if jitter > 0.0 else grass.darkened(-jitter)
	var rock := Color(0.48, 0.46, 0.42)
	return grass.lerp(rock, clampf((slope - 1.2) / 1.5, 0.0, 1.0))


func _build_flowers() -> void:
	var colors := [Color(0.93, 0.55, 0.65), Color(0.98, 0.95, 0.90), Color(0.74, 0.62, 0.90), Color(0.98, 0.84, 0.45)]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bloom := SphereMesh.new()
	bloom.radius = 0.06
	bloom.height = 0.1
	bloom.radial_segments = 6
	bloom.rings = 3
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	bloom.material = material
	mm.mesh = bloom
	mm.instance_count = 4000
	var rng := RandomNumberGenerator.new()
	rng.seed = 1817
	for i in mm.instance_count:
		var x := rng.randf_range(-100.0, 100.0)
		var z := rng.randf_range(-100.0, 100.0)
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, height_at(x, z) + 0.12, z)))
		mm.set_instance_color(i, colors[rng.randi() % colors.size()])
	var flowers := MultiMeshInstance3D.new()
	flowers.name = "Flowers"
	flowers.multimesh = mm
	flowers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flowers)


## Blocks of rising height near the spawn for testing the mantle.
func _build_ledges() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.78, 0.74, 0.68)
	var heights_to_test := [0.9, 1.5, 2.1, 2.8]
	for i in heights_to_test.size():
		var h: float = heights_to_test[i]
		var x := -8.0 + i * 4.0
		var z := SPAWN.y - 10.0
		_add_box(Vector3(x, height_at(x, z) + h * 0.5 - 0.3, z), Vector3(3.0, h + 0.6, 3.0), stone)


func _build_summit_trigger() -> void:
	var trigger := ActionTrigger.new()
	trigger.name = "SummitTrigger"
	trigger.flag = "fact.test.reached_summit"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 7.0
	shape.shape = sphere
	trigger.add_child(shape)
	trigger.position = Vector3(HILL_CENTER.x, height_at(HILL_CENTER.x, HILL_CENTER.y), HILL_CENTER.y)
	trigger.collision_mask = Feyre.PLAYER_LAYER
	add_child(trigger)


## A thorn wall that opens when the summit phase begins.
func _build_thorn_gate() -> void:
	var gate := RegionGate.new()
	gate.name = "ThornGate"
	gate.region_id = &"test_meadow"
	add_child(gate)
	var thorn := StandardMaterial3D.new()
	thorn.albedo_color = Color(0.20, 0.24, 0.14)
	var x := -40.0
	for i in 9:
		var z := 10.0 + i * 3.0
		var box := _add_box(Vector3(x, height_at(x, z) + 1.6, z), Vector3(2.2, 3.6, 3.2), thorn, gate)
		box.rotation.y = 0.3 * sin(i * 1.3)


func _build_target() -> void:
	var x := 22.0
	var z := 35.0
	var target := StaticBody3D.new()
	target.name = "ArcheryTarget"
	target.set_script(TARGET_SCRIPT)
	target.collision_layer = 1 << 3
	target.position = Vector3(x, height_at(x, z) + 1.4, z)
	target.rotation.y = atan2(SPAWN.x - x, SPAWN.y - z)
	var face := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.15
	face.mesh = disc
	face.rotation_degrees.x = 90.0
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.86, 0.74, 0.46)
	face.material_override = straw
	target.add_child(face)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.7
	cylinder.height = 0.15
	shape.shape = cylinder
	shape.rotation_degrees.x = 90.0
	target.add_child(shape)
	var trigger := ActionTrigger.new()
	trigger.name = "HitTrigger"
	trigger.flag = "fact.test.target_hit"
	trigger.fire_on_body_enter = false
	target.add_child(trigger)
	add_child(target)


func _add_box(at: Vector3, size: Vector3, material: Material, parent: Node = self) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)
	return body
