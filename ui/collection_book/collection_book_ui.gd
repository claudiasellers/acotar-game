## The collection book (J): pastel tabs with progress bars, a swatch tile per
## entry (a grey "?" until found), and a pink "new" badge that bounces once
## and clears when the tab is viewed. The page is the menu shell's collection
## tab (CollectionTab); these are its entry points and the parts it is built from.
extends RefCounted

const TILE := Vector2(122, 132)


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


## One entry: a stitched slot with its picture (a lilac silhouette until
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
	var swatch: Control
	if e.found and (String(e.image) != "" or e.get("icon") is Texture2D):
		var tex := TextureRect.new()
		tex.texture = e.icon if e.get("icon") is Texture2D else Gallery.load_texture({"path": e.image})
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		swatch = tex
	else:
		swatch = ItemIcon.make(e.shape, e.color, not e.found, e.shiny)
	swatch.custom_minimum_size = Vector2(56, 56)
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(swatch)
	var name_label := Label.new()
	name_label.text = String(e.name) if e.found else String(e.hint)
	name_label.theme_type_variation = &"SatchelSmall" if e.found else &"SatchelWhere"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(TILE.x - 16, 0)
	name_label.add_theme_font_size_override(&"font_size", 15 if e.found else 13)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	if e.new:
		var badge := Label.new()
		badge.text = "new"
		badge.theme_type_variation = &"SatchelPin"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(badge)
		slot.ready.connect(func() -> void:
			slot.pivot_offset = TILE * 0.5
			Juice.bounce_control(slot, 0.14), CONNECT_ONE_SHOT)
	if not e.found:
		col.modulate.a = 0.75
	slot.mouse_entered.connect(func() -> void:
		detail.text = ("%s. %s" % [e.name, e.note]).strip_edges() if e.found else "Not found yet. %s." % e.hint)
	return slot
