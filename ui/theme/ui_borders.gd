## Kenney's Fantasy UI Borders (CC0, kenney.nl), softened into piped gilt by
## tools/ui/build_ui_borders.py, framing the menus' main panels (L65). Every
## menu built on SatchelTheme gets the page frame on its SatchelDetail panel
## (satchel tag, dressing room, journal pages, brew and market cards); the
## pause card gets the card frame. Tinted from the active theme's `line`.
class_name UiBorders
extends RefCounted

const PAGE_FRAME := "res://ui/theme/borders/frame_page.png"
const CARD_FRAME := "res://ui/theme/borders/frame_card.png"
## Texture px per source px is 4 (build_ui_borders.py SCALE); corner ornaments span 12 source px.
const PATCH_MARGIN := 48.0
const FRAME_SCALE := 0.5
## Panel variation -> how far in from its edge the frame sits. The crafted
## tag's deckle and eyelet take the outer ~14 px.
const FRAMED := {&"SatchelDetail": 15.0}
## Space kept between the frame line and the panel's contents.
const PAD := 6.0


static func framed(base: StyleBox, frame_path: String, inset: float, tint: Color) -> FramedStyleBox:
	var box := FramedStyleBox.new()
	box.base = base
	box.frame = load(frame_path) as Texture2D
	box.patch_margin = PATCH_MARGIN
	box.frame_scale = FRAME_SCALE
	box.inset = inset
	box.tint = tint
	# Contents clear the frame's straight edge (the ornaments only fill the corners).
	var edge := inset + 3.0 * 4.0 * FRAME_SCALE + PAD
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		var own := base.get_content_margin(side) if base else 0.0
		box.set_content_margin(side, maxf(own, edge))
	return box


## Wraps each FRAMED panel style in `t` (in place) with the page frame.
static func dress(t: Theme, tint: Color) -> void:
	for v: StringName in FRAMED:
		if not t.has_stylebox(&"panel", v):
			continue
		var own := t.get_stylebox(&"panel", v)
		if own is FramedStyleBox:
			continue
		t.set_stylebox(&"panel", v, framed(own, PAGE_FRAME, FRAMED[v], tint))


## The pause card's frame, drawn by a Panel filling the card's content area,
## so a negative inset pushes it out towards the card's edge.
static func card_frame(tint: Color, outset: float) -> FramedStyleBox:
	return framed(null, CARD_FRAME, -outset, tint)
