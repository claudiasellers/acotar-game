extends GutTest
## The main cast built by tools/blender/cast/build_cast.py on Feyre's rig.

const CAST := {
	"tamlin": 1.93, "lucien": 1.85, "nesta": 1.70, "elain": 1.63, "father": 1.75,
}
const CLIPS: Array[StringName] = [&"idle", &"walk", &"run"]
const SHAPES := ["blink_L", "jaw_open", "smile", "vis_AA"]


func _model(id: String) -> Node3D:
	var path := "res://characters/%s/%s_model.tscn" % [id, id]
	if not ResourceLoader.exists(path):
		return null
	var m := (load(path) as PackedScene).instantiate() as Node3D
	add_child_autofree(m)
	return m


func test_every_cast_member_shares_feyres_rig() -> void:
	for id: String in CAST:
		var m := _model(id)
		assert_not_null(m, id + " scene")
		if m == null:
			continue
		var sk: Skeleton3D = m.skeleton
		assert_eq(sk.get_bone_count(), 60, id)
		for bone in ["Hips", "Head", "Jaw", "LeftHand", "RightToes", "LeftEye"]:
			assert_gt(sk.find_bone(bone), -1, "%s %s" % [id, bone])
		for s in SHAPES:
			assert_gt(m.body.find_blend_shape_by_name(s), -1, "%s %s" % [id, s])
		for c in CLIPS:
			assert_true(m.anim.has_animation(c), "%s %s" % [id, c])
		assert_eq(m.anim.current_animation, &"idle", id + " starts in idle")


func test_heights_and_outfits() -> void:
	for id: String in CAST:
		var m := _model(id)
		if m == null:
			continue
		var aabb: AABB = m.body.get_aabb()
		assert_almost_eq(aabb.size.y, CAST[id], 0.04, id + " height")
		assert_gt(m.worn.size(), 0, id + " wears an outfit")
		assert_not_null(m.hair, id + " hair")
		for node: Node3D in m.worn.values():
			var mi := node.get_child(0) as MeshInstance3D
			assert_not_null(mi.skin, id + " " + node.name + " skinned")


func test_tamlin_claws_slide_out() -> void:
	var m := _model("tamlin")
	var claws := m.find_child("Claws", true, false) as MeshInstance3D
	assert_not_null(claws)
	m.set_claws(1.0)
	assert_almost_eq(claws.get_blend_shape_value(claws.find_blend_shape_by_name("claws_out")), 1.0, 0.001)
