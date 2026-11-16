// Candyfloss: the candyfloss tree's crown (tools/woods/blender/
// special_trees.py builds it, tools/woods/gen_floss_cotton.py paints its
// cotton). The crown is a heap of soft billows with a second skin standing a
// little off them: the fuzz. The cotton picture is laid on from three sides
// (no seams): its value mottles the fluff, its alpha cuts the fuzz into small
// tufts, so every billow has a soft broken edge instead of an outline.
//
// The mesh carries no colour of its own: COLOR.r is a tone (deep in the
// creases between billows, light on their tops) and each tree takes its
// colours, pale over deep, from where it stands: most trees one pair, and
// multi_share of them a pair to each tuft (COLOR.g says which of four a
// billow's tuft is). A grove is a mix of pink, rose, lilac and pearl trees
// and trees of all four, from one model. UV.x is the wind
// flex. Lit like the woods' flora.
//
// This is the billows, drawn solid. The fuzz is its own mesh on
// woods_floss_fuzz.gdshader; the body of both is woods_floss.gdshaderinc.
shader_type spatial;
render_mode depth_draw_opaque;

#include "woods_floss.gdshaderinc"
