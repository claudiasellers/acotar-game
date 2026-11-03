// Alabaster ashlar for the manor's outer walls (L42, audit A8).
// World-space coursing, so merged wall boxes of any size line up.
// Ground storey is rusticated (deep horizontal channels).
// Albedo stays at or below 0.85 (L18-4 glare rule).
shader_type spatial;
render_mode cull_back;
// Lighting: candy_lit (render program T2), stock defaults = the look it had.
#define CANDY_LOBES
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

uniform vec3 stone_a : source_color = vec3(0.84, 0.79, 0.78);   // blush alabaster
uniform vec3 stone_b : source_color = vec3(0.82, 0.79, 0.83);   // lilac alabaster
uniform vec3 stone_c : source_color = vec3(0.85, 0.81, 0.75);   // butter alabaster
uniform float course_h = 0.6;
uniform float block_l = 1.3;
uniform float joint = 0.022;
uniform float rustic_top = 6.6;       // world y where rustication stops (set by ManorFacade)
uniform float rustic_joint = 0.07;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wnrm);
	float u = n.x > n.z ? wpos.z : wpos.x;
	float v = wpos.y;
	bool rustic = v < rustic_top;
	float ch = rustic ? course_h * 1.0 : course_h;
	float row = floor(v / ch);
	float off = mod(row, 2.0) * 0.5;
	float bl = rustic ? block_l * 1.4 : block_l;
	float col = floor(u / bl + off);
	vec2 cell = vec2(col, row);
	float fu = fract(u / bl + off) * bl;
	float fv = fract(v / ch) * ch;
	float hj = rustic ? rustic_joint : joint;
	float vj = rustic ? joint * 1.3 : joint;
	// distance to the nearest joint (metres)
	float dh = min(fv, ch - fv);
	float dv = min(fu, bl - fu);
	float in_h = 1.0 - smoothstep(hj * 0.5, hj * 0.5 + 0.01, dh);
	float in_v = 1.0 - smoothstep(vj * 0.5, vj * 0.5 + 0.008, dv);
	float j = max(in_h, in_v);
	float h = hash2(cell);
	vec3 base = h < 0.5 ? mix(stone_a, stone_b, h * 2.0) : mix(stone_a, stone_c, (h - 0.5) * 2.0);
	base *= 0.95 + 0.05 * noise2(vec2(u, v) * 3.0) + 0.02 * noise2(vec2(u, v) * 17.0);
	// rusticated blocks: soft bevel shading toward the channel
	if (rustic) {
		base *= 0.93 + 0.07 * smoothstep(0.0, 0.12, dh);
	}
	vec3 mortar = base * vec3(0.80, 0.76, 0.80);
	vec3 c = mix(base, mortar, j);
	ALBEDO = min(c, vec3(0.85));
	ROUGHNESS = mix(0.58, 0.9, j);
	candy_lobes(0.35, 0.0, 0.5);
	// faint pearlescent shimmer at grazing angles (R3), kept tiny for glare
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = vec3(0.10, 0.06, 0.12) * fres * (1.0 - j);
}
