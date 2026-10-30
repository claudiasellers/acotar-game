// Small gatherables and keepsakes of the Manor Estate (R3: glossy, candy-bright).
// Albedo comes from vertex colour. Vertices with alpha < 0.6 are the sparkle
// glint: they glow and twinkle per instance so keepsakes catch the eye.
shader_type spatial;
render_mode cull_disabled;

global uniform float magic_amount;
uniform float glint_strength : hint_range(0.0, 8.0) = 3.0;
uniform float sway : hint_range(0.0, 0.3) = 0.06;

varying float v_glint;
varying float v_phase;

void vertex() {
	v_glint = COLOR.a < 0.6 ? 1.0 : 0.0;
	v_phase = float(INSTANCE_ID) * 1.7;
	// gentle sway for petals and stems, more toward the top
	float h = max(VERTEX.y, 0.0);
	VERTEX.x += sin(TIME * 1.6 + v_phase) * sway * h;
	VERTEX.z += cos(TIME * 1.3 + v_phase) * sway * h * 0.6;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = mix(0.45, 0.2, v_glint);
	SPECULAR = 0.6;
	RIM = 0.5;
	RIM_TINT = 0.6;
	float tw = 0.55 + 0.45 * sin(TIME * 3.1 + v_phase);
	EMISSION = COLOR.rgb * v_glint * glint_strength * tw * (0.5 + 0.5 * magic_amount);
}
