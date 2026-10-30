// Additive glowing billboard particle (faelights, wisps, fireflies, sparkles,
// embers, flame, lantern motes). Bright enough to bloom.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://world/spring_court/wider/fx/shaders/court_fx_common.gdshaderinc"

// 0 orb, 1 star, 2 petal, 3 flake, 4 flame, 5 smoke, 6 seed, 7 leaf
uniform int shape = 0;
uniform float intensity : hint_range(0.0, 32.0) = 4.0;
uniform float core_whiten : hint_range(0.0, 1.0) = 0.5;
uniform float twinkle : hint_range(0.0, 1.0) = 0.0;
uniform float twinkle_speed = 6.0;

varying float v_seed;

void vertex() {
	v_seed = court_hash12(vec2(float(INSTANCE_ID) * 0.173, 2.7));
	mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float ang = INSTANCE_CUSTOM.x;
	mat_world = mat_world * mat4(vec4(cos(ang), -sin(ang), 0.0, 0.0), vec4(sin(ang), cos(ang), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float m = court_shape_mask(shape, p, v_seed, TIME);
	float tw = mix(1.0, pow(0.5 + 0.5 * sin(TIME * twinkle_speed * (0.6 + v_seed) + v_seed * 50.0), 3.0), twinkle);
	float core = exp(-dot(p, p) * 12.0);
	vec3 col = mix(COLOR.rgb, vec3(1.0), core * core_whiten);
	ALBEDO = col * m * COLOR.a * tw * intensity;
	ALPHA = clamp(m * COLOR.a, 0.0, 1.0);
}
