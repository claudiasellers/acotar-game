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

const MAGNET_STEP := 75.0
const MAGNET_OFFSET := 18.0
const MAGNET_HEIGHT := 14.0

var _task := -1
var _layers := {}


func _ready() -> void:
	if content == null:
		push_error("CourtRegion '%s' has no content" % name)
		return
	if threaded:
		# Load every model and fill the static caches here on the main thread, so
		# the worker never waits on the resource loader (which can need this thread).
		CourtHeight.prewarm()
		WorldHeight.height_at(0.0, 0.0)
		for e in content.forage:
			CourtAssets.mesh(e.model_id())
		for d in content.decor:
			CourtAssets.mesh(d.mesh_id)
			if d.is_tree:
				CourtAssets.mesh(d.mesh_id, true)
		_task = WorkerThreadPool.add_task(_generate, false, "court_region_%s" % content.region_id)
	else:
		build()


func _process(_delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_finish()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Builds everything now, on the calling thread (tools and tests).
func build() -> void:
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
	else:
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
	_layers = {
		"forage": CourtScatterGenerator.forage_layers(content),
		"decor": CourtScatterGenerator.decor_layers(content),
		"terrain": CourtTerrainFallback.compute(content),
	}


func _finish() -> void:
	var forage: Array[ScatterLayer] = _layers["forage"]
	var decor: Array[ScatterLayer] = _layers["decor"]
	var terrain: Array[Dictionary] = _layers["terrain"]
	CourtTerrainFallback.build_nodes(self, terrain)
	var small: Array[ScatterLayer] = []
	var trees: Array[ScatterLayer] = []
	for layer in decor:
		if layer.tags.has("tree"):
			trees.append(layer)
		else:
			small.append(layer)
	forage_field = _field("Forage", forage, SMALL_CHUNK)
	decor_field = _field("Decor", small, SMALL_CHUNK)
	tree_field = _field("Trees", trees, CourtScatterGenerator.TREE_CHUNK)
	_build_landmarks()
	_build_magnets()
	_build_anchors()
	_build_water()
	_build_fx()
	_build_grade()
	_build_creatures()
	_build_gates()
	_layers.clear()
	is_built = true
	built.emit()


func _field(node_name: String, layers: Array[ScatterLayer], chunk: float) -> ScatterField:
	var field := ScatterField.new()
	field.name = node_name
	field.region_id = content.region_id
	field.chunk_size = chunk
	field.layers = layers
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
		for i in n:
			var offset := _offset(lm, i, n)
			var world := lm.position + offset.rotated(-node.rotation.y)
			var ground := WorldHeight.height_at(world.x, world.y)
			var piece := _model(StringName(lm.asset_ids[i]))
			if CourtAssets.woods_species(StringName(lm.asset_ids[i])) != &"":
				_scale_to_height(piece, lm.height_m)
			piece.position = Vector3(offset.x, ground - y, offset.y)
			piece.rotation.y = atan2(-offset.x, -offset.y) if n > 4 and offset != Vector2.ZERO else 0.0
			node.add_child(piece)


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
	if species != &"":
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
		if col == null and not String(id).begins_with("flora_"):
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
		holder.add_child(mi)
	var river := _river_mesh()
	if river != null:
		var mi := MeshInstance3D.new()
		mi.name = "Thornwater"
		mi.mesh = river
		mi.material_override = _water_material(RIVER_MATERIAL, false)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)


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
	var mat := StandardMaterial3D.new()
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
	for lm in content.landmarks:
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
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, 6.0, 3.0)
		cs.shape = box
		cs.position.y = 3.0
		body.add_child(cs)
		gate.add_child(body)
		var n := maxi(2, int(width / 3.5))
		for i in n:
			var x := -width * 0.5 + (i + 0.5) * width / n
			var piece := _model(GATE_MODEL)
			piece.position = Vector3(x, 0.0, 0.0)
			piece.rotation.y = float(i) * 1.7
			piece.scale = Vector3.ONE * (1.3 + 0.25 * sin(i * 2.1))
			gate.add_child(piece)
		add_child(gate)


func _build_grade() -> void:
	var grade := RegionGrade.new()
	grade.name = "RegionGrade"
	grade.grade = content.grade
	grade.bounds = content.bounding_rect()
	add_child(grade)
