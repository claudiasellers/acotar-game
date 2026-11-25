## One icon lookup (docs/contracts/ui-theme.md, "Icons"): a thing's picture is
## res://ui/theme/icons/<kind>/<id>.webp, found through Icons and nowhere else.
extends GutTest

const SKIP_DIRS := ["res://addons", "res://tests", "res://tools", "res://.godot", "res://.lanes"]


func test_a_kind_and_an_id_give_the_picture() -> void:
	assert_eq(Icons.path(Icons.STATUS, &"venom"), "res://ui/theme/icons/status/venom.webp")
	assert_true(Icons.has(Icons.STATUS, &"venom"))
	assert_not_null(Icons.texture(Icons.STATUS, &"venom"))
	assert_not_null(Icons.texture(Icons.STATUS, &"hud_bow_string"), "the bow meter's layers are filed with the statuses")
	assert_eq(Icons.path(Icons.STATUS, &"no_such_status"), "")
	assert_false(Icons.has(Icons.BREWS, &""), "nothing has no picture")
	assert_null(Icons.texture(Icons.BREWS, &""))


func test_every_kind_has_its_folder_of_pictures() -> void:
	for kind: StringName in [Icons.ITEMS, Icons.OUTFITS, Icons.BREWS, Icons.STATUS]:
		var pictures := 0
		for file in DirAccess.get_files_at(Icons.DIR + String(kind)):
			if file.ends_with(".webp"):
				pictures += 1
				assert_true(Icons.has(kind, StringName(file.get_basename())), "%s/%s" % [kind, file])
		assert_gt(pictures, 3, "%s has pictures" % kind)


func test_an_item_is_its_picture_or_its_drawn_shape() -> void:
	var rose := &"ing_rose_hip"
	assert_true(Icons.has(Icons.ITEMS, Icons.item_key(rose)), "the rose hip has a picture")
	var pictured := Icons.item({"id": rose, "icon": &"berry"}, 64.0)
	add_child_autofree(pictured)
	assert_true(pictured is TextureRect)
	assert_eq(pictured.custom_minimum_size, Vector2(64, 64))
	var drawn := Icons.item({"id": &"no_such_thing", "icon": &"berry"}, 48.0)
	add_child_autofree(drawn)
	assert_false(drawn is TextureRect, "no picture: the book's drawn shape")
	assert_eq(drawn.size, Vector2(48, 48))


func test_no_script_builds_an_icon_path_of_its_own() -> void:
	var own := RegEx.create_from_string("theme/icons/")
	var hits: Array[String] = []
	_scan("res://", own, hits)
	assert_eq(hits, [] as Array[String], "an icon path written outside Icons. Fix: use Icons.texture(kind, id) or Icons.item(entry, px) / Icons.path(kind, id) instead of spelling theme/icons/...")
	for gone in ["res://ui/satchel/satchel_icon.gd", "res://ui/dressing_room/wardrobe_icon.gd"]:
		assert_false(FileAccess.file_exists(gone), gone)


func _scan(dir: String, own: RegEx, hits: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		var path := dir.path_join(sub)
		if not sub.begins_with(".") and path not in SKIP_DIRS:
			_scan(path, own, hits)
	for file in DirAccess.get_files_at(dir):
		var path := dir.path_join(file)
		if not file.ends_with(".gd") or path == "res://ui/theme/icons.gd":
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			if not lines[i].strip_edges().begins_with("#") and own.search(lines[i]):
				hits.append("%s:%d" % [path, i + 1])
