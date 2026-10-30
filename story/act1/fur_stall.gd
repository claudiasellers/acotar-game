## The fur trader's stall at the market (act1_fur_stall). E sells Andras's
## pelt through the inventory's market (Inventory.sell -> item_sold), which is
## what PeltSale waits for. Without the pelt it does nothing.
class_name FurStall
extends SimpleStation

const PELT := &"obj_wolf_pelt"


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
