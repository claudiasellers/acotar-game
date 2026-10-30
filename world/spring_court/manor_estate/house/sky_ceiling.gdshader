// A ceiling painted as an open sky (experience bar §2.6): an oval medallion of
// soft blue sky with blush-lit clouds inside a gilt frame, on a pearl field.
// room_rect = (min x, min z, width, depth) in world metres; only the face that
// looks down gets the painting. Sky ambient from below is the ground colour
// (green), so the ceiling ignores ambient and carries its own soft light.
shader_type spatial;
render_mode cull_back, ambient_light_disabled;

uniform vec4 room_rect = vec4(0.0, 0.0, 10.0, 10.0);
uniform vec4 field : source_color = vec4(0.984, 0.969, 0.949, 1.0);
uniform vec4 sky_high : source_color = vec4(0.655, 0.71, 0.949, 1.0);   // periwinkle #A7B5F2
uniform vec4 sky_mid : source_color = vec4(0.788, 0.855, 0.957, 1.0);   // soft blue #C9DAF4
uniform vec4 sky_glow : source_color = vec4(1.0, 0.92, 0.88, 1.0);      // warm dawn at the centre
uniform vec4 cloud_tint : source_color = vec4(0.98, 0.83, 0.86, 1.0);   // blush #FAD4DC
uniform vec4 gilt : source_color = vec4(0.902, 0.753, 0.408, 1.0);
uniform float glow = 0.55;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

float band(float d, float w) {
	float aa = max(fwidth(d), 0.0005);
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

void fragment() {
	vec3 col = field.rgb;
	float g = 0.0;
	vec3 emit = vec3(0.0);
	if (wnrm.y < -0.5) {
		vec2 half_size = room_rect.zw * 0.5;
		vec2 p = wpos.xz - (room_rect.xy + half_size);
		vec2 radii = max(half_size - vec2(0.9), vec2(0.6));
		float e = length(p / radii);
		float d = (e - 1.0) * min(radii.x, radii.y);    // ~metres from the frame
		if (d < 0.0) {
			vec3 sky = mix(sky_mid.rgb, sky_high.rgb, smoothstep(0.3, 1.0, e));
			sky = mix(sky_glow.rgb, sky, smoothstep(0.0, 0.55, e));
			float c = fbm(wpos.xz * 0.28 + vec2(3.1, 7.7));
			float cloud = smoothstep(0.48, 0.7, c) * (1.0 - smoothstep(0.75, 1.0, e) * 0.6);
			vec3 cl = mix(vec3(1.0, 0.99, 0.97), cloud_tint.rgb, smoothstep(0.55, 0.8, c) * 0.6);
			col = mix(sky, cl, cloud);
			emit = col * glow;
		} else {
			// painted plaster lit by the chandeliers: a little self-light keeps
			// the ground-coloured ambient from below from greening it
			col = field.rgb * mix(0.93, 1.0, smoothstep(0.0, 0.4, d));
			emit = col * glow * 1.3;
		}
		g = band(d - 0.06, 0.05);
		g = max(g, band(d - 0.24, 0.015));
		g = max(g, band(d + 0.05, 0.008) * 0.8);
	}
	// gilt here can't mirror an ambient it ignores: keep it mostly dielectric
	// and let it glow like leaf catching the chandeliers
	ALBEDO = mix(col, gilt.rgb, g);
	METALLIC = 0.3 * g;
	ROUGHNESS = mix(0.9, 0.35, g);
	EMISSION = mix(emit, gilt.rgb * 0.75, g);
}
