## The player's map pin standing in the world: a soft, sparkly faelight beam
## with rising glints, so she can steer by eye. It fades as she
## draws near and bursts into sparkles when she arrives (R3). Lives under
## WorldMapHud; follows its MapPin.
extends Node3D

const HEIGHT := 70.0
const RADIUS := 1.1
## Fully faded within FADE_NEAR m, full beyond FADE_FAR m.
const FADE_NEAR := 18.0
const FADE_FAR := 90.0
const SHADER := preload("res://ui/map/pin_beacon.gdshader")

var _beam: MeshInstance3D
var _mat: ShaderMaterial
var _motes: CPUParticles3D
var _burst: CPUParticles3D


func _ready() -> void:
	visible = false
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS * 0.35
	mesh.bottom_radius = RADIUS
	mesh.height = HEIGHT
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	_beam = MeshInstance3D.new()
	_beam.mesh = mesh
	_beam.material_override = _mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = HEIGHT * 0.5
	add_child(_beam)
	_motes = _sparkles(40, 3.5, false)
	add_child(_motes)
	_burst = _sparkles(90, 1.4, true)
	add_child(_burst)


func show_at(world: Vector3) -> void:
	global_position = world
	visible = true
	_motes.emitting = true


func hide_beacon() -> void:
	visible = false
	_motes.emitting = false


## Arrival: one bright burst where the beam stood, then gone.
func burst() -> void:
	_burst.amount = 30 if GameSettings.reduced_effects else 90
	_burst.restart()
	_burst.emitting = true
	_beam.visible = false
	_motes.emitting = false
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		_beam.visible = true
		hide_beacon())


func set_colours(tint: Color, glow: Color) -> void:
	_mat.set_shader_parameter(&"tint", tint)
	_mat.set_shader_parameter(&"glow", glow)


## Fade by Feyre's distance (metres).
func set_distance(d: float) -> void:
	_mat.set_shader_parameter(&"strength", smoothstep(FADE_NEAR, FADE_FAR, d))


func _sparkles(count: int, life: float, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = count
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 0.95 if one_shot else 0.0
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.5
	p.direction = Vector3.UP
	p.spread = 70.0 if one_shot else 12.0
	p.gravity = Vector3(0, -2.0 if one_shot else 0.6, 0)
	p.initial_velocity_min = 4.0 if one_shot else 1.0
	p.initial_velocity_max = 9.0 if one_shot else 3.0
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = PauseStyle.soft_dot(32)
	quad.material = m
	p.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
	ramp.set_color(1, Color(1.0, 0.75, 0.88, 0.0))
	p.color_ramp = ramp
	return p
