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
	p.amount = 44
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.process_material = process_material()
	p.draw_pass_1 = draw_mesh()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-8, -1, -8), Vector3(24, 20, 24))
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
	m.gravity = Vector3(0.45, 0.1, 0.12)  # a light wind bends and spreads the column
	m.damping_min = 0.08
	m.damping_max = 0.16
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -8.0
	m.angular_velocity_max = 8.0
	m.scale_min = 0.8
	m.scale_max = 1.25
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.9
	m.turbulence_noise_scale = 3.0
	m.turbulence_influence_min = 0.04
	m.turbulence_influence_max = 0.14
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.45))
	curve.add_point(Vector2(0.3, 1.5))
	curve.add_point(Vector2(1.0, 4.2))
	var ct := CurveTexture.new()
	ct.curve = curve
	m.scale_curve = ct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0.5, 0.5, 0.53, 0.0), Color(0.55, 0.55, 0.59, 0.26),
			Color(0.68, 0.69, 0.73, 0.14), Color(0.8, 0.81, 0.85, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	_process = m
	return m


static func draw_mesh() -> QuadMesh:
	if _mesh != null:
		return _mesh
	var q := QuadMesh.new()
	q.size = Vector2(2.6, 2.6)
	var puff := Gradient.new()
	# A gaussian-like falloff with no visible edge: hard-edged disks read as
	# a chain of white balls (audit A7 follow-up).
	puff.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	puff.colors = PackedColorArray([Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.38),
			Color(1, 1, 1, 0.17), Color(1, 1, 1, 0.05), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = puff
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var mat := MaterialLibrary.surface()
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
