// The mural's land (lane L33): one great island painted in gold line on
// lacquer-dark ground, under gold-dust stars.
// - draw 0..1: the coastline draws itself around the island.
// - fill 0..1: forests, rivers and the mountain in the middle appear.
// - wall 0..1: one line of light is drawn across the land, coast to coast.
// - split 0..1: north of the line blooms in jewel colours and sparkles;
//   south of it drains to grey and snow.
// - wash 0..1: the paint runs like wet paint and washes away (the turn).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float draw = 1.0;
uniform float fill = 1.0;
uniform float wall = 0.0;
uniform float split = 0.0;
uniform float wash = 0.0;
uniform float wall_v = 0.38;
uniform vec3 ground : source_color = vec3(0.045, 0.035, 0.09);
uniform vec3 gold : source_color = vec3(1.0, 0.83, 0.46);

varying vec2 uv;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int k = 0; k < 5; k++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}

// Signed distance-ish field of the island: an elongated blob with a ragged
// coast, wider in the north, a narrow tip in the south (the human lands).
float island(vec2 p) {
	vec2 c = p - vec2(0.5, 0.5);
	c.x *= 1.0 + 0.55 * smoothstep(0.1, -0.45, c.y);
	float d = length(c * vec2(1.55, 1.0)) - 0.4;
	d += (fbm(p * 6.0) - 0.5) * 0.14 + (fbm(p * 19.0) - 0.5) * 0.03;
	return d;
}

void vertex() {
	uv = UV;
}

void fragment() {
	// North is up the frame (far from the lens), the human south toward it.
	vec2 p = vec2(uv.x, 1.0 - uv.y);
	p.x += wash * (fbm(vec2(p.y * 7.0, TIME * 0.2)) - 0.5) * 0.1;
	p.y -= wash * wash * 0.25 * fbm(vec2(p.x * 9.0, 1.0));
	float d = island(p);
	vec2 c = p - vec2(0.5);
	float ang = (atan(c.x, -c.y) / 6.28318) + 0.5;
	float drawn = step(ang, draw * 1.02);
	vec3 col = ground * (0.75 + 0.5 * fbm(p * 40.0));
	// Gold-dust stars in the dark sea.
	vec2 sg = p * 420.0;
	float st = step(0.996, hash(floor(sg))) * (0.5 + 0.5 * sin(TIME * 2.0 + hash(floor(sg)) * 30.0))
			* smoothstep(0.5, 0.15, length(fract(sg) - 0.5));
	col += gold * st * 0.8 * step(0.0, d);
	// Inside the land: a soft lacquer wash, later forests, rivers, mountain.
	float inside = smoothstep(0.01, -0.01, d) * drawn;
	vec3 land = mix(vec3(0.09, 0.07, 0.13), vec3(0.16, 0.12, 0.1), fbm(p * 5.0));
	// Forests: tiny painted trees, stippled where the woods grow thick.
	vec2 tc = p * 120.0;
	vec2 cell = floor(tc);
	vec2 tf = fract(tc) - 0.5 + (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.35;
	float tw = fwidth(tc.x) * 1.2;
	float tree = smoothstep(tw, -tw, abs(tf.x) - (0.3 - tf.y) * 0.42) * step(-0.22, tf.y) * step(tf.y, 0.3);
	float woods = step(0.6, fbm(p * 13.0 + 4.0)) * step(0.3, hash(cell)) * step(abs(p.y - wall_v), 1.0);
	float forest = tree * woods * fill;
	land += gold * forest * 0.55;
	float river = smoothstep(0.006, 0.0, abs(fbm(p * vec2(3.0, 8.0) + 3.0) - 0.5) - 0.002) * fill;
	land += gold * river * 0.5;
	// The mountains in the middle of the north: a small range, one peak
	// standing over the rest. Inked outlines, hatched on their shadow side.
	float mountain = 0.0;
	float mfill = 0.0;
	float mw = fwidth(p.x) * 1.4;
	for (int i = 0; i < 5; i++) {
		float k = float(i) - 2.0;
		float h = 0.045 + 0.035 * (1.0 - abs(k) * 0.5);
		vec2 q = p - vec2(0.5 + k * 0.03 + (hash(vec2(k, 2.0)) - 0.5) * 0.01, 0.55 + abs(k) * 0.008);
		float side = (h - q.y) * 0.62;
		float in_peak = step(abs(q.x), side) * step(0.0, q.y);
		float rim = smoothstep(mw, 0.0, abs(abs(q.x) - side)) * step(0.0, q.y) * step(q.y, h);
		float hatch = step(0.55, fract((q.x * 0.7 - q.y) * 300.0)) * step(0.0, q.x) * in_peak;
		mfill = max(mfill, in_peak);
		mountain = max(mountain * (1.0 - in_peak), max(rim, hatch * 0.45));
	}
	mountain *= fill;
	land = mix(land, vec3(0.06, 0.045, 0.1), mfill * fill);
	land += gold * mountain * 0.9;
	// The Wall's split: north blooms in jewel colours, south drains to snow.
	float north = smoothstep(wall_v - 0.004, wall_v + 0.004, p.y);
	vec3 jewel = 0.5 + 0.5 * cos(6.28318 * (fbm(p * 4.0) + vec3(0.0, 0.33, 0.67)));
	jewel = mix(jewel * vec3(0.8, 0.75, 0.95), vec3(1.0, 0.72, 0.62), 0.5);
	vec2 sc = p * 260.0;
	float sparkle = step(0.985, hash(floor(sc) + floor(TIME * 3.0)))
			* smoothstep(0.45, 0.1, length(fract(sc) - 0.5));
	vec3 bloom = jewel * 0.75 + sparkle * vec3(1.0, 0.95, 0.85) * 1.5;
	vec3 snow = vec3(0.5, 0.53, 0.6) * (0.7 + 0.3 * fbm(p * 30.0));
	land = mix(land, mix(snow, bloom, north), split);
	col = mix(col, land, inside);
	// The coastline in gold, drawn around the island.
	float coast = smoothstep(0.006, 0.0, abs(d)) * drawn;
	float tip = smoothstep(0.012, 0.0, abs(ang - draw)) * step(draw, 0.999) * step(abs(d), 0.02);
	col += gold * coast * 1.4 + vec3(1.0, 0.95, 0.8) * tip * 3.0;
	// The Wall: one line of light coast to coast, drawn from west to east.
	float line = smoothstep(0.004, 0.0, abs(p.y - wall_v)) * step(p.x, wall * 1.1) * inside;
	col += vec3(1.0, 0.95, 0.9) * line * (2.5 + 0.8 * sin(TIME * 5.0 + p.x * 40.0));
	col *= 1.0 - smoothstep(0.55, 1.0, wash);
	ALBEDO = col;
	EMISSION = gold * (coast * 0.8 + tip * 2.0 + mountain * inside * 0.4) + vec3(1.0) * line * 1.5 + bloom * north * split * inside * 0.3;
}
