extends GutTest
## Contract: the dressing room uses the manor palette in EB Garamond, with no soft glows.


func test_fonts_are_eb_garamond() -> void:
	assert_string_contains(DressingStyle.BODY.resource_path, "EBGaramond")
	assert_string_contains(DressingStyle.caps_font(3).base_font.resource_path, "EBGaramond")


func test_boxes_have_no_glow() -> void:
	for b: StyleBoxFlat in [DressingStyle.sheet(), DressingStyle.card(true), DressingStyle.card(false), DressingStyle.swatch(Color.RED, true, true)]:
		assert_eq(b.shadow_size, 0)


func test_worn_swatch_has_gilt_rim() -> void:
	assert_eq(DressingStyle.swatch(Color.RED, false, true).border_color, DressingStyle.GILT_DEEP)
