## Shared helpers for the hunting_forest and wall_seam generators: layer
## creation, ground checks against the human realm layout, landmark nodes
## built from the Blender .glb + .collision.json, the draw-call estimate and
## saving. Generators are deterministic: every random draw comes from the
## RandomNumberGenerator passed in.
class_name ForestGenUtil
extends RefCounted

const FLORA := "res://world/human_realm/shared/assets/flora/%s.glb"
const FLORA_FAR := "res://world/human_realm/shared/assets/flora/%s_far.glb"
const FLORA_MAT := preload("res://world/shared/materials/stylized_flora.tres")
const FOREST_ASSETS := "res://world/human_realm/hunting_forest/assets/%s.glb"
const FOREST_PROPS := "res://world/human_realm/hunting_forest/assets/props/%s.glb"
const SEAM_ASSETS := "res://world/human_realm/wall_seam/assets/%s.glb"
const SEAM_PROPS := "res://world/human_realm/wall_seam/assets/props/%s.glb"
const CHUNK := 64.0


## A new layer. `canon` is "C" or "X" (Keeper's tag, added as "canon:C/X").
static func layer(id: StringName, mesh_path: String, ingredient: StringName, tags: Array, canon: String, flora_material := false, wind := 0.0) -> ScatterLayer:
	var l := ScatterLayer.new()
	l.id = id
	l.mesh_path = mesh_path
	l.ingredient_id = ingredient
	var t := PackedStringArray(tags)
	t.append("canon:" + canon)
	l.tags = t
	l.wind = wind
	if flora_material:
		l.material = FLORA_MAT
	return l


static func tree_layer(id: StringName, asset: String, canon: String) -> ScatterLayer:
	var l := layer(id, FLORA % asset, &"", ["tree"], canon, true, 0.15)
	l.impostor_path = FLORA_FAR % asset
	l.draw_distance = 140.0
	l.impostor_distance = 320.0
	return l


static func off_road(p: Vector2, margin: float = 1.0) -> bool:
	return HumanRealmLayout.distance_to_road(p) > HumanRealmLayout.ROAD_HALF_WIDTH + margin


static func off_creek(p: Vector2, margin: float = 0.5) -> bool:
	return HumanRealmLayout.distance_to_creek(p) > HumanRealmLayout.CREEK_HALF_WIDTH + margin


static func off_path(p: Vector2, margin: float = 0.3) -> bool:
	return HumanRealmLayout.distance_to_path(p) > HumanRealmLayout.PATH_HALF_WIDTH + margin


## True when p is outside every exclusion circle (Vector3(x, z, radius)).
static func clear_of(p: Vector2, circles: Array) -> bool:
	for c: Vector3 in circles:
		if p.distance_squared_to(Vector2(c.x, c.y)) < c.z * c.z:
			return false
	return true


static func put(l: ScatterLayer, x: float, z: float, yaw: float, scale: float, lift := 0.0) -> void:
	l.add(Vector3(x, WorldHeight.height_at(x, z) + lift, z), yaw, scale)


## Yaw (radians about +Y) that turns a model's local +Z toward direction d (x, z).
static func yaw_facing(d: Vector2) -> float:
	return atan2(d.x, d.y)


## Yaw that lays a model's local +X along direction d (x, z).
static func yaw_along(d: Vector2) -> float:
	return atan2(-d.y, d.x)


## A point on a polyline at arc length s (clamped), plus the unit direction.
static func along(line: PackedVector2Array, s: float) -> Array:
	var left := s
	for i in line.size() - 1:
		var seg := line[i + 1] - line[i]
		var len := seg.length()
		if left <= len or i == line.size() - 2:
			var t := clampf(left / len, 0.0, 1.0)
			return [line[i] + seg * t, seg / len]
		left -= len
	return [line[0], Vector2.RIGHT]


static func polyline_length(line: PackedVector2Array) -> float:
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	return total


## Box collision from a Blender .collision.json beside the .glb, transformed
## by (pos, yaw, scale). Blender (x, y, z) -> Godot (x, z, -y).
static func collision_boxes(glb_path: String) -> Array:
	var json_path := glb_path.get_basename() + ".collision.json"
	if not FileAccess.file_exists(json_path):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	return data if data is Array else []


static func add_boxes(body: StaticBody3D, owner: Node, boxes: Array, pos: Vector3, yaw: float, scale := 1.0) -> void:
	var rot := Basis(Vector3.UP, yaw)
	for b: Dictionary in boxes:
		var c: Array = b["centre"]
		var sz: Array = b["size"]
		var shape := BoxShape3D.new()
		shape.size = Vector3(sz[0], sz[2], sz[1]) * scale
		var cs := CollisionShape3D.new()
		cs.shape = shape
		var local := Vector3(c[0], c[2], -float(c[1])) * scale
		cs.transform = Transform3D(rot * Basis(Vector3.UP, float(b["yaw"])), pos + rot * local - body.position)
		body.add_child(cs)
		cs.owner = owner


## Instance a landmark .glb at pos (y from the ground unless given) with its
## box collision on layer 1. Returns the instance.
static func landmark(parent: Node, owner: Node, name: String, glb_path: String, p: Vector2, yaw: float, scale := 1.0, y_offset := 0.0) -> Node3D:
	var scene := load(glb_path) as PackedScene
	var pos := Vector3(p.x, WorldHeight.height_at(p.x, p.y) + y_offset, p.y)
	var node: Node3D
	if scene != null:
		node = scene.instantiate()
	else:
		push_warning("ForestGenUtil: missing %s" % glb_path)
		node = Node3D.new()
	node.name = name
	node.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), pos)
	parent.add_child(node)
	node.owner = owner
	var boxes := collision_boxes(glb_path)
	if not boxes.is_empty():
		var body := StaticBody3D.new()
		body.name = name + "Collision"
		body.collision_layer = 1
		body.collision_mask = 0
		parent.add_child(body)
		body.owner = owner
		add_boxes(body, owner, boxes, pos, yaw, scale)
	return node


## Collision for every instance of a wall-like scatter layer, one body.
static func layer_collision(parent: Node, owner: Node, name: String, l: ScatterLayer, glb_path: String) -> void:
	var boxes := collision_boxes(glb_path)
	if boxes.is_empty() or l.count() == 0:
		return
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	body.owner = owner
	for i in l.count():
		var o := i * ScatterLayer.STRIDE
		add_boxes(body, owner, boxes, l.position_of(i), l.instances[o + 3], l.instances[o + 4])


## Estimated draw calls: the worst viewpoint over a 50 m grid of `area`,
## counting every (layer, 64 m chunk) drawn from there (near mesh within
## draw_distance, impostor out to impostor_distance), plus `nodes` (extra
## meshes: landmarks, the shimmer) within 120 m of the viewpoint.
static func estimate_draw_calls(layers: Array[ScatterLayer], area: Rect2, nodes: PackedVector3Array) -> int:
	var chunks: Array = []  # per layer: Array of chunk centres (Vector2)
	for l in layers:
		var seen := {}
		var list: Array[Vector2] = []
		for i in l.count():
			var p := l.position_of(i)
			var k := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
			if not seen.has(k):
				seen[k] = true
				list.append(Vector2((k.x + 0.5) * CHUNK, (k.y + 0.5) * CHUNK))
		chunks.append(list)
	var worst := 0
	var x := area.position.x
	while x <= area.end.x:
		var z := area.position.y
		while z <= area.end.y:
			var v := Vector2(x, z)
			var n := 0
			for li in layers.size():
				var l := layers[li]
				var far := l.impostor_distance if (l.impostor_path != "" or l.impostor_mesh != null) else 0.0
				for c: Vector2 in chunks[li]:
					var d := maxf(0.0, v.distance_to(c) - CHUNK * 0.7071)
					if d <= l.draw_distance:
						n += 1
					elif d <= far:
						n += 1
			for p in nodes:
				if v.distance_to(Vector2(p.x, p.z)) < 120.0:
					n += 1
			worst = maxi(worst, n)
			z += 50.0
		x += 50.0
	return worst


## Save layers as <dir>/<id>.tres; remove stale .tres there. Returns them
## with resource paths set, ready to be referenced by the scene.
static func save_layers(layers: Array[ScatterLayer], dir: String) -> Array[ScatterLayer]:
	DirAccess.make_dir_recursive_absolute(dir)
	var keep := {}
	for l in layers:
		keep["%s.tres" % l.id] = true
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres") and not keep.has(f):
			DirAccess.remove_absolute("%s/%s" % [dir, f])
	var out: Array[ScatterLayer] = []
	for l in layers:
		var path := "%s/%s.tres" % [dir, l.id]
		var err := ResourceSaver.save(l, path, ResourceSaver.FLAG_CHANGE_PATH)
		if err != OK:
			push_error("save %s failed: %d" % [path, err])
		l.take_over_path(path)
		out.append(l)
	return out


static func save_scene(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack %s failed: %d" % [path, err])
		return
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("save %s failed: %d" % [path, err])


static func save_region_def(id: StringName, rect: Rect2, neighbors: PackedStringArray) -> void:
	var def := RegionDef.new()
	def.id = id
	def.scene_path = "res://world/human_realm/%s/%s.tscn" % [id, id]
	var c := rect.get_center()
	def.center = Vector3(c.x, WorldHeight.height_at(c.x, c.y), c.y)
	def.radius = rect.size.length() * 0.5
	def.neighbors = neighbors
	def.report_path = "res://world/human_realm/%s/%s_report.json" % [id, id]
	DirAccess.make_dir_recursive_absolute("res://data/regions/human_realm")
	ResourceSaver.save(def, "res://data/regions/human_realm/%s.tres" % id)
