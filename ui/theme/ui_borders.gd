## Kenney's Fantasy UI Borders (CC0, kenney.nl), softened into piped gilt by
## tools/ui/build_ui_borders.py: the frame inside the pause card (L65).
class_name UiBorders
extends RefCounted

const CARD_FRAME := "res://ui/theme/borders/frame_card.png"
## Texture px per source px is 4 (build_ui_borders.py SCALE); corner ornaments span 12 source px.
const PATCH_MARGIN := 48.0
const FRAME_SCALE := 0.5


## The pause card's frame, drawn by a Panel filling the card's content area,
## so a negative inset pushes it out towards the card's edge.
static func card_frame(tint: Color, outset: float) -> FramedStyleBox:
	var box := FramedStyleBox.new()
	box.frame = load(CARD_FRAME) as Texture2D
	box.patch_margin = PATCH_MARGIN
	box.frame_scale = FRAME_SCALE
	box.inset = -outset
	box.tint = tint
	return box
