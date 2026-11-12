// Candyfloss: the candyfloss tree's crown (tools/woods/blender/
// special_trees.py builds it, tools/woods/gen_floss_cotton.py paints its
// cotton). The crown is a heap of soft billows with a second skin standing a
// little off them: the fuzz. The cotton picture is laid on from three sides
// (no seams): its value mottles the fluff, its alpha cuts the fuzz into small
// tufts, so every billow has a soft broken edge instead of an outline.
//
// The mesh carries no colour of its own: COLOR.r is a tone (deep in the
// creases between billows, light on their tops) and each tree takes one pair
// of colours, pale over deep, picked from where it stands. A grove is a mix
// of pink, rose, lilac and pearl trees from one model. UV.x is the wind
// flex, UV.y marks the fuzz. Lit like the woods' flora.
shader_type spatial;
render_mode depth_draw_opaque;

#include "res://world/shared/shaders/foliage_wind.gdshaderinc"

uniform sampler2D cotton : source_color, filter_linear_mipmap, repeat_enable;
// repeats of the cotton picture per metre
uniform float cotton_scale = 0.45;
// The trees' colours, pale then deep (the first candyfloss tree's).
uniform vec4 top_0 : source_color = vec4(0.980, 0.831, 0.863, 1.0);
uniform vec4 deep_0 : source_color = vec4(0.933, 0.498, 0.659, 1.0);
uniform vec4 top_1 : source_color = vec4(0.969, 0.702, 0.796, 1.0);
uniform vec4 deep_1 : source_color = vec4(0.886, 0.353, 0.541, 1.0);
uniform vec4 top_2 : source_color = vec4(0.914, 0.839, 0.969, 1.0);
uniform vec4 deep_2 : source_color = vec4(0.655, 0.498, 0.859, 1.0);
uniform vec4 top_3 : source_color = vec4(0.984, 0.929, 0.918, 1.0);
uniform vec4 deep_3 : source_color = vec4(0.941, 0.553, 0.698, 1.0);
// how far up from the deep colour to the pale one the lightest fluff goes
uniform float colour_lift : hint_range(0.0, 1.0) = 0.72;
// how much the cotton's light and dark shows in the fluff
uniform float mottle : hint_range(0.0, 1.0) = 0.35;
// the fuzz is this much paler than the billow under it
uniform float fuzz_pale : hint_range(0.0, 1.0) = 0.1;
uniform float translucency : hint_range(0.0, 1.0) = 0.3;
// sugar crystals catching the light
uniform float sparkle : hint_range(0.0, 1.0) = 0.5;
uniform vec4 sparkle_color : source_color = vec4(1.0, 0.95, 0.9, 1.0);

varying vec3 world_pos;
varying vec3 v_obj;
varying vec3 v_objn;
varying float v_fuzz;
varying float v_pick;

#define CANDY_ALBEDO_MIX_DEFAULT 1.0
#define CANDY_GAIN_DEFAULT 2.0
#define CANDY_BURLEY_DEFAULT 0.0
#define CANDY_WRAP_DEFAULT 0.7
#define CANDY_SHADE_DEFAULT vec4(0.74, 0.64, 0.86, 1.0)
#define CANDY_RIM_COLOR_DEFAULT vec4(1.0, 0.9, 0.88, 1.0)
#define CANDY_RIM_STRENGTH_DEFAULT 0.25
#define CANDY_NO_SPEC_LOBE
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

void vertex() {
	vec2 o = MODEL_MATRIX[3].xz;
	v_pick = fract(sin(dot(o, vec2(12.9898, 78.233))) * 43758.5453);
	v_obj = VERTEX;
	v_objn = NORMAL;
	v_fuzz = UV.y;
	VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, UV.x * 1.6);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	// the cotton from three sides, blended by the facing
	vec3 w = pow(abs(v_objn), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 p = v_obj * cotton_scale;
	vec4 c = texture(cotton, p.zy) * w.x + texture(cotton, p.xz) * w.y + texture(cotton, p.xy) * w.z;
	// (read as colour, linear: back to its painted value)
	float value = pow(dot(c.rgb, vec3(0.3, 0.59, 0.11)), 0.4545);
	bool fuzz = v_fuzz > 0.5;
	if (fuzz) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}
	vec3 top = top_0.rgb;
	vec3 deep = deep_0.rgb;
	if (v_pick > 0.75) {
		top = top_3.rgb;
		deep = deep_3.rgb;
	} else if (v_pick > 0.5) {
		top = top_2.rgb;
		deep = deep_2.rgb;
	} else if (v_pick > 0.25) {
		top = top_1.rgb;
		deep = deep_1.rgb;
	}
	float tone = clamp(COLOR.r * (1.0 - mottle * 0.6 + mottle * value), 0.0, 1.0);
	// (the light is generous: the pale colour is held back so the floss keeps its pink)
	vec3 col = mix(deep, top, tone * colour_lift);
	if (fuzz) {
		col = mix(col, mix(top, vec3(1.0), 0.4), fuzz_pale);
	}
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
	float s = sparkle * magic_amount;
	vec3 glint = vec3(0.0);
	if (s > 0.0) {
		float h = hash3(floor(world_pos * 14.0));
		float twinkle = step(0.994 - s * 0.01, h) * pow(0.5 + 0.5 * sin(TIME * 4.0 + h * 40.0), 4.0);
		glint = sparkle_color.rgb * twinkle * 2.5;
	}
	EMISSION = glint;
	BACKLIGHT = col * translucency;
}
