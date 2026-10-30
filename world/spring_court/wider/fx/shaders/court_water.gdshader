// Spring Court water: pastel depth tint, fresnel, procedural ripples, soft foam,
// screen-space refraction and an optional daylight "starlight" sun-glitter mode
// for the Starlight Pool (sparkles in bright sunlight, Keeper lore correction).
shader_type spatial;
render_mode depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://world/spring_court/wider/fx/shaders/court_fx_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

uniform float blight : hint_range(0.0, 1.0) = 0.0;

uniform vec4 shallow_color : source_color = vec4(0.62, 0.93, 0.88, 1.0);
uniform vec4 deep_color : source_color = vec4(0.52, 0.56, 0.92, 1.0);
uniform vec4 fresnel_color : source_color = vec4(1.0, 0.86, 0.94, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 0.98, 1.0, 1.0);
uniform float depth_scale = 2.5;
uniform float clarity : hint_range(0.0, 1.0) = 0.55;
uniform float refraction_strength = 0.03;
uniform float ripple_scale = 0.35;
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.45;
uniform vec2 flow_dir = vec2(0.0, 0.0);
uniform float flow_speed = 0.0;
uniform float ripple_speed = 0.25;
uniform float foam_width = 0.45;
uniform float foam_strength : hint_range(0.0, 2.0) = 0.8;
uniform float fresnel_power = 4.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.06;
uniform float blight_affect : hint_range(0.0, 1.0) = 1.0;

uniform bool starlight_mode = false;
uniform float glitter_density = 6.0;
uniform float glitter_threshold : hint_range(0.5, 0.999) = 0.9;
uniform float glitter_strength : hint_range(0.0, 20.0) = 7.0;
uniform vec4 glitter_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);
uniform vec3 sun_dir_hint = vec3(0.3, 0.8, 0.4);

varying vec3 v_world_pos;

float water_height(vec2 p, float t) {
	vec2 flow = flow_dir * flow_speed * t;
	float a = court_fbm(p * ripple_scale + flow + vec2(t * ripple_speed, t * ripple_speed * 0.6));
	float b = court_fbm(p * ripple_scale * 1.9 - flow * 1.3 + vec2(-t * ripple_speed * 0.8, t * ripple_speed * 0.5) + 5.3);
	return a * 0.6 + b * 0.4;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	vec2 wp = v_world_pos.xz;
	float e = 0.12;
	float h0 = water_height(wp, t);
	float hx = water_height(wp + vec2(e, 0.0), t);
	float hz = water_height(wp + vec2(0.0, e), t);
	vec2 slope = vec2(hx - h0, hz - h0) / e * ripple_strength;
	vec3 n = normalize(NORMAL + TANGENT * slope.x * 0.35 + BINORMAL * slope.y * 0.35);
	NORMAL = n;

	// Water depth from the depth texture (view space).
	float raw_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	float scene_z = upos.z / upos.w;
	float water_depth = max(VERTEX.z - scene_z, 0.0);

	vec2 refr_uv = SCREEN_UV + slope * refraction_strength * clamp(water_depth, 0.0, 1.0);
	float refr_raw = texture(depth_tex, refr_uv).r;
	vec4 rpos = INV_PROJECTION_MATRIX * vec4(refr_uv * 2.0 - 1.0, refr_raw, 1.0);
	if (rpos.z / rpos.w > VERTEX.z) {
		refr_uv = SCREEN_UV; // refracted sample is in front of the water: avoid leaks
	}
	vec3 behind = texture(screen_tex, refr_uv).rgb;

	float depth_f = 1.0 - exp(-water_depth / max(depth_scale, 0.01));
	vec3 water_col = mix(shallow_color.rgb, deep_color.rgb, depth_f);
	vec3 col = mix(water_col, behind * shallow_color.rgb * 1.2, clarity * (1.0 - depth_f));

	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), fresnel_power);
	col = mix(col, fresnel_color.rgb, fres * 0.6);

	float foam_noise = court_vnoise(wp * 3.0 + vec2(t * 0.3, -t * 0.2));
	float foam = (1.0 - smoothstep(0.0, foam_width, water_depth)) * smoothstep(0.25, 0.75, foam_noise + 0.3);
	col = mix(col, foam_color.rgb, foam * foam_strength);

	vec3 emit = vec3(0.0);
	if (starlight_mode) {
		vec2 cell = floor(wp * glitter_density);
		float rnd = court_hash12(cell);
		vec2 f = fract(wp * glitter_density) - 0.5;
		float pt = exp(-dot(f, f) * 60.0);
		float tw = pow(0.5 + 0.5 * sin(t * (3.0 + rnd * 7.0) + rnd * 60.0), 6.0);
		// Sun glitter: strongest where ripple normals reflect the sun toward the camera.
		vec3 sun_v = normalize((VIEW_MATRIX * vec4(normalize(sun_dir_hint), 0.0)).xyz);
		vec3 refl = reflect(-VIEW, n);
		float sun_align = pow(clamp(dot(refl, sun_v), 0.0, 1.0), 4.0) * 0.7 + 0.3;
		float spark = step(glitter_threshold, rnd) * pt * tw * sun_align;
		emit += glitter_color.rgb * spark * glitter_strength;
		col += vec3(0.06, 0.05, 0.08) * fres;
	}

	float b = blight * blight_affect;
	col = court_blight_mix(col, b) * mix(1.0, 0.45, b);
	ALBEDO = col;
	ROUGHNESS = mix(roughness_value, 0.6, b);
	SPECULAR = 0.6;
	METALLIC = 0.0;
	EMISSION = emit * (1.0 - b) + foam * foam_color.rgb * 0.05;
}
