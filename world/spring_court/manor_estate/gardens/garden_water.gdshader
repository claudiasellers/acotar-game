// Still garden water for the reflecting canal (L35-6, audit E2): deep and
// clear looking straight down, a mirror of the sky toward the far end, with
// soft wind ripples moving across it. The ripples are a sum of a few slow
// directional waves worked out in the shader (no textures to load), so the
// sky's reflection wobbles gently instead of sitting as one flat blue.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.13, 0.22, 0.34, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.30, 0.46, 0.58, 1.0);
uniform float ripple_strength = 0.08;
uniform float ripple_scale = 0.55;
uniform float ripple_speed = 0.6;
uniform float clarity = 0.93;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// The slope (d/dx, d/dz) of the summed waves at p.
vec2 ripple_slope(vec2 p, float t) {
	vec2 dirs[5] = { vec2(1.0, 0.25), vec2(-0.45, 1.0), vec2(0.7, -0.8), vec2(-1.0, -0.35), vec2(0.15, 1.0) };
	float freq[5] = { 1.1, 1.9, 3.1, 4.7, 7.3 };
	float amp[5] = { 0.5, 0.34, 0.2, 0.11, 0.06 };
	float speed[5] = { 0.55, 0.8, 1.05, 1.35, 1.8 };
	vec2 g = vec2(0.0);
	for (int i = 0; i < 5; i++) {
		vec2 d = normalize(dirs[i]);
		float ph = dot(d, p) * freq[i] + t * speed[i];
		g += d * freq[i] * amp[i] * cos(ph);
	}
	return g;
}

void fragment() {
	vec2 g = ripple_slope(world_pos.xz * ripple_scale, TIME * ripple_speed) * ripple_strength * 0.1;
	vec3 n = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// looking down you see into the dark pool; at a glance, the sky
	ALBEDO = mix(shallow_color.rgb, deep_color.rgb, facing);
	METALLIC = 0.0;
	ROUGHNESS = 0.03;
	SPECULAR = 0.8;
	ALPHA = clarity;
}
