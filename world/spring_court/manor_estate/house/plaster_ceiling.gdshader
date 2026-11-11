// Plaster ceilings (L38, quality audit A2/A4). A ceiling looks down, so its
// ambient light comes from the lower half of the sky, the lawn green, which
// turned every plain ceiling sage. Like the painted skies, it ignores ambient
// and carries a soft bounce of its own colour instead, as if lit from the
// room below; the room's lamps still light it directly. Albedo stays at or
// under 0.85 (L18-4 glare rule); the bounce is well below the lamps.
shader_type spatial;
render_mode cull_back, ambient_light_disabled;
// Lighting: candy_lit (render program T2), stock defaults = the look it had.
// Room shells are lit by the flat interior ambient; no sun bounce through the walls (T3a).
#define CANDY_BOUNCE_DEFAULT 0.0
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

uniform vec4 color : source_color = vec4(0.85, 0.82, 0.80, 1.0);
uniform float bounce = 0.32;
uniform float roughness = 0.88;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// faint trowel mottling so a big ceiling isn't one flat colour
	vec2 q = wpos.xz * 0.6;
	float n = hash(floor(q)) * 0.5 + hash(floor(q * 3.1)) * 0.5;
	vec3 c = min(color.rgb * mix(0.97, 1.02, n), vec3(0.85));
	ALBEDO = c;
	ROUGHNESS = roughness;
	EMISSION = c * bounce;
}
