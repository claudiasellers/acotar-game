extends GutTest
## Half two: the hook resets global state before each script, so nothing
## test_reset_a_leaks.gd left behind is visible here.

func test_starts_clean() -> void:
	var hud: HudLayout = get_tree().root.get_node_or_null("HudLayout") as HudLayout
	if hud != null:
		assert_false(hud.dread(), "no dread carried in")
		hud.free()
	assert_true(StoryControl.holders().is_empty(), "no hold carried in")
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL, "full control carried in")
