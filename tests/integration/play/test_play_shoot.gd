# gate: needs:terrain
# gate: when:systems/bow/*,data/bows/*,data/arrows/*,characters/feyre/feyre.gd,tests/integration/play/play_harness.gd
## Play test (T111): the bow with real input, in the woods (New Game) and in
## the Spring Court (Continue). Hold right mouse to raise the bow; hold left
## mouse to draw (BowData.draw_time) and let go to loose one full-power arrow;
## the bow stays up for the next; letting go of aim lowers it and shoots
## nothing; Q cycles owned types.
extends GutTest

const PlayHarness := preload("res://tests/integration/play/play_harness.gd")
const COURT_SLOT := "gut_play_shoot_court"
const BEDROOM := [20.15, 13.7, -63.54]
const COURT_SAVE := {
	"version": 2,
	"clock": {"day": 5, "time_of_day": 0.4},
	"world_state": {"flags": {"wolf_killed": true, "fact.wolf_skinned": true, "fact.wolf_spotted": true,
		"pelt_sold": true, "beast_claim_accepted": true, "wall_crossed": true, "fact.manor_arrived": true,
		"fact.alis_bathed": true, "first_dinner_eaten": true, "fact.mare_ridden": true}},
	"phase": {"phase": "p2_grounds", "phase_set": "res://data/phases/spring_court_phases.tres",
		"unlocked_regions": ["manor_estate", "manor_grounds", "manor_house"]},
	"world_deltas": {},
	"providers": {"player_placement": {"position": BEDROOM, "yaw": 0.0}},
}

var h: PlayHarness
var booted := false
var fired: Array[float] = []  ## launch speed of each arrow loosed


func before_all() -> void:
	h = PlayHarness.new(self)
	booted = await h.boot_new_game()


func after_all() -> void:
	SaveSystem.delete_save(COURT_SLOT)
	await h.shutdown()
	h.dispose()


func before_each() -> void:
	h.require_control(booted)
	h.release_all()


func after_each() -> void:
	h.release_all()


func _bow() -> BowController:
	return h.feyre.bow_controller


func _on_arrow(arrow: Arrow) -> void:
	fired.append(arrow.linear_velocity.length())


## Hold right mouse until the bow is up with an arrow on the string.
func _raise() -> bool:
	h.hold(&"aim")
	return await h.wait_until(func() -> bool: return _bow().is_nocked, 30)


## Hold left mouse through a full draw, then let go.
func _draw_and_loose() -> void:
	h.hold(&"fire")
	await h.wait_until(func() -> bool: return _bow().draw_amount >= 1.0, 120)
	h.release(&"fire")
	await h.settle()


## The whole bow story, where she stands now.
func _play_the_bow() -> void:
	var bc := _bow()
	# Setup: arrows to spend, and a second type for Q to land on.
	# A full quiver, whatever the chapter gives her: this is about the bow.
	Gameplay.inventory.carry_quiver(Inventory.FULL_QUIVER)
	Gameplay.inventory.add(&"arrow_wood", 6)
	Gameplay.inventory.add(&"arrow_ash", 2)
	bc.selected = &"arrow_wood"
	fired.clear()
	h.feyre.arrow_fired.connect(_on_arrow)
	var start := Gameplay.inventory.arrow_count(&"arrow_wood")

	# Raise: the bow comes up with an arrow on the string, and nothing flies.
	assert_true(await _raise(), "holding aim raises the bow")
	assert_false(bc.is_drawing, "the string waits for left mouse")
	assert_eq(fired.size(), 0, "nothing has been loosed by raising")

	# A quick tap is an early release: the string comes down, no weak shot.
	await h.press(&"fire", 2)
	await wait_physics_frames(30)
	assert_eq(fired.size(), 0, "a tap looses nothing")
	assert_eq(Gameplay.inventory.arrow_count(&"arrow_wood"), start, "and costs nothing")

	# Hold to full draw, let go: one full-power arrow.
	await _draw_and_loose()
	assert_eq(fired.size(), 1, "a full draw looses one arrow")
	assert_eq(Gameplay.inventory.arrow_count(&"arrow_wood"), start - 1, "and costs one arrow")
	if fired.size() > 0:
		assert_almost_eq(fired[0], bc.bow.max_speed, bc.bow.max_speed * 0.02, "at full power")

	# The bow stays up with aim held, and the next draw looses the next arrow.
	assert_true(bc.is_aiming, "after a shot the bow stays up")
	await _draw_and_loose()
	assert_eq(fired.size(), 2, "a second draw looses a second arrow")
	assert_eq(Gameplay.inventory.arrow_count(&"arrow_wood"), start - 2, "two arrows spent")

	# Let go of aim mid-draw: the bow lowers and looses nothing.
	h.hold(&"fire")
	await h.wait_until(func() -> bool: return bc.draw_amount >= 1.0, 120)
	h.release(&"aim")
	await h.settle()
	h.release(&"fire")
	await h.settle()
	await wait_physics_frames(2)
	assert_false(bc.is_aiming, "letting go of aim lowers the bow")
	assert_eq(fired.size(), 2, "and looses nothing")
	assert_eq(Gameplay.inventory.arrow_count(&"arrow_wood"), start - 2, "no arrow spent")

	# Q cycles to the next arrow type she owns, and round again.
	var first := bc.selected
	await h.press(&"cycle_arrow", 2)
	assert_ne(bc.selected, first, "Q picks the next arrow type she owns")
	assert_gt(Gameplay.inventory.arrow_count(bc.selected), 0, "one she actually has")
	await h.press(&"cycle_arrow", 2)
	assert_eq(bc.selected, first, "and Q again comes back round")

	h.feyre.arrow_fired.disconnect(_on_arrow)


func test_woods_the_bow_raises_draws_looses_and_lowers() -> void:
	if not booted:
		return
	assert_true(h.on_solid_ground() or await h.wait_still(120), "standing in the woods")
	await _play_the_bow()


func test_court_the_bow_raises_draws_looses_and_lowers() -> void:
	if not booted:
		return
	await h.shutdown()
	booted = await h.boot_from_save(COURT_SLOT, COURT_SAVE)
	assert_true(booted, "Continue puts her in the Spring Court")
	if not booted:
		return
	assert_true(await h.wait_still(120), "standing in the manor")
	await _play_the_bow()
