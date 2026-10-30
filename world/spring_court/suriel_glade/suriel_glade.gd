## The Suriel's glade in the western woods: young birches by the Thornwater
## (ch. 13-15). The snare, the waiting tree, and the naga's backwater.
extends WoodsRegion


func _build_water(parent: Node3D) -> void:
	var river := resample(clip_to_bounds(MacroHeight.THORNWATER, 60.0), 4.0)
	if river.size() < 2:
		# The glade is short: take the two Thornwater points around it.
		river = resample(PackedVector2Array([Vector2(-950.0, 150.0), Vector2(-820.0, 520.0), Vector2(-700.0, 800.0)]), 4.0)
	var ribbon := make_water_ribbon(river, MacroHeight.RIVER_HALF_WIDTH + 12.0, func(x: float, z: float) -> float:
		return MacroHeight.land_height_at(x, z) - MacroHeight.RIVER_DEPTH + 1.4)
	ribbon.name = "Thornwater"
	parent.add_child(ribbon)
	var bw := SurielGladeTerrain.NAGA_BACKWATER
	var pond := make_pond(Vector3(bw.x, WorldHeight.height_at(bw.x, bw.y) + 1.6, bw.y), bw.z * 0.7, true)
	pond.name = "NagaBackwater"
	parent.add_child(pond)


func _build_landmarks(parent: Node3D) -> void:
	var T := SurielGladeTerrain
	place_landmark(parent, "WaitingOak", FloraLibrary.mesh(&"oak"), T.WAITING_OAK, 1.1, 1.4, 0.7)
	var ring := Node3D.new()
	ring.name = "BirchRing"
	ring.add_to_group(&"landmark")
	parent.add_child(ring)
	landmark_count += 1
	for i in 8:
		var a := TAU * i / 8.0
		place_prop(ring, "Birch%d" % i, FloraLibrary.mesh(&"silver_birch"), T.SNARE_SITE + Vector2(cos(a), sin(a)) * 18.0, a, 0.8, 0.22)
	var bw := Vector2(T.NAGA_BACKWATER.x, T.NAGA_BACKWATER.y)
	var drowned := Node3D.new()
	drowned.name = "DrownedAlders"
	drowned.add_to_group(&"landmark")
	parent.add_child(drowned)
	landmark_count += 1
	for i in 5:
		var a := TAU * i / 5.0
		place_prop(drowned, "Stump%d" % i, FloraLibrary.far_mesh(&"twisted_dead"), bw + Vector2(cos(a), sin(a)) * (8.0 + i * 3.0), a, 0.6)
	# Story contract anchor: Feyre stands here, -Z faces the snare and the
	# water the naga come out of.
	var snare := place_anchor(parent, "suriel_snare", T.SNARE_SITE + Vector2(-4.0, -6.0), 12.0,
			"ch. 14-15: double-loop snare, chicken bait, young birches by running water; waiting oak within 12 m; four naga.")
	snare.look_at(snare.position + Vector3(T.SNARE_SITE.x + 20.0 - snare.position.x, 0.0, T.SNARE_SITE.y + 10.0 - snare.position.z), Vector3.UP)
	place_fog(parent, "BackwaterMist", Vector3(bw.x, WorldHeight.height_at(bw.x, bw.y) + 2.0, bw.y),
			Vector3(T.NAGA_BACKWATER.z * 2.4, 8.0, T.NAGA_BACKWATER.z * 2.4), 0.05, Color(0.30, 0.34, 0.32))
