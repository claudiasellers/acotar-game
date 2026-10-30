extends GutTest

const MODEL := "res://characters/feyre/model/feyre_model.tscn"
const HAIR_DIR := "res://characters/feyre/hair/"
const WARDROBE_DIR := "res://characters/feyre/wardrobe/"
const CLIPS: Array[StringName] = [&"idle", &"idle_look", &"walk", &"run", &"sprint", &"turn_left", &"turn_right"]
const SHAPES := ["nourished", "blink_L", "blink_R", "jaw_open", "smile", "vis_AA", "vis_MBP"]
const REGIONS := ["torso", "arms", "legs", "feet", "hands", "head"]


func _model() -> Node3D:
	var m := (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child_autofree(m)
	return m


func test_skeleton_and_body_surfaces() -> void:
	var m := _model()
	var sk: Skeleton3D = m.skeleton
	assert_not_null(sk)
	assert_eq(sk.get_bone_count(), 60)
	for bone in ["Hips", "Head", "LeftHand", "RightToes", "Braid_4", "LeftEye"]:
		assert_gt(sk.find_bone(bone), -1, bone)
	var names := []
	for i in m.body.mesh.get_surface_count():
		names.append(m.surface_name_of(m.body.mesh, i))
	for r in REGIONS:
		assert_has(names, r)
	for s in SHAPES:
		assert_gt(m.body.find_blend_shape_by_name(s), -1, s)


func test_clips_loop_and_never_t_pose() -> void:
	var m := _model()
	assert_not_null(m.anim)
	for c in CLIPS:
		assert_true(m.anim.has_animation(c), String(c))
	assert_eq(m.anim.get_animation(&"walk").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(m.anim.get_animation(&"turn_left").loop_mode, Animation.LOOP_NONE)
	assert_eq(m.anim.current_animation, &"idle", "she starts in idle, not the rest T-pose")
	m.play_locomotion(5.5, true)
	assert_eq(m.anim.current_animation, &"run")
	assert_almost_eq(m.anim.speed_scale, 1.0, 0.01)
	m.play_locomotion(8.0, true)
	assert_eq(m.anim.current_animation, &"sprint")


func test_every_hairstyle_binds() -> void:
	var m := _model()
	var dir := DirAccess.open(HAIR_DIR)
	var count := 0
	for f in dir.get_files():
		if f.ends_with(".glb"):
			m.set_hair(HAIR_DIR + f)
			assert_not_null(m.hair, f)
			var mi := m.hair.get_child(0) as MeshInstance3D
			assert_not_null(mi.skin, f)
			count += 1
	assert_eq(count, 16)


func test_gowns_have_tintable_fabric() -> void:
	for id in ["gown_dinner", "gown_ball", "gown_garden", "gown_solstice", "gown_rose_petal", "gown_starlight", "woven_crown"]:
		var inst := (load(WARDROBE_DIR + id + ".glb") as PackedScene).instantiate()
		var mi := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var found := false
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			found = found or (mat != null and mat.resource_name == "fabric")
		assert_true(found, id)
		inst.free()


const EVERYDAY := ["spring_tunic", "spring_trousers", "painter_smock", "riding_leathers", "woods_leathers", "vest",
		"capelet", "velvet_cloak", "riding_boots", "slippers", "gloves_lace", "stockings", "mask_butterfly", "mask_fox",
		"mask_leaf", "circlet", "butterfly_clips", "hair_ribbon", "pearl_pins", "earrings_drop", "earrings_hoop",
		"earrings_pearl", "earrings_rose", "earrings_star", "necklace_choker", "necklace_locket", "necklace_pearl",
		"necklace_pendant", "ribbon_sash", "charm_bracelet", "flower_wristlet", "bangle", "ribbon_cuff"]


func test_everyday_wardrobe_is_skinned_with_fabric_first() -> void:
	for id in EVERYDAY:
		var inst := (load(WARDROBE_DIR + id + ".glb") as PackedScene).instantiate()
		var mi := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		assert_not_null(mi.skin, id)
		var mat := mi.mesh.surface_get_material(0)
		assert_eq(mat.resource_name if mat else "", "fabric", id)
		inst.free()
