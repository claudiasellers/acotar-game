// The mural's land (lane L33): one great island painted in gold line on
// lacquer-dark ground, under gold-dust stars.
// - draw 0..1: the coastline draws itself around the island.
// - fill 0..1: forests, rivers and the mountain in the middle appear.
// - wall 0..1: one line of light is drawn across the land, coast to coast.
// - split 0..1: north of the line blooms in jewel colours and sparkles;
//   south of it drains to grey and snow.
// - wash 0..1: the paint runs like wet paint and washes away (the turn).
// - detail 0..1 (lane L67): the map's icons (Kenney's Cartography Pack, laid
//   out by tools/film/gen_mural_map_detail.py) draw themselves in, icon by
//   icon. Sea icons (waves, compass, cartouche) follow the coastline's brush
//   on `draw`; land icons (peaks, woods, hills, lakes, palaces, temples)
//   follow `detail`. At the split, the south's icons fade to nothing.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float draw = 1.0;
uniform float fill = 1.0;
uniform float wall = 0.0;
uniform float split = 0.0;
uniform float wash = 0.0;
uniform float wall_v = 0.38;
uniform float detail = 1.0;
// R ink line, G body, B draw-in order (see the generator).
uniform sampler2D detail_tex : filter_linear, repeat_disable, hint_default_black;
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
	// The lacquer runs in from the coast once the line has closed, like ink
	// soaking into paper, never as a wedge cut behind the brush.
	float closed = smoothstep(0.82, 1.0, draw);
	float soak = smoothstep(0.0, 0.035, closed * 0.5 + d + (fbm(p * 8.0 + 2.0) - 0.5) * 0.06);
	float inside = smoothstep(0.01, -0.01, d) * soak;
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
	// Ch 13: "a small, snowy mountain range. From it arose a mammoth,
	// solitary peak. Bald of snow". The range is drawn first and snow-capped;
	// the bare peak last, in front, and taller than the rest.
	float snow_cap = 0.0;
	for (int i = 0; i < 5; i++) {
		float k = i == 4 ? 0.0 : (i < 2 ? float(i) * 4.0 - 2.0 : float(i) * 2.0 - 5.0);
		float h = k == 0.0 ? 0.08 : 0.034 + 0.014 * (2.0 - abs(k));
		vec2 q = p - vec2(0.5 + k * 0.03 + (hash(vec2(k, 2.0)) - 0.5) * 0.01, 0.55 + abs(k) * 0.008);
		float side = (h - q.y) * 0.62;
		float in_peak = step(abs(q.x), side) * step(0.0, q.y);
		float rim = smoothstep(mw, 0.0, abs(abs(q.x) - side)) * step(0.0, q.y) * step(q.y, h);
		float hatch = step(0.55, fract((q.x * 0.7 - q.y) * 300.0)) * step(0.0, q.x) * in_peak;
		mfill = max(mfill, in_peak);
		mountain = max(mountain * (1.0 - in_peak), max(rim, hatch * 0.45));
		float cap = in_peak * step(h * 0.6 + 0.004 * sin(q.x * 900.0), q.y) * step(0.5, abs(k));
		snow_cap = max(snow_cap * (1.0 - in_peak), cap);
	}
	mountain *= fill;
	land = mix(land, vec3(0.06, 0.045, 0.1), mfill * fill);
	land = mix(land, vec3(0.86, 0.88, 0.96) * 0.7, snow_cap * fill);
	land += gold * mountain * 0.9;
	// The map's icons. The wash's runny p carries them with the paint.
	vec3 dt = texture(detail_tex, vec2(p.x, 1.0 - p.y)).rgb;
	bool at_sea = dt.b < 0.5;
	float order = at_sea ? dt.b / 0.45 : (dt.b - 0.5) * 2.0;
	float clock = at_sea ? draw * 1.02 : detail * 1.06;
	float shown = clamp((clock - order) / 0.02, 0.0, 1.0);
	// A bright nib where the line is being drawn, like the coast's tip.
	float nib = smoothstep(0.02, 0.0, abs(clock - order - 0.01)) * step(clock, 1.04);
	float north_of = smoothstep(wall_v - 0.004, wall_v + 0.004, p.y);
	// Ch 13: south of the Wall, "a blur of nothing", no markers.
	float keep = 1.0 - split * (1.0 - north_of) * 0.92;
	float ink = dt.r * shown * keep;
	float body = dt.g * shown * keep;
	float on_land = at_sea ? 0.0 : 1.0;
	land = mix(land, vec3(0.07, 0.055, 0.11), body * 0.85 * on_land);
	land += (gold * ink * 0.95 + vec3(1.0, 0.95, 0.8) * dt.r * nib * keep * 2.0) * on_land;
	// The Wall's split: north blooms in jewel colours, south drains to snow.
	float north = smoothstep(wall_v - 0.004, wall_v + 0.004, p.y);
	vec3 jewel = 0.5 + 0.5 * cos(6.28318 * (fbm(p * 4.0) + vec3(0.0, 0.33, 0.67)));
	// Deep jewel tones (emerald, garnet, sapphire), not pastel.
	jewel = mix(jewel * jewel * vec3(0.75, 0.7, 0.9), vec3(0.9, 0.62, 0.4), 0.18);
	vec2 sc = p * 260.0;
	float sparkle = step(0.985, hash(floor(sc) + floor(TIME * 3.0)))
			* smoothstep(0.45, 0.1, length(fract(sc) - 0.5));
	vec3 bloom = jewel * 0.75 + sparkle * vec3(1.0, 0.95, 0.85) * 1.5;
	vec3 snow = vec3(0.5, 0.53, 0.6) * (0.7 + 0.3 * fbm(p * 30.0));
	// A tint over the map, not a wash over it: rivers, woods and the
	// mountain stay legible under the colour, so it still reads as the land.
	land = mix(land, mix(snow, bloom, north), split * mix(0.55, 0.85, 1.0 - north));
	col = mix(col, land, inside);
	// Sea icons stay outside the coast.
	float sea_side = (1.0 - inside) * (1.0 - on_land);
	col = mix(col, ground * 0.7, body * 0.8 * sea_side);
	col += (gold * ink * 0.85 + vec3(1.0, 0.95, 0.8) * dt.r * nib * 2.0) * sea_side;
	// The coastline in gold, drawn around the island.
	float coast = smoothstep(0.006, 0.0, abs(d)) * drawn;
	float tip = smoothstep(0.012, 0.0, abs(ang - draw)) * step(draw, 0.999) * step(abs(d), 0.02);
	col += gold * coast * 1.4 + vec3(1.0, 0.95, 0.8) * tip * 3.0;
	// The Wall: one line of light coast to coast, drawn from west to east.
	float line = smoothstep(0.004, 0.0, abs(p.y - wall_v)) * step(p.x, wall * 1.1) * inside;
	col += vec3(1.0, 0.95, 0.9) * line * (2.5 + 0.8 * sin(TIME * 5.0 + p.x * 40.0));
	col *= 1.0 - smoothstep(0.55, 1.0, wash);
	ALBEDO = col;
	EMISSION = gold * (ink * 0.3 + dt.r * nib * 1.2) * (on_land * inside + sea_side) + gold * (coast * 0.8 + tip * 2.0 + mountain * inside * 0.4) + vec3(1.0) * line * 1.5 + bloom * north * split * inside * 0.12;
}
