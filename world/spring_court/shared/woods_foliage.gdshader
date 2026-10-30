// The woods' flora material: the shared stylized look (world/shared/shaders/
// stylized_foliage.gdshader: wrapped lilac-tinted light, warm rim, sparkle
// scaled by magic_amount) adapted to the woods' multi-coloured procedural
// meshes, which keep albedo in vertex COLOR and wind flex in UV.x instead of
// COLOR.r. UV.y is glow (faelights, glowcaps, starmoss).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://world/shared/shaders/foliage_wind.gdshaderinc"

global uniform float magic_amount;

uniform float wrap : hint_range(0.0, 1.0) = 0.55;
uniform vec4 shade_tint : source_color = vec4(0.66, 0.56, 0.82, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.84, 0.76, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.55;
uniform float translucency : hint_range(0.0, 1.0) = 0.4;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.7;
uniform float sparkle : hint_range(0.0, 1.0) = 0.0;
uniform vec4 sparkle_color : source_color = vec4(1.0, 0.92, 0.80, 1.0);
uniform float glow_energy : hint_range(0.0, 6.0) = 2.5;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
// 0 = eternal spring; 1 = colour drained (dread margin, blight).
uniform float drain : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;
varying float v_glow;

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
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.35;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 glint = vec3(0.0);
	float s = (sparkle + v_glow * 0.6) * magic_amount * (1.0 - drain);
	if (s > 0.0) {
		vec3 cell = floor(world_pos * 7.0);
		float h = hash3(cell);
		float twinkle = step(0.996 - s * 0.012, h) * pow(0.5 + 0.5 * sin(TIME * 4.0 + h * 40.0), 4.0);
		glint = sparkle_color.rgb * twinkle * 3.0;
	}
	EMISSION = rim_color.rgb * rim * rim_strength * mix(0.25, 1.0, magic_amount) * (1.0 - drain)
			+ glint + col * v_glow * glow_energy;
	BACKLIGHT = col * translucency;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrapped = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	vec3 lit = mix(shade_tint.rgb, vec3(1.0), wrapped);
	DIFFUSE_LIGHT += ALBEDO * lit * LIGHT_COLOR * ATTENUATION * wrapped / PI * 2.0;
}
