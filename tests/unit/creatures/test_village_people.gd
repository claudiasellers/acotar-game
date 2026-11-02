extends GutTest
## Lane L52: the human village and market people (the square's villagers, the peddler,
## a Child of the Blessed and the ch 3 mercenary) are built on the main cast's body
## (tools/blender/cast/build_village_people.py), not the old stick-figure skin bodies:
## the cast's 60-bone rig, all five CourtNpc clips, a baked face, clothes, a human
## height, inside the 15k creature budget (R4).

const IDS := ["human_woman", "human_man", "human_elder", "human_youth", "peddler", "blessed", "blessed_2", "mercenary"]
const CLIPS: Array[StringName] = [&"idle", &"walk", &"talk", &"flinch", &"bow"]
const BUDGET := 15000


func _npc(id: String) -> CourtNpc:
	var npc := (load("res://creatures/people/scenes/%s.tscn" % id) as PackedScene).instantiate() as CourtNpc
	npc.wander_radius = 0.0
	add_child_autofree(npc)
	return npc


func _model(id: String) -> Node3D:
	var m := (load("res://creatures/models/people/%s.gltf" % id) as PackedScene).instantiate() as Node3D
	add_child_autofree(m)
	return m


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		out.append(mi as MeshInstance3D)
	return out


func _tris(root: Node) -> int:
	var n := 0
	for mi in _meshes(root):
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			n += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


## Width (x) of the figure's vertices in a band of heights, in the model's own space.
func _width(root: Node, z0: float, z1: float) -> float:
	var lo := INF
	var hi := -INF
	for mi in _meshes(root):
		for s in mi.mesh.get_surface_count():
			for v in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var p := mi.transform * v
				if p.y > z0 and p.y < z1 and absf(p.x) < 0.35:
					lo = minf(lo, p.x)
					hi = maxf(hi, p.x)
	return hi - lo


func test_each_villager_is_on_the_cast_rig_with_its_clips() -> void:
	for id in IDS:
		var npc := _npc(id)
		assert_not_null(npc.current_model(), id)
		assert_false(npc.animators.is_empty(), id + " has an animator")
		for a in npc.animators:
			assert_gte(a.skeleton.get_bone_count(), 50, id + " is on the cast's rig, not the stick rig")
			for c in CLIPS:
				assert_true(a.anim.has_animation(c), "%s %s" % [id, c])
			assert_between(a.native_walk, 0.6, 2.0, id + " native walk speed")


func test_each_villager_is_dressed_with_a_painted_face_inside_the_budget() -> void:
	for id in IDS:
		var m := _model(id)
		assert_between(_tris(m), 8000, BUDGET, id + " LOD0 tris")
		var surfaces := 0
		var face := false
		for mi in _meshes(m):
			surfaces += mi.mesh.get_surface_count()
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if mat != null and mat.albedo_texture != null and mat.albedo_texture.resource_path.contains("_face"):
					face = true
		assert_gte(surfaces, 12, id + ": skin, eyes, hair and several garments")
		assert_true(face, id + " has its baked face")


func test_a_fleshed_out_human_height_and_build() -> void:
	for id in IDS:
		var m := _model(id)
		var top := -INF
		for mi in _meshes(m):
			top = maxf(top, (mi.transform * mi.get_aabb()).end.y)
		assert_between(top, 1.45, 1.95, id + " height")
		# hips and skirts: the old figures were tubes a few centimetres across
		assert_gte(_width(m, top * 0.50, top * 0.56), 0.26, id + " is fleshed out at the hips")


func _top(root: Node) -> float:
	var top := -INF
	for mi in _meshes(root):
		top = maxf(top, (mi.transform * mi.get_aabb()).end.y)
	return top


func test_the_mercenary_is_a_mountain_of_a_woman() -> void:
	var merc := _model("mercenary")
	var hm := _top(merc)
	for id in IDS:
		if id != "mercenary":
			assert_gt(hm, _top(_model(id)), "the mercenary stands taller than " + id)
	var man := _model("human_man")
	var hs := _top(man)
	var w_merc := _width(merc, hm * 0.79, hm * 0.83)
	var w_man := _width(man, hs * 0.79, hs * 0.83)
	gut.p("shoulders: mercenary %.3f m, village man %.3f m" % [w_merc, w_man])
	assert_gt(w_merc, w_man, "broader across the shoulders than the village man")
