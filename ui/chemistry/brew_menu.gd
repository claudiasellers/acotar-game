## The brewing screen (lane L62): at any hearth, kitchen range, stillroom
## bench, potion room or the starlight pool, Feyre lays forage from her pouch
## and satchel into the pot, picks how to work it, and brews. Drawn on the
## open tin (OpenTin; owner, 2026-11-26), so the bench stays on screen:
## JournalTheme only, no colours here.
##
## Two ways to fill the pot (owner, 2026-11-25). On the tin's lid, the
## recipes she knows: every brew and dish the book has recorded
## (RecipeUnlocks: made, or gathered all of). Picking one lays its makings in
## the pot and sets how to work it; one she lacks something for says what,
## and one worked somewhere else says where. In the tin, her bags as pans, to
## try what no recipe names, and the pot as a well at its right end. What she
## has made, and steeping a blade, are on a slip above the tin. Discovery stays hers: an unknown brew is never
## listed, and her hunch line only names what she has made or unlocked, or
## the tags she has learned from using each ingredient. The first time a
## named brew comes out of the pot, a card shows its name and her note, with
## sparkle, chime and bounce (R3).
class_name BrewMenu
extends CanvasLayer

signal brewed(result: Dictionary)
signal closed

## The lid her recipes stand on, the tin's left compartment, the pot's well,
## and the slip of what she has made.
const LID_WIDTH := 372.0
const LEFT_WIDTH := 300.0
const POT_WIDTH := 440.0
const SLIP_WIDTH := 520.0
const RECIPE_ICON := 40.0
## How faint a recipe is that she can't make here and now.
const UNMADE_ALPHA := 0.55
## What is in the pot, pictured.
const POT_ICON := 56.0
## Her bags: pans to a row, and how many rows show before they scroll.
const COLUMNS := 8
const ROWS_SHOWN := 2
const PAN_GAP := 8
## A method's picture: a brew worked that way, until the methods have
## glyphs of their own.
const METHOD_ICON := 24
const METHOD_BREWS := {
	&"infuse": &"brew_steadying_tea", &"distill": &"brew_glow_draught", &"salve": &"brew_healing_salve",
	&"steep": &"brew_hush_steep", &"tincture": &"brew_giddy_tincture", &"roast": &"brew_spit_roast",
	&"stew": &"brew_hearty_stew", &"cook": &"brew_hunters_stew", &"bake": &"brew_honey_cakes",
	&"preserve": &"brew_hedgerow_preserve",
}
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

var tin: OpenTin
var _title: Label
var _found: Label
var _grid: GridContainer
var _recipes: VBoxContainer
var _pot: HFlowContainer
var _methods: GridContainer
var _hunch: Label
var _brew: Button
var _reveal: PanelContainer
var _reveal_name: Label
var _reveal_note: Label
var _reveal_icon: TextureRect
var _outcome: Label
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
	return tin != null and tin.visible


func open(who: Feyre, at: CookingStation, her_rack: WeaponRack = null) -> void:
	feyre = who
	station = at
	rack = her_rack
	chosen.clear()
	method = at.station.methods[0] if at.station and not at.station.methods.is_empty() else &""
	_reveal.visible = false
	_outcome.text = ""
	tin.visible = true
	_refresh()
	ScreenStack.push(self)
	tin.settle()


func close() -> void:
	if not is_open():
		return
	tin.visible = false
	ScreenStack.pop(self)
	closed.emit()


## Esc or B while the stillroom is the top screen.
func screen_cancel() -> void:
	close()


## A pad starts on the first recipe she can lay, or the first thing in her bags.
func screen_focus() -> void:
	for group: Control in [_recipes, _grid]:
		for c in group.get_children():
			if c is Button and not (c as Button).disabled:
				(c as Button).grab_focus()
				return


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
	tin = OpenTin.lay(self, true)
	tin.visible = false
	var known := tin.lid(LID_WIDTH)
	var known_head := BookKit.label("Recipes I know", &"PageSection")
	known_head.uppercase = true
	known.add_child(known_head)
	_recipes = VBoxContainer.new()
	_recipes.name = "Recipes"
	_recipes.add_theme_constant_override(&"separation", 4)
	known.add_child(_recipes)

	var left := tin.compartment(LEFT_WIDTH)
	var head := OpenTin.head(left, "", " ")
	_title = head[0]
	_found = head[1]
	left.add_child(OpenTin.section("How"))
	_methods = GridContainer.new()
	_methods.columns = 2
	_methods.add_theme_constant_override(&"h_separation", 8)
	_methods.add_theme_constant_override(&"v_separation", 8)
	left.add_child(_methods)
	left.add_child(BookKit.spring())
	var away := OpenTin.hint_button("Esc", "Step away")
	away.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	away.pressed.connect(close)
	left.add_child(away)

	var bags := tin.compartment()
	bags.add_child(OpenTin.section("What's in my bags"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = OpenTin.Pan.small_height() * ROWS_SHOWN + PAN_GAP * (ROWS_SHOWN - 1)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	bags.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", PAN_GAP)
	_grid.add_theme_constant_override(&"v_separation", PAN_GAP)
	scroll.add_child(_grid)

	var pot_side := tin.compartment(POT_WIDTH)
	var pot_well := OpenTin.well()
	pot_well.name = "Pot"
	pot_well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pot_side.add_child(pot_well)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	pot_well.add_child(col)
	var pot_head := BookKit.label("In the pot", &"PageSection")
	pot_head.uppercase = true
	col.add_child(pot_head)
	_pot = HFlowContainer.new()
	_pot.add_theme_constant_override(&"h_separation", 14)
	_pot.add_theme_constant_override(&"v_separation", 4)
	col.add_child(_pot)
	_hunch = BookKit.label("", &"ThoughtText", true)
	col.add_child(_hunch)
	_reveal = PanelContainer.new()
	_reveal.theme_type_variation = &"LineBare"
	_reveal.visible = false
	col.add_child(_reveal)
	var reveal_row := HBoxContainer.new()
	reveal_row.add_theme_constant_override(&"separation", 14)
	_reveal.add_child(reveal_row)
	_reveal_icon = BookKit.picture(null, Vector2(REVEAL_ICON, REVEAL_ICON))
	_reveal_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reveal_row.add_child(_reveal_icon)
	var reveal_text := VBoxContainer.new()
	reveal_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reveal_text.add_theme_constant_override(&"separation", 0)
	reveal_row.add_child(reveal_text)
	reveal_text.add_child(BookKit.label("A new brew", &"SatchelSmall"))
	_reveal_name = BookKit.label("", &"SatchelHeading", true)
	reveal_text.add_child(_reveal_name)
	_reveal_note = BookKit.label("", &"SatchelWhere", true)
	reveal_text.add_child(_reveal_note)
	_outcome = BookKit.label("", &"SatchelBody", true)
	col.add_child(_outcome)
	col.add_child(BookKit.spring())
	_brew = OpenTin.key_button("E", "Brew")
	_brew.name = "Brew"
	_brew.pressed.connect(func() -> void: brew())
	col.add_child(_brew)


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
		_grid.remove_child(c)
		c.queue_free()
	var ids := _pantry()
	_grid.columns = COLUMNS if not ids.is_empty() else 1
	if ids.is_empty():
		_grid.add_child(OpenTin.words("Nothing to brew with. Forage first."))
	for id in ids:
		_grid.add_child(_tile(id))
	for c in _pot.get_children():
		c.queue_free()
	for id in chosen:
		var item := ItemCatalog.get_item(id)
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override(&"separation", 6)
		pair.add_child(Icons.item(SatchelEntries.item_entry(Gameplay.inventory, id, &""), POT_ICON))
		var named := BookKit.label(item.display_name, &"SatchelBody")
		named.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(named)
		_pot.add_child(pair)
	_pot.visible = not chosen.is_empty()
	for c in _methods.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	for m in data.methods:
		var b := BookKit.chip(String(m).capitalize())
		b.name = String(m)
		b.focus_mode = Control.FOCUS_ALL
		b.icon = Icons.texture(Icons.BREWS, METHOD_BREWS.get(m, &""))
		b.add_theme_constant_override(&"icon_max_width", METHOD_ICON)
		b.button_group = group
		b.button_pressed = m == method
		b.pressed.connect(set_method.bind(m))
		_methods.add_child(b)
	_hunch.text = hunch()
	# The discovery, when there is one, has the well to itself.
	_hunch.visible = not _reveal.visible
	_outcome.visible = _outcome.text != ""
	_brew.disabled = chosen.is_empty()
	(_brew.get_node("Row") as Control).modulate.a = UNMADE_ALPHA if _brew.disabled else 1.0
	_refresh_slip()


## What she has made here, and steeping the weapon in her hand (WeaponSteep:
## a chip per steeped arrow it takes, at a hearth or a lit camp fire), on a
## slip above the tin. With neither, there is no slip.
func _refresh_slip() -> void:
	var inv := Gameplay.inventory
	var arrows: Array[StringName] = []
	if WeaponSteep.is_fire(station):
		arrows = WeaponSteep.offers(rack, inv)
	if inv.dishes.is_empty() and arrows.is_empty():
		tin.drop_slip()
		return
	var slip := tin.slip(SLIP_WIDTH)
	if not inv.dishes.is_empty():
		slip.add_child(_paper_section("Made"))
	for i in inv.dishes.size():
		var d: Dictionary = inv.dishes[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		var tex := Icons.texture(Icons.BREWS, StringName(d.get("brew", &"")))
		if tex:
			row.add_child(BookKit.picture(tex, Vector2(36, 36)))
		var title := BookKit.label(String(d.get("name", "Dish")), &"SatchelBody")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		row.add_child(_small_button("Eat" if StringName(d.get("kind", &"")) == &"food" else "Drink", eat.bind(i)))
		if float(d.get("food_days", 0.0)) > 0.0:
			row.add_child(_small_button("Give to family", give.bind(i)))
		slip.add_child(row)
	if not arrows.is_empty():
		slip.add_child(_paper_section("Steep a blade"))
		var steeps := HFlowContainer.new()
		steeps.name = "Steeps"
		steeps.add_theme_constant_override(&"h_separation", 6)
		steeps.add_theme_constant_override(&"v_separation", 6)
		slip.add_child(steeps)
		for arrow in arrows:
			steeps.add_child(_small_button(WeaponSteep.verb(rack, arrow), steep_blade.bind(arrow)))


func _paper_section(text: String) -> Label:
	var l := BookKit.label(text, &"PageSection")
	l.uppercase = true
	return l


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
	var pan := OpenTin.pan(Icons.item(SatchelEntries.item_entry(Gameplay.inventory, id, &""), OpenTin.Pan.ICON_SMALL), "", true)
	pan.name = String(id)
	pan.wash = _grid.get_child_count()
	pan.in_pot = chosen.has(id)
	pan.count("×%d" % maxi(left, 0))
	var known := Gameplay.journal.known_tags(id)
	pan.tooltip_text = "%s\n%s" % [item.display_name,
			", ".join(PackedStringArray(known)) if not known.is_empty() else "I haven't used this yet."]
	pan.pressed.connect(func() -> void:
		if toggle(id):
			Juice.bounce_control(_pot, 0.08))
	return pan


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
	var icon := BookKit.picture(Icons.texture(Icons.BREWS, recipe.id), Vector2(RECIPE_ICON, RECIPE_ICON))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
		Juice.bounce_control(_found, 0.25)
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
