## Contract (T092): people are solid. Feyre walking into someone standing still
## stops at about the two capsule radii and never passes through; a person never
## fades part by part (that showed their eyes and teeth like a skeleton), only
## vanishes whole while the lens is inside them.
extends GutTest

const FEYRE := preload("res://characters/feyre/feyre.tscn")


func after_each() -> void:
	Input.action_release(&"move_forward")
	CameraFade.headless_opt_in = false


func _floor() -> void:
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor.add_child(shape)
	add_child_autofree(floor)
	floor.global_position = Vector3(0, -0.5, 0)


func _villager(at: Vector3) -> CourtNpc:
	var npc := CourtNpc.new()
	npc.npc_id = &"test_villager"
	add_child_autofree(npc)
	npc.global_position = at
	return npc


func test_feyre_bumps_into_a_standing_person() -> void:
	_floor()
	var npc := _villager(Vector3.ZERO)
	assert_not_null(ActorBody.find_on(npc), "a villager has a body")
	var f := FEYRE.instantiate() as Feyre
	add_child_autofree(f)
	f.global_position = Vector3(0, 0.05, 5)
	Input.action_press(&"move_forward")
	await wait_physics_frames(150)
	var gap := Vector2(f.global_position.x, f.global_position.z).length()
	assert_gt(f.global_position.z, 0.0, "never passed through")
	assert_almost_eq(gap, 0.3 + ActorBody.RADIUS, 0.15, "stopped about two radii from their centre")


func test_a_hidden_person_is_not_solid() -> void:
	var npc := _villager(Vector3.ZERO)
	var body := ActorBody.find_on(npc)
	assert_true(body.is_solid())
	npc.visible = false
	assert_false(body.is_solid(), "away or hidden: no invisible wall")


func test_a_person_never_fades_part_by_part() -> void:
	CameraFade.headless_opt_in = true
	var npc := _villager(Vector3.ZERO)
	var part := MeshInstance3D.new()
	part.mesh = BoxMesh.new()
	part.position.y = 1.0
	npc.add_child(part)
	part.add_to_group(CameraFade.PROBE_GROUP)
	var fade := CameraFade.new()
	add_child_autofree(fade)
	assert_eq(fade.near_meshes(Vector3(0, 1.0, 0.6), CameraFade.OWN_RADIUS).size(), 0, "no per-part fade")
	assert_eq(fade.sight_blockers(Vector3(0, 1.0, 3.0), Vector3(0, 1.0, -3.0)).size(), 0, "no sight-line fade")
	assert_has(fade.people_at_lens(Vector3(0, 1.0, 0.1)), part, "lens inside: the whole person goes")
	assert_eq(fade.people_at_lens(Vector3(0, 1.0, 1.5)).size(), 0, "lens outside: they stay")
