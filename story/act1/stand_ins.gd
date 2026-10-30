## Capsule-and-box stand-ins for actors that other lanes own (the wolf, the
## doe, the beast, the horse). Story spawns these only when nobody answers
## EventBus.story_spawn_requested, so the scenes play before the creatures
## and art lanes land, and vanish from the code path once they do.
class_name StandIns
extends RefCounted

const TARGET_LAYER := 1 << 3
const CAST_MODEL := "res://characters/%s/%s_model.tscn"
const BEAST_MODEL := "res://characters/tamlin/beast/tamlin_beast_model.tscn"


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
	if ResourceLoader.exists(BEAST_MODEL):
		var model := (load(BEAST_MODEL) as PackedScene).instantiate() as Node3D
		model.name = "StandIn_tamlin_beast"
		return model
	var root := Node3D.new()
	root.name = "StandIn_tamlin_beast"
	return _mesh_body(Vector3(1.4, 2.4, 3.0), Color(0.78, 0.62, 0.30), root)


static func horse() -> Node3D:
	var root := Node3D.new()
	root.name = "StandIn_horse"
	return _mesh_body(Vector3(0.7, 1.6, 2.3), Color(0.94, 0.93, 0.90), root)


## A person or fae for any story actor without a lane of its own: the cast
## model when one exists (characters/<id>/<id>_model.tscn), otherwise a capsule
## tinted per actor.
static func figure(actor_id: String) -> Node3D:
	var tints := {
		"tamlin": Color(0.85, 0.70, 0.35), "lucien": Color(0.75, 0.30, 0.20),
		"alis": Color(0.55, 0.45, 0.30), "rhysand": Color(0.15, 0.15, 0.25),
		"nesta": Color(0.35, 0.40, 0.55), "elain": Color(0.80, 0.70, 0.55),
		"father": Color(0.40, 0.36, 0.30), "suriel": Color(0.80, 0.78, 0.72),
		"naga": Color(0.20, 0.30, 0.20), "attor": Color(0.25, 0.22, 0.28),
		"bogge": Color(0.05, 0.05, 0.06), "puca": Color(0.40, 0.36, 0.30),
		"summer_faerie": Color(0.30, 0.50, 0.85), "high_fae_male": Color(0.45, 0.35, 0.30),
	}
	# "naga_2" is the second naga: same kind, own actor id.
	var base := actor_id
	var parts := actor_id.rsplit("_", true, 1)
	if parts.size() == 2 and parts[1].is_valid_int():
		base = parts[0]
	var root: Node3D
	var model_path := CAST_MODEL % [base, base]
	if ResourceLoader.exists(model_path):
		root = (load(model_path) as PackedScene).instantiate() as Node3D
	elif base in ["naga", "high_fae_male"]:
		root = creature(StringName(base), Vector3(0.6, 1.8, 0.6), tints.get(base, Color.GRAY))
	else:
		root = Node3D.new()
		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.28
		capsule.height = 1.85
		mesh.mesh = capsule
		mesh.position.y = 0.925
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tints.get(base, Color(0.6, 0.6, 0.6))
		mesh.material_override = mat
		root.add_child(mesh)
	root.name = "StandIn_%s" % actor_id
	return root
