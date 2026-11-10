// Tree exploration preview (owner, 2026-11-10: "should we maybe use some of
// the assets"): EZ-Tree's leaf sprays (tools: tools/court/eztree/), drawn two
// ways. painted = 0: the photo leaves as they come. painted = 1: the same
// leaf shapes repainted into spring greens in soft value bands (light from
// the photo's own value), so they can sit on the storybook ground.
// Preview only: nothing in the game uses it.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float painted : hint_range(0.0, 1.0) = 1.0;
uniform vec4 shadow_col : source_color = vec4(0.16, 0.30, 0.20, 1.0);
uniform vec4 mid_col : source_color = vec4(0.36, 0.55, 0.28, 1.0);
uniform vec4 light_col : source_color = vec4(0.66, 0.78, 0.42, 1.0);
uniform float bands : hint_range(2.0, 8.0) = 4.0;
uniform float translucency : hint_range(0.0, 1.0) = 0.3;

varying float v_tree;
varying float v_height;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	v_tree = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453);
	// How high up the tree (0 at the foot), for darker lower leaves.
	v_height = clamp(VERTEX.y / 70.0, 0.0, 1.0);
}

void fragment() {
	vec4 t = texture(leaf_tex, UV);
	if (t.a < 0.5) {
		discard;
	}
	vec3 photo = t.rgb;
	float v = dot(t.rgb, vec3(0.3, 0.59, 0.11));
	float k = clamp(v * 1.6 * (0.75 + 0.45 * v_height), 0.0, 1.0);
	k = floor(k * bands + 0.5) / bands * 0.7 + k * 0.3;  // soft painted bands
	vec3 paint = k < 0.5 ? mix(shadow_col.rgb, mid_col.rgb, k * 2.0) : mix(mid_col.rgb, light_col.rgb, (k - 0.5) * 2.0);
	vec3 col = mix(photo, paint, painted);
	col *= 0.92 + 0.16 * v_tree;
	ALBEDO = col;
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	BACKLIGHT = col * translucency;
}
