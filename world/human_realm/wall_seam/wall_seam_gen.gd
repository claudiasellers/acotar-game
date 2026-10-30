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
	var built := builder.build()
	built.append_array(defile_layers())
	var layers := ForestGenUtil.save_layers(built, DIR + "/scatter")
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

	_build_crossing(root, layers)

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


# --- The wall crossing set piece (experience bar §1.2) ------------------------------
# Compression on this side: the road narrows into a thorn defile, grey, close
# and dim, half-width DEFILE_OPEN at its mouth down to DEFILE_NECK at the gap.
# Release on the far side belongs to the Border Woods (the framed rise); the
# frame marker below is where that view is composed from.

const DEFILE_MOUTH_Z := 1446.0
const DEFILE_OPEN := 7.5
const DEFILE_NECK := 2.4
const FRAME_POINT := Vector2(-100.0, 1362.0)
## The weenie: the Border Woods' great oak (BorderWoodsTerrain.GREAT_OAK).
const WEENIE := Vector2(-150.0, 1080.0)


## Defile half-width at z (between the mouth and the gap).
static func defile_half_width(z: float) -> float:
	var t := clampf((z - WorldMap.WALL_Z) / (DEFILE_MOUTH_Z - WorldMap.WALL_Z), 0.0, 1.0)
	return lerpf(DEFILE_NECK, DEFILE_OPEN, t * t)


## Road centre x at z inside the defile (it eases onto the gap).
static func defile_centre_x(z: float) -> float:
	var t := clampf((z - WorldMap.WALL_Z) / (DEFILE_MOUTH_Z - WorldMap.WALL_Z), 0.0, 1.0)
	return lerpf(WorldMap.WALL_GAP_X, -95.0, t)


static func defile_layers() -> Array[ScatterLayer]:
	var F := "res://world/human_realm/shared/assets/flora/%s.glb"
	var thorn := ForestGenUtil.layer(&"defile_blackthorn", F % "blackthorn_sloe", &"", ["set_piece"], "X", true, 0.15)
	var briar := ForestGenUtil.layer(&"defile_briar", F % "blackberry_bramble", &"", ["set_piece"], "X", true, 0.1)
	var rock := ForestGenUtil.layer(&"defile_rock", F % "rock_boulder_b", &"", ["set_piece"], "X")
	var snag := ForestGenUtil.layer(&"defile_snag", F % "tree_dead_snag", &"", ["set_piece"], "X")
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xDEF11E
	var z := DEFILE_MOUTH_Z + 6.0
	var i := 0
	while z > WorldMap.WALL_Z + 1.0:
		var hw := defile_half_width(z)
		var cx := defile_centre_x(z)
		# The thorns climb as the gap nears: 2.2x at the mouth to 3.4x at the neck.
		var tall := lerpf(3.4, 2.2, clampf((z - WorldMap.WALL_Z) / (DEFILE_MOUTH_Z - WorldMap.WALL_Z), 0.0, 1.0))
		for side in [-1.0, 1.0]:
			var x: float = cx + side * (hw + rng.randf_range(0.4, 1.0))
			var l := thorn if (i + int(side > 0.0)) % 3 != 0 else briar
			ForestGenUtil.put(l, x, z + rng.randf_range(-0.4, 0.4), rng.randf() * TAU, tall * rng.randf_range(0.9, 1.1))
			# A second, taller rank behind closes the sky.
			ForestGenUtil.put(thorn, x + side * rng.randf_range(2.0, 3.0), z + rng.randf_range(-0.8, 0.8), rng.randf() * TAU, tall * 1.25)
			if i % 4 == 2:
				ForestGenUtil.put(rock, x + side * 1.2, z, rng.randf() * TAU, rng.randf_range(1.6, 2.4), -0.3)
			if i % 6 == 3:
				# Dead snags leaning in over the road.
				ForestGenUtil.put(snag, x + side * 0.8, z, (0.5 * PI if side < 0.0 else -0.5 * PI) + rng.randf_range(-0.3, 0.3), rng.randf_range(1.1, 1.4))
		z -= 1.7
		i += 1
	# Lichen-and-frost stone, not flat grey (R3).
	var stone := (ForestGenUtil.FLORA_MAT as ShaderMaterial).duplicate() as ShaderMaterial
	stone.set_shader_parameter(&"use_vertex_color", false)
	stone.set_shader_parameter(&"albedo", Color(0.66, 0.63, 0.56))
	stone.set_shader_parameter(&"translucency", 0.0)
	stone.set_shader_parameter(&"flex_height", 100.0)
	stone.set_shader_parameter(&"wind_amount", 0.0)
	stone.set_shader_parameter(&"snow_catch", 0.9)
	rock.material = stone
	for l in [thorn, briar, rock, snag]:
		l.draw_distance = 160.0
	return [thorn, briar, rock, snag]


func _build_crossing(root: Node3D, layers: Array[ScatterLayer]) -> void:
	var sp := Node3D.new()
	sp.name = "WallCrossing"
	root.add_child(sp)
	sp.owner = root
	# Thorn walls hold the player in the defile.
	var body := StaticBody3D.new()
	body.name = "DefileWalls"
	sp.add_child(body)
	body.owner = root
	var z := DEFILE_MOUTH_Z
	while z > WorldMap.WALL_Z + 0.5:
		for side in [-1.0, 1.0]:
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.2, 6.0, 2.2)
			cs.shape = box
			var x: float = defile_centre_x(z) + side * (defile_half_width(z) + 0.9)
			cs.position = Vector3(x, WorldHeight.height_at(x, z) + 3.0, z)
			body.add_child(cs)
			cs.owner = root
		z -= 2.0
	# Dim and close: a grey haze inside the defile only.
	var haze := FogVolume.new()
	haze.name = "DefileHaze"
	haze.size = Vector3(DEFILE_OPEN * 2.0, 7.0, DEFILE_MOUTH_Z - WorldMap.WALL_Z)
	var hm := FogMaterial.new()
	hm.density = 0.08
	hm.albedo = Color(0.62, 0.66, 0.72)
	haze.material = hm
	var mid_z := (DEFILE_MOUTH_Z + WorldMap.WALL_Z) * 0.5
	haze.position = Vector3(defile_centre_x(mid_z), WorldHeight.height_at(-98.0, mid_z) + 3.0, mid_z)
	sp.add_child(haze)
	haze.owner = root
	# The lure: past the neck, spring glows green-gold through the gap, the
	# brightest and warmest thing in the grey.
	var lure := OmniLight3D.new()
	lure.name = "SpringLure"
	lure.light_color = Color(1.0, 0.88, 0.55)
	lure.light_energy = 6.0
	lure.omni_range = 18.0
	lure.position = Vector3(WorldMap.WALL_GAP_X, WorldHeight.height_at(WorldMap.WALL_GAP_X, WorldMap.WALL_Z - 6.0) + 2.5, WorldMap.WALL_Z - 6.0)
	sp.add_child(lure)
	lure.owner = root
	var veil := MeshInstance3D.new()
	veil.name = "SpringGlow"
	var q := QuadMesh.new()
	q.size = Vector2(10.0, 9.0)
	veil.mesh = q
	var vm := StandardMaterial3D.new()
	vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var gg := Gradient.new()
	gg.set_color(0, Color(1.0, 0.86, 0.42, 1.0))
	gg.set_color(1, Color(0.45, 0.8, 0.42, 0.0))
	gg.add_point(0.55, Color(0.62, 0.9, 0.4, 0.9))
	var gt := GradientTexture2D.new()
	gt.gradient = gg
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.6)
	gt.fill_to = Vector2(1.0, 0.6)
	vm.albedo_texture = gt
	vm.emission_enabled = true
	vm.emission = Color(1.0, 0.9, 0.55)
	vm.emission_energy_multiplier = 4.0
	vm.cull_mode = BaseMaterial3D.CULL_DISABLED
	veil.material_override = vm
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	veil.position = Vector3(WorldMap.WALL_GAP_X, WorldHeight.height_at(WorldMap.WALL_GAP_X, WorldMap.WALL_Z - 3.0) + 3.4, WorldMap.WALL_Z - 3.0)
	sp.add_child(veil)
	veil.owner = root

	# Geometry for the lure: sunlit blossom boughs arching over the far side
	# of the gap, a warm pool on the snow for the last ~10 m, and petals
	# drifting back through the neck toward the player.
	var gy := WorldHeight.height_at(WorldMap.WALL_GAP_X, WorldMap.WALL_Z - 3.0)
	for side in [-1.0, 1.0]:
		var bough := MeshInstance3D.new()
		bough.name = "BlossomBough" + ("West" if side < 0.0 else "East")
		bough.mesh = blossom_bough_mesh(side, 0xB10550 + int(side > 0.0))
		bough.position = Vector3(WorldMap.WALL_GAP_X, gy + 1.5, WorldMap.WALL_Z - 3.0)
		bough.scale = Vector3.ONE * 1.9
		bough.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.add_child(bough)
		bough.owner = root
	var pool := SpotLight3D.new()
	pool.name = "WarmPool"
	pool.light_color = Color(1.0, 0.82, 0.5)
	pool.light_energy = 5.0
	pool.spot_range = 16.0
	pool.spot_angle = 32.0
	pool.position = Vector3(WorldMap.WALL_GAP_X, WorldHeight.height_at(WorldMap.WALL_GAP_X, WorldMap.WALL_Z + 5.0) + 9.0, WorldMap.WALL_Z + 5.0)
	pool.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	sp.add_child(pool)
	pool.owner = root
	var petals := CPUParticles3D.new()
	petals.name = "DriftingPetals"
	petals.amount = 40
	petals.lifetime = 9.0
	petals.preprocess = 9.0
	petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	petals.emission_box_extents = Vector3(3.0, 1.5, 1.0)
	petals.direction = Vector3(0.0, -0.15, 1.0)
	petals.spread = 25.0
	petals.initial_velocity_min = 0.8
	petals.initial_velocity_max = 1.4
	petals.gravity = Vector3(0.0, -0.12, 0.0)
	petals.angular_velocity_min = -90.0
	petals.angular_velocity_max = 90.0
	petals.color = Color(1.0, 0.78, 0.86)
	var pq := QuadMesh.new()
	pq.size = Vector2(0.06, 0.045)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pmat.vertex_color_use_as_albedo = true
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pq.material = pmat
	petals.mesh = pq
	petals.position = Vector3(WorldMap.WALL_GAP_X, gy + 2.5, WorldMap.WALL_Z - 2.0)
	sp.add_child(petals)
	petals.owner = root

	# Where the release view is composed from: just past the gap, looking at
	# the weenie (-Z faces it).
	var frame := Marker3D.new()
	frame.name = "wall_crossing_frame"
	var fp := Vector3(FRAME_POINT.x, WorldHeight.height_at(FRAME_POINT.x, FRAME_POINT.y) + 1.6, FRAME_POINT.y)
	var wp := Vector3(WEENIE.x, WorldHeight.height_at(WEENIE.x, WEENIE.y) + 25.0, WEENIE.y)
	frame.transform = Transform3D.IDENTITY.looking_at(wp - fp, Vector3.UP).translated(fp)
	frame.set_meta(&"fov", 55.0)
	frame.set_meta(&"shot", "wall_crossing")
	frame.add_to_group(&"shot_frame", true)
	sp.add_child(frame)
	frame.owner = root
	for l in layers:
		if l.id == &"defile_rock":
			ForestGenUtil.layer_collision(sp, root, "DefileRocks", l, "res://world/human_realm/shared/assets/flora/rock_boulder_b.glb")


## One bough reaching in over the gap from `side` (-1 west, 1 east), local to
## the gap: a curved limb with pink and white blossom clusters, one mesh.
static func blossom_bough_mesh(side: float, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.43, 0.32, 0.33)
	var pts: Array[Vector3] = []
	for i in 9:
		var t := i / 8.0
		pts.append(Vector3(side * lerpf(6.5, 0.6, t), lerpf(0.0, 4.6, sqrt(t)) - 0.8 * t * t, lerpf(0.0, -1.5, t)))
	for i in pts.size() - 1:
		_limb(st, pts[i], pts[i + 1], lerpf(0.22, 0.05, float(i) / 8.0), bark)
	var pinks := [Color(0.96, 0.65, 0.75), Color(0.98, 0.83, 0.86), Color(0.98, 0.97, 0.95)]
	for i in range(3, pts.size()):
		for k in 3:
			var c: Vector3 = pts[i] + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.3, 0.6), rng.randf_range(-0.6, 0.6))
			_puff(st, c, rng.randf_range(0.45, 0.8), pinks[rng.randi() % pinks.size()])
	st.generate_normals()
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.82)
	mat.emission_energy_multiplier = 0.35
	m.surface_set_material(0, mat)
	return m


static func _limb(st: SurfaceTool, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var d := (b - a).normalized()
	var u := d.cross(Vector3.FORWARD if absf(d.z) < 0.9 else Vector3.RIGHT).normalized()
	var v := d.cross(u)
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		var o0 := (u * cos(a0) + v * sin(a0)) * r
		var o1 := (u * cos(a1) + v * sin(a1)) * r
		for p in [a + o0, b + o0 * 0.8, b + o1 * 0.8, a + o0, b + o1 * 0.8, a + o1]:
			st.set_color(col)
			st.add_vertex(p)


## A faceted blossom cluster (octahedron squashed a little).
static func _puff(st: SurfaceTool, c: Vector3, r: float, col: Color) -> void:
	var px := [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(0, 0, -r)]
	var top := c + Vector3(0, r * 0.75, 0)
	var bot := c - Vector3(0, r * 0.6, 0)
	for k in 4:
		var p0: Vector3 = c + px[k]
		var p1: Vector3 = c + px[(k + 1) % 4]
		for p in [top, p1, p0, bot, p0, p1]:
			st.set_color(col)
			st.add_vertex(p)
