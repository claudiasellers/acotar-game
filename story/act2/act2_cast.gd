## The Act II cast as actors: Tamlin and Lucien are L02's real cast models
## (through StandIns.figure); Alis is a coloured placeholder at her height
## (R4) until the art lane models her: rotund, brown hair, white apron over a
## brown dress, a simple brass bird mask (lore/03-characters/alis.md).
class_name Act2Cast
extends RefCounted

const ALIS_HEIGHT := 1.6


## A cast member, or StandIns' figure for anyone else.
static func build(actor_id: String) -> Node3D:
	if actor_id == "alis":
		return alis()
	return StandIns.figure(actor_id)


static func alis() -> Node3D:
	var root := Node3D.new()
	root.name = "StandIn_alis"
	_part(root, _capsule(0.36, 1.25), Vector3(0, 0.62, 0), Color(0.52, 0.36, 0.25))     # brown dress
	_part(root, _box(Vector3(0.5, 0.8, 0.06)), Vector3(0, 0.62, -0.33), Color(0.98, 0.96, 0.93))  # apron
	_part(root, _sphere(0.2), Vector3(0, 1.38, 0), Color(0.93, 0.78, 0.66))          # face
	_part(root, _sphere(0.22), Vector3(0, 1.45, 0.05), Color(0.42, 0.28, 0.18))      # brown hair
	var mask := _part(root, _box(Vector3(0.34, 0.12, 0.05)), Vector3(0, 1.41, -0.19), Color(0.80, 0.62, 0.30))
	(mask.material_override as StandardMaterial3D).metallic = 0.9
	(mask.material_override as StandardMaterial3D).roughness = 0.25
	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.05
	beak.height = 0.14
	var b := _part(root, beak, Vector3(0, 1.37, -0.27), Color(0.80, 0.62, 0.30))
	b.rotation_degrees.x = -90.0
	(b.material_override as StandardMaterial3D).metallic = 0.9
	return root


static func _part(root: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mi.material_override = mat
	root.add_child(mi)
	return mi


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m


static func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
