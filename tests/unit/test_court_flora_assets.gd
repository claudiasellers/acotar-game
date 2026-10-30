extends GutTest
## Checks the generated wider Spring Court flora (tools/court/blender/flora_generate.py):
## every manifest entry imports, carries <id> and <id>_LOD1 meshes, respects the tri budget,
## and matches the manifest's height and glow flag.

const FLORA_DIR: String = "res://world/spring_court/wider/assets/flora/"
const MANIFEST_PATH: String = FLORA_DIR + "flora_manifest.json"
const TRI_BUDGET: int = 3000

var _assets: Array = []


func before_all() -> void:
	var text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_assets = (parsed as Dictionary).get("assets", [])


func _tris(mesh: Mesh) -> int:
	var total: int = 0
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
			total += (idx as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _has_glow(mesh: Mesh) -> bool:
	for s: int in mesh.get_surface_count():
		var cols: Variant = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
		if cols is PackedColorArray:
			for c: Color in cols as PackedColorArray:
				if c.a > 0.5:
					return true
	return false


func test_manifest_lists_full_set() -> void:
	var forage: int = 0
	var decor: int = 0
	for e: Dictionary in _assets:
		if e["kind"] == "forage":
			forage += 1
		else:
			decor += 1
	assert_gte(forage, 77, "forage meshes")
	assert_gte(decor, 33, "decor + tree meshes")


func test_every_asset_imports_within_budget() -> void:
	assert_gt(_assets.size(), 0, "manifest loaded")
	for e: Dictionary in _assets:
		var id: String = e["id"]
		var packed: PackedScene = load(FLORA_DIR + String(e["file"])) as PackedScene
		assert_not_null(packed, id + " loads")
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		var base: MeshInstance3D = root.find_child(id, true, false) as MeshInstance3D
		var lod: MeshInstance3D = root.find_child(id + "_LOD1", true, false) as MeshInstance3D
		assert_not_null(base, id + " base mesh")
		assert_not_null(lod, id + " LOD1 mesh")
		if base != null and lod != null:
			var tris: int = _tris(base.mesh)
			var tris_lod: int = _tris(lod.mesh)
			assert_lte(tris, TRI_BUDGET, id + " tri budget")
			assert_eq(tris, int(e["tris"]), id + " tris match manifest")
			var ratio: float = float(tris_lod) / float(maxi(1, tris))
			assert_between(ratio, 0.4, 0.6, id + " LOD1 ratio")
			var aabb: AABB = base.mesh.get_aabb()
			var height: float = aabb.end.y - minf(0.0, aabb.position.y)
			var want: float = float(e["height_m"])
			assert_between(height, want * 0.7, want * 1.3, id + " height")
			assert_eq(_has_glow(base.mesh), bool(e["glows"]), id + " glow flag")
		root.free()
