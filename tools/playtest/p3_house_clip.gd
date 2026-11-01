## The R17 clip of the p3 house beats (L28): the house playtest, played the
## same way, with the screen saved as numbered frames while things happen
## (her map page, the beast in the moonlit hall, the flash, the walk, the
## infirmary, the mural). Mac only.
##   shot house res://tools/playtest/p3_house_clip.tscn {out}
## Frames: <out>/frame_000.png ... (at most MAX_FRAMES).
extends "res://tools/playtest/p3_house_playtest.gd"

const MAX_FRAMES := 80

var frames_dir: String = ""
var frame: int = 0
var _next_at: float = 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			frames_dir = arg
	if frames_dir != "":
		out_path = frames_dir.path_join("p3_house_playtest.json")
	get_tree().root.size = Vector2i(1920, 1080)
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if frames_dir == "" or frame >= MAX_FRAMES or _beat.is_empty() or DisplayServer.get_name() == "headless":
		return
	var every := _every()
	if every <= 0.0 or _sim_seconds() < _next_at:
		return
	_next_at = _sim_seconds() + every
	_grab.call_deferred()


## Seconds between frames for what is on screen now; 0 = none.
func _every() -> float:
	match String(_beat.id):
		"hall_marks":
			return 4.0
		"map_drawn":
			return 0.8
		"the_beast":
			return 0.5
		"to_the_infirmary":
			return 3.0
		"wound_dressed":
			return 1.0
		"mural":
			return 0.7
	return 0.0


func _grab() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(frames_dir.path_join("frame_%03d.png" % frame))
		frame += 1
