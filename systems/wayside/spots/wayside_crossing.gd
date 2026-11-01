## A shortcut over water or a gap [X; Tamlin "hopped over tiny brooks", and
## one ch 14 stream takes "a running leap"]: stepping stones, a fallen oak or
## a small footbridge from `position` to `target`, with world collision
## (layer 1) so she can run straight over. The first crossing says a line.
class_name WaysideCrossing
extends WaysideSpotNode

var piece: StringName
var bodies: Array[StaticBody3D] = []
var _was_near_start := false


func build() -> void:
	piece = StringName(spot.param("model", "stepping_stones"))
	var span := spot.target - spot.position
	var flat := Vector2(span.x, span.z)
	var yaw := atan2(span.x, span.z)
	var length := flat.length()
	var unit := float(spot.param("unit_length", 4.0))
	var count := maxi(1, ceili(length / unit)) if spot.param("repeat", true) else 1
	for i in count:
		var t := (float(i) + 0.5) / count
		var at := span * t
		at.y = maxf(ground(spot.position.x + at.x, spot.position.z + at.z), float(spot.param("water_y", -INF))) - spot.position.y
		var mi := add_model(piece, at, yaw + float(spot.param("yaw_offset", 0.0)), float(spot.param("scale", 1.0)))
		if mi == null:
			continue
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = mi.mesh.create_trimesh_shape()
		body.add_child(shape)
		body.transform = mi.transform
		add_child(body)
		bodies.append(body)


func _process(_delta: float) -> void:
	if found():
		set_process(false)
		return
	var p := player()
	if p == null:
		return
	var a := Vector2(spot.position.x, spot.position.z)
	var b := Vector2(spot.target.x, spot.target.z)
	var q := Vector2(p.global_position.x, p.global_position.z)
	if q.distance_to(a) < 4.0:
		_was_near_start = true
	elif _was_near_start and q.distance_to(b) < 4.0:
		complete()
