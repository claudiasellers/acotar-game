## Bestiary 6 (hollow-crows): the model the behaviour lane builds on (lane L83).
# gate: when:creatures/models/fae/hollow_crow*,data/animation/creatures/hollow_crow_gaits.txt,creatures/materials/hollow_crow_hide.tres,creatures/materials/monster_hide.gdshader
extends GutTest

const MODEL := preload("res://creatures/models/fae/hollow_crow.gltf")
const GAITS := "res://data/animation/creatures/hollow_crow_gaits.txt"
## Bestiary 6.4.
const CLIPS: Array[StringName] = [&"perch_idle", &"head_cock", &"caw", &"shriek", &"mimic", &"peck", &"walk", &"hop",
		&"fly", &"glide", &"take_off", &"land", &"telegraph_crow_peck", &"attack_crow_peck",
		&"telegraph_crow_dive", &"attack_crow_dive", &"hit_l", &"hit_r", &"death_l", &"death_r", &"death_air"]
const MAX_TRIS := 3000
const HIDDEN_EYES := 9


func test_the_crow_has_its_clips_bones_and_hidden_eyes_within_budget() -> void:
	var m := MODEL.instantiate() as Node3D
	add_child_autofree(m)
	var player := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := m.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_not_null(player)
	assert_not_null(sk)
	for clip in CLIPS:
		assert_true(player.has_animation(clip), "hollow-crow has %s" % clip)
	for bone: StringName in [&"head", &"jaw", &"beak", &"tail", &"wing_2_l", &"pri_7_r", &"sec_6_l", &"ter_2_r", &"paw_leg_l"]:
		assert_gt(sk.find_bone(bone), -1, "bone %s" % bone)
	var tris := 0
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_index_len(s) / 3
		assert_gt(mi.find_blend_shape_by_name("eyes_open"), -1, "one key opens every hidden eye")
		for i in HIDDEN_EYES:
			assert_gt(mi.find_blend_shape_by_name("eyelid_%d" % i), -1, "eyelid_%d" % i)
	assert_gt(tris, 2000, "a real model")
	assert_lte(tris, MAX_TRIS)


func test_every_clip_has_its_row_in_the_gaits_file() -> void:
	var rows := {}
	for line in FileAccess.get_file_as_string(GAITS).split("\n", false):
		if not line.begins_with("#"):
			rows[StringName(line.get_slice(" ", 0))] = line.split(" ", false)
	for clip in CLIPS:
		assert_true(rows.has(clip), "a row for %s" % clip)
	assert_almost_eq(float(rows[&"fly"][1]), 9.0, 0.01, "flies at 9 m/s")
	assert_almost_eq(float(rows[&"attack_crow_dive"][4]), 0.4, 0.01, "the dive lands at 0.4 s")
	assert_almost_eq(float(rows[&"attack_crow_peck"][4]), 0.1, 0.01, "the peck lands at 0.1 s")
