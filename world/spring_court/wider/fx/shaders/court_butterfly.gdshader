// Butterfly draw pass: a QuadMesh lying flat (orientation FACE_Y, subdivide_width 2)
// whose two halves flap around the body axis. Wing colour = particle COLOR.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert_wrap;

#include "res://world/spring_court/wider/fx/shaders/court_fx_common.gdshaderinc"

uniform float flap_speed = 15.0;
uniform float flap_angle : hint_range(0.0, 1.5) = 1.1;
uniform vec4 body_color : source_color = vec4(0.28, 0.2, 0.3, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform float shimmer : hint_range(0.0, 4.0) = 0.6;

varying float v_seed;

void vertex() {
	v_seed = court_hash12(vec2(float(INSTANCE_ID) * 0.31, 8.3));
	float a = (0.5 + 0.5 * sin(TIME * flap_speed * (0.8 + v_seed * 0.4) + v_seed * 30.0)) * flap_angle;
	float r = abs(VERTEX.x);
	VERTEX.y += r * sin(a);
	VERTEX.x = sign(VERTEX.x) * r * cos(a);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 q = vec2(abs(p.x), p.y);
	float upper = 1.0 - smoothstep(0.42, 0.5, length((q - vec2(0.48, -0.22)) * vec2(1.0, 1.15)));
	float lower = 1.0 - smoothstep(0.3, 0.38, length((q - vec2(0.36, 0.42)) * vec2(1.1, 1.0)));
	float body = (1.0 - smoothstep(0.05, 0.09, abs(p.x))) * (1.0 - smoothstep(0.7, 0.8, abs(p.y)));
	float wing = max(upper, lower);
	float rim_u = smoothstep(0.32, 0.46, length((q - vec2(0.48, -0.22)) * vec2(1.0, 1.15))) * upper;
	float spot = 1.0 - smoothstep(0.06, 0.1, length(q - vec2(0.55, -0.3)));
	vec3 col = COLOR.rgb;
	col = mix(col, edge_color.rgb, clamp(rim_u * 0.8 + spot * 0.9, 0.0, 1.0));
	col = mix(col, body_color.rgb, body);
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = col;
	EMISSION = court_pastel_rainbow(fres + v_seed) * fres * shimmer * wing + col * 0.15;
	ROUGHNESS = 0.5;
	ALPHA = clamp(max(wing, body) * COLOR.a, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
