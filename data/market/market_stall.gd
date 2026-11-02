## One stall in the village market and the trade it keeps (lane L53). The
## transform is the stall's own (from the village scatter): +Z is its front.
class_name MarketStall
extends Resource

@export var trade: StringName
@export var display_name: String
@export var canon: String = "X"
## res:// path of the trade sign (tools/market/market_signs.py).
@export var sign_path: String
@export var position: Vector3
@export var yaw: float
## Empty when the stall only sells to Feyre's neighbours, not to her.
@export var buyer: MarketBuyer


func xform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), position)


## Where a customer stands, 1.7 m in front of the counter.
func customer_spot() -> Vector3:
	return xform() * Vector3(0.0, 0.0, 1.7)
