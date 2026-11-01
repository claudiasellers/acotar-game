## F24: the Bogge is a Blender model (tools/blender/bogge.py), not code-built
## primitives, and its dissolve follows `reveal` (L25 drives set_reveal()).
extends GutTest

var PRIMITIVES: Array = [BoxMesh, CapsuleMesh, CylinderMesh, SphereMesh, PrismMesh]


func _bogge() -> Bogge:
	var b := (load("res://creatures/fae/bogge.tscn") as PackedScene).instantiate() as Bogge
	add_child_autofree(b)
	return b


func test_form_has_no_primitive_meshes() -> void:
	var b := _bogge()
	var form := b.get_node("Form")
	var meshes := form.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "the model loaded")
	for node in meshes:
		var mesh := (node as MeshInstance3D).mesh
		for kind in PRIMITIVES:
			assert_false(is_instance_of(mesh, kind), "%s is a primitive" % node.name)


func test_every_surface_dissolves_with_reveal() -> void:
	var b := _bogge()
	var mats: Array[ShaderMaterial] = []
	var eyes := 0
	for node in b.get_node("Form").find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			assert_not_null(m, "surface %d of %s uses the form shader" % [i, mi.name])
			if m:
				mats.append(m)
				if m.get_shader_parameter(&"is_eye"):
					eyes += 1
	assert_eq(eyes, 1, "one eye surface")
	b.set_reveal(0.6)
	for m in mats:
		assert_almost_eq(float(m.get_shader_parameter(&"reveal")), 0.6, 0.001)


func test_idle_loops_and_manifest_lunges() -> void:
	var b := _bogge()
	var anim := b.get_node("Form").find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(anim)
	assert_eq(anim.current_animation, "idle")
	assert_eq(anim.get_animation(&"idle").loop_mode, Animation.LOOP_LINEAR)
	b.manifest(Vector3(0, 0, -3))
	assert_eq(anim.current_animation, "lunge")
	assert_eq(b.reveal, 1.0)
