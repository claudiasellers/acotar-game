// Mown stripes on the lawns either side of the drive (L56-2): a thin tint laid
// over the terrain, alternating lighter and darker 4 m bands along the drive's
// axis, the way a lawn mown up and down catches the light. Soft at its edges
// and gone by ~180 m. Vertex alpha carries the edge fade.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform float band = 4.0;
uniform float strength = 0.16;
uniform vec3 light_tint : source_color = vec3(0.56, 0.66, 0.36);
uniform vec3 dark_tint : source_color = vec3(0.16, 0.26, 0.12);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float s = sin(world_pos.x * 3.14159 / band);
	float stripe = smoothstep(-0.25, 0.25, s);
	float far = 1.0 - smoothstep(120.0, 180.0, length(world_pos - CAMERA_POSITION_WORLD));
	ALBEDO = mix(dark_tint, light_tint, stripe);
	ALPHA = strength * COLOR.a * far;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
