## The invisible Wall made barely visible: a tall, thin strip of heat haze
## along z = 1400 that follows the ground, brightening as Feyre comes within
## `near_radius` metres. Built at load (one mesh, one draw call).
class_name WallShimmer
extends Node3D

const SHADER := preload("res://world/human_realm/wall_seam/wall_shimmer.gdshader")

@export var wall_z := WorldMap.WALL_Z
@export var x_min := -900.0
@export var x_max := 700.0
@export var height := 60.0
@export var segment := 8.0
@export var near_radius := 15.0

var near_amount := 0.0
var _mat: ShaderMaterial
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Haze"
	_mesh_instance.mesh = build_mesh()
	_mesh_instance.material_override = _mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)


## Vertical strip: bottom edge 2 m under the ground, top `height` above it.
func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := maxi(1, ceili((x_max - x_min) / segment))
	for i in n:
		var xa := x_min + (x_max - x_min) * i / n
		var xb := x_min + (x_max - x_min) * (i + 1) / n
		var ya := WorldHeight.height_at(xa, wall_z) - 2.0
		var yb := WorldHeight.height_at(xb, wall_z) - 2.0
		var ua := float(i) / n
		var ub := float(i + 1) / n
		var a0 := Vector3(xa, ya, wall_z) - position
		var b0 := Vector3(xb, yb, wall_z) - position
		var a1 := a0 + Vector3.UP * height
		var b1 := b0 + Vector3.UP * height
		for v: Array in [[a0, Vector2(ua, 1)], [b0, Vector2(ub, 1)], [b1, Vector2(ub, 0)], [a0, Vector2(ua, 1)], [b1, Vector2(ub, 0)], [a1, Vector2(ua, 0)]]:
			st.set_normal(Vector3.BACK)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	return st.commit()


static func near_for(distance: float, radius: float) -> float:
	return 1.0 - clampf(absf(distance) / maxf(radius, 0.001), 0.0, 1.0)


func _process(_delta: float) -> void:
	var best := 0.0
	for n in get_tree().get_nodes_in_group(&"player"):
		if n is Node3D:
			var p := (n as Node3D).global_position
			if p.x >= x_min - near_radius and p.x <= x_max + near_radius:
				best = maxf(best, near_for(p.z - wall_z, near_radius))
	if not is_equal_approx(best, near_amount):
		near_amount = best
		_mat.set_shader_parameter(&"near", best)
