## One sitting at the easel (L30): the canvas, the paints, the palette and
## what's picked, with no UI. StudioUi drives it; the playtest and tests can
## drive it directly.
class_name StudioSession
extends RefCounted

var canvas: StudioCanvas
var supply: StudioSupply
var palette: StudioPalette
var easel: Node3D
var feyre: Node3D
## Paint picked in the paint box (&"" when a well is picked).
var selected: StringName = &""
## Well picked (-1 when a paint is picked).
var selected_well: int = -1
## Set when the last stroke opened the gallery (the UI celebrates, then clears it).
var opened_gallery: bool = false

# UI hooks (StudioUi sets these).
var layer: CanvasLayer
var canvas_rect: TextureRect
var refresh: Callable
var refresh_needed: bool = false
var dirty: bool = false


func _init(inventory: Inventory, at_easel: Node3D = null, who: Node3D = null) -> void:
	canvas = StudioCanvas.new()
	supply = StudioSupply.new(inventory)
	palette = StudioPalette.new()
	easel = at_easel
	feyre = who
	canvas.load_wip(key())
	canvas.changed.connect(func() -> void: dirty = true)
	var paints := supply.paints()
	select_paint(paints[0].id)


## Names the work in progress after the easel it sits on.
func key() -> String:
	return String(easel.name) if easel else "easel"


func select_paint(id: StringName) -> void:
	selected = id
	selected_well = -1


## A paint picked + a well tapped = mix it in. Returns true when it mixed.
func tap_well(i: int) -> bool:
	if selected != &"" and selected_well == -1:
		if not supply.spend(selected):
			return false
		palette.drop(i, supply.color_of(selected))
		selected = &""
		selected_well = i
		return true
	selected = &""
	selected_well = i
	return false


func current_color() -> Color:
	if selected_well >= 0:
		return palette.wells[selected_well].color
	return supply.color_of(selected)


## Starts a stroke at a canvas pixel. Returns "" or why it can't.
func start_stroke(at: Vector2) -> String:
	if selected_well >= 0:
		if not palette.use(selected_well):
			return "That well's dry. Mix more paint into it."
	elif selected != &"":
		if not supply.spend(selected):
			return "That paint's all used up."
	else:
		return "Pick a paint first."
	canvas.begin(at, current_color())
	if feyre and feyre.is_inside_tree():
		opened_gallery = StudioDeeds.stroke_made(feyre.get_tree()) or opened_gallery
	return ""


func end_stroke() -> void:
	canvas.end()
	refresh_needed = true


## Paints a whole stroke through points (tests, playtest).
func paint_line(points: Array[Vector2]) -> String:
	var why := start_stroke(points[0])
	if why != "":
		return why
	for p in points.slice(1):
		canvas.drag(p)
	end_stroke()
	return ""


func finish(title: String) -> Dictionary:
	var tree := feyre.get_tree() if feyre and feyre.is_inside_tree() else null
	var record := StudioDeeds.finish(canvas, title, tree, easel if easel and easel.is_inside_tree() else null)
	StudioCanvas.clear_wip(key())
	canvas = StudioCanvas.new()
	if easel and easel.is_inside_tree():
		StudioRoom.show_on_easel(easel, canvas.image, _toward())
	return record


## Leaving: keep the work in progress and show it on the easel.
func close() -> void:
	if canvas.strokes > 0:
		canvas.save_wip(key())
	if easel and easel.is_inside_tree():
		StudioRoom.show_on_easel(easel, canvas.image, _toward())


## Once a frame while open: push paint to the screen and the easel.
func tick() -> void:
	if dirty and canvas_rect and is_instance_valid(canvas_rect):
		var tex := canvas_rect.texture as ImageTexture
		if tex:
			tex.update(canvas.image)
		dirty = false
	if refresh_needed and refresh.is_valid():
		refresh_needed = false
		refresh.call()


func _toward() -> Vector3:
	return feyre.global_position if feyre and feyre.is_inside_tree() else easel.global_position + easel.global_basis.z
