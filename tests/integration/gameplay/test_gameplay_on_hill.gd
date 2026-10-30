## Gameplay systems in the real test hill with the real Feyre.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")

var hill: Node3D
var feyre: Feyre


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	await wait_physics_frames(10)


func after_each() -> void:
	Engine.time_scale = 1.0


func test_feyre_has_her_components_and_arrows() -> void:
	assert_not_null(feyre.bow_controller)
	assert_not_null(feyre.body_state)
	assert_not_null(feyre.element_state)
	assert_eq(feyre.quiver, feyre.starting_arrows)
	assert_eq(Gameplay.wardrobe.equipped_in(&"top"), &"hunter_tunic")


func test_interact_picks_forage_and_it_respawns() -> void:
	var field := hill.get_node("GameplaySandbox/Forage_ing_snowdrop") as ForageScatter
	var spot := field.multimesh.get_instance_transform(0).origin
	feyre.global_position = field.global_transform * spot
	assert_true(feyre.interactor.interact())
	assert_gte(Gameplay.inventory.count(&"ing_snowdrop"), 1)
	var picked_key := ""
	for i in field.multimesh.instance_count:
		if Gameplay.forage.is_picked(&"test_hill", "%s:%d" % [field.name, i]):
			picked_key = "%d" % i
	assert_ne(picked_key, "", "one instance is marked picked")
	Clock.advance(Clock.DAY_LENGTH_SECONDS * 5.0)
	field.refresh()
	assert_false(Gameplay.forage.is_picked(&"test_hill", "%s:%s" % [field.name, picked_key]))


func test_campfire_cooks_and_warms() -> void:
	var fire := hill.get_node("GameplaySandbox/Campfire") as CookingStation
	assert_gt(fire.heat_at(fire.global_position + Vector3(1, 0, 0)), 0.5)
	Gameplay.inventory.add(&"ing_pine_needles")
	var r := fire.cook([&"ing_pine_needles"] as Array[StringName], &"infuse")
	assert_true(r.ok, String(r.get("reason", "")))
	assert_true(r.first_time)
	assert_eq(Gameplay.inventory.dishes.size(), 1)
	assert_eq(Gameplay.inventory.count(&"ing_pine_needles"), 0)
	assert_false(fire.cook([&"ing_pine_needles"] as Array[StringName], &"infuse").ok, "used up")


func test_release_uses_a_wood_arrow_never_the_ash_by_fallback() -> void:
	Gameplay.inventory.remove(&"arrow_wood", 100)
	Gameplay.inventory.add(&"arrow_ash")
	feyre.bow_controller.selected = &"arrow_wood"
	feyre.bow_controller.update_draw(0.5, true, false)
	assert_false(feyre.bow_controller.is_drawing, "won't draw the ash arrow unless chosen")
	feyre.bow_controller.cycle_arrow()
	assert_eq(feyre.bow_controller.selected, &"arrow_ash")
	feyre.bow_controller.update_draw(0.5, true, false)
	var arrow := feyre.bow_controller.release()
	assert_not_null(arrow)
	assert_eq(arrow.arrow_id, &"ash")
	assert_eq(arrow.get_meta(&"arrow_id"), &"ash")
	assert_eq(Gameplay.inventory.arrow_count(&"arrow_ash"), 0)


func test_arrows_break_on_stone_by_chance() -> void:
	var boulder := hill.get_node("GameplaySandbox/Boulder") as Node3D
	var brittle := (load("res://data/arrows/wood.tres") as ArrowData).duplicate() as ArrowData
	brittle.stone_break_chance = 1.0
	var tough := brittle.duplicate() as ArrowData
	tough.stone_break_chance = 0.0
	var broke := []
	var a := Arrow.create(brittle)
	hill.add_child(a)
	a.broke.connect(func(_at: Vector3) -> void: broke.append(true))
	var from := boulder.global_position + Vector3(0, 0, 6)
	a.launch(from, boulder.global_position - from, 40.0)
	var b := Arrow.create(tough)
	hill.add_child(b)
	b.launch(from + Vector3(0.2, 0, 0), boulder.global_position - from, 40.0)
	await wait_physics_frames(30)
	assert_eq(broke.size(), 1)
	assert_false(is_instance_valid(a))
	assert_true(b.stuck)


func test_slow_time_while_aiming_a_draw_then_stamina_runs_out() -> void:
	feyre.bow_controller.update_draw(0.5, true, true)
	assert_eq(Engine.time_scale, BowController.SLOW_TIME_SCALE)
	feyre.stamina = 0.0
	feyre.bow_controller.update_draw(0.1, true, true)
	assert_eq(Engine.time_scale, 1.0)


func test_wardrobe_station_opens_the_dressing_room() -> void:
	var wardrobe := hill.get_node("GameplaySandbox/Wardrobe") as Node3D
	feyre.global_position = wardrobe.global_position + Vector3(0, -1.0, 1.0)
	assert_true(feyre.interactor.interact())
	var room := get_tree().root.get_node_or_null("DressingRoom")
	assert_not_null(room)
	assert_true(get_tree().paused)
	assert_true(Gameplay.wardrobe.owns(&"ball_gown_rose"), "the room's gowns are hanging there")
	assert_true(Gameplay.wardrobe.equip(&"ball_gown_rose"))
	await wait_process_frames(2)
	assert_gt(feyre.wardrobe_applier.get_child_count() + feyre.model.get_node("Worn").get_child_count(), 0)
	load("res://ui/dressing_room/dressing_room.gd").close_room(feyre)
	assert_false(get_tree().paused)


func test_campfire_opens_the_hearth_panel() -> void:
	var fire := hill.get_node("GameplaySandbox/Campfire") as Node3D
	feyre.global_position = fire.global_position + Vector3(1.2, 0.1, 0)
	assert_true(feyre.interactor.interact())
	assert_not_null(get_tree().root.get_node_or_null("HearthPanel"))
	load("res://ui/hearth_panel.gd")._close(feyre)
	assert_false(get_tree().paused)
