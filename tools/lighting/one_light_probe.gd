## Mac look check for the one lighting authority (L89; docs/SHOTS.md):
##   godot res://tools/lighting/one_light_probe.tscn -- <out_dir>
## The manor entrance hall at noon with the ride's spring grade still held and
## a wolf's full dread (hall: the rooms' own look; fear never darkens). Then
## the front lawn with that hold and dread (lawn_dread: the held grade, no
## darkening) and with every request released (lawn_calm). Prints what the
## director chose and each frame's mean luminance.
extends Node

const ESTATE := "res://world/spring_court/manor_estate/manor_estate.tscn"
const EYE := 1.65

var _out := ""
var _cam: Camera3D
var _director: GradeDirector
var _focus: Node3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_environment("SHOTS_OUT")
	if _out == "":
		_out = "user://one_light"
	DirAccess.make_dir_recursive_absolute(_out)
	Clock.time_of_day = 0.5
	Clock.paused = true
	var estate := (load(ESTATE) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(estate)
	get_tree().current_scene = estate
	_director = GradeDirector.light(estate, &"manor")
	_focus = Node3D.new()
	estate.add_child(_focus)
	_cam = Camera3D.new()
	_cam.fov = 72.0
	_cam.far = 400.0
	estate.add_child(_cam)
	_cam.make_current()
	await _frames(30)

	var hall := _room(&"entrance_hall")
	var y := ManorHouseBuilder.floor_y(hall.level)
	var lo := hall.rect.position + Vector2(2.0, 2.0)
	var hi := hall.rect.end - Vector2(2.0, 2.0)
	var aim := lo.lerp(hi, 0.65)
	var hall_eye := Vector3(lo.x, y + EYE, lo.y)
	var hall_aim := Vector3(aim.x, y + 0.9, aim.y)

	_place(hall_eye, hall_aim)
	_director.focus = _focus
	var ride := Node.new()
	ride.name = "RideStandIn"
	estate.add_child(ride)
	EventBus.grade_swap_requested.emit(ride, &"spring", 0.0)
	EventBus.mood_requested.emit(DreadField, &"dread", 1.0, 0.0)
	await _frames(4)
	_director.swap_to(_director.target_id(), 0.0)
	await _shot("hall")

	# Outside on the front lawn, looking at the house: the held grade lands.
	var lawn := ManorSitePlan.SPAWN
	var lawn_y := WorldHeight.height_at(lawn.x, lawn.z)
	_place(Vector3(lawn.x, lawn_y + EYE, lawn.z), Vector3(0.0, lawn_y + 6.0, -50.0))
	await _frames(4)
	_director.swap_to(_director.target_id(), 0.0)
	await _shot("lawn_dread")

	EventBus.mood_requested.emit(DreadField, &"calm", 0.0, 0.0)
	EventBus.grade_swap_requested.emit(ride, &"", 0.0)
	await _frames(4)
	_director.swap_to(_director.target_id(), 0.0)
	await _shot("lawn_calm")
	get_tree().quit()


func _room(id: StringName) -> ManorRoomDef:
	for layout in ManorHouseBuilder.load_layouts():
		for r: ManorRoomDef in layout.rooms:
			if r.id == id:
				return r
	return null


func _place(eye: Vector3, aim: Vector3) -> void:
	_cam.global_position = eye
	_cam.look_at(aim, Vector3.UP)
	_focus.global_position = Vector3(eye.x, eye.y - EYE, eye.z)


func _shot(label: String) -> void:
	await _seconds(3.0 if OS.get_environment("SHOTS_QUALITY") == "look" else 0.5)
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	var path := _out.path_join(label + ".png")
	img.save_png(path)
	print("PROBE %-11s grade %-16s indoors %-5s mood %s %.2f  luma %.3f  %s" % [label,
			_director.current.id, _director.indoors, _director.mood, _director.mood_strength,
			_luma(img), path])


static func _luma(img: Image) -> float:
	var small := img.duplicate() as Image
	small.resize(64, 36, Image.INTERPOLATE_BILINEAR)
	var total := 0.0
	for y in small.get_height():
		for x in small.get_width():
			total += small.get_pixel(x, y).get_luminance()
	return total / (small.get_width() * small.get_height())


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
