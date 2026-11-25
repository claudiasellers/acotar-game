## T149 contract: an arrow that has landed in open ground beside Feyre shows
## the use prompt and E pulls it (count up, glimmer gone); a full quiver says so.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")

var hill: Node3D
var feyre: Feyre


func before_each() -> void:
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)  # no dread left by an earlier test: it holds the log
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	feyre.set_physics_process(false)
	await wait_physics_frames(5)


## A real shot into the ground a metre or so ahead of her.
func _land() -> Arrow:
	var arrow := Arrow.create(load("res://data/arrows/wood.tres"))
	hill.add_child(arrow)
	var at := feyre.global_position + Vector3(1.0, 0, 0)
	var space := hill.get_world_3d().direct_space_state
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 5.0, at + Vector3.DOWN * 50.0))
	assert_false(ground.is_empty(), "there is ground to land on")
	arrow.launch(ground.position + Vector3.UP * 3.0, Vector3.DOWN, 20.0)
	await wait_physics_frames(30)
	return arrow


func test_landed_arrow_shows_prompt_and_e_picks_it_up() -> void:
	var arrow := await _land()
	assert_true(arrow.is_in_group(Arrow.STUCK_GROUP), "it landed")
	assert_not_null(ArrowGlimmer.of(arrow), "it glimmers")
	var before := Gameplay.inventory.arrow_count()
	feyre.global_position = arrow.global_position + Vector3(0.8, 0, 0)
	assert_eq(String(feyre.interactor.target().get("verb", "")), "pull the arrow")
	await wait_seconds(Interactor.PROMPT_REFRESH + 0.3)
	assert_ne(UsePrompt.of(get_tree()).offered(), [], "the E prompt is up")
	var e := InputEventAction.new()
	e.action = &"interact"
	e.pressed = true
	Input.parse_input_event(e)
	await wait_process_frames(2)
	assert_eq(Gameplay.inventory.arrow_count(), before + 1, "E took it")
	assert_false(is_instance_valid(arrow) and not arrow.is_queued_for_deletion())
	await wait_process_frames(2)
	assert_eq(get_tree().get_nodes_in_group(ArrowGlimmer.GROUP).size(), 0, "glimmer gone")


func test_full_quiver_still_shows_the_prompt_and_says_so() -> void:
	Gameplay.inventory.quiver_size = 10
	var arrow := await _land()
	while Gameplay.inventory.add(&"arrow_wood", 1) > 0:
		pass
	feyre.global_position = arrow.global_position + Vector3(0.8, 0, 0)
	await wait_seconds(Interactor.PROMPT_REFRESH + 0.3)
	assert_eq(UsePrompt.of(get_tree()).offered(), [Interactor.FULL_QUIVER_VERB, &"interact"], "the prompt says why")
	assert_true(feyre.interactor.interact(), "E answers")
	assert_true(arrow.is_in_group(Arrow.STUCK_GROUP), "the arrow stays")
	assert_has(Array(PickupLog.of(get_tree()).lines()), Interactor.NO_ROOM_LINES[Inventory.QUIVER])
	Gameplay.inventory.remove(&"arrow_wood", Gameplay.inventory.arrow_count())
	await wait_seconds(Interactor.PROMPT_REFRESH + 0.3)
	assert_eq(String(feyre.interactor.target().verb), "pull the arrow", "room again, and it can be pulled")
