## Generator for the winter hunting forest (run headless, deterministic):
##   godot --headless -s res://world/human_realm/hunting_forest/hunting_forest_gen.gd
## Writes scatter/<layer>.tres, hunting_forest_report.json, hunting_forest.tscn
## and data/regions/human_realm/hunting_forest.tres.
extends SceneTree

const ID := &"hunting_forest"
const DIR := "res://world/human_realm/hunting_forest"
const A := "res://world/human_realm/hunting_forest/assets/%s.glb"

## Trunk radius and collision height at scale 1, per tree layer (measured
## from the flora library's meshes).
const TRUNKS := {
	&"tree_oak": Vector2(0.36, 4.0), &"tree_birch": Vector2(0.18, 4.0), &"tree_pine": Vector2(0.32, 5.0),
	&"tree_spruce": Vector2(0.3, 5.0), &"tree_snag": Vector2(0.3, 4.0), &"tree_willow": Vector2(0.4, 3.0),
	&"tree_ash": Vector2(0.3, 5.0), &"waiting_oak": Vector2(1.1, 5.0),
}

var _landmarks := 0
var _node_positions := PackedVector3Array()


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var builder := HuntingForestBuilder.new()
	var built := builder.build()
	var layers := ForestGenUtil.save_layers(built, DIR + "/scatter")
	var rect: Rect2 = HumanRealmLayout.REGION_RECTS[ID]

	var root := Node3D.new()
	root.name = "HuntingForest"
	var field := ScatterField.new()
	field.name = "ScatterField"
	field.region_id = ID
	field.layers = layers
	root.add_child(field)
	field.owner = root

	var trunks := ForestTrunkCollision.new()
	trunks.name = "TrunkCollision"
	var tree_layers: Array[ScatterLayer] = []
	var radii := PackedFloat32Array()
	var heights := PackedFloat32Array()
	for l in layers:
		if TRUNKS.has(l.id):
			tree_layers.append(l)
			radii.append(TRUNKS[l.id].x)
			heights.append(TRUNKS[l.id].y)
	trunks.layers = tree_layers
	trunks.radii = radii
	trunks.heights = heights
	root.add_child(trunks)
	trunks.owner = root

	var walls := Node3D.new()
	walls.name = "WallCollision"
	root.add_child(walls)
	walls.owner = root
	for l in layers:
		var src := {&"ash_wall": "ash_wall_segment", &"ash_wall_slump": "ash_wall_slump", &"park_wall": "boundary_wall_section", &"park_wall_end": "boundary_wall_end"}
		if src.has(l.id):
			ForestGenUtil.layer_collision(walls, root, String(l.id).to_pascal_case(), l, A % src[l.id])

	_build_landmarks(root, builder)
	_build_mood(root, builder)

	var draw_calls := ForestGenUtil.estimate_draw_calls(layers, rect, _node_positions)
	var report := ScatterReport.compute(layers, rect, _landmarks, draw_calls)
	ScatterReport.save(report, DIR + "/hunting_forest_report.json")
	ForestGenUtil.save_scene(root, DIR + "/hunting_forest.tscn")
	ForestGenUtil.save_region_def(ID, rect, PackedStringArray(["wall_seam", "cottage", "village", "workshop"]))
	root.free()

	var total := 0
	for l in layers:
		total += l.count()
	print("hunting_forest: %d layers, %d instances, report %s (%d ms)" % [layers.size(), total, JSON.stringify(report), Time.get_ticks_msec() - t0])
	quit()


func _lm(parent: Node, root: Node, name: String, asset: String, p: Vector2, yaw: float, scale := 1.0, y := 0.0) -> Node3D:
	var n := ForestGenUtil.landmark(parent, root, name, asset, p, yaw, scale, y)
	n.add_to_group(&"landmark", true)
	_landmarks += 1
	_node_positions.append(n.position)
	return n


func _group(parent: Node, name: String, owner: Node = null) -> Node3D:
	var g := Node3D.new()
	g.name = name
	parent.add_child(g)
	g.owner = owner if owner != null else parent
	return g


func _marker(parent: Node, root: Node, name: String, p: Vector2, yaw := 0.0, lift := 0.0) -> Marker3D:
	var m := Marker3D.new()
	m.name = name
	m.position = Vector3(p.x, WorldHeight.height_at(p.x, p.y) + lift, p.y)
	m.rotation.y = yaw
	parent.add_child(m)
	m.owner = root
	m.add_to_group(&"story_anchor", true)
	return m


func _build_landmarks(root: Node3D, b: HuntingForestBuilder) -> void:
	var lm := _group(root, "Landmarks")

	# The waiting oak (a scatter instance, so the flora library's hero mesh can
	# land later) + its trunk collision is in TrunkCollision. Feyre's hide.
	_landmarks += 1  # the waiting oak itself
	var hide_yaw := ForestGenUtil.yaw_facing(HumanRealmLayout.DOE_CLEARING - HuntingForestBuilder.HIDE)
	_lm(lm, root, "HuntersHide", A % "hunters_hide", HuntingForestBuilder.HIDE, hide_yaw)
	_marker(lm, root, "WaitingOakSeat", HumanRealmLayout.WAITING_OAK + Vector2(1.6, -0.8), hide_yaw, 1.4)
	_marker(lm, root, "DoeClearing", HumanRealmLayout.DOE_CLEARING)
	# Act I: Feyre at the thicket edge; the doe stands 22 m along -Z, the wolf
	# comes from ~33 m (story anchor, world.md).
	_marker(lm, root, "act1_wolf_clearing", HumanRealmLayout.DOE_CLEARING + Vector2(0.0, 22.0), 0.0)

	# The old noble hunting lodge, its deer stand.
	_lm(lm, root, "HuntingLodgeRuin", A % "lodge_ruin", HumanRealmLayout.HUNTING_LODGE, 0.35, 1.0, -0.1)
	_marker(lm, root, "LodgeHearth", HumanRealmLayout.HUNTING_LODGE + Vector2(-7.2, -2.4).rotated(-0.35))
	_lm(lm, root, "RottedDeerStand", A % "deer_stand", HuntingForestBuilder.DEER_STAND, 0.8)

	# The walled ash grove: wall runs are scatter; gate, water grates, keeper.
	var grove := _group(lm, "AshGroveWalled", root)
	grove.add_to_group(&"landmark", true)
	_landmarks += 1
	var gate_p := HumanRealmLayout.ASH_GROVE + Vector2(HuntingForestBuilder.GROVE_RADIUS, 0.0)
	_lm(grove, root, "AshGroveGate", A % "ash_gate", gate_p, ForestGenUtil.yaw_facing(Vector2(-1.0, 0.0)), 1.0, -0.2)
	var crossings := HuntingForestBuilder.creek_crossings()
	for i in crossings.size():
		var a: float = crossings[i]
		var p := HumanRealmLayout.ASH_GROVE + Vector2(cos(a), sin(a)) * HuntingForestBuilder.GROVE_RADIUS
		var asset := "water_grate_broken" if i == 0 else "water_grate"
		_lm(grove, root, "WaterGrate%d" % i, A % asset, p, ForestGenUtil.yaw_facing(-Vector2(cos(a), sin(a))), 1.0, 1.2)
		if i == 0:
			_marker(grove, root, "AshGroveGap", p, ForestGenUtil.yaw_facing(-Vector2(cos(a), sin(a))))
	var slump_a := deg_to_rad(-125.0)
	_marker(grove, root, "AshGroveClimb", HumanRealmLayout.ASH_GROVE + Vector2(cos(slump_a), sin(slump_a)) * (HuntingForestBuilder.GROVE_RADIUS + 1.5))
	_lm(grove, root, "GamekeeperHut", A % "gamekeeper_hut", HuntingForestBuilder.KEEPER_HUT, ForestGenUtil.yaw_facing(gate_p - HuntingForestBuilder.KEEPER_HUT))
	var lanterns := [gate_p + Vector2(2.0, -4.2), gate_p + Vector2(2.0, 4.2), HuntingForestBuilder.KEEPER_HUT + Vector2(-3.0, 4.0)]
	for k in [-0.9, -0.45, 0.6, 1.1]:
		lanterns.append(HumanRealmLayout.ASH_GROVE + Vector2(cos(k), sin(k)) * (HuntingForestBuilder.GROVE_RADIUS + 3.0))
	for i in lanterns.size():
		var lp: Vector2 = lanterns[i]
		var post := ForestGenUtil.landmark(grove, root, "LanternPost%d" % i, A % "lantern_post", lp, rng_yaw(i))
		_node_positions.append(post.position)
		var light := OmniLight3D.new()
		light.name = "LanternLight%d" % i
		light.light_color = Color(1.0, 0.74, 0.42)
		light.light_energy = 1.4
		light.omni_range = 9.0
		light.shadow_enabled = false
		light.position = post.position + Basis(Vector3.UP, rng_yaw(i)) * Vector3(0.5, 2.15, 0.0)
		grove.add_child(light)
		light.owner = root

	# The creek: the frozen fall, the lightning-split oak, the woodcutter's lean-to.
	var fall_dir := _creek_dir(HuntingForestBuilder.FALL)
	_lm(lm, root, "FrozenFall", A % "frozen_fall", HuntingForestBuilder.FALL, ForestGenUtil.yaw_facing(fall_dir), 1.0, -0.6)
	_lm(lm, root, "LightningSplitOak", A % "split_oak", HuntingForestBuilder.SPLIT_OAK, 1.1)
	_lm(lm, root, "WoodcuttersLeanTo", A % "woodcutter_leanto", HuntingForestBuilder.LEANTO, ForestGenUtil.yaw_facing(Vector2(0.4, -1.0)))

	# The long ride north to the Wall (ROADS[1]): bridge, crossroads, shrine,
	# the abandoned farmstead, waystones.
	var ride := _group(lm, "RideNorth", root)
	var bridge: Array = HuntingForestBuilder.bridge_site()
	var bp: Vector2 = bridge[0]
	var road_dir: Vector2 = bridge[1]
	_lm(ride, root, "FrozenBridge", A % "frozen_bridge", bp, ForestGenUtil.yaw_along(road_dir), 1.0, -0.6)
	var cr := HuntingForestBuilder.crossroads()
	var road := HumanRealmLayout.ROADS[1]
	var side := Vector2(-road_dir.y, road_dir.x)
	_lm(ride, root, "CrossroadsGibbet", A % "gibbet", cr + side * 7.0 + road_dir * 4.0, ForestGenUtil.yaw_along(road_dir))
	_lm(ride, root, "BrokenSignpost", A % "broken_signpost", cr - side * 5.0 - road_dir * 3.0, 0.4)
	var sh: Array = ForestGenUtil.along(road, HuntingForestBuilder.SHRINE_S)
	var shp: Vector2 = sh[0]
	var shd: Vector2 = sh[1]
	_lm(ride, root, "RoadsideShrine", A % "roadside_shrine", shp + Vector2(-shd.y, shd.x) * 5.0, ForestGenUtil.yaw_facing(-Vector2(-shd.y, shd.x)))
	var cand := OmniLight3D.new()
	cand.name = "ShrineCandles"
	cand.light_color = Color(1.0, 0.8, 0.5)
	cand.light_energy = 0.5
	cand.omni_range = 3.0
	var shpos := shp + Vector2(-shd.y, shd.x) * 5.0
	cand.position = Vector3(shpos.x, WorldHeight.height_at(shpos.x, shpos.y) + 1.5, shpos.y)
	ride.add_child(cand)
	cand.owner = root
	_lm(ride, root, "AbandonedFarmstead", A % "farmstead", HuntingForestBuilder.FARMSTEAD, ForestGenUtil.yaw_facing(_nearest_road_dir(HuntingForestBuilder.FARMSTEAD)))
	var length := ForestGenUtil.polyline_length(road)
	var s := 40.0
	var n := 0
	while s < length:
		var at: Array = ForestGenUtil.along(road, s)
		var p: Vector2 = at[0]
		var d: Vector2 = at[1]
		var q := p + Vector2(-d.y, d.x) * (4.5 if n % 2 == 0 else -4.5)
		if b.rect.has_point(q) and q.distance_to(bp) > 15.0 and q.distance_to(cr) > 15.0 and q.distance_to(shp) > 12.0 and ForestGenUtil.off_creek(q, 2.0):
			_lm(ride, root, "Waystone%d" % n, A % "waystone", q, ForestGenUtil.yaw_along(d))
			n += 1
		s += 110.0


func rng_yaw(i: int) -> float:
	return fposmod(i * 2.399, TAU)


func _creek_dir(p: Vector2) -> Vector2:
	var best := INF
	var dir := Vector2.RIGHT
	for i in HumanRealmLayout.CREEK.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, HumanRealmLayout.CREEK[i], HumanRealmLayout.CREEK[i + 1])
		if p.distance_to(q) < best:
			best = p.distance_to(q)
			dir = (HumanRealmLayout.CREEK[i + 1] - HumanRealmLayout.CREEK[i]).normalized()
	return dir


func _nearest_road_dir(p: Vector2) -> Vector2:
	var road := HumanRealmLayout.ROADS[1]
	var best := INF
	var dir := Vector2.RIGHT
	for i in road.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, road[i], road[i + 1])
		if p.distance_to(q) < best:
			best = p.distance_to(q)
			dir = (q - p).normalized()
	return dir


func _build_mood(root: Node3D, _b: HuntingForestBuilder) -> void:
	var mood := _group(root, "Mood")
	# Cold mist pooled in the creek hollows, at the fall, and in the walled grove.
	for f: Array in [[HuntingForestBuilder.FALL, Vector3(28, 5, 28), 0.05], [HumanRealmLayout.WAITING_OAK + Vector2(60, 40), Vector3(60, 4, 40), 0.03],
			[HumanRealmLayout.ASH_GROVE, Vector3(70, 6, 70), 0.03], [HumanRealmLayout.HUNTING_LODGE, Vector3(40, 6, 40), 0.035],
			[Vector2(-150.0, 1900.0), Vector3(50, 4, 30), 0.03]]:
		var p: Vector2 = f[0]
		var fog := FogVolume.new()
		fog.name = "Mist_%d_%d" % [int(p.x), int(p.y)]
		fog.size = f[1]
		fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		var mat := FogMaterial.new()
		mat.density = f[2]
		mat.albedo = Color(0.82, 0.86, 0.94)
		fog.material = mat
		fog.position = Vector3(p.x, WorldHeight.height_at(p.x, p.y) + 1.0, p.y)
		mood.add_child(fog)
		fog.owner = root
	# The gamekeeper's lit window.
	var win := OmniLight3D.new()
	win.name = "KeeperWindow"
	win.light_color = Color(1.0, 0.7, 0.38)
	win.light_energy = 1.0
	win.omni_range = 7.0
	win.position = Vector3(HuntingForestBuilder.KEEPER_HUT.x, WorldHeight.height_at(HuntingForestBuilder.KEEPER_HUT.x, HuntingForestBuilder.KEEPER_HUT.y) + 1.4, HuntingForestBuilder.KEEPER_HUT.y)
	mood.add_child(win)
	win.owner = root
