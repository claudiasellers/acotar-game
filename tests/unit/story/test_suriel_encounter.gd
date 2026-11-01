## L26 contract: the Suriel snare scores the setup the way the Keeper's canon
## reads (ch 13-15), the wait only counts hidden, still and downwind, the
## answers come in book order as journal entries until the naga cut in, and
## the naga fight can kill her, be won, and be retried.
extends GutTest

const STEP := 0.1
const NAGA := preload("res://creatures/fae/naga.tscn")
const WIND := Vector3(3.0, 0.0, 0.0)  # blows toward +X

var root: Node3D
var feyre: Node3D
var inv: Inventory
var journal: Array[StringName] = []


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	root = Node3D.new()
	add_child_autofree(root)
	feyre = Node3D.new()
	feyre.add_to_group(&"player")
	root.add_child(feyre)
	inv = Inventory.new()
	journal.clear()
	EventBus.journal_entry_added.connect(_on_journal)


func after_each() -> void:
	EventBus.journal_entry_added.disconnect(_on_journal)
	StoryControl.release()


func _on_journal(id: StringName) -> void:
	journal.append(id)


func _snare() -> SurielSnare:
	var s := SurielSnare.new()
	s.auto_tick = false
	s.inventory = inv
	s.birch_center = Vector3(100, 0, 100)
	s.water_distance_fn = func(_p: Vector3) -> float: return 20.0
	s.wind_fn = func(_p: Vector3) -> Vector3: return WIND
	root.add_child(s)
	s.position = Vector3(100, 0, 100)
	return s


func _run(s: SceneSpace, seconds: float, each: Callable = Callable()) -> void:
	for _i in int(seconds / STEP):
		if each.is_valid():
			each.call()
		s.tick(STEP)


func test_canon_setup_buys_five_answers_cut_short() -> void:
	var canon := SnarePlan.score({"birch_distance": 5.0, "water_distance": 20.0, "loops": 2, "bait": 0.75})
	assert_almost_eq(float(canon.quality), 0.885, 0.01)
	assert_eq(SnarePlan.answers_for(canon.quality), 5)
	assert_false(SnarePlan.blight_full(canon.quality), "canon: the blight answer is cut off")
	var perfect := SnarePlan.score({"birch_distance": 5.0, "water_distance": 20.0, "loops": 2, "bait": 0.95, "elevated": true})
	assert_true(SnarePlan.blight_full(perfect.quality))
	var poor := SnarePlan.score({"birch_distance": 80.0, "water_distance": 120.0, "loops": 1, "bait": 0.0, "smelled_seconds": 30.0})
	assert_eq(SnarePlan.answers_for(poor.quality), 1)
	assert_lt(SnarePlan.naga_distance(false), SnarePlan.naga_distance(true), "scouting the stream buys room")
	assert_gt(SnarePlan.wait_seconds(0.0), SnarePlan.wait_seconds(0.9))


func test_baits_are_scored_from_forage_tags() -> void:
	assert_almost_eq(SnarePlan.bait_score(&"ing_rabbit"), 0.75, 0.001)
	assert_gt(SnarePlan.bait_score(&"ing_rabbit"), SnarePlan.bait_score(&"ing_salt"))
	inv.add(&"ing_sinew", 2)
	inv.add(&"ing_rabbit", 1)
	inv.add(&"ing_salt", 1)
	var baits := SnarePlan.baits_in(inv)
	assert_eq(baits[0], &"ing_rabbit", "best bait first")
	assert_false(baits.has(&"ing_sinew"), "cordage is the loops, not bait")
	assert_eq(SnarePlan.loops_from(inv), 2)


func test_no_snare_without_cordage_or_outside_the_birches() -> void:
	WorldState.set_flag("fact.suriel_method_known")
	var s := _snare()
	inv.add(&"ing_rabbit", 1)
	assert_true(s.start())
	feyre.global_position = Vector3(100, 0, 100)
	s.press_interact()
	assert_eq(s.snare_at, Vector3.INF, "no cordage, no snare")
	inv.add(&"ing_sinew", 2)
	feyre.global_position = Vector3(180, 0, 100)
	s.press_interact()
	assert_eq(s.snare_at, Vector3.INF, "too far from the young birches")


func test_the_gardeners_twine_ties_both_loops() -> void:
	WorldState.set_flag("fact.suriel_method_known")
	var s := _snare()
	inv.add(&"mat_snare_twine", 1)
	inv.add(&"ing_dead_chicken", 1)
	assert_eq(SnarePlan.loops_from(inv), 2, "one coil is enough for both loops")
	assert_false(SnarePlan.baits_in(inv).has(&"mat_snare_twine"), "twine is not bait")
	s.start()
	feyre.global_position = Vector3(104, 0, 100)
	s.press_interact()
	assert_eq(s.loops, 2)
	assert_eq(inv.count(&"mat_snare_twine"), 0, "the coil is used up")
	assert_eq(s.bait_id, &"ing_dead_chicken")


func test_the_twine_waits_on_the_potting_shed_table() -> void:
	var garden := Node3D.new()
	add_child_autofree(garden)
	ManorKitchenGarden.build(garden)
	var kit := garden.get_node_or_null(^"SnareTwine") as LarderPickup
	assert_not_null(kit, "a twine pickup in the kitchen garden")
	if kit:
		assert_true(kit.is_in_group(LarderPickup.GROUP))
		assert_eq(kit.harvest(), &"mat_snare_twine")
		assert_false(kit.stocked(), "gone until tomorrow")
	assert_eq(SnareKitThought.think(get_tree(), 0), false, "no card in tests")


func test_bait_presses_swap_and_return_the_last_one() -> void:
	WorldState.set_flag("fact.suriel_method_known")
	var s := _snare()
	inv.add(&"ing_sinew", 2)
	inv.add(&"ing_rabbit", 1)
	inv.add(&"ing_salt", 1)
	s.start()
	feyre.global_position = Vector3(104, 0, 100)
	s.press_interact()
	assert_eq(s.loops, 2)
	assert_eq(inv.count(&"ing_sinew"), 0, "both loops used")
	assert_eq(s.bait_id, &"ing_rabbit")
	s.press_interact()
	assert_eq(s.bait_id, &"ing_salt")
	assert_eq(inv.count(&"ing_rabbit"), 1, "swapped bait goes back in the satchel")


func test_upwind_she_waits_for_nothing() -> void:
	WorldState.set_flag("fact.suriel_method_known")
	var s := _snare()
	inv.add(&"ing_sinew", 2)
	inv.add(&"ing_rabbit", 1)
	s.start()
	feyre.global_position = Vector3(104, 0, 100)
	s.press_interact()
	feyre.global_position = Vector3(84, 0, 100)  # 20 m upwind: her scent blows onto it
	_run(s, 80.0)
	assert_eq(s.stage, SurielSnare.Stage.WAIT)
	assert_almost_eq(s.waited, 0.0, 0.001)
	assert_gt(s.smelled_seconds, 70.0)


func test_canon_hunt_answers_in_book_order_then_the_naga_come() -> void:
	WorldState.set_flag("fact.suriel_method_known")
	var s := _snare()
	inv.add(&"ing_sinew", 2)
	inv.add(&"ing_rabbit", 1)
	s.start()
	feyre.global_position = Vector3(104, 0, 100)
	s.press_interact()
	feyre.global_position = Vector3(120, 0, 100)  # 16 m downwind, still
	_run(s, SnarePlan.wait_seconds(0.75) + 1.0)
	assert_eq(s.stage, SurielSnare.Stage.ARRIVE, "the Suriel comes")
	assert_not_null(s.suriel)
	assert_lt(s.suriel.global_position.x, 104.0, "from upwind")
	_run(s, 20.0)
	assert_eq(s.stage, SurielSnare.Stage.SNARED)
	feyre.global_position = Vector3(106, 0, 100)
	_run(s, 60.0)
	assert_true(WorldState.has_flag("fact.suriel_answered"))
	assert_false(s.running)
	var order: Array[StringName] = [&"suriel_no_way_home", &"suriel_tamlin", &"suriel_no_court", &"suriel_stay", &"suriel_blight_cut"]
	assert_eq(SnarePlan.answers_for(s.quality), 5)
	assert_eq(journal, order, "five answers in book order, the blight cut short")
	assert_true(float(WorldState.get_flag("fact.suriel_snare_quality", 0.0)) > 0.8)


func test_walking_off_mid_answer_holds_the_words() -> void:
	WorldState.set_flag("fact.suriel_method_known")
	var s := _snare()
	inv.add(&"ing_sinew", 1)
	inv.add(&"ing_rabbit", 1)
	s.start()
	feyre.global_position = Vector3(104, 0, 100)
	s.press_interact()
	feyre.global_position = Vector3(120, 0, 100)
	_run(s, 60.0)
	feyre.global_position = Vector3(106, 0, 100)
	_run(s, 0.5)
	assert_eq(journal.size(), 1)
	feyre.global_position = Vector3(130, 0, 100)
	_run(s, 30.0)
	assert_eq(journal.size(), 1, "out of earshot, no more answers")


func _ambush() -> NagaAmbush:
	WorldState.set_flag("fact.suriel_answered")
	WorldState.set_flag("fact.suriel_snare_quality", 0.88)
	var a := NagaAmbush.new()
	a.auto_tick = false
	a.snare_at = Vector3(0, 0, 0)
	a.wake_at = Vector3(-8, 0, -8)
	a.ground_fn = func(_p: Vector3) -> float: return 0.0
	root.add_child(a)
	feyre.global_position = Vector3(1, 0, 0)
	return a


func test_four_naga_and_four_strikes_fell_her() -> void:
	var a := _ambush()
	assert_true(a.start())
	assert_eq(a.naga.size(), 4)
	_run(a, 4.0)
	for i in NagaAmbush.STRIKES_TO_FALL - 1:
		a.strike()
		a.strike()  # inside the grace window: doesn't count
		_run(a, NagaAmbush.STRIKE_GRACE + 0.1)
	assert_eq(a.strikes, NagaAmbush.STRIKES_TO_FALL - 1)
	assert_true(a.running)
	a.strike()
	_run(a, NagaAmbush.FALL_SECONDS + 0.5)
	assert_false(a.running, "she fell")
	assert_eq(a.falls, 1)
	assert_almost_eq(feyre.global_position.x, -8.0, 0.01, "she wakes by the oak")
	assert_false(WorldState.has_flag("fact.naga_escaped"))
	assert_false(a.can_start(), "she gets a breath first")
	a._rest = 0.0
	assert_true(a.can_start(), "the fight can be tried again")


func test_a_kill_then_holding_on_brings_tamlin() -> void:
	var a := _ambush()
	a.start()
	EventBus.creature_killed.emit(&"naga", &"naga", &"arrow_wood", Vector3.ZERO)
	EventBus.creature_killed.emit(&"naga_2", &"naga", &"knife", Vector3.ZERO)
	_run(a, NagaAmbush.TAMLIN_EARLIEST - 1.0)
	assert_false(a.tamlin_came, "never in the first seconds, even after two kills")
	_run(a, 1.5)
	assert_true(a.tamlin_came)
	assert_true(WorldState.has_flag("fact.naga_escaped"))


func test_strikes_bring_tamlin_only_after_her_first_kill() -> void:
	var a := _ambush()
	a.start()
	_run(a, 2.0)
	EventBus.creature_hit.emit(&"naga", &"naga", &"arrow_wood", &"body")
	assert_true(a.fought_back)
	for i in NagaAmbush.TAMLIN_STRIKES:
		a.strike()
		_run(a, NagaAmbush.STRIKE_GRACE + 0.1)
	assert_false(a.tamlin_came, "a wound is not a kill: she must kill one herself first")
	EventBus.creature_killed.emit(&"naga", &"naga", &"knife", Vector3.ZERO)
	_run(a, STEP * 2)
	assert_true(a.tamlin_came, "after her first kill, three strikes bring him, even before 8 s")
	assert_eq(a.falls, 0)
	assert_true(WorldState.has_flag("fact.naga_escaped"))


func test_the_knife_finishes_the_wounded_naga() -> void:
	var a := _ambush()
	a.start()
	var near := NAGA.instantiate() as Naga
	near.creature_id = &"naga_near"
	root.add_child(near)
	near.global_position = Vector3(1.5, 0, 0)
	var cut := NAGA.instantiate() as Naga
	cut.creature_id = &"naga_cut"
	root.add_child(cut)
	cut.global_position = Vector3(3.0, 0, 0)
	cut.health -= NagaAmbush.KNIFE_DAMAGE
	a.naga[&"naga_near"] = near
	a.naga[&"naga_cut"] = cut
	var before := near.health
	assert_true(a.knife())
	assert_lt(cut.health, 16.0 - NagaAmbush.KNIFE_DAMAGE, "the wounded one takes the blade")
	assert_eq(near.health, before, "not the fresh one, though it is nearer")


func test_running_or_never_fighting_back_is_still_lethal() -> void:
	var a := _ambush()
	a.start()
	feyre.global_position = Vector3(60, 0, 0)  # ran
	_run(a, NagaAmbush.HOLD_SECONDS + 5.0)
	assert_false(a.tamlin_came, "nobody comes for a girl who runs")
	for i in NagaAmbush.STRIKES_TO_FALL:
		a.strike()
		_run(a, NagaAmbush.STRIKE_GRACE + 0.1)
	_run(a, NagaAmbush.FALL_SECONDS + 0.5)
	assert_false(a.tamlin_came)
	assert_eq(a.falls, 1, "five strikes fell her")


## F21 A/B: the chicken (the full blight answer) is a better snare than the
## rabbit, yet both get the same naga, as far off, and the same Tamlin.
func test_better_bait_buys_answers_not_a_harder_fight() -> void:
	var out := {}
	for bait: StringName in [&"ing_dead_chicken", &"ing_rabbit"]:
		WorldState.clear()
		var q := float(SnarePlan.score({"birch_distance": 4.0, "water_distance": 20.0, "loops": 2,
				"bait": SnarePlan.bait_score(bait), "elevated": true}).quality)
		var a := _ambush()
		WorldState.set_flag("fact.suriel_snare_quality", q)
		a.start()
		var spots: Array[Vector3] = []
		for id: StringName in NagaAmbush.NAGA_IDS:
			spots.append((a.naga[id] as Node3D).global_position)
		_run(a, 3.0)
		EventBus.creature_killed.emit(&"naga", &"naga", &"knife", Vector3.ZERO)
		var t := 0.0
		while not a.tamlin_came and t < 40.0:
			if t > 2.0 and t < 2.2:
				EventBus.creature_killed.emit(&"naga_2", &"naga", &"arrow_wood", Vector3.ZERO)
			_run(a, STEP)
			t += STEP
		out[bait] = {"q": q, "answers": SnarePlan.answers_for(q), "full": SnarePlan.blight_full(q),
				"spots": spots, "tamlin_at": a._t, "falls": a.falls}
		a.queue_free()
	var c: Dictionary = out[&"ing_dead_chicken"]
	var r: Dictionary = out[&"ing_rabbit"]
	assert_gt(float(c.q), float(r.q), "the chicken is the better bait")
	assert_true(c.full, "the chicken up a tree earns the whole blight answer")
	assert_gte(int(c.answers), int(r.answers))
	assert_eq(c.spots, r.spots, "same naga, same distance")
	assert_almost_eq(float(c.tamlin_at), float(r.tamlin_at), 0.01, "Tamlin comes just as soon")
	assert_eq(c.falls, 0)
	assert_eq(r.falls, 0)


func test_tether_shot_frees_the_suriel_and_the_knife_kills() -> void:
	var a := _ambush()
	a.start()
	a.arrow_landed(Vector3(0.5, 0, 0.5))
	assert_true(a.freed)
	var n := NAGA.instantiate() as Naga
	n.creature_id = &"naga_k"
	root.add_child(n)
	n.global_position = Vector3(2, 0, 0)
	a.naga[&"naga_k"] = n
	assert_true(a.knife())
	assert_false(a.knife(), "one stab at a time")
	assert_true(n.alive, "one stab wounds")
	_run(a, 1.0)
	assert_true(a.knife())
	assert_false(n.alive, "two stabs kill (16 health)")


func test_the_glade_anchor_gets_both_spaces() -> void:
	var anchor := Node3D.new()
	anchor.name = "suriel_snare"
	root.add_child(anchor)
	var spaces := Act3Anchors.attach(anchor)
	assert_eq(spaces.size(), 2)
	assert_true(spaces[0] is SurielSnare)
	assert_true(spaces[1] is NagaAmbush)
	var naga := spaces[1] as NagaAmbush
	assert_gt(naga.backwater_dir.z, 0.5, "the naga come from the backwater, downstream")
	assert_eq(Act3Anchors.attach(anchor).size(), 2, "safe to call twice")
	assert_eq(anchor.get_child_count(), 2)
