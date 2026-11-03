## One kind of loose, physical prop: a crate, a pot, a bucket, a log (T5).
## Feyre can shove it, pick it up, carry it, throw it and stack it; fire,
## water and wind act on it through ElementField (systems/chemistry).
## Content lives in data/props/<id>.tres (R8).
class_name PropData
extends Resource

## Unique id, also the prop layer id in data/props/placements/*.tres.
@export var id: StringName
@export var display_name: String
## The model (.glb). Its first MeshInstance3D's mesh is used.
@export_file("*.glb", "*.tscn", "*.tres", "*.res") var mesh_path: String
## Collision: &"box" (size = extents x2) or &"cylinder" (size.x = diameter, size.y = height).
@export var shape: StringName = &"box"
@export var size: Vector3 = Vector3(0.6, 0.6, 0.6)
@export_range(0.1, 200.0) var mass: float = 6.0
@export_range(0.0, 1.0) var friction: float = 0.7
@export_range(0.0, 1.0) var bounce: float = 0.15
## Feyre can lift it (heavy things are only pushed).
@export var carryable: bool = true
## Breaks on a hard landing (impact speed above break_speed).
@export var breakable: bool = false
@export var break_speed: float = 9.0
## Burns when an element of fire reaches it (ElementField).
@export var flammable: bool = false
## Starting wetness 0..1 (a full bucket starts wet and puts fire out).
@export_range(0.0, 1.0) var wetness: float = 0.0
## Sparkle colour on pick-up (R3).
@export var sparkle: Color = Color(1.0, 0.86, 0.94)


## Half the height: the mesh origin sits on the ground, the body centre above it.
func half_height() -> float:
	return size.y * 0.5


func make_shape() -> Shape3D:
	if shape == &"cylinder":
		var c := CylinderShape3D.new()
		c.radius = size.x * 0.5
		c.height = size.y
		return c
	var b := BoxShape3D.new()
	b.size = size
	return b


func load_mesh() -> Mesh:
	if mesh_path.is_empty() or not ResourceLoader.exists(mesh_path):
		return null
	var res := load(mesh_path)
	if res is Mesh:
		return res
	if res is PackedScene:
		var inst := (res as PackedScene).instantiate()
		var mesh := _first_mesh(inst)
		inst.free()
		return mesh
	return null


static func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		return (node as MeshInstance3D).mesh
	for c in node.get_children():
		var m := _first_mesh(c)
		if m:
			return m
	return null
