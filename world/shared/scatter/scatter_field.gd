## Builds a region's ScatterLayers into chunked MultiMeshInstance3D nodes, so
## each chunk is culled on its own and nothing is a per-instance node (R16).
##
## Every forage chunk is a MultiMeshInstance3D in group "forage_field" with:
##   meta "ingredient_id": StringName
##   meta "scatter_id":    StringName  (the layer id)
##   meta "region_id":     StringName
##   meta "instance_ids":  PackedInt32Array, layer index of each multimesh instance
##   meta "layer":         the ScatterLayer (positions come from its data, since
##                         multimesh buffers are not readable headless)
## so the systems lane can pick instance i as WorldDeltas key "<scatter_id>:<instance_ids[i]>",
## find it with ScatterField.instance_position(chunk, i), and hide it with
## ScatterField.set_instance_hidden(chunk, i, true).
class_name ScatterField
extends Node3D

const FORAGE_GROUP := &"forage_field"

@export var region_id: StringName
@export var layers: Array[ScatterLayer] = []
@export var chunk_size := 64.0


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		child.free()
	for layer in layers:
		if layer != null and layer.count() > 0 and layer.resolve_mesh() != null:
			_build_layer(layer)


func chunk_key(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))


func forage_chunks() -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for child in get_children():
		if child is MultiMeshInstance3D and child.is_in_group(FORAGE_GROUP):
			out.append(child)
	return out


## World position of multimesh instance `i` of a forage chunk.
static func instance_position(chunk: MultiMeshInstance3D, i: int) -> Vector3:
	var layer: ScatterLayer = chunk.get_meta(&"layer")
	var ids: PackedInt32Array = chunk.get_meta(&"instance_ids")
	return layer.position_of(ids[i])


## Hide (picked) or restore (respawned) one instance by collapsing its scale.
static func set_instance_hidden(chunk: MultiMeshInstance3D, i: int, hidden: bool) -> void:
	var layer: ScatterLayer = chunk.get_meta(&"layer")
	var ids: PackedInt32Array = chunk.get_meta(&"instance_ids")
	var t := layer.transform_of(ids[i])
	t.origin -= chunk.position
	if hidden:
		t = t.scaled_local(Vector3.ZERO)
	chunk.multimesh.set_instance_transform(i, t)


func _build_layer(layer: ScatterLayer) -> void:
	var buckets := {}
	for i in layer.count():
		var key := chunk_key(layer.position_of(i))
		if not buckets.has(key):
			buckets[key] = PackedInt32Array()
		buckets[key].append(i)
	for key: Vector2i in buckets:
		var ids: PackedInt32Array = buckets[key]
		var origin := Vector3((key.x + 0.5) * chunk_size, 0.0, (key.y + 0.5) * chunk_size)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = layer.mesh
		mm.instance_count = ids.size()
		for j in ids.size():
			var t := layer.transform_of(ids[j])
			t.origin -= origin
			mm.set_instance_transform(j, t)
		var node := _make_instance(layer, "%s_%d_%d" % [layer.id, key.x, key.y], mm, origin)
		node.visibility_range_end = layer.draw_distance
		node.visibility_range_end_margin = 8.0
		if layer.is_forage():
			node.add_to_group(FORAGE_GROUP)
			node.set_meta(&"ingredient_id", layer.ingredient_id)
			node.set_meta(&"scatter_id", layer.id)
			node.set_meta(&"region_id", region_id)
			node.set_meta(&"instance_ids", ids)
			node.set_meta(&"layer", layer)
		if layer.resolve_impostor() != null:
			var far_mm := MultiMesh.new()
			far_mm.transform_format = MultiMesh.TRANSFORM_3D
			far_mm.mesh = layer.impostor_mesh
			far_mm.instance_count = ids.size()
			for j in ids.size():
				far_mm.set_instance_transform(j, mm.get_instance_transform(j))
			var far := _make_instance(layer, "%s_%d_%d_far" % [layer.id, key.x, key.y], far_mm, origin)
			far.visibility_range_begin = layer.draw_distance
			far.visibility_range_begin_margin = 8.0
			far.visibility_range_end = layer.impostor_distance
			far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_instance(layer: ScatterLayer, node_name: String, mm: MultiMesh, origin: Vector3) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.position = origin
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if layer.cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if layer.material != null:
		node.material_override = layer.material
	add_child(node)
	return node
