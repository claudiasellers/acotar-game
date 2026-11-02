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
const KIT := "res://story/market/assets/%s.glb"
## Awning tones, so neighbours differ (tools/market/market_kit.py TONES).
const TONE := {
	&"charms": "slate", &"spice": "madder", &"cobbler": "oat", &"grain": "rust", &"clothier": "slate",
	&"baker": "oat", &"wool": "madder", &"roots": "rust", &"tinker": "slate", &"salt": "oat",
}
## Nudges off the generated ring: [metres forward(+)/back along the stall's
## facing, metres sideways, yaw radians]. The cobbler stays put: Act I's
## act1_fur_stall anchor stands at its counter.
const NUDGE := {
	&"charms": [0.8, 0.3, 0.12], &"spice": [-0.6, 0.0, -0.08], &"cobbler": [0.0, 0.0, 0.0],
	&"grain": [0.9, -0.2, 0.15], &"clothier": [-0.7, 0.4, -0.14], &"baker": [1.0, -0.3, 0.22],
	&"wool": [0.0, 0.5, 0.06], &"roots": [0.3, 0.0, -0.1], &"tinker": [0.0, -0.4, -0.05], &"salt": [0.4, 0.0, 0.08],
}
## Set dressing for the square: [kit name, x, z, yaw, collision box size].
const DRESSING := [
	["handcart", 363.0, 2246.5, 0.6, Vector3(1.6, 1.1, 1.0)],
	["crate_pile", 392.5, 2259.0, -0.4, Vector3(1.6, 1.0, 1.2)],
]
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
			s.stall_path = KIT % ("stall_" + TONE[trade])
			s.goods_path = KIT % ("goods_" + trade)
			s.sign_path = KIT % ("sign_" + trade)
			s.scatter_position = Vector3(layer.instances[i * 5], layer.instances[i * 5 + 1], layer.instances[i * 5 + 2])
			var yaw0: float = layer.instances[i * 5 + 3]
			var nudge: Array = NUDGE[trade]
			var b := Basis(Vector3.UP, yaw0)
			var p := s.scatter_position + b * Vector3(float(nudge[1]), 0.0, float(nudge[0]))
			p.y = WorldHeight.height_at(p.x, p.z) if nudge[0] != 0.0 or nudge[1] != 0.0 else s.scatter_position.y
			s.position = p
			s.yaw = yaw0 + float(nudge[2])
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
	for d: Array in DRESSING:
		set.dressing_paths.append(KIT % d[0])
		set.dressing_xforms.append(Transform3D(Basis(Vector3.UP, d[3]), Vector3(d[1], WorldHeight.height_at(d[1], d[2]), d[2])))
		set.dressing_boxes.append(d[4])
	for st in set.stalls:
		if st.buyer or st.trade in [&"grain", &"roots"]:
			print("keeper %s: %.2f, %.2f yaw %.1f" % [st.trade, st.keeper_spot().x, st.keeper_spot().z, rad_to_deg(st.yaw + PI)])
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
