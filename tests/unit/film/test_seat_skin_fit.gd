# gate: when:story/film/*,core/*,systems/wardrobe/*,data/wardrobe/*,characters/*,art/film/*,project.godot
## A sitting figure's body doesn't poke through their clothes (T045). Tamlin's tunic
## and Lucien's are skinned for standing, so with the thigh swung forward the
## buttock and hip came out through them in patches of skin. SeatSkinFit takes the
## triangles that sit under cloth out of the body while a figure sits, and puts the
## originals back when they rise.
## Every vertex is read as drawn, from skeleton_updated: outside the modification
## pass the skeleton answers with the idle pose. Numeric only: it can't say how
## the cloth looks in a window.
extends GutTest

## The hip band, in the skeleton's space at rest: waist down to above the knee.
const BAND_LOW := 0.45
const BAND_HIGH := 0.95
## A body vertex further out than this from the cloth over it is poking through,
## and one more than this far is a thigh that has come out from under a hem.
const POKE_MIN := 0.003
const POKE_MAX := 0.05
## Triangles further than this from a vertex aren't looked at.
const NEAR := 0.12
## The most vertices a sitting figure may poke through, against how many the same
## pose pokes with the standing skin.
const POKES_MOST := 2
const POKES_BEFORE_LEAST := 8
const FIGURES := ["tamlin", "lucien"]

var _sk: Skeleton3D


func _figure(id: String) -> Node3D:
	var model := (load("res://characters/%s/%s_model.tscn" % [id, id]) as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	_sk = model.find_child("Skeleton3D", true, false) as Skeleton3D
	return model


## The bones' global poses, a moment after `pose` is set.
func _drawn() -> Array[Transform3D]:
	var at: Array[Transform3D] = []
	var read := func() -> void:
		at.clear()
		for i in _sk.get_bone_count():
			at.append(_sk.get_bone_global_pose(i))
	_sk.skeleton_updated.connect(read)
	await wait_process_frames(4)
	_sk.skeleton_updated.disconnect(read)
	return at


## Every vertex of `mi`'s surfaces `surfaces` ([] for all) that a drawn triangle
## uses, as [rest position, posed position] pairs, and the triangles as posed positions.
func _skinned(mi: MeshInstance3D, surfaces: Array, pose: Array[Transform3D]) -> Dictionary:
	var rest_at := PackedVector3Array()
	var posed := PackedVector3Array()
	var tris: Array = []
	var skin := mi.skin
	var to_rest: Array[Transform3D] = []
	var to_pose: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = _sk.find_bone(skin.get_bind_name(b))
		to_rest.append(_sk.get_bone_global_rest(bone) * skin.get_bind_pose(b))
		to_pose.append(pose[bone] * skin.get_bind_pose(b))
	for s in mi.mesh.get_surface_count():
		if not surfaces.is_empty() and not surfaces.has(s):
			continue
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var per := bones.size() / verts.size()
		var here := PackedVector3Array()
		var there := PackedVector3Array()
		here.resize(verts.size())
		there.resize(verts.size())
		for v in verts.size():
			for k in per:
				var w := weights[v * per + k]
				if w > 0.0:
					here[v] += w * (to_rest[bones[v * per + k]] * verts[v])
					there[v] += w * (to_pose[bones[v * per + k]] * verts[v])
		var used := {}
		for t in range(0, index.size() - 2, 3):
			if index[t] == index[t + 1] and index[t] == index[t + 2]:
				continue   # a degenerate triangle draws nothing
			tris.append([there[index[t]], there[index[t + 1]], there[index[t + 2]]])
			for k in 3:
				used[index[t + k]] = true
		for v: int in used:
			rest_at.append(here[v])
			posed.append(there[v])
	return {"rest": rest_at, "posed": posed, "tris": tris}


## How far `p` stands out from the nearest of `tris` it lies over (positive on the
## side the triangle's winding faces), or INF when none is near enough.
func _out_of(p: Vector3, tris: Array) -> float:
	var best := INF
	var best_abs := INF
	for t: Array in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		if p.distance_squared_to((a + b + c) / 3.0) > NEAR * NEAR:
			continue
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue
		n = n.normalized()
		var q := p - n * (p - a).dot(n)
		var v0 := b - a
		var v1 := c - a
		var v2 := q - a
		var d00 := v0.dot(v0)
		var d01 := v0.dot(v1)
		var d11 := v1.dot(v1)
		var den := d00 * d11 - d01 * d01
		if absf(den) < 1e-12:
			continue
		var vv := (d11 * v2.dot(v0) - d01 * v2.dot(v1)) / den
		var ww := (d00 * v2.dot(v1) - d01 * v2.dot(v0)) / den
		if vv < -0.02 or ww < -0.02 or 1.0 - vv - ww < -0.02:
			continue
		var d := (p - a).dot(n)
		if absf(d) < best_abs:
			best_abs = absf(d)
			best = d
	return best


## The garments' triangles as drawn now, under a pose.
func _cloth(model: Node, pose: Array[Transform3D]) -> Array:
	var tris: Array = []
	for part in ["tunic", "trousers", "doublet"]:
		var holder := model.find_child("*_%s" % part, true, false)
		if holder == null:
			continue
		for mi: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if mat != null and mat.resource_name == "fabric":
					tris.append_array(_skinned(mi, [s], pose)["tris"])
	return tris


## The body's torso and legs, as drawn now.
func _body(model: Node, pose: Array[Transform3D]) -> Dictionary:
	var mi := _sk.find_child("Body", false, false) as MeshInstance3D
	var surfaces: Array = []
	for s in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(s)
		if mat != null and mat.resource_name in ["torso", "legs"]:
			surfaces.append(s)
	return _skinned(mi, surfaces, pose)


## How many body vertices in the hip band lay under cloth standing and stand out of it now.
func _pokes(model: Node, standing: Array[Transform3D], now: Array[Transform3D]) -> int:
	var cloth_standing := _cloth(model, standing)
	var cloth_now := _cloth(model, now)
	var body_standing := _body(model, standing)
	var body_now := _body(model, now)
	# which side is under the cloth: where most of the standing body lies
	var inside := 0
	var outside := 0
	var rest: PackedVector3Array = body_standing["rest"]
	var posed: PackedVector3Array = body_standing["posed"]
	for i in rest.size():
		if rest[i].y < BAND_LOW or rest[i].y > BAND_HIGH:
			continue
		var d := _out_of(posed[i], cloth_standing)
		if d != INF:
			if d > 0.0:
				outside += 1
			else:
				inside += 1
	var under := 1.0 if outside >= inside else -1.0
	var rest_now: PackedVector3Array = body_now["rest"]
	var posed_now: PackedVector3Array = body_now["posed"]
	var count := 0
	for i in rest_now.size():
		if rest_now[i].y < BAND_LOW or rest_now[i].y > BAND_HIGH:
			continue
		var d := _out_of(posed_now[i], cloth_now)
		if d != INF and d * under < -POKE_MIN and d * under > -POKE_MAX:
			count += 1
	return count


func test_a_sitting_body_does_not_poke_through_the_clothes() -> void:
	for id: String in FIGURES:
		var model := _figure(id)
		await wait_process_frames(6)
		var fp := FilmPose.on(model)
		fp.to(&"", 0.0)
		var standing := await _drawn()
		fp.to(&"sit", 0.0, &"chair_dining")
		var sitting := await _drawn()
		var fitted := _pokes(model, standing, sitting)
		# the same pose with the standing skin: what the owner saw
		SeatSkinFit.set_seated(_sk, false)
		var before := _pokes(model, standing, sitting)
		gut.p("%s: %d vertices poke through sitting, %d with the standing skin" % [id, fitted, before])
		assert_gt(before, POKES_BEFORE_LEAST, "%s: the standing skin pokes through when seated (the test sees the hole)" % id)
		assert_lt(fitted, POKES_MOST, "%s: the sitting skin doesn't" % id)


func test_standing_up_puts_the_standing_skin_back() -> void:
	for id: String in FIGURES:
		var model := _figure(id)
		await wait_process_frames(6)
		var body := _sk.find_child("Body", false, false) as MeshInstance3D
		var drawn := body.mesh
		var fp := FilmPose.on(model)
		fp.to(&"sit", 0.0, &"chair_dining")
		assert_ne(body.mesh, drawn, "%s: sitting swaps the body for the sitting one" % id)
		fp.to(&"", 0.0)
		assert_eq(body.mesh, drawn, "%s: rising puts the same body mesh back" % id)
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			assert_false(mi.has_meta(SeatSkinFit.ORIGINAL), "%s: %s has nothing left to restore" % [id, mi.name])
