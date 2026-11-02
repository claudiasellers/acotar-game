// The player's pin in the world: a soft faelight beam, brightest at the
// ground and melting upward, with drifting glints (R3). Unlit, alpha-blended.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.86, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.92, 0.66, 1.0);
// 0 hidden, 1 full; fades as Feyre gets close.
uniform float strength = 1.0;

// Widen with distance so it stays a few dozen pixels wide from across the map.
uniform float widen_from = 70.0;

void vertex() {
	float d = length(INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz);
	VERTEX.xz *= max(1.0, d / widen_from);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float h = UV.y;  // 0 top, 1 ground on Godot's cylinder
	// Strong at the ground, still readable high up so it shows over the trees.
	float rise = 0.22 + 0.78 * pow(h, 1.4);
	// Soft edges: brighter facing the camera, fading at the silhouette.
	float facing = pow(abs(dot(NORMAL, VIEW)), 1.6);
	float shimmer = 0.75 + 0.25 * sin(TIME * 1.7 + UV.y * 9.0);
	// Glints drifting up the beam.
	vec2 g = vec2(UV.x * 24.0, UV.y * 60.0 + TIME * 3.0);
	vec2 cell = floor(g);
	// Round, soft glints rather than whole cells.
	float glint = step(0.97, hash(cell)) * 0.9 * smoothstep(0.5, 0.1, length(fract(g) - 0.5));
	vec3 col = mix(tint.rgb, glow.rgb, clamp((1.0 - rise) * 0.7 + glint, 0.0, 1.0));
	// Mixed rather than added, so it shows against snow and a pale sky too.
	ALBEDO = col;
	ALPHA = clamp((rise * facing * shimmer * 1.15 + glint * h) * strength, 0.0, 0.95);
}
