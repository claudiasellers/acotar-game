// The manor's ward: a glamour veil, nearly invisible from afar, a soft
// rose-gold shimmer that ripples as Feyre nears it and rings out where she
// touches it. `fade` takes it away when the grounds unlock.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.62, 0.72, 1.0);
uniform vec4 glint : source_color = vec4(1.0, 0.84, 0.5, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec3 player_position = vec3(0.0, -1000.0, 0.0);
// Where she last touched it, and how many seconds ago.
uniform vec3 contact_position = vec3(0.0, -1000.0, 0.0);
uniform float contact_age = 100.0;
uniform float near_distance = 6.0;
uniform float far_distance = 40.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = distance(world_pos, player_position);
	float near = smoothstep(far_distance, near_distance, d);
	// Slow vertical ripples with a finer glitter weave.
	float ripple = 0.5 + 0.5 * sin(world_pos.x * 0.9 + world_pos.z * 0.9 - TIME * 1.6 + sin(world_pos.y * 0.7 + TIME));
	float weave = 0.5 + 0.5 * sin(world_pos.y * 3.1 + TIME * 2.3) * sin((world_pos.x + world_pos.z) * 2.7);
	// A ring that runs out from the contact point for about a second.
	float age = contact_age;
	float ring_r = age * 7.0;
	float cd = distance(world_pos, contact_position);
	float ring = (1.0 - smoothstep(0.0, 1.2, abs(cd - ring_r))) * (1.0 - smoothstep(0.0, 1.2, age));
	// Brightest low down, dissolving towards the top.
	float rise = 1.0 - smoothstep(0.55, 1.0, UV.y);
	float a = (0.02 + near * (0.08 + 0.16 * ripple) + 0.08 * near * weave) * rise + ring * 0.8;
	vec3 col = mix(tint.rgb, glint.rgb, weave * 0.5 + ring * 0.5);
	ALBEDO = col * 1.25;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
