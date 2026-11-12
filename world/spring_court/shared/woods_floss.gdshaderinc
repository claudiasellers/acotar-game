// The candyfloss shaders' body: woods_floss.gdshader (the billows, solid) and
// woods_floss_fuzz.gdshader (the fuzz skin, cut out; it defines FLOSS_FUZZ).
// Two shaders because one that writes ALPHA anywhere is drawn as a cut-out
// everywhere, and a cut-out is the dear kind of surface.

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
uniform float mottle : hint_range(0.0, 1.0) = 0.22;
// the share of trees whose tufts are each their own colour
uniform float multi_share : hint_range(0.0, 1.0) = 0.4;
// the fuzz is this much paler than the billow under it
uniform float fuzz_pale : hint_range(0.0, 1.0) = 0.06;
// the fuzz thins out between these distances (m) and is not drawn past the
// second: by then it is finer than a pixel, and it is the dear part to draw
uniform float fuzz_fade_begin = 40.0;
uniform float fuzz_fade_end = 70.0;
uniform float translucency : hint_range(0.0, 1.0) = 0.3;
// sugar crystals catching the light
uniform float sparkle : hint_range(0.0, 1.0) = 0.5;
uniform vec4 sparkle_color : source_color = vec4(1.0, 0.95, 0.9, 1.0);

varying vec3 world_pos;
varying vec3 v_obj;
varying vec3 v_objn;
varying float v_thin;
varying float v_pick;
varying float v_multi;

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
	v_multi = step(fract(sin(dot(o, vec2(39.346, 11.135))) * 24634.6345), multi_share);
	v_obj = VERTEX;
	v_objn = NORMAL;
	VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, UV.x * 1.6);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_thin = 0.0;
#ifdef FLOSS_FUZZ
	// (the main camera's place, so the shadow passes agree with the picture)
	float away = distance(MODEL_MATRIX[3].xyz, MAIN_CAM_INV_VIEW_MATRIX[3].xyz);
	v_thin = smoothstep(fuzz_fade_begin, fuzz_fade_end, away);
	// Past the fade, and in the shadow passes (the billows under it cast the
	// shadow), the fuzz folds to a point: no triangle, nothing to cut out.
	if (IN_SHADOW_PASS || away >= fuzz_fade_end) {
		VERTEX = vec3(0.0);
	}
#endif
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
#ifdef FLOSS_FUZZ
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = mix(0.5, 1.01, v_thin);
#endif
	vec3 top = top_0.rgb;
	vec3 deep = deep_0.rgb;
	// a tree of many colours: each tuft its own, turned by the tree's pick so no two trees match
	float pick = v_multi > 0.5 ? fract(COLOR.g + floor(v_pick * 4.0) * 0.25) : v_pick;
	if (pick > 0.75) {
		top = top_3.rgb;
		deep = deep_3.rgb;
	} else if (pick > 0.5) {
		top = top_2.rgb;
		deep = deep_2.rgb;
	} else if (pick > 0.25) {
		top = top_1.rgb;
		deep = deep_1.rgb;
	}
	float tone = clamp(COLOR.r * (1.0 - mottle * 0.6 + mottle * value), 0.0, 1.0);
	// (the light is generous: the pale colour is held back so the floss keeps its pink)
	vec3 col = mix(deep, top, tone * colour_lift);
#ifdef FLOSS_FUZZ
	col = mix(col, mix(top, vec3(1.0), 0.4), fuzz_pale);
#endif
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
