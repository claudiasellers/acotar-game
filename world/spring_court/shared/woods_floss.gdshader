// Spun sugar: the candyfloss tree's wisps (tools/woods/blender/
// special_trees.py lays them on the tree, tools/woods/gen_floss_wisp.py
// paints them). A wisp is a skein of fine threads on a card: the picture's
// alpha is their cover, its value their light and dark. The colour is the
// tuft's own (vertex COLOR, as the woods' other flora); the light threads go
// pale, as thin sugar does with the light through it, and the wisp's thin
// edge paler still. The normal is the tuft's, not the card's, so a tuft
// shades as one soft mass while its outline is threads. Wind flex is COLOR.a.
// Lit like the woods' flora (woods_foliage.gdshaderinc).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://world/shared/shaders/foliage_wind.gdshaderinc"

uniform sampler2D wisps : source_color, filter_linear_mipmap, repeat_disable;
// how far the light threads go toward white
uniform float pale : hint_range(0.0, 1.0) = 0.3;
// how much deeper the dark threads are
uniform float thread_depth : hint_range(0.0, 1.0) = 0.16;
uniform float translucency : hint_range(0.0, 1.0) = 0.4;
// sugar crystals catching the light
uniform float sparkle : hint_range(0.0, 1.0) = 0.6;
uniform vec4 sparkle_color : source_color = vec4(1.0, 0.95, 0.9, 1.0);

varying vec3 world_pos;

#define CANDY_ALBEDO_MIX_DEFAULT 1.0
#define CANDY_GAIN_DEFAULT 2.0
#define CANDY_BURLEY_DEFAULT 0.0
#define CANDY_WRAP_DEFAULT 0.6
#define CANDY_SHADE_DEFAULT vec4(0.7, 0.6, 0.84, 1.0)
#define CANDY_RIM_COLOR_DEFAULT vec4(1.0, 0.88, 0.84, 1.0)
#define CANDY_RIM_STRENGTH_DEFAULT 0.35
#define CANDY_NO_SPEC_LOBE
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

void vertex() {
	VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, COLOR.a * 1.6);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	vec4 t = texture(wisps, UV);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	// a card seen from behind keeps its tuft's normal
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	// the picture is read as colour (linear): back to its painted value
	float v = pow(dot(t.rgb, vec3(0.3, 0.59, 0.11)), 0.4545);
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec3 col = mix(base * (1.0 - thread_depth), mix(base, vec3(0.94, 0.9, 0.92), pale), smoothstep(0.5, 0.92, v));
	col = mix(col, vec3(0.94, 0.9, 0.92), (1.0 - smoothstep(0.45, 0.9, t.a)) * 0.12);
	ALBEDO = col;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	float s = sparkle * magic_amount;
	vec3 glint = vec3(0.0);
	if (s > 0.0) {
		vec3 cell = floor(world_pos * 14.0);
		float h = hash3(cell);
		float twinkle = step(0.994 - s * 0.01, h) * pow(0.5 + 0.5 * sin(TIME * 4.0 + h * 40.0), 4.0);
		glint = sparkle_color.rgb * twinkle * 2.5;
	}
	EMISSION = glint;
	BACKLIGHT = col * translucency;
}
