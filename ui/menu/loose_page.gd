## A loose page of her journal, laid over the world at a station she uses
## with E: the stillroom, a stall, the whorl stones, the easel. One sheet of
## paper centred on a scrim, a column to write in, a heading row and key caps
## at its foot. The station owns what is written on the page and its place on
## ScreenStack; this owns how every loose page looks, so no station builds a
## scrim, a card or a footer of its own. Looks come from JournalTheme only.
## Each page carries one mark of the journal it came from: a dab of her
## watercolour under its name, in the station's own wash.
class_name LoosePage
extends RefCounted

## The paper's theme variation.
const SHEET := &"LoosePage"
## The dab under a page's name: how wide, and how far it sits up and left of
## the first letter (inside the paper's edge).
const DAB := 92.0
const DAB_AT := Vector2(-12.0, -14.0)
## The dab's paint is laid on thicker than a blot behind a drawing (the wash
## texture is thin at its thickest), so the heading's colour reads at a glance.
const DAB_LIFT := 1.5

var root: Control
var sheet: PanelContainer
var column: VBoxContainer
## Which of the journal's washes this station's dab is painted in.
var wash: int = 0
var _hints: HBoxContainer


## Lays a page `width` wide on `layer`, hidden or shown by root.visible, with
## its dab in the nth wash.
static func lay(layer: CanvasLayer, width: float, wash_index: int, separation: int = 12) -> LoosePage:
	layer.layer = UiLayers.SCREEN
	var page := LoosePage.new()
	page.wash = wash_index
	page.root = Control.new()
	page.root.name = "Page"
	page.root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(page.root)
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = JournalTheme.color(&"scrim")
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.root.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.root.add_child(center)
	page.sheet = paper()
	page.sheet.custom_minimum_size = Vector2(width, 0)
	page.sheet.pivot_offset = Vector2(width, 0) * 0.5
	center.add_child(page.sheet)
	page.column = VBoxContainer.new()
	page.column.add_theme_constant_override(&"separation", separation)
	page.sheet.add_child(page.column)
	return page


## The paper alone, for a station that places its own sheet (the mare's side
## of the screen, the ride's whole-screen leaf).
static func paper() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Sheet"
	p.theme_type_variation = SHEET
	return p


## A page's name, with the dab of paint under where it starts.
static func heading(text: String, wash_index: int) -> Label:
	var title := BookKit.label(text, &"SatchelHeading")
	var dab := BookKit.wash(DAB, wash_index)
	dab.name = "Dab"
	dab.position = DAB_AT
	dab.modulate.a = DAB_LIFT
	dab.show_behind_parent = true
	title.add_child(dab)
	return title


## The heading row: the page's name, and a small count at its right.
## Returns [name, count].
func head() -> Array[Label]:
	var row := HBoxContainer.new()
	column.add_child(row)
	var title := heading("", wash)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"SatchelChip"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	var count := BookKit.label("", &"SatchelCount")
	chip.add_child(count)
	return [title, count]


## The keys this page answers, as caps along its foot:
## [["E", "Brew"], ["Esc", "Step away"]]. Call again to change them.
func set_hints(pairs: Array) -> void:
	if _hints == null:
		_hints = HBoxContainer.new()
		_hints.name = "Hints"
		_hints.alignment = BoxContainer.ALIGNMENT_CENTER
		_hints.add_theme_constant_override(&"separation", 22)
		column.add_child(_hints)
	for c in _hints.get_children():
		_hints.remove_child(c)
		c.free()
	for p: Array in pairs:
		_hints.add_child(BookKit.key_hint(p[0], p[1]))


## A choice written on the page: a row she can press.
static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"SatchelTab"
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void: Juice.bounce_control(b, 0.06))
	return b


## The small lift a page gives as it is laid down.
func settle() -> void:
	Juice.bounce_control(sheet, 0.05)
