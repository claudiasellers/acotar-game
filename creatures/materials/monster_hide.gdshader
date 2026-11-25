// The hide of a monster built by tools/blender/monsters (lane L83): baked
// albedo, normal, ORM and emission maps plus a mask map that marks what the
// game changes at run time:
//   mask.r  the glint zone (talons, beak, teeth): flashes with `glint`, the
//           tell before an attack (bestiary 1.5)
//   mask.g  the seams between scales: take `seam_tint`, one undertone per individual
//   mask.b  a scar only some individuals carry: shown by `scar`
// `dull` (0..1) kills the sheen (an ash arrow's mortal wound).
// Nothing here glows on its own. The rim and the glint are lit: they change
// albedo, specular and roughness, never EMISSION. The emission map shows only
// through `eye_glow`, an instance value that is 0 by default and that the
// creature's code raises at night or once the glamour has lifted; `emit_base`
// is how bright the map is at eye_glow 1, and `emit_drift` makes that light
// crawl slowly, like something swirling.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Shared rim curve of the candy_lit family (render program T2).
#include "res://world/shared/shaders/candy_rim.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D emit_tex : source_color, hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap, repeat_disable;

uniform float normal_depth : hint_range(0.0, 2.0) = 1.0;
uniform float roughness_scale : hint_range(0.0, 2.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform vec3 rim_color : source_color = vec3(0.55, 0.66, 0.7);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.25;
uniform float rim_power : hint_range(1.0, 8.0) = 3.5;
uniform float seam_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 scar_color : source_color = vec3(0.33, 0.25, 0.24);
uniform vec3 glint_color : source_color = vec3(0.9, 0.95, 1.0);
uniform float glint_strength = 2.5;
uniform float emit_base = 1.0;
uniform float emit_drift : hint_range(0.0, 1.0) = 0.0;

instance uniform vec3 seam_tint : source_color = vec3(0.035, 0.075, 0.07);
instance uniform float scar : hint_range(0.0, 1.0) = 0.0;
instance uniform float dull : hint_range(0.0, 1.0) = 0.0;
instance uniform float glint : hint_range(0.0, 1.0) = 0.0;
instance uniform float eye_glow = 0.0;

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	vec3 orm = texture(orm_tex, UV).rgb;
	vec3 mask = texture(mask_tex, UV).rgb;
	float scarred = mask.b * scar;
	base = mix(base, seam_tint, mask.g * seam_amount);
	base = mix(base, scar_color, scarred);
	// An ash-struck hide greys and loses its light.
	float grey = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(base, vec3(grey) * 1.15 + 0.012, dull * 0.7);
	float rough = clamp(orm.g * roughness_scale, 0.03, 1.0);
	rough = mix(rough, 0.85, scarred);
	rough = mix(rough, 0.95, dull);
	float spec = specular * (1.0 - 0.7 * dull);
	// Smooth parts catch the rim; the seams stay dark, so scale edges read.
	float rim = candy_fresnel(NORMAL, VIEW, rim_power) * (1.0 - mask.g) * (1.0 - dull);
	base = mix(base, rim_color, clamp(rim * rim_amount * 0.35 * orm.r, 0.0, 1.0));
	// The tell: the talon goes cold, hard and mirror-bright as `glint` rises.
	float tell = clamp(mask.r * glint * glint_strength * 0.4, 0.0, 1.0);
	base = mix(base, glint_color * 0.85, tell * 0.6);
	ALBEDO = base;
	ROUGHNESS = mix(rough, 0.06, tell);
	METALLIC = orm.b;
	SPECULAR = mix(spec, 1.0, tell);
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.35;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth * (1.0 - 0.6 * scarred);
	float drift = 1.0 - emit_drift * (0.5 + 0.5 * sin(TIME * 0.9 + UV.x * 310.0 + sin(TIME * 0.37 + UV.y * 240.0) * 2.0));
	EMISSION = texture(emit_tex, UV).rgb * emit_base * drift * eye_glow;
}
