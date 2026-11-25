extends GutTest
## Contract test for the monster weapon and camp gear models (lane L88,
## docs/contracts/monster_gear_models.md): every model in the manifest loads,
## is a generated mesh inside the prop triangle cap with a LOD1 and the albedo
## cap, weapons carry their grip, tip, imbue point and worn twin, and
## containers carry their loot point.
# gate: when:art/monster_gear/*,tools/blender/monster_gear*.py,tools/blender/upcoming_kit.py,tools/blender/prop_kit.py

const DIR := "res://art/monster_gear/"
const MANIFEST := DIR + "monster_gear_manifest.json"
const MAX_TRIS := 3000
const ALBEDO_CAP := 0.85
## The least a worn twin's outline differs from the clean one's, as a share of the clean outline.
const WORN_DELTA := 0.04
## plans/hostile-fae/monster-gear.md: the weapons the loot rules name.
const WEAPONS: Array[String] = [
	"wpn_gloamer_hookknife", "wpn_gloamer_knuckleclub", "wpn_gloamer_trinket_flail", "wpn_gloamer_scythe_glaive",
	"wpn_woodcutter_hatchet", "wpn_pruning_hook", "wpn_naga_talon_knife", "wpn_naga_talon_hook", "wpn_fishers_gaff",
	"wpn_briar_thorn_whip", "wpn_briar_rose_shiv", "wpn_smiths_hammer", "wpn_shepherds_crook", "wpn_hob_tooth_cleaver",
	"wpn_blackvein_veinhook", "wpn_blackvein_jaw_shears", "wpn_martax_tooth_club", "wpn_martax_fang_knife", "wpn_crow_beak_awl",
]
## Camp gear that opens: a lid mesh hinged at its own origin.
const LIDDED: Array[String] = ["camp_gloamer_hoard_log", "camp_naga_reed_cache"]

var _assets: Array = []


func before_all() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if data is Dictionary:
		_assets = (data as Dictionary).get("assets", []) as Array


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


func _instance(entry: Dictionary) -> Node3D:
	var scene := load(DIR + String(entry["file"])) as PackedScene
	assert_not_null(scene, "%s loads" % entry["id"])
	return (scene.instantiate() as Node3D) if scene else null


func test_manifest_covers_every_weapon_in_the_spec() -> void:
	var group: Dictionary = {}
	for entry: Dictionary in _assets:
		group[String(entry["id"])] = String(entry["group"])
	for id: String in WEAPONS:
		assert_eq(String(group.get(id, "")), "weapon", "%s is modelled as a weapon" % id)
	assert_gt(_assets.size(), 40, "weapons and camp gear are both in the manifest")


func test_every_model_is_generated_in_budget_with_a_lod() -> void:
	for entry: Dictionary in _assets:
		var id := String(entry["id"])
		var root := _instance(entry)
		if root == null:
			continue
		var lod0 := 0
		var lod1 := 0
		var worn := 0
		for n: Node in root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			assert_true(mi.mesh is ArrayMesh, "%s/%s is a generated mesh, not a primitive" % [id, mi.name])
			assert_lte(_max_albedo(mi.mesh), ALBEDO_CAP + 0.01, "%s/%s albedo cap" % [id, mi.name])
			if String(mi.name).ends_with("_lod1"):
				lod1 += _tris(mi.mesh)
			elif String(mi.name).ends_with("_worn"):
				worn += _tris(mi.mesh)
			else:
				lod0 += _tris(mi.mesh)
		assert_gt(lod0, 0, "%s has a mesh" % id)
		assert_lte(lod0, MAX_TRIS, "%s is within the prop cap (%d tris)" % [id, lod0])
		assert_lte(worn, MAX_TRIS, "%s worn is within the prop cap (%d tris)" % [id, worn])
		assert_gt(lod1, 0, "%s has a LOD1" % id)
		assert_lte(lod1, int(lod0 * 0.7), "%s LOD1 is about half (%d of %d)" % [id, lod1, lod0])
		root.free()


func test_weapons_have_a_grip_a_tip_an_imbue_point_and_a_worn_twin() -> void:
	for entry: Dictionary in _assets:
		if String(entry["group"]) != "weapon":
			continue
		var id := String(entry["id"])
		var root := _instance(entry)
		if root == null:
			continue
		add_child_autofree(root)
		var body := root.find_child(id, true, false) as MeshInstance3D
		var tip := root.find_child(id + "_tip", true, false) as Node3D
		assert_not_null(body, "%s has its mesh" % id)
		assert_not_null(tip, "%s has a tip" % id)
		assert_not_null(root.find_child(id + "_imbue", true, false), "%s has an imbue point" % id)
		assert_true(root.find_child(id + "_worn", true, false) is MeshInstance3D, "%s has a worn twin" % id)
		if body == null or tip == null:
			continue
		var box := body.get_aabb().grow(0.01)
		assert_true(box.has_point(Vector3.ZERO), "%s is gripped at the origin" % id)
		var at: Vector3 = root.global_transform.affine_inverse() * tip.global_position
		assert_gt(at.y, 0.05, "%s runs up +Y from the grip" % id)
		assert_lte(at.z, 0.001, "%s strikes toward -Z" % id)
		assert_almost_eq(at.x, 0.0, 0.01, "%s tip is in the swing plane" % id)
		assert_almost_eq(at.length(), float(entry["reach_m"]), 0.005, "%s reach matches the manifest" % id)
		assert_gt(float(entry["rest_lift_m"]), 0.0, "%s can be laid on the ground" % id)
		# measured by the generator from the side, the view of a weapon in the hand
		assert_gte(float(entry.get("worn_delta", 0.0)), WORN_DELTA, "%s worn twin reads as worn in outline" % id)


func test_containers_have_a_loot_point_and_lids_hinge() -> void:
	var seen := 0
	for entry: Dictionary in _assets:
		if not entry.has("loot"):
			continue
		seen += 1
		var id := String(entry["id"])
		var root := _instance(entry)
		if root == null:
			continue
		assert_not_null(root.find_child(id + "_loot", true, false), "%s has a loot point" % id)
		if LIDDED.has(id):
			var lid := root.find_child(id + "_lid", true, false) as MeshInstance3D
			assert_not_null(lid, "%s has a lid" % id)
			if lid != null:
				assert_gt(lid.position.length(), 0.01, "%s lid's origin is its hinge, not the base" % id)
		root.free()
	assert_gt(seen, 5, "the containers are in the manifest")
