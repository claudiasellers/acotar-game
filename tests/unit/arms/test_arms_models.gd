extends GutTest
## Contract test for the bow, arrow and quiver models (lane L73,
## docs/contracts/arms_models.md): every model in the manifest loads, has its
## nodes, stays inside the R4 triangle cap with a LOD1, keeps its albedo at or
## under 0.85 and is a generated mesh, never an engine primitive.
# gate: when:art/arms/*,tools/blender/arms_props.py,tools/blender/upcoming_kit.py

const DIR := "res://art/arms/"
const MANIFEST := DIR + "arms_manifest.json"
const MAX_TRIS := 3000
const ALBEDO_CAP := 0.85
const BOWS: Array[String] = ["hunting_bow", "yew_longbow", "fae_recurve", "sentry_warbow", "gilded_bow"]

var _assets: Array = []


func before_all() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
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


func _instance(entry: Dictionary) -> Node:
	var scene := load(DIR + String(entry["file"])) as PackedScene
	assert_not_null(scene, "%s loads" % entry["id"])
	return scene.instantiate() if scene else null


func test_manifest_covers_the_bow_ladder_and_every_arrow() -> void:
	var ids: Dictionary = {}
	for entry: Dictionary in _assets:
		ids[String(entry["id"])] = true
	for bow: String in BOWS:
		assert_true(ids.has("bow_" + bow), "bow_%s is modelled" % bow)
		assert_true(ResourceLoader.exists("res://data/bows/%s.tres" % bow), "%s is a real BowData" % bow)
	var dir := DirAccess.open("res://data/arrows")
	for f: String in dir.get_files():
		if f.ends_with(".tres"):
			assert_true(ids.has("arrow_" + f.get_basename()), "arrow_%s is modelled" % f.get_basename())


func test_every_model_is_generated_in_budget_with_a_lod() -> void:
	assert_gt(_assets.size(), 15, "the manifest lists the family")
	for entry: Dictionary in _assets:
		var id := String(entry["id"])
		var root := _instance(entry)
		if root == null:
			continue
		var lod0 := 0
		var lod1 := 0
		for mi: MeshInstance3D in _meshes(root):
			assert_true(mi.mesh is ArrayMesh, "%s/%s is a generated mesh, not a primitive" % [id, mi.name])
			assert_lte(_max_albedo(mi.mesh), ALBEDO_CAP + 0.01, "%s/%s albedo cap" % [id, mi.name])
			if String(mi.name).to_lower().ends_with("_lod1"):
				lod1 += _tris(mi.mesh)
			else:
				lod0 += _tris(mi.mesh)
		assert_gt(lod0, 0, "%s has a mesh" % id)
		assert_lte(lod0, MAX_TRIS, "%s is within the prop cap (%d tris)" % [id, lod0])
		assert_gt(lod1, 0, "%s has a LOD1" % id)
		assert_lte(lod1, int(lod0 * 0.7), "%s LOD1 is about half (%d of %d)" % [id, lod1, lod0])
		root.free()


func test_bows_have_flexing_limbs_and_string_nocks() -> void:
	for entry: Dictionary in _assets:
		if String(entry["kind"]) != "bow":
			continue
		var id := String(entry["id"])
		var root := _instance(entry)
		if root == null:
			continue
		add_child_autofree(root)
		for part: String in ["_riser", "_limb_top", "_limb_bottom", "_tip_top", "_tip_bottom"]:
			assert_not_null(root.find_child(id + part, true, false), "%s has %s" % [id, part])
		var top := root.find_child(id + "_tip_top", true, false) as Node3D
		var bottom := root.find_child(id + "_tip_bottom", true, false) as Node3D
		var limb := root.find_child(id + "_limb_top", true, false) as Node3D
		if top == null or bottom == null or limb == null:
			continue
		var a: Vector3 = root.global_transform.affine_inverse() * top.global_position
		var b: Vector3 = root.global_transform.affine_inverse() * bottom.global_position
		assert_almost_eq(a.y, -b.y, 0.002, "%s tips mirror about the grip" % id)
		assert_gt(a.y, 0.55, "%s top nock is up the limb" % id)
		assert_gt(a.y, limb.position.y, "%s limb pivots below its nock" % id)
		assert_almost_eq(a.x, 0.0, 0.002, "%s string runs in the bow's plane" % id)


func test_arrows_keep_the_arrow_model_contract() -> void:
	for entry: Dictionary in _assets:
		if String(entry["kind"]) != "arrow":
			continue
		var id := String(entry["id"])
		var root := _instance(entry)
		if root == null:
			continue
		var box := AABB()
		var first := true
		for mi: MeshInstance3D in _meshes(root):
			if String(mi.name).to_lower().ends_with("_lod1"):
				continue
			var b := mi.transform * mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var length := float(entry["length"])
		assert_almost_eq(box.end.z, 0.0, 0.01, "%s nock sits at the origin" % id)
		assert_almost_eq(box.position.z, -length, 0.01, "%s tip is %.2f m down -Z" % [id, length])
		assert_lt(maxf(box.size.x, box.size.y), 0.09, "%s stays slim enough to nock" % id)
		root.free()
	var ash := 0.0
	var wood := 0.0
	for entry: Dictionary in _assets:
		if String(entry["id"]) == "arrow_ash":
			ash = float(entry["length"])
		elif String(entry["id"]) == "arrow_wood":
			wood = float(entry["length"])
	assert_gt(ash, wood, "the ash arrow is the longest in her quiver (canon)")
