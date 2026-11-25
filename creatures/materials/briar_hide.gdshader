// A plant-monster's hide (the briarling, lane L83): the same baked albedo,
// normal and ORM maps as monster_hide, but drawn on both sides, because its
// leaves and petals are single sheets, and with a little light let through
// them. Its sheets (leaves, petals, thorns) share painted swatches in a strip
// down the right of the atlas (UV.x >= strip): there the map is detail only and
// the colour is the vertex colour, the same one the court's foliage material
// shows when the briarling is a bush. Nothing here glows: there is no EMISSION. `dull` (0..1) greys it (an
// ash arrow's mortal wound, or burning down to char).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
// Shared rim curve of the candy_lit family (render program T2).
#include "res://world/shared/shaders/candy_rim.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;

uniform float normal_depth : hint_range(0.0, 2.0) = 1.0;
uniform float roughness_scale : hint_range(0.0, 2.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.4;
uniform vec3 rim_color : source_color = vec3(0.7, 0.8, 0.6);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.2;
uniform float rim_power : hint_range(1.0, 8.0) = 3.5;
uniform float backlight : hint_range(0.0, 1.0) = 0.25;
// tools/blender/monsters/briarling.py: STRIP and NEUTRAL
const float STRIP = 0.755;
const float NEUTRAL = 0.6;

instance uniform float dull : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float sheet = step(STRIP, UV.x);
	base = mix(base, COLOR.rgb * base / NEUTRAL, sheet);
	vec3 orm = texture(orm_tex, UV).rgb;
	float grey = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(base, vec3(grey) * 0.8 + 0.01, dull * 0.8);
	float rim = candy_fresnel(NORMAL, VIEW, rim_power) * (1.0 - dull);
	base = mix(base, rim_color, clamp(rim * rim_amount * 0.35 * orm.r, 0.0, 1.0));
	ALBEDO = base;
	ROUGHNESS = mix(clamp(orm.g * roughness_scale, 0.03, 1.0), 0.95, dull);
	METALLIC = orm.b;
	SPECULAR = specular * (1.0 - 0.7 * dull);
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.35;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	BACKLIGHT = base * backlight * sheet * (1.0 - dull);
}
