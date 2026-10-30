## Builds res://ui/theme/acotar_theme.tres (and the Act I variant) from
## AcotarPalette. Run: godot --headless -s tools/ui_theme/build_acotar_theme.gd
extends SceneTree

const DISPLAY_FONT := "res://ui/title/fonts/EBGaramond-SemiBold.ttf"
const BODY_FONT := "res://ui/title/fonts/EBGaramond-Medium.ttf"
const ITALIC_FONT := "res://ui/title/fonts/EBGaramond-MediumItalic.ttf"

## Type variations the consuming lanes style against (contract: docs/contracts/ui-theme.md).
const PANELS := [&"SatchelCard", &"SatchelDetail", &"QuickBarSlot", &"QuickBarSlotSelected", &"NotifyCard"]
const BUTTONS := [&"SatchelTab", &"SatchelSlot", &"MenuTab"]
const LABELS := {
	&"SatchelHeading": 30, &"SatchelBody": 20, &"SatchelSmall": 16, &"SatchelCount": 16,
	&"QuickBarKey": 15, &"QuickBarCount": 15, &"MenuTitle": 44, &"NotifyText": 20,
	&"ThoughtText": 21,
}


func _init() -> void:
	var out := {
		"res://ui/theme/acotar_theme.tres": AcotarPalette.Act.SPRING,
		"res://ui/theme/acotar_theme_human.tres": AcotarPalette.Act.HUMAN,
	}
	for path: String in out:
		var err := ResourceSaver.save(build(out[path]), path)
		print("%s -> %s" % [path, error_string(err)])
	quit()


static func build(act: AcotarPalette.Act) -> Theme:
	var c := AcotarPalette.colours(act)
	var t := Theme.new()
	t.default_font = load(BODY_FONT)
	t.default_font_size = 20
	t.set_color(&"font_color", &"Label", c.ink)

	for key: String in c:
		t.set_color(StringName(key), &"Satchel", c[key])
		t.set_color(StringName(key), &"Acotar", c[key])

	for name: StringName in PANELS:
		t.set_type_variation(name, &"PanelContainer")
	t.set_stylebox(&"panel", &"SatchelCard", _box(c.paper, c.line, 2, 18))
	t.set_stylebox(&"panel", &"SatchelDetail", _box(c.paper_deep, c.line, 1, 18))
	t.set_stylebox(&"panel", &"NotifyCard", _box(c.paper, c.line, 1, 12))
	t.set_stylebox(&"panel", &"QuickBarSlot", _box(Color(c.paper, 0.9), c.line, 2, 6, 32))
	t.set_stylebox(&"panel", &"QuickBarSlotSelected", _box(c.paper, c.accent, 3, 6, 32))

	for name: StringName in BUTTONS:
		t.set_type_variation(name, &"Button")
		t.set_stylebox(&"normal", name, _box(c.paper, Color(c.line, 0.6), 1, 8))
		t.set_stylebox(&"hover", name, _box(c.paper_deep, c.line, 1, 8))
		t.set_stylebox(&"pressed", name, _box(c.accent, c.line, 2, 8))
		t.set_stylebox(&"hover_pressed", name, _box(c.accent, c.line, 2, 8))
		t.set_stylebox(&"disabled", name, _box(Color(c.paper, 0.5), Color(c.line, 0.25), 1, 8))
		var focus := _box(Color(0, 0, 0, 0), c.ink, 2, 8)
		focus.draw_center = false
		t.set_stylebox(&"focus", name, focus)
		for col in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]:
			t.set_color(col, name, c.ink)
		t.set_color(&"font_disabled_color", name, Color(c.ink, 0.35))

	for name: StringName in LABELS:
		t.set_type_variation(name, &"Label")
		t.set_font_size(&"font_size", name, LABELS[name])
		t.set_color(&"font_color", name, c.ink_soft if name in [&"SatchelSmall", &"QuickBarKey"] else c.ink)
	for name in [&"SatchelHeading", &"MenuTitle"]:
		t.set_font(&"font", name, load(DISPLAY_FONT))
	t.set_font(&"font", &"ThoughtText", load(ITALIC_FONT))

	t.set_type_variation(&"SatchelMeter", &"ProgressBar")
	t.set_stylebox(&"background", &"SatchelMeter", _box(c.paper_deep, Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox(&"fill", &"SatchelMeter", _box(c.accent, Color(0, 0, 0, 0), 0, 4))
	return t


## Flat box: no gradients, no glow (L13 direction rule).
static func _box(bg: Color, border: Color, width: int, margin: int, radius: int = 4) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	return b
