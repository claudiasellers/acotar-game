## The notices: everything the game tells her at the top of the screen, one at
## a time, in HudLayout's NOTICE zone. The first-find card (experience-bar
## §1.4.2) is a dark pill with the illustrated icon, the name in her hand and
## one line of flavour, held 1.2 s; page rewards and small notes are the same
## pill. A chapter heading is a title on the said line's smear. The game keeps
## running underneath and notices queue, so a handful picked together show one
## after another. Under dread or a staged moment the cards wait (UiMode.quiet;
## R3: a find never lands on the Suriel or the beast); a heading does not,
## because a heading is how a staged moment opens.
class_name FindCard
extends RefCounted

const HOLD := 1.2
const FADE := 0.18
const GROUP := &"find_card"
## How often a held queue asks again.
const RECHECK := 0.5
## How long a chapter heading stays, and how slowly it comes and goes.
const HEADING_HOLD := 3.2
const HEADING_FADE := 0.6
const ICON := 96.0
## The widest a card's line runs before it wraps.
const LINE_WIDTH := 420.0

static var _queue: Array[Dictionary] = []
static var _showing: bool = false
## Bumped per held recheck (and by clear) so only the newest one acts.
static var _held: int = 0
## Recipes unlocked this frame: one pickup can unlock several, and they share
## one card.
static var _recipes: Array[StringName] = []


## The first time something lands in the book.
static func show_find(tree: SceneTree, entry_id: StringName, tab: StringName) -> void:
	var item := ItemCatalog.get_item(entry_id)
	var piece := WardrobeCatalog.piece(entry_id)
	var card := {"shape": ItemIcon.shape_for(entry_id, tab), "color": JournalTheme.wash(0),
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
		_unlocked(tree, entry_id)
		return
	elif tab == &"sketches" or tab == &"paintings":
		return
	_push(tree, card)


## Recipes unlock when her bags first hold everything one needs (L62). The
## card says what to do with it. A brew she just made at a pot is skipped:
## the pot's own reveal card has already shown it.
static func _unlocked(tree: SceneTree, entry_id: StringName) -> void:
	var r := RecipeUnlocks.get_recipe(entry_id)
	if tree == null or r.is_empty() or (r.brew and Gameplay.journal and Gameplay.journal.has_brew(entry_id)):
		return
	_recipes.append(entry_id)
	if _recipes.size() == 1:
		tree.process_frame.connect(func() -> void: _flush_recipes(tree), CONNECT_ONE_SHOT)


static func _flush_recipes(tree: SceneTree) -> void:
	var ids := _recipes.duplicate()
	_recipes.clear()
	if ids.is_empty():
		return
	var first := RecipeUnlocks.get_recipe(ids[0])
	var card := {"shape": &"bowl", "color": first.color, "title": first.name, "line": RecipeUnlocks.how_to(first),
		"banner": "Recipe unlocked", "gold": false, "shiny": false, "icon": BrewMenu.icon_for(first.id)}
	if ids.size() > 1:
		var names := PackedStringArray()
		for id: StringName in ids:
			names.append(String(RecipeUnlocks.get_recipe(id).name))
		card.banner = "%d recipes unlocked" % ids.size()
		if names.size() == 2:
			card.title = "%s & %s" % [names[0], names[1]]
			card.line = "She has everything for both. They're in her book (J)."
		else:
			card.title = "New recipes"
			card.line = "%s. All in her book (J)." % ", ".join(names)
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
	_push(tree, {"shape": &"", "title": "", "line": text, "banner": "", "gold": false, "shiny": false})


## A chapter heading: "The Wolf in the Snow". It never waits on dread.
static func heading(tree: SceneTree, title: String) -> void:
	_push(tree, {"heading": title})


## Drops anything showing or queued (the book is opening).
static func clear(tree: SceneTree) -> void:
	_queue.clear()
	_recipes.clear()
	_showing = false
	_held += 1
	if tree:
		for n in tree.get_nodes_in_group(GROUP):
			n.queue_free()


static func pending() -> int:
	return _queue.size() + (1 if _showing else 0) + (1 if not _recipes.is_empty() else 0)


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
	# Held cards wait their turn; a heading goes past them. Only the newest
	# recheck acts, so a push while held never starts a second chain.
	var at := 0
	if UiMode.quiet(tree):
		at = _queue.find_custom(func(c: Dictionary) -> bool: return c.has("heading"))
		if at < 0:
			_showing = false
			_held += 1
			var ticket := _held
			tree.create_timer(RECHECK).timeout.connect(func() -> void:
				if ticket == _held and not _showing:
					_next(tree))
			return
	_showing = true
	var card: Dictionary = _queue.pop_at(at)
	var is_heading := card.has("heading")
	var panel := _heading(card.heading) if is_heading else _card(card)
	panel.add_to_group(GROUP)
	HudLayout.of(tree).place(panel, HudLayout.Zone.NOTICE)
	panel.pivot_offset = Vector2(panel.size.x * 0.5, 0)
	panel.modulate.a = 0.0
	var fade := HEADING_FADE if is_heading else FADE
	var tween := panel.create_tween()
	tween.tween_property(panel, ^"modulate:a", 1.0, fade)
	if not is_heading:
		panel.scale = Vector2.ONE * 0.85
		tween.parallel().tween_property(panel, ^"scale", Vector2.ONE, FADE * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HEADING_HOLD if is_heading else HOLD)
	tween.tween_property(panel, ^"modulate:a", 0.0, fade)
	tween.tween_callback(func() -> void:
		panel.queue_free()
		_next(tree))


## A find, a reward or a note: icon, kicker, name and one line on a dark pill.
static func _card(card: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"NoticeRare" if card.gold else &"NoticeCard"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	panel.add_child(row)
	if card.get("icon") is Texture2D:
		row.add_child(BookKit.picture(card.icon, Vector2(ICON, ICON)))
	elif card.shape != &"":
		row.add_child(ItemIcon.make(card.shape, card.color, false, card.shiny, ICON))
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	if card.banner != "":
		text.add_child(BookKit.label(String(card.banner).to_upper(), &"NoticeKicker"))
	if card.title != "":
		var title := BookKit.label(card.title, &"NoticeTitle")
		title.name = "Title"
		text.add_child(title)
	if card.line != "":
		var line := BookKit.label(card.line, &"NoticeBody", true)
		line.name = "Line"
		var font := line.get_theme_font(&"font")
		var wide := font.get_string_size(card.line, HORIZONTAL_ALIGNMENT_LEFT, -1, line.get_theme_font_size(&"font_size")).x
		line.custom_minimum_size = Vector2(minf(LINE_WIDTH, wide + 2.0), 0)
		text.add_child(line)
	return panel


## A chapter heading: the title alone, on the said line's smear.
static func _heading(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"LineBand"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := BookKit.label(title, &"ChapterTitle")
	label.name = "Title"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel
