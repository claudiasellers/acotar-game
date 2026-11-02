## The R17 clip of P6 "The blight tightens" (L46): the p6 playtest, played the
## same way, with the screen saved as numbered frames through each beat (the
## glen, Alis's bark, the head on the heron, the solstice dance, the carriage).
## Mac only.
##   shot blight res://tools/playtest/p6_blight_clip.tscn {out}
## Frames: <out>/frame_000.png ... (at most MAX_FRAMES).
extends "res://tools/playtest/p6_blight_playtest.gd"

const MAX_FRAMES := 400
## Seconds of game time between frames, by beat (0 = none). The dressing beat
## is mostly the ride to the plateau, so it is sparse.
const EVERY := {
	"invite": 2.0, "picnic": 0.5, "wonders": 0.8, "alis": 0.5, "fountain": 0.5,
	"dressing": 8.0, "solstice": 1.5, "lunch": 0.5, "farewell": 0.8, "carriage": 0.5,
}

var frames_dir: String = ""
var frame: int = 0
var _next_at: float = 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			frames_dir = arg
	if frames_dir != "":
		out_path = frames_dir.path_join("p6_playtest.json")
	get_tree().root.size = Vector2i(1280, 720)
	super._ready()


func _filming() -> bool:
	return frames_dir != "" and frame < MAX_FRAMES and DisplayServer.get_name() != "headless"


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _filming() or _beat.is_empty():
		return
	var every := float(EVERY.get(String(_beat.id), 0.0))
	if every <= 0.0 or _sim_seconds() < _next_at:
		return
	_next_at = _sim_seconds() + every
	_grab.call_deferred()


func _grab() -> void:
	if not _filming():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(frames_dir.path_join("frame_%03d.png" % frame))
		frame += 1
