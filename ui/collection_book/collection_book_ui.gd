## The collection book (J): pastel tabs with progress bars, a swatch tile per
## entry (a grey "?" until found), and a pink "new" badge that bounces once
## and clears when the tab is viewed. Pauses the game while open.
extends RefCounted

const TILE := Vector2(122, 132)

static var _open: CanvasLayer = null


static func is_open() -> bool:
	return _open != null and is_instance_valid(_open)


static func toggle(feyre: Feyre) -> void:
	if is_open():
		close(feyre)
	else:
		open(feyre)


static func open(feyre: Feyre) -> void:
	if is_open():
		return
	FindCard.clear(feyre.get_tree())
	var book := Gameplay.collection
	var parts := UiStyle.modal("CollectionBook", 980.0)
	var layer: CanvasLayer = parts[0]
	var box: VBoxContainer = parts[1]
	_open = layer
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := UiStyle.label("My collection", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := UiStyle.button("Close (J)")
	close_button.shortcut = _shortcut([&"open_collection", &"ui_cancel"])
	close_button.pressed.connect(func() -> void: close(feyre))
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 6)
	box.add_child(tabs)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.add_theme_stylebox_override(&"fill", _rounded(UiStyle.ACCENT))
	bar.add_theme_stylebox_override(&"background", _rounded(Color(1, 1, 1, 0.8)))
	box.add_child(bar)
	var count_row := HBoxContainer.new()
	box.add_child(count_row)
	var count := UiStyle.label("", 16)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count_row.add_child(count)
	var reward := UiStyle.label("", 16)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward.autowrap_mode = TextServer.AUTOWRAP_OFF
	reward.add_theme_color_override(&"font_color", Color(0.72, 0.52, 0.18))
	count_row.add_child(reward)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	scroll.add_child(grid)
	var detail := UiStyle.label("", 16)
	box.add_child(detail)

	var buttons: Dictionary = {}
	var show_tab := func(tab: StringName) -> void:
		for t: StringName in buttons:
			(buttons[t] as Button).button_pressed = t == tab
		for c in grid.get_children():
			c.queue_free()
		var p := book.progress(tab)
		if p.y > 0:
			bar.visible = true
			bar.max_value = p.y
			bar.value = p.x
			count.text = "%d of %d found" % [p.x, p.y]
		else:
			bar.visible = false
			count.text = "%d so far" % p.x if p.x > 0 else "Nothing yet. Keep your eyes open."
		reward.text = _reward_text(book, tab)
		for e in book.entries(tab):
			grid.add_child(_tile(e, detail))
		book.seen(tab)
		_refresh_labels(buttons, book)
	for tab in CollectionBook.TABS:
		var b := UiStyle.button("", true)
		b.pressed.connect(func() -> void: show_tab.call(tab))
		tabs.add_child(b)
		buttons[tab] = b
	_refresh_labels(buttons, book)

	feyre.get_tree().root.add_child(layer)
	var first: StringName = CollectionBook.TABS[0]
	for tab in CollectionBook.TABS:
		if book.new_count(tab) > 0:
			first = tab
			break
	show_tab.call(first)
	feyre.get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func close(feyre: Feyre) -> void:
	if is_open():
		_open.queue_free()
	_open = null
	feyre.get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	if e.found and String(e.image) != "":
		var tex := TextureRect.new()
		tex.texture = Gallery.load_texture({"path": e.image})
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

