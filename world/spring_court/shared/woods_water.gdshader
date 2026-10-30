// Water for the woods: candy-clear turquoise in the pretty woods (rule R3),
// black and still where the horror lives (set the colours and sparkle off).
shader_type spatial;
render_mode cull_disabled, depth_draw_always, specular_schlick_ggx;

global uniform float magic_amount;

uniform vec4 shallow_color : source_color = vec4(0.55, 0.88, 0.86, 1.0);
uniform vec4 deep_color : source_color = vec4(0.30, 0.55, 0.78, 1.0);
uniform float clarity : hint_range(0.0, 1.0) = 0.55;
uniform float flow_speed = 0.35;
uniform float sparkle : hint_range(0.0, 1.0) = 0.6;
// Rainbow falls (ch. 23): hue bands that slide down the water.
uniform float rainbow : hint_range(0.0, 1.0) = 0.0;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ripple(vec2 p) {
	return sin(p.x * 1.7 + TIME * 1.3) * 0.5 + sin(p.y * 2.3 - TIME * 1.1) * 0.5;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 flow = wp.xz + vec2(0.0, TIME * flow_speed);
	EMISSION = vec3(0.0);
	float r = ripple(flow) * 0.5 + ripple(flow * 2.7) * 0.25;
	NORMAL = normalize(NORMAL + vec3(r * 0.08, 0.0, ripple(flow.yx) * 0.08));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(shallow_color.rgb, deep_color.rgb, fresnel);
	if (rainbow > 0.0) {
		float hue = fract(UV.y * 0.08 + UV.x * 0.3 - TIME * 0.25);
		vec3 bands = clamp(abs(fract(hue + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
		ALBEDO = mix(ALBEDO, mix(vec3(1.0), bands, 0.6), rainbow);
		EMISSION += bands * rainbow * 0.6 * magic_amount;
	}
	ALPHA = mix(clarity, 0.95, fresnel);
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	float s = sparkle * magic_amount;
	float h = hash2(floor(wp.xz * 6.0 + vec2(floor(TIME * 3.0))));
	EMISSION += vec3(1.0, 0.95, 0.88) * step(0.992, h) * s * 2.5;
}
