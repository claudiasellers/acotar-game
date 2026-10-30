## Ingredient tags + station + method -> effect (root doc §5, Keeper-adjusted).
##
## Rules:
## - Same tags reinforce: n copies give n * (1 + REINFORCE * (n - 1)).
## - Opposites cancel: warm/cool, quiet/bright, vital/bitter.
## - Bitter flips healing to harm: when bitter outweighs vital, the net is harm.
## - Fae multiplies every other effect and adds to the fae toll (halved at a
##   fae-safe station). It reads as faerie-wine giddiness, not poison.
## - Bind is required for salves and steeps; it is structural, not an effect.
## - Ash is apply-only: it never goes into the pot (arrows only).
class_name Chemistry
extends RefCounted

const REINFORCE := 0.25
const FAE_MULTIPLIER := 0.5
const OPPOSITES := [[&"warm", &"cool"], [&"quiet", &"bright"]]
## Tags that are not effects.
const STRUCTURAL: Array[StringName] = [&"bind", &"preserve", &"ash", &"fae", &"vital", &"bitter"]
const FOOD_METHODS: Array[StringName] = [&"roast", &"stew", &"cook", &"bake", &"preserve"]
const BIND_METHODS: Array[StringName] = [&"salve", &"steep"]

## method -> {nutrition, food_days, potency, duration, warm}
const METHODS := {
	&"roast": {"nutrition": 1.0, "food_days": 1.0, "potency": 0.8, "duration": 120.0, "warm": 0.5},
	&"stew": {"nutrition": 1.3, "food_days": 1.5, "potency": 1.0, "duration": 300.0, "warm": 1.0},
	&"infuse": {"nutrition": 0.2, "food_days": 0.0, "potency": 1.2, "duration": 240.0, "warm": 0.5},
	&"cook": {"nutrition": 1.2, "food_days": 1.3, "potency": 1.0, "duration": 240.0, "warm": 0.5},
	&"bake": {"nutrition": 1.2, "food_days": 1.4, "potency": 0.9, "duration": 240.0, "warm": 0.3},
	&"preserve": {"nutrition": 1.0, "food_days": 2.0, "potency": 0.6, "duration": 120.0, "warm": 0.0},
	&"distill": {"nutrition": 0.0, "food_days": 0.0, "potency": 1.6, "duration": 300.0, "warm": 0.0},
	&"salve": {"nutrition": 0.0, "food_days": 0.0, "potency": 1.4, "duration": 600.0, "warm": 0.0},
	&"steep": {"nutrition": 0.0, "food_days": 0.0, "potency": 1.5, "duration": 0.0, "warm": 0.0},
	&"tincture": {"nutrition": 0.0, "food_days": 0.0, "potency": 1.8, "duration": 360.0, "warm": 0.0},
}
const HEAL_PER_VITAL := 0.15
const DISH_DIR := "res://data/dishes"

static var _dishes: Array[DishData] = []


## Combines ingredients. Always returns a Dictionary; "ok" says whether it
## worked and "reason" why not.
static func combine(ingredients: Array[IngredientData], station: StationData, method: StringName) -> Dictionary:
	var fail := func(reason: String) -> Dictionary: return {"ok": false, "reason": reason}
	if ingredients.is_empty():
		return fail.call("nothing to combine")
	if station and not station.methods.has(method):
		return fail.call("%s can't %s" % [station.display_name, method])
	if station and ingredients.size() > station.max_ingredients:
		return fail.call("too many ingredients")
	if not METHODS.has(method):
		return fail.call("unknown method")
	var all_pigment := ingredients.all(func(i: IngredientData) -> bool:
		return i.pigment != &"" or i.has_tag(&"bind"))
	var any_pigment := ingredients.any(func(i: IngredientData) -> bool: return i.pigment != &"")
	if method == &"infuse" and all_pigment and any_pigment:
		return _pigment(ingredients)
	for i in ingredients:
		if i.is_apply_only():
			return fail.call("%s never goes in the pot" % i.display_name)
		if not i.edible and FOOD_METHODS.has(method):
			return fail.call("%s isn't food" % i.display_name)
		if not i.edible and method == &"infuse" and not i.has_tag(&"bind") and i.pigment == &"":
			return fail.call("%s won't steep into anything drinkable" % i.display_name)
	var has_bind := ingredients.any(func(i: IngredientData) -> bool: return i.has_tag(&"bind"))
	if BIND_METHODS.has(method) and not has_bind:
		return fail.call("needs something to bind it")

	var m: Dictionary = METHODS[method]
	var totals := tag_totals(ingredients)
	for pair in OPPOSITES:
		_cancel(totals, pair[0], pair[1])
	var fae := float(totals.get(&"fae", 0.0))
	var multiplier := 1.0 + FAE_MULTIPLIER * fae
	var fae_toll := fae * (0.5 if station and station.fae_safe else 1.0)
	var vital := float(totals.get(&"vital", 0.0)) - float(totals.get(&"bitter", 0.0))

	var effects := {}
	for tag: StringName in totals:
		if STRUCTURAL.has(tag):
			continue
		var value := float(totals[tag]) * float(m.potency) * multiplier
		if value > 0.001:
			effects[tag] = snappedf(value, 0.001)
	if float(m.warm) > 0.0 and not effects.has(&"cool"):
		effects[&"warm"] = snappedf(float(effects.get(&"warm", 0.0)) + float(m.warm), 0.001)

	var nutrition := 0.0
	var food_days := 0.0
	for i in ingredients:
		nutrition += i.nutrition
		food_days += i.food_days
	var strongest := 0.0
	for v: float in effects.values():
		strongest = maxf(strongest, v)
	var ids := ingredients.map(func(i: IngredientData) -> StringName: return i.id)
	var result := {
		"ok": true,
		"reason": "",
		"key": journal_key(method, ids),
		"method": method,
		"ingredients": ids,
		"effects": effects,
		"heal": snappedf(maxf(vital, 0.0) * HEAL_PER_VITAL * multiplier * float(m.potency), 0.001),
		"harm": snappedf(maxf(-vital, 0.0) * HEAL_PER_VITAL * multiplier * float(m.potency), 0.001),
		"hunger_relief": snappedf(minf(nutrition * float(m.nutrition), 1.0), 0.001),
		"food_days": snappedf(food_days * float(m.food_days), 0.001),
		"fae_toll": snappedf(fae_toll, 0.001),
		"duration": float(m.duration) * (1.0 + 0.25 * maxf(strongest - 1.0, 0.0)),
		"kind": _kind(method, nutrition, vital),
	}
	result["name"] = dish_name(method, ingredients)
	return result


## Tag -> reinforced magnitude.
static func tag_totals(ingredients: Array[IngredientData]) -> Dictionary:
	var counts := {}
	for i in ingredients:
		for tag in i.tags:
			counts[tag] = int(counts.get(tag, 0)) + 1
	var totals := {}
	for tag: StringName in counts:
		var n := int(counts[tag])
		totals[tag] = n * (1.0 + REINFORCE * (n - 1))
	return totals


static func journal_key(method: StringName, ids: Array) -> String:
	var sorted := ids.map(func(id: Variant) -> String: return String(id))
	sorted.sort()
	return "%s:%s" % [method, "+".join(PackedStringArray(sorted))]


static func dish_name(method: StringName, ingredients: Array[IngredientData]) -> String:
	var ids := ingredients.map(func(i: IngredientData) -> StringName: return i.id)
	var best: DishData = null
	for dish in dishes():
		if dish.method != method:
			continue
		if dish.required.all(func(r: StringName) -> bool: return ids.has(r)):
			if best == null or dish.required.size() > best.required.size():
				best = dish
	if best:
		return best.display_name
	var main := ingredients[0]
	for i in ingredients:
		if i.nutrition > main.nutrition:
			main = i
	var noun := main.display_name.to_lower()
	match method:
		&"roast":
			return "Roast %s" % noun
		&"stew":
			return "Stew of %s" % noun if ingredients.size() == 1 else "Stew of %s and more" % noun
		&"infuse":
			return "Infusion of %s" % noun
		&"salve":
			return "%s salve" % main.display_name
		&"steep":
			return "%s steep" % main.display_name
	return "%s (%s)" % [main.display_name, method]


static func dishes() -> Array[DishData]:
	if _dishes.is_empty():
		for file in ResourceLoader.list_directory(DISH_DIR):
			if file.ends_with(".tres") or file.ends_with(".res"):
				var d := load(DISH_DIR.path_join(file)) as DishData
				if d:
					_dishes.append(d)
	return _dishes


static func _cancel(totals: Dictionary, a: StringName, b: StringName) -> void:
	var va := float(totals.get(a, 0.0))
	var vb := float(totals.get(b, 0.0))
	totals.erase(a)
	totals.erase(b)
	if va > vb:
		totals[a] = va - vb
	elif vb > va:
		totals[b] = vb - va


static func _kind(method: StringName, nutrition: float, vital: float) -> StringName:
	if vital < 0.0:
		return &"poison"
	if FOOD_METHODS.has(method) or nutrition >= 0.1:
		return &"food"
	if method == &"infuse":
		return &"tea"
	if method == &"steep":
		return &"steep"
	return &"remedy"


static func _pigment(ingredients: Array[IngredientData]) -> Dictionary:
	var colors: Array[StringName] = []
	for i in ingredients:
		if i.pigment != &"" and not colors.has(i.pigment):
			colors.append(i.pigment)
	var ids := ingredients.map(func(i: IngredientData) -> StringName: return i.id)
	var bound := ingredients.any(func(i: IngredientData) -> bool: return i.has_tag(&"bind"))
	return {
		"ok": true, "reason": "", "key": journal_key(&"infuse", ids), "method": &"infuse",
		"ingredients": ids, "effects": {}, "heal": 0.0, "harm": 0.0, "hunger_relief": 0.0,
		"food_days": 0.0, "fae_toll": 0.0, "duration": 0.0, "kind": &"pigment",
		"pigments": colors, "bound": bound,
		"name": "%s paint" % " and ".join(PackedStringArray(colors.map(func(c: StringName) -> String: return String(c).replace("_", " ")))).capitalize(),
	}
