## Slice 2(c) (hostile plan §5.3, health-interactions §4.3, bestiary §7): a
## briarling stands among the Rosewild's real roses in their own material, and
## the only tell is that it doesn't sway. It is a bush by day, walks its brake
## from 18:00, unfolds before it moves, lashes, snares every third strike, and
## two wood arrows kill it.
extends GutTest

const BRIARLING := preload("res://creatures/hostile/briarling_roamer.tscn")
const ROSEWILD := "res://data/regions/spring_court/content/rosewild.tres"
const DT := 1.0 / 30.0

var _time: float


func before_each() -> void:
	_time = Clock.time_of_day
	Clock.time_of_day = 12.0 / 24.0


func after_each() -> void:
	Clock.time_of_day = _time


func _briarling() -> BriarlingRoamer:
	var b := BRIARLING.instantiate() as BriarlingRoamer
	b.creature_id = &"briarling_test"
	add_child_autofree(b)
	b.set_physics_process(false)
	b.senses.set_physics_process(false)
	b.collision_mask = 0
	return b


func _think(b: BriarlingRoamer, seconds: float) -> void:
	for i in int(ceil(seconds / DT)):
		b._think(DT)


# --- 2(c): the bush doesn't sway; the real roses do ------------------------------

func test_the_real_roses_sway() -> void:
	var content := load(ROSEWILD) as CourtRegionContent
	var found := false
	for e in content.decor:
		if e.mesh_id == BriarlingRoamer.BUSH_MESH:
			found = true
			assert_gt(e.wind, 0.0, "the Rosewild's rose bushes are planted swaying")
	assert_true(found, "the Rosewild grows the rose bush a briarling copies")
	assert_gt(BriarlingRoamer.wind_of(CourtAssets.material_for(BriarlingRoamer.BUSH_MESH)), 0.0,
			"and their material moves in the wind")


func test_a_briarling_bush_has_wind_0() -> void:
	var b := _briarling()
	assert_true(b.is_bush())
	assert_not_null(b.mimic_material)
	assert_eq(BriarlingRoamer.wind_of(b.mimic_material), 0.0, "the mimic layer's wind is 0")
	var geoms := b.model.find_children("*", "GeometryInstance3D", true, false)
	assert_gt(geoms.size(), 0)
	for g in geoms:
		assert_eq((g as GeometryInstance3D).material_override, b.mimic_material, "every leaf and bloom wears it")


func test_the_bush_wears_the_roses_own_look() -> void:
	var b := _briarling()
	var real := CourtAssets.material_for(BriarlingRoamer.BUSH_MESH) as ShaderMaterial
	var mimic := b.mimic_material as ShaderMaterial
	assert_not_null(real)
	assert_not_null(mimic)
	if real and mimic:
		assert_eq(mimic.shader, real.shader, "the same shader as the real roses")
		assert_ne(mimic, real, "its own copy: the real roses keep their wind")
		assert_gt(BriarlingRoamer.wind_of(real), 0.0)
	assert_eq(b.data.model_scene.resource_path.get_file().get_basename(), String(BriarlingRoamer.BUSH_MESH),
			"the court's own rose bush model")


# --- the brain -------------------------------------------------------------------

func test_still_as_a_bush_by_day() -> void:
	var b := _briarling()
	_think(b, 2.0)
	assert_eq(b.routine, &"bush")
	assert_true(b.is_bush())
	assert_eq(b.move_speed, 0.0)


func test_it_unfolds_before_it_walks_at_night() -> void:
	Clock.time_of_day = 19.0 / 24.0
	var b := _briarling()
	b.home = b.global_position
	_think(b, DT)
	assert_eq(b.routine, &"hunt", "18:00 to 07:00 it walks its brake")
	assert_eq(b.form, BriarlingRoamer.Form.UNFOLDING)
	assert_eq(b.move_speed, 0.0, "not a step while it unfolds")
	_think(b, BriarlingRoamer.UNFOLD_SECONDS + DT)
	assert_eq(b.form, BriarlingRoamer.Form.CREATURE)
	_think(b, DT)
	assert_gt(b.move_speed, 0.0)


func test_it_folds_back_into_a_bush_at_home_by_day() -> void:
	var b := _briarling()
	b.form = BriarlingRoamer.Form.CREATURE
	_think(b, DT)
	assert_eq(b.form, BriarlingRoamer.Form.FOLDING)
	_think(b, BriarlingRoamer.FOLD_SECONDS + DT)
	assert_true(b.is_bush())


func test_waking_unfolds_it() -> void:
	var b := _briarling()
	b.senses.awareness = 1.0
	_think(b, 1.0)
	assert_false(b.is_bush(), "a woken bush unfolds")


func test_its_rows() -> void:
	var b := _briarling()
	assert_eq(b.attack_id, BriarlingRoamer.LASH)
	assert_eq(b.grab_attack, BriarlingRoamer.SNARE)
	assert_eq(b.grab_presses, 4)
	assert_almost_eq(b.grab_seconds, 2.5, 0.001)
	assert_almost_eq(b.grab_follow_scale, 2.0, 0.001, "failing the snare: two lashes")
	assert_almost_eq(NagaRoamer.windup_of(BriarlingRoamer.LASH), 0.4, 0.001)
	assert_almost_eq(NagaRoamer.windup_of(BriarlingRoamer.SNARE), 0.6, 0.001)
	assert_eq(AttackTell.pose_kind(BriarlingRoamer.LASH), &"thorn")
	assert_eq(AttackTell.pose_kind(BriarlingRoamer.SNARE), &"grab")
	assert_false(b._may_lunge(), "knee-high: no lunge")


func test_every_third_strike_is_a_snare() -> void:
	var b := _briarling()
	var her := Node3D.new()
	add_child_autofree(her)
	var picks: Array[StringName] = []
	for i in 6:
		picks.append(b.pick_strike(her))
	assert_eq(picks, [BriarlingRoamer.LASH, BriarlingRoamer.LASH, BriarlingRoamer.SNARE,
			BriarlingRoamer.LASH, BriarlingRoamer.LASH, BriarlingRoamer.SNARE])


func test_two_wood_arrows_kill_it() -> void:
	var b := _briarling()
	b.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", b.global_position)
	assert_true(b.alive)
	b.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", b.global_position)
	assert_false(b.alive)


func test_the_naga_keeps_its_own_rows() -> void:
	var n := (load("res://creatures/hostile/naga_roamer.tscn") as PackedScene).instantiate() as NagaRoamer
	add_child_autofree(n)
	n.set_physics_process(false)
	assert_eq(n.attack_id, NagaRoamer.CLAW)
	assert_eq(n.grab_attack, NagaRoamer.COIL)
	assert_eq(n.grab_presses, NagaRoamer.COIL_PRESSES)
	assert_almost_eq(n.grab_seconds, NagaRoamer.COIL_SECONDS, 0.001)
	assert_eq(n.routine_at(12.0), NagaRoamer.routine_for(12.0))
