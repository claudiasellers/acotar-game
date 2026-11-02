// Procedural fur coat with optional shells (lane L43, quality audit B7).
// Used by creatures/materials/*_coat.tres on the great wolf and the doe.
// The mesh carries (tools/blender/creature_fur.py):
//   UV  = rest-pose position (x, y), V flipped by glTF; UV2 = (rest z, rib mask)
//   COLOR = (pale, fur length, dark, wet)
// The pattern lives in rest space, so it rides the skin instead of swimming.
// shell == 0 is the hide; each next_pass shell sets shell in (0, 1] and is
// pushed out along the normal, combed back and drooped, cut to strands.
shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 coat : source_color = vec3(0.16, 0.16, 0.18);
uniform vec3 pale : source_color = vec3(0.62, 0.58, 0.5);
uniform vec3 dark : source_color = vec3(0.06, 0.06, 0.07);
uniform vec3 tip : source_color = vec3(0.5, 0.52, 0.56);
uniform vec3 mouth : source_color = vec3(0.16, 0.03, 0.04);
uniform float tip_amount : hint_range(0.0, 1.0) = 0.35;
uniform float shell : hint_range(0.0, 1.0) = 0.0;
uniform float fur_length = 0.05;
uniform float density = 90.0;
uniform float droop = 0.35;
uniform float comb = 0.5;
uniform float streak : hint_range(0.0, 1.0) = 0.45;
uniform float rib_depth : hint_range(0.0, 1.0) = 0.0;
uniform float rib_spacing = 0.09;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.45;
uniform float roughness_fur : hint_range(0.0, 1.0) = 0.82;

varying vec3 rest;
varying vec4 zone;
varying float rib;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

// Height (0..1) of the strand standing at this point; 0 between strands.
float strand_height(vec3 p) {
	float best = 0.0;
	for (int k = 0; k < 2; k++) {
		vec3 q = p * density + float(k) * vec3(0.37, 0.71, 0.53);
		vec3 c = floor(q);
		float h = 0.55 + 0.45 * hash13(c + 11.0 * float(k));
		float d = length(fract(q) - 0.5) * 2.0;
		best = max(best, h * (1.0 - d));
	}
	return best;
}

void vertex() {
	rest = vec3(UV.x, 1.0 - UV.y, UV2.x);
	rib = 1.0 - UV2.y;
	zone = COLOR;
	if (shell > 0.0) {
		float h = shell * fur_length * zone.g;
		// Model space: y up, the head toward -Z, so combing runs to +Z.
		VERTEX += NORMAL * h + vec3(0.0, -droop * h * shell, comb * h * shell);
	}
}

void fragment() {
	float s = strand_height(rest);
	// Far away a strand is under a pixel: settle on its average so the shells
	// read as a soft fattened coat instead of shimmering contour rings.
	float footprint = length(fwidth(rest)) * density;
	s = mix(s, 0.45, smoothstep(0.6, 1.6, footprint));
	if (shell > 0.0 && (zone.g < 0.04 || s < shell * 0.95 + 0.05)) {
		discard;
	}
	// Coat: base, ivory underparts, obsidian saddle and mask, then the
	// streaky lie of the hair (stretched along the body).
	vec3 col = mix(coat, pale, zone.r);
	float st = vnoise(rest * vec3(density * 0.18, density * 0.035, density * 0.12));
	float big = vnoise(rest * 6.0);
	col *= mix(1.0, 0.6 + 0.8 * st, streak) * (0.85 + 0.3 * big);
	// Root shade to tip sheen: the hide is darkest, the outer shells catch silver.
	float layer = shell > 0.0 ? shell : 0.0;
	col *= mix(0.55 + 0.35 * s, 1.0, layer);
	col = mix(col, tip, tip_amount * layer * layer * (1.0 - zone.b));
	// Ribs: grooves between the ribs on a starved flank.
	float phase = (rest.y - 0.35 * rest.z) / rib_spacing;
	float ridge = pow(0.5 + 0.5 * cos(6.2831853 * phase), 2.0);
	col *= 1.0 - rib_depth * rib * (1.0 - ridge) * (1.0 - layer);
	// Wet mouth, then black lips, nose and pupils on top.
	col = mix(col, mouth, zone.a);
	col = mix(col, dark, zone.b);
	ALBEDO = col;
	ROUGHNESS = mix(roughness_fur, 0.12, zone.a);
	SPECULAR = mix(0.3, 0.7, zone.a);
	RIM = rim_amount * (1.0 - zone.a) * (0.5 + 0.5 * layer);
	RIM_TINT = 0.6;
}
