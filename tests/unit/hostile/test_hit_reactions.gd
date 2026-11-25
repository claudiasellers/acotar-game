## HF hit reactions (health-interactions §3.5 item 7, §3.5 done-whens): every
## hit flinches (0.25 s, a 0.3 m push off the weak spot) and the brain keeps
## going; a weak-spot hit staggers 0.8 s and cancels the wind-up in progress,
## whose length is the row's windup_s. creature_hit stays one emit per hit
## (L80's HitStop listens to it).
extends GutTest

const ROAMER := preload("res://creatures/hostile/naga_roamer.tscn")
const DEER := preload("res://creatures/prey/deer.tscn")
const BodyTick := preload("res://tests/fixtures/body_tick.gd")
const DT := 1.0 / 30.0


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
var creature_hits: Array = []


func before_each() -> void:
	StoryControl.release()
	hits.clear()
	creature_hits.clear()
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
	her.global_position = Vector3.ZERO
	EventBus.player_hit.connect(_on_hit)
	EventBus.creature_hit.connect(_on_creature_hit)


func after_each() -> void:
	if EventBus.player_hit.is_connected(_on_hit):
		EventBus.player_hit.disconnect(_on_hit)
	if EventBus.creature_hit.is_connected(_on_creature_hit):
		EventBus.creature_hit.disconnect(_on_creature_hit)
	StoryControl.release()
	WorldState.clear()


func _on_hit(source_id: StringName, attack_id: StringName, scale: float, _origin: Vector3) -> void:
	hits.append([source_id, attack_id, scale])


func _on_creature_hit(id: StringName, _kind: StringName, cause: StringName, _part: Variant) -> void:
	creature_hits.append([id, cause])


## A lone naga at `at`, engaged, no collisions (BodyTick is exact then).
func _naga(at: Vector3) -> NagaRoamer:
	var n := ROAMER.instantiate() as NagaRoamer
	n.creature_id = &"naga_hr"
	add_child_autofree(n)
	n.set_physics_process(false)
	n.navigate = false
	n.collision_layer = 0
	n.collision_mask = 0
	n.global_position = at
	return n


func _step(c: Creature, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		if c is NagaRoamer:
			(c as NagaRoamer).senses.awareness = 1.0
		BodyTick.tick(c, DT)
		c.global_position.y = 0.0
		c.velocity.y = 0.0
		v._iframes = maxf(v._iframes - DT, 0.0)


## Ticks until it starts its claw, so a test can hit it mid wind-up.
func _until_winding(n: NagaRoamer) -> void:
	for i in 90:
		if n.winding_up() != &"":
			return
		_step(n, DT)


func _body_point(c: Creature, side: Vector3) -> Vector3:
	return c.global_position + Vector3(0, c.data.body_height * 0.3, 0) + side * 0.3


func _weak_point(c: Creature) -> Vector3:
	return c.global_position + Vector3(0, c.data.body_height * 0.9, 0)


func test_a_body_hit_flinches_and_pushes_it_about_0_3_m_away() -> void:
	var d := DEER.instantiate() as Creature
	add_child_autofree(d)
	d.set_physics_process(false)
	d.navigate = false
	d.collision_layer = 0
	d.collision_mask = 0
	d.scripted = true
	d.global_position = Vector3(10, 0, 0)
	var at := _body_point(d, Vector3(-1, 0, 0))
	assert_eq(d.hit_zone(at), &"body")
	var start := d.global_position
	d.apply_hit(&"arrow_wood", &"wood", 0.05, &"body", at)
	assert_almost_eq(d.flinch_left, Creature.FLINCH_SECONDS, 0.001, "every hit flinches")
	assert_eq(d.stagger_left, 0.0, "a body hit is no stagger")
	_step(d, 0.5)
	var moved := d.global_position - start
	assert_almost_eq(Vector2(moved.x, moved.z).length(), Creature.FLINCH_PUSH_M, 0.05, "a 0.3 m push")
	assert_gt(moved.x, 0.0, "away from where it struck")
	assert_eq(d.flinch_left, 0.0)
	assert_almost_eq(Vector2(d.velocity.x, d.velocity.z).length(), 0.0, 0.001, "the push never stays in its velocity")


func test_every_hit_emits_creature_hit_once() -> void:
	var n := _naga(Vector3(0, 0, -6))
	n.apply_hit(&"arrow_wood", &"wood", 0.05, &"body", _body_point(n, Vector3.ZERO))
	n.apply_hit(&"arrow_wood", &"wood", 0.05, &"weak", _weak_point(n))
	assert_eq(creature_hits.size(), 2, "one creature_hit per hit, flinch or stagger")


func test_a_body_hit_mid_wind_up_does_not_cancel_the_claw() -> void:
	var n := _naga(Vector3(0, 0, -1.2))
	_until_winding(n)
	assert_eq(n.winding_up(), NagaRoamer.CLAW, "it claws in front")
	n.apply_hit(&"arrow_wood", &"wood", 0.05, &"body", _body_point(n, Vector3.ZERO))
	assert_eq(n.winding_up(), NagaRoamer.CLAW, "a flinch keeps the wind-up")
	_step(n, NagaRoamer.windup_of(NagaRoamer.CLAW) + 0.1)
	assert_true(hits.any(func(h: Array) -> bool: return h[1] == NagaRoamer.CLAW), "and the claw lands")


func test_a_weak_spot_hit_staggers_0_8_s_and_cancels_the_wind_up() -> void:
	var n := _naga(Vector3(0, 0, -1.2))
	_until_winding(n)
	assert_eq(n.winding_up(), NagaRoamer.CLAW)
	var start := n.global_position
	n.apply_hit(&"arrow_wood", &"wood", 0.05, &"weak", _weak_point(n))
	assert_almost_eq(n.stagger_left, Creature.STAGGER_WEAK_SECONDS, 0.001, "0.8 s reeling")
	assert_almost_eq(n.flinch_left, Creature.FLINCH_SECONDS, 0.001, "it flinches too")
	assert_eq(n.winding_up(), &"", "the wind-up is lost")
	assert_eq(n.fight, NagaRoamer.Fight.RECOVER)
	_step(n, NagaRoamer.windup_of(NagaRoamer.CLAW) + 0.1)
	assert_eq(hits.size(), 0, "nothing lands where the claw would have")
	var moved := n.global_position - start
	assert_almost_eq(Vector2(moved.x, moved.z).length(), 0.0, 0.01, "a stagger stands where it is: no push")


func test_the_wind_up_length_is_the_rows_windup_s() -> void:
	var n := _naga(Vector3(0, 0, -1.2))
	_until_winding(n)
	assert_almost_eq(n._fight_left, NagaRoamer.windup_of(NagaRoamer.CLAW), DT + 0.001,
			"the brain's one fight timer, set from AttackData.windup_s")
	assert_almost_eq(NagaRoamer.windup_of(NagaRoamer.CLAW), 0.55, 0.001)


func test_a_killing_hit_does_not_flinch() -> void:
	var n := _naga(Vector3(0, 0, -6))
	n.apply_hit(&"arrow_wood", &"wood", 100.0, &"weak", _weak_point(n))
	assert_false(n.alive)
	assert_eq(n.flinch_left, 0.0)
	assert_eq(n.stagger_left, 0.0)
