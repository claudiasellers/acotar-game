## Builds data/market/market.tres from the village scatter (lane L53):
##   godot --headless -s res://tools/market/gen_market.gd
## Every stall the village generator laid out (its goods layer instances) gets
## one trade, matched by goods kind in the order the scatter lists them, so a
## village regeneration that keeps the stalls keeps the trades. The test
## tests/unit/market/test_market.gd fails if a stall goes missing.
## Lines and canon from the Keeper (ch 3, lines 676-990).
extends SceneTree

const OUT := "res://data/market/market.tres"
const SCATTER := "res://world/human_realm/village/scatter/%s.tres"
const VILLAGE := "res://world/human_realm/village/village.tscn"
const SIGN := "res://story/market/assets/sign_%s.glb"
## The cottage fork, a few metres down the village road (HumanRealmLayout.ROADS[0]).
const FORK_FROM := Vector2(-150.0, 2160.0)
const FORK_TOWARD := Vector2(-20.0, 2200.0)
const FORK_ALONG := 27.0
const FORK_SIDE := 3.6

## goods layer -> trades, one per instance in scatter order (square first, then the north lane).
const TRADES := {
	&"goods_iron": [&"charms", &"tinker"],
	&"goods_salt": [&"spice", &"salt"],
	&"goods_pelts": [&"cobbler"],
	&"goods_grain": [&"grain", &"baker", &"roots"],
	&"goods_furs": [&"clothier", &"wool"],
}
## trade -> [name, canon]
const NAMES := {
	&"charms": ["charms and bits of iron", "C"], &"tinker": ["the tinker", "C"],
	&"spice": ["hot food and spice", "C"], &"salt": ["salt", "C"],
	&"cobbler": ["the cobbler", "C"], &"clothier": ["the clothier", "C"],
	&"grain": ["grain", "C"], &"baker": ["bread", "X"], &"roots": ["roots and turnips", "X"],
	&"wool": ["wool and old cloth", "X"],
}
const HIDES := ["ing_hide", "ing_hare_pelt", "ing_wolf_pelt", "obj_wolf_pelt"]
const GAME := ["ing_rabbit", "ing_hare", "ing_venison", "ing_boar", "ing_trout", "ing_dead_chicken"]


func _initialize() -> void:
	var set := MarketSet.new()
	var used := {}
	for layer_id: StringName in TRADES:
		var layer := load(SCATTER % layer_id) as ScatterLayer
		if layer == null:
			push_error("gen_market: no scatter layer %s" % layer_id)
			quit(1)
			return
		var trades: Array = TRADES[layer_id]
		var n := layer.instances.size() / 5
		for i in n:
			if i >= trades.size():
				push_error("gen_market: %s has more stalls (%d) than trades" % [layer_id, n])
				break
			var trade: StringName = trades[i]
			var s := MarketStall.new()
			s.trade = trade
			s.display_name = NAMES[trade][0]
			s.canon = NAMES[trade][1]
			s.sign_path = SIGN % trade
			s.position = Vector3(layer.instances[i * 5], layer.instances[i * 5 + 1], layer.instances[i * 5 + 2])
			s.yaw = layer.instances[i * 5 + 3]
			s.buyer = _buyer(trade)
			set.stalls.append(s)
			used[trade] = true
	set.mercenary = _mercenary()
	var well := _well()
	# She stands at the well's lip on the side the cottage road comes in by, facing it.
	set.mercenary_at = well + Vector3(-1.45, 0.0, 0.0)
	set.mercenary_yaw = PI / 2.0
	var dir := (FORK_TOWARD - FORK_FROM).normalized()
	var at := FORK_FROM + dir * FORK_ALONG + Vector2(dir.y, -dir.x) * FORK_SIDE
	set.fingerpost_at = Vector3(at.x, WorldHeight.height_at(at.x, at.y), at.y)
	# The arm (local +Z) points down the road to the village.
	set.fingerpost_yaw = atan2(dir.x, dir.y)
	var err := ResourceSaver.save(set, OUT)
	print("gen_market: %d stalls (%d buy from Feyre), mercenary at %s -> %s (%d)" % [
			set.stalls.size(), set.buyers().size() - 1, set.mercenary_at, OUT, err])
	quit(0 if err == OK else 1)


func _well() -> Vector3:
	var packed := load(VILLAGE) as PackedScene
	var state := packed.get_state()
	for i in state.get_node_count():
		if state.get_node_name(i) != &"VillageWell":
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"transform":
				return (state.get_node_property_value(i, p) as Transform3D).origin
	push_error("gen_market: no VillageWell in the village scene")
	return HumanRealmLayout.VILLAGE_SQUARE.x * Vector3.RIGHT + HumanRealmLayout.VILLAGE_SQUARE.y * Vector3.BACK


func _mercenary() -> MarketBuyer:
	var b := MarketBuyer.new()
	b.id = &"mercenary"
	b.display_name = "the woman at the well"
	b.canon = "C"
	b.buys = PackedStringArray(["obj_wolf_pelt", "ing_wolf_pelt", "ing_hide"])
	# She overpays, by a lot (the text names no price: the number is [X]).
	b.price_factor = 1.5
	b.greeting = "What is your business with me, girl?"
	b.thanks = "Doesn't seem like a faerie. From one hunter to another: stay out of the deep woods."
	b.nothing = "I travel light. Coin for hides, nothing else."
	return b


func _buyer(trade: StringName) -> MarketBuyer:
	var b := MarketBuyer.new()
	b.id = trade
	b.display_name = NAMES[trade][0]
	match trade:
		&"cobbler", &"clothier":
			# Her usual buyers, from the town nearby; they bid low [C].
			b.canon = "C"
			b.buys = PackedStringArray(HIDES + ["ing_sinew"] if trade == &"cobbler" else HIDES)
			b.price_factor = 0.6
			b.greeting = "Hides again? Let's see them." if trade == &"cobbler" else "Show me. Quickly, girl."
			b.thanks = "That'll do." if trade == &"cobbler" else "Fair enough. Next time, bring them clean."
			b.nothing = "Nothing I can use." if trade == &"cobbler" else "No hides, no business."
		&"spice":
			# Hot food and spice: a buyer for game is invented [X].
			b.canon = "X"
			b.buys = PackedStringArray(GAME + ["ing_honey", "ing_wild_garlic", "ing_juniper_berry", "ing_salt"])
			b.price_factor = 0.8
			b.greeting = "Fresh meat? I'll take it off your hands."
			b.thanks = "Into the pot it goes."
			b.nothing = "Nothing for my pot there."
		&"charms":
			# The charm stalls ("charms and baubles and incantations and bits
			# of iron") taking herbs and odd finds is invented [X].
			b.canon = "X"
			b.buys = PackedStringArray(["ing_crow_feather", "ing_owl_feather", "ing_hawk_feather",
					"ing_shed_antler", "ing_iron_filings", "ing_oak_gall", "ing_snail_shell"])
			b.buys_tags = PackedStringArray(["bitter", "quiet", "keen", "steady", "cool", "warm", "bind", "swift", "bright", "vital", "strong"])
			b.refuses = PackedStringArray(GAME + HIDES + ["ing_salt", "ing_venison_stew"])
			b.price_factor = 1.0
			b.greeting = "Herbs for charms? Iron wards and rowan, that's what keeps them out."
			b.thanks = "Good. That'll ward a doorway."
			b.nothing = "Nothing a charm wants."
		_:
			return null
	return b
