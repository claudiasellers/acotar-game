## The collection book (J): pastel tabs with progress bars, a swatch tile per
## entry (a grey "?" until found), and a pink "new" badge that bounces once
## and clears when the tab is viewed. Pauses the game while open.
extends RefCounted

const TILE := Vector2(132, 118)
const UNFOUND := Color(0.84, 0.82, 0.86)

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
	var count := UiStyle.label("", 16)
	box.add_child(count)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
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
	if book.new_count() > 0:
		_chime(layer)
	show_tab.call(first)
	feyre.get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func close(feyre: Feyre) -> void:
	if is_open():
		_open.queue_free()
	_open = null
	feyre.get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	style.border_color = UiStyle.ACCENT if e.new else (UiStyle.BORDER if e.found else Color(UiStyle.BORDER, 0.3))
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
		var gem := Panel.new()
		var round := StyleBoxFlat.new()
		round.set_corner_radius_all(28)
		round.bg_color = e.color if e.found else UNFOUND
		round.border_color = Color(1, 1, 1, 0.9)
		round.set_border_width_all(3)
		gem.add_theme_stylebox_override(&"panel", round)
		if not e.found:
			var q := UiStyle.label("?", 26)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			q.set_anchors_preset(Control.PRESET_FULL_RECT)
			q.add_theme_color_override(&"font_color", Color(1, 1, 1))
			gem.add_child(q)
		swatch = gem
	swatch.custom_minimum_size = Vector2(56, 56)
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(swatch)
	var name_label := UiStyle.label(String(e.name) if e.found else "· · ·", 13)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)
	if e.new:
		var badge := UiStyle.label("new!", 12)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_color_override(&"font_color", Color(0.93, 0.36, 0.6))
		col.add_child(badge)
		panel.ready.connect(func() -> void: Juice.bounce_control(panel, 0.14), CONNECT_ONE_SHOT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(func() -> void:
		detail.text = ("%s. %s" % [e.name, e.note]).strip_edges() if e.found else "Not found yet.")
	return panel


static func _chime(layer: CanvasLayer) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = Juice.chime(&"unlock")
	player.volume_db = -8.0
	player.autoplay = true
	player.finished.connect(player.queue_free)
	layer.add_child(player)


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


## A little pastel card that rises from the bottom of the screen with a chime
## when something new is logged in the book.
static func toast(tree: SceneTree, entry_id: StringName, tab: StringName) -> void:
	if tree == null or is_open():
		return
	var item := ItemCatalog.get_item(entry_id)
	var piece := WardrobeCatalog.piece(entry_id)
	var entry_name := item.display_name if item else (piece.display_name if piece else String(entry_id).capitalize())
	var layer := CanvasLayer.new()
	layer.layer = 15
	var card := PanelContainer.new()
	var style := UiStyle.panel_box()
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override(&"panel", style)
	const KIND := {&"ingredients": "ingredient", &"keepsakes": "keepsake", &"recipes": "recipe",
		&"sketches": "sketch", &"paintings": "painting", &"wardrobe": "piece for the wardrobe"}
	var text := "✦ New %s: %s" % [KIND.get(tab, "find"), entry_name]
	if tab == &"truths":
		text = "✦ A new truth in your journal"
	card.add_child(UiStyle.label(text + "   (J)", 17))
	card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.position.y -= 90.0
	card.modulate.a = 0.0
	layer.add_child(card)
	tree.root.add_child(layer)
	_chime(layer)
	var tween := card.create_tween()
	tween.tween_property(card, ^"modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(card, ^"position:y", card.position.y - 20.0, 0.35).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(2.2)
	tween.tween_property(card, ^"modulate:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)
