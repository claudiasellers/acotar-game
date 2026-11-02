## L45-6: the cave's campfire and the pyres' flames read as fire up close, and
## the Rite cave is dark stone, not pastel rock.
extends GutTest


func test_campfire_builds_ring_cards_sparks_smoke_and_light() -> void:
	var f := CalanmaiFire.campfire()
	add_child_autofree(f)
	assert_not_null(f.find_child("CalanmaiCampfire", false, false), "the stone ring and logs")
	var cards := f.find_children("Flame_*", "MeshInstance3D", false, false)
	assert_eq(cards.size(), CalanmaiFire.CARDS.size())
	assert_not_null(f.find_child("Embers", false, false))
	assert_not_null(f.find_child("Smoke", false, false))
	assert_not_null(f.light)
	assert_true(f.light.shadow_enabled)


## No card's gain lets its core pass about 1.0: a stack of them blooms orange,
## not white (the L45-5 still's blot).
func test_flame_cards_are_capped() -> void:
	var f := CalanmaiFire.bonfire(3.2)
	f.light_energy = 0.0
	add_child_autofree(f)
	assert_null(f.light, "a pyre's light is its owner's")
	var total := 0.0
	for c: MeshInstance3D in f.find_children("Flame_*", "MeshInstance3D", false, false):
		var g := float(c.get_instance_shader_parameter(&"gain"))
		assert_lt(g, 0.7)
		total += g
		var mat := c.material_override as ShaderMaterial
		assert_eq(mat.shader, CalanmaiFire.FLAME_SHADER)
	assert_gt(total, 1.0, "a pyre has a crown of tongues")
	assert_null(f.find_child("CalanmaiCampfire", false, false), "the pyre model is the wood")


func test_rite_cave_stone_material() -> void:
	for id: StringName in [&"rite_cave_wall_a", &"rite_cave_pillar", &"rite_cave_mouth"]:
		var mat := CourtAssets.material_for(id) as ShaderMaterial
		assert_not_null(mat, String(id))
		assert_string_contains(mat.shader.resource_path, "court_cave_stone")
	assert_false((CourtAssets.material_for(&"rite_cave_pool_rim") as ShaderMaterial).shader.resource_path.contains("cave_stone"),
		"the spring keeps its glitter")
	assert_false((CourtAssets.material_for(&"rite_standing_stone_a") as ShaderMaterial).shader.resource_path.contains("cave_stone"))


func test_cave_props_are_dark() -> void:
	var m := CourtAssets.mesh(&"rite_cave_wall_a")
	assert_not_null(m)
	var arr := m.surface_get_arrays(0)
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	assert_gt(cols.size(), 0)
	var sum := 0.0
	for c in cols:
		sum += c.get_luminance()
	assert_lt(sum / cols.size(), 0.25, "dark stone, not pearl (was ~0.8)")


func test_hill_has_no_floating_flame() -> void:
	var content := load("res://data/regions/spring_court/content/hill_of_the_rite.tres")
	assert_false((content.get(&"ambient_fx") as PackedStringArray).has("fx_bonfire_flame"))
