# gate: when:story/*,data/story/*,data/regions/spring_court/manor_estate/house/*,world/spring_court/manor_estate/props/*,world/spring_court/manor_estate/house/*,characters/*/model/*,characters/*/*_model.tscn,characters/feyre/feyre.tscn,project.godot
## Every place the manor's scenes and films put someone (T062). A seat stands on a
## chair FilmPose can fit; anyone else stands clear of the furniture, and a thing set
## on a table is over one. Read off the stage data, the films' own constants and the
## house layout, so nothing here is a number copied from them.
## Numeric only: nothing here can say how it looks in a window.
extends GutTest

const FILMS := ["res://story/film/cutscenes/night_court.gd", "res://story/film/cutscenes/silent_manor.gd"]
## Where a seat mark may be from its chair's centre.
const ON_CHAIR := 0.05
## Lower than this a mark is someone's feet; higher, a thing on a surface, up to SET_TOP.
const FEET_TOP := 0.3
const SET_TOP := 1.2
## How far a thing may float over the surface under it, or sink into it.
const SET_GIVE := 0.12
## Low props nobody can stand in.
const UNDERFOOT := ["rug_large", "rug_runner", "rug_round", "stone_steps"]
## Marks nobody is put on: "stage:mark", or ":mark" in any stage.
const LOOKED_AT := {
	":table": "where they look",
	":lucien_face": "where he looks",
	":seat_camera": "her camera",
	":seat_look": "her camera",
	"gown_dinner_stage:tamlin_close": "the table has shrunk by then",
	"gown_dinner_stage:feyre_close": "the table has shrunk by then",
	"gown_dinner_stage:view": "relative to the easel, not this anchor",
	"bruise_vanity_stage:vanity": "where the scene waits for her, nobody stands on it",
}
## Who sits how on what, as the scenes do it.
const SEATINGS := [["tamlin", &"sit", &"chair_head_dining"], ["tamlin", &"sit_slouch", &"chair_head_dining"],
	["lucien", &"sit", &"chair_dining"], ["feyre", &"sit", &"chair_dining"], ["feyre", &"sit", &"chair_simple"]]
## An ankle no higher than this.
const FOOT_TOP := 0.16
## A knee, as thick as it's drawn.
const KNEE_RADIUS := 0.05
## Marks that want a staged moment changed to move: waiting on the owner (T062).
const UNSETTLED := {
	"lunch_table_stage:tamlin_chair": "standing 4.5 m from his chair",
	"lunch_table_stage:lucien_chair": "standing in the table",
	"lunch_table_stage:feyre_chair": "standing in the table",
	"night_court:DRAPE": "the curtain beat stands her in the window seat's end",
}
const BONES := ["Hips", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]


## The floor's collision furniture on `level`, as footprints in the house frame.
func _furniture(level: int) -> Array:
	var out: Array = []
	for l in ManorHouseBuilder.load_layouts():
		for room in l.rooms:
			if room.level != level:
				continue
			for p in room.props:
				var size := PropLib.size_of(p.prop_id) * p.scale
				if not PropLib.entry(p.prop_id)[3] or p.position.y > FEET_TOP or UNDERFOOT.has(String(p.prop_id)):
					continue
				out.append({"id": p.prop_id, "room": room.id, "size": size,
					"centre": Vector2(room.rect.position.x + p.position.x, room.rect.position.y + p.position.z),
					"yaw": deg_to_rad(p.yaw_deg)})
	return out


## `at` in `prop`'s own axes, from its centre.
func _in_prop(prop: Dictionary, at: Vector2) -> Vector2:
	var d: Vector2 = at - prop["centre"]
	var yaw := float(prop["yaw"])
	return Vector2(d.x * cos(yaw) - d.y * sin(yaw), d.x * sin(yaw) + d.y * cos(yaw))


func _inside(prop: Dictionary, at: Vector2) -> bool:
	var size: Vector3 = prop["size"]
	var p := _in_prop(prop, at)
	return absf(p.x) < size.x * 0.5 and absf(p.y) < size.z * 0.5


## Stage path -> the house anchor it hangs on, for every scene hung in the house.
func _stages() -> Dictionary:
	var anchors := {}
	for l in ManorHouseBuilder.load_layouts():
		for a in l.anchors:
			anchors[a.anchor_id] = a
	var out := {}
	for id: StringName in Act2Spaces.EXTRA:
		for spec: Dictionary in Act2Spaces.EXTRA[id]:
			if anchors.has(id):
				out[String(spec["stage"])] = anchors[id]
	for id: StringName in Act6Spaces.ROWS:
		for spec: Dictionary in Act6Spaces.ROWS[id]:
			if anchors.has(id):
				out[Act6Spaces.STAGES + String(spec["stage"])] = anchors[id]
	for id: StringName in Act2Spaces.CODED:
		var moment := load("res://data/story/moments/%s.tres" % id) as StoryMoment
		if moment and anchors.has(moment.anchor_id):
			out[String(Act2Spaces.CODED[id]["stage"])] = anchors[moment.anchor_id]
	return out


## [label, name, house point, level, the chair a film brings for it] for every
## mark and film constant.
func _points() -> Array:
	var out: Array = []
	var stages := _stages()
	for path: String in stages:
		var anchor = stages[path]
		var stage := load(path) as Act2Stage
		for m: StringName in stage.marks:
			var local: Vector3 = stage.marks[m]
			var at: Vector3 = anchor.position + Basis(Vector3.UP, deg_to_rad(anchor.yaw_deg)) * local
			out.append([path.get_file().get_basename(), String(m), Vector3(at.x, local.y, at.z), anchor.level, &""])
	for path: String in FILMS:
		var constants := (load(path) as Script).get_script_constant_map()
		for c: String in constants:
			if constants[c] is Vector3:
				var brought: StringName = constants.get("CHAIR", &"") if c.ends_with("_SIT") else &""
				out.append([path.get_file().get_basename(), c, constants[c], 0, brought])
	return out


## The floor mark's name says what it is: a seat, or feet.
func _is_seat(mark_name: String) -> bool:
	return mark_name.to_lower().ends_with("_seat") or mark_name.ends_with("_SIT")


func _name(pt: Array) -> String:
	return "%s %s %s" % [pt[0], pt[1], pt[2]]


func _skipped(pt: Array) -> bool:
	var mark_id := "%s:%s" % [pt[0], pt[1]]
	return LOOKED_AT.has(mark_id) or LOOKED_AT.has(":%s" % pt[1]) or UNSETTLED.has(mark_id)


func _figure(id: String) -> Node3D:
	if id == "feyre":
		var real := (load("res://characters/feyre/feyre.tscn") as PackedScene).instantiate() as Node3D
		add_child_autofree(real)
		real.set_physics_process(false)  # no floor here to stand on
		return real.get(&"model") as Node3D
	var model := (load("res://characters/%s/%s_model.tscn" % [id, id]) as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	return model


## Where the bones are as drawn, on a figure at the origin looking down +Z.
func _drawn(figure: Node3D) -> Dictionary:
	figure.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var sk := FilmPose.on(figure).get_skeleton()
	var at := {}
	var read := func() -> void:
		for bone: String in BONES:
			var i := sk.find_bone(bone)
			if i >= 0:
				at[bone] = sk.global_transform * sk.get_bone_global_pose(i).origin
	sk.skeleton_updated.connect(read)
	await wait_process_frames(6)
	sk.skeleton_updated.disconnect(read)
	return at


func test_every_seat_is_on_a_chair_its_pose_can_fit() -> void:
	var furniture := {0: _furniture(0), 1: _furniture(1), 2: _furniture(2)}
	var seats := 0
	for pt: Array in _points():
		if not _is_seat(pt[1]):
			continue
		seats += 1
		var at := Vector2(pt[2].x, pt[2].z)
		if pt[4] != &"":
			assert_true(FilmPose.CHAIRS.has(pt[4]), "%s: FilmPose knows %s" % [_name(pt), pt[4]])
			for f: Dictionary in furniture[pt[3]]:
				assert_false(_inside(f, at), "%s: its chair clear of %s at %s" % [_name(pt), f["id"], f["centre"]])
			continue
		var chair := {}
		for f: Dictionary in furniture[pt[3]]:
			if (f["centre"] as Vector2).distance_to(at) <= ON_CHAIR:
				chair = f
		var nearest := ""
		if chair.is_empty():
			for f: Dictionary in furniture[pt[3]]:
				if String(f["id"]).contains("chair") and (f["centre"] as Vector2).distance_to(at) < 1.0:
					nearest = " (%s at %s is %.2f m off)" % [f["id"], f["centre"], (f["centre"] as Vector2).distance_to(at)]
		assert_false(chair.is_empty(), "%s: on a chair%s" % [_name(pt), nearest])
		if not chair.is_empty():
			assert_true(FilmPose.CHAIRS.has(chair["id"]), "%s: FilmPose knows %s" % [_name(pt), chair["id"]])
	assert_gt(seats, 10, "the seats were found")


func test_nobody_stands_in_the_furniture() -> void:
	var furniture := {0: _furniture(0), 1: _furniture(1), 2: _furniture(2)}
	for pt: Array in _points():
		if _is_seat(pt[1]) or _skipped(pt) or pt[2].y > FEET_TOP:
			continue
		var at := Vector2(pt[2].x, pt[2].z)
		for f: Dictionary in furniture[pt[3]]:
			assert_false(_inside(f, at), "%s: clear of %s at %s" % [_name(pt), f["id"], f["centre"]])


func test_what_is_set_down_rests_on_something() -> void:
	var furniture := {0: _furniture(0), 1: _furniture(1), 2: _furniture(2)}
	for pt: Array in _points():
		if _skipped(pt) or pt[2].y <= FEET_TOP or pt[2].y >= SET_TOP:
			continue
		var at := Vector2(pt[2].x, pt[2].z)
		var under := false
		for f: Dictionary in furniture[pt[3]]:
			if _inside(f, at) and absf((f["size"] as Vector3).y - pt[2].y) <= SET_GIVE:
				under = true
		if not under:
			for f: Dictionary in furniture[pt[3]]:
				if (f["centre"] as Vector2).distance_to(at) < 2.0:
					gut.p("near %s: %s at %s, %.2f high" % [_name(pt), f["id"], f["centre"], (f["size"] as Vector3).y])
		assert_true(under, "%s: over a surface at that height" % _name(pt))


## How high each chair's seat is and how far its front, off its own mesh: the
## numbers FilmPose fits to.
func test_filmpose_knows_its_chairs_as_built() -> void:
	for id: StringName in FilmPose.CHAIRS:
		var model := PropLib.build(id)
		add_child_autofree(model)
		var top := 0.0
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var to_model := model.global_transform.affine_inverse() * mi.global_transform
			var faces: PackedVector3Array = mi.mesh.get_faces()
			for i in range(0, faces.size() - 2, 3):
				var a: Vector3 = to_model * faces[i]
				var b: Vector3 = to_model * faces[i + 1]
				var c: Vector3 = to_model * faces[i + 2]
				if Geometry2D.is_point_in_polygon(Vector2(0.06, 0.0), PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])):
					var plane := Plane(a, b, c)
					if absf(plane.normal.y) > 0.001:
						var y := (plane.d - plane.normal.x * 0.06) / plane.normal.y
						top = maxf(top, y if y < 1.0 else 0.0)
		assert_almost_eq(float(FilmPose.CHAIRS[id]["top"]), top, 0.01, "%s: the seat is as high as FilmPose says" % id)
		assert_almost_eq(float(FilmPose.CHAIRS[id]["front"]), PropLib.size_of(id).z * 0.5, 0.01, "%s: the front edge is where FilmPose says" % id)


## Each seat as the scenes use it: hips on the cushion, not under it, and feet
## on the floor. The fit leans on the figure's own legs, so these are the real ones.
func test_seated_figures_rest_on_their_chairs() -> void:
	for case: Array in SEATINGS:
		var who := _figure(case[0])
		await wait_process_frames(4)
		var fp := FilmPose.on(who)
		fp.to(case[1], 0.0, case[2])
		var at: Dictionary = await _drawn(who)
		var top := float(FilmPose.CHAIRS[case[2]]["top"])
		var hips: Vector3 = at["Hips"]
		var label := "%s %s on %s" % case
		gut.p("%s: hips %.3f over the cushion, %.3f ahead of the centre; feet L %.3f R %.3f" % [label, hips.y - top, hips.z,
			(at["LeftFoot"] as Vector3).y, (at["RightFoot"] as Vector3).y])
		assert_between(hips.y - top, 0.05, 0.2, "%s: hips on the seat" % label)
		assert_lt((at["LeftFoot"] as Vector3).y, FOOT_TOP, "%s: left foot down" % label)
		assert_lt((at["RightFoot"] as Vector3).y, FOOT_TOP, "%s: right foot down" % label)
		assert_gt((at["RightFoot"] as Vector3).y, 0.0, "%s: right foot not through the floor" % label)


## A side chair stands 0.3 m from the table's edge, so the knees go under: they
## must fit below its apron and slab.
func test_knees_go_under_the_long_table() -> void:
	var table := PropLib.size_of(&"table_dining_long")
	var gap := 1.1 - table.z * 0.5   # the side chairs stand 1.1 m off the table's centre line
	var apron_edge := gap + table.z * 0.05
	for id: String in ["tamlin", "lucien", "feyre"]:
		var who := _figure(id)
		await wait_process_frames(4)
		FilmPose.on(who).to(&"sit", 0.0, &"chair_dining")
		var at: Dictionary = await _drawn(who)
		for side: String in ["Left", "Right"]:
			var knee: Vector3 = at[side + "LowerLeg"]
			gut.p("%s %s knee: %.3f ahead (table edge %.2f, apron %.2f), %.3f up" % [id, side, knee.z, gap, apron_edge, knee.y])
			if knee.z + KNEE_RADIUS > gap:
				assert_lt(knee.y + KNEE_RADIUS, table.y - 0.06, "%s %s knee under the slab" % [id, side])
			if knee.z + KNEE_RADIUS > apron_edge:
				assert_lt(knee.y + KNEE_RADIUS, table.y - 0.15, "%s %s knee under the apron" % [id, side])
