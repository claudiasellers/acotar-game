## Headless touch test for the touchable world (T5). Builds a small yard,
## then plays each check the way a player would and prints one line per check:
##   push   - walk a body into a crate: it moves >= 0.5 m
##   throw  - pick up a pot and toss it: it lands >= 3 m away
##   (more checks join with the navmesh and chemistry slices)
##   tools/mq/godot.sh -s tools/playtest/touch_test.gd
## Passes when the log ends "TOUCH exit 0".
extends SceneTree

var _root: Node3D
var _results: Array[String] = []
var _failed := 0


func _initialize() -> void:
	_root = Node3D.new()
	_root.name = "TouchYard"
	root.add_child(_root)
	_floor(Vector3(0, -0.5, 0), Vector3(120, 1, 120))
	_run.call_deferred()


func _run() -> void:
	await _check_push()
	await _check_throw()
	for line in _results:
		print(line)
	print("TOUCH exit %d" % _failed)
	quit(_failed)


func _check_push() -> void:
	var crate := _prop(&"crate", Vector3(0, 0, -1.2))
	var walker := _walker(Vector3.ZERO)
	await _physics(10)
	var start := crate.global_position
	# Walk forward (-Z) at her run pace for 1.5 s; the carrier shoves what she hits.
	for i in 90:
		walker.velocity = Vector3(0, -1, -5.0)
		walker.move_and_slide()
		await physics_frame
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


# --- helpers ---------------------------------------------------------------

func _record(id: String, ok: bool, detail: String) -> void:
	_results.append("TOUCH %s %s: %s" % [id, "pass" if ok else "FAIL", detail])
	if not ok:
		_failed += 1


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


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
