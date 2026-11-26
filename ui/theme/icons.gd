## One lookup from a thing to its picture: an item, an outfit, a brew, a
## status. The icon list is the folder res://ui/theme/icons/<kind>/, one
## <id>.webp a thing, so a new thing needs one file there and swapping the
## whole set touches no code. No screen builds an icon path of its own.
##
## Where the pictures come from: items from their real models
## (tools/ui/render_item_icons.gd), outfits from tools/wardrobe/
## render_wardrobe_icons.gd, brews from tools/chemistry/render_brew_icons.gd,
## statuses and the bow meter's layers from tools/ui/status_icons/.
## Contract: docs/contracts/ui-theme.md ("Icons").
class_name Icons
extends RefCounted

const DIR := "res://ui/theme/icons/"
## The kinds: each is a folder under DIR.
const ITEMS := &"items"
const OUTFITS := &"wardrobe"
const BREWS := &"brews"
const STATUS := &"status"
const BONDS := &"bonds"
## The bond measures' glyphs (BondBook.MEASURES ids).
const MEASURES := &"measures"
## Every cooked dish shares one picture.
const DISH := &"dish"


## The picture's file, or "" when the thing has none.
static func path(kind: StringName, id: StringName) -> String:
	var file := "%s%s/%s.webp" % [DIR, kind, id]
	return file if id != &"" and ResourceLoader.exists(file) else ""


static func has(kind: StringName, id: StringName) -> bool:
	return path(kind, id) != ""


## The picture, or null when the thing has none.
static func texture(kind: StringName, id: StringName) -> Texture2D:
	var file := path(kind, id)
	return load(file) as Texture2D if file != "" else null


## The id an item's picture is filed under: its canonical id, or the one
## dish picture.
static func item_key(id: StringName) -> StringName:
	return DISH if SatchelEntries.is_dish(id) else ItemCatalog.canonical(id)


## A Control of `px` square for an entry from SatchelEntries: its picture,
## else the collection book's drawn shape in the item's colour.
static func item(e: Dictionary, px: float) -> Control:
	var tex := texture(ITEMS, item_key(e.id))
	if tex:
		return BookKit.picture(tex, Vector2(px, px))
	var data := e.get("item") as ItemData
	var drawn := ItemIcon.make(e.icon, data.color if data else JournalTheme.color(&"accent"), false,
			data != null and data.rarity == &"shiny", px)
	drawn.size = Vector2(px, px)
	return drawn


## A holder `px` square showing a wardrobe piece; change the piece with
## show_outfit().
static func outfit(p: WardrobePiece, px: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_outfit(holder, p)
	return holder


static func show_outfit(holder: Control, p: WardrobePiece) -> void:
	if holder == null or p == null or holder.get_meta(&"piece", &"") == p.id:
		return
	holder.set_meta(&"piece", p.id)
	for c in holder.get_children():
		c.queue_free()
	var px := holder.custom_minimum_size.y
	var tex := texture(OUTFITS, p.id)
	var pic: Control
	if tex:
		pic = BookKit.picture(tex, Vector2(px, px))
	else:
		var drawn := ItemIcon.make(ItemIcon.shape_for(p.id, &"wardrobe"), p.color, false, false, px)
		drawn.custom_minimum_size = Vector2(px, px)
		pic = CenterContainer.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(drawn)
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(pic)
