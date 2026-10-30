## Root of a woods region scene (docs/contracts/world.md §3): positioned at
## world coordinates, content only (no sky, sun or environment).
##
## Everything is generated from the region's WoodsRegionDef and height
## provider with fixed seeds (R15): the heavy point placement runs on a
## worker thread, then the node tree is built on the main thread:
##   TerrainFallback   stand-in chunk meshes + collision until Terrain3D lands
##   Trees/Shrubs/Forage   ScatterFields (chunked MultiMeshes; forage chunks
##                     carry the contract's forage_field metas)
##   TrunkColliders    one static body per chunk, shapes added on the server
##   Water             river/stream ribbons and pond surfaces
##   GroundCover       DetailScatter: dense flowers and grass near Feyre
##   AmbientLife       particles and small creatures driven by the biome
##   Landmarks         named places, built by the subclass
class_name WoodsRegion
extends Node3D

signal built

const CHUNK_TREE := WoodsScatter.CHUNK_TREE
const CHUNK_SHRUB := WoodsScatter.CHUNK_SHRUB
const CHUNK_FORAGE := WoodsScatter.CHUNK_FORAGE
## Draw calls outside the scatter layers: ground cover (25 cells x ~6
## species), particles, water, landmarks, terrain stand-in.
const EXTRA_DRAW_CALLS := 260
const TERRAIN_STEP := 2.0
const TERRAIN_CHUNK := 64.0
const WATER_SHADER := preload("res://world/spring_court/shared/woods_water.gdshader")

@export var def: WoodsRegionDef
## Build the stand-in terrain (off once the World scene's Terrain3D is live).
@export var build_terrain_fallback := true
@export var build_ground_cover := true
@export var build_ambient_life := true

var bounds: Rect2
var layers: Array[ScatterLayer] = []
var landmark_count := 0
var is_built := false

var _task_id := -1
var _placements: Dictionary = {}
var _heights := PackedFloat32Array()
var _colors := PackedColorArray()
var _grid := Vector2i.ZERO


func _ready() -> void:
	if def == null:
		push_error("WoodsRegion '%s' has no def" % name)
		return
	bounds = def.provider.BOUNDS
	# Warm the static noise/feature caches on this thread before the worker
	# reads them.
	WorldHeight.height_at(bounds.get_center().x, bounds.get_center().y)
	def.provider.biome_at(bounds.get_center().x, bounds.get_center().y)
	_task_id = WorkerThreadPool.add_task(_generate, false, "woods:%s" % def.region_id)
	set_process(true)


func _process(_delta: float) -> void:
	if _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_build()


func _exit_tree() -> void:
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1


## The coverage report for tools/world_smoke.gd (contract §5). Needs build.
func coverage_report() -> Dictionary:
	return ScatterReport.compute(layers, bounds, landmark_count,
			WoodsScatter.estimate_draw_calls(layers, bounds, EXTRA_DRAW_CALLS))


## Builds synchronously (tests and tools).
func build_now() -> void:
	if is_built:
		return
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
	elif _placements.is_empty():
		_generate()
	_build()


func _generate() -> void:
	for kind in ["tree", "shrub", "forage"]:
		_placements[kind] = WoodsScatter.place(def, bounds, kind)
	if build_terrain_fallback:
		_sample_terrain()


func _build() -> void:
	if is_built:
		return
	set_process(false)
	layers.clear()
	var fields := {"tree": [], "shrub": [], "forage": []}
	for kind in ["tree", "shrub", "forage"]:
		var points: Dictionary = _placements[kind]
		var ids := points.keys()
		ids.sort()
		for id: StringName in ids:
			var layer := WoodsScatter._make_layer(def, kind, id, points[id])
			layers.append(layer)
			fields[kind].append(layer)
	if build_terrain_fallback:
		_build_terrain()
	_add_field("Trees", fields["tree"], CHUNK_TREE)
	_add_field("Shrubs", fields["shrub"], CHUNK_SHRUB)
	_add_field("Forage", fields["forage"], CHUNK_FORAGE)
	_build_trunk_colliders(fields["tree"] + fields["shrub"])
	var water := Node3D.new()
	water.name = "Water"
	add_child(water)
	_build_water(water)
	var landmarks := Node3D.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	_build_landmarks(landmarks)
	if build_ground_cover:
		var cover := DetailScatter.new()
		cover.name = "GroundCover"
		cover.def = def
		cover.bounds = bounds
		add_child(cover)
	if build_ambient_life:
		var life := AmbientLife.new()
		life.name = "AmbientLife"
		life.def = def
		life.bounds = bounds
		add_child(life)
	_placements.clear()
	_heights = PackedFloat32Array()
	_colors = PackedColorArray()
	is_built = true
	built.emit()


## Subclasses add their named places here (and bump landmark_count).
func _build_landmarks(_parent: Node3D) -> void:
	pass


## Subclasses add rivers, streams and ponds here.
func _build_water(_parent: Node3D) -> void:
	pass


func _add_field(field_name: String, field_layers: Array, chunk: float) -> void:
	var field := ScatterField.new()
	field.name = field_name
	field.region_id = def.region_id
	field.chunk_size = chunk
	var typed: Array[ScatterLayer] = []
	for l in field_layers:
		typed.append(l)
	field.layers = typed
	add_child(field)


# ---------------------------------------------------------------- terrain --

func _sample_terrain() -> void:
	_grid = Vector2i(int(bounds.size.x / TERRAIN_STEP) + 1, int(bounds.size.y / TERRAIN_STEP) + 1)
	_heights.resize(_grid.x * _grid.y)
	_colors.resize(_grid.x * _grid.y)
	var biomes := def.biome_map()
	var provider: Variant = def.provider
	for iz in _grid.y:
		for ix in _grid.x:
			var x := bounds.position.x + ix * TERRAIN_STEP
			var z := bounds.position.y + iz * TERRAIN_STEP
			var i := iz * _grid.x + ix
			_heights[i] = WorldHeight.height_at(x, z)
			var b: WoodsBiome = biomes.get(provider.biome_at(x, z))
			var col := Color(0.45, 0.66, 0.36) if b == null else b.ground_color.lerp(b.ground_color_alt, 0.5 + 0.5 * sin(x * 0.05) * cos(z * 0.043))
			if provider.clearance(x, z) < 0.2:
				col = col.lerp(Color(0.72, 0.62, 0.50), 0.55)
			if provider.is_water(x, z):
				col = Color(0.42, 0.40, 0.34)
			_colors[i] = col.darkened(0.22)


func _build_terrain() -> void:
	var root := Node3D.new()
	root.name = "TerrainFallback"
	add_child(root)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	var per := int(TERRAIN_CHUNK / TERRAIN_STEP)
	for cz in range(0, _grid.y - 1, per):
		for cx in range(0, _grid.x - 1, per):
			var mesh := _chunk_mesh(cx, cz, mini(per, _grid.x - 1 - cx), mini(per, _grid.y - 1 - cz))
			mesh.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.name = "Chunk_%d_%d" % [cx / per, cz / per]
			root.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	var shape := HeightMapShape3D.new()
	shape.map_width = _grid.x
	shape.map_depth = _grid.y
	shape.map_data = _heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(TERRAIN_STEP, 1.0, TERRAIN_STEP)
	cs.position = Vector3(bounds.position.x + bounds.size.x * 0.5, 0.0, bounds.position.y + bounds.size.y * 0.5)
	body.add_child(cs)
	root.add_child(body)


func _chunk_mesh(x0: int, z0: int, w: int, d: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for iz in d + 1:
		for ix in w + 1:
			var gx := x0 + ix
			var gz := z0 + iz
			var h := _h(gx, gz)
			verts.append(Vector3(bounds.position.x + gx * TERRAIN_STEP, h, bounds.position.y + gz * TERRAIN_STEP))
			var nx := _h(gx - 1, gz) - _h(gx + 1, gz)
			var nz := _h(gx, gz - 1) - _h(gx, gz + 1)
			normals.append(Vector3(nx, 2.0 * TERRAIN_STEP, nz).normalized())
			colors.append(_colors[gz * _grid.x + gx])
	for iz in d:
		for ix in w:
			var i := iz * (w + 1) + ix
			indices.append_array(PackedInt32Array([i, i + 1, i + w + 1, i + 1, i + w + 2, i + w + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _h(gx: int, gz: int) -> float:
	return _heights[clampi(gz, 0, _grid.y - 1) * _grid.x + clampi(gx, 0, _grid.x - 1)]


# -------------------------------------------------------------- colliders --

## Trunks and big rocks block Feyre. One static body per chunk; shapes go
## straight to the physics server (no per-instance nodes, R16).
func _build_trunk_colliders(solid_layers: Array) -> void:
	var root := Node3D.new()
	root.name = "TrunkColliders"
	add_child(root)
	var bodies := {}
	var shapes := {}
	for layer: ScatterLayer in solid_layers:
		var species := StringName(String(layer.id).split("_", true, 1)[1])
		var radius: float = FloraLibrary.info(species).get("radius", 0.0)
		if radius <= 0.0:
			continue
		for i in layer.count():
			var o := i * ScatterLayer.STRIDE
			var p := Vector3(layer.instances[o], layer.instances[o + 1], layer.instances[o + 2])
			var s := layer.instances[o + 4]
			var r := snappedf(radius * s, 0.1)
			if not shapes.has(r):
				var cyl := CylinderShape3D.new()
				cyl.radius = r
				cyl.height = 5.0
				shapes[r] = cyl
			var key := Vector2i(floori(p.x / CHUNK_SHRUB), floori(p.z / CHUNK_SHRUB))
			if not bodies.has(key):
				var body := StaticBody3D.new()
				body.name = "Trunks_%d_%d" % [key.x, key.y]
				body.collision_layer = 1
				body.collision_mask = 0
				root.add_child(body)
				bodies[key] = body
			var b: StaticBody3D = bodies[key]
			PhysicsServer3D.body_add_shape(b.get_rid(), shapes[r].get_rid(), Transform3D(Basis(), p + Vector3.UP * 2.3))
	# Keep the shape resources alive as long as the region.
	root.set_meta(&"shapes", shapes.values())


# ------------------------------------------------------------------ water --

## A ribbon of water following a polyline; `level` gives the surface height
## at a point.
func make_water_ribbon(points: PackedVector2Array, half_width: float, level: Callable, dread := false) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var along := 0.0
	for i in points.size():
		var p := points[i]
		var dir := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-dir.y, dir.x) * half_width
		var y: float = level.call(p.x, p.y)
		if i > 0:
			along += p.distance_to(points[i - 1])
		verts.append(Vector3(p.x - side.x, y, p.y - side.y))
		verts.append(Vector3(p.x + side.x, y, p.y + side.y))
		uvs.append(Vector2(0.0, along))
		uvs.append(Vector2(1.0, along))
		if i > 0:
			var a := (i - 1) * 2
			indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, water_material(dread))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func make_pond(center: Vector3, radius: float, dread := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 32
	mesh.material = water_material(dread)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func water_material(dread: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	if dread:
		m.set_shader_parameter(&"shallow_color", Color(0.10, 0.12, 0.10))
		m.set_shader_parameter(&"deep_color", Color(0.02, 0.03, 0.03))
		m.set_shader_parameter(&"sparkle", 0.0)
	return m


## Clips a world polyline to this region's bounds (plus a margin).
func clip_to_bounds(points: PackedVector2Array, margin: float = 0.0) -> PackedVector2Array:
	var rect := bounds.grow(margin)
	var out := PackedVector2Array()
	for p in points:
		if rect.has_point(p):
			out.append(p)
	return out


## Resamples a polyline every `step` metres.
static func resample(points: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for s in n:
			out.append(a.lerp(b, float(s) / n))
	if not points.is_empty():
		out.append(points[points.size() - 1])
	return out


# -------------------------------------------------------------- landmarks --

## A single hand-placed mesh (with optional collision) at ground height.
func place_prop(parent: Node3D, prop_name: String, mesh: Mesh, at: Vector2, yaw: float = 0.0,
		scale_by: float = 1.0, collider_radius: float = 0.0) -> Node3D:
	var y := WorldHeight.height_at(at.x, at.y)
	var node: Node3D
	if collider_radius > 0.0:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = collider_radius
		cyl.height = 4.0 * scale_by
		cs.shape = cyl
		cs.position = Vector3.UP * cyl.height * 0.5 / scale_by
		body.add_child(cs)
		node = body
	else:
		node = Node3D.new()
	node.name = prop_name
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	node.add_child(mi)
	node.position = Vector3(at.x, y, at.y)
	node.rotation.y = yaw
	node.scale = Vector3.ONE * scale_by
	parent.add_child(node)
	return node


## A named landmark (counted for the coverage report).
func place_landmark(parent: Node3D, landmark_name: String, mesh: Mesh, at: Vector2, yaw: float = 0.0,
		scale_by: float = 1.0, collider_radius: float = 0.0) -> Node3D:
	var node := place_prop(parent, landmark_name, mesh, at, yaw, scale_by, collider_radius)
	node.add_to_group(&"landmark")
	landmark_count += 1
	return node


## A story anchor other lanes find by group/name (snare site, Bogge path...).
func place_anchor(parent: Node3D, anchor_name: String, at: Vector2, radius: float, notes: String) -> Marker3D:
	var m := Marker3D.new()
	m.name = anchor_name
	m.position = Vector3(at.x, WorldHeight.height_at(at.x, at.y), at.y)
	m.add_to_group(&"story_anchor")
	m.set_meta(&"radius", radius)
	m.set_meta(&"notes", notes)
	parent.add_child(m)
	return m


## A fog volume for local mood (contract: local mood goes in FogVolumes).
func place_fog(parent: Node3D, fog_name: String, center: Vector3, size: Vector3, density: float, albedo: Color) -> FogVolume:
	var fog := FogVolume.new()
	fog.name = fog_name
	fog.size = size
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	var mat := FogMaterial.new()
	mat.density = density
	mat.albedo = albedo
	mat.edge_fade = 0.6
	fog.material = mat
	fog.position = center
	parent.add_child(fog)
	return fog
