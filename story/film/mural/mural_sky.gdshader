// A mural tableau's backdrop (lane L33): a painted night gradient on lacquer
// with gold-dust stars and the canvas weave, painted on like the figures.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 top : source_color = vec3(0.06, 0.04, 0.14);
uniform vec3 low : source_color = vec3(0.28, 0.12, 0.26);
uniform vec3 gold : source_color = vec3(1.0, 0.83, 0.46);
uniform float stars = 1.0;
uniform float reveal = 1.0;
uniform float drain = 0.0;
uniform float glow_band = 0.0;

varying vec2 uv;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	uv = UV;
}

void fragment() {
	// Soaks on like the figures' paint: a soft ragged front, west to east.
	float pool = noise(uv * vec2(5.0, 3.0) + 7.0) * 0.65 + noise(uv * vec2(17.0, 11.0)) * 0.35;
	if (uv.x > reveal * 1.6 - 0.3 - (pool - 0.5) * 0.5 + (noise(vec2(uv.x * 40.0, uv.y * 60.0)) - 0.5) * 0.03) {
		discard;
	}
	vec3 col = mix(low, top, smoothstep(0.0, 0.8, 1.0 - uv.y));
	col *= 0.85 + 0.3 * noise(uv * vec2(600.0, 6.0)) * noise(uv * 80.0);
	float s = step(0.9975, hash(floor(uv * vec2(900.0, 500.0))));
	col += gold * s * stars * (1.0 - drain) * (0.6 + 0.4 * sin(TIME * 1.7 + hash(floor(uv * 300.0)) * 20.0));
	col += gold * glow_band * smoothstep(0.35, 0.0, abs(uv.y - 0.72)) * 0.25;
	col *= 1.0 - 0.6 * drain;
	ALBEDO = col;
}
