// Billboarded sparkle so collectibles read on the ground. Use on a small QuadMesh.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://world/spring_court/wider/fx/shaders/court_fx_common.gdshaderinc"

uniform vec4 glint_color : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform vec4 glint_core : source_color = vec4(1.0, 0.95, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 16.0) = 4.0;
uniform float pulse_speed = 2.2;
uniform float spin_speed = 0.6;
uniform float bob_height = 0.06;
uniform float blight : hint_range(0.0, 1.0) = 0.0;

varying float v_phase;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_phase = court_hash12(floor(origin.xz * 7.0)) * 6.2831;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	float a = TIME * spin_speed + v_phase;
	vec2 rv = vec2(VERTEX.x * cos(a) - VERTEX.y * sin(a), VERTEX.x * sin(a) + VERTEX.y * cos(a));
	vec3 world = origin + vec3(0.0, sin(TIME * 1.7 + v_phase) * bob_height, 0.0);
	world += INV_VIEW_MATRIX[0].xyz * rv.x * sx + INV_VIEW_MATRIX[1].xyz * rv.y * sy;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float pulse = 0.65 + 0.35 * sin(TIME * pulse_speed + v_phase);
	float star = court_star_mask(p * (1.1 - 0.2 * pulse));
	float core = exp(-dot(p, p) * 40.0);
	vec3 col = mix(glint_color.rgb, glint_core.rgb, core);
	col = court_blight_mix(col, blight) * (1.0 - blight * 0.7);
	ALBEDO = col * star * intensity * pulse;
	ALPHA = clamp(star, 0.0, 1.0);
}
