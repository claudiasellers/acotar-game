// The court trees' leaf cards (tools/court/blender/court_trees.py; owner's
// pick 2026-11-10). A card's leaves come from the painted leaf atlas
// (models/cards/leaf_atlas.png, tools/court/gen_leaf_atlas.py) through UV2;
// the rest of the card is cut away (alpha test). Albedo is the card's painted
// vertex COLOR (sRGB) times the atlas; UV.x is wind flex; light is the woods'
// candy_lit response. The cards carry the crown's outward normal, so the
// crown lights as one soft mass with a leafy edge. Each tree gets its own
// small shift in value and warmth from where it stands, so two builds of a
// species side by side never match.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://world/shared/shaders/foliage_wind.gdshaderinc"

uniform sampler2D leaf_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float translucency : hint_range(0.0, 1.0) = 0.3;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.75;
// No lime (experience bar §2.2), gentler than the woods' 0.6: these greens
// are painted deep on purpose.
uniform float lime_guard : hint_range(0.0, 1.0) = 0.25;
// Per-tree variety: value and warmth spread across trees.
uniform float tree_value_spread : hint_range(0.0, 0.5) = 0.12;
uniform float tree_warmth_spread : hint_range(0.0, 0.3) = 0.06;
// 0 = eternal spring; 1 = colour drained (dread, blight), as woods_foliage.
uniform float drain : hint_range(0.0, 1.0) = 0.0;

varying float v_tree;

#define CANDY_ALBEDO_MIX_DEFAULT 1.0
#define CANDY_GAIN_DEFAULT 2.0
#define CANDY_BURLEY_DEFAULT 0.0
#define CANDY_WRAP_DEFAULT 0.55
#define CANDY_SHADE_DEFAULT vec4(0.66, 0.56, 0.82, 1.0)
#define CANDY_RIM_COLOR_DEFAULT vec4(1.0, 0.84, 0.76, 1.0)
#define CANDY_RIM_STRENGTH_DEFAULT 0.12
#define CANDY_NO_SPEC_LOBE
#define CANDY_RIM_SCALE (1.0 - drain)
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

void vertex() {
	VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, UV.x * 1.6);
	vec3 o = MODEL_MATRIX[3].xyz;
	v_tree = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 leaf = texture(leaf_atlas, UV2);
	// Alpha-tested leaves thin out in the small mipmaps; lift the coverage
	// with the mip level so far crowns stay full.
	vec2 px = UV2 * vec2(textureSize(leaf_atlas, 0));
	float lod = max(0.0, 0.5 * log2(max(dot(dFdx(px), dFdx(px)), dot(dFdy(px), dFdy(px)))));
	float a = leaf.a * (1.0 + 0.35 * lod);
	if (a < 0.5) {
		discard;
	}
	vec3 col = pow(COLOR.rgb, vec3(2.2)) * leaf.rgb;
	float grey = dot(col, vec3(0.3, 0.59, 0.11));
	float greenness = clamp((col.g - max(col.r, col.b)) / max(col.g, 0.001), 0.0, 1.0) * lime_guard;
	col = mix(col, vec3(grey), greenness);
	float t = v_tree * 2.0 - 1.0;
	float w = fract(v_tree * 7.13) * 2.0 - 1.0;
	col *= 1.0 + tree_value_spread * t;
	col.r *= 1.0 + tree_warmth_spread * w;
	col.b *= 1.0 - tree_warmth_spread * w;
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))) * vec3(0.80, 0.80, 0.84), drain);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.3;
	BACKLIGHT = col * translucency;
}
