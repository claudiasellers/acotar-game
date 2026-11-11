# gate: needs:terrain
# gate: when:world/shared/world/*,world/human_realm/wall_seam/*,systems/mount/*,characters/feyre/*,systems/actor_body/*,core/story_control.gd,world/shared/world_map.gd
## T107 contract: in the World scene Feyre (and the mare) can walk up to the
## Wall but never across it, either way; story moves still cross.
extends GutTest

const WORLD := preload("res://world/shared/world/world.tscn")
const X := -300.0

var world: World


func before_each() -> void:
	StoryControl.release()
	world = WORLD.instantiate()
	add_child_autofree(world)
	await wait_physics_frames(2)


## A stand-in with Feyre's collision layer and mask, in the player group.
func _walker(z: float) -> CharacterBody3D:
	var b := CharacterBody3D.new()
	b.collision_layer = Feyre.PLAYER_LAYER
	b.collision_mask = Feyre.WORLD_MASK | ActorBody.LAYER
	b.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	cs.shape = cap
	b.add_child(cs)
	b.add_to_group(&"player")
	b.set_physics_process(true)  # Feyre's script has _physics_process; the guard reads this
	add_child_autofree(b)
	b.global_position = Vector3(X, WorldHeight.height_at(X, z) + 3.0, z)
	return b


func _walk(b: CharacterBody3D, dir_z: float, frames: int) -> void:
	for i in frames:
		b.velocity = Vector3(0.0, 0.0, dir_z * 6.0)
		b.move_and_slide()
		await wait_physics_frames(1)


func test_act1_she_cannot_walk_north_into_prythian() -> void:
	var b := _walker(WorldMap.WALL_Z + 6.0)
	await _walk(b, -1.0, 90)  # 9 m worth at 6 m/s
	assert_false(WorldMap.is_in_prythian(b.global_position), "still in the human realm at z %.2f" % b.global_position.z)
	assert_lt(b.global_position.z, WorldMap.WALL_Z + 1.5, "she reached the Wall itself")


func test_act2_she_cannot_walk_south_back_to_the_woods() -> void:
	var b := _walker(WorldMap.WALL_Z - 6.0)
	await _walk(b, 1.0, 90)
	assert_true(WorldMap.is_in_prythian(b.global_position), "still in Prythian at z %.2f" % b.global_position.z)
	assert_gt(b.global_position.z, WorldMap.WALL_Z - 1.5, "she reached the Wall itself")


func test_a_short_hop_past_the_slab_is_sent_back_but_story_moves_cross() -> void:
	var b := _walker(WorldMap.WALL_Z + 2.0)
	await wait_physics_frames(2)
	b.global_position.z = WorldMap.WALL_Z - 2.0  # a mantle tween or a fast frame
	await wait_physics_frames(2)
	assert_false(WorldMap.is_in_prythian(b.global_position), "guard put her back")
	b.set_physics_process(false)  # the ride north carries her with physics off
	b.global_position.z = WorldMap.WALL_Z - 2.0
	await wait_physics_frames(2)
	assert_true(WorldMap.is_in_prythian(b.global_position), "story crossing kept")


func test_the_wall_stays_see_through() -> void:
	var wall := world.get_node("WallBarrier") as WallBarrier
	assert_not_null(wall)
	assert_eq(wall.find_children("*", "VisualInstance3D", true, false).size(), 0, "nothing drawn")
	var slab := wall.get_node("Slab") as StaticBody3D
	assert_eq(slab.collision_layer & Feyre.WORLD_MASK, 0, "camera and floor rays (world layer) ignore it")
	var mare := MareMount.new()
	assert_ne(slab.collision_layer & mare.collision_mask, 0, "the mare is stopped too")
	assert_true(mare.is_in_group(WallBarrier.GROUP), "and guarded")
	mare.free()
