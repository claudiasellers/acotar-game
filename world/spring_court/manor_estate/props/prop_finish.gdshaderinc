// Shared body of prop_finish.gdshader and prop_finish_clear.gdshader: one
// shader for every Blender prop finish (tools/blender/prop_kit.py), so a merged
// room of props is one opaque draw call plus one for glass and water.
// Vertex colour = albedo (linear). UV.x carries the finish: (index + 0.5) / 16.
// 0 matte, 1 satin, 2 fabric, 3 gold, 4 pearl, 5 glass, 6 mirror, 7 glow, 8 water, 9 leaf.

uniform float glow_energy : hint_range(0.0, 8.0) = 2.4;

varying flat int finish;

void vertex() {
	finish = int(UV.x * 16.0);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float rough = 0.6;
	float metal = 0.0;
	float rim = 0.0;
	float rim_tint = 0.5;
	float coat = 0.0;
	float coat_rough = 0.3;
	vec3 emit = vec3(0.0);
	if (finish == 0) { rough = 0.78; }
	else if (finish == 1) { rough = 0.42; coat = 0.3; coat_rough = 0.35; }
	else if (finish == 2) { rough = 0.92; rim = 0.18; rim_tint = 0.8; }                    // velvet/silk sheen
	else if (finish == 3) { rough = 0.3; metal = 1.0; rim = 0.3; rim_tint = 1.0; }         // gilt
	else if (finish == 4) { rough = 0.18; metal = 0.12; coat = 0.7; coat_rough = 0.15; rim = 0.6; rim_tint = 0.7; }  // pearl
	else if (finish == 5) { rough = 0.05; metal = 0.1; coat = 1.0; rim = 0.5; }            // glass
	else if (finish == 6) { rough = 0.06; metal = 0.9; rim = 0.4; }                        // mirror
	else if (finish == 7) { rough = 0.5; emit = c * glow_energy; }                         // flames, faelights
	else if (finish == 8) { rough = 0.04; metal = 0.2; }                                   // water
	else if (finish == 9) { rough = 0.7; rim = 0.35; rim_tint = 0.6; }                     // leaves
	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = metal;
	RIM = rim;
	RIM_TINT = rim_tint;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = coat_rough;
	EMISSION = emit;
#ifdef CLEAR
	ALPHA = COLOR.a * (finish == 8 ? 0.82 : 1.0);
#endif
}
