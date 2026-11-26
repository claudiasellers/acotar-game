## The brewing screen (lane L62): at any hearth, kitchen range, stillroom
## bench, potion room or the starlight pool, Feyre lays forage from her pouch
## and satchel into the pot, picks how to work it, and brews. Drawn on the
## satchel's crafted look (L50; JournalTheme only, no colours here).
##
## Two ways to fill the pot on the one page (owner, 2026-11-25). On the left,
## the recipes she knows: every brew and dish the book has recorded
## (RecipeUnlocks: made, or gathered all of). Picking one lays its makings in
## the pot and sets how to work it; one she lacks something for says what,
## and one worked somewhere else says where. On the right, her bags, to try
## what no recipe names. Discovery stays hers: an unknown brew is never
## listed, and her hunch line only names what she has made or unlocked, or
## the tags she has learned from using each ingredient. The first time a
## named brew comes out of the pot, a card shows its name and her note, with
## sparkle, chime and bounce (R3).
class_name BrewMenu
extends CanvasLayer

signal brewed(result: Dictionary)
signal closed

const WIDTH := 1140.0
## The recipes column.
const RECIPES_WIDTH := 340.0
const RECIPE_ICON := 40.0
## How faint a recipe is that she can't make here and now.
const UNMADE_ALPHA := 0.55
## The green wash: leaves in the pot.
const WASH := 2
const ICON := 52.0
const COLUMNS := 6
## The scene-tree name, kept from the M1 panel (tests and tools look for it).
const NODE_NAME := "HearthPanel"
const REVEAL_ICON := 96.0
## Effect tag -> the word Feyre senses for it.
const SENSE := {
	&"warm": "warm", &"cool": "cool", &"bright": "bright", &"quiet": "quiet",
	&"swift": "quick", &"strong": "strong", &"steady": "steadying", &"keen": "sharp",
	&"heal": "mending", &"harm": "bitter", &"fae_toll": "strange",
}

var feyre: Feyre
var station: CookingStation
var chosen: Array[StringName] = []
var method: StringName = &""
## The last brew result (empty before the first brew).
var last: Dictionary = {}

var _page: LoosePage
var _root: Control
var _title: Label
var _found: Label
var _grid: GridContainer
var _recipes: VBoxContainer
var _pot: HBoxContainer
var _methods: HBoxContainer
var _hunch: Label
var _brew: Button
var _reveal: PanelContainer
var _reveal_name: Label
var _reveal_note: Label
var _reveal_icon: TextureRect
var _outcome: Label
var _dishes: VBoxContainer
## The weapon in her hand, steeped with a steeped arrow (WeaponSteep): one
## button per arrow it would take, at a hearth or a lit camp fire.
var _steeps: HBoxContainer
## Her weapon rack, handed in by whoever opens the screen (null: no steeping).
var rack: WeaponRack


## Opens the screen at `at`, making one if the scene has none.
static func open_for(who: Feyre, at: CookingStation) -> BrewMenu:
	if who == null or at == null or not who.is_inside_tree():
		return null
	var menu := find(who.get_tree())
	if menu == null:
		menu = BrewMenu.new()
		who.get_tree().root.add_child(menu)
	menu.open(who, at, WeaponSteep.rack_of(who))
	return menu


static func find(tree: SceneTree) -> BrewMenu:
	return tree.root.get_node_or_null(NODE_NAME) as BrewMenu


func _init() -> void:
	name = NODE_NAME


func _ready() -> void:
	_build()


func is_open() -> bool:
	return _root != null and _root.visible


func open(who: Feyre, at: CookingStation, her_rack: WeaponRack = null) -> void:
	feyre = who
	station = at
	rack = her_rack
	chosen.clear()
	method = at.station.methods[0] if at.station and not at.station.methods.is_empty() else &""
	_reveal.visible = false
	_outcome.text = ""
	_root.visible = true
	_refresh()
	ScreenStack.push(self)
	_page.settle()


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	ScreenStack.pop(self)
	closed.emit()


## Esc or B while the stillroom is the top screen.
func screen_cancel() -> void:
	close()


## Adds or removes one ingredient from the pot. Returns true if it changed.
func toggle(id: StringName) -> bool:
	if chosen.has(id):
		chosen.erase(id)
	elif station and chosen.size() < station.station.max_ingredients:
		chosen.append(id)
	else:
		return false
	_refresh()
	return true


func set_method(m: StringName) -> void:
	method = m
	_refresh()


## The recipes she knows, as RecipeUnlocks gives them: what she can make
## here and now first, then what she lacks something for, then what is
## worked somewhere else.
func known_recipes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in RecipeUnlocks.all():
		if Gameplay.collection.is_found(r.id) or Gameplay.journal.has_brew(r.id):
			out.append(r)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := _rank(a)
		var rb := _rank(b)
		return ra < rb if ra != rb else String(a.name) < String(b.name))
	return out


## Whether this station works the recipe's method.
func made_here(recipe: Dictionary) -> bool:
	return station != null and station.station.methods.has(recipe.method)


## The makings of a recipe that her bags do not hold.
func missing(recipe: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in recipe.needs:
		if Gameplay.inventory.count(id) <= 0:
			out.append(id)
	return out


## Lays a known recipe's makings in the pot and sets how to work it; picking
## the one already laid empties the pot. False if it can't be made here now.
func pick(id: StringName) -> bool:
	var recipe := RecipeUnlocks.get_recipe(id)
	if recipe.is_empty() or not known_recipes().has(recipe) or not made_here(recipe) or not missing(recipe).is_empty():
		return false
	if laid() == id:
		chosen.clear()
	else:
		chosen.assign(recipe.needs)
		method = recipe.method
	_refresh()
	return true


## The known recipe the pot holds exactly, or &"".
func laid() -> StringName:
	for r in known_recipes():
		var needs: Array = r.needs
		if r.method == method and needs.size() == chosen.size() and needs.all(func(id: StringName) -> bool: return chosen.has(id)):
			return r.id
	return &""


## What a recipe's row says under its name.
func recipe_line(recipe: Dictionary) -> String:
	if not made_here(recipe):
		var place := String(RecipeUnlocks.PLACES.get(recipe.station, "somewhere else"))
		return place[0].to_upper() + place.substr(1)
	var lacking := missing(recipe)
	if not lacking.is_empty():
		return "Missing %s" % ", ".join(PackedStringArray(lacking.map(_item_name)))
	return ", ".join(PackedStringArray((recipe.needs as Array).map(_item_name)))


func _rank(recipe: Dictionary) -> int:
	if not made_here(recipe):
		return 2
	return 0 if missing(recipe).is_empty() else 1


func _item_name(id: StringName) -> String:
	var item := ItemCatalog.get_item(id)
	return (item.display_name if item else String(id)).to_lower()


## Brews what is in the pot. The result is CookingStation.cook's.
func brew() -> Dictionary:
	if station == null or chosen.is_empty():
		return {"ok": false, "reason": "the pot is empty"}
	var r := station.cook(chosen.duplicate(), method)
	last = r
	if r.ok:
		chosen.clear()
		_show_result(r)
		brewed.emit(r)
	else:
		_reveal.visible = false
		var why := String(r.reason)
		_outcome.text = why[0].to_upper() + why.substr(1) + "."
	_refresh()
	return r


## What she expects from the pot as it stands, without using anything up.
func hunch() -> String:
	if chosen.is_empty():
		return "Pick what goes in the pot."
	var items: Array[IngredientData] = []
	for id in chosen:
		items.append(ItemCatalog.get_item(id) as IngredientData)
	var r := Chemistry.combine(items, station.station if station else null, method)
	if not r.ok:
		var why := String(r.reason)
		return why[0].to_upper() + why.substr(1) + "."
	var brew_id := StringName(r.get("brew", &""))
	if brew_id != &"" and Gameplay.journal.has_brew(brew_id):
		return "%s. I've made this before." % BrewBook.get_rule(brew_id).display_name
	if brew_id != &"" and Gameplay.collection.is_found(brew_id):
		return "%s, I think. I know the recipe." % BrewBook.get_rule(brew_id).display_name
	var words := PackedStringArray()
	for id in chosen:
		if Gameplay.journal.known_tags(id).is_empty():
			return "I don't know what this will make. Only one way to find out."
	for key: StringName in SENSE:
		if BrewRule.value_of(r, key) > 0.001 and not words.has(SENSE[key]):
			words.append(SENSE[key])
	if words.is_empty():
		return "Something plain, I think."
	return "Something %s, I think." % ", ".join(words.slice(0, 3))


# --- input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if MenuTab.key_pressed(event, [KEY_E, KEY_ENTER, KEY_KP_ENTER]) or MenuTab.pad_pressed(event, JOY_BUTTON_Y):
		brew()
	else:
		return
	get_viewport().set_input_as_handled()


# --- build -------------------------------------------------------------------

func _build() -> void:
	_page = LoosePage.lay(self, WIDTH, WASH)
	_root = _page.root
	_root.visible = false
	var head := _page.head()
	_title = head[0]
	_found = head[1]

	# Two columns under the heading: the recipes she knows, and the pot.
	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 22)
	_page.column.add_child(body)
	var known := VBoxContainer.new()
	known.custom_minimum_size.x = RECIPES_WIDTH
	known.add_theme_constant_override(&"separation", 8)
	body.add_child(known)
	known.add_child(BookKit.label("Recipes I know", &"PageSection"))
	var known_scroll := ScrollContainer.new()
	known_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	known_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	known.add_child(known_scroll)
	_recipes = VBoxContainer.new()
	_recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipes.add_theme_constant_override(&"separation", 6)
	known_scroll.add_child(_recipes)
	body.add_child(VSeparator.new())
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 12)
	body.add_child(col)

	col.add_child(BookKit.label("Or try what's in my bags", &"PageSection"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, (ICON + 22.0) * 3.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", 8)
	_grid.add_theme_constant_override(&"v_separation", 8)
	scroll.add_child(_grid)

	col.add_child(HSeparator.new())
	var pot_row := HBoxContainer.new()
	pot_row.add_theme_constant_override(&"separation", 12)
	col.add_child(pot_row)
	pot_row.add_child(BookKit.label("In the pot", &"PageSection"))
	_pot = HBoxContainer.new()
	_pot.add_theme_constant_override(&"separation", 6)
	_pot.custom_minimum_size = Vector2(0, ICON)
	_pot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pot_row.add_child(_pot)
	_methods = HBoxContainer.new()
	_methods.add_theme_constant_override(&"separation", 6)
	col.add_child(_methods)
	_hunch = BookKit.label("", &"SatchelBody")
	_hunch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hunch)
	_brew = LoosePage.button("Brew")
	_brew.custom_minimum_size = Vector2(0, 44)
	_brew.pressed.connect(func() -> void: brew())
	col.add_child(_brew)

	_reveal = PanelContainer.new()
	_reveal.theme_type_variation = &"SatchelCard"
	_reveal.visible = false
	col.add_child(_reveal)
	var reveal_row := HBoxContainer.new()
	reveal_row.add_theme_constant_override(&"separation", 14)
	_reveal.add_child(reveal_row)
	_reveal_icon = TextureRect.new()
	_reveal_icon.custom_minimum_size = Vector2(REVEAL_ICON, REVEAL_ICON)
	_reveal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reveal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reveal_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reveal_row.add_child(_reveal_icon)
	var reveal_text := VBoxContainer.new()
	reveal_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reveal_row.add_child(reveal_text)
	reveal_text.add_child(BookKit.label("A new brew", &"SatchelSmall"))
	_reveal_name = BookKit.label("", &"SatchelHeading")
	reveal_text.add_child(_reveal_name)
	_reveal_note = BookKit.label("", &"SatchelBody")
	_reveal_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reveal_text.add_child(_reveal_note)
	_outcome = BookKit.label("", &"SatchelBody")
	_outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_outcome)
	_steeps = HBoxContainer.new()
	_steeps.add_theme_constant_override(&"separation", 6)
	col.add_child(_steeps)

	col.add_child(BookKit.label("Made", &"PageSection"))
	_dishes = VBoxContainer.new()
	_dishes.add_theme_constant_override(&"separation", 4)
	col.add_child(_dishes)
	_page.set_hints([["E", "Brew"], ["Esc", "Step away"]])


func _refresh() -> void:
	if station == null:
		return
	var data := station.station
	_title.text = data.display_name
	_found.text = "%d / %d brews" % [Gameplay.journal.brews.size(), BrewBook.rules().size()]
	for c in _recipes.get_children():
		_recipes.remove_child(c)
		c.queue_free()
	var known := known_recipes()
	if known.is_empty():
		_recipes.add_child(BookKit.label("None yet. What I brew, and what I gather all the makings of, gets written here.", &"SatchelSmall", true))
	var now := laid()
	for r in known:
		_recipes.add_child(_recipe_row(r, r.id == now))
	for c in _grid.get_children():
		c.queue_free()
	var ids := _pantry()
	if ids.is_empty():
		_grid.add_child(BookKit.label("Nothing to brew with. Forage first.", &"SatchelSmall"))
	for id in ids:
		_grid.add_child(_tile(id))
	for c in _pot.get_children():
		c.queue_free()
	for id in chosen:
		var item := ItemCatalog.get_item(id)
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override(&"separation", 4)
		pair.add_child(Icons.item(SatchelEntries.item_entry(Gameplay.inventory, id, &""), ICON * 0.8))
		var named := BookKit.label(item.display_name, &"SatchelSmall")
		named.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(named)
		_pot.add_child(pair)
	for c in _methods.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	for m in data.methods:
		var b := Button.new()
		b.theme_type_variation = &"SatchelTab"
		b.text = String(m).capitalize()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = m == method
		b.pressed.connect(set_method.bind(m))
		_methods.add_child(b)
	_hunch.text = hunch()
	_brew.disabled = chosen.is_empty()
	_refresh_dishes()
	_refresh_steeps()


## Steep the held weapon (WeaponSteep): a button per steeped arrow it takes.
func _refresh_steeps() -> void:
	for c in _steeps.get_children():
		_steeps.remove_child(c)
		c.queue_free()
	if not WeaponSteep.is_fire(station):
		return
	for arrow in WeaponSteep.offers(rack, Gameplay.inventory):
		_steeps.add_child(_small_button(WeaponSteep.verb(rack, arrow), steep_blade.bind(arrow)))


## Steeps the weapon in her hand with one `arrow`.
func steep_blade(arrow: StringName) -> Dictionary:
	var r := WeaponSteep.steep(rack, station, arrow)
	_reveal.visible = false
	if r.ok:
		_outcome.text = String(r.text)
		Juice.bounce_control(_outcome, 0.18)
	else:
		var why := String(r.reason)
		_outcome.text = why[0].to_upper() + why.substr(1) + "."
	_refresh()
	return r


## Every ingredient she carries, pouch first.
func _pantry() -> Array[StringName]:
	var ids: Array[StringName] = []
	for container: StringName in [Inventory.POUCH, Inventory.SATCHEL]:
		for id: StringName in Gameplay.inventory.contents(container):
			if ItemCatalog.get_item(id) is IngredientData and not ids.has(id):
				ids.append(id)
	return ids


func _tile(id: StringName) -> Button:
	var item := ItemCatalog.get_item(id)
	var left := Gameplay.inventory.count(id) - chosen.count(id)
	var b := Button.new()
	b.theme_type_variation = &"SatchelSlot"
	b.custom_minimum_size = Vector2(ICON + 56.0, ICON + 18.0)
	b.toggle_mode = true
	b.button_pressed = chosen.has(id)
	var known := Gameplay.journal.known_tags(id)
	b.tooltip_text = "%s\n%s" % [item.display_name,
			", ".join(PackedStringArray(known)) if not known.is_empty() else "I haven't used this yet."]
	b.pressed.connect(func() -> void:
		if toggle(id):
			Juice.bounce_control(_pot, 0.08))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -6
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := Icons.item(SatchelEntries.item_entry(Gameplay.inventory, id, &""), ICON)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var count := BookKit.label("×%d" % maxi(left, 0), &"SatchelCount")
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	return b


## One known recipe: its picture, its name, and what it takes or lacks.
func _recipe_row(recipe: Dictionary, is_laid: bool) -> Button:
	var b := Button.new()
	b.name = String(recipe.id)
	b.theme_type_variation = &"SatchelSlot"
	b.custom_minimum_size = Vector2(0, RECIPE_ICON + 20.0)
	b.focus_mode = Control.FOCUS_ALL
	b.toggle_mode = true
	b.button_pressed = is_laid
	b.disabled = not made_here(recipe) or not missing(recipe).is_empty()
	b.pressed.connect(func() -> void:
		if pick(recipe.id):
			Juice.bounce_control(_pot, 0.08))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := TextureRect.new()
	icon.texture = Icons.texture(Icons.BREWS, recipe.id)
	icon.custom_minimum_size = Vector2(RECIPE_ICON, RECIPE_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override(&"separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	words.add_child(BookKit.label(String(recipe.name), &"SatchelBody"))
	var line := BookKit.label(recipe_line(recipe), &"SatchelSmall")
	line.clip_text = true
	words.add_child(line)
	if b.disabled:
		row.modulate.a = UNMADE_ALPHA
	return b


func _refresh_dishes() -> void:
	for c in _dishes.get_children():
		c.queue_free()
	var inv := Gameplay.inventory
	if inv.dishes.is_empty():
		_dishes.add_child(BookKit.label("Nothing yet.", &"SatchelSmall"))
	for i in inv.dishes.size():
		var d: Dictionary = inv.dishes[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		var tex := Icons.texture(Icons.BREWS, StringName(d.get("brew", &"")))
		if tex:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.custom_minimum_size = Vector2(36, 36)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
		var title := BookKit.label(String(d.get("name", "Dish")), &"SatchelBody")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		row.add_child(_small_button("Eat" if StringName(d.get("kind", &"")) == &"food" else "Drink", eat.bind(i)))
		if float(d.get("food_days", 0.0)) > 0.0:
			row.add_child(_small_button("Give to family", give.bind(i)))
		_dishes.add_child(row)


## Feyre eats or drinks dish `i`; its effects run on her body (BodyState).
func eat(i: int) -> void:
	var dish := Gameplay.inventory.take_dish(i)
	if dish.is_empty():
		return
	if feyre and feyre.body_state:
		feyre.body_state.eat(dish)
	_outcome.text = "She takes it. %s" % describe(dish)
	_reveal.visible = false
	_refresh()


func give(i: int) -> void:
	var dish := Gameplay.inventory.take_dish(i)
	if dish.is_empty():
		return
	var days := Gameplay.food_tally.give_dish(dish)
	_outcome.text = "+%.1f days of food. The tally reads %.1f." % [days, Gameplay.food_tally.days_of_food]
	_reveal.visible = false
	_refresh()


func _show_result(r: Dictionary) -> void:
	var rule := BrewBook.get_rule(StringName(r.get("brew", &"")))
	if r.get("new_brew", false) and rule:
		_reveal.visible = true
		_reveal_name.text = String(r.name)
		_reveal_note.text = "“%s”" % rule.note
		_reveal_icon.texture = Icons.texture(Icons.BREWS, rule.id)
		_outcome.text = describe(r)
		Juice.bounce_control(_reveal, 0.18)
		Juice.bounce_control(_found.get_parent() as Control, 0.25)
	else:
		_reveal.visible = false
		_outcome.text = "%s. %s" % [r.name, describe(r)]


static func describe(r: Dictionary) -> String:
	var parts := PackedStringArray()
	if float(r.get("hunger_relief", 0.0)) > 0.0:
		parts.append("fills %d%%" % roundi(float(r.hunger_relief) * 100.0))
	if float(r.get("heal", 0.0)) > 0.0:
		parts.append("mends")
	if float(r.get("harm", 0.0)) > 0.0:
		parts.append("bitter: it hurts")
	var effects: Dictionary = r.get("effects", {})
	for tag: Variant in effects:
		parts.append(String(SENSE.get(StringName(tag), String(tag))))
	if float(r.get("fae_toll", 0.0)) > 0.0:
		parts.append("the world tilts a little")
	if r.has("arrows"):
		parts.append("%d arrows coated" % int(r.arrows.count))
	if parts.is_empty():
		return ""
	var line := ", ".join(parts) + "."
	return line[0].to_upper() + line.substr(1)


func _small_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"SatchelTab"
	b.text = text
	b.pressed.connect(action)
	return b
