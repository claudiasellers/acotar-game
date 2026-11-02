// Alis's true form (canon ch24): skin "made from tree bark" that bleaches
// birch-white when she is frightened. Procedural: long ridged furrows along
// the surface's V, warm umber plates with mossy-gold lichen flecks and a soft
// rim so she still reads as a warm, kind figure in the manor's light.
// `fright` 0..1 blends the bark to pale birch with dark lenticels.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 bark_dark : source_color = vec4(0.27, 0.17, 0.11, 1.0);
uniform vec4 bark_light : source_color = vec4(0.58, 0.41, 0.27, 1.0);
uniform vec4 lichen : source_color = vec4(0.70, 0.72, 0.42, 1.0);
uniform vec4 birch : source_color = vec4(0.94, 0.92, 0.86, 1.0);
uniform vec4 birch_mark : source_color = vec4(0.16, 0.14, 0.13, 1.0);
uniform float fright : hint_range(0.0, 1.0) = 0.0;
uniform float ridge_scale = 38.0;
uniform float ridge_depth : hint_range(0.0, 2.0) = 0.9;
uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.70, 1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.3;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
			mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
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

// Furrows: stretched noise along V, sharpened into ridges.
float bark_height(vec2 uv) {
	vec2 p = vec2(uv.x * ridge_scale, uv.y * ridge_scale * 0.22);
	float warp = fbm(p * 0.35) * 2.5;
	float r = abs(sin((p.x + warp) * 1.7));
	r = pow(r, 0.55);
	float plates = fbm(p * vec2(1.0, 2.6));
	return mix(r, plates, 0.35);
}

void fragment() {
	vec2 uv = UV;
	float h = bark_height(uv);
	float e = 0.0025;
	float hx = bark_height(uv + vec2(e, 0.0)) - h;
	float hy = bark_height(uv + vec2(0.0, e)) - h;
	vec3 bump = normalize(vec3(-hx * ridge_depth * 6.0, -hy * ridge_depth * 6.0, 1.0));
	vec3 bark = mix(bark_dark.rgb, bark_light.rgb, smoothstep(0.15, 0.95, h));
	float moss = smoothstep(0.62, 0.8, fbm(uv * ridge_scale * 0.5 + 7.0)) * (1.0 - h);
	bark = mix(bark, lichen.rgb, moss * 0.45);
	// Birch: pale, smooth, with dark horizontal lenticel dashes.
	float dash = smoothstep(0.78, 0.86, fbm(vec2(uv.x * ridge_scale * 0.6, uv.y * ridge_scale * 3.0)));
	vec3 pale = mix(birch.rgb, birch_mark.rgb, dash * 0.85);
	float f = smoothstep(0.0, 1.0, fright);
	ALBEDO = mix(bark, pale, f);
	ROUGHNESS = mix(0.86, 0.55, f);
	SPECULAR = 0.25;
	NORMAL_MAP = mix(bump, vec3(0.0, 0.0, 1.0), f * 0.8) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color.rgb * rim * rim_amount * 0.35;
}
