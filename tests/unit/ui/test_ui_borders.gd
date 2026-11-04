extends GutTest
## Contract (L65): the menus' main panels wear Kenney's frames through the
## shared theme, tinted from the palette, without crowding their contents.


func test_satchel_theme_frames_the_page_panel_over_the_crafted_paper() -> void:
	var t := SatchelTheme.theme()
	var box := t.get_stylebox(&"panel", &"SatchelDetail")
	assert_true(box is FramedStyleBox, "SatchelDetail is framed")
	var f := box as FramedStyleBox
	assert_true(f.base is StyleBoxTexture, "the crafted paper stays underneath")
	assert_not_null(f.frame)
	assert_eq(f.tint, t.get_color(&"line", &"Satchel"), "tinted from the palette's line")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_gte(f.get_content_margin(side), f.inset + 6.0, "contents clear the frame line")
		assert_gte(f.get_content_margin(side), f.base.get_content_margin(side), "the paper's own margins hold")


func test_dress_is_idempotent() -> void:
	var t := SatchelTheme.theme().duplicate() as Theme
	var before := t.get_stylebox(&"panel", &"SatchelDetail")
	UiBorders.dress(t, Color.WHITE)
	assert_same(t.get_stylebox(&"panel", &"SatchelDetail"), before, "no frame inside a frame")


func test_pause_card_inner_frame_is_a_kenney_border() -> void:
	var f := PauseStyle.inner_frame() as FramedStyleBox
	assert_not_null(f)
	assert_eq(f.frame.resource_path, UiBorders.CARD_FRAME)
	assert_lt(f.inset, 0.0, "pushed out towards the card edge")


func test_frame_textures_are_small_and_square() -> void:
	for path in [UiBorders.PAGE_FRAME, UiBorders.CARD_FRAME]:
		var tex := load(path) as Texture2D
		assert_not_null(tex, path)
		assert_lte(tex.get_width(), 256, path)
		assert_eq(tex.get_width(), tex.get_height(), path)
		assert_gt(tex.get_width(), UiBorders.PATCH_MARGIN * 2.0, "room for the 9-patch corners")
		assert_lt(FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(path)).size(), 64 * 1024, path)
