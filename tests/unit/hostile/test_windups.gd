## HF tells (health-interactions §3.5 item 4, L81 G19): every camp member's
## attack row winds up on its model's own telegraph clip
## (CreatureAnimator.play_windup), stretched to the row's windup_s and held to
## contact, then strikes on its own attack clip. A stagger calls it off. The
## brain announces it on EventBus.hostile_windup with the row's windup_s, and
## the naga's hiss is in the bank. No fallback: a family without the rig or a
## row without its clip fails here. Circling, a naga stalks and now and then
## laughs (L81 G21).
extends GutTest

const NAGA := preload("res://creatures/hostile/naga_roamer.tscn")
const BRIARLING := preload("res://creatures/hostile/briarling_roamer.tscn")
const DT := 1.0 / 30.0

var windups: Array = []
var cancels: Array = []


func before_each() -> void:
	windups.clear()
	cancels.clear()
	EventBus.hostile_windup.connect(_on_windup)
	EventBus.hostile_windup_cancelled.connect(_on_cancel)


func after_each() -> void:
	if EventBus.hostile_windup.is_connected(_on_windup):
		EventBus.hostile_windup.disconnect(_on_windup)
	if EventBus.hostile_windup_cancelled.is_connected(_on_cancel):
		EventBus.hostile_windup_cancelled.disconnect(_on_cancel)


func _on_windup(id: StringName, kind: StringName, attack: StringName, at: Vector3, seconds: float) -> void:
	windups.append([id, kind, attack, at, seconds])


func _on_cancel(id: StringName) -> void:
	cancels.append(id)


func _member(scene: PackedScene, id: StringName = &"windup_test") -> HostileRoamer:
	var n := scene.instantiate() as HostileRoamer
	n.creature_id = id
	add_child_autofree(n)
	n.set_physics_process(false)
	n.collision_layer = 0
	n.collision_mask = 0
	n.global_position = Vector3(0, 0, -6)
	return n


## Her stand-in, far enough off that nothing lands on her.
func _her(at: Vector3 = Vector3(0, 0, 20)) -> Node3D:
	var her := Node3D.new()
	add_child_autofree(her)
	her.global_position = at
	return her


func _phase(n: HostileRoamer, attack: StringName) -> HostileRoamer.Fight:
	return HostileRoamer.Fight.LUNGE if attack == n.lunge_attack else HostileRoamer.Fight.STRIKE


## Each family and the rows its scene names.
func _families() -> Array:
	var out := []
	for scene in [NAGA, BRIARLING]:
		var n := _member(scene)
		var rows: Array[StringName] = []
		for r in [n.attack_id, n.grab_attack, n.lunge_attack]:
			if r != &"":
				rows.append(r)
		out.append([scene, rows])
	return out


func test_every_family_is_rigged_with_a_clip_for_every_row() -> void:
	for f in _families():
		var n := _member(f[0])
		assert_not_null(n.animator, "%s: no silent skip, the rig is always there" % n.data.kind)
		if n.animator == null:
			continue
		for attack: StringName in f[1]:
			assert_true(n.animator.anim.has_animation(StringName("telegraph_%s" % attack)), "%s winds up on its own clip" % attack)
			assert_true(n.animator.anim.has_animation(StringName("attack_%s" % attack)), "%s strikes on its own clip" % attack)


func test_every_row_announces_its_tell_with_its_windup_s() -> void:
	for f in _families():
		for attack: StringName in f[1]:
			windups.clear()
			var n := _member(f[0])
			n._wind_up(_phase(n, attack), attack)
			assert_eq(windups.size(), 1, "%s is announced once" % attack)
			if windups.is_empty():
				continue
			assert_eq(windups[0][1], n.data.kind)
			assert_eq(windups[0][2], attack)
			assert_almost_eq(float(windups[0][4]), AttackTable.resolve(attack).windup_s, 0.001, "%s: the row's windup_s" % attack)
			assert_gt(float(windups[0][4]), 0.0, "%s has a tell at all" % attack)
			assert_eq(n.winding_up(), attack)
			assert_almost_eq(n.windup_left(), AttackTable.resolve(attack).windup_s, 0.001)


## The telegraph plays from the start of the wind-up and its last pose holds
## to contact, however long the row's windup_s is against the clip.
func test_the_telegraph_plays_through_the_windup_and_holds_to_contact() -> void:
	for f in _families():
		for attack: StringName in f[1]:
			var n := _member(f[0])
			var clip := StringName("telegraph_%s" % attack)
			n._wind_up(_phase(n, attack), attack)
			assert_eq(n.animator.action_clip(), clip, "%s starts on its telegraph" % attack)
			var seconds := AttackTable.resolve(attack).windup_s
			for i in int(ceil(seconds * 2.0 / DT)):
				n.animator._drive_action(DT)
			assert_true(n.animator.is_acting(), "%s: still held past its windup_s" % attack)
			assert_eq(n.animator.action_clip(), clip, "%s holds its last pose until contact" % attack)


func test_contact_plays_the_blow() -> void:
	var n := _member(NAGA)
	var her := _her()
	n.fight = HostileRoamer.Fight.STRIKE
	n._wind_up(HostileRoamer.Fight.STRIKE, n.attack_id)
	n._fight_left = 0.0
	n._fight(her, DT)
	assert_eq(n.animator.action_clip(), StringName("attack_%s" % n.attack_id), "the claw swings, if only at air")
	assert_eq(n.fight, HostileRoamer.Fight.RECOVER)
	assert_eq(cancels, [], "a tell that ran to contact isn't called off")


func test_the_leap_plays_the_lunge() -> void:
	var n := _member(NAGA)
	var her := _her(n.global_position + Vector3(0, 0, 5))
	n._wind_up(HostileRoamer.Fight.LUNGE, n.lunge_attack)
	n._fight_left = 0.0
	n._fight(her, DT)
	assert_eq(n.fight, HostileRoamer.Fight.LEAP)
	assert_eq(n.animator.action_clip(), StringName("attack_%s" % n.lunge_attack))


func test_a_stagger_calls_the_telegraph_off() -> void:
	for scene in [NAGA, BRIARLING]:
		cancels.clear()
		var n := _member(scene, &"windup_stagger")
		var telegraph := StringName("telegraph_%s" % n.attack_id)
		n._wind_up(HostileRoamer.Fight.STRIKE, n.attack_id)
		assert_eq(n.animator.action_clip(), telegraph)
		n.stagger(0.8)
		assert_eq(cancels, [&"windup_stagger"], "%s: a stagger calls the tell off" % n.data.kind)
		assert_ne(n.animator.action_clip(), telegraph, "and the telegraph is let go")


func test_contact_is_not_a_cancel() -> void:
	var n := _member(NAGA)
	n._wind_up(HostileRoamer.Fight.STRIKE, NagaRoamer.CLAW)
	n._fight_left = 0.0
	n._recover()
	assert_eq(cancels, [], "a tell that ran to contact isn't called off")


func test_a_circling_naga_stalks_and_now_and_then_laughs() -> void:
	var n := _member(NAGA)
	var her := _her(n.global_position + Vector3(0, 0, 5))
	assert_eq(n.taunt_clip, &"laugh")
	assert_true(n.animator.anim.has_animation(n.taunt_clip), "its model has the laugh")
	var to := her.global_position - n.global_position
	n._taunt_left = HostileRoamer.TAUNT_EVERY.x
	n._circle(her, to, 5.0, DT)
	assert_eq(n.gait_hint, &"stalk", "it circles on the stalk")
	assert_false(n.animator.is_acting(), "not every step")
	n._taunt_left = 0.0
	n._circle(her, to, 5.0, DT)
	assert_eq(n.animator.action_clip(), &"laugh", "now and then, a laugh")
	assert_between(n._taunt_left, HostileRoamer.TAUNT_EVERY.x, HostileRoamer.TAUNT_EVERY.y, "then a while before the next")


func test_the_briarling_has_no_taunt() -> void:
	var b := _member(BRIARLING)
	assert_eq(b.taunt_clip, &"", "a bush doesn't laugh")


func test_the_naga_hiss_is_in_the_bank() -> void:
	var bank := load(SoundDirector.BANK_PATH) as SoundBank
	for kind: StringName in SoundDirector.WINDUP_CUES:
		var c := bank.cue(SoundDirector.WINDUP_CUES[kind])
		assert_not_null(c, "%s's wind-up sound" % kind)
		if c:
			assert_false(c.streams.is_empty())
	assert_true(SoundDirector.WINDUP_CUES.has(&"naga"))
