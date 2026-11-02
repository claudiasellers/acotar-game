// The living mural's figures in their own colours (lane L33): each model
// keeps its real albedo (colour, texture or vertex colour), lit by the
// tableau's key light and painted on like the rest of the mural, with the
// gilt rim as an accent. mural_paint's ink-only silhouettes read as broken,
// dark rendering on screen; this keeps the paint and the gold but shows
// what the figures are.
// - albedo_col / albedo_tex / use_vcol: copied from the model's material.
// - ink, ink_mix 0..1: how far the body leans into the tableau's ink colour
//   (beasts lean far, so they stay half-seen).
// - reveal, origin, span, gold, rim_power, rim_gain, glow, drain, rust,
//   crack, alpha_cut: as in mural_paint, so the director drives both alike.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 albedo_col : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool use_vcol = false;
uniform float alpha_scissor = 0.0;
uniform float roughness = 0.75;
uniform vec3 ink : source_color = vec3(0.05, 0.04, 0.09);
uniform float ink_mix = 0.18;
uniform vec3 gold : source_color = vec3(1.0, 0.82, 0.45);
uniform float rim_power = 2.6;
uniform float rim_gain = 1.6;
uniform float glow = 0.0;
uniform float reveal = 1.0;
uniform vec3 origin = vec3(0.0);
uniform float span = 20.0;
uniform float drain = 0.0;
uniform float rust = 0.0;
uniform float crack = 0.0;
// The paint thins to nothing (the mother lets go): grain below this is gone.
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
	float p = q.x / span;
	float pool = fbm(q.xy * 0.32 + vec2(11.0, 3.0));
	float bristle = (fbm(vec2(q.x * 2.2, q.y * 9.0)) - 0.5) * 0.06;
	float edge = reveal * 1.6 - 0.3 - (pool - 0.5) * 0.5 + bristle - p;
	vec4 tex = texture(albedo_tex, UV) * albedo_col;
	if (use_vcol) {
		tex *= COLOR;
	}
	if (edge < 0.0 || (alpha_scissor > 0.0 && tex.a < alpha_scissor)) {
		discard;
	}
	float wet = smoothstep(0.05, 0.0, edge) * step(reveal, 0.999);
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), rim_power);
	vec3 g = gold * (1.0 - 0.85 * drain);
	vec3 col = mix(tex.rgb, ink, ink_mix);
	// Paint grain: a light hand of pigment over the colour.
	float grain = fbm(q.xy * 9.0 + q.z * 3.0);
	if (alpha_cut > 0.0 && grain < alpha_cut) {
		discard;
	}
	col *= 0.9 + 0.2 * grain;
	col = mix(col, vec3(0.55, 0.07, 0.05), rust * smoothstep(0.6, -0.4, q.y * 0.25 + grain * 0.5 - 0.2));
	float cr = smoothstep(0.02, 0.0, abs(fbm(q.xy * 2.2) - 0.5)) * crack;
	col = mix(col, vec3(0.0), cr);
	col *= 1.0 - 0.5 * drain;
	ALBEDO = col;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
	// A thin gilt line on the silhouette only: lit bodies need far less rim
	// than ink ones, or small far figures wash out to white.
	float line = fres * fres;
	EMISSION = g * (glow + line * rim_gain * 0.3) + g * wet * 2.0;
}
