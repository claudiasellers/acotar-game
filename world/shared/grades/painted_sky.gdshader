// The World sky: Godot's procedural gradient and sun, plus a layer of soft
// painted clouds that drift slowly (R3: stylised, storybook, never photo).
// GradeDirector sets every uniform from the GradePreset. Clouds are left out
// of the radiance cubemap, so ambient light and reflections are unchanged.
shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.5, 0.56, 0.64);
uniform vec3 sky_horizon_color : source_color = vec3(0.76, 0.78, 0.81);
uniform vec3 ground_horizon_color : source_color = vec3(0.66, 0.67, 0.7);
uniform vec3 ground_bottom_color : source_color = vec3(0.3, 0.31, 0.34);
uniform float sky_curve = 0.15;
uniform float ground_curve = 0.02;
uniform float sun_angle_max = 20.0;
uniform float sun_curve = 0.15;

// 0 = clear, ~0.3 = a few fair-weather clouds, ~0.8 = overcast.
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.0;
uniform vec3 cloud_color : source_color = vec3(0.97, 0.94, 0.96);
uniform vec3 cloud_shade : source_color = vec3(0.74, 0.72, 0.86);
uniform float cloud_scale = 1.0;
uniform vec2 cloud_drift = vec2(0.008, 0.003);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Few octaves on purpose: big soft lobes read painted, fine detail reads photo.
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(13.7, 7.1);
		a *= 0.45;
	}
	return v;
}

vec3 gradient(vec3 dir) {
	float v_angle = acos(clamp(dir.y, -1.0, 1.0));
	if (dir.y >= 0.0) {
		float c = 1.0 - v_angle / (PI * 0.5);
		return mix(sky_horizon_color, sky_top_color, clamp(1.0 - pow(1.0 - c, 1.0 / sky_curve), 0.0, 1.0));
	}
	float c = (v_angle - PI * 0.5) / (PI * 0.5);
	return mix(ground_horizon_color, ground_bottom_color, clamp(1.0 - pow(1.0 - c, 1.0 / ground_curve), 0.0, 1.0));
}

void sky() {
	vec3 col = gradient(EYEDIR);
	vec3 sun_light = vec3(0.0);
	if (LIGHT0_ENABLED) {
		sun_light = LIGHT0_COLOR * LIGHT0_ENERGY;
		float sun_angle = acos(clamp(dot(LIGHT0_DIRECTION, EYEDIR), -1.0, 1.0));
		float a_min = LIGHT0_SIZE;
		float a_max = radians(sun_angle_max);
		if (sun_angle < a_min) {
			col = sun_light;
		} else if (sun_angle < a_max) {
			float c2 = (sun_angle - a_min) / (a_max - a_min);
			col = mix(sun_light, col, clamp(1.0 - pow(1.0 - c2, 1.0 / sun_curve), 0.0, 1.0));
		}
	}
	if (!AT_CUBEMAP_PASS && cloud_cover > 0.001 && EYEDIR.y > 0.0) {
		// A flat cloud deck: farther clouds bunch toward the horizon.
		vec2 uv = EYEDIR.xz / (EYEDIR.y + 0.08) * 1.4 * cloud_scale + TIME * cloud_drift;
		float n = fbm(uv);
		// cover 0.3 leaves about a third of the sky clouded, 0.8 nearly all of it.
		float edge = 0.66 - cloud_cover * 0.42;
		float density = smoothstep(edge, edge + 0.12, n);
		// Soft painterly light: sample toward the sun, lit where the cloud thins that way.
		vec2 to_sun = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION.xz + vec2(0.0001)) : vec2(0.0, 1.0);
		float n_sun = fbm(uv + to_sun * 0.09);
		float lit = clamp(0.62 + (n - n_sun) * 5.0, 0.0, 1.0);
		// Two-tone banding, softened, for the storybook look.
		lit = mix(lit, smoothstep(0.35, 0.65, lit), 0.6);
		vec3 tint = mix(cloud_shade, cloud_color, lit);
		// Clouds take the day's light: white at noon, warm at dusk, dim at night.
		vec3 light = clamp(sky_horizon_color * 0.45 + sun_light * 0.6, vec3(0.0), vec3(1.0));
		vec3 cloud = tint * light;
		// Silver lining near the sun.
		if (LIGHT0_ENABLED) {
			float near_sun = pow(max(dot(LIGHT0_DIRECTION, EYEDIR), 0.0), 24.0);
			cloud += sun_light * near_sun * (1.0 - density) * 0.6;
		}
		density *= smoothstep(0.0, 0.14, EYEDIR.y);
		col = mix(col, cloud, density * 0.92);
	}
	COLOR = col;
}
