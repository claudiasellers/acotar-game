## Look check for the saddle and the seat (lane L47-8): Feyre sits the mare at a
## stand, side-on and from the front quarter, with the saddle and bareback, and
## it measures what the review asked for: her pelvis over the saddle centre
## (side-on, within 5 cm) and both hands within 8 cm of the rein line.
##   xvfb-run godot --rendering-method gl_compatibility res://tools/mount/mare_seat_shot.tscn -- <out_dir>
extends Node3D

const FEYRE := preload("res://characters/feyre/feyre.tscn")
const SIZE := Vector2i(960, 720)

var out := "/tmp/mare_seat"
var director: MountDirector
var feyre: Node3D
var cam: Camera3D
var report := {}


func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.8, 0.84, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.9)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	sun.light_energy = 0.75
	add_child(sun)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	mesh.mesh = plane
	mesh.material_override = MaterialLibrary.surface(Color(0.42, 0.56, 0.4), 0.9)
	ground.add_child(mesh)
	add_child(ground)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Pelvis and hands, read where the pose is real (inside the skeleton's update).
func _measure(tag: String) -> void:
	var sk := Saddle.skeleton_of(feyre)
	var horse := director.mare.horse
	var got := {}
	var read := func() -> void:
		var g := func(b: StringName) -> Vector3: return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b)).origin
		got["hips"] = g.call(&"Hips")
		got["lh"] = g.call(&"LeftHand")
		got["rh"] = g.call(&"RightHand")
		got["lf"] = g.call(&"LeftFoot")
		got["rf"] = g.call(&"RightFoot")
	sk.skeleton_updated.connect(read)
	await _frames(3)
	sk.skeleton_updated.disconnect(read)
	var centre := horse.on_back(MareSaddle.CENTRE)
	var f := -horse.global_basis.z
	var d: Vector3 = got["hips"] - centre
	var reins := horse.get_node(^"MareReins") as MareReins
	var lh_line := _to_line(got["lh"], reins.bit(true), horse.rein_hands[0])
	var rh_line := _to_line(got["rh"], reins.bit(false), horse.rein_hands[1])
	report[tag] = {
		"pelvis_ahead_of_centre_m": d.dot(f),
		"pelvis_side_of_centre_m": d.dot(horse.global_basis.x),
		"pelvis_above_centre_m": d.y,
		"left_hand_to_rein_m": lh_line,
		"right_hand_to_rein_m": rh_line,
		"feet": [got["lf"], got["rf"]],
	}
	print("%s %s" % [tag, report[tag]])


## Distance from p to the rein line (bit to grip; the grip is where the rein ends).
func _to_line(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	var horse := director.mare.horse
	cam.look_at_from_position(horse.global_transform * from, horse.global_transform * at)
	await _frames(2)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	_world()
	get_tree().root.get_viewport().get_window().size = SIZE
	StoryControl.set_mode(StoryControl.Mode.FULL)
	WorldState.set_flag("first_dinner_eaten", true)
	WorldState.set_flag("fact.mare_ridden", true)
	WorldDeltas.set_region_value(&"mount", "whistle_taught", true)
	WorldDeltas.set_region_value(&"mount", "tend_taught", true)
	feyre = FEYRE.instantiate() as Node3D
	add_child(feyre)
	feyre.global_position = Vector3(1.4, 0.05, 0)
	director = MountDirector.new()
	add_child(director)
	cam = Camera3D.new()
	cam.fov = 32.0
	add_child(cam)
	cam.current = true
	await _frames(10)
	director.spawn_mare(Vector3(0, 0.05, 0), 0.0)
	await _frames(5)
	director.mare.refresh_look()
	await _frames(2)
	await _shot("empty_side", Vector3(-6.5, 1.7, -0.2), Vector3(0, 1.5, -0.2))
	await _shot("empty_quarter", Vector3(-3.5, 2.6, -3.8), Vector3(0, 1.6, -0.3))
	director.mount(feyre, true)
	await _frames(20)
	await _measure("saddle")
	await _shot("seat_side", Vector3(-6.5, 1.9, -0.2), Vector3(0, 1.75, -0.2))
	await _shot("seat_quarter", Vector3(-3.0, 2.8, -3.6), Vector3(0, 1.8, -0.3))
	await _shot("seat_front", Vector3(-0.6, 2.4, -4.6), Vector3(0, 1.8, -0.3))
	MareTack.set_saddled(false)
	director.mare.refresh_look()
	await _frames(40)
	await _measure("bareback")
	await _shot("bare_side", Vector3(-6.5, 1.9, -0.2), Vector3(0, 1.75, -0.2))
	await _shot("bare_quarter", Vector3(-3.0, 2.8, -3.6), Vector3(0, 1.8, -0.3))
	MareTack.set_saddled(true)
	director.mare.refresh_look()
	var f := FileAccess.open("%s/report.json" % out, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	get_tree().quit()
