## The cottage door swings in as Feyre comes up to it (fixlist F13).
extends GutTest

var cottage: Node3D
var anchor: Marker3D
var feyre: Node3D


func before_each() -> void:
	WorldState.clear()
	cottage = Node3D.new()
	add_child_autofree(cottage)
	var door := Node3D.new()
	door.name = "CottageDoor"
	door.position = Vector3(-1.9, 0.0, -2.95)
	cottage.add_child(door)
	var intact := Node3D.new()
	intact.name = "IntactState"
	door.add_child(intact)
	intact.add_child((load("res://world/human_realm/cottage/assets/cottage_door_intact.glb") as PackedScene).instantiate())
	var interior := Node3D.new()
	interior.name = "Interior"
	cottage.add_child(interior)
	anchor = Marker3D.new()
	anchor.name = "act1_cottage_door"
	anchor.position = Vector3(-1.9, 0.0, -2.85)
	anchor.rotation_degrees.y = 180.0  # as cottage_gen places it: -Z into the room
	anchor.add_to_group(&"story_anchor")
	interior.add_child(anchor)
	feyre = Node3D.new()
	feyre.add_to_group(&"player")
	add_child_autofree(feyre)
	StoryDirector.attach_anchor(anchor)


func _free_edge() -> Vector3:
	var leaf := cottage.get_node(^"CottageDoor/IntactState") as Node3D
	return leaf.global_transform * Vector3(0.474, 1.0, -0.06)


func test_the_door_opens_into_the_room_and_shuts_behind_her() -> void:
	var latch := anchor.get_node_or_null(^"CottageDoorLatch") as CottageDoorLatch
	assert_not_null(latch, "hung on the door anchor")
	var shut := _free_edge()
	feyre.global_position = Vector3(-1.9, 0.0, -4.5)
	latch._physics_process(0.1)
	assert_true(latch.is_open)
	await wait_seconds(CottageDoorLatch.SWING_SECONDS + 0.2)
	var open := _free_edge()
	assert_gt(open.z - shut.z, 0.8, "swung in, toward the room")
	feyre.global_position = Vector3(-1.9, 0.0, 3.0)
	for i in 20:
		latch._physics_process(0.1)
	assert_false(latch.is_open, "shut once she's well inside")
	await wait_seconds(CottageDoorLatch.SWING_SECONDS + 0.2)
	assert_almost_eq(_free_edge().distance_to(shut), 0.0, 0.01)


func test_attaching_twice_hangs_one_latch() -> void:
	StoryDirector.attach_anchor(anchor)
	assert_eq(anchor.get_child_count(), 1)


func test_the_beast_bursts_through_into_the_room() -> void:
	var latch := anchor.get_node(^"CottageDoorLatch") as CottageDoorLatch
	var beast := (load("res://creatures/beast/beast_actor.tscn") as PackedScene).instantiate() as BeastActor
	add_child_autofree(beast)
	beast.global_position = latch.global_position + latch.global_basis.z * BeastDoor.OUTSIDE
	beast.door = latch
	feyre.global_position = latch.global_position - latch.global_basis.z * 6.0  # across the room
	var shut := _free_edge()
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	for i in 120:
		beast._process(1.0 / 30.0)
	var inside := latch.global_position - latch.global_basis.z * beast.enter_depth
	assert_almost_eq(Vector2(beast.global_position.x, beast.global_position.z).distance_to(Vector2(inside.x, inside.z)), 0.0, 0.1,
			"in the room, %.1f m past the door" % beast.enter_depth)
	assert_true(beast.global_position.z > latch.global_position.z, "on the room side (+Z of the cottage)")
	assert_true(latch.broken, "the latch let go")
	await wait_seconds(0.4)
	assert_gt(_free_edge().z - shut.z, 0.8, "the leaf flew in")


func test_he_towers_over_her_never_through_her() -> void:
	var latch := anchor.get_node(^"CottageDoorLatch") as CottageDoorLatch
	# Feyre standing right where the break would carry him.
	feyre.global_position = latch.global_position - latch.global_basis.z * 2.6
	var beast := (load("res://creatures/beast/beast_actor.tscn") as PackedScene).instantiate() as BeastActor
	add_child_autofree(beast)
	beast.global_position = latch.global_position + latch.global_basis.z * BeastDoor.OUTSIDE
	beast.door = latch
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	for i in 120:
		beast._process(1.0 / 30.0)
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"accuse")
	for i in 120:
		beast._process(1.0 / 30.0)
	var gap := Vector2(beast.global_position.x, beast.global_position.z).distance_to(Vector2(feyre.global_position.x, feyre.global_position.z))
	assert_gt(gap, beast.keep_clear - 0.1, "%.2f m from her" % gap)
	assert_lt(gap, beast.keep_clear + 0.6, "but close enough to loom")
