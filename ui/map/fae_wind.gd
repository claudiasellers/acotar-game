## The guiding wind: when the player has a pin, gusts of blossom petals lift
## a few steps ahead of Feyre and tumble off the way she should go, like
## Ghost of Tsushima's guiding wind. Petals, not lights: they are lit by the
## scene like anything else (no daytime glow before the glamour lifts). A
## gust comes when the pin is set or the map closes, then every GUST_EVERY
## seconds; it stops near the pin, where the beam takes over (R3). Lives
## under WorldMapHud.
extends Node3D

const GUST_EVERY := 4.5
const GUST_SECONDS := 1.8
## Quiet within this distance of the pin (metres).
const NEAR := 25.0
const SPEED := 7.0
const LIFE := 2.0
## Where a gust starts: this far behind her along the wind, at knee height.
const UPWIND := 1.5
const KNEE := 0.4
const SHADER := preload("res://ui/map/fae_wind.gdshader")
static var _petal: ImageTexture

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
	_stream.emission_box_extents = Vector3(1.4, 0.2, 1.4)
	_stream.spread = 7.0
	_stream.gravity = Vector3(0, -0.6, 0)
	# Tumbling: the shader turns each petal by its angle.
	_stream.angle_min = -180.0
	_stream.angle_max = 180.0
	_stream.angular_velocity_min = -220.0
	_stream.angular_velocity_max = 220.0
	_stream.tangential_accel_min = -1.5
	_stream.tangential_accel_max = 1.5
	_stream.initial_velocity_min = SPEED * 0.75
	_stream.initial_velocity_max = SPEED * 1.15
	_stream.damping_min = 0.6
	_stream.damping_max = 1.4
	_stream.scale_amount_min = 0.12
	_stream.scale_amount_max = 0.24
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	_stream.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"petal", petal_texture())
	quad.material = m
	_stream.mesh = quad
	set_colours(Color(1.0, 0.75, 0.86), Color(1.0, 0.93, 0.7))
	add_child(_stream)


## Petal colours from the realm's theme (blush and rose in Spring), deepened
## a little so they read against snow; white blossom mixed in.
func set_colours(tint: Color, _glow: Color = Color.WHITE) -> void:
	var rose := Color.from_hsv(tint.h, clampf(tint.s * 1.5, 0.0, 1.0), tint.v * 0.95)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(rose, 0.0))
	ramp.add_point(0.1, Color(rose, 1.0))
	ramp.add_point(0.75, Color(rose.lerp(Color(1.0, 0.95, 0.96), 0.35), 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(rose, 0.0))
	_stream.color_ramp = ramp


## A soft petal: an egg-shaped mask, rounder at the top, pinched at the base,
## with a pale vein down the middle (red channel) for the shader.
static func petal_texture() -> ImageTexture:
	if _petal:
		return _petal
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var w := 0.55 * (1.0 - 0.45 * v)  # wider at the top
			var d := Vector2(u / w, v / 0.95).length()
			var a := clampf((1.0 - d) * 6.0, 0.0, 1.0)
			var vein := 1.0 - clampf(1.0 - absf(u) * 9.0, 0.0, 1.0) * 0.6
			img.set_pixel(x, y, Color(vein, vein, vein, a))
	_petal = ImageTexture.create_from_image(img)
	return _petal


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
	# Start a little upwind of her and low, knee height, like wind through the
	# grass: the petals blow past her legs and on towards the pin. (Higher or
	# further ahead, the camera behind her sees them burst round her head.)
	_stream.global_position = feyre_pos - Vector3(heading.x, 0.0, heading.y) * UPWIND + Vector3.UP * KNEE
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
