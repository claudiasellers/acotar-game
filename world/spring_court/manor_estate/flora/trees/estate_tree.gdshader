// The estate's trees (wider-court D2/E2; tools/blender/estate_tree.py), lit
// like the rest of the estate's flora: candy_lit with stylized_foliage's
// response (wrapped light, lilac shade, a soft warm rim). A material per part
// of the tree (EstateTrees). This shader draws the cut-out part (1);
// estate_tree_solid.gdshader draws the solid ones (0, 2, 3). Their shared body
// is estate_tree.gdshaderinc.
//   part 0 bark:   the painted bark's light and dark in bark_col, laid on
//                  from three sides (the skinned wood has no UVs, so no seams)
//   part 1 leaves: a leaf-clump card. A leaf clump is a painted value, banded
//                  shadow -> mid -> light (as court_tree.gdshader's painted
//                  sprays); a blossom clump (own_colour) keeps its painted
//                  colours. The normal is the cloud's, not the card's: the
//                  crown shades as soft cotton-candy clouds while its outline
//                  and surface are leaves. The willow's fronds are part 1 too
//                  (hanging: they sway most at their tips).
//   part 2 core:   the ball inside each cloud: leaves in shade, the crown's depth
//   part 3 fruit:  vertex-coloured (the pears)
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#define ESTATE_TREE_CARDS
#include "estate_tree.gdshaderinc"
