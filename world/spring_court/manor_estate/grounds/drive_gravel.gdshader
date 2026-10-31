// The drive and forecourt: blush-and-pearl gravel with gold grit and the odd
// fallen petal, in world space so long drapes never stretch it (R3).
shader_type spatial;
render_mode cull_back;

uniform vec3 sand : source_color = vec3(0.93, 0.80, 0.74);
uniform vec3 pearl : source_color = vec3(1.0, 0.95, 0.92);
uniform vec3 taupe : source_color = vec3(0.78, 0.64, 0.60);
uniform vec3 grit : source_color = vec3(0.95, 0.78, 0.42);
uniform vec3 petal : source_color = vec3(1.0, 0.62, 0.76);
uniform float pebble_size = 0.14;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// two offset layers of jittered pebbles of mixed size: no visible grid
	vec3 col = sand;
	for (int layer = 0; layer < 2; layer++) {
		float sz = pebble_size * (layer == 0 ? 1.0 : 0.63);
		vec2 p = world_pos.xz / sz + float(layer) * 17.3;
		vec2 cell = floor(p);
		vec2 f = fract(p) - 0.5;
		float h = hash(cell);
		vec2 jitter = (vec2(hash(cell + 7.0), hash(cell + 3.0)) - 0.5) * 0.5;
		float radius = mix(0.12, 0.34, hash(cell + 13.0));
		float peb = smoothstep(radius, radius * 0.55, length(f - jitter)) * step(0.35, hash(cell + 29.0));
		col = mix(col, pearl, step(0.6, h) * peb * 0.8);
		col = mix(col, taupe, step(h, 0.22) * peb * 0.55);
		col = mix(col, grit, step(0.95, hash(cell + 11.0)) * peb);
	}
	// broad soft variation so it never reads as a flat strip
	vec2 big = world_pos.xz * 0.15;
	float wash = hash(floor(big)) * 0.5 + hash(floor(big * 2.3 + 5.0)) * 0.5;
	col *= mix(0.94, 1.03, wash);
	// a scatter of petals, a petal every few metres
	vec2 q = world_pos.xz / 0.6;
	vec2 qc = floor(q);
	vec2 qf = fract(q) - 0.5;
	float on = step(0.93, hash(qc + 19.0));
	float ang = hash(qc + 23.0) * 6.283;
	vec2 r = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * qf;
	float petal_shape = smoothstep(1.0, 0.8, length(r * vec2(5.5, 9.0)));
	col = mix(col, petal, on * petal_shape);
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.55, on * petal_shape);
	SPECULAR = 0.35;
}
