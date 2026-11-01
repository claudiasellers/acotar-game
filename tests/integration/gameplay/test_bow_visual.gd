## The bow you can see: slung on her back, up in her hands to aim and draw,
## the string hand coming back to her chin, Q always answering with a card.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")

var hill: Node3D
var feyre: Feyre


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	StoryControl.release()
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	await wait_physics_frames(10)


func after_each() -> void:
	Input.action_release(&"aim")
	Input.action_release(&"fire")
	Engine.time_scale = 1.0


func _visual() -> BowVisual:
	return feyre.bow_controller.visual


func test_the_bow_is_on_her_back_while_she_walks() -> void:
	var v := _visual()
	assert_not_null(v, "Feyre carries a BowVisual")
	assert_not_null(v.pose, "her arms get a bow pose modifier")
	assert_almost_eq(v.raised, 0.0, 0.01)
	var back := -(feyre.model.global_basis.z)
	var to_bow := v.bow_root.global_position - (feyre.global_position + Vector3.UP * 1.2)
	assert_lt(to_bow.dot(back), 0.0, "the bow sits behind her")
	assert_lt(to_bow.length(), 0.5, "close against her back")
	assert_false(v.arrow_node.visible, "no arrow nocked while it's slung")


func test_q_raises_the_bow_and_shows_the_arrow_card() -> void:
	feyre.bow_controller.cycle_arrow()
	await wait_seconds(0.5)
	var v := _visual()
	assert_gt(v.raised, 0.9, "the bow comes up into her hands")
	assert_gt(v.pose.influence, 0.9)
	assert_true(v.arrow_node.visible, "an arrow is nocked")
	var card := feyre.bow_controller.quiver_card
	assert_string_contains(card.text, "Wood arrow")
	assert_string_contains(card.text, "×%d" % feyre.quiver)


func test_aiming_and_drawing_bring_the_string_hand_to_her_chin() -> void:
	var v := _visual()
	Input.action_press(&"aim")
	await wait_seconds(0.5)
	var hand_at_rest := v.pose.string_hand_world()
	var grip := v.pose.bow_hand_world()
	var aim := v.aim_direction()
	assert_gt((grip - (feyre.global_position + Vector3.UP * 1.3)).dot(aim), 0.4, "the bow arm reaches down the aim")
	Input.action_press(&"fire")
	await wait_seconds(1.5)
	assert_true(feyre.bow_controller.is_drawing)
	var head := feyre.global_position + Vector3.UP * 1.45
	var hand_drawn := v.pose.string_hand_world()
	assert_lt(hand_drawn.distance_to(head), hand_at_rest.distance_to(head) - 0.15, "the draw comes back toward her face")
	assert_lt(v.bow_root.global_position.distance_to(v.pose.bow_hand_world()), 0.2, "the bow is in her hand")
	watch_signals(feyre)
	var before := feyre.quiver
	Input.action_release(&"fire")
	await wait_physics_frames(3)
	assert_signal_emitted(feyre, "arrow_fired")
	assert_eq(feyre.quiver, before - 1, "she loosed one arrow")
	Input.action_release(&"aim")
	await wait_seconds(0.4)
	assert_gt(_visual().raised, 0.9, "the bow stays up a moment after the shot")
