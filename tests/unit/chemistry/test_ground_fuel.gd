## Contract: a Spring region's grass, reeds and hay become ElementField ground
## fuel when it streams in (built off the main thread) and are gone when it
## streams out; winter regions and forageables never burn (T5, L57).
extends GutTest

var touch: TouchWorld


func before_each() -> void:
	touch = TouchWorld.new()
	add_child_autofree(touch)
	touch.elements.follow_world_wind = false
	touch.elements.set_physics_process(false)


## A region root with a 24 m meadow of grass clumps 3 m apart round (10, 0, 10),
## a rock outcrop at x 60 and a strawberry drift at x 100.
func _region(path: String, script_source: String = "") -> Node3D:
	var root := Node3D.new()
	if script_source != "":
		var s := GDScript.new()
		s.source_code = script_source
		s.reload()
		root.set_script(s)
	root.scene_file_path = path
	var field := ScatterField.new()
	field.region_id = &"test_meadow"
	field.layers = [
		_layer(&"decor_00_flora_grass_clump_a", Vector2(-2, -2), 3.0, 9),
		_layer(&"decor_31_rock_mossy", Vector2(60, 0), 2.0, 5),
		_layer(&"forage_ing_wild_strawberry", Vector2(100, 0), 1.0, 5, &"ing_wild_strawberry"),
	]
	root.add_child(field)
	add_child_autofree(root)
	return root


func _layer(id: StringName, from: Vector2, spacing: float, n: int, ingredient: StringName = &"") -> ScatterLayer:
	var l := ScatterLayer.new()
	l.id = id
	l.ingredient_id = ingredient
	for ix in n:
		for iz in n:
			l.add(Vector3(from.x + ix * spacing, 0.0, from.y + iz * spacing), 0.0, 1.0)
	return l


func _wait_for_ground() -> void:
	for i in 300:
		if not touch.elements.ground_pending():
			return
		await get_tree().process_frame


func test_stream_in_registers_grass_and_unload_frees_it() -> void:
	var field := touch.elements
	touch._on_region_loaded(&"test_meadow", _region("res://world/spring_court/test_meadow/test_meadow.tscn"))
	await _wait_for_ground()
	assert_true(field.has_ground(&"test_meadow"), "registered from a worker thread")
	assert_eq(field.cell_count(), 0, "no cells until something happens there")
	assert_gt(field.ignite_at(Vector3(10, 0, 10), 1.2), 0, "a fire arrow lights the meadow")
	for i in 40:
		field.step(ElementField.TICK)
	assert_gt(field.cell_count(), 30, "the fire ran on through the grass: %d cells" % field.cell_count())
	assert_eq(field.ignite_at(Vector3(64, 0, 4), 1.2), 0, "the rocks do not burn")
	assert_eq(field.ignite_at(Vector3(102, 0, 2), 1.2), 0, "nor do forageables (rule 3)")
	touch._on_region_unloaded(&"test_meadow")
	assert_false(field.has_ground(&"test_meadow"))
	assert_eq(field.cell_count(), 0, "every ground cell went with the region")
	assert_eq(field.burning_count(), 0)
	assert_eq(field.ignite_at(Vector3(4, 0, 4), 1.2), 0, "and nothing is left to light")


func test_winter_regions_have_no_ground_fuel() -> void:
	touch._on_region_loaded(&"village", _region("res://world/human_realm/village/village.tscn"))
	await _wait_for_ground()
	assert_false(touch.elements.has_ground(&"village"))
	assert_eq(touch.elements.ignite_at(Vector3(10, 0, 10), 1.2), 0)


func test_waits_for_a_region_still_building_its_scatter() -> void:
	var root := _region("res://world/spring_court/test_meadow/test_meadow.tscn", "extends Node3D\nsignal built\nvar is_built := false\n")
	touch._on_region_loaded(&"test_meadow", root)
	await _wait_for_ground()
	assert_false(touch.elements.has_ground(&"test_meadow"), "nothing before its scatter is built")
	root.set(&"is_built", true)
	root.emit_signal(&"built")
	await get_tree().process_frame
	await _wait_for_ground()
	assert_true(touch.elements.has_ground(&"test_meadow"), "registered once built")


func test_rain_soaked_ground_will_not_light() -> void:
	var field := touch.elements
	touch.add_ground_fuel(&"test_meadow", _region("res://world/spring_court/test_meadow/test_meadow.tscn"), false)
	field.rain = 1.0
	for i in 80:
		field.step(ElementField.TICK)
	assert_eq(field.ignite_at(Vector3(10, 0, 10), 1.2), 0, "a shower soaks the meadow")
