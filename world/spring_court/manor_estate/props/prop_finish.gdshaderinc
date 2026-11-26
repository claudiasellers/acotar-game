// Shared body of prop_finish.gdshader and prop_finish_clear.gdshader: one
// shader for every Blender prop finish (tools/blender/prop_kit.py), so a merged
// room of props is one opaque draw call plus one for glass and water.
// Vertex colour = albedo (linear). UV.x carries the finish: (index + 0.5) / 16.
// 0 matte, 1 satin, 2 fabric, 3 gold, 4 pearl, 5 glass, 6 mirror, 7 glow, 8 water, 9 leaf.

// Lighting: candy_lit (render program T2); glass's rim and clearcoat go through its lobes.
#define CANDY_LOBES
#define CANDY_COAT
#include "res://world/shared/shaders/candy_lit.gdshaderinc"

// Glare rule (L18-4), as on every candy surface: no lit finish reflects more than
// 0.85 per channel, so white linen and pale paint keep their shape under a lamp.
const float ALBEDO_CAP = 0.85;

uniform float glow_energy : hint_range(0.0, 8.0) = 2.4;
// magic_amount (declared by candy_lit) is the grade's magic, 0..1: the
// glow of flames and faelights follows it.

varying flat int finish;

void vertex() {
	finish = int(UV.x * 16.0);
}

// The finishes are what the thing is made of, lit by the room and nothing else
// (owner, 2026-11-25: furniture looked waxy and self-lit). Painted wood, cloth,
// stone and china are matte to satin with no clearcoat and no rim; only real
// glass, mirror and water are glossy, and only finish 7 (flames, faelights) emits.
void fragment() {
	vec3 c = COLOR.rgb;
	float rough = 0.6;
	float metal = 0.0;
	float spec = 0.5;
	float rim = 0.0;
	float coat = 0.0;
	float coat_rough = 0.3;
	vec3 emit = vec3(0.0);
	if (finish == 0) { rough = 0.85; spec = 0.4; }                          // matte: plaster, stone, raw wood
	else if (finish == 1) { rough = 0.62; }                                 // satin: painted and polished wood
	else if (finish == 2) { rough = 0.95; spec = 0.25; }                    // fabric: linen, velvet, silk
	else if (finish == 3) { rough = 0.42; metal = 1.0; }                    // gilt: brushed, not mirror-bright
	else if (finish == 4) { rough = 0.5; }                                  // pearl: china, marble, white paint
	else if (finish == 5) { rough = 0.08; metal = 0.1; coat = 0.6; rim = 0.15; }   // glass
	else if (finish == 6) { rough = 0.06; metal = 0.9; }                    // mirror
	else if (finish == 7) { rough = 0.5; emit = c * glow_energy; }          // flames, faelights
	else if (finish == 8) { rough = 0.04; metal = 0.2; }                    // water
	else if (finish == 9) { rough = 0.75; spec = 0.35; }                    // leaves
	float magic = clamp(magic_amount, 0.0, 1.0);
	emit *= mix(0.7, 1.0, magic);    // candle flames stay as points in the dark
	ALBEDO = finish == 7 ? c : min(c, vec3(ALBEDO_CAP));
	ROUGHNESS = rough;
	METALLIC = metal;
	candy_lobes(spec, rim, 0.5);
	candy_coat(coat, coat_rough);
	EMISSION = emit;
#ifdef CLEAR
	ALPHA = COLOR.a * (finish == 8 ? 0.82 : 1.0);
#endif
}
