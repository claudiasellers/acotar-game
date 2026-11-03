// candy_lit_unlit: the FX member of the candy_lit family (glows, motes, decals).
// Unshaded, alpha-blended, double-sided, never writes depth or takes shadows.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
#define CANDY_UNSHADED
#define CANDY_ALPHA
#include "res://world/shared/shaders/candy_surface.gdshaderinc"
