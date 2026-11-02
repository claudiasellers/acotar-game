## Contract: Feyre.teleport is final. Teleported in the middle of a ledge climb (by
## Return Home, Wriggle Free, a save load or a tool), she stays at the target: the
## climb stops, is_mantling clears, and her velocity is zero.
extends GutTest

const FEYRE := preload("res://characters/feyre/feyre.tscn")


func _slab(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = center


## Floor, a 1.2 m ledge just in front of her (-z), and a far floor to send her to.
func _mid_climb() -> Feyre:
	_slab(Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	_slab(Vector3(0, 0.6, -1.5), Vector3(4, 1.2, 2))
	_slab(Vector3(40, -0.5, 0), Vector3(10, 1, 10))
	var f := FEYRE.instantiate() as Feyre
	add_child_autofree(f)
	f.global_position = Vector3(0, 0.05, 0)
	f.model.rotation.y = 0.0   # facing -z, the ledge
	return f


func test_a_teleport_mid_climb_stays_at_the_target() -> void:
	var f := _mid_climb()
	await wait_seconds(0.5)
	assert_true(f._try_mantle(), "the ledge starts a climb")
	await wait_seconds(0.1)
	assert_true(f.is_mantling, "still climbing")
	var target := Vector3(40, 0.05, 0)
	f.teleport(target)
	assert_false(f.is_mantling, "the climb is over")
	assert_eq(f.velocity, Vector3.ZERO)
	await wait_seconds(0.8)   # longer than the whole 0.44 s climb tween
	var flat := Vector2(f.global_position.x, f.global_position.z)
	assert_lt(flat.distance_to(Vector2(target.x, target.z)), 0.3, "she is still at the target, not back on the ledge (%s)" % f.global_position)


func test_return_home_goes_through_teleport() -> void:
	var f := _mid_climb()
	await wait_seconds(0.5)
	assert_true(f._try_mantle())
	await wait_seconds(0.1)
	ReturnHome.go(f, Vector3(40, 0.05, 0))
	await wait_seconds(0.8)
	assert_false(f.is_mantling)
	assert_gt(f.global_position.x, 30.0, "Return Home's fallback holds (%s)" % f.global_position)
