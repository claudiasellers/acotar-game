// The living mural's paint (lane L33): ink bodies with gilt edges, painted on
// by brush strokes. Unshaded, so the look is the painter's, not the light's.
// - ink: the body colour; gold: the rim (fresnel) and the wet stroke edge.
// - reveal 0..1: horizontal brush strokes sweep across the tableau, each
//   band starting at its own offset with a ragged, bristled edge.
// - origin / span: the tableau's left edge and width in world x, so every
//   mesh in one tableau shares one set of strokes.
// - drain 0..1: the gold goes out of the paint (horror beats).
// - rust 0..1: red bleeds up from below. crack 0..1: dark cracks spread.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 ink : source_color = vec3(0.05, 0.04, 0.09);
uniform vec3 gold : source_color = vec3(1.0, 0.82, 0.45);
uniform float rim_power = 2.6;
uniform float rim_gain = 1.6;
uniform float glow = 0.0;
uniform float reveal = 1.0;
uniform vec3 origin = vec3(0.0);
uniform float span = 20.0;
uniform float band = 0.55;
uniform float drain = 0.0;
uniform float rust = 0.0;
uniform float crack = 0.0;
uniform float alpha_cut = 0.0;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int k = 0; k < 4; k++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 q = wpos - origin;
	// Brush strokes: bands in y, each sweeping in x from its own start.
	float row = floor((q.y + 0.25 * noise(vec2(q.x * 0.35, 3.1))) / band);
	float start = hash(vec2(row, 7.0)) * 0.35;
	float p = q.x / span;
	float bristle = (fbm(vec2(q.x * 3.0, q.y * 28.0)) - 0.5) * 0.08;
	float front = reveal * 1.45 - start + bristle;
	float edge = front - p;
	if (edge < 0.0) {
		discard;
	}
	float wet = smoothstep(0.05, 0.0, edge) * step(reveal, 0.999);

	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), rim_power);
	vec3 g = gold * (1.0 - 0.85 * drain);
	vec3 col = ink;
	// Paint grain and the canvas weave.
	float grain = fbm(q.xy * 9.0 + q.z * 3.0);
	col *= 0.82 + 0.36 * grain;
	col = mix(col, vec3(0.55, 0.07, 0.05), rust * smoothstep(0.6, -0.4, q.y * 0.25 + grain * 0.5 - 0.2));
	float cr = smoothstep(0.02, 0.0, abs(fbm(q.xy * 2.2) - 0.5)) * crack;
	col = mix(col, vec3(0.0), cr);
	col += g * fres * rim_gain;
	col += g * wet * 2.2;
	ALBEDO = col;
	EMISSION = g * (glow + fres * rim_gain * 0.35) + g * wet;
	if (alpha_cut > 0.0 && grain < alpha_cut) {
		discard;
	}
}
