// Leaf clumps of the Border Woods trees (tools/woods/blender/vriksh_trees.py).
// One model serves every colourway: COLOR.r is the crown gradient (0 deep
// inside, 1 sunlit tip), COLOR.g a per-clump random, COLOR.b height / tree
// height (wind flex), COLOR.a 0 on the solid inner blobs. The mask's alpha cuts the leaf shapes out of the card
// and its red channel carries the painted detail (0.667 = neutral). Light is
// candy_lit with the toon bands and the plum shadow fill.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://world/shared/shaders/foliage_wind.gdshaderinc"

uniform sampler2D leaf_mask : filter_linear_mipmap, repeat_disable;
uniform bool use_mask = true;
uniform vec4 deep_color : source_color = vec4(0.24, 0.50, 0.45, 1.0);
uniform vec4 mid_color : source_color = vec4(0.44, 0.75, 0.60, 1.0);
uniform vec4 light_color : source_color = vec4(0.73, 0.91, 0.76, 1.0);
uniform vec4 accent_color : source_color = vec4(0.96, 0.65, 0.75, 1.0);
uniform float accent_amount : hint_range(0.0, 1.0) = 0.0;
uniform float detail : hint_range(0.0, 1.0) = 0.6;
uniform float translucency : hint_range(0.0, 1.0) = 0.3;
uniform float tree_value_spread : hint_range(0.0, 0.5) = 0.10;
// 0 = eternal spring; 1 = colour drained (dread, blight).
uniform float drain : hint_range(0.0, 1.0) = 0.0;

varying float v_tree;

#define CANDY_ALBEDO_MIX_DEFAULT 1.0
#define CANDY_GAIN_DEFAULT 2.0
#define CANDY_BURLEY_DEFAULT 0.0
#define CANDY_WRAP_DEFAULT 0.35
#define CANDY_SHADE_DEFAULT vec4(0.62, 0.50, 0.80, 1.0)
#define CANDY_RIM_COLOR_DEFAULT vec4(1.0, 0.86, 0.78, 1.0)
#define CANDY_RIM_STRENGTH_DEFAULT 0.3
#define CANDY_NO_SPEC_LOBE
#define CANDY_RIM_SCALE (1.0 - drain)
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

void vertex() {
	VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, COLOR.b * 1.4);
	vec3 o = MODEL_MATRIX[3].xyz;
	v_tree = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float painted = 1.0;
	if (use_mask && COLOR.a > 0.5) {
		vec4 m = texture(leaf_mask, UV);
		vec2 px = UV * vec2(textureSize(leaf_mask, 0));
		float lod = max(0.0, 0.5 * log2(max(dot(dFdx(px), dFdx(px)), dot(dFdy(px), dFdy(px)))));
		if (m.a * (1.0 + 0.35 * lod) < 0.5) {
			discard;
		}
		painted = mix(1.0, m.r * 1.5, detail);
	}
	float t = clamp(COLOR.r + (COLOR.g - 0.5) * 0.18, 0.0, 1.0);
	vec3 col = mix(deep_color.rgb, mid_color.rgb, smoothstep(0.0, 0.55, t));
	col = mix(col, light_color.rgb, smoothstep(0.5, 1.0, t));
	col = mix(col, accent_color.rgb, step(1.0 - accent_amount, COLOR.g));
	col *= painted * (1.0 + tree_value_spread * (v_tree * 2.0 - 1.0));
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))) * vec3(0.80, 0.80, 0.84), drain);
	ALBEDO = col;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	BACKLIGHT = col * translucency;
}
