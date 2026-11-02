extends GutTest
## Lane L33: the opening film's history mural is built from real models, not
## placeholders. The people are on the cast's body (tools/blender/cast,
## cast_minor.DESIGNS); the props are Blender models (tools/blender/film/
## mural_props.py). Every one fits what the Keeper found in book 1.

## The mural's own people: the High Fae before the Wall, their armoured
## warriors, the six queens' three faces, the humans, the Archerons' mother
## and Feyre as a girl.
const PEOPLE := ["old_court_lord", "old_court_lady", "old_court_lady_2", "war_fae_1", "war_fae_2",
		"mortal_queen_1", "mortal_queen_2", "mortal_queen_3", "archeron_mother", "young_feyre",
		"mortal_man", "mortal_woman", "mortal_youth", "mortal_elder"]
const PROPS := ["fae_palace_a", "fae_palace_b", "fae_palace_c", "court_terrace", "feral_temple",
		"stone_block", "chain_span", "war_banner", "sword", "longbow", "ground_dust", "ground_mud",
		"treaty_table", "treaty_parchment", "treaty_seal", "treaty_wax", "archeron_manor",
		"carried_chest", "carried_frame", "carried_chair", "merchant_ship", "storm_sea"]
const CLIPS: Array[StringName] = [&"idle", &"walk", &"talk", &"flinch", &"bow"]
const OPENING: Array[StringName] = [&"court", &"slaves", &"war", &"treaty", &"mother", &"house", &"ships"]


func _tris(root: Node) -> int:
	var n := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			n += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _load(path: String) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	add_child_autofree(n)
	return n


func test_the_mural_people_are_on_the_cast_rig_in_budget() -> void:
	for id in PEOPLE:
		var m := _load(MuralStage.PEOPLE % id)
		var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		assert_ne(sk.find_bone("Head"), -1, id + " has a head for its crown")
		assert_ne(sk.find_bone("RightHand"), -1, id + " has a hand for a sword")
		var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for c in CLIPS:
			assert_true(ap.has_animation(c), "%s %s" % [id, c])
		assert_between(_tris(m), 8000, 15000, id + " LOD0 tris")


func test_the_props_are_painted_per_vertex_and_light() -> void:
	for id in PROPS:
		var m := _load(MuralStage.PROP % id)
		var t := _tris(m)
		assert_between(t, 100, 16000, id + " tris")
		var coloured := false
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var mesh := (mi as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				coloured = coloured or (mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR) != 0
		assert_true(coloured, id + " carries its colours per vertex")


func test_no_tableau_is_built_from_primitives_or_the_cast() -> void:
	var stage := MuralStage.new()
	stage.build_only = OPENING
	add_child_autofree(stage)
	for id in OPENING:
		var root := stage.root_of(id)
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var mesh := (n as MeshInstance3D).mesh
			assert_false(mesh is CylinderMesh, "%s: %s is a cylinder" % [id, n.name])
			if mesh is BoxMesh:
				assert_lt((mesh as BoxMesh).size.length(), 0.5, "%s: %s is a box" % [id, n.name])
		# Tamlin and Lucien were never the rulers before the Wall.
		for s in root.find_children("*", "Node3D", true, false):
			var path := s.scene_file_path
			assert_false(path.begins_with("res://characters/tamlin") or path.begins_with("res://characters/lucien"),
					"%s: %s" % [id, path])


func test_the_director_still_finds_its_nodes() -> void:
	var stage := MuralStage.new()
	stage.build_only = OPENING
	add_child_autofree(stage)
	for path in ["Sheet", "Seal", "Wax"]:
		assert_not_null(stage.root_of(&"treaty").get_node_or_null(path), path)
	assert_not_null(stage.root_of(&"house").get_node_or_null("Men"))
	for i in 3:
		assert_not_null(stage.root_of(&"ships").get_node_or_null("Ship%d" % i))
		assert_not_null(stage.root_of(&"war").get_node_or_null("Banner%d" % i))
	assert_not_null(stage.root_of(&"court").get_node_or_null("Eye"))


func test_six_queens_at_the_treaty() -> void:
	var stage := MuralStage.new()
	stage.build_only = [&"treaty"]
	add_child_autofree(stage)
	var n := 0
	for c in stage.root_of(&"treaty").get_children():
		if c.scene_file_path.contains("mortal_queen_"):
			n += 1
	assert_eq(n, 6, "six mortal queens (ch 3)")
