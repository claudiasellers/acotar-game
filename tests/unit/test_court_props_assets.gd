extends GutTest
## Checks every asset listed in the wider Spring Court props manifest:
## it loads, has <id> and <id>_LOD1 meshes, meets the tri budget and its
## AABB matches the manifest size within 30 %.

const PROPS_DIR := "res://world/spring_court/wider/assets/props/"
const MANIFEST_PATH := PROPS_DIR + "props_manifest.json"
const BUDGET_DEFAULT := 3000
const BUDGET_COLLECTIBLE := 600
const SIZE_TOLERANCE := 0.3

var _assets: Array = []


func before_all() -> void:
	var text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		_assets = (data as Dictionary).get("assets", []) as Array


func _tri_count(mesh: Mesh) -> int:
	var tris: int = 0
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array and (indices as PackedInt32Array).size() > 0:
			tris += (indices as PackedInt32Array).size() / 3
		else:
			tris += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return tris


func _mesh_node(root: Node, node_name: String) -> MeshInstance3D:
	var found: Node = root.find_child(node_name, true, false)
	return found as MeshInstance3D


func test_manifest_lists_assets() -> void:
	assert_gt(_assets.size(), 100, "manifest should list the full wider-court prop set")
	var ids: Dictionary = {}
	for entry: Dictionary in _assets:
		ids[entry["id"]] = true
	assert_eq(ids.size(), _assets.size(), "asset ids are unique")


func test_every_asset_instantiates_with_lod_and_budget() -> void:
	for entry: Dictionary in _assets:
		var id: String = entry["id"]
		var scene: PackedScene = load(PROPS_DIR + String(entry["file"])) as PackedScene
		assert_not_null(scene, "%s loads" % id)
		if scene == null:
			continue
		var root: Node = scene.instantiate()
		assert_not_null(root, "%s instantiates" % id)
		var base: MeshInstance3D = _mesh_node(root, id)
		var lod: MeshInstance3D = _mesh_node(root, id + "_LOD1")
		assert_not_null(base, "%s has base mesh" % id)
		assert_not_null(lod, "%s has LOD1 mesh" % id)
		if base != null and lod != null:
			var budget: int = BUDGET_COLLECTIBLE if entry["kind"] == "collectible" else BUDGET_DEFAULT
			var tris: int = _tri_count(base.mesh)
			var tris_lod: int = _tri_count(lod.mesh)
			assert_true(tris > 0 and tris <= budget, "%s tris %d within %d" % [id, tris, budget])
			assert_true(tris_lod > 0 and tris_lod < tris, "%s LOD1 tris %d below base %d" % [id, tris_lod, tris])
			var size: Vector3 = base.get_aabb().size
			var want: Array = entry["size_m"]
			for axis: int in 3:
				var w: float = float(want[axis])
				var tol: float = maxf(w * SIZE_TOLERANCE, 0.02)
				assert_almost_eq(size[axis], w, tol, "%s AABB axis %d" % [id, axis])
		if bool(entry.get("collision", false)):
			assert_true(root.find_child(id + "_col", true, false) is StaticBody3D, "%s has static collision" % id)
		if bool(entry.get("climbable", false)):
			assert_not_null(_mesh_node(root, id + "_climb"), "%s has climb mesh" % id)
		root.free()
