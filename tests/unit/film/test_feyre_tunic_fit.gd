## Feyre's trousers stay under her tunic (T053). They came through it at the hip
## standing as well as sitting: the skirt sat 2 mm off them in coarse rows, and the
## shell stopped short of the skirt's top edge at the flanks. A trouser vertex under
## the tunic counts as showing when no cloth lies outward along its normal.
## Numeric only: a look at seated_fit_shot is what says the cloth reads whole.
extends GutTest

## The tunic's reach down the hips at rest; lower, the legs are meant to show.
const BAND_LOW := 0.76
const BAND_HIGH := 0.98
## The legs' inner faces look at each other, not at the cloth.
const INNER_X := 0.09
const INNER_Y := 0.84
const REACH := 0.12
const SECTORS := 24
const SHOWING_MOST := 3

var _sk: Skeleton3D


func _feyre() -> Node3D:
	var model := (load("res://characters/feyre/model/feyre_model.tscn") as PackedScene).instantiate() as Node3D
	var outfit := Wardrobe.new()
	for piece: StringName in [&"spring_tunic_sky", &"spring_trousers_cream"]:
		outfit.grant(piece)
		outfit.equip(piece)
	outfit.unequip_slot(&"outer")
	WardrobeApplier.dress(model, outfit)
	add_child_autofree(model)
	await wait_process_frames(8)
	_sk = model.find_child("Skeleton3D", true, false) as Skeleton3D
	return model


## The bones' global poses, a moment after `pose` is set (outside the modification
## pass the skeleton answers with the idle pose).
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


func _worn(model: Node, fragment: String) -> MeshInstance3D:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta(&"wardrobe") and String(mi.name).contains(fragment):
			return mi
	return null


## `mi`'s fabric as drawn under `pose`: positions at rest and posed, normals at rest and
## posed, the index list, and which vertices a drawn triangle uses.
func _skinned(mi: MeshInstance3D, pose: Array[Transform3D]) -> Dictionary:
	var to_rest: Array[Transform3D] = []
	var to_pose: Array[Transform3D] = []
	for b in mi.skin.get_bind_count():
		var bone := mi.skin.get_bind_bone(b)
		if bone < 0:
			bone = _sk.find_bone(mi.skin.get_bind_name(b))
		to_rest.append(_sk.get_bone_global_rest(bone) * mi.skin.get_bind_pose(b))
		to_pose.append(pose[bone] * mi.skin.get_bind_pose(b))
	var arrays := mi.mesh.surface_get_arrays(0)   # always "fabric"
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per := bones.size() / verts.size()
	var rest := PackedVector3Array()
	var posed := PackedVector3Array()
	var rest_n := PackedVector3Array()
	var posed_n := PackedVector3Array()
	for a: PackedVector3Array in [rest, posed, rest_n, posed_n]:
		a.resize(verts.size())
	for v in verts.size():
		for k in per:
			var w := weights[v * per + k]
			if w > 0.0:
				var bind := bones[v * per + k]
				rest[v] += w * (to_rest[bind] * verts[v])
				posed[v] += w * (to_pose[bind] * verts[v])
				rest_n[v] += w * (to_rest[bind].basis * norms[v])
				posed_n[v] += w * (to_pose[bind].basis * norms[v])
	var used := {}
	for t in range(0, index.size() - 2, 3):
		if index[t] != index[t + 1] or index[t] != index[t + 2]:   # a degenerate triangle draws nothing
			used[index[t]] = true
			used[index[t + 1]] = true
			used[index[t + 2]] = true
	return {"rest": rest, "posed": posed, "rest_n": rest_n, "posed_n": posed_n, "index": index, "used": used}


func _sector(p: Vector3, hub: Vector3) -> int:
	return posmod(int(floor(atan2(p.z - hub.z, p.x - hub.x) / TAU * SECTORS)), SECTORS)


## How many trouser vertices under the tunic have no cloth over them. `rear_only`
## looks at what faces away from her front: sitting, the thigh's front swings out from
## under the hem, and that is meant to show.
func _showing(model: Node, pose: Array[Transform3D], rear_only: bool) -> int:
	var cloth := _skinned(_worn(model, "tunic"), pose)
	var trousers := _skinned(_worn(model, "trousers"), pose)
	var hub: Vector3 = pose[_sk.find_bone("Hips")].origin
	var by_sector: Array = []
	for s in SECTORS:
		by_sector.append(PackedInt32Array())
	var at: PackedVector3Array = cloth["posed"]
	var tri: PackedInt32Array = cloth["index"]
	for t in range(0, tri.size() - 2, 3):
		for corner in 3:
			var home := _sector(at[tri[t + corner]], hub)
			if not (by_sector[home] as PackedInt32Array).has(t):
				by_sector[home].append(t)
	var front := SeatSkinFit._front(_sk)
	var rest: PackedVector3Array = trousers["rest"]
	var rest_n: PackedVector3Array = trousers["rest_n"]
	var posed: PackedVector3Array = trousers["posed"]
	var posed_n: PackedVector3Array = trousers["posed_n"]
	var count := 0
	for v: int in trousers["used"]:
		var r := rest[v]
		if r.y < BAND_LOW or r.y > BAND_HIGH or (absf(r.x) < INNER_X and r.y < INNER_Y):
			continue
		if rear_only and rest_n[v].normalized().dot(front) > SeatSkinFit.KEEP_FRONT:
			continue
		var dir := posed_n[v].normalized()
		var from := posed[v] - dir * 0.0005
		var covered := false
		var home := _sector(posed[v] + dir * 0.02, hub)
		for step in range(-2, 3):
			for t: int in by_sector[posmod(home + step, SECTORS)]:
				var hit: Variant = Geometry3D.ray_intersects_triangle(from, dir, at[tri[t]], at[tri[t + 1]], at[tri[t + 2]])
				if hit != null and from.distance_to(hit) < REACH:
					covered = true
					break
			if covered:
				break
		if not covered:
			count += 1
	return count


func test_standing_the_trousers_stay_under_the_tunic() -> void:
	var model := await _feyre()
	FilmPose.on(model).to(&"", 0.0)
	var showing := _showing(model, await _drawn(), false)
	gut.p("standing: %d trouser vertices show through the tunic" % showing)
	assert_lte(showing, SHOWING_MOST, "her trousers don't come through her tunic at the hip")


func test_sitting_the_trousers_stay_under_the_tunic() -> void:
	var model := await _feyre()
	var fp := FilmPose.on(model)
	fp.to(&"sit", 0.0, &"chair_dining")
	var showing := _showing(model, await _drawn(), true)
	gut.p("sitting: %d trouser vertices show through the tunic" % showing)
	assert_lte(showing, SHOWING_MOST, "her trousers don't come through her tunic when she sits")


func test_rising_puts_her_whole_trousers_back() -> void:
	var model := await _feyre()
	var trousers := _worn(model, "trousers")
	var whole := trousers.mesh
	var fp := FilmPose.on(model)
	fp.to(&"sit", 0.0, &"chair_dining")
	assert_ne(trousers.mesh, whole, "sitting swaps her trousers for the fitted ones")
	fp.to(&"", 0.0)
	assert_eq(trousers.mesh, whole, "rising puts the same trousers back")


## Sitting, her hem rests on the cushion instead of sinking into it (T057): the flanks of the
## hem hung 6 cm below the cushion's top, and what stood out of its edge showed as a wedge.
func test_sitting_the_hem_rests_on_the_cushion() -> void:
	var model := await _feyre()
	var fp := FilmPose.on(model)
	fp.to(&"sit", 0.0, &"chair_dining")
	var pose := await _drawn()
	var top: float = FilmPose.CHAIRS[&"chair_dining"]["top"]
	var cloth := _skinned(_worn(model, "tunic"), pose)
	var posed: PackedVector3Array = cloth["posed"]
	var lowest := 9.0
	for v: int in cloth["used"]:
		var at := _sk.global_transform * posed[v]
		if absf(at.x) < 0.25 and absf(at.z) < 0.25:
			lowest = minf(lowest, at.y)
	gut.p("sitting: the hem's lowest point is %.1f mm under the cushion's top" % ((top - lowest) * 1000.0))
	assert_gte(lowest, top - 0.002, "no cloth sunk into the cushion")
