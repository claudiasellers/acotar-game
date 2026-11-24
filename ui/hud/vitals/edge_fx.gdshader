// Feyre's screen edges in one full-screen pass (plan §14.5, §15 D): fear,
// low health, venom veins, frost, fae-toll colour bleed, the ease bloom, the
// heal burst, the hit-direction bruise, the paper edge of hiding, the beat of
// an unseen attack, drowsy eyelids, and the knockdown's
// stars, rose-black iris and white-gold wake. Horror layers use the horror
// palette and are never pretty; the Spring layers are candy and gold.
shader_type canvas_item;
render_mode unshaded;

uniform float strength = 1.0;
uniform float aspect = 1.7778;
uniform float dread = 0.0;
uniform float low_health = 0.0;
uniform float venom = 0.0;
uniform float cold = 0.0;
uniform vec3 frost_color = vec3(0.86, 0.90, 1.0);
uniform float fae = 0.0;
uniform float ease = 0.0;
uniform float heal = 0.0;
uniform vec2 hit_dir = vec2(0.0, -1.0);
uniform float hit_amount = 0.0;
uniform float hidden = 0.0;
uniform vec3 paper_color = vec3(0.92, 0.90, 0.85);
uniform float warn = 0.0;
uniform float warn_side = 0.0;
uniform float drowsy_lid = 0.0;
uniform float stars = 0.0;
uniform float iris = 0.0;
uniform float wake = 1.0;

const vec3 ICHOR = vec3(0.071, 0.047, 0.063);
const vec3 BRUISE = vec3(0.227, 0.118, 0.180);
const vec3 BILE = vec3(0.435, 0.498, 0.227);
const vec3 OLD_BLOOD = vec3(0.478, 0.118, 0.165);
const vec3 GOLD = vec3(1.0, 0.89, 0.63);
const vec3 BLUSH = vec3(1.0, 0.76, 0.84);
const vec3 DAWN = vec3(1.0, 0.96, 0.86);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Paints c at alpha a over the running (premultiplied) colour.
void over(inout vec4 acc, vec3 c, float a) {
	a = clamp(a, 0.0, 1.0);
	acc.rgb = c * a + acc.rgb * (1.0 - a);
	acc.a = a + acc.a * (1.0 - a);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0) * 2.0;
	float r = length(p) / aspect;
	float v = length((uv - 0.5) * vec2(1.0, 0.78)) * 1.65;
	float edge = smoothstep(0.5, 1.05, v);
	vec4 acc = vec4(0.0);
	float s = strength;

	// Dread: a creeping dark that eats in from the edges.
	if (dread > 0.0) {
		float n = fbm(uv * 5.0 + vec2(TIME * 0.05, -TIME * 0.04));
		float m = smoothstep(0.85 - dread * 0.45, 1.2, v + (n - 0.5) * 0.35);
		over(acc, ICHOR, m * dread * 0.8 * s);
	}
	// Low health: rose-black thorns that pulse with a heartbeat.
	if (low_health > 0.0) {
		float beat = pow(abs(sin(TIME * 3.6)), 8.0);
		float thorn = fbm(vec2(atan(p.y, p.x) * 6.0, v * 3.0));
		float m = smoothstep(0.95 - low_health * 0.35, 1.15, v + thorn * 0.25);
		over(acc, mix(OLD_BLOOD, ICHOR, 0.35), m * low_health * (0.55 + 0.45 * beat) * s);
	}
	// Venom: black veins crawling in, tinged with bile.
	if (venom > 0.0) {
		float n = fbm(uv * vec2(9.0, 6.0) + vec2(0.0, TIME * 0.02));
		float vein = 1.0 - abs(n * 2.0 - 1.0);
		vein = pow(vein, 10.0);
		float reach = smoothstep(1.05 - venom * 0.5, 1.15, v + 0.1);
		over(acc, mix(ICHOR, BILE, 0.25), vein * reach * venom * 1.6 * s);
		over(acc, BILE, reach * venom * 0.12 * s);
	}
	// Frost: grows in from the corners, with fine glints.
	if (cold > 0.0) {
		float corner = smoothstep(0.75, 1.15, length(uv - 0.5) * 2.0 / 1.2 + (fbm(uv * 14.0) - 0.5) * 0.3);
		float glint = step(0.985, hash(floor(uv * vec2(320.0, 180.0)))) * (0.5 + 0.5 * sin(TIME * 4.0 + uv.x * 40.0));
		over(acc, frost_color, (corner * 0.7 + glint * corner) * cold * s);
	}
	// Fae-toll: a candy colour bleed at the edges.
	if (fae > 0.0) {
		float h = fract(uv.x * 0.6 + uv.y * 0.4 + TIME * 0.06);
		vec3 candy = 0.72 + 0.28 * cos(6.2832 * (h + vec3(0.0, 0.33, 0.67)));
		over(acc, candy, edge * fae * 0.4 * s);
	}
	// An ease moment: warm gold bloom and a drift of blush motes.
	if (ease > 0.0) {
		float mote = step(0.992, hash(floor((uv + vec2(0.0, -TIME * 0.02)) * vec2(160.0, 90.0))));
		over(acc, GOLD, edge * ease * 0.45 * s);
		over(acc, BLUSH, mote * edge * ease * s);
	}
	// Healing: a soft petal-pink burst inward.
	if (heal > 0.0) {
		over(acc, BLUSH, smoothstep(0.6, 1.1, v) * heal * 0.4 * s);
	}
	// The hit-direction bruise on the edge she was struck from.
	if (hit_amount > 0.0) {
		vec2 dir = normalize(p + vec2(0.0001));
		float facing = smoothstep(0.55, 1.0, dot(dir, normalize(hit_dir)));
		float hair = pow(1.0 - abs(fbm(vec2(atan(p.y, p.x) * 18.0, v * 8.0)) * 2.0 - 1.0), 6.0);
		float m = facing * smoothstep(0.55, 1.05, v);
		over(acc, mix(BRUISE, OLD_BLOOD, 0.4), m * hit_amount * 0.85);
		over(acc, ICHOR, m * hair * hit_amount * 0.6);
	}
	// Hidden: the page's own edge draws in, torn and soft, while she is hard to see.
	if (hidden > 0.0) {
		float tear = fbm(vec2(atan(p.y, p.x) * 5.0, v * 2.0)) - 0.5;
		float m = smoothstep(0.78 - hidden * 0.12, 1.02, v + tear * 0.22);
		over(acc, paper_color, m * hidden * 0.7 * s);
	}
	// An attack she cannot see winding up: that side's edge beats (the bottom for behind her).
	if (warn > 0.0) {
		float beat = 0.55 + 0.45 * sin(TIME * 11.0);
		float side = abs(warn_side) < 0.2 ? smoothstep(0.72, 1.0, uv.y) : smoothstep(0.7, 1.0, 0.5 + (uv.x - 0.5) * sign(warn_side));
		over(acc, mix(OLD_BLOOD, BRUISE, 0.3), side * side * warn * beat * 0.7);
	}
	// Drowsy: heavy eyelids closing from top and bottom.
	if (drowsy_lid > 0.0) {
		float d = abs(uv.y - 0.5) * 2.0 + (1.0 - cos(p.x / aspect * 1.6)) * 0.25;
		over(acc, BRUISE * 0.6, smoothstep(1.0 - drowsy_lid, 1.0 - drowsy_lid + 0.18, d));
	}
	// Knocked down: the view dims and blurs into dancing stars...
	if (stars > 0.0) {
		over(acc, ICHOR, stars * 0.45);
		vec2 cell = floor(p * 5.0);
		vec2 f = fract(p * 5.0) - 0.5;
		float rnd = hash(cell);
		float tw = 0.5 + 0.5 * sin(TIME * (3.0 + rnd * 4.0) + rnd * 40.0);
		vec2 o = f - (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.6;
		float star = max(0.0, 1.0 - (abs(o.x) * 18.0 + abs(o.y) * 3.0)) + max(0.0, 1.0 - (abs(o.y) * 18.0 + abs(o.x) * 3.0));
		over(acc, mix(GOLD, vec3(1.0), rnd), clamp(star, 0.0, 1.0) * step(0.55, rnd) * tw * stars);
	}
	// ...then a rose-black iris closes.
	if (iris > 0.0) {
		float rad = mix(1.25, -0.05, iris);
		over(acc, mix(ICHOR, OLD_BLOOD, 0.15), smoothstep(rad, rad + 0.12, r));
	}
	// Coming round: a white-gold iris opens.
	if (wake < 1.0) {
		float rad = mix(-0.1, 1.3, wake);
		over(acc, DAWN, smoothstep(rad - 0.2, rad, r) * (1.0 - wake * 0.6));
	}
	COLOR = vec4(acc.rgb / max(acc.a, 0.0001), acc.a);
}
