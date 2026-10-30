## Loads the whole Manor Estate region and walks Feyre onto it.
extends GutTest

const SCENE := preload("res://world/spring_court/manor_estate/manor_estate.tscn")
const FEYRE := preload("res://characters/feyre/feyre.tscn")

var estate: ManorEstate


func before_all() -> void:
	var t := Time.get_ticks_msec()
	estate = SCENE.instantiate()
	add_child(estate)
	gut.p("estate built in %d ms" % (Time.get_ticks_msec() - t))


func after_all() -> void:
	estate.queue_free()


func _drop_feyre_at(x: float, z: float, y: float = NAN) -> Node3D:
	var f := FEYRE.instantiate() as Node3D
	var ground := WorldHeight.height_at(x, z) if is_nan(y) else y
	f.position = Vector3(x, ground + 0.4, z)
	estate.add_child(f)
	return f


func test_feyre_lands_on_the_drive() -> void:
	var s := ManorSitePlan.SPAWN
	var f := _drop_feyre_at(s.x, s.z)
	await wait_physics_frames(40)
	assert_true((f as CharacterBody3D).is_on_floor())
	assert_gt(f.global_position.y, WorldHeight.height_at(s.x, s.z) - 0.3)
	f.queue_free()


func test_ground_never_lets_feyre_fall_through() -> void:
	var points := [Vector2(-500, -400), Vector2(450, -300), Vector2(-400, 200), Vector2(300, 250), Vector2(0, -150), Vector2(190, 160)]
	var bodies: Array[Node3D] = []
	for p in points:
		bodies.append(_drop_feyre_at(p.x, p.y))
	await wait_physics_frames(40)
	for i in bodies.size():
		var p: Vector2 = points[i]
		assert_gt(bodies[i].global_position.y, WorldHeight.height_at(p.x, p.y) - 0.5, "fell through at %s" % p)
		bodies[i].queue_free()
