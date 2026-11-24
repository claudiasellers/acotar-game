## The old card look, kept only for the play-time cards that have not moved
## to JournalTheme yet (find card, prompts, caption, quiver card: step 8 of the
## UI plan deletes this file). Screens use LoosePage and the book.
class_name UiStyle
extends RefCounted

const BG := Color(0.99, 0.94, 0.96, 0.94)
const BORDER := Color(0.90, 0.74, 0.42)
const TEXT := Color(0.36, 0.22, 0.32)
const ACCENT := Color(0.96, 0.62, 0.76)


static func panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BG
	box.border_color = BORDER
	box.set_border_width_all(3)
	box.set_corner_radius_all(22)
	box.set_content_margin_all(18)
	box.shadow_color = Color(0.6, 0.3, 0.5, 0.25)
	box.shadow_size = 12
	return box


static func label(text: String, size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
