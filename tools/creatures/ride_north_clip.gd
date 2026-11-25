## Clip of the played ride north (L86-11), on the player's own camera: deeds
## up to the beast's claim set directly, then the real RideNorth runs from the
## cottage to the manor steps under an autopilot that rides behind him and
## bolts once (the menace). Frames (854x480 JPG) are saved at FPS game-time in
## the windows that matter; between them the game runs at FAST x.
##   res://tools/creatures/ride_north_clip.tscn -- <out_dir>
extends Node

const FPS := 10.0
const FAST := 3.0
const SIZE := Vector2i(854, 480)
## Frames per saved sheet (stacked top to bottom): the shot runner returns at
## most 200 files, so the frames travel as sheets and are cut apart after.
const PER_SHEET := 20

var out_dir := "user://ride_clip"
var game: Node
var feyre: Node3D
var ride: RideNorth
var frame := 0
var _acc := 0.0
var _capturing := false
var _bolt_from := 0.0
var _bolt_until := -1.0
var _t := 0.0
var _ended_at := -1.0
var _sheet: Image
var _sheets := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _log(s: String) -> void:
	print("CLIP [%6.1f] %s" % [_t, s])


func _run() -> void:
	game = (load("res://story/act1/act1_game.tscn") as PackedScene).instantiate()
	add_child(game)
	var w := 0.0
	while not game.get(&"spawned") and w < 90.0:
		await get_tree().create_timer(0.5).timeout
		w += 0.5
	feyre = game.get(&"feyre")
	await get_tree().create_timer(6.0).timeout
	LinePresenter.of(get_tree()).clear()
	Clock.from_dict({"time_of_day": 0.93, "day": 1})
	for flag in ["wolf_killed", "pelt_sold", CottageEvening.SLEPT, "beast_claim_accepted"]:
		WorldState.raise_deed(flag)
	w = 0.0
	while (ride == null or ride.horse == null) and w < 30.0:
		await get_tree().create_timer(0.25).timeout
		w += 0.25
		ride = get_tree().get_first_node_in_group(RideNorth.GROUP) as RideNorth
	if ride == null or ride.horse == null:
		_log("no ride / no mare")
		get_tree().quit(1)
		return
	_log("mare waiting at %s; road %.0f m, Wall at %.0f m" % [ride.horse.global_position, ride.path_length(), ride.seam_at()])
	# Stand her a few steps from the mare, facing it, and let a second play.
	var m := ride.horse.global_position
	var back := (feyre.global_position - m)
	back.y = 0.0
	back = back.normalized() * 4.0 if back.length() > 0.1 else Vector3(0, 0, 4)
	feyre.global_position = m + back + Vector3.UP * 0.5
	_capturing = true
	await get_tree().create_timer(2.5).timeout
	ride.mount(feyre)
	_bolt_from = ride._mark(&"live")
	ride.autopilot = _pilot
	while ride.step != RideNorth.Step.AT_STEPS and _t < 900.0:
		await get_tree().process_frame
	_log("at the stairs (step %s) at %s" % [ride.step, Clock.hour()])
	_capturing = true
	Engine.time_scale = 1.0
	w = 0.0
	while ride._speaking() and w < 15.0:
		await get_tree().create_timer(0.25).timeout
		w += 0.25
	await get_tree().create_timer(1.0).timeout
	ride.get_down()
	await get_tree().create_timer(7.0).timeout
	_flush()
	_log("done: %d frames, feyre at %s, manor_arrival running %s" % [frame, feyre.global_position, _arrival_running()])
	get_tree().quit(0)


func _flush() -> void:
	if _sheet == null:
		return
	_sheet.save_jpg("%s/sheet_%03d.jpg" % [out_dir, _sheets], 0.85)
	_sheets += 1
	_sheet = null


func _arrival_running() -> bool:
	for n in get_tree().get_nodes_in_group(&"story_anchor"):
		var a := n.get_node_or_null(^"ManorArrival")
		if a:
			return a.running
	return false


func _pilot() -> Array:
	var at := ride.horse.global_position
	if ride.progress >= _bolt_from and _bolt_until < 0.0:
		_bolt_until = _t + 9.0
		_log("bolting east")
	if _bolt_until > 0.0 and _t < _bolt_until:
		return [ride.pose_at(ride.progress).basis.x.normalized(), true]
	var to := ride.pose_at(ride.progress + 9.0).origin - at
	to.y = 0.0
	return [to.normalized() if to.length() > 0.1 else Vector3.ZERO, ride.progress < ride.beast_at - 6.0]


## Which stretches are filmed: the mount and first thoughts, the bolt and his
## answer, the Wall, the sentry gate and drive, and the steps.
func _want_frames() -> bool:
	if ride == null or ride.step == RideNorth.Step.TO_MARE or ride.step == RideNorth.Step.MOUNTING:
		return true
	if ride.step != RideNorth.Step.RIDING:
		return true
	var p := ride.progress
	if p < ride._mark(&"village") + 40.0:
		return true
	if _bolt_until > 0.0 and _t < _bolt_until + 8.0:
		return true
	if absf(p - ride.seam_at()) < 70.0:
		return true
	if p > ride._mark(&"gate") - 30.0 and p < ride._mark(&"gate") + 60.0:
		return true
	return ride.path_length() - p < 140.0


func _process(delta: float) -> void:
	_t += delta
	if ride == null or not _capturing:
		return
	var want := _want_frames()
	Engine.time_scale = 1.0 if want else FAST
	if not want:
		_acc = 0.0
		return
	_acc += delta
	if _acc < 1.0 / FPS and frame > 0:
		return
	_acc = 0.0
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGB8)
	if _sheet == null:
		_sheet = Image.create(SIZE.x, SIZE.y * PER_SHEET, false, Image.FORMAT_RGB8)
	_sheet.blit_rect(img, Rect2i(Vector2i.ZERO, SIZE), Vector2i(0, SIZE.y * (frame % PER_SHEET)))
	frame += 1
	if frame % PER_SHEET == 0:
		_flush()
	if frame % 60 == 0:
		_log("frame %d, step %s, progress %.0f, stray %.1f tier %d" % [frame, ride.step, ride.progress, ride.stray, ride.tier])
