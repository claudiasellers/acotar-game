extends GutTest

const LORE_IDS := ["ing_rose_red", "ing_rose_white", "ing_rose_gold", "ing_rose_hip", "ing_thornbriar_sap",
	"ing_wild_hyacinth", "ing_foxglove", "ing_lavender", "ing_honeysuckle", "ing_willow_bark", "ing_elderflower",
	"ing_wild_strawberry", "ing_blackberry", "ing_moonflower", "ing_glowcap", "ing_hollow_root",
	"ing_faelight_dandelion", "ing_ash_wood", "ing_oak_gall", "ing_woad", "ing_madder", "ing_snowdrop",
	"ing_pine_resin", "ing_wisteria", "ing_cherry_blossom", "ing_lilac", "ing_moss", "ing_blighted_petals",
	"ing_venison", "ing_sinew", "ing_hide", "ing_rabbit", "ing_hare", "ing_boar", "ing_trout",
	"ing_hawk_feather", "ing_owl_feather", "ing_honey", "ing_snail_shell", "ing_wolf_pelt",
	"ing_starlight_water", "ing_rose_maze_dew", "ing_rite_spring", "ing_river_silt", "ing_salt",
	"ing_iron_filings", "ing_manor_fruit", "ing_faerie_wine", "ing_faerie_bread", "ing_candied_flowers",
	"ing_stale_bread", "ing_venison_stew"]


func test_every_lore_ingredient_has_data() -> void:
	for id in LORE_IDS:
		assert_true(ItemCatalog.has(StringName(id)), "missing %s" % id)


func test_catalogue_is_large_and_tagged() -> void:
	var all := ItemCatalog.ingredients()
	assert_gt(all.size(), 100)
	for i in all:
		assert_ne(i.display_name, "", "%s has a name" % i.id)
		assert_false(i.regions.is_empty(), "%s has regions" % i.id)
		assert_false(i.has_tag(&"iron"), "iron does nothing to fae (Keeper)")


func test_human_realm_has_ten_plus_edible_winter_ingredients() -> void:
	var count := 0
	for i in ItemCatalog.ingredients():
		var human := i.regions.has(&"reg_winter_forest") or i.regions.has(&"reg_archeron_cottage") or i.regions.has(&"reg_village")
		if human and i.edible and i.season != &"spring":
			count += 1
	assert_gte(count, 10)


func test_aliases_resolve_to_lore_ids() -> void:
	assert_eq(ItemCatalog.get_item(&"deer_venison").id, &"ing_venison")
	assert_eq(ItemCatalog.canonical(&"great_wolf_pelt"), &"obj_wolf_pelt")


func test_wardrobe_variety() -> void:
	assert_gte(WardrobeCatalog.all_pieces().size(), 60)
	assert_gte(WardrobeCatalog.all_makeup().size(), 25)
	assert_gte(WardrobeCatalog.all_hair().size(), 8)
	for m in WardrobeCatalog.all_makeup():
		assert_true(MakeupData.CHANNELS.has(m.channel), "%s channel" % m.id)
