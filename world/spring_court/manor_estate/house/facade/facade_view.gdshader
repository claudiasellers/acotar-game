// The view out of a manor window, seen from inside (L42, audit D2): a bright
// pastel sky, lilac hills, blossom trees and a rose garden, with parallax so
// it reads as depth, not a flat colour. Upper floors see more sky. At night it
// turns to an indigo sky with stars and faelights.
// INSTANCE_CUSTOM: r = seed, g = level / 3.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

uniform float glow : hint_range(0.0, 1.0) = 0.0;   // night amount (ManorFacadeGlow)
uniform vec3 sky_top : source_color = vec3(0.62, 0.70, 0.96);
uniform vec3 sky_low : source_color = vec3(0.98, 0.86, 0.88);
uniform vec3 hills : source_color = vec3(0.76, 0.70, 0.90);
uniform vec3 woods : source_color = vec3(0.52, 0.78, 0.66);
uniform vec3 lawn : source_color = vec3(0.62, 0.86, 0.66);
uniform vec3 blossom : source_color = vec3(0.98, 0.72, 0.82);
uniform vec3 night_top : source_color = vec3(0.10, 0.10, 0.26);
uniform vec3 night_low : source_color = vec3(0.30, 0.22, 0.42);

varying float seed;
varying float height;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(vec2(i, 0.0)), hash(vec2(i + 1.0, 0.0)), f * f * (3.0 - 2.0 * f));
}

void vertex() {
	seed = INSTANCE_CUSTOM.r;
	height = INSTANCE_CUSTOM.g;
}

void fragment() {
	// parallax: view direction in the pane's own plane
	vec2 par = vec2(dot(VIEW, TANGENT), -dot(VIEW, BINORMAL));
	vec2 uv = vec2(UV.x, 1.0 - UV.y);           // y up
	float shift = seed * 40.0;
	float horizon = 0.42 - height * 0.22;
	// far layers move least
	vec2 u_far = uv + par * 0.05;
	vec2 u_mid = uv + par * 0.14;
	vec2 u_near = uv + par * 0.3;
	vec3 sky = mix(sky_low, sky_top, smoothstep(horizon, 1.05, u_far.y));
	sky += vec3(0.10, 0.07, 0.02) * smoothstep(0.35, 0.0, length(u_far - vec2(0.75, horizon + 0.32)));
	// soft clouds
	float cl = smoothstep(0.55, 0.75, noise(u_far.x * 5.0 + shift) * 0.6 + noise(u_far.x * 13.0 + shift) * 0.4)
			* smoothstep(0.08, 0.0, abs(u_far.y - horizon - 0.38));
	sky = mix(sky, vec3(1.0, 0.97, 0.98), cl * 0.7);
	vec3 c = sky;
	float h_far = horizon + 0.06 + 0.07 * noise(u_far.x * 3.0 + shift);
	c = mix(c, mix(hills, sky_low, 0.35), step(u_far.y, h_far));
	float h_mid = horizon + 0.02 + 0.05 * noise(u_mid.x * 9.0 + shift + 3.0) + 0.03 * noise(u_mid.x * 23.0 + shift);
	float in_woods = step(u_mid.y, h_mid);
	vec3 wood_c = mix(woods, woods * 0.85, noise(u_mid.x * 31.0 + shift));
	float bl = step(0.8, hash(floor(vec2(u_mid.x * 60.0, u_mid.y * 60.0) + shift)));
	wood_c = mix(wood_c, blossom, bl * 0.8);
	c = mix(c, wood_c, in_woods);
	float h_near = horizon - 0.06 + 0.015 * noise(u_near.x * 7.0 + shift);
	float in_lawn = step(u_near.y, h_near);
	vec3 lawn_c = lawn * (0.9 + 0.1 * u_near.y / max(h_near, 0.01));
	float rose = step(0.86, hash(floor(vec2(u_near.x * 40.0, u_near.y * 40.0) + shift * 2.0))) * step(u_near.y, h_near - 0.05);
	lawn_c = mix(lawn_c, blossom * vec3(1.0, 0.85, 0.9), rose);
	c = mix(c, lawn_c, in_lawn);
	// night: indigo sky, stars, faelights over the garden
	vec3 night = mix(night_low, night_top, smoothstep(horizon, 1.0, u_far.y));
	float star = step(0.995, hash(floor(u_far * 180.0 + shift))) * step(h_far, u_far.y);
	night += vec3(star);
	night = mix(night, night_low * 0.5, max(in_woods, step(u_far.y, h_far)) * 0.8);
	float fl = step(0.985, hash(floor(u_near * 70.0 + shift))) * in_lawn;
	night += vec3(1.0, 0.85, 0.55) * fl * 1.5;
	c = mix(c, night, glow);
	ALBEDO = min(c, vec3(0.97));
}
