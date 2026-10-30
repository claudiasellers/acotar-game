// The court's unseen folk before the glamour lifts: a person-shaped ripple
// in the air, like heat over stone, edged with the faintest gold.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform float strength : hint_range(0.0, 1.0) = 0.35;
uniform vec3 rim_color : source_color = vec3(1.0, 0.92, 0.7);

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float ripple = 0.5 + 0.5 * sin(VERTEX.y * 9.0 + TIME * 2.3 + sin(VERTEX.x * 7.0 + TIME));
	ALBEDO = rim_color;
	ALPHA = clamp(rim * (0.4 + 0.6 * ripple) * strength, 0.0, 1.0);
	ALBEDO *= ALPHA;
}
