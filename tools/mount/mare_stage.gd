## Cloud look-dev stage for the white mare's feel (L47-6): flat meadow, the real
## Feyre player and MountDirector, no world. Whistle and arrival, the vault on,
## a canter and gallop with turns, the slide off. Writes numbered PNGs per beat
## and prints the motion numbers. The real-scene proof is mount_ride_clip.
##   xvfb-run godot --rendering-method gl_compatibility res://tools/mount/mare_stage.tscn -- <out_dir>
extends Node3D

const FEYRE := preload("res://characters/feyre/feyre.tscn")
const FPS := 30.0
const SIZE := Vector2i(960, 540)

var out := "user://mare_stage"
var director: MountDirector
var feyre: Node3D
var cam: Camera3D
var _frame := 0
var _beat := ""
var _follow: Callable


func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = SIZE
	Engine.max_fps = 0
	_run.call_deferred()


func _set_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.62, 0.7, 0.95)
	sm.sky_horizon_color = Color(0.98, 0.86, 0.9)
	sm.ground_horizon_color = Color(0.86, 0.9, 0.8)
	sm.ground_bottom_color = Color(0.5, 0.62, 0.45)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.9, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.shadow_enabled = true
	sun.light_energy = 0.62
	e.tonemap_exposure = 0.82
	add_child(sun)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 1, 600)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.74, 0.5)
	mat.uv1_scale = Vector3(120, 120, 1)
	mat.albedo_texture = _checker()
	pm.material = mat
	mesh.mesh = pm
	ground.add_child(mesh)
	add_child(ground)


func _checker() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in 8:
		for x in 8:
			var k := 0.92 if ((x / 4) + (y / 4)) % 2 == 0 else 1.0
			img.set_pixel(x, y, Color(k, k, k))
	return ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	if _follow.is_valid():
		_follow.call()
	if _beat == "":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%04d.png" % [out, _beat, _frame])
	_frame += 1


func _record(beat: String) -> void:
	_beat = beat
	_frame = 0


func _wait(seconds: float) -> void:
	var frames := int(seconds * FPS)
	for i in frames:
		await get_tree().process_frame


func _run() -> void:
	_set_world()
	StoryControl.set_mode(StoryControl.Mode.FULL)
	WorldState.set_flag("first_dinner_eaten", true)
	WorldState.set_flag("fact.mare_ridden", true)
	WorldDeltas.set_region_value(&"mount", "whistle_taught", true)
	feyre = FEYRE.instantiate() as Node3D
	add_child(feyre)
	feyre.global_position = Vector3(10, 0.05, 10)
	director = MountDirector.new()
	add_child(director)
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 50.0
	cam.current = true
	# Fixed timestep so the clip is real-time whatever the render speed.
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	get_tree().root.get_viewport().get_window().size = SIZE
	for i in 10:
		await get_tree().process_frame
	# 1. The whistle: she comes from behind the camera and pulls up side-on.
	director.spawn_mare(Vector3(-30, 0.05, -25), 0.0)
	cam.current = true
	_follow = func() -> void:
		cam.look_at_from_position(feyre.global_position + Vector3(3.0, 2.0, 6.5), feyre.global_position + Vector3(-1.5, 1.1, -3.0))
	_record("whistle")
	director.whistle()
	var waited := 0.0
	while waited < 16.0 and not (director.mare and director.mare.state == MareMount.State.STANDING and is_nan(director.mare._present_yaw)):
		await _wait(0.2)
		waited += 0.2
	await _wait(0.8)
	var m := director.mare
	var to_f := feyre.global_position - m.global_position
	to_f.y = 0
	print("ARRIVE dist %.2f  side %.2f (1 = Feyre square on her left)" % [to_f.length(), to_f.normalized().dot(-m.global_basis.x)])
	# 2. The vault on, from a side camera.
	_record("mount")
	var side := -m.global_basis.x
	_follow = func() -> void:
		cam.look_at_from_position(m.global_position + side * 5.2 + m.global_basis.z * 1.5 + Vector3.UP * 1.7, m.global_position + Vector3.UP * 1.4)
	director.mount(feyre)
	var mm := director.motion
	await _wait(1.6)
	print("MOUNT peak hip speed %.2f m/s  %.2f s" % [mm.max_hip_speed if mm else -1.0, mm.t if mm else -1.0])
	# 3. The ride: canter a wide left turn, then gallop and turn right.
	_record("ride")
	var t0 := Time.get_ticks_msec()
	director.autopilot = func() -> Array:
		var s := (Time.get_ticks_msec() - t0) / 1000.0
		var dir := -m.global_basis.z
		var turn := 0.5 if s < 3.0 else -0.6
		return [dir.rotated(Vector3.UP, turn), s > 3.0]
	_follow = func() -> void:
		cam.look_at_from_position(m.global_position + m.global_basis.z * 7.0 + m.global_basis.x * 2.5 + Vector3.UP * 3.2, m.global_position + Vector3.UP * 1.6)
	await _wait(6.0)
	director.autopilot = func() -> Array: return [Vector3.ZERO, false]
	await _wait(2.0)
	# 4. The slide off.
	_record("dismount")
	side = -m.global_basis.x
	_follow = func() -> void:
		cam.look_at_from_position(m.global_position + side * 5.2 + m.global_basis.z * 1.5 + Vector3.UP * 1.7, m.global_position + Vector3.UP * 1.3)
	director.dismount()
	var dm := director.motion
	await _wait(1.5)
	print("DISMOUNT peak hip speed %.2f m/s" % (dm.max_hip_speed if dm else -1.0))
	print("DISMOUNT riding=%s physics=%s" % [director.riding, feyre.is_physics_processing()])
	_beat = ""
	get_tree().quit()
