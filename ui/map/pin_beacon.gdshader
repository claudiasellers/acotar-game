// The player's pin in the world: a soft faelight beam, brightest at the
// ground and melting upward, with drifting glints (R3). Additive, unlit.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.86, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.92, 0.66, 1.0);
// 0 hidden, 1 full; fades as Feyre gets close.
uniform float strength = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float h = UV.y;  // 0 top, 1 ground on Godot's cylinder
	float rise = pow(h, 2.2);
	// Soft edges: brighter facing the camera, fading at the silhouette.
	float facing = pow(abs(dot(NORMAL, VIEW)), 1.6);
	float shimmer = 0.75 + 0.25 * sin(TIME * 1.7 + UV.y * 9.0);
	// Glints drifting up the beam.
	vec2 cell = floor(vec2(UV.x * 24.0, UV.y * 60.0 + TIME * 3.0));
	float glint = step(0.97, hash(cell)) * 0.9;
	vec3 col = mix(tint.rgb, glow.rgb, rise * 0.6 + glint);
	ALBEDO = col * (rise * facing * shimmer + glint * h) * strength * 1.3;
}
