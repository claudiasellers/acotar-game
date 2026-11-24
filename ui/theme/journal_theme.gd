## Feyre's Journal: the one look of every menu, card and HUD piece. Every
## colour, font and size in the UI is a token here, and the one Theme built
## from them is the project-wide theme (project.godot, gui/theme/custom), so a
## Control anywhere in the game wears it with no code.
##
## Two token sets, as the story has two palettes: the human realm (Act I,
## sparse and worn) and the Spring Court. apply() rewrites the live project
## theme in place when the story crosses the Wall.
## Contract: docs/contracts/ui-theme.md.
class_name JournalTheme
extends RefCounted

enum Act { HUMAN, SPRING }

const THEME_PATH := "res://ui/theme/journal_theme.tres"
## Theme colours are read from this type: get_theme_color(&"ink", &"Journal").
const COLOR_TYPE := &"Journal"
## Phases before the wall crossing use the human-realm tokens.
const HUMAN_PHASES: Array[String] = ["p0", "p1"]

const FONT_DISPLAY := "res://ui/theme/fonts/Marcellus.ttf"
const FONT_BODY := "res://ui/theme/fonts/Nunito.ttf"
const FONT_HAND := "res://ui/theme/fonts/CormorantI.ttf"
const PAPER_PAGE := "res://ui/theme/paper/page.png"
const PAPER_SLIP := "res://ui/theme/paper/slip.png"

const COLORS := {
	Act.HUMAN: {
		&"paper": Color("#ebe5d8"),  # the page
		&"paper_deep": Color("#dcd2bf"),  # a page under a page
		&"ink": Color("#2f2a33"),  # type
		&"ink_soft": Color("#5a5256"),  # small type (6.0 to 1 on the page)
		&"accent": Color("#b98a3a"),  # her one tin of yellow paint
		&"glow": Color("#e3c35a"),  # what is chosen
		&"rare": Color("#8e7aa8"),
		&"danger": Color("#8e2a2a"),
		&"line": Color("#8a6f4a"),  # tarnished brass: rules, rims, stitching
		&"leather": Color("#5a4332"),  # straps and covers
		&"scrim": Color(0.09, 0.08, 0.10, 0.55),  # the dim behind a page
	},
	Act.SPRING: {
		&"paper": Color("#f6f0e3"),
		&"paper_deep": Color("#ece2cc"),
		&"ink": Color("#3a2f4a"),
		&"ink_soft": Color("#5b4f6b"),
		&"accent": Color("#d9577f"),
		&"glow": Color("#e8c14a"),
		&"rare": Color("#cbbaf0"),
		&"danger": Color("#8e2a45"),
		&"line": Color("#b08c4a"),
		&"leather": Color("#7a2238"),
		&"scrim": Color(0.10, 0.06, 0.12, 0.55),
	},
}

## The horror palette (R3: horror is never dressed up as the pretty UI). The
## same in both acts; only the Bogge's whisper and the Suriel's voice wear it.
const HORROR := {
	&"bone": Color(0.90, 0.88, 0.80),
	&"pall": Color(0.03, 0.03, 0.04),
	&"blood": Color(0.25, 0.0, 0.02),
}

## The pastel washes she paints with: one per index tab of the book, and the
## blot behind a thing drawn on a page. The same in both acts.
const WASHES: Array[Color] = [
	Color("#f4c6d4"), Color("#d9c9f4"), Color("#bfe6cf"), Color("#f3e2a4"), Color("#bcd3f0"),
]

## Label variation -> [size, font: "display" | "body" | "hand", weight, colour token]
const LABELS := {
	&"SatchelHeading": [34, "display", 400, &"ink"],
	&"MenuTitle": [40, "display", 400, &"ink"],
	&"PageSection": [18, "display", 400, &"ink_soft"],
	&"SatchelBody": [20, "body", 500, &"ink"],
	&"SatchelSmall": [16, "body", 700, &"ink"],
	&"SatchelWhere": [20, "hand", 500, &"ink_soft"],
	&"SatchelKeyLabel": [16, "body", 800, &"paper"],
	&"QuickBarKey": [15, "body", 800, &"ink_soft"],
	&"QuickBarCount": [15, "body", 800, &"ink"],
	&"NotifyText": [20, "body", 600, &"ink"],
	&"ThoughtText": [26, "hand", 600, &"ink"],
	&"ReadText": [30, "hand", 600, &"ink"],
	&"LineSaid": [24, "body", 600, &"paper"],
	&"LineName": [23, "display", 400, &"glow"],
	&"LineTold": [34, "hand", 600, &"paper"],
	&"LineWhisper": [40, "hand", 600, &"bone"],
	&"LineDread": [28, "display", 400, &"bone"],
	&"PromptText": [20, "body", 700, &"paper"],
	&"PromptKeyLabel": [17, "body", 800, &"ink"],
	&"NoticeKicker": [14, "body", 800, &"glow"],
	&"NoticeTitle": [32, "hand", 600, &"paper"],
	&"NoticeBody": [17, "body", 600, &"paper"],
	&"ChapterTitle": [44, "display", 400, &"paper"],
}
const PANELS: Array[StringName] = [
	&"SatchelCard", &"LoosePage", &"NotifyCard", &"LineBand", &"LineFlood", &"LineBare", &"ThoughtMark", &"SatchelChip", &"SatchelKey",
	&"PromptPill", &"PromptKey", &"NoticeCard", &"NoticeRare",
	&"QuickBarSlot", &"QuickBarSlotSelected",
]
const BUTTONS: Array[StringName] = [&"SatchelTab", &"MenuTab", &"SatchelSlot"]
## An index tab along the top of the book. White, so each wears its own wash.
const INDEX_TAB := &"BookTab"
## The page that hangs from the book's ribbon, at its foot (settings).
const RIBBON_TAB := &"BookRibbon"
## Side of a check box and of a slider's knob, in px.
const CHECK_SIZE := 24
const KNOB_SIZE := 22
## How dark the pills that sit on the world are: prompts and notices.
const PILL_DEPTH := 0.88
## How dark the smear behind a said line is, and how far its edge fades.
const BAND_DEPTH := 0.8
const SMEAR_EDGE := 40
## How far the Suriel's black reaches past its words: off every screen.
const FLOOD_REACH := 4000
## How far above its words the black thins out, in px.
const FLOOD_RISE := 90
const BUTTON_STATES: Array[StringName] = [
	&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus",
]

static var _smear_cache: ImageTexture


static func is_human_realm() -> bool:
	var pm := _autoload(^"PhaseManager")
	var phase := String(pm.get(&"current_phase")) if pm else ""
	return phase == "" or HUMAN_PHASES.any(func(p: String) -> bool: return phase.begins_with(p + "_"))


static func act() -> Act:
	return Act.HUMAN if is_human_realm() else Act.SPRING


## A colour token for the act the story is in.
static func color(token: StringName) -> Color:
	return COLORS[act()][token]


static func colors(of_act: Act) -> Dictionary:
	return COLORS[of_act]


## The wash for the nth thing in a row (tabs, slots), going round.
static func wash(i: int) -> Color:
	return WASHES[posmod(i, WASHES.size())]


## A font of the journal at a weight ("display" has one weight).
static func font(face: String, weight: int = 500) -> Font:
	var file := load({"display": FONT_DISPLAY, "body": FONT_BODY, "hand": FONT_HAND}[face]) as Font
	if face == "display":
		return file
	var cut := FontVariation.new()
	cut.base_font = file
	# Keyed by the tag's number: a name as the key is silently ignored.
	cut.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return cut


## Rewrites the live project theme for the act the story is in.
static func apply() -> void:
	var live := ThemeDB.get_project_theme()
	if live == null:
		return
	# No clear(): it drops the old fonts while Labels already on screen (the
	# menu shell lives at root once opened) still hold them, and the engine
	# logs 'Parameter "fd" is null' for each. Both acts set the same keys,
	# so merging over the live theme replaces every one in place.
	live.merge_with(build(act()))


## Keeps the project theme in step with the story. Called once, by ScreenStack.
static func follow_story() -> void:
	var bus := _autoload(^"EventBus")
	if bus:
		bus.connect(&"phase_changed", func(_previous: StringName, _current: StringName) -> void: apply())
	apply()


## Autoloads by path, so the theme builds in a tool script that has none.
static func _autoload(path: NodePath) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(path) if tree else null


static func build(of_act: Act) -> Theme:
	var c: Dictionary = (COLORS[of_act] as Dictionary).merged(HORROR)
	var t := Theme.new()
	t.default_font = font("body", 500)
	t.default_font_size = 20
	for token: StringName in c:
		t.set_color(token, COLOR_TYPE, c[token])
	t.set_color(&"font_color", &"Label", c.ink)

	for v in PANELS:
		t.set_type_variation(v, &"PanelContainer")
	t.set_stylebox(&"panel", &"SatchelCard", _paper(PAPER_PAGE, c.paper, 40, 28))
	t.set_stylebox(&"panel", &"LoosePage", _paper(PAPER_PAGE, c.paper_deep, 40, 26))
	t.set_stylebox(&"panel", &"NotifyCard", _paper(PAPER_SLIP, c.paper, 20, 14))
	t.set_stylebox(&"panel", &"LineBand", _smear(Color(c.ink, BAND_DEPTH)))
	t.set_stylebox(&"panel", &"LineFlood", _flood(c.pall))
	var bare := StyleBoxEmpty.new()
	bare.set_content_margin_all(12)
	t.set_stylebox(&"panel", &"LineBare", bare)
	t.set_stylebox(&"panel", &"ThoughtMark", _pill(c.ink, c.line, 2, Vector2(12, 12), 14))
	t.set_stylebox(&"panel", &"SatchelChip", _pill(c.paper_deep, Color(c.line, 0.7), 1, Vector2(12, 3)))
	t.set_stylebox(&"panel", &"SatchelKey", _pill(c.ink, c.line, 1, Vector2(12, 5), 8))
	# What sits on the world, not on paper: dark pills, so they read on snow.
	t.set_stylebox(&"panel", &"PromptPill", _pill(Color(c.ink, PILL_DEPTH), Color(c.line, 0.8), 1, Vector2(14, 8)))
	t.set_stylebox(&"panel", &"PromptKey", _pill(c.paper, c.line, 1, Vector2(10, 2), 8))
	t.set_stylebox(&"panel", &"NoticeCard", _pill(Color(c.ink, PILL_DEPTH), Color(c.line, 0.8), 1, Vector2(22, 14), 20))
	t.set_stylebox(&"panel", &"NoticeRare", _pill(Color(c.ink, PILL_DEPTH), c.glow, 3, Vector2(22, 14), 20))
	t.set_stylebox(&"panel", &"QuickBarSlot", _pill(Color(c.paper, 0.92), c.line, 2, Vector2(6, 6)))
	t.set_stylebox(&"panel", &"QuickBarSlotSelected", _pill(c.paper, c.glow, 3, Vector2(6, 6)))

	for v in BUTTONS:
		t.set_type_variation(v, &"Button")
		if v == &"SatchelSlot":
			# A thing drawn on the page: no box until it is pointed at or chosen.
			t.set_stylebox(&"normal", v, _arch(Color(c.paper, 0.0), Color(c.line, 0.0), 0))
			t.set_stylebox(&"hover", v, _arch(Color(c.paper_deep, 0.6), Color(c.line, 0.5), 1))
			t.set_stylebox(&"pressed", v, _arch(Color(c.glow, 0.16), c.glow, 3))
			t.set_stylebox(&"hover_pressed", v, _arch(Color(c.glow, 0.22), c.glow, 3))
			t.set_stylebox(&"disabled", v, _arch(Color(c.paper, 0.0), Color(c.line, 0.0), 0))
			t.set_stylebox(&"focus", v, _arch(Color(c.glow, 0.0), c.glow, 3))
		else:
			var pad := Vector2(15, 7)
			t.set_stylebox(&"normal", v, _pill(c.paper, Color(c.line, 0.55), 1, pad))
			t.set_stylebox(&"hover", v, _pill(c.paper_deep, c.line, 1, pad))
			t.set_stylebox(&"pressed", v, _pill(c.ink, c.glow, 2, pad))
			t.set_stylebox(&"hover_pressed", v, _pill(c.ink, c.glow, 2, pad))
			t.set_stylebox(&"disabled", v, _pill(Color(c.paper, 0.4), Color(c.line, 0.2), 1, pad))
			var ring := _pill(Color(0, 0, 0, 0), c.glow, 2, pad)
			ring.draw_center = false
			t.set_stylebox(&"focus", v, ring)
		t.set_font(&"font", v, font("body", 700))
		t.set_font_size(&"font_size", v, 17)
		for state in [&"font_color", &"font_hover_color", &"font_focus_color"]:
			t.set_color(state, v, c.ink)
		for state in [&"font_pressed_color", &"font_hover_pressed_color"]:
			t.set_color(state, v, c.paper)
		t.set_color(&"font_disabled_color", v, Color(c.ink, 0.35))
	for state in [&"font_pressed_color", &"font_hover_pressed_color"]:
		t.set_color(state, &"SatchelSlot", c.ink)

	t.set_type_variation(INDEX_TAB, &"Button")
	for state in BUTTON_STATES:
		var on: bool = state in [&"pressed", &"hover_pressed"]
		t.set_stylebox(state, INDEX_TAB, _index_tab(c.paper if on else Color.WHITE, 16.0 if on else (4.0 if state == &"hover" else 0.0)))
	t.set_stylebox(&"focus", INDEX_TAB, StyleBoxEmpty.new())
	t.set_font(&"font", INDEX_TAB, font("display"))
	t.set_font_size(&"font_size", INDEX_TAB, 19)
	for state in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		t.set_color(state, INDEX_TAB, c.ink)

	t.set_type_variation(RIBBON_TAB, &"Button")
	for state in BUTTON_STATES:
		var on: bool = state in [&"pressed", &"hover_pressed"]
		t.set_stylebox(state, RIBBON_TAB, _ribbon_tab(c.paper if on else (c.leather.lightened(0.12) if state == &"hover" else c.leather), c.line))
	t.set_stylebox(&"focus", RIBBON_TAB, StyleBoxEmpty.new())
	t.set_font(&"font", RIBBON_TAB, font("display"))
	t.set_font_size(&"font_size", RIBBON_TAB, 17)
	for state in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		t.set_color(state, RIBBON_TAB, c.paper)
	for state in [&"font_pressed_color", &"font_hover_pressed_color"]:
		t.set_color(state, RIBBON_TAB, c.ink)

	# A setting on a page: an inked box that fills when it is on, and a brass
	# rule with a knob. Focus is the same gold ring the chips wear.
	var no_box := StyleBoxEmpty.new()
	no_box.set_content_margin_all(4)
	for state in [&"normal", &"pressed", &"hover", &"hover_pressed", &"disabled"]:
		t.set_stylebox(state, &"CheckBox", no_box)
	var check_ring := _pill(Color(0, 0, 0, 0), c.glow, 2, Vector2(4, 4), 10)
	check_ring.draw_center = false
	t.set_stylebox(&"focus", &"CheckBox", check_ring)
	for state in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		t.set_color(state, &"CheckBox", c.ink)
	t.set_icon(&"unchecked", &"CheckBox", _check_box(false, c.ink, c.paper))
	t.set_icon(&"checked", &"CheckBox", _check_box(true, c.ink, c.paper))
	t.set_constant(&"h_separation", &"CheckBox", 10)
	# A line to write on: the easel's title.
	t.set_stylebox(&"normal", &"LineEdit", _pill(c.paper, Color(c.line, 0.7), 1, Vector2(12, 6), 10))
	t.set_stylebox(&"focus", &"LineEdit", _pill(c.paper, c.accent, 2, Vector2(12, 6), 10))
	t.set_color(&"font_color", &"LineEdit", c.ink)
	t.set_color(&"font_placeholder_color", &"LineEdit", c.ink_soft)
	t.set_color(&"caret_color", &"LineEdit", c.ink)
	t.set_stylebox(&"slider", &"HSlider", _pill(Color(c.line, 0.3), Color(0, 0, 0, 0), 0, Vector2(0, 3)))
	for area in [&"grabber_area", &"grabber_area_highlight"]:
		t.set_stylebox(area, &"HSlider", _pill(c.accent, Color(0, 0, 0, 0), 0, Vector2(0, 3)))
	t.set_icon(&"grabber", &"HSlider", _knob(c.paper, c.ink))
	t.set_icon(&"grabber_highlight", &"HSlider", _knob(c.glow, c.ink))
	t.set_icon(&"grabber_disabled", &"HSlider", _knob(c.paper_deep, c.ink_soft))

	for v: StringName in LABELS:
		var spec: Array = LABELS[v]
		t.set_type_variation(v, &"Label")
		t.set_font_size(&"font_size", v, spec[0])
		t.set_font(&"font", v, font(spec[1], spec[2]))
		t.set_color(&"font_color", v, c[spec[3]])
	# Said lines sit on the world, not on paper: a soft drop keeps them read.
	var spaced := FontVariation.new()
	spaced.base_font = font("display")
	spaced.spacing_glyph = 3
	t.set_font(&"font", &"LineName", spaced)
	for v in [&"LineSaid", &"LineName", &"LineTold", &"ChapterTitle"]:
		t.set_color(&"font_shadow_color", v, Color(c.ink, 0.8))
		t.set_constant(&"shadow_offset_x", v, 0)
		t.set_constant(&"shadow_offset_y", v, 1)
		t.set_constant(&"shadow_outline_size", v, 4)
	# The whisper has no sheet at all: it bleeds.
	t.set_color(&"font_shadow_color", &"LineWhisper", Color(c.blood, 0.55))
	t.set_constant(&"shadow_offset_x", &"LineWhisper", 0)
	t.set_constant(&"shadow_offset_y", &"LineWhisper", 0)
	t.set_constant(&"shadow_outline_size", &"LineWhisper", 18)
	# Count and pin sit on their own small chip.
	for v in [&"SatchelCount", &"SatchelPin"]:
		t.set_type_variation(v, &"Label")
		t.set_font(&"font", v, font("body", 800))
		t.set_font_size(&"font_size", v, 16)
		t.set_color(&"font_color", v, c.ink)
		t.set_stylebox(&"normal", v, _pill(c.paper, Color(c.line, 0.8), 1, Vector2(9, 1)))

	# Hairlines and slim scroll bars, everywhere.
	var rule := StyleBoxLine.new()
	rule.color = Color(c.line, 0.45)
	rule.thickness = 1
	t.set_stylebox(&"separator", &"HSeparator", rule)
	t.set_constant(&"separation", &"HSeparator", 6)
	for bar in [&"VScrollBar", &"HScrollBar"]:
		t.set_stylebox(&"scroll", bar, _pill(Color(c.line, 0.12), Color(0, 0, 0, 0), 0, Vector2(4, 4)))
		t.set_stylebox(&"grabber", bar, _pill(Color(c.line, 0.6), Color(0, 0, 0, 0), 0, Vector2(4, 4)))
		t.set_stylebox(&"grabber_highlight", bar, _pill(c.line, Color(0, 0, 0, 0), 0, Vector2(4, 4)))
		t.set_stylebox(&"grabber_pressed", bar, _pill(c.accent, Color(0, 0, 0, 0), 0, Vector2(4, 4)))

	t.set_type_variation(&"SatchelMeter", &"ProgressBar")
	t.set_stylebox(&"background", &"SatchelMeter", _pill(c.paper_deep, Color(c.line, 0.5), 1, Vector2(0, 4)))
	t.set_stylebox(&"fill", &"SatchelMeter", _pill(c.accent, Color(0, 0, 0, 0), 0, Vector2(0, 4)))
	return t


## A sheet of the journal's paper, tinted to a token.
static func _paper(path: String, tint: Color, edge: int, margin: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(path)
	box.set_texture_margin_all(edge)
	box.set_content_margin_all(margin)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.modulate_color = tint
	return box


## The dark behind a line that stands on the world: a smear with no edge, so
## the words read over any ground and nothing looks like a box. Solid under
## the words, fading out past them, all within the sheet's own rect.
static func _smear(tint: Color) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = _smear_texture()
	box.set_texture_margin_all(SMEAR_EDGE)
	box.modulate_color = tint
	# The fade is inside the sheet, so the sheet's own rect is all it covers.
	box.set_content_margin_all(SMEAR_EDGE - 6)
	box.content_margin_left = SMEAR_EDGE + 24
	box.content_margin_right = SMEAR_EDGE + 24
	return box


## The black the Suriel's words write on: no sheet and no corners. It floods
## up from the foot of the screen, edge to edge, and thins out above the words.
static func _flood(pall: Color) -> StyleBoxTexture:
	var rise := Gradient.new()
	rise.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	rise.colors = PackedColorArray([Color(pall, 0.0), Color(pall, 0.9), Color(pall, 0.96)])
	var dark := GradientTexture2D.new()
	dark.gradient = rise
	dark.fill_from = Vector2(0.5, 0.0)
	dark.fill_to = Vector2(0.5, 1.0)
	dark.width = 8
	dark.height = 128
	var box := StyleBoxTexture.new()
	box.texture = dark
	# The fade is the top margin; everything under it is solid, however far.
	box.set_texture_margin(SIDE_TOP, FLOOD_RISE)
	box.set_content_margin_all(14)
	box.set_expand_margin(SIDE_LEFT, FLOOD_REACH)
	box.set_expand_margin(SIDE_RIGHT, FLOOD_REACH)
	box.set_expand_margin(SIDE_TOP, FLOOD_RISE)
	box.set_expand_margin(SIDE_BOTTOM, FLOOD_REACH)
	return box


static func _smear_texture() -> ImageTexture:
	if _smear_cache == null:
		var side := SMEAR_EDGE * 2 + 8
		var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
		for y in side:
			for x in side:
				var out := Vector2(maxf(0.0, SMEAR_EDGE - minf(x, side - 1 - x)), maxf(0.0, SMEAR_EDGE - minf(y, side - 1 - y)))
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 - smoothstep(0.0, 1.0, out.length() / SMEAR_EDGE)))
		_smear_cache = ImageTexture.create_from_image(img)
	return _smear_cache


## A slot on a page: an arch, round at the top like a specimen window.
static func _arch(fill: Color, rim: Color, width: int) -> StyleBoxFlat:
	var box := _pill(fill, rim, width, Vector2(6, 6), 12)
	box.corner_radius_top_left = 999
	box.corner_radius_top_right = 999
	return box


## An index tab: round shoulders, no foot, and `rise` px taller when it is
## the page in front.
static func _index_tab(fill: Color, rise: float) -> StyleBoxFlat:
	var box := _pill(fill, Color(0, 0, 0, 0), 0, Vector2(22, 12), 0)
	box.corner_radius_top_left = 14
	box.corner_radius_top_right = 14
	box.expand_margin_top = rise
	return box


## The ribbon's tab: hangs down from the book's foot, round at the bottom.
static func _ribbon_tab(fill: Color, rim: Color) -> StyleBoxFlat:
	var box := _pill(fill, rim, 1, Vector2(20, 8), 0)
	box.border_width_top = 0
	box.corner_radius_bottom_left = 12
	box.corner_radius_bottom_right = 12
	return box


## A check box drawn in ink: an open square, or a filled one with a tick.
static func _check_box(on: bool, ink: Color, paper: Color) -> ImageTexture:
	var n := CHECK_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var half := n * 0.5 - 1.0
	var tick := PackedVector2Array([Vector2(6.0, 12.5), Vector2(10.5, 17.0), Vector2(18.0, 7.5)])
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			# Distance outside a rounded square (radius 5).
			var q := (p - Vector2(n, n) * 0.5).abs() - Vector2(half - 5.0, half - 5.0)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 5.0
			var inside := clampf(0.5 - d, 0.0, 1.0)
			var rim := inside * clampf(d + 2.5, 0.0, 1.0)
			var col := Color(ink, rim)
			if on:
				var stroke := minf(_to_segment(p, tick[0], tick[1]), _to_segment(p, tick[1], tick[2]))
				col = Color(ink, inside).lerp(Color(paper, inside), clampf(1.7 - stroke, 0.0, 1.0))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## A slider's knob: a flat disc with an inked rim.
static func _knob(fill: Color, rim: Color) -> ImageTexture:
	var n := KNOB_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r := n * 0.5 - 1.0
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length()
			var col := fill.lerp(rim, clampf(d - (r - 2.5), 0.0, 1.0))
			img.set_pixel(x, y, Color(col, clampf(r - d + 0.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0))


## A soft round mote, white so a particle can tint it: sparkles and beacons.
static func soft_dot(size: int = 32) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.45, Color(1, 1, 1, 0.85))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


## A clean flat shape: buttons, chips, key caps. No gradient, glow or bevel.
static func _pill(fill: Color, rim: Color, width: int, pad: Vector2, radius: int = 999) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad.x
	box.content_margin_right = pad.x
	box.content_margin_top = pad.y
	box.content_margin_bottom = pad.y
	box.anti_aliasing = true
	return box
