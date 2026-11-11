# gate: needs:terrain
# gate: when:characters/*,core/*,story/*,world/*,systems/*,creatures/*,ui/*,data/*,tests/integration/play/*
## Play test (T097): sitting and standing, the one place the game seats her in
## free play so far: the first dinner (story/act2/first_dinner.gd). Continue
## from a save after Alis's bath, in the dining hall; walk to the table, to her
## chair, try to get up (one shove), E until the plate is clear, stand and walk
## away, all with real key and pad events. The woods have no seat to sit on.
extends GutTest

const PlayHarness := preload("res://tests/integration/play/play_harness.gd")
const SLOT := "gut_play_sit"
## In the dining hall between its door and the table: the scene's anchor
## (manor_dining_table, 21, -31.5 on the ground floor) is at the door, the table
## 6.5 m in, and the scene begins within 3 m of the anchor.
const DINING := [21.0, 8.9, -36.0]
const SAVE := {
	"version": 2,
	"clock": {"day": 2, "time_of_day": 0.8},
	"world_state": {"flags": {"wolf_killed": true, "fact.wolf_skinned": true, "fact.wolf_spotted": true,
		"pelt_sold": true, "beast_claim_accepted": true, "wall_crossed": true, "fact.manor_arrived": true,
		"fact.alis_bathed": true}},
	"phase": {"phase": "p2_grounds", "phase_set": "res://data/phases/spring_court_phases.tres",
		"unlocked_regions": ["manor_estate", "manor_grounds", "manor_house"]},
	"world_deltas": {},
	"providers": {"player_placement": {"position": DINING, "yaw": 0.0}},
}

var h: PlayHarness
var booted := false


func before_all() -> void:
	h = PlayHarness.new(self)
	booted = await h.boot_from_save(SLOT, SAVE)


func after_all() -> void:
	SaveSystem.delete_save(SLOT)
	await h.shutdown()
	h.dispose()


func after_each() -> void:
	h.release_all()


func _dinner() -> FirstDinner:
	var found: Array[FirstDinner] = []
	var walk := func(self_ref: Callable, n: Node) -> void:
		if n is FirstDinner:
			found.append(n)
			return
		for c in n.get_children():
			self_ref.call(self_ref, c)
	walk.call(walk, h.game)
	return found[0] if not found.is_empty() else null


func _beat(d: FirstDinner) -> String:
	return d.current_beat_label() if d and d.running else ""


func test_she_sits_at_the_first_dinner_and_stands_after() -> void:
	if not booted:
		pending("Continue never gave her control")
		return
	var dinner := _dinner()
	assert_not_null(dinner, "the first dinner hangs on the dining table")
	if dinner == null:
		return
	# Walk across the hall toward the door: within 3 m of it the scene starts.
	await h.walk_to(dinner.global_position, 2.0, 600, false, 0.6)
	var began := await h.wait_until(func() -> bool: return _beat(dinner).begins_with("reach feyre_chair"), 60 * 40)
	assert_true(began, "walking in the dining hall begins the dinner (beat '%s', at %s)" % [_beat(dinner), h.feyre.global_position])
	if not began:
		return
	# Walk to her chair: she sits.
	await h.walk_to(dinner.mark(&"feyre_chair"), 1.0, 60 * 20, false, 0.6)
	var sat := await h.wait_until(func() -> bool: return dinner.seated, 60 * 40)
	assert_true(sat, "at her chair she sits (%.2f m off it, beat '%s')" % [
			PlayHarness.flat_distance(h.feyre.global_position, dinner.mark(&"feyre_chair")), _beat(dinner)])
	if not sat:
		return
	assert_false(StoryControl.can_move(), "seated, the stick does not walk her off")
	var seat_at := h.feyre.global_position
	# Try to get up: one invisible shove, then she is held.
	# Her temper rises on its own RISE_AFTER s into that beat, so on a slow
	# frame the shove may already have come: then the push just meets the hold.
	assert_true(await h.wait_until(func() -> bool: return _beat(dinner) == "until she rises" or dinner.held, 60 * 90),
			"the talk at table runs to her temper (beat '%s')" % _beat(dinner))
	var pushed_first := not dinner.held
	await h.hold_for(&"move_forward", 10)
	var held := await h.wait_until(func() -> bool: return dinner.held, 60 * 10)
	assert_true(held, "pushing to stand brings the shove that holds her (pushed before her temper: %s)" % pushed_first)
	assert_eq(dinner.shoves, 1, "one shove only")
	assert_lt(PlayHarness.flat_distance(seat_at, h.feyre.global_position), 0.3, "and she stays in the chair")
	if not held:
		return
	# E until the plate is clear and the torte vanishes.
	assert_true(await h.wait_until(func() -> bool: return _beat(dinner) == "until her first bite", 60 * 60),
			"the held lines run to the first bite (beat '%s')" % _beat(dinner))
	for i in 8:
		if dinner.torte_gone:
			break
		await h.press(&"interact")
		await wait_process_frames(24)
	assert_true(dinner.torte_gone, "E eats the plate clear and reaches for the torte (bites %d)" % dinner.bites)
	# She stands: the controls come back and her body leaves the chair pose.
	var stood := await h.wait_until(func() -> bool: return not dinner.seated and StoryControl.can_move(), 60 * 30)
	assert_true(stood, "after the meal she stands and can walk (beat '%s')" % _beat(dinner))
	if not stood:
		return
	assert_eq(h.feyre.model.position, Vector3.ZERO, "her model is back on her body")
	var before := h.feyre.global_position
	await h.hold_for(&"move_back", 40)
	assert_gt(PlayHarness.flat_distance(before, h.feyre.global_position), 0.5,
			"and she walks away from the table")
