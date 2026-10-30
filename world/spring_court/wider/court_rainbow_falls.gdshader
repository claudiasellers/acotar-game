// Rainbow waterfall sheet (canon rainbow falls, Keeper): bands of colour that
// run down the water with white foam streaks, glittering with magic_amount.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, shadows_disabled;

global uniform float magic_amount;

uniform float flow_speed = 0.9;
uniform float band_count = 5.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.82;
uniform float glow : hint_range(0.0, 4.0) = 0.6;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float streaks(vec2 uv, float t) {
	float col = floor(uv.x * 38.0);
	float speed = 0.7 + hash21(vec2(col, 1.7)) * 0.6;
	float v = fract(uv.y * 3.0 - t * speed + hash21(vec2(col, 9.1)));
	return smoothstep(0.55, 1.0, v);
}

vec3 rainbow(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	float t = TIME * flow_speed;
	float hue = fract(UV.x * band_count / 6.0 + UV.y * 0.15 - t * 0.05);
	vec3 base = mix(rainbow(hue), vec3(1.0), 0.45);
	float foam = streaks(UV, t);
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	float twinkle = step(0.985, hash21(floor(vec2(UV.x * 60.0, UV.y * 90.0 - t * 40.0)))) * magic_amount;
	ALBEDO = mix(base, vec3(1.0), foam * 0.6);
	EMISSION = (base * glow + vec3(twinkle * 2.0)) * (0.6 + foam * 0.4);
	ROUGHNESS = 0.1;
	ALPHA = clamp((opacity * (0.7 + foam * 0.3)) * edge, 0.0, 1.0);
}
