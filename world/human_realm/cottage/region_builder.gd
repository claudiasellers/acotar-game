## Shared, deterministic placement kit for the cottage and workshop region
## generators (cottage_gen.gd, workshop_gen.gd). Preload it; not a global class.
##
## A generator describes layers as dictionaries (see `add_layer`), each with a
## zone weight callable; the builder samples points in the allowed rects that
## keep off roads, paths, the creek and any reserved circles, writes the
## ScatterLayers, fills every empty 100 m cell, builds trunk/wall/rock
## collision per 64 m chunk, and estimates draw calls for the report.
extends RefCounted

const CHUNK := 64.0
const FLORA := "res://world/human_realm/shared/assets/flora/%s.glb"
const FLORA_FAR := "res://world/human_realm/shared/assets/flora/%s_far.glb"
const FLORA_MAT := "res://world/shared/materials/stylized_flora.tres"

var region_id: StringName
var area: Rect2                     ## report area (union of the rects)
var rects: Array[Rect2] = []        ## where things may be placed
var reserved: Array = []            ## [Vector2 centre, radius] kept clear
var layers: Array[ScatterLayer] = []
var specs: Dictionary = {}          ## layer id -> spec dictionary
var rng := RandomNumberGenerator.new()
var _flora_mat: Material


func _init(p_region: StringName, p_rects: Array[Rect2], p_seed: int) -> void:
	region_id = p_region
	rects = p_rects
	area = p_rects[0]
	for r in p_rects:
		area = area.merge(r)
	rng.seed = p_seed
	_flora_mat = load(FLORA_MAT)


func reserve(centre: Vector2, radius: float) -> void:
	reserved.append([centre, radius])


func inside(p: Vector2) -> bool:
	for r in rects:
		if r.has_point(p):
			return true
	return false


## True where small things may sit: inside, off roads/paths/creek, clear of
## reserved circles by `clearance` metres.
func free_at(p: Vector2, clearance: float = 0.5, allow_reserved: bool = false) -> bool:
	if not inside(p):
		return false
	if HumanRealmLayout.distance_to_road(p) < HumanRealmLayout.ROAD_HALF_WIDTH + clearance + 0.5:
		return false
	if HumanRealmLayout.distance_to_path(p) < HumanRealmLayout.PATH_HALF_WIDTH + clearance:
		return false
	if HumanRealmLayout.distance_to_creek(p) < HumanRealmLayout.CREEK_HALF_WIDTH + 1.0 + clearance:
		return false
	if not allow_reserved:
		for r in reserved:
			if p.distance_to(r[0]) < float(r[1]) + clearance:
				return false
	return true


## Spec keys: id, mesh (flora id or res:// path), ingredient, tags, canon
## ("C"/"X"), count, zone (Callable(Vector2)->float 0..1 weight), sampler
## (optional Callable(rng)->Vector2), clearance, scale [min, max], sink
## (metres pushed into the ground), wind, draw, far (bool: flora _far
## impostor), flora_mat (bool), collider ({"type": "trunk"/"sphere"/"box",
## "r", "size"}), align (Callable(Vector2)->float yaw), allow_reserved.
func add_layer(spec: Dictionary) -> ScatterLayer:
	var layer := ScatterLayer.new()
	layer.id = StringName(spec.id)
	var mesh: String = spec.get("mesh", "")
	var is_flora := not mesh.begins_with("res://")
	layer.mesh_path = FLORA % mesh if is_flora else mesh
	if spec.get("far", false):
		layer.impostor_path = FLORA_FAR % mesh
	layer.ingredient_id = StringName(spec.get("ingredient", ""))
	var tags := PackedStringArray(spec.get("tags", []))
	tags.append("canon:%s" % spec.get("canon", "X"))
	layer.tags = tags
	layer.wind = spec.get("wind", 0.0)
	layer.draw_distance = spec.get("draw", 120.0)
	layer.cast_shadow = spec.get("shadow", true)
	if spec.get("flora_mat", is_flora):
		layer.material = _flora_mat
	layers.append(layer)
	specs[layer.id] = spec
	_fill(layer, spec)
	return layer


func _fill(layer: ScatterLayer, spec: Dictionary) -> void:
	var want: int = spec.get("count", 0)
	var zone: Callable = spec.get("zone", Callable())
	var sampler: Callable = spec.get("sampler", Callable())
	var clearance: float = spec.get("clearance", 0.5)
	var spacing: float = spec.get("spacing", 0.0)
	var allow_reserved: bool = spec.get("allow_reserved", false)
	var tries := 0
	while layer.count() < want and tries < want * 60:
		tries += 1
		var p: Vector2 = sampler.call(rng) if sampler.is_valid() else _uniform()
		if zone.is_valid() and rng.randf() > float(zone.call(p)):
			continue
		if not free_at(p, clearance, allow_reserved):
			continue
		if spacing > 0.0 and _too_close(layer, p, spacing):
			continue
		place(layer, p, spec)


func _too_close(layer: ScatterLayer, p: Vector2, spacing: float) -> bool:
	for i in layer.count():
		var q := layer.position_of(i)
		if absf(q.x - p.x) < spacing and absf(q.z - p.y) < spacing and Vector2(q.x, q.z).distance_to(p) < spacing:
			return true
	return false


func place(layer: ScatterLayer, p: Vector2, spec: Dictionary) -> void:
	var sc: Array = spec.get("scale", [0.8, 1.2])
	var s := rng.randf_range(sc[0], sc[1])
	var yaw := rng.randf() * TAU
	var align: Callable = spec.get("align", Callable())
	if align.is_valid():
		yaw = float(align.call(p))
	var y := WorldHeight.height_at(p.x, p.y) - float(spec.get("sink", 0.0)) * s
	layer.add(Vector3(p.x, y, p.y), yaw, s)


func _uniform() -> Vector2:
	var r: Rect2 = rects[rng.randi() % rects.size()]
	return Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))


# --- Samplers -------------------------------------------------------------------

## Points within `radius` of `centre` (denser toward the middle if `falloff`).
static func near(centre: Vector2, radius: float, inner: float = 0.0) -> Callable:
	return func(r: RandomNumberGenerator) -> Vector2:
		var a := r.randf() * TAU
		var d := lerpf(inner, radius, sqrt(r.randf()))
		return centre + Vector2(cos(a), sin(a)) * d


## Points along polylines, within `half_width` either side.
static func along(lines: Array, half_width: float) -> Callable:
	return func(r: RandomNumberGenerator) -> Vector2:
		var line: PackedVector2Array = lines[r.randi() % lines.size()]
		var i := r.randi() % (line.size() - 1)
		var a := line[i]
		var b := line[i + 1]
		var t := r.randf()
		var n := (b - a).orthogonal().normalized()
		return a.lerp(b, t) + n * r.randf_range(-half_width, half_width)


## Distance from p to the nearest of several polylines.
static func dist_lines(p: Vector2, lines: Array) -> float:
	var best := INF
	for l: PackedVector2Array in lines:
		best = minf(best, HumanRealmLayout.distance_to_polyline(p, l))
	return best


## Tile a mesh along polylines every `step` metres, yawed to the line (field
## walls). Skips stretches that cross roads/paths/reserved ground.
func tile_along(layer: ScatterLayer, lines: Array, step: float, spec: Dictionary) -> void:
	for l: PackedVector2Array in lines:
		for i in l.size() - 1:
			var a := l[i]
			var b := l[i + 1]
			var n := int(floor(a.distance_to(b) / step))
			var yaw := -atan2(b.y - a.y, b.x - a.x)
			for k in n:
				var p := a.lerp(b, (k + 0.5) / n)
				if free_at(p, 1.5):
					var y := WorldHeight.height_at(p.x, p.y) - 0.15
					layer.add(Vector3(p.x, y, p.y), yaw, 1.0)


# --- Coverage -------------------------------------------------------------------

func _interesting(layer: ScatterLayer) -> bool:
	return layer.is_forage() or layer.tags.has("collectible") or layer.tags.has("landmark") or layer.tags.has("look")


func empty_cells() -> Array[Vector2i]:
	var filled := {}
	for layer in layers:
		if not _interesting(layer):
			continue
		for i in layer.count():
			var p := layer.position_of(i)
			filled[Vector2i(floori((p.x - area.position.x) / ScatterReport.CELL), floori((p.z - area.position.y) / ScatterReport.CELL))] = true
	var out: Array[Vector2i] = []
	for cx in ceili(area.size.x / ScatterReport.CELL):
		for cz in ceili(area.size.y / ScatterReport.CELL):
			if not filled.has(Vector2i(cx, cz)):
				out.append(Vector2i(cx, cz))
	return out


## Every 100 m cell gets at least `per_cell` things from the fallback layers.
func cover_empty(fallback_ids: Array, per_cell: int = 2) -> int:
	var added := 0
	for c in empty_cells():
		var cell := Rect2(area.position + Vector2(c) * ScatterReport.CELL, Vector2.ONE * ScatterReport.CELL)
		for k in per_cell:
			for t in 200:
				var p := Vector2(rng.randf_range(cell.position.x, cell.end.x), rng.randf_range(cell.position.y, cell.end.y))
				if free_at(p, 0.5):
					var id: StringName = StringName(fallback_ids[rng.randi() % fallback_ids.size()])
					place(layer_by_id(id), p, specs[id])
					added += 1
					break
	return added


func layer_by_id(id: StringName) -> ScatterLayer:
	for l in layers:
		if l.id == id:
			return l
	return null


# --- Output ---------------------------------------------------------------------

## Saves every layer to dir/<id>.tres and re-points them at their files so the
## scene references them as external resources.
func save_layers(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			DirAccess.remove_absolute(dir.path_join(f))
	for layer in layers:
		var path := dir.path_join("%s.tres" % layer.id)
		var err := ResourceSaver.save(layer, path, ResourceSaver.FLAG_CHANGE_PATH)
		assert(err == OK, "save %s" % path)


## One StaticBody3D per 64 m chunk holding the colliders of every layer with
## a `collider` spec (tree trunks, boulders, field walls). Layer 1.
func build_colliders(parent: Node3D, owner: Node) -> int:
	var chunks := {}
	var shapes := 0
	for layer in layers:
		var spec: Dictionary = specs[layer.id]
		if not spec.has("collider"):
			continue
		var col: Dictionary = spec.collider
		for i in layer.count():
			var t := layer.transform_of(i)
			var key := Vector2i(floori(t.origin.x / CHUNK), floori(t.origin.z / CHUNK))
			if not chunks.has(key):
				var body := StaticBody3D.new()
				body.name = "Colliders_%d_%d" % [key.x, key.y]
				body.collision_layer = 1
				body.collision_mask = 0
				parent.add_child(body)
				body.owner = owner
				chunks[key] = body
			var s := t.basis.get_scale().x
			var cs := CollisionShape3D.new()
			cs.name = "%s_%d" % [layer.id, i]
			match String(col.type):
				"trunk":
					var c := CylinderShape3D.new()
					c.radius = float(col.r) * s
					c.height = float(col.get("h", 4.0)) * s
					cs.shape = c
					cs.position = t.origin + Vector3(0, c.height * 0.5, 0)
				"sphere":
					var sp := SphereShape3D.new()
					sp.radius = float(col.r) * s
					cs.shape = sp
					cs.position = t.origin + Vector3(0, sp.radius * 0.4, 0)
				"box":
					var b := BoxShape3D.new()
					b.size = (col.size as Vector3) * s
					cs.shape = b
					cs.transform = Transform3D(t.basis.orthonormalized(), t.origin + Vector3(0, b.size.y * 0.5, 0))
			chunks[key].add_child(cs)
			cs.owner = owner
			shapes += 1
	return shapes


## Honest draw-call estimate: worst point on a 50 m grid over the area, of
## (layer, chunk) multimeshes within each layer's draw distance, plus impostor
## chunks out to their impostor distance, plus the scene's mesh nodes.
func estimate_draw_calls(scene_meshes: int) -> int:
	var per_layer := []
	for layer in layers:
		var keys := {}
		for i in layer.count():
			var p := layer.position_of(i)
			keys[Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))] = true
		per_layer.append([layer, keys.keys()])
	var worst := 0
	var x := area.position.x
	while x <= area.end.x:
		var z := area.position.y
		while z <= area.end.y:
			var n := 0
			for entry in per_layer:
				var layer: ScatterLayer = entry[0]
				for k: Vector2i in entry[1]:
					var c := Vector2((k.x + 0.5) * CHUNK, (k.y + 0.5) * CHUNK)
					var d := c.distance_to(Vector2(x, z)) - CHUNK * 0.7
					if d < layer.draw_distance:
						n += 1
					elif layer.impostor_path != "" and d < layer.impostor_distance:
						n += 1
			worst = maxi(worst, n)
			z += 50.0
		x += 50.0
	return worst + scene_meshes


static func count_meshes(node: Node) -> int:
	var n := 0
	for c in node.find_children("*", "MeshInstance3D", true, false):
		n += 1
	return n


## Writes data/regions/human_realm/<id>.tres: centre = area centre at ground
## height, radius = half the area's diagonal.
func save_region_def(scene_path: String, report_path: String, neighbors: PackedStringArray) -> void:
	var def := RegionDef.new()
	def.id = region_id
	def.scene_path = scene_path
	var c := area.get_center()
	def.center = Vector3(c.x, WorldHeight.height_at(c.x, c.y), c.y)
	def.radius = area.size.length() * 0.5
	def.neighbors = neighbors
	def.report_path = report_path
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/regions/human_realm"))
	ResourceSaver.save(def, "res://data/regions/human_realm/%s.tres" % region_id)
