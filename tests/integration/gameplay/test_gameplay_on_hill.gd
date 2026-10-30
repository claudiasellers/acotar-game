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


func test_rope_arrow_leaves_an_anchor_and_bows_switch() -> void:
	var boulder := hill.get_node("GameplaySandbox/Boulder") as Node3D
	var data := (load("res://data/arrows/rope.tres") as ArrowData).duplicate() as ArrowData
	data.stone_break_chance = 0.0
	var a := Arrow.create(data)
	hill.add_child(a)
	var from := boulder.global_position + Vector3(0, 0.3, 6)
	a.launch(from, boulder.global_position + Vector3(0, 0.3, 0) - from, 40.0)
	await wait_physics_frames(30)
	assert_eq(get_tree().get_nodes_in_group(ArrowEffects.ROPE_GROUP).size(), 1)
	assert_eq(feyre.bow_controller.owned_bows().size(), 1)
	Gameplay.inventory.add(&"bow_fae_recurve")
	feyre.bow_controller.cycle_bow()
	assert_eq(feyre.bow.id, &"fae_recurve")


func test_collection_book_opens_on_j_and_closes() -> void:
	var ui := load("res://ui/collection_book/collection_book_ui.gd")
	Gameplay.inventory.add(&"ing_acorn")
	var press := InputEventAction.new()
	press.action = &"open_collection"
	press.pressed = true
	feyre.interactor._unhandled_input(press)
	assert_true(ui.is_open(), "J opens the book")
	assert_true(feyre.get_tree().paused)
	await wait_frames(2)
	assert_false(Gameplay.collection.is_new(&"ing_acorn"), "the opened tab clears its badges")
	ui.close(feyre)
	assert_false(ui.is_open())
	assert_false(feyre.get_tree().paused)


func test_e_at_a_carcass_skins_before_pulling_arrows() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar done := false\nfunc harvest() -> Array:\n\tif done:\n\t\treturn []\n\tdone = true\n\treturn [{\"item_id\": &\"ing_hare_pelt\", \"qty\": 1}]\n"
	script.reload()
	var carcass := Node3D.new()
	carcass.set_script(script)
	carcass.add_to_group(&"harvestable")
	hill.add_child(carcass)
	carcass.global_position = feyre.global_position + Vector3(1, 0, 0)
	var arrow := Arrow.create()
	hill.add_child(arrow)
	arrow.global_position = carcass.global_position
	arrow.add_to_group(Arrow.STUCK_GROUP)
	var arrows_before := Gameplay.inventory.arrow_count()
	assert_true(feyre.interactor.interact())
	assert_eq(Gameplay.inventory.count(&"ing_hare_pelt"), 1, "first E skins")
	assert_eq(Gameplay.inventory.arrow_count(), arrows_before, "arrows wait")
	assert_true(feyre.interactor.interact())
	assert_eq(Gameplay.inventory.arrow_count(), arrows_before + 1, "then E pulls the arrow")


func test_reticle_follows_the_predicted_impact() -> void:
	var reticle := feyre.bow_controller.find_child("Reticle", true, false) as AimReticle
	assert_not_null(reticle)
	var guess := feyre.bow_controller.predict_impact(1.0)
	assert_true(guess.has("point"))
	var aim := feyre.aim_point()
	assert_lt(guess.point.distance_to(feyre.bow_controller.muzzle()), aim.distance_to(feyre.bow_controller.muzzle()) + 0.5,
		"the arrow never lands beyond the aim point")


func test_nearest_find_glints_and_names_itself() -> void:
	var field := hill.get_node("GameplaySandbox/Forage_ing_snowdrop") as ForageScatter
	var spot := field.global_transform * field.multimesh.get_instance_transform(0).origin
	feyre.global_position = spot + Vector3(0.8, 0, 0)
	var focus := feyre.interactor.forage_focus
	var near := focus.nearest(feyre.global_position, ForageFocus.GLINT_RADIUS)
	assert_false(near.is_empty())
	await wait_seconds(ForageFocus.REFRESH * 2.0 + 0.05)
	assert_false(focus.focus.is_empty(), "something glints nearby")
	assert_true(focus._card.visible, "a pick card shows in reach")
	assert_string_contains(focus._label.text, "pick")
	var id: StringName = focus.focus.id
	var before := Gameplay.inventory.count(id)
	assert_true(feyre.interactor.interact())
	assert_eq(Gameplay.inventory.count(id), before + 1, "E picks exactly what the card names")


func test_windowed_finds_hide_outside_their_window() -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = MultiMesh.new()
	mmi.add_to_group(ForageScatter.GROUP)
	mmi.set_meta(&"ingredient_id", &"ing_chaga")
	hill.add_child(mmi)
	Clock.time_of_day = 12.0 / 24.0
	feyre.interactor.update_forage_windows()
	assert_false(mmi.visible, "chaga is a dusk find")
	Clock.time_of_day = 19.0 / 24.0
	feyre.interactor.update_forage_windows()
	assert_true(mmi.visible)
