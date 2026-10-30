// The Wall: a barely-there heat haze on a tall strip along z = 1400.
// Bends what is behind it a little and lifts a cold glint; `near` (0..1) is
// set by WallShimmer when Feyre is close, making it easier to see.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float near : hint_range(0.0, 1.0) = 0.0;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.035;
uniform float near_alpha : hint_range(0.0, 1.0) = 0.22;
uniform float distortion = 0.006;
uniform vec4 tint : source_color = vec4(0.86, 0.92, 1.0, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float wave(vec2 p, float t) {
	return sin(p.x * 0.9 + t * 1.7) * 0.5 + sin(p.y * 1.3 - t * 2.3 + p.x * 0.4) * 0.35 + sin((p.x + p.y) * 2.7 + t * 3.1) * 0.15;
}

void fragment() {
	float t = TIME;
	vec2 p = world_pos.xy;
	vec2 off = vec2(wave(p, t), wave(p.yx + 13.0, t * 1.1)) * distortion * (0.5 + near);
	vec3 behind = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	// Fade at the bottom (ground) and top of the strip.
	float v = UV.y;
	float fade = smoothstep(0.0, 0.08, 1.0 - v) * smoothstep(1.0, 0.35, 1.0 - v);
	float shimmer = 0.5 + 0.5 * wave(p * 0.35, t * 0.6);
	ALBEDO = mix(behind, tint.rgb, 0.12 + 0.25 * near * shimmer);
	ALPHA = clamp((base_alpha + near_alpha * near) * fade * (0.6 + 0.4 * shimmer), 0.0, 1.0);
}
