extends GutTest


func before_each() -> void:
	Gameplay.reset()
	WorldState.clear()


func test_twelve_pigments_and_infusing_makes_paint() -> void:
	var count := 0
	for id in ItemCatalog.all_ids():
		if String(id).begins_with("pig_"):
			count += 1
	assert_gte(count, 10)
	var fire := CookingStation.new()
	add_child_autofree(fire)
	Gameplay.inventory.add(&"ing_woad")
	Gameplay.inventory.add(&"ing_madder")
	var r := fire.cook([&"ing_woad", &"ing_madder"] as Array[StringName], &"infuse")
	assert_true(r.ok)
	assert_eq(Gameplay.inventory.count(&"pig_blue"), 1)
	assert_eq(Gameplay.inventory.count(&"pig_red"), 1)
	assert_eq(Gameplay.inventory.dishes.size(), 0)


func test_strokes_spend_paint() -> void:
	Gameplay.inventory.add(&"pig_blue")
	var canvas := PaintingCanvas.new(Gameplay.inventory)
	assert_eq(int(canvas.palette()[&"pig_blue"]), PaintingCanvas.STROKES_PER_CAKE)
	assert_true(canvas.stroke(Vector2(10, 10), Vector2(100, 60), &"pig_blue", 2))
	assert_eq(Gameplay.inventory.count(&"pig_blue"), 0, "the cake is opened")
	assert_eq(int(canvas.palette()[&"pig_blue"]), PaintingCanvas.STROKES_PER_CAKE - 1)
	assert_ne(canvas.image.get_pixel(55, 35), PaintingCanvas.PAPER, "paint landed")
	for i in PaintingCanvas.STROKES_PER_CAKE - 1:
		canvas.stroke(Vector2(5, 5), Vector2(6, 6), &"pig_blue", 0)
	assert_false(canvas.stroke(Vector2(5, 5), Vector2(6, 6), &"pig_blue", 0), "out of paint")
	assert_false(canvas.stroke(Vector2(5, 5), Vector2(6, 6), &"pig_red", 0), "never had red")


func test_finishing_saves_records_and_raises_first_painting() -> void:
	Gameplay.inventory.add(&"pig_red")
	var canvas := PaintingCanvas.new(Gameplay.inventory)
	canvas.stroke(Vector2(50, 50), Vector2(200, 200), &"pig_red", 1)
	var record := Gameplay.gallery.finish(canvas, "Roses", get_tree())
	assert_true(FileAccess.file_exists(record.path))
	assert_true(WorldState.has_flag("first_painting"))
	assert_not_null(Gallery.load_texture(record))
	var copy := Gallery.new()
	copy.load_state(JSON.parse_string(JSON.stringify(Gameplay.gallery.save_state())))
	assert_eq(copy.count(), 1)
	assert_eq(String(copy.paintings[0].title), "Roses")
	DirAccess.remove_absolute(record.path)


func test_painting_hangs_on_a_free_hook() -> void:
	var hook := Node3D.new()
	hook.add_to_group(PaintingObject.HOOK_GROUP)
	add_child_autofree(hook)
	hook.position = Vector3(3, 2, 0)
	var easel := Node3D.new()
	add_child_autofree(easel)
	Gameplay.inventory.add(&"pig_green")
	var canvas := PaintingCanvas.new(Gameplay.inventory)
	canvas.stroke(Vector2(1, 1), Vector2(30, 30), &"pig_green")
	var record := Gameplay.gallery.finish(canvas, "", get_tree())
	var obj := PaintingObject.hang(record, self, easel)
	assert_eq(obj.get_parent(), hook)
	assert_true(hook.get_meta(&"occupied"))
	assert_eq(String(record.title), "Untitled")
	DirAccess.remove_absolute(record.path)
