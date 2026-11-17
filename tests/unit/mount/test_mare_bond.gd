extends GutTest
## Contract test for the white mare's bond (L47-8, docs/contracts/mare_bond.md):
## deeds earn capped points, each step needs its points and its deed, the steps
## widen how far she hears the whistle and carries Feyre, and the bond only ever
## raises `fact.mare_bond_*` facts, never a phase flag (R2). Also the saddle and
## reins she wears for it.

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
	MareBond.raise = func(fact: String) -> void:
		raised.append(fact)
		WorldState.set_flag(fact, true)


func after_each() -> void:
	MareBond.raise = Callable()


func test_nothing_counts_before_she_is_ridden() -> void:
	WorldState.set_flag("first_dinner_eaten", true)
	assert_eq(MareBond.tier(), 0)
	assert_eq(MareBond.earn(&"treat"), 0)
	assert_eq(MareBond.points(), 0)
	assert_eq(MareBond.hear_range(), 0.0, "before the first ride she doesn't come to the whistle")


func test_deeds_are_capped_each_day() -> void:
	WorldState.set_flag("fact.mare_ridden", true)
	for i in 5:
		MareBond.earn(&"treat")
	assert_eq(MareBond.points(), 3, "three treats a day count")
	for i in 4:
		MareBond.earn(&"answered")
	assert_eq(MareBond.points(), 5, "two answered whistles a day")
	MareBond.ride(MareBond.RIDE_STEP * 20.0, false)
	assert_eq(MareBond.points(), 5 + 8, "eight ride points a day")
	assert_true(MareBond.reach_region(&"woods"))
	assert_false(MareBond.reach_region(&"woods"), "a region counts once")


func test_the_steps_need_points_and_their_deeds() -> void:
	WorldState.set_flag("fact.mare_ridden", true)
	WorldDeltas.set_region_value(&"mount", "bond_points", 11)
	assert_eq(MareBond.check(), -1)
	MareBond.earn(&"treat")
	assert_eq(MareBond.tier(), 2, "12 points: she trusts Feyre")
	assert_true(MareBond.can_ride_bareback(), "the saddle can come off now")
	WorldDeltas.set_region_value(&"mount", "bond_points", 40)
	assert_eq(MareBond.check(), -1, "points alone don't make the bareback step")
	MareBond.ride(310.0, true)
	assert_eq(MareBond.tier(), 3, "300 m bareback: the third step")
	WorldDeltas.set_region_value(&"mount", "bond_points", 80)
	assert_eq(MareBond.check(), -1, "her heart waits for Calanmai")
	WorldState.set_flag("calanmai_attended", true)
	MareBond.check()
	assert_eq(MareBond.tier(), 4)
	assert_true(is_inf(MareBond.hear_range()) and is_inf(MareBond.carry_range()), "anywhere")
	for f in raised:
		assert_true(f.begins_with("fact.mare_bond_"), "only bond facts are raised (%s)" % f)


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
