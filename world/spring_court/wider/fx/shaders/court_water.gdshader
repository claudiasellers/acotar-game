// Spring Court water: a clear depth tint (aqua shallows over blue depths), a
// sky-blue sheen at low angles, procedural ripples, a thin foam line at the
// waterline, screen-space refraction and an optional daylight "starlight"
// sun-glitter mode for the Starlight Pool (sparkles in bright sunlight, Keeper
// lore correction). A lake can carry the painted reflection of a wood on its
// far shore (mirror_*).
// The water keeps its own colour at every angle (owner, 2026-11-16: clear
// colours, never washed out). Seen along the surface, a lake used to turn into
// a sheet of the pale pink horizon: a mirror-smooth surface reflects all of
// the sky there, and the sheen colour was the horizon's too. So the sheen is
// the sky's blue, and the mirror is held to `mirror` (the most of the sky the
// surface gives back at the lowest angle is about 50 x 0.16 x mirror^2).
shader_type spatial;
render_mode depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;
// Shared rim curve of the candy_lit family (render program T2).
#include "res://world/shared/shaders/candy_rim.gdshaderinc"

#include "res://world/spring_court/wider/fx/shaders/court_fx_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

uniform float blight : hint_range(0.0, 1.0) = 0.0;

uniform vec4 shallow_color : source_color = vec4(0.30, 0.70, 0.74, 1.0);
uniform vec4 deep_color : source_color = vec4(0.16, 0.44, 0.76, 1.0);
uniform vec4 fresnel_color : source_color = vec4(0.46, 0.72, 0.95, 1.0);
// How far the surface goes to fresnel_color at the lowest angle.
uniform float sheen : hint_range(0.0, 1.0) = 0.4;
// The surface as a mirror of the sky (SPECULAR); see the note at the top.
uniform float mirror : hint_range(0.0, 1.0) = 0.2;
uniform vec4 foam_color : source_color = vec4(1.0, 0.98, 1.0, 1.0);
uniform float depth_scale = 2.5;
uniform float clarity : hint_range(0.0, 1.0) = 0.55;
uniform float refraction_strength = 0.03;
uniform float ripple_scale = 0.35;
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.45;
uniform vec2 flow_dir = vec2(0.0, 0.0);
uniform float flow_speed = 0.0;
uniform float ripple_speed = 0.25;
// Metres of water (along the view) the foam line fades over: a line at the
// waterline. On an eased shore 0.45 was a white band metres wide.
uniform float foam_width = 0.14;
uniform float foam_strength : hint_range(0.0, 2.0) = 0.6;
uniform float fresnel_power = 4.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.1;
uniform float blight_affect : hint_range(0.0, 1.0) = 1.0;

// A wood's reflection, painted (the water does not mirror trees): Looking
// Lake's far wood lying on the water (CourtGlenPlaces.mirror; CourtRegion sets
// these on the lake's own mesh). The wood is taken as a wall round part of a
// circle: xy the circle's middle (world x, z), z its radius, w the wood's
// height over the water. mirror_arc: x the bearing of the wood's middle, y its
// half-arc (radians). mirror_colour: rgb the colour, a how far the water goes
// to it (0: no reflection, the default).
instance uniform vec4 mirror_wood = vec4(0.0, 0.0, 0.0, 0.0);
instance uniform vec2 mirror_arc = vec2(0.0, 0.0);
instance uniform vec4 mirror_colour : source_color = vec4(0.07, 0.25, 0.2, 0.0);

uniform bool starlight_mode = false;
uniform float glitter_density = 6.0;
uniform float glitter_threshold : hint_range(0.5, 0.999) = 0.9;
uniform float glitter_strength : hint_range(0.0, 20.0) = 7.0;
uniform vec4 glitter_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);
uniform vec3 sun_dir_hint = vec3(0.3, 0.8, 0.4);
// Starlight Pool by night (0 day .. 1 night), driven by the pool's own node
// (story/act4/starlight_steep.gd): the water goes dark and clear and the sun
// glitter gives way to a still field of reflected stars.
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 night_deep : source_color = vec4(0.012, 0.02, 0.07, 1.0);
uniform vec4 night_shallow : source_color = vec4(0.04, 0.07, 0.16, 1.0);
uniform vec4 star_color : source_color = vec4(0.86, 0.9, 1.0, 1.0);

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

	float night = starlight_mode ? night_amount : 0.0;
	vec3 shallow_c = mix(shallow_color.rgb, night_shallow.rgb, night);
	vec3 deep_c = mix(deep_color.rgb, night_deep.rgb, night);
	float depth_f = 1.0 - exp(-water_depth / max(depth_scale, 0.01));
	vec3 water_col = mix(shallow_c, deep_c, depth_f);
	vec3 col = mix(water_col, behind * shallow_c * 1.2, clarity * (1.0 - depth_f));

	float fres = candy_fresnel(n, VIEW, fresnel_power);
	col = mix(col, mix(fresnel_color.rgb, night_shallow.rgb * 1.6, night), fres * mix(sheen, 0.6, night));

	if (mirror_colour.a > 0.0) {
		// where the eye's ray, turned back off the rippled surface, meets the wood
		vec3 view_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 n_w = normalize(vec3(-slope.x * 0.22, 1.0, -slope.y * 0.22));
		vec3 r = reflect(-view_w, n_w);
		float flat_len = length(r.xz);
		if (r.y > 0.0 && flat_len > 0.0001) {
			vec2 d = r.xz / flat_len;
			vec2 o = wp - mirror_wood.xy;
			float ob = dot(o, d);
			float disc = ob * ob - dot(o, o) + mirror_wood.z * mirror_wood.z;
			if (disc > 0.0) {
				float reach = -ob + sqrt(disc);
				vec2 hit = o + d * reach;
				// (the bearing as an offset from the wood's middle, so it does not wrap inside the arc)
				float off = mod(atan(hit.y, hit.x) - mirror_arc.x + PI, TAU) - PI;
				float in_arc = 1.0 - smoothstep(mirror_arc.y - 0.22, mirror_arc.y, abs(off));
				// the crowns' own outline: round heads of different heights along the wood
				float along = off * mirror_wood.z;
				float crowns = mirror_wood.w * (0.62 + 0.3 * court_vnoise(vec2(along * 0.11, 3.7)) + 0.12 * court_vnoise(vec2(along * 0.42, 9.1)));
				float up = reach * r.y / flat_len;
				float under = 1.0 - smoothstep(crowns - 1.2, crowns + 0.4, up);
				col = mix(col, mirror_colour.rgb * mix(0.8, 1.15, court_vnoise(vec2(along * 0.3, up * 0.35))), in_arc * under * mirror_colour.a * (1.0 - night));
			}
		}
	}

	float foam_noise = court_vnoise(wp * 3.0 + vec2(t * 0.3, -t * 0.2));
	float foam = (1.0 - smoothstep(0.0, foam_width, water_depth)) * smoothstep(0.25, 0.75, foam_noise + 0.3);
	foam *= 1.0 - night;
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
		emit += glitter_color.rgb * spark * glitter_strength * (1.0 - night);
		col += vec3(0.06, 0.05, 0.08) * fres * (1.0 - night);
		// Night: reflected stars, finer and steadier than the sun glitter,
		// shivering a little with the ripples; a few brighter ones.
		vec2 sp = wp * glitter_density * 1.7 + slope * 0.6;
		vec2 scell = floor(sp);
		float srnd = court_hash12(scell + 17.0);
		vec2 sf = fract(sp) - 0.5 - (vec2(court_hash12(scell + 3.1), court_hash12(scell + 7.7)) - 0.5) * 0.6;
		float spt = exp(-dot(sf, sf) * 220.0);
		float stw = 0.65 + 0.35 * sin(t * (0.6 + srnd * 1.8) + srnd * 40.0);
		float bright = step(0.985, srnd) * 2.5 + 1.0;
		float star = step(0.93, srnd) * spt * stw * bright;
		emit += star_color.rgb * star * glitter_strength * 0.8 * night;
		emit += night_shallow.rgb * 0.12 * fres * night;
	}

	float b = blight * blight_affect;
	col = court_blight_mix(col, b) * mix(1.0, 0.45, b);
	ALBEDO = col;
	ROUGHNESS = mix(roughness_value, 0.6, b);
	SPECULAR = mix(mirror, 0.24, night);
	METALLIC = 0.0;
	EMISSION = emit * (1.0 - b) + foam * foam_color.rgb * 0.05;
}
