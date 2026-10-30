// Draws the painted world map under a drifting pastel mist where Feyre has not
// been yet, with a gold sparkle along the edge of what she has uncovered (R3).
// Used by the minimap (round) and the full map (rectangle).
shader_type canvas_item;

uniform sampler2D map_tex : filter_linear, repeat_disable;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
// What part of the map (0-1 UV) this rectangle shows.
uniform vec2 view_center = vec2(0.5);
uniform vec2 view_size = vec2(0.1);
uniform bool round_mask = false;
uniform vec4 mist_a : source_color = vec4(0.93, 0.89, 0.99, 1.0);
uniform vec4 mist_b : source_color = vec4(1.0, 0.90, 0.95, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.86, 0.52, 1.0);
uniform float sparkle = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = view_center + (UV - 0.5) * view_size;
	// Map space in ~metres/64 so the mist has the same grain at any zoom.
	vec2 m = uv * vec2(64.0, 80.0);
	vec4 map = texture(map_tex, clamp(uv, vec2(0.0), vec2(1.0)));
	float seen = texture(fog_tex, uv).r;
	bool inside = uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
	if (!inside) {
		seen = 0.0;
	}
	// A ragged watercolour edge to the uncovered part.
	float wobble = fbm(m * 1.7 + TIME * 0.03) - 0.5;
	float reveal = smoothstep(0.38, 0.62, seen + wobble * 0.45);

	// Mist: two pastel washes swirling slowly, a few pale cloud tops.
	float swirl = fbm(m * 0.9 + vec2(TIME * 0.02, -TIME * 0.015));
	vec3 mist = mix(mist_a.rgb, mist_b.rgb, smoothstep(0.3, 0.7, swirl));
	mist = mix(mist, vec3(1.0), smoothstep(0.62, 0.8, fbm(m * 2.3 - TIME * 0.025)) * 0.5);
	// The map shows through the mist very faintly, like a page under vellum.
	mist = mix(mist, map.rgb, 0.05 * float(inside));

	vec3 col = mix(mist, map.rgb, reveal);
	// Gold along the edge of the uncovered part, twinkling.
	float edge = reveal * (1.0 - reveal) * 4.0;
	vec2 cell = floor(m * 6.0);
	float star = step(0.93, hash(cell)) * (0.5 + 0.5 * sin(TIME * 3.0 + hash(cell + 7.0) * 6.28));
	col = mix(col, gold.rgb, clamp(edge * (0.35 + star * sparkle), 0.0, 1.0));

	float alpha = 1.0;
	if (round_mask) {
		float r = length(UV - 0.5) * 2.0;
		alpha = 1.0 - smoothstep(0.985, 1.0, r);
		// A soft pearly inner rim.
		col = mix(col, vec3(1.0, 0.97, 0.99), smoothstep(0.82, 1.0, r) * 0.35);
	}
	COLOR = vec4(col, alpha * COLOR.a);
}
