// Butterflies and faelights in one MultiMesh. The MultiMesh instance colour
// is the tint (it arrives in COLOR). Wing weight comes from distance off the
// body's long axis, so wings flap about the body while the body stays still.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;

uniform float flap_speed = 14.0;
uniform float flap_angle = 1.1;
uniform float glow = 0.0;
uniform float translucency = 0.35;
// Half wingspan of the mesh in metres (0.065 butterfly, 0.028 faelight).
uniform float wing_span = 0.065;
uniform vec3 body_color : source_color = vec3(0.16, 0.13, 0.15);

varying float wing;
varying vec3 tint;

void vertex() {
	float span = abs(VERTEX.x);
	wing = clamp(span / wing_span, 0.0, 1.0);
	tint = COLOR.rgb;
	float phase = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453) * 6.2831;
	float a = sin(TIME * flap_speed + phase) * flap_angle * wing;
	VERTEX = vec3(sign(VERTEX.x) * span * cos(a), VERTEX.y + span * sin(a), VERTEX.z);
}

void fragment() {
	float on_wing = smoothstep(0.08, 0.25, wing);
	ALBEDO = mix(body_color, tint, max(on_wing, glow));
	ROUGHNESS = 0.55;
	EMISSION = tint * glow * 3.0;
	BACKLIGHT = tint * translucency;
}
