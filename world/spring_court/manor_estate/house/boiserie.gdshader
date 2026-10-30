// Rococo boiserie for the manor's state rooms (experience bar §2.6): pale
// pastel panelling with gilded mouldings, painted procedurally in world space
// so every wall box of a room shares one material per colour.
//   skirting -> lower panels -> gilt dado rail -> tall upper panels with
//   rounded (rocaille) corners and a gilt rosette -> cornice under the ceiling.
// Panels repeat every panel_width metres along the wall; height is measured
// from the storey's floor (floor0 + n * storey).
shader_type spatial;
render_mode cull_back;

uniform vec4 wall_color : source_color = vec4(1.0, 0.88, 0.9, 1.0);
uniform vec4 frame_color : source_color = vec4(0.984, 0.969, 0.949, 1.0);
uniform vec4 gilt : source_color = vec4(0.902, 0.753, 0.408, 1.0);
uniform float floor0 = 0.0;
uniform float storey = 4.8;
uniform float wall_height = 4.5;
uniform float panel_width = 1.6;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// 1 on a band of half-width w around d = 0, anti-aliased.
float band(float d, float w) {
	float aa = max(fwidth(d), 0.0005);
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

void fragment() {
	vec3 field = wall_color.rgb;
	vec3 frame = mix(field, frame_color.rgb, 0.6);
	vec3 col = frame;
	float g = 0.0;          // gilt mask
	float shade = 1.0;      // fake relief
	if (abs(wnrm.y) < 0.5) {
		float along = abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x;
		float h = mod(wpos.y - floor0 + 0.001, storey);
		float u = (fract(along / panel_width) - 0.5) * panel_width;
		float top = wall_height - 0.5;
		if (h < 0.2) {
			col = mix(field, frame, 0.3) * 0.86;
		} else if (h < 0.9) {
			float d = sd_round_box(vec2(u, h - 0.56), vec2(panel_width * 0.5 - 0.14, 0.24), 0.05);
			col = d < 0.0 ? field : frame;
			g = band(d + 0.02, 0.009);
			shade = d < 0.0 ? mix(0.9, 1.0, smoothstep(0.0, 0.06, -d)) : 1.0;
		} else if (h < 1.02) {
			col = frame_color.rgb;
			shade = mix(0.92, 1.04, smoothstep(0.9, 1.0, h));
		} else if (h < top) {
			float cy = (1.02 + top) * 0.5;
			vec2 half_size = vec2(panel_width * 0.5 - 0.16, (top - 1.02) * 0.5 - 0.16);
			vec2 p = vec2(u, h - cy);
			float d = sd_round_box(p, half_size, 0.28);
			// a shallow arch on the panel's top edge
			float arch = length((p - vec2(0.0, half_size.y - 0.15)) / vec2(half_size.x * 0.75, 0.32)) - 1.0;
			d = min(d, max(arch * 0.2, -(p.y - half_size.y + 0.4)));
			col = d < 0.0 ? mix(field, frame_color.rgb, 0.18 + 0.12 * smoothstep(-0.6, 0.6, p.y / half_size.y)) : frame;
			g = band(d + 0.025, 0.011);
			// inner fillet and a rosette at the head of each panel
			g = max(g, band(d + 0.09, 0.004) * 0.7);
			float ro = length(p - vec2(0.0, half_size.y - 0.32));
			g = max(g, band(ro - 0.07, 0.012));
			g = max(g, 1.0 - smoothstep(0.025, 0.03, ro));
			shade = d < 0.0 ? mix(0.9, 1.0, smoothstep(0.0, 0.08, -d)) : 1.0;
		} else {
			col = mix(frame_color.rgb, field, 0.15);
			shade = mix(1.0, 1.08, smoothstep(top, wall_height, h));
		}
		// gilt rails: top of skirting, both edges of the dado, the cornice
		g = max(g, band(h - 0.2, 0.012));
		g = max(g, band(h - 0.9, 0.01));
		g = max(g, band(h - 1.02, 0.014));
		g = max(g, band(h - top, 0.016));
		g = max(g, band(h - (top + 0.18), 0.008));
	}
	ALBEDO = mix(col * shade, gilt.rgb, g);
	METALLIC = 0.85 * g;
	ROUGHNESS = mix(0.82, 0.3, g);
	SPECULAR = 0.4;
}
