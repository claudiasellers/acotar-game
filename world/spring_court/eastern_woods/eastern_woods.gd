## The Eastern Woods: deep green-gold woods east of the manor that tip into
## the Bogge's wood (ch. 10, met on a hunt with Lucien) and a dark reed marsh.
extends WoodsRegion


func _water_ribbons() -> Array:
	var out := []
	for seg_group in _stream_lines():
		out.append(["Stream%d" % out.size(), ribbon_arrays(seg_group[0], seg_group[1], func(x: float, z: float) -> float:
			return WorldHeight.height_at(x, z) + 0.9), seg_group[2]])
	return out


func _build_water(parent: Node3D) -> void:
	var T := EasternWoodsTerrain
	var marsh := Vector2(T.REED_MARSH.x, T.REED_MARSH.y)
	var pond := make_pond(Vector3(marsh.x, WorldHeight.height_at(marsh.x, marsh.y) + 2.5, marsh.y), T.REED_MARSH.z * 0.6, true)
	pond.name = "MarshWater"
	parent.add_child(pond)


## Each stream as [points, half_width, dread].
func _stream_lines() -> Array:
	var out := []
	var current := PackedVector2Array()
	var half := 3.5
	var last := Vector2.INF
	for seg in EasternWoodsTerrain.features().segments(&"stream"):
		var a: Vector2 = seg[0]
		if a != last and not current.is_empty():
			out.append([current, half + 2.5, half < 3.0])
			current = PackedVector2Array()
		if current.is_empty():
			current.append(a)
		current.append(seg[1])
		half = seg[2]
		last = seg[1]
	if not current.is_empty():
		out.append([current, half + 2.5, half < 3.0])
	return out


func _build_landmarks(parent: Node3D) -> void:
	var T := EasternWoodsTerrain
	# Standing stones in the stream glen.
	var glen := Vector2(T.STREAM_GLEN.x, T.STREAM_GLEN.y)
	var stones := Node3D.new()
	stones.name = "GlenStones"
	stones.add_to_group(&"landmark")
	parent.add_child(stones)
	landmark_count += 1
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		place_prop(stones, "Stone%d" % i, FloraLibrary.mesh(&"standing_stone"), glen + Vector2(cos(a), sin(a)) * 11.0, a, 1.1, 0.45)
	# The beech hall's king: a giant smooth-barked beech.
	place_landmark(parent, "KingBeech", FloraLibrary.mesh(&"beech"), Vector2(980.0, -480.0), 0.4, 2.2, 1.0)
	# The Bogge's heart: a ring of black trees round a mound of pale fungus.
	var bogge := Vector2(T.BOGGE_HEART.x, T.BOGGE_HEART.y)
	var heart := Node3D.new()
	heart.name = "BoggeHeart"
	heart.add_to_group(&"landmark")
	parent.add_child(heart)
	landmark_count += 1
	for i in 11:
		var a := TAU * i / 11.0
		place_prop(heart, "Dead%d" % i, FloraLibrary.mesh(&"twisted_dead"), bogge + Vector2(cos(a), sin(a)) * (26.0 + 6.0 * sin(i * 3.3)),
				a, 1.5 + 0.3 * cos(i), 0.5)
	place_prop(heart, "Fungus", FloraLibrary.mesh(&"pale_fungus"), bogge, 0.0, 3.0)
	for i in 4:
		place_prop(heart, "Charm%d" % i, FloraLibrary.mesh(&"bone_charm"), bogge + Vector2(cos(i * 1.7), sin(i * 1.7)) * 9.0, i, 1.5)
	# Drowned stumps standing in the marsh water.
	var marsh := Vector2(T.REED_MARSH.x, T.REED_MARSH.y)
	var drowned := Node3D.new()
	drowned.name = "DrownedStumps"
	drowned.add_to_group(&"landmark")
	parent.add_child(drowned)
	landmark_count += 1
	for i in 6:
		var a := TAU * i / 6.0 + 0.2
		place_prop(drowned, "Stump%d" % i, FloraLibrary.far_mesh(&"twisted_dead"), marsh + Vector2(cos(a), sin(a)) * (20.0 + i * 6.0), a, 0.7)
	# A withered rose arch where the blight begins.
	place_landmark(parent, "BlightedArch", FloraLibrary.mesh(&"thornbriar"), Vector2(T.BLIGHT_X - 30.0, -60.0), 0.0, 3.2)

	# Story anchors and mood.
	place_anchor(parent, "BoggeTerritory", bogge, T.BOGGE_HEART.z, "The Bogge's wood: do not look. Tamlin hunts and kills it (ch. 11-12).")
	place_anchor(parent, "NagaMarsh", marsh, T.REED_MARSH.z, "Naga roam Spring under the blight; dark water, reeds over head height.")
	place_fog(parent, "BoggeFog", Vector3(bogge.x, WorldHeight.height_at(bogge.x, bogge.y) + 6.0, bogge.y),
			Vector3(T.BOGGE_HEART.z * 2.6, 40.0, T.BOGGE_HEART.z * 2.6), 0.08, Color(0.22, 0.23, 0.24))
	place_fog(parent, "MarshFog", Vector3(marsh.x, WorldHeight.height_at(marsh.x, marsh.y) + 3.0, marsh.y),
			Vector3(T.REED_MARSH.z * 2.2, 14.0, T.REED_MARSH.z * 2.2), 0.05, Color(0.30, 0.34, 0.30))
	# The light, colour and fog follow dread_at() through AmbientLife's dread
	# mood, so walking out of the Bogge lifts them again.
