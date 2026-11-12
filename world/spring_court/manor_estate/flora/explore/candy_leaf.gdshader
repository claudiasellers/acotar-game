// Exploration (owner, 2026-11-11: the smooth puff oak was "not detailed ...
// just look at the other ones"): the leafy cotton-candy tree of candy_leafy.py,
// lit like the rest of the estate's flora (candy_lit with stylized_foliage's
// response: wrapped light, lilac shade, a warm rim).
//   part 0 bark:   the court's painted bark (light and dark) in bark_col
//   part 1 leaves: a leaf-clump card; its painted value banded shadow -> mid
//                  -> light (court_tree.gdshader mode 2). The normal is the
//                  puff's, not the card's, so the crown shades as soft clouds
//                  while the outline and surface are leaves.
//   part 2 core:   the ball inside each puff: the crown's shaded heart
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://world/shared/shaders/foliage_wind.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform int part = 1;
uniform vec4 shadow_col : source_color = vec4(0.30, 0.56, 0.44, 1.0);
uniform vec4 mid_col : source_color = vec4(0.50, 0.79, 0.56, 1.0);
uniform vec4 light_col : source_color = vec4(0.78, 0.95, 0.72, 1.0);
uniform vec4 bark_col : source_color = vec4(0.56, 0.42, 0.43, 1.0);
uniform float bark_mean = 0.338;
uniform float bands : hint_range(2.0, 8.0) = 4.0;
uniform float model_height = 12.0;
uniform float tree_value_spread : hint_range(0.0, 0.3) = 0.08;

#define CANDY_ALBEDO_MIX_DEFAULT 1.0
#define CANDY_GAIN_DEFAULT 2.0
#define CANDY_BURLEY_DEFAULT 0.0
#define CANDY_WRAP_DEFAULT 0.5
#define CANDY_SHADE_DEFAULT vec4(0.62, 0.55, 0.78, 1.0)
#define CANDY_RIM_COLOR_DEFAULT vec4(1.0, 0.86, 0.72, 1.0)
#define CANDY_RIM_STRENGTH_DEFAULT 0.6
#define CANDY_NO_SPEC_LOBE
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

varying float v_tree;
varying float v_height;
varying float v_up;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	v_tree = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453);
	v_height = clamp(VERTEX.y / max(model_height, 0.01), 0.0, 1.0);
	// the puff's own top and underside (the normal is the puff's, not the card's)
	v_up = NORMAL.y;
	if (part != 0) {
		VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, smoothstep(0.25, 1.0, v_height));
	}
}

void fragment() {
	vec3 col;
	if (part == 0) {
		col = bark_col.rgb * mix(1.0, dot(texture(tex, UV).rgb, vec3(0.3, 0.59, 0.11)) / bark_mean, 0.75);
	} else {
		// A card seen from behind keeps its puff's normal: the crown shades
		// as clouds whichever way a card faces.
		if (!FRONT_FACING) {
			NORMAL = -NORMAL;
		}
		if (part == 2) {
			col = shadow_col.rgb * 0.8;
		} else {
			vec4 t = texture(tex, UV);
			ALPHA = t.a;
			ALPHA_SCISSOR_THRESHOLD = 0.5;
			float v = dot(t.rgb, vec3(0.3, 0.59, 0.11));
			// lighter on a puff's top and up the tree, deeper underneath
			float k = clamp(v * 1.6 * (0.56 + 0.26 * v_height + 0.42 * v_up), 0.0, 1.0);
			k = floor(k * bands + 0.5) / bands * 0.7 + k * 0.3;
			col = k < 0.5 ? mix(shadow_col.rgb, mid_col.rgb, k * 2.0) : mix(mid_col.rgb, light_col.rgb, (k - 0.5) * 2.0);
		}
		BACKLIGHT = col * 0.3;
	}
	col *= 1.0 + tree_value_spread * (v_tree * 2.0 - 1.0);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.0;
}
