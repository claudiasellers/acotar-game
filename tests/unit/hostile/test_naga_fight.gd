## H2: the naga fight (docs/contracts/hostiles.md, health-interactions §3.2,
## §3.4, §11). Done-whens: 4 naga never strike more than 2 at once over 60 s;
## standing still in a 4-naga camp takes at least 4 s to put her down; the
## claw is a claw; the coil comes only from behind and its failure is a claw
## x1.5; the lunge opens the camp's fight once.
extends GutTest

const SITE_SCRIPT := preload("res://creatures/hostile/hostile_site.gd")
const BodyTick := preload("res://tests/fixtures/body_tick.gd")
const ROAMER := preload("res://creatures/hostile/naga_roamer.tscn")
const DT := 1.0 / 30.0
const ATTACKING := [NagaRoamer.Fight.STRIKE, NagaRoamer.Fight.LUNGE, NagaRoamer.Fight.LEAP, NagaRoamer.Fight.HOLD]


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
var v: VitalsState
var hits: Array = []


func before_each() -> void:
	StoryControl.release()
	hits.clear()
	# In the gate's long shared run an earlier file can leave a body in group
	# player (an orphan Feyre); a naga hunts the first one it finds, so only
	# hers may be in it here.
	for stale in get_tree().get_nodes_in_group(&"player"):
		stale.remove_from_group(&"player")
	her = FakeHer.new()
	her.add_to_group(&"player")
	add_child_autofree(her)
	her.body_state = BodyState.new()
	her.body_state.name = "BodyState"
	her.add_child(her.body_state)
	her.body_state.set_physics_process(false)
	v = VitalsState.new()
	v.name = "Vitals"
	v.player = her
	her.body_state.vitals = v
	her.add_child(v)
	v.set_physics_process(false)
	EventBus.player_hit.connect(_on_hit)


func after_each() -> void:
	if EventBus.player_hit.is_connected(_on_hit):
		EventBus.player_hit.disconnect(_on_hit)
	StoryControl.release()
	WorldState.clear()


func _on_hit(source_id: StringName, attack_id: StringName, scale: float, _origin: Vector3) -> void:
	hits.append([source_id, attack_id, scale])


## A ground to stand on at `at`.
func _floor(at: Vector3) -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	ground.add_child(shape)
	add_child_autofree(ground)
	ground.global_position = at + Vector3(0, -0.5, 0)


## The Reed Marsh camp (4 members on an 8 m ring), with her at its core. By
## default the camp is moved to the origin; `at_core` keeps it at the real core
## (1180, 330). Either way its members take no collisions and stand on a flat
## height: these ticks are about the brains, not the ground.
func _camp(at_core := false) -> HostileSite:
	var d := (load("res://data/creatures/hostile_sites/naga_reed_marsh.tres") as HostileSiteData).duplicate() as HostileSiteData
	if not at_core:
		d.core = Vector2.ZERO
	var site := SITE_SCRIPT.new() as HostileSite
	site.data = d
	site.snap_to_core = at_core
	site.height_func = func(_x: float, _z: float) -> float: return 0.0
	add_child_autofree(site)
	site.set_physics_process(false)
	for m in site.members:
		m.set_physics_process(false)
		m.navigate = false
		m.collision_layer = 0
		m.collision_mask = 0
	her.global_position = site.global_position
	return site


## Keeps a body on the ground plane: a floor added this frame isn't in the
## physics space until a physics step, and these ticks run between steps.
func _ground(c: Creature) -> void:
	c.global_position.y = 0.0
	c.velocity.y = 0.0


## One tick of the camp: every member knows where she is. BodyTick steps each
## by DT: move_and_slide alone would move it by the engine's delta.
func _tick(site: HostileSite) -> void:
	for m in site.members:
		if is_instance_valid(m) and m.alive:
			m.senses.awareness = 1.0
			BodyTick.tick(m, DT)
			_ground(m)
	v._iframes = maxf(v._iframes - DT, 0.0)
	v._step_grab(DT)


## Why, for a rejection log read without the machine: each member's fight
## state, ladder, flat distance to her, height, token, and the hits so far.
func _why(site: HostileSite, ticks: int) -> String:
	var hunted := get_tree().get_first_node_in_group(&"player")
	var out := "after %d ticks (%.1f s), her at %s (hunted is her: %s), grabbed=%s down=%s; hits %s; " % [
		ticks, ticks * DT, her.global_position, hunted == her, v.is_grabbed(), v.is_down, hits]
	for m in site.members:
		var r := m as NagaRoamer
		if r == null or not is_instance_valid(r):
			continue
		out += "[%s alive=%s fight=%s ladder=%s flat=%.2f dy=%.2f token=%s flee=%.1f stagger=%.1f] " % [
			r.name, r.alive, NagaRoamer.Fight.keys()[r.fight], HostileLadder.State.keys()[r.ladder.state],
			Creature.flat_distance(r.global_position, her.global_position), r.global_position.y - her.global_position.y,
			r.has_token(), r._flee_left, r.stagger_left]
	return out


func _attacking(site: HostileSite) -> int:
	var n := 0
	for m in site.members:
		var r := m as NagaRoamer
		if r and r.alive and ATTACKING.has(r.fight):
			n += 1
	return n


func test_four_naga_never_attack_more_than_two_at_once() -> void:
	var site := _camp()
	assert_eq(site.members.size(), 4)
	assert_eq(site.token_count(), 2)
	var most_tokens := 0
	var ticks := 0
	for i in int(60.0 / DT):
		ticks += 1
		v.health = VitalsState.MAX_HEALTH
		_tick(site)
		var n := _attacking(site)
		var held := site.token_holders().size()
		most_tokens = maxi(most_tokens, held)
		assert_lte(n, 2, "at most two attack at once (tick %d)" % i)
		assert_lte(held, 2)
		if n > 2:
			break
	assert_eq(most_tokens, 2, "both tokens get used")
	assert_gt(hits.size(), 4, "they do fight: " + _why(site, ticks))


func test_standing_still_takes_at_least_four_seconds() -> void:
	var site := _camp()
	var first := -1.0
	var t := 0.0
	var ticks := 0
	while t < 40.0 and not v.is_down:
		_tick(site)
		t += DT
		ticks += 1
		if first < 0.0 and v.health < VitalsState.MAX_HEALTH:
			first = t
	assert_true(v.is_down, "a 4-naga camp does put her down: health %.0f, " % v.health + _why(site, ticks))
	assert_gt(first, 0.0)
	assert_gte(t - first, 4.0, "from the first wound to the ground is at least 4 s")


## The same camp at its real core in Reed Marsh fights the same: nothing about
## the place (leash, ring, far-from-origin floats) keeps it off her.
func test_the_real_reed_marsh_camp_fights_at_its_core() -> void:
	var site := _camp(true)
	assert_almost_eq(site.global_position.x, 1180.0, 0.01)
	assert_almost_eq(site.global_position.z, 330.0, 0.01)
	var ticks := 0
	while ticks < int(40.0 / DT) and not v.is_down:
		_tick(site)
		ticks += 1
	assert_gt(hits.size(), 4, "the real camp does fight: " + _why(site, ticks))
	assert_true(v.is_down, "the real camp puts her down: health %.0f, " % v.health + _why(site, ticks))


func test_the_lunge_opens_the_fight_once() -> void:
	var site := _camp()
	for i in int(20.0 / DT):
		v.health = VitalsState.MAX_HEALTH
		_tick(site)
	var lunges := hits.filter(func(h: Array) -> bool: return h[1] == NagaRoamer.LUNGE_ATTACK)
	assert_lte(lunges.size(), 1, "one naga bursts out, not four")
	assert_false(site.lunge_ready())


func test_the_claw_row() -> void:
	var row := AttackTable.resolve(&"naga")
	assert_eq(row.id, &"naga_claw")
	assert_eq(row.damage_kind, &"claw")
	assert_almost_eq(row.damage, 22.0, 0.001)
	assert_eq(AttackTable.resolve(&"naga_lunge").damage_kind, &"blunt")
	assert_false(ResourceLoader.exists("res://data/combat/attacks/naga_bite.tres"))
	var gen := FileAccess.get_file_as_string("res://tools/vitals/gen_attack_rows.gd")
	assert_false(gen.contains("naga_bite"))


## A lone naga (no site) at `at`, engaged and facing her.
func _naga(at: Vector3) -> NagaRoamer:
	_floor(Vector3.ZERO)
	var n := ROAMER.instantiate() as NagaRoamer
	n.creature_id = &"naga_lone"
	add_child_autofree(n)
	n.set_physics_process(false)
	n.navigate = false
	n.collision_layer = 0
	n.collision_mask = 0
	n.global_position = at
	return n


func _run(n: NagaRoamer, seconds: float) -> void:
	for i in int(seconds / DT):
		n.senses.awareness = 1.0
		BodyTick.tick(n, DT)
		_ground(n)
		v._iframes = maxf(v._iframes - DT, 0.0)
		v._step_grab(DT)


func test_in_front_it_claws() -> void:
	her.global_position = Vector3.ZERO
	var n := _naga(Vector3(0, 0, -1.2))
	_run(n, 3.0)
	assert_false(v.is_grabbed())
	assert_true(hits.any(func(h: Array) -> bool: return h[1] == NagaRoamer.CLAW and is_equal_approx(float(h[2]), 1.0)))


func test_from_behind_it_coils_and_a_held_coil_ends_in_a_heavy_claw() -> void:
	her.global_position = Vector3.ZERO
	var n := _naga(Vector3(0, 0, 1.2))
	var held := false
	for i in int(3.0 / DT):
		_run(n, DT)
		held = held or v.is_grabbed()
		if held:
			break
	assert_true(held, "behind her it coils")
	assert_eq(v.grab_source, &"naga_lone")
	assert_eq(n.fight, NagaRoamer.Fight.HOLD)
	_run(n, AttackTable.resolve(NagaRoamer.COIL).grab_seconds + 0.2)
	assert_false(v.is_grabbed())
	assert_true(hits.any(func(h: Array) -> bool: return h[1] == NagaRoamer.CLAW \
			and is_equal_approx(float(h[2]), AttackTable.resolve(NagaRoamer.COIL).grab_fail_scale)), "she didn't break it")


func test_breaking_the_coil_spares_the_claw() -> void:
	her.global_position = Vector3.ZERO
	var n := _naga(Vector3(0, 0, 1.2))
	for i in int(3.0 / DT):
		_run(n, DT)
		if v.is_grabbed():
			break
	assert_true(v.is_grabbed())
	for p in AttackTable.resolve(NagaRoamer.COIL).grab_presses:
		v.press_break_free()
	assert_false(v.is_grabbed())
	assert_eq(n.fight, NagaRoamer.Fight.RECOVER)
	_run(n, 1.0)
	assert_false(hits.any(func(h: Array) -> bool: return float(h[2]) > 1.0))


func test_a_stagger_lets_go_of_the_coil() -> void:
	her.global_position = Vector3.ZERO
	var n := _naga(Vector3(0, 0, 1.2))
	for i in int(3.0 / DT):
		_run(n, DT)
		if v.is_grabbed():
			break
	assert_true(v.is_grabbed())
	n.stagger(1.0)
	assert_false(v.is_grabbed(), "it lets go at once")
	assert_eq(n.fight, NagaRoamer.Fight.RECOVER)


func test_a_held_her_keeps_the_others_off() -> void:
	her.global_position = Vector3.ZERO
	var n := _naga(Vector3(0, 0, -1.2))
	EventBus.player_grabbed.emit(&"someone_else", 6, 10.0)
	_run(n, 2.0)
	assert_eq(n.fight, NagaRoamer.Fight.CIRCLE)
	assert_true(hits.is_empty())
	EventBus.player_released.emit(&"someone_else")


## Every creature move carries its tell on its row, at or over the floor for
## its reaction (health-interactions §3.5 #4); hazards have none.
func test_every_move_has_its_wind_up_on_its_row() -> void:
	var floors := {&"light": 0.4, &"medium": 0.55, &"heavy": 0.8, &"none": 0.6}
	for f in DirAccess.get_files_at("res://data/combat/attacks/"):
		if not f.ends_with(".tres"):
			continue
		var row := load("res://data/combat/attacks/" + f) as AttackData
		if row.family == &"":
			assert_eq(row.windup_s, 0.0, "%s is a hazard: no tell" % row.id)
		else:
			assert_gte(row.windup_s, float(floors[row.reaction]), "%s tells at least the %s floor" % [row.id, row.reaction])
	assert_almost_eq(NagaRoamer.windup_of(NagaRoamer.CLAW), 0.55, 0.001)
	assert_almost_eq(NagaRoamer.windup_of(NagaRoamer.LUNGE_ATTACK), 0.8, 0.001)
	assert_almost_eq(NagaRoamer.windup_of(NagaRoamer.COIL), 0.6, 0.001)
	assert_false(FileAccess.get_file_as_string("res://creatures/hostile/naga_roamer.gd").contains("const WINDUP"), "one home: the row")


func test_a_naga_on_a_ledge_above_her_cant_reach_her() -> void:
	her.global_position = Vector3(0, -2, 0)
	var n := _naga(Vector3(0, 0, -1.2))
	_run(n, 3.0)
	assert_true(hits.is_empty(), "2 m of height between them: no claw lands")
	assert_false(v.is_grabbed())
