// The glen's clear brook in cutscene A (lane L33). `rainbow` 0..1 brings up
// the near-invisible rainbow that runs on it once the glamour lifts.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec3 water : source_color = vec3(0.32, 0.5, 0.58);
uniform float rainbow = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	// UV.x runs along the brook (metres), UV.y across it (0..1).
	vec2 flow = vec2(UV.x * 1.4 - TIME * 0.6, UV.y * 3.0);
	float n1 = noise(flow * 3.0);
	float n2 = noise(flow * 7.0 + 11.0);
	NORMAL_MAP = normalize(vec3(n1 - 0.5, n2 - 0.5, 1.6)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
	float edge = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.82, UV.y);
	ALBEDO = water;
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
	METALLIC = 0.0;
	vec3 hue = 0.5 + 0.5 * cos(6.28318 * (UV.x * 0.12 - TIME * 0.05 + UV.y * 0.4 + vec3(0.0, 0.33, 0.67)));
	EMISSION = hue * rainbow * 0.22 * (0.6 + 0.4 * n1) * edge;
	ALPHA = 0.62 * edge + 0.1;
}
