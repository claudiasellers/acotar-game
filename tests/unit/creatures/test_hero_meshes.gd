## Contract (lane L61, render program T4): hero meshes are real models.
## The opening film's winter wood is grown trees, not cylinders.
# gate: when:story/film/opening/*,world/spring_court/shared/models/*,tools/woods/blender/*
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
