extends GutTest
## L21 Spring Court flora kit (tools/woods/blender/spring_flora.py): every
## species is in FloraLibrary, loads from its Blender model with a "near"
## mesh inside the R4 budget for its layer and a "far" LOD1 of about half,
## and every species the woods biomes list has a mesh.

const BUDGET := {"tree": 3000, "shrub": 700, "detail": 180}
const NEW := [
	&"candyfloss_tree", &"wisteria_tree", &"golden_chain", &"magnolia",
	&"peony_bush", &"hydrangea", &"azalea", &"lavender_mound", &"iris_clump", &"goldenrod",
	&"lupin_clump", &"sugarberry_bush",
	&"tulip_patch", &"daffodil", &"maidens_lace", &"forget_me_not", &"allium", &"pansy_patch",
]
const REMADE := [
	&"rose_bush_red", &"rose_bush_white", &"honeysuckle_bush", &"hazel", &"bramble", &"fern",
	&"bracken", &"foxglove", &"moss_mound", &"grass_tuft", &"tall_grass", &"clover", &"bluebell",
	&"crocus", &"snowdrop", &"primrose", &"violet", &"buttercup", &"daisy", &"wood_anemone", &"cowslip",
]
const BIOMES := [&"border_woods", &"eastern_woods", &"suriel_glade"]


func _tris(root: Node, name: String) -> int:
	var mi := root.find_child(name, true, false) as MeshInstance3D
	if mi == null:
		return -1
	var a: Array = mi.mesh.surface_get_arrays(0)
	var idx: Variant = a[Mesh.ARRAY_INDEX]
	return (idx.size() if idx != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3


func test_kit_is_big_enough() -> void:
	var trees := NEW.filter(func(s: StringName) -> bool: return FloraLibrary.info(s)["layer"] == "tree")
	var shrubs := NEW.filter(func(s: StringName) -> bool: return FloraLibrary.info(s)["layer"] == "shrub")
	var flowers := NEW.filter(func(s: StringName) -> bool: return FloraLibrary.info(s)["layer"] == "detail")
	assert_gte(trees.size(), 4, "new trees")
	assert_gte(shrubs.size(), 6, "new shrubs")
	assert_gte(flowers.size(), 5, "new flowers")
	assert_gte(REMADE.size(), 15, "procedural species remade in Blender")


func test_every_species_loads_from_blender_inside_budget() -> void:
	for s: StringName in NEW + REMADE:
		assert_true(FloraLibrary.has(s), "%s in FloraLibrary" % s)
		assert_true(FloraLibrary.has_model(s), "%s has a Blender model" % s)
		var root := (load(FloraLibrary.MODELS % s) as PackedScene).instantiate()
		var near := _tris(root, "near")
		var far := _tris(root, "far")
		root.free()
		var cap: int = BUDGET[FloraLibrary.info(s)["layer"]]
		assert_between(near, 1, cap, "%s near tris" % s)
		assert_between(far, 1, int(near * 0.65), "%s LOD1 tris" % s)
		assert_gt((FloraLibrary.mesh(s) as ArrayMesh).get_surface_count(), 0, "%s mesh" % s)


func test_models_carry_vertex_colour_and_stay_small() -> void:
	for s: StringName in NEW + REMADE:
		var path := FloraLibrary.MODELS % s
		assert_lt(FileAccess.get_file_as_bytes(path).size(), 300 * 1024, "%s glb size" % s)
		var a: Array = FloraLibrary.arrays_for(s, 1)
		assert_not_null(a[Mesh.ARRAY_COLOR], "%s vertex colour" % s)
		assert_not_null(a[Mesh.ARRAY_TEX_UV], "%s wind/glow UV" % s)


func test_spring_biomes_use_the_new_kit_and_every_listed_species_exists() -> void:
	for id in BIOMES:
		var def: WoodsRegionDef = load("res://data/regions/spring_court/%s_biomes.tres" % id)
		var used := {}
		for b: WoodsBiome in def.biomes:
			for dict: Dictionary in [b.trees, b.shrubs, b.detail]:
				for k: StringName in dict:
					assert_true(FloraLibrary.has(k), "%s/%s lists %s" % [id, b.id, k])
					if k in NEW:
						used[k] = true
		assert_gte(used.size(), 8, "%s new L21 species in use" % id)
