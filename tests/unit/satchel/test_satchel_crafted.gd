## Contract test for L50 (the satchel page's real models and handmade look):
## every forage item and keepsake with a model has an icon rendered from it,
## the hero is the live model, the tag says where and when, and the look
## comes from the crafted theme layer.
extends GutTest


func _forage_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for id in ItemCatalog.all_ids():
		var item := ItemCatalog.get_item(id)
		if item is IngredientData or item is CollectibleData:
			out.append(item)
	return out


func test_every_modelled_forage_item_has_a_rendered_icon() -> void:
	var modelled := 0
	var missing: Array[String] = []
	for item in _forage_items():
		if not SatchelModel.has_model(item.id):
			continue
		modelled += 1
		if not SatchelIcon.path_for(item.id, 256.0).ends_with(".webp"):
			missing.append(String(item.id))
	assert_gt(modelled, 140, "most forage and keepsakes have a real model")
	assert_eq(missing, [] as Array[String], "re-run tools/ui/render_item_icons.gd")


func test_aliased_ids_find_their_model_and_icon() -> void:
	assert_true(SatchelModel.has_model(&"ing_watermint"))
	assert_true(SatchelModel.has_model(&"col_jay_feather"))
	assert_true(SatchelIcon.path_for(&"col_jay_feather", 256.0).ends_with(".webp"))


func test_model_is_dressed_with_vertex_colour() -> void:
	var m := SatchelModel.instance(&"ing_bilberry")
	assert_not_null(m)
	var meshes := m.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0)
	var mat := (meshes[0] as MeshInstance3D).material_override as StandardMaterial3D
	assert_not_null(mat)
	assert_true(mat.vertex_color_use_as_albedo)
	assert_gt(SatchelModel.bounds(m).size.length(), 0.0)
	m.free()


func test_hero_is_the_real_model_and_unmodelled_things_keep_their_cut_out() -> void:
	var table := SatchelTable.new()
	add_child_autofree(table)
	var inv := Inventory.new()
	inv.add(&"ing_moonflower")
	var card := table.add_card(SatchelEntries.item_entry(inv, &"ing_moonflower", SatchelEntries.ALL))
	table.place(card, Vector2(400, 300), 160.0, 0.0, 0.1, 0.5)
	var pivot := table.hero_model(card, &"ing_moonflower")
	assert_not_null(pivot)
	assert_gt(pivot.find_children("*", "MeshInstance3D", true, false).size(), 0)
	table.place_model(card, 1.0, 0.7)
	assert_true(pivot.visible)
	assert_false((card.get_node(^"Face") as Node3D).visible)
	table.place_model(card, 0.0, 0.0)
	assert_false(pivot.visible)
	assert_true((card.get_node(^"Face") as Node3D).visible)
	assert_null(table.hero_model(table.add_card({"id": &"ing_venison", "icon": &"meat"}), &"ing_venison"))


func test_tag_says_where_when_and_what_it_is() -> void:
	var moon := ItemCatalog.get_item(&"ing_moonflower")
	var where := SatchelMenu.where_text(moon)
	assert_true(where.to_lower().contains("night"), where)
	assert_eq(where.to_lower().count("night"), 1, "no doubled 'at night': " + where)
	var bil := ItemCatalog.get_item(&"ing_bilberry")
	var traits := SatchelMenu.trait_words(bil)
	assert_has(traits, "Vital")
	assert_has(traits, "Edible")
	assert_eq(SatchelMenu.where_text(null), "")


func test_handmade_layer_dresses_the_page() -> void:
	var t := SatchelTheme.theme()
	for v: StringName in [&"SatchelTab", &"SatchelDetail", &"SatchelChip", &"SatchelKey"]:
		var style_name := &"panel" if v != &"SatchelTab" else &"normal"
		assert_true(t.get_stylebox(style_name, v) is StyleBoxTexture, "%s is a crafted texture" % v)
	assert_not_null(SatchelTheme.texture(SatchelTheme.WEAVE_PATH))
	assert_not_null(SatchelTheme.texture(SatchelTheme.WASH_PATH))
