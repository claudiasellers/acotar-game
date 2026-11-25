## Slice 2(c) (hostile plan §5.3, health-interactions §4.3, bestiary §7): a
## briarling stands among the Rosewild's real roses in their own material, and
## the only tell is that it doesn't sway. It is a bush by day, walks its brake
## from 18:00, unfolds before it moves, lashes, snares every third strike, and
## one wood arrow or one knife hit kills it.
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

## The flora table id the briarling copies, from its own data.
func _rose() -> StringName:
	return (load("res://data/creatures/hostile/briarling_roamer.tres") as CreatureData).flora_id


func test_the_real_roses_sway() -> void:
	var content := load(ROSEWILD) as CourtRegionContent
	var found := false
	for e in content.decor:
		if e.mesh_id == _rose():
			found = true
			assert_gt(e.wind, 0.0, "the Rosewild's rose bushes are planted swaying")
	assert_true(found, "the Rosewild grows the rose bush a briarling copies")
	assert_gt(BriarlingRoamer.wind_of(CourtAssets.material_for(_rose())), 0.0,
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
	var real := CourtAssets.material_for(_rose()) as ShaderMaterial
	var mimic := b.mimic_material as ShaderMaterial
	assert_not_null(real)
	assert_not_null(mimic)
	if real and mimic:
		assert_eq(mimic.shader, real.shader, "the same shader as the real roses")
		assert_ne(mimic, real, "its own copy: the real roses keep their wind")
		assert_gt(BriarlingRoamer.wind_of(real), 0.0)
	assert_eq(b.data.flora_id, &"flora_bush_rose", "the Rosewild's rose bush, by its flora id")
	assert_null(b.data.model_scene, "no file path: a flora swap of the rose reaches it")
	var mi := b.model.find_children("*", "MeshInstance3D", true, false)
	assert_false(mi.is_empty())
	if not mi.is_empty():
		assert_eq((mi[0] as MeshInstance3D).mesh, CourtAssets.mesh(_rose()), "the flora table's own mesh")


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
	assert_eq(b.grab_presses(), 4, "the snare row's terms")
	assert_almost_eq(b.grab_seconds(), 2.5, 0.001)
	assert_almost_eq(b.grab_fail_scale(), 2.0, 0.001, "failing the snare: two lashes")
	assert_eq(b.lunge_attack, &"", "knee-high: no lunge row")
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


## Small means fragile (owner, 2026-11-25): one arrow, or one knife hit.
func test_one_wood_arrow_kills_it() -> void:
	var b := _briarling()
	b.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", b.global_position)
	assert_false(b.alive)


func test_one_knife_hit_kills_it() -> void:
	var b := _briarling()
	b.apply_hit(&"knife", &"knife", StrikeController.KNIFE_MULT, &"body", b.global_position)
	assert_false(b.alive)


func test_its_hit_box_is_bigger_than_its_body() -> void:
	var b := _briarling()
	var box := (b.get_node(^"Collision") as CollisionShape3D).shape as BoxShape3D
	assert_almost_eq(box.size.x, b.data.body_width * 1.5, 0.01)


func test_the_naga_keeps_its_own_rows() -> void:
	var n := (load("res://creatures/hostile/naga_roamer.tscn") as PackedScene).instantiate() as NagaRoamer
	add_child_autofree(n)
	n.set_physics_process(false)
	assert_eq(n.attack_id, NagaRoamer.CLAW)
	assert_eq(n.grab_attack, NagaRoamer.COIL)
	assert_eq(n.lunge_attack, NagaRoamer.LUNGE_ATTACK)
	assert_eq(n.grab_presses(), 6, "the coil: six presses")
	assert_almost_eq(n.grab_seconds(), 3.0, 0.001, "in three seconds")
	assert_almost_eq(n.grab_fail_scale(), 1.5, 0.001, "then a claw at 1.5")
	assert_almost_eq(n.strike_reach, 1.7, 0.001)
	assert_eq(n.routine_at(12.0), NagaRoamer.routine_for(12.0))


## R18: the shared brain carries no family's values; each family is a thin
## subclass whose values are on its scene and in its rows.
func test_the_shared_brain_is_no_familys() -> void:
	var src := FileAccess.get_file_as_string("res://creatures/hostile/hostile_roamer.gd")
	for word in ["naga_", "briarling_", "NagaRoamer", "BriarlingRoamer"]:
		assert_false(src.contains(word), "hostile_roamer.gd names %s" % word)
	var bare := HostileRoamer.new()
	assert_eq(bare.attack_id, &"")
	assert_eq(bare.grab_attack, &"")
	assert_eq(bare.lunge_attack, &"")
	assert_eq(bare.dread_radius, Vector2.ZERO)
	bare.free()
	for script in [NagaRoamer, BriarlingRoamer]:
		assert_eq((script as GDScript).get_base_script(), HostileRoamer)
