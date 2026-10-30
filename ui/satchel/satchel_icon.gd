## An item's picture: the painted icon from the UI look lane when it exists
## (res://ui/theme/icons/items/<id>.png, <id>_128.png for small sizes), else
## the collection book's drawn shape.
class_name SatchelIcon
extends RefCounted

const DIR := "res://ui/theme/icons/items/"
const DISH_ID := "dish"


static func path_for(id: StringName, px: float) -> String:
	var key := DISH_ID if SatchelEntries.is_dish(id) else String(id)
	var small := DIR + key + "_128.png"
	var big := DIR + key + ".png"
	if px <= 128.0 and ResourceLoader.exists(small):
		return small
	return big if ResourceLoader.exists(big) else ""


## A Control of `px` square for an entry from SatchelEntries.
static func make(e: Dictionary, px: float) -> Control:
	var path := path_for(e.id, px)
	if path != "":
		var tex := TextureRect.new()
		tex.texture = load(path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(px, px)
		tex.size = Vector2(px, px)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tex
	var item := e.get("item") as ItemData
	var color: Color = item.color if item else SatchelTheme.color(&"accent")
	var icon := ItemIcon.make(e.icon, color, false, item != null and item.rarity == &"shiny", px)
	icon.size = Vector2(px, px)
	return icon
