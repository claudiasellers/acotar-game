## Her paint tin, opened out along the foot of the screen at a place where
## she works with her hands: the mare's side, a brewing bench (owner,
## 2026-11-26: "The Open Tin"). The book is where she reads; the tin is where
## she does, so the world stays on screen above it. It is the quick strap's
## tin at a station's size: a tray of ink with a brass rim and her whorl,
## round pans to choose with (the chosen one stands proud and is named on a
## tag over the tray's edge), wells of her paper set into it for what she
## reads and presses, a lid of paper standing at its left end for a longer
## read, and a slip above its right end. A station owns what goes in the tin
## and its place on ScreenStack; this owns how every tin looks, so no station
## builds a tray, a well, a lid or a key cap of its own. Looks come from
## JournalTheme only.
class_name OpenTin
extends Control

## How far the tray keeps from the screen's sides and its foot.
const EDGE := Vector2(28, 26)
## The tallest a tray may stand, so the world above it stays clear.
const MAX_HEIGHT := 350.0
## The flat drop under the tray, as the strap's tin has.
const DROP := 8.0
## The hairline inside the rim, and her whorl in the top right corner.
const HAIRLINE_IN := 6.0
const WHORL_AT := Vector2(38, 34)
const WHORL_R := 13.0
## How far a well in the last compartment stays from the tray's right side, so
## her whorl sits on the tin.
const WHORL_ROOM := 30
## Between compartments: the rule's own room.
const RULE_ROOM := 40.0
## How much of the page scrim a tin lays over a station that stops the world.
const SCRIM_DEPTH := 0.25
## The lid: how far in from the tray's end it stands, how far it sits into
## the tray's rim, the tallest it stands, and its hinges.
const LID_IN := 18.0
const LID_SEAT := 3.0
const LID_MAX := 640.0
const HINGE := Vector2(46, 22)
const HINGE_IN := 48.0
## The slip: how far above the tray it floats.
const SLIP_UP := 22.0

var tray: Tray
## The tray's compartments, left to right.
var row: HBoxContainer
var _tag: Label
var _named: Pan
var _lid: PanelContainer
var _slip: PanelContainer
var _hinges: Hinges


## Lays a tin over `parent` (a station's CanvasLayer or its own full-screen
## Control). `dim` lays a thin scrim behind it, for a station that stops the
## world; a station the world keeps turning under takes none.
static func lay(parent: Node, dim: bool = false) -> OpenTin:
	if parent is CanvasLayer:
		(parent as CanvasLayer).layer = UiLayers.SCREEN
	var tin := OpenTin.new()
	tin.name = "Tin"
	parent.add_child(tin)
	if dim:
		var scrim := ColorRect.new()
		scrim.name = "Scrim"
		var tint := JournalTheme.color(&"scrim")
		scrim.color = Color(tint, tint.a * SCRIM_DEPTH)
		scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tin.add_child(scrim)
		tin.move_child(scrim, 0)
	return tin


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray = Tray.new()
	tray.name = "Tray"
	add_child(tray)
	row = HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override(&"separation", 0)
	tray.add_child(row)
	_hinges = Hinges.new()
	_hinges.tin = self
	add_child(_hinges)
	_tag = BookKit.label("", &"TinTag")
	_tag.name = "Tag"
	_tag.uppercase = true
	_tag.visible = false
	add_child(_tag)


## A compartment of the tray, `width` wide (0: it takes what is left), with a
## rule between it and the one before.
func compartment(width: float = 0.0, separation: int = 8) -> VBoxContainer:
	if row.get_child_count() > 0:
		row.add_child(Rule.new())
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", separation)
	if width > 0.0:
		col.custom_minimum_size.x = width
	else:
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	return col


## The station's name, and a count line under it. Returns [name, count].
static func head(into: Control, title: String, sub: String = "") -> Array[Label]:
	var name_label := BookKit.label(title, &"TinTitle")
	name_label.name = "Title"
	into.add_child(name_label)
	var count := BookKit.label(sub, &"TinSub")
	count.name = "Sub"
	count.visible = sub != ""
	into.add_child(count)
	return [name_label, count]


## A group's name on the tin, in foil capitals.
static func section(text: String) -> Label:
	var l := BookKit.label(text, &"TinSection")
	l.uppercase = true
	return l


## Words on the tin itself, in its ivory.
static func words(text: String, wrap: bool = false) -> Label:
	return BookKit.label(text, &"TinLabel", wrap)


## A rule between two groups inside one compartment.
static func rule() -> Control:
	return Rule.new()


## A round choice: a tab, an ingredient, a treat. `icon` is its picture.
static func pan(icon: Control, text: String, small: bool = false) -> Pan:
	return Pan.new(icon, text, small)


## An ivory tile set into the tin; `chosen` rings it in gold.
static func well(chosen: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"TinWellChosen" if chosen else &"TinWell"
	return p


## A choice she presses, in a well or on the lid. It wears the chosen ring
## while it will work; `disabled` takes the ring off and fades it.
static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = JournalTheme.TIN_ACT
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void: Juice.bounce_control(b, 0.06))
	return b


## Key caps on the tin: [["Esc", "Step away"]]. A paper cap with an inked
## letter, so it reads on the dark.
static func hints(pairs: Array) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = "Hints"
	line.add_theme_constant_override(&"separation", 22)
	for p: Array in pairs:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override(&"separation", 10)
		var cap := BookKit.key_cap(p[0])
		cap.theme_type_variation = &"TinKey"
		(cap.get_node("Key") as Label).theme_type_variation = &"TinKeyLabel"
		pair.add_child(cap)
		var word := BookKit.label(p[1], &"TinHint")
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(word)
		line.add_child(pair)
	return line


## The one thing a well is for, full width, with its key in it: [E] Brew.
## Its cap and word are the child "Row".
static func key_button(key: String, word: String) -> Button:
	var b := button("")
	b.custom_minimum_size.y = 46
	var line := BookKit.key_hint(key, word)
	line.name = "Row"
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in line.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(line)
	return b


## A key cap and its word that can also be pressed with the mouse.
static func hint_button(key: String, word: String) -> Button:
	var b := Button.new()
	b.name = "HintButton"
	b.theme_type_variation = JournalTheme.TIN_PAN
	b.focus_mode = Control.FOCUS_NONE
	var line := hints([[key, word]])
	b.add_child(line)
	for c in line.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.custom_minimum_size = line.get_combined_minimum_size()
	return b


## Names `chosen` on the tag over the tray's edge (null: no tag).
func name_pan(chosen: Pan) -> void:
	_named = chosen
	_tag.text = chosen.text_name if chosen else ""
	_tag.visible = chosen != null and _tag.text != ""
	_tag.reset_size()
	_place()


## Stands the lid up at the tray's left end, `width` wide, and returns the
## column to write on it. Asked again, it is the same lid, wiped.
func lid(width: float) -> VBoxContainer:
	if _lid == null:
		_lid = _sheet("Lid", width)
		_lid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return _wiped(_lid)


## Puts the lid away.
func drop_lid() -> void:
	if _lid:
		_lid.queue_free()
		_lid = null
		_hinges.queue_redraw()


func has_lid() -> bool:
	return _lid != null


## A slip of paper above the tray's right end, `width` wide; returns its
## column. Asked again, it is the same slip, wiped.
func slip(width: float) -> VBoxContainer:
	if _slip == null:
		_slip = _sheet("Slip", width)
	return _wiped(_slip)


func drop_slip() -> void:
	if _slip:
		_slip.queue_free()
		_slip = null


func has_slip() -> bool:
	return _slip != null


## Where the tray's top edge is: everything above it is the world's.
func clear_height() -> float:
	return tray.position.y


## True where the tin, its lid or its slip is under `at`.
func covers(at: Vector2) -> bool:
	if at.y >= clear_height():
		return true
	for sheet: PanelContainer in [_lid, _slip]:
		if sheet and sheet.get_rect().has_point(at):
			return true
	return false


## The small lift a tin gives as it is opened.
func settle() -> void:
	tray.pivot_offset = Vector2(tray.size.x * 0.5, tray.size.y)
	Juice.bounce_control(tray, 0.03)


func _sheet(sheet_name: String, width: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = sheet_name
	p.theme_type_variation = &"TinLid"
	p.custom_minimum_size.x = width
	add_child(p)
	move_child(p, tray.get_index())
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	p.add_child(scroll)
	var col := VBoxContainer.new()
	col.name = "Column"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 8)
	scroll.add_child(col)
	return p


func _wiped(sheet: PanelContainer) -> VBoxContainer:
	var col := sheet.get_node("Scroll/Column") as VBoxContainer
	for c in col.get_children():
		col.remove_child(c)
		c.queue_free()
	return col


func _process(_delta: float) -> void:
	_place()


## Keeps the lid, the slip and the tag where the tray is.
func _place() -> void:
	var top := tray.position.y
	for sheet: PanelContainer in [_lid, _slip]:
		if sheet == null:
			continue
		var scroll := sheet.get_node("Scroll") as ScrollContainer
		var inside := (scroll.get_child(0) as Control).get_combined_minimum_size().y
		var frame := sheet.get_theme_stylebox(&"panel").get_minimum_size().y
		scroll.custom_minimum_size.y = minf(inside, LID_MAX - frame)
		sheet.reset_size()
	if _lid:
		_lid.position = Vector2(tray.position.x + LID_IN, top - _lid.size.y + LID_SEAT)
	if _slip:
		_slip.position = Vector2(tray.position.x + tray.size.x - _slip.size.x - LID_IN, top - _slip.size.y - SLIP_UP)
	if _named and is_instance_valid(_named) and _named.is_inside_tree():
		var at := _named.disc_centre() + _named.global_position - global_position
		_tag.position = Vector2(clampf(at.x - _tag.size.x * 0.5, tray.position.x, tray.position.x + tray.size.x - _tag.size.x),
				top - _tag.size.y * 0.5)
	_hinges.queue_redraw()


## The tray: ink, a brass rim, a hairline inside it, and the flat drop under
## it.
class Tray extends MarginContainer:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		offset_left = OpenTin.EDGE.x
		offset_right = -OpenTin.EDGE.x
		offset_bottom = -OpenTin.EDGE.y
		grow_vertical = Control.GROW_DIRECTION_BEGIN

	func _ready() -> void:
		var box := get_theme_stylebox(&"panel", &"TinTray")
		add_theme_constant_override(&"margin_left", int(box.content_margin_left))
		add_theme_constant_override(&"margin_right", int(box.content_margin_right))
		add_theme_constant_override(&"margin_top", int(box.content_margin_top))
		add_theme_constant_override(&"margin_bottom", int(box.content_margin_bottom))

	func _draw() -> void:
		var box := get_theme_stylebox(&"panel", &"TinTray") as StyleBoxFlat
		var whole := Rect2(Vector2.ZERO, size)
		var drop := box.duplicate() as StyleBoxFlat
		drop.bg_color = JournalTheme.color(&"leather")
		drop.border_color = drop.bg_color
		draw_style_box(drop, Rect2(Vector2(0, OpenTin.DROP), size))
		draw_style_box(box, whole)
		var hair := box.duplicate() as StyleBoxFlat
		hair.draw_center = false
		hair.set_border_width_all(1)
		hair.border_color = Color(JournalTheme.color(&"glow"), 0.5)
		hair.set_corner_radius_all(maxi(box.corner_radius_top_left - int(OpenTin.HAIRLINE_IN), 0))
		draw_style_box(hair, whole.grow(-OpenTin.HAIRLINE_IN))


## The rule between two compartments: brass, fading at both ends.
class Rule extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.x = OpenTin.RULE_ROOM

	func _draw() -> void:
		var line := Color(JournalTheme.color(&"line"), 0.8)
		var clear := Color(line, 0.0)
		var x := size.x * 0.5
		draw_polyline_colors(
				PackedVector2Array([Vector2(x, 0), Vector2(x, size.y * 0.12), Vector2(x, size.y * 0.88), Vector2(x, size.y)]),
				PackedColorArray([clear, line, line, clear]), 2.0, true)


## What lies over the tray and its sheets: her whorl stamped into the tray's
## top right corner, and the lid's two brass hinges over the seam where it
## meets the tray.
class Hinges extends Control:
	var tin: OpenTin

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if tin == null:
			return
		var stamp := tin.tray.position + Vector2(tin.tray.size.x - OpenTin.WHORL_AT.x, OpenTin.WHORL_AT.y)
		WhorlInk.ink_whorl(self, stamp, OpenTin.WHORL_R, Color(JournalTheme.color(&"glow"), 0.9), 2.5)
		if tin._lid == null:
			return
		var lid_rect := tin._lid.get_rect()
		var brass := StyleBoxFlat.new()
		brass.bg_color = JournalTheme.color(&"line")
		brass.set_corner_radius_all(5)
		brass.anti_aliasing = true
		var y := tin.tray.position.y - OpenTin.HINGE.y * 0.5
		for x: float in [lid_rect.position.x + OpenTin.HINGE_IN, lid_rect.end.x - OpenTin.HINGE_IN - OpenTin.HINGE.x]:
			draw_style_box(brass, Rect2(Vector2(x, y), OpenTin.HINGE))


## One pan: a disc of her paper with a brass rim and a dab of wash under its
## picture, its name under it. Chosen, it grows, takes a gold rim and stands
## proud, and the tin names it on the tag instead. A small pan is an
## ingredient or a treat: a count at its lower right, "in the pot" across it
## when it is, faint when it is only wished for.
class Pan extends Button:
	const DISC := 82.0
	const DISC_CHOSEN := 96.0
	const DISC_SMALL := 70.0
	const ICON := 54.0
	const ICON_SMALL := 46.0
	## How far the chosen pan stands proud, and the room that leaves above.
	const PROUD := 14.0
	const STEP := 110.0
	const STEP_SMALL := 88.0
	## Room under a small pan for the count that hangs off its rim.
	const COUNT_ROOM := 8.0
	const NAME_GAP := 4.0
	const RIM := 3.0
	const RIM_CHOSEN := 5.0
	const RIM_POT := 4.0
	const IN_POT_ALPHA := 0.4
	const WISHED_ALPHA := 0.45

	var text_name: String
	var small: bool
	## Which of her washes is dabbed under the picture.
	var wash: int = 0:
		set(v):
			wash = v
			queue_redraw()
	## An ingredient that is in the pot.
	var in_pot: bool = false:
		set(v):
			in_pot = v
			_lay()
	## A treat she likes but has none of.
	var wished: bool = false:
		set(v):
			wished = v
			disabled = v
			modulate.a = WISHED_ALPHA if v else 1.0

	var _icon: Control
	var _label: Label
	var _count: Label
	var _pot: Label

	func _init(icon: Control, text: String, is_small: bool) -> void:
		text_name = text
		small = is_small
		theme_type_variation = JournalTheme.TIN_PAN
		toggle_mode = not is_small
		focus_mode = Control.FOCUS_ALL
		_icon = icon
		if _icon:
			_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_icon)
		_label = BookKit.label(text, &"TinLabel")
		_label.name = "Name"
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_label)
		_label.reset_size()
		var disc := DISC_SMALL if small else DISC
		var step := maxf(STEP_SMALL if small else STEP, _label.size.x + 8.0)
		var names := _label.size.y + NAME_GAP if text != "" else 0.0
		custom_minimum_size = Vector2(step, (COUNT_ROOM if small else PROUD) + disc + names)
		toggled.connect(func(_on: bool) -> void: _lay())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		resized.connect(_lay)
		_lay()

	## How many she has of it, on a chip at the pan's lower right ("" for none).
	func count(text: String) -> void:
		if _count == null:
			_count = BookKit.count_badge()
			_count.name = "Count"
			add_child(_count)
		_count.text = text
		_count.visible = text != ""
		_count.reset_size()
		_lay()

	## How tall a small pan with no name is.
	static func small_height() -> float:
		return DISC_SMALL + COUNT_ROOM

	## The middle of the disc, in the pan's own space.
	func disc_centre() -> Vector2:
		var seat := Vector2(size.x * 0.5, (0.0 if small else PROUD) + (DISC_SMALL if small else DISC) * 0.5)
		return seat - Vector2(0, PROUD - (DISC_CHOSEN - DISC) * 0.5) if _chosen() else seat

	func radius() -> float:
		return (DISC_CHOSEN if _chosen() else (DISC_SMALL if small else DISC)) * 0.5

	## Marks it the chosen pan, or not, without pressing it.
	func choose(on: bool) -> void:
		set_pressed_no_signal(on)
		_lay()

	func _chosen() -> bool:
		return toggle_mode and button_pressed

	func _lay() -> void:
		var c := disc_centre()
		if _icon:
			var px := ICON_SMALL if small else ICON
			_icon.custom_minimum_size = Vector2(px, px)
			_icon.size = Vector2(px, px)
			_icon.position = c - Vector2(px, px) * 0.5
			_icon.modulate.a = IN_POT_ALPHA if in_pot else 1.0
		_label.visible = not _chosen() and text_name != ""
		_label.position = Vector2((size.x - _label.size.x) * 0.5, size.y - _label.size.y)
		if _count:
			_count.position = c + Vector2(radius() * 0.35, radius() * 0.35)
		if in_pot and _pot == null:
			_pot = BookKit.label("in the pot", &"TinName")
			_pot.name = "InPot"
			add_child(_pot)
			_pot.reset_size()
		if _pot:
			_pot.visible = in_pot
			_pot.position = c - _pot.size * 0.5
		queue_redraw()

	func _draw() -> void:
		var c := disc_centre()
		var r := radius()
		var glow := JournalTheme.color(&"glow")
		var rim := RIM
		var rim_colour := JournalTheme.color(&"line")
		if _chosen():
			rim = RIM_CHOSEN
			rim_colour = glow
		elif in_pot:
			rim = RIM_POT
			rim_colour = glow
		elif is_hovered() and not disabled:
			rim_colour = glow
		# What the pad is on wears the chosen ring, a little out from the disc.
		if has_focus():
			draw_arc(c, r + 5.0, 0.0, TAU, 64, glow, 3.0, true)
		draw_circle(c, r, rim_colour, true, -1.0, true)
		draw_circle(c, r - rim, JournalTheme.color(&"paper"), true, -1.0, true)
		draw_circle(c, r - rim - 6.0, Color(JournalTheme.wash(wash), 0.75), true, -1.0, true)
