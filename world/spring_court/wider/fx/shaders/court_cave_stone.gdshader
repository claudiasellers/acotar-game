// The Rite cave's stone and earth (L45-6): vertex colour is the dark base, and
// this adds what the low-poly mass can't carry. A grain bump from world-space
// noise breaks the facets, mottling varies the albedo, and wet streaks run down
// the faces, darker and glossier. Standard lighting, no rim and no wrap, so the
// stone is cool and dark in itself and only the fire's light warms it.
shader_type spatial;
render_mode depth_draw_opaque;

uniform float bump : hint_range(0.0, 3.0) = 1.1;
uniform float grain_scale = 2.2;
uniform float mottle : hint_range(0.0, 1.0) = 0.45;
uniform float wet_amount : hint_range(0.0, 1.0) = 0.55;
uniform float dry_roughness : hint_range(0.0, 1.0) = 0.88;
uniform float wet_roughness : hint_range(0.0, 1.0) = 0.22;
uniform float emission_glow : hint_range(0.0, 8.0) = 2.5;

varying vec4 v_color;
varying vec3 v_world_pos;

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x),
			mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x),
			mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec3(3.1, 1.7, 5.3);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_color = COLOR;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 wp = v_world_pos;
	float grain = fbm(wp * grain_scale);
	float coarse = fbm(wp * 0.45 + vec3(7.0));
	// Water runs down: noise stretched along the vertical, gathering in bands.
	vec3 sp = vec3(wp.x * 1.3, wp.y * 0.4, wp.z * 1.3) + vec3(coarse * 1.5);
	float streak = vnoise(sp) * 0.65 + vnoise(sp * 2.1 + vec3(4.0)) * 0.35;
	float wet = smoothstep(0.52, 0.7, streak) * wet_amount;
	vec3 col = v_color.rgb * mix(1.0 - mottle * 0.5, 1.0 + mottle * 0.5, coarse) * mix(0.85, 1.12, grain);
	col *= mix(1.0, 0.55, wet);
	ALBEDO = col;
	ROUGHNESS = mix(dry_roughness, wet_roughness, wet) - grain * 0.08;
	SPECULAR = mix(0.35, 0.6, wet);
	// Bump from the grain's screen-space slope (world space, then view space).
	vec3 n_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float hgt = (grain * 0.7 + coarse * 0.3) * bump * 0.06;
	vec3 dpdx = dFdx(wp);
	vec3 dpdy = dFdy(wp);
	float dhx = dFdx(hgt);
	float dhy = dFdy(hgt);
	vec3 r1 = cross(dpdy, n_w);
	vec3 r2 = cross(n_w, dpdx);
	float det = dot(dpdx, r1);
	vec3 g = sign(det) * (dhx * r1 + dhy * r2);
	vec3 bumped = normalize(abs(det) * n_w - g);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
	EMISSION = col * clamp(v_color.a, 0.0, 1.0) * emission_glow;
}
