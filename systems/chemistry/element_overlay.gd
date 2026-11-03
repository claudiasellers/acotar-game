## Debug view of ElementField (F8): one dot per cell, coloured by state
## (red burning, blue wet, grey burnt, green fuel). One MultiMesh, one draw.
class_name ElementOverlay
extends MultiMeshInstance3D


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dot := SphereMesh.new()
	dot.radius = 0.12
	dot.height = 0.24
	dot.radial_segments = 6
	dot.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	dot.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = dot


func redraw(field: ElementField) -> void:
	var cells := field.debug_cells()
	multimesh.instance_count = cells.size()
	for i in cells.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, cells[i][0] + Vector3.UP * 0.3))
		multimesh.set_instance_color(i, cells[i][1])
