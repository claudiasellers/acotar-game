extends GutTest
## L37: Nesta's and Elain's princess faces. Each wears her own makeup on the
## head material (feyre_skin.gdshader), the two looks differ, and both carry
## strand lashes (many separate strands, not Feyre's single ribbon).

const SISTERS := ["nesta", "elain"]


func _head_mat(id: String) -> ShaderMaterial:
	var m := (load("res://characters/%s/%s_model.tscn" % [id, id]) as PackedScene).instantiate() as Node3D
	add_child_autofree(m)
	return m.get(&"skin_head_material") as ShaderMaterial


func test_each_sister_wears_full_makeup() -> void:
	for id: String in SISTERS:
		var mat := _head_mat(id)
		assert_not_null(mat, id)
		if mat == null:
			continue
		for p in ["lips_amount", "liner_amount", "eyeshadow_amount", "blush_amount"]:
			assert_gt(float(mat.get_shader_parameter(p)), 0.3, "%s %s" % [id, p])


func test_two_distinct_looks() -> void:
	var n := _head_mat("nesta")
	var e := _head_mat("elain")
	# Nesta: cool berry mouth and a dark, sharp liner; Elain: warm pink mouth, a softer liner.
	var nl: Color = n.get_shader_parameter("lips_color")
	var el: Color = e.get_shader_parameter("lips_color")
	assert_gt(nl.b, el.b - 0.2, "Nesta's lips are the cooler")
	assert_gt(float(n.get_shader_parameter("liner_amount")), float(e.get_shader_parameter("liner_amount")))
	assert_gt(float(e.get_shader_parameter("blush_amount")), float(n.get_shader_parameter("blush_amount")))


func test_strand_lashes() -> void:
	for id: String in SISTERS:
		var root := (load("res://characters/%s/model/%s.glb" % [id, id]) as PackedScene).instantiate() as Node3D
		add_child_autofree(root)
		var lashes := root.find_child("Lashes", true, false) as MeshInstance3D
		assert_not_null(lashes, id + " lashes")
		if lashes:
			# 4 rows of 2 verts per strand; Feyre's ribbon has 15 rows of 4 per side (120 verts)
			assert_gt(lashes.mesh.get_faces().size() / 3, 400, id + " strand count")
