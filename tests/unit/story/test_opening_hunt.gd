extends GutTest
## The opening hunt before the doe (plans/onboarding/plan.md, "Done when"):
## the keys taught as they first matter, her empty snare, the rabbit that
## can't be killed, three arrows in her quiver, and hints that can be off.
# gate: when:story/act1/*,characters/feyre/*,creatures/*,systems/bow/*,data/bows/*,data/story/act1/*,data/guide/onboarding/*,ui/hud/key_prompt.gd,systems/settings/*

const CFG := "user://test_opening_prompts.cfg"
const SETTINGS := "user://test_opening_settings.cfg"
const RABBIT: CreatureData = preload("res://data/story/act1/hare_ch1.tres")

var prompts: KeyPrompts
var feyre: Feyre
var _saved_path: String


func before_each() -> void:
	WorldState.clear()
	_empty_quiver()
	_saved_path = GameSettings.settings_path
	GameSettings.settings_path = SETTINGS
	GameSettings.load_settings()
	prompts = KeyPrompts.new()
	prompts.settings_path = CFG
	add_child_autofree(prompts)
	feyre = load("res://characters/feyre/feyre.tscn").instantiate()
	add_child_autofree(feyre)
	feyre.global_position = Vector3(0, 0, 0)


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	GameSettings.settings_path = _saved_path
	GameSettings.load_settings()
	WorldState.clear()
	_empty_quiver()
	TimeScale.reset()


func _empty_quiver() -> void:
	for id: StringName in [&"arrow_wood", &"arrow_ash"]:
		Gameplay.inventory.remove(id, Gameplay.inventory.count(id))


func test_walk_and_look_are_offered_only_to_a_player_who_has_not() -> void:
	prompts._learn(4.9)
	assert_eq(prompts.want(), &"", "not before 5 s of control")
	prompts._learn(0.2)
	assert_eq(prompts.want(), &"walk")
	feyre.global_position += Vector3(1.5, 0, 0)
	prompts._learn(0.1)
	assert_eq(prompts.want(), &"walk", "1.5 m isn't walking yet")
	feyre.global_position += Vector3(1.0, 0, 0)
	prompts._learn(0.1)
	assert_true(prompts.taught.get(&"walk", false), "2 m walked")
	assert_eq(prompts.want(), &"", "look waits for 8 s")
	prompts._learn(3.0)
	assert_eq(prompts.want(), &"look")
	feyre.camera_look_yaw += 0.2
	feyre.camera_control.rig.rotation.y += 0.2
	prompts._learn(0.1)
	assert_true(prompts.taught.get(&"look", false), "0.15 rad turned")
	assert_eq(prompts.want(), &"")
	var again := KeyPrompts.new()
	again.settings_path = CFG
	add_child_autofree(again)
	again._control = 60.0
	assert_eq(again.want(), &"", "never again once done")


func test_a_player_who_moves_at_once_never_sees_walk_or_look() -> void:
	feyre.global_position += Vector3(3.0, 0, 0)
	prompts._learn(0.1)
	feyre.global_position += Vector3(3.0, 0, 0)
	feyre.camera_control.rig.rotation.y += 0.4
	prompts._learn(0.1)
	prompts._learn(10.0)
	assert_eq(prompts.want(), &"")


func test_the_snare_sits_early_on_the_doe_trail() -> void:
	var pts := Act1Wayfinding.track_points()
	var spot := OpeningHunt.snare_spot()
	var walked := 0.0
	var along := -1.0
	for i in range(1, pts.size()):
		var near := Geometry2D.get_closest_point_to_segment(spot, pts[i - 1], pts[i])
		if near.distance_to(spot) <= OpeningHunt.SNARE_SIDE + 0.05:
			along = walked + pts[i - 1].distance_to(near)
			break
		walked += pts[i].distance_to(pts[i - 1])
	assert_between(along, 75.0, 85.0, "80 m down the trail from its start")
	assert_gt(spot.distance_to(HumanRealmLayout.DOE_CLEARING), 300.0, "well before the doe")
	var gap := OpeningHunt.rabbit_spot().distance_to(spot)
	assert_between(gap, 18.0, 22.5, "the rabbit grazes a little farther on")


func test_the_snare_prompt_shows_in_reach_and_checking_it_brings_the_rabbit() -> void:
	var hunt := OpeningHunt.new()
	add_child_autofree(hunt)
	var spot := OpeningHunt.snare_spot()
	feyre.global_position = Vector3(spot.x, WorldHeight.height_at(spot.x, spot.y), spot.y) + Vector3(20, 0, 0)
	hunt._process(0.016)
	assert_not_null(hunt.snare, "built once she is near")
	assert_eq(prompts.want(), &"", "20 m off: nothing to press")
	feyre.global_position = hunt.snare.global_position + Vector3(Interactor.REACH - 0.3, 0, 0)
	assert_eq(prompts.want(), &"snare")
	(hunt.snare as OpeningSnare).use(feyre)
	assert_true(hunt.snare_checked)
	assert_not_null(hunt.rabbit)
	assert_true(hunt.rabbit.is_in_group(OpeningHunt.RABBIT_GROUP))
	prompts._learn(0.016)
	assert_true(prompts.taught.get(&"snare", false))
	assert_ne(prompts.want(), &"snare", "checked once")
	(hunt.snare as OpeningSnare).use(feyre)
	assert_eq(get_tree().get_nodes_in_group(OpeningHunt.RABBIT_GROUP).size(), 1, "one rabbit, however often she looks")


func test_the_rabbit_can_never_be_killed_or_skinned() -> void:
	assert_eq(RABBIT.harvest_items.size(), 0)
	var arrows := DirAccess.get_files_at("res://data/items")
	var tried := 0
	for file in arrows:
		if not file.begins_with("arrow_") or not file.ends_with(".tres"):
			continue
		tried += 1
		var id := StringName(file.get_basename())
		var health := RABBIT.max_health
		for i in 100:
			var out := Creature.resolve_arrow(RABBIT, health, id, false)
			health = out.health
			assert_false(out.killed or out.mortal, "%s, hit %d" % [id, i])
			if out.killed or out.mortal:
				break
	assert_gt(tried, 5, "every arrow type")


func test_the_rabbit_lifts_its_ears_at_the_nock_and_bolts_at_the_release() -> void:
	var hunt := OpeningHunt.new()
	add_child_autofree(hunt)
	var spot := OpeningHunt.rabbit_spot()
	feyre.global_position = Vector3(spot.x, WorldHeight.height_at(spot.x, spot.y), spot.y) + Vector3(18, 0, 0)
	hunt.check_snare()
	var rabbit := hunt.rabbit
	rabbit.set_physics_process(false)
	hunt._steer_rabbit(feyre, 0.016)
	assert_lt(rabbit.senses.awareness, OpeningHunt.NOCK_AWARENESS, "calm while she only walks")
	feyre.bow_controller.is_nocked = true
	hunt._steer_rabbit(feyre, 0.016)
	assert_gte(rabbit.senses.awareness, OpeningHunt.NOCK_AWARENESS - 0.001, "ears up the frame she nocks")
	assert_ne(rabbit.state, Prey.State.FLEE)
	hunt.on_release(feyre.global_position)
	rabbit._think(0.016)
	assert_eq(rabbit.state, Prey.State.FLEE, "gone the frame she looses")
	# An arrow that found it is left in the snow when it goes.
	var arrow := Arrow.new()
	rabbit.add_child(arrow)
	hunt._steer_rabbit(feyre, OpeningHunt.GONE_SECONDS + 0.1)
	assert_true(hunt.rabbit_done)
	assert_null(hunt.rabbit)
	assert_eq(arrow.get_parent(), hunt, "her arrow stays behind")
	arrow.queue_free()


func test_retrieve_shows_beside_a_stuck_arrow_and_is_taught_by_the_pickup() -> void:
	var stuck := Node3D.new()
	add_child_autofree(stuck)
	stuck.add_to_group(Arrow.STUCK_GROUP)
	stuck.global_position = Vector3(6, 0, 0)
	prompts._learn(0.016)
	assert_eq(prompts.want(), &"", "6 m off")
	stuck.global_position = Vector3(2.0, 0, 0)
	assert_eq(prompts.want(), &"retrieve")
	prompts._learn(0.016)
	assert_eq(prompts.want(), &"retrieve")
	Gameplay.inventory.add(&"arrow_wood", 1)
	stuck.remove_from_group(Arrow.STUCK_GROUP)
	prompts._learn(0.016)
	assert_true(prompts.taught.get(&"retrieve", false))
	stuck.add_to_group(Arrow.STUCK_GROUP)
	assert_eq(prompts.want(), &"", "taught once")


func test_crouch_is_offered_near_the_doe_until_she_crouches() -> void:
	var c := HumanRealmLayout.DOE_CLEARING
	feyre.global_position = Vector3(c.x + 90.0, 0, c.y)
	assert_eq(prompts.want(), &"", "90 m out")
	feyre.global_position = Vector3(c.x + 65.0, 0, c.y)
	assert_eq(prompts.want(), &"crouch")
	WorldState.set_flag("fact.wolf_spotted", true)
	assert_eq(prompts.want(), &"", "not once the wolf is here")
	WorldState.clear()
	feyre.crouch.set_crouched(true)
	assert_eq(prompts.want(), &"", "she is crouching")
	prompts._learn(0.016)
	feyre.crouch.set_crouched(false)
	assert_true(prompts.taught.get(&"crouch", false))
	assert_eq(prompts.want(), &"")


func test_focus_is_offered_nocked_in_the_wolf_hunt_once_he_is_seen() -> void:
	prompts.teach(&"ash")
	prompts.teach(&"draw")
	feyre.bow_controller.is_nocked = true
	assert_eq(prompts.want(), &"", "no hunt")
	EventBus.scene_space_started.emit(&"wolf_kill")
	assert_eq(prompts.want(), &"", "he isn't seen yet")
	WorldState.set_flag("fact.wolf_spotted", true)
	assert_eq(prompts.want(), &"focus")
	feyre.bow_controller.is_nocked = false
	assert_eq(prompts.want(), &"", "only with an arrow on the string")
	feyre.bow_controller.is_nocked = true
	feyre.bow_controller.is_focused = true
	prompts._learn(0.016)
	assert_true(prompts.taught.get(&"focus", false), "taught by the first held breath")
	assert_eq(prompts.want(), &"")
	EventBus.scene_space_finished.emit(&"wolf_kill")


func test_hints_off_hides_every_taught_key() -> void:
	var stuck := Node3D.new()
	add_child_autofree(stuck)
	stuck.add_to_group(Arrow.STUCK_GROUP)
	stuck.global_position = Vector3(1.5, 0, 0)
	assert_eq(prompts.want(), &"retrieve")
	GameSettings.set_value(&"key_hints", false)
	assert_eq(prompts.want(), &"")
	prompts._control = 60.0
	assert_eq(prompts.want(), &"")
	GameSettings.set_value(&"key_hints", true)
	assert_eq(prompts.want(), &"retrieve")


func test_every_prompt_names_a_key() -> void:
	for id: StringName in KeyPrompts.PROMPTS:
		for pair: Array in KeyPrompts.row(id):
			if (KeyPrompts.PROMPTS[id] as Array).size() == 1:
				assert_ne(pair[0], "", "%s has a key cap" % id)
	assert_eq(KeyPrompts.cap(&"move"), String(InputSettings.SCHEME_NAMES[InputSettings.scheme]), "the keys she chose")
	assert_eq(KeyPrompts.cap(&"look"), "Mouse")


func test_chapter_one_starts_with_two_plain_arrows_and_the_ash() -> void:
	var quivers := Feyre.QUIVER_LOADOUTS
	for phase: StringName in [&"p0_winter", &"p1_wolf_and_crossing"]:
		var inv := Inventory.new()
		quivers.fill(inv, phase)
		assert_eq(inv.count(&"arrow_wood"), 2, phase)
		assert_eq(inv.count(&"arrow_ash"), 1, phase)
		assert_eq(inv.arrow_count(), 3, "three arrows")
		quivers.fill(inv, phase)
		assert_eq(inv.arrow_count(), 3, "a quiver with arrows in it is left alone")
	var hill := Inventory.new()
	quivers.fill(hill, &"")
	assert_eq(hill.arrow_count(&"arrow_wood"), 12, "test hills keep a full dozen")


func test_the_wolf_hunt_gives_back_only_the_arrow_she_cannot_do_without() -> void:
	var kill := WolfKill.new()
	kill.auto_start = false
	add_child_autofree(kill)
	var granted: Array = []
	var note := func(id: StringName, n: int) -> void: granted.append([id, n])
	EventBus.story_item_granted.connect(note)
	Gameplay.inventory.add(&"arrow_wood", 2)
	kill._keep_an_arrow(kill.ash_regrant_seconds + 0.1)
	assert_eq(granted, [[&"arrow_ash", 1]], "no ash anywhere: one comes back")
	granted.clear()
	_empty_quiver()
	var stuck := Node3D.new()
	add_child_autofree(stuck)
	stuck.add_to_group(Arrow.STUCK_GROUP)
	stuck.set_meta(&"arrow_id", &"ash")
	kill._keep_an_arrow(kill.ash_regrant_seconds + 0.1)
	assert_eq(granted, [], "her ash arrow is lying where she can fetch it")
	stuck.set_meta(&"arrow_id", &"wood")
	kill.ash_struck = true
	kill._keep_an_arrow(kill.ash_regrant_seconds + 0.1)
	assert_eq(granted, [], "after the ash, any arrow she can pull will do")
	stuck.remove_from_group(Arrow.STUCK_GROUP)
	kill._keep_an_arrow(kill.ash_regrant_seconds + 0.1)
	assert_eq(granted, [[&"arrow_wood", 1]], "nothing left for his eye: one plain arrow")
	EventBus.story_item_granted.disconnect(note)


func test_her_empty_belly_is_thought_once_when_she_first_runs_low() -> void:
	var hunt := OpeningHunt.new()
	add_child_autofree(hunt)
	feyre.stamina = feyre.max_stamina * 0.5
	hunt._watch_winded(feyre)
	assert_false(hunt.winded_shown)
	feyre.stamina = feyre.max_stamina * 0.39
	hunt._watch_winded(feyre)
	assert_true(hunt.winded_shown)
	assert_eq(hunt.save_state().winded, true, "saved, so never twice")
	for path: String in OpeningHunt.THOUGHTS.values():
		assert_true(ResourceLoader.exists(path), path)
		assert_true(load(path) is GuideThread, path)
