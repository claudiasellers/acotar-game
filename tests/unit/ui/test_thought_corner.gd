## Feyre's thoughts stand in the top left corner beside her bookmark, never in
## the lane where speech is (owner, 2026-11-24): one place for what she
## thinks, one for what is said, and a new thought is seen arriving.
extends GutTest

const V := LinePresenter.Voice
const PATH := "user://test_thought_corner.cfg"

var lines: LinePresenter
var _saved_path: String


func before_each() -> void:
	_saved_path = GameSettings.settings_path
	GameSettings.settings_path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameSettings.load_settings()
	lines = LinePresenter.of(get_tree())
	lines.clear()
	get_tree().paused = false
	await _settle()


func after_each() -> void:
	lines.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameSettings.settings_path = _saved_path
	GameSettings.load_settings()


func _settle() -> void:
	await get_tree().create_timer(LinePresenter.ARRIVE_SECONDS + 0.15).timeout


func test_a_thought_stands_beside_the_bookmark_and_keeps_to_its_corner() -> void:
	lines.say(V.THOUGHT, "", "Eight days of snow, and the doe is the first thing I have seen worth an arrow. If I miss, there is nothing for the pot tonight and nothing to sell tomorrow.", null, 30.0)
	await _settle()
	var view := get_viewport().get_visible_rect().size
	var slip := lines.stand_of(V.THOUGHT).get_global_rect()
	assert_almost_eq(slip.position.x, LinePresenter.CORNER.x, 1.0)
	assert_almost_eq(slip.position.y, LinePresenter.CORNER.y, 1.0, "level with the bookmark")
	assert_gt(slip.position.x, HudLayout.MARGIN + GuideJournal.TAB_WIDTH, "clear of the bookmark's tab")
	assert_lt(slip.end.x, view.x * 0.36, "clear of the notices at the top centre")
	assert_lt(slip.end.y, view.y * 0.3, "well above her")
	assert_eq(lines.stand_of(V.THOUGHT).text_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)


func test_a_thought_is_not_in_the_lane_so_the_strap_stays() -> void:
	lines.say(V.THOUGHT, "", "Bread. Think of bread.", null, 30.0)
	assert_false(lines.in_lane())
	assert_eq(lines.showing, "Bread. Think of bread.")
	assert_eq(lines.voice, V.THOUGHT)


func test_what_she_thinks_and_what_is_said_stand_together() -> void:
	lines.say(V.SAID, "Lucien", "Keep to the path.", null, 30.0)
	lines.say(V.THOUGHT, "", "He would say that.", null, 30.0)
	await _settle()
	assert_almost_eq(lines.stand_of(V.SAID).modulate.a, 1.0, 0.01, "his line is still up")
	assert_almost_eq(lines.stand_of(V.THOUGHT).modulate.a, 1.0, 0.01)
	assert_true(lines.in_lane())
	assert_eq(lines.showing, "He would say that.", "the newest words")
	lines.clear_voice(V.THOUGHT)
	assert_eq(lines.showing, "Keep to the path.", "then what is still up")
	assert_eq(lines.voice, V.SAID)


func test_a_new_thought_slides_out_and_inks_its_whorl() -> void:
	var stand := lines.stand_of(V.THOUGHT)
	var box := stand.get_parent() as Control
	lines.say(V.THOUGHT, "", "Last loaf's gone.", null, 30.0)
	assert_lt(box.offset_left, LinePresenter.CORNER.x, "it starts nearer the bookmark")
	assert_lt(stand.whorl.progress, 0.1, "its whorl not yet drawn")
	await _settle()
	assert_almost_eq(box.offset_left, LinePresenter.CORNER.x, 0.5)
	assert_almost_eq(stand.whorl.progress, 1.0, 0.01)
	lines.say(V.THOUGHT, "", "Last loaf's gone.", null, 30.0)
	assert_almost_eq(box.offset_left, LinePresenter.CORNER.x, 0.5, "the same thought again does not arrive twice")


func test_with_reduced_effects_it_only_fades_in() -> void:
	GameSettings.set_value(&"reduced_effects", true)
	var stand := lines.stand_of(V.THOUGHT)
	lines.say(V.THOUGHT, "", "Last loaf's gone.", null, 30.0)
	assert_almost_eq((stand.get_parent() as Control).offset_left, LinePresenter.CORNER.x, 0.5)
	assert_almost_eq(stand.whorl.progress, 1.0, 0.01)
