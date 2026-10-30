## Code-built stand-in bodies, used until a species' data names a model scene.
## They face -Z with feet at y = 0, the same contract real models follow.
class_name PlaceholderBody
extends RefCounted


static func build(data: CreatureData) -> Node3D:
	if data.model_scene:
		return data.model_scene.instantiate() as Node3D
	if data.body_plan == CreatureData.BodyPlan.BIRD:
		return _bird(data)
	return _quadruped(data)


static func _quadruped(data: CreatureData) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var coat := _mat(data.coat_color)
	var belly := _mat(data.belly_color)
	var l := data.body_length
	var h := data.body_height
	var w := data.body_width
	var leg_h := h * 0.55
	var torso_r := (h - leg_h) * 0.6
	var torso := _capsule(torso_r, l * 0.62, coat)
	torso.rotation_degrees.x = 90.0
	torso.position = Vector3(0, leg_h + torso_r * 0.8, 0)
	torso.scale = Vector3(w / (torso_r * 2.0), 1.0, 1.0)
	root.add_child(torso)
	var under := _capsule(torso_r * 0.8, l * 0.5, belly)
	under.rotation_degrees.x = 90.0
	under.position = Vector3(0, leg_h + torso_r * 0.45, 0)
	under.scale = torso.scale
	root.add_child(under)
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			var leg := _cylinder(w * 0.11, leg_h + torso_r * 0.4, coat)
			leg.position = Vector3(side * w * 0.3, (leg_h + torso_r * 0.4) * 0.5, end * l * 0.27)
			root.add_child(leg)
	var neck := _capsule(torso_r * 0.45, h * 0.45, coat)
	neck.position = Vector3(0, leg_h + torso_r * 1.4, -l * 0.33)
	neck.rotation_degrees.x = -35.0
	root.add_child(neck)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, leg_h + torso_r * 1.9, -l * 0.42)
	root.add_child(head)
	var skull := _box(Vector3(w * 0.42, torso_r * 0.8, l * 0.22), coat)
	skull.position.z = -l * 0.06
	head.add_child(skull)
	var eye_mat := _mat(data.eye_color)
	if data.eye_glow > 0.0:
		eye_mat.emission_enabled = true
		eye_mat.emission = data.eye_color
		eye_mat.emission_energy_multiplier = data.eye_glow
	for side in [-1.0, 1.0]:
		var eye := _sphere(torso_r * 0.09, eye_mat)
		eye.position = Vector3(side * w * 0.2, torso_r * 0.15, -l * 0.1)
		head.add_child(eye)
		var ear := _box(Vector3(w * 0.06, torso_r * 0.55, w * 0.1), coat)
		ear.position = Vector3(side * w * 0.14, torso_r * 0.6, 0.0)
		head.add_child(ear)
		if data.antlers:
			var antler := _cylinder(0.015, h * 0.45, _mat(Color(0.55, 0.45, 0.33)))
			antler.position = Vector3(side * w * 0.12, torso_r * 0.6 + h * 0.2, 0.02)
			antler.rotation_degrees.z = side * 20.0
			head.add_child(antler)
	var tail := _capsule(torso_r * 0.2, l * 0.18, coat)
	tail.position = Vector3(0, leg_h + torso_r, l * 0.36)
	tail.rotation_degrees.x = 60.0
	root.add_child(tail)
	return root


static func _bird(data: CreatureData) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var coat := _mat(data.coat_color)
	var body := _sphere(data.body_length * 0.3, coat)
	body.scale = Vector3(0.8, 0.8, 1.3)
	body.position.y = data.body_height * 0.55
	root.add_child(body)
	var head := _sphere(data.body_length * 0.17, coat)
	head.position = Vector3(0, data.body_height * 0.85, -data.body_length * 0.3)
	head.name = "Head"
	root.add_child(head)
	var breast := _sphere(data.body_length * 0.22, _mat(data.belly_color))
	breast.position = Vector3(0, data.body_height * 0.5, -data.body_length * 0.12)
	root.add_child(breast)
	for side in [-1.0, 1.0]:
		var wing := _box(Vector3(data.body_length * 0.5, 0.01, data.body_length * 0.35), coat)
		wing.name = "Wing%s" % ("L" if side < 0 else "R")
		wing.position = Vector3(side * data.body_length * 0.25, data.body_height * 0.6, 0.0)
		root.add_child(wing)
	return root


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


static func _capsule(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	return _inst(m, mat)


static func _cylinder(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius * 0.8
	m.height = height
	return _inst(m, mat)


static func _sphere(radius: float, mat: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return _inst(m, mat)


static func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _inst(m, mat)


static func _inst(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi
