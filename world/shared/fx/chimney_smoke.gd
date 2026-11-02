## Chimney smoke for the human realm (quality audit B3): soft camera-facing
## sprites with a radial falloff, many of them overlapping, rising, widening,
## drifting with the wind and fading in and out, so the plume reads as one
## soft column rather than a chain of separate spheres. One shared process
## material and draw mesh (a new process material compiles its shader).
class_name ChimneySmoke
extends RefCounted

static var _process: ParticleProcessMaterial
static var _mesh: QuadMesh


## A plume at `at` (local to its parent), ready to add.
static func make(at: Vector3, plume_name: String = "ChimneySmoke") -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = plume_name
	p.position = at
	p.amount = 28
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.process_material = process_material()
	p.draw_pass_1 = draw_mesh()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(18, 16, 18))
	p.visibility_range_end = 320.0
	return p


static func process_material() -> ParticleProcessMaterial:
	if _process != null:
		return _process
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0.1, 1, 0)
	m.spread = 9.0
	m.initial_velocity_min = 0.55
	m.initial_velocity_max = 0.85
	m.gravity = Vector3(0.32, 0.12, 0.08)  # a light wind bends the column
	m.damping_min = 0.08
	m.damping_max = 0.16
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -8.0
	m.angular_velocity_max = 8.0
	m.scale_min = 0.8
	m.scale_max = 1.25
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.6
	m.turbulence_noise_scale = 3.0
	m.turbulence_influence_min = 0.04
	m.turbulence_influence_max = 0.09
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(0.35, 1.2))
	curve.add_point(Vector2(1.0, 3.2))
	var ct := CurveTexture.new()
	ct.curve = curve
	m.scale_curve = ct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.52, 0.52, 0.55, 0.0), Color(0.56, 0.56, 0.6, 0.42),
			Color(0.7, 0.71, 0.75, 0.24), Color(0.8, 0.81, 0.85, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	_process = m
	return m


static func draw_mesh() -> QuadMesh:
	if _mesh != null:
		return _mesh
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	var puff := Gradient.new()
	puff.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	puff.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = puff
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.disable_receive_shadows = true
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.6
	q.material = mat
	_mesh = q
	return q
