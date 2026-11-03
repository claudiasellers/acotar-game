## A wardrobe piece's picture (L64): its rendered thumbnail
## (tools/wardrobe/render_wardrobe_icons.gd -> res://ui/theme/icons/wardrobe/<id>.webp),
## else the collection book's drawn shape in its colour.
class_name WardrobeIcon
extends RefCounted

const DIR := "res://ui/theme/icons/wardrobe/"


static func path_for(id: StringName) -> String:
	var path := DIR + String(id) + ".webp"
	return path if ResourceLoader.exists(path) else ""


## A Control about `px` tall showing `p`; swap the piece with show_piece().
static func make(p: WardrobePiece, px: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_piece(holder, p)
	return holder


static func show_piece(holder: Control, p: WardrobePiece) -> void:
	if holder == null or p == null or holder.get_meta(&"piece", &"") == p.id:
		return
	holder.set_meta(&"piece", p.id)
	for c in holder.get_children():
		c.queue_free()
	var px := holder.custom_minimum_size.y
	var path := path_for(p.id)
	var pic: Control
	if path != "":
		var tex := TextureRect.new()
		tex.texture = load(path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic = tex
	else:
		var icon := ItemIcon.make(ItemIcon.shape_for(p.id, &"wardrobe"), p.color, false, false, px)
		icon.custom_minimum_size = Vector2(px, px)
		var centre := CenterContainer.new()
		centre.add_child(icon)
		pic = centre
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(pic)
