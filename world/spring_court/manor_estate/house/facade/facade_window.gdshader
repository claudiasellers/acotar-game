// Outer window pane for the manor façade (L42): gilt glazing bars over sky-
// tinted glass by day; warm candle-lit rooms with rose curtains at dusk.
// One-sided, facing out: from inside the rooms the pane is culled, so the
// interior glass and views are untouched. INSTANCE_CUSTOM.r picks which
// rooms are lit (about 3 in 4) and how warm.
shader_type spatial;
render_mode cull_back;

uniform float glow : hint_range(0.0, 1.0) = 0.0;   // set by ManorFacadeGlow from the clock
uniform vec3 sky_top : source_color = vec3(0.66, 0.70, 0.92);
uniform vec3 sky_low : source_color = vec3(0.85, 0.78, 0.88);
uniform vec3 bar_color : source_color = vec3(0.80, 0.66, 0.40);
uniform vec3 lamp : source_color = vec3(1.0, 0.62, 0.30);
uniform vec3 curtain : source_color = vec3(0.92, 0.52, 0.62);
uniform float lamp_energy = 1.7;

varying float seed;

void vertex() {
	seed = INSTANCE_CUSTOM.r;
}

void fragment() {
	vec2 uv = UV;
	// glazing bars: 2 columns x 4 rows
	vec2 g = vec2(uv.x * 2.0, uv.y * 4.0);
	vec2 d = min(fract(g), 1.0 - fract(g)) / vec2(2.0, 4.0);
	float bar = 1.0 - smoothstep(0.006, 0.012, min(d.x * 1.5, d.y * 2.6));
	float frame = 1.0 - smoothstep(0.02, 0.035, min(min(uv.x, 1.0 - uv.x) * 1.7, min(uv.y, 1.0 - uv.y)));
	bar = max(bar, frame);
	// day: sky reflection with a soft diagonal sheen
	vec3 glass = mix(sky_top, sky_low, uv.y) * 0.62;
	glass += vec3(0.08, 0.07, 0.10) * smoothstep(0.08, 0.0, abs(uv.x - uv.y * 0.6 - 0.15));
	// night: lit rooms and curtains drawn back at the sides
	float lit = step(seed, 0.76);
	float side = smoothstep(0.24, 0.16, min(uv.x, 1.0 - uv.x));
	float warm = 0.85 + 0.3 * fract(seed * 7.13);
	vec3 room = lamp * warm * mix(1.0, 0.7, uv.y);
	vec3 night = mix(room, curtain * 0.55, side);
	float g_on = glow * lit;
	ALBEDO = mix(glass, bar_color, bar);
	ALBEDO = mix(ALBEDO, ALBEDO * 0.35, g_on * (1.0 - bar));
	ROUGHNESS = mix(0.06, 0.4, bar);
	METALLIC = mix(0.25, 0.8, bar);
	EMISSION = night * lamp_energy * g_on * (1.0 - bar);
}
