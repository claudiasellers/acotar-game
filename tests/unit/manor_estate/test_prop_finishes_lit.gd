extends GutTest
# gate: when:world/shared/shaders/candy_lit*,world/spring_court/manor_estate/props/*
## Contract for the manor's furniture finishes (L92; owner, 2026-11-25: the
## furniture looked waxy and self-lit). A prop is lit by the room and nothing
## else: a lamp's rim falls off with the lamp, painted wood, cloth, stone and
## china carry no clearcoat and no rim, no lit finish goes over the albedo cap,
## and only flames and faelights emit. Read from the shader source (headless
## has no shader compiler).

const CANDY_LIT := "res://world/shared/shaders/candy_lit.gdshaderinc"
const FINISH := "res://world/spring_court/manor_estate/props/prop_finish.gdshaderinc"
const GLASS := 5
const GLOW := 7


func _finish_lines() -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("finish == (\\d+)\\) \\{([^}]*)\\}")
	for m in re.search_all(FileAccess.get_file_as_string(FINISH)):
		out[int(m.get_string(1))] = m.get_string(2)
	return out


func test_a_lamps_rim_reaches_only_as_far_as_the_lamp() -> void:
	var code := FileAccess.get_file_as_string(CANDY_LIT)
	var at := code.find("if (v_rim > 0.0)")
	assert_gt(at, 0, "the light rim lobe")
	var lobe := code.substr(at, code.find("}", at) - at)
	assert_true(lobe.contains("* LIGHT_COLOR * ATTENUATION;"), "the rim is attenuated and shadowed like its light")


func test_only_glass_is_glossy_and_only_flames_emit() -> void:
	var lines := _finish_lines()
	assert_eq(lines.size(), 10, "the ten finishes of tools/blender/prop_kit.py")
	for i: int in lines:
		var line: String = lines[i]
		if i != GLASS:
			assert_false(line.contains("coat"), "finish %d has no clearcoat" % i)
			assert_false(line.contains("rim"), "finish %d has no rim" % i)
		assert_eq(line.contains("emit"), i == GLOW, "finish %d: only flames and faelights emit" % i)
	var re := RegEx.create_from_string("rough = ([0-9.]+)")
	for i in [0, 1, 2, 3, 4, 9]:
		assert_gte(re.search(lines[i]).get_string(1).to_float(), 0.4, "finish %d is matte to satin" % i)


func test_lit_finishes_hold_the_albedo_cap() -> void:
	var code := FileAccess.get_file_as_string(FINISH)
	assert_true(code.contains("const float ALBEDO_CAP = %s;" % CandyMaterial.MAX_ALBEDO), "the candy cap")
	assert_true(code.contains("ALBEDO = finish == 7 ? c : min(c, vec3(ALBEDO_CAP));"), "every lit finish is capped")


func test_procedural_props_wear_the_same_finishes() -> void:
	var c := Color(0.66, 0.93, 0.80)
	for m: CandyMaterial in [PropMats.gold(), PropMats.pearl(), PropMats.gloss(c), PropMats.satin(c),
			PropMats.fabric(c), PropMats.wood(c), PropMats.metal(c), PropMats.body(c), PropMats.book(0)]:
		assert_false(m.clearcoat_enabled, "no clearcoat")
		assert_false(m.rim_enabled, "no rim")
		assert_false(m.emission_enabled, "no light of its own")
		assert_gte(m.roughness, 0.4, "matte to satin")
	assert_false(PropMats.crystal().emission_enabled, "crystal catches the candles; it doesn't glow")
	assert_true(PropMats.flame().emission_enabled, "a flame is a light source")
