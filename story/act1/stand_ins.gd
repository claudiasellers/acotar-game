## Capsule-and-box stand-ins for actors that other lanes own (the wolf, the
## doe, the beast, the horse). Story spawns these only when nobody answers
## EventBus.story_spawn_requested, so the scenes play before the creatures
## and art lanes land, and vanish from the code path once they do.
class_name StandIns
extends RefCounted

const TARGET_LAYER := 1 << 3


static func _mesh_body(size: Vector3, color: Color, body: Node3D) -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position.y = size.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)
	if body is CollisionObject3D:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		shape.position.y = size.y * 0.5
		body.add_child(shape)
	return body


## A creature an arrow can hit. On a hit it reports creature_killed with the
## arrow's item id (meta "item_id"; untyped M0 arrows count as ash) and
## topples. Only ash kills the great wolf; anything else makes it flinch.
static func creature(kind: StringName, size: Vector3, color: Color) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "StandIn_%s" % kind
	body.collision_layer = TARGET_LAYER
	body.set_script(preload("res://story/act1/stand_in_creature.gd"))
	body.set(&"kind", kind)
	return _mesh_body(size, color, body)


static func great_wolf() -> Node3D:
	return creature(&"great_wolf", Vector3(0.7, 1.25, 2.2), Color(0.35, 0.33, 0.32))


static func doe() -> Node3D:
	return creature(&"deer", Vector3(0.5, 1.2, 1.5), Color(0.55, 0.42, 0.30))


static func beast() -> Node3D:
	var root := Node3D.new()
	root.name = "StandIn_tamlin_beast"
	return _mesh_body(Vector3(1.4, 2.4, 3.0), Color(0.78, 0.62, 0.30), root)


static func horse() -> Node3D:
	var root := Node3D.new()
	root.name = "StandIn_horse"
	return _mesh_body(Vector3(0.7, 1.6, 2.3), Color(0.94, 0.93, 0.90), root)
