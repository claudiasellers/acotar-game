## The fur trader's stall at the market (act1_fur_stall). E sells Andras's
## pelt through the inventory's market (Inventory.sell -> item_sold), which is
## what PeltSale waits for. Without the pelt it opens the cobbler's sell
## screen (lane L53, MarketMenu) when she carries hides he takes.
class_name FurStall
extends SimpleStation

const PELT := &"obj_wolf_pelt"
const MARKET := "res://data/market/market.tres"
const TRADE := &"cobbler"


func _ready() -> void:
	super._ready()
	collision_layer = 0
	collision_mask = 0


func has_pelt() -> bool:
	return Gameplay.inventory.count(PELT) > 0


func use(user: Node) -> void:
	super.use(user)
	if has_pelt():
		Gameplay.inventory.sell(PELT, Gameplay.inventory.count(PELT))
	elif cobbler() and not cobbler().offers(Gameplay.inventory).is_empty():
		MarketMenu.open_for(get_tree(), cobbler())


## The cobbler who keeps this stall (data/market/market.tres), or null.
static func cobbler() -> MarketBuyer:
	var market := load(MARKET) as MarketSet if ResourceLoader.exists(MARKET) else null
	return market.buyer(TRADE) if market else null
