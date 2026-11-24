## The collection (J): a tile per entry (a lilac silhouette until found) and a
## "new" badge that bounces once and clears when its tab is viewed. The page
## is the journal's collection page (CollectionTab); these are its entry
## points and the parts it is built from.
extends RefCounted

const TILE := Vector2(128, 138)
const PICTURE := 72.0


static func is_open() -> bool:
	var loop := Engine.get_main_loop() as SceneTree
	var tab := MenuShell.of(loop).find(&"collection") if loop else null
	return tab != null and tab.is_open()


static func toggle(feyre: Feyre) -> void:
	if is_open():
		close(feyre)
	else:
		open(feyre)


static func open(feyre: Feyre) -> void:
	CollectionTab.ensure(feyre.get_tree()).open()


static func close(feyre: Feyre) -> void:
	CollectionTab.ensure(feyre.get_tree()).close()


## "✦ Next: a gold ribbon sash at 60" plus how many of the page's rewards are earned.
static func _reward_text(book: CollectionBook, tab: StringName) -> String:
	var all := CollectionBook.rewards(tab)
	if all.is_empty():
		return ""
	var earned := all.filter(func(r: CollectionReward) -> bool: return book.is_claimed(r)).size()
	var next := book.next_reward(tab)
	if next == null:
		return "✦ Every reward on this page earned (%d)" % earned
	return "✦ Next reward at %d: %s   (%d/%d earned)" % [next.need, next.label, earned, all.size()]


static func _refresh_labels(buttons: Dictionary, book: CollectionBook) -> void:
	for tab: StringName in buttons:
		var p := book.progress(tab)
		var text: String = CollectionBook.TITLES[tab]
		text += " %d/%d" % [p.x, p.y] if p.y > 0 else " %d" % p.x
		var fresh := book.new_count(tab)
		if fresh > 0:
			text += "  ✦%d" % fresh
		(buttons[tab] as Button).text = text


## One entry: its picture over a blot of wash (a lilac silhouette until
## found), its name or where to look, and a "new" pin that bounces once.
static func _tile(e: Dictionary, detail: Label) -> Control:
	var slot := Button.new()
	slot.theme_type_variation = &"SatchelSlot"
	slot.custom_minimum_size = TILE
	slot.focus_mode = Control.FOCUS_NONE
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(col)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(PICTURE, PICTURE)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	var picture: Control
	var item_art := Icons.texture(Icons.ITEMS, Icons.item_key(e.id)) if e.found else null
	if e.found and (String(e.image) != "" or e.get("icon") is Texture2D):
		picture = BookKit.picture(e.icon if e.get("icon") is Texture2D else Gallery.load_texture({"path": e.image}), Vector2(PICTURE, PICTURE))
	elif item_art:
		holder.add_child(BookKit.wash(PICTURE, hash(String(e.id))))
		picture = BookKit.picture(item_art, Vector2(PICTURE, PICTURE))
	else:
		picture = ItemIcon.make(e.shape, e.color, not e.found, e.shiny, PICTURE)
	holder.add_child(picture)
	var name_label := BookKit.label(String(e.name) if e.found else String(e.hint), &"SatchelSmall" if e.found else &"SatchelWhere", true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(TILE.x - 12, 0)
	# Two lines at the page's small size; the whole hint shows in the detail line.
	name_label.max_lines_visible = 2
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_label)
	if e.new:
		var badge := BookKit.label("new", &"SatchelPin")
		badge.position = Vector2(4, 4)
		slot.add_child(badge)
		slot.ready.connect(func() -> void:
			slot.pivot_offset = TILE * 0.5
			Juice.bounce_control(slot, 0.14), CONNECT_ONE_SHOT)
	if not e.found:
		holder.modulate.a = 0.75
	slot.mouse_entered.connect(func() -> void:
		detail.text = ("%s. %s" % [e.name, e.note]).strip_edges() if e.found else "Not found yet. %s." % e.hint)
	return slot
