// Manor floors other than the Rococo lozenge marble (L38, quality audit A2):
// painted in world space so every room sharing a pattern and palette shares
// one material. pattern: 0 chevron parquet, 1 square checker marble (the
// foyer's canon black and white), 2 small glazed tiles, 3 long pale boards
// (the gallery, canon), 4 stone flags.
shader_type spatial;
render_mode cull_back;

uniform int pattern = 0;
uniform vec4 base : source_color = vec4(0.80, 0.58, 0.44, 1.0);
uniform vec4 alt : source_color = vec4(0.72, 0.50, 0.38, 1.0);
uniform vec4 joint : source_color = vec4(0.55, 0.38, 0.30, 1.0);
uniform float scale = 1.0;
uniform float gloss = 0.35;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 0..1 distance-to-joint for a cell (0 on the joint line).
float edge_mask(vec2 f, float w) {
	vec2 d = min(f, 1.0 - f);
	float e = min(d.x, d.y);
	float aa = max(fwidth(e), 0.0008);
	return smoothstep(w - aa, w + aa, e);
}

void fragment() {
	vec2 p = wpos.xz / scale;
	vec3 col = base.rgb;
	float j = 1.0;
	float rough = 0.5;
	if (pattern == 0) {
		// chevron parquet (point de Hongrie): 0.5 m columns of 45-degree planks,
		// alternating direction column to column
		float cw = 0.5;
		float ci = floor(p.x / cw);
		float lx = fract(p.x / cw);
		float dir = mod(ci, 2.0) < 1.0 ? 1.0 : -1.0;
		float along = p.y / 0.14 + dir * lx * (cw / 0.14);
		float id = hash(vec2(ci, floor(along)));
		col = mix(base.rgb, alt.rgb, id * 0.85);
		col *= mix(0.93, 1.05, noise(vec2(along * 0.4, lx * 30.0) + id * 13.0));
		j = min(edge_mask(vec2(lx, 0.5), 0.006), edge_mask(vec2(0.5, fract(along)), 0.04));
		rough = 0.45;
	} else if (pattern == 1) {
		vec2 cell = floor(p / 0.75);
		vec2 f = fract(p / 0.75);
		float checker = mod(cell.x + cell.y, 2.0);
		col = mix(base.rgb, alt.rgb, checker);
		float vein = noise(p * 2.3 + cell * 3.7) * 0.6 + noise(p * 7.1) * 0.4;
		col *= mix(0.93, 1.04, smoothstep(0.35, 0.8, vein));
		j = edge_mask(f, 0.008);
		rough = 0.18;
	} else if (pattern == 2) {
		vec2 cell = floor(p / 0.3);
		vec2 f = fract(p / 0.3);
		col = mix(base.rgb, alt.rgb, hash(cell) * 0.7);
		j = edge_mask(f, 0.035);
		rough = 0.3;
	} else if (pattern == 3) {
		// long boards 0.22 m wide running along x, staggered ends
		float row = floor(p.y / 0.22);
		float x = p.x / 2.4 + hash(vec2(row, 3.0));
		vec2 f = vec2(fract(x), fract(p.y / 0.22));
		float id = hash(vec2(floor(x), row));
		col = mix(base.rgb, alt.rgb, id * 0.6);
		col *= mix(0.95, 1.03, noise(vec2(p.x * 2.0, p.y * 30.0) + id * 9.0));
		j = min(edge_mask(vec2(f.x, 0.5), 0.004), edge_mask(vec2(0.5, f.y), 0.03));
		rough = 0.4;
	} else {
		vec2 g = p / 0.9;
		float row = floor(g.y);
		g.x += mod(row, 2.0) * 0.5;
		vec2 cell = floor(g);
		vec2 f = fract(g);
		col = mix(base.rgb, alt.rgb, hash(cell));
		col *= mix(0.9, 1.04, noise(p * 3.0));
		j = edge_mask(f, 0.03);
		rough = 0.8;
	}
	ALBEDO = mix(joint.rgb, col, j);
	ROUGHNESS = mix(0.85, rough * (1.0 - gloss * 0.5), j);
	SPECULAR = 0.45;
	CLEARCOAT = gloss * j;
	CLEARCOAT_ROUGHNESS = 0.25;
}
