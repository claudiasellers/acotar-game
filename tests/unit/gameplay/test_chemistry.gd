extends GutTest

const HEARTH := preload("res://data/stations/hearth.tres")
const STILLROOM := preload("res://data/stations/stillroom.tres")
const FAE_ROOM := preload("res://data/stations/fae_potion_room.tres")


func _ing(ids: Array) -> Array[IngredientData]:
	var out: Array[IngredientData] = []
	for id in ids:
		out.append(ItemCatalog.get_item(StringName(id)) as IngredientData)
	return out


func test_same_tags_reinforce() -> void:
	var t := Chemistry.tag_totals(_ing(["ing_snowdrop", "ing_snowdrop"]))
	assert_almost_eq(float(t[&"steady"]), 2.5, 0.001)


func test_opposites_cancel() -> void:
	# Blackberry: vital+warm; snowdrop: cool+steady. warm and cool cancel.
	var r := Chemistry.combine(_ing(["ing_blackberry", "ing_snowdrop"]), HEARTH, &"infuse")
	assert_true(r.ok)
	assert_false(r.effects.has(&"cool"))
	assert_true(r.effects.has(&"steady"))


func test_bitter_flips_healing_to_harm() -> void:
	# Acorn: strong+bitter, sloe: bitter+bind -> bitter 2.5 vs no vital.
	var r := Chemistry.combine(_ing(["ing_acorn", "ing_sloe"]), HEARTH, &"stew")
	assert_true(r.ok)
	assert_gt(r.harm, 0.0)
	assert_eq(r.heal, 0.0)
	assert_eq(r.kind, &"poison")


func test_venison_stew_feeds_the_family() -> void:
	var r := Chemistry.combine(_ing(["ing_venison", "ing_snowmelt_water"]), HEARTH, &"stew")
	assert_true(r.ok)
	assert_eq(r.name, "Venison stew")
	assert_almost_eq(r.food_days, 2.25, 0.001)
	assert_gt(r.heal, 0.0)
	assert_gte(float(r.effects[&"warm"]), 1.0, "a stew always warms")


func test_stew_stretches_food_more_than_roast() -> void:
	var stew := Chemistry.combine(_ing(["ing_hare"]), HEARTH, &"stew")
	var roast := Chemistry.combine(_ing(["ing_hare"]), HEARTH, &"roast")
	assert_gt(stew.food_days, roast.food_days)
	assert_eq(roast.name, "Roast hare")


func test_fae_multiplies_and_tolls() -> void:
	var plain := Chemistry.combine(_ing(["ing_honeysuckle"]), FAE_ROOM, &"infuse")
	var fae := Chemistry.combine(_ing(["ing_honeysuckle", "ing_candied_flowers"]), FAE_ROOM, &"infuse")
	assert_gt(float(fae.effects[&"swift"]), float(plain.effects[&"swift"]))
	assert_almost_eq(fae.fae_toll, 0.5, 0.001, "fae-safe station halves the toll")


func test_bind_required_for_salves() -> void:
	assert_false(Chemistry.combine(_ing(["ing_snowdrop"]), STILLROOM, &"salve").ok)
	assert_true(Chemistry.combine(_ing(["ing_snowdrop", "ing_willow_bark"]), STILLROOM, &"salve").ok)


func test_ash_is_never_eaten_and_hides_arent_food() -> void:
	assert_false(Chemistry.combine(_ing(["ing_ash_wood", "ing_venison"]), HEARTH, &"stew").ok)
	assert_false(Chemistry.combine(_ing(["ing_hide"]), HEARTH, &"roast").ok)


func test_hearth_rejects_unknown_methods() -> void:
	assert_false(Chemistry.combine(_ing(["ing_snowdrop"]), HEARTH, &"distill").ok)


func test_pigment_infusion() -> void:
	var r := Chemistry.combine(_ing(["ing_woad", "ing_clay"]), HEARTH, &"infuse")
	assert_true(r.ok)
	assert_eq(r.kind, &"pigment")
	assert_true((r.pigments as Array).has(&"blue"))


func test_journal_records_once_and_learns_tags() -> void:
	var j := ProofJournal.new()
	var ings := _ing(["ing_pine_needles"])
	var r := Chemistry.combine(ings, HEARTH, &"infuse")
	assert_true(j.record(r, ings))
	assert_false(j.record(r, ings))
	assert_eq(j.count(), 1)
	assert_true(j.known_tags(&"ing_pine_needles").has("keen"))
	assert_eq(r.name, "Pine-needle tea")
