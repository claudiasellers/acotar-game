## Contract (owner, T038): she walks in at the front door, and no jump, however
## many in a chain and at whatever speed, takes her out of a manor room. The walls
## hold on their own (the sweep stops her); what let her out was a ledge climb past
## the wall and the rooms under the roof having no lid. (T049) Every flight walks up
## and down the way its steps go, and is solid: she can't fall through or get inside.
extends GutTest

const SCENE := preload("res://world/spring_court/manor_estate/manor_estate.tscn")
const FEYRE := preload("res://characters/feyre/feyre.tscn")
## Room, her yaw toward a blank stretch of wall, and where she runs from.
const RUNS: Array[Array] = [
	[&"entrance_hall", PI * 0.5, Vector2(-6, -44)],
	[&"library", -PI * 0.5, Vector2(-24, -66)],
	[&"map_room", 0.0, Vector2(-33, -44)],
]

var estate: ManorEstate
var f: Feyre
var all: ManorHouseIndex


func before_all() -> void:
	PhaseManager.start(load("res://data/phases/spring_court_phases.tres"), &"p2_grounds")
	estate = SCENE.instantiate()
	estate.build_scatter = false
	estate.build_grounds = false
	add_child(estate)
	all = ManorHouseIndex.new(ManorHouseBuilder.load_layouts())
	f = FEYRE.instantiate() as Feyre
	estate.add_child(f)
	Engine.max_physics_steps_per_frame = 16
	Engine.time_scale = 8.0
	await wait_physics_frames(5)


func after_all() -> void:
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8
	estate.free()


func after_each() -> void:
	for a in [&"move_forward", &"sprint", &"jump"]:
		Input.action_release(a)


func _room(id: StringName) -> ManorRoomDef:
	for r in all.interior_rooms():
		if r.id == id:
			return r
	return null


func _face(yaw: float) -> void:
	f.nudge_camera(angle_difference(f.camera_yaw(), yaw), 0.0)
	f.model.rotation.y = yaw


func test_she_walks_in_at_the_front_door() -> void:
	var gate := estate.house.get_node("Gate_manor_house") as RegionGate
	assert_false(gate.is_locked())
	for sprint: bool in [false, true]:
		f.teleport(Vector3(0.0, WorldHeight.height_at(0.0, -16.0) + 0.4, -16.0))
		_face(0.0)
		await wait_physics_frames(5)
		Input.action_press(&"move_forward")
		if sprint:
			Input.action_press(&"sprint")
		for i in 180:
			await get_tree().physics_frame
			if f.global_position.z < -30.0:
				break
		after_each()
		assert_lt(f.global_position.z, -30.0, "through the doors, in the entrance hall (sprint %s)" % sprint)


func test_jump_chains_never_leave_the_room() -> void:
	for run: Array in RUNS:
		var r := _room(run[0])
		var y0 := ManorHouseBuilder.floor_y(r.level)
		for sprint: bool in [false, true]:
			for jumps in [2, 3]:
				var from: Vector2 = run[2]
				f.teleport(Vector3(from.x, y0 + 0.1, from.y))
				_face(run[1])
				await wait_physics_frames(2)
				Input.action_press(&"move_forward")
				if sprint:
					Input.action_press(&"sprint")
				for t in 100:
					await get_tree().physics_frame
					if t in [12, 24, 36].slice(0, jumps):
						Input.action_press(&"jump")
					else:
						Input.action_release(&"jump")
				after_each()
				var p := f.global_position
				assert_true(r.rect.has_point(Vector2(p.x, p.z)) and p.y < y0 + ManorHouseBuilder.ceiling_of(r),
						"%s: sprint %s, %d jumps, ended at %s" % [r.id, sprint, jumps, p])


func test_every_room_has_a_lid() -> void:
	await get_tree().physics_frame
	var space := f.get_world_3d().direct_space_state
	var open := PackedStringArray()
	for r in all.interior_rooms():
		if r.level < 0:
			continue
		var y0 := ManorHouseBuilder.floor_y(r.level)
		var c := r.rect.get_center()
		var top := y0 + ManorHouseBuilder.ceiling_of(r)
		# A stairwell's lid is a storey on, in the room the stairs lead to.
		var query := PhysicsRayQueryParameters3D.create(Vector3(c.x, top - 0.2, c.y),
				Vector3(c.x, top + ManorSitePlan.HOUSE_STOREY + 0.4, c.y), EstateKit.WORLD_LAYER)
		if space.intersect_ray(query).is_empty():
			open.append(String(r.id))
	assert_eq(open, PackedStringArray(), "a jump chain reaches 9 m: nothing over these rooms")


## The height of a flight's walking surface over `p`, its foot and rise (0..1 along it).
func _surface(s: ManorStairDef, p: Vector3) -> float:
	var dir := ManorHouseBuilder._dir(s.rise_toward)
	var run: float = absf(dir.dot(s.rect.size))
	var foot := s.rect.get_center() - dir * run * 0.5
	var low := ManorHouseBuilder.floor_y(s.level_from)
	var rise := ManorHouseBuilder.floor_y(s.level_from + 1) - low
	return low + rise * clampf((Vector2(p.x, p.z) - foot).dot(dir) / run, 0.0, 1.0)


## How far below the walking surface she is right now, over the flight (0 elsewhere).
func _depth(s: ManorStairDef) -> float:
	var p := f.global_position
	return maxf(_surface(s, p) - p.y, 0.0) if s.rect.has_point(Vector2(p.x, p.z)) else 0.0


## Runs from `from` facing `yaw` for `frames`, or until she is level with `to` at
## height `y`. Returns [where she ended, the deepest she got under the surface].
func _walk(s: ManorStairDef, from: Vector3, yaw: float, frames: int, to := Vector2.INF, y := 0.0) -> Array:
	f.teleport(from)
	_face(yaw)
	await wait_physics_frames(2)
	Input.action_press(&"move_forward")
	var deepest := 0.0
	for i in frames:
		await get_tree().physics_frame
		deepest = maxf(deepest, _depth(s))
		var p := f.global_position
		if to != Vector2.INF and (to - Vector2(p.x, p.z)).dot(to - Vector2(from.x, from.z)) <= 0.0 and absf(p.y - y) < 0.2:
			break
	after_each()
	return [f.global_position, deepest]


func test_every_flight_walks_up_and_down_on_its_steps() -> void:
	assert_eq(all.stairs.size(), 12)
	for s in all.stairs:
		var low := ManorHouseBuilder.floor_y(s.level_from)
		var high := ManorHouseBuilder.floor_y(s.level_from + 1)
		var dir := ManorHouseBuilder._dir(s.rise_toward)
		var yaw := atan2(-dir.x, -dir.y)
		var bottom := ManorHouseBuilder.stair_bottom(s)
		var top := ManorHouseBuilder.stair_top(s)
		var up: Array = await _walk(s, Vector3(bottom.x, low + 0.1, bottom.y), yaw, 150, top, high)
		assert_almost_eq((up[0] as Vector3).y, high, 0.3, "%s: up from the foot ends at %s" % [s.id, up[0]])
		assert_lt(up[1], 0.3, "%s: on the steps going up" % s.id)
		var down: Array = await _walk(s, Vector3(top.x, high + 0.1, top.y), yaw + PI, 150, bottom, low)
		assert_almost_eq((down[0] as Vector3).y, low, 0.3, "%s: down from the top ends at %s" % [s.id, down[0]])
		assert_lt(down[1], 0.3, "%s: on the steps going down" % s.id)


## All four ways a flight can rise: the shipped ones only go north and south.
func test_ramps_rise_the_way_their_steps_do_in_all_four_directions() -> void:
	var x := 200.0
	for toward: StringName in [&"north", &"south", &"east", &"west"]:
		x += 20.0   # apart, so each ray reads only its own flight
		var stair := ManorStairDef.new()
		stair.id = &"probe"
		stair.rect = Rect2(x, 200, 8, 8)
		stair.rise_toward = toward
		var holder := Node3D.new()
		add_child_autofree(holder)
		ManorHouseBuilder._build_stair(holder, stair)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var dir := ManorHouseBuilder._dir(toward)
		var c := stair.rect.get_center()
		var low := c - dir * 3.0
		var high := c + dir * 3.0
		var space := f.get_world_3d().direct_space_state
		var heights: Array[float] = []
		for at: Vector2 in [low, high]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
					Vector3(at.x, 100.0, at.y), Vector3(at.x, -100.0, at.y), EstateKit.WORLD_LAYER))
			heights.append(float(hit.position.y) if not hit.is_empty() else NAN)
		assert_gt(heights[1], heights[0], "%s flight: high end above its foot" % toward)


## The volume under every flight is collider, all the way along and across.
func test_every_flight_is_solid_to_the_floor() -> void:
	await get_tree().physics_frame
	var space := f.get_world_3d().direct_space_state
	for s in all.stairs:
		var dir := ManorHouseBuilder._dir(s.rise_toward)
		var side := Vector2(absf(dir.y), absf(dir.x))
		var run: float = absf(dir.dot(s.rect.size))
		var width: float = side.dot(s.rect.size)
		var low := ManorHouseBuilder.floor_y(s.level_from)
		var hollow := 0
		for a: float in [0.3, 0.5, 0.7, 0.9]:
			for b: float in [-0.4, 0.0, 0.4]:
				var at := s.rect.get_center() + dir * run * (a - 0.5) + side * width * b
				var surface := _surface(s, Vector3(at.x, 0.0, at.y))
				for h: float in [0.25, 0.6]:   # share of the way up from the floor to the surface
					var q := PhysicsPointQueryParameters3D.new()
					q.position = Vector3(at.x, lerpf(low, surface, h), at.y)
					q.collision_mask = EstateKit.WORLD_LAYER
					hollow += 1 if space.intersect_point(q, 1).is_empty() else 0
		assert_eq(hollow, 0, "%s: points inside the flight with nothing there" % s.id)


## Dropped on any flight, she lands on it and stays on top.
func test_she_lands_on_every_flight_and_never_falls_through() -> void:
	for s in all.stairs:
		var c := s.rect.get_center()
		var surface := _surface(s, Vector3(c.x, 0.0, c.y))
		f.teleport(Vector3(c.x, surface + 3.0, c.y))
		var deepest := 0.0
		for i in 50:
			await get_tree().physics_frame
			deepest = maxf(deepest, _depth(s))
		assert_lt(deepest, 0.3, "%s: fell into the flight, ended at %s" % [s.id, f.global_position])


## From the floor beside a flight and behind its high end she runs into its side.
func test_she_cant_get_in_under_a_flight() -> void:
	for id: StringName in [&"grand", &"attic", &"main_cellar"]:
		var s: ManorStairDef = all.stairs.filter(func(st: ManorStairDef) -> bool: return st.id == id)[0]
		var dir := ManorHouseBuilder._dir(s.rise_toward)
		var side := Vector2(absf(dir.y), absf(dir.x))
		var run: float = absf(dir.dot(s.rect.size))
		var width: float = side.dot(s.rect.size)
		var low := ManorHouseBuilder.floor_y(s.level_from)
		var c := s.rect.get_center()
		for way: Vector2 in [side, -side, -dir]:
			var reach: float = (width if way.dot(side) != 0.0 else run) * 0.5 + 1.0
			var at := c + dir * run * 0.25 - way * reach if way.dot(dir) == 0.0 else c - way * reach
			var r: Array = await _walk(s, Vector3(at.x, low + 0.1, at.y), atan2(-way.x, -way.y), 45)
			assert_lt(r[1], 0.3, "%s: got under it running %s, ended at %s" % [s.id, way, r[0]])
