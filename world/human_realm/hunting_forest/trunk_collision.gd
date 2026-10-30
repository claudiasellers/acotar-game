## Trunk collision for scatter trees: one StaticBody3D (collision layer 1)
## per 64 m chunk, holding a CollisionShape3D cylinder per tree, built at
## load from the tree ScatterLayers so nothing per-tree is saved in the scene.
## `radii` and `heights` give each layer's trunk at scale 1 (same order as
## `layers`); shapes are shared per layer and 0.1 scale step.
class_name ForestTrunkCollision
extends Node3D

@export var layers: Array[ScatterLayer] = []
@export var radii: PackedFloat32Array = []
@export var heights: PackedFloat32Array = []
@export var chunk_size := 64.0

var _shapes := {}


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		child.free()
	var bodies := {}
	for li in layers.size():
		var layer := layers[li]
		if layer == null:
			continue
		var r := radii[li] if li < radii.size() else 0.3
		var h := heights[li] if li < heights.size() else 4.0
		for i in layer.count():
			var o := i * ScatterLayer.STRIDE
			var pos := layer.position_of(i)
			var s := snappedf(layer.instances[o + 4], 0.1)
			var key := Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))
			var body: StaticBody3D = bodies.get(key)
			if body == null:
				body = StaticBody3D.new()
				body.name = "Trunks_%d_%d" % [key.x, key.y]
				body.collision_layer = 1
				body.collision_mask = 0
				body.position = Vector3((key.x + 0.5) * chunk_size, 0.0, (key.y + 0.5) * chunk_size)
				add_child(body)
				bodies[key] = body
			var cs := CollisionShape3D.new()
			cs.shape = _shape(li, r * s, h * s)
			cs.position = pos - body.position + Vector3(0.0, h * s * 0.5, 0.0)
			body.add_child(cs)


func body_count() -> int:
	return get_child_count()


func shape_count() -> int:
	var n := 0
	for b in get_children():
		n += b.get_child_count()
	return n


func _shape(li: int, radius: float, height: float) -> CylinderShape3D:
	var k := Vector3i(li, roundi(radius * 100.0), roundi(height * 10.0))
	if not _shapes.has(k):
		var c := CylinderShape3D.new()
		c.radius = maxf(radius, 0.05)
		c.height = maxf(height, 0.5)
		_shapes[k] = c
	return _shapes[k]
