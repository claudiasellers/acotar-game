## Ambient life around Feyre in the woods: the "magic everywhere" layer (rule
## R3) plus small creatures. Particle systems follow her and switch on and
## off with the biome she is in (WoodsBiome.ambience) and the time of day.
## Horror biomes list only "mist", so the sparkle and birdsong simply stop:
## that silence is the readable tip into dread.
##
## Effects: pollen, petals, sparkles, faelights (dusk/night), fireflies
## (night), ash_motes (blight), mist. Creatures: butterflies, songbirds,
## dragonflies, fish, moths (night).
class_name AmbientLife
extends Node3D

const EFFECTS := ["pollen", "petals", "sparkles", "faelights", "fireflies", "ash_motes",
		"butterflies", "songbirds", "dragonflies", "fish", "moths"]
## Effects that only show at dusk/night, and those that only show by day.
const NIGHT_ONLY := ["faelights", "fireflies", "moths"]
const DAY_ONLY := ["butterflies", "songbirds", "dragonflies"]

var def: WoodsRegionDef
var bounds: Rect2
## False when a region builder adds the effects one per job (add_effect).
var build_effects := true

const VISIBILITY := AABB(Vector3(-40, -10, -40), Vector3(80, 40, 80))

## effect id -> [process material, draw mesh, amount, lifetime], shared.
static var _kits: Dictionary = {}

var _systems: Dictionary = {}
var _biomes: Dictionary = {}
var _timer := 0.0
var current_biome: StringName


func _ready() -> void:
	_biomes = def.biome_map()
	if build_effects:
		for id in EFFECTS:
			add_effect(id)


func add_effect(id: String) -> void:
	# Materials are shared across regions: binding a new particle process
	# material compiles its shader (~4 ms), reusing one costs nothing.
	if not _kits.has(id):
		var made := _make(id)
		_kits[id] = [made.process_material, made.draw_pass_1, made.amount, made.lifetime]
		made.free()
	var kit: Array = _kits[id]
	var p := GPUParticles3D.new()
	p.process_material = kit[0]
	p.draw_pass_1 = kit[1]
	p.amount = kit[2]
	p.lifetime = kit[3]
	p.preprocess = kit[3]
	p.local_coords = false
	p.visibility_aabb = VISIBILITY
	p.name = id.capitalize().replace(" ", "")
	p.emitting = false
	add_child(p)
	_systems[id] = p


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var cam := get_viewport().get_camera_3d()
	var focus: Vector3 = player.global_position if player != null else (cam.global_position if cam != null else Vector3.INF)
	if focus == Vector3.INF or not bounds.grow(40.0).has_point(Vector2(focus.x, focus.z)):
		for id in _systems:
			_systems[id].emitting = false
		return
	global_position = focus
	var clock := get_node_or_null(^"/root/Clock")
	refresh(def.provider.biome_at(focus.x, focus.z), clock.hour() if clock != null else 12.0)


## Switches effects for a biome and hour (public for tests).
func refresh(biome_id: StringName, hour: float) -> void:
	current_biome = biome_id
	var b: WoodsBiome = _biomes.get(biome_id)
	var wanted: PackedStringArray = b.ambience if b != null else PackedStringArray()
	var dusk_or_night := hour >= 18.5 or hour < 5.5
	for id in _systems:
		var on := wanted.has(id)
		if id in NIGHT_ONLY:
			on = on and dusk_or_night
		if id in DAY_ONLY:
			on = on and not dusk_or_night
		_systems[id].emitting = on


func active_effects() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _systems:
		if _systems[id].emitting:
			out.append(id)
	return out


func _make(id: String) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.gravity = Vector3.ZERO
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var draw := StandardMaterial3D.new()
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.vertex_color_use_as_albedo = true
	quad.material = draw
	p.draw_pass_1 = quad
	match id:
		"pollen":
			_cloud(p, mat, 300, 8.0, Vector3(18, 4, 18), Color(1.0, 0.94, 0.62, 0.8), 0.04, 0.25)
		"petals":
			_cloud(p, mat, 160, 9.0, Vector3(16, 6, 16), Color(1.0, 0.72, 0.84, 0.95), 0.09, 0.6)
			mat.gravity = Vector3(0.3, -0.25, 0.1)
			mat.angular_velocity_min = -90.0
			mat.angular_velocity_max = 90.0
			draw.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
			draw.cull_mode = BaseMaterial3D.CULL_DISABLED
		"sparkles":
			_cloud(p, mat, 220, 2.5, Vector3(14, 3, 14), Color(1.0, 0.96, 0.85, 1.0), 0.05, 0.1)
			draw.emission_enabled = true
			draw.emission = Color(1.0, 0.9, 0.95)
			draw.emission_energy_multiplier = 4.0
		"faelights":
			_cloud(p, mat, 120, 10.0, Vector3(20, 3, 20), Color(0.78, 0.95, 1.0, 1.0), 0.12, 0.4)
			mat.gravity = Vector3(0, 0.08, 0)
			draw.emission_enabled = true
			draw.emission = Color(0.7, 0.92, 1.0)
			draw.emission_energy_multiplier = 6.0
		"fireflies":
			_cloud(p, mat, 160, 6.0, Vector3(18, 2, 18), Color(1.0, 0.95, 0.55, 1.0), 0.06, 0.8)
			draw.emission_enabled = true
			draw.emission = Color(1.0, 0.92, 0.5)
			draw.emission_energy_multiplier = 5.0
		"ash_motes":
			_cloud(p, mat, 200, 10.0, Vector3(18, 5, 18), Color(0.62, 0.62, 0.64, 0.7), 0.05, 0.2)
			mat.gravity = Vector3(0.0, -0.08, 0.0)
		"butterflies":
			_creatures(p, mat, 18, Vector3(14, 1.5, 14), _wing_mesh(Color(0.98, 0.70, 0.90), 0.09), 1.2, 1.0)
		"songbirds":
			_creatures(p, mat, 10, Vector3(30, 3, 30), _wing_mesh(Color(0.55, 0.45, 0.40), 0.16), 5.0, 9.0)
		"dragonflies":
			_creatures(p, mat, 12, Vector3(10, 0.6, 10), _wing_mesh(Color(0.55, 0.85, 0.95), 0.07), 3.0, 0.6)
		"fish":
			_creatures(p, mat, 14, Vector3(6, 0.2, 6), _fish_mesh(), 0.8, -0.4)
		"moths":
			_creatures(p, mat, 14, Vector3(12, 2, 12), _wing_mesh(Color(0.92, 0.90, 0.82), 0.06), 1.5, 1.4)
	return p


func _cloud(p: GPUParticles3D, mat: ParticleProcessMaterial, amount: int, lifetime: float, box: Vector3,
		color: Color, size: float, turbulence: float) -> void:
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	mat.emission_box_extents = box
	mat.color = color
	mat.scale_min = size / 0.06 * 0.7
	mat.scale_max = size / 0.06 * 1.3
	mat.turbulence_enabled = turbulence > 0.0
	mat.turbulence_noise_strength = turbulence
	mat.turbulence_noise_scale = 3.0
	mat.initial_velocity_min = 0.05
	mat.initial_velocity_max = 0.3
	mat.direction = Vector3(0.3, 0.2, 0.1)
	mat.spread = 180.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(0.85, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	mat.scale_curve = tex


## Small flying/swimming creatures: few, slow, wandering, each drawn with a
## flapping wing mesh (vertex sway in the foliage shader does the flap).
func _creatures(p: GPUParticles3D, mat: ParticleProcessMaterial, amount: int, box: Vector3, mesh: Mesh,
		speed: float, height: float) -> void:
	p.amount = amount
	p.lifetime = 14.0
	p.preprocess = 14.0
	mat.emission_box_extents = box
	mat.emission_shape_offset = Vector3(0, height, 0)
	mat.initial_velocity_min = speed * 0.6
	mat.initial_velocity_max = speed
	mat.direction = Vector3(1, 0, 0)
	mat.spread = 180.0
	mat.flatness = 0.85
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.6
	mat.turbulence_noise_scale = 2.0
	mat.particle_flag_align_y = false
	mat.particle_flag_rotate_y = true
	p.draw_pass_1 = mesh


func _wing_mesh(color: Color, span: float) -> Mesh:
	var kit := MeshKit.new(hash(color))
	var body := color.darkened(0.5)
	kit.tube(Vector3(-span * 0.4, 0, 0), Vector3(span * 0.4, 0, 0), span * 0.06, span * 0.04, 4, body, body)
	for side in [-1.0, 1.0]:
		var tip := Vector3(0.0, span * 0.1, side * span)
		# Wings sway (flap) on UV.x through the foliage shader's wind.
		kit.tri(Vector3(-span * 0.3, 0, 0), Vector3(span * 0.3, 0, 0), tip, color, color, color.lightened(0.2), 0.0, 0.0, 1.0)
		kit.tri(Vector3(span * 0.3, 0, 0), Vector3(span * 0.1, 0, side * span * 0.7), tip, color, color, color.lightened(0.2), 0.0, 0.8, 1.0)
	var m := kit.commit()
	var mat := ShaderMaterial.new()
	mat.shader = FloraLibrary.FOLIAGE_SHADER
	mat.set_shader_parameter(&"sparkle", 0.3)
	m.surface_set_material(0, mat)
	return m


func _fish_mesh() -> Mesh:
	var kit := MeshKit.new(77)
	var c := Color(0.70, 0.62, 0.55)
	kit.blob(Vector3.ZERO, Vector3(0.14, 0.03, 0.035), c, c.darkened(0.3), 0.05, 3, 6)
	kit.tri(Vector3(-0.13, 0, 0), Vector3(-0.22, 0.04, 0), Vector3(-0.22, -0.04, 0), c, c, c, 0.0, 1.0, 1.0)
	var m := kit.commit()
	m.surface_set_material(0, FloraLibrary.material(&"plain"))
	return m
