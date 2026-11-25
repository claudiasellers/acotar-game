## The mare's tending screen owns the click (docs/contracts/mare_bond.md,
## ui-frame.md): it doesn't pause the game, so the bow still ticks, but while
## it's on ScreenStack no shot is allowed (ScreenStack.takes_play, read by
## StoryControl.can_shoot). A click that brushes her looses no arrow; after
## she closes it, the same click shoots as ever. Drives the bow's own tick
## (update_bow) with fire held, as the brushing click holds it.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")
const TICK := 1.0 / 60.0

var hill: Node3D
var feyre: Feyre
var bow: BowController
var fired: Array[Arrow] = []


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	StoryControl.release()
	TimeScale.reset()
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	bow = feyre.bow_controller
	bow.set_physics_process(false)
	Gameplay.inventory.add(&"arrow_wood", 8)
	fired = []
	feyre.arrow_fired.connect(func(a: Arrow) -> void: fired.append(a))
	await wait_physics_frames(10)
	feyre.stamina = feyre.max_stamina


func after_each() -> void:
	StoryControl.release()
	TimeScale.reset()


## Holds fire for `seconds`, then lets go; returns the arrows loosed.
func _click(seconds: float) -> int:
	var before := fired.size()
	for i in roundi(seconds / TICK):
		bow.update_bow(TICK, false, true)
	for i in 6:
		bow.update_bow(TICK, false, false)
	return fired.size() - before


func test_a_click_while_tending_looses_no_arrow() -> void:
	var view := MareTendingView.open(hill, null, feyre, Gameplay.inventory)
	await wait_process_frames(2)
	assert_true(ScreenStack.has(view), "the tending screen is on the stack")
	assert_false(get_tree().paused, "tending doesn't pause: the bow still ticks")
	assert_true(ScreenStack.takes_play())
	assert_false(StoryControl.can_shoot(), "no shot while a screen is open")
	assert_eq(_click(bow.bow.draw_time + 0.3), 0, "the brushing click looses no arrow")
	assert_false(bow.is_aiming or bow.is_drawing, "the bow never came up")
	view.close()
	await wait_process_frames(2)
	assert_false(ScreenStack.takes_play())
	assert_eq(_click(bow.bow.draw_time + 0.3), 1, "closed, the same click shoots")


func test_tending_has_its_own_key_not_e() -> void:
	assert_true(InputMap.has_action(MountDirector.TEND_ACTION), "tend_mount is in the input map")
	var tend := InputSettings.signature(InputMap.action_get_events(MountDirector.TEND_ACTION)[0])
	for e in InputMap.action_get_events(&"interact"):
		assert_ne(InputSettings.signature(e), tend, "tending isn't on E")
	assert_eq(KeyHints.row(&"tend").size(), 1, "a key hint names it")
