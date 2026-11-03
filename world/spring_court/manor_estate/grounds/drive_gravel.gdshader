// The drive, the forecourt and the garden walks: fine honey-cream gravel (the
// roses carry the pink), in world space so long drapes never stretch it (R3).
// L56-2: was big round confetti dots ("polka dots"). Now small irregular
// stones from a cellular pattern at two grain sizes (the cell edges make
// angular stones, not discs), a fine grit noise between them, gold grit and
// the odd fallen petal. With `lanes` on (drapes laid with across-UV 0..0.25),
// two soft carriage ruts run down the middle and the edges wear into the lawn.
// Kept below ~0.86 albedo so it never clips white at noon.
// L56-4 (the user: "extend it out a little further ... then smooth it out by
// gradation as it flows backward"): the stones now hold through the foreground
// and midground and soften in three steps with distance: the fine grit goes
// first (~12-35 m), the stones next (~30-85 m), and a coarse low-contrast
// mottle of stone clusters carries the texture on to ~160 m. Each step fades
// toward the average gravel tone, never to flat sand, so there is no band.
shader_type spatial;
render_mode cull_back;

uniform vec3 sand : source_color = vec3(0.60, 0.57, 0.49);
uniform vec3 pearl : source_color = vec3(0.78, 0.76, 0.69);
uniform vec3 taupe : source_color = vec3(0.49, 0.43, 0.37);
uniform vec3 grit : source_color = vec3(0.92, 0.76, 0.44);
uniform vec3 petal : source_color = vec3(1.0, 0.64, 0.77);
uniform vec3 moss : source_color = vec3(0.42, 0.50, 0.30);
uniform float stone_size = 0.045;
uniform float lanes = 0.0;

uniform float stones_near = 30.0;   // stones full strength up to here (m)
uniform float stones_far = 85.0;    // and gone (melted into the mottle) by here
uniform float grit_near = 12.0;
uniform float grit_far = 35.0;
uniform float mottle_far = 160.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + 31.7));
}

// Cellular stones: x = distance to the nearest stone centre, y = edge (F2 - F1), z = stone id.
vec3 cells(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(c + g) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; id = hash(c + g + 5.0); }
			else if (d < d2) { d2 = d; }
		}
	}
	return vec3(d1, d2 - d1, id);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = world_pos.xz;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	// the tone the stones average out to, so every fade lands on gravel colour
	vec3 avg = mix(sand, mix(taupe, pearl, 0.5), 0.55);
	float grit_fade = smoothstep(grit_far, grit_near, dist);
	float stone_fade = smoothstep(stones_far, stones_near, dist);
	float mottle_fade = smoothstep(mottle_far, stones_near, dist);
	// fine grit between the stones
	vec3 col = mix(avg, sand, stone_fade) * mix(1.0, mix(0.86, 1.06, vnoise(w * 60.0)), grit_fade);
	// coarse mottle: clusters of lighter and darker stones, ~4 stones across
	vec3 m = cells(w / (stone_size * 4.5) + 7.3);
	float mot = (m.z - 0.5) * 0.14 * mottle_fade * clamp(2.4 - length(fwidth(w / (stone_size * 4.5))) * 1.6, 0.0, 1.0);
	col *= 1.0 + mot;
	// two grain sizes of irregular stones
	for (int layer = 0; layer < 2; layer++) {
		float sz = stone_size * (layer == 0 ? 1.0 : 0.55);
		vec3 c = cells(w / sz + float(layer) * 13.1);
		float stone = smoothstep(0.02, 0.12, c.y);          // the gaps between stones stay sand
		// soften where a stone shrinks under a couple of pixels (no shimmer), and with distance
		stone *= clamp(2.4 - length(fwidth(w / sz)) * 1.6, 0.0, 1.0);
		stone *= layer == 0 ? stone_fade : grit_fade;
		vec3 tone = c.z < 0.35 ? taupe : (c.z > 0.7 ? pearl : mix(sand, pearl, 0.45));
		tone *= mix(0.9, 1.08, hash(vec2(c.z * 91.0, float(layer)))) * (1.0 + mot);
		col = mix(col, tone, stone * (layer == 0 ? 0.85 : 0.6));
		col = mix(col, grit, step(0.97, c.z) * stone * 0.8);
	}
	// broad, soft variation so a long drive never reads as a flat strip
	col *= mix(0.93, 1.04, vnoise(w * 0.35)) * mix(0.96, 1.02, vnoise(w * 0.07 + 3.0));
	float rough = 0.9;
	if (lanes > 0.5) {
		float u = clamp(UV.x * 4.0, 0.0, 1.0);             // 0..1 across the drape
		// carriage ruts: two soft, slightly darker, more compacted lanes
		float rut = exp(-pow((u - 0.3) / 0.07, 2.0)) + exp(-pow((u - 0.7) / 0.07, 2.0));
		rut *= 0.7 + 0.3 * vnoise(w * 0.8);
		col *= 1.0 - 0.09 * rut;
		rough -= 0.12 * rut;
		// worn edges: the lawn creeps in, mossy and darker, irregularly
		float edge = min(u, 1.0 - u);
		float creep = smoothstep(0.12, 0.0, edge + (vnoise(w * 1.3) - 0.5) * 0.08);
		col = mix(col, moss, creep * 0.55);
	}
	// a fallen petal every few metres
	vec2 q = w / 0.6;
	vec2 qc = floor(q);
	vec2 qf = fract(q) - 0.5;
	float on = step(0.94, hash(qc + 19.0));
	float ang = hash(qc + 23.0) * 6.283;
	vec2 r = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * qf;
	float petal_shape = smoothstep(1.0, 0.8, length(r * vec2(5.5, 9.0)));
	col = mix(col, petal, on * petal_shape);
	ALBEDO = min(col, vec3(0.86));
	ROUGHNESS = mix(rough, 0.55, on * petal_shape);
	SPECULAR = 0.3;
}
