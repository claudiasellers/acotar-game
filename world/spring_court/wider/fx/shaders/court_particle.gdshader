// Soft lit billboard particle (petals, leaves, seeds, ash, smoke, mist).
// Colour comes from the particle COLOR (ParticleProcessMaterial colour ramps).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap;

#include "res://world/spring_court/wider/fx/shaders/court_fx_common.gdshaderinc"

// 0 orb, 1 star, 2 petal, 3 flake, 4 flame, 5 smoke, 6 seed, 7 leaf
uniform int shape = 2;
uniform float emission_boost : hint_range(0.0, 8.0) = 0.25;
uniform float shade_floor : hint_range(0.0, 1.0) = 0.55;
uniform float edge_tint : hint_range(0.0, 1.0) = 0.25;
uniform float blight : hint_range(0.0, 1.0) = 0.0;
uniform float blight_affect : hint_range(0.0, 1.0) = 0.0;

varying float v_seed;

void vertex() {
	v_seed = court_hash12(vec2(float(INSTANCE_ID) * 0.137, 4.1));
	mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float ang = INSTANCE_CUSTOM.x;
	mat_world = mat_world * mat4(vec4(cos(ang), -sin(ang), 0.0, 0.0), vec4(sin(ang), cos(ang), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float m = court_shape_mask(shape, p, v_seed, TIME);
	vec3 col = COLOR.rgb;
	// Pale edges / deeper base read as a soft gradient on petals.
	col = mix(col, mix(col, vec3(1.0), 0.6), edge_tint * clamp(length(p), 0.0, 1.0));
	float b = clamp(blight * blight_affect, 0.0, 1.0);
	col = court_blight_mix(col, b) * mix(1.0, 0.5, b);
	ALBEDO = col * shade_floor + col * (1.0 - shade_floor) * 0.5;
	EMISSION = col * emission_boost + col * shade_floor * 0.35;
	ROUGHNESS = 0.8;
	SPECULAR = 0.1;
	ALPHA = clamp(m * COLOR.a, 0.0, 1.0);
}
