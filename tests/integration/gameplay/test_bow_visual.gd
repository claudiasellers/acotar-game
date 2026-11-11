## The bow you can see: slung on her back, up in her hands to aim and draw,
## the string hand coming back to her chin, Q always answering with a card.
extends GutTest

const ArrowModel := preload("res://systems/bow/arrow_model.gd")

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
	var arrows := Gameplay.inventory.arrow_count(&"arrow_wood")
	Gameplay.inventory.remove(&"arrow_wood", arrows)
	Input.action_press(&"aim")
	await wait_seconds(0.5)
	assert_false(feyre.bow_controller.is_drawing, "no arrow, nothing to draw")
	var hand_at_rest := v.pose.string_hand_world()
	var grip := v.pose.bow_hand_world()
	var aim := v.aim_direction()
	assert_gt((grip - (feyre.global_position + Vector3.UP * 1.3)).dot(aim), 0.4, "the bow arm reaches down the aim")
	Gameplay.inventory.add(&"arrow_wood", arrows)
	await wait_seconds(1.5)
	assert_true(feyre.bow_controller.is_drawing)
	var head := feyre.global_position + Vector3.UP * 1.45
	var hand_drawn := v.pose.string_hand_world()
	assert_lt(hand_drawn.distance_to(head), hand_at_rest.distance_to(head) - 0.15, "the draw comes back toward her face")
	assert_lt(v.bow_root.global_position.distance_to(v.pose.bow_hand_world()), 0.2, "the bow is in her hand")
	watch_signals(feyre)
	var before := feyre.quiver
	_click()
	await wait_physics_frames(3)
	assert_signal_emitted(feyre, "arrow_fired")
	assert_eq(feyre.quiver, before - 1, "she loosed one arrow")
	await wait_seconds(0.4)
	assert_lt(_visual().raised, 0.1, "the bow comes down after the shot (T096)")
	Input.action_release(&"aim")


## A fire press and release, as events (the bow reads the press, not the hold).
func _click() -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = &"fire"
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()


## F43: every draw logged "det == 0" inverting a degenerate bow transform.
func test_ten_draws_log_no_errors() -> void:
	for k in 10:
		Input.action_press(&"aim")
		await wait_seconds(0.4)
		_click()
		await wait_physics_frames(2)
		Input.action_release(&"aim")
		await wait_physics_frames(6)
	assert_engine_error_count(0, "no invert errors while drawing")


func test_hand_basis_holds_up_aiming_straight_up_or_down() -> void:
	for dir: Vector3 in [Vector3.DOWN, Vector3.UP, Vector3(0, -1, 0.0001), Vector3.ZERO, Vector3.FORWARD]:
		var b := BowVisual.hand_basis(dir, Vector3.FORWARD)
		assert_almost_eq(absf(b.determinant()), 1.0, 0.001, "basis for %s" % dir)


## F44: arrows in flight, stuck arrows and the nocked arrow share ArrowModel,
## never a primitive mesh the grey-box guard would flag.
func test_arrows_use_the_arrow_model_not_primitives() -> void:
	for id: StringName in BowController.arrow_data():
		var arrow := Arrow.create(BowController.arrow_data()[id])
		var model := arrow.get_node_or_null(^"ArrowModel") as MeshInstance3D
		assert_not_null(model, "%s has an ArrowModel" % id)
		for child in arrow.get_children():
			if child is MeshInstance3D:
				assert_false((child as MeshInstance3D).mesh is PrimitiveMesh, "%s: %s" % [id, child.name])
		arrow.free()
	feyre.bow_controller.cycle_arrow()
	await wait_seconds(0.5)
	var nocked := _visual().arrow_node
	for child in nocked.get_children():
		if child is MeshInstance3D:
			assert_false((child as MeshInstance3D).mesh is PrimitiveMesh, "nocked %s" % child.name)
	var aabb := ArrowModel.mesh(0.83, 0.0, Color.WHITE, Color.WHITE, ArrowModel.STEEL).get_aabb()
	assert_almost_eq(aabb.position.z, -0.83, 0.01, "tip 0.83 down -Z from the nock")


## The bow broke when arrow_model.gd was a new global class the play folder's
## class cache hadn't picked up yet: arrow.gd failed to compile and she could
## not shoot. It is loaded by path, so a stale cache can't do that again.
func test_arrow_model_is_loaded_by_path_not_a_global_class() -> void:
	var src := FileAccess.get_file_as_string("res://systems/bow/arrow_model.gd")
	assert_false(src.contains("\nclass_name "), "arrow_model.gd declares no class_name")
