## The R17 clip of the Summer faerie (ch 17): the held playtest, played the
## same way, with the screen saved as numbered frames while things happen (he
## is carried in, the triage, his words, her hand, his death). Mac only.
##   shot faerie res://tools/playtest/p3_faerie_clip.tscn {out}
## Frames: <out>/frame_000.png ... (at most MAX_FRAMES).
extends "res://tools/playtest/p3_faerie_playtest.gd"

const MAX_FRAMES := 60

var frames_dir: String = ""
var frame: int = 0
var _next_at: float = 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			frames_dir = arg
	if frames_dir != "":
		out_path = frames_dir.path_join("p3_faerie_playtest.json")
	get_tree().root.size = Vector2i(1920, 1080)
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if triage and triage.running and feyre and String(_beat.get("id", "")) in ["words", "held"]:
		_turn_camera_to(triage.global_position + Vector3.UP * 0.9)
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
		"carried_in", "words", "hand":
			return 0.4
		"triage":
			return 0.8
		"held":
			return 0.9
	return 0.0


func _grab() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(frames_dir.path_join("frame_%03d.png" % frame))
		frame += 1
