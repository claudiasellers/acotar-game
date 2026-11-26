extends GutTest
## Contract of tests/fixtures/reset_hook.gd, half one: leaks dread and a
## StoryControl hold on purpose (no calm, no release) and leaves its HudLayout
## in the tree for test_reset_b_clean.gd to find. Runs before
## test_reset_b_clean.gd, which must still start clean.

var _hud: HudLayout


func before_all() -> void:
	_hud = HudLayout.new()
	get_tree().root.add_child(_hud)


func test_leaks_dread_and_a_hold() -> void:
	EventBus.mood_changed.emit(&"dread", 1.0, 0.0)
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	assert_true(_hud.dread(), "the leak is real")
