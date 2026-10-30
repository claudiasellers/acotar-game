## Ground of the Manor Estate as a pure height function plus a fallback mesh.
##
## height_at() takes WORLD coordinates and is registered as the "manor_estate"
## HeightProvider in world/shared/terrain/height_providers.tres (world contract §2).
## Placement samples WorldHeight.height_at (the blended map height), never this
## directly. build_fallback() makes chunk meshes and one HeightMapShape3D under
## TerrainFallback, which the World scene disables when Terrain3D is active.
class_name ManorTerrain
extends RefCounted

const CHUNK := 100.0
const MESH_STEP := 2.0
const COLLISION_STEP := 2.0


## Ground height in metres at a world x/z position.
static func height_at(x: float, z: float) -> float:
	var h := natural_height(x, z)
	for pad in ManorSitePlan.pads():
		var area: Rect2 = pad[0]
		var w := _pad_weight(area, float(pad[2]), x, z)
		if w > 0.0:
			h = lerpf(h, ManorSitePlan.base_y() + float(pad[1]), w)
	h -= _pond_carve(x, z)
	return h


## Rolling estate ground before pads: lawns falling gently south toward the
## Border Woods, rising to wooded hills and the Rosewild in the north.
static func natural_height(x: float, z: float) -> float:
	var b := ManorSitePlan.BOUNDS
	var north := clampf((-z - 240.0) / 260.0, 0.0, 1.0)
	var h := ManorSitePlan.base_y()
	h += 0.012 * -z * 0.35                           # gentle fall to the south
	h += 14.0 * north * north                        # wooded hills toward the Rosewild
	h += 3.2 * sin(x * 0.0091 + 0.7) * cos(z * 0.0077 - 0.4)
	h += 1.3 * sin(x * 0.027 + z * 0.019) + 0.55 * sin(x * 0.071 - z * 0.053)
	var belvedere := ManorSitePlan.BELVEDERE_HILL
	h += 16.0 * exp(-(pow(x - belvedere.x, 2) + pow(z - belvedere.y, 2)) / (2.0 * 60.0 * 60.0))
	# Ease toward the shared macro height over the outer 160 m, so the
	# provider's own 64 m fade only has a small step left to blend.
	var edge := minf(minf(x - b.position.x, b.end.x - x), minf(z - b.position.y, b.end.y - z))
	var t := 1.0 - smoothstep(64.0, 224.0, edge)
	return lerpf(h, MacroHeight.land_height_at(x, z), t)


## Terrain3D texture slots (WorldHeight.Tex): spring grass, gravel paths,
## forest floor at the wooded edges, riverbed in the pond.
static func texture_at(x: float, z: float) -> Vector3i:
	if ManorSitePlan.in_pond(x, z, 1.1):
		return Vector3i(WorldHeight.Tex.RIVERBED, WorldHeight.Tex.MOSS, 60)
	if ManorSitePlan.is_on_path(x, z):
		return Vector3i(WorldHeight.Tex.PATH, WorldHeight.Tex.SPRING_GRASS, 30)
	var b := ManorSitePlan.BOUNDS
	var edge := minf(minf(x - b.position.x, b.end.x - x), minf(z - b.position.y, b.end.y - z))
	var woods := int(clampf(1.0 - (edge - 40.0) / 80.0, 0.0, 1.0) * 255.0)
	return Vector3i(WorldHeight.Tex.SPRING_GRASS, WorldHeight.Tex.FOREST_FLOOR, woods)


static func _pad_weight(area: Rect2, blend: float, x: float, z: float) -> float:
	var dx := maxf(maxf(area.position.x - x, x - area.end.x), 0.0)
	var dz := maxf(maxf(area.position.y - z, z - area.end.y), 0.0)
	var d := sqrt(dx * dx + dz * dz)
	if d >= blend:
		return 0.0
	return 1.0 - smoothstep(0.0, blend, d)


static func _pond_carve(x: float, z: float) -> float:
	var d := (Vector2(x, z) - ManorSitePlan.POND_CENTER) / (ManorSitePlan.POND_RADII * 1.25)
	var r2 := d.length_squared()
	if r2 >= 1.0:
		return 0.0
	return ManorSitePlan.POND_DEPTH * 1.25 * pow(1.0 - r2, 1.5)


## Water surface height of the pond.
static func pond_level() -> float:
	return ManorSitePlan.base_y() + ManorSitePlan.POND_PAD - 0.35


## Builds TerrainFallback: visual chunks plus a single heightmap collider.
static func build_fallback(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "TerrainFallback"
	parent.add_child(root)
	var b := ManorSitePlan.BOUNDS
	var material := ground_material()
	var cx := int(ceil(b.size.x / CHUNK))
	var cz := int(ceil(b.size.y / CHUNK))
	for iz in cz:
		for ix in cx:
			var origin := Vector2(b.position.x + ix * CHUNK, b.position.y + iz * CHUNK)
			var chunk := MeshInstance3D.new()
			chunk.name = "Chunk_%d_%d" % [ix, iz]
			chunk.mesh = _chunk_mesh(origin, material)
			root.add_child(chunk)
	root.add_child(_collider())
	return root


static func _chunk_mesh(origin: Vector2, material: Material) -> ArrayMesh:
	var n := int(CHUNK / MESH_STEP) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in n:
		for xi in n:
			var x := origin.x + xi * MESH_STEP
			var z := origin.y + zi * MESH_STEP
			var h := WorldHeight.height_at(x, z)
			st.set_color(ground_color(x, z, h))
			st.set_uv(Vector2(x, z) / 6.0)
			st.add_vertex(Vector3(x, h, z))
	for zi in n - 1:
		for xi in n - 1:
			var i := zi * n + xi
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + n)
			st.add_index(i + 1)
			st.add_index(i + n + 1)
			st.add_index(i + n)
	st.generate_normals()
	st.set_material(material)
	return st.commit()


static func _collider() -> StaticBody3D:
	var b := ManorSitePlan.BOUNDS
	var w := int(b.size.x / COLLISION_STEP) + 1
	var d := int(b.size.y / COLLISION_STEP) + 1
	var heights := PackedFloat32Array()
	heights.resize(w * d)
	for zi in d:
		for xi in w:
			heights[zi * w + xi] = WorldHeight.height_at(b.position.x + xi * COLLISION_STEP, b.position.y + zi * COLLISION_STEP)
	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = d
	shape.map_data = heights
	var body := StaticBody3D.new()
	body.name = "Collider"
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = shape
	# HeightMapShape3D is centred on its node and spaced one unit per sample.
	cs.scale = Vector3(COLLISION_STEP, 1.0, COLLISION_STEP)
	body.position = Vector3(b.get_center().x, 0.0, b.get_center().y)
	body.add_child(cs)
	return body


## Base ground colour: spring lawn, wildflower meadow tints, woodland floor.
static func ground_color(x: float, z: float, h: float) -> Color:
	var lawn := Color(0.40, 0.58, 0.26)
	var meadow := Color(0.52, 0.62, 0.30)
	var wood := Color(0.27, 0.36, 0.18)
	var t := 0.5 + 0.5 * sin(x * 0.013 + 1.3) * cos(z * 0.011 - 0.2)
	var c := lawn.lerp(meadow, t * 0.6)
	var b := ManorSitePlan.BOUNDS
	var edge := minf(minf(x - b.position.x, b.end.x - x), minf(z - b.position.y, b.end.y - z))
	c = c.lerp(wood, clampf(1.0 - (edge - 40.0) / 90.0, 0.0, 1.0))
	if ManorSitePlan.in_pond(x, z, 1.15):
		c = c.lerp(Color(0.33, 0.30, 0.22), 0.7)
	var jitter := 0.035 * sin(x * 1.37 + z * 2.11)
	return c.lightened(jitter) if jitter > 0.0 else c.darkened(-jitter)


static func ground_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	tex.color_ramp = Gradient.new()
	tex.color_ramp.set_color(0, Color(0.82, 0.86, 0.80))
	tex.color_ramp.set_color(1, Color(1.0, 1.0, 1.0))
	m.albedo_texture = tex
	return m
