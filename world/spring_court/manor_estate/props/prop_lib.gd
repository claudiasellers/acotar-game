## Every prop in the estate, by id. One generator for all of them, so Blender
## models can replace any id later without touching a layout.
##
## build(id) returns a Node3D whose origin is the prop's base centre, facing -Z.
## Ids missing from the catalogue build a labelled blush box and are reported by
## missing_ids() (a test keeps that list empty).
class_name PropLib
extends RefCounted

static var _mesh_cache: Dictionary = {}


static func has(id: StringName) -> bool:
	return PropCatalog.ENTRIES.has(id)


## [category, size, colour, collide] for an id.
static func entry(id: StringName) -> Array:
	return PropCatalog.ENTRIES.get(id, [&"unknown", Vector3(0.6, 0.6, 0.6), EstateKit.BLUSH, true])


static func size_of(id: StringName) -> Vector3:
	return entry(id)[1]


static func build(id: StringName) -> Node3D:
	var e := entry(id)
	var size: Vector3 = e[1]
	var root: Node3D
	if e[3]:
		var body := StaticBody3D.new()
		body.collision_layer = EstateKit.WORLD_LAYER
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		cs.position.y = size.y * 0.5
		body.add_child(cs)
		root = body
	else:
		root = Node3D.new()
	root.name = String(id)
	var shape_node := PropShapes.build(id, size, e[2])
	shape_node.name = "Look"
	root.add_child(shape_node)
	return root


## Ids used by layouts but missing from the catalogue.
static func missing_ids(ids: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids:
		if not has(id) and not out.has(String(id)):
			out.append(String(id))
	return out
