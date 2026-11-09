## Captures a film as it really plays (lane L33), for Mac look shots
## (docs/SHOTS.md). Persistent under the root, so it rides through the
## opening film's scene change. Writes into `out`:
## - still_<t>.jpg at each time in `stills` (full size),
## - sheet.png: the stills as a 4-wide contact sheet (640x360 tiles),
## - clip_<k>.jpg at `fps`: frames of 384x216, 64 to an 8x8 atlas, left to
##   right then down (the Mac returns at most 200 files a shot), for
##   tools/film/make_clip.sh,
## - timing.txt: when each beat fired against the film clock, and the
##   frame time it rendered at (for the R9 check).
class_name FilmCapture
extends Node

const TILE := Vector2i(640, 360)
const CLIP := Vector2i(384, 216)
const CLIP_COLS := 8
const CLIP_PER := 64

## Sizes the picture to the film's output size. In a quiet Mac render (T088,
## tools/mq/shots_common.sh) the OS window stays small and the root is in
## "viewport" stretch: size the picture (content_scale_size), never the window.
static func size_root(win: Window, size: Vector2i = Vector2i(1920, 1080)) -> void:
	if win.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT:
		win.content_scale_size = size
	else:
		win.size = size


var out: String = "user://film_capture"
var stills: PackedFloat32Array = []
var fps: float = 4.0
var quit_after: float = 0.0
## Count from the first film to start (a cutscene the story starts), not
## from load; give up after `give_up` seconds without one.
var wait_for_film: bool = false
var give_up: float = 300.0
var _seen_film: bool = false

var _done_stills: int = 0
var _frame: int = 0
var _atlas: Image
var _next_clip: float = 0.0
var _sheet_tiles: Array[Image] = []
var _log: PackedStringArray = []
var _watched: FilmPlayer
var _t_end: float = -1.0
var _worst_ms: float = 0.0
var _frames: int = 0
var _sum_ms: float = 0.0
var _last_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out)


func _film_time() -> float:
	var p := FilmPlayer.current(get_tree())
	if p:
		_seen_film = true
	if wait_for_film and not _seen_film:
		if Time.get_ticks_msec() / 1000.0 > give_up:
			push_error("film_capture: no film started in %.0f s" % give_up)
			_log.append("no film started")
			_finish()
		return -1.0
	if p and p != _watched:
		_watched = p
		p.beat.connect(func(b: StringName) -> void: _log.append("beat %s at %.2f" % [b, p.time]))
	if p and not p.ended:
		_last_t = p.time
		return p.time
	if _t_end < 0.0:
		_t_end = Time.get_ticks_msec() / 1000.0 - _last_t
	return Time.get_ticks_msec() / 1000.0 - _t_end


func _process(delta: float) -> void:
	var t := _film_time()
	if t > 1.0:
		_frames += 1
		_sum_ms += delta * 1000.0
		_worst_ms = maxf(_worst_ms, delta * 1000.0)
	var img: Image = null
	if fps > 0.0 and t >= _next_clip:
		_next_clip += 1.0 / fps
		img = get_viewport().get_texture().get_image()
		var small := img.duplicate() as Image
		small.resize(CLIP.x, CLIP.y, Image.INTERPOLATE_BILINEAR)
		small.convert(Image.FORMAT_RGB8)
		if _atlas == null:
			_atlas = Image.create(CLIP.x * CLIP_COLS, CLIP.y * (CLIP_PER / CLIP_COLS), false, Image.FORMAT_RGB8)
		var k := _frame % CLIP_PER
		_atlas.blit_rect(small, Rect2i(Vector2i.ZERO, CLIP), Vector2i((k % CLIP_COLS) * CLIP.x, (k / CLIP_COLS) * CLIP.y))
		_frame += 1
		if _frame % CLIP_PER == 0:
			_flush_atlas()
	if _done_stills < stills.size() and t >= stills[_done_stills]:
		if img == null:
			img = get_viewport().get_texture().get_image()
		img.save_jpg("%s/still_%05.1f.jpg" % [out, stills[_done_stills]], 0.93)
		var tile := img.duplicate() as Image
		tile.resize(TILE.x, TILE.y, Image.INTERPOLATE_BILINEAR)
		_sheet_tiles.append(tile)
		_done_stills += 1
	if quit_after > 0.0 and t >= quit_after:
		_finish()


func _flush_atlas() -> void:
	if _atlas == null:
		return
	_atlas.save_jpg("%s/clip_%02d.jpg" % [out, (_frame - 1) / CLIP_PER], 0.85)
	_atlas = null


func _finish() -> void:
	set_process(false)
	_flush_atlas()
	if not _sheet_tiles.is_empty():
		var cols := 4
		var rows := int(ceil(_sheet_tiles.size() / float(cols)))
		var sheet := Image.create(TILE.x * cols, TILE.y * rows, false, Image.FORMAT_RGB8)
		for i in _sheet_tiles.size():
			var tile := _sheet_tiles[i]
			tile.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, TILE), Vector2i((i % cols) * TILE.x, (i / cols) * TILE.y))
		sheet.save_png(out + "/sheet.png")
	_log.append("clip %d frames at %.1f fps, %dx%d, %d to an atlas" % [_frame, fps, CLIP.x, CLIP.y, CLIP_PER])
	_log.append("frames %d, mean %.2f ms, worst %.2f ms" % [_frames, _sum_ms / maxf(1.0, _frames), _worst_ms])
	_log.append("draw calls (last frame) %d" % RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var f := FileAccess.open(out + "/timing.txt", FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	print("film_capture: %d stills, %d clip frames -> %s" % [_done_stills, _frame, out])
	get_tree().quit(0)
