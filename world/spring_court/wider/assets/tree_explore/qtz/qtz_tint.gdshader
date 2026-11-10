// Tree exploration preview: a Quaternius tree tinted into the court's palette.
// Leaves: the target green times the model's baked vertex shading (COLOR),
// the leaf texture used only for its cut-out. Bark: a taupe brown carrying
// the bark texture's light and dark. Preview only.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform bool is_leaf = true;
uniform vec4 leaf_col : source_color = vec4(0.42, 0.62, 0.30, 1.0);
uniform vec4 leaf_light : source_color = vec4(0.62, 0.76, 0.40, 1.0);
uniform vec4 bark_col : source_color = vec4(0.46, 0.37, 0.36, 1.0);
uniform float bark_mean = 0.42;

varying float v_tree;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	v_tree = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 t = texture(tex, UV);
	if (is_leaf) {
		if (t.a < 0.2) {
			discard;
		}
		float shade = dot(COLOR.rgb, vec3(0.333));
		ALBEDO = mix(leaf_col.rgb, leaf_light.rgb, smoothstep(0.55, 1.0, shade)) * (0.55 + 0.45 * shade);
	} else {
		float v = dot(t.rgb, vec3(0.3, 0.59, 0.11)) / bark_mean;
		ALBEDO = bark_col.rgb * v * (0.6 + 0.4 * dot(COLOR.rgb, vec3(0.333)));
	}
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = is_leaf ? ALBEDO * 0.25 : vec3(0.0);
}
