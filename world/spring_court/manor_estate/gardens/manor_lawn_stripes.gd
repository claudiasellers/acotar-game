## Mown stripes on the front lawns (L56-2): the lawns either side of the drive,
## from the forecourt to past the dismount point, read as a cared-for lawn
## rather than a flat green plain. One draped, tinted overlay mesh (one draw).
## [X] invented.
class_name ManorLawnStripes
extends RefCounted

const SHADER := preload("res://world/spring_court/manor_estate/gardens/lawn_stripes.gdshader")
## Lawn areas (clear of the pond and the walled orchard), and the edge fade.
const AREAS: Array[Rect2] = [Rect2(8.0, 30.0, 116.0, 124.0), Rect2(-150.0, 30.0, 142.0, 124.0)]
const FADE := 12.0
const STEP := 2.0
const LIFT := 0.05


static func build(parent: Node3D) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in AREAS:
		var nx := ceili(r.size.x / STEP)
		var nz := ceili(r.size.y / STEP)
		var verts := []
		for j in nz + 1:
			for i in nx + 1:
				var x := r.position.x + r.size.x * i / nx
				var z := r.position.y + r.size.y * j / nz
				var edge := minf(minf(x - r.position.x, r.end.x - x), minf(z - r.position.y, r.end.y - z))
				var a := clampf(edge / FADE, 0.0, 1.0)
				# keep off the drive and the forecourt
				if absf(x) < ManorSitePlan.DRIVE_WIDTH * 0.5 + 1.0:
					a = 0.0
				verts.append([Vector3(x, WorldHeight.height_at(x, z) + LIFT, z), a])
		for j in nz:
			for i in nx:
				var k := j * (nx + 1) + i
				for idx in [k, k + 1, k + nx + 2, k, k + nx + 2, k + nx + 1]:
					st.set_color(Color(1, 1, 1, verts[idx][1]))
					st.set_normal(Vector3.UP)
					st.add_vertex(verts[idx][0])
	var mi := MeshInstance3D.new()
	mi.name = "LawnStripes"
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = SHADER
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = EstateKit.WORLD_LAYER
	parent.add_child(mi)
	return mi
