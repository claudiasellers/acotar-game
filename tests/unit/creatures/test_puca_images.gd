extends GutTest
## F25: the puca's images wear the real things, not code-built primitives
## (the playtest's grey-box guard fails a run on a primitive mesh on an actor).
## Her father is his cast model and limps on walk_limp; her sisters are
## Nesta's and Elain's cast models; the bow and supplies are prop glbs.

const PUCA := preload("res://creatures/fae/puca.tscn")
const PRIMITIVES: Array[String] = ["BoxMesh", "CapsuleMesh", "CylinderMesh", "SphereMesh", "PrismMesh"]


func _puca() -> Puca:
	var p := PUCA.instantiate() as Puca
	add_child_autofree(p)
	return p


func _primitives(n: Node) -> Array[String]:
	var found: Array[String] = []
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh and m.mesh.get_class() in PRIMITIVES:
			found.append(String(n.get_path_to(m)))
	return found


func test_no_image_is_built_from_primitives() -> void:
	var p := _puca()
	for id: StringName in p._images:
		var node := p._images[id] as Node3D
		assert_gt(node.find_children("*", "MeshInstance3D", true, false).size(), 0, "%s has meshes" % id)
		assert_eq(_primitives(node), [] as Array[String], "%s is no grey box" % id)


func test_father_is_his_cast_model_and_limps() -> void:
	var p := _puca()
	var dad := p._father_body
	assert_not_null(dad, "the father's cast model")
	assert_true(p._images[&"father"].is_ancestor_of(dad))
	var anim := dad.get(&"anim") as AnimationPlayer
	assert_eq(anim.current_animation, &"idle", "waits on his cane (idle_cane)")
	dad.call(&"play_locomotion", p.lure_speed, true, 0.1)
	assert_true(anim.has_animation(&"walk_limp"))
	assert_eq(anim.current_animation, &"walk", "walk is his walk_limp")


func test_sisters_are_nesta_and_elain() -> void:
	var p := _puca()
	var sisters := p._images[&"sisters"] as Node3D
	var paths: Array[String] = []
	for c in sisters.get_children():
		paths.append(c.scene_file_path)
	assert_eq(paths, ["res://characters/nesta/nesta_model.tscn", "res://characters/elain/elain_model.tscn"])
