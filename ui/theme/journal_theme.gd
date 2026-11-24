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
		&"ink_soft": Color("#6a6266"),  # small type
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
		&"ink_soft": Color("#6b5f7a"),
		&"accent": Color("#d9577f"),
		&"glow": Color("#e8c14a"),
		&"rare": Color("#cbbaf0"),
		&"danger": Color("#8e2a45"),
		&"line": Color("#b08c4a"),
		&"leather": Color("#7a2238"),
		&"scrim": Color(0.10, 0.06, 0.12, 0.55),
	},
}

## Label variation -> [size, font: "display" | "body" | "hand", weight, colour token]
const LABELS := {
	&"SatchelHeading": [30, "display", 400, &"ink"],
	&"MenuTitle": [44, "display", 400, &"ink"],
	&"SatchelBody": [20, "body", 500, &"ink"],
	&"SatchelSmall": [16, "body", 600, &"ink_soft"],
	&"SatchelWhere": [20, "hand", 500, &"ink_soft"],
	&"SatchelKeyLabel": [16, "body", 800, &"paper"],
	&"QuickBarKey": [15, "body", 800, &"ink_soft"],
	&"QuickBarCount": [15, "body", 800, &"ink"],
	&"NotifyText": [20, "body", 600, &"ink"],
	&"ThoughtText": [24, "hand", 500, &"ink"],
}
const PANELS: Array[StringName] = [
	&"SatchelCard", &"SatchelDetail", &"NotifyCard", &"SatchelChip", &"SatchelKey",
	&"QuickBarSlot", &"QuickBarSlotSelected",
]
const BUTTONS: Array[StringName] = [&"SatchelTab", &"MenuTab", &"SatchelSlot"]
const BUTTON_STATES: Array[StringName] = [
	&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus",
]

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


## A font of the journal at a weight ("display" has one weight).
static func font(face: String, weight: int = 500) -> Font:
	var file := load({"display": FONT_DISPLAY, "body": FONT_BODY, "hand": FONT_HAND}[face]) as Font
	if face == "display":
		return file
	var cut := FontVariation.new()
	cut.base_font = file
	cut.variation_opentype = {"wght": weight}
	return cut


## Rewrites the live project theme for the act the story is in.
static func apply() -> void:
	var live := ThemeDB.get_project_theme()
	if live == null:
		return
	live.clear()
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
	var c: Dictionary = COLORS[of_act]
	var t := Theme.new()
	t.default_font = font("body", 500)
	t.default_font_size = 20
	for token: StringName in c:
		t.set_color(token, COLOR_TYPE, c[token])
	t.set_color(&"font_color", &"Label", c.ink)

	for v in PANELS:
		t.set_type_variation(v, &"PanelContainer")
	t.set_stylebox(&"panel", &"SatchelCard", _paper(PAPER_PAGE, c.paper, 40, 28))
	t.set_stylebox(&"panel", &"SatchelDetail", _paper(PAPER_PAGE, c.paper_deep, 40, 26))
	t.set_stylebox(&"panel", &"NotifyCard", _paper(PAPER_SLIP, c.paper, 20, 14))
	t.set_stylebox(&"panel", &"SatchelChip", _pill(c.paper_deep, Color(c.line, 0.7), 1, Vector2(12, 3)))
	t.set_stylebox(&"panel", &"SatchelKey", _pill(c.ink, c.line, 1, Vector2(12, 5), 8))
	t.set_stylebox(&"panel", &"QuickBarSlot", _pill(Color(c.paper, 0.92), c.line, 2, Vector2(6, 6)))
	t.set_stylebox(&"panel", &"QuickBarSlotSelected", _pill(c.paper, c.glow, 3, Vector2(6, 6)))

	for v in BUTTONS:
		t.set_type_variation(v, &"Button")
		var pad := Vector2(8, 8) if v == &"SatchelSlot" else Vector2(20, 9)
		var radius := 10 if v == &"SatchelSlot" else 999
		t.set_stylebox(&"normal", v, _pill(Color(c.paper, 0.0 if v == &"SatchelSlot" else 1.0), Color(c.line, 0.55), 1, pad, radius))
		t.set_stylebox(&"hover", v, _pill(c.paper_deep, c.line, 1, pad, radius))
		t.set_stylebox(&"pressed", v, _pill(c.ink, c.glow, 2, pad, radius))
		t.set_stylebox(&"hover_pressed", v, _pill(c.ink, c.glow, 2, pad, radius))
		t.set_stylebox(&"disabled", v, _pill(Color(c.paper, 0.4), Color(c.line, 0.2), 1, pad, radius))
		var ring := _pill(Color(0, 0, 0, 0), c.glow, 2, pad, radius)
		ring.draw_center = false
		t.set_stylebox(&"focus", v, ring)
		t.set_font(&"font", v, font("body", 700))
		t.set_font_size(&"font_size", v, 18)
		for state in [&"font_color", &"font_hover_color", &"font_focus_color"]:
			t.set_color(state, v, c.ink)
		for state in [&"font_pressed_color", &"font_hover_pressed_color"]:
			t.set_color(state, v, c.paper)
		t.set_color(&"font_disabled_color", v, Color(c.ink, 0.35))

	for v: StringName in LABELS:
		var spec: Array = LABELS[v]
		t.set_type_variation(v, &"Label")
		t.set_font_size(&"font_size", v, spec[0])
		t.set_font(&"font", v, font(spec[1], spec[2]))
		t.set_color(&"font_color", v, c[spec[3]])
	# Count and pin sit on their own small chip.
	for v in [&"SatchelCount", &"SatchelPin"]:
		t.set_type_variation(v, &"Label")
		t.set_font(&"font", v, font("body", 800))
		t.set_font_size(&"font_size", v, 16 if v == &"SatchelCount" else 14)
		t.set_color(&"font_color", v, c.ink)
		t.set_stylebox(&"normal", v, _pill(c.paper, Color(c.line, 0.8), 1, Vector2(9, 1)))

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
