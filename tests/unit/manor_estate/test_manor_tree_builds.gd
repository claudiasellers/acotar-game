extends GutTest
# gate: when:world/spring_court/manor_estate/*,world/shared/scatter/*,world/shared/shaders/*,world/spring_court/wider/assets/trees/ez/bark_*,tools/blender/estate_tree.py,tools/blender/prop_kit.py,tools/court/gen_estate_tree_clumps.py
## Wider-court D2/E2: the estate's trees are EstateTrees' (the estate
## tree-builder): every tree species comes in several builds inside the tree
## budget, each part on its own material of the estate tree shader; the willow
## is fronds, no leaf clouds; the scatter splits each tree layer over the
## builds so neighbours differ and draws them from the tree field.

const TREES: Array[StringName] = [&"oak", &"birch", &"willow", &"cherry_blossom", &"apple_blossom", &"pear_tree", &"crab_apple"]

var layers: Array[ScatterLayer]


func before_all() -> void:
	layers = ManorScatter.build_all()


static func _tris(m: Mesh) -> int:
	var n := 0
	for i in m.get_surface_count():
		n += (m.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


static func _parts(m: Mesh) -> Array:
	var out := []
	for i in m.get_surface_count():
		out.append(int((m.surface_get_material(i) as ShaderMaterial).get_shader_parameter(&"part")))
	return out


func test_every_tree_species_has_its_builds_within_budget() -> void:
	for sp in TREES:
		assert_true(EstateTrees.has(sp), "%s is an estate tree" % sp)
		assert_eq(FloraLib.builds(sp), 5 if sp == &"willow" else 3, "%s builds" % sp)
		var seen := {}
		var h := FloraLib.height_of(sp)
		for b in FloraLib.builds(sp):
			var m := FloraLib.mesh(sp, b)
			assert_not_null(m, "%s#%d" % [sp, b])
			assert_false(seen.has(m), "%s#%d is its own mesh" % [sp, b])
			seen[m] = true
			var box := m.get_aabb()
			assert_almost_eq(box.end.y, h, h * 0.03, "%s#%d stands at the species height" % [sp, b])
			assert_gt(box.position.y, -maxf(0.05, h * 0.01), "%s#%d roots stay near the ground" % [sp, b])
			assert_lte(_tris(m), 6000, "%s#%d within the tree budget" % [sp, b])
			for i in m.get_surface_count():
				var mat := m.surface_get_material(i) as ShaderMaterial
				# cut-out leaves and fronds; everything else solid
				assert_eq(mat.shader.resource_path, EstateTrees.SHADER if _parts(m)[i] == 1 else EstateTrees.SHADER_SOLID,
					"%s#%d surface %d on its estate tree shader" % [sp, b, i])
				assert_eq(mat, FloraLib.mesh(sp, 0).surface_get_material(i) if b > 0 and _parts(m) == _parts(FloraLib.mesh(sp, 0)) else mat,
					"%s#%d shares the species' materials" % [sp, b])
		assert_same(FloraLib.mesh(sp), FloraLib.mesh(sp, 0), "%s default is build a" % sp)
		assert_same(FloraLib.mesh(sp, FloraLib.builds(sp)), FloraLib.mesh(sp, 0), "%s builds wrap" % sp)


func test_parts_wood_leaf_clouds_and_hearts() -> void:
	# bark 0, leaves 1, core 2, fruit 3 (EstateTrees.PARTS)
	assert_eq(_parts(FloraLib.mesh(&"oak")), [0, 1, 2], "the oak: wood, leaf clouds, their hearts")
	assert_eq(_parts(FloraLib.mesh(&"pear_tree")), [0, 1, 2, 3], "the pear carries pears")
	for sp in TREES:
		if sp == &"willow":
			continue    # fronds, below
		var leaves := FloraLib.mesh(sp).surface_get_material(1) as ShaderMaterial
		assert_eq(bool(leaves.get_shader_parameter(&"own_colour")), sp in [&"cherry_blossom", &"apple_blossom", &"crab_apple"],
			"%s: blossom keeps its painted colours, leaves are banded" % sp)
		assert_true(String((leaves.get_shader_parameter(&"tex") as Texture2D).resource_path).ends_with("puff_%s.png" % sp), "%s has its clump picture" % sp)
	var birch_bark: Color = EstateTrees.material(&"birch", &"bark").get_shader_parameter(&"bark_col")
	assert_gt(birch_bark.get_luminance(), 0.8, "birch bark is white")


func test_the_willow_is_fronds_with_no_leaf_clouds() -> void:
	# owner, 2026-11-12: "i dont like the clumps at the top ... thats not what actual willows look like"
	for b in FloraLib.builds(&"willow"):
		var m := FloraLib.mesh(&"willow", b)
		assert_eq(_parts(m), [0, 1], "willow#%d: wood and fronds" % b)
		var fronds := m.surface_get_material(1) as ShaderMaterial
		assert_true(bool(fronds.get_shader_parameter(&"hanging")), "willow#%d fronds hang" % b)
		assert_true(String((fronds.get_shader_parameter(&"tex") as Texture2D).resource_path).ends_with("frond_willow.png"))
	# the curtains: a..c stop short, d trails some strands, e every strand reaches the grass
	var low := []
	for b in FloraLib.builds(&"willow"):
		var verts: PackedVector3Array = FloraLib.mesh(&"willow", b).surface_get_arrays(1)[Mesh.ARRAY_VERTEX]
		var n := 0
		for v in verts:
			n += 1 if v.y < 0.4 else 0
		low.append(n)
	assert_eq(low[0] + low[1] + low[2], 0, "the short curtains stop above the grass")
	assert_gt(low[3], 20, "d trails some strands to the grass")
	assert_gt(low[4], low[3] * 3, "e sends every strand to the grass")


func test_leaf_cards_carry_their_picture_coordinates_and_tone() -> void:
	# Blender 5.3's exporter dropped COLOR_0 unless the attribute was active.
	for sp in TREES:
		var a := FloraLib.mesh(sp).surface_get_arrays(1)
		assert_not_null(a[Mesh.ARRAY_TEX_UV], "%s leaves have UVs" % sp)
		assert_not_null(a[Mesh.ARRAY_COLOR], "%s leaves have their tone" % sp)


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
	for l in (parent.get_node("ScatterFieldWide") as ScatterField).layers:
		assert_false(l.tags.has("tree"), "%s: no tree is drawn twice" % l.id)


func test_tree_draws_are_counted_per_build_and_stay_lighter_than_before() -> void:
	var tree_draws := 0
	for l in layers:
		if l.tags.has("tree"):
			for g: Array in ManorScatter.chunk_groups(l):
				tree_draws += (g[2] as Dictionary).size()
	# one build in 128 m chunks drew 146 tree chunks
	gut.p("tree chunk draws: %d" % tree_draws)
	assert_lt(tree_draws, 146, "the builds in 320 m chunks draw fewer tree chunks than one did")
	assert_gt(tree_draws, 7 * 3, "every species' builds are counted")


func test_trunk_colliders_fit_the_species() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	ManorScatter.add_field(parent, layers)
	var oak := 0
	var birch := 0
	for cs: CollisionShape3D in parent.get_node("TreeTrunks").get_children():
		var r := (cs.shape as CylinderShape3D).radius
		oak += 1 if is_equal_approx(r, EstateTrees.TRUNK_RADIUS[&"oak"]) else 0
		birch += 1 if is_equal_approx(r, EstateTrees.TRUNK_RADIUS[&"birch"]) else 0
	assert_gt(oak, 100, "the oaks' stout trunks")
	assert_gt(birch, 100, "the birches' slender ones")
	assert_gt(EstateTrees.TRUNK_RADIUS[&"oak"], EstateTrees.TRUNK_RADIUS[&"crab_apple"] * 2.0)
