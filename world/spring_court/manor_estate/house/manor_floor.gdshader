// Manor floors other than the Rococo lozenge marble (L38, quality audit A2):
// painted in world space so every room sharing a pattern and palette shares
// one material. pattern: 0 chevron parquet, 1 checker marble laid on point
// (the foyer's canon black and white), 2 small glazed tiles, 3 long pale boards
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
	float joint_rough = 0.85;
	float joint_metal = 0.0;
	float coat_k = 1.0;
	float spec = 0.45;
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
		// the foyer's canon black-and-white marble, laid on point: 0.85 m
		// squares turned 45 degrees, ivory with soft grey veins and nero with
		// fine white veins, set in a gilt fillet (audit G1: a square grid of
		// flat navy and white read as a diner floor)
		vec2 q = vec2(p.x + p.y, p.y - p.x) * 0.70710678 / 0.85;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float dark = mod(cell.x + cell.y, 2.0);
		vec2 w = q * 0.85 + cell * 5.3;
		float warp = noise(w * 1.1) * 2.2 + noise(w * 3.3) * 0.9;
		float vein = 1.0 - smoothstep(0.0, 0.07, abs(sin(w.x * 1.6 + w.y * 0.7 + warp * 2.6)));
		float fine = 1.0 - smoothstep(0.0, 0.035, abs(sin(w.x * 4.1 - w.y * 2.3 + warp * 4.0)));
		float cloud = noise(w * 0.8) * 0.6 + noise(w * 2.7) * 0.4;
		vec3 ivory = base.rgb * mix(0.96, 1.02, cloud);
		// veins borrow the other square's warmth: rose-grey in the ivory,
		// rose-pearl in the plum-black (L38-5: the canon's black and white,
		// warmed to sit with the pastel house)
		ivory = mix(ivory, mix(vec3(0.70, 0.64, 0.64), alt.rgb * 6.0, 0.25), vein * 0.32 + fine * 0.12);
		vec3 nero = alt.rgb * mix(0.85, 1.15, cloud);
		nero = mix(nero, base.rgb * vec3(1.0, 0.86, 0.9), vein * 0.5 + fine * 0.25);
		col = mix(ivory, nero, dark);
		j = edge_mask(f, 0.012);
		// the fillet is brass, not grout
		joint_rough = 0.32;
		joint_metal = 0.85;
		// the dark squares are honed, not lacquered: a polished black mirrors the
		// lilac sky and reads navy (shots L38-10)
		coat_k = mix(1.0, 0.0, dark);
		spec = mix(0.45, 0.12, dark);
		rough = mix(0.16, 0.5, dark);
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
	ROUGHNESS = mix(joint_rough, rough * (1.0 - gloss * 0.5), j);
	METALLIC = (1.0 - j) * joint_metal;
	SPECULAR = spec;
	CLEARCOAT = gloss * j * coat_k;
	CLEARCOAT_ROUGHNESS = 0.25;
}
