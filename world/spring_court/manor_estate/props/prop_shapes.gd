## The look of each prop. Owned by the props lane: replace the generic shapes
## here with real procedural (or Blender) meshes per id or per category.
class_name PropShapes
extends RefCounted


## Returns a visual-only Node3D for the prop, base at y = 0, fitting `size`.
static func build(id: StringName, size: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position.y = size.y * 0.5
	mi.material_override = EstateKit.mat(color, 0.5)
	mi.visibility_range_end = 90.0
	root.add_child(mi)
	return root
