## The walk up the drive: flower borders both sides from the gate to the
## forecourt, forage among them, and the drive in its own gravel shader.
extends GutTest


func test_borders_line_both_sides_with_finds() -> void:
	var sb := ManorScatter.new()
	ManorForecourt.plant_borders(sb)
	var edge := ManorSitePlan.DRIVE_WIDTH * 0.5
	var per_side := {-1: 0, 1: 0}
	var finds := 0
	var longest_gap := 0.0
	var zs: Array[float] = []
	for id: StringName in sb.layers:
		var l: ScatterLayer = sb.layers[id]
		for i in l.count():
			var p := l.position_of(i)
			assert_between(absf(p.x), edge, edge + 3.5, "%s stays in the border strip" % id)
			assert_false(ManorSitePlan.is_on_path(p.x, p.z), "nothing on the gravel")
			per_side[int(signf(p.x))] += 1
			if l.is_forage():
				finds += 1
			elif p.x < 0.0:
				zs.append(p.z)
	zs.sort()
	for k in zs.size() - 1:
		longest_gap = maxf(longest_gap, zs[k + 1] - zs[k])
	assert_gt(per_side[-1], 250)
	assert_gt(per_side[1], 250)
	assert_gt(finds, 60, "something to gather every few steps")
	assert_lt(longest_gap, 4.0, "no bare stretch along the drive")


func test_drive_is_textured_gravel() -> void:
	var m := ManorForecourt.drive_gravel() as ShaderMaterial
	assert_not_null(m)
	assert_eq(m.shader.resource_path, "res://world/spring_court/manor_estate/grounds/drive_gravel.gdshader")
