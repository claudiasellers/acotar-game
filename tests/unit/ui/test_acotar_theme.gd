extends GutTest
## Contract: the shared theme exposes every variation the UI lanes style against.

const NAMES := [
	&"SatchelCard", &"SatchelDetail", &"SatchelTab", &"SatchelSlot", &"SatchelHeading",
	&"SatchelBody", &"SatchelSmall", &"SatchelCount", &"SatchelMeter", &"QuickBarSlot",
	&"QuickBarSlotSelected", &"QuickBarKey", &"QuickBarCount",
]


func test_both_act_themes_have_every_variation() -> void:
	for path in ["res://ui/theme/acotar_theme.tres", "res://ui/theme/acotar_theme_human.tres"]:
		var t := load(path) as Theme
		assert_not_null(t, path)
		for n: StringName in NAMES:
			assert_ne(t.get_type_variation_base(n), &"", "%s missing %s" % [path, n])
		for col in [&"ink", &"accent", &"glow", &"rare"]:
			assert_true(t.has_color(col, &"Satchel"), "%s missing Satchel/%s" % [path, col])


func test_body_font_is_eb_garamond() -> void:
	var t := load("res://ui/theme/acotar_theme.tres") as Theme
	assert_string_contains(t.default_font.resource_path, "EBGaramond")
