## Audit B9: a roof's eaves never reach into a room. The main block's gables
## overhung 0.4 m into the corner towers' top rooms (the observatory and the
## rose bower), a lilac slab through their floor and wall. Eaves now stop
## wherever the house goes on at the roof's height.
extends GutTest

var _all: ManorHouseIndex


func before_all() -> void:
	_all = ManorHouseIndex.new(ManorHouseBuilder.load_layouts())


func _footprint(roof: ManorRoofDef) -> Rect2:
	var o := ManorHouseBuilder.roof_overhang(roof, _all)
	var r := roof.rect
	return Rect2(r.position - Vector2(o[0], o[2]), r.size + Vector2(o[0] + o[1], o[2] + o[3]))


func test_no_roof_reaches_into_a_room() -> void:
	var bad := []
	var pitched := 0
	for roof in _all.roofs:
		if roof.style in [&"cone", &"dome", &"flat"]:
			continue
		pitched += 1
		var fp := _footprint(roof)
		for room in _all.rooms:
			if not ManorHouseIndex.occupies(room, roof.base_level + 1):
				continue
			var cut := fp.intersection(room.rect.grow(-ManorHouseBuilder.WALL))
			if cut.get_area() > 0.01:
				bad.append("%s roof %s cuts %s L%d by %.2f x %.2f m" % [roof.style, roof.rect, room.id, room.level, cut.size.x, cut.size.y])
	assert_gt(pitched, 2)
	assert_eq(bad.size(), 0, "\n".join(bad))


func test_open_sides_keep_their_eaves() -> void:
	var main: ManorRoofDef = null
	for roof in _all.roofs:
		if roof.style == &"gable_x":
			main = roof
	assert_not_null(main)
	var o := ManorHouseBuilder.roof_overhang(main, _all)
	assert_eq(o[2], ManorHouseBuilder.EAVES, "the north eaves over the garden front")
	assert_eq(o[3], ManorHouseBuilder.EAVES, "the south eaves over the drive")
