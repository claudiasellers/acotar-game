## The Border Woods: the first sight of the Spring Court past the Wall.
extends WoodsRegion

const HERO_FOLIAGE := preload("res://world/spring_court/shared/woods_foliage_hero.gdshader")

static var _spray: Array = []

var _ford := Vector2.ZERO


func _prepare_extra() -> void:
	_ford = _ford_point()


func _water_ribbons() -> Array:
	var river := resample(clip_to_bounds(MacroHeight.THORNWATER, 40.0), 4.0)
	if river.size() < 2:
		return []
	return [["Thornwater", ribbon_arrays(river, MacroHeight.RIVER_HALF_WIDTH + 12.0, thornwater_level), false]]


func _build_water(parent: Node3D) -> void:
	var hollow := Vector2(BorderWoodsTerrain.FAELIGHT_HOLLOW.x, BorderWoodsTerrain.FAELIGHT_HOLLOW.y)
	var pool_level := WorldHeight.height_at(hollow.x, hollow.y) + 0.8
	var pool := make_pond(Vector3(hollow.x, pool_level, hollow.y - 12.0), 24.0)
	pool.name = "FaelightPool"
	parent.add_child(pool)
	defer(_build_rainbow_falls.bind(parent, pool_level))


## Canon rainbow falls (ch. 23): a sheet of water off the bluff's lip into
## the faelight pool, hue bands sliding down it, spray and a rainbow mist.
func _build_rainbow_falls(parent: Node3D, pool_level: float) -> void:
	var lip := BorderWoodsTerrain.FALLS_LIP
	var top := WorldHeight.height_at(lip.x, lip.y - 6.0) + 0.3
	var falls := Node3D.new()
	falls.name = "RainbowFalls"
	falls.add_to_group(&"landmark")
	parent.add_child(falls)
	landmark_count += 1
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rows := 12
	var width := 7.0
	for r in rows + 1:
		var t := float(r) / rows
		var y := lerpf(top, pool_level, t)
		var out := 1.5 * sin(t * PI * 0.5) + 2.0 * t  # the sheet arcs out from the lip
		for side in [-1.0, 1.0]:
			verts.append(Vector3(lip.x + side * width * (0.5 + 0.15 * t), y, lip.y - 6.0 + out + 4.0 * t))
			uvs.append(Vector2(0.5 + side * 0.5, t * 20.0))
		if r > 0:
			var a := (r - 1) * 2
			indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := water_material(false)
	mat.set_shader_parameter(&"rainbow", 0.55)
	mat.set_shader_parameter(&"flow_speed", -6.0)
	mat.set_shader_parameter(&"clarity", 0.75)
	mesh.surface_set_material(0, mat)
	var sheet := MeshInstance3D.new()
	sheet.name = "Sheet"
	sheet.mesh = mesh
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	falls.add_child(sheet)
	var spray := GPUParticles3D.new()
	spray.name = "Spray"
	spray.amount = 160
	spray.lifetime = 2.5
	if _spray.is_empty():
		_spray = _make_spray(width)
	spray.process_material = _spray[0]
	spray.draw_pass_1 = _spray[1]
	spray.position = Vector3(lip.x, pool_level + 0.3, lip.y + 4.0)
	falls.add_child(spray)


## [process material, draw mesh] for the falls' spray, shared across loads:
## binding a fresh process material compiles its shader (~4 ms).
static func _make_spray(width: float) -> Array:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(width * 0.6, 0.5, 1.5)
	pm.direction = Vector3(0, 1, 0.4)
	pm.spread = 50.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -1.2, 0)
	# Pastel rainbow mist (R3): each droplet takes a hue from rose to lilac.
	var hues := Gradient.new()
	hues.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	hues.colors = PackedColorArray([Color(1.0, 0.78, 0.86, 0.5), Color(1.0, 0.94, 0.72, 0.5),
			Color(0.76, 0.96, 0.86, 0.5), Color(0.74, 0.86, 1.0, 0.5), Color(0.88, 0.78, 1.0, 0.5)])
	var hue_tex := GradientTexture1D.new()
	hue_tex.gradient = hues
	pm.color_initial_ramp = hue_tex
	pm.scale_min = 6.0
	pm.scale_max = 14.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var dm := StandardMaterial3D.new()
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.vertex_color_use_as_albedo = true
	quad.material = dm
	return [pm, quad]


static func thornwater_level(x: float, z: float) -> float:
	return MacroHeight.land_height_at(x, z) - MacroHeight.RIVER_DEPTH + 1.4


func _build_landmarks(parent: Node3D) -> void:
	var T := BorderWoodsTerrain
	var oak := Vector2(T.GREAT_OAK.x, T.GREAT_OAK.y)
	var great := place_landmark(parent, "GreatOak", FloraLibrary.mesh(&"ancient_oak"), oak, 0.7, 3.2, 1.5)
	# The weenie of the wall-crossing reveal: the brightest thing in frame,
	# its crown rim-lit gold, glinting and unfogged where the others are plain.
	var lit := FloraLibrary.material(&"tree").duplicate() as ShaderMaterial
	lit.shader = HERO_FOLIAGE
	lit.set_shader_parameter(&"rim_strength", 1.6)
	lit.set_shader_parameter(&"rim_color", Color(1.0, 0.86, 0.6))
	lit.set_shader_parameter(&"translucency", 0.8)
	lit.set_shader_parameter(&"sparkle", 0.6)
	(great.find_children("*", "MeshInstance3D", false, false)[0] as MeshInstance3D).material_override = lit
	var oak_light := make_light_shaft(20.0, 90.0, 0.32)
	oak_light.name = "GreatOakLight"
	oak_light.position += Vector3(oak.x, WorldHeight.height_at(oak.x, oak.y), oak.y)
	parent.add_child(oak_light)
	defer(_build_wall_frame.bind(parent))
	# Each group is its own frame-budget job (see WoodsRegion.defer).
	defer(_build_moonstone_ring.bind(parent))
	defer(_build_crocus_knoll.bind(parent))
	# The willow glen (ch. 23 flavour; the glamour-lift scene itself is
	# anchored in blossom_vale by the story lane).
	place_landmark(parent, "GreatWillow", FloraLibrary.mesh(&"willow"), T.WILLOW_GLEN, 0.4, 2.4, 1.0)
	defer(_build_ford.bind(parent))
	# A waystone where the ride north comes through the Wall.
	place_landmark(parent, "WallGapWaystone", FloraLibrary.mesh(&"standing_stone"), T.WALL_GAP + Vector2(14.0, -40.0), 0.3, 1.6, 0.5)
	defer(_build_hollow_roots.bind(parent))
	var hunt := place_anchor(parent, "bogge_hunt_path", T.BOGGE_HUNT, 12.0,
			"ch. 9-10: hunting with Lucien. 'Don't move, look straight ahead.' The Bogge passes behind them (bogge_survived).")
	hunt.look_at(Vector3(T.BOGGE_HUNT_LOOK.x, hunt.position.y, T.BOGGE_HUNT_LOOK.y), Vector3.UP)
	place_anchor(parent, "WallCrossingArrival", T.WALL_GAP + Vector2(0.0, -30.0), 30.0,
			"Where the ride north comes out of the Wall into the Spring Court (wall_crossed).")


## Blossom boughs framing the first view past the Wall: crab apples either
## side of the frame, just ahead, leaving the cone to the Great Oak open.
func _build_wall_frame(parent: Node3D) -> void:
	var T := BorderWoodsTerrain
	var dir := (Vector2(T.GREAT_OAK.x, T.GREAT_OAK.y) - T.WALL_FRAME).normalized()
	var side := Vector2(-dir.y, dir.x)
	var frame := Node3D.new()
	frame.name = "WallCrossingBoughs"
	parent.add_child(frame)
	for k in [-1.0, 1.0]:
		for i in 2:
			var at: Vector2 = T.WALL_FRAME + dir * (5.0 + i * 6.0) + side * k * (8.0 + i * 3.0)
			place_prop(frame, "Bough%d_%d" % [int(k), i], FloraLibrary.mesh(&"crab_apple"), at,
					k * 0.8 + i, 1.25 - i * 0.15, 0.3)


## The moonstone ring: nine standing stones on a low rise.
func _build_moonstone_ring(parent: Node3D) -> void:
	var T := BorderWoodsTerrain
	var ring_center := Vector2(T.MOONSTONE_RING.x, T.MOONSTONE_RING.y)
	var ring := Node3D.new()
	ring.name = "MoonstoneRing"
	ring.add_to_group(&"landmark")
	parent.add_child(ring)
	landmark_count += 1
	for i in 9:
		var a := TAU * i / 9.0
		place_prop(ring, "Stone%d" % i, FloraLibrary.mesh(&"standing_stone"), ring_center + Vector2(cos(a), sin(a)) * 14.0,
				a + PI * 0.5, 1.3 + 0.25 * sin(i * 2.1), 0.5)


## The crocus knoll: a sunny rise ringed by oaks "as tall as castle spires".
func _build_crocus_knoll(parent: Node3D) -> void:
	var T := BorderWoodsTerrain
	var knoll := Vector2(T.CROCUS_KNOLL.x, T.CROCUS_KNOLL.y)
	var oaks := Node3D.new()
	oaks.name = "CrocusKnollOaks"
	oaks.add_to_group(&"landmark")
	parent.add_child(oaks)
	landmark_count += 1
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		place_prop(oaks, "Oak%d" % i, FloraLibrary.mesh(&"oak"), knoll + Vector2(cos(a), sin(a)) * 48.0, a, 2.0, 1.0)


## The ford: stepping stones where the woods road crosses the Thornwater.
func _build_ford(parent: Node3D) -> void:
	var ford := _ford
	var stones := Node3D.new()
	stones.name = "ThornwaterFord"
	stones.add_to_group(&"landmark")
	parent.add_child(stones)
	landmark_count += 1
	for i in 7:
		var p := ford + Vector2(-12.0 + i * 4.0, (i % 2) * 1.2 - 0.6)
		place_prop(stones, "Step%d" % i, FloraLibrary.mesh(&"boulder"), p, i * 0.9, 0.9, 0.0)


## Faelight hollow: a ring of old roots around the pool.
func _build_hollow_roots(parent: Node3D) -> void:
	var T := BorderWoodsTerrain
	var hollow := Vector2(T.FAELIGHT_HOLLOW.x, T.FAELIGHT_HOLLOW.y)
	var roots := Node3D.new()
	roots.name = "FaelightHollowRoots"
	roots.add_to_group(&"landmark")
	parent.add_child(roots)
	landmark_count += 1
	for i in 6:
		var a := TAU * i / 6.0
		place_prop(roots, "Root%d" % i, FloraLibrary.mesh(&"root_arch"), hollow + Vector2(cos(a), sin(a)) * 22.0, a, 1.4)


func _ford_point() -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	for seg in BorderWoodsTerrain.features().segments(&"road"):
		for t in 5:
			var p: Vector2 = seg[0].lerp(seg[1], t / 4.0)
			var d := MacroHeight.distance_to_river(p.x, p.y)
			if d < best_d:
				best_d = d
				best = p
	return best
