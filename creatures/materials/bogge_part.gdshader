// A piece of the Bogge's half-seen kit (bestiary 4.3; tools/blender/monsters/bogge.py):
// claws, a jaw or an eye pushing out of its shimmer. The part is modelled
// coming through the plane z = 0 of its own space toward -Z, and whatever is
// still behind that plane is not drawn, so the `surface` and `sink` clips
// only slide it through. The cut edge is ragged and rimed, never a clean
// slice. `presence` (0..1, per instance) thins the whole part away for the
// code's own fades; 1 by default.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://world/shared/shaders/candy_rim.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D emit_tex : source_color, hint_default_black, filter_linear_mipmap, repeat_disable;

uniform float normal_depth : hint_range(0.0, 2.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.6;
uniform vec3 rim_color : source_color = vec3(0.55, 0.68, 0.8);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.35;
uniform float rim_power : hint_range(1.0, 8.0) = 3.0;
uniform float emit_base = 0.0;
// How far in front of the plane the part is still ragged and thin (metres).
uniform float edge_depth : hint_range(0.005, 0.2) = 0.06;
uniform vec3 edge_color : source_color = vec3(0.6, 0.72, 0.85);
uniform float edge_glow : hint_range(0.0, 2.0) = 0.35;

instance uniform float presence : hint_range(0.0, 1.0) = 1.0;

varying vec3 at;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x), mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x), mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	at = VERTEX;
}

void fragment() {
	// 0 at the plane, 1 once it is `edge_depth` clear of it
	float out_of = clamp(-at.z / edge_depth, -1.0, 1.0);
	float grain = vnoise(at * 90.0) * 0.6 + vnoise(at * 260.0 + TIME * 0.7) * 0.4;
	float there = out_of * 1.4 - grain * 0.9 + (presence - 1.0) * 1.6 + 0.1;
	if (there <= 0.0) {
		discard;
	}
	float edge = 1.0 - smoothstep(0.0, 0.35, there);
	vec3 orm = texture(orm_tex, UV).rgb;
	ALBEDO = mix(texture(albedo_tex, UV).rgb, edge_color * 0.6, edge * 0.7);
	ROUGHNESS = mix(clamp(orm.g, 0.03, 1.0), 0.8, edge);
	METALLIC = orm.b;
	SPECULAR = specular;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.35;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	float rim = candy_fresnel(NORMAL, VIEW, rim_power);
	EMISSION = rim_color * rim * rim_amount * 0.35 * orm.r + texture(emit_tex, UV).rgb * emit_base + edge_color * edge * edge_glow;
}
