extends GutTest
## Lane L67: the opening film's land map carries Kenney's Cartography Pack
## (CC0) as gold-ink icons, laid out by tools/film/gen_mural_map_detail.py
## and drawn in by mural_map.gdshader. Contract: docs/contracts/film.md.

const MANIFEST := "res://art/film/mural/cartography/map_detail.json"
const WALL_V := 0.38


func _manifest() -> Dictionary:
	var f := FileAccess.open(MANIFEST, FileAccess.READ)
	assert_not_null(f, MANIFEST)
	return JSON.parse_string(f.get_as_text()) as Dictionary


func test_the_detail_texture_is_small_and_square() -> void:
	var tex := load(MuralStage.MAP_DETAIL) as Texture2D
	assert_not_null(tex, MuralStage.MAP_DETAIL)
	assert_eq(tex.get_width(), 2048)
	assert_eq(tex.get_height(), 2048)
	var bytes := FileAccess.get_file_as_bytes(MuralStage.MAP_DETAIL).size()
	assert_lt(bytes, 600 * 1024, "R15: the detail texture stays small")


func test_the_map_is_dense_enough_to_read_as_a_map() -> void:
	var counts: Dictionary = _manifest().counts
	assert_gte(int(counts.get("mountain", 0)), 8)
	assert_gte(int(counts.get("forest", 0)), 15)
	assert_gte(int(counts.get("wave", 0)), 8)
	assert_eq(int(counts.get("compass", 0)), 1)
	assert_eq(int(counts.get("cartouche", 0)), 1)
	# Before the War the fae held the whole island: palaces and temples
	# stand south of the Wall too (Keeper, ch 3 and ch 13).
	var south_fae := 0
	for p: Dictionary in _manifest().placements:
		if p.category in ["palace", "temple"] and float(p.y) < WALL_V:
			south_fae += 1
	assert_gte(south_fae, 2)


func test_land_icons_stay_on_land_and_sea_icons_at_sea() -> void:
	for p: Dictionary in _manifest().placements:
		var land: bool = p.land
		var at_sea: bool = p.category in ["wave", "compass", "cartouche"]
		assert_eq(land, not at_sea, "%s %s" % [p.zone, p.category])
		# Nothing human on the pre-War map, and nothing sits on the Wall's line.
		assert_false(String(p.sprite).begins_with("house"), p.sprite)
		if land:
			var y0 := float(p.y)
			var y1 := y0 + float(p.h)
			assert_false(y0 < WALL_V and WALL_V < y1, "%s straddles the Wall" % p.zone)


func test_the_land_map_starts_blank_and_takes_the_texture() -> void:
	var stage := MuralStage.new()
	stage.build_only = [&"land"]
	add_child_autofree(stage)
	var m := stage.land_material()
	assert_eq(float(m.get_shader_parameter(&"detail")), 0.0, "icons draw in, never pop")
	assert_not_null(m.get_shader_parameter(&"detail_tex"))
	var names: Array[StringName] = []
	for u in m.shader.get_shader_uniform_list():
		names.append(StringName(u.name))
	for want: StringName in [&"draw", &"fill", &"detail", &"detail_tex", &"split", &"wash"]:
		assert_has(names, want)
