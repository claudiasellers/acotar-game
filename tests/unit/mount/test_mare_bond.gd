extends GutTest
## Contract test for the white mare's bond (L47-8, docs/contracts/mare_bond.md):
## each step opens on one-off deeds behind a barrier, never on days, the steps
## widen how far she hears the whistle and carries Feyre, her page says what to
## try, and the bond only ever raises `fact.mare_*` facts, never a phase flag
## (R2). Also the saddle and reins she wears for it. The bond runs on the one
## engine (docs/contracts/relationships.md): her milestones are her facts.

const HORSE := preload("res://creatures/fae/white_horse.tscn")
const FEYRE_MODEL := preload("res://characters/feyre/model/feyre_model.tscn")

var raised: Array[String] = []


class Rider:
	extends Node3D
	var model: Node3D


func before_each() -> void:
	WorldState.clear()
	WorldDeltas.clear()
	raised.clear()
	MarePage.reset()
	Relationships.raise = func(fact: String) -> void:
		raised.append(fact)
		WorldState.set_flag(fact, true)


func after_each() -> void:
	Relationships.raise = Callable()


func test_nothing_counts_before_she_is_ridden() -> void:
	WorldState.set_flag("first_dinner_eaten", true)
	assert_eq(MareBond.tier(), 0)
	assert_false(MareBond.mark(&"answered"))
	assert_false(MareBond.done(&"answered"))
	assert_eq(MareBond.hear_range(), 0.0, "before the first ride she doesn't come to the whistle")


func test_no_day_limits_the_bond() -> void:
	assert_false("DAILY" in MareBond, "no daily caps")
	assert_false("POINTS" in MareBond, "no points to grind")
	WorldState.set_flag("fact.mare_ridden", true)
	MareBond.answered()
	MareCare.on_care.append(MareBond.on_care)
	MareCare._tell(&"brushed", 1)
	MareCare._tell(&"honeyplum", 1)
	MareCare.on_care.erase(MareBond.on_care)
	assert_eq(MareBond.tier(), 2, "the deeds alone, all on one day: she trusts Feyre")


func test_each_step_opens_on_its_deeds() -> void:
	WorldState.set_flag("fact.mare_ridden", true)
	MareBond.answered()
	MareBond.on_care(&"brushed", 1)
	assert_eq(MareBond.tier(), 1, "the honeyplum is still to come")
	MareBond.on_care(&"honeyplum", 1)
	assert_eq(MareBond.tier(), 2)
	assert_true(MareBond.can_ride_bareback(), "the saddle can come off now")
	# Step 3: the edge of her range, three places, one unbroken bareback run.
	MareBond.reached_edge()
	for r in [&"rosewild", &"border_woods", &"rosewild", &"eastern_woods"]:
		MareBond.reach_region(r)
	assert_eq(MareBond.places_reached(), 3, "a place counts once")
	MareBond.ride(200.0, true)
	MareBond.ride_ended()
	MareBond.ride(200.0, true)
	assert_eq(MareBond.tier(), 2, "two short bareback rides aren't one long one")
	MareBond.ride(50.0, false)
	assert_eq(MareBond.bareback_run(), 0.0, "the saddle back on ends the run")
	MareBond.ride(310.0, true)
	assert_eq(MareBond.tier(), 3, "300 m unbroken bareback: the third step")
	# Step 4: the blight, the balm, and Calanmai's reunion.
	MareBond.blight_ride(500.0)
	assert_false(MareBond.done(&"blight_ride"), "without the balm she never carries Feyre in")
	assert_true(MareBond.balked())
	assert_false(MareBond.balked(), "the balk counts once")
	assert_eq(MareBond.balks(), 2)
	var bag := Inventory.new()
	assert_false(MareBond.put_balm(bag))
	for id in MareBond.BALM_NEEDS:
		bag.add(id, 1)
	assert_true(MareBond.put_balm(bag))
	assert_true(MareBond.balmed())
	for id in MareBond.BALM_NEEDS:
		assert_eq(bag.count(id), 0, "the balm used its makings")
	MareBond.blight_ride(210.0)
	MareBond.beside()
	assert_eq(MareBond.tier(), 3, "her heart waits for Calanmai")
	WorldState.set_flag("calanmai_attended", true)
	MareBond.beside()
	assert_eq(MareBond.tier(), 4)
	assert_true(is_inf(MareBond.hear_range()) and is_inf(MareBond.carry_range()), "anywhere")
	MareBond.balm_off()
	assert_false(MareBond.balmed())
	for f in raised:
		assert_true(f.begins_with("fact.mare_"), "only mare facts are raised (%s)" % f)


func test_her_page_says_what_to_try_and_remembers() -> void:
	MarePage.reset()
	WorldState.set_flag("fact.mare_ridden", true)
	assert_ne(MarePage.now_line(), "")
	assert_eq(MarePage.current().id, &"answered")
	assert_false(MarePage.can_think(), "no hint before she's tried")
	MarePage.tick(HintLadder.STUCK[0] + 1.0)
	assert_true(MarePage.can_think())
	assert_ne(MarePage.think(), "")
	assert_eq(MarePage.hints_shown().size(), 1)
	MareBond.answered()
	assert_eq(MarePage.current().id, &"gleam", "the page moves on")
	assert_eq(MarePage.memories().size(), 1, "and keeps what's done")
	var d := MarePage.data()
	for step: int in MareBond.MILESTONES:
		for id: StringName in MareBond.MILESTONES[step]:
			var n := d.note(id)
			assert_not_null(n, "a page note for %s" % id)
			if n:
				assert_eq(n.hints.size(), 3, "%s: three hints, gentle to plain" % id)
				assert_ne(n.memory, "")
	assert_eq(d.now.size(), MareBond.TIERS.size())


func test_her_page_and_the_bonds_tab_read_the_same_facts() -> void:
	WorldState.set_flag("wall_crossed", true)
	WorldState.set_flag("first_dinner_eaten", true)
	WorldState.set_flag("fact.mare_ridden", true)
	MareBond.answered()
	MareBond.on_care(&"brushed", 1)
	MareBond.on_care(&"honeyplum", 1)
	var mare: Dictionary = {}
	for b in BondBook.known():
		if b.kind == BondBook.MARE:
			mare = b
	assert_false(mare.is_empty(), "she is in the Bonds tab")
	var shown: Array[String] = []
	for m in BondBook.moments(mare):
		shown.append(String(m.flag))
	for step: int in MareBond.MILESTONES:
		for id: StringName in MareBond.MILESTONES[step]:
			var fact := MareBond.DID_PREFIX + String(id)
			assert_eq(shown.has(fact), MareBond.done(id), "%s: the tab shows it exactly when it's done" % fact)
	assert_eq(MarePage.memories().size(), 3, "her page remembers the same three")
	assert_eq(BondBook.these_days(mare), MarePage.data().now[2], "and both say she trusts Feyre")
	assert_false("bond_done" in str(WorldDeltas.to_dict()), "the old store is gone")


func test_each_step_reaches_farther() -> void:
	var last_hear := -1.0
	var last_carry := -1.0
	for i in range(1, MareBond.TIERS.size()):
		var t: Dictionary = MareBond.TIERS[i]
		assert_gt(float(t["hear"]), last_hear)
		assert_gt(float(t["carry"]), last_carry)
		assert_gte(float(t["carry"]), float(t["hear"]), "she carries Feyre at least as far as she hears her")
		last_hear = float(t["hear"])
		last_carry = float(t["carry"])


func test_she_wears_a_saddle_and_reins_and_can_go_bareback() -> void:
	var horse := HORSE.instantiate() as WhiteHorse
	add_child_autofree(horse)
	await wait_process_frames(2)
	assert_true(MareSaddle.saddled(horse), "the generator saddle is on her")
	var mi := MareSaddle.mesh_of(horse)
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		var n := String(m.resource_name) if m else ""
		assert_false(n in MareSaddle.DROP_SURFACES, "the old flat seat is gone (%s)" % n)
	assert_lt(horse.bits[0].x, 0.0, "her left bit ring found")
	assert_gt(horse.bits[1].x, 0.0, "her right bit ring found")
	assert_not_null(horse.get_node_or_null(^"MareReins"))
	var seat := horse.seat_point()
	MareSaddle.set_saddled(horse, false)
	assert_false(MareSaddle.saddled(horse))
	assert_true(horse.bareback)
	assert_lt(horse.seat_point().y, seat.y, "bareback she sits lower, on the mare's back")


func test_her_hands_hold_the_reins() -> void:
	var horse := HORSE.instantiate() as WhiteHorse
	add_child_autofree(horse)
	var rider := Rider.new()
	add_child_autofree(rider)
	rider.model = FEYRE_MODEL.instantiate() as Node3D
	rider.add_child(rider.model)
	await wait_process_frames(2)
	var pose := Saddle.seat(rider)
	var sk := Saddle.skeleton_of(rider)
	var got := {}
	var read := func() -> void:
		got["l"] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(&"LeftHand")).origin
		got["r"] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(&"RightHand")).origin
		got["hips"] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(&"Hips")).origin
	sk.skeleton_updated.connect(read)
	for i in 20:
		Saddle.place(rider, horse)
		await wait_process_frames(1)
	sk.skeleton_updated.disconnect(read)
	assert_almost_eq(pose.reins, 1.0, 0.01)
	assert_false(got.is_empty(), "the skeleton updated")
	if got.is_empty():
		return
	assert_lt((got["l"] as Vector3).distance_to(horse.rein_grip(true)), 0.08, "left hand on the rein")
	assert_lt((got["r"] as Vector3).distance_to(horse.rein_grip(false)), 0.08, "right hand on the rein")
	var centre := horse.on_back(MareSaddle.CENTRE)
	var off := (got["hips"] as Vector3) - centre
	off.y = 0.0
	assert_lt(off.length(), 0.05, "her pelvis over the saddle centre")
