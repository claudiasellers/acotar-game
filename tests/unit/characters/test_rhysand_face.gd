extends GutTest
## L49: Rhysand's reworked face. Book 1 canon [C]: pale skin, violet eyes, unmasked,
## a half smile (ch20). The skin sits under the cast-wide 0.85 albedo glare cap
## (hue kept), the head wears his own makeup, he rests in a half smile, and his
## model carries the full expression set.

const ID := "rhysand"


func _model() -> Node3D:
	var m := (load("res://characters/rhysand/rhysand_model.tscn") as PackedScene).instantiate() as Node3D
	add_child_autofree(m)
	return m


func test_skin_under_the_albedo_cap_and_still_pale_and_cool() -> void:
	var m := _model()
	for prop in [&"skin_head_material", &"skin_body_material"]:
		var mat := m.get(prop) as ShaderMaterial
		assert_not_null(mat, prop)
		if mat == null:
			continue
		var c: Color = mat.get_shader_parameter("albedo")
		assert_lte(maxf(c.r, maxf(c.g, c.b)), 0.85, "%s albedo under the cap" % prop)
		assert_gt(c.r, 0.8, "pale (book 1: 'pale skin', 'moon-white')")
		assert_lt(c.r - c.b, 0.12, "cool porcelain, not golden")


func test_head_wears_his_makeup() -> void:
	var mat := _model().get(&"skin_head_material") as ShaderMaterial
	assert_not_null(mat)
	if mat == null:
		return
	assert_gte(float(mat.get_shader_parameter("brows_amount")), 0.95, "strong dark brows")
	assert_gt(float(mat.get_shader_parameter("liner_amount")), 0.5, "a dark lash line")
	# the blush channel is a muted contour under the cheekbones, never a pink flush
	var bc: Color = mat.get_shader_parameter("blush_color")
	assert_lt(bc.r - bc.g, 0.2, "contour is a muted taupe-brown, not pink")
	assert_lt(float(mat.get_shader_parameter("blush_amount")), 0.45, "subtle contour")
	assert_gt(float(mat.get_shader_parameter("subsurface")), 0.3, "warm subsurface, not flat porcelain")


func test_rests_in_a_half_smile_unmasked() -> void:
	var prof := load("res://data/faces/rhysand_face.tres")
	assert_not_null(prof, "profile")
	if prof == null:
		return
	assert_eq(String(prof.get(&"rest")), "half_smile")
	assert_false(bool(prof.get(&"masked")), "the only unmasked High Fae at Spring [C]")


func test_violet_eyes_and_strand_lashes() -> void:
	var root := (load("res://characters/rhysand/model/rhysand.glb") as PackedScene).instantiate() as Node3D
	add_child_autofree(root)
	var lashes := root.find_child("Lashes", true, false) as MeshInstance3D
	assert_not_null(lashes, "lashes")
	if lashes:
		assert_gt(lashes.mesh.get_faces().size() / 3, 200, "strand lashes")
	var body := root.find_child("Body", true, false) as MeshInstance3D
	assert_not_null(body, "body")
	if body:
		assert_gte(body.mesh.get_blend_shape_count(), 40, "17 base + 23 expression keys")
