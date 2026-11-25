## Contract: docs/contracts/creature_motion.md, "Monsters" (lane L83).
# gate: when:creatures/anim/*,creatures/models/fae/naga*,creatures/models/fae/suriel*,data/animation/creatures/naga_gaits.txt,data/animation/creatures/suriel_gaits.txt,creatures/materials/*
extends GutTest

const NAGA := preload("res://creatures/fae/naga.tscn")
const GREAT_WOLF := preload("res://creatures/wolves/great_wolf.tscn")
## Bestiary 2.4: the naga's whole clip table.
const CLIPS: Array[StringName] = [&"idle", &"walk", &"lope", &"run", &"stalk", &"swim", &"alert", &"startle", &"call",
		&"dodge_l", &"dodge_r", &"bask", &"nest", &"sleep_fall", &"sleep", &"wake",
		&"telegraph_naga_claw", &"attack_naga_claw", &"telegraph_naga_lunge", &"attack_naga_lunge",
		&"telegraph_naga_coil", &"attack_naga_coil", &"coil_hold", &"coil_thrown", &"recover",
		&"hit_l", &"hit_r", &"stagger", &"burn", &"speak", &"laugh",
		&"death_l", &"death_r", &"death_throat", &"death_ash"]
const SOCKETS: Array[StringName] = [&"throat", &"mouth", &"grab_point", &"talon_l", &"talon_r"]
const MAX_TRIS := 15000
const SURIEL_MODEL := preload("res://creatures/models/fae/suriel.gltf")
## Bestiary 3.4.
const SURIEL_CLIPS: Array[StringName] = [&"idle", &"stalk", &"snared", &"scream", &"sit_down", &"sit_idle", &"notice",
		&"head_cock", &"speak", &"laugh", &"warn", &"burst", &"hit_l", &"hit_r"]


func before_each() -> void:
	WorldState.clear()


func _spawn(scene: PackedScene) -> Creature:
	var c := scene.instantiate() as Creature
	add_child_autofree(c)
	return c


func test_the_naga_is_rigged_with_every_clip_the_guide_lists() -> void:
	var a := _spawn(NAGA).animator
	assert_not_null(a, "the naga has an animator")
	for clip in CLIPS:
		assert_true(a.anim.has_animation(clip), "naga has %s" % clip)
	for bone in SOCKETS:
		assert_not_null(a.socket(bone), "socket %s" % bone)
	assert_eq(a.anim.get_animation(&"walk").loop_mode, Animation.LOOP_LINEAR, "gaits loop")
	assert_eq(a.anim.get_animation(&"coil_hold").loop_mode, Animation.LOOP_LINEAR, "the hold loops")
	assert_eq(a.anim.get_animation(&"death_throat").loop_mode, Animation.LOOP_NONE, "death holds")


func test_the_naga_is_within_the_triangle_budget() -> void:
	var c := _spawn(NAGA)
	var tris := 0
	for m: MeshInstance3D in c.model.find_children("*", "MeshInstance3D", true, false):
		for s in m.mesh.get_surface_count():
			tris += m.mesh.surface_get_array_index_len(s) / 3
	assert_gt(tris, 8000, "a real model")
	assert_lte(tris, MAX_TRIS)


func test_a_biped_steps_from_walk_to_run_at_the_guides_speeds() -> void:
	var a := _spawn(NAGA).animator
	assert_eq(a.loco, [&"walk", &"lope", &"run"] as Array[StringName], "stalk and swim are not steps of the gait ladder")
	assert_almost_eq(float(a.native_speeds[&"walk"]), 1.4, 0.05)
	assert_almost_eq(float(a.native_speeds[&"run"]), 8.0, 0.2)
	assert_almost_eq(float(a.native_speeds[&"stalk"]), 0.8, 0.05)
	assert_eq(a.gait_for(1.4, 0), 0, "walking")
	assert_eq(a.gait_for(3.4, 0), 1, "the lope covers the gap")
	assert_eq(a.gait_for(8.0, 0), 2, "running")


func test_a_quadruped_still_walks_trots_and_gallops() -> void:
	var a := _spawn(GREAT_WOLF).animator
	assert_eq(a.loco, [&"walk", &"trot", &"gallop"] as Array[StringName])


func test_an_attack_tells_first_and_reports_when_it_lands() -> void:
	var a := _spawn(NAGA).animator
	var lands := a.play_attack(&"naga_claw")
	assert_almost_eq(lands, 0.55 + 0.067, 0.02, "0.55 s of warning, then the claw")
	assert_true(a.is_acting())
	assert_eq(a.action_clip(), &"telegraph_naga_claw")
	await wait_seconds(0.7)
	assert_eq(a.action_clip(), &"attack_naga_claw", "the telegraph runs into the attack")
	a.cancel_attack()
	assert_false(a.is_acting())
	assert_eq(a.play_attack(&"no_such_attack"), -1.0)
	assert_almost_eq(float(a.clip_travel[&"attack_naga_lunge"]), 5.0, 0.01, "the lunge carries 5 m")


func test_a_wind_up_stretches_to_the_rows_time_and_holds_until_the_strike() -> void:
	var a := _spawn(NAGA).animator
	for row: StringName in [&"naga_claw", &"naga_lunge", &"naga_coil"]:
		assert_true(a.anim.has_animation(StringName("telegraph_%s" % row)), "%s has its tell" % row)
		assert_true(a.anim.has_animation(StringName("attack_%s" % row)), "%s has its strike" % row)
	a.play_windup(&"naga_claw", 0.3)
	assert_almost_eq(float(a.tree.get(&"parameters/action_scale/scale")), 0.533 / 0.3, 0.05)
	await wait_seconds(0.5)
	assert_true(a.is_acting(), "the last pose is held past the clip's end")
	assert_eq(a.action_clip(), &"telegraph_naga_claw")
	assert_almost_eq(a.play_strike(&"naga_claw"), 0.067, 0.01)
	assert_eq(a.action_clip(), &"attack_naga_claw")
	assert_almost_eq(float(a.tree.get(&"parameters/action_scale/scale")), 1.0, 0.001)
	a.cancel_attack()
	assert_false(a.is_acting())


func test_a_throat_shot_plays_its_own_death() -> void:
	var a := _spawn(NAGA).animator
	a.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	a.die(&"throat")
	a.tree.advance(0.02)
	assert_string_starts_with(String(a.tree.get(&"parameters/life/current_state")), "death_")
	assert_eq((a._death_nodes[&"death_l" if a.fell_to < 0 else &"death_r"] as AnimationNodeAnimation).animation, &"death_throat")
	assert_almost_eq(a.death_length(), 3.0, 0.05)
	assert_eq(a.play_oneshot(&"startle"), 0.0, "the dead do not startle")



func test_the_suriel_has_its_clips_sockets_cloth_and_face() -> void:
	var m := SURIEL_MODEL.instantiate() as Node3D
	add_child_autofree(m)
	var player := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := m.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_not_null(player)
	for clip in SURIEL_CLIPS:
		assert_true(player.has_animation(clip), "suriel has %s" % clip)
	for bone: StringName in [&"ankle_l", &"mouth", &"eyes", &"jaw", &"spine2", &"finger_4b_l", &"veil_fl_2", &"veil_b1_2", &"hem_7_1"]:
		assert_gt(sk.find_bone(bone), -1, "bone %s" % bone)
	var marked := CreatureAnimator.apply_loops(player, "res://data/animation/creatures/suriel_gaits.txt")
	assert_eq(marked, 5, "idle, stalk, snared, sit_idle and speak loop")
	assert_eq(player.get_animation(&"sit_idle").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(player.get_animation(&"scream").loop_mode, Animation.LOOP_NONE)
	assert_almost_eq(float(CreatureAnimator.read_gaits("res://data/animation/creatures/suriel_gaits.txt")[&"stalk"][0]), 0.6, 0.01)
	var tris := 0
	var keys := 0
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		keys = maxi(keys, mi.mesh.get_blend_shape_count())
		for s in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_index_len(s) / 3
		for key: String in ["threat", "speak_open", "eyes_wide"]:
			assert_gt(mi.find_blend_shape_by_name(key), -1, "shape key %s" % key)
	assert_gt(tris, 8000, "a real model")
	assert_lte(tris, MAX_TRIS)
