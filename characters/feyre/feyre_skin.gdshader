// Feyre's skin: base albedo + six makeup layers + soft rim light.
//
// Masks are baked by tools/blender/feyre/build_feyre.py from the head's UVs:
//   makeup_mask_a  R lips  G eyeshadow  B liner  A blush
//   makeup_mask_b  R brows G face_paint
// Unassigned masks read as black, so the same shader works for body surfaces
// (which simply have no makeup).
//
// Each layer: <c>_color (rgb + alpha as opacity), <c>_amount (0..1),
// <c>_sheen (0 matte .. 1 glossy shimmer).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.86, 0.69, 0.57, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.62;
uniform float specular_level : hint_range(0.0, 1.0) = 0.4;
uniform float subsurface : hint_range(0.0, 1.0) = 0.25;

uniform sampler2D makeup_mask_a : hint_default_black, filter_linear_mipmap;
uniform sampler2D makeup_mask_b : hint_default_black, filter_linear_mipmap;

uniform vec4 lips_color : source_color = vec4(0.72, 0.36, 0.38, 1.0);
uniform float lips_amount : hint_range(0.0, 1.0) = 0.25;
uniform float lips_sheen : hint_range(0.0, 1.0) = 0.1;

uniform vec4 eyeshadow_color : source_color = vec4(0.55, 0.42, 0.55, 1.0);
uniform float eyeshadow_amount : hint_range(0.0, 1.0) = 0.0;
uniform float eyeshadow_sheen : hint_range(0.0, 1.0) = 0.3;

uniform vec4 liner_color : source_color = vec4(0.08, 0.06, 0.05, 1.0);
uniform float liner_amount : hint_range(0.0, 1.0) = 0.0;
uniform float liner_sheen : hint_range(0.0, 1.0) = 0.0;

uniform vec4 blush_color : source_color = vec4(0.90, 0.48, 0.45, 1.0);
uniform float blush_amount : hint_range(0.0, 1.0) = 0.0;
uniform float blush_sheen : hint_range(0.0, 1.0) = 0.15;

// Brows are painted (no brow geometry yet), so they default on.
uniform vec4 brows_color : source_color = vec4(0.30, 0.20, 0.12, 1.0);
uniform float brows_amount : hint_range(0.0, 1.0) = 0.85;
uniform float brows_sheen : hint_range(0.0, 1.0) = 0.0;

uniform vec4 face_paint_color : source_color = vec4(0.95, 0.80, 0.35, 1.0);
uniform float face_paint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float face_paint_sheen : hint_range(0.0, 1.0) = 0.6;

// Shimmer: tiny view-dependent glints scaled by each layer's sheen.
uniform float shimmer_scale = 220.0;
uniform float shimmer_strength : hint_range(0.0, 2.0) = 0.6;

// Soft fresnel rim (stylised, gentle).
uniform vec4 rim_color : source_color = vec4(1.0, 0.86, 0.78, 1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.25;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void layer(inout vec3 col, inout float sheen, inout vec3 sheen_col, float mask, vec4 c, float amount, float s) {
	float w = clamp(mask * amount * c.a, 0.0, 1.0);
	col = mix(col, c.rgb, w);
	sheen += w * s;
	sheen_col += c.rgb * w * s;
}

void fragment() {
	vec4 ma = texture(makeup_mask_a, UV);
	vec4 mb = texture(makeup_mask_b, UV);
	vec3 col = albedo.rgb;
	float sheen = 0.0;
	vec3 sheen_col = vec3(0.0);
	layer(col, sheen, sheen_col, ma.a, blush_color, blush_amount, blush_sheen);
	layer(col, sheen, sheen_col, ma.g, eyeshadow_color, eyeshadow_amount, eyeshadow_sheen);
	layer(col, sheen, sheen_col, mb.r, brows_color, brows_amount, brows_sheen);
	layer(col, sheen, sheen_col, mb.g, face_paint_color, face_paint_amount, face_paint_sheen);
	layer(col, sheen, sheen_col, ma.b, liner_color, liner_amount, liner_sheen);
	layer(col, sheen, sheen_col, ma.r, lips_color, lips_amount, lips_sheen);
	sheen = clamp(sheen, 0.0, 1.0);

	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// Glints: hashed cells that twinkle as the view angle changes.
	vec2 cell = floor(UV * shimmer_scale);
	float g = hash21(cell);
	float twinkle = smoothstep(0.92, 1.0, fract(g * 7.0 + ndv * 3.0 + g));
	vec3 glint = (sheen_col / max(sheen, 1e-3) + vec3(0.35)) * twinkle * sheen * shimmer_strength;

	float fres = pow(1.0 - ndv, rim_power);

	ALBEDO = col;
	ROUGHNESS = mix(roughness, 0.28, sheen);
	SPECULAR = mix(specular_level, 0.7, sheen);
	EMISSION = glint * 0.25 + rim_color.rgb * rim_amount * fres * 0.5;
	SSS_STRENGTH = subsurface;
}
