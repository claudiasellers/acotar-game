## Contract for the bow's feedback (plans/combat/bow-combat-design.md §13 B3):
## every sound of §5.8 is a cue in the bank and plays on its own event, the
## crosshair catches at full draw and pulses on a hit, an empty quiver is
## heard and nocks nothing, the Focus hush is a
## bus effect on Ambience, and a blow costs her half the draw.
extends GutTest
# gate: when:systems/bow/*,systems/audio/*,data/audio/*,data/bows/*,ui/aim_reticle.gd,characters/feyre/*,systems/interaction/*

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")
const TICK := 1.0 / 60.0
## §5.8, by cue id.
const CUES: Array[StringName] = [&"bow_nock", &"bow_creak", &"bow_let_down", &"bow_empty",
	&"bow_release", &"bow_release_sentry_warbow", &"bow_release_fae_recurve", &"bow_release_gilded_bow",
	&"bow_release_ash", &"bow_focus_in", &"bow_focus_out", &"bow_heartbeat", &"arrow_retrieve",
	&"bow_bash", &"bow_hit_stone", &"deer_lost", &"hare_lost"]

var hill: Node3D
var feyre: Feyre
var bow: BowController
var sound: SoundDirector


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
	sound = SoundDirector.new()
	add_child_autofree(sound)
	await wait_physics_frames(10)
	feyre.body_state.hunger = 0.0
	feyre.body_state.cold = 0.0
	feyre.vitals.dread = 0.0
	feyre.stamina = feyre.max_stamina
	sound.played.clear()


func after_each() -> void:
	StoryControl.release()
	TimeScale.reset()
	sound._set_hush(0.0, -12.0)


func _hold(seconds: float, aim: bool, fire: bool, focus: bool = false) -> Arrow:
	var out: Arrow = null
	for i in ceili(seconds / TICK):
		var a := bow.update_bow(TICK * Engine.time_scale, aim, fire, focus)
		if a and out == null:
			out = a
	return out


func _played(cue: StringName) -> int:
	return int(sound.played.get(cue, 0))


func test_every_sound_of_the_bow_is_in_the_bank() -> void:
	var ids := CUES.duplicate()
	for file in DirAccess.get_files_at("res://data/arrows"):
		if file.ends_with(".tres"):
			ids.append(StringName("arrow_select_%s" % file.get_basename()))
	assert_eq(ids.size(), CUES.size() + 10, "one select sound per arrow type")
	for id: StringName in ids:
		var cue := sound.bank.cue(id)
		assert_not_null(cue, "%s is a cue" % id)
		if cue:
			assert_false(cue.streams.is_empty(), "%s has a sound" % id)
	for path: String in ["res://data/creatures/deer.tres", "res://data/creatures/hare.tres"]:
		var data := load(path) as CreatureData
		assert_not_null(sound.bank.cue(data.lost_cue), "%s gives itself away with a sound" % data.kind)


func test_an_empty_quiver_looses_nothing_and_nocks_nothing() -> void:
	for id: StringName in [&"arrow_wood", &"arrow_ash"]:
		Gameplay.inventory.remove(id, Gameplay.inventory.count(id))
	_hold(0.2, true, false)
	assert_false(bow.is_nocked)
	assert_null(bow.release(), "no arrow, nothing leaves the bow")
	assert_eq(Gameplay.inventory.arrow_count(), 0)
	assert_eq(_played(&"bow_nock"), 0)


func test_each_bow_and_the_ash_arrow_have_their_own_release() -> void:
	var ash := Arrow.new()
	ash.arrow_id = &"ash"
	var wood := Arrow.new()
	var bows := {"hunting_bow": &"bow_release", "yew_longbow": &"bow_release",
		"sentry_warbow": &"bow_release_sentry_warbow", "fae_recurve": &"bow_release_fae_recurve",
		"gilded_bow": &"bow_release_gilded_bow"}
	for id: String in bows:
		var data := load("res://data/bows/%s.tres" % id) as BowData
		assert_eq(SoundDirector.release_cue(wood, data, sound.bank), bows[id], id)
		assert_eq(SoundDirector.release_cue(ash, data, sound.bank), &"bow_release_ash", "the ash arrow on the %s" % id)
	ash.free()
	wood.free()


func test_the_arrow_in_hand_is_heard_and_stone_clatters() -> void:
	Gameplay.inventory.add(&"arrow_wood", 2)
	Gameplay.inventory.add(&"arrow_ash", 1)
	bow.cycle_arrow()
	assert_eq(_played(StringName("arrow_select_%s" % String(bow.selected).trim_prefix("arrow_"))), 1)
	var rock := StaticBody3D.new()
	rock.add_to_group(Arrow.STONE_GROUP)
	add_child_autofree(rock)
	assert_eq(SoundDirector.arrow_hit_cue(rock, &"snow"), &"bow_hit_stone")
	var post := StaticBody3D.new()
	add_child_autofree(post)
	assert_eq(SoundDirector.arrow_hit_cue(post, &"snow"), &"bow_hit_wood")


func test_the_kick_is_the_bows_own_and_off_under_reduced_effects() -> void:
	var kicks := {}
	for id: String in ["hunting_bow", "sentry_warbow", "fae_recurve"]:
		kicks[id] = (load("res://data/bows/%s.tres" % id) as BowData).kick_degrees
	assert_gt(kicks.sentry_warbow, kicks.hunting_bow)
	assert_lt(kicks.fae_recurve, kicks.hunting_bow)
	var was: bool = GameSettings.reduced_effects
	GameSettings._values[&"reduced_effects"] = true
	feyre.camera_control._kick_t = -1.0
	feyre.camera_control.kick(0.35, 0.06, 0.15)
	assert_lt(feyre.camera_control._kick_t, 0.0, "no kick under Reduced Effects")
	GameSettings._values[&"reduced_effects"] = false
	feyre.camera_control.kick(0.35, 0.06, 0.15)
	assert_eq(feyre.camera_control._kick_t, 0.0)
	GameSettings._values[&"reduced_effects"] = was


func test_a_hit_on_a_creature_pulses_the_ring_unless_hit_marks_are_off() -> void:
	var reticle: AimReticle = null
	for node in get_tree().root.find_children("Reticle", "AimReticle", true, false):
		reticle = node
	assert_not_null(reticle)
	var was: bool = bool(GameSettings.get_value(&"hit_marks"))
	GameSettings._values[&"hit_marks"] = true
	EventBus.creature_hit.emit(&"deer_1", &"deer", &"arrow_wood", &"side")
	assert_almost_eq(reticle.pulse_left, bow.tuning.hit_pulse_s, 0.001)
	reticle.pulse_left = 0.0
	EventBus.creature_hit.emit(&"deer_1", &"deer", &"great_wolf", &"side")
	assert_eq(reticle.pulse_left, 0.0, "only her own arrows")
	GameSettings._values[&"hit_marks"] = false
	EventBus.creature_hit.emit(&"deer_1", &"deer", &"arrow_wood", &"side")
	assert_eq(reticle.pulse_left, 0.0, "off with hit marks")
	GameSettings._values[&"hit_marks"] = was


func test_an_arrow_the_story_hands_her_is_named_on_the_quiver_card() -> void:
	var card := bow.quiver_card
	card._left = 0.0
	card._panel.visible = false
	var before := Gameplay.inventory.count(&"arrow_ash")
	EventBus.story_item_granted.emit(&"arrow_ash", 1)
	await wait_physics_frames(2)
	assert_true(card._panel.visible, "the card shows as it lands")
	assert_string_contains(card.text, "×%d" % (before + 1))
	var ash: ArrowData = BowController.arrow_data().get(&"arrow_ash")
	assert_string_contains(card.text, ash.display_name)


## UX review G12 and the L81 note on L80-17: no bow key is silent, and the
## card shows the quiver's size beside the count.
func test_the_card_shows_her_arrows_of_what_the_quiver_holds() -> void:
	var inv := Gameplay.inventory
	inv.remove(&"arrow_wood", 999)
	inv.remove(&"arrow_ash", 999)
	inv.quiver_size = 10
	inv.add(&"arrow_wood", 2)
	inv.add(&"arrow_ash", 1)
	assert_string_ends_with(bow.quiver_card.describe(&"arrow_wood"), "×2 · 3 of 10")


func test_an_arrow_she_cannot_make_says_what_is_short() -> void:
	var inv := Gameplay.inventory
	for id: StringName in [&"mat_shaft", &"mat_arrowhead"]:
		inv.remove(id, 999)
	for id in inv.ids_with_craft_tag(&"fletching"):
		inv.remove(id, 999)
	bow.selected = &"arrow_wood"
	watch_signals(bow)
	assert_false(bow.craft_selected())
	assert_signal_emitted(bow, "craft_failed")
	var wood: ArrowData = BowController.arrow_data().get(&"arrow_wood")
	assert_string_starts_with(bow.quiver_card.text, wood.display_name + ": needs ")
	assert_string_contains(bow.quiver_card.text, "1 fletching")
	assert_string_contains(bow.quiver_card.text, "1 " + ItemCatalog.get_item(&"mat_shaft").display_name.to_lower())
	inv.add(&"mat_shaft", 1)
	assert_false(bow.craft_selected())
	assert_does_not_have(Array(bow.quiver_card.text.split(", ")), "1 " + ItemCatalog.get_item(&"mat_shaft").display_name.to_lower(),
			"only what is still short")


func test_a_full_quiver_is_why_and_nothing_is_spent() -> void:
	var inv := Gameplay.inventory
	inv.add(&"mat_shaft", 1)
	inv.add(&"mat_arrowhead", 1)
	inv.add(&"ing_crow_feather", 1)
	inv.quiver_size = maxi(inv.arrow_count(), 1)
	inv.add(&"arrow_wood", 99)
	bow.selected = &"arrow_wood"
	assert_eq(Crafting.missing(Crafting.recipe(&"arrow_wood"), inv), {})
	assert_false(bow.craft_selected())
	assert_string_ends_with(bow.quiver_card.text, "no room in the quiver")
	assert_eq(inv.count(&"mat_shaft"), 1, "the shaft is still hers")


func test_the_bow_key_with_one_bow_names_the_bow() -> void:
	assert_eq(bow.owned_bows().size(), 1)
	bow.cycle_bow()
	assert_eq(bow.quiver_card.text, bow.bow.display_name)
	assert_true(bow.quiver_card._panel.visible)
