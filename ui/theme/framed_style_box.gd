## A panel's own style with one of Kenney's frames drawn over it (L65): the
## frame is a white 9-patch tinted from the palette, inset from the panel's
## edge and drawn at `frame_scale` so a supersampled texture stays crisp.
## Built by UiBorders; nothing else constructs one.
@tool
class_name FramedStyleBox
extends StyleBox

## The panel's own look (the crafted paper, a flat card); null draws only the frame.
@export var base: StyleBox
@export var frame: Texture2D
## 9-patch margin in texture pixels (the corner ornament).
@export var patch_margin: float = 48.0
@export var frame_scale: float = 0.5
## Distance from the panel's edge to the frame, in screen pixels. Negative grows it.
@export var inset: float = 12.0
@export var tint: Color = Color.WHITE


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if base:
		base.draw(to_canvas_item, rect)
	if frame == null:
		return
	var r := rect.grow(-inset)
	var size := r.size / frame_scale
	if size.x < patch_margin * 2.0 or size.y < patch_margin * 2.0:
		return
	var rs := RenderingServer
	rs.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, Vector2.ONE * frame_scale, 0.0, r.position))
	var m := Vector2.ONE * patch_margin
	rs.canvas_item_add_nine_patch(to_canvas_item, Rect2(Vector2.ZERO, size), Rect2(Vector2.ZERO, frame.get_size()),
		frame.get_rid(), m, m, RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, false, tint)
	rs.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)


## On-screen width of the frame's corner ornament, from the panel's edge.
func reach() -> float:
	return inset + patch_margin * frame_scale
