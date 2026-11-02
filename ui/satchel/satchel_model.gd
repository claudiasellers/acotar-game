## Finds the real 3D model of a satchel entry: the forage and keepsake glTFs
## the world scatters (art/forage for the human realm, the Spring Court's
## flora and props folders), so the page shows the same thing she picked up.
## Used by the icon renderer (tools/ui/render_item_icons.gd) and by the page's
## hero preview. Loads happen on the calling (main) thread only (F27/F37).
class_name SatchelModel
extends RefCounted

const DIRS: Array[String] = [
	"res://art/forage/",
	"res://world/spring_court/wider/assets/flora/",
	"res://world/spring_court/wider/assets/props/",
]
const EXTS: Array[String] = [".glb", ".gltf"]
## Catalogue id -> model file stem, where the two were named apart.
const STEMS := {
	&"ing_watermint": &"ing_water_mint",
	&"col_blue_jay_feather": &"col_jay_feather",
	&"col_acorn_cap": &"col_acorn_caps",
	&"obj_white_roses": &"ing_rose_white",
}

static var _paths: Dictionary = {}
static var _vcol: Material = null


## The model file for an item id, or "" when it has none.
static func path_for(id: StringName) -> String:
	if _paths.has(id):
		return _paths[id]
	var stem := String(STEMS.get(id, ItemCatalog.canonical(id)))
	var found := ""
	for stem_try: String in [stem, String(id)]:
		for dir in DIRS:
			for ext in EXTS:
				if found == "" and ResourceLoader.exists(dir + stem_try + ext):
					found = dir + stem_try + ext
	_paths[id] = found
	return found


static func has_model(id: StringName) -> bool:
	return path_for(id) != ""


## A fresh instance of the model, or null. Main thread only.
static func instance(id: StringName) -> Node3D:
	var path := path_for(id)
	if path == "":
		return null
	var scene := ResourceLoader.load(path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate() as Node3D
	dress(root)
	return root


## The generators bake colour into COLOR_0 and the importer leaves it off
## (the world draws them through its own court shaders, which lean on world
## globals such as snow and magic). Off the world, one shared material does
## the colour: vertex colour as albedo, soft sheen, a warm rim (R3).
static func dress(root: Node3D) -> void:
	if _vcol == null:
		var std := StandardMaterial3D.new()
		std.resource_name = "satchel_vcol"
		std.vertex_color_use_as_albedo = true
		std.roughness = 0.6
		std.cull_mode = BaseMaterial3D.CULL_DISABLED
		std.rim_enabled = true
		std.rim = 0.3
		std.rim_tint = 0.7
		_vcol = std
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh is ArrayMesh and _has_colours(mi.mesh as ArrayMesh):
			mi.material_override = _vcol


static func _has_colours(mesh: ArrayMesh) -> bool:
	for s in mesh.get_surface_count():
		if mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR:
			return true
	return false


## The combined bounds of every mesh under `root`, in root's space.
static func bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := root.global_transform.affine_inverse() * mi.global_transform \
				if root.is_inside_tree() else _local_xf(root, mi)
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _local_xf(root: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
