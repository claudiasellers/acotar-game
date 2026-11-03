## Where a region's loose props start (T5): one ScatterLayer per prop kind,
## layer id = PropData id, five floats per instance (x, y, z, yaw, scale) in
## world space. Written by tools/generators/gen_props.gd, read by PropField.
class_name PropPlacements
extends Resource

const DIR := "res://data/props/placements/%s.tres"
const DATA_DIR := "res://data/props/%s.tres"

@export var region_id: StringName
@export var layers: Array[ScatterLayer] = []


func count() -> int:
	var n := 0
	for l in layers:
		n += l.count()
	return n


static func for_region(id: StringName) -> PropPlacements:
	var path := DIR % id
	return load(path) as PropPlacements if ResourceLoader.exists(path) else null


static func prop_data(id: StringName) -> PropData:
	var path := DATA_DIR % id
	return load(path) as PropData if ResourceLoader.exists(path) else null
