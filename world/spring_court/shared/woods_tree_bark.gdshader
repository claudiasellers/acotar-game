// Trunks and limbs of the Border Woods trees: one bark colour, darker at the
// foot (COLOR.b is height / tree height), with soft painted streaks along the
// grain. candy_lit with the toon bands and the plum shadow fill.
shader_type spatial;

#include "res://world/shared/shaders/foliage_wind.gdshaderinc"

uniform vec4 bark_color : source_color = vec4(0.56, 0.42, 0.43, 1.0);
uniform vec4 foot_color : source_color = vec4(0.36, 0.25, 0.32, 1.0);
uniform float streaks : hint_range(0.0, 1.0) = 0.25;
uniform float drain : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_local;

#define CANDY_ALBEDO_MIX_DEFAULT 1.0
#define CANDY_GAIN_DEFAULT 2.0
#define CANDY_BURLEY_DEFAULT 0.0
#define CANDY_WRAP_DEFAULT 0.25
#define CANDY_SHADE_DEFAULT vec4(0.62, 0.50, 0.80, 1.0)
#define CANDY_RIM_COLOR_DEFAULT vec4(1.0, 0.86, 0.78, 1.0)
#define CANDY_RIM_STRENGTH_DEFAULT 0.35
#define CANDY_NO_SPEC_LOBE
#define CANDY_RIM_SCALE (1.0 - drain)
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

void vertex() {
	v_local = VERTEX;
	VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, COLOR.b * COLOR.b * 0.8);
}

void fragment() {
	vec3 col = mix(foot_color.rgb, bark_color.rgb, smoothstep(0.0, 0.5, COLOR.b) * 0.6 + 0.4);
	float a = atan(v_local.x, v_local.z);
	float grain = sin(a * 9.0 + v_local.y * 1.3 + sin(v_local.y * 4.0) * 0.8);
	col *= 1.0 - streaks * smoothstep(0.2, 0.9, grain) * 0.45;
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))) * vec3(0.80, 0.80, 0.84), drain);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
