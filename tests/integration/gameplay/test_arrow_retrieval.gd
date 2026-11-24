## Bow design §8.3: one press pulls every arrow out of a body, a full quiver
## stops it and says so, and a steeped arrow comes back plain with a line in
## the pickup log. A bigger quiver arrives with the phase that brings it.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")
const FIRE: ArrowData = preload("res://data/arrows/fire.tres")

var hill: Node3D
var feyre: Feyre


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	feyre.set_physics_process(false)
	feyre.global_position = Vector3(400.0, 80.0, 400.0)
	Gameplay.inventory.remove(&"arrow_wood", 999)
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	await wait_physics_frames(5)
	PickupLog.of(get_tree()).clear()
	await wait_process_frames(1)


func _carcass() -> Harvestable:
	var carcass := Harvestable.new()
	carcass.setup(&"hare", &"animal", [{"item_id": &"ing_snowdrop", "qty": 1}] as Array[Dictionary])
	hill.add_child(carcass)
	carcass.global_position = feyre.global_position + Vector3(1, 0, 0)
	return carcass


func _stuck(parent: Node3D, data: ArrowData = null, offset := Vector3(0, 0.2, 0)) -> Arrow:
	var arrow := Arrow.create(data)
	parent.add_child(arrow)
	arrow.position = offset
	arrow.add_to_group(Arrow.STUCK_GROUP)
	return arrow


func test_one_press_pulls_every_arrow_from_the_body() -> void:
	var body := _carcass()
	for i in 3:
		_stuck(body, null, Vector3(0, 0.2 + 0.1 * i, 0))
	var elsewhere := _stuck(hill)
	elsewhere.global_position = feyre.global_position + Vector3(-2, 0.2, 0)
	assert_eq(feyre.interactor.target().kind, &"arrow")
	assert_true(feyre.interactor.interact())
	assert_eq(Gameplay.inventory.count(&"arrow_wood"), 3, "all three from the body, in one press")
	assert_true(elsewhere.is_in_group(Arrow.STUCK_GROUP), "an arrow in the ground is its own press")
	assert_false(body.is_harvested, "pulling arrows doesn't skin it")


func test_a_full_quiver_stops_the_pull_and_says_so() -> void:
	Gameplay.inventory.quiver_size = 10
	Gameplay.inventory.add(&"arrow_wood", 8)
	var body := _carcass()
	var arrows: Array[Arrow] = []
	for i in 4:
		arrows.append(_stuck(body, null, Vector3(0, 0.2 + 0.1 * i, 0)))
	assert_true(feyre.interactor.interact())
	assert_eq(Gameplay.inventory.count(&"arrow_wood"), 10)
	var left := arrows.filter(func(a: Arrow) -> bool: return a.is_in_group(Arrow.STUCK_GROUP))
	assert_eq(left.size(), 2, "the rest stay in the body")
	await wait_process_frames(2)
	assert_has(Array(PickupLog.of(get_tree()).lines()), Interactor.NO_ROOM_LINES[Inventory.QUIVER])


func test_a_steeped_arrow_comes_back_plain_and_the_log_says_why() -> void:
	var arrow := _stuck(hill, FIRE)
	arrow.global_position = feyre.global_position + Vector3(1, 0.2, 0)
	assert_eq(feyre.interactor.target().item, &"arrow_wood")
	assert_true(feyre.interactor.interact())
	assert_eq(Gameplay.inventory.count(&"arrow_wood"), 1)
	assert_eq(Gameplay.inventory.count(FIRE.item_id), 0)
	await wait_process_frames(2)
	assert_has(Array(PickupLog.of(get_tree()).lines()), Interactor.SPENT_LINE)


func test_a_plain_arrow_says_nothing_about_steeping() -> void:
	var arrow := _stuck(hill)
	arrow.global_position = feyre.global_position + Vector3(1, 0.2, 0)
	assert_true(feyre.interactor.interact())
	await wait_process_frames(2)
	assert_does_not_have(Array(PickupLog.of(get_tree()).lines()), Interactor.SPENT_LINE)


func test_a_new_phase_brings_its_quiver_and_the_log_names_it() -> void:
	Gameplay.inventory.quiver_size = 3
	EventBus.phase_changed.emit(&"p1_wolf_and_crossing", &"p2_grounds")
	assert_eq(Gameplay.inventory.quiver_size, 10)
	await wait_process_frames(2)
	assert_has(Array(PickupLog.of(get_tree()).lines()), QuiverCard.GREW_LINE % 10)
	EventBus.phase_changed.emit(&"p2_grounds", &"p1_wolf_and_crossing")
	assert_eq(Gameplay.inventory.quiver_size, 10, "going back never shrinks it")
