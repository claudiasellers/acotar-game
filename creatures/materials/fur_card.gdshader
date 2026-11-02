// Guard-hair clumps (lane L43): each alpha-cut card is a fan of tapering
// strands of different lengths. UV.x runs across the card, UV.y (flipped by
// glTF) from root to tip; UV2.x is the card's seed; COLOR = (pale, -, dark, -).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;

uniform vec3 root_color : source_color = vec3(0.06, 0.06, 0.07);
uniform vec3 tip_color : source_color = vec3(0.42, 0.43, 0.47);
uniform vec3 pale : source_color = vec3(0.62, 0.58, 0.5);
uniform float strands = 6.0;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.5;

varying float seed;
varying vec4 zone;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void vertex() {
	seed = UV2.x;
	zone = COLOR;
}

void fragment() {
	float v = 1.0 - UV.y;
	float x = UV.x * strands + seed * 3.0;
	float id = floor(x);
	float h = hash11(id + seed * 97.0);
	float len = 0.5 + 0.5 * h;
	float f = fract(x) - 0.5 + (hash11(id * 1.7 + 3.1) - 0.5) * 0.3 * v;
	float w = 0.5 * (1.0 - pow(v / len, 1.3));
	// Never thinner than about a pixel, or a clump seen from a few metres
	// off cuts itself to nothing and the silhouette goes smooth.
	w = max(w, 0.9 * fwidth(x)) * step(0.0, 1.0 - pow(v / len, 1.3));
	if (v > len || abs(f) > w) {
		discard;
	}
	vec3 col = mix(root_color, tip_color, smoothstep(0.15, 1.0, v / len));
	col = mix(col, pale, zone.r * smoothstep(0.3, 1.0, v / len));
	col = mix(col, root_color, zone.b * 0.6);
	col *= 0.75 + 0.5 * h;
	ALBEDO = col;
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
	RIM = rim_amount;
	RIM_TINT = 0.6;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
