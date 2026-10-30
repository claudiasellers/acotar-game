## Code-built stand-in people: High Fae, the Summer faerie, the puca's
## borrowed shapes. Main characters stay placeholders until the user designs
## them in Blender (R4), so these are deliberately simple: a clothed body,
## a head with pointed ears, optional mask and wings. Feet at y = 0, facing -Z.
class_name PlaceholderFigure
extends RefCounted


## spec keys (all optional): height, skin, clothes, hair, robe (bool),
## pointed_ears (bool), mask (Color, alpha 0 = none), wings (Color, alpha 0 =
## none), stoop (degrees), cane (bool).
static func build(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Figure"
	var h: float = spec.get("height", 1.85)
	var u := h / 1.85
	var skin := PlaceholderBody._mat(spec.get("skin", Color(0.93, 0.80, 0.70)))
	var clothes := PlaceholderBody._mat(spec.get("clothes", Color(0.35, 0.55, 0.35)))
	var hair := PlaceholderBody._mat(spec.get("hair", Color(0.45, 0.30, 0.18)))
	var body := Node3D.new()
	body.name = "Body"
	body.rotation_degrees.x = -float(spec.get("stoop", 0.0))
	root.add_child(body)
	if spec.get("robe", false):
		var robe := CylinderMesh.new()
		robe.top_radius = 0.17 * u
		robe.bottom_radius = 0.32 * u
		robe.height = 1.05 * u
		var r := PlaceholderBody._inst(robe, clothes)
		r.position.y = 0.52 * u
		body.add_child(r)
	else:
		for side in [-1.0, 1.0]:
			var leg := PlaceholderBody._cylinder(0.075 * u, 0.9 * u, clothes)
			leg.position = Vector3(side * 0.1 * u, 0.45 * u, 0)
			body.add_child(leg)
	var torso := PlaceholderBody._capsule(0.18 * u, 0.62 * u, clothes)
	torso.position.y = 1.2 * u
	torso.scale = Vector3(1.0, 1.0, 0.7)
	body.add_child(torso)
	for side in [-1.0, 1.0]:
		var arm := PlaceholderBody._capsule(0.05 * u, 0.62 * u, clothes)
		arm.position = Vector3(side * 0.24 * u, 1.2 * u, 0)
		arm.rotation_degrees.z = side * 6.0
		body.add_child(arm)
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 1.66 * u
	body.add_child(head)
	head.add_child(PlaceholderBody._sphere(0.12 * u, skin))
	var hair_cap := PlaceholderBody._sphere(0.128 * u, hair)
	hair_cap.position = Vector3(0, 0.025 * u, 0.02 * u)
	hair_cap.scale = Vector3(1.0, 0.9, 1.0)
	head.add_child(hair_cap)
	if spec.get("pointed_ears", true):
		for side in [-1.0, 1.0]:
			var ear := _cone(0.025 * u, 0.09 * u, skin)
			ear.position = Vector3(side * 0.12 * u, 0.02 * u, 0.01 * u)
			ear.rotation_degrees = Vector3(-15.0, 0.0, -side * 70.0)
			head.add_child(ear)
	var mask_color: Color = spec.get("mask", Color(0, 0, 0, 0))
	if mask_color.a > 0.0:
		# The Spring Court's masks: a half-face of leaves and gilt.
		var mask := PlaceholderBody._box(Vector3(0.24 * u, 0.1 * u, 0.04 * u), _shiny(mask_color))
		mask.name = "Mask"
		mask.position = Vector3(0, 0.02 * u, -0.11 * u)
		head.add_child(mask)
	var wing_color: Color = spec.get("wings", Color(0, 0, 0, 0))
	if wing_color.a > 0.0:
		var wing_mat := StandardMaterial3D.new()
		wing_mat.albedo_color = wing_color
		wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		wing_mat.emission_enabled = true
		wing_mat.emission = Color(wing_color.r, wing_color.g, wing_color.b)
		wing_mat.emission_energy_multiplier = 0.3
		for side in [-1.0, 1.0]:
			var wing := PlaceholderBody._box(Vector3(0.55 * u, 0.9 * u, 0.01), wing_mat)
			wing.name = "Wing%s" % ("L" if side < 0 else "R")
			wing.position = Vector3(side * 0.3 * u, 1.35 * u, 0.14 * u)
			wing.rotation_degrees = Vector3(0, side * -25.0, side * -18.0)
			body.add_child(wing)
	if spec.get("cane", false):
		var cane := PlaceholderBody._cylinder(0.015 * u, 0.95 * u, PlaceholderBody._mat(Color(0.35, 0.25, 0.16)))
		cane.position = Vector3(0.3 * u, 0.47 * u, -0.15 * u)
		root.add_child(cane)
	return root


static func _cone(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	return PlaceholderBody._inst(m, mat)


static func _shiny(color: Color) -> StandardMaterial3D:
	var m := PlaceholderBody._mat(color)
	m.metallic = 0.7
	m.roughness = 0.35
	return m
