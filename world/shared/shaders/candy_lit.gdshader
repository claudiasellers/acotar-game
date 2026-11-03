// candy_lit: the default opaque stylized surface (render program T2).
// The stock material defaults; CandyMaterial picks other variants under candy/.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;
#include "res://world/shared/shaders/candy_surface.gdshaderinc"
