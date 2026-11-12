extends GutTest
# gate: when:world/spring_court/manor_estate/*,world/shared/scatter/*,world/shared/shaders/stylized_foliage*,tools/blender/manor_flora.py,tools/blender/prop_kit.py
## Wider-court D2 (owner, 2026-11-12: keep the cotton-candy trees, refine
## them): every estate tree species comes in builds, build 0 the original;
## the scatter splits each tree layer over the builds so neighbours differ,
## draws them from the tree field, and each tree takes its own shade.

const TREES: Array[StringName] = [&"oak", &"birch", &"willow", &"cherry_blossom", &"apple_blossom", &"pear_tree", &"crab_apple"]

var layers: Array[ScatterLayer]


func before_all() -> void:
	layers = ManorScatter.build_all()


func test_every_tree_species_has_three_builds_on_one_material() -> void:
	for sp in TREES:
		assert_eq(FloraLib.builds(sp), 3, "%s builds" % sp)
		var seen := {}
		for b in FloraLib.builds(sp):
			var m := FloraLib.mesh(sp, b)
			assert_not_null(m, "%s#%d" % [sp, b])
			assert_false(seen.has(m), "%s#%d is its own mesh" % [sp, b])
			seen[m] = true
			var box := m.get_aabb()
			var h := FloraLib.height_of(sp)
			assert_almost_eq(box.size.y, h, h * 0.03, "%s#%d stands at the species height" % [sp, b])
			assert_almost_eq(box.position.y, 0.0, 0.05, "%s#%d stands on the ground" % [sp, b])
			assert_lte(PropModels.tri_count(m), 3000, "%s#%d within the tree budget" % [sp, b])
			var mat := m.surface_get_material(0) as ShaderMaterial
			assert_eq(mat, FloraLib.foliage_material(sp), "%s#%d shares the species material" % [sp, b])
			assert_eq(mat.get_shader_parameter(&"use_vertex_color"), true)
		assert_eq(FloraLib.mesh(sp, 0), FloraLib.mesh(sp), "%s build 0 is the original" % sp)


func test_build_meshes_carry_vertex_colour() -> void:
	# Blender 5.3's exporter dropped COLOR_0 unless the attribute was active.
	for sp in TREES:
		for b in FloraLib.builds(sp):
			var a := FloraLib.mesh(sp, b).surface_get_arrays(0)
			assert_not_null(a[Mesh.ARRAY_COLOR], "%s#%d has vertex colours" % [sp, b])


func test_trees_take_their_own_shade() -> void:
	var mat := FloraLib.foliage_material(&"oak")
	assert_gt(float(mat.get_shader_parameter(&"instance_value")), 0.0)
	assert_gt(float(mat.get_shader_parameter(&"instance_hue")), 0.0)
	var flower: Variant = FloraLib.foliage_material(&"lavender").get_shader_parameter(&"instance_value")
	assert_true(flower == null or float(flower) == 0.0, "flowers keep one shade")


func test_the_scatter_splits_trees_over_builds_and_neighbours_differ() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	ManorScatter.add_field(parent, layers)
	var field := parent.get_node("ScatterFieldTrees") as ScatterField
	assert_eq(field.chunk_size, ManorScatter.TREE_CHUNK)
	var drawn := 0
	for l in field.layers:
		drawn += l.count()
		assert_true(String(l.id).contains("@"), "%s is a build layer" % l.id)
	var planted := 0
	var pairs := 0
	var same := 0
	for l in layers:
		if not l.tags.has("tree"):
			continue
		planted += l.count()
		var w := ManorScatter.tree_builds(l, FloraLib.builds(ManorScatter.species_of(l)))
		for i in l.count():
			for j in i:
				if l.position_of(i).distance_to(l.position_of(j)) < 10.0:
					pairs += 1
					same += 1 if w[i] == w[j] else 0
	assert_eq(drawn, planted, "every tree drawn once")
	assert_gt(pairs, 300, "the estate has close tree neighbours to test")
	gut.p("same-build neighbours within 10 m: %d of %d" % [same, pairs])
	assert_lt(float(same) / pairs, 0.1, "close neighbours rarely share a build")
	assert_null(parent.get_node("ScatterFieldWide").layers.filter(func(l: ScatterLayer) -> bool: return l.tags.has("tree")).pop_back(),
		"no tree is drawn twice")


func test_tree_draws_are_counted_per_build_and_stay_lighter_than_before() -> void:
	var tree_draws := 0
	for l in layers:
		if l.tags.has("tree"):
			for g: Array in ManorScatter.chunk_groups(l):
				tree_draws += (g[2] as Dictionary).size()
	# one build in 128 m chunks drew 146 tree chunks
	assert_lt(tree_draws, 146, "three builds in 320 m chunks draw fewer tree chunks than one did")
	assert_gt(tree_draws, 7 * 3, "every species' builds are counted")
