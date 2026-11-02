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
	assert_eq(count, 17, "16 + the Calanmai crown braid (L45)")


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


## Princess pass 2: the lashes close with the lids, and her natural colouring
## (blush, glossy lips, lash line, brows) lives outside the six makeup channels,
## so the vanity's "None" never leaves her bare-faced.
func test_lashes_blink_and_natural_colouring_survives_no_makeup() -> void:
	var m := _model()
	assert_not_null(m.lashes)
	for s in ["blink_L", "blink_R"]:
		assert_gt(m.lashes.find_blend_shape_by_name(s), -1, s)
	m.set_shape("blink_L", 1.0)
	var li: int = m.lashes.find_blend_shape_by_name("blink_L")
	assert_almost_eq(m.lashes.get_blend_shape_value(li), 1.0, 0.001)
	var head: ShaderMaterial = m.skin_head_material
	for ch in MakeupData.CHANNELS:
		head.set_shader_parameter("%s_amount" % ch, 0.0)
	for p in ["natural_blush_amount", "natural_lips_amount", "natural_lips_gloss",
			"natural_liner_amount", "natural_brows_amount"]:
		assert_gt(float(head.get_shader_parameter(p)), 0.2, p)
	var body: ShaderMaterial = m.skin_body_material
	var body_blush: Variant = body.get_shader_parameter("natural_blush_amount")
	assert_true(body_blush == null or float(body_blush) == 0.0, "body has no face colouring")


## The wardrobe applier must leave her head on the skin shader (it used to reset
## uncovered regions to the glb's flat skin, losing makeup and natural colouring).
func test_worn_feyre_keeps_the_skin_shader_on_her_face() -> void:
	var f := (load("res://characters/feyre/feyre.tscn") as PackedScene).instantiate() as Feyre
	add_child_autofree(f)
	await wait_frames(2)
	var body := f.find_child("Body", true, false) as MeshInstance3D
	assert_not_null(body)
	for i in body.mesh.get_surface_count():
		if (body.mesh as ArrayMesh).surface_get_name(i) == "head":
			var mat := body.get_active_material(i) as ShaderMaterial
			assert_not_null(mat, "head keeps the skin shader")
			assert_gt(float(mat.get_shader_parameter("natural_lips_amount")), 0.2)


## L41-4 (audit G0): a bare feyre_model.tscn, with no Feyre and no wardrobe, is never unclothed:
## she wears her linen shift over the torso and legs.
func test_bare_model_wears_her_linen_shift() -> void:
	var m := _model()
	await wait_frames(1)
	assert_not_null(m.base_layer, "the bare model wears a base layer")
	var shown := _base_layer_regions(m, false)
	for r in ["torso", "legs"]:
		assert_has(shown, r, "%s covered on the bare model" % r)


## Dressing a bare model the game's way hides the shift where her clothes cover her,
## and her clothes cover the torso and legs.
func test_dressed_bare_model_hides_the_shift_under_her_clothes() -> void:
	var m := (load(MODEL) as PackedScene).instantiate() as Node3D
	var applier := WardrobeApplier.dress(m)
	add_child_autofree(m)
	await wait_frames(2)
	var worn := m.get_node_or_null(^"Worn")
	assert_not_null(worn, "worn pieces bound to the bare model")
	assert_gt(worn.get_child_count(), 0)
	var covered: Array[StringName] = []
	for p in applier.wardrobe.worn_pieces():
		covered.append_array(p.hides_body_regions)
	for r in [&"torso", &"legs"]:
		assert_has(covered, r, "her default outfit covers the %s" % r)
	assert_eq(_base_layer_regions(m, false), [], "shift hidden under the tunic and trousers")


## The cast reuse feyre_model.gd with other bodies: they get no Feyre shift.
func test_cast_models_have_no_feyre_base_layer() -> void:
	var path := "res://characters/elain/elain_model.tscn"
	if not ResourceLoader.exists(path):
		pending("no elain model")
		return
	var c := (load(path) as PackedScene).instantiate() as Node3D
	add_child_autofree(c)
	await wait_frames(1)
	assert_null(c.get(&"base_layer"))


## Region names of the base-layer surfaces that are drawn (`hidden` false) or hidden.
func _base_layer_regions(m: Node3D, hidden: bool) -> Array:
	var out := []
	for c in (m.base_layer as Node3D).get_children():
		var mi := c as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var name: String = m.surface_name_of(mi.mesh, i).trim_prefix("shift_")
			if name == "fabric":
				continue
			var mat := mi.get_surface_override_material(i) as BaseMaterial3D
			var clear := mat != null and mat.albedo_color.a == 0.0
			if clear == hidden:
				out.append(name)
	return out
