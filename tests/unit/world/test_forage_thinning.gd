extends GutTest
## ForageThinning: the owner's "in between" density for the human realm.


func _layer(id: StringName, ingredient: StringName, points: Array) -> ScatterLayer:
	var l := ScatterLayer.new()
	l.id = id
	l.ingredient_id = ingredient
	l.tags = PackedStringArray(["canon:X"])
	for p: Vector2 in points:
		l.add(Vector3(p.x, 0.0, p.y), 0.0, 1.0)
	return l


func test_a_fifth_stays_pickable_and_the_rest_is_dressing() -> void:
	var pts := []
	for i in 50:
		pts.append(Vector2(10.0 + i, 10.0))
	var rock := _layer(&"rock", &"", pts)
	var out := ForageThinning.split([_layer(&"ing_flint", &"ing_flint", pts), rock] as Array[ScatterLayer], Rect2(0, 0, 100, 100))
	assert_eq(out.size(), 3)
	var dressing: ScatterLayer = out[0]
	var find: ScatterLayer = out[2]
	assert_false(dressing.is_forage())
	assert_eq(find.id, &"ing_flint_find")
	assert_eq(find.ingredient_id, &"ing_flint")
	assert_eq(find.count(), 10)
	assert_eq(dressing.count() + find.count(), 50, "nothing lost from the scenery")
	assert_eq(rock.count(), 50, "non-forage layers untouched")


func test_every_cell_that_had_a_find_keeps_one() -> void:
	# Every fifth (indices 0 and 5) lands in cell (0,0); cell (1,0) holds 1..4
	# and gets one back.
	var pts := [Vector2(5, 5), Vector2(150, 5), Vector2(151, 5), Vector2(152, 5), Vector2(153, 5), Vector2(6, 5)]
	var out := ForageThinning.split([_layer(&"ing_snail_shell", &"ing_snail_shell", pts)] as Array[ScatterLayer], Rect2(0, 0, 200, 100))
	var r := ScatterReport.compute(out, Rect2(0, 0, 200, 100), 0, 0)
	assert_eq(int(r.empty_cells), 0)
	assert_eq((out[1] as ScatterLayer).count(), 3)
