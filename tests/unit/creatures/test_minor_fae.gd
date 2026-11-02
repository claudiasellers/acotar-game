extends GutTest
## Lane L48: the revellers, the cave trio, the masked household and the sentries
## are built on the main cast's body (tools/blender/cast/build_minor_fae.py) and
## still fill the old CourtNpc slots: rigged, all five clips, a head that turns
## to Feyre, inside the 15k creature budget (R4).

## CourtNpc scenes (creatures/people/scenes/).
const IDS := ["reveler_1", "reveler_2", "reveler_3", "servant_maid", "servant_footman", "servant_cook",
		"sentry_1", "sentry_2"]
## Every model file, the cave trio's included (calanmai_faerie.gd instances them as they are).
const MODELS := ["reveler_1", "reveler_2", "reveler_3", "calanmai_1", "calanmai_2", "calanmai_3",
		"servant_maid_true", "servant_footman_true", "servant_cook_true", "sentry_1", "sentry_2"]
const CLIPS: Array[StringName] = [&"idle", &"walk", &"talk", &"flinch", &"bow"]
const BUDGET := 15000


func before_each() -> void:
	WorldState.clear()
	WorldState.set_flag("glamour_lifted", true)


func after_each() -> void:
	WorldState.clear()


func _npc(id: String) -> CourtNpc:
	var npc := (load("res://creatures/people/scenes/%s.tscn" % id) as PackedScene).instantiate() as CourtNpc
	npc.wander_radius = 0.0
	add_child_autofree(npc)
	return npc


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


func test_each_figure_is_on_the_cast_rig_with_its_clips() -> void:
	for id in IDS:
		var npc := _npc(id)
		var model := npc.current_model()
		assert_not_null(model, id)
		assert_false(npc.animators.is_empty(), id + " has an animator")
		for a in npc.animators:
			assert_gte(a.skeleton.get_bone_count(), 50, id + " is on the cast's 60-bone rig")
			assert_ne(a.skeleton.find_bone("Head"), -1, id)
			for c in CLIPS:
				assert_true(a.anim.has_animation(c), "%s %s" % [id, c])
			assert_between(a.native_walk, 0.6, 2.0, id + " native walk speed")


func _model(id: String) -> Node3D:
	var m := (load("res://creatures/models/people/%s.gltf" % id) as PackedScene).instantiate() as Node3D
	add_child_autofree(m)
	return m


func test_each_figure_is_inside_the_creature_budget() -> void:
	for id in MODELS:
		var t := _tris(_model(id))
		assert_between(t, 8000, BUDGET, "%s LOD0 tris" % id)


func test_unplayed_figure_stands_at_ease_not_in_a_t_pose() -> void:
	for id in MODELS:
		var sk := _model(id).find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var hand := sk.get_bone_global_rest(sk.find_bone("LeftHand")).origin
		var shoulder := sk.get_bone_global_rest(sk.find_bone("LeftUpperArm")).origin
		assert_lt(hand.y, shoulder.y - 0.35, id + ": the hand hangs well below the shoulder at rest")


func test_feet_on_the_ground_and_a_fae_height() -> void:
	for id in MODELS:
		var model := _model(id)
		var lo := INF
		var hi := -INF
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var box := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			lo = minf(lo, box.position.y)
			hi = maxf(hi, box.end.y)
		assert_almost_eq(lo, 0.0, 0.08, id + " stands on its origin")
		assert_between(hi, 1.5, 2.4, id + " height")
