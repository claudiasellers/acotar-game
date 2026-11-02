## The faelight wind: when the player has a pin, gusts of pastel glints rise
## round Feyre and stream off the way she should go, a few metres ahead of
## her and level with her shoulders, like a guiding breeze (Ghost of
## Tsushima's guiding wind; Fable's breadcrumb trail). A gust comes when the
## pin is set or the map closes, then every GUST_EVERY seconds; it stops
## near the pin, where the beam takes over (R3). Lives under WorldMapHud.
extends Node3D

const GUST_EVERY := 4.5
const GUST_SECONDS := 1.8
## Quiet within this distance of the pin (metres).
const NEAR := 25.0
const SPEED := 7.0
const LIFE := 2.0
const SHADER := preload("res://ui/map/fae_wind.gdshader")

var _stream: CPUParticles3D
var _gust_left: float = 0.0
var _next_gust: float = 0.0
## The way the wind blows (world XZ, unit), for tests.
var heading: Vector2 = Vector2.ZERO
var gusting: bool = false


func _ready() -> void:
	_stream = CPUParticles3D.new()
	_stream.amount = 110
	_stream.lifetime = LIFE
	_stream.local_coords = false
	_stream.emitting = false
	_stream.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_stream.emission_box_extents = Vector3(1.6, 0.35, 1.6)
	_stream.spread = 7.0
	_stream.gravity = Vector3(0, 0.25, 0)
	_stream.initial_velocity_min = SPEED * 0.75
	_stream.initial_velocity_max = SPEED * 1.15
	_stream.damping_min = 0.6
	_stream.damping_max = 1.4
	_stream.scale_amount_min = 0.16
	_stream.scale_amount_max = 0.36
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	_stream.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"dot", PauseStyle.soft_dot(32))
	quad.material = m
	_stream.mesh = quad
	set_colours(Color(1.0, 0.75, 0.86), Color(1.0, 0.93, 0.7))
	add_child(_stream)


func set_colours(tint: Color, glow: Color) -> void:
	# Pale theme colours vanish on snow: deepen the rose so it reads, and keep
	# the gold for the sparkle at birth.
	var rose := Color.from_hsv(tint.h, clampf(tint.s * 1.6, 0.0, 1.0), tint.v * 0.92)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(glow, 0.0))
	ramp.add_point(0.12, Color(glow, 1.0))
	ramp.add_point(0.4, Color(rose, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(rose, 0.0))
	_stream.color_ramp = ramp


## A gust now (pin just set, or the map just closed).
func gust() -> void:
	_next_gust = 0.0


func stop() -> void:
	_stream.emitting = false
	gusting = false
	_gust_left = 0.0
	_next_gust = 0.0


## Each frame from WorldMapHud: where she stands and where the pin is.
func follow(feyre_pos: Vector3, pin_xz: Vector2, delta: float) -> void:
	var to := pin_xz - Vector2(feyre_pos.x, feyre_pos.z)
	if to.length() < NEAR:
		_stream.emitting = false
		gusting = false
		return
	heading = to.normalized()
	var dir := Vector3(heading.x, 0.05, heading.y).normalized()
	_stream.direction = dir
	# Start a few steps ahead of her, low (knee to hip, like wind through the
	# grass), so it leads the eye without crossing the camera's view of her.
	_stream.global_position = feyre_pos + Vector3(heading.x, 0.0, heading.y) * 3.5 + Vector3.UP * 0.7
	_next_gust -= delta
	if _gust_left > 0.0:
		_gust_left -= delta
		if _gust_left <= 0.0:
			_stream.emitting = false
			gusting = false
	elif _next_gust <= 0.0:
		_next_gust = GUST_EVERY
		_gust_left = GUST_SECONDS
		_stream.amount = 40 if GameSettings.reduced_effects else 110
		_stream.emitting = true
		gusting = true
