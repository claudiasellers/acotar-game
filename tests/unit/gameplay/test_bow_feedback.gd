## Contract for the bow's feedback (plans/combat/bow-combat-design.md §13 B3):
## every sound of §5.8 is a cue in the bank and plays on its own event, the
## reticle shows the draw closing and catches at full draw, an early release
## is heard, an empty quiver is heard and nocks nothing, the Focus hush is a
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


func test_an_arrow_seating_clicks_on_the_raise_and_after_each_shot() -> void:
	Gameplay.inventory.add(&"arrow_wood", 3)
	_hold(0.1, true, false)
	assert_eq(_played(&"bow_nock"), 1, "the raise")
	_hold(0.5, true, false)
	assert_eq(_played(&"bow_nock"), 1, "once, not every frame")
	_hold(bow.bow.draw_time + 0.1, true, true)
	assert_not_null(_hold(0.05, true, false), "loosed")
	assert_eq(_played(&"bow_nock"), 1, "nothing seats inside the follow-through")
	_hold(bow.tuning.follow_through_s + 0.05, true, false)
	assert_eq(_played(&"bow_nock"), 2, "the next arrow")


func test_an_early_release_is_heard_and_a_full_draw_is_seen() -> void:
	Gameplay.inventory.add(&"arrow_wood", 3)
	var reticle := bow.get_node_or_null(^"Reticle") as AimReticle
	if reticle == null:
		for node in get_tree().root.find_children("Reticle", "AimReticle", true, false):
			reticle = node
	assert_not_null(reticle, "the bow has its reticle")
	watch_signals(bow)
	var arrows := Gameplay.inventory.arrow_count()
	_hold(0.1, true, false)
	_hold(bow.bow.draw_time * 0.4, true, true)
	assert_between(bow.draw_amount, 0.3, 0.5, "the arc is part closed")
	assert_eq(reticle.catch_left, 0.0)
	_hold(0.05, true, false)
	assert_signal_emitted(bow, "let_down")
	assert_eq(_played(&"bow_let_down"), 1, "the string eased forward is heard")
	assert_eq(Gameplay.inventory.arrow_count(), arrows, "and the arrow is kept")
	_hold(bow.bow.draw_time + 0.05, true, true)
	assert_signal_emit_count(bow, "full_draw", 1)
	assert_gt(reticle.catch_left, 0.0, "the ring catches as the draw closes")
	sound._update_bow()
	assert_true(sound._creak.playing, "the string creaks while she holds it")
	_hold(0.05, true, false)
	sound._update_bow()
	assert_false(sound._creak.playing)
	assert_eq(_played(&"bow_let_down"), 1, "a loosed arrow is not a let-down")


func test_an_empty_quiver_is_a_pat_and_nothing_nocks() -> void:
	for id: StringName in [&"arrow_wood", &"arrow_ash"]:
		Gameplay.inventory.remove(id, Gameplay.inventory.count(id))
	_hold(0.2, true, false)
	assert_false(bow.is_nocked)
	assert_eq(_played(&"bow_empty"), 0, "raising an empty bow is silent")
	_hold(0.3, true, true)
	assert_eq(_played(&"bow_empty"), 1, "reaching for an arrow is one pat")
	assert_false(bow.is_drawing)
	assert_eq(_played(&"bow_nock"), 0)
	_hold(0.1, true, false)
	_hold(0.1, true, true)
	assert_eq(_played(&"bow_empty"), 2, "and again each time she reaches")


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


func test_the_focus_hush_is_an_effect_on_the_ambience_bus() -> void:
	var bus := AudioServer.get_bus_index(SoundDirector.AMBIENCE_BUS)
	assert_ne(bus, -1, "the beds have a bus of their own")
	for bed in sound._beds:
		assert_eq(bed.bus, SoundDirector.AMBIENCE_BUS)
	var amp := AudioServer.get_bus_effect(bus, 0) as AudioEffectAmplify
	var low := AudioServer.get_bus_effect(bus, 1) as AudioEffectLowPassFilter
	assert_almost_eq(amp.volume_db, 0.0, 0.01)
	Gameplay.inventory.add(&"arrow_wood", 2)
	_hold(0.2, true, false, true)
	assert_true(bow.is_focused)
	assert_eq(_played(&"bow_focus_in"), 1, "an inhale")
	assert_true(sound._heart.playing, "her heartbeat for as long as she holds")
	await get_tree().create_timer(bow.tuning.hush_fade_s + 0.15, true, false, true).timeout
	assert_almost_eq(amp.volume_db, bow.tuning.hush_duck_db, 0.05, "12 dB down in the mixer")
	assert_almost_eq(low.cutoff_hz, SoundDirector.HUSH_CLOSED_HZ, 5.0)
	_hold(0.1, true, false, false)
	assert_false(bow.is_focused)
	assert_eq(_played(&"bow_focus_out"), 1, "an exhale")
	assert_false(sound._heart.playing)
	await get_tree().create_timer(bow.tuning.hush_fade_s + 0.15, true, false, true).timeout
	assert_almost_eq(amp.volume_db, 0.0, 0.05, "and the world comes back")


func test_a_blow_costs_her_half_the_draw() -> void:
	Gameplay.inventory.add(&"arrow_wood", 2)
	_hold(0.1, true, false)
	_hold(bow.bow.draw_time * 0.8, true, true)
	var before := bow.draw_amount
	assert_gt(before, 0.7)
	bow._on_player_hit(&"naga", &"bite", 1.0, Vector3.ZERO)
	assert_almost_eq(bow.draw_amount, before * bow.tuning.draw_kept_when_hit, 0.001)
	assert_true(bow.is_nocked, "the arrow stays on the string")


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
