## Root of every wider-court region scene (world/spring_court/<id>/<id>.tscn).
## Builds the region from its CourtRegionContent when it enters the tree:
## scatter (forage, flowers, trees), landmarks with collision, lake and river
## water, ambient particles and the region's grade. No environment, sun or sky
## (the World scene's GradeDirector owns those).
class_name CourtRegion
extends Node3D

const SMALL_CHUNK := CourtScatterGenerator.SMALL_CHUNK
const FX_DIR := "res://world/spring_court/wider/fx/particles/"
const WATER_MATERIAL := "res://world/spring_court/wider/fx/materials/mat_water_lake.tres"
const RIVER_MATERIAL := "res://world/spring_court/wider/fx/materials/mat_water_river.tres"
const POOL_MATERIAL := "res://world/spring_court/wider/fx/materials/mat_water_starlight.tres"
const FX_PER_REGION := 10
const SPAWNER_SCRIPT := "res://creatures/spawning/creature_spawner.gd"
const SPAWN_DIR := "res://data/creatures/spawn/"
const WATER_TABLE := "res://data/creatures/spawn/court_waters.tres"
const GATE_MODEL := &"flora_blighted_thicket"

@export var content: CourtRegionContent
## Generate scatter on a worker thread so streaming in a region never stalls a frame.
@export var threaded: bool = true

signal built

var is_built: bool = false
var forage_field: ScatterField
var decor_field: ScatterField
var tree_field: ScatterField
var near_tree_field: ScatterField
## A place planted by place (content.place_planting): its small plants, and its grass.
var place_field: ScatterField
var sward: CourtSward

## The arched footbridge (tools/court/blender/props_shapes_b.py fae_footbridge).
const BRIDGE_ASSET := &"fae_footbridge"
const BRIDGE_MODEL_SPAN := 8.0
const BRIDGE_RISE := 1.3
const BRIDGE_HALF_WIDTH := 1.0
## River half width, the water ribbon's margin and a little dry bank.
const BRIDGE_HALF_SPAN := MacroHeight.RIVER_HALF_WIDTH + 5.0
const MAGNET_STEP := 75.0
const MAGNET_OFFSET := 18.0
const MAGNET_HEIGHT := 14.0
## The grass clumps (flora_grass_clump_*) are scattered but not drawn (owner,
## 2026-11-09): the pale tufts didn't read as grass on the storybook ground.
## Their layers stay, because GroundFuel reads them as the meadow's fuel, so a
## fire still runs through the grass; only their chunks are hidden.
const DRAW_GRASS_CLUMPS := false
const GRASS_CLUMP := "grass_clump"

var _task := -1
var _layers := {}
## The threaded build's main-thread half, one small step per entry, run under
## FrameBudget a few a frame (T161: built in one go, a neighbour streaming in
## cost the ride a 60-220 ms frame). build_now() runs what is left at once.
var _steps: Array[Callable] = []
## Bumped whenever a paced warm-up or build is abandoned (left the tree).
var _gen := 0
var _warming := false


func _ready() -> void:
	if content == null:
		push_error("CourtRegion '%s' has no content" % name)
		return
	if threaded:
		_begin()
	else:
		build()


## The threaded path: warm the caches on the main thread a model at a time,
## then generate on a worker.
func _begin() -> void:
	_gen += 1
	_warming = true
	_warm_then_start(weakref(self), _gen, BuildPace.new(get_tree(), content.region_id))


static func _warm_then_start(ref: WeakRef, gen: int, pace: BuildPace) -> void:
	var r := ref.get_ref() as CourtRegion
	if r == null:
		return
	for step in prewarm_steps(r.content):
		step.call()
		await pace.tick()
		r = ref.get_ref() as CourtRegion
		if r == null or r._gen != gen:
			return
	r._warming = false
	r._start()


## Loads every model and fills the static caches on the main thread, so the
## worker never waits on the resource loader (which can need this thread
## while it waits on the worker: a deadlock). Covers everything
## forage_layers / decor_layers ask for, places included
## (tests/unit/landscape/test_place_composition.gd checks that).
static func prewarm(c: CourtRegionContent) -> void:
	for step in prewarm_steps(c):
		step.call()


## prewarm() as separate steps (one model each), for a paced warm-up.
static func prewarm_steps(c: CourtRegionContent) -> Array[Callable]:
	var out: Array[Callable] = [CourtHeight.prewarm, WorldHeight.height_at.bind(0.0, 0.0)]
	for e in c.forage:
		out.append(CourtAssets.mesh.bind(e.model_id()))
	for d in c.decor:
		out.append(CourtAssets.mesh.bind(d.mesh_id))
		if d.is_tree:
			out.append(CourtAssets.mesh.bind(d.mesh_id, true))
			# The tree set: every build and step the scatter splits them over.
			out.append(CourtTreeSet.prewarm.bind([d.mesh_id]))
	out.append(func() -> void: PlaceComposer.prewarm(PlaceComposer.in_rect(PlaceComposer.table(), c.bounding_rect())))
	if c.place_planting != &"":
		out.append(CourtPlacePlants.prewarm)
	return out


func _start() -> void:
	BuildCancel.clear(content.region_id)
	_task = WorkerThreadPool.add_task(_generate, false, "court_region_%s" % content.region_id)


## Back in the tree after leaving mid-build: a paced build carries on where
## it stopped; a cancelled worker's partial layers were dropped, so generate again.
func _enter_tree() -> void:
	if not is_node_ready() or content == null or not threaded or is_built:
		return
	if not _steps.is_empty():
		_gen += 1
		_run_paced(weakref(self), _gen, BuildPace.new(get_tree(), content.region_id))
	elif _task < 0 and _layers.is_empty():
		_begin()


func _process(_delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_plan_finish()
		_gen += 1
		_run_paced(weakref(self), _gen, BuildPace.new(get_tree(), content.region_id))


static func _run_paced(ref: WeakRef, gen: int, pace: BuildPace) -> void:
	while true:
		var r := ref.get_ref() as CourtRegion
		if r == null or r._gen != gen or r._steps.is_empty():
			return
		r._steps.pop_front().call()
		r = null
		await pace.tick()


func _exit_tree() -> void:
	# A paced warm-up or build pauses here; _enter_tree picks it up again.
	_gen += 1
	_warming = false
	if _task >= 0:
		# Leaving mid-build (quit, teleport): stop the worker early, then join.
		BuildCancel.request(content.region_id)
		WorkerThreadPool.wait_for_task_completion(_task)
		# The worker is joined: drop the flag, or every later scatter of this
		# region (a map, a test, a tool) sees it and comes back empty.
		BuildCancel.clear(content.region_id)
		_task = -1
		_layers.clear()


## Builds everything now, on the calling thread (tools and tests).
func build() -> void:
	BuildCancel.clear(content.region_id)
	_generate()
	_finish()


## Hero trees along the walks, one about every MAGNET_STEP m, so a magnet is
## always in view ahead (experience bar 1.3): the region's signature blossom
## tree, alternating with ancient oaks. Deterministic from the content.
func _build_magnets() -> void:
	if content.blight:
		return
	var blossom: StringName = &"woods_ancient_oak"
	for d in content.decor:
		if String(d.mesh_id) in ["woods_wild_cherry", "woods_lilac_tree", "woods_crab_apple", "woods_hawthorn"]:
			blossom = d.mesh_id
			break
	var holder := Node3D.new()
	holder.name = "Magnets"
	add_child(holder)
	var placed: Array[Vector2] = []
	for lm in content.landmarks:
		placed.append(lm.position)
	var n := 0
	for line in sightline_paths():
		var walked := MAGNET_STEP * 0.5
		for i in range(1, line.size()):
			walked += line[i].distance_to(line[i - 1])
			if walked < MAGNET_STEP:
				continue
			var dir := (line[i] - line[i - 1]).normalized()
			var side := Vector2(-dir.y, dir.x) * (MAGNET_OFFSET if n % 2 == 0 else -MAGNET_OFFSET)
			var p := line[i] + dir * 45.0 + side
			if not content.owns(p) or content.in_anchor_clearing(p):
				continue
			var crowded := false
			for q in placed:
				crowded = crowded or q.distance_to(p) < MAGNET_STEP * 0.4
			if crowded:
				continue
			var id := blossom if n % 2 == 0 else &"woods_ancient_oak"
			var piece := _model(id)
			_scale_to_height(piece, MAGNET_HEIGHT)
			piece.name = "magnet_%02d" % n
			piece.position = Vector3(p.x, WorldHeight.height_at(p.x, p.y), p.y)
			piece.rotation.y = float(n) * 2.39
			piece.add_to_group(&"magnet")
			piece.set_meta(&"magnet_height", MAGNET_HEIGHT * 0.8)
			holder.add_child(piece)
			placed.append(p)
			walked = 0.0
			n += 1


## Sightline checker hook (tools/sightline_check.gd): finish a pending build now.
func build_now() -> void:
	if is_built:
		return
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_finish()
	elif not _steps.is_empty():
		_gen += 1
		while not _steps.is_empty():
			_steps.pop_front().call()
	else:
		if _warming:
			_gen += 1
			_warming = false
		build()


## The walks a player takes here, for the sightline checker: a nearest-first
## tour of the region's landmarks, story anchors and gates, cut where it
## leaves our ground.
func sightline_paths() -> Array[PackedVector2Array]:
	var stops: Array[Vector2] = []
	for lm in content.landmarks:
		stops.append(lm.position)
	for a in content.anchors:
		stops.append(a["position"])
	for g in content.gates:
		stops.append(g["position"])
	var out: Array[PackedVector2Array] = []
	if stops.size() < 2:
		return out
	var tour: Array[Vector2] = [stops.pop_front()]
	while not stops.is_empty():
		var last: Vector2 = tour[-1]
		var best := 0
		for i in stops.size():
			if stops[i].distance_to(last) < stops[best].distance_to(last):
				best = i
		tour.append(stops.pop_at(best))
	var line := PackedVector2Array()
	for i in tour.size() - 1:
		var a: Vector2 = tour[i]
		var b: Vector2 = tour[i + 1]
		var steps := maxi(1, int(a.distance_to(b) / 10.0))
		for k in steps:
			var p := a.lerp(b, float(k) / steps)
			if content.owns(p):
				line.append(p)
			elif line.size() > 1:
				out.append(line)
				line = PackedVector2Array()
			else:
				line.clear()
	if line.size() > 1:
		out.append(line)
	return out


## Horror zones are measured by their own bar (withdrawal), not by magnets.
func sightline_skip(_x: float, _z: float) -> bool:
	return content.blight


func _generate() -> void:
	var forage := CourtScatterGenerator.forage_layers(content)
	var decor := CourtScatterGenerator.decor_layers(content)
	var terrain := CourtTerrainFallback.compute(content)
	if BuildCancel.requested(content.region_id):
		return  # partial; _exit_tree drops it
	var small: Array[ScatterLayer] = []
	var trees: Array[ScatterLayer] = []
	var near_trees: Array[ScatterLayer] = []
	var fine: Array[ScatterLayer] = []
	for layer in decor:
		if layer.tags.has("fine"):
			fine.append(layer)
		elif layer.tags.has("near"):
			near_trees.append(layer)
		elif layer.tags.has("tree"):
			trees.append(layer)
		else:
			small.append(layer)
	# Each field: [node name, layers, chunk size, per layer its chunk plan].
	var fields := [["Forage", forage, SMALL_CHUNK], ["Decor", small, SMALL_CHUNK],
		["Trees", trees, CourtScatterGenerator.TREE_CHUNK],
		# the near step in smaller chunks (each tree switches step at its own distance)
		["TreesNear", near_trees, CourtScatterGenerator.NEAR_CHUNK]]
	if content.place_planting != &"":
		# a place's own small plants, by the small chunk
		fields.append(["PlacePlants", fine, CourtGlenPlanting.FINE_CHUNK])
	for f: Array in fields:
		var plans := []
		for layer: ScatterLayer in f[1]:
			var drawn := layer != null and layer.count() > 0 and layer.draw_mesh() != null
			plans.append(ScatterField.chunk_plan(layer, f[2]) if drawn else [])
		f.append(plans)
	_layers = {"terrain": terrain, "fields": fields}


## Builds everything _generate prepared, now.
func _finish() -> void:
	_plan_finish()
	while not _steps.is_empty():
		_steps.pop_front().call()


## The main-thread build as small steps: the fallback terrain, the scatter
## fields a chunk at a time, then each kind of set dressing.
func _plan_finish() -> void:
	var terrain: Array[Dictionary] = _layers["terrain"]
	_steps.clear()
	_steps.append(CourtTerrainFallback.build_nodes.bind(self, terrain))
	for f: Array in _layers["fields"]:
		var field := _field(f[0], f[1], f[2], true)
		match String(f[0]):
			"Forage": forage_field = field
			"Decor": decor_field = field
			"Trees": tree_field = field
			"TreesNear": near_tree_field = field
			"PlacePlants": place_field = field
		var layers: Array[ScatterLayer] = f[1]
		var plans: Array = f[3]
		for i in layers.size():
			for chunk: Array in plans[i]:
				_steps.append(field.build_chunk.bind(layers[i], chunk[0], chunk[1]))
		if field == decor_field and not DRAW_GRASS_CLUMPS:
			_steps.append(_hide_grass_clumps.bind(field))
	if content.place_planting != &"":
		_steps.append(_build_sward)
	for step: Callable in [_build_landmarks, _build_places, _build_magnets, _build_anchors, _build_water,
			_build_fx, _build_grade, _build_creatures, _build_gates, _built]:
		_steps.append(step)


## Its grass round the player, and the motes.
func _build_sward() -> void:
	sward = CourtSward.new()
	sward.name = "Sward"
	sward.content = content
	sward.trunks = CourtGlenPlanting.trunks(content.region_id)
	add_child(sward)
	CourtMotes.build(self, content)


func _built() -> void:
	_layers.clear()
	is_built = true
	built.emit()



## Hides the grass clumps' chunks (see DRAW_GRASS_CLUMPS); the layers stay fuel.
static func _hide_grass_clumps(field: ScatterField) -> void:
	if not field.is_node_ready():
		# Built off-tree (tools): its chunks appear when it enters the tree.
		field.ready.connect(_hide_grass_clumps.bind(field), CONNECT_ONE_SHOT)
		return
	for child in field.get_children():
		if child is MultiMeshInstance3D and String(child.name).contains(GRASS_CLUMP):
			child.visible = false


func _field(node_name: String, layers: Array[ScatterLayer], chunk: float, chunked: bool = false) -> ScatterField:
	var field := ScatterField.new()
	field.name = node_name
	field.region_id = content.region_id
	field.chunk_size = chunk
	field.layers = layers
	# Its chunks come a step at a time (_plan_finish), not all in _ready.
	field.prebuilt = chunked
	add_child(field)
	return field


func _build_landmarks() -> void:
	var holder := Node3D.new()
	holder.name = "Landmarks"
	add_child(holder)
	for lm in content.landmarks:
		var node := Node3D.new()
		node.name = String(lm.id)
		node.set_meta(&"display_name", lm.display_name)
		node.set_meta(&"kind", lm.kind)
		node.add_to_group(&"landmark")
		var y := WorldHeight.height_at(lm.position.x, lm.position.y)
		node.position = Vector3(lm.position.x, y, lm.position.y)
		node.rotation.y = deg_to_rad(lm.yaw_degrees)
		holder.add_child(node)
		if lm.kind == &"waterfall" and not lm.offsets.is_empty():
			_build_falls(node, lm)
		var n := lm.asset_ids.size()
		if lm.asset_ids.has(BRIDGE_ASSET):
			_build_bridge(node, lm)
			continue
		for i in n:
			var offset := _offset(lm, i, n)
			var world := lm.position + offset.rotated(-node.rotation.y)
			var ground := WorldHeight.height_at(world.x, world.y)
			var piece := _model(StringName(lm.asset_ids[i]))
			if CourtAssets.woods_species(StringName(lm.asset_ids[i])) != &"":
				_scale_to_height(piece, lm.height_m)
			piece.position = Vector3(offset.x, ground - y, offset.y)
			piece.rotation.y = atan2(-offset.x, -offset.y) if n > 4 and offset != Vector2.ZERO else 0.0
			var great := CourtAssets.great_species(StringName(lm.asset_ids[i]))
			if great != &"":
				piece.rotation.y = CourtGreatTrees.facing(great, world) - node.rotation.y
			node.add_child(piece)


## {a, b}: where a bridge landmark's deck ends sit, square across the Thornwater
## at its nearest point, clear of the water ribbon either side.
static func bridge_ends(lm: CourtLandmark) -> Array[Vector3]:
	var span := BridgeSpan.square_across(MacroHeight.THORNWATER, lm.position, Vector2.ZERO)
	return BridgeSpan.ends_on_ground(span, BRIDGE_HALF_SPAN)


## The arched footbridge stretched along its length to reach both banks, a
## deck collider of its own, and the landmark's other pieces at its ends.
func _build_bridge(node: Node3D, lm: CourtLandmark) -> void:
	var ends := bridge_ends(lm)
	var xf := node.transform.affine_inverse() * BridgeSpan.frame(ends[0], ends[1])
	var length := ends[0].distance_to(ends[1])
	var piece := _model(BRIDGE_ASSET)
	var col := piece.get_node_or_null("Collision")
	if col != null:
		piece.remove_child(col)
		col.free()
	# The model's long axis is local X and its deck spans BRIDGE_MODEL_SPAN.
	piece.transform = Transform3D(xf.basis * Basis(Vector3.UP, -PI * 0.5) * Basis.from_scale(Vector3(length / BRIDGE_MODEL_SPAN, 1.0, 1.0)), xf.origin)
	node.add_child(piece)
	var body := StaticBody3D.new()
	body.name = "BridgeDeck"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = BridgeSpan.deck_shape(BridgeSpan.arch_profile(length, BRIDGE_RISE), BRIDGE_HALF_WIDTH)
	cs.transform = xf
	body.add_child(cs)
	node.add_child(body)
	var side := xf.basis.x * (BRIDGE_HALF_WIDTH + 0.5)
	var posts := 0
	for id in lm.asset_ids:
		if id == BRIDGE_ASSET:
			continue
		var other := _model(StringName(id))
		if id == "stepping_stones":
			var mid := (ends[0] + ends[1]) * 0.5
			other.position = node.transform.affine_inverse() * Vector3(mid.x, WorldHeight.height_at(mid.x, mid.z), mid.z)
		else:
			other.position = node.transform.affine_inverse() * ends[posts % 2] + side
			posts += 1
		node.add_child(other)


## Each landmark's own setting (lane L32): its light, particles and
## positional sound. The planted collar and props are scatter (decor_layers).
func _build_places() -> void:
	var holder := Node3D.new()
	holder.name = "Places"
	add_child(holder)
	var mine: Array[PlaceSetting] = []
	var t := PlaceComposer.table()
	if t == null:
		return
	for lm in content.landmarks:
		var s := t.find(lm.id)
		if s != null:
			mine.append(s)
	PlaceComposer.build_nodes(holder, mine)


## Story anchors: StoryDirector hangs each book scene's MomentSpace here.
func _build_anchors() -> void:
	for a in content.anchors:
		var marker := Marker3D.new()
		marker.name = String(a["id"])
		marker.set_meta(&"anchor_id", a["id"])
		marker.add_to_group(&"story_anchor")
		var p: Vector2 = a["position"]
		marker.position = Vector3(p.x, WorldHeight.height_at(p.x, p.y), p.y)
		marker.rotation.y = deg_to_rad(float(a["yaw_degrees"]))
		add_child(marker)


## A rainbow sheet of water from the crest (the landmark) to where it lands
## (its first offset), with mist at the foot.
func _build_falls(node: Node3D, lm: CourtLandmark) -> void:
	var land := lm.position + lm.offsets[0]
	var top := node.position.y + 1.0
	var bottom := WorldHeight.height_at(land.x, land.y)
	for lake in CourtHeight.lakes():
		if land.distance_to(lake["center"]) <= float(lake["radius"]) + 6.0:
			bottom = float(lake["level"])
	var across := lm.offsets[0].normalized().orthogonal()
	var width := clampf(lm.height_m * 0.3, 5.0, 12.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 12
	var verts: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	for r in rows + 1:
		var t := float(r) / rows
		# Water leaves the lip nearly flat, then drops: ease the horizontal run.
		var run: Vector2 = lm.offsets[0] * (1.0 - pow(1.0 - t, 2.2))
		var y := lerpf(top, bottom, t * t * (3.0 - 2.0 * t)) - node.position.y
		var w := width * (1.0 + t * 0.6)
		for side: float in [-1.0, 1.0]:
			var p: Vector2 = run + across * w * 0.5 * side
			verts.append(Vector3(p.x, y, p.y))
			uvs.append(Vector2(0.0 if side < 0.0 else 1.0, t))
	for r in rows:
		var i := r * 2
		for idx in [i, i + 2, i + 1, i + 1, i + 2, i + 3]:
			st.set_uv(uvs[idx])
			st.add_vertex(verts[idx])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "RainbowFalls"
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/spring_court/wider/court_rainbow_falls.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	var mist_path := "%sfx_water_mist.tscn" % FX_DIR
	if ResourceLoader.exists(mist_path):
		var mist := (load(mist_path) as PackedScene).instantiate() as Node3D
		mist.position = Vector3(lm.offsets[0].x, bottom - node.position.y + 0.5, lm.offsets[0].y)
		node.add_child(mist)


## Pieces in a ring (stone circles, cottage rows) or a loose cluster.
func _offset(lm: CourtLandmark, i: int, n: int) -> Vector2:
	if i < lm.offsets.size():
		return lm.offsets[i]
	if n == 1 or i == 0 and n <= 4:
		return Vector2.ZERO
	var radius := clampf(2.6 * n, 6.0, 22.0)
	var a := TAU * float(i) / float(n)
	return Vector2(cos(a), sin(a)) * radius


## Hero trees: the archetype grown to the landmark's height.
func _scale_to_height(piece: Node3D, height: float) -> void:
	var mi := piece.get_child(0) as MeshInstance3D
	var h := mi.mesh.get_aabb().size.y if mi != null and mi.mesh != null else 0.0
	if h > 0.1:
		piece.scale = Vector3.ONE * (height / h)


func _model(id: StringName) -> Node3D:
	var packed := CourtAssets.scene(id)
	var root: Node3D
	var species := CourtAssets.woods_species(id)
	var great := CourtAssets.great_species(id)
	if great != &"":
		# one of the court's great trees: its own mesh at its true height, and its bole to walk into
		root = Node3D.new()
		var tree := MeshInstance3D.new()
		tree.name = "near"
		tree.mesh = CourtGreatTrees.mesh(great)
		root.add_child(tree)
		var bole := CylinderShape3D.new()
		bole.radius = float(CourtGreatTrees.TREES[great]["trunk"])
		bole.height = 6.0
		_add_collision(root, bole, Transform3D(Basis(), Vector3(0, 3.0, 0)))
	elif species != &"":
		root = Node3D.new()
		var tree := MeshInstance3D.new()
		tree.name = "near"
		tree.mesh = CourtAssets.mesh(id)
		root.add_child(tree)
		var radius := float(FloraLibrary.info(species).get("radius", 0.0))
		if radius > 0.0:
			var shape := CylinderShape3D.new()
			shape.radius = radius
			shape.height = 6.0
			_add_collision(root, shape, Transform3D(Basis(), Vector3(0, 3.0, 0)))
	elif packed != null:
		root = packed.instantiate() as Node3D
		var lod := root.find_child("%s_LOD1" % id, true, false) as MeshInstance3D
		if lod != null:
			lod.visible = false
		var col := root.find_child("%s_col" % id, true, false) as MeshInstance3D
		if col != null:
			col.visible = false
			_add_collision(root, col.mesh.create_trimesh_shape(), col.transform)
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if mi.visible:
				mi.material_override = CourtAssets.material_for(id)
		# Godot turns `<id>_col-colonly` into a StaticBody3D named `<id>_col`, so the
		# model already carries its authored collision. Without this check the whole
		# bounding box was added too, which sealed every arch's opening.
		var authored := root.find_child("%s_col" % id, true, false) is CollisionObject3D
		if col == null and not authored and not String(id).begins_with("flora_"):
			_add_box_collision(root)
	else:
		root = Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = CourtAssets.placeholder(id)
		if mi.mesh is BoxMesh:
			mi.position.y = (mi.mesh as BoxMesh).size.y * 0.5
		elif mi.mesh is CapsuleMesh:
			mi.position.y = (mi.mesh as CapsuleMesh).height * 0.5
		root.add_child(mi)
		if not String(id).begins_with("flora_"):
			_add_box_collision(root)
	root.name = String(id)
	return root


func _add_box_collision(root: Node3D) -> void:
	var aabb := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible or mi.mesh == null:
			continue
		var box := mi.transform * mi.mesh.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	if first or aabb.size.length() < 0.5:
		return
	var shape := BoxShape3D.new()
	shape.size = aabb.size
	_add_collision(root, shape, Transform3D(Basis(), aabb.get_center()))


func _add_collision(root: Node3D, shape: Shape3D, xform: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xform
	body.add_child(cs)
	root.add_child(body)


func _build_water() -> void:
	var holder := Node3D.new()
	holder.name = "Water"
	add_child(holder)
	for lake in CourtHeight.lakes():
		var c: Vector2 = lake["center"]
		if not content.owns(c):
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Lake_%d_%d" % [int(c.x), int(c.y)]
		var disk := CylinderMesh.new()
		disk.top_radius = float(lake["radius"]) * 1.12
		disk.bottom_radius = disk.top_radius
		disk.height = 0.02
		disk.radial_segments = 48
		disk.rings = 1
		mi.mesh = disk
		mi.position = Vector3(c.x, float(lake["level"]), c.y)
		var pool := float(lake["radius"]) < 30.0
		mi.material_override = _water_material(POOL_MATERIAL if pool else WATER_MATERIAL, pool)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# a wood across the water lies on it (CourtGlenPlaces: Looking Lake's mirror)
		var mirror := CourtGlenPlaces.mirror(content, lake)
		if not mirror.is_empty():
			var at: Vector2 = mirror["center"]
			var colour: Color = mirror["colour"]
			mi.set_instance_shader_parameter(&"mirror_wood", Vector4(at.x, at.y, mirror["radius"], mirror["height"]))
			mi.set_instance_shader_parameter(&"mirror_arc", Vector2(mirror["bearing"], mirror["half"]))
			mi.set_instance_shader_parameter(&"mirror_colour", Color(colour.r, colour.g, colour.b, mirror["strength"]))
		holder.add_child(mi)
	var river := _river_mesh()
	if river != null:
		var mi := MeshInstance3D.new()
		mi.name = "Thornwater"
		mi.mesh = river
		mi.material_override = _water_material(RIVER_MATERIAL, false)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	var brooks := _brook_mesh()
	if brooks != null:
		var mi := MeshInstance3D.new()
		mi.name = "Brooks"
		mi.mesh = brooks
		mi.material_override = _water_material(RIVER_MATERIAL, false)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)


## The clear brooks (CourtHeight.brooks): a ribbon at each brook's own water
## level, only where this region owns the bank.
func _brook_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := 0
	for b in CourtHeight.brooks():
		var pts: PackedVector2Array = b["points"]
		var lv: PackedFloat32Array = b["levels"]
		var half: float = float(b["half_width"]) + 0.4
		for k in pts.size() - 1:
			var p0 := pts[k]
			var p1 := pts[k + 1]
			if not content.owns(p0.lerp(p1, 0.5)):
				continue
			var side := (p1 - p0).normalized().orthogonal() * half
			var v := [Vector3(p0.x + side.x, lv[k], p0.y + side.y), Vector3(p0.x - side.x, lv[k], p0.y - side.y),
				Vector3(p1.x + side.x, lv[k + 1], p1.y + side.y), Vector3(p1.x - side.x, lv[k + 1], p1.y - side.y)]
			for idx in [0, 2, 1, 1, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(1.0 if idx % 2 == 1 else 0.0, (k + (1 if idx >= 2 else 0)) * 0.3))
				st.add_vertex(v[idx])
			quads += 1
	if quads == 0:
		return null
	return st.commit()


## A ribbon over the river channel, only where this region owns the bank.
func _river_mesh() -> Mesh:
	var pts := MacroHeight.THORNWATER
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := MacroHeight.RIVER_HALF_WIDTH + 3.0
	var quads := 0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var steps := maxi(1, int(a.distance_to(b) / 6.0))
		for s in steps:
			var p0 := a.lerp(b, float(s) / steps)
			var p1 := a.lerp(b, float(s + 1) / steps)
			if not content.owns(p0.lerp(p1, 0.5)):
				continue
			var side := (p1 - p0).normalized().orthogonal() * half
			var y0 := CourtHeight.river_level_at(p0.x, p0.y)
			var y1 := CourtHeight.river_level_at(p1.x, p1.y)
			var v := [Vector3(p0.x + side.x, y0, p0.y + side.y), Vector3(p0.x - side.x, y0, p0.y - side.y),
				Vector3(p1.x + side.x, y1, p1.y + side.y), Vector3(p1.x - side.x, y1, p1.y - side.y)]
			for idx in [0, 2, 1, 1, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(1.0 if idx % 2 == 1 else 0.0, (s + (1 if idx >= 2 else 0)) * 0.2))
				st.add_vertex(v[idx])
			quads += 1
	if quads == 0:
		return null
	return st.commit()


func _water_material(path: String, pool: bool) -> Material:
	if ResourceLoader.exists(path):
		return load(path) as Material
	var mat := MaterialLibrary.surface()
	mat.albedo_color = Color(0.62, 0.86, 0.95, 0.72) if not pool else Color(0.80, 0.90, 1.0, 0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mat.metallic_specular = 0.9
	return mat


func _build_fx() -> void:
	var holder := Node3D.new()
	holder.name = "Ambient"
	add_child(holder)
	var spots: Array[Vector2] = []
	# Landmarks with a PlaceSetting carry their own particles (_build_places).
	var dressed := PlaceComposer.table()
	for lm in content.landmarks:
		if dressed == null or dressed.find(lm.id) == null:
			spots.append(lm.position)
	for h in content.habitats:
		if h.shape == CourtHabitat.Shape.CIRCLE or h.shape == CourtHabitat.Shape.RING:
			if content.owns(h.center):
				spots.append(h.center)
	if spots.is_empty():
		spots.append(content.bounding_rect().get_center())
	var placed := 0
	var i := 0
	while placed < FX_PER_REGION and not content.ambient_fx.is_empty() and i < FX_PER_REGION * 3:
		var fx_id := content.ambient_fx[i % content.ambient_fx.size()]
		var spot := spots[i % spots.size()]
		i += 1
		var path := "%s%s.tscn" % [FX_DIR, fx_id]
		if not ResourceLoader.exists(path):
			continue
		var fx := (load(path) as PackedScene).instantiate() as Node3D
		if fx == null:
			continue
		fx.name = "%s_%d" % [fx_id, placed]
		fx.position = Vector3(spot.x, WorldHeight.height_at(spot.x, spot.y) + 1.5, spot.y)
		holder.add_child(fx)
		placed += 1
	# a composed place's own (CourtGlenPlaces: petals falling at the Thorn Gate and the Blossom Knoll)
	for e: Array in CourtGlenPlaces.effects(content):
		var path := "%s%s.tscn" % [FX_DIR, e[0]]
		if not ResourceLoader.exists(path):
			continue
		var fx := (load(path) as PackedScene).instantiate() as Node3D
		if fx == null:
			continue
		var at: Vector3 = e[1]
		fx.name = "%s_place_%d" % [e[0], holder.get_child_count()]
		fx.position = Vector3(at.x, WorldHeight.height_at(at.x, at.z) + at.y, at.z)
		holder.add_child(fx)


## The creatures lane's spawners (data only: a table per region, plus the
## water table on our lakes). Loaded by path so regions don't depend on the
## creatures lane's classes.
func _build_creatures() -> void:
	if not ResourceLoader.exists(SPAWNER_SCRIPT):
		return
	var script := load(SPAWNER_SCRIPT)
	var table_path := "%s%s.tres" % [SPAWN_DIR, content.region_id]
	if ResourceLoader.exists(table_path):
		var table := load(table_path)
		for i in content.bounds.size():
			var sp := Node3D.new()
			sp.set_script(script)
			sp.name = "Creatures_%d" % i
			sp.set("table", table)
			sp.set("bounds", content.bounds[i])
			sp.set("seed", content.seed + i)
			add_child(sp)
	if ResourceLoader.exists(WATER_TABLE):
		var water := load(WATER_TABLE)
		for lake in CourtHeight.lakes():
			var c: Vector2 = lake["center"]
			if not content.owns(c) or float(lake["radius"]) < 30.0:
				continue
			var rad: float = lake["radius"]
			var sp := Node3D.new()
			sp.set_script(script)
			sp.name = "Waters_%d_%d" % [int(c.x), int(c.y)]
			sp.set("table", water)
			sp.set("bounds", Rect2(c - Vector2(rad, rad) * 1.4, Vector2(rad, rad) * 2.8))
			sp.set("water_level", float(lake["level"]))
			sp.set("water_bounds", Rect2(c - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4))
			sp.set("seed", content.seed + 77)
			add_child(sp)


## Physical locks (RegionGate): a wall of blighted thorn across the way, solid
## until the phase ladder opens its region. Never an invisible wall.
func _build_gates() -> void:
	for g in content.gates:
		var gate := RegionGate.new()
		gate.name = "Gate_%s" % g["region_id"]
		gate.region_id = g["region_id"]
		var p: Vector2 = g["position"]
		gate.position = Vector3(p.x, WorldHeight.height_at(p.x, p.y), p.y)
		gate.rotation.y = deg_to_rad(float(g["yaw_degrees"]))
		var width: float = g["width"]
		var height := RegionGate.min_height()
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, height, 3.0)
		cs.shape = box
		cs.position.y = height * 0.5
		body.add_child(cs)
		gate.add_child(body)
		var n := maxi(2, int(width / 3.5))
		for i in n:
			var x := -width * 0.5 + (i + 0.5) * width / n
			var piece := _model(GATE_MODEL)
			piece.position = Vector3(x, 0.0, 0.0)
			piece.rotation.y = float(i) * 1.7
			# Grown at least as tall as the lock, crowns arching over the way.
			_scale_to_height(piece, height * (1.04 + 0.08 * absf(sin(i * 2.1))))
			piece.rotation.x = 0.12 * sin(i * 1.3)
			gate.add_child(piece)
		add_child(gate)


func _build_grade() -> void:
	var grade := RegionGrade.new()
	grade.name = "RegionGrade"
	grade.grade = content.grade
	grade.bounds = content.bounding_rect()
	grade.rects = content.bounds
	grade.holes = content.holes
	add_child(grade)
