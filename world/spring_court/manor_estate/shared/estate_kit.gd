## Small building helpers shared by every part of the Manor Estate.
##
## Static geometry goes on collision layer 1 (the world), which Feyre walks on.
## Materials are cached by key so a thousand walls share one material.
class_name EstateKit
extends RefCounted

# Palette (R3, princess look): rose pink, blush, lilac, periwinkle, mint, butter
# yellow, pearl white, gold accents. Saturated and candy-bright, never grey.
const PEARL := Color(0.98, 0.95, 0.93)
const MARBLE := Color(0.97, 0.92, 0.91)          # pearl-pink marble
const WARM_STONE := Color(0.96, 0.86, 0.80)
const STONE_DARK := Color(0.86, 0.72, 0.70)
const GRAVEL := Color(0.97, 0.89, 0.82)
const OAK := Color(0.78, 0.55, 0.42)              # honeyed, warm
const OAK_DARK := Color(0.58, 0.36, 0.30)
const GOLD := Color(1.0, 0.80, 0.38)
const ROSE := Color(0.98, 0.55, 0.70)
const BLUSH := Color(1.0, 0.80, 0.84)
const CREAM := Color(1.0, 0.96, 0.88)
const BUTTER := Color(1.0, 0.92, 0.58)
const MINT := Color(0.66, 0.93, 0.80)
const LILAC := Color(0.80, 0.68, 0.96)
const PERIWINKLE := Color(0.67, 0.72, 1.0)
const MOSS := Color(0.48, 0.78, 0.40)
const HEDGE := Color(0.30, 0.66, 0.36)
const SLATE := Color(0.60, 0.52, 0.80)             # lilac roof slate
const GLASS := Color(0.90, 0.97, 1.0, 0.25)
const WATER := Color(0.55, 0.85, 0.95, 0.75)

const WORLD_LAYER := 1

static var _materials: Dictionary = {}


## A cached opaque material. `key` defaults to the colour.
static func mat(color: Color, roughness: float = 0.85, metallic: float = 0.0, key: String = "") -> StandardMaterial3D:
	var k := key if key != "" else "%s|%.2f|%.2f" % [color.to_html(), roughness, metallic]
	if _materials.has(k):
		return _materials[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if metallic > 0.0 or roughness < 0.3:
		m.clearcoat_enabled = true
		m.clearcoat = 0.6
		m.clearcoat_roughness = 0.2
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[k] = m
	return m


## Glossy pearlescent material: a soft rim glow over a clearcoat (R3).
static func pearl(color: Color = PEARL, key: String = "") -> StandardMaterial3D:
	var k := key if key != "" else "pearl|" + color.to_html()
	if _materials.has(k):
		return _materials[k]
	var m := mat(color, 0.18, 0.15, k + "|base").duplicate() as StandardMaterial3D
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.7
	_materials[k] = m
	return m


## A cached material that takes its albedo from vertex colours (for MultiMesh tints).
static func vertex_mat(roughness: float = 0.8, key: String = "vertex") -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	_materials[key] = m
	return m


## A solid box: mesh plus collision. `center` is the box centre.
static func box(parent: Node, center: Vector3, size: Vector3, material: Material,
		collide: bool = true, rot_y: float = 0.0, vis_end: float = 0.0) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	if vis_end > 0.0:
		mi.visibility_range_end = vis_end
	if not collide:
		mi.position = center
		mi.rotation.y = rot_y
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = center
	body.rotation.y = rot_y
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body


## A solid vertical cylinder (columns, posts, trunks, fountain basins).
static func cylinder(parent: Node, base: Vector3, radius: float, height: float, material: Material,
		collide: bool = true, segments: int = 16, top_radius: float = -1.0) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	var center := base + Vector3.UP * height * 0.5
	if not collide:
		mi.position = center
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = center
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = maxf(radius, mesh.top_radius)
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body


## A visual-only mesh instance.
static func visual(parent: Node, mesh: Mesh, xform: Transform3D, material: Material = null,
		vis_end: float = 0.0, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform
	if material:
		mi.material_override = material
	if vis_end > 0.0:
		mi.visibility_range_end = vis_end
		mi.visibility_range_end_margin = vis_end * 0.1
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Many copies of one mesh in a single draw: the only way to place foliage (R16).
static func multimesh(parent: Node, mesh: Mesh, transforms: Array[Transform3D],
		colors: PackedColorArray = PackedColorArray(), vis_end: float = 0.0,
		shadows: bool = false, node_name: String = "") -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i % colors.size()])
	var mmi := MultiMeshInstance3D.new()
	if node_name != "":
		mmi.name = node_name
	mmi.multimesh = mm
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


## A transform standing on the estate ground at x/z with yaw and uniform scale.
static func on_ground(x: float, z: float, yaw: float = 0.0, scale: float = 1.0, lift: float = 0.0) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	return Transform3D(basis, Vector3(x, WorldHeight.height_at(x, z) + lift, z))


## Deterministic RNG for a named generator, so the estate is identical every load.
static func rng(seed_name: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(seed_name)
	return r
