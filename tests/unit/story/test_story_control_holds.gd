## Contract: StoryControl holds belong to their owners. A scene freed mid-run
## (a save loading, its region streaming out) never leaves Feyre's controls
## narrowed; one hold letting go keeps another's restriction; a load or a new
## story starts in full control and calm.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SLOT := "gut_story_control"


class Held:
	extends SceneSpace

	func _build_beats() -> Array:
		return [
			Beats.control(StoryControl.Mode.LOOK, self),
			Beats.wait(10.0),
		]


var _moods: Array = []


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	_moods.clear()


func after_each() -> void:
	if EventBus.mood_requested.is_connected(_on_mood):
		EventBus.mood_requested.disconnect(_on_mood)
	SaveSystem.delete_save(SLOT)
	SaveSystem.active_slot = "slot_0"
	SaveSystem._loading = {}
	StoryControl.release()


func _on_mood(mood: StringName, intensity: float, _seconds: float) -> void:
	_moods.append([mood, intensity])


func test_a_scene_freed_mid_run_leaves_control_full() -> void:
	var space := Held.new()
	space.auto_tick = false
	space.space_id = &"held"
	add_child(space)
	assert_true(space.start())
	space.tick(1.0)
	assert_true(space.running)
	assert_eq(StoryControl.mode, StoryControl.Mode.LOOK)
	space.free()
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL, "the freed scene's hold went with it")
	assert_true(StoryControl.can_move())
	assert_null(StoryControl.focus)


func test_a_freed_owner_outside_the_tree_is_dropped_on_read() -> void:
	var holder := Node.new()
	StoryControl.hold(holder, StoryControl.Mode.NONE)
	assert_eq(StoryControl.mode, StoryControl.Mode.NONE)
	holder.free()
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL)


func test_releasing_one_hold_keeps_the_other() -> void:
	var a := Node.new()
	var b := Node.new()
	add_child_autofree(a)
	add_child_autofree(b)
	StoryControl.hold(a, StoryControl.Mode.LOOK)
	StoryControl.hold(b, StoryControl.Mode.WALK, PackedStringArray(["interact"]))
	assert_eq(StoryControl.mode, StoryControl.Mode.LOOK, "the most restrictive hold wins")
	assert_false(StoryControl.can_interact())
	StoryControl.release(b)
	assert_eq(StoryControl.mode, StoryControl.Mode.LOOK, "a's restriction stays")
	StoryControl.hold(b, StoryControl.Mode.WALK, PackedStringArray(["interact"]))
	StoryControl.release(a)
	assert_eq(StoryControl.mode, StoryControl.Mode.WALK)
	assert_true(StoryControl.can_interact(), "b's allowed actions apply once it sets the mode")
	StoryControl.release(b)
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL)


func test_load_game_resets_to_full_and_calm() -> void:
	PhaseManager.start(TEST_SET)
	SaveSystem.active_slot = SLOT
	assert_eq(SaveSystem.save_game(SLOT), OK)
	StoryControl.set_mode(StoryControl.Mode.NONE)
	EventBus.mood_requested.connect(_on_mood)
	assert_eq(SaveSystem.load_game(SLOT), OK)
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL)
	assert_true(_moods.has([&"calm", 0.0]), "the load sends calm")
