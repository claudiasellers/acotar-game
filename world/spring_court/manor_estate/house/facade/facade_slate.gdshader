// Lilac fish-scale slate for the manor's roofs (L42; keeper: lilac, never
// emerald, so the manor never reads as the Archerons' ch28 chateau).
// World-space scales laid along each roof face, rows running level.
shader_type spatial;
render_mode cull_disabled;
// Lighting: candy_lit (render program T2), stock defaults = the look it had.
#define CANDY_LOBES
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

uniform vec3 slate : source_color = vec3(0.60, 0.52, 0.80);
uniform float row_h = 0.32;
uniform float tile_w = 0.42;

varying vec3 wpos;
varying vec3 wnrm;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 side = cross(vec3(0.0, 1.0, 0.0), wnrm);
	if (length(side) < 0.05) {
		side = vec3(1.0, 0.0, 0.0);
	}
	side = normalize(side);
	float u = dot(wpos, side);
	float v = wpos.y;
	float row = floor(v / row_h);
	float off = mod(row, 2.0) * 0.5;
	float colx = floor(u / tile_w + off);
	vec2 f = vec2(fract(u / tile_w + off) - 0.5, fract(v / row_h));
	// round-bottomed scale: distance from the scale's lower arc
	float r = length(vec2(f.x * tile_w, (f.y - 0.62) * row_h)) / (tile_w * 0.5);
	float edge = smoothstep(0.82, 1.0, r);
	float h = hash2(vec2(colx, row));
	vec3 c = slate * (0.90 + 0.14 * h);
	c = mix(c, c * vec3(1.05, 1.0, 1.08), smoothstep(0.3, 0.0, f.y));
	c *= 1.0 - 0.22 * edge;
	ALBEDO = min(c, vec3(0.85));
	ROUGHNESS = 0.42 + 0.2 * edge;
	candy_lobes(0.5, 0.0, 0.5);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.10, 0.07, 0.16) * fres;
}
