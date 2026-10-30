## Root of a woods region scene (docs/contracts/world.md §3): positioned at
## world coordinates, content only (no sky, sun or environment).
##
## Streaming cost (no hitches): everything heavy happens on a worker thread:
## loading the baked cache from `make update` (WoodsScatterCache) or, if it is
## missing or stale, generating placements with fixed seeds (R15); building
## mesh arrays, MultiMesh buffers, terrain chunk arrays and collider lists.
## The main thread then only turns prepared data into nodes, one small job at
## a time under FrameBudget (4 ms per frame, shared by all builders):
##   TerrainFallback   stand-in chunk meshes + collision until Terrain3D lands
##   Trees/Shrubs/Forage   SlicedScatterFields (forage chunks carry the
##                     contract's forage_field metas)
##   TrunkColliders    one static body per chunk, shapes added on the server
##   Water, Landmarks  rivers, ponds, falls; named places and story anchors
##   GroundCover       DetailScatter: dense flowers and grass near Feyre
##   AmbientLife       particles and small creatures driven by the biome
class_name WoodsRegion
extends Node3D

signal built

const CHUNK_TREE := WoodsScatter.CHUNK_TREE
const CHUNK_SHRUB := WoodsScatter.CHUNK_SHRUB
const CHUNK_FORAGE := WoodsScatter.CHUNK_FORAGE
## Draw calls outside the scatter layers: ground cover (25 cells x ~6
## species), particles, water, landmarks, terrain stand-in.
const EXTRA_DRAW_CALLS := 260
## Clearing heroes and their shafts draw out to here (past the sightline
## checker's 150 m magnet range), fading over the last stretch.
const CLEARING_DRAW_DISTANCE := 240.0
const TERRAIN_STEP := 2.0
const TERRAIN_CHUNK := 64.0
const KINDS := ["tree", "shrub", "forage"]
const COLLIDER_BATCH := 16
## Meshes landmarks and props use; warmed on the worker with the scatter's.
const PROP_SPECIES: Array[StringName] = [&"ancient_oak", &"oak", &"beech", &"willow", &"silver_birch", &"standing_stone",
		&"crab_apple", &"lilac_tree", &"hawthorn", &"fallen_log",
		&"standing_stone", &"boulder", &"root_arch", &"twisted_dead", &"pale_fungus", &"bone_charm", &"thornbriar"]
const SHAFT_SHADER := preload("res://world/spring_court/shared/woods_light_shaft.gdshader")
## Clearing heroes: [scale, trunk collider radius] (collider 0 = none).
const HERO_STYLE := {&"ancient_oak": [0.75, 1.2], &"crab_apple": [1.35, 0.3], &"lilac_tree": [1.35, 0.2],
		&"hawthorn": [1.4, 0.25], &"standing_stone": [1.5, 0.6], &"fallen_log": [1.0, 0.0],
		&"twisted_dead": [1.3, 0.4]}
const WATER_SHADER := preload("res://world/spring_court/shared/woods_water.gdshader")

@export var def: WoodsRegionDef
## Build the stand-in terrain (off once the World scene's Terrain3D is live).
@export var build_terrain_fallback := true
@export var build_ground_cover := true
@export var build_ambient_life := true
## Use the baked cache from `make update` when it matches.
@export var use_cache := true

var bounds: Rect2
var layers: Array[ScatterLayer] = []
var landmark_count := 0
var is_built := false
## True when this load came from the baked cache.
var used_cache := false

## Shared shaft-mote kit [process material, draw mesh] (a new process
## material compiles its shader, ~4 ms; reusing one costs nothing).
static var _mote_kit: Array = []
var _task_id := -1
var _fingerprint := ""
var _prepared: Dictionary = {}
var _jobs: Array[Callable] = []
var _fields: Dictionary = {}
var _terrain_mat: StandardMaterial3D
var _grid := Vector2i.ZERO


func _ready() -> void:
	if def == null:
		push_error("WoodsRegion '%s' has no def" % name)
		return
	bounds = def.provider.BOUNDS
	# Warm the static noise/feature caches here before the worker reads them,
	# and fingerprint the inputs so a stale cache is never trusted.
	_fingerprint = WoodsScatterCache.fingerprint_for(def)
	_start()


func _start() -> void:
	BuildCancel.clear(def.region_id)
	_task_id = WorkerThreadPool.add_task(_prepare, false, "woods:%s" % def.region_id)


## Back in the tree after leaving mid-build (the cancelled worker's partial
## result was dropped): start the build again.
func _enter_tree() -> void:
	if is_node_ready() and def != null and not is_built and _task_id < 0 and _jobs.is_empty() and _prepared.is_empty():
		_start()


func _process(_delta: float) -> void:
	if _task_id >= 0:
		if not WorkerThreadPool.is_task_completed(_task_id):
			return
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_queue_jobs()
	if not _jobs.is_empty() and FrameBudget.run(_jobs) == 0:
		_finish()


func _exit_tree() -> void:
	if _task_id >= 0:
		# Leaving mid-build (quit, teleport): stop the worker early, then join.
		BuildCancel.request(def.region_id)
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_prepared.clear()


## The coverage report for tools/world_smoke.gd (contract §5). Needs build.
func coverage_report() -> Dictionary:
	# Clearing heroes: a glade's casts a shadow (2 calls) plus its shaft and
	# motes, a beacon's is shadowless plus a thin shaft.
	var props := PackedVector3Array()
	for c: Dictionary in WoodsComposition.clearings(def):
		var center: Vector2 = c["center"]
		props.append(Vector3(center.x, center.y, 4.0 if not c["beacon"] else (1.0 if c["dread"] else 2.0)))
	return ScatterReport.compute(layers, bounds, landmark_count,
			WoodsScatter.estimate_draw_calls(layers, bounds, EXTRA_DRAW_CALLS, props, CLEARING_DRAW_DISTANCE))


## Walkable lines for tools/sightline_check.gd: every road and path.
func sightline_paths() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var f: WoodsFeatures = def.provider.features()
	for kind in WoodsComposition.PATH_KINDS:
		var line := PackedVector2Array()
		for seg: Array in f.segments(kind):
			if not line.is_empty() and line[line.size() - 1] != seg[0]:
				out.append(line)
				line = PackedVector2Array()
			if line.is_empty():
				line.append(seg[0])
			line.append(seg[1])
		if line.size() > 1:
			out.append(line)
	return out


## Horror biomes withdraw on purpose: the sightline check leaves them out.
func sightline_skip(x: float, z: float) -> bool:
	return WoodsComposition.of(def)["horror"].has(def.provider.biome_at(x, z))


## Builds synchronously, ignoring the frame budget (tests and tools).
func build_now() -> void:
	if is_built:
		return
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
	elif _prepared.is_empty():
		if _fingerprint.is_empty():
			_fingerprint = WoodsScatterCache.fingerprint_for(def)
		BuildCancel.clear(def.region_id)
		_prepare()
	if _jobs.is_empty():
		_queue_jobs()
	while not _jobs.is_empty():
		_jobs.pop_front().call()
	_finish()


## Generates everything the generator bakes (pure data; any thread).
static func generate_cache(region_def: WoodsRegionDef, fingerprint: String, with_terrain: bool = true) -> WoodsScatterCache:
	var cache := WoodsScatterCache.new()
	cache.fingerprint = fingerprint
	var rect: Rect2 = region_def.provider.BOUNDS
	for kind in KINDS:
		if BuildCancel.requested(region_def.region_id):
			return cache
		cache.placements[kind] = WoodsScatter.place(region_def, rect, kind)
	if with_terrain:
		_sample_terrain(region_def, rect, cache)
	return cache


# ------------------------------------------------------------ worker side --

func _prepare() -> void:
	var cache: WoodsScatterCache = null
	var path := WoodsScatterCache.path_for(def.region_id)
	if use_cache and ResourceLoader.exists(path):
		cache = ResourceLoader.load(path) as WoodsScatterCache
		if cache != null and (cache.fingerprint != _fingerprint or (build_terrain_fallback and cache.heights.is_empty())):
			cache = null
	used_cache = cache != null
	if cache == null:
		cache = generate_cache(def, _fingerprint, build_terrain_fallback)
	if BuildCancel.requested(def.region_id):
		return
	var out := {"layers": [], "chunks": [], "terrain": [], "colliders": {}}
	var species := {}
	for kind in KINDS:
		var points: Dictionary = cache.placements[kind]
		var ids := points.keys()
		ids.sort()
		for id: StringName in ids:
			if BuildCancel.requested(def.region_id):
				return
			var layer := WoodsScatter.layer_without_mesh(def, kind, id, points[id])
			var visual := WoodsScatter.visual_of(def, kind, id)
			species[visual] = kind
			out["layers"].append([kind, layer, visual])
			var size: float = {"tree": CHUNK_TREE, "shrub": CHUNK_SHRUB, "forage": CHUNK_FORAGE}[kind]
			for chunk in SlicedScatterField.prepare(layer, size):
				out["chunks"].append([kind, layer, chunk])
			if kind != "forage":
				_collect_colliders(layer, visual, out["colliders"])
	# Mesh arrays now, so mesh() on the main thread is only an upload.
	for visual in PROP_SPECIES:
		if FloraLibrary.has(visual) and not species.has(visual):
			species[visual] = FloraLibrary.info(visual).get("layer", "")
	for visual: StringName in species:
		if BuildCancel.requested(def.region_id):
			return
		FloraLibrary.arrays_for(visual, 1)
		if species[visual] == "tree":
			FloraLibrary.arrays_for(visual, 0)
	if build_terrain_fallback:
		_grid = cache.grid
		out["terrain"] = _terrain_chunks(cache)
	out["ribbons"] = _water_ribbons()
	WoodsComposition.of(def)
	_prepare_extra()
	_prepared = out


static func _sample_terrain(region_def: WoodsRegionDef, rect: Rect2, cache: WoodsScatterCache) -> void:
	var grid := Vector2i(int(rect.size.x / TERRAIN_STEP) + 1, int(rect.size.y / TERRAIN_STEP) + 1)
	cache.grid = grid
	cache.heights.resize(grid.x * grid.y)
	cache.colors.resize(grid.x * grid.y * 3)
	var biomes := region_def.biome_map()
	var provider: Variant = region_def.provider
	for iz in grid.y:
		if BuildCancel.requested(region_def.region_id):
			return
		for ix in grid.x:
			var x := rect.position.x + ix * TERRAIN_STEP
			var z := rect.position.y + iz * TERRAIN_STEP
			var i := iz * grid.x + ix
			cache.heights[i] = WorldHeight.height_at(x, z)
			var b: WoodsBiome = biomes.get(provider.biome_at(x, z))
			var col := Color(0.45, 0.66, 0.36) if b == null else b.ground_color.lerp(b.ground_color_alt, 0.5 + 0.5 * sin(x * 0.05) * cos(z * 0.043))
			if provider.clearance(x, z) < 0.2:
				col = col.lerp(Color(0.72, 0.62, 0.50), 0.55)
			if provider.is_water(x, z):
				col = Color(0.42, 0.40, 0.34)
			col = col.darkened(0.22)
			cache.colors[i * 3] = col.r8
			cache.colors[i * 3 + 1] = col.g8
			cache.colors[i * 3 + 2] = col.b8


## Terrain chunk arrays + per-chunk height maps: Array of
## [name, mesh arrays, heightmap data, width, depth, centre].
func _terrain_chunks(cache: WoodsScatterCache) -> Array:
	var out := []
	var per := int(TERRAIN_CHUNK / TERRAIN_STEP)
	for cz in range(0, _grid.y - 1, per):
		for cx in range(0, _grid.x - 1, per):
			var w := mini(per, _grid.x - 1 - cx)
			var d := mini(per, _grid.y - 1 - cz)
			var verts := PackedVector3Array()
			var normals := PackedVector3Array()
			var colors := PackedColorArray()
			var indices := PackedInt32Array()
			var hmap := PackedFloat32Array()
			for iz in d + 1:
				for ix in w + 1:
					var gx := cx + ix
					var gz := cz + iz
					var h := _h(cache.heights, gx, gz)
					hmap.append(h)
					verts.append(Vector3(bounds.position.x + gx * TERRAIN_STEP, h, bounds.position.y + gz * TERRAIN_STEP))
					var nx := _h(cache.heights, gx - 1, gz) - _h(cache.heights, gx + 1, gz)
					var nz := _h(cache.heights, gx, gz - 1) - _h(cache.heights, gx, gz + 1)
					normals.append(Vector3(nx, 2.0 * TERRAIN_STEP, nz).normalized())
					var ci := (gz * _grid.x + gx) * 3
					colors.append(Color8(cache.colors[ci], cache.colors[ci + 1], cache.colors[ci + 2]))
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
			var centre := Vector3(bounds.position.x + (cx + w * 0.5) * TERRAIN_STEP, 0.0,
					bounds.position.y + (cz + d * 0.5) * TERRAIN_STEP)
			out.append(["Chunk_%d_%d" % [cx / per, cz / per], arrays, hmap, w + 1, d + 1, centre])
	return out


func _h(heights: PackedFloat32Array, gx: int, gz: int) -> float:
	return heights[clampi(gz, 0, _grid.y - 1) * _grid.x + clampi(gx, 0, _grid.x - 1)]


## Trunk and rock colliders grouped by chunk: { key: [[radius, position], ...] }.
static func _collect_colliders(layer: ScatterLayer, visual: StringName, into: Dictionary) -> void:
	var radius: float = FloraLibrary.info(visual).get("radius", 0.0)
	if radius <= 0.0:
		return
	for i in layer.count():
		var o := i * ScatterLayer.STRIDE
		var p := Vector3(layer.instances[o], layer.instances[o + 1], layer.instances[o + 2])
		var key := Vector2i(floori(p.x / CHUNK_SHRUB), floori(p.z / CHUNK_SHRUB))
		if not into.has(key):
			into[key] = []
		into[key].append([snappedf(radius * layer.instances[o + 4], 0.1), p])


# -------------------------------------------------------------- main side --

## Turns prepared data into small jobs for FrameBudget.
func _queue_jobs() -> void:
	_jobs.clear()
	layers.clear()
	var visuals := {}
	for entry in _prepared["layers"]:
		layers.append(entry[1])
		visuals[entry[2]] = entry[0]
	for visual in PROP_SPECIES:
		if FloraLibrary.has(visual) and not visuals.has(visual):
			visuals[visual] = FloraLibrary.info(visual).get("layer", "")
	for visual: StringName in visuals:
		_jobs.append(_job_mesh.bind(visual, visuals[visual] == "tree"))
	for entry in _prepared["layers"]:
		_jobs.append(_job_assign_mesh.bind(entry[1], entry[2], entry[0] == "tree"))
	if build_terrain_fallback:
		_jobs.append(_job_terrain_root)
		for chunk in _prepared["terrain"]:
			_jobs.append(_job_terrain_chunk.bind(chunk))
	_jobs.append(_job_fields)
	for entry in _prepared["chunks"]:
		_jobs.append(_job_scatter_chunk.bind(entry[0], entry[1], entry[2]))
	_jobs.append(_job_collider_root)
	for key: Vector2i in _prepared["colliders"]:
		var entries: Array = _prepared["colliders"][key]
		# Small bodies: Jolt rebuilds a body's compound shape on every add,
		# so one big body per chunk costs tens of ms.
		for b in range(0, entries.size(), COLLIDER_BATCH):
			_jobs.append(_job_colliders.bind("Trunks_%d_%d_%d" % [key.x, key.y, b / COLLIDER_BATCH],
					entries.slice(b, b + COLLIDER_BATCH)))
	_jobs.append(_job_clearing_root)
	for glade: Dictionary in WoodsComposition.clearings(def):
		_jobs.append(_job_clearing.bind(glade))
	_jobs.append(_job_water)
	for ribbon in _prepared["ribbons"]:
		_jobs.append(_job_ribbon.bind(ribbon))
	_jobs.append(_job_landmarks)
	if build_ground_cover:
		_jobs.append(_job_ground_cover)
	if build_ambient_life:
		_jobs.append(_job_ambient)
		for id in AmbientLife.EFFECTS:
			_jobs.append(_job_ambient_effect.bind(id))


func _finish() -> void:
	if is_built:
		return
	_prepared.clear()
	is_built = true
	set_process(false)
	built.emit()


func _job_mesh(visual: StringName, tree: bool) -> void:
	FloraLibrary.mesh(visual)
	if tree:
		FloraLibrary.far_mesh(visual)


func _job_assign_mesh(layer: ScatterLayer, visual: StringName, tree: bool) -> void:
	layer.mesh = FloraLibrary.mesh(visual)
	if tree:
		layer.impostor_mesh = FloraLibrary.far_mesh(visual)


func _job_fields() -> void:
	for kind in KINDS:
		var field := SlicedScatterField.new()
		field.name = {"tree": "Trees", "shrub": "Shrubs", "forage": "Forage"}[kind]
		field.region_id = def.region_id
		field.chunk_size = {"tree": CHUNK_TREE, "shrub": CHUNK_SHRUB, "forage": CHUNK_FORAGE}[kind]
		var typed: Array[ScatterLayer] = []
		for l in layers:
			if l.id.begins_with(kind + "_"):
				typed.append(l)
		field.layers = typed
		add_child(field)
		_fields[kind] = field


func _job_scatter_chunk(kind: String, layer: ScatterLayer, chunk: Array) -> void:
	(_fields[kind] as SlicedScatterField).add_chunk(layer, chunk[0], chunk[1], chunk[2])


func _job_terrain_root() -> void:
	var root := Node3D.new()
	root.name = "TerrainFallback"
	add_child(root)
	_terrain_mat = StandardMaterial3D.new()
	_terrain_mat.vertex_color_use_as_albedo = true
	_terrain_mat.vertex_color_is_srgb = true
	_terrain_mat.roughness = 1.0
	# No specular: at the grazing angles you see ground from, Fresnel turned
	# the pale sky into a white sheen over the whole floor.
	_terrain_mat.metallic_specular = 0.0
	_terrain_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED


func _job_terrain_chunk(chunk: Array) -> void:
	var root := get_node("TerrainFallback")
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, chunk[1])
	mesh.surface_set_material(0, _terrain_mat)
	var mi := MeshInstance3D.new()
	mi.name = chunk[0]
	mi.mesh = mesh
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.name = String(chunk[0]) + "_Collision"
	body.collision_layer = 1
	var shape := HeightMapShape3D.new()
	shape.map_width = chunk[3]
	shape.map_depth = chunk[4]
	shape.map_data = chunk[2]
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(TERRAIN_STEP, 1.0, TERRAIN_STEP)
	cs.position = chunk[5]
	body.add_child(cs)
	root.add_child(body)


func _job_collider_root() -> void:
	var root := Node3D.new()
	root.name = "TrunkColliders"
	root.set_meta(&"shapes", {})
	add_child(root)


## Trunks and big rocks block Feyre. One static body per chunk; shapes go
## straight to the physics server (no per-instance nodes, R16).
func _job_colliders(body_name: String, entries: Array) -> void:
	var root := get_node("TrunkColliders")
	var shapes: Dictionary = root.get_meta(&"shapes")
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for e in entries:
		var r: float = e[0]
		if not shapes.has(r):
			var cyl := CylinderShape3D.new()
			cyl.radius = r
			cyl.height = 5.0
			shapes[r] = cyl
		PhysicsServer3D.body_add_shape(body.get_rid(), shapes[r].get_rid(), Transform3D(Basis(), e[1] + Vector3.UP * 2.3))


func _job_clearing_root() -> void:
	var root := Node3D.new()
	root.name = "Clearings"
	add_child(root)


## A clearing's stage: its hero object in a shaft of warm light. Heroes are
## in group "clearing_hero" (magnets for tools/sightline_check.gd).
func _job_clearing(glade: Dictionary) -> void:
	var root := get_node("Clearings")
	var c: Vector2 = glade["center"]
	var hero: StringName = glade["hero"]
	var style: Array = HERO_STYLE.get(hero, [1.0, 0.0])
	var node := place_prop(root, "Clearing_%d_%d" % [roundi(c.x), roundi(c.y)], FloraLibrary.mesh(hero), c,
			glade["yaw"], style[0], style[1])
	node.add_to_group(&"clearing_hero")
	var mi: MeshInstance3D = node.find_children("*", "MeshInstance3D", false, false)[0]
	_fade_out(mi)
	if glade["beacon"]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta(&"hero", hero)
	node.set_meta(&"magnet_height", 14.0 if not glade["beacon"] else 9.0)  # the shaft reads from afar
	if glade["dread"]:
		return  # no light where the Bogge is
	node.set_meta(&"radius", glade["radius"])
	# The shaft hangs off the clearing root so the hero's scale and yaw
	# don't tilt it.
	var shaft := make_light_shaft(3.0, 20.0, 0.09) if glade["beacon"] else make_light_shaft(float(glade["radius"]) * 0.45, 30.0, 0.14)
	shaft.name = node.name + "_Light"
	_fade_out(shaft)
	if not glade["beacon"]:
		# The glade's dense sparkle: gold motes drifting in the beam
		# (§2.4: concentrate particles in light shafts and glades).
		var motes := make_shaft_motes()
		motes.name = node.name + "_Motes"
		motes.position = node.position + Vector3.UP * 3.0
		motes.visibility_range_end = 120.0
		root.add_child(motes)
	shaft.position += node.position
	root.add_child(shaft)


## Soft gold motes hanging in a clearing's shaft (shared kit; the box fits
## the narrowest glade's beam, 14 m x 0.45).
static func make_shaft_motes() -> GPUParticles3D:
	if _mote_kit.is_empty():
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(6, 3, 6)
		pm.gravity = Vector3(0, 0.03, 0)
		pm.direction = Vector3(0.2, 1, 0.1)
		pm.spread = 180.0
		pm.initial_velocity_min = 0.02
		pm.initial_velocity_max = 0.12
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.15
		pm.turbulence_noise_scale = 2.0
		pm.color = Color(1.0, 0.9, 0.66, 0.85)
		pm.scale_min = 0.7
		pm.scale_max = 1.5
		var fade := Curve.new()
		fade.add_point(Vector2(0.0, 0.0))
		fade.add_point(Vector2(0.2, 1.0))
		fade.add_point(Vector2(0.8, 1.0))
		fade.add_point(Vector2(1.0, 0.0))
		var fade_tex := CurveTexture.new()
		fade_tex.curve = fade
		pm.scale_curve = fade_tex
		var quad := QuadMesh.new()
		quad.size = Vector2(0.07, 0.07)
		var draw := AmbientLife.soft_sprite_material()
		draw.emission_enabled = true
		draw.emission = Color(1.0, 0.86, 0.6)
		draw.emission_energy_multiplier = 3.0
		quad.material = draw
		_mote_kit = [pm, quad]
	var p := GPUParticles3D.new()
	p.process_material = _mote_kit[0]
	p.draw_pass_1 = _mote_kit[1]
	p.amount = 60
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 9, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## A slanted shaft of warm light standing on the node's origin.
static func make_light_shaft(radius: float, height: float, strength: float) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.7
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 16
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = SHAFT_SHADER
	mat.set_shader_parameter(&"strength", strength)
	cyl.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "LightShaft"
	mi.mesh = cyl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Lean toward the afternoon sun (south-west, high) so it reads as a beam.
	mi.rotation = Vector3(deg_to_rad(-14.0), 0.0, deg_to_rad(12.0))
	mi.position = Vector3(-height * 0.5 * sin(deg_to_rad(12.0)), height * 0.5, -height * 0.5 * sin(deg_to_rad(14.0)))
	return mi


func _job_water() -> void:
	var water := Node3D.new()
	water.name = "Water"
	add_child(water)
	_build_water(water)


func _job_ribbon(ribbon: Array) -> void:
	var mi := ribbon_instance(ribbon[1], ribbon[2])
	mi.name = ribbon[0]
	get_node("Water").add_child(mi)


func _job_landmarks() -> void:
	var landmarks := Node3D.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	_build_landmarks(landmarks)


func _job_ground_cover() -> void:
	var cover := DetailScatter.new()
	cover.name = "GroundCover"
	cover.def = def
	cover.bounds = bounds
	add_child(cover)


func _job_ambient() -> void:
	var life := AmbientLife.new()
	life.name = "AmbientLife"
	life.def = def
	life.bounds = bounds
	life.build_effects = false
	add_child(life)


func _job_ambient_effect(id: String) -> void:
	(get_node("AmbientLife") as AmbientLife).add_effect(id)


## Subclass builders hand slow parts to the frame budget with this; outside
## a build it runs the job at once.
func defer(job: Callable) -> void:
	if is_built:
		job.call()
	else:
		_jobs.append(job)


## Subclasses add their named places here (and bump landmark_count).
func _build_landmarks(_parent: Node3D) -> void:
	pass


## Subclasses add rivers, streams and ponds here.
## Worker side: subclasses precompute anything slow their builders need.
## Pure: no nodes.
func _prepare_extra() -> void:
	pass


## Worker side: polyline water as [name, surface arrays, dread], so the
## main thread only uploads it (see ribbon_arrays). Pure: no nodes.
func _water_ribbons() -> Array:
	return []


func _build_water(_parent: Node3D) -> void:
	pass


# ------------------------------------------------------------------ water --

## A ribbon of water following a polyline; `level` gives the surface height
## at a point.
func make_water_ribbon(points: PackedVector2Array, half_width: float, level: Callable, dread := false) -> MeshInstance3D:
	return ribbon_instance(ribbon_arrays(points, half_width, level), dread)


## Surface arrays for a ribbon of water following a polyline; `level` gives
## the surface height at a point. Pure, so it runs on worker threads.
static func ribbon_arrays(points: PackedVector2Array, half_width: float, level: Callable) -> Array:
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
	return arrays


static func ribbon_instance(arrays: Array, dread: bool) -> MeshInstance3D:
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


static func _fade_out(gi: GeometryInstance3D) -> void:
	gi.visibility_range_end = CLEARING_DRAW_DISTANCE
	gi.visibility_range_end_margin = 30.0
	gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


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
