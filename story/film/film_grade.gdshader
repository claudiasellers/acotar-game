// A cutscene's grade over the game picture (lane L33). Everything is 0 = off.
// - veil: the glamour on human eyes, a little grey and flat (cutscene A).
// - bloom: the world as it really is, richer, warmer, clearer (A #7).
// - edge_gold: a faint gold shimmer along every edge in the frame (A #7).
// - cold: the light cooling toward violet-blue as power walks in (B #4).
// - crack: violet static cracking in from the frame's edges (B #9).
// - time: seconds, for the shimmer and the static.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float veil = 0.0;
uniform float bloom = 0.0;
uniform float edge_gold = 0.0;
uniform float cold = 0.0;
uniform float crack = 0.0;
uniform float t = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	// The crack's static bends the picture a little where it runs.
	float edge_d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float cracks = 0.0;
	if (crack > 0.0) {
		float n = noise(uv * vec2(9.0, 5.0) + vec2(t * 0.3, 0.0));
		float reach = crack * 0.42 + n * 0.12;
		float vein = smoothstep(0.035, 0.0, abs(noise(uv * 14.0 + t * 0.15) - 0.5)) * step(edge_d, reach);
		cracks = clamp(vein + smoothstep(reach, reach - 0.12, edge_d) * 0.5, 0.0, 1.0) * crack;
		uv += (vec2(hash(uv * 700.0 + t), hash(uv * 900.0 - t)) - 0.5) * 0.012 * cracks;
	}
	vec3 c = texture(screen, uv).rgb;
	float l = luma(c);
	// The veil: a greyer, flatter world.
	c = mix(c, vec3(l) * vec3(1.0, 0.98, 0.95), veil * 0.38);
	c = mix(c, vec3(0.5) + (c - 0.5) * 0.86, veil);
	// Bloom: saturation, warmth and a soft lift of the lights.
	c = mix(vec3(l), c, 1.0 + bloom * 0.45);
	c *= 1.0 + bloom * vec3(0.06, 0.03, -0.02);
	c += bloom * 0.12 * smoothstep(0.55, 1.0, l) * vec3(1.0, 0.9, 0.75);
	// Gold along the edges of things, breathing.
	if (edge_gold > 0.0) {
		float gx = luma(texture(screen, uv + vec2(px.x, 0.0)).rgb) - luma(texture(screen, uv - vec2(px.x, 0.0)).rgb);
		float gy = luma(texture(screen, uv + vec2(0.0, px.y)).rgb) - luma(texture(screen, uv - vec2(0.0, px.y)).rgb);
		float e = smoothstep(0.05, 0.25, length(vec2(gx, gy)));
		float shimmer = 0.6 + 0.4 * sin(t * 2.2 + uv.x * 40.0 + uv.y * 25.0);
		c += vec3(1.0, 0.82, 0.42) * e * shimmer * edge_gold * 0.45;
	}
	// Cold: the light drains toward violet-blue, the shadows deepen.
	vec3 cool = vec3(l * 0.78, l * 0.8, l * 1.05) * vec3(0.85, 0.82, 1.0);
	c = mix(c, cool * (0.65 + 0.35 * smoothstep(0.1, 0.7, l)), cold * 0.8);
	// Violet static in the cracks.
	vec3 stat = vec3(0.55, 0.3, 1.0) * (0.4 + 0.6 * hash(floor(uv / px / 2.0) + floor(t * 24.0)));
	c = mix(c, stat, cracks * 0.75);
	c *= 1.0 - cracks * 0.35 * smoothstep(0.3, 0.0, edge_d);
	COLOR = vec4(c, 1.0);
}
