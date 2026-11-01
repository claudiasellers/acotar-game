## The R17 clip of painting (L30): the p4 painting playtest, played the same
## way, with the screen saved as numbered frames while she paints (strokes
## drawn over several frames), finishes, the canvas leans by the wall, and she
## walks into the gallery. Mac only.
##   shot painting res://tools/playtest/p4_painting_clip.tscn {out}
## Frames: <out>/frame_000.png ... (at most MAX_FRAMES).
extends "res://tools/playtest/p4_painting_playtest.gd"

const MAX_FRAMES := 110
## Drags between frames while a stroke is being painted.
const DRAGS_PER_FRAME := 6

var frames_dir: String = ""
var frame: int = 0
var _next_at: float = 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			frames_dir = arg
	if frames_dir != "":
		out_path = frames_dir.path_join("p4_playtest.json")
	get_tree().root.size = Vector2i(1920, 1080)
	super._ready()


func _filming() -> bool:
	return frames_dir != "" and frame < MAX_FRAMES and DisplayServer.get_name() != "headless"


## Paints the stroke a few drags per frame, saving frames as it goes.
func _stroke(session: StudioSession, points: Array[Vector2]) -> String:
	if not _filming():
		return await super._stroke(session, points)
	var why := session.start_stroke(points[0])
	if why != "":
		return why
	for i in range(1, points.size()):
		session.canvas.drag(points[i])
		if i % DRAGS_PER_FRAME == 0:
			session.tick()
			await _grab()
	session.end_stroke()
	session.tick()
	await _grab()
	return ""


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _filming() or _beat.is_empty() or StudioUi.is_open():
		return
	var every := _every()
	if every <= 0.0 or _sim_seconds() < _next_at:
		return
	_next_at = _sim_seconds() + every
	_grab.call_deferred()


## Seconds between frames outside the studio; 0 = none.
func _every() -> float:
	match String(_beat.id):
		"studio_open":
			return 0.5
		"first_painting":
			return 0.25
		"gallery_seen":
			return 0.6
	return 0.0


func _grab() -> void:
	if not _filming():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(frames_dir.path_join("frame_%03d.png" % frame))
		frame += 1
