## Slice 1 done-whens (b) and (c) (hostile-fae plan §8.4 item 1), at the real
## Reed Marsh camp (1180, 330), with no World:
## (b) a hush draught makes a pack trailing her by scent lose her within 20 s
##     in at least 9 of 10 seeded runs (and without it they stay on her);
## (c) a lure arrow draws the camp into the reeds, a fire arrow lights the bed,
##     and every naga flees or dies within REED_FIRE_CLEAR_S (docs/tuning.md,
##     "Hostile checks").
## Bodies step with BodyTick; the senses, the field and the brains are ticked
## by hand at DT.
extends GutTest

const SITE_SCRIPT := preload("res://creatures/hostile/hostile_site.gd")
const SITE_DATA := preload("res://data/creatures/hostile_sites/naga_reed_marsh.tres")
const BodyTick := preload("res://tests/fixtures/body_tick.gd")
const DT := 1.0 / 30.0
const RUNS := 10
const LOSE_WITHIN_S := 20.0
## Her pace away from the pack (a careful walk) and how far behind they trail.
const HER_PACE := 1.5
const TRAIL_MIN := 8.0
const TRAIL_MAX := 14.0
## docs/tuning.md "Hostile checks": a lured naga stands within 1 m of the lure
## and fears flame within 3 m, so it sees the fire on its first scan (0.3 s);
## one that wandered to 5 m waits for the front to cross 2 m at about
## 1 / HEAT_RATE (1.1 s) a metre: 0.3 + 2.2 = 2.5 s, rounded up.
const REED_FIRE_CLEAR_S := 3.0
const REED_BED_RADIUS := 5.0


class FakeHer:
	extends CharacterBody3D
	var body_state: BodyState
	var is_aiming: bool = false
	var stamina: float = 100.0
	var max_stamina: float = 100.0

	func drain_stamina(amount: float) -> void:
		stamina -= amount

	func is_winded() -> bool:
		return stamina <= 0.0


var her: FakeHer


func before_each() -> void:
	StoryControl.release()
	for stale in get_tree().get_nodes_in_group(&"player"):
		stale.remove_from_group(&"player")
	her = FakeHer.new()
	her.add_to_group(&"player")
	add_child_autofree(her)
	her.body_state = BodyState.new()
	her.body_state.name = "BodyState"
	her.add_child(her.body_state)
	her.body_state.set_physics_process(false)


func after_each() -> void:
	StoryControl.release()
	WorldState.clear()


## The camp at its real core, members brain-ticked by hand.
func _camp() -> HostileSite:
	var d := SITE_DATA.duplicate() as HostileSiteData
	var site := SITE_SCRIPT.new() as HostileSite
	site.data = d
	site.height_func = func(_x: float, _z: float) -> float: return 0.0
	add_child(site)
	site.set_physics_process(false)
	for m in site.members:
		m.set_physics_process(false)
		m.senses.set_physics_process(false)
		m.navigate = false
		m.collision_layer = 0
		m.collision_mask = 0
	return site


func _tick(site: HostileSite, field: ElementField = null) -> void:
	if field:
		field.step(DT)
	for m in site.members:
		if not is_instance_valid(m) or not m.alive:
			continue
		m.senses._physics_process(DT)
		BodyTick.tick(m, DT)
		m.global_position.y = 0.0
		m.velocity.y = 0.0


func _hostile_count(site: HostileSite) -> int:
	var n := 0
	for m in site.members:
		var r := m as NagaRoamer
		if r and r.alive and r.ladder.is_hostile():
			n += 1
	return n


## One seeded run: the pack engaged and trailing her on her scent past the
## leash, with or without the draught. Returns the seconds until no member is
## hostile, or INF if they were still on her at LOSE_WITHIN_S.
func _trail_run(run_seed: int, hushed: bool) -> float:
	seed(run_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var site := _camp()
	var away := Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU)
	her.global_position = site.global_position + away * (site.leash_radius() + rng.randf_range(10.0, 25.0))
	var blind := (site.members[0] as Creature).data.duplicate() as CreatureData
	blind.sight_range = 0.0  # trailing by scent alone: she's out of sight
	for m in site.members:
		var r := m as NagaRoamer
		r.data = blind
		var side := away.cross(Vector3.UP) * rng.randf_range(-3.0, 3.0)
		r.global_position = her.global_position - away * rng.randf_range(TRAIL_MIN, TRAIL_MAX) + side
		r.ladder.state = HostileLadder.State.ENGAGED
		r.senses.awareness = 1.0
		r._last_awareness = 1.0
		r._trail_left = NagaRoamer.TRAIL_SECONDS
	if hushed:
		her.body_state.add_effect(&"quiet", 2.0, 120.0)
	var t := 0.0
	var lost_at := INF
	while t < LOSE_WITHIN_S:
		her.global_position += away * HER_PACE * DT
		_tick(site)
		t += DT
		if _hostile_count(site) == 0:
			if lost_at == INF:
				lost_at = t
		else:
			lost_at = INF
	site.free()
	her.body_state.effects.clear()
	return lost_at


func test_a_hush_draught_loses_a_trailing_pack_in_nine_of_ten() -> void:
	her.body_state.add_effect(&"quiet", 2.0, 120.0)
	assert_lte(Vitals.scent_scale(her), NagaRoamer.HUSH_SCALE, "the draught (quiet 2) is a hush")
	her.body_state.effects.clear()
	var lost := 0
	var times := []
	for i in RUNS:
		var at := _trail_run(7100 + i, true)
		times.append(at)
		if at <= LOSE_WITHIN_S:
			lost += 1
	assert_gte(lost, 9, "lost her in %d of %d runs (s: %s)" % [lost, RUNS, times])


func test_without_the_draught_they_stay_on_her() -> void:
	var kept := 0
	for i in RUNS:
		if _trail_run(7100 + i, false) == INF:
			kept += 1
	assert_gte(kept, 9, "the scent alone keeps the trail in %d of %d runs" % [kept, RUNS])


func test_lure_and_fire_burn_the_reed_bed_and_the_pack_flees_or_dies() -> void:
	seed(7200)
	var field := ElementField.new()
	field.follow_world_wind = false
	add_child_autofree(field)
	field.set_physics_process(false)
	var site := _camp()
	var bed := site.global_position
	var cells := field.add_patch(bed, REED_BED_RADIUS, &"grass", 1.0)
	# She's far off and unseen: the camp is calm when the lure lands.
	her.global_position = bed + Vector3(0, 0, 90)
	Creature.lure(get_tree(), bed)
	var t := 0.0
	var drawn := false
	while t < 12.0 and not drawn:
		_tick(site, field)
		t += DT
		drawn = site.members.all(func(m: Node) -> bool:
			return Creature.flat_distance((m as Node3D).global_position, bed) <= 2.0)
	assert_true(drawn, "the lure draws all four into the reeds (%.1f s)" % t)
	assert_eq(_hostile_count(site), 0, "still calm: they came for the lure")
	assert_gt(field.ignite_at(bed, 0.8), 0, "the fire arrow lights the bed")
	var cleared := {}
	t = 0.0
	while t < REED_FIRE_CLEAR_S and cleared.size() < site.members.size():
		_tick(site, field)
		t += DT
		for m in site.members:
			var r := m as NagaRoamer
			if not r.alive or r._flee_left > 0.0:
				cleared[r.creature_id] = true
	assert_eq(cleared.size(), site.members.size(),
			"every naga fled or died within %.1f s (%.1f s)" % [REED_FIRE_CLEAR_S, t])
	# The bed burns through.
	var burnt := 0
	for i in int(20.0 / DT):
		field.step(DT)
	for id in cells:
		if field.is_burnt(id):
			burnt += 1
	assert_gt(burnt, cells.size() / 2, "the reed bed burns (%d of %d)" % [burnt, cells.size()])
	site.free()
