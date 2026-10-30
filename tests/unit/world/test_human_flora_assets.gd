extends GutTest
## Human realm shared flora library (tools/blender/human_realm/build_flora.py):
## every asset loads through ScatterLayer._load_mesh, carries vertex colours
## and stays inside its triangle budget. Trees also have a <id>_far.glb LOD.

const DIR := "res://world/human_realm/shared/assets/flora/"
const FAR_BUDGET := 300

const BUDGETS := {
	"acorn_scatter": 500,
	"ash_deadfall": 500,
	"blackberry_bramble": 1500,
	"blackthorn_sloe": 1500,
	"chaga_growth": 500,
	"chalk_lump": 500,
	"charcoal_lump": 500,
	"clay_lump": 500,
	"dead_bracken": 1500,
	"feather_crow": 300,
	"feather_hawk": 300,
	"feather_owl": 300,
	"flint_nodule": 500,
	"frozen_reeds": 1500,
	"hawthorn": 1500,
	"hazel_shrub": 1500,
	"hazelnut_scatter": 500,
	"holly_bush": 1500,
	"ice_moss": 500,
	"icicle_cluster": 500,
	"juniper_shrub": 1500,
	"log_fallen": 800,
	"madder_patch": 1000,
	"mistletoe_clump": 500,
	"oak_gall_twig": 500,
	"old_mans_beard": 500,
	"pine_cone_scatter": 500,
	"pine_resin_blob": 500,
	"red_ochre_rock": 500,
	"rock_boulder_a": 800,
	"rock_boulder_b": 800,
	"rock_boulder_c": 800,
	"rock_flat": 800,
	"rock_scree": 800,
	"shed_antler": 500,
	"snail_shells": 500,
	"snow_mound": 800,
	"snowdrop_cluster": 500,
	"stone_wall_section": 800,
	"stump": 800,
	"tinder_fungus": 500,
	"tree_ash": 6000,
	"tree_birch": 6000,
	"tree_dead_snag": 4000,
	"tree_oak_bare": 6000,
	"tree_pine": 6000,
	"tree_spruce": 6000,
	"tree_waiting_oak": 15000,
	"tree_willow_pollard": 5000,
	"wild_rose_briar": 1500,
	"willow_withies": 1500,
	"winter_grass_tuft": 800,
	"wintergreen_patch": 500,
	"woad_rosette": 800,
}

const TREES := ["tree_oak_bare", "tree_ash", "tree_birch", "tree_pine", "tree_spruce", "tree_dead_snag", "tree_willow_pollard", "tree_waiting_oak"]


func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			n += (idx as PackedInt32Array).size() / 3
		else:
			n += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _check(path: String, budget: int) -> void:
	var mesh := ScatterLayer._load_mesh(path)
	assert_not_null(mesh, "loads %s" % path)
	if mesh == null:
		return
	assert_gt(mesh.get_surface_count(), 0, "%s has surfaces" % path)
	var arr := mesh.surface_get_arrays(0)
	var colors = arr[Mesh.ARRAY_COLOR]
	assert_true(colors != null and (colors as PackedColorArray).size() > 0, "%s has vertex colours" % path)
	var tris := _tris(mesh)
	assert_between(tris, 1, budget, "%s triangles %d within %d" % [path, tris, budget])
	var aabb := mesh.get_aabb()
	assert_almost_eq(aabb.position.y, 0.0, 0.25, "%s origin at its base" % path)


func test_every_asset_loads_with_colour_and_budget() -> void:
	for id: String in BUDGETS:
		_check(DIR + id + ".glb", BUDGETS[id])


func test_every_tree_has_far_lod() -> void:
	for id: String in TREES:
		_check(DIR + id + "_far.glb", FAR_BUDGET)
