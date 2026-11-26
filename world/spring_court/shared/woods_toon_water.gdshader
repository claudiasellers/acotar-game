// Toon water for the woods: flat candy colour with drifting foam cells and a
// foam line wherever the bank, a rock or a root meets the surface. No textures.
// The cell pattern is Megalithium's "Toon Style 3D Water Shader" (CC0,
// godotshaders.com, after NekotoArts), moved to world space so ribbons and
// ponds tile without UVs, with this project's uniforms (colours, clarity,
// sparkle, the rainbow falls).
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

global uniform float magic_amount;

uniform vec4 shallow_color : source_color = vec4(0.55, 0.88, 0.86, 1.0);
uniform vec4 deep_color : source_color = vec4(0.30, 0.55, 0.78, 1.0);
uniform vec4 foam_color : source_color = vec4(0.96, 0.99, 1.0, 1.0);
uniform float clarity : hint_range(0.0, 1.0) = 0.55;
uniform float flow_speed = 0.35;
uniform float sparkle : hint_range(0.0, 1.0) = 0.6;
uniform float rainbow : hint_range(0.0, 1.0) = 0.0;
uniform float cell_size = 7.0;
uniform float foam_width = 0.45;
uniform float depth_fade = 0.9;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

const float TWOPI = 6.283185307;
const float SIXPI = 18.84955592;
const int CELLS = 40;
const vec3 CELL[40] = {
	vec3(0.37378, 0.277169, 0.0268181), vec3(0.0317477, 0.540372, 0.0193742), vec3(0.430044, 0.882218, 0.0232337),
	vec3(0.641033, 0.695106, 0.0117864), vec3(0.0146398, 0.0791346, 0.0299458), vec3(0.43871, 0.394445, 0.0289087),
	vec3(0.909446, 0.878141, 0.028466), vec3(0.310149, 0.686637, 0.0128496), vec3(0.928617, 0.195986, 0.0152041),
	vec3(0.0438506, 0.868153, 0.0268601), vec3(0.308619, 0.194937, 0.00806102), vec3(0.349922, 0.449714, 0.00928667),
	vec3(0.0449556, 0.953415, 0.023126), vec3(0.117761, 0.503309, 0.0151272), vec3(0.563517, 0.244991, 0.0292322),
	vec3(0.566936, 0.954457, 0.00981141), vec3(0.0489944, 0.200931, 0.0178746), vec3(0.569297, 0.624893, 0.0132408),
	vec3(0.298347, 0.710972, 0.0114426), vec3(0.119673, 0.541984, 0.0124621), vec3(0.629598, 0.295629, 0.0198736),
	vec3(0.334357, 0.266278, 0.0187145), vec3(0.918044, 0.968163, 0.0182928), vec3(0.71403, 0.576945, 0.0215641),
	vec3(0.748873, 0.413325, 0.0110795), vec3(0.0623365, 0.896713, 0.0236203), vec3(0.647463, 0.654349, 0.0188713),
	vec3(0.428928, 0.382426, 0.0298806), vec3(0.525104, 0.572233, 0.0141796), vec3(0.431526, 0.911372, 0.0213234),
	vec3(0.514523, 0.243263, 0.0270685), vec3(0.502214, 0.47269, 0.0234534), vec3(0.693271, 0.431469, 0.0246533),
	vec3(0.0409132, 0.83406, 0.0191398), vec3(0.99871, 0.583864, 0.0107329), vec3(0.0761895, 0.16327, 0.0145935),
	vec3(0.949386, 0.802936, 0.0100873), vec3(0.896854, 0.803707, 0.013969), vec3(0.506365, 0.531118, 0.0144016),
	vec3(0.987324, 0.146545, 0.0288391)
};

float circ(vec2 pos, vec2 c, float s) {
	c = abs(pos - c);
	c = min(c, 1.0 - c);
	return smoothstep(0.0, 0.004, sqrt(s) - sqrt(dot(c, c))) * -1.0;
}

float waterlayer(vec2 uv) {
	uv = mod(uv, 1.0);
	float ret = 1.0;
	for (int i = 0; i < CELLS; i++) {
		ret += circ(uv, CELL[i].xy, CELL[i].z);
	}
	return max(ret, 0.0);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * flow_speed * 2.0;
	vec2 uv = wp.xz / cell_size + vec2(0.0, t * 0.05);
	float d1 = mod(uv.x + uv.y, TWOPI) + t * 0.07;
	float d2 = mod((uv.x + uv.y + 0.25) * 1.3, SIXPI) + t * 0.5;
	vec2 dist = vec2(sin(d1) * 0.15 + sin(d2) * 0.05, cos(d1) * 0.15 + cos(d2) * 0.05);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, waterlayer(uv + dist));
	float lines = waterlayer(vec2(1.0) - uv - dist.yx);

	// How much water lies between the surface and what is behind it.
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float thickness = -behind.z / behind.w + VERTEX.z;
	float edge = 1.0 - smoothstep(0.0, foam_width, thickness + (vnoise(wp.xz * 2.5 + t * 0.4) - 0.5) * foam_width);
	float foam = max(lines * 0.85, edge);
	col = mix(col, foam_color.rgb, foam);

	EMISSION = vec3(0.0);
	if (rainbow > 0.0) {
		float hue = fract(UV.y * 0.08 + UV.x * 0.3 - TIME * 0.25);
		vec3 bands = clamp(abs(fract(hue + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
		col = mix(col, mix(vec3(1.0), bands, 0.6), rainbow);
		EMISSION += bands * rainbow * 0.6 * magic_amount;
	}
	ALBEDO = col;
	ALPHA = max(mix(clarity, 0.96, smoothstep(0.0, depth_fade, thickness)), foam);
	ROUGHNESS = 0.4;
	SPECULAR = 0.2;
	float s = sparkle * magic_amount;
	float h = hash2(floor(wp.xz * 6.0 + vec2(floor(TIME * 3.0))));
	EMISSION += vec3(1.0, 0.95, 0.88) * step(0.992, h) * s * 2.5;
}
