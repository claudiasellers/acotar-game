## L29 contract: the Summer faerie's triage (ch 17) is a real clock that
## cannot be won. Care buys time and his words; warm or bitter dressings make
## it worse; holding his hand when he dies is the deed (summer_faerie_held),
## dying alone costs it, and only the daytime vigil at his grave mends it.
extends GutTest

const STEP := 0.1
const STILLROOM := preload("res://data/stations/stillroom.tres")

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


func _ing(id: StringName) -> IngredientData:
	return ItemCatalog.get_item(id) as IngredientData


## Runs a state until he dies; returns seconds.
func _run_out(s: TriageState, limit: float = 900.0) -> float:
	while not s.dead and s.elapsed < limit:
		s.tick(STEP)
	return s.elapsed


## Every step on both stumps, with a dressing of this rating.
func _tend(s: TriageState, rating: float) -> void:
	for i in 2:
		for step in [TriageWound.Step.READ, TriageWound.Step.CLEAN, TriageWound.Step.DRESS, TriageWound.Step.BIND]:
			if step == TriageWound.Step.CLEAN:
				s.take_supplies()
			if step == TriageWound.Step.BIND:
				s.take_supplies()
			s.dressing_rating = rating
			s.begin(i, step)
			while not s.work.is_empty():
				s.tick(STEP)


func test_untreated_he_dies_in_about_three_minutes() -> void:
	var t := _run_out(TriageState.new())
	assert_between(t, 160.0, 180.0, "two open stumps bleed him out in 160-180 s (got %.1f)" % t)


func test_good_care_brings_him_round_to_speak() -> void:
	var s := TriageState.new()
	var spoke := [false]
	s.came_round.connect(func() -> void: spoke[0] = true)
	_tend(s, 0.55)
	assert_true(s.lucid and spoke[0], "both stumps tended with blood left: he speaks")
	assert_true(s.elapsed <= 90.0, "the full triage fits in 90 s (%.1f)" % s.elapsed)
	assert_gte(s.blood, TriageState.LUCID_BLOOD)
	assert_eq(s.linen_left, 1, "one strip per stump, one spare")


func test_warm_and_bitter_dressings_make_it_worse() -> void:
	var lily := TriageMath.rate_ingredient(_ing(&"ing_fire_lily"))
	var w := TriageWound.new()
	w.read = true
	w.cleaned = true
	w.dressed = true
	w.dressing = lily
	assert_gte(w.rate() / TriageWound.BASE_RATE, 1.29, "warm thins the blood: x1.3 (rating %.2f)" % lily)
	assert_eq(TriageMath.rate_ingredient(_ing(&"ing_nettle")), TriageMath.MIN_RATING, "bitter over vital harms")
	var s := TriageState.new()
	s.wounds[0].read = true
	s.dressing_rating = TriageMath.MIN_RATING
	s.begin(0, TriageWound.Step.DRESS)
	var before := s.blood
	while not s.work.is_empty():
		s.tick(STEP)
	assert_lte(s.blood, before - TriageMath.HARM_LOSS, "a harmful dressing costs 10 at once")


func test_it_cannot_be_won() -> void:
	var s := TriageState.new()
	_tend(s, TriageMath.MAX_RATING)
	var t := _run_out(s, 2000.0)
	assert_true(s.dead, "the best care still loses him")
	assert_lt(t, 360.0, "dead within 6 minutes even so (%.1f s)" % t)


func test_holding_his_hand_he_lets_go_and_hears_the_promise_only_if_he_came_round() -> void:
	var early := TriageState.new()
	assert_false(early.take_hand(), "no words before he comes round")
	var t := _run_out(early)
	assert_lte(t, TriageState.FADE_SECONDS + 0.2)
	var late := TriageState.new()
	_tend(late, 0.55)
	var at := late.elapsed
	assert_true(late.take_hand(), "he came round: he hears her promise")
	assert_lte(_run_out(late) - at, TriageState.FADE_SECONDS + 0.2)


func test_triage_math_reads_l12_tags() -> void:
	var yarrow := TriageMath.rate_ingredient(_ing(&"ing_yarrow"))
	assert_gt(yarrow, 0.2, "yarrow staunches")
	assert_false(TriageMath.is_dressing(_ing(&"ing_venison")), "meat is no dressing")
	var salve := Chemistry.combine([_ing(&"ing_yarrow"), _ing(&"ing_honey")] as Array[IngredientData], STILLROOM, &"salve")
	assert_true(salve.ok, str(salve.get("reason", "")))
	assert_gt(TriageMath.rate_dish(salve), yarrow, "a ground salve beats raw forage")
	inv.add(&"ing_yarrow", 1)
	inv.add(&"ing_fire_lily", 1)
	assert_eq(TriageMath.best_dressing(inv).id, &"ing_yarrow", "she reaches for what helps")
	inv.dishes.append(salve)
	var best := TriageMath.best_dressing(inv)
	assert_eq(String(best.kind), "dish", "a salve she carries comes first")
	assert_true(TriageMath.use_dressing(inv, best))
	assert_eq(inv.dishes.size(), 0)


func _space() -> SummerFaerieTriage:
	var anchor := Marker3D.new()
	anchor.name = "manor_window_hide"
	root.add_child(anchor)
	var spaces := Act3Anchors.attach(anchor)
	var t := spaces[0] as SummerFaerieTriage
	t.auto_tick = false
	(spaces[1] as SceneSpace).auto_tick = false
	t.inventory = inv
	return t


func _press_at(t: SummerFaerieTriage, target: SummerFaerieTriage.Target) -> void:
	feyre.global_position = t.target_point(target) + Vector3(0, 0, -0.6)
	assert_eq(t.target_at(feyre.global_position), target)
	t.press_interact()


func _work(t: SummerFaerieTriage) -> void:
	_press_at(t, SummerFaerieTriage.Target.WOUNDS)
	while not t.state.work.is_empty():
		t.tick(STEP)


func test_hall_space_held_to_the_end_raises_the_deed() -> void:
	WorldState.set_flag("naga_survived")
	Clock.from_dict({"time_of_day": 0.95, "day": Clock.day})
	var t := _space()
	assert_true(t.start(), "night, after the naga: Tamlin carries him in")
	inv.add(&"ing_yarrow", 2)
	for i in 2:
		_work(t)  # read
		_press_at(t, SummerFaerieTriage.Target.SUPPLIES)  # rag
		_work(t)  # clean
		_work(t)  # dress (yarrow)
		_press_at(t, SummerFaerieTriage.Target.SUPPLIES)  # linen
		_work(t)  # bind
	assert_true(t.spoke, "he spoke: 'She took my wings.'")
	assert_eq(inv.count(&"ing_yarrow"), 0, "both dressings used")
	_press_at(t, SummerFaerieTriage.Target.HAND)
	assert_true(t.state.holding and t.state.promised)
	for _i in 600:
		if not t.running:
			break
		t.tick(STEP)
	assert_false(t.running)
	assert_eq(t.outcome, &"held")
	for f in ["fact.summer_faerie_held", "fact.summer_faerie_farewell", "fact.summer_faerie_buried"]:
		assert_true(WorldState.has_flag(f), f)
	assert_false(WorldState.has_flag("fact.summer_faerie_died_alone"))
	assert_has(journal, &"summer_faerie_wings")
	assert_false(t.can_start(), "it never plays twice")
	var caption := get_tree().get_first_node_in_group(Act2Caption.GROUP) as Act2Caption
	assert_eq(caption.showing, "", "no triage text remains after he dies (L30's p4 house showed the herbs hint)")


func test_leaving_him_he_dies_alone_and_the_grave_vigil_mends_it_by_day() -> void:
	WorldState.set_flag("naga_survived")
	Clock.from_dict({"time_of_day": 0.95, "day": Clock.day})
	var t := _space()
	assert_true(t.start())
	feyre.global_position = t.global_position + Vector3(30, 0, 0)  # off for a salve
	for _i in 3000:
		if not t.running:
			break
		t.tick(STEP)
	assert_eq(t.outcome, &"alone")
	assert_eq((get_tree().get_first_node_in_group(Act2Caption.GROUP) as Act2Caption).showing, "",
		"the shelves hint is gone once he is dead")
	assert_true(WorldState.has_flag("fact.summer_faerie_died_alone"))
	assert_false(WorldState.has_flag("fact.summer_faerie_farewell"), "the deed is lost here")
	assert_has(journal, &"summer_faerie_alone")
	var grave := t.get_parent().get_node(^"SummerFaerieGrave") as SummerFaerieGrave
	assert_false(grave.can_start(), "not at night: night outside is forbidden to her")
	Clock.from_dict({"time_of_day": 0.4, "day": Clock.day + 1})
	assert_true(grave.start(), "next day, by day, at the grave")
	feyre.global_position = grave.global_position + Vector3(1, 0, 0)
	var walking := 0
	for _i in 200:  # pacing about doesn't count
		walking += 1
		feyre.global_position.x += 0.2
		grave.tick(STEP)
	assert_lt(grave.vigil, 2.0)
	feyre.global_position = grave.global_position + Vector3(1, 0, 0)
	for _i in 500:
		if not grave.running:
			break
		grave.tick(STEP)
	assert_true(WorldState.has_flag("fact.summer_faerie_farewell"))
	assert_true(WorldState.has_flag("fact.summer_faerie_mourned"))


func test_anchor_hangs_both_spaces_once_and_the_moment_raises_comforted() -> void:
	var anchor := Marker3D.new()
	anchor.name = "manor_window_hide"
	anchor.add_to_group(&"story_anchor")
	root.add_child(anchor)
	var spaces := Act3Anchors.attach(anchor)
	assert_eq(spaces.size(), 2)
	assert_eq(Act3Anchors.attach(anchor).size(), 2)
	assert_eq(anchor.get_child_count(), 2, "attaching twice adds nothing")
	var t := spaces[0] as SummerFaerieTriage
	assert_almost_eq(t.global_position.z, SummerFaerieTriage.TABLE_CENTER.y, 0.01, "on the hall table")
	var moment := StoryDirector.get_moment(&"summer_faerie")
	assert_eq(moment.anchor_id, &"")
	assert_eq(String(moment.trigger), "auto")


func test_with_nothing_to_dress_she_thinks_of_the_infirmary_shelves() -> void:
	WorldState.set_flag("naga_survived")
	Clock.from_dict({"time_of_day": 0.95, "day": Clock.day})
	var t := _space()
	assert_true(t.start())
	feyre.global_position = t.global_position + Vector3(0, 0, -2)
	for _i in 50:
		t.tick(STEP)
	assert_true(t.hinted)
	assert_eq(t.caption.showing, SummerFaerieTriage.SHELF_HINT, "she thinks of the shelves")
	var defs := load("res://data/regions/spring_court/manor_estate/house/service.tres")
	var found := []
	for d in defs.get(&"secrets"):
		if d.kind == &"larder" and String(d.secret_id).begins_with("infirmary_"):
			found.append(d.item_id)
			assert_gt(TriageMath.rate_ingredient(ItemCatalog.get_item(d.item_id) as IngredientData), 0.2, "%s staunches" % d.item_id)
	assert_eq(found.size(), 2, "two wound herbs on the infirmary shelves, one per stump")


func test_lucien_backs_away_retches_and_leaves_and_the_blood_shows() -> void:
	WorldState.set_flag("naga_survived")
	Clock.from_dict({"time_of_day": 0.95, "day": Clock.day})
	var t := _space()
	assert_true(t.start())
	feyre.global_position = t.global_position + Vector3(0, 0, -2)
	var lucien := get_tree().get_first_node_in_group(&"story_actor_lucien") as Node3D
	if t.lucien_exit == null:
		assert_not_null(lucien.find_child("CastCues", true, false), "the cast model acts leaves_sick itself (L22)")
	# The stand-in fallback: a bare figure backs away, retches and walks out.
	var stand_in := Node3D.new()
	root.add_child(stand_in)
	stand_in.global_position = t.global_position + Vector3(2.4, 0, 1.6)
	var exit := LucienExit.new(stand_in, t.global_position, Vector3(1.2, 0, -28.6))
	var seen := {}
	for _i in 300:
		t.tick(STEP)
		exit.tick(STEP)
		seen[exit.stage] = true
		if exit.gone():
			break
	assert_true(seen.has(LucienExit.Stage.RETCH), "he doubles over first")
	assert_true(exit.gone(), "then he is gone through the front doors")
	assert_false(stand_in.visible)
	var pool := t.props.get_node(^"BloodPool")
	assert_true((pool.get_node(^"TableSlick") as Node3D).visible, "blood on the table")
	assert_true((pool.get_node(^"FloorPool") as Node3D).visible, "and on the floor")
	assert_true((pool.get_node(^"Drips") as Node3D).visible)


func test_e_beside_the_wounds_never_takes_his_hand() -> void:
	var t := _space()
	for x in [-0.45, -0.15, 0.15]:
		var at := t.to_global(Vector3(x, 0, -1.15))
		assert_eq(t.target_at(at), SummerFaerieTriage.Target.WOUNDS, "at x %.2f (the Mac walker stopped 0.3 m off)" % x)
	assert_eq(t.target_at(t.to_global(Vector3(-1.4, 0, -1.05))), SummerFaerieTriage.Target.HAND)
