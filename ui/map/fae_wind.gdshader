// The guiding wind's petals: blossom petals lit by the scene like anything
// else in the world (no glow of their own), billboarded and turning as they
// tumble (the particle's angle), alpha from a petal-shaped mask. Black is
// dropped: the compatibility renderer draws a not-yet-born CPU particle as an
// opaque black quad at the emitter.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D petal : source_color, filter_linear, repeat_disable;

void vertex() {
	mat4 face = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]),
			normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float a = INSTANCE_CUSTOM.x;
	mat4 spin = mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0),
			vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * face * spin * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	if (COLOR.r + COLOR.g + COLOR.b < 0.05) {
		discard;
	}
	vec4 m = texture(petal, UV);
	// A little vein of shade down the middle, so it reads as a petal.
	ALBEDO = COLOR.rgb * mix(0.82, 1.0, m.r);
	ALPHA = COLOR.a * m.a;
	ROUGHNESS = 0.8;
}
