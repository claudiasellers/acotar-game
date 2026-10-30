// A soft shaft of warm light falling into a clearing: the glade's "stage"
// (plans/experience-bar.md §2.4). Additive, unshaded, brightest down the
// middle of the beam and fading at its top, its foot and its silhouette, so
// it reads as light in the air rather than a cone.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.949, 0.824, 0.478, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.16;

varying float v_height;

void vertex() {
	v_height = VERTEX.y;
}

void fragment() {
	// CylinderMesh: UV.y runs 0 at the top to 1 at the foot.
	float along = smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.75, UV.y);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = pow(facing, 2.5);
	float drift = 0.85 + 0.15 * sin(TIME * 0.6 + v_height * 0.15);
	ALBEDO = color.rgb;
	ALPHA = strength * along * core * drift;
}
