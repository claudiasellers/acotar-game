// The faelight wind's glints: soft dots in the particle colour, billboarded,
// alpha-mixed so they read against snow (added light vanishes there). Black
// is dropped: the compatibility renderer draws a not-yet-born CPU particle
// as an opaque black quad at the emitter.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D dot : source_color, filter_linear, repeat_disable;

void vertex() {
	mat4 face = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]),
			normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * face * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	if (COLOR.r + COLOR.g + COLOR.b < 0.05) {
		discard;
	}
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * texture(dot, UV).a;
}
