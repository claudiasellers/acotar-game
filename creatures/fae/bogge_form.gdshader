// The Bogge's body, dissolved by how real it has become (bogge.gd `reveal`).
// At 0 it is a faint darker patch the eye slides off; on a glance it half
// forms as drifting fragments of shadow; at 1 it is solid, wet-rimmed dark.
// Eyes (is_eye) only come on once it is mostly there.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform vec4 albedo : source_color = vec4(0.03, 0.028, 0.026, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform bool is_eye = false;
uniform vec3 eye_color : source_color = vec3(0.86, 0.9, 0.62);
uniform float eye_energy = 5.0;
// Size of the shadow fragments it forms from, in metres.
uniform float grain = 0.35;

varying vec3 local_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// Fragments that drift slowly upward, like smoke that has not decided.
	vec3 p = local_pos / grain + vec3(0.0, -TIME * 0.25, 0.0);
	float n = noise(p) * 0.65 + noise(p * 2.7) * 0.35;
	// The core (spine, head) gathers first; the reaching limbs last.
	float core = clamp(length(local_pos.xz) / 1.6, 0.0, 1.0) * 0.35;
	float c = reveal * 1.35 - core;
	float edge = c - n;
	if (is_eye) {
		float on = clamp(reveal * 1.6 - 0.2, 0.0, 1.0);
		ALBEDO = eye_color;
		EMISSION = eye_color * eye_energy * on;
		ALPHA = on;
	} else {
		ALBEDO = albedo.rgb * mix(0.25, 1.0, smoothstep(0.0, 0.25, edge));
		ROUGHNESS = roughness;
		METALLIC = 0.3;
		RIM = 0.9 * reveal;
		RIM_TINT = 0.2;
		// Unformed: a barely darker patch. Forming: ragged, smoky edges.
		ALPHA = edge > 0.0 ? mix(0.55, 0.97, smoothstep(0.0, 0.2, edge)) : 0.04 * (1.0 - smoothstep(-0.3, 0.0, edge)) + 0.04;
	}
}
