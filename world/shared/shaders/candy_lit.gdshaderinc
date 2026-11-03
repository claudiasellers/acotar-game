// candy_lit: the one stylized lighting model for every surface (render program T2).
// Include in a spatial shader (not unshaded) to get its light() function, the
// shared fresnel rim and the band ramp. Every tunable is a uniform with a
// neutral default that reproduces the look it replaced; docs/tuning.md lists them.
//
// The response per light:
//   band   = ramp(wrap(N.L))         identity until a ramp texture is set
//   tint   = mix(shade_tint, 1, band)
//   diffuse = mix(1, ALBEDO, light_albedo_mix) * tint * band * burley * diffuse_gain
//   + ground_bounce: the sunlit ground's light thrown back up into the shade band
//     (T3a; directional lights only, out of the lit band, so lit pixels are unchanged)
//   + the candy rim: rim_color * candy_fresnel * rim_strength, LIT by each light
//     (scaled by its colour and shadowing), never an additive glow
//   + Godot's own light rim (CANDY_LOBES), clearcoat (CANDY_COAT) and GGX specular.
//
// Optional defines, set before the #include:
//   CANDY_LOBES          per-pixel specular + light rim; call candy_lobes(spec, rim, rim_tint)
//                        in fragment() instead of writing SPECULAR/RIM/RIM_TINT
//   CANDY_COAT           per-pixel clearcoat; call candy_coat(amount, roughness)
//                        instead of writing CLEARCOAT/CLEARCOAT_ROUGHNESS
//   CANDY_NO_SPEC_LOBE   no direct specular (the foliage family never had one)
//   CANDY_SOFT_SPEC      the soft power-law gloss of the court props instead of GGX
//   CANDY_BACKLIGHT_SCALE  expression scaling backlight_strength (e.g. (1.0 - v_blight))
//   CANDY_WRAP_DEFAULT, CANDY_SHADE_DEFAULT, CANDY_ALBEDO_MIX_DEFAULT,
//   CANDY_GAIN_DEFAULT, CANDY_BURLEY_DEFAULT, CANDY_RIM_STRENGTH_DEFAULT,
//   CANDY_RIM_COLOR_DEFAULT, CANDY_BACKLIGHT_DEFAULT, CANDY_BOUNCE_DEFAULT: per-family defaults.
//   CANDY_RIM_SCALE      expression scaling the rim (e.g. (1.0 - v_blight))

#ifndef CANDY_WRAP_DEFAULT
#define CANDY_WRAP_DEFAULT 0.0
#endif
#ifndef CANDY_SHADE_DEFAULT
#define CANDY_SHADE_DEFAULT vec4(1.0)
#endif
#ifndef CANDY_ALBEDO_MIX_DEFAULT
#define CANDY_ALBEDO_MIX_DEFAULT 0.0
#endif
#ifndef CANDY_GAIN_DEFAULT
#define CANDY_GAIN_DEFAULT 1.0
#endif
#ifndef CANDY_BURLEY_DEFAULT
#define CANDY_BURLEY_DEFAULT 1.0
#endif
#ifndef CANDY_RIM_STRENGTH_DEFAULT
#define CANDY_RIM_STRENGTH_DEFAULT 0.0
#endif
#ifndef CANDY_RIM_COLOR_DEFAULT
// Median of the warm rims this replaced (court_prop, court_foliage, woods_foliage, stylized_foliage).
#define CANDY_RIM_COLOR_DEFAULT vec4(1.0, 0.86, 0.74, 1.0)
#endif
#ifndef CANDY_BACKLIGHT_DEFAULT
#define CANDY_BACKLIGHT_DEFAULT 0.0
#endif
#ifndef CANDY_BOUNCE_DEFAULT
// T3a: every surface outdoors. The manor's room shells set 0: SDFGI lights those rooms.
#define CANDY_BOUNCE_DEFAULT 0.35
#endif

// 1 in the court, 0 under dread (GradeDirector).
global uniform float magic_amount;

group_uniforms candy_light;
// Diffuse band ramp (GradientTexture1D, red channel). Unset = identity, i.e.
// today's lambert response; data/render/candy_ramp_3band.tres is the 3-band preset.
uniform sampler2D diffuse_ramp : hint_default_transparent, filter_linear, repeat_disable;
uniform float wrap : hint_range(0.0, 1.0) = CANDY_WRAP_DEFAULT;
uniform vec4 shade_tint : source_color = CANDY_SHADE_DEFAULT;
uniform float light_albedo_mix : hint_range(0.0, 1.0) = CANDY_ALBEDO_MIX_DEFAULT;
uniform float diffuse_gain : hint_range(0.0, 4.0) = CANDY_GAIN_DEFAULT;
uniform float diffuse_burley : hint_range(0.0, 1.0) = CANDY_BURLEY_DEFAULT;
// T3a: light that the sunlit ground throws back up into the shade band. 0 = off.
uniform float ground_bounce : hint_range(0.0, 1.0) = CANDY_BOUNCE_DEFAULT;
// Mean albedo of the terrain textures (tools/lighting/terrain_albedo_average.gd).
uniform vec4 ground_bounce_color : source_color = vec4(0.523, 0.548, 0.545, 1.0);
uniform float backlight_strength : hint_range(0.0, 4.0) = CANDY_BACKLIGHT_DEFAULT;
group_uniforms candy_rim;
uniform vec4 rim_color : source_color = CANDY_RIM_COLOR_DEFAULT;
uniform float rim_strength : hint_range(0.0, 2.0) = CANDY_RIM_STRENGTH_DEFAULT;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
group_uniforms;
#ifndef CANDY_NO_SPEC_LOBE
uniform float specular : hint_range(0.0, 1.0) = 0.5;
#endif

// Varyings can't be written from a function, so these are macros (call in fragment()).
#ifdef CANDY_LOBES
varying float v_spec;
varying float v_rim;
varying float v_rim_tint;
#define candy_lobes(SPEC_AMT, RIM_AMT, RIM_TINT_AMT) SPECULAR = (SPEC_AMT); v_spec = SPECULAR; v_rim = (RIM_AMT); v_rim_tint = (RIM_TINT_AMT)
#endif
#ifdef CANDY_COAT
varying float v_coat;
varying float v_coat_rough;
#define candy_coat(COAT_AMT, COAT_ROUGH) CLEARCOAT = (COAT_AMT); CLEARCOAT_ROUGHNESS = (COAT_ROUGH); v_coat = CLEARCOAT; v_coat_rough = CLEARCOAT_ROUGHNESS
#endif

#include "res://world/shared/shaders/candy_rim.gdshaderinc"


float candy_band(float x) {
	vec4 r = texture(diffuse_ramp, vec2(x, 0.5));
	return mix(x, r.r, r.a);
}

float candy_schlick(float u) {
	float m = 1.0 - u;
	float m2 = m * m;
	return m2 * m2 * m;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float cndl = clamp(ndl, 0.0, 1.0);
	float band = candy_band(clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0));
	vec3 lc = LIGHT_COLOR * ATTENUATION / PI;
	vec3 h = normalize(VIEW + LIGHT);
	float cndv = max(dot(NORMAL, VIEW), 1e-4);
	float cldh = clamp(dot(LIGHT, h), 0.0, 1.0);
	float burley = 1.0;
	if (diffuse_burley > 0.0) {
		float fd90 = 2.0 * cldh * cldh * ROUGHNESS - 0.5;
		burley = mix(1.0, (1.0 + fd90 * candy_schlick(cndv)) * (1.0 + fd90 * candy_schlick(cndl)), diffuse_burley);
	}
	float coat_att = 1.0;
#ifdef CANDY_COAT
	if (v_coat > 0.0) {
		float cndh = clamp(dot(NORMAL, h), 0.0, 1.0);
		float a = cndh * mix(0.001, 0.1, v_coat_rough);
		float k = mix(0.001, 0.1, v_coat_rough) / (1.0 - cndh * cndh + a * a);
		float fr = mix(0.04, 1.0, candy_schlick(cldh)) * v_coat;
		coat_att = 1.0 - fr;
		SPECULAR_LIGHT += k * k / PI * (0.25 / (cldh * cldh + 1e-4)) * fr * cndl * LIGHT_COLOR * ATTENUATION;
	}
#endif
	vec3 alb = mix(vec3(1.0), ALBEDO, light_albedo_mix);
	vec3 tint = mix(shade_tint.rgb, vec3(1.0), band);
	DIFFUSE_LIGHT += alb * tint * band * burley * lc * diffuse_gain * coat_att;
	if (ground_bounce > 0.0 && LIGHT_IS_DIRECTIONAL) {
		// The ground this light reaches (its height over the horizon), seen by faces
		// that look down (1) or sideways (0.5). The surface's own shadow doesn't block
		// light coming up from the ground; the lit band doesn't take it.
		vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 lw = normalize((INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz);
		float ground_lit = clamp(lw.y, 0.0, 1.0);
		float sees_ground = clamp(0.5 - 0.5 * nw.y, 0.0, 1.0);
		float lit_band = band * dot(vec3(ATTENUATION), vec3(1.0 / 3.0));
		DIFFUSE_LIGHT += ground_bounce * ground_bounce_color.rgb * ground_lit * sees_ground * (1.0 - lit_band) * LIGHT_COLOR / PI;
	}
	if (backlight_strength > 0.0) {
		float back = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 3.0) * backlight_strength;
#ifdef CANDY_BACKLIGHT_SCALE
		back *= CANDY_BACKLIGHT_SCALE;
#endif
		DIFFUSE_LIGHT += alb * back * lc * 0.6;
	}
	if (rim_strength > 0.0) {
		// Lit, never glowing: the light's colour and shadow scale it; withdrawn under dread.
		float rim_amt = candy_fresnel(NORMAL, VIEW, rim_power) * rim_strength * mix(0.25, 1.0, clamp(magic_amount, 0.0, 1.0));
#ifdef CANDY_RIM_SCALE
		rim_amt *= CANDY_RIM_SCALE;
#endif
		SPECULAR_LIGHT += rim_color.rgb * rim_amt * lc;
	}
#ifdef CANDY_LOBES
	if (v_rim > 0.0) {
		float rim_light = candy_fresnel(NORMAL, VIEW, max(0.0, (1.0 - ROUGHNESS) * 16.0));
		DIFFUSE_LIGHT += rim_light * v_rim * mix(vec3(1.0), ALBEDO, v_rim_tint) * LIGHT_COLOR;
	}
#endif
#if defined(CANDY_SOFT_SPEC)
	float soft = pow(clamp(dot(NORMAL, h), 0.0, 1.0), mix(8.0, 96.0, 1.0 - ROUGHNESS)) * (1.0 - ROUGHNESS);
	SPECULAR_LIGHT += soft * LIGHT_COLOR * ATTENUATION / PI;
#elif !defined(CANDY_NO_SPEC_LOBE)
	if (ROUGHNESS > 0.0) {
		float alpha = ROUGHNESS * ROUGHNESS;
		float cndh = clamp(dot(NORMAL, h), 0.0, 1.0);
		float a = cndh * alpha;
		float k = alpha / (1.0 - cndh * cndh + a * a);
		float d = k * k / PI;
		float g = 0.5 / mix(2.0 * cndl * cndv, cndl + cndv, alpha);
#ifdef CANDY_LOBES
		float dielectric = 0.16 * v_spec * v_spec;
#else
		float dielectric = 0.16 * specular * specular;
#endif
		vec3 f0 = mix(vec3(dielectric), ALBEDO, vec3(METALLIC));
		float f90 = clamp(50.0 * f0.g, 0.0, 1.0);
		vec3 f = f0 + (f90 - f0) * candy_schlick(cldh);
		SPECULAR_LIGHT += cndl * d * f * g * LIGHT_COLOR * ATTENUATION * coat_att * SPECULAR_AMOUNT;
	}
#endif
}
