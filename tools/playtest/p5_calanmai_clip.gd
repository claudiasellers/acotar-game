## The R17 clip of Calanmai (L45): the p5 playtest, played the same way, with
## the screen saved as numbered frames through the beats worth seeing: the
## order at dusk, the bonfires, the three and the stranger, the moonlit
## hallway (the veil sinks), the vanity's bruise, and the paintings. Mac only.
##   shot calanmai res://tools/playtest/p5_calanmai_clip.tscn {out}
## Frames: <out>/frame_000.png ... (at most MAX_FRAMES).
extends "res://tools/playtest/p5_calanmai_playtest.gd"

const MAX_FRAMES := 150

var frames_dir: String = ""
var frame: int = 0
var _next_at: float = 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			frames_dir = arg
	if frames_dir != "":
		out_path = frames_dir.path_join("p5_playtest.json")
	get_tree().root.size = Vector2i(1920, 1080)
	# The Mac gives a shot about five minutes: no 1.2 km walk on film.
	ride_to_hill = true
	super._ready()


func _filming() -> bool:
	return frames_dir != "" and frame < MAX_FRAMES and DisplayServer.get_name() != "headless"


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _filming() or _beat.is_empty():
		return
	var every := _every()
	if every <= 0.0 or _sim_seconds() < _next_at:
		return
	_next_at = _sim_seconds() + every
	_grab.call_deferred()


## Seconds between frames in each beat; 0 = none (the long walks).
func _every() -> float:
	match String(_beat.id):
		"order":
			return 3.0
		"stranger":
			return 1.2
		"bite":
			return 0.8
		"vanity", "lunch":
			return 1.5
		"gown":
			return 1.2
		"fires":
			# Only once the hill is in sight, not along the road.
			var a := _anchor(&"calanmai_bonfires")
			return 1.0 if a and _flat(a.global_position) < 60.0 else 0.0
	return 0.0


func _grab() -> void:
	if not _filming():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(frames_dir.path_join("frame_%03d.png" % frame))
		frame += 1
