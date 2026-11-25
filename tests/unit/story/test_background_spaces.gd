## Contract (T150): the background moments that wait on deeds all act
## (manor_map, hall_mark_1..5; running from fact.alis_tripped, never finishing)
## are not "a scene is open". The game still saves and the dread sting still
## fires; a real scene that holds her controls still stops both.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SLOT := "gut_bg_spaces"

var root: Node3D
var director: SoundDirector


class FakePlacement:
	extends RefCounted

	func save_state() -> Dictionary:
		return {"position": [1.0, 2.0, 3.0]}

	func load_state(_d: Dictionary) -> void:
		pass


func before_each() -> void:
	WorldState.clear()
	Clock.paused = true
	StoryControl.release()
	PhaseManager.start(TEST_SET)
	SaveSystem.active_slot = SLOT
	SaveSystem.register_provider(SaveSystem.PLACEMENT_KEY, FakePlacement.new())
	root = Node3D.new()
	add_child_autofree(root)
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = false
	director = SoundDirector.new()
	add_child_autofree(director)
	WorldState.set_flag("fact.alis_tripped", true)


func after_each() -> void:
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = true
	SaveSystem.unregister_provider(SaveSystem.PLACEMENT_KEY)
	SaveSystem.active_slot = "slot_0"
	SaveSystem._autosave_due = false
	SaveSystem.delete_save(SLOT)
	StoryControl.release()
	Clock.paused = false


func _start_background() -> Array[MomentSpace]:
	var out: Array[MomentSpace] = []
	for id in ["manor_map", "hall_mark_1", "hall_mark_5"]:
		var space := MomentSpace.new()
		space.moment = load("res://data/story/moments/%s.tres" % id)
		space.auto_tick = false
		root.add_child(space)
		assert_true(space.start(), "%s runs from alis_tripped" % id)
		out.append(space)
	return out


func test_background_moments_do_not_block_a_save() -> void:
	var spaces := _start_background()
	assert_true(spaces[0].running, "they stay running")
	assert_true(SaveSystem.can_autosave(), "a save is still whole")


func test_background_moments_do_not_hush_the_dread_sting() -> void:
	_start_background()
	EventBus.mood_requested.emit(&"dread", 0.8, 0.05)
	assert_eq(int(director.played.get(&"horror_wrong", 0)), 1)


func test_a_scene_that_holds_her_controls_still_stops_both() -> void:
	var spaces := _start_background()
	StoryControl.hold(spaces[0], StoryControl.Mode.NONE)
	assert_false(SaveSystem.can_autosave())
	EventBus.mood_requested.emit(&"dread", 0.8, 0.05)
	assert_false(director.played.has(&"horror_wrong"), "a real scene brings its own horror")
