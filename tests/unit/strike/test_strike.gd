## HK: Strike, the bow bash and the boot knife (docs/contracts/strike.md).
## Done-whens (health-interactions §11): crouched behind an unaware naga, one
## strike takes 4 of its 6; a sleep arrow then the knife kills it; the knife
## breaks a coil at once. Bow design B-bash: a bash cancels a wind-up, does no
## kill damage, costs 15 stamina and runs through resolve_hit as &"bow_bash".
extends GutTest

const ROAMER := preload("res://creatures/hostile/naga_roamer.tscn")
const ROAMER_DATA := preload("res://data/creatures/hostile/naga_roamer.tres")


class FakeHer:
	extends CharacterBody3D
	var body_state: BodyState
	var is_aiming: bool = false
	var crouch := CrouchMotor.new()
	var stamina: float = 100.0
	var max_stamina: float = 100.0

	func drain_stamina(amount: float) -> void:
		stamina -= amount

	func is_winded() -> bool:
		return stamina <= 0.0


class Snare:
	extends Node3D
	var was_cut: bool = false

	func cut(_by: Node3D) -> bool:
		was_cut = true
		return true


var her: FakeHer
var k: StrikeController


func before_each() -> void:
	StoryControl.release()
	her = FakeHer.new()
	her.add_to_group(&"player")
	add_child_autofree(her)
	k = StrikeController.new()
	her.add_child(k)
	k.set_physics_process(false)


func after_each() -> void:
	StoryControl.release()


## A naga roamer at the origin facing -Z, unaware of her.
func _naga(id: StringName = &"naga_test") -> NagaRoamer:
	var n := ROAMER.instantiate() as NagaRoamer
	n.creature_id = id
	add_child_autofree(n)
	n.set_physics_process(false)
	n.senses.awareness = 0.0
	return n


func test_a_sneak_from_behind_takes_four_of_its_six() -> void:
	var n := _naga()
	her.global_position = Vector3(0, 0, 1.2)
	assert_true(StrikeController.is_behind(n, her.global_position))
	assert_eq(StrikeController.knife_kind(n, her.global_position, false, &""), &"sneak")
	assert_true(k.strike())
	assert_almost_eq(n.health, ROAMER_DATA.max_health - ROAMER_DATA.arrow_damage * 4.0, 0.01)
	assert_true(n.alive)


func test_crouched_in_front_is_a_sneak_too() -> void:
	var n := _naga()
	her.global_position = Vector3(0, 0, -1.2)
	her.crouch.set_crouched(true)
	assert_true(k.strike())
	assert_almost_eq(n.health, ROAMER_DATA.max_health - ROAMER_DATA.arrow_damage * 4.0, 0.01)


func test_standing_in_front_is_one_arrow() -> void:
	var n := _naga()
	her.global_position = Vector3(0, 0, -1.2)
	assert_true(k.strike())
	assert_almost_eq(n.health, ROAMER_DATA.max_health - ROAMER_DATA.arrow_damage, 0.01)
	assert_gt(n.stagger_left, 0.0, "a knife wound drives it back a step")


func test_an_aware_naga_is_no_sneak() -> void:
	var n := _naga()
	n.senses.awareness = 0.8
	her.global_position = Vector3(0, 0, 1.2)
	assert_eq(StrikeController.knife_kind(n, her.global_position, true, &""), &"knife")


func test_a_sneak_needs_her_close() -> void:
	var n := _naga()
	assert_eq(StrikeController.knife_kind(n, Vector3(0, 0, 1.7), true, &""), &"knife", "1.7 m is reach, not sneak")


func test_a_sleep_arrow_then_the_knife_kills() -> void:
	var n := _naga()
	var arrow := Node3D.new()
	add_child_autofree(arrow)
	n.on_arrow_effect(&"sleep", arrow)
	assert_gt(n.asleep_left, 0.0)
	n.senses.awareness = 1.0
	her.global_position = Vector3(0, 0, -1.2)
	assert_eq(StrikeController.knife_kind(n, her.global_position, false, &""), &"finisher")
	assert_true(k.strike())
	assert_false(n.alive, "x6 of 8 is all 48")


func test_one_stab_at_a_time() -> void:
	var n := _naga()
	her.global_position = Vector3(0, 0, -1.2)
	assert_true(k.strike())
	assert_false(k.strike())
	k.step(StrikeController.KNIFE_COOLDOWN + 0.05)
	assert_true(k.strike())
	assert_almost_eq(n.health, ROAMER_DATA.max_health - ROAMER_DATA.arrow_damage * 2.0, 0.01)


func test_out_of_reach_does_nothing_and_leaves_the_press() -> void:
	var n := _naga()
	her.global_position = Vector3(0, 0, -(StrikeController.REACH + 0.3))
	assert_false(k.strike(), "the press goes on to whatever else is bound to it")
	assert_eq(n.health, ROAMER_DATA.max_health)


func test_bow_raised_is_a_bash_that_cancels_the_wind_up() -> void:
	var n := _naga()
	n.senses.awareness = 1.0
	n.fight = NagaRoamer.Fight.STRIKE
	her.global_position = Vector3(0, 0, -1.2)
	her.is_aiming = true
	watch_signals(k)
	assert_true(k.strike())
	assert_signal_emitted_with_parameters(k, "struck", [&"bash", n])
	assert_eq(n.health, ROAMER_DATA.max_health, "no kill damage")
	assert_eq(n.fight, NagaRoamer.Fight.RECOVER, "the strike it was winding up is lost")
	assert_gt(n.stagger_left, 0.0)
	assert_almost_eq(her.stamina, 100.0 - StrikeController.BASH_STAMINA, 0.01)


func test_a_bash_goes_through_the_hit_rule() -> void:
	var n := _naga()
	n.senses.awareness = 1.0
	her.global_position = Vector3(0, 0, -1.2)
	her.is_aiming = true
	watch_signals(EventBus)
	k.strike()
	assert_signal_emitted_with_parameters(EventBus, "creature_hit", [&"naga_test", &"naga", &"bow_bash", &"body"])


func test_a_winded_bash_does_nothing() -> void:
	var n := _naga()
	n.senses.awareness = 1.0
	her.global_position = Vector3(0, 0, -1.2)
	her.is_aiming = true
	her.stamina = 0.0
	assert_false(k.strike())
	assert_eq(n.stagger_left, 0.0)


func test_a_bash_never_finishes_a_mortal_wound() -> void:
	var r := Creature.resolve_hit(ROAMER_DATA, 10.0, &"bow_bash", 0.0, 1, true)
	assert_false(r.killed)
	assert_eq(r.health, 10.0)
	assert_true(Creature.resolve_hit(ROAMER_DATA, 10.0, &"knife", 1.0, 1, true).killed)


func test_bow_raised_still_knifes_a_sneak() -> void:
	var n := _naga()
	her.global_position = Vector3(0, 0, 1.2)
	her.is_aiming = true
	assert_true(k.strike())
	assert_almost_eq(n.health, ROAMER_DATA.max_health - ROAMER_DATA.arrow_damage * 4.0, 0.01)


func test_the_knife_breaks_a_coil_at_once_and_opens_a_finisher() -> void:
	her.body_state = BodyState.new()
	her.body_state.name = "BodyState"
	her.add_child(her.body_state)
	var v := VitalsState.new()
	v.name = "Vitals"
	v.player = her
	her.body_state.vitals = v
	her.add_child(v)
	her.body_state.set_physics_process(false)
	v.set_physics_process(false)
	var n := _naga(&"naga_coil")
	n.senses.awareness = 1.0
	her.global_position = Vector3(0, 0, -1.2)
	EventBus.player_grabbed.emit(&"naga_coil", 6, 10.0)
	assert_true(v.is_grabbed())
	assert_true(k.strike())
	assert_false(v.is_grabbed(), "one cut, not six presses")
	assert_eq(n.health, ROAMER_DATA.max_health, "the cut frees her; it doesn't stab")
	k.step(StrikeController.KNIFE_COOLDOWN + 0.05)
	assert_eq(StrikeController.knife_kind(n, her.global_position, false, &"naga_coil"), &"finisher")
	assert_true(k.strike())
	assert_false(n.alive, "the one that held her takes the finisher")


func test_the_finisher_window_closes() -> void:
	EventBus.player_released.emit(&"naga_coil")
	var n := _naga(&"naga_coil")
	n.senses.awareness = 1.0
	her.global_position = Vector3(0, 0, -1.2)
	k.step(StrikeController.FREED_WINDOW + 0.1)
	assert_true(k.strike())
	assert_almost_eq(n.health, ROAMER_DATA.max_health - ROAMER_DATA.arrow_damage, 0.01)


func test_the_knife_cuts_a_snare_in_reach() -> void:
	var s := Snare.new()
	s.add_to_group(StrikeController.CUTTABLE_GROUP)
	add_child_autofree(s)
	s.global_position = Vector3(1.0, 0, 0)
	assert_true(k.strike())
	assert_true(s.was_cut)


func test_strike_is_v() -> void:
	assert_true(ProjectSettings.has_setting("input/strike"), "strike is in project.godot")
	var keys := []
	var buttons := []
	for e in InputMap.action_get_events(StrikeController.ACTION):
		if e is InputEventKey:
			keys.append((e as InputEventKey).physical_keycode)
		elif e is InputEventJoypadButton:
			buttons.append((e as InputEventJoypadButton).button_index)
	assert_has(keys, KEY_V)
	assert_eq(buttons, [], "no pad button until the owner picks the layout")


## R18: one knife. The ambush's own is gone, and Feyre carries Strike.
func test_one_knife() -> void:
	var ambush := FileAccess.get_file_as_string("res://story/act3/suriel/naga_ambush.gd")
	for gone in ["func knife(", "KNIFE_REACH", "KNIFE_DAMAGE", "KNIFE_COOLDOWN", "_knife_cd"]:
		assert_false(ambush.contains(gone), "%s is gone from the ambush" % gone)
	var feyre := FileAccess.get_file_as_string("res://characters/feyre/feyre.gd")
	assert_true(feyre.contains("StrikeController.new()"))
