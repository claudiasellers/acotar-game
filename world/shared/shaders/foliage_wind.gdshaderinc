// Shared GPU wind for every swaying mesh (scatter, trees, reeds, cloth).
// Globals are set from project.godot [shader_globals] and driven at runtime by
// the World scene from Weather.wind_at() and Clock. Include in a spatial shader:
//   #include "res://world/shared/shaders/foliage_wind.gdshaderinc"
//   void vertex() { VERTEX = foliage_wind(VERTEX, MODEL_MATRIX, COLOR.r); }
// COLOR.r (vertex colour red) = how free that vertex is to move, 0 at the root.

global uniform vec3 wind_direction;
global uniform float wind_strength;
global uniform float snow_cover;
instance uniform float wind_amount = 0.5;

vec3 foliage_wind(vec3 vertex, mat4 model, float flex) {
	vec3 world_origin = model[3].xyz;
	float phase = dot(world_origin.xz, vec2(0.071, 0.113));
	float gust = sin(TIME * 1.7 + phase) * 0.6 + sin(TIME * 3.9 + phase * 2.3) * 0.25;
	float sway = (wind_strength * (0.6 + gust)) * wind_amount * flex;
	vec3 dir = normalize(vec3(wind_direction.x, 0.0, wind_direction.z) + vec3(0.0001));
	vec3 local_dir = (inverse(model) * vec4(dir, 0.0)).xyz;
	return vertex + local_dir * sway * max(vertex.y, 0.0) * 0.15;
}
