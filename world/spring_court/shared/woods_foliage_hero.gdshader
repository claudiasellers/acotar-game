// The woods' flora material for a weenie seen from far off (the Great Oak at
// the wall crossing): fog-free, so it alone cuts through the haze while the
// canopy around it keeps its aerial perspective (experience-bar §2.1).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, fog_disabled;

#include "res://world/spring_court/shared/woods_foliage.gdshaderinc"
