// A great tree's long fronds (the Weeping Lady: CourtGreatTrees;
// tools/blender/estate_tree.py `frond_tile`). The estate trees' cut-out leaf
// shader, with the frond picture repeating down a strand at its own size
// instead of stretched over the whole of it: a strand thirty metres long keeps
// leaves the size of a willow's. How far down the strand a point hangs (the
// wind's hold on it) comes in the vertex colour's green.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#define ESTATE_TREE_CARDS
#define FROND_TILED
#include "res://world/spring_court/manor_estate/flora/trees/estate_tree.gdshaderinc"
