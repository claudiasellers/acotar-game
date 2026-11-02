// A soft pool of light on the ground under the nearest find: a round radial
// falloff that breathes slowly, additive, pastel gold.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.62, 1.0);
uniform float strength = 0.55;
uniform float breathe_speed = 2.2;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	float glow = exp(-r2 * 4.0) * (1.0 - smoothstep(0.7, 1.0, sqrt(r2)));
	float breathe = 0.75 + 0.25 * sin(TIME * breathe_speed);
	ALBEDO = tint.rgb;
	ALPHA = glow * breathe * strength;
}
