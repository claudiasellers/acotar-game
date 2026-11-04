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


static func _tile(e: Dictionary, detail: Label) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = TILE
	var style := UiStyle.panel_box()
	style.set_content_margin_all(8)
	style.set_corner_radius_all(16)
	style.shadow_size = 4
	style.bg_color = Color(1, 1, 1, 0.92) if e.found else Color(0.95, 0.94, 0.96, 0.85)
	style.border_color = UiStyle.ACCENT if e.new else (ItemIcon.GOLD if e.found and e.rare \
			else (UiStyle.BORDER if e.found else Color(UiStyle.BORDER, 0.3)))
	panel.add_theme_stylebox_override(&"panel", style)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
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
	col.add_child(swatch)
	var name_label := UiStyle.label(String(e.name) if e.found else String(e.hint), 13 if e.found else 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not e.found:
		name_label.add_theme_color_override(&"font_color", Color(UiStyle.TEXT, 0.6))
	col.add_child(name_label)
	if e.new:
		var badge := UiStyle.label("new!", 12)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_color_override(&"font_color", Color(0.93, 0.36, 0.6))
		col.add_child(badge)
		panel.ready.connect(func() -> void: Juice.bounce_control(panel, 0.14), CONNECT_ONE_SHOT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(func() -> void:
		detail.text = ("%s. %s" % [e.name, e.note]).strip_edges() if e.found else "Not found yet. %s." % e.hint)
	return panel


static func _shortcut(actions: Array[StringName]) -> Shortcut:
	var s := Shortcut.new()
	for a in actions:
		var ev := InputEventAction.new()
		ev.action = a
		s.events.append(ev)
	return s


static func _rounded(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(9)
	return box

