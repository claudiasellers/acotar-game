// Oil on canvas for the manor's paintings (L39). The picture comes from one
// layer of the paintings array (whites already capped at 0.85, L18-4): the
// whole part of UV.x is the layer, so every canvas shares this material; the shader adds the canvas
// weave and a varnish sheen that catches the room's lights. Never emissive:
// there is no daytime glow before the glamour lifts (director, L39).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2DArray sheet : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 sheet_px = vec2(2048.0, 2040.0);
uniform float weave = 0.035;
uniform float varnish = 0.6;

void fragment() {
	float layer = floor(UV.x);
	vec2 uv = vec2(UV.x - layer, UV.y);
	vec3 c = texture(sheet, vec3(uv, layer)).rgb;
	// the canvas weave, about two texels a thread, faded where it would shimmer
	vec2 t = uv * sheet_px * 0.5;
	float fade = clamp(1.6 - length(fwidth(t)) * 1.4, 0.0, 1.0);
	float w = (sin(t.x * TAU) * sin(t.y * TAU)) * fade;
	c *= 1.0 + w * weave;
	ALBEDO = min(c, vec3(0.694)); // 0.85 in sRGB
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	// varnish pools in the thick paint: a little glossier in the lights
	ROUGHNESS = mix(0.62, 0.34, varnish) - lum * 0.08 + w * 0.04;
	SPECULAR = 0.45;
	METALLIC = 0.0;
}
