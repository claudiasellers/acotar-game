## A draught through the bedroom window (L34-7): the room's own curtains
## stir, the fabric moving more toward the hem, then settle. A vertex sway on
## the drapes' fabric surface for a few seconds; the original material comes
## back after. Diegetic only: no glow, no marker (R2).
class_name CurtainDraught
extends RefCounted

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.75;
uniform float amp = 0.0;
uniform float top_y = 3.0;
uniform float bottom_y = 0.0;
void vertex() {
	float w = clamp((top_y - VERTEX.y) / max(top_y - bottom_y, 0.01), 0.0, 1.0);
	w = w * w;
	VERTEX += NORMAL * amp * w * (0.55 + 0.45 * sin(TIME * 2.3 + VERTEX.x * 2.1 + VERTEX.z * 1.7));
}
void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
}
"""
const PEAK := 0.07

static var _shader: Shader


## Stirs `curtains` (a room's "Curtains" mesh) for `seconds`. Returns the tween.
static func stir(curtains: MeshInstance3D, seconds: float = 4.0) -> Tween:
	if curtains == null or curtains.mesh == null or not curtains.is_inside_tree():
		return null
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var base := curtains.mesh.surface_get_material(0) as StandardMaterial3D
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter(&"albedo", base.albedo_color if base else Color(0.16, 0.56, 0.40))
	mat.set_shader_parameter(&"roughness", base.roughness if base else 0.75)
	var box := curtains.mesh.get_aabb()
	mat.set_shader_parameter(&"top_y", box.end.y)
	mat.set_shader_parameter(&"bottom_y", box.position.y)
	curtains.set_surface_override_material(0, mat)
	var tw := curtains.create_tween()
	tw.tween_method(func(a: float) -> void: mat.set_shader_parameter(&"amp", a), 0.0, PEAK, seconds * 0.3) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(a: float) -> void: mat.set_shader_parameter(&"amp", a), PEAK, 0.0, seconds * 0.7) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		if is_instance_valid(curtains):
			curtains.set_surface_override_material(0, null))
	return tw
