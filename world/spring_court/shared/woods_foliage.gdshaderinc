// The woods' flora material body, shared by woods_foliage.gdshader and the
// fog-free hero variant (render_mode can't be a uniform).
#include "res://world/shared/shaders/foliage_wind.gdshaderinc"


uniform float translucency : hint_range(0.0, 1.0) = 0.4;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.7;
uniform float sparkle : hint_range(0.0, 1.0) = 0.0;
uniform vec4 sparkle_color : source_color = vec4(1.0, 0.92, 0.80, 1.0);
uniform float glow_energy : hint_range(0.0, 6.0) = 2.5;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
// 0 = eternal spring; 1 = colour drained (dread margin, blight).
uniform float drain : hint_range(0.0, 1.0) = 0.0;
// No lime (experience-bar §2.2): green-dominant albedo loses this much
// chroma and leans teal, so sunlight and the spring grade's saturation
// boost can't push it into #00FF00-#7FFF00.
uniform float lime_guard : hint_range(0.0, 1.0) = 0.6;

varying vec3 world_pos;
varying float v_glow;

// Lighting: candy_lit (render program T2) with this family's old response as
// its defaults: wrapped lambert x2 on albedo, shade tint, no direct specular.
#define CANDY_ALBEDO_MIX_DEFAULT 1.0
#define CANDY_GAIN_DEFAULT 2.0
#define CANDY_BURLEY_DEFAULT 0.0
#define CANDY_WRAP_DEFAULT 0.55
#define CANDY_SHADE_DEFAULT vec4(0.66, 0.56, 0.82, 1.0)
#define CANDY_RIM_COLOR_DEFAULT vec4(1.0, 0.84, 0.76, 1.0)
#define CANDY_RIM_STRENGTH_DEFAULT 0.55
#define CANDY_NO_SPEC_LOBE
#define CANDY_RIM_SCALE (1.0 - drain)
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

void vertex() {
	VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, UV.x * 1.6);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_glow = UV.y;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	float grey = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(vec3(grey), col, saturation);
	col = mix(col, vec3(grey) * vec3(0.80, 0.80, 0.84), drain);
	float greenness = clamp((col.g - max(col.r, col.b)) / max(col.g, 0.001), 0.0, 1.0) * lime_guard;
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))), greenness);
	col.b += greenness * col.g * 0.35;
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.35;
	vec3 glint = vec3(0.0);
	float s = (sparkle + v_glow * 0.6) * magic_amount * (1.0 - drain);
	if (s > 0.0) {
		vec3 cell = floor(world_pos * 7.0);
		float h = hash3(cell);
		float twinkle = step(0.996 - s * 0.012, h) * pow(0.5 + 0.5 * sin(TIME * 4.0 + h * 40.0), 4.0);
		glint = sparkle_color.rgb * twinkle * 3.0;
	}
	EMISSION = glint + col * v_glow * glow_energy;
	BACKLIGHT = col * translucency;
}
