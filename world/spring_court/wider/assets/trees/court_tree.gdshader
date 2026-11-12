// The court's trees (finish plan T4/T6; owner's mixed wood, wcterrain-28):
// Quaternius and EZ-Tree models in one palette, each pack keeping its own
// look (owner: "don't change it, that's how nature is"). The maths of each
// mode is the approved preview's, unchanged (qtz_tint.gdshader, ez_leaf.gdshader
// in tree_explore/); what this adds is wind, a small per-tree shade, the
// drained blight and the far crown.
//   mode 0 bark: the bark texture's light and dark (value / bark_mean) times
//          bark_col, shaded by the model's baked vertex colour.
//   mode 1 Quaternius leaves: leaf_col to leaf_light by the baked vertex
//          shade; the texture is only the cut-out.
//   mode 2 EZ-Tree leaves: the painted spray's value in soft bands from
//          shadow_col through mid_col to light_col.
//   mode 3 blossom spray: the painted spray's own colours (gen_ez_blossoms.py).
//   mode 4 far crown: leaf_col lit by its normal, no texture (the far step);
//          its trunk (vertex alpha 0) is bark_col.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://world/shared/shaders/foliage_wind.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform int mode = 1;
uniform vec4 leaf_col : source_color = vec4(0.27, 0.48, 0.30, 1.0);
uniform vec4 leaf_light : source_color = vec4(0.46, 0.64, 0.38, 1.0);
uniform vec4 bark_col : source_color = vec4(0.50, 0.42, 0.36, 1.0);
uniform float bark_mean = 0.42;
uniform vec4 shadow_col : source_color = vec4(0.17, 0.32, 0.21, 1.0);
uniform vec4 mid_col : source_color = vec4(0.27, 0.48, 0.30, 1.0);
uniform vec4 light_col : source_color = vec4(0.46, 0.64, 0.38, 1.0);
uniform float bands : hint_range(2.0, 8.0) = 4.0;
// The model's height in its own units, for the painted leaves' height shading
// and the wind's flex (set per build by CourtTreeSet).
uniform float model_height = 12.0;
// Per-tree value spread (a tree a little lighter or darker than its neighbour).
uniform float tree_value_spread : hint_range(0.0, 0.3) = 0.08;
// 0 = eternal spring; 1 = colour drained (the Blight), as woods_foliage.
uniform float drain : hint_range(0.0, 1.0) = 0.0;

varying float v_tree;
varying float v_height;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	v_tree = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453);
	v_height = clamp(VERTEX.y / max(model_height, 0.01), 0.0, 1.0);
	if (mode != 0) {
		VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, smoothstep(0.25, 1.0, v_height));
	}
}

void fragment() {
	vec4 t = texture(tex, UV);
	vec3 col;
	// Cut-outs go through the alpha scissor (opaque pass, depth prepass), not
	// discard (T7: the leaves' overdraw was the dense wood's cost).
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (mode == 0) {
		float v = dot(t.rgb, vec3(0.3, 0.59, 0.11)) / bark_mean;
		col = bark_col.rgb * v * (0.6 + 0.4 * dot(COLOR.rgb, vec3(0.333)));
	} else if (mode == 1) {
		ALPHA = t.a;
		ALPHA_SCISSOR_THRESHOLD = 0.2;
		float shade = dot(COLOR.rgb, vec3(0.333));
		col = mix(leaf_col.rgb, leaf_light.rgb, smoothstep(0.55, 1.0, shade)) * (0.55 + 0.45 * shade);
	} else if (mode == 2) {
		ALPHA = t.a;
		float v = dot(t.rgb, vec3(0.3, 0.59, 0.11));
		float k = clamp(v * 1.6 * (0.75 + 0.45 * v_height), 0.0, 1.0);
		k = floor(k * bands + 0.5) / bands * 0.7 + k * 0.3;
		col = k < 0.5 ? mix(shadow_col.rgb, mid_col.rgb, k * 2.0) : mix(mid_col.rgb, light_col.rgb, (k - 0.5) * 2.0);
		col *= 0.92 + 0.16 * v_tree;
	} else if (mode == 3) {
		ALPHA = t.a;
		col = t.rgb * (0.92 + 0.16 * v_tree);
	} else if (COLOR.a < 0.5) {
		col = bark_col.rgb * 0.8;
	} else {
		col = mix(leaf_col.rgb, leaf_light.rgb, 0.55);
	}
	if (mode != 2 && mode != 3) {
		col *= 1.0 + tree_value_spread * (v_tree * 2.0 - 1.0);
	}
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))) * vec3(0.80, 0.80, 0.84), drain);
	ALBEDO = col;
	ROUGHNESS = mode == 0 ? 0.85 : 0.8;
	SPECULAR = 0.25;
	BACKLIGHT = mode == 0 ? vec3(0.0) : col * (mode == 1 ? 0.25 : 0.3);
}
