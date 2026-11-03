## Contract: ElementField's three rules (T5). Elements change materials;
## elements change each other; materials never change each other.
extends GutTest

var field: ElementField


func before_each() -> void:
	field = ElementField.new()
	field.follow_world_wind = false
	add_child_autofree(field)
	field.set_physics_process(false)


func _run(seconds: float) -> void:
	for i in int(round(seconds / ElementField.TICK)):
		field.step(ElementField.TICK)


func test_fire_spreads_through_dry_grass_within_three_seconds() -> void:
	var cells := field.add_patch(Vector3.ZERO, 3.0, &"grass", 1.0)
	var first := field.cells_near(Vector3.ZERO, 0.1)[0]
	var neighbour := field.cells_near(Vector3(1, 0, 0), 0.1)[0]
	assert_eq(field.ignite_at(Vector3.ZERO, 0.1), 1)
	var t := 0.0
	while t < 3.0 and not field.is_burning(neighbour):
		field.step(ElementField.TICK)
		t += ElementField.TICK
	assert_true(field.is_burning(neighbour), "a neighbour 1 m away caught in %.1f s" % t)
	assert_lte(t, 3.0)
	_run(10.0)
	assert_true(field.is_burnt(first), "burns out when its fuel is gone")
	assert_gt(cells.size(), 20)


func test_wet_grass_will_not_light() -> void:
	field.add_patch(Vector3.ZERO, 1.5, &"grass", 1.0, 0.8)
	assert_eq(field.ignite_at(Vector3.ZERO, 0.5), 0, "wet grass refuses the flame")
	assert_eq(field.burning_count(), 0)


func test_water_puts_fire_out_and_wets() -> void:
	field.add_patch(Vector3.ZERO, 2.0, &"grass", 1.0)
	field.ignite_at(Vector3.ZERO, 1.1)
	assert_gt(field.burning_count(), 0)
	field.soak_at(Vector3.ZERO, 3.0)
	assert_eq(field.burning_count(), 0, "doused")
	assert_eq(field.ignite_at(Vector3.ZERO, 1.1), 0, "and too wet to relight")


func test_rain_wets_and_puts_fires_out() -> void:
	var id := field.add_cell(Vector3.ZERO, &"hay")
	field.ignite_at(Vector3.ZERO, 0.1)
	field.rain = 1.0
	_run(8.0)
	assert_false(field.is_burning(id))
	assert_gte(field.wet(id), ElementField.WET_STOPS)


func test_wind_carries_fire_downwind_only() -> void:
	var down := field.add_cell(Vector3(2.4, 0, 0), &"grass")
	var up := field.add_cell(Vector3(-2.4, 0, 0), &"grass")
	field.add_cell(Vector3.ZERO, &"wood")
	field.wind = Vector3(8, 0, 0)
	field.ignite_at(Vector3.ZERO, 0.1)
	_run(4.0)
	assert_true(field.is_burning(down) or field.is_burnt(down), "downwind 2.4 m catches")
	assert_false(field.is_burning(up) or field.is_burnt(up), "upwind 2.4 m does not")


func test_materials_never_change_each_other() -> void:
	var stone := field.add_cell(Vector3.ZERO, &"stone")
	var grass := field.add_cell(Vector3(0.5, 0, 0), &"grass")
	assert_eq(field.ignite_at(Vector3.ZERO, 0.1), 0, "stone does not burn")
	_run(5.0)
	assert_false(field.is_burning(grass), "and nothing reaches the grass without a fire")
	assert_false(field.is_burning(stone))


func test_tracks_a_flammable_prop_and_its_wetness() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var crate := Prop.make(PropPlacements.prop_data(&"crate"))
	root.add_child(crate)
	crate.global_position = Vector3(5, 0, 0)
	var id := field.track_prop(crate)
	crate.global_position = Vector3(9, 0, 0)
	field.step(ElementField.TICK)
	assert_eq(field.cells_near(Vector3(9, 0, 0), 0.5).size(), 1, "the cell follows the crate")
	field.ignite_at(Vector3(9, 0, 0), 0.5)
	assert_gt(crate.burning, 0.0, "the crate shows it burns")
	crate.free()
	field.step(ElementField.TICK)
	assert_false(field.is_burning(id), "gone with the crate")


func test_overlay_toggles() -> void:
	field.add_cell(Vector3.ZERO, &"grass")
	assert_true(field.toggle_overlay())
	assert_false(field.toggle_overlay())
	assert_true(InputMap.has_action(ElementField.DEBUG_ACTION))
