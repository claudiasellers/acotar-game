// Gilt type for the title: a vertical gold gradient across the label with a
// slow sheen sweeping through it.
shader_type canvas_item;

uniform vec4 top : source_color = vec4(1.0, 0.95, 0.78, 1.0);
uniform vec4 mid : source_color = vec4(0.95, 0.82, 0.48, 1.0);
uniform vec4 low : source_color = vec4(0.79, 0.59, 0.24, 1.0);
uniform vec4 foot : source_color = vec4(0.96, 0.86, 0.57, 1.0);
uniform float label_height = 160.0;
uniform float label_width = 900.0;
uniform float sheen_period = 7.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec4 glyph = texture(TEXTURE, UV);
	float t = clamp(local.y / label_height, 0.0, 1.0);
	vec3 g = t < 0.4 ? mix(top.rgb, mid.rgb, t / 0.4)
		: t < 0.68 ? mix(mid.rgb, low.rgb, (t - 0.4) / 0.28)
		: mix(low.rgb, foot.rgb, (t - 0.68) / 0.32);
	float sweep = fract(TIME / sheen_period) * 1.8 - 0.4;
	float x = local.x / label_width - t * 0.15;
	g += vec3(1.0, 0.95, 0.85) * smoothstep(0.06, 0.0, abs(x - sweep)) * 0.45;
	COLOR = vec4(g, glyph.a * COLOR.a);
}
