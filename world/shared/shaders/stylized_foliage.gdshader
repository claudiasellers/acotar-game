// Shared stylized foliage / flora material for every region (art direction R3).
// Soft wrapped lighting, a warm rim, leaf translucency, GPU wind, snow on top
// in the human realm, and sparkle glints where the Spring Court's magic is on.
// Use as a ShaderMaterial on scatter meshes; tune per species with the uniforms.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://world/shared/shaders/foliage_wind.gdshaderinc"

global uniform float magic_amount;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform bool use_vertex_color = true;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.4;
uniform float wrap : hint_range(0.0, 1.0) = 0.5;
uniform vec4 shade_tint : source_color = vec4(0.62, 0.55, 0.78, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.86, 0.72, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.6;
uniform float translucency : hint_range(0.0, 1.0) = 0.35;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.75;
// How much this species takes snow on its upward faces when snow_cover is on.
uniform float snow_catch : hint_range(0.0, 1.0) = 0.8;
uniform vec4 snow_color : source_color = vec4(0.93, 0.95, 1.0, 1.0);
// Glitter on magical species, scaled by the global magic_amount.
uniform float sparkle : hint_range(0.0, 1.0) = 0.0;
uniform vec4 sparkle_color : source_color = vec4(1.0, 0.93, 0.75, 1.0);
uniform float emission_glow : hint_range(0.0, 4.0) = 0.0;

varying vec3 world_normal;
varying vec3 world_pos;

void vertex() {
	VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, COLOR.r);
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 col = albedo.rgb * tex.rgb;
	if (use_vertex_color) {
		col *= mix(vec3(1.0), COLOR.rgb, step(0.001, COLOR.g + COLOR.b));
	}
	float up = clamp(world_normal.y, 0.0, 1.0);
	float snow = smoothstep(0.35, 0.8, up) * snow_cover * snow_catch;
	col = mix(col, snow_color.rgb, snow);
	ALBEDO = col;
	ALPHA = tex.a * albedo.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = mix(roughness_value, 0.55, snow);
	SPECULAR = 0.3;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 glint = vec3(0.0);
	float s = sparkle * magic_amount;
	if (s > 0.0) {
		vec3 cell = floor(world_pos * 18.0);
		float h = hash3(cell);
		float twinkle = step(0.985 - s * 0.03, h) * (0.5 + 0.5 * sin(TIME * 6.0 + h * 40.0));
		glint = sparkle_color.rgb * twinkle * 3.0;
	}
	EMISSION = rim_color.rgb * rim * rim_strength * mix(0.25, 1.0, magic_amount) + glint + col * emission_glow;
	BACKLIGHT = col * translucency;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrapped = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	vec3 lit = mix(shade_tint.rgb, vec3(1.0), wrapped);
	DIFFUSE_LIGHT += ALBEDO * lit * LIGHT_COLOR * ATTENUATION * wrapped / PI * 2.0;
}
