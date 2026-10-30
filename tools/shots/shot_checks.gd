## Numeric layout checks: the answer to "is the stair where it should be?" as
## numbers instead of a picture. Each check returns {name, kind, ok, values}
## (or {.., error}). `ok` is null unless the check carries `expect`.
## Kinds and fields: docs/contracts/shot_request.md.
class_name ShotChecks
extends RefCounted


## `space` must be read during a physics frame (the runner awaits one).
static func run(check: Dictionary, root: Node, space: PhysicsDirectSpaceState3D, use_terrain: bool) -> Dictionary:
	var out := {"name": check.name, "kind": check.kind, "ok": null}
	var values := {}
	match str(check.kind):
		"position":
			var n := find(root, str(check.get("node", ""))) as Node3D
			if n == null:
				return _error(out, "node '%s' not found" % check.get("node", ""))
			values = _vec(n.global_position)
			values.rotation_y_deg = snappedf(n.global_rotation_degrees.y, 0.01)
			if use_terrain:
				var g := WorldHeight.height_at(n.global_position.x, n.global_position.z)
				values.ground = snappedf(g, 0.001)
				values.above_ground = snappedf(n.global_position.y - g, 0.001)
		"aabb":
			var n := find(root, str(check.get("node", "")))
			if n == null:
				return _error(out, "node '%s' not found" % check.get("node", ""))
			var box := global_aabb(n)
			if box.size == Vector3.ZERO:
				return _error(out, "node '%s' has no visible geometry" % check.node)
			values = _box(box)
		"overlap":
			var a := find(root, str(check.get("a", "")))
			var b := find(root, str(check.get("b", "")))
			if a == null or b == null:
				return _error(out, "node '%s' or '%s' not found" % [check.get("a", ""), check.get("b", "")])
			var ba := global_aabb(a).grow(-float(check.get("margin", 0.0)))
			var bb := global_aabb(b)
			var inter := ba.intersection(bb)
			values.overlaps = ba.intersects(bb)
			values.volume = snappedf(inter.get_volume(), 0.001)
			values.gap = snappedf(_gap(ba, bb), 0.001)
		"height":
			var at: Array = check.get("at", [0, 0])
			var x := float(at[0])
			var z := float(at[at.size() - 1])
			values.x = x
			values.z = z
			if use_terrain:
				values.terrain = snappedf(WorldHeight.height_at(x, z), 0.001)
			var hit := _ray(space, Vector3(x, 2000.0, z), Vector3(x, -2000.0, z))
			values.hit = not hit.is_empty()
			if not hit.is_empty():
				values.surface = snappedf((hit.position as Vector3).y, 0.001)
				values.collider = _node_path(root, hit.collider)
		"ray":
			var from := _v(check.get("from"))
			var to := _v(check.get("to"))
			var hit := _ray(space, from, to)
			values.hit = not hit.is_empty()
			if not hit.is_empty():
				values.merge(_vec(hit.position))
				values.distance = snappedf(from.distance_to(hit.position), 0.001)
				values.collider = _node_path(root, hit.collider)
		"count":
			var nodes := _matching(root, check)
			values.count = nodes.size()
		_:
			return _error(out, "unknown kind '%s'" % check.kind)
	out.values = values
	if check.has("expect"):
		out.ok = expect_met(values, check.expect)
	return out


## `expect` maps a value name to [min, max] or to an exact bool/number/string.
static func expect_met(values: Dictionary, expect: Variant) -> bool:
	if not expect is Dictionary:
		return false
	for key: String in expect:
		if not values.has(key):
			return false
		var want: Variant = expect[key]
		var got: Variant = values[key]
		if want is Array and (want as Array).size() == 2:
			if not (got is float or got is int) or float(got) < float(want[0]) or float(got) > float(want[1]):
				return false
		elif want is bool or want is String:
			if got != want:
				return false
		elif not is_equal_approx(float(got), float(want)):
			return false
	return true


## "group:x" (first in group), "name:X" (first descendant named X), or a node
## path from the scene root, falling back to a name search.
static func find(root: Node, ref: String) -> Node:
	if ref.begins_with("group:"):
		for n in root.get_tree().get_nodes_in_group(StringName(ref.substr(6))):
			if root == n or root.is_ancestor_of(n):
				return n
		return null
	if ref.begins_with("name:"):
		return root.find_child(ref.substr(5), true, false)
	if ref.is_empty():
		return null
	var n := root.get_node_or_null(NodePath(ref))
	return n if n != null else root.find_child(ref, true, false)


## The merged world-space bounds of every visual under `node` (itself included).
static func global_aabb(node: Node) -> AABB:
	var box := AABB()
	var first := true
	var nodes: Array[Node] = [node]
	nodes.append_array(node.find_children("*", "VisualInstance3D", true, false))
	for n in nodes:
		if not n is VisualInstance3D or not (n as VisualInstance3D).is_visible_in_tree():
			continue
		var vi := n as VisualInstance3D
		var b := vi.global_transform * vi.get_aabb()
		if b.size == Vector3.ZERO:
			continue
		box = b if first else box.merge(b)
		first = false
	return box


static func _matching(root: Node, check: Dictionary) -> Array[Node]:
	var nodes: Array[Node] = []
	if check.has("group"):
		for n in root.get_tree().get_nodes_in_group(StringName(str(check.group))):
			if root.is_ancestor_of(n) or n == root:
				nodes.append(n)
	else:
		nodes = root.find_children(str(check.get("pattern", "*")), str(check.get("type", "")), true, false)
	if check.has("center"):
		var c := _v(check.center)
		var r := float(check.get("radius", 50.0))
		nodes = nodes.filter(func(n: Node) -> bool:
			return n is Node3D and (n as Node3D).global_position.distance_to(c) <= r)
	return nodes


static func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	if space == null:
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	return space.intersect_ray(q)


static func _gap(a: AABB, b: AABB) -> float:
	var d := Vector3.ZERO
	for i in 3:
		d[i] = maxf(0.0, maxf(a.position[i] - b.end[i], b.position[i] - a.end[i]))
	return d.length()


static func _node_path(root: Node, obj: Object) -> String:
	if obj is Node and (root.is_ancestor_of(obj) or obj == root):
		return str(root.get_path_to(obj))
	return str(obj)


static func _v(a: Variant) -> Vector3:
	return ShotRequest._vec3(a, Vector3.ZERO)


static func _vec(p: Vector3) -> Dictionary:
	return {"x": snappedf(p.x, 0.001), "y": snappedf(p.y, 0.001), "z": snappedf(p.z, 0.001)}


static func _box(b: AABB) -> Dictionary:
	return {
		"min": [snappedf(b.position.x, 0.001), snappedf(b.position.y, 0.001), snappedf(b.position.z, 0.001)],
		"max": [snappedf(b.end.x, 0.001), snappedf(b.end.y, 0.001), snappedf(b.end.z, 0.001)],
		"size_x": snappedf(b.size.x, 0.001), "size_y": snappedf(b.size.y, 0.001), "size_z": snappedf(b.size.z, 0.001),
	}


static func _error(out: Dictionary, msg: String) -> Dictionary:
	out.error = msg
	out.ok = false
	return out
