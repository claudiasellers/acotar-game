## Seated actors at the manor's long table (T039, T041): Tamlin's oversized
## head chair, Lucien's side chair and Feyre's at the far end. A seated actor
## stands on the floor at the chair's centre, faces out from the chair's back,
## and FilmPose's sit fits their legs to it. The chair stands where the house
## layout puts it and its seat is read off its mesh, so the marks and the pose
## are checked against that, not against a number copied here. Every leg bone
## is read as drawn, from skeleton_updated: outside the modification pass the
## skeleton answers with the idle pose.
## Numeric only: nothing here can say how it looks in a window.
extends GutTest

const HOUSE := "res://data/regions/spring_court/manor_estate/house/"
## How far the hips may sit from the seat centre, flat, and from the seat top, up.
const HIP_FLAT := 0.2
const HIP_UP := 0.2
## The rigid frame under each cushion: no leg passes through it.
const FRAME_TOP := {&"chair_dining": 0.49, &"chair_head_dining": 0.48}
## Thigh and shin, as thick as they're drawn, about the bone.
const THIGH_RADIUS := 0.055
const SHIN_RADIUS := 0.04
## How far a thigh may press into the cushion.
const CUSHION_GIVE := 0.04
## An ankle no higher than this, toes no lower than the floor.
const ANKLE_TOP := 0.13
const TOES_LOW := -0.005
## The most open knee: thighs slope down off these high seats, most on Feyre.
const KNEE_OPEN := 125.0
const LEGS := ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]

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


## Where the bones are as drawn, a moment after sit().
func _drawn(who: Node3D) -> Dictionary:
	var sk := FilmPose.on(who).get_skeleton()
	var at := {}
	var read := func() -> void:
		for bone: String in LEGS + ["Hips"]:
			at[bone] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
	sk.skeleton_updated.connect(read)
	await wait_seconds(0.4)
	sk.skeleton_updated.disconnect(read)
	return at


## The top of the seat under its centre, off the prop's own triangles.
func _seat_top(prop_id: StringName) -> float:
	var model := PropLib.build(prop_id)
	add_child(model)
	var top := 0.0
	var point := Vector2(0.06, 0.0)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var to_model := model.global_transform.affine_inverse() * mi.global_transform
		var faces: PackedVector3Array = mi.mesh.get_faces()
		for i in range(0, faces.size() - 2, 3):
			var a: Vector3 = to_model * faces[i]
			var b: Vector3 = to_model * faces[i + 1]
			var c: Vector3 = to_model * faces[i + 2]
			if Geometry2D.is_point_in_polygon(point, PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])):
				var plane := Plane(a, b, c)
				if absf(plane.normal.y) > 0.001:
					var y := (plane.d - plane.normal.x * point.x - plane.normal.z * point.y) / plane.normal.y
					top = maxf(top, y if y < 1.0 else 0.0)
	model.free()
	return top


func _local(world: Vector3) -> Vector3:
	return anchor.global_transform.affine_inverse() * world


## A leg point in the chair's own terms: x along the seat from its centre
## towards its front edge, y above the floor.
func _in_chair(world: Vector3, chair: Dictionary) -> Vector2:
	var p := _local(world)
	var c: Vector2 = chair["centre"]
	var face: Vector3 = chair["facing"]
	return Vector2(Vector2(p.x - c.x, p.z - c.y).dot(Vector2(face.x, face.z).normalized()), p.y)


func _check_leg(at: Dictionary, side: String, chair: Dictionary, prop_id: StringName, label: String) -> void:
	var seat: Dictionary = FilmPose.CHAIRS[prop_id]
	var front := float(seat["front"])
	var top := float(seat["top"])
	var frame := float(FRAME_TOP[prop_id])
	var hip: Vector3 = at[side + "UpperLeg"]
	var knee: Vector3 = at[side + "LowerLeg"]
	var ankle: Vector3 = at[side + "Foot"]
	var toes: Vector3 = at[side + "Toes"]
	var k := _in_chair(knee, chair)
	var a := _in_chair(ankle, chair)
	var t := _in_chair(toes, chair)
	gut.p("%s %s: hip %s knee %s ankle %s toes %s (x past chair centre, y up)" % [label, side, _in_chair(hip, chair), k, a, t])
	assert_gt(k.x, front + SHIN_RADIUS, "%s %s: knee past the seat front (%.2f)" % [label, side, front])
	assert_lt(a.y, ANKLE_TOP, "%s %s: ankle down at the floor" % [label, side])
	assert_gt(t.y, TOES_LOW, "%s %s: toes not through the floor" % [label, side])
	assert_gt(a.x, front, "%s %s: foot in front of the chair" % [label, side])
	var bend := (hip - knee).angle_to(ankle - knee)
	assert_between(rad_to_deg(bend), 80.0, KNEE_OPEN, "%s %s: knee bent about square" % [label, side])
	for i in 9:
		var along := i / 8.0
		var thigh := _in_chair(hip.lerp(knee, along), chair)
		if thigh.x < front:
			assert_gt(thigh.y - THIGH_RADIUS, frame, "%s %s: thigh above the seat frame at %.2f" % [label, side, thigh.x])
		if thigh.x < front - 0.06:
			assert_gt(thigh.y, top - CUSHION_GIVE, "%s %s: thigh on the cushion at %.2f" % [label, side, thigh.x])
		var shin := _in_chair(knee.lerp(ankle, along), chair)
		if shin.y < frame + SHIN_RADIUS:
			assert_gt(shin.x - SHIN_RADIUS, front, "%s %s: shin clear of the seat front at %.2f high" % [label, side, shin.y])


func _check(who: Node3D, chair: Dictionary, label: String, prop_id: StringName = &"chair_dining") -> void:
	assert_not_null(who, "%s is cast" % label)
	await wait_process_frames(3)
	var c: Vector2 = chair["centre"]
	var face: Vector3 = chair["facing"]
	var feet := _local(who.global_position)
	assert_lt(Vector2(feet.x, feet.z).distance_to(c), 0.15, "%s stands at the chair's centre, not behind its back" % label)
	var at: Dictionary = await _drawn(who)
	var hips := _local(at["Hips"])
	var flat := Vector2(hips.x, hips.z).distance_to(c)
	var top := _seat_top(prop_id)
	assert_almost_eq(float(FilmPose.CHAIRS[prop_id]["top"]), top, 0.01, "%s: the seat is as high as FilmPose says" % prop_id)
	assert_almost_eq(float(FilmPose.CHAIRS[prop_id]["front"]), PropLib.size_of(prop_id).z * 0.5, 0.01, "%s: its front edge is where FilmPose says" % prop_id)
	var up := hips.y - top
	gut.p("%s: hips %.2f m from the seat centre, %.2f m off the seat top (hips y %.2f)" % [label, flat, up, hips.y])
	assert_lt(flat, HIP_FLAT, "%s: hips over the seat" % label)
	assert_between(up, 0.05, HIP_UP, "%s: hips on the seat" % label)
	_check_leg(at, "Left", chair, prop_id, label)
	_check_leg(at, "Right", chair, prop_id, label)
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
	await _check(space.actor(&"tamlin"), chair, "Tamlin", &"chair_head_dining")


func test_lucien_sits_in_his_chair() -> void:
	space._set_the_scene(null)
	var chair := _chair(&"chair_dining", Vector2(-3.4, -7.6))
	await _check(space.actor(&"lucien"), chair, "Lucien")


## Feyre, the real player: her body keeps clear of the chair's collision box
## behind it, and her model sits. Up again, her model is back on her body.
func test_feyre_sits_in_her_chair() -> void:
	var real: Node3D = (load("res://characters/feyre/feyre.tscn") as PackedScene).instantiate()
	root.get_tree().get_first_node_in_group(&"player").free()
	root.add_child(real)
	if not real.is_in_group(&"player"):
		real.add_to_group(&"player")
	real.global_position = anchor.global_position + Vector3(4.95, 0.0, -6.5)
	real.set_physics_process(false)  # no floor here to stand on
	real.rotation.y = PI  # the estate spawns her turned round
	await wait_process_frames(2)
	space._set_the_scene(null)
	space._sit(null)
	var chair := _chair(&"chair_dining", Vector2(4.4, -6.5))
	var body: Node3D = real.get(&"model")
	await _check(body, chair, "Feyre")
	space._use_seat_camera(false)
	space.unseat_feyre()
	assert_eq((real.get(&"model") as Node3D).position, Vector3.ZERO, "her model is back on her body")


## Every scene seats its people on the chairs the layout has.
func test_every_seat_mark_is_on_its_chair() -> void:
	var seats := {
		"res://data/story/act2/first_dinner_stage.tres": [&"tamlin_seat", &"lucien_seat", &"feyre_seat"],
		"res://data/story/act2/manor_arrival_stage.tres": [&"tamlin_seat", &"lucien_seat"],
		"res://data/story/act5/bruise_lunch_stage.tres": [&"tamlin_seat", &"lucien_seat"],
		"res://data/story/act5/gown_dinner_stage.tres": [&"tamlin_seat", &"feyre_seat"],
	}
	var props := {&"tamlin_seat": &"chair_head_dining", &"lucien_seat": &"chair_dining", &"feyre_seat": &"chair_dining"}
	for path: String in seats:
		var stage: Act2Stage = load(path)
		for seat: StringName in seats[path]:
			var at := stage.mark(seat)
			var chair := _chair(props[seat], Vector2(at.x, at.z))
			assert_lt(Vector2(at.x, at.z).distance_to(chair["centre"]), 0.05, "%s %s on its chair" % [path, seat])
