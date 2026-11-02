extends GutTest
## The Thornwater's water (CourtHeight.river_level_at) sits in its carved bed
## along the whole river, whichever provider owns the ground there. Reads the
## height field only, so it needs no bake.

const STEP := 150.0
const MIN_DEPTH := 0.3   # metres of water over the bed
const MAX_DEPTH := 0.8
const BANK_OFFSET := MacroHeight.RIVER_HALF_WIDTH + MacroHeight.RIVER_BANK


func _centreline() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var pts := MacroHeight.THORNWATER
	for i in pts.size() - 1:
		var n := maxi(1, int(pts[i].distance_to(pts[i + 1]) / STEP))
		for s in n:
			out.append(pts[i].lerp(pts[i + 1], float(s) / n))
	return out


func test_water_stands_a_set_depth_over_the_bed_all_along() -> void:
	WorldHeight.warm_up()
	for p in _centreline():
		var over := CourtHeight.river_level_at(p.x, p.y) - WorldHeight.height_at(p.x, p.y)
		assert_between(over, MIN_DEPTH, MAX_DEPTH, "water %.2f m over the bed at %s" % [over, p])


func test_water_is_level_across_the_channel() -> void:
	var pts := MacroHeight.THORNWATER
	for i in pts.size() - 1:
		var n := (pts[i + 1] - pts[i]).normalized().orthogonal()
		var p := pts[i].lerp(pts[i + 1], 0.5)
		assert_almost_eq(CourtHeight.river_level_at(p.x + n.x * 4.0, p.y + n.y * 4.0), CourtHeight.river_level_at(p.x, p.y), 0.3, "tilted across the channel near %s" % p)


func test_water_is_below_the_banks() -> void:
	WorldHeight.warm_up()
	var pts := MacroHeight.THORNWATER
	for i in pts.size() - 1:
		var n := (pts[i + 1] - pts[i]).normalized().orthogonal()
		for s in int(pts[i].distance_to(pts[i + 1]) / STEP):
			var p := pts[i].lerp(pts[i + 1], float(s * STEP) / pts[i].distance_to(pts[i + 1]))
			var water := CourtHeight.river_level_at(p.x, p.y)
			var a := p + n * BANK_OFFSET
			var b := p - n * BANK_OFFSET
			var ha := WorldHeight.height_at(a.x, a.y)
			var hb := WorldHeight.height_at(b.x, b.y)
			assert_lt(water, maxf(ha, hb), "water over both banks at %s" % p)
			if absf(ha - hb) < 1.0:
				assert_lt(water, minf(ha, hb), "water over a level bank at %s" % p)


func test_lantern_bridge_folk_stand_on_the_bank() -> void:
	WorldHeight.warm_up()
	var roster := load("res://data/dialogue/presence.tres") as PresenceRoster
	var found := 0
	for spot in roster.spots:
		if spot.id != &"fae_stag_lantern_bridge" and spot.id != &"fae_nymph_lantern_bridge":
			continue
		found += 1
		var clear := MacroHeight.RIVER_HALF_WIDTH + 3.0 + spot.wander
		assert_gt(MacroHeight.distance_to_river(spot.at.x, spot.at.y), clear, "%s wanders into the water" % spot.id)
		assert_gt(WorldHeight.height_at(spot.at.x, spot.at.y), CourtHeight.river_level_at(spot.at.x, spot.at.y), "%s stands under the water" % spot.id)
	assert_eq(found, 2)
