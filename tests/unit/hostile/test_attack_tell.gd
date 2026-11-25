## HF tells (health-interactions §3.5 item 4, L81 G19): every naga attack row
## shows its tell for its full windup_s before contact. The pose comes in
## through the wind-up and is let go after it, the brain announces it on
## EventBus.hostile_windup with the row's windup_s, and the naga's hiss is in
## the bank. Nothing skips quietly: a naga without a tell fails here.
extends GutTest

const ROAMER := preload("res://creatures/hostile/naga_roamer.tscn")
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


func _naga() -> NagaRoamer:
	var n := ROAMER.instantiate() as NagaRoamer
	n.creature_id = &"naga_tell"
	add_child_autofree(n)
	n.set_physics_process(false)
	n.collision_layer = 0
	n.collision_mask = 0
	n.global_position = Vector3(0, 0, -6)
	n.tell.set_process(false)
	return n


func _rows() -> Array[StringName]:
	return [NagaRoamer.CLAW, NagaRoamer.LUNGE_ATTACK, NagaRoamer.COIL]


func test_every_naga_has_a_tell_on_its_model() -> void:
	var n := _naga()
	assert_not_null(n.tell, "no silent skip: the tell is always there")
	assert_not_null(n.model, "and it has a body to pose")


func test_every_row_announces_its_tell_with_its_windup_s() -> void:
	for attack in _rows():
		windups.clear()
		var n := _naga()
		var phase := NagaRoamer.Fight.LUNGE if attack == NagaRoamer.LUNGE_ATTACK else NagaRoamer.Fight.STRIKE
		n._wind_up(phase, attack)
		assert_eq(windups.size(), 1, "%s is announced once" % attack)
		if windups.is_empty():
			continue
		assert_eq(windups[0][1], &"naga")
		assert_eq(windups[0][2], attack)
		assert_almost_eq(float(windups[0][4]), AttackTable.resolve(attack).windup_s, 0.001, "%s: the row's windup_s" % attack)
		assert_gt(float(windups[0][4]), 0.0, "%s has a tell at all" % attack)
		assert_eq(n.winding_up(), attack)
		assert_almost_eq(n.windup_left(), AttackTable.resolve(attack).windup_s, 0.001)


func test_the_pose_comes_in_through_the_windup_and_holds_to_contact() -> void:
	for attack in _rows():
		var n := _naga()
		var rest := n.model.basis
		var row := AttackTable.resolve(attack)
		var phase := NagaRoamer.Fight.LUNGE if attack == NagaRoamer.LUNGE_ATTACK else NagaRoamer.Fight.STRIKE
		n._wind_up(phase, attack)
		n.tell.step(DT)
		assert_lt(n.tell.weight, 0.2, "%s starts near rest" % attack)
		# Half way: well into the pose, and the model shows it.
		n._fight_left = row.windup_s * 0.5
		n.tell.step(DT)
		assert_gt(n.tell.weight, 0.5, "%s half way" % attack)
		assert_false(n.model.basis.is_equal_approx(rest), "%s: the model is posed" % attack)
		# The last moment before contact: the full pose.
		n._fight_left = 0.01
		n.tell.step(DT)
		assert_almost_eq(n.tell.weight, 1.0, 0.001, "%s holds the full pose to contact" % attack)
		assert_eq(n.tell.kind, AttackTell.pose_kind(attack))


func test_the_pose_lets_go_and_the_model_comes_back_to_rest() -> void:
	var n := _naga()
	var rest := n.model.basis
	n._wind_up(NagaRoamer.Fight.STRIKE, NagaRoamer.CLAW)
	n._fight_left = 0.01
	n.tell.step(DT)
	assert_false(n.model.basis.is_equal_approx(rest))
	n.stagger(0.8)
	assert_eq(cancels, [&"naga_tell"], "a stagger calls the tell off")
	for i in int(ceil(AttackTell.RELEASE_SECONDS / DT)) + 1:
		n.tell.step(DT)
	assert_eq(n.tell.weight, 0.0)
	assert_true(n.model.basis.is_equal_approx(rest), "back to the body's own basis, nothing left over")


func test_contact_is_not_a_cancel() -> void:
	var n := _naga()
	n._wind_up(NagaRoamer.Fight.STRIKE, NagaRoamer.CLAW)
	n._fight_left = 0.0
	n._recover()
	assert_eq(cancels, [], "a tell that ran to contact isn't called off")


func test_pose_kinds_follow_the_rows_damage_kind() -> void:
	for attack in _rows():
		assert_eq(AttackTell.pose_kind(attack), AttackTable.resolve(attack).damage_kind, String(attack))
	assert_eq(AttackTell.pose_kind(NagaRoamer.CLAW), &"claw")
	assert_eq(AttackTell.pose_kind(NagaRoamer.LUNGE_ATTACK), &"blunt")
	assert_eq(AttackTell.pose_kind(NagaRoamer.COIL), &"grab", "the coil is a hold (vitals.md): a grab")


## No borrowed pose: every row that telegraphs (windup_s > 0), any family,
## has its own damage_kind's pose.
func test_every_telegraphed_rows_kind_has_a_pose() -> void:
	var seen := 0
	for f in DirAccess.get_files_at(AttackTable.DIR):
		var path := AttackTable.DIR + f.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var row := load(path) as AttackData
		if row == null or row.windup_s <= 0.0:
			continue
		seen += 1
		assert_true(AttackTell.POSES.has(row.damage_kind), "%s (%s) has a pose" % [row.id, row.damage_kind])
	assert_gt(seen, 10, "the rows were read")


func test_weight_eases_in_then_holds() -> void:
	assert_almost_eq(AttackTell.weight_at(0.55, 0.55), 0.0, 0.001)
	assert_almost_eq(AttackTell.weight_at(0.55, 0.55 * (1.0 - AttackTell.EASE_IN)), 1.0, 0.001)
	assert_almost_eq(AttackTell.weight_at(0.55, 0.0), 1.0, 0.001)
	assert_almost_eq(AttackTell.weight_at(0.0, 0.0), 1.0, 0.001)


func test_the_naga_hiss_is_in_the_bank() -> void:
	var bank := load(SoundDirector.BANK_PATH) as SoundBank
	for kind: StringName in SoundDirector.WINDUP_CUES:
		var c := bank.cue(SoundDirector.WINDUP_CUES[kind])
		assert_not_null(c, "%s's wind-up sound" % kind)
		if c:
			assert_false(c.streams.is_empty())
	assert_true(SoundDirector.WINDUP_CUES.has(&"naga"))
