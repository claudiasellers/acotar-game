## Headless touch test for the touchable world (T5). Builds a small yard,
## then plays each check the way a player would and prints one line per check:
##   push   - walk a body into a crate: it moves >= 0.5 m
##   throw  - pick up a pot and toss it: it lands >= 3 m away
##   route  - build the real manor house, bake its navmesh and send a wolf from
##            the entrance hall down the east corridor: it arrives, and walks no more
##            than 1.5x the straight line plus the door detour of the nav path
##   fire   - stream in Blossom Vale, register its grass (TouchWorld), shoot a
##            fire arrow at a clump in a meadow: it spreads beyond the first
##            cells within 3 s
##   scorch - the burnt squares' clumps are hidden and scorch decals lie there;
##            after REGROW_HOURS in-game hours they grow back
##   wet    - a frost arrow soaks another meadow: it will not light; unloading
##            the region frees every ground cell
##   tools/mq/godot.sh res://tools/playtest/touch_test.tscn
## (a scene, not -s, so the autoloads the manor builder needs are loaded)
## Passes when the log ends "TOUCH exit 0".
extends Node

const FIRE_REGION := "res://world/spring_court/blossom_vale/blossom_vale.tscn"

var _root: Node3D
var _results: Array[String] = []
var _failed := 0


func _ready() -> void:
	_root = Node3D.new()
	_root.name = "TouchYard"
	add_child(_root)
	_floor(Vector3(0, -0.5, 0), Vector3(120, 1, 120))
	_run.call_deferred()


func _run() -> void:
	await _check_push()
	await _check_throw()
	await _check_route()
	await _check_fire()
	for line in _results:
		print(line)
	print("TOUCH exit %d" % _failed)
	get_tree().quit(_failed)


func _check_push() -> void:
	var crate := _prop(&"crate", Vector3(0, 0, -1.2))
	var walker := _walker(Vector3.ZERO)
	await _physics(10)
	var start := crate.global_position
	# Walk forward (-Z) at her run pace for 1.5 s; the carrier shoves what she hits.
	for i in 90:
		walker.velocity = Vector3(0, -1, -5.0)
		walker.move_and_slide()
		await get_tree().physics_frame
	var moved := Vector2(crate.global_position.x - start.x, crate.global_position.z - start.z).length()
	_record("push", moved >= 0.5, "crate moved %.2f m" % moved)
	walker.queue_free()
	crate.queue_free()


func _check_throw() -> void:
	var walker := _walker(Vector3(20, 0, 0))
	var pot := _prop(&"pot_glazed", Vector3(20, 0, -0.9))
	await _physics(10)
	pot.use(walker)
	await _physics(20)
	var carrier := PropCarrier.for_body(walker)
	var from := walker.global_position
	carrier.throw()
	await _physics(150)
	var flat := Vector2(pot.global_position.x - from.x, pot.global_position.z - from.z).length()
	var resting := pot.linear_velocity.length() < 0.5
	_record("throw", flat >= 3.0 and resting, "pot landed %.2f m away" % flat)


## House-space spots on the ground floor (the p3 house playtest walks these).
const ROUTE_FROM := Vector2(7, -38)
const ROUTE_TO := Vector2(40, -50)
const WOLF := "res://creatures/wolves/wolf.tscn"


func _check_route() -> void:
	var holder := Node3D.new()
	holder.name = "Manor"
	_root.add_child(holder)
	var house := ManorHouseBuilder.build(holder)
	await _physics(2)
	var y := ManorHouseBuilder.floor_y(0)
	var aabb := NavBaker.manor_aabb()
	aabb = AABB(Vector3(aabb.position.x, y - 0.5, aabb.position.z), Vector3(aabb.size.x, ManorHouseBuilder.storey_height(0), aabb.size.z))
	NavBaker.bake_area(house, aabb, holder)
	var wolf := (load(WOLF) as PackedScene).instantiate() as Creature
	wolf.scripted = true
	_root.add_child(wolf)
	wolf.global_position = Vector3(ROUTE_FROM.x, y + 0.05, ROUTE_FROM.y)
	var goal := Vector3(ROUTE_TO.x, y, ROUTE_TO.y)
	var mover := NavMover.on(wolf)
	for i in 120:
		await get_tree().physics_frame
		if mover.has_mesh_at(wolf.global_position):
			break
	# The walkable spot nearest the chosen one (furniture stands on some floor).
	goal = NavigationServer3D.map_get_closest_point(mover.get_navigation_map(), goal)
	var straight := Vector2(goal.x - ROUTE_FROM.x, goal.z - ROUTE_FROM.y).length()
	var nav_path := mover.path_length_to(goal)
	var walked := 0.0
	var last := wolf.global_position
	var arrived := false
	for i in 60 * 40:
		wolf.move_direction = goal - wolf.global_position
		wolf.move_speed = wolf.data.walk_speed * 1.6
		await get_tree().physics_frame
		walked += Vector2(wolf.global_position.x - last.x, wolf.global_position.z - last.z).length()
		last = wolf.global_position
		if Vector2(goal.x - last.x, goal.z - last.z).length() < 1.0:
			arrived = true
			break
	var allowed := 1.5 * straight + maxf(nav_path - straight, 0.0)
	_record("route", arrived and walked <= allowed,
			"%s -> %s: arrived %s, walked %.1f m, straight %.1f m, nav path %.1f m, allowed %.1f m"
			% [_room_at(ROUTE_FROM), _room_at(Vector2(goal.x, goal.z)), arrived, walked, straight, nav_path, allowed])
	wolf.queue_free()


func _check_fire() -> void:
	# The real Blossom Vale streams in and registers its grass the way World does.
	var touch := TouchWorld.new()
	_root.add_child(touch)
	var field := touch.elements
	field.follow_world_wind = false
	var region := (load(FIRE_REGION) as PackedScene).instantiate() as Node3D
	_root.add_child(region)
	var frames := 0
	while not region.get(&"is_built") and frames < 60 * 120:
		await get_tree().process_frame
		frames += 1
	touch.add_ground_fuel(&"blossom_vale", region)
	while field.ground_pending() and frames < 60 * 150:
		await get_tree().process_frame
		frames += 1
	var fuel := field.ground(&"blossom_vale")
	if fuel == null:
		_record("fire", false, "Blossom Vale registered no ground fuel (built %s)" % region.get(&"is_built"))
		region.queue_free()
		touch.queue_free()
		return
	var spots := _meadow_spots(region, fuel, 2)
	var start: Vector3 = spots[0]
	var lit := field.ignite_at(start, 1.2)  # a fire arrow (forage-chemistry contract)
	frames = 0
	while frames < 60 * 3 and _touched(field, start, 20.0) <= lit:
		await get_tree().physics_frame
		frames += 1
	var spread_s := frames / 60.0
	await _physics(60 * 5)
	_record("fire", lit > 0 and spread_s < 3.0,
			"a fire arrow at a grass clump in Blossom Vale (%s) lit %d cells, the fire spread on after %.1f s, %d cells burning or burnt after %.0f s, %d flames, %d fuel squares in the region"
			% [start.snapped(Vector3.ONE * 0.1), lit, spread_s, _touched(field, start, 20.0), spread_s + 5.0,
			field.get_node("FireFx").flame_count(), fuel.square_count()])
	var hidden := field.scorch.hidden_count()
	var decals := field.scorch.decal_count()
	var grew := field.regrow_due(field.game_hours() + ElementField.REGROW_HOURS + 0.1)
	_record("scorch", hidden > 0 and decals > 0 and grew > 0 and field.scorch.hidden_count() == 0,
			"burnt squares hid %d real grass clumps under %d scorch decals; %.0f in-game hours later %d squares grew back (%d clumps still hidden)"
			% [hidden, decals, ElementField.REGROW_HOURS, grew, field.scorch.hidden_count()])
	var wet_at: Vector3 = spots[1]
	field.soak_at(wet_at, 1.8)  # a frost arrow
	var wet_lit := field.ignite_at(wet_at, 1.2)
	await _physics(60)
	var cells_before := field.cell_count()
	touch._on_region_unloaded(&"blossom_vale")
	_record("wet", wet_lit == 0 and _touched(field, wet_at, 3.0) == 0 and field.cell_count() == 0,
			"soaked grass at %s lit %d; unloading the region freed %d ground cells (left %d)"
			% [wet_at.snapped(Vector3.ONE * 0.1), wet_lit, cells_before, field.cell_count()])
	region.queue_free()
	touch.queue_free()


## Grass clumps in the middle of a meadow (every square round them has fuel), 40 m apart.
func _meadow_spots(region: Node3D, fuel: GroundFuel, n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var layers := []
	for f in TouchWorld.scatter_fields(region):
		layers.append_array((f as ScatterField).layers)
	for layer in layers:
		if GroundFuel.code_for(layer) != GroundFuel.GRASS:
			continue
		for i in range(0, layer.count(), 7):
			var p := (layer as ScatterLayer).position_of(i)
			var k := GroundFuel.key_of(p)
			var inside := true
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					if fuel.at(k + Vector2i(dx, dz)) == GroundFuel.NONE:
						inside = false
			if inside and out.all(func(q: Vector3) -> bool: return q.distance_to(p) > 40.0):
				out.append(p)
				if out.size() == n:
					return out
	return out


## Cells round `at` that are burning or burnt.
func _touched(field: ElementField, at: Vector3, radius: float) -> int:
	var n := 0
	for id in field.cells_near(at, radius):
		if field.is_burning(id) or field.is_burnt(id):
			n += 1
	return n


func _room_at(p: Vector2) -> String:
	for layout in ManorHouseBuilder.load_layouts():
		for room in layout.rooms:
			if room.level == 0 and room.rect.has_point(p):
				return String(room.id)
	return "?"


# --- helpers ---------------------------------------------------------------

func _record(id: String, ok: bool, detail: String) -> void:
	_results.append("TOUCH %s %s: %s" % [id, "pass" if ok else "FAIL", detail])
	if not ok:
		_failed += 1


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _floor(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	_root.add_child(body)
	body.position = at
	return body


func _walker(at: Vector3) -> CharacterBody3D:
	var b := CharacterBody3D.new()
	b.collision_layer = 1 << 1
	b.collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	col.shape = cap
	col.position.y = 0.8
	b.add_child(col)
	_root.add_child(b)
	b.position = at
	PropCarrier.for_body(b)
	return b


func _prop(id: StringName, at: Vector3) -> Prop:
	var p := Prop.make(PropPlacements.prop_data(id))
	_root.add_child(p)
	p.position = at
	return p
