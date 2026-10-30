// Spring Court props: same base as court_foliage (albedo = COLOR.rgb,
// glow = COLOR.a * emission_glow, wrap light, shade tint, rim) with no wind,
// plus optional pearlescent sheen and view-dependent glitter for magic items.
shader_type spatial;
render_mode depth_draw_opaque;

#include "res://world/spring_court/wider/fx/shaders/court_fx_common.gdshaderinc"

global uniform float magic_amount;
global uniform float snow_cover;

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool vertex_color_srgb = false;
uniform float saturation_boost : hint_range(0.0, 2.0) = 1.1;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.55;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float wrap : hint_range(0.0, 1.0) = 0.4;
uniform vec4 shade_tint : source_color = vec4(0.66, 0.58, 0.8, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.88, 0.76, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.4;
uniform float snow_catch : hint_range(0.0, 1.0) = 0.6;
uniform vec4 snow_color : source_color = vec4(0.93, 0.95, 1.0, 1.0);
uniform float emission_glow : hint_range(0.0, 8.0) = 2.5;
uniform float pearl_strength : hint_range(0.0, 2.0) = 0.0;
uniform float pearl_shift = 0.0;
uniform float glitter_strength : hint_range(0.0, 8.0) = 0.0;
uniform float glitter_density = 90.0;
uniform float glitter_threshold : hint_range(0.5, 0.999) = 0.93;
uniform vec4 glitter_color : source_color = vec4(1.0, 0.92, 0.98, 1.0);
uniform float blight : hint_range(0.0, 1.0) = 0.0;
uniform float blight_affect : hint_range(0.0, 1.0) = 1.0;

varying vec4 v_color;
varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying float v_blight;

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec4 c = COLOR;
	if (vertex_color_srgb) {
		c.rgb = to_linear(c.rgb);
	}
	v_color = c;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_blight = clamp(blight * blight_affect, 0.0, 1.0);
}

void fragment() {
	float b = v_blight;
	float alive = 1.0 - b;
	vec3 col = v_color.rgb * albedo.rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = max(mix(vec3(lum), col, saturation_boost), vec3(0.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 emit = vec3(0.0);
	if (pearl_strength > 0.0) {
		vec3 sheen = court_pastel_rainbow(fres * 0.9 + pearl_shift + dot(v_world_normal, vec3(0.3, 0.5, 0.2)));
		col = mix(col, col * sheen * 1.25, clamp(pearl_strength * (0.35 + fres), 0.0, 1.0));
		emit += sheen * fres * pearl_strength * 0.25;
	}
	if (glitter_strength > 0.0) {
		vec3 cell = floor(v_world_pos * glitter_density);
		float rnd = court_hash13(cell);
		vec3 cam_dir = normalize(CAMERA_POSITION_WORLD - v_world_pos);
		float view_rnd = court_hash13(cell + floor(cam_dir * 12.0) * 31.0);
		float tw = 0.5 + 0.5 * sin(TIME * (2.0 + rnd * 5.0) + rnd * 40.0);
		float spark = step(glitter_threshold, rnd * 0.5 + view_rnd * 0.5) * tw;
		emit += glitter_color.rgb * spark * glitter_strength * mix(0.35, 1.0, magic_amount);
	}
	float up = clamp(v_world_normal.y, 0.0, 1.0);
	float snow = smoothstep(0.35, 0.8, up) * snow_cover * snow_catch;
	col = mix(col, snow_color.rgb, snow);
	col = court_blight_mix(col, b) * mix(1.0, 0.55, b);
	ALBEDO = col;
	ROUGHNESS = mix(roughness_value, 1.0, b);
	METALLIC = metallic_value * alive;
	SPECULAR = 0.4;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float glow = clamp(v_color.a, 0.0, 1.0) * emission_glow * mix(1.0, 0.1, b);
	EMISSION = (emit + rim_color.rgb * rim * rim_strength * mix(0.25, 1.0, magic_amount)) * alive + col * glow;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrapped = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	vec3 lit = mix(shade_tint.rgb, vec3(1.0), wrapped);
	DIFFUSE_LIGHT += ALBEDO * lit * LIGHT_COLOR * ATTENUATION * wrapped / PI * 2.0;
	vec3 hv = normalize(LIGHT + VIEW);
	float spec = pow(clamp(dot(NORMAL, hv), 0.0, 1.0), mix(8.0, 96.0, 1.0 - roughness_value)) * (1.0 - roughness_value);
	SPECULAR_LIGHT += spec * ATTENUATION * LIGHT_COLOR / PI;
}
