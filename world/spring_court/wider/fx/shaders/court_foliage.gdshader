// Spring Court foliage for the wider-court plant models.
// Based on world/shared/shaders/stylized_foliage.gdshader (same wrap lighting, shade
// tint, rim, translucency, sparkle * magic_amount, shared GPU wind) but for our assets:
//   albedo = COLOR.rgb (vertex colour is the real colour)
//   glow   = COLOR.a * emission_glow (alpha 1 marks glowing parts)
//   wind flex = clamp(VERTEX.y / sway_height, 0, 1)^2, times the instance uniform
//   wind_amount (set per ScatterField layer), NOT COLOR.r.
// Plus a per-material `blight` mix (written by CourtBlightDriver) and a per-instance
// flutter phase so MultiMesh instances never move in lockstep.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://world/shared/shaders/foliage_wind.gdshaderinc"
#include "res://world/spring_court/wider/fx/shaders/court_fx_common.gdshaderinc"


uniform vec4 albedo : source_color = vec4(1.0);
uniform bool vertex_color_srgb = false;
uniform float saturation_boost : hint_range(0.0, 2.0) = 1.15;
uniform float sway_height = 1.5;
uniform float flutter_amount = 0.02;
uniform float translucency : hint_range(0.0, 1.0) = 0.4;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.75;
uniform float snow_catch : hint_range(0.0, 1.0) = 0.8;
uniform vec4 snow_color : source_color = vec4(0.93, 0.95, 1.0, 1.0);
uniform float sparkle : hint_range(0.0, 1.0) = 0.0;
uniform vec4 sparkle_color : source_color = vec4(1.0, 0.93, 0.75, 1.0);
uniform float emission_glow : hint_range(0.0, 8.0) = 2.0;
uniform float blight : hint_range(0.0, 1.0) = 0.0;
uniform float blight_affect : hint_range(0.0, 1.0) = 1.0;

varying vec4 v_color;
varying vec3 world_normal;
varying vec3 world_pos;
varying float v_blight;

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

// Lighting: candy_lit (render program T2) with this family's old response as
// its defaults: wrapped lambert x2, shade tint, sun-behind petal glow, no specular.
#define CANDY_ALBEDO_MIX_DEFAULT 1.0
#define CANDY_GAIN_DEFAULT 2.0
#define CANDY_BURLEY_DEFAULT 0.0
#define CANDY_WRAP_DEFAULT 0.5
#define CANDY_SHADE_DEFAULT vec4(0.62, 0.55, 0.78, 1.0)
#define CANDY_RIM_COLOR_DEFAULT vec4(1.0, 0.86, 0.72, 1.0)
#define CANDY_RIM_STRENGTH_DEFAULT 0.6
#define CANDY_BACKLIGHT_DEFAULT 0.8
#define CANDY_NO_SPEC_LOBE
#define CANDY_BACKLIGHT_SCALE (1.0 - v_blight)
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

void vertex() {
	vec4 c = COLOR;
	if (vertex_color_srgb) {
		c.rgb = to_linear(c.rgb);
	}
	v_color = c;
	float h = clamp(VERTEX.y / max(sway_height, 0.001), 0.0, 1.0);
	float flex = h * h;
	VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, flex);
	// Per-instance leaf flutter (phase from INSTANCE_ID and world origin).
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = court_hash12(floor(origin.xz * 3.0)) * 6.2831 + float(INSTANCE_ID) * 3.8832;
	float flutter = sin(TIME * 6.5 + phase + VERTEX.x * 6.0 + VERTEX.z * 5.0);
	VERTEX.y += flutter * flutter_amount * flex * wind_strength * wind_amount;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_blight = clamp(blight * blight_affect, 0.0, 1.0);
}

void fragment() {
	vec3 col = v_color.rgb * albedo.rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = max(mix(vec3(lum), col, saturation_boost), vec3(0.0));
	float up = clamp(world_normal.y, 0.0, 1.0);
	float snow = smoothstep(0.35, 0.8, up) * snow_cover * snow_catch;
	col = mix(col, snow_color.rgb, snow);
	col = court_blight_mix(col, v_blight) * mix(1.0, 0.55, v_blight);
	ALBEDO = col;
	ROUGHNESS = mix(mix(roughness_value, 0.55, snow), 1.0, v_blight);
	SPECULAR = 0.3;
	float alive = 1.0 - v_blight;
	float rim = candy_fresnel(NORMAL, VIEW, rim_power);
	vec3 glint = vec3(0.0);
	float s = sparkle * magic_amount * alive;
	if (s > 0.0) {
		vec3 cell = floor(world_pos * 18.0);
		float hsh = court_hash13(cell);
		float twinkle = step(0.985 - s * 0.03, hsh) * (0.5 + 0.5 * sin(TIME * 6.0 + hsh * 40.0));
		glint = sparkle_color.rgb * twinkle * 3.0;
	}
	float glow = clamp(v_color.a, 0.0, 1.0) * emission_glow * mix(1.0, 0.1, v_blight);
	EMISSION = (rim_color.rgb * rim * rim_strength * mix(0.25, 1.0, magic_amount) + glint) * alive + col * glow;
	BACKLIGHT = col * translucency * alive;
}
