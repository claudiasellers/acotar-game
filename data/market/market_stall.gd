## One stall in the village market and the trade it keeps (lane L53). The
## transform is the stall's own (from the village scatter): +Z is its front.
class_name MarketStall
extends Resource

@export var trade: StringName
@export var display_name: String
@export var canon: String = "X"
## res:// paths of the kit (tools/market/market_kit.py): the stall in its
## awning tone, the trade's goods, and its hanging sign.
@export var stall_path: String
@export var goods_path: String
@export var sign_path: String
## Where the village generator put it (scatter goods layer); `position` and
## `yaw` are that, nudged so the square doesn't read as a perfect ring.
@export var scatter_position: Vector3
@export var position: Vector3
@export var yaw: float
## Empty when the stall only sells to Feyre's neighbours, not to her.
@export var buyer: MarketBuyer


func xform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), position)


## Where a customer stands, 1.7 m in front of the counter.
func customer_spot() -> Vector3:
	return xform() * Vector3(0.0, 0.0, 1.7)


## Where its keeper stands, behind the counter.
func keeper_spot() -> Vector3:
	return xform() * Vector3(0.0, 0.0, -0.35)
