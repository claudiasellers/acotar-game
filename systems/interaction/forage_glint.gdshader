// The forage glint: a soft four-point star with a round core and halo,
// additive, twinkling per particle. Tint comes from the particle colour
// (pastel and gold, see ForageFocus). Billboarded like BILLBOARD_PARTICLES.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float twinkle_speed = 6.0;
uniform float brightness = 1.25;

varying float v_seed;

void vertex() {
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float a = INSTANCE_CUSTOM.x;
	world = world * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_seed = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	float core = exp(-r2 * 30.0);
	float halo = exp(-r2 * 5.0) * 0.3;
	float rays = exp(-abs(p.x) * 26.0) * exp(-abs(p.y) * 3.0) + exp(-abs(p.y) * 26.0) * exp(-abs(p.x) * 3.0);
	float twinkle = 0.55 + 0.45 * sin(TIME * twinkle_speed * (0.8 + 0.4 * v_seed) + v_seed * 31.0);
	float edge = 1.0 - smoothstep(0.85, 1.0, max(abs(p.x), abs(p.y)));
	float a = clamp((core + halo + rays * 0.9 * twinkle) * edge, 0.0, 1.0);
	ALBEDO = COLOR.rgb * brightness;
	ALPHA = a * COLOR.a;
}
