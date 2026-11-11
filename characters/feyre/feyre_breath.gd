## Visible breath in the cold (root doc §4.8): faster and bigger when she is
## cold, hungry or working hard. A child of her model named "Breath"; Feyre
## calls `update()` each _process (T100: moved out of feyre.gd).
class_name FeyreBreath
extends GPUParticles3D

var _body_state: BodyState
var _phase: float = 0.0


func _init(body_state: BodyState) -> void:
	_body_state = body_state
	name = "Breath"
	amount = 10
	lifetime = 1.4
	emitting = false
	position = Vector3(0, 1.55, -0.16)
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0.2, -1)
	mat.spread = 18.0
	mat.initial_velocity_min = 0.25
	mat.initial_velocity_max = 0.45
	mat.gravity = Vector3(0, 0.08, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.35))
	grad.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	process_material = mat
	var puff := QuadMesh.new()
	puff.size = Vector2(0.12, 0.12)
	var pm := MaterialLibrary.surface()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.vertex_color_use_as_albedo = true
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.material = pm
	draw_pass_1 = puff


func update(delta: float) -> void:
	if _body_state == null:
		return
	var weather := Weather.find(get_tree())
	var visible_breath := weather != null and weather.is_breath_visible()
	_phase = fmod(_phase + delta * _body_state.breath_rate(), 1.0)
	# Exhale for the first 40% of each breath.
	emitting = visible_breath and _phase < 0.4
	amount_ratio = _body_state.breath_intensity()
