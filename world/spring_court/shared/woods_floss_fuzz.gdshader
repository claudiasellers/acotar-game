// The candyfloss tree's fuzz: a second skin standing a little off the billows,
// cut into small tufts by the cotton picture's alpha, thinning out with
// distance and gone past fuzz_fade_end. See woods_floss.gdshader; the body is
// woods_floss.gdshaderinc.
shader_type spatial;
render_mode depth_draw_opaque;

#define FLOSS_FUZZ
#include "woods_floss.gdshaderinc"
