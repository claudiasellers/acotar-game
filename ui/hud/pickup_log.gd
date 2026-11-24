## The log: everything she gains, in HudLayout's PICKUPS zone (left,
## mid-screen), and the only place it is told. One row a thing on a dark trail
## that fades to nothing rightwards:
##   a pickup        "Rose hips ×2"; picking more of the same adds to its row
##   a first find    the same row with a kicker over it ("New", "A rare
##                   find!") and its one line of flavour under it
##   a recipe, a collection reward, a truth, a piece for the wardrobe
##                   a kicker, its name and one line
##   a note          one short line: what she got or what she sees ("A brace
##                   of rabbits."), never what is left to do (R2)
## A row stays a few seconds, longer when it has a line to read, and the
## oldest go first. Under dread or a staged moment everything waits
## (UiMode.quiet; R3: a find never lands on the Suriel or the beast) and shows
## once play is calm. There is one log, made the first time it is asked for:
## PickupLog.of(tree).
class_name PickupLog
extends VBoxContainer

const NODE := "PickupLog"
const HOLD := 2.8
## A row with a line to read stays this long.
const HOLD_READ := 6.0
const FADE := 0.5
const MAX_ROWS := 4
const ICON := 30.0
const WIDTH := 340.0

## key -> its Row, while it shows.
var _rows: Dictionary[StringName, Row] = {}
## What came in while play was not calm: it shows afterwards, in order.
var _held: Array[Callable] = []
## Recipes unlocked this frame: one pickup can unlock several, and they share
## one row.
var _recipes: Array[StringName] = []


static func of(tree: SceneTree) -> PickupLog:
	var zone := HudLayout.of(tree).zone(HudLayout.Zone.PICKUPS)
	var log := zone.get_node_or_null(NODE) as PickupLog
	if log == null:
		log = PickupLog.new()
		HudLayout.of(tree).place(log, HudLayout.Zone.PICKUPS)
	return log


func _init() -> void:
	name = NODE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 4)


## `count` more of `id` went into her bags.
func add(id: StringName, count: int) -> void:
	_when_calm(func() -> void: _row(id).item(id).more(count))


## The first time something lands in her book.
func find(entry_id: StringName, tab: StringName) -> void:
	var item := ItemCatalog.get_item(entry_id)
	var piece := WardrobeCatalog.piece(entry_id)
	if item:
		var kicker := "New"
		if item.is_rare():
			kicker = "A shiny find!" if item.rarity == &"shiny" else "A rare find!"
		_when_calm(func() -> void: _row(entry_id).item(entry_id).read(kicker, item.description))
	elif piece:
		_when_calm(func() -> void:
			_row(entry_id).picture(ItemIcon.make(ItemIcon.shape_for(entry_id, tab), piece.color, false, false, ICON)) \
					.named(piece.display_name).read("New for the wardrobe", piece.description))
	elif tab == &"truths":
		_when_calm(func() -> void: _row(entry_id).named("Something true").read("A new truth", "Written in her journal."))
	elif tab == &"recipes":
		_unlocked(entry_id)


## A page reward reached in the collection book.
func reward(prize: CollectionReward) -> void:
	var piece := WardrobeCatalog.piece(prize.reward_id)
	var item := ItemCatalog.get_item(prize.reward_id)
	var shape := ItemIcon.shape_for(prize.reward_id, &"wardrobe" if piece else (&"sketches" if prize.kind == &"sketch" else &""))
	var tint: Color = piece.color if piece else (item.color if item else ItemIcon.GOLD)
	var line := "A reward for %d %s." % [prize.need, CollectionBook.TITLES.get(prize.tab, "finds").to_lower()]
	_when_calm(func() -> void:
		_row(StringName("reward:%s" % prize.reward_id)).picture(ItemIcon.make(shape, tint, false, true, ICON)) \
				.named(prize.label).read("Collection reward", line))


## A short line: what she got or what she sees, never what is left to do (R2).
func note(text: String) -> void:
	_when_calm(func() -> void: _row(StringName("note:" + text)).named(text).stay(HOLD_READ))


## Drops everything showing or waiting (the book is opening, a new scene's HUD).
func clear() -> void:
	_held.clear()
	_recipes.clear()
	_rows.clear()
	for row in get_children():
		remove_child(row)
		row.queue_free()


## How many things are waiting for play to be calm.
func waiting() -> int:
	return _held.size()


## What the log reads now, top to bottom: ["Rose hips  ×2", ...].
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for row in get_children():
		if not (row as Row).leaving():
			out.append((row as Row).text())
	return out


func _process(_delta: float) -> void:
	if _held.is_empty() or UiMode.quiet(get_tree()):
		return
	var due := _held.duplicate()
	_held.clear()
	for entry: Callable in due:
		entry.call()


func _when_calm(entry: Callable) -> void:
	if is_inside_tree() and UiMode.quiet(get_tree()):
		_held.append(entry)
	else:
		entry.call()


## The row under `key`, made at the foot of the log if it is not showing.
func _row(key: StringName) -> Row:
	# A row that faded and freed itself is still in the book under its key.
	var kept: Variant = _rows.get(key)
	var row: Row = kept if is_instance_valid(kept) else null
	if row == null or row.leaving():
		row = Row.new()
		_rows[key] = row
		add_child(row)
		while get_child_count() > MAX_ROWS:
			var oldest := get_child(0)
			remove_child(oldest)
			oldest.queue_free()
	return row


## Recipes unlock when her bags first hold everything one needs (L62). The
## row says what to do with it. A brew she just made at a pot is skipped: the
## pot's own reveal has already shown it.
func _unlocked(entry_id: StringName) -> void:
	var r := RecipeUnlocks.get_recipe(entry_id)
	if r.is_empty() or (r.brew and Gameplay.journal and Gameplay.journal.has_brew(entry_id)):
		return
	_recipes.append(entry_id)
	if _recipes.size() == 1:
		_flush_recipes.call_deferred()


func _flush_recipes() -> void:
	var ids := _recipes.duplicate()
	_recipes.clear()
	if ids.is_empty():
		return
	var first := RecipeUnlocks.get_recipe(ids[0])
	var kicker := "Recipe unlocked"
	var title := String(first.name)
	var line := RecipeUnlocks.how_to(first)
	if ids.size() > 1:
		var names := PackedStringArray()
		for id: StringName in ids:
			names.append(String(RecipeUnlocks.get_recipe(id).name))
		kicker = "%d recipes unlocked" % ids.size()
		if names.size() == 2:
			title = "%s & %s" % [names[0], names[1]]
			line = "She has everything for both. They're in her book (J)."
		else:
			title = "New recipes"
			line = "%s. All in her book (J)." % ", ".join(names)
	_when_calm(func() -> void:
		var row := _row(&"recipes")
		var bottle := Icons.texture(Icons.BREWS, first.id)
		row.picture(ItemIcon.of_picture(bottle, ICON) if bottle
				else ItemIcon.make(&"bowl", first.color, false, false, ICON))
		row.named(title).read(kicker, line))


## One row: a picture, a kicker over the name, and a line under it. Each part
## shows only when it has something to say.
class Row extends PanelContainer:
	var count: int = 0
	var _box: HBoxContainer
	var _icon: Control
	var _kicker: Label
	var _label: Label
	var _line: Label
	var _name: String = ""
	var _left: float = 0.0

	func _init() -> void:
		theme_type_variation = &"PickupRow"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.x = PickupLog.WIDTH
		modulate.a = 0.0
		_box = HBoxContainer.new()
		_box.add_theme_constant_override(&"separation", 12)
		add_child(_box)
		var words := VBoxContainer.new()
		words.name = "Words"
		words.add_theme_constant_override(&"separation", 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_box.add_child(words)
		_kicker = BookKit.label("", &"PickupKicker")
		_kicker.name = "Kicker"
		_kicker.uppercase = true
		_kicker.visible = false
		words.add_child(_kicker)
		_label = BookKit.label("", &"PickupText", true)
		_label.name = "Name"
		words.add_child(_label)
		_line = BookKit.label("", &"PickupLine", true)
		_line.name = "Line"
		_line.visible = false
		words.add_child(_line)

	## Dresses the row as the item `id`: its icon and its name.
	func item(id: StringName) -> Row:
		var entry := ItemCatalog.get_item(id)
		if _icon == null:
			picture(ItemIcon.make(entry.icon if entry else &"trinket", entry.color if entry else JournalTheme.wash(0),
					false, entry != null and entry.rarity == &"shiny", PickupLog.ICON))
		return named(entry.display_name if entry else String(id).capitalize())

	func picture(icon: Control) -> Row:
		if _icon:
			_icon.free()
		_icon = icon
		_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_box.add_child(_icon)
		_box.move_child(_icon, 0)
		return self

	func named(text: String) -> Row:
		_name = text
		_label.text = self.text()
		return stay(PickupLog.HOLD)

	func more(n: int) -> Row:
		count += n
		_label.text = text()
		return stay(PickupLog.HOLD)

	## A kicker over the name and one line under it, and time to read them.
	func read(kicker: String, line: String) -> Row:
		_kicker.text = kicker
		_kicker.visible = kicker != ""
		_line.text = line
		_line.visible = line != ""
		return stay(PickupLog.HOLD_READ)

	## Keeps the row at least `seconds` longer.
	func stay(seconds: float) -> Row:
		_left = maxf(_left, seconds)
		return self

	func kicker() -> String:
		return _kicker.text

	func line() -> String:
		return _line.text

	func text() -> String:
		return "%s  ×%d" % [_name, count] if count > 0 else _name

	func leaving() -> bool:
		return _left <= 0.0

	func _process(delta: float) -> void:
		_left -= delta
		modulate.a = move_toward(modulate.a, 0.0 if leaving() else 1.0, delta / PickupLog.FADE)
		if leaving() and modulate.a <= 0.0:
			queue_free()
