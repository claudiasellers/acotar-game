## The dressing room's look: the manor's own palette (pale green walls sketched
## with gold, ivory, gilt mouldings; rose as the accent) set in EB Garamond.
## Flat fills and fine gilt rules only, no soft glows (L13 direction).
class_name DressingStyle
extends RefCounted

const IVORY := Color("#FBF7EE")
const GREEN := Color("#DDEBDC")
const GREEN_DEEP := Color("#C3DCC8")
const GILT := Color("#D4A94F")
const GILT_LIGHT := Color("#F2D27A")
const GILT_DEEP := Color("#A47E36")
const INK := Color("#4A2E3E")
const INK_SOFT := Color("#8E6A6E")
const ROSE := Color("#E58FAE")
const EMERALD := Color("#4F9A82")

const BODY := preload("res://ui/title/fonts/EBGaramond-Medium.ttf")
const DISPLAY := preload("res://ui/title/fonts/EBGaramond-SemiBold.ttf")
const ITALIC := preload("res://ui/title/fonts/EBGaramond-MediumItalic.ttf")


## Spaced capitals for titles and tabs, like an engraved label.
static func caps_font(spacing: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = DISPLAY
	f.spacing_glyph = spacing
	return f


static func label(text: String, size: int = 18, italic: bool = false, colour: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", ITALIC if italic else BODY)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A plain rectangle: square-cut corners read as tailored, not toy-like.
static func box(bg: Color, border: Color, width: int, margin: int = 8) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(2)
	b.set_content_margin_all(margin)
	b.anti_aliasing = true
	return b


## The wardrobe sheet: ivory with a gilt edge (the hairline and corners are
## drawn by GiltFrameDecor on top).
static func sheet() -> StyleBoxFlat:
	return box(IVORY, GILT, 2, 9)


## Ivory text button with a hairline of gilt; toggled ones sit in manor green.
static func button(text: String, toggle: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override(&"font", BODY)
	b.add_theme_font_size_override(&"font_size", 18)
	var margin := 7
	b.add_theme_stylebox_override(&"normal", box(Color(IVORY, 0.0), Color(GILT, 0.7), 1, margin))
	b.add_theme_stylebox_override(&"hover", box(Color(GREEN, 0.7), GILT, 1, margin))
	b.add_theme_stylebox_override(&"pressed", box(GREEN_DEEP, GILT_DEEP, 2, margin))
	b.add_theme_stylebox_override(&"hover_pressed", box(GREEN_DEEP, GILT_DEEP, 2, margin))
	var focus := box(Color(0, 0, 0, 0), GILT_DEEP, 2, margin)
	focus.draw_center = false
	focus.set_expand_margin_all(3)
	b.add_theme_stylebox_override(&"focus", focus)
	for col in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		b.add_theme_color_override(col, INK)
	b.pressed.connect(func() -> void: Juice.bounce_control(b, 0.05))
	return b


## A colour swatch: a round enamel with a faint gilt rim; worn ones get a strong one.
static func swatch(colour: Color, hot: bool, worn: bool) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = colour
	b.set_corner_radius_all(32)
	b.set_border_width_all(3 if worn else 2)
	b.border_color = GILT_DEEP if worn else (GILT if hot else Color(GILT, 0.45))
	if worn:
		b.set_expand_margin_all(3)
	b.anti_aliasing = true
	return b


## One garment card: a pale green panel; the worn garment turns ivory with a gilt edge.
static func card(worn: bool) -> StyleBoxFlat:
	return box(IVORY if worn else Color(GREEN, 0.55), GILT if worn else Color(GILT, 0.35), 2 if worn else 1, 11)
