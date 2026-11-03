// candy_surface: the BaseMaterial3D-shaped surface on top of candy_lit.
// CandyMaterial (world/shared/shaders/candy_material.gd) drives these uniforms
// with the same property names BaseMaterial3D had, so runtime code and
// imported glbs keep their colours. The variant wrapper sets render_mode and:
//   CANDY_UNSHADED, CANDY_ALPHA (blend), CANDY_SCISSOR, CANDY_BILLBOARD plus one of
//   CANDY_BILLBOARD_VIEW / _Y / _PARTICLES, CANDY_KEEP_SCALE, CANDY_NORMAL_MAP, CANDY_WIND,
//   CANDY_PROXIMITY_FADE, CANDY_COAT.

#ifndef CANDY_UNSHADED
#ifndef CANDY_NO_SPEC_LOBE
#define CANDY_LOBES
#endif
#include "res://world/shared/shaders/candy_lit.gdshaderinc"
#else
global uniform float magic_amount;
#endif
#ifdef CANDY_WIND
#include "res://world/shared/shaders/foliage_wind.gdshaderinc"
uniform float flex_height = 1.0;
#endif

group_uniforms surface;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform bool vertex_color_use_as_albedo = false;
uniform bool vertex_color_is_srgb = false;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
// ORM packing as glTF stores it: G roughness, B metallic. White = no change.
uniform sampler2D orm_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float grow = 0.0;
group_uniforms emission;
uniform bool emission_enabled = false;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy_multiplier : hint_range(0.0, 16.0) = 1.0;
uniform sampler2D emission_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
group_uniforms lobes;
// Godot's own light rim and clearcoat (BaseMaterial3D rim/clearcoat).
uniform float rim : hint_range(0.0, 1.0) = 0.0;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.5;
uniform float clearcoat : hint_range(0.0, 1.0) = 0.0;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.5;
group_uniforms candy_sparkle;
// Pearlescent sheen and glitter: off at 0, scaled by magic_amount.
uniform float pearl : hint_range(0.0, 1.0) = 0.0;
uniform float glitter : hint_range(0.0, 1.0) = 0.0;
uniform float glitter_scale = 18.0;
uniform vec4 glitter_color : source_color = vec4(1.0, 0.93, 0.75, 1.0);
group_uniforms;
#ifdef CANDY_PROXIMITY_FADE
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float proximity_fade_distance = 1.0;
#endif
#ifdef CANDY_NORMAL_MAP
uniform sampler2D normal_texture : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
#endif

varying vec3 candy_world_pos;

float candy_hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	if (grow != 0.0) {
		VERTEX += NORMAL * grow;
	}
#ifdef CANDY_WIND
	VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, smoothstep(0.0, flex_height, VERTEX.y));
#endif
	candy_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
#if defined(CANDY_BILLBOARD_VIEW)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(MAIN_CAM_INV_VIEW_MATRIX[0], MAIN_CAM_INV_VIEW_MATRIX[1], MAIN_CAM_INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
#elif defined(CANDY_BILLBOARD_Y)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), MAIN_CAM_INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(MAIN_CAM_INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
#elif defined(CANDY_BILLBOARD_PARTICLES)
	mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	mat_world = mat_world * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
#endif
#if defined(CANDY_BILLBOARD) && defined(CANDY_KEEP_SCALE)
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
#endif
#ifdef CANDY_BILLBOARD
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
#endif
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec4 col = albedo_color * tex;
	if (vertex_color_use_as_albedo) {
		vec4 vc = COLOR;
		if (vertex_color_is_srgb) {
			vc.rgb = mix(pow((vc.rgb + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), vc.rgb * (1.0 / 12.92), lessThan(vc.rgb, vec3(0.04045)));
		}
		col *= vc;
	}
	float magic = clamp(magic_amount, 0.0, 1.0);
	vec3 emit = vec3(0.0);
	if (emission_enabled) {
		emit = (emission.rgb + texture(emission_texture, UV).rgb) * emission_energy_multiplier;
	}
	if (pearl > 0.0) {
		float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		vec3 iri = 0.5 + 0.5 * cos(6.2831 * (f * 0.8 + vec3(0.0, 0.33, 0.67)));
		col.rgb = mix(col.rgb, col.rgb * mix(vec3(1.0), iri * 1.2, 0.5), f * pearl * magic);
	}
	if (glitter > 0.0) {
		float g = glitter * magic;
		float hsh = candy_hash(floor(candy_world_pos * glitter_scale));
		emit += glitter_color.rgb * step(0.985 - g * 0.03, hsh) * (0.5 + 0.5 * sin(TIME * 6.0 + hsh * 40.0)) * 3.0;
	}
	ALBEDO = col.rgb;
#ifndef CANDY_UNSHADED
	vec4 orm = texture(orm_texture, UV);
	ROUGHNESS = roughness * orm.g;
	METALLIC = metallic * orm.b;
	EMISSION = emit + candy_rim_emission(NORMAL, VIEW);
#ifdef CANDY_LOBES
	candy_lobes(specular, rim, rim_tint);
#endif
#ifdef CANDY_COAT
	candy_coat(clearcoat, clearcoat_roughness);
#endif
#ifdef CANDY_NORMAL_MAP
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
#endif
#endif
#if defined(CANDY_ALPHA) || defined(CANDY_SCISSOR)
	ALPHA = col.a;
#endif
#ifdef CANDY_PROXIMITY_FADE
	float depth_tex = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 depth_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex, 1.0);
	depth_pos.xyz /= depth_pos.w;
	ALPHA *= clamp(1.0 - smoothstep(depth_pos.z + proximity_fade_distance, depth_pos.z, VERTEX.z), 0.0, 1.0);
#endif
#ifdef CANDY_SCISSOR
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
#endif
}
