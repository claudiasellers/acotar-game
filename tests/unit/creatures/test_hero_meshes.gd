## Contract (lane L61, render program T4): hero meshes are real models.
## The opening film's winter wood is grown trees, not cylinders; every
## creature model has a skeleton; every species names a real model.
# gate: when:story/film/opening/*,world/spring_court/shared/models/*,tools/woods/blender/*,creatures/*,data/creatures/*
extends GutTest


func test_opening_film_trees_are_models_not_cylinders() -> void:
	var stage := WolfEyeStage.new()
	add_child_autofree(stage)
	var cylinders := 0
	var trees := 0
	for node in stage.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh is CylinderMesh:
			cylinders += 1
		elif mesh is ArrayMesh and mesh.get_faces().size() / 3 > 1000:
			trees += 1
	assert_eq(cylinders, 0, "no CylinderMesh trunks")
	assert_gt(trees, 26, "26 woods_trees trunks, the bough's tree and the bough")
	var bough := stage.find_child("Bough", true, false) as MeshInstance3D
	assert_not_null(bough, "the bough that sheds its snow")
	assert_true(bough != null and bough.mesh is ArrayMesh, "the bough is a grown model, not a box")


## Every creature model under creatures/models imports with a Skeleton3D, so
## any of them can be animated by bone (lane L61: 21 had none).
func test_every_creature_model_has_a_skeleton() -> void:
	var models := _models("res://creatures/models")
	assert_gt(models.size(), 70, "the creature model library")
	var bare: Array[String] = []
	for path in models:
		var root := (load(path) as PackedScene).instantiate()
		if root.find_children("*", "Skeleton3D", true, false).is_empty():
			bare.append(path)
		root.free()
	assert_eq(bare, [] as Array[String], "creature models without a skeleton")


## No creature species falls back to a code-built placeholder body.
func test_every_creature_data_names_a_model() -> void:
	var missing: Array[String] = []
	for path in _files("res://data/creatures", ".tres"):
		var res := load(path)
		if res is CreatureData and (res as CreatureData).model_scene == null:
			missing.append(path)
	assert_eq(missing, [] as Array[String], "CreatureData without model_scene")


func _models(dir: String) -> Array[String]:
	var out: Array[String] = []
	for ext in [".gltf", ".glb"]:
		out.append_array(_files(dir, ext))
	return out


func _files(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(d), ext))
	return out
