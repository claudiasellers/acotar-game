## A ScatterField that builds one chunk per call instead of everything in
## _ready, from instance buffers prepared on a worker thread, so a region
## streams in under FrameBudget. Chunks keep the contract's forage metas
## (docs/contracts/world.md §4) and ScatterField's static helpers still work.
class_name SlicedScatterField
extends ScatterField

const FLOATS := 12


func _ready() -> void:
	pass  # Built chunk by chunk through add_chunk().


## Instance buffers for a layer, grouped by chunk (pure data, thread-safe):
## Array of [key: Vector2i, ids: PackedInt32Array, buffer: PackedFloat32Array].
static func prepare(layer: ScatterLayer, size: float) -> Array:
	var buckets := {}
	for i in layer.count():
		var o := i * ScatterLayer.STRIDE
		var key := Vector2i(floori(layer.instances[o] / size), floori(layer.instances[o + 2] / size))
		if not buckets.has(key):
			buckets[key] = PackedInt32Array()
		buckets[key].append(i)
	var out := []
	var keys := buckets.keys()
	keys.sort()
	for key: Vector2i in keys:
		var ids: PackedInt32Array = buckets[key]
		var origin := Vector3((key.x + 0.5) * size, 0.0, (key.y + 0.5) * size)
		out.append([key, ids, transforms_buffer(layer.instances, ids, origin)])
	return out


## MultiMesh TRANSFORM_3D buffer (3x4 row-major per instance) for the given
## instances of a 5-float x, y, z, yaw, scale array, relative to `origin`.
static func transforms_buffer(instances: PackedFloat32Array, ids: PackedInt32Array, origin: Vector3) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(ids.size() * FLOATS)
	for j in ids.size():
		var o := ids[j] * ScatterLayer.STRIDE
		var s := instances[o + 4]
		var c := cos(instances[o + 3]) * s
		var sn := sin(instances[o + 3]) * s
		var b := j * FLOATS
		buf[b] = c
		buf[b + 1] = 0.0
		buf[b + 2] = sn
		buf[b + 3] = instances[o] - origin.x
		buf[b + 4] = 0.0
		buf[b + 5] = s
		buf[b + 6] = 0.0
		buf[b + 7] = instances[o + 1] - origin.y
		buf[b + 8] = -sn
		buf[b + 9] = 0.0
		buf[b + 10] = c
		buf[b + 11] = instances[o + 2] - origin.z
	return buf


## Builds one chunk of `layer` (and its impostor chunk) from prepared data.
func add_chunk(layer: ScatterLayer, key: Vector2i, ids: PackedInt32Array, buffer: PackedFloat32Array) -> void:
	var origin := Vector3((key.x + 0.5) * chunk_size, 0.0, (key.y + 0.5) * chunk_size)
	var node := _make_instance(layer, "%s_%d_%d" % [layer.id, key.x, key.y], _multimesh(layer.mesh, ids.size(), buffer), origin)
	node.visibility_range_end = layer.draw_distance
	node.visibility_range_end_margin = 8.0
	if layer.is_forage():
		node.add_to_group(FORAGE_GROUP)
		node.set_meta(&"ingredient_id", layer.ingredient_id)
		node.set_meta(&"scatter_id", layer.id)
		node.set_meta(&"region_id", region_id)
		node.set_meta(&"instance_ids", ids)
		node.set_meta(&"layer", layer)
	if layer.impostor_mesh != null:
		var far := _make_instance(layer, "%s_%d_%d_far" % [layer.id, key.x, key.y], _multimesh(layer.impostor_mesh, ids.size(), buffer), origin)
		far.visibility_range_begin = layer.draw_distance
		far.visibility_range_begin_margin = 8.0
		far.visibility_range_end = layer.impostor_distance
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _multimesh(mesh: Mesh, count: int, buffer: PackedFloat32Array) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.buffer = buffer
	return mm
