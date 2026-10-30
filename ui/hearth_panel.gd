## The hearth: pick ingredients from the pouch and satchel, pick a method,
## cook. Dishes can be eaten or given to the family's food tally.
## Functional M1 UI; it pauses the game while open.
extends RefCounted

static var _open: CanvasLayer = null


static func open(feyre: Feyre, station: CookingStation) -> void:
	if _open and is_instance_valid(_open):
		return
	var parts := UiStyle.modal("HearthPanel")
	var layer: CanvasLayer = parts[0]
	var box: VBoxContainer = parts[1]
	_open = layer
	box.add_child(UiStyle.label(station.station.display_name, 26))
	var chosen: Array[StringName] = []
	var method := [station.station.methods[0]]
	var result_label := UiStyle.label("Choose up to %d ingredients and a method." % station.station.max_ingredients)

	var grid := GridContainer.new()
	grid.columns = 4
	box.add_child(grid)
	var ids: Array[StringName] = []
	for container: StringName in [Inventory.POUCH, Inventory.SATCHEL]:
		for id: StringName in Gameplay.inventory.contents(container):
			if ItemCatalog.get_item(id) is IngredientData and not ids.has(id):
				ids.append(id)
	if ids.is_empty():
		box.add_child(UiStyle.label("Your pouch is empty. Forage first."))
	for id in ids:
		var item := ItemCatalog.get_item(id)
		var b := UiStyle.button("%s ×%d" % [item.display_name, Gameplay.inventory.count(id)], true)
		var known := Gameplay.journal.known_tags(id)
		if not known.is_empty():
			b.tooltip_text = ", ".join(PackedStringArray(known))
		b.toggled.connect(func(on: bool) -> void:
			if on and chosen.size() < station.station.max_ingredients:
				chosen.append(id)
			elif not on:
				chosen.erase(id)
			else:
				b.set_pressed_no_signal(false))
		grid.add_child(b)

	var methods := HBoxContainer.new()
	box.add_child(methods)
	var group := ButtonGroup.new()
	for m in station.station.methods:
		var b := UiStyle.button(String(m).capitalize(), true)
		b.button_group = group
		b.button_pressed = m == method[0]
		b.pressed.connect(func() -> void: method[0] = m)
		methods.add_child(b)

	var dishes := VBoxContainer.new()
	var refresh_dishes := func() -> void:
		for c in dishes.get_children():
			c.queue_free()
		for i in Gameplay.inventory.dishes.size():
			var d: Dictionary = Gameplay.inventory.dishes[i]
			var row := HBoxContainer.new()
			row.add_child(UiStyle.label(String(d.get("name", "Dish")), 16))
			var eat := UiStyle.button("Eat")
			eat.pressed.connect(func() -> void:
				var dish := Gameplay.inventory.take_dish(i)
				if feyre.body_state:
					feyre.body_state.eat(dish)
				result_label.text = "She eats. %s" % _describe(dish)
				layer.get_meta(&"refresh").call())
			row.add_child(eat)
			if float(d.get("food_days", 0.0)) > 0.0:
				var give := UiStyle.button("Give to family")
				give.pressed.connect(func() -> void:
					var dish := Gameplay.inventory.take_dish(i)
					var days := Gameplay.food_tally.give_dish(dish)
					result_label.text = "+%.1f days of food. The tally reads %.1f." % [days, Gameplay.food_tally.days_of_food]
					layer.get_meta(&"refresh").call())
				row.add_child(give)
			dishes.add_child(row)
	layer.set_meta(&"refresh", refresh_dishes)

	var cook := UiStyle.button("Cook")
	cook.pressed.connect(func() -> void:
		var r := station.cook(chosen.duplicate(), method[0])
		if r.ok:
			result_label.text = "%s%s. %s" % [r.name, "  (new in the journal!)" if r.get("first_time", false) else "", _describe(r)]
		else:
			result_label.text = String(r.reason).capitalize()
		layer.queue_free()
		_open = null
		open(feyre, station))
	box.add_child(cook)
	box.add_child(result_label)
	box.add_child(UiStyle.label("Dishes", 20))
	box.add_child(dishes)
	refresh_dishes.call()
	var close := UiStyle.button("Close")
	close.pressed.connect(func() -> void: _close(feyre))
	box.add_child(close)
	feyre.get_tree().root.add_child(layer)
	feyre.get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func _close(feyre: Feyre) -> void:
	if _open and is_instance_valid(_open):
		_open.queue_free()
	_open = null
	feyre.get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


static func _describe(r: Dictionary) -> String:
	var parts := PackedStringArray()
	if float(r.get("hunger_relief", 0.0)) > 0.0:
		parts.append("fills %d%%" % roundi(float(r.hunger_relief) * 100.0))
	if float(r.get("heal", 0.0)) > 0.0:
		parts.append("heals")
	if float(r.get("harm", 0.0)) > 0.0:
		parts.append("bitter: it hurts")
	var effects: Dictionary = r.get("effects", {})
	for tag in effects:
		parts.append("%s %.1f" % [tag, float(effects[tag])])
	if float(r.get("fae_toll", 0.0)) > 0.0:
		parts.append("the world tilts a little")
	return ", ".join(parts).capitalize() if parts.size() > 0 else ""
