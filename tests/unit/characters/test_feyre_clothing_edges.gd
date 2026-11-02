## Feyre's tunic and boots end in clean edges (T057). The tunic's neckline cut every cloth face above
## the collar at any distance from the neck, so each shoulder top had a hole her arm came through,
## and its U left a void under saw-tooth neck skin; the boots' cuff was a saw-tooth over her
## trousers. A look at tools/seated_fit_shot says the cloth reads whole; these read the open
## edges of the meshes as worn.
extends GutTest

## The collar lies at the base of the neck, never lower than this (the old U dropped to 1.21).
const COLLAR_LOW := 1.30
## The shoulder tops, over the body: no cloth edge on them (the flutter sleeve's own end is at 0.19).
const SHOULDER_X := [0.12, 0.18]
const SHOULDER_Y := 1.30
## How much a boot's top edge may rise and fall (the cut saw-tooth was 58 mm).
const CUFF_SPREAD := 0.025


func _dressed(pieces: Array) -> Node3D:
	var model := (load("res://characters/feyre/model/feyre_model.tscn") as PackedScene).instantiate() as Node3D
	var outfit := Wardrobe.new()
	for piece: StringName in pieces:
		outfit.grant(piece)
		outfit.equip(piece)
	if pieces.has(&"spring_tunic_sky"):
		outfit.unequip_slot(&"outer")
	WardrobeApplier.dress(model, outfit)
	add_child_autofree(model)
	return model


func _worn(model: Node, fragment: String) -> MeshInstance3D:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta(&"wardrobe") and String(mi.name).contains(fragment):
			return mi
	return null


## The positions, at rest, of the vertices on an open edge of surface `surface` of `mi`.
func _open_edge_points(mi: MeshInstance3D, surface: int) -> PackedVector3Array:
	var sk := mi.get_node(mi.skeleton) as Skeleton3D
	var arrays := mi.mesh.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var at: PackedVector3Array = SeatSkinFit._rest_frames(mi, verts, PackedVector3Array(), bones, weights, bones.size() / verts.size(), sk)[0]
	var uses := {}   # edge (quantised end points) -> how many triangles use it
	var points := {}
	for t in range(0, index.size() - 2, 3):
		for e in 3:
			var a := _key(at[index[t + e]])
			var b := _key(at[index[t + (e + 1) % 3]])
			if a == b:
				continue
			var edge := [a, b] if a < b else [b, a]
			uses[edge] = int(uses.get(edge, 0)) + 1
			points[a] = at[index[t + e]]
			points[b] = at[index[t + (e + 1) % 3]]
	var open := PackedVector3Array()
	var seen := {}
	for edge: Array in uses.keys():
		if uses[edge] == 1:
			for k in edge:
				if not seen.has(k):
					seen[k] = true
					open.append(points[k])
	return open


func _key(p: Vector3) -> Vector3i:
	return Vector3i((p * 10000.0).round())


func test_no_hole_cut_into_the_shoulder_tops() -> void:
	var model := await _dressed([&"spring_tunic_sky", &"spring_trousers_cream"])
	await wait_process_frames(2)
	var tunic := _worn(model, "tunic")
	var holed := 0
	for p in _open_edge_points(tunic, 0):
		if absf(p.x) > SHOULDER_X[0] and absf(p.x) < SHOULDER_X[1] and p.y > SHOULDER_Y:
			holed += 1
	assert_eq(holed, 0, "no edge of cloth on her shoulder tops, where her arm came through")


func test_the_collar_sits_at_the_base_of_the_neck() -> void:
	var model := await _dressed([&"spring_tunic_sky", &"spring_trousers_cream"])
	await wait_process_frames(2)
	var tunic := _worn(model, "tunic")
	var rim := 0
	var lowest := 9.0
	for p in _open_edge_points(tunic, 0):
		if absf(p.x) < SHOULDER_X[0] and p.y > 1.15:
			rim += 1
			lowest = minf(lowest, p.y)
	gut.p("collar: %d edge vertices, lowest %.3f" % [rim, lowest])
	assert_gt(rim, 10, "the neck opening is found")
	assert_gte(lowest, COLLAR_LOW, "no neckline scoop under her neck skin, where nothing is drawn")


func test_the_boot_cuff_is_an_even_edge() -> void:
	var model := await _dressed([&"hunter_boots", &"hunter_trousers", &"hunter_tunic"])
	await wait_process_frames(2)
	var boots := _worn(model, "boots")
	var tops: Array[float] = []
	for p in _open_edge_points(boots, 0):
		if p.y > 0.2:
			tops.append(p.y)
	assert_gt(tops.size(), 20, "the cuff is found")
	var spread: float = tops.max() - tops.min()
	gut.p("boot cuff: %d vertices, spread %.1f mm" % [tops.size(), spread * 1000.0])
	assert_lt(spread, CUFF_SPREAD, "the top of her boots is not a saw-tooth")
