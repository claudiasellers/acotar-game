## Selling the pelt at the market (lore: human-village.md). The systems lane
## runs the trade; when Andras's pelt sells, Feyre weighs the coin (the most
## she has held in years) and pelt_sold rises.
class_name PeltSale
extends DeedMoment

## Ids the systems and creatures lanes use for Andras's pelt.
@export var pelt_ids: PackedStringArray = ["obj_wolf_pelt", "great_wolf_pelt"]

var coin_received: int = 0


func _init() -> void:
	space_id = &"pelt_sale"
	deed_flag = "pelt_sold"
	require_flags = PackedStringArray(["wolf_killed"])
	done_flags = PackedStringArray(["pelt_sold"])


func _ready() -> void:
	super._ready()
	EventBus.item_sold.connect(_on_item_sold)


func _on_item_sold(item_id: StringName, coin: int) -> void:
	if pelt_ids.has(String(item_id)):
		coin_received = coin
		trigger()
