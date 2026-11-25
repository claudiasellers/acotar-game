// A lampwing (bestiary §8, lane L83): one small moth, drawn forty to eighty at
// a time as a MultiMesh, so it is posed here and not by a skeleton.
//
// Four numbers pose it, the same ones data/animation/creatures/lampwing_states.txt
// lists for each beat (roost, feed, flutter, swarm, bite, scatter, fall):
//   fold   0 = wings out and beating, 1 = shut upright over its back (grey undersides out)
//   rate   how fast it beats, 1 = ordinary flight
//   mouth  0 = shut, 1 = the snout split four ways
//   light  0 = dark, 1 = lit from within
// With `per_instance` on they come from the MultiMesh's custom data
// (INSTANCE_CUSTOM = fold, rate, mouth, light); off, from the uniforms.
// The MultiMesh instance colour tints the wings.
//
// `light` is 0 unless the swarm's code raises it: a lampwing is dark by day.
// It is the only thing here that glows.
//
// The mesh says what each vertex is (tools/blender/monsters/lampwing.py):
// UV2.x = how far out along a wing, UV2.y = how far along a mouth lobe, and the
// quarter of the atlas its UV is in: fore wing, hind wing, body, small parts.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://world/shared/shaders/candy_rim.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool per_instance = false;
uniform float fold : hint_range(0.0, 1.0) = 0.0;
uniform float rate : hint_range(0.0, 3.0) = 1.0;
uniform float mouth : hint_range(0.0, 1.0) = 0.0;
uniform float light : hint_range(0.0, 1.0) = 0.0;
uniform float flap_speed = 26.0;
uniform float flap_angle : hint_range(0.0, 1.5) = 0.95;
uniform vec3 under_color : source_color = vec3(0.4, 0.37, 0.39);
uniform vec3 sheen_a : source_color = vec3(0.85, 0.55, 0.75);
uniform vec3 sheen_b : source_color = vec3(0.5, 0.8, 0.78);
uniform float sheen : hint_range(0.0, 1.0) = 0.3;
uniform vec3 light_color : source_color = vec3(1.0, 0.78, 0.66);
uniform float light_energy = 2.4;
uniform float translucency : hint_range(0.0, 1.0) = 0.45;

// tools/blender/monsters/lampwing.py: HINGE and MOUTH, in this engine's axes
const vec3 HINGE = vec3(0.0055, 0.004, -0.008);
const vec2 MOUTH_AT = vec2(0.0, 0.001);

varying float v_wing;
varying float v_light;
varying float v_fold;

void vertex() {
	vec4 pose = per_instance ? INSTANCE_CUSTOM : vec4(fold, rate, mouth, light);
	float out_along = UV2.x;
	bool hind = UV.x > 0.5 && UV.y < 0.5;   // the atlas is flipped top to bottom on import
	float side = sign(VERTEX.x);
	float phase = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453) * 6.2831;
	float t = TIME * flap_speed * pose.y + phase - (hind ? 0.5 : 0.0);
	float beat = sin(t) * flap_angle + 0.22;
	float a = mix(beat, 1.5, pose.x);
	if (out_along > 0.0) {
		vec3 h = vec3(HINGE.x * side, HINGE.y, HINGE.z + (hind ? 0.004 : 0.0));
		vec3 p = VERTEX - h;
		// shut, the wings sweep back a little before they close
		float sweep = pose.x * (hind ? 0.1 : 0.3) * side;
		p = vec3(p.x * cos(sweep) - p.z * sin(sweep), p.y, p.x * sin(sweep) + p.z * cos(sweep));
		float bend = a * (0.72 + 0.28 * out_along) * side;
		vec3 n = NORMAL;
		p = vec3(p.x * cos(bend) - p.y * sin(bend), p.x * sin(bend) + p.y * cos(bend), p.z);
		NORMAL = vec3(n.x * cos(bend) - n.y * sin(bend), n.x * sin(bend) + n.y * cos(bend), n.z);
		// shut wings lie against each other, not through each other
		p.x += side * 0.0012 * pose.x;
		VERTEX = h + p;
	}
	// the body rides against the beat
	VERTEX.y -= sin(t) * 0.003 * (1.0 - pose.x) * min(pose.y, 1.0);
	float lobe = UV2.y;
	if (lobe > 0.0) {
		vec2 d = VERTEX.xy - MOUTH_AT;
		float len = max(length(d), 0.0001);
		VERTEX.xy += d / len * lobe * pose.z * 0.0115;
		VERTEX.z += lobe * lobe * pose.z * 0.0075;
	}
	v_wing = out_along;
	v_light = pose.w;
	v_fold = pose.x;
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	bool wing = UV.y < 0.5;
	bool body = UV.y >= 0.5 && UV.x < 0.5;
	bool wet = UV.y >= 0.5 && UV.y < 0.75 && UV.x >= 0.5;
	float rough = 0.7;
	if (wing) {
		float grey = dot(base, vec3(0.299, 0.587, 0.114));
		if (FRONT_FACING) {
			base *= COLOR.rgb;
			// the dust on them: two colours that trade places as it turns (lit, not glowing)
			float f = candy_fresnel(NORMAL, VIEW, 2.0);
			base = mix(base, mix(sheen_a, sheen_b, f) * 0.85, sheen * f);
			rough = 0.42;
		} else {
			base = under_color * (0.6 + 1.1 * grey);
			rough = 0.85;
		}
		BACKLIGHT = base * translucency;
	} else if (wet) {
		rough = 0.12;
	}
	ALBEDO = base;
	ROUGHNESS = rough;
	SPECULAR = wet ? 0.8 : 0.4;
	// lit from within: the body, and the wings near it
	float lit = body ? 1.0 : (wing ? pow(1.0 - v_wing, 2.0) * 0.6 + 0.08 : 0.0);
	EMISSION = light_color * light_energy * v_light * lit;
}
