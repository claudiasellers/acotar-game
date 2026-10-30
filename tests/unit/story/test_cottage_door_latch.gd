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
