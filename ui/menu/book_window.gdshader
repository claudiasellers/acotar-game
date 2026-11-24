// Cuts an arched window through whatever it is on (the book's art, the dim
// behind it), so the world shows through: the wardrobe's mirror.
// `window` is x, y, width, height in screen space; zero size cuts nothing.
shader_type canvas_item;

uniform vec4 window = vec4(0.0);

varying vec2 at;

void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (window.z > 0.0) {
		vec2 half_size = window.zw * 0.5;
		vec2 p = at - (window.xy + half_size);
		float r = half_size.x;
		// An arch: a half circle on a box with small feet.
		float foot = 14.0;
		vec2 q = abs(p) - half_size + vec2(foot);
		float box = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - foot;
		float cap = length(p - vec2(0.0, -half_size.y + r)) - r;
		float d = p.y < -half_size.y + r ? cap : box;
		COLOR.a *= smoothstep(-1.0, 1.0, d);
	}
}
