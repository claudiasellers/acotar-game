extends GutTest
## Shared contract for a generated prop family (lane L73): every model in the
## family's manifest loads, is a generated mesh (never an engine primitive),
## stays inside the R4 prop cap with a LOD1 at about half, keeps its albedo at
## or under 0.85 and stands on the origin. A family's test extends this and
## sets `dir`, `manifest` and `required`.

const MAX_TRIS := 3000
const ALBEDO_CAP := 0.85

var dir := ""
var manifest := ""
var required: Array[String] = []

var _assets: Array = []


func before_all() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + manifest))
	if data is Dictionary:
		_assets = (data as Dictionary).get("assets", []) as Array


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	if root is MeshInstance3D:
		out.append(root as MeshInstance3D)
	return out


func _tris(mesh: Mesh) -> int:
	var total := 0
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
			total += (idx as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _max_albedo(mesh: Mesh) -> float:
	var top := 0.0
	for s: int in mesh.get_surface_count():
		var colors: Variant = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
		if colors is PackedColorArray:
			for c: Color in colors as PackedColorArray:
				var srgb := c.linear_to_srgb()
				top = maxf(top, maxf(srgb.r, maxf(srgb.g, srgb.b)))
	return top


func test_manifest_lists_every_model_the_contract_names() -> void:
	var ids: Dictionary = {}
	for entry: Dictionary in _assets:
		ids[String(entry["id"])] = true
		assert_true(ResourceLoader.exists(dir + String(entry["file"])), "%s is on disk" % entry["id"])
	for id: String in required:
		assert_true(ids.has(id), "%s is modelled" % id)


func test_every_model_is_generated_in_budget_with_a_lod() -> void:
	assert_gte(_assets.size(), required.size(), "the manifest lists the family")
	for entry: Dictionary in _assets:
		var id := String(entry["id"])
		var scene := load(dir + String(entry["file"])) as PackedScene
		assert_not_null(scene, "%s loads" % id)
		if scene == null:
			continue
		var root := scene.instantiate()
		var lod0 := 0
		var lod1 := 0
		var floor_y := INF
		for mi: MeshInstance3D in _meshes(root):
			assert_true(mi.mesh is ArrayMesh, "%s/%s is a generated mesh, not a primitive" % [id, mi.name])
			assert_lte(_max_albedo(mi.mesh), ALBEDO_CAP + 0.01, "%s/%s albedo cap" % [id, mi.name])
			if String(mi.name).to_lower().ends_with("_lod1"):
				lod1 += _tris(mi.mesh)
			else:
				lod0 += _tris(mi.mesh)
				floor_y = minf(floor_y, (mi.transform * mi.mesh.get_aabb()).position.y)
		assert_gt(lod0, 0, "%s has a mesh" % id)
		assert_lte(lod0, MAX_TRIS, "%s is within the prop cap (%d tris)" % [id, lod0])
		assert_eq(lod0, int(entry["tris"]), "%s matches its manifest count" % id)
		assert_gt(lod1, 0, "%s has a LOD1" % id)
		assert_lte(lod1, int(lod0 * 0.7), "%s LOD1 is about half (%d of %d)" % [id, lod1, lod0])
		assert_almost_eq(floor_y, 0.0, 0.02, "%s stands on the origin" % id)
		root.free()
