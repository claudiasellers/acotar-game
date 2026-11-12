extends GutTest
## L21 Spring Court flora kit (tools/woods/blender/spring_flora.py): every
## species is in FloraLibrary, loads from its Blender model with a "near"
## mesh inside the R4 budget for its layer and a "far" LOD1 of about half,
## and every species the woods biomes list has a mesh.

const BUDGET := {"tree": 3000, "shrub": 700, "detail": 180}
## The special trees (tools/woods/blender/special_trees.py), rebuilt one at a
## time with the owner: planted sparsely, on the estate trees' budget.
const SPECIAL: Array[StringName] = [&"magnolia", &"magnolia_harlequin", &"candyfloss_tree", &"wisteria_tree"]
const SPECIAL_BUDGET := 6000
## A candyfloss tree is wood plus meshes of floss and fuzz (FloraLibrary.FLOSSED):
## all together stay inside this.
const FLOSSED_BUDGET := 9000
const NEW := [
	&"golden_chain", &"magnolia",
	&"peony_bush", &"hydrangea", &"azalea", &"lavender_mound", &"iris_clump", &"goldenrod",
	&"lupin_clump", &"sugarberry_bush", &"spire_bed",
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


## Triangles of one detail step: the "near"/"far" mesh, plus its floss and
## fuzz meshes on a flossed species.
func _step_tris(root: Node, species: StringName, step: String) -> int:
	var n := _tris(root, step)
	if n < 0 or species not in FloraLibrary.FLOSSED:
		return n
	return n + maxi(_tris(root, step + "_floss"), 0) + maxi(_tris(root, step + "_fuzz"), 0)


func test_kit_is_big_enough() -> void:
	var trees := (NEW + SPECIAL).filter(func(s: StringName) -> bool: return FloraLibrary.info(s)["layer"] == "tree")
	var shrubs := NEW.filter(func(s: StringName) -> bool: return FloraLibrary.info(s)["layer"] == "shrub")
	var flowers := NEW.filter(func(s: StringName) -> bool: return FloraLibrary.info(s)["layer"] == "detail")
	assert_gte(trees.size(), 4, "new trees")
	assert_gte(shrubs.size(), 6, "new shrubs")
	assert_gte(flowers.size(), 5, "new flowers")
	assert_gte(REMADE.size(), 15, "procedural species remade in Blender")


func test_every_species_loads_from_blender_inside_budget() -> void:
	for s: StringName in NEW + REMADE + SPECIAL:
		assert_true(FloraLibrary.has(s), "%s in FloraLibrary" % s)
		assert_true(FloraLibrary.has_model(s), "%s has a Blender model" % s)
		var root := (load(FloraLibrary.MODELS % s) as PackedScene).instantiate()
		var near := _step_tris(root, s, "near")
		var far := _step_tris(root, s, "far")
		root.free()
		var cap: int = BUDGET[FloraLibrary.info(s)["layer"]]
		if s in FloraLibrary.FLOSSED:
			cap = FLOSSED_BUDGET
		elif s in SPECIAL:
			cap = SPECIAL_BUDGET
		assert_between(near, 1, cap, "%s near tris" % s)
		assert_between(far, 1, 1500 if s in SPECIAL else int(near * 0.65), "%s LOD1 tris" % s)
		assert_gt((FloraLibrary.mesh(s) as ArrayMesh).get_surface_count(), 0, "%s mesh" % s)


func test_models_carry_vertex_colour_and_stay_small() -> void:
	for s: StringName in NEW + REMADE + SPECIAL:
		var path := FloraLibrary.MODELS % s
		assert_lt(FileAccess.get_file_as_bytes(path).size(), (600 if s in SPECIAL else 300) * 1024, "%s glb size" % s)
		var a: Array = FloraLibrary.arrays_for(s, 1)
		assert_not_null(a[Mesh.ARRAY_COLOR], "%s vertex colour" % s)
		assert_not_null(a[Mesh.ARRAY_TEX_UV], "%s wind/glow UV" % s)


func test_a_flossed_tree_draws_solid_floss_and_cut_out_fuzz() -> void:
	for s: StringName in FloraLibrary.FLOSSED:
		assert_true(s in SPECIAL, "%s is one of the special trees" % s)
		var root := (load(FloraLibrary.MODELS % s) as PackedScene).instantiate()
		assert_gt(_tris(root, "near_floss"), 0, "%s near floss mesh" % s)
		assert_gt(_tris(root, "near_fuzz"), 0, "%s near fuzz mesh" % s)
		assert_gt(_tris(root, "far_floss"), 0, "%s far floss mesh" % s)
		assert_lt(_tris(root, "far_floss"), _tris(root, "near_floss"), "%s far floss is the lighter one" % s)
		assert_eq(_tris(root, "far_fuzz"), -1, "%s has no fuzz far away" % s)
		root.free()
		var m := FloraLibrary.mesh(s) as ArrayMesh
		assert_eq(m.get_surface_count(), 3, "%s wood, floss and fuzz surfaces" % s)
		assert_eq((FloraLibrary.far_mesh(s) as ArrayMesh).get_surface_count(), 2, "%s far: wood and floss" % s)
		# Only the fuzz is a cut-out: a shader that writes ALPHA anywhere is
		# drawn as one everywhere, so the billows have a shader of their own.
		var floss := m.surface_get_material(1) as ShaderMaterial
		var fuzz := m.surface_get_material(2) as ShaderMaterial
		assert_eq(floss.shader.resource_path, FloraLibrary.FLOSS_SHADER, "%s floss shader" % s)
		assert_eq(fuzz.shader.resource_path, FloraLibrary.FUZZ_SHADER, "%s fuzz shader" % s)
		assert_false(floss.shader.code.contains("FLOSS_FUZZ"), "%s billows are drawn solid" % s)
		assert_true(fuzz.shader.code.contains("#define FLOSS_FUZZ"), "%s fuzz is the cut-out" % s)
		var body := FileAccess.get_file_as_string("res://world/spring_court/shared/woods_floss.gdshaderinc")
		assert_eq(body.count("ALPHA = "), 1, "the floss body writes ALPHA once")
		assert_lt(body.find("#ifdef FLOSS_FUZZ", body.find("void fragment")), body.find("ALPHA = "), "and only for the fuzz")
		for surface in [1, 2]:
			var mat := m.surface_get_material(surface) as ShaderMaterial
			assert_not_null(mat.get_shader_parameter(&"cotton"), "%s cotton texture on surface %d" % [s, surface])
			var a: Array = m.surface_get_arrays(surface)
			assert_not_null(a[Mesh.ARRAY_COLOR], "%s tone and tuft colour on surface %d" % [s, surface])
			assert_not_null(a[Mesh.ARRAY_TEX_UV], "%s wind UV on surface %d" % [s, surface])


## The tuft colour seen from outside, by where round the tree and how high:
## {bin: colour 0..3} of the floss point furthest out in each bin.
func _outer_tufts(arrays: Array) -> Dictionary:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var bounds := AABB(v[0], Vector3.ZERO)
	for p in v:
		bounds = bounds.expand(p)
	var out := {}
	var reach := {}
	for i in v.size():
		var p := v[i]
		var bin := Vector2i(int((atan2(p.z, p.x) + PI) / TAU * 12.0) % 12,
			mini(int((p.y - bounds.position.y) / bounds.size.y * 8.0), 7))
		var r := Vector2(p.x, p.z).length()
		if r > float(reach.get(bin, -1.0)):
			reach[bin] = r
			out[bin] = int(c[i].g * 4.0)
	return out


## A tree of many colours keeps them as it swaps to its far step: seen from
## outside, the far floss has the near floss's colour in the same place.
func test_a_flossed_tree_is_coloured_alike_near_and_far() -> void:
	for s: StringName in FloraLibrary.FLOSSED:
		var near := _outer_tufts((FloraLibrary.mesh(s) as ArrayMesh).surface_get_arrays(1))
		var far := _outer_tufts((FloraLibrary.far_mesh(s) as ArrayMesh).surface_get_arrays(1))
		var colours := {}
		var same := 0
		var both := 0
		for bin: Vector2i in far:
			colours[far[bin]] = true
			if near.has(bin):
				both += 1
				if near[bin] == far[bin]:
					same += 1
		assert_eq(colours.size(), 4, "%s far floss shows all four tuft colours" % s)
		assert_gt(both, 60, "%s near and far floss fill the same cone" % s)
		assert_gte(float(same) / float(maxi(both, 1)), 0.7, "%s far tufts match the near ones (%d of %d places)" % [s, same, both])


func test_spring_biomes_use_the_new_kit_and_every_listed_species_exists() -> void:
	for id in BIOMES:
		var def: WoodsRegionDef = load("res://data/regions/spring_court/%s_biomes.tres" % id)
		var used := {}
		for b: WoodsBiome in def.biomes:
			for dict: Dictionary in [b.trees, b.shrubs, b.detail]:
				for k: StringName in dict:
					assert_true(FloraLibrary.has(k), "%s/%s lists %s" % [id, b.id, k])
					if k in NEW or k in SPECIAL:
						used[k] = true
		assert_gte(used.size(), 8, "%s new L21 species in use" % id)
