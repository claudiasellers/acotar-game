## Contract test for Feyre's vitals (L76, docs/contracts/vitals.md): the bus
## signals and their argument counts, the attack rows, hit handling, regen to
## the cap, food heals, afflictions, the status list the HUD reads, knockdown
## and wake, grabs, and the HUD's visibility rules.
# gate: when:systems/vitals/*,systems/body/*,ui/hud/vitals/*,data/combat/*,core/event_bus.gd
extends GutTest

## signal -> argument count (contract §1, plus the three L75/crouch seams).
const BUS := {
	&"player_struck": 3, &"player_hit": 4, &"player_status_applied": 4, &"player_startled": 2,
	&"player_grabbed": 3, &"player_released": 1, &"player_health_changed": 4,
	&"player_knocked_down": 3, &"player_woke": 2, &"player_status_changed": 3,
	&"player_mood_changed": 2, &"player_imbue_changed": 3,
	&"site_settled": 1, &"hostile_alerted": 2, &"player_stance_changed": 1,
}


class FakePlayer:
	extends CharacterBody3D
	var body_state: BodyState
	var stamina: float = 100.0
	var max_stamina: float = 100.0
	var presses_paid: float = 0.0

	func drain_stamina(amount: float) -> void:
		presses_paid += amount
		stamina -= amount

	func is_winded() -> bool:
		return false


var player: FakePlayer
var v: VitalsState


func before_each() -> void:
	player = FakePlayer.new()
	player.body_state = BodyState.new()
	player.body_state.name = "BodyState"
	player.add_child(player.body_state)
	v = VitalsState.new()
	v.name = "Vitals"
	v.player = player
	player.body_state.vitals = v
	player.add_child(v)
	add_child_autofree(player)
	player.body_state.set_physics_process(false)
	v.set_physics_process(false)


func test_bus_declares_every_vitals_signal_with_its_arguments() -> void:
	var declared: Dictionary = {}
	for s in EventBus.get_signal_list():
		declared[StringName(s.name)] = (s.args as Array).size()
	for name: StringName in BUS:
		assert_true(declared.has(name), "EventBus.%s" % name)
		assert_eq(declared.get(name, -1), BUS[name], "%s argument count" % name)


func test_attack_rows_resolve_by_id_family_and_unknown() -> void:
	assert_gte(AttackTable.count(), 25)
	assert_eq(AttackTable.resolve(&"naga").id, &"naga_bite", "a family resolves to its default row")
	assert_eq(AttackTable.resolve(&"martax_roar").status_tag, &"roar_shake")
	assert_eq(AttackTable.resolve(&"no_such_attack").id, &"generic_hit")


func test_a_hit_lands_once_then_iframes_drop_the_next() -> void:
	var dealt := v.take_hit(&"wolf", AttackTable.resolve(&"wolf_bite"))
	assert_almost_eq(dealt, 25.0, 0.01)
	assert_almost_eq(v.health, 75.0, 0.01)
	assert_eq(v.take_hit(&"wolf", AttackTable.resolve(&"wolf_bite")), 0.0, "i-frames")
	v.step(1.0)
	assert_gt(v.take_hit(&"wolf", AttackTable.resolve(&"wolf_bite")), 0.0, "i-frames over")


func test_bus_hit_reaches_her() -> void:
	EventBus.player_hit.emit(&"naga_1", &"naga_lunge", 1.0, Vector3(0, 0, 5))
	assert_almost_eq(v.health, 70.0, 0.01)
	assert_eq(v.last_hit_origin, Vector3(0, 0, 5))


func test_legacy_struck_from_a_naga_takes_its_default_bite() -> void:
	EventBus.player_struck.emit(&"naga_1", &"naga", 1.0)
	assert_almost_eq(v.health, 78.0, 0.01)


func test_queries_are_neutral_without_a_player() -> void:
	assert_eq(Vitals.sight_scale(null), 1.0)
	assert_eq(Vitals.noise_scale(null), 1.0)
	assert_eq(Vitals.scent_scale(null), 1.0)
	assert_eq(Vitals.dread_gain_scale(null), 1.0)
	assert_eq(Vitals.damage_taken_scale(null, &"bite"), 1.0)
	assert_eq(Vitals.health_fraction(null), 1.0)
	assert_false(Vitals.is_down(null))
	assert_false(Vitals.is_invulnerable(null))


func test_hazard_rows_respect_their_floor() -> void:
	v.health = 26.0
	v.take_hit(&"thorn", AttackTable.resolve(&"thorns"))
	assert_almost_eq(v.health, 25.0, 0.01, "thorns can't go below 25")
	v.step(1.0)
	v.take_hit(&"thorn", AttackTable.resolve(&"thorns"))
	assert_almost_eq(v.health, 25.0, 0.01)


func test_regen_waits_ten_seconds_and_stops_at_the_cap() -> void:
	player.body_state.hunger = 0.0
	v.take_hit(&"hob", AttackTable.resolve(&"hob_swat"))
	assert_almost_eq(v.health, 45.0, 0.01)
	v.step(5.0)
	assert_almost_eq(v.health, 45.0, 0.01, "no regen inside 10 s")
	for i in 40:
		v.step(1.0)
	assert_almost_eq(v.health, v.regen_cap(), 0.01, "regen stops at the cap")
	assert_lt(v.regen_cap(), 100.0)


func test_food_heals_over_three_seconds_past_the_cap() -> void:
	v.health = 40.0
	player.body_state.eat({"heal": 0.5, "hunger_relief": 0.1})
	assert_true(v.statuses().any(func(s: Dictionary) -> bool: return s.tag == &"heal"))
	for i in 4:
		v.step(1.0)
	assert_almost_eq(v.health, 90.0, 0.01)


func test_bitter_food_harms_without_knocking_her_down() -> void:
	v.health = 30.0
	player.body_state.eat({"harm": 0.45})
	assert_almost_eq(v.health, 10.0, 0.01, "food harm stops at 10")


func test_venom_creeps_blocks_regen_and_drains() -> void:
	EventBus.player_status_applied.emit(&"bv", &"venom", 0.35, 1.0)
	assert_almost_eq(v.affliction(&"venom"), 0.35, 0.001)
	v.step(10.0)
	assert_gt(v.affliction(&"venom"), 0.35, "venom creeps")
	v.apply_status(&"bv", &"venom", 0.3, 1.0)
	var before := v.health
	v.step(1.0)
	assert_lt(v.health, before, "drains at 0.5 and up")


func test_roar_is_timed_and_drowsy_decays() -> void:
	v.apply_status(&"m", &"roar_shake", 0.8, 6.0)
	v.apply_status(&"l", &"drowsy", 0.3, 1.0)
	v.step(4.0)
	assert_eq(v.affliction(&"drowsy"), 0.0, "drowsy decays 0.08/s")
	assert_gt(v.affliction(&"roar_shake"), 0.0)
	v.step(3.0)
	assert_eq(v.affliction(&"roar_shake"), 0.0)


func test_three_brew_effects_at_most() -> void:
	var b := player.body_state
	b.add_effect(&"steady", 1.0, 60.0)
	b.add_effect(&"swift", 1.0, 30.0)
	b.add_effect(&"warm", 1.0, 90.0)
	b.add_effect(&"keen", 1.0, 120.0)
	assert_eq(b.effects.size(), 3)
	assert_false(b.effects.has(&"swift"), "the one with least time left goes")


func test_statuses_list_danger_first_with_timers() -> void:
	player.body_state.add_effect(&"steady", 1.0, 60.0)
	v.apply_status(&"bv", &"venom", 0.4, 1.0)
	player.body_state.cold = 0.8
	var tags: Array = v.statuses().map(func(s: Dictionary) -> StringName: return s.tag)
	assert_eq(tags[0], &"venom")
	assert_true(tags.has(&"chilled"))
	var steady: Dictionary = v.statuses().filter(func(s: Dictionary) -> bool: return s.tag == &"steady")[0]
	assert_almost_eq(float(steady.total), 60.0, 0.01)
	for s in v.statuses():
		assert_true(ResourceLoader.exists(StatusRules.icon_path(s.tag)), "icon for %s" % s.tag)


func test_every_status_tag_has_an_icon() -> void:
	for tag: StringName in StatusRules.ORDER:
		assert_true(ResourceLoader.exists(StatusRules.icon_path(tag)), String(tag))


func test_knockdown_then_wake_on_the_spot_without_a_rest_point() -> void:
	var flags: Dictionary = WorldState.to_dict()
	var clock: Dictionary = Clock.to_dict()
	watch_signals(v)
	v.take_hit(&"hob", AttackTable.resolve(&"hob_swat"))
	v.step(2.0)
	v.take_hit(&"hob", AttackTable.resolve(&"hob_swat"))
	assert_true(v.is_down)
	assert_signal_emitted(v, "knocked_down")
	assert_eq(v.take_hit(&"hob", AttackTable.resolve(&"hob_swat")), 0.0, "no hits while down")
	v.step(VitalsState.DOWN_SECONDS + 0.1)
	assert_false(v.is_down)
	assert_signal_emitted(v, "woke")
	assert_gt(v.health, 0.0)
	assert_almost_eq(v.dread, 0.2, 0.001)
	assert_true(v.is_invulnerable(), "wake grace")
	assert_eq(int(StoryControl.mode), 0, "free play handed back")
	WorldState.from_dict(flags)
	Clock.from_dict(clock)


func test_grab_breaks_free_with_presses_that_cost_stamina() -> void:
	EventBus.player_grabbed.emit(&"puca", 3, 4.0)
	assert_true(v.is_grabbed())
	EventBus.player_grabbed.emit(&"other", 9, 4.0)
	assert_eq(v.grab_source, &"puca", "one hold at a time")
	for i in 3:
		v.press_break_free()
	assert_false(v.is_grabbed())
	assert_almost_eq(player.presses_paid, 3.0 * VitalsState.GRAB_PRESS_STAMINA, 0.01)


func test_ease_raises_max_stamina_and_dread_follows_mood() -> void:
	v.ease = 0.4
	v.step(0.1)
	assert_almost_eq(player.max_stamina, 120.0, 0.01)
	EventBus.mood_requested.emit(&"dread", 0.8, 1.0)
	v.step(1.0)
	assert_gt(v.dread, 0.1)


func test_save_round_trip() -> void:
	v.health = 42.0
	v.ease = 0.3
	v.apply_status(&"bv", &"venom", 0.4, 1.0)
	var data := v.save_state()
	var other := VitalsState.new()
	other.load_state(data)
	assert_almost_eq(other.health, 42.0, 0.01)
	assert_almost_eq(other.ease, 0.3, 0.01)
	assert_almost_eq(other.affliction(&"venom"), 0.4, 0.01)
	other.free()


func test_hud_contextual_shows_dangers_and_new_buffs_only() -> void:
	var hud := VitalsHud.new()
	add_child_autofree(hud)
	await wait_process_frames(2)
	assert_true(hud._status_wanted({"tag": &"venom", "seconds_left": -1.0, "total": -1.0}))
	hud._first_seen[&"steady"] = hud._clock - 10.0
	assert_false(hud._status_wanted({"tag": &"steady", "seconds_left": 100.0, "total": 200.0}), "old buff hides")
	assert_true(hud._status_wanted({"tag": &"steady", "seconds_left": 10.0, "total": 200.0}), "near its end")
