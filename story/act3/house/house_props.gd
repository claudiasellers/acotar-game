## Props for the p3 house beats (L28): the cloud-Blender models in art/house/
## (tools/blender/house_set.py), the soft gold glint that marks the next thing
## to use (never text, R2), and the dark, shining blood (ch12, [C]).
class_name HouseProps
extends RefCounted

const DIR := "res://art/house/"
const GLINT_GOLD := Color(1.0, 0.86, 0.55)
const BLOOD := Color(0.20, 0.015, 0.03)


## A model as a MeshInstance3D (LOD1 by visibility range); a small pastel box
## when the model is missing so a scene never breaks.
static func model(id: StringName) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = String(id).to_pascal_case()
	var pair := PropModels.pair(DIR + String(id) + ".glb", String(id))
	if not pair.is_empty() and pair[0] != null:
		mi.mesh = pair[0]
	else:
		var b := BoxMesh.new()
		b.size = Vector3(0.2, 0.08, 0.2)
		mi.mesh = b
		var mat := MaterialLibrary.surface()
		mat.albedo_color = Color(0.98, 0.9, 0.92)
		mi.material_override = mat
	return mi


## A soft gold glint: a small warm light and a slow twinkle, for the next
## thing she can use. Hidden by default.
static func glint() -> HouseGlint:
	var root := HouseGlint.new()
	root.name = "Glint"
	var light := OmniLight3D.new()
	light.light_color = GLINT_GOLD
	light.light_energy = 0.6
	light.omni_range = 1.4
	light.shadow_enabled = false
	root.add_child(light)
	var star := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	star.mesh = quad
	var mat := MaterialLibrary.surface()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.95, 0.75, 0.9)
	mat.emission_enabled = true
	mat.emission = GLINT_GOLD
	mat.emission_energy_multiplier = 3.0
	star.material_override = mat
	root.add_child(star)
	root.visible = false
	return root


## Dark, shining stains on the marble ("dark, shining stains", ch12).
static func blood_drop(radius: float = 0.05) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Blood"
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = 0.004
	m.radial_segments = 10
	m.rings = 1
	mi.mesh = m
	mi.material_override = blood_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func blood_material(alpha: float = 1.0) -> CandyMaterial:
	var mat := MaterialLibrary.surface()
	mat.albedo_color = Color(BLOOD.r, BLOOD.g, BLOOD.b, alpha)
	mat.roughness = 0.08
	mat.metallic_specular = 0.9
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
