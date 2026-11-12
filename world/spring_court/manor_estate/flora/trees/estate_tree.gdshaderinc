// The estate tree shaders' shared body: estate_tree.gdshader (the leaf-clump
// cards and the willow's fronds: cut out, two-sided; it defines
// ESTATE_TREE_CARDS) and estate_tree_solid.gdshader (bark, the clouds' hearts,
// fruit: solid). They are two shaders because one that cuts out anywhere is
// drawn as a cut-out everywhere, and the solid parts are far cheaper as solids
// (finish plan E2: about 3 ms a frame in the orchard on the Mac).
#include "res://world/shared/shaders/foliage_wind.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform int part = 1;
uniform bool own_colour = false;
uniform bool hanging = false;
// bark and heart patterns: repeats per metre
uniform float pattern_scale = 0.3;
uniform vec4 shadow_col : source_color = vec4(0.30, 0.56, 0.44, 1.0);
uniform vec4 mid_col : source_color = vec4(0.50, 0.79, 0.56, 1.0);
uniform vec4 light_col : source_color = vec4(0.78, 0.95, 0.72, 1.0);
uniform vec4 bark_col : source_color = vec4(0.56, 0.42, 0.43, 1.0);
// the bark picture's mean painted value (its light and dark vary about bark_col)
uniform float bark_mean = 0.338;
uniform float bands : hint_range(2.0, 8.0) = 4.0;
uniform float model_height = 12.0;
// Per-tree shade: each tree a little lighter or darker, warmer or cooler than
// its neighbour, hashed from where it stands.
uniform float tree_value_spread : hint_range(0.0, 0.3) = 0.08;
uniform float tree_hue_spread : hint_range(0.0, 1.0) = 0.4;
uniform float snow_catch : hint_range(0.0, 1.0) = 0.8;
uniform vec4 snow_color : source_color = vec4(0.93, 0.95, 1.0, 1.0);

#define CANDY_ALBEDO_MIX_DEFAULT 1.0
#define CANDY_GAIN_DEFAULT 2.0
#define CANDY_BURLEY_DEFAULT 0.0
#define CANDY_WRAP_DEFAULT 0.5
#define CANDY_SHADE_DEFAULT vec4(0.62, 0.55, 0.78, 1.0)
#define CANDY_RIM_COLOR_DEFAULT vec4(1.0, 0.86, 0.72, 1.0)
#define CANDY_RIM_STRENGTH_DEFAULT 0.2
#define CANDY_NO_SPEC_LOBE
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

varying vec2 v_tree;
varying float v_height;
varying float v_up;
varying vec3 v_obj;
varying vec3 v_objn;
varying float v_world_up;

void vertex() {
	vec2 o = MODEL_MATRIX[3].xz;
	v_tree = vec2(fract(sin(dot(o, vec2(12.9898, 78.233))) * 43758.5453), fract(sin(dot(o, vec2(39.346, 11.135))) * 24634.6345));
	v_height = clamp(VERTEX.y / max(model_height, 0.01), 0.0, 1.0);
	// the cloud's own top and underside (the normal is the cloud's, not the card's)
	v_up = NORMAL.y;
	v_obj = VERTEX;
	v_objn = NORMAL;
	v_world_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	if (part != 0) {
		// UV.y runs from a frond's seat (0) to its tip (1)
		VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, hanging ? UV.y * 0.9 : smoothstep(0.25, 1.0, v_height));
	}
}

// The picture's painted value from three sides, blended by the facing (the
// texture is read as colour, linear: back to its painted value).
float pattern(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec4 a = texture(tex, p.zy * pattern_scale) * w.x + texture(tex, p.xz * pattern_scale) * w.y + texture(tex, p.xy * pattern_scale) * w.z;
	return pow(dot(a.rgb, vec3(0.3, 0.59, 0.11)), 0.4545);
}

void fragment() {
	vec3 col;
	if (part == 3) {
		col = COLOR.rgb;
	} else if (part == 0) {
		col = bark_col.rgb * mix(1.0, pattern(v_obj, v_objn) / bark_mean, 0.8);
		// the limbs darken up into the crown's shade
		col *= mix(1.0, 0.8, smoothstep(0.3, 0.6, v_height));
	} else {
		// A card seen from behind keeps its cloud's normal: the crown shades
		// as clouds whichever way a card faces.
		if (!FRONT_FACING) {
			NORMAL = -NORMAL;
		}
#ifdef ESTATE_TREE_CARDS
		if (part == 1) {
			vec4 t = texture(tex, UV);
			ALPHA = t.a;
			ALPHA_SCISSOR_THRESHOLD = 0.5;
			if (own_colour) {
				// lighter on a cloud's top and up the tree, deeper underneath
				col = t.rgb * mix(0.76, 1.08, clamp(0.45 + 0.4 * v_up + 0.25 * v_height, 0.0, 1.0));
			} else {
				float v = pow(dot(t.rgb, vec3(0.3, 0.59, 0.11)), 0.4545);
				float k = clamp(v * 1.5 * (0.56 + 0.26 * v_height + 0.42 * v_up), 0.0, 1.0);
				k = floor(k * bands + 0.5) / bands * 0.7 + k * 0.3;
				col = k < 0.5 ? mix(shadow_col.rgb, mid_col.rgb, k * 2.0) : mix(mid_col.rgb, light_col.rgb, (k - 0.5) * 2.0);
			}
			col *= COLOR.r;   // each cloud a touch lighter or deeper (the generator's tone)
		} else
#endif
		{
			col = mix(shadow_col.rgb * 0.9, mid_col.rgb, clamp(pattern(v_obj * 1.7, v_objn) * 2.2, 0.0, 1.0) * 0.65);
		}
		BACKLIGHT = col * 0.3;
		float warm = v_tree.y * 2.0 - 1.0;
		col *= mix(vec3(1.0), warm > 0.0 ? vec3(1.07, 1.03, 0.88) : vec3(0.93, 0.99, 1.07), tree_hue_spread * abs(warm));
	}
	col *= 1.0 + tree_value_spread * (v_tree.x * 2.0 - 1.0);
	float snow = smoothstep(0.35, 0.8, clamp(v_world_up, 0.0, 1.0)) * snow_cover * snow_catch;
	col = mix(col, snow_color.rgb, snow);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.55, snow);
	SPECULAR = 0.0;
}
