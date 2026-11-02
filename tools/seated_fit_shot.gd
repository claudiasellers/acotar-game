## Seated figures in their clothes, from the side and both quarters (T045):
##   godot res://tools/seated_fit_shot.tscn -- [out_dir] [who,who,...]
## Tamlin, Lucien and Feyre (her tunic, then her dinner gown) each sit on the
## dining chair in FilmPose's fitted sit, on a plain floor with a studio light.
## A geometry check, not a lighting one. Needs a GPU or lavapipe.
extends Node

const WHO := ["tamlin", "lucien", "feyre_tunic", "feyre_gown"]
const VIEWS := {
	"side": Vector3(0.0, 0.75, 2.2),
	"front_l": Vector3(1.6, 0.9, 1.5),
	"back_l": Vector3(-1.6, 0.9, 1.5),
	"back_r": Vector3(-1.6, 0.9, -1.5),
}

var _cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_environment("SHOTS_OUT")
	if out == "":
		out = "user://"
	var who: Array = Array(args[1].split(",")) if args.size() > 1 else WHO
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.6, 0.65)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	var chair := PropLib.build(&"chair_dining")
	add_child(chair)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	add_child(_cam)
	_cam.make_current()
	for id: String in who:
		var figure := _figure(id)
		add_child(figure)
		figure.global_basis = Basis.looking_at(Vector3.RIGHT, Vector3.UP)
		await _frames(6)
		FilmPose.on(figure).to(&"sit", 0.0, &"chair_dining")
		await _frames(8)
		for view: String in VIEWS:
			_cam.global_position = Vector3(0.0, 0.0, 0.0) + (VIEWS[view] as Vector3)
			_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			if img != null and not img.is_empty():
				img.save_png(out.path_join("%s_%s.png" % [id, view]))
				print("saved ", id, "_", view)
		figure.queue_free()
		await _frames(2)
	get_tree().quit()


func _figure(id: String) -> Node3D:
	if id == "tamlin" or id == "lucien":
		return (load("res://characters/%s/%s_model.tscn" % [id, id]) as PackedScene).instantiate() as Node3D
	var model := (load("res://characters/feyre/model/feyre_model.tscn") as PackedScene).instantiate() as Node3D
	var outfit := Wardrobe.new()
	var pieces: Array = [&"spring_tunic_sky", &"spring_trousers_cream"] if id == "feyre_tunic" else [&"dinner_gown_blush"]
	for piece: StringName in pieces:
		outfit.grant(piece)
		outfit.equip(piece)
	if id == "feyre_tunic":
		outfit.unequip_slot(&"outer")
	WardrobeApplier.dress(model, outfit)
	return model


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
