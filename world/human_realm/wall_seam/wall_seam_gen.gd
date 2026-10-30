## Generator for the wall seam (run headless, deterministic):
##   godot --headless -s res://world/human_realm/wall_seam/wall_seam_gen.gd
## Writes scatter/<layer>.tres, wall_seam_report.json, wall_seam.tscn and
## data/regions/human_realm/wall_seam.tres.
extends SceneTree

const ID := &"wall_seam"
const DIR := "res://world/human_realm/wall_seam"
const A := "res://world/human_realm/wall_seam/assets/%s.glb"

var _landmarks := 0
var _node_positions := PackedVector3Array()


func _initialize() -> void:
	var builder := WallSeamBuilder.new()
	var layers := ForestGenUtil.save_layers(builder.build(), DIR + "/scatter")
	var rect: Rect2 = HumanRealmLayout.REGION_RECTS[ID]

	var root := Node3D.new()
	root.name = "WallSeam"
	var field := ScatterField.new()
	field.name = "ScatterField"
	field.region_id = ID
	field.layers = layers
	root.add_child(field)
	field.owner = root

	var trunks := ForestTrunkCollision.new()
	trunks.name = "TrunkCollision"
	var tree_layers: Array[ScatterLayer] = []
	for l in layers:
		if l.id == &"tree_snag":
			tree_layers.append(l)
	trunks.layers = tree_layers
	trunks.radii = PackedFloat32Array([0.3])
	trunks.heights = PackedFloat32Array([4.0])
	root.add_child(trunks)
	trunks.owner = root

	# The Wall: the shimmer and the felt volume.
	var shimmer := WallShimmer.new()
	shimmer.name = "WallShimmer"
	root.add_child(shimmer)
	shimmer.owner = root
	_node_positions.append(Vector3(WorldMap.WALL_GAP_X, 0.0, WorldMap.WALL_Z))
	var sense := WallSenseVolume.new()
	sense.name = "WallSenseVolume"
	sense.add_to_group(&"no_birds_zone", true)
	root.add_child(sense)
	sense.owner = root
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(sense.x_max - sense.x_min + sense.sense_depth * 2.0, 400.0, sense.sense_depth * 2.0)
	cs.shape = box
	cs.position = Vector3((sense.x_min + sense.x_max) * 0.5, 0.0, sense.wall_z)
	sense.add_child(cs)
	cs.owner = root

	var lm := Node3D.new()
	lm.name = "Landmarks"
	root.add_child(lm)
	lm.owner = root
	var gap := WallSeamBuilder.GAP
	# The two old leaning stones at the gap, leaning in toward each other.
	_lm(lm, root, "GapStoneWest", A % "leaning_stone", gap + Vector2(-5.0, 2.0), 0.0)
	_lm(lm, root, "GapStoneEast", A % "leaning_stone", gap + Vector2(5.0, 2.0), PI)
	_lm(lm, root, "GreatWarningCairn", A % "great_cairn", WallSeamBuilder.GREAT_CAIRN, 0.6)
	_lm(lm, root, "OfferingPost", A % "offering_post", WallSeamBuilder.OFFERING_POST, ForestGenUtil.yaw_facing(Vector2(0.0, 1.0)))
	_lm(lm, root, "IronWardPost", A % "iron_post", WallSeamBuilder.IRON_POST, PI)
	_landmarks += 1  # the iron stake fence line (scatter)

	var gate := Marker3D.new()
	gate.name = "wall_gate_north"
	gate.position = Vector3(gap.x, WorldHeight.height_at(gap.x, gap.y + 2.0), gap.y + 2.0)
	gate.rotation.y = 0.0  # Marker3D faces -Z (north) by default
	gate.add_to_group(&"story_anchor", true)
	root.add_child(gate)
	gate.owner = root

	# The ride north: village north road -> the gap -> into Prythian.
	var path := Path3D.new()
	path.name = "WallSeamPath"
	var curve := Curve3D.new()
	for p: Vector2 in [WallSeamBuilder.ROAD_IN, Vector2(-90.0, 1450.0), Vector2(-97.0, 1415.0), gap, Vector2(-100.0, 1350.0), Vector2(-100.0, 1300.0)]:
		curve.add_point(Vector3(p.x, WorldHeight.height_at(p.x, p.y) + 0.1, p.y))
	path.curve = curve
	root.add_child(path)
	path.owner = root

	# A cold low mist banked along the line.
	var fog := FogVolume.new()
	fog.name = "LineMist"
	fog.size = Vector3(rect.size.x, 3.0, 14.0)
	var mat := FogMaterial.new()
	mat.density = 0.04
	mat.albedo = Color(0.85, 0.9, 0.97)
	fog.material = mat
	fog.position = Vector3(rect.get_center().x, WorldHeight.height_at(-100.0, 1406.0) + 0.5, WorldMap.WALL_Z + 6.0)
	root.add_child(fog)
	fog.owner = root

	var draw_calls := ForestGenUtil.estimate_draw_calls(layers, rect, _node_positions)
	var report := ScatterReport.compute(layers, rect, _landmarks, draw_calls)
	ScatterReport.save(report, DIR + "/wall_seam_report.json")
	ForestGenUtil.save_scene(root, DIR + "/wall_seam.tscn")
	ForestGenUtil.save_region_def(ID, rect, PackedStringArray(["hunting_forest"]))
	root.free()
	var total := 0
	for l in layers:
		total += l.count()
	print("wall_seam: %d layers, %d instances, report %s" % [layers.size(), total, JSON.stringify(report)])
	quit()


func _lm(parent: Node, root: Node, name: String, asset: String, p: Vector2, yaw: float) -> void:
	var n := ForestGenUtil.landmark(parent, root, name, asset, p, yaw)
	n.add_to_group(&"landmark", true)
	_landmarks += 1
	_node_positions.append(n.position)
