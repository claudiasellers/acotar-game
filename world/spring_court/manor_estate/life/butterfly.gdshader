// Butterflies for GPUParticles3D draw passes: a flat two-winged card whose wings
// flap per particle. Wing colour comes from the particle colour (pastel ramp).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec4 body_color : source_color = vec4(0.35, 0.22, 0.30, 1.0);

void vertex() {
	float flap = sin(TIME * 13.0 + INSTANCE_CUSTOM.x * 61.0) * 1.05;
	float x = VERTEX.x;
	VERTEX.x = x * cos(flap);
	VERTEX.y += abs(x) * sin(flap);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;                  // -1..1, x across the wings
	float ax = abs(p.x);
	// two lobes per side: fore wing and hind wing
	float fore = length(vec2(ax - 0.5, (p.y + 0.28) * 1.3));
	float hind = length(vec2(ax - 0.42, (p.y - 0.42) * 1.6));
	float wing = min(fore, hind * 1.15);
	if (wing > 0.5 && ax > 0.06) {
		discard;
	}
	if (ax <= 0.06 && abs(p.y) > 0.75) {
		discard;
	}
	vec3 col = COLOR.rgb;
	col = mix(col, vec3(1.0), smoothstep(0.32, 0.5, wing) * 0.5);
	ALBEDO = ax <= 0.06 ? body_color.rgb : col;
	EMISSION = col * 0.25;
	ROUGHNESS = 0.4;
}
