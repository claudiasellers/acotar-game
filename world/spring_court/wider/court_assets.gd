## Finds the wider court's models (cloud-Blender .gltf in assets/flora and
## assets/props) and their shared materials, with a coloured stand-in mesh for
## any model not exported yet so regions always load (R3: never grey).
class_name CourtAssets
extends RefCounted

const FLORA_DIR := "res://world/spring_court/wider/assets/flora/"
const PROPS_DIR := "res://world/spring_court/wider/assets/props/"
const MATERIAL_DIR := "res://world/spring_court/wider/fx/materials/"

const PASTELS := [
	Color(0.98, 0.62, 0.76), Color(0.99, 0.80, 0.85), Color(0.80, 0.68, 0.95),
	Color(0.68, 0.74, 0.98), Color(0.66, 0.93, 0.80), Color(0.99, 0.92, 0.58),
	Color(0.98, 0.96, 0.92), Color(0.95, 0.80, 0.45),
]
const BLIGHT_WORDS := ["blight", "ashen", "grey_lichen", "bone", "mask", "crow", "nightshade"]

static var _meshes := {}
static var _scenes := {}
static var _materials := {}
## Regions generate scatter on worker threads; the caches are shared.
static var _lock := Mutex.new()


static func scene_path(id: StringName) -> String:
	for dir in [FLORA_DIR, PROPS_DIR]:
		var path := "%s%s.gltf" % [dir, id]
		if ResourceLoader.exists(path):
			return path
	return ""


static func has_model(id: StringName) -> bool:
	return scene_path(id) != ""


static func is_blight(id: StringName) -> bool:
	for w: String in BLIGHT_WORDS:
		if String(id).contains(w):
			return true
	return false


## The mesh for scatter (`lod` = the _LOD1 object, used as the far mesh).
static func mesh(id: StringName, lod: bool = false) -> Mesh:
	_lock.lock()
	var m := _mesh_locked(id, lod)
	_lock.unlock()
	return m


static func _mesh_locked(id: StringName, lod: bool) -> Mesh:
	var key := "%s%s" % [id, "_LOD1" if lod else ""]
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh = null
	var path := scene_path(id)
	if path != "":
		var packed := load(path) as PackedScene
		if packed != null:
			var root := packed.instantiate()
			var node := root.find_child(key, true, false) as MeshInstance3D
			if node == null and not lod:
				node = _first_mesh(root)
			if node != null and node.mesh != null:
				m = node.mesh.duplicate()
			root.free()
	if m == null:
		m = placeholder(id) if not lod else _mesh_locked(id, false)
	_apply_material(id, m)
	_meshes[key] = m
	return m


## The whole model scene (landmarks: mesh + `<id>_col` collision mesh).
static func scene(id: StringName) -> PackedScene:
	if _scenes.has(id):
		return _scenes[id]
	var path := scene_path(id)
	var packed: PackedScene = load(path) as PackedScene if path != "" else null
	_scenes[id] = packed
	return packed


static func material_for(id: StringName) -> Material:
	_lock.lock()
	var mat := _material_locked(id)
	_lock.unlock()
	return mat


static func _material_locked(id: StringName) -> Material:
	var name := "mat_prop_default"
	var s := String(id)
	if is_blight(id):
		name = "mat_foliage_blight"
	elif s.begins_with("flora_") or s.begins_with("ing_"):
		name = "mat_foliage_default"
	elif s.contains("crystal") or s.contains("starglass") or s.contains("pool_rim"):
		name = "mat_prop_glitter"
	# Trees sway less than grass and flowers; wind is a material uniform (see
	# court_foliage.gdshader), so they get their own copy.
	if name == "mat_foliage_default" and s.begins_with("flora_tree_"):
		if not _materials.has("mat_foliage_tree"):
			var tree_mat := _material_locked(&"flora_grass_clump_a").duplicate() as Material
			if tree_mat is ShaderMaterial:
				(tree_mat as ShaderMaterial).set_shader_parameter(&"wind_amount", 0.25)
			_materials["mat_foliage_tree"] = tree_mat
		return _materials["mat_foliage_tree"]
	if _materials.has(name):
		return _materials[name]
	var path := "%s%s.tres" % [MATERIAL_DIR, name]
	var mat: Material = null
	if ResourceLoader.exists(path):
		mat = load(path) as Material
	if mat == null:
		var std := StandardMaterial3D.new()
		std.vertex_color_use_as_albedo = true
		std.roughness = 0.8
		mat = std
	_materials[name] = mat
	return mat


## A readable stand-in: pastel colour from the id, sized by kind.
static func placeholder(id: StringName) -> Mesh:
	var s := String(id)
	var color: Color = PASTELS[absi(hash(s)) % PASTELS.size()]
	if is_blight(id):
		color = Color(0.32, 0.31, 0.33)
	var m: PrimitiveMesh
	if s.contains("tree") or s.contains("oak") or s.contains("birch") or s.contains("willow") \
			or s.contains("maple") or s.contains("cherry") and s.begins_with("flora_") or s.contains("apple_blossom") \
			or s.contains("hawthorn") or s.contains("rowan"):
		var capsule := CapsuleMesh.new()
		capsule.radius = 2.2
		capsule.height = 9.0
		m = capsule
	elif s.begins_with("flora_grass") or s.begins_with("flora_wildflower"):
		var quad := QuadMesh.new()
		quad.size = Vector2(0.6, 0.35)
		quad.center_offset = Vector3(0.0, 0.17, 0.0)
		m = quad
	elif s.begins_with("ing_") or s.begins_with("col_"):
		var sphere := SphereMesh.new()
		sphere.radius = 0.14
		sphere.height = 0.22
		sphere.radial_segments = 8
		sphere.rings = 4
		m = sphere
	else:
		var box := BoxMesh.new()
		box.size = Vector3(2.0, 2.5, 2.0)
		m = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	if s.contains("glow") or s.contains("starlight") or s.contains("faelight") or s.contains("moonflower"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.5
	m.material = mat
	return m


static func _apply_material(id: StringName, m: Mesh) -> void:
	if m is PrimitiveMesh:
		return
	var mat := _material_locked(id)
	for i in m.get_surface_count():
		m.surface_set_material(i, mat)


static func _first_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child in root.get_children():
		var found := _first_mesh(child)
		if found != null and not String(found.name).ends_with("_LOD1") and not String(found.name).ends_with("_col"):
			return found
	return null
