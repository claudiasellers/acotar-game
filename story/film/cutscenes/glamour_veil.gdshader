// Lucien's glamour over Feyre in cutscene B (lane L33): a faint grey veil
// that settles over her and takes the curtain's colour, so she fades into
// the drapes; Rhysand tears it like wet paper.
// - amount 0..1: how far it has settled. tear 0..1: the hole spreading from
//   the front (local +z) until nothing is left.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// Shared rim curve of the candy_lit family (render program T2).
#include "res://world/shared/shaders/candy_rim.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.3, 0.07, 0.1);
uniform float amount = 0.0;
uniform float tear = 0.0;

varying vec3 lp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int k = 0; k < 4; k++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 q = vec2(atan(lp.x, lp.z) * 0.36, lp.y);
	// The tear: a ragged hole opening from the front, its edge wet and pale.
	float ragged = fbm(q * vec2(9.0, 7.0)) * 0.35;
	float d = length(q * vec2(1.0, 0.75)) + ragged;
	float hole = tear * 1.6;
	if (tear > 0.0 && d < hole) {
		discard;
	}
	float wet = tear > 0.0 ? smoothstep(0.06, 0.0, d - hole) : 0.0;
	float weave = noise(q * vec2(80.0, 140.0) + vec2(TIME * 0.4, 0.0));
	float drift = fbm(q * vec2(3.0, 2.0) + vec2(0.0, TIME * 0.15));
	float fres = candy_fresnel(dot(NORMAL, VIEW) < 0.0 ? -NORMAL : NORMAL, VIEW, 1.6);
	vec3 grey = vec3(0.52, 0.52, 0.56);
	vec3 col = mix(grey, tint, smoothstep(0.2, 0.9, amount)) * (0.85 + 0.25 * drift);
	col = mix(col, vec3(0.8, 0.78, 0.82), wet * 0.7);
	col += vec3(0.1, 0.1, 0.12) * fres * (1.0 - amount * 0.5);
	ALBEDO = col;
	ALPHA = clamp(amount * (0.8 + 0.15 * weave + 0.2 * fres) + wet * 0.5, 0.0, 0.97);
}
