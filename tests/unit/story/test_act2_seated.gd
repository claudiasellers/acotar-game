## Seated actors at the manor's long table (T039): Tamlin's oversized head
## chair and Lucien's side chair. A seated actor stands on the floor at the
## chair's centre, faces out from the chair's back, and FilmPose's sit drops
## the hips onto the seat. The chair stands where the house layout puts it, so
## the marks are checked against that data, not against a number copied here.
## Numeric only: nothing here can say how it looks in a window.
extends GutTest

const HOUSE := "res://data/regions/spring_court/manor_estate/house/"
## How far the hips may sit from the seat centre, flat, and from the seat top, up.
const HIP_FLAT := 0.2
const HIP_UP := 0.2
## The seat top of the head chair (its cushion in tools/blender/manor_props_furnish.py).
const SEAT_TOP := 0.56

var root: Node3D
var anchor: Marker3D
var space: FirstDinner


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	root = Node3D.new()
	add_child_autofree(root)
	var feyre := Node3D.new()
	feyre.add_to_group(&"player")
	root.add_child(feyre)
	anchor = Marker3D.new()
	anchor.name = "manor_dining_table"
	anchor.add_to_group(&"story_anchor")
	anchor.position = _layout_anchor(&"manor_dining_table")
	root.add_child(anchor)
	StoryDirector.attach_anchor(anchor)
	space = anchor.get_node(^"Moment_first_dinner") as FirstDinner
	space.auto_tick = false


func after_each() -> void:
	StoryControl.release()


func _layout_anchor(id: StringName) -> Vector3:
	for l in ManorHouseBuilder.load_layouts():
		for a in l.anchors:
			if a.anchor_id == id:
				return a.position
	return Vector3.ZERO


## The chair `prop_id` nearest `near` (anchor-local XZ): its centre and the
## direction it faces, both anchor-local.
func _chair(prop_id: StringName, near: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	var base := _layout_anchor(&"manor_dining_table")
	for l in ManorHouseBuilder.load_layouts():
		for room in l.rooms:
			for p in room.props:
				if p.prop_id != prop_id:
					continue
				var c := Vector2(room.rect.position.x + p.position.x - base.x, room.rect.position.y + p.position.z - base.z)
				if c.distance_to(near) < best_d:
					best_d = c.distance_to(near)
					best = {"centre": c, "yaw": p.yaw_deg}
	assert_lt(best_d, 1.0, "%s stands near %s" % [prop_id, near])
	# the model's back rest is its tall side: it faces away from that
	var model := PropLib.build(prop_id)
	var tall := Vector3.ZERO
	var n := 0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				if v.y > 1.0:
					tall += v
					n += 1
	assert_gt(n, 0, "%s has a back rest" % prop_id)
	var back := Vector3(tall.x, 0.0, tall.z).normalized() if n > 0 else Vector3.BACK
	best["facing"] = Basis(Vector3.UP, deg_to_rad(float(best["yaw"]))) * -back
	model.free()
	return best


func _hips(who: Node3D) -> Vector3:
	var fp := FilmPose.on(who)
	assert_true(fp.has_hips, "the sit pose has drawn the hips")
	return fp.get_skeleton().global_transform * fp.hips_local


func _local(world: Vector3) -> Vector3:
	return anchor.global_transform.affine_inverse() * world


func _check(who: Node3D, chair: Dictionary, label: String) -> void:
	assert_not_null(who, "%s is cast" % label)
	await wait_process_frames(3)
	var c: Vector2 = chair["centre"]
	var face: Vector3 = chair["facing"]
	var feet := _local(who.global_position)
	assert_lt(Vector2(feet.x, feet.z).distance_to(c), 0.15, "%s stands at the chair's centre, not behind its back" % label)
	var hips := _local(_hips(who))
	var flat := Vector2(hips.x, hips.z).distance_to(c)
	var up := hips.y - SEAT_TOP
	gut.p("%s: hips %.2f m from the seat centre, %.2f m off the seat top (hips y %.2f)" % [label, flat, up, hips.y])
	assert_lt(flat, HIP_FLAT, "%s: hips over the seat" % label)
	assert_lt(absf(up), HIP_UP, "%s: hips on the seat" % label)
	var out := -who.global_basis.z
	out = anchor.global_basis.inverse() * out
	gut.p("%s faces %s, the chair faces %s" % [label, out, face])
	assert_gt(Vector2(out.x, out.z).normalized().dot(Vector2(face.x, face.z)), 0.9, "%s faces out from the chair back" % label)
	# the pose swings the thighs along the skeleton's +Z: that must be out from the back too
	var knees := anchor.global_basis.inverse() * FilmPose.on(who).get_skeleton().global_basis.z
	gut.p("%s: thighs point %s" % [label, knees])
	assert_gt(Vector2(knees.x, knees.z).normalized().dot(Vector2(face.x, face.z)), 0.9, "%s: thighs run out over the seat front" % label)


func test_tamlin_sits_in_the_head_chair() -> void:
	space._set_the_scene(null)
	var chair := _chair(&"chair_head_dining", Vector2(-4.4, -6.5))
	await _check(space.actor(&"tamlin"), chair, "Tamlin")


func test_lucien_sits_in_his_chair() -> void:
	space._set_the_scene(null)
	var chair := _chair(&"chair_dining", Vector2(-3.4, -7.6))
	await _check(space.actor(&"lucien"), chair, "Lucien")
