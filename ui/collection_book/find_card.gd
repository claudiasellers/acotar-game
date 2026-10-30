## The first-find card (experience-bar §1.4.2): a big card at the top of the
## screen with the illustrated icon, the name in a script face and one line of
## flavour, held 1.2 s. The game keeps running underneath. Cards queue, so a
## handful picked together show one after another. Page rewards and small
## notes use the same queue.
class_name FindCard
extends RefCounted

const HOLD := 1.2
const FADE := 0.18
const GROUP := &"find_card"
const SCRIPT_FONTS: Array[String] = ["Snell Roundhand", "Apple Chancery", "Brush Script MT",
	"Z003", "URW Chancery L", "Lobster", "cursive"]

static var _queue: Array[Dictionary] = []
static var _showing: bool = false
static var _font: SystemFont = null


## The first time something lands in the book.
static func show_find(tree: SceneTree, entry_id: StringName, tab: StringName) -> void:
	var item := ItemCatalog.get_item(entry_id)
	var piece := WardrobeCatalog.piece(entry_id)
	var card := {"shape": ItemIcon.shape_for(entry_id, tab), "color": Color(0.95, 0.8, 0.88),
		"title": String(entry_id).capitalize(), "line": "", "banner": "First find", "gold": false, "shiny": false}
	if item:
		card.color = item.color
		card.title = item.display_name
		card.line = item.description
		card.gold = item.is_rare()
		card.shiny = item.rarity == &"shiny"
		if item.is_rare():
			card.banner = "A shiny find!" if card.shiny else "A rare find!"
	elif piece:
		card.color = piece.color
		card.title = piece.display_name
		card.line = piece.description
		card.banner = "New for the wardrobe"
	elif tab == &"truths":
		card.title = "Something true"
		card.line = "Written in her journal."
		card.banner = "A new truth"
	elif tab == &"recipes":
		for d in Chemistry.dishes():
			if d.id == entry_id:
				card.title = d.display_name
				card.line = d.journal_note
		card.banner = "A new recipe"
	elif tab == &"sketches" or tab == &"paintings":
		return
	_push(tree, card)


## A page reward reached in the collection book.
static func show_reward(tree: SceneTree, reward: CollectionReward) -> void:
	var piece := WardrobeCatalog.piece(reward.reward_id)
	var item := ItemCatalog.get_item(reward.reward_id)
	_push(tree, {"shape": ItemIcon.shape_for(reward.reward_id, &"wardrobe" if piece else (&"sketches" if reward.kind == &"sketch" else &"")),
		"color": piece.color if piece else (item.color if item else ItemIcon.GOLD), "title": reward.label,
		"line": "A reward for %d %s." % [reward.need, CollectionBook.TITLES.get(reward.tab, "finds").to_lower()],
		"banner": "Collection reward", "gold": true, "shiny": true})


## A short line in the same place (no icon), e.g. "Two more flowers for a crown".
static func note(tree: SceneTree, text: String) -> void:
	_push(tree, {"shape": &"", "title": "", "line": text, "banner": "", "gold": false, "shiny": false, "color": Color.WHITE})


## Drops anything showing or queued (the book is opening).
static func clear(tree: SceneTree) -> void:
	_queue.clear()
	_showing = false
	if tree:
		for n in tree.get_nodes_in_group(GROUP):
			n.queue_free()


static func pending() -> int:
	return _queue.size() + (1 if _showing else 0)


static func _push(tree: SceneTree, card: Dictionary) -> void:
	if tree == null:
		return
	_queue.append(card)
	if not _showing:
		_next(tree)


static func _next(tree: SceneTree) -> void:
	if _queue.is_empty() or tree == null or tree.root == null:
		_showing = false
		return
	_showing = true
	var card: Dictionary = _queue.pop_front()
	var layer := CanvasLayer.new()
	layer.layer = 15
	layer.add_to_group(GROUP)
	var panel := PanelContainer.new()
	var style := UiStyle.panel_box()
	style.set_content_margin_all(14)
	style.set_corner_radius_all(26)
	if card.gold:
		style.border_color = ItemIcon.GOLD
		style.set_border_width_all(5)
		style.bg_color = Color(1.0, 0.97, 0.88, 0.96)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 36.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	panel.add_child(row)
	if card.shape != &"":
		row.add_child(ItemIcon.make(card.shape, card.color, false, card.shiny, 96.0))
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	if card.banner != "":
		var banner := UiStyle.label(String(card.banner).to_upper(), 13)
		banner.autowrap_mode = TextServer.AUTOWRAP_OFF
		banner.add_theme_color_override(&"font_color", Color(0.72, 0.52, 0.18) if card.gold else UiStyle.ACCENT.darkened(0.2))
		text.add_child(banner)
	if card.title != "":
		var title := UiStyle.label(card.title, 34)
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.add_theme_font_override(&"font", _script_font())
		text.add_child(title)
	if card.line != "":
		var line := UiStyle.label(card.line, 16)
		line.custom_minimum_size = Vector2(minf(420.0, 9.0 * String(card.line).length()), 0)
		text.add_child(line)
	layer.add_child(panel)
	tree.root.add_child(layer)
	panel.pivot_offset = Vector2(panel.size.x * 0.5, 0)
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.85
	var tween := panel.create_tween()
	tween.tween_property(panel, ^"modulate:a", 1.0, FADE)
	tween.parallel().tween_property(panel, ^"scale", Vector2.ONE, FADE * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD)
	tween.tween_property(panel, ^"modulate:a", 0.0, FADE)
	tween.tween_callback(func() -> void:
		layer.queue_free()
		_next(tree))


static func _script_font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(SCRIPT_FONTS)
		_font.font_italic = true
	return _font
