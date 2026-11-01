## Feyre's canvas (L30): a linen-weave ground, brushes that turn with the
## stroke, wet paint that mixes into the brush, and undo. Pure model, no UI:
##   begin(pos, color) -> drag(pos)... -> end()
class_name StudioCanvas
extends RefCounted

signal changed

const WIDTH := 1024
const HEIGHT := 768
## Brush radii in canvas pixels (before the brush's own size_scale).
const SIZES: Array[int] = [5, 10, 20, 38]
const UNDO_DEPTH := 12
const LINEN := Color(0.95, 0.92, 0.85)
## Share of the brush's own paint it takes back per dab while picking up.
const RELOAD := 0.2
const WIP_DIR := "user://paintings"
const BRUSH_DIR := "res://data/studio/brushes"
const BRUSH_ORDER: Array[StringName] = [&"round", &"flat", &"bristle", &"wash", &"sparkle"]

static var _linen: Image = null

var image: Image
var brush: StudioBrushData
var size_index: int = 1
## Finished strokes on this canvas.
var strokes: int = 0
var painting: bool = false

var _undo: Array[Image] = []
var _load := Color.BLACK
var _carry := Color.BLACK
var _last := Vector2.ZERO
var _dir: float = 0.0
var _travel: float = 0.0
var _src: Image = null
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	image = linen().duplicate()
	brush = brushes()[0]


static func brushes() -> Array[StudioBrushData]:
	var out: Array[StudioBrushData] = []
	for id in BRUSH_ORDER:
		out.append(load("%s/%s.tres" % [BRUSH_DIR, id]) as StudioBrushData)
	return out


## The bare canvas: cream linen with a fine weave and a little tooth.
static func linen() -> Image:
	if _linen:
		return _linen
	var tile := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in 32:
		for x in 32:
			# Over-under threads: warp on even cells, weft on odd.
			var warp := 0.5 + 0.5 * sin(x * PI * 0.5)
			var weft := 0.5 + 0.5 * sin(y * PI * 0.5)
			var over := warp if ((x >> 1) + (y >> 1)) % 2 == 0 else weft
			var shade := 0.94 + over * 0.06 + rng.randf_range(-0.015, 0.015)
			tile.set_pixel(x, y, Color(LINEN.r * shade, LINEN.g * shade, LINEN.b * shade, 1.0))
	_linen = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for ty in range(0, HEIGHT, 32):
		for tx in range(0, WIDTH, 32):
			_linen.blit_rect(tile, Rect2i(0, 0, 32, 32), Vector2i(tx, ty))
	return _linen


func radius() -> int:
	return maxi(int(SIZES[clampi(size_index, 0, SIZES.size() - 1)] * brush.size_scale), 2)


func begin(pos: Vector2, color: Color) -> void:
	_undo.append(image.duplicate())
	if _undo.size() > UNDO_DEPTH:
		_undo.pop_front()
	_load = Color(color, 1.0)
	_carry = _load
	_last = pos
	_travel = 0.0
	painting = true
	_dab(pos)
	changed.emit()


func drag(pos: Vector2) -> void:
	if not painting:
		return
	var delta := pos - _last
	var dist := delta.length()
	if dist < 0.5:
		return
	_dir = lerp_angle(_dir, delta.angle(), 0.5)
	var step := maxf(radius() * brush.spacing, 1.0)
	var t := step - _travel
	while t <= dist:
		_dab(_last + delta * (t / dist))
		t += step
	_travel = dist - (t - step)
	_last = pos
	changed.emit()


func end() -> void:
	if not painting:
		return
	painting = false
	strokes += 1
	changed.emit()


func can_undo() -> bool:
	return not _undo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	image = _undo.pop_back()
	strokes = maxi(strokes - 1, 0)
	changed.emit()
	return true


## One footprint of paint at `at` (canvas pixels).
func _dab(at: Vector2) -> void:
	var r := radius()
	if brush.pickup > 0.0:
		var p := Vector2i(clampi(int(at.x), 0, WIDTH - 1), clampi(int(at.y), 0, HEIGHT - 1))
		# Wet-in-wet: the brush picks up what was on the canvas before this
		# stroke (its own fresh paint doesn't count), then reloads a little.
		var before: Image = _undo.back() if not _undo.is_empty() else image
		var under := before.get_pixel(p.x, p.y)
		if PigmentMix.distance(under, LINEN) > 0.08:
			_carry = PigmentMix.mix(_carry, under, brush.pickup)
		_carry = PigmentMix.mix(_carry, _load, RELOAD)
	var color := _carry
	var angle := _dir
	if brush.shape == StudioBrushData.Shape.SPARKLE:
		color = _load.lerp(Color(1, 1, 1), 0.55)
		angle = _rng.randf() * PI
	var masks := StudioStamps.masks(brush, r, angle)
	var size := r * 2 + 1
	if _src == null or _src.get_width() != size:
		_src = Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Each nested level blends once, so the heart gets `opacity` in total.
	var a := 1.0 - pow(1.0 - clampf(brush.opacity, 0.0, 0.99), 1.0 / masks.size())
	_src.fill(Color(color, a))
	var dst := Vector2i(int(at.x) - r, int(at.y) - r)
	for m: Image in masks:
		image.blend_rect_mask(_src, m, Rect2i(0, 0, size, size), dst)


# --- Work in progress, kept per easel between visits ------------------------

static func wip_path(key: String) -> String:
	return "%s/wip_%s.png" % [WIP_DIR, key.validate_filename()]


func save_wip(key: String) -> void:
	DirAccess.make_dir_recursive_absolute(WIP_DIR)
	image.save_png(wip_path(key))


func load_wip(key: String) -> bool:
	var path := wip_path(key)
	if not FileAccess.file_exists(path):
		return false
	var img := Image.load_from_file(path)
	if img == null or img.get_size() != Vector2i(WIDTH, HEIGHT):
		return false
	img.convert(Image.FORMAT_RGBA8)
	image = img
	strokes = 1
	changed.emit()
	return true


static func clear_wip(key: String) -> void:
	DirAccess.remove_absolute(wip_path(key))
