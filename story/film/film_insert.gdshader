// A film insert on screen (lane L33): its own little world, rendered in a
// SubViewport and laid over the frame with a painter's hand.
// - paint 0..1: a soft Kuwahara-style smear and the canvas weave (the mural).
// - cover 0..1: brush strokes sweep the insert on over whatever is behind it
//   (0 = gone, 1 = full), with a gold wet edge.
// - ripple 0..1: one shiver of colour through the frame (the Wall).
shader_type canvas_item;

uniform sampler2D view : filter_linear;
uniform float paint = 1.0;
uniform float cover = 1.0;
uniform float ripple = 0.0;
uniform float vignette = 0.55;
uniform vec4 gold : source_color = vec4(1.0, 0.84, 0.5, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

// Mean and variance of a 3x3 block offset by `o` texels: the brush picks
// the calmest neighbourhood, so edges stay crisp while flats smear like paint.
vec4 quad(vec2 uv, vec2 px, vec2 o) {
	vec3 m = vec3(0.0), m2 = vec3(0.0);
	for (int y = 0; y < 3; y++) {
		for (int x = 0; x < 3; x++) {
			vec3 c = texture(view, uv + (o + vec2(float(x), float(y))) * px * 1.6).rgb;
			m += c;
			m2 += c * c;
		}
	}
	m /= 9.0;
	vec3 v = abs(m2 / 9.0 - m * m);
	return vec4(m, v.r + v.g + v.b);
}

void fragment() {
	vec2 uv = UV;
	if (ripple > 0.0) {
		float w = sin(uv.y * 40.0 - ripple * 30.0) * sin(uv.x * 23.0 + ripple * 9.0);
		uv += vec2(w, -w) * 0.006 * sin(ripple * 3.14159);
	}
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 col = texture(view, uv).rgb;
	if (paint > 0.0) {
		vec4 a = quad(uv, px, vec2(-2.0, -2.0));
		vec4 b = quad(uv, px, vec2(0.0, -2.0));
		vec4 c = quad(uv, px, vec2(-2.0, 0.0));
		vec4 d = quad(uv, px, vec2(0.0, 0.0));
		vec4 best = a;
		if (b.w < best.w) best = b;
		if (c.w < best.w) best = c;
		if (d.w < best.w) best = d;
		vec3 weave = vec3(0.92 + 0.12 * noise(uv * vec2(900.0, 30.0)) * noise(uv * vec2(30.0, 900.0)));
		col = mix(col, best.rgb * weave, paint);
		// Gold flecks in the lacquer.
		col += gold.rgb * step(0.9993, hash(floor(uv * vec2(640.0, 360.0)))) * 0.6 * paint;
	}
	if (ripple > 0.0) {
		col += vec3(0.6, 0.4, 0.9) * 0.18 * sin(ripple * 3.14159) * (0.5 + 0.5 * sin(uv.x * 30.0 + uv.y * 12.0));
	}
	vec2 v = uv - 0.5;
	col *= 1.0 - vignette * dot(v, v) * 1.6;
	// Brush strokes sweeping the insert on: bands in y, ragged bristle edges.
	float row = floor(UV.y * 11.0);
	float start = hash(vec2(row, 5.0)) * 0.3;
	float bristle = (noise(vec2(UV.x * 20.0, UV.y * 260.0)) - 0.5) * 0.05;
	float edge = cover * 1.35 - start + bristle - UV.x;
	float a = smoothstep(0.0, 0.015, edge);
	col += gold.rgb * smoothstep(0.035, 0.0, abs(edge)) * step(cover, 0.999) * step(0.001, cover) * 1.6;
	COLOR = vec4(col, a * step(0.001, cover));
}
