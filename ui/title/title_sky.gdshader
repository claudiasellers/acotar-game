// The title backdrop's sky: two skies meeting at the Wall. The Wall is the
// plane x = 0, which meets the sky along EYEDIR.x = 0, so the human side
// (x > 0, screen left) is a cold blue-grey dusk and the spring side (x < 0) a pastel
// sunset with a low gold sun.
shader_type sky;

uniform vec3 winter_zenith : source_color = vec3(0.16, 0.18, 0.28);
uniform vec3 winter_horizon : source_color = vec3(0.47, 0.50, 0.62);
uniform vec3 spring_zenith : source_color = vec3(0.62, 0.55, 0.86);
uniform vec3 spring_mid : source_color = vec3(0.96, 0.66, 0.78);
uniform vec3 spring_horizon : source_color = vec3(1.0, 0.88, 0.70);
uniform vec3 sun_color : source_color = vec3(1.0, 0.93, 0.78);
uniform vec3 sun_dir = vec3(-0.62, 0.16, 0.78);
// How far the spring colour bleeds past the line (in EYEDIR.x).
uniform float bleed = 0.035;
// 0 = split at the Wall; 1 = spring everywhere (the crossing).
uniform float spring_all : hint_range(0.0, 1.0) = 0.0;

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, 0.0, 1.0);
	vec3 winter = mix(winter_horizon, winter_zenith, pow(h, 0.6));
	vec3 spring = mix(spring_horizon, spring_mid, smoothstep(0.0, 0.18, h));
	spring = mix(spring, spring_zenith, smoothstep(0.15, 0.75, h));
	float sun = max(dot(d, normalize(sun_dir)), 0.0);
	spring += sun_color * (pow(sun, 6.0) * 0.55 + pow(sun, 120.0) * 1.6);
	float side = smoothstep(-bleed, bleed * 0.4, -d.x);
	side = max(side, spring_all);
	// Below the horizon: a soft continuation so reflections are not black.
	vec3 col = mix(winter, spring, side);
	if (d.y < 0.0) {
		col = mix(col, col * 0.6, clamp(-d.y * 3.0, 0.0, 1.0));
	}
	COLOR = col;
}
