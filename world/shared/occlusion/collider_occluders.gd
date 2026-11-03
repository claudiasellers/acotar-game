## Builds an occluder from the box colliders of solid buildings under
## `source` (program T1), once, when the region enters the tree. A shape counts
## when its own name or its body's name starts with one of `prefixes`. Each box
## is shrunk (footprint by `shrink`, height to `wall_fraction` of the bottom) so
## the occluder stays inside what is drawn: a gable roof's empty corners never
## hide what is behind them.
class_name ColliderOccluders
extends Node3D

@export var source: NodePath = ^"../Collision"
@export var prefixes: PackedStringArray = []
## Names starting with one of these never count (e.g. "mill_wheel" under "mill").
@export var exclude: PackedStringArray = []
@export var shrink: float = 0.9
@export var wall_fraction: float = 0.5

var boxes: int = 0


func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	var src := get_node_or_null(source) as Node3D
	if src == null:
		return
	var mesh := OccluderMesh.new()
	for n in src.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		var box := cs.shape as BoxShape3D
		if box == null or not _matches(cs):
			continue
		var size := Vector3(box.size.x * shrink, box.size.y * wall_fraction, box.size.z * shrink)
		# Keep the bottom: move the centre down by the height removed.
		var xf := global_transform.affine_inverse() * cs.global_transform
		xf.origin -= xf.basis.y.normalized() * (box.size.y - size.y) * 0.5
		if mesh.add_box(xf, size):
			boxes += 1
	mesh.build(self, "Occluder")


func _matches(cs: CollisionShape3D) -> bool:
	var body := cs.get_parent()
	var names: Array[String] = [String(cs.name), String(body.name) if body != null else ""]
	for e in exclude:
		if names[0].begins_with(e) or names[1].begins_with(e):
			return false
	for p in prefixes:
		if names[0].begins_with(p) or names[1].begins_with(p):
			return true
	return false
