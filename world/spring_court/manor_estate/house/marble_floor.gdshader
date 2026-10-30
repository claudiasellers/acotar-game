// Rococo marble floor for the state rooms (experience bar §2.6): a damier of
// pearl and tinted lozenges with a fine gilt-grey joint and soft veining,
// painted in world space so a whole level's marble floors share one material.
// Darker than plain pearl so the room's hero, not the floor, is the brightest
// thing in view (light hierarchy, §2.1).
shader_type spatial;
render_mode cull_back;

uniform vec4 light_stone : source_color = vec4(0.97, 0.93, 0.92, 1.0);
uniform vec4 dark_stone : source_color = vec4(0.82, 0.74, 0.84, 1.0);
uniform vec4 joint : source_color = vec4(0.86, 0.76, 0.58, 1.0);
uniform float tile = 0.9;

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

void fragment() {
	// rotate 45 degrees for lozenges
	vec2 q = vec2(wpos.x + wpos.z, wpos.x - wpos.z) * 0.70710678 / tile;
	vec2 cell = floor(q);
	vec2 f = fract(q) - 0.5;
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 col = mix(light_stone.rgb, dark_stone.rgb, checker * 0.55);
	float vein = noise(wpos.xz * 1.7 + cell * 3.1) * 0.6 + noise(wpos.xz * 5.3) * 0.4;
	col *= mix(0.94, 1.03, smoothstep(0.3, 0.75, vein));
	float edge = max(abs(f.x), abs(f.y));
	float aa = max(fwidth(edge), 0.0005);
	float j = smoothstep(0.5 - 0.012 - aa, 0.5 - 0.012 + aa, edge);
	ALBEDO = mix(col, joint.rgb, j);
	ROUGHNESS = mix(0.22, 0.5, j);
	METALLIC = 0.0;
	SPECULAR = 0.45;
	CLEARCOAT = 0.4 * (1.0 - j);
	CLEARCOAT_ROUGHNESS = 0.2;
}
