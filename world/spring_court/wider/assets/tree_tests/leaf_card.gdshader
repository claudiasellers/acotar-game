// Model direction test B (tools/court/blender/tree_directions.py): a crown's
// leaf card. The card's own 0..1 coordinates arrive in UV2; the shader paints
// a spray of pointed leaves on it and cuts the rest away (alpha test), so a
// crown of a few hundred cards reads as painted leaves with a broken edge.
// Everything else is the woods' foliage look: vertex COLOR albedo (sRGB),
// UV.x wind flex, candy_lit light. The cards carry the crown's outward normal
// (set in Blender), so the whole crown lights as one soft mass.
// Preview only: nothing in the game uses it until the owner picks.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://world/shared/shaders/foliage_wind.gdshaderinc"

uniform float translucency : hint_range(0.0, 1.0) = 0.3;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.75;
uniform float lime_guard : hint_range(0.0, 1.0) = 0.15;
uniform float leaf_size : hint_range(0.5, 2.0) = 1.0;

varying vec3 world_pos;

#define CANDY_ALBEDO_MIX_DEFAULT 1.0
#define CANDY_GAIN_DEFAULT 2.0
#define CANDY_BURLEY_DEFAULT 0.0
#define CANDY_WRAP_DEFAULT 0.55
#define CANDY_SHADE_DEFAULT vec4(0.66, 0.56, 0.82, 1.0)
#define CANDY_RIM_COLOR_DEFAULT vec4(1.0, 0.84, 0.76, 1.0)
#define CANDY_RIM_STRENGTH_DEFAULT 0.35
#define CANDY_NO_SPEC_LOBE
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

void vertex() {
	VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, UV.x * 1.6);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float h1(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

// One pointed leaf: 1 inside, plus its lit side (-1..1 across the blade).
vec2 leaf(vec2 uv, vec2 c, float a, float len, float wid) {
	vec2 d = uv - c;
	vec2 q = vec2(cos(a) * d.x + sin(a) * d.y, -sin(a) * d.x + cos(a) * d.y);
	float t = q.x / len;
	if (abs(t) > 1.0) {
		return vec2(0.0);
	}
	float half_w = wid * sqrt(1.0 - t * t) * (1.0 - 0.35 * t);
	if (abs(q.y) > half_w) {
		return vec2(0.0);
	}
	return vec2(1.0, q.y / max(half_w, 1e-4));
}

void fragment() {
	vec2 uv = UV2;
	float inside = 0.0;
	float side = 0.0;
	float which = 0.0;
	// A spray of leaves from the card's centre outward, fixed per card shape;
	// the cards themselves are twisted at random, so no two sprays line up.
	for (int i = 0; i < 11; i++) {
		float fi = float(i);
		float a = fi * 2.399 + h1(fi) * 0.8;
		float r = 0.08 + 0.3 * sqrt(h1(fi + 7.0));
		vec2 c = vec2(0.5) + vec2(cos(a), sin(a)) * r;
		vec2 l = leaf(uv, c, a + (h1(fi + 3.0) - 0.5) * 1.2, 0.17 * leaf_size, 0.075 * leaf_size);
		if (l.x > 0.0) {
			inside = 1.0;
			side = l.y;
			which = fi;
		}
	}
	if (inside < 0.5) {
		discard;
	}
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	float greenness = clamp((col.g - max(col.r, col.b)) / max(col.g, 0.001), 0.0, 1.0) * lime_guard;
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))), greenness);
	// Painted leaf: a lit half and a shade half, a darker midrib, and a
	// little value jitter leaf to leaf.
	float lit = 0.9 + 0.14 * side - 0.1 * (1.0 - smoothstep(0.0, 0.18, abs(side)));
	col *= lit * (0.9 + 0.2 * h1(which + 13.0));
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.3;
	BACKLIGHT = col * translucency;
}
