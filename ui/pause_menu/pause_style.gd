## The pause menu's look (R3): pearl and blush card, gold trim, Cinzel
## Decorative headings, rounded Quicksand body text, pearl slider knobs and
## rose "pearl" checkboxes. One Theme, so every control inside matches.
class_name PauseStyle
extends RefCounted

const DISPLAY_FONT := preload("res://ui/fonts/CinzelDecorative-Bold.ttf")
const BODY_FONT := preload("res://ui/fonts/Quicksand-Variable.ttf")

const PEARL := Color(1.0, 0.97, 0.98)
const BLUSH := Color(1.0, 0.86, 0.91)
const ROSE := Color(0.95, 0.55, 0.72)
const LILAC := Color(0.82, 0.74, 0.96)
const PERIWINKLE := Color(0.70, 0.76, 0.98)
const GOLD := Color(0.88, 0.70, 0.36)
const GOLD_LIGHT := Color(1.0, 0.88, 0.58)
const PLUM := Color(0.38, 0.22, 0.38)
const PLUM_SOFT := Color(0.52, 0.38, 0.52)

static var _theme: Theme = null


static func body_font(weight: int = 600) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = BODY_FONT
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 20
	t.set_color(&"font_color", &"Label", PLUM)

	# Buttons: pearl pills with a gold edge; hover blushes, pressed goes rose.
	var normal := _pill(PEARL, Color(GOLD, 0.6), 2)
	var hover := _pill(BLUSH, GOLD, 2)
	var pressed := _pill(Color(ROSE, 0.9), GOLD, 2)
	var focus := _pill(Color(0, 0, 0, 0), GOLD_LIGHT, 3)
	focus.draw_center = false
	for type in [&"Button", &"CheckBox"]:
		t.set_stylebox(&"normal", type, normal if type == &"Button" else _flat())
		t.set_stylebox(&"hover", type, hover if type == &"Button" else _flat(Color(BLUSH, 0.6)))
		t.set_stylebox(&"pressed", type, pressed if type == &"Button" else _flat())
		t.set_stylebox(&"hover_pressed", type, pressed if type == &"Button" else _flat(Color(BLUSH, 0.6)))
		t.set_stylebox(&"focus", type, focus)
		t.set_color(&"font_color", type, PLUM)
		t.set_color(&"font_hover_color", type, PLUM)
		t.set_color(&"font_focus_color", type, PLUM)
		t.set_color(&"font_pressed_color", type, Color.WHITE if type == &"Button" else PLUM)
		t.set_color(&"font_hover_pressed_color", type, Color.WHITE if type == &"Button" else PLUM)
	var disabled := _pill(Color(PEARL, 0.5), Color(GOLD, 0.25), 2)
	t.set_stylebox(&"disabled", &"Button", disabled)
	t.set_color(&"font_disabled_color", &"Button", Color(PLUM, 0.35))
	t.set_icon(&"unchecked", &"CheckBox", disc(26, PEARL, GOLD, Color(0, 0, 0, 0)))
	t.set_icon(&"checked", &"CheckBox", disc(26, ROSE, GOLD, PEARL))
	t.set_constant(&"h_separation", &"CheckBox", 12)

	# Sliders: lilac track that fills rose, a pearl knob ringed in gold.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(LILAC, 0.55)
	track.set_corner_radius_all(6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = ROSE
	t.set_stylebox(&"slider", &"HSlider", track)
	t.set_stylebox(&"grabber_area", &"HSlider", fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	t.set_icon(&"grabber", &"HSlider", disc(28, PEARL, GOLD, BLUSH))
	t.set_icon(&"grabber_highlight", &"HSlider", disc(30, BLUSH, GOLD, PEARL))
	t.set_icon(&"grabber_disabled", &"HSlider", disc(28, PEARL, GOLD, BLUSH))
	# A slim rose scrollbar on a clear track (large text sizes scroll).
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(ROSE, 0.75)
	bar.set_corner_radius_all(5)
	bar.content_margin_left = 5
	bar.content_margin_right = 5
	var bar_hover := bar.duplicate() as StyleBoxFlat
	bar_hover.bg_color = ROSE
	var lane := StyleBoxFlat.new()
	lane.bg_color = Color(LILAC, 0.25)
	lane.set_corner_radius_all(5)
	lane.content_margin_left = 5
	lane.content_margin_right = 5
	t.set_stylebox(&"scroll", &"VScrollBar", lane)
	t.set_stylebox(&"grabber", &"VScrollBar", bar)
	t.set_stylebox(&"grabber_highlight", &"VScrollBar", bar_hover)
	t.set_stylebox(&"grabber_pressed", &"VScrollBar", bar_hover)
	_theme = t
	return t


## The card: pearl with a blush wash, a double gold edge and a soft rose glow.
static func card_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 0.95, 0.97, 0.97)
	box.border_color = GOLD
	box.set_border_width_all(3)
	box.set_corner_radius_all(30)
	box.set_content_margin_all(34)
	box.shadow_color = Color(0.85, 0.45, 0.7, 0.35)
	box.shadow_size = 28
	return box


## Inner gold hairline between the card edge and its contents.
static func inner_frame() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Color(GOLD, 0.5)
	box.set_border_width_all(1)
	box.set_corner_radius_all(22)
	box.set_expand_margin_all(16)
	return box


## A section: soft tinted well behind a group of settings.
static func section_box(tint: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(tint, 0.18)
	box.border_color = Color(tint, 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(18)
	box.set_content_margin_all(16)
	return box


static func title(text: String, size: int = 54) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", DISPLAY_FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", Color(0.74, 0.42, 0.62))
	l.add_theme_color_override(&"font_outline_color", GOLD_LIGHT)
	l.add_theme_constant_override(&"outline_size", 6)
	l.add_theme_color_override(&"font_shadow_color", Color(0.9, 0.5, 0.75, 0.45))
	l.add_theme_constant_override(&"shadow_offset_y", 3)
	return l


static func heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", DISPLAY_FONT)
	l.add_theme_font_size_override(&"font_size", 22)
	l.add_theme_color_override(&"font_color", Color(0.70, 0.50, 0.24))
	return l


static func note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", body_font(500))
	l.add_theme_font_size_override(&"font_size", 17)
	l.add_theme_color_override(&"font_color", PLUM_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A soft round glow (sparkles, petals), white so particles can tint it.
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


## A filled circle with a ring and an optional centre pearl, as a texture.
static func disc(size: int, fill: Color, ring: Color, centre: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	var r := size * 0.5 - 1.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var col := Color(0, 0, 0, 0)
			if d <= r:
				col = ring if d > r - 2.5 else fill
				if centre.a > 0.0 and d < r * 0.38:
					col = centre
				# Glossy highlight in the upper left.
				var hl := Vector2(x - c * 0.7, y - c * 0.6).length()
				if d <= r - 2.5 and hl < r * 0.3:
					col = col.lerp(Color.WHITE, 0.45 * (1.0 - hl / (r * 0.3)))
				col.a *= clampf(r - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _pill(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(22)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = Color(0.8, 0.5, 0.7, 0.18)
	box.shadow_size = 4
	return box


static func _flat(bg: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(12)
	box.set_content_margin_all(4)
	return box
