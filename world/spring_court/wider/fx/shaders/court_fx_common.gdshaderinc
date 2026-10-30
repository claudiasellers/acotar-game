// Shared procedural helpers for the Spring Court FX shaders. No image files.

float court_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float court_hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float court_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = court_hash12(i);
	float b = court_hash12(i + vec2(1.0, 0.0));
	float c = court_hash12(i + vec2(0.0, 1.0));
	float d = court_hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float court_fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * court_vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		amp *= 0.5;
	}
	return v;
}

// Soft pastel rainbow used for pearlescent sheen (rose -> lilac -> mint -> butter).
vec3 court_pastel_rainbow(float t) {
	vec3 c = 0.5 + 0.5 * cos(6.28318 * (vec3(1.0, 1.0, 1.0) * t + vec3(0.0, 0.33, 0.67)));
	return mix(c, vec3(1.0), 0.45);
}

// Blight: desaturate, darken and push toward a sickly grey.
vec3 court_blight_mix(vec3 col, float amount) {
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 grey = vec3(lum) * vec3(0.42, 0.43, 0.44);
	return mix(col, grey, clamp(amount, 0.0, 1.0));
}

// Four-point star sparkle mask; p in -1..1.
float court_star_mask(vec2 p) {
	float r = length(p);
	float cross_a = exp(-abs(p.x) * 18.0) * max(0.0, 1.0 - abs(p.y));
	float cross_b = exp(-abs(p.y) * 18.0) * max(0.0, 1.0 - abs(p.x));
	float core = exp(-r * r * 30.0);
	float halo = exp(-r * r * 6.0) * 0.25;
	return clamp(cross_a + cross_b + core + halo, 0.0, 1.0);
}

float court_orb_mask(vec2 p) {
	float r = clamp(length(p), 0.0, 1.0);
	float soft = 1.0 - r;
	return soft * soft * (0.6 + 0.4 * exp(-r * r * 10.0) * 2.0);
}

float court_petal_mask(vec2 p) {
	// Rounded rose/cherry petal with a small heart notch at the tip.
	vec2 q = vec2(p.x * 1.55, p.y + 0.15);
	float d = length(q) - 0.78 + 0.18 * p.y;
	float notch = exp(-pow(p.x * 9.0, 2.0)) * smoothstep(0.35, 0.8, p.y) * 0.22;
	return 1.0 - smoothstep(-0.06, 0.04, d + notch);
}

float court_leaf_mask(vec2 p) {
	float w = 0.62 * (1.0 - p.y * p.y);
	float edge = 1.0 - smoothstep(w - 0.06, w + 0.02, abs(p.x));
	float rib = 1.0 - 0.35 * exp(-pow(p.x * 30.0, 2.0));
	return edge * rib * step(abs(p.y), 0.98);
}

float court_flake_mask(vec2 p, float seed) {
	float a = atan(p.y, p.x);
	float r = length(p);
	float edge = 0.55 + 0.18 * sin(a * 5.0 + seed * 6.28) + 0.1 * sin(a * 3.0 - seed * 11.0);
	return 1.0 - smoothstep(edge - 0.08, edge, r);
}

float court_flame_mask(vec2 p, float t) {
	// p.y up. Teardrop flame with a wobbling tip.
	float y = p.y * 0.5 + 0.5;
	float wob = sin(t * 9.0 + y * 6.0) * 0.08 * y;
	float w = 0.62 * pow(max(1.0 - y, 0.0), 0.7) * smoothstep(0.0, 0.25, y + 0.12);
	float d = abs(p.x - wob) - w;
	return 1.0 - smoothstep(-0.12, 0.02, d);
}

float court_smoke_mask(vec2 p, float seed) {
	float n = court_fbm(p * 2.2 + vec2(seed * 13.0, seed * 7.0));
	float r = length(p) + (n - 0.5) * 0.5;
	float m = 1.0 - smoothstep(0.2, 0.95, r);
	return m * m;
}

float court_seed_mask(vec2 p) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float strands = pow(abs(cos(a * 7.0)), 30.0) * smoothstep(0.95, 0.2, r);
	float tips = exp(-pow((r - 0.8) * 9.0, 2.0)) * 0.6;
	float core = exp(-r * r * 60.0);
	return clamp(strands + tips + core, 0.0, 1.0);
}

float court_shape_mask(int shape, vec2 p, float seed, float t) {
	if (shape == 1) { return court_star_mask(p); }
	if (shape == 2) { return court_petal_mask(p); }
	if (shape == 3) { return court_flake_mask(p, seed); }
	if (shape == 4) { return court_flame_mask(p, t + seed * 10.0); }
	if (shape == 5) { return court_smoke_mask(p, seed); }
	if (shape == 6) { return court_seed_mask(p); }
	if (shape == 7) { return court_leaf_mask(p); }
	return court_orb_mask(p);
}
