## The drift of petals the white mare leaves when she is called (lane L47-6,
## R3: petals). Blush, lilac, butter and pearl petals kicked up from her
## hooves, tumbling and fading behind her. World-space, so the trail stays
## where she passed. Sunlit, no emission; albedo capped at 0.85.
class_name MareTrail
extends GPUParticles3D

## Albedo stays at or under 0.85 a channel (the project's albedo cap).
const COLORS: Array[Color] = [Color(0.85, 0.68, 0.75), Color(0.73, 0.66, 0.85),
	Color(0.85, 0.8, 0.61), Color(0.85, 0.82, 0.81)]

static var _mesh: QuadMesh


func _init() -> void:
	name = "MareTrail"
	amount = 120
	lifetime = 2.2
	local_coords = false
	emitting = false
	position = Vector3(0.0, 0.25, 0.35)
	draw_pass_1 = _petal_mesh()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-30, -4, -30), Vector3(60, 12, 60))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.35, 0.15, 0.7)
	m.direction = Vector3(0.0, 1.0, 0.0)
	m.spread = 55.0
	m.initial_velocity_min = 0.8
	m.initial_velocity_max = 2.2
	m.gravity = Vector3(0.0, -0.9, 0.0)
	m.damping_min = 1.2
	m.damping_max = 2.4
	m.angular_velocity_min = -220.0
	m.angular_velocity_max = 220.0
	m.angle_min = 0.0
	m.angle_max = 360.0
	m.scale_min = 0.6
	m.scale_max = 1.25
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(0.12, 1.0))
	curve.add_point(Vector2(0.75, 0.85))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	m.scale_curve = ct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	g.colors = PackedColorArray(COLORS)
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_initial_ramp = gt
	process_material = m


static func _petal_mesh() -> QuadMesh:
	if _mesh:
		return _mesh
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(0.1, 0.07)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _petal_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Lit by the sun like everything else: no emission in daylight (project rule).
	mat.roughness = 0.55
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material = mat
	return _mesh


## A soft rounded petal: an ellipse with a paler heart.
static func _petal_texture() -> ImageTexture:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var r := u * u / 0.9 + v * v / 0.55
			var a := clampf((1.0 - r) * 3.0, 0.0, 1.0)
			var heart := 1.0 - 0.18 * clampf(1.0 - r * 2.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(heart, heart, heart, a))
	return ImageTexture.create_from_image(img)
