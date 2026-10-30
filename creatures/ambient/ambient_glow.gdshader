// Faelights and fireflies: soft round motes of warm light, one MultiMesh.
// Camera-facing, additive, with a gentle per-mote pulse. COLOR is the tint.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float glow = 1.0;
uniform float pulse_speed = 1.7;

varying vec3 tint;
varying float pulse;

void vertex() {
	tint = COLOR.rgb;
	float phase = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453) * 6.2831;
	pulse = 0.65 + 0.35 * sin(TIME * pulse_speed + phase);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	// A small hot core inside a wide soft halo: a mote, never a square.
	float core = smoothstep(0.3, 0.0, d);
	float halo = pow(clamp(1.0 - d, 0.0, 1.0), 2.2) * 0.45;
	float a = (core * 0.8 + halo) * pulse * glow;
	ALBEDO = mix(tint, vec3(1.0), core * 0.12) * a;
	ALPHA = clamp(a, 0.0, 1.0);
}
