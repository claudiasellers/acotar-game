// candy_lit_foliage: candy_lit for leaves and petals. Sways with the shared
// WindDriver globals (foliage_wind.gdshaderinc, like stylized_foliage), clips
// on albedo alpha, and starts from the foliage family's lighting: half wrap, the
// lilac shade tint, the doubled albedo response, no direct specular, warm rim.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
#define CANDY_WRAP_DEFAULT 0.5
#define CANDY_SHADE_DEFAULT vec4(0.62, 0.55, 0.78, 1.0)
#define CANDY_ALBEDO_MIX_DEFAULT 1.0
#define CANDY_GAIN_DEFAULT 2.0
#define CANDY_BURLEY_DEFAULT 0.0
#define CANDY_RIM_STRENGTH_DEFAULT 0.6
#define CANDY_RIM_COLOR_DEFAULT vec4(1.0, 0.86, 0.72, 1.0)
#define CANDY_NO_SPEC_LOBE
#define CANDY_SCISSOR
#define CANDY_WIND
#include "res://world/shared/shaders/candy_surface.gdshaderinc"
