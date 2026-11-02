// The Wall, felt not seen (lane L33): one shiver through the lens as the
// camera passes the line, a ring of refraction and a breath of colour.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float k = 0.0;

void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	float r = length(c);
	float ring = smoothstep(0.12, 0.0, abs(r - k * 0.9));
	float env = sin(k * 3.14159);
	vec2 off = normalize(c + 1e-4) * ring * 0.018 * env;
	off += vec2(sin(SCREEN_UV.y * 60.0 + k * 20.0), cos(SCREEN_UV.x * 50.0 - k * 18.0)) * 0.002 * env;
	vec3 col = texture(screen, SCREEN_UV + off).rgb;
	col += vec3(0.55, 0.45, 1.0) * ring * 0.18 * env;
	col += vec3(1.0, 0.75, 0.9) * env * 0.05;
	COLOR = vec4(col, 1.0);
}
