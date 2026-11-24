## The pause card's inner frame (L65): Kenney's border, tinted gold, pushed
## out towards the card's edge.
extends GutTest


func test_pause_card_has_its_inner_frame() -> void:
	var f := PauseStyle.inner_frame() as FramedStyleBox
	assert_not_null(f)
	assert_eq(f.frame.resource_path, UiBorders.CARD_FRAME)
	assert_eq(f.tint, PauseStyle.GOLD)
	assert_lt(f.inset, 0.0, "drawn out past the content area")


func test_frame_texture_is_white_art_with_room_for_its_corners() -> void:
	var tex := load(UiBorders.CARD_FRAME) as Texture2D
	assert_not_null(tex)
	assert_gt(tex.get_width(), UiBorders.PATCH_MARGIN * 2.0, "room for the 9-patch corners")
