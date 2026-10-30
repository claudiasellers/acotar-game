// The woods' flora material: the shared stylized look (world/shared/shaders/
// stylized_foliage.gdshader: wrapped lilac-tinted light, warm rim, sparkle
// scaled by magic_amount) adapted to the woods' multi-coloured procedural
// meshes, which keep albedo in vertex COLOR and wind flex in UV.x instead of
// COLOR.r. UV.y is glow (faelights, glowcaps, starmoss).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://world/spring_court/shared/woods_foliage.gdshaderinc"
