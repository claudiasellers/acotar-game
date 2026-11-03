## Flames on burning ElementField cells (T5): a small pooled flame per cell,
## riding the prop it burns on; a puff of steam when water puts it out.
## Fire is the one thing in the spring world that glows by itself.
class_name FireFx
extends Node3D

const MAX_FLAMES := 32

var _flames: Dictionary = {}  # cell id -> GPUParticles3D
var _follow: Dictionary = {}  # cell id -> Node3D
static var _flame_mesh: QuadMesh
static var _steam_mesh: QuadMesh


func _ready() -> void:
	top_level = true


func light(id: int, at: Vector3, follow: Node3D = null) -> void:
	if _flames.has(id) or _flames.size() >= MAX_FLAMES:
		return
	var p := _particles(_flame(), 28, 0.7, Vector3(0, 1.6, 0), Color(1.0, 0.62, 0.3), Color(1.0, 0.86, 0.5))
	add_child(p)
	p.global_position = at + Vector3.UP * 0.15
	p.emitting = true
	_flames[id] = p
	if follow:
		_follow[id] = follow


func douse(id: int, steam: bool) -> void:
	var p := _flames.get(id) as GPUParticles3D
	_flames.erase(id)
	_follow.erase(id)
	if p == null:
		return
	if steam:
		var s := _particles(_steam(), 14, 1.2, Vector3(0, 1.0, 0), Color(0.95, 0.95, 1.0, 0.6), Color(1, 1, 1, 0.0))
		s.one_shot = true
		add_child(s)
		s.global_position = p.global_position
		s.emitting = true
		s.finished.connect(s.queue_free)
	p.emitting = false
	get_tree().create_timer(p.lifetime).timeout.connect(p.queue_free)


func flame_count() -> int:
	return _flames.size()


func _process(_delta: float) -> void:
	for id: int in _follow.keys():
		var n := _follow[id] as Node3D
		if not is_instance_valid(n):
			_follow.erase(id)
			continue
		(_flames[id] as Node3D).global_position = n.global_position + Vector3.UP * 0.3


func _particles(mesh: Mesh, amount: int, life: float, gravity: Vector3, from: Color, to: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.draw_pass_1 = mesh
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.18
	m.gravity = gravity
	m.initial_velocity_min = 0.1
	m.initial_velocity_max = 0.4
	m.scale_min = 0.5
	m.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, from)
	ramp.set_color(1, to)
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	m.color_ramp = tex
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	m.scale_curve = ct
	p.process_material = m
	p.visibility_aabb = AABB(Vector3(-1, -0.5, -1), Vector3(2, 3, 2))
	return p


static func _flame() -> QuadMesh:
	if _flame_mesh == null:
		_flame_mesh = _quad(0.34, BaseMaterial3D.BLEND_MODE_ADD, true)
	return _flame_mesh


static func _steam() -> QuadMesh:
	if _steam_mesh == null:
		_steam_mesh = _quad(0.5, BaseMaterial3D.BLEND_MODE_MIX, false)
	return _steam_mesh


static func _quad(size: float, blend: BaseMaterial3D.BlendMode, unshaded: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = blend
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_dot()
	q.material = mat
	return q


static func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	return t
