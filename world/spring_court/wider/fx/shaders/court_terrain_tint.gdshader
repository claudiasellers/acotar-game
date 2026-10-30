// Vertex-colour ground with procedural pastel variation, slope rock blend and blight.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://world/spring_court/wider/fx/shaders/court_fx_common.gdshaderinc"

uniform float blight : hint_range(0.0, 1.0) = 0.0;
uniform bool vertex_color_srgb = false;
uniform bool use_vertex_color = true;
uniform vec4 grass_a : source_color = vec4(0.62, 0.86, 0.58, 1.0);
uniform vec4 grass_b : source_color = vec4(0.74, 0.92, 0.64, 1.0);
uniform vec4 grass_c : source_color = vec4(0.70, 0.84, 0.72, 1.0);
uniform vec4 blossom_speck : source_color = vec4(1.0, 0.78, 0.88, 1.0);
uniform vec4 rock_color : source_color = vec4(0.86, 0.80, 0.84, 1.0);
uniform float noise_scale = 0.08;
uniform float speck_density = 3.0;
uniform float speck_amount : hint_range(0.0, 1.0) = 0.12;
uniform float slope_start : hint_range(0.0, 1.0) = 0.62;
uniform float slope_end : hint_range(0.0, 1.0) = 0.78;
uniform float vertex_color_weight : hint_range(0.0, 1.0) = 0.6;
uniform float blight_affect : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_color;

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 c = COLOR;
	if (vertex_color_srgb) {
		c.rgb = to_linear(c.rgb);
	}
	v_color = c;
}

void fragment() {
	vec2 p = v_world_pos.xz;
	float n1 = court_fbm(p * noise_scale);
	float n2 = court_fbm(p * noise_scale * 3.7 + 11.0);
	vec3 grass = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.3, 0.7, n1));
	grass = mix(grass, grass_c.rgb, smoothstep(0.45, 0.8, n2) * 0.6);
	float speck = step(1.0 - speck_amount, court_hash12(floor(p * speck_density)));
	grass = mix(grass, blossom_speck.rgb, speck * 0.5);
	vec3 base = grass;
	if (use_vertex_color) {
		base = mix(grass, v_color.rgb * (0.9 + 0.2 * n2), vertex_color_weight);
	}
	float up = clamp(v_world_normal.y, 0.0, 1.0);
	float rock = 1.0 - smoothstep(slope_start, slope_end, up);
	vec3 rock_c = rock_color.rgb * (0.85 + 0.3 * n2);
	vec3 col = mix(base, rock_c, rock);
	float b = blight * blight_affect;
	col = court_blight_mix(col, b) * mix(1.0, 0.5, b);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.95, rock);
	SPECULAR = 0.25;
}
