## The village market (lane L53): every stall has one trade and a sign, the
## buyers price and take the right things, the sell screen pays through
## Inventory.sell (so the pelt still raises pelt_sold), Feyre's walk lines
## fire in order, and the fur stall keeps Act I's direct pelt sale.
extends GutTest

const MARKET := "res://data/market/market.tres"
const GOODS := ["goods_iron", "goods_salt", "goods_pelts", "goods_grain", "goods_furs"]
const PELT_STALL := Vector3(375.16156, 3.0976639, 2269.406)

var market: MarketSet
var sales: Array = []


func _on_sold(item_id: StringName, coin: int) -> void:
	sales.append([item_id, coin])


func before_each() -> void:
	market = load(MARKET) as MarketSet
	Gameplay.reset()
	WorldState.clear()
	sales.clear()
	EventBus.item_sold.connect(_on_sold)


func after_each() -> void:
	EventBus.item_sold.disconnect(_on_sold)
	for m in get_tree().root.find_children("*", "MarketMenu", true, false):
		(m as MarketMenu).close()
		m.free()
	get_tree().paused = false
	Gameplay.reset()


func test_every_stall_has_one_distinct_trade_and_a_sign() -> void:
	var stalls := 0
	for id in GOODS:
		var layer := load("res://world/human_realm/village/scatter/%s.tres" % id) as ScatterLayer
		for i in layer.instances.size() / 5:
			stalls += 1
			var at := Vector3(layer.instances[i * 5], layer.instances[i * 5 + 1], layer.instances[i * 5 + 2])
			var match := market.stalls.filter(func(s: MarketStall) -> bool: return s.scatter_position.distance_to(at) < 0.05)
			assert_eq(match.size(), 1, "%s stall %d at %s has a trade" % [id, i, at])
	assert_eq(market.stalls.size(), stalls, "one trade per stall")
	var trades := {}
	for s in market.stalls:
		assert_false(trades.has(s.trade), "%s is not doubled" % s.trade)
		trades[s.trade] = true
		for path in [s.stall_path, s.goods_path, s.sign_path]:
			assert_true(ResourceLoader.exists(path), "%s: %s" % [s.trade, path])
		assert_lt(s.position.distance_to(s.scatter_position), 1.5, "%s nudged, not moved away" % s.trade)
		assert_true(s.canon in ["C", "A", "X"], "%s is tagged canon" % s.trade)
	assert_true(ResourceLoader.exists("res://story/market/assets/sign_fingerpost.glb"), "the fingerpost")


func test_the_cobbler_keeps_the_act1_pelt_stall() -> void:
	var cobbler := market.stall(&"cobbler")
	assert_not_null(cobbler)
	assert_almost_eq(cobbler.position.distance_to(PELT_STALL), 0.0, 0.05, "the goods_pelts stall, not nudged")


func test_buyers_take_and_price() -> void:
	var merc := market.mercenary
	assert_true(merc.takes(&"obj_wolf_pelt"), "she buys the wolf pelt")
	assert_true(merc.takes(&"ing_hide"), "and a doe hide")
	assert_false(merc.takes(&"ing_mugwort"), "coin for hides, nothing else")
	assert_eq(merc.price(&"obj_wolf_pelt"), 60, "she overpays")
	var clothier := market.buyer(&"clothier")
	assert_lt(clothier.price(&"ing_hide"), merc.price(&"ing_hide"), "the usual buyers bid low")
	var charms := market.buyer(&"charms")
	assert_true(charms.takes(&"ing_mugwort"), "herbs for charms")
	assert_false(charms.takes(&"ing_hide"), "no hides at the charm stall")
	assert_false(charms.takes(&"ing_rabbit"), "no game at the charm stall")
	assert_true(market.buyer(&"spice").takes(&"ing_rabbit"), "game for the pot")
	assert_eq(market.buyers().size(), 5, "mercenary, cobbler, clothier, spice, charms")


func test_selling_the_pelt_to_the_mercenary_pays_and_raises_pelt_sold() -> void:
	WorldState.set_flag("wolf_killed", true)
	var sale := PeltSale.new()
	add_child_autofree(sale)
	Gameplay.inventory.add(&"obj_wolf_pelt", 1)
	Gameplay.inventory.add(&"ing_mugwort", 3)
	var menu := MarketMenu.open_for(get_tree(), market.mercenary)
	assert_true(menu.is_open())
	assert_eq(menu.offers.size(), 1, "only the pelt is on offer to her")
	assert_eq(menu.sell_selected(0), 60)
	assert_eq(Gameplay.inventory.coin, 60)
	assert_eq(Gameplay.inventory.count(&"obj_wolf_pelt"), 0)
	assert_eq(sales, [[&"obj_wolf_pelt", 60]], "item_sold once")
	assert_eq(sale.coin_received, 60, "PeltSale heard the sale (pelt_sold follows its look)")
	assert_true(sale._triggered, "the deed moment is triggered")
	assert_eq(menu.offers.size(), 0, "nothing left for her")
	menu.close()
	assert_false(get_tree().paused, "closing unpauses")


func test_sell_one_then_all() -> void:
	Gameplay.inventory.add(&"ing_mugwort", 3)
	var menu := MarketMenu.open_for(get_tree(), market.buyer(&"charms"))
	assert_eq(menu.sell_selected(1), 1)
	assert_eq(Gameplay.inventory.count(&"ing_mugwort"), 2)
	assert_eq(menu.sell_selected(0), 2)
	assert_eq(Gameplay.inventory.count(&"ing_mugwort"), 0)


func test_fur_stall_sells_the_pelt_directly_and_otherwise_opens_the_cobbler() -> void:
	var stall := FurStall.new()
	add_child_autofree(stall)
	Gameplay.inventory.add(&"obj_wolf_pelt", 1)
	stall.use(null)
	assert_eq(Gameplay.inventory.count(&"obj_wolf_pelt"), 0, "Act I's sale is unchanged")
	assert_eq(sales.size(), 1)
	assert_eq(get_tree().root.find_children("*", "MarketMenu", true, false).size(), 0, "no screen for the pelt")
	stall.use(null)
	assert_eq(get_tree().root.find_children("*", "MarketMenu", true, false).size(), 0, "nothing he takes: nothing opens")
	Gameplay.inventory.add(&"ing_hide", 2)
	stall.use(null)
	var menus := get_tree().root.find_children("*", "MarketMenu", true, false)
	assert_eq(menus.size(), 1)
	assert_eq((menus[0] as MarketMenu).buyer.id, &"cobbler")
	assert_eq((menus[0] as MarketMenu).offers.size(), 1, "the hides")


func test_walk_lines_fire_in_order_and_once() -> void:
	var t := MarketThoughts.new()
	add_child_autofree(t)
	var lines: Array[String] = []
	for p: Vector2 in [HumanRealmLayout.COTTAGE, Vector2(150.0, 2230.0), Vector2(300.0, 2243.0),
			HumanRealmLayout.VILLAGE_SQUARE + Vector2(0.0, 20.0), Vector2(377.0, 2255.0)]:
		lines.append(t.update(p, 0.1))
	assert_eq(lines.size(), 5)
	for i in lines.size():
		assert_eq(lines[i], MarketThoughts.PLACES[i][4], "line %d" % i)
	assert_eq(t.update(HumanRealmLayout.COTTAGE, 0.1), "", "once each")
	assert_true(String(MarketThoughts.PLACES[4][4]).contains("woman by the well"), "names the buyers")


func test_wandering_off_with_the_pelt_gets_a_nudge() -> void:
	var t := MarketThoughts.new()
	add_child_autofree(t)
	t.update(HumanRealmLayout.VILLAGE_SQUARE + Vector2(-200.0, 0.0), 0.1)
	var raised := ""
	for i in 30:
		raised = t.update(HumanRealmLayout.VILLAGE_SQUARE + Vector2(-400.0, -300.0), 1.0)
		if raised != "":
			break
	assert_eq(raised, MarketThoughts.WRONG_WAY[4])


func test_dressing_builds_signs_stations_and_the_mercenary() -> void:
	var d := MarketDressing.new()
	add_child_autofree(d)
	var signs := d.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Sign_"))
	assert_eq(signs.size(), 10, "a sign per stall")
	for prefix in ["Stall_", "Goods_", "Counter_"]:
		assert_eq(d.get_children().filter(func(n: Node) -> bool: return n.name.begins_with(prefix)).size(), 10, prefix)
	assert_not_null(d.get_node_or_null(^"Handcart"))
	assert_not_null(d.get_node_or_null(^"CratePile"))
	var stations := get_tree().get_nodes_in_group(MarketStation.GROUP)
	var ids := stations.map(func(s: MarketStation) -> String: return String(s.buyer.id))
	ids.sort()
	assert_eq(ids, ["charms", "clothier", "mercenary", "spice"], "the cobbler is the FurStall")
	assert_not_null(d.mercenary_station, "her station is by the well in the winter")
	assert_not_null(d.get_node_or_null(^"Fingerpost"))
	for s in d.get_children():
		if s is MeshInstance3D:
			assert_lt((s as MeshInstance3D).mesh.get_faces().size() / 3, 3000, "%s is a prop (<3k tris)" % s.name)


func test_the_mercenary_presence_spot_matches_the_market() -> void:
	var roster := load(CastPresence.ROSTER_PATH) as PresenceRoster
	var found: PresenceSpot = null
	for s in roster.spots:
		if s.speaker == &"mercenary":
			found = s
	assert_not_null(found, "CastPresence stands her at the well")
	assert_almost_eq(found.at.distance_to(Vector2(market.mercenary_at.x, market.mercenary_at.z)), 0.0, 0.05)
	assert_almost_eq(deg_to_rad(found.yaw_deg), market.mercenary_yaw, 0.01)


func test_the_village_stall_layers_give_way() -> void:
	var field := ScatterField.new()
	field.region_id = &"village"
	add_child_autofree(field)
	var chunk := MultiMeshInstance3D.new()
	chunk.name = "stall_brown_3_8"
	field.add_child(chunk)
	var crate := MultiMeshInstance3D.new()
	crate.name = "crate_3_8"
	field.add_child(crate)
	assert_true(MarketDressing.is_village_stall_chunk(chunk))
	assert_false(MarketDressing.is_village_stall_chunk(crate), "only stalls and goods")
	var d := MarketDressing.new()
	add_child_autofree(d)
	assert_false(chunk.visible, "hidden")
	assert_true(crate.visible)


func test_market_keepers_stand_behind_their_counters() -> void:
	var roster := load(CastPresence.ROSTER_PATH) as PresenceRoster
	var keepers := 0
	for sp in roster.spots:
		var id := String(sp.id)
		if not id.begins_with("market_") or id.begins_with("market_shopper"):
			continue
		keepers += 1
		var st := market.stall(StringName(id.trim_prefix("market_")))
		assert_not_null(st, id)
		var k := st.keeper_spot()
		assert_almost_eq(sp.at.distance_to(Vector2(k.x, k.z)), 0.0, 0.05, "%s behind the counter" % id)
	assert_gte(keepers, 4)
