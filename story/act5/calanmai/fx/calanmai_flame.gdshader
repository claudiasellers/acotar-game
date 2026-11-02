// A flame tongue on an upright card (CalanmaiFire). The card turns about its
// own vertical axis to face the camera, so the fire keeps its height from any
// side. The tongue is noise-sheared and ragged at the tip, hottest low in the
// middle, and capped: the brightest channel stays near 1.0 per card, so a
// stack of cards blooms orange under ACES instead of clipping to white.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.74, 0.34, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.40, 0.09, 1.0);
uniform vec4 edge_color : source_color = vec4(0.55, 0.11, 0.02, 1.0);
uniform float speed = 1.5;
instance uniform float seed = 0.0;
instance uniform float gain = 0.7;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int k = 0; k < 4; k++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	to_cam.y = 0.0;
	to_cam = length(to_cam) > 0.0001 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
	vec3 right = vec3(to_cam.z, 0.0, -to_cam.x);
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 wp = origin + right * VERTEX.x * sx + vec3(0.0, VERTEX.y * sy, 0.0) + to_cam * 0.001 * seed;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	float h = 1.0 - UV.y;
	float x = UV.x * 2.0 - 1.0;
	float t = TIME * speed + seed * 17.0;
	float n = fbm(vec2(x * 1.4 + seed * 5.0, h * 2.4 - t));
	float n2 = fbm(vec2(x * 3.1 - seed * 2.0, h * 4.6 - t * 1.7));
	// It sways and licks: more at the top than at the root.
	float xs = x + (n - 0.5) * 1.1 * h + sin(t * 1.3 + h * 3.0 + seed) * 0.07 * h;
	float w = 0.66 * pow(clamp(1.0 - h, 0.0, 1.0), 0.6) * (0.8 + 0.4 * n2) * (0.55 + 0.45 * smoothstep(0.0, 0.22, h));
	float body = 1.0 - smoothstep(w * 0.3, w, abs(xs));
	// The tip tears off in licks; the root fades into the embers.
	float tip = smoothstep(0.0, 0.22, (0.5 + n * 0.75) - h);
	float root = smoothstep(0.0, 0.16, h + (n2 - 0.5) * 0.08);
	float m = clamp(body * tip * root, 0.0, 1.0);
	float heat = clamp(m * (1.25 - h * 1.1) * (0.75 + 0.5 * n2), 0.0, 1.0);
	vec3 col = mix(edge_color.rgb, mid_color.rgb, smoothstep(0.1, 0.45, heat));
	col = mix(col, core_color.rgb, smoothstep(0.5, 0.95, heat));
	ALBEDO = col * gain;
	ALPHA = m * smoothstep(0.02, 0.2, heat);
}
